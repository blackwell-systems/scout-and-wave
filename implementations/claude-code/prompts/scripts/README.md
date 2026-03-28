# Scripts Directory

This directory contains **vendor-neutral fallback scripts** for Scout-and-Wave's progressive disclosure system. These scripts enable reference injection on platforms that don't support Claude Code hooks (raw API, other LLMs, CI/CD environments).

## Purpose

Scout-and-Wave uses a two-layer progressive disclosure architecture:

1. **Hook layer** (Claude Code): `validate_agent_launch` and `inject_skill_context` hooks automatically inject reference files when launching agents or processing user prompts
2. **Script layer** (vendor-neutral): Bash scripts that can be called manually from agent prompts when hooks are unavailable

These scripts mirror the logic of Claude Code hooks but run as model-initiated bash commands. They read configuration from the skill's `saw-skill.md` frontmatter and inject matching reference files based on triggers or agent types.

## Scripts

### `inject-context`

**Purpose:** Context injection for user-invoked commands based on trigger patterns.

**When used:** Automatically called by the `inject_skill_context` hook when the user types a `/saw` command. Can be manually invoked on platforms without hooks.

**How it works:**
1. Reads `triggers:` section from `saw-skill.md` frontmatter
2. Matches user prompt against regex patterns
3. Outputs concatenated contents of matching reference files with injection markers

**Configuration (saw-skill.md frontmatter):**
```yaml
triggers:
  - match: "^/saw program"
    inject: references/program-flow.md
  - match: "^/saw amend"
    inject: references/amend-flow.md
```

**Usage:**
```bash
# From stdin
echo "/saw program plan" | bash scripts/inject-context

# From argument
bash scripts/inject-context "/saw amend --add-wave"

# Model-initiated (in agent prompt instructions):
inject=$(bash ${CLAUDE_SKILL_DIR}/scripts/inject-context "$user_prompt")
```

**Output format:**
```
<!-- injected: references/program-flow.md -->
[contents of program-flow.md]

<!-- injected: references/amend-flow.md -->
[contents of amend-flow.md]
```

**Exit codes:**
- `0` - Success (output may be empty if no triggers matched)
- `1` - Error (SKILL.md missing or parse failure)

**Related documentation:**
- [agentskills-subcommand-dispatch.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/agentskills-subcommand-dispatch.md) - Original design proposal
- [inject_skill_context hook](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/inject_skill_context) - Hook orchestrator

---

### `inject-agent-context`

**Purpose:** Reference injection for subagent launches based on agent type and conditional patterns.

**When used:** Automatically called by the `validate_agent_launch` hook when spawning Scout, Wave, Critic, Planner, or Integration agents. Can be manually invoked on platforms without hooks.

**How it works:**
1. Reads `agent-references:` section from `saw-skill.md` frontmatter
2. Matches requested agent type (e.g., `scout`, `wave-agent`)
3. Optionally matches `when:` regex patterns against agent prompt
4. Outputs concatenated contents of matching reference files with injection markers
5. Prevents duplicate injection using marker deduplication

**Configuration (saw-skill.md frontmatter):**
```yaml
agent-references:
  - agent-type: scout
    inject: references/scout-suitability-gate.md
  - agent-type: scout
    inject: references/scout-implementation-process.md
  - agent-type: scout
    inject: references/scout-program-contracts.md
    when: "--program"
  - agent-type: wave-agent
    inject: references/wave-agent-worktree-isolation.md
  - agent-type: wave-agent
    inject: references/wave-agent-program-contracts.md
    when: "frozen_contracts_hash|frozen: true"
```

**Usage:**
```bash
# Basic usage
inject=$(bash scripts/inject-agent-context --type scout --prompt "$agent_prompt")
full_prompt="${inject}${agent_prompt}"

# With conditional matching
inject=$(bash scripts/inject-agent-context \
  --type wave-agent \
  --prompt "IMPL doc: docs/IMPL/IMPL-feature.yaml\nfrozen_contracts_hash: abc123")

# Model-initiated (in orchestrator prompt):
inject=$(bash ${CLAUDE_SKILL_DIR}/scripts/inject-agent-context \
  --type wave-agent \
  --prompt "$agent_prompt")
```

**Arguments:**
- `--type <agent-type>` (required) - Agent type to match (must match `agent-type:` value in frontmatter)
- `--prompt <text>` (optional) - Agent prompt text for conditional `when:` pattern matching

**Output format:**
```
<!-- injected: references/scout-suitability-gate.md -->
[contents of scout-suitability-gate.md]

<!-- injected: references/scout-implementation-process.md -->
[contents of scout-implementation-process.md]
```

**Exit codes:**
- `0` - Success (output may be empty if no matches)
- `1` - Error (--type missing or SKILL.md parse failure)

**Environment variables:**
- `CLAUDE_SKILL_DIR` - Overrides default skill directory resolution (defaults to parent of scripts/)

**Related documentation:**
- [subagent-prompt-injection.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/subagent-prompt-injection.md) - Original design proposal
- [validate_agent_launch hook](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/validate_agent_launch) - Hook implementation (lines 55-468)
- [skills-progressive-disclosure.md](/Users/dayna.blackwell/code/scout-and-wave/docs/skills-progressive-disclosure.md) - Architecture overview

---

## Architecture Overview

### Two-Layer Design

**Layer 1: Hook-based (Claude Code)**
- `inject_skill_context` hook: Fires on `UserPromptSubmit`, calls `scripts/inject-context` for all installed skills
- `validate_agent_launch` hook: Fires on `PreToolUse(Agent)`, calls inline injection logic (mirrors `inject-agent-context`)
- **Pros:** Automatic, zero model effort, consistent
- **Cons:** Claude Code only

**Layer 2: Script-based (vendor-neutral)**
- Model reads instruction in skill prompt: "On platforms without hooks, call `scripts/inject-agent-context`"
- Model makes Bash tool call before launching agent
- **Pros:** Works anywhere with Bash (raw API, Bedrock, CI/CD)
- **Cons:** Requires model discipline, costs tokens

### Why Both Layers?

Scout-and-Wave must work in environments without Claude Code (CI/CD, web apps, raw API). The scripts provide a portable fallback that implements the same logic as hooks. The skill prompt (saw-skill.md line 78) documents the fallback pattern:

> Agent references auto-injected by `validate_agent_launch` hook (see frontmatter). Vendor-neutral fallback: `scripts/inject-agent-context --type <agent-type>`.

### Deduplication Protocol

Both scripts and hooks use HTML comment markers to prevent duplicate injection:

```markdown
<!-- injected: references/scout-suitability-gate.md -->
```

Before injecting a reference file, the script checks if the marker already exists in the prompt. This prevents redundant injection when:
- Hook already injected but model calls script anyway
- Script called multiple times (error retry)
- Reference already manually included

## Dependencies

**Required:**
- Bash 4.0+ (for `set -euo pipefail`, `${BASH_REMATCH}`)
- Standard Unix tools: `cat`, `grep`, `awk`, `sed`

**Optional (graceful degradation):**
- None - scripts work with minimal tooling

**Skill directory structure:**
```
~/.claude/skills/saw/
├── saw-skill.md              # Frontmatter with triggers/agent-references
├── scripts/
│   ├── inject-context        # This script
│   └── inject-agent-context  # This script
└── references/               # Reference files
    ├── scout-suitability-gate.md
    ├── wave-agent-worktree-isolation.md
    └── ...
```

## Usage Patterns

### Pattern 1: Hook-based (automatic)

No model action required. Hooks call scripts automatically.

**Orchestrator perspective:**
```
User types: /saw program plan
→ inject_skill_context hook fires
→ Calls scripts/inject-context for all skills
→ Matches trigger "^/saw program"
→ Injects references/program-flow.md
→ Model receives expanded prompt
```

### Pattern 2: Manual invocation (vendor-neutral)

Model must call script before launching agent.

**Orchestrator prompt instructions (saw-skill.md line 78):**
```
Vendor-neutral fallback: `scripts/inject-agent-context --type <agent-type>`.
```

**Agent launch code:**
```bash
# Resolve skill directory
SKILL_DIR="${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/saw}"

# Inject references
inject=$(bash "$SKILL_DIR/scripts/inject-agent-context" \
  --type wave-agent \
  --prompt "$agent_prompt")

# Prepend to agent prompt
full_prompt="${inject}${agent_prompt}"

# Launch agent with expanded prompt
```

### Pattern 3: CI/CD integration

Scripts can be called from CI/CD pipelines without Claude Code.

**Example (GitHub Actions):**
```yaml
- name: Launch Scout agent
  run: |
    SKILL_DIR=/opt/saw-skill
    inject=$(bash $SKILL_DIR/scripts/inject-agent-context \
      --type scout \
      --prompt "$(cat agent-prompt.txt)")
    echo "$inject" > injected-context.txt
    cat injected-context.txt agent-prompt.txt | curl -X POST \
      -H "Content-Type: application/json" \
      -d @- https://api.anthropic.com/v1/messages
```

## Troubleshooting

### Script exits with code 1

**Cause:** `saw-skill.md` not found or parse error.

**Solution:**
- Verify `CLAUDE_SKILL_DIR` points to correct directory
- Check `saw-skill.md` exists and has valid YAML frontmatter
- Ensure frontmatter is wrapped in `---` delimiters

### Empty output (no injection)

**Cause:** No triggers or agent-references matched.

**Solution:**
- Check trigger patterns in frontmatter match user prompt regex
- Verify `--type` argument matches `agent-type:` values exactly
- Test conditional `when:` patterns match prompt content
- Confirm reference files exist at specified paths

### Duplicate injection

**Cause:** Marker deduplication not working.

**Solution:**
- Check HTML comment format: `<!-- injected: references/file.md -->`
- Ensure prompt passed to `--prompt` includes any prior injections
- Verify grep matches exact marker string (no extra spaces)

### Script not executable

**Cause:** Missing execute permissions.

**Solution:**
```bash
chmod +x scripts/inject-context scripts/inject-agent-context
```

## Protocol References

These scripts implement execution rules from the Scout-and-Wave protocol:

- **E42** (Progressive Disclosure): References loaded on-demand, not upfront
- **H5** (Agent Launch Validation): `validate_agent_launch` hook calls injection logic
- **M1-M4** (Determinism Tools): Reference injection ensures consistent agent behavior

See protocol documentation for execution rule details:
- [/Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md](/Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md)
- [/Users/dayna.blackwell/code/scout-and-wave/docs/skills-progressive-disclosure.md](/Users/dayna.blackwell/code/scout-and-wave/docs/skills-progressive-disclosure.md)

## Maintenance

### Adding new reference files

1. Create reference file in `references/` directory
2. Add entry to `saw-skill.md` frontmatter:
   ```yaml
   agent-references:
     - agent-type: wave-agent
       inject: references/new-reference.md
       when: "optional-pattern"  # Optional
   ```
3. No script changes needed - scripts read frontmatter dynamically

### Testing scripts

**Test inject-context:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts
echo "/saw program plan" | bash scripts/inject-context
# Should output: <!-- injected: references/program-flow.md --> + file contents
```

**Test inject-agent-context:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts
bash scripts/inject-agent-context \
  --type scout \
  --prompt "Analyze codebase for feature X"
# Should output: scout-suitability-gate.md + scout-implementation-process.md
```

**Test conditional injection:**
```bash
bash scripts/inject-agent-context \
  --type scout \
  --prompt "Analyze codebase --program"
# Should include scout-program-contracts.md
```

### Debugging frontmatter parsing

Scripts use `awk` to parse YAML frontmatter. To debug parsing:

```bash
# Extract triggers
awk '/^---$/ { if (++delim == 2) exit; next }
     delim == 1 && /^triggers:/ { in_triggers = 1; next }
     in_triggers && /^[^ ]/ { exit }
     in_triggers && /^  - match:/ {
       m = $0; sub(/.*match: *"?/, "", m); sub(/"? *$/, "", m)
       current_match = m; next
     }
     in_triggers && /^    inject:/ {
       i = $0; sub(/.*inject: *"?/, "", i); sub(/"? *$/, "", i)
       if (current_match != "" && i != "") print current_match "\t" i
       current_match = ""
     }' saw-skill.md

# Extract agent-references
awk '/^---$/ { if (++delim == 2) exit; next }
     delim == 1 && /^agent-references:/ { in_block = 1; next }
     in_block && /^[^ ]/ { exit }
     in_block && /^  - agent-type:/ {
       if (current_type != "" && current_file != "")
         print current_type "\t" current_file "\t" current_when
       t = $0; sub(/.*agent-type: *"?/, "", t); sub(/"? *$/, "", t)
       current_type = t; current_file = ""; current_when = ""; next
     }
     in_block && /^    inject:/ {
       f = $0; sub(/.*inject: *"?/, "", f); sub(/"? *$/, "", f)
       current_file = f; next
     }
     in_block && /^    when:/ {
       w = $0; sub(/.*when: *"?/, "", w); sub(/"? *$/, "", w)
       current_when = w; next
     }
     END {
       if (current_type != "" && current_file != "")
         print current_type "\t" current_file "\t" current_when
     }' saw-skill.md
```

## Cross-References

**Protocol documentation:**
- [execution-rules.md](/Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md) - E42 progressive disclosure
- [invariants.md](/Users/dayna.blackwell/code/scout-and-wave/protocol/invariants.md) - I6 role separation

**Design proposals:**
- [agentskills-subcommand-dispatch.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/agentskills-subcommand-dispatch.md) - Context injection design
- [subagent-prompt-injection.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/subagent-prompt-injection.md) - Agent reference injection design
- [skills-progressive-disclosure.md](/Users/dayna.blackwell/code/scout-and-wave/docs/skills-progressive-disclosure.md) - Two-layer architecture

**Hook implementations:**
- [inject_skill_context](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/inject_skill_context) - UserPromptSubmit hook
- [validate_agent_launch](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/validate_agent_launch) - PreToolUse(Agent) hook

**Skill configuration:**
- [saw-skill.md](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md) - Frontmatter with triggers and agent-references
