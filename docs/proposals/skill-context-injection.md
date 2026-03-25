# Proposal: Skill Context Injection via UserPromptSubmit Hook

**Status:** Proposal
**Created:** 2026-03-24
**Relates to:** `docs/skills-progressive-disclosure.md`

---

## Problem

The current progressive disclosure model relies on the orchestrator *following* a routing table in `SKILL.md`. This is convention-based — the model can ignore it, pre-load everything, or load references at the wrong time. There is no enforcement.

See `docs/skills-progressive-disclosure.md` § "Known Limitation" for the full gap description.

---

## Proposed Solution

Use the `UserPromptSubmit` lifecycle hook to automatically inject reference file content into the model's context **before** the skill runs, based on pattern matches declared in the skill's YAML frontmatter.

### How it works

1. User invokes `/saw program execute "add caching"`
2. `UserPromptSubmit` hook fires, receives the raw prompt text
3. Hook reads `~/.claude/skills/saw/SKILL.md` frontmatter
4. Frontmatter declares trigger patterns and which reference file each maps to
5. Hook matches `"program"` against prompt, loads `references/program-flow.md`
6. Hook returns `additionalContext` — reference content is prepended to model context
7. Model receives skill + reference content together, never needs to manually read the file

### Frontmatter extension (proposed)

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
- `inject`: path relative to the skill directory (`~/.claude/skills/<name>/`)
- Multiple matches in one invocation → all matching references injected (concatenated)
- No match → no injection, zero overhead

### Hook return value

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

### Phase 1: Hook script (`inject_skill_context`)

New hook script at `implementations/claude-code/hooks/inject_skill_context`:

```bash
#!/usr/bin/env bash
# inject_skill_context — UserPromptSubmit hook for skill context injection
# Reads skill frontmatter triggers and injects matching reference files.

PROMPT=$(jq -r '.prompt // ""' 2>/dev/null)
SKILL_DIR="$HOME/.claude/skills"

injected=""

for skill_dir in "$SKILL_DIR"/*/; do
  skill_file="$skill_dir/SKILL.md"
  [ -f "$skill_file" ] || continue

  # Extract triggers block from frontmatter (between --- delimiters)
  # Parse each trigger's match pattern and inject path
  # If prompt matches, append file contents to injected string
done

if [ -n "$injected" ]; then
  payload=$(jq -n --arg ctx "$injected" \
    '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}')
  echo "$payload"
fi
```

Full implementation uses `yq` or `awk` to parse YAML frontmatter triggers.

### Phase 2: `install.sh` wiring

Add to `hooks/install.sh`:
- Symlink `inject_skill_context` to `~/.local/bin/`
- Register `UserPromptSubmit` hook in `~/.claude/settings.json`

### Phase 3: SAW frontmatter update

Add `triggers:` block to `implementations/claude-code/prompts/saw-skill.md` frontmatter.

### Phase 4: Routing table simplification (optional)

Once injection is working, the "On-Demand References" routing table in `SKILL.md` becomes documentation rather than instructions. It can be condensed to a single line:

```
Reference files are auto-injected by the UserPromptSubmit hook based on
frontmatter triggers. Manual loading is not required.
```

This saves ~10 lines of core skill content and removes the model's decision point entirely.

---

## Design Properties

### Redundancy in the happy path

Both layers are active simultaneously:
- **Hook layer**: injects reference content deterministically before the model runs
- **Routing table**: still present as documentation/fallback if hook is not installed

A user without the hook gets current behavior (model follows routing table). A user with the hook gets automatic injection. No regression either way.

### Generalization

This pattern is not SAW-specific. Any skill in `~/.claude/skills/` that declares `triggers:` frontmatter gets automatic context injection. The hook script iterates all skill directories — one install, universal coverage.

Future skills benefit without any additional setup beyond adding `triggers:` to their frontmatter.

### Scope control

The hook only fires on `UserPromptSubmit` (user-initiated prompts). It does not fire on:
- Model tool calls (no spurious injections during wave execution)
- Sub-agent messages
- Internal orchestration

### Performance

- No injection = no overhead (fast pattern miss)
- Injection = one file read per matched trigger (negligible)
- Hook exits 0 with no output if nothing matches (transparent to Claude Code)

---

## Open Questions

1. **Parser choice**: `yq` for YAML frontmatter parsing is clean but adds a dependency. `awk`-based parsing is dependency-free but brittle. Which is acceptable?

2. **Multiple skill match**: If two skills both match the same prompt, both inject. Is that desirable or should first-match win?

3. **Failure mode**: If the injected file doesn't exist (broken symlink), hook should log a warning and continue rather than blocking the prompt.

4. **Timing relative to skill load**: `UserPromptSubmit` fires before the skill loads. The injected content arrives in context *before* `SKILL.md`. Is ordering guaranteed? Does it matter?

---

## Relationship to Progressive Disclosure

This proposal completes the progressive disclosure model by converting it from convention-based to enforcement-based:

| Tier | Current | With injection |
|------|---------|---------------|
| Metadata | Always loaded (Skills API) | Unchanged |
| Core SKILL.md | Always loaded on invocation | Unchanged |
| Reference files | Model reads on routing match | Hook injects on pattern match |

The three-tier structure is preserved. The enforcement mechanism for Tier 3 changes from model instruction to hook automation.
