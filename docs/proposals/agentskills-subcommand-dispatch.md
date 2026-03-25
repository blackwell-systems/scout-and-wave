# Proposal: Deterministic Subcommand Reference Routing

**Status:** Approved
**Created:** 2026-03-24
**Relates to:** `docs/skills-progressive-disclosure.md`, [Agent Skills specification](https://agentskills.io/specification)

---

## Problem

The [Agent Skills specification](https://agentskills.io/specification) defines a three-tier progressive disclosure model (Metadata → Instructions → Resources). Tier 3 (Resources) loading is convention-based: "the model loads specific files on demand when the skill's instructions reference them."

This is a deliberate gap — the spec is vendor-neutral and cannot standardize on enforcement mechanisms that depend on vendor-specific lifecycle hooks. The consequence is that subcommand dispatch to Tier 3 references is unreliable: `/saw program execute "add caching"` should deterministically load `references/program-flow.md`, but currently depends on the model following a routing table in the skill's instructions.

This proposal solves the subcommand routing problem. It does not attempt to solve mid-execution context loading (failure states, blocked agents, error codes) — those scenarios occur at points in the flow that `UserPromptSubmit` cannot reach, and keyword-based triggers false-positive against skill body content. See [Scope](#scope) and [Known Limitations](#known-limitations).

See `docs/skills-progressive-disclosure.md` § "Known Limitation" for SAW-specific impact.

---

## Scope

**In scope:** Deterministic dispatch of Tier 3 reference files when the user invokes a specific subcommand at prompt time.

Examples of what this reliably solves:
- `/saw program execute "add caching"` → `references/program-flow.md` is in context before the model runs
- `/saw amend "redirect agent C"` → `references/amend-flow.md` is in context before the model runs

**Out of scope:** Mid-execution reference loading triggered by session state (failure detection, blocked agents, error codes like E19/E25/E26). These remain convention-based — the model is expected to follow routing table instructions in SKILL.md. Keyword triggers (`failure|blocked|partial`) are not used in the hook layer because `UserPromptSubmit` receives the post-expansion prompt (full SKILL.md content included), causing false-positives on every invocation. See [Known Limitations](#known-limitations).

---

## Solution: Two Enforcement Layers

Subcommand routing is implemented at two layers — a vendor-neutral script layer that works on any Agent Skills-compliant client, and a Claude Code-specific hook layer that provides deterministic enforcement. Both use the same trigger definitions.

### Layer 1: Injection Script (vendor-neutral)

A script bundled in the skill's `scripts/` directory — the convention the Agent Skills spec already defines for executable code. Any agent that can execute scripts can use this.

```
saw/
├── SKILL.md
├── scripts/
│   └── inject-context        # reads prompt, returns matching references
├── references/
│   └── program-flow.md
```

The skill's instructions include: "Before executing, run `scripts/inject-context` with the user's prompt." The model calls Bash, the script matches triggers and outputs reference content, the model has context.

**Tradeoff:** Model-initiated — the model has to follow the instruction. But "run this one script first" is a simpler convention to follow than a multi-entry routing table with conditional dispatch logic.

### Layer 2: UserPromptSubmit Hook (Claude Code-specific)

For Claude Code users, a `UserPromptSubmit` lifecycle hook injects reference content **before** the model runs — no model decision required.

1. User invokes `/saw program execute "add caching"`
2. `UserPromptSubmit` hook fires, receives the raw prompt text
3. Hook reads skill frontmatter `triggers:` declarations
4. Hook matches `"program"` against prompt, loads `references/program-flow.md`
5. Hook returns `additionalContext` — reference content is prepended to model context
6. Model receives skill + reference content together, never needs to manually read the file

**This layer is deterministic for subcommand dispatch.** The model cannot skip or misroute — the content is in context before it starts.

### Layer 3: Routing Table (fallback)

Current behavior — the model follows routing table instructions in SKILL.md. Unchanged. Active for all invocations where Layers 1 and 2 don't fire or aren't installed.

### Shared Trigger Definitions

Both layers read from the same source — `triggers:` in the skill's YAML frontmatter:

```yaml
---
name: saw
description: Scout-and-Wave parallel agent coordination
triggers:
  - match: "^/saw program"
    inject: references/program-flow.md
  - match: "^/saw amend"
    inject: references/amend-flow.md
---
```

- `match`: regex pattern tested against the user's prompt text at invocation time
- `inject`: path relative to the skill directory
- Multiple matches → all matching references injected (concatenated)
- No match → no injection, zero overhead
- **Only use subcommand anchors (`^/saw program`, `^/saw amend`).** Keyword triggers (`failure|blocked`) belong in the routing table, not here — see [Known Limitations](#known-limitations)

Note: `triggers:` is not part of the Agent Skills spec. It uses the spec's `metadata:` extension point — any key-value mapping is allowed in frontmatter. Unknown keys are ignored by non-SAW clients.

### Hook return value (Layer 2)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "<!-- injected: references/program-flow.md -->\n<file content>"
  }
}
```

---

## Implementation Plan

### Phase 1: Injection script (`scripts/inject-context`)

Vendor-neutral script bundled with the skill:

```bash
#!/usr/bin/env bash
# inject-context — reads prompt from $1 or stdin, outputs matching reference content
# Only subcommand-anchored triggers are reliable here. See proposal § Known Limitations.
set -euo pipefail

PROMPT="${1:-$(cat)}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"

[ -f "$SKILL_FILE" ] || exit 0

# Extract triggers from frontmatter using awk.
# Requires exact indentation: 2 spaces for "- match:", 4 spaces for "inject:".
# If indentation changes, triggers will not parse. See proposal § Known Limitations.
triggers=$(awk '/^---$/{if(++c==2)exit}c==1' "$SKILL_FILE" \
  | awk '/^triggers:/{found=1;next} found && /^  - match:/{m=$0; sub(/.*match: *"?/,"",m); sub(/"? *$/,"",m); match_pat=m; next} found && /^    inject:/{i=$0; sub(/.*inject: *"?/,"",i); sub(/"? *$/,"",i); print match_pat "\t" i; next} found && /^[^ ]/{exit}')

injected=""
while IFS=$'\t' read -r pattern file; do
  [ -z "$pattern" ] && continue
  if echo "$PROMPT" | grep -qE "$pattern"; then
    ref_path="$SKILL_DIR/$file"
    if [ -f "$ref_path" ]; then
      injected+="<!-- injected: $file -->"$'\n'
      injected+="$(cat "$ref_path")"$'\n\n'
    else
      echo "warn: inject target not found: $ref_path" >&2
    fi
  fi
done <<< "$triggers"

[ -n "$injected" ] && printf '%s' "$injected"
```

### Phase 2: Claude Code hook (`inject_skill_context`)

Hook script at `implementations/claude-code/hooks/inject_skill_context`:

```bash
#!/usr/bin/env bash
# inject_skill_context — UserPromptSubmit hook for Claude Code
# Iterates all installed skills, runs trigger matching, returns additionalContext.
# Only fires on subcommand-anchored triggers. See proposal § Known Limitations.
set -euo pipefail

input=$(cat)
PROMPT=$(echo "$input" | jq -r '.prompt // ""')
[ -z "$PROMPT" ] && exit 0

SKILL_DIRS=("$HOME/.claude/skills" "$HOME/.agents/skills")
injected=""

for base_dir in "${SKILL_DIRS[@]}"; do
  [ -d "$base_dir" ] || continue
  for skill_dir in "$base_dir"/*/; do
    inject_script="$skill_dir/scripts/inject-context"
    [ -x "$inject_script" ] || continue
    result=$("$inject_script" "$PROMPT" 2>/dev/null) || true
    [ -n "$result" ] && injected+="$result"$'\n'
  done
done

if [ -n "$injected" ]; then
  jq -n --arg ctx "$injected" \
    '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'
fi
```

The hook is a thin orchestrator — it iterates skill directories and delegates to each skill's own `scripts/inject-context`. Each skill owns its trigger logic. Adding a new skill requires zero hook changes.

### Phase 3: `install.sh` wiring

Handled by the consolidated root `install.sh` (completed):
- Symlinks `inject_skill_context` to `~/.local/bin/`
- Registers `UserPromptSubmit` hook in `~/.claude/settings.json`
- `--generic` mode installs to `~/.agents/skills/saw/` (cross-client convention)

### Phase 4: SAW frontmatter update

Add `triggers:` block to `implementations/claude-code/prompts/saw-skill.md` frontmatter.
Add `scripts/inject-context` to the SAW skill directory.

### Phase 5: Routing table simplification (optional)

Once subcommand dispatch is working, the subcommand entries in the "On-Demand References" routing table in `SKILL.md` become documentation rather than instructions. They can be condensed to:

```
Subcommand references are auto-injected via frontmatter triggers.
Layer 1: scripts/inject-context (any agent). Layer 2: UserPromptSubmit hook (Claude Code).
Manual loading is not required for subcommands but works as a fallback.
Failure/error references must still be loaded manually per the routing table.
```

---

## Known Limitations

### Keyword triggers are not reliable in Layer 2

`UserPromptSubmit` receives `.prompt` after skill body expansion — the full SKILL.md content is included. Triggers like `failure|blocked|partial|E19|E25|E26` false-positive on every invocation because the skill body contains those words.

**Consequence:** Only subcommand-anchored triggers (`^/saw program`, `^/saw amend`) are reliable in Layers 1 and 2. Failure routing, mid-execution error handling, and state-based reference loading remain convention-based (Layer 3). They are not in scope for this proposal.

### The awk frontmatter parser requires exact indentation

The `inject-context` script parses `triggers:` using awk with hardcoded indent patterns (2 spaces for `- match:`, 4 spaces for `inject:`). YAML editors that normalize indentation or use tabs will silently break trigger parsing. The reference files will not be injected and the script exits cleanly — no error surfaced to the user.

Mitigation: add a trigger parse test to `install.sh` that verifies at least one trigger fires on a known pattern before completing installation.

### Context bloat with many installed skills

All matching skills inject. With many installed skills and broad trigger patterns, a single prompt could accumulate significant reference content. Currently low risk but worth a guard if skill count grows beyond ~10.

---

## Design Properties

### Three layers of redundancy

All three layers are active simultaneously:

1. **Hook layer** (Claude Code): deterministic injection before the model runs — subcommands only
2. **Script layer** (any agent): model-initiated injection via `scripts/inject-context` — subcommands only
3. **Routing table** (fallback): model reads references based on SKILL.md instructions — all scenarios including mid-execution

A user with the hook gets Layer 1 for subcommands (best). Without the hook but with script support, they get Layer 2 (good). Without either, they get Layer 3 (current behavior). No regression at any level.

### Spec alignment

The solution uses only conventions the Agent Skills spec already defines:
- `scripts/` directory for executable code
- `metadata:` extension point for custom frontmatter fields
- `references/` directory for on-demand content

The `triggers:` field is skill-specific metadata using the spec's existing extensibility. Any agent that doesn't understand `triggers:` simply ignores it.

### Scope control

The hook only fires on `UserPromptSubmit` (user-initiated prompts). It does not fire on model tool calls, sub-agent messages, or internal orchestration.

### Performance

- No injection = no overhead (fast pattern miss per skill)
- Injection = one file read per matched trigger (negligible)
- Hook exits 0 with no output if nothing matches (transparent to Claude Code)

---

## Relationship to Agent Skills Spec

The [Agent Skills specification](https://agentskills.io/specification) defines progressive disclosure but intentionally leaves Resource (Tier 3) enforcement to the client implementation.

This proposal provides enforcement for the subcommand dispatch case specifically:

| Layer | Mechanism | Vendor-neutral? | Enforcement | Scope |
|-------|-----------|-----------------|-------------|-------|
| Script | `scripts/inject-context` | Yes — any agent with Bash | Model-initiated | Subcommands only |
| Hook | `UserPromptSubmit` | No — Claude Code only | Deterministic | Subcommands only |
| Fallback | Routing table in SKILL.md | Yes — any agent | Convention-based | All scenarios |

The script layer is a candidate for upstream contribution to the Agent Skills ecosystem — it uses only spec-defined conventions and works on any compliant client. The contribution would be scoped to subcommand routing specifically, not general context injection.
