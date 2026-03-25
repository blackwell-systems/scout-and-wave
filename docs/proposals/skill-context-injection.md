# Proposal: Skill Context Injection

**Status:** Approved
**Created:** 2026-03-24
**Relates to:** `docs/skills-progressive-disclosure.md`, [Agent Skills specification](https://agentskills.io/specification)

---

## Problem

The [Agent Skills specification](https://agentskills.io/specification) defines a three-tier progressive disclosure model (Metadata → Instructions → Resources). The spec intentionally leaves Tier 3 (Resources) loading as convention-based: "the model loads specific files on demand when the skill's instructions reference them."

This is a deliberate gap — the spec is vendor-neutral and cannot standardize on enforcement mechanisms that depend on vendor-specific lifecycle hooks. But the consequence is that Resource loading is unreliable. The model can ignore routing tables, pre-load everything, or load references at the wrong time.

See `docs/skills-progressive-disclosure.md` § "Known Limitation" for SAW-specific impact.

---

## Proposed Solution: Two Layers

Context injection is implemented at two layers — a vendor-neutral script layer that works on any Agent Skills-compliant client, and a Claude Code-specific hook layer that provides deterministic enforcement. Both use the same trigger definitions.

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

**Tradeoff:** This is model-initiated — the model has to follow the instruction. But "run this one script first" is a much simpler convention to follow than a multi-entry routing table with conditional dispatch logic.

### Layer 2: UserPromptSubmit Hook (Claude Code-specific)

For Claude Code users, a `UserPromptSubmit` lifecycle hook injects reference content **before** the model runs — no model decision required.

1. User invokes `/saw program execute "add caching"`
2. `UserPromptSubmit` hook fires, receives the raw prompt text
3. Hook reads skill frontmatter `triggers:` declarations
4. Hook matches `"program"` against prompt, loads `references/program-flow.md`
5. Hook returns `additionalContext` — reference content is prepended to model context
6. Model receives skill + reference content together, never needs to manually read the file

**This layer is deterministic.** The model cannot skip or misroute — the content is in context before it starts.

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
  - match: "failure|blocked|partial|E19|E25|E26"
    inject: references/failure-routing.md
---
```

- `match`: regex pattern tested against the full prompt text
- `inject`: path relative to the skill directory
- Multiple matches in one invocation → all matching references injected (concatenated)
- No match → no injection, zero overhead

Note: `triggers:` is not part of the Agent Skills spec. It uses the spec's `metadata:` extension point — any key-value mapping is allowed in frontmatter. The trigger definitions are stored where both layers can read them without duplication.

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
set -euo pipefail

PROMPT="${1:-$(cat)}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"

[ -f "$SKILL_FILE" ] || exit 0

# Extract triggers from frontmatter using awk
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

This works on any agent that can run `bash scripts/inject-context "user prompt text"`.

### Phase 2: Claude Code hook (`inject_skill_context`)

Hook script at `implementations/claude-code/hooks/inject_skill_context`:

```bash
#!/usr/bin/env bash
# inject_skill_context — UserPromptSubmit hook for Claude Code
# Iterates all installed skills, runs trigger matching, returns additionalContext.
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

The hook is a thin orchestrator — it iterates skill directories and delegates to each skill's own `scripts/inject-context`. This means:
- Each skill owns its trigger logic
- The hook doesn't need to parse frontmatter itself
- Adding a new skill requires zero hook changes

### Phase 3: `install.sh` wiring

Add to `hooks/install.sh`:
- Symlink `inject_skill_context` to `~/.local/bin/`
- Register `UserPromptSubmit` hook in `~/.claude/settings.json`
- Scan both `~/.claude/skills/` and `~/.agents/skills/` (cross-client convention)

### Phase 4: SAW frontmatter update

Add `triggers:` block to `implementations/claude-code/prompts/saw-skill.md` frontmatter.
Add `scripts/inject-context` to the SAW skill directory.

### Phase 5: Routing table simplification (optional)

Once injection is working, the "On-Demand References" routing table in `SKILL.md` becomes documentation rather than instructions. It can be condensed to:

```
Reference files are auto-injected based on frontmatter triggers.
Layer 1: scripts/inject-context (any agent). Layer 2: UserPromptSubmit hook (Claude Code).
Manual loading is not required but works as a fallback.
```

---

## Design Properties

### Three layers of redundancy

All three layers are active simultaneously:

1. **Hook layer** (Claude Code): deterministic injection before the model runs
2. **Script layer** (any agent): model-initiated injection via `scripts/inject-context`
3. **Routing table** (fallback): model reads references based on SKILL.md instructions

A user with the hook gets Layer 1 (best). Without the hook but with script support, they get Layer 2 (good). Without either, they get Layer 3 (current behavior). No regression at any level.

### Spec alignment

The solution uses only conventions the Agent Skills spec already defines:
- `scripts/` directory for executable code
- `metadata:` extension point for custom frontmatter fields
- `references/` directory for on-demand content

The `triggers:` field is not a spec extension — it's skill-specific metadata using the spec's existing extensibility. Any agent that doesn't understand `triggers:` simply ignores it.

### Scope control

The hook only fires on `UserPromptSubmit` (user-initiated prompts). It does not fire on:
- Model tool calls (no spurious injections during wave execution)
- Sub-agent messages
- Internal orchestration

### Performance

- No injection = no overhead (fast pattern miss per skill)
- Injection = one file read per matched trigger (negligible)
- Hook exits 0 with no output if nothing matches (transparent to Claude Code)

---

## Design Decisions

1. **Parser**: `awk` for frontmatter extraction — no `yq` dependency. The trigger block is simple (`match:` + `inject:` lines between `---` delimiters). `jq` is already a universal dependency for hook JSON I/O.

2. **Multiple skill match**: All matching skills inject. If `/saw program` matches both SAW triggers and another skill's triggers, both are relevant context. No first-match-wins cutoff.

3. **Failure mode**: Missing inject files log to stderr and continue. Never block a prompt — a broken symlink is not worth stalling the user.

4. **Timing**: `additionalContext` from `UserPromptSubmit` is injected into model context before the skill processes. This is the desired ordering — reference content is available when the model first encounters the skill prompt.

5. **Hook delegates to scripts**: The Claude Code hook doesn't parse frontmatter itself — it calls each skill's `scripts/inject-context`. This keeps trigger logic owned by the skill, not the infrastructure.

6. **Dispatch-time triggers only**: `UserPromptSubmit` receives the prompt after skill body expansion — the full SKILL.md content is in the `.prompt` field, not just the user's raw text. This means keyword triggers like `failure|blocked|partial` will false-positive on every invocation because the skill's own instructions contain those words. Only dispatch-time references (subcommand routing via `^/saw program`, `^/saw amend`) should use triggers. Mid-execution references (loaded after agents report back) stay convention-based — they're needed at a point in the flow that the hook can't reach.

---

## Relationship to Agent Skills Spec

The [Agent Skills specification](https://agentskills.io/specification) defines progressive disclosure but intentionally leaves Resource (Tier 3) enforcement to the client implementation. The [client implementation guide](https://agentskills.io/client-implementation/adding-skills-support) notes that "the model loads specific files on demand when the skill's instructions reference them" — convention-based.

This proposal provides enforcement at two levels:

| Layer | Mechanism | Vendor-neutral? | Enforcement |
|-------|-----------|-----------------|-------------|
| Script | `scripts/inject-context` | Yes — any agent with Bash | Model-initiated (simpler convention) |
| Hook | `UserPromptSubmit` | No — Claude Code only | Deterministic (pre-model) |
| Fallback | Routing table in SKILL.md | Yes — any agent | Convention-based (current behavior) |

The script layer is a candidate for upstream contribution to the Agent Skills ecosystem — it uses only spec-defined conventions and works on any compliant client. The hook layer is a Claude Code reference implementation of the same pattern.
