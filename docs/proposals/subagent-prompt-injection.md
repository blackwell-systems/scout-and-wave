# Decision Record: Deterministic Agent Type Reference Injection

**Status:** Implemented — pattern encoded in `IMPL-{scout,wave-agent,critic-agent,planner,integration-agent}-prompt-extraction.yaml`; injection blocks are the Scout path and Checks 10–13 in `validate_agent_launch`.
**Created:** 2026-03-25
**Relates to:** `docs/proposals/agentskills-subcommand-dispatch.md`, `docs/skills-progressive-disclosure.md`
**Previously named:** `agentskills-agent-type-injection.md` (renamed: mechanism is SAW-internal, not an Agent Skills spec contribution)

---

## Context

The `agentskills-subcommand-dispatch.md` proposal solves Tier 3 reference loading for **orchestrator-level** subcommands — `/saw program execute`, `/saw amend` — using the `UserPromptSubmit` hook and `additionalContext`. Content is injected into the orchestrator's context before it runs.

Extracting heavy procedure content from agent type prompts (`wave-agent.md`, `critic-agent.md`, `scout.md`, `planner.md`, `integration-agent.md`) into `references/` files requires a second, distinct injection mechanism. Convention-based loading ("read this file if you need it") is insufficient — the agent may not follow the instruction, or reads it too late.

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
      "prompt": "<!-- injected: references/wave-agent-worktree-isolation.md -->\n[reference content]\n\n[original prompt]",
      "description": "[original description]",
      "run_in_background": false
    }
  }
}
```

The `updatedInput` object is derived from the full original `tool_input` — not constructed from scratch — so all fields (`run_in_background`, `model`, `name`, `isolation`, etc.) survive the hook unmodified. Only `prompt` (and `description`, when auto-fixing scout tags) is overwritten.

### jq implementation

```bash
# tool_input is the full original tool_input object captured at hook entry
inject_content="<!-- injected: $ref_file -->\n$(command cat "$ref_path")"
jq -n --arg inject "$inject_content" --arg orig "$prompt" --argjson orig_input "$tool_input" \
  '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow",
    "updatedInput": ($orig_input | .prompt = ($inject + "\n\n" + $orig))}}'
```

The `$orig_input | .prompt = (...)` pattern modifies `prompt` in place on the original object, preserving all other fields.

---

## Decision: Single-Hook Type Dispatch

Rather than one hook per agent type, a single `PreToolUse` hook on the `Agent` tool dispatches by `subagent_type` (with description-tag fallback). Each agent type is handled by a separate `if` block — not a single `case` statement — because each block may exit the hook independently:

```bash
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty')

# Scout path — before Check 1
if [[ "$subagent_type" == "scout" ]] || [[ "$description" =~ \[SAW:scout ]]; then
  # inject scout-suitability-gate.md, scout-implementation-process.md
  # conditional: scout-program-contracts.md (only when prompt has --program)
  # ... emit updatedInput, exit 0
fi

# Check 11: critic-agent — before Check 1
if [[ "$subagent_type" == "critic-agent" ]] || [[ "$description" =~ \[SAW:critic ]]; then
  # inject critic-agent-verification-checks.md, critic-agent-completion-format.md
  # ... emit updatedInput, exit 0
fi

# Check 12: planner — before Check 1
if [[ "$subagent_type" == "planner" ]] || [[ "$description" =~ \[SAW:planner ]]; then
  # inject planner-suitability-gate.md, planner-implementation-process.md, planner-example-manifest.md
  # ... emit updatedInput, exit 0
fi

# Check 13: integration-agent — before Check 1
if [[ "$subagent_type" == "integration-agent" ]] || [[ "$description" =~ \[SAW:integration ]]; then
  # inject integration-connectors-reference.md, integration-agent-completion-report.md
  # ... emit updatedInput, exit 0
fi

# Check 1: wave-agent tag extraction — non-wave-agent calls exit here
if ! [[ "$description" =~ \[SAW:wave([0-9]+):agent-([A-Za-z0-9]+)\] ]]; then
  exit 0
fi

# Checks 2–8: IMPL exists, IMPL valid, agent in wave, ownership file, worktree branch, scaffold committed

# Check 10: wave-agent injection — runs after Checks 2–8 pass
if [[ "$subagent_type" == "wave-agent" ]] || [[ "$description" =~ \[SAW:wave ]]; then
  # inject wave-agent-worktree-isolation.md, wave-agent-completion-report.md, wave-agent-build-diagnosis.md
  # conditional: wave-agent-program-contracts.md (only when frozen_contracts_hash present)
  # ... emit updatedInput, exit 0
fi
```

For each matched type, the hook reads the corresponding reference files from `~/.claude/skills/saw/references/`, prepends them to the agent prompt, and returns the `updatedInput` JSON. If reference files are missing, the hook skips injection silently (graceful degradation) and falls through to the original prompt.

### The mapping is declared in frontmatter, not hardcoded

The type→file mapping is not hardcoded in the hook or the script. It lives in `saw-skill.md` frontmatter under `agent-references:`, using the same flat-list structure as `triggers:`:

```yaml
agent-references:
  - agent-type: scout
    inject: references/scout-suitability-gate.md
  - agent-type: scout
    inject: references/scout-program-contracts.md
    when: "--program"
  - agent-type: wave-agent
    inject: references/wave-agent-worktree-isolation.md
  - agent-type: wave-agent
    inject: references/wave-agent-program-contracts.md
    when: "frozen_contracts_hash|frozen: true"
  # ... etc
```

Each entry has `agent-type`, `inject` (path relative to skill dir), and optional `when` (regex applied to the agent prompt for conditional injection). `scripts/inject-agent-context` reads this block at runtime using the same awk-based frontmatter parser as `inject-context`. The hook's `if` blocks are the Claude Code enforcement layer; the frontmatter is the single source of truth for what gets injected. Adding a new agent type requires one frontmatter entry and one hook block — no changes to either script.

This hook already exists as `validate_agent_launch` (registered as `PreToolUse/Agent` in `settings.json`). Checks 1–8 are enforcement (blocking bad agent launches). Injection uses named blocks: Scout path, Checks 10–13 — same hook, same registration, same test path.

**One registration, one file, unified dedup logic.**

### Execution order in the hook

The ordering is structurally significant:

1. **Scout path** — before Check 1; injects scout references, emits `updatedInput`, exits 0
2. **Check 11 (critic-agent)** — before Check 1; injects critic references, emits `updatedInput`, exits 0
3. **Check 12 (planner)** — before Check 1; injects planner references, emits `updatedInput`, exits 0
4. **Check 13 (integration-agent)** — before Check 1; injects integration references, emits `updatedInput`, exits 0
5. **Check 1** — extracts `[SAW:wave{N}:agent-{ID}]` tag; non-wave-agent calls exit here
6. **Checks 2–8** — IMPL existence, validation, agent-in-wave, ownership file, worktree branch, scaffold committed
7. **Check 10 (wave-agent)** — runs after Checks 2–8 pass; injects wave-agent references

Checks 11–13 and the Scout path must run before Check 1 because Check 1 exits 0 for any description that does not match the wave-agent pattern — those agent types would never reach their injection blocks if positioned after it. Check 10 is positioned after Checks 2–8 because wave-agent injection should only fire when the structural pre-launch checks have passed.

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

PreToolUse/Agent → validate_agent_launch (Scout path + Checks 10–13)
  Matches:  subagent_type ∈ {scout, critic-agent, planner, integration-agent, wave-agent}
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
<!-- injected: references/wave-agent-worktree-isolation.md -->
```

Before injecting, the hook checks whether the marker already appears in the prompt. If present, skip. This handles cases where the orchestrator manually prepended the reference (e.g., for debugging) or where multiple hook layers might otherwise stack.

---

## How to Extend — Adding a New Agent Type

**Step 1: Declare the mapping in `saw-skill.md` frontmatter.**

Add one entry per reference file under `agent-references:`:

```yaml
agent-references:
  - agent-type: my-agent
    inject: references/my-agent-procedure.md
  - agent-type: my-agent
    inject: references/my-agent-completion.md
    when: "some-condition-regex"   # omit if always-inject
```

`scripts/inject-agent-context` picks this up automatically — no script changes needed.

**Step 2: Add a detection block to `validate_agent_launch`.**

Insert an `if` block **before Check 1** (the wave-agent tag gate). Non-wave-agent types must exit before Check 1 or they will be silently passed through.

```bash
# Check N: my-agent reference injection — before Check 1
is_my_agent=false
if [[ "$subagent_type" == "my-agent" ]] || [[ "$description" =~ \[SAW:my-agent ]]; then
  is_my_agent=true
fi

if [[ "$is_my_agent" == "true" ]]; then
  skill_dir="${CLAUDE_SKILL_DIR:-${HOME}/.claude/skills/saw}"
  ref_dir="${skill_dir}/references"
  inject_content=""

  for ref_file in my-agent-procedure.md my-agent-completion.md; do
    ref_path="${ref_dir}/${ref_file}"
    if [[ -f "$ref_path" ]] && ! echo "$prompt" | grep -qF "<!-- injected: references/${ref_file} -->"; then
      inject_content+="<!-- injected: references/${ref_file} -->"$'\n'
      inject_content+="$(command cat "$ref_path")"$'\n\n'
    fi
  done

  if [[ -n "$inject_content" ]]; then
    jq -n --arg inject "$inject_content" --arg orig "$prompt" --argjson orig_input "$tool_input" \
      '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow",
        "updatedInput": ($orig_input | .prompt = ($inject + "\n\n" + $orig))}}'
    exit 0
  fi
fi
```

**Step 3: No installer changes needed.** `install.sh` dynamically discovers all `*.md` files in `references/` — adding a new reference file requires no installer update.

**Step 4: Verify.** Launch the new agent type and confirm the injection markers appear in its initial context before it takes its first step.

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
| `validate_agent_launch` Scout path + Checks 10–13 | `PreToolUse/Agent` | Subagents | Deterministic | Agent types |
| `scripts/inject-agent-context` | (none — model-initiated) | Subagents | Convention-based | Agent types |
| Routing table in SKILL.md | — | All | Convention-based | All scenarios |

The `updatedInput` mechanism is Claude Code-specific. The concept is generalizable — any agent framework with a pre-tool-use hook that supports parameter modification could implement the same pattern.

For platforms without Claude Code hooks (raw API, other LLMs, CI/CD), `scripts/inject-agent-context` provides a vendor-neutral fallback. It mirrors the same reference mapping and dedup marker protocol as the hook, but runs as a model-initiated bash script:

```bash
inject=$(bash ${SKILL_DIR}/scripts/inject-agent-context --type wave-agent --prompt "$agent_prompt")
full_prompt="${inject}${agent_prompt}"
```

The key trade-off: the hook fires deterministically (always), while the script fires only if the orchestrator on that platform knows to call it. The orchestrator skill prompt (or its equivalent on the target platform) must reference the script. The dedup markers are shared between layers, so if both run, double-injection is prevented.
