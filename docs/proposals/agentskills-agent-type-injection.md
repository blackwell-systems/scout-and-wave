# Decision Record: Deterministic Agent Type Reference Injection

**Status:** Implemented — pattern encoded in `IMPL-{scout,wave-agent,critic-agent,planner}-prompt-extraction.yaml`; `validate_agent_launch` checks 9+ are Wave 2 Agent D in each IMPL.
**Created:** 2026-03-25
**Relates to:** `docs/proposals/agentskills-subcommand-dispatch.md`, `docs/skills-progressive-disclosure.md`

---

## Context

The `agentskills-subcommand-dispatch.md` proposal solves Tier 3 reference loading for **orchestrator-level** subcommands — `/saw program execute`, `/saw amend` — using the `UserPromptSubmit` hook and `additionalContext`. Content is injected into the orchestrator's context before it runs.

Extracting heavy procedure content from agent type prompts (`wave-agent.md`, `critic-agent.md`, `scout.md`, `planner.md`) into `references/` files requires a second, distinct injection mechanism. Convention-based loading ("read this file if you need it") is insufficient — the agent may not follow the instruction, or reads it too late.

`UserPromptSubmit` cannot solve this. It fires when the user submits a prompt; by the time the orchestrator calls the `Agent` tool to launch a subagent, `UserPromptSubmit` is long past. There is no mechanism within that hook to target a subagent's initial context.

The correct mechanism is **`updatedInput` in a `PreToolUse` hook on the `Agent` tool**. This was discovered during the progressive disclosure extraction project (2026-03-25) after three critic cycles caught the wrong mechanism (`additionalContext`). This document records the decision and explains the reasoning.

---

## Mechanism: `updatedInput` vs `additionalContext`

Claude Code's `PreToolUse` hook supports two distinct output fields. They are not interchangeable:

| Field | Target | Use case |
|-------|--------|----------|
| `additionalContext` | The **calling model's** context (orchestrator) | Add background info the orchestrator needs before deciding |
| `updatedInput` | The **tool call parameters** before execution | Modify what gets passed into the tool — including the subagent's `prompt` |

For subagent injection, `additionalContext` is wrong: it augments the orchestrator, which already has its context. `updatedInput.prompt` modifies the `Agent` tool's `prompt` parameter before Claude Code launches the subagent. The subagent receives the modified prompt as its initial message — the reference content is present before it takes its first step.

### Correct hook output format

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "prompt": "<!-- injected: references/wave-agent-isolation.md -->\n[reference content]\n\n[original prompt]"
    }
  }
}
```

### jq implementation

```bash
inject_content="<!-- injected: $ref_file -->\n$(cat "$ref_path")"
jq -n --arg inject "$inject_content" --arg orig "$prompt" \
  '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow",
    "updatedInput": {"prompt": ($inject + "\n\n" + $orig)}}}'
```

---

## Decision: Single-Hook Type Dispatch

Rather than one hook per agent type, a single `PreToolUse` hook on the `Agent` tool dispatches by `subagent_type`:

```bash
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty')

case "$subagent_type" in
  wave-agent)   refs=("worktree-isolation.md" "build-diagnosis.md" "completion-report.md") ;;
  critic-agent) refs=("verification-checks.md" "completion-format.md") ;;
  scout)        refs=("suitability-gate.md" "scout-procedure.md") ;;
  planner)      refs=("suitability-gate.md" "implementation-process.md" "example-manifest.md") ;;
  *)            exit 0 ;;
esac
```

For each matched type, the hook reads the corresponding reference files from `~/.claude/skills/saw/references/`, prepends them to the agent prompt, and returns the `updatedInput` JSON. If reference files are missing, the hook skips injection silently (graceful degradation) and falls through to the original prompt.

This hook already exists as `validate_agent_launch` (registered as `PreToolUse/Agent` in `settings.json`). Checks 1–8 are enforcement (blocking bad agent launches). Injection is appended as checks 9+ — same hook, same registration, same test path.

**One registration, one file, unified dedup logic.**

---

## Two-Layer Injection Architecture

This proposal and `agentskills-subcommand-dispatch.md` define complementary layers that cover the full injection surface:

```
User types: /saw wave

UserPromptSubmit → inject_skill_context
  Matches:  ^/saw program, ^/saw amend (subcommand anchors)
  Injects:  program-flow.md, amend-flow.md, failure-routing.md
  Target:   Orchestrator context (additionalContext)
  Hook:     UserPromptSubmit

      │
      ▼  (orchestrator runs, calls Agent tool)

PreToolUse/Agent → validate_agent_launch (checks 9+)
  Matches:  subagent_type ∈ {wave-agent, critic-agent, scout, planner}
  Injects:  agent type reference files
  Target:   Subagent initial prompt (updatedInput)
  Hook:     PreToolUse
```

Neither layer can substitute for the other:
- `UserPromptSubmit` fires at user prompt time — it cannot reach a subagent launched later
- `PreToolUse/Agent` fires at agent launch time — it cannot target the orchestrator's earlier context

---

## Dedup Marker Protocol

Injection uses HTML comment markers to prevent double-injection across layers:

```
<!-- injected: references/wave-agent-isolation.md -->
```

Before injecting, the hook checks whether the marker already appears in the prompt. If present, skip. This handles cases where the orchestrator manually prepended the reference (e.g., for debugging) or where multiple hook layers might otherwise stack.

---

## Known Limitations

### Silent degradation on missing reference files

If a reference file is not symlinked into `~/.claude/skills/saw/references/`, the hook skips injection without error. The agent launches with the slimmed core prompt only — it will not have the reference content and may produce lower-quality output or miss required procedures.

**Mitigation:** Add a reference file existence check to `install.sh` that verifies each declared reference file resolves at install time. Surfacing a missing symlink at install is far preferable to silent degradation at runtime.

### Non-`subagent_type` launches bypass injection

If an orchestrator launches an agent using `subagent_type: general-purpose` with a full prompt (the fallback path), the hook's type dispatch will not match. The fallback path is expected to carry full context in the prompt itself — this is by design, not a gap.

### Context bloat with large reference sets

Multiple reference files per agent type contribute to the subagent's initial context. For agents with 3+ reference files, monitor total context size. Currently low risk (reference files are bounded in scope), but worth a guard if the reference set grows significantly.

---

## Relationship to Agent Skills Spec

The Agent Skills specification defines Tier 3 (Resources) as convention-based. This proposal provides a Claude Code-specific enforcement layer for the **subagent** tier — analogous to the hook layer in `agentskills-subcommand-dispatch.md`, which provides enforcement for the **orchestrator** tier.

| Layer | Hook event | Target | Enforcement | Scope |
|-------|-----------|--------|-------------|-------|
| `inject_skill_context` | `UserPromptSubmit` | Orchestrator | Deterministic | Subcommands |
| `validate_agent_launch` checks 9+ | `PreToolUse/Agent` | Subagents | Deterministic | Agent types |
| Routing table in SKILL.md | — | All | Convention-based | All scenarios |

The `updatedInput` mechanism is Claude Code-specific. The concept is generalizable — any agent framework with a pre-tool-use hook that supports parameter modification could implement the same pattern. The `inject-context` script layer from `agentskills-subcommand-dispatch.md` does not extend to this case because it runs at user prompt time, not at agent launch time.
