# Scripts Directory

This directory contains **vendor-neutral fallback scripts** for Scout-and-Wave's progressive disclosure system. These scripts enable reference injection on platforms that don't support Claude Code hooks (raw API, other LLMs, CI/CD environments).

## Purpose

Scout-and-Wave uses a two-layer progressive disclosure architecture:

1. **Hook layer** (Claude Code): `validate_agent_launch` and `inject_skill_context` hooks automatically inject reference files when launching agents or processing user prompts
2. **Script layer** (vendor-neutral): Bash scripts that can be called manually from agent prompts when hooks are unavailable

These scripts mirror the logic of Claude Code hooks but run as model-initiated bash commands. They use direct conditional logic to inject matching reference files based on prompt patterns or agent types.

## Scripts

### `inject-context`

**Purpose:** Context injection for user-invoked commands based on trigger patterns.

**When used:** Automatically called by the `inject_skill_context` hook when the user types a `/saw` command. Can be manually invoked on platforms without hooks.

**How it works:**
1. Receives user prompt as argument or stdin
2. Uses conditional logic (case/if statements) to match prompt patterns
3. Outputs concatenated contents of matching reference files with injection markers

**Conditional logic:**
```bash
# Direct conditional logic:
#   "^/saw program" in prompt -> inject references/program-flow.md
#   "^/saw amend" in prompt -> inject references/amend-flow.md
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
- `1` - Error (script directory resolution failure)

**Related documentation:**
- [agentskills-subcommand-dispatch.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/agentskills-subcommand-dispatch.md) - Original design proposal
- [inject_skill_context hook](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/inject_skill_context) - Hook orchestrator

---

### `inject-agent-context`

**Purpose:** Conditional reference injection for subagent launches based on agent type and prompt content.

**When used:** Called by the `validate_agent_launch` hook when spawning Scout or Wave agents that may need conditional references. Can be manually invoked on platforms without hooks.

**How it works:**
1. Receives agent type and prompt text as arguments
2. Uses conditional logic (case/if statements) to determine which references to inject
3. Only 3 conditional references remain -- most agent content is now inlined in agent definitions
4. Outputs concatenated contents of matching reference files with injection markers
5. Prevents duplicate injection using marker deduplication

**Conditional logic:**
```bash
# Direct conditional logic:
#   scout + "--program" in prompt -> inject references/scout-program-contracts.md
#   wave-agent + "baseline_verification_failed" in prompt -> inject references/wave-agent-build-diagnosis.md
#   wave-agent + "frozen_contracts" in prompt -> inject references/wave-agent-program-contracts.md
#   All other agent types -> no injection (empty output)
```

**Usage:**
```bash
# Basic usage (scout with --program flag)
inject=$(bash scripts/inject-agent-context --type scout --prompt "Analyze --program")
full_prompt="${inject}${agent_prompt}"

# Wave agent with frozen contracts
inject=$(bash scripts/inject-agent-context \
  --type wave-agent \
  --prompt "IMPL doc: docs/IMPL/IMPL-feature.yaml\nfrozen_contracts_hash: abc123")

# Model-initiated (in orchestrator prompt):
inject=$(bash ${CLAUDE_SKILL_DIR}/scripts/inject-agent-context \
  --type wave-agent \
  --prompt "$agent_prompt")
```

**Arguments:**
- `--type <agent-type>` (required) - Agent type (`scout`, `wave-agent`, etc.)
- `--prompt <text>` (optional) - Agent prompt text for conditional pattern matching

**Output format:**
```
<!-- injected: references/scout-program-contracts.md -->
[contents of scout-program-contracts.md]
```

**Exit codes:**
- `0` - Success (output may be empty if no conditions matched)
- `1` - Error (--type missing)

**Environment variables:**
- `CLAUDE_SKILL_DIR` - Overrides default skill directory resolution (defaults to parent of scripts/)

**Related documentation:**
- [subagent-prompt-injection.md](/Users/dayna.blackwell/code/scout-and-wave/docs/proposals/subagent-prompt-injection.md) - Original design proposal
- [validate_agent_launch hook](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/hooks/validate_agent_launch) - Hook implementation (lines 55-468)
- [skills-progressive-disclosure.md](/Users/dayna.blackwell/code/scout-and-wave/docs/skills-progressive-disclosure.md) - Architecture overview

---

## Architecture Overview

### Three-Layer Design

**Layer 1: Inlined in agent definitions (primary)**
- Most reference content is now inlined directly in agent type definitions (`agents/*.md`)
- Agent definitions are self-contained: no external injection needed for common cases
- **Pros:** Simpler, no hook dependency, no injection failures, faster agent startup
- **Cons:** Larger agent definition files

**Layer 2: Hook-based conditional injection (Claude Code)**
- `inject_skill_context` hook: Fires on `UserPromptSubmit`, calls `scripts/inject-context` for orchestrator references
- `validate_agent_launch` hook: Fires on `PreToolUse(Agent)`, calls `scripts/inject-agent-context` for 3 conditional agent references
- **Pros:** Automatic, zero model effort, only injects when conditions match
- **Cons:** Claude Code only

**Layer 3: Script-based (vendor-neutral)**
- Model reads instruction in skill prompt: "On platforms without hooks, call `scripts/inject-agent-context`"
- Model makes Bash tool call before launching agent
- **Pros:** Works anywhere with Bash (raw API, Bedrock, CI/CD)
- **Cons:** Requires model discipline, costs tokens

### Why This Design?

Most agent reference content was unconditionally injected at every launch. Inlining it in agent definitions eliminates the injection step entirely for the common case. Only 3 references remain conditional because their content is only relevant in specific scenarios (program contracts, build diagnosis). The hook and script layers handle these conditional cases.

### Deduplication Protocol

Both scripts and hooks use HTML comment markers to prevent duplicate injection:

```markdown
<!-- injected: references/scout-program-contracts.md -->
```

Before injecting a reference file, the script checks if the marker already exists in the prompt. This prevents redundant injection when:
- Hook already injected but model calls script anyway
- Script called multiple times (error retry)
- Reference already manually included

## Dependencies

**Required:**
- Bash 4.0+ (for `set -euo pipefail`, `${BASH_REMATCH}`)
- Standard Unix tools: `cat`, `grep`

**Optional (graceful degradation):**
- None - scripts work with minimal tooling

**Skill directory structure:**
```
~/.claude/skills/saw/
├── saw-skill.md              # Orchestrator skill definition
├── scripts/
│   ├── inject-context        # Orchestrator reference injection
│   └── inject-agent-context  # Conditional agent reference injection
└── references/               # On-demand reference files (11 total)
    ├── program-flow.md       # Orchestrator references (8)
    ├── scout-program-contracts.md    # Conditional agent references (3)
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
- Check that `CLAUDE_SKILL_DIR` resolves to a directory containing `references/`

### Empty output (no injection)

**Cause:** No conditional patterns matched.

**Solution:**
- Verify `--type` argument matches agent type values exactly (`scout`, `wave-agent`, etc.)
- Test conditional patterns match prompt content (e.g., `--program` for scout, `baseline_verification_failed` for wave-agent)
- Confirm reference files exist at specified paths in `references/` directory

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

**For always-needed content:** Inline directly in the agent definition (`agents/*.md`). This is the preferred approach -- it keeps agent definitions self-contained and eliminates injection complexity.

**For conditional content** (only needed in specific scenarios):
1. Create reference file in `references/` directory
2. Add a case branch in `scripts/inject-agent-context` for the new condition
3. Update `validate_agent_launch` hook if it has its own injection logic

### Testing scripts

**Test inject-context:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts
echo "/saw program plan" | bash scripts/inject-context
# Should output: <!-- injected: references/program-flow.md --> + file contents
```

**Test inject-agent-context (conditional injection):**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts

# Scout without --program: should produce empty output
bash scripts/inject-agent-context --type scout --prompt "Analyze codebase for feature X"

# Scout with --program: should inject scout-program-contracts.md
bash scripts/inject-agent-context --type scout --prompt "Analyze codebase --program"

# Wave agent with frozen contracts: should inject wave-agent-program-contracts.md
bash scripts/inject-agent-context --type wave-agent \
  --prompt "frozen_contracts_hash: abc123"

# Wave agent with build failure: should inject wave-agent-build-diagnosis.md
bash scripts/inject-agent-context --type wave-agent \
  --prompt "baseline_verification_failed: true"
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
- [saw-skill.md](/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md) - Orchestrator skill definition
