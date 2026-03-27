# Agent Model Selection

**Purpose:** This reference documents the 3-level model override hierarchy and config file lookup logic for Scout-and-Wave agent launches.

## Override Hierarchy (Highest Precedence First)

### 1. Skill Argument Override

Parse `--model <value>` from the skill invocation before the subcommand payload:
- `/saw scout --model sonnet "add caching layer"`
- `/saw wave --model haiku --impl tool-journaling`

If present, this model takes precedence over config and parent model.

### 2. Config File Override

Use a two-level config file lookup (first match wins):

1. **Project-local:** `<project-root>/saw.config.json`
2. **Global default:** `~/.claude/saw.config.json`

The config uses per-role model fields under the `agent` key:

```json
{
  "agent": {
    "scout_model": "claude-sonnet-4-20250514",
    "wave_model": "claude-haiku-4-20250508",
    "chat_model": "claude-opus-4-20250514",
    "integration_model": "claude-sonnet-4-20250514",
    "scaffold_model": "claude-sonnet-4-20250514",
    "planner_model": "claude-opus-4-20250514",
    "critic_model": "claude-sonnet-4-20250514"
  }
}
```

**Role-to-field mapping:**
- `/saw scout` → `agent.scout_model`
- `/saw wave` → `agent.wave_model`
- `/saw program execute` → `agent.planner_model`
- Scaffold agents → `agent.scaffold_model`
- Critic agents → `agent.critic_model`
- Integration agents → `agent.integration_model`

**Empty field behavior:** Empty string or missing field means "fall through to level 3."

**No config found:** If neither file exists, fall through to level 3.

### 3. Parent Model Inheritance

If no override is specified at levels 1 or 2, agents inherit the parent orchestrator session's model.

Implementation: Custom `subagent_type` values (`scout`, `wave-agent`, etc.) inherit automatically. No `model:` field in frontmatter = inherit parent model.

## Agent Tool Limitation & Indirect Override

**Problem:** The Agent tool does not expose a `model` parameter.

**Solution:** Custom `subagent_type` definitions inherit the parent session's model. When an explicit override is requested (via `--model` argument) and the custom subagent_type would inherit a different model:

1. Apply the Fallback Rule (see saw-skill.md lines 84-85)
2. Use `subagent_type: general-purpose` with the full agent prompt from `${CLAUDE_SKILL_DIR}/agents/<type>.md`
3. Pass the same context payload (IMPL doc path, feature description, repo root, etc.)

**Example:** Parent session is Opus, user requests `/saw wave --model sonnet`:
- Custom `wave-agent` type would inherit Opus
- Override detected → use `subagent_type: general-purpose` + `agents/wave-agent.md` prompt
- Result: Agent runs with parent model (which should be changed to Sonnet via session-level override if possible)

## Rate-Limit Fallback

If an agent returns immediately with:
- 0 tool uses
- Rate-limit error message

**Recovery:**
1. Retry once using `subagent_type: general-purpose` with the full agent prompt
2. Log to user: "Agent hit rate limit on [model], retrying with parent model."

This allows graceful degradation when custom agent types encounter quota limits.
