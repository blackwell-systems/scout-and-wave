# SAW-Teams

Alternate execution layer for the Scout-and-Wave (SAW) protocol using Claude
Code Agent Teams. Same invariants, same IMPL doc, same Scout. Different wave
plumbing: teammates replace background Agent tool calls, and you get
inter-agent messaging, a shared task list, and real-time protocol enforcement
via hooks.

## When to use this vs standard `/saw`

| | `/saw` (standard) | `/saw-teams` |
|---|---|---|
| **Stability** | Stable | Experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` required) |
| **Crash recovery** | Good (session resumable, agents survive) | Poor (teammates lost on crash) |
| **Deviation alerts** | At merge time (post-hoc) | Real time (teammate messages lead) |
| **Progress visibility** | None until completion | Live, per-teammate |
| **Token cost** | Lower | Higher (each teammate = full context window) |

**Default recommendation:** use `/saw`. Use `/saw-teams` when the wave has
complex interfaces and real-time deviation handling is worth the experimental
risk.

Both use the same IMPL doc. Switching between them mid-feature is safe.

## Setup

**Quick start:** copy `example-settings.json` from this directory into your
project's `.claude/settings.json`, then follow steps 3 and 4 below.

### 1. Enable Agent Teams

Set in your project's `.claude/settings.json` or `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Choose a display mode

| Mode | How | Best for |
|---|---|---|
| `in-process` (default) | All teammates in main terminal; Shift+Down cycles | Any terminal |
| `split-pane` | Each teammate in its own pane | tmux or iTerm2; SAW wave work |

For SAW, split-pane mode is recommended so you can watch all agents
simultaneously. Set in settings:

```json
{
  "teammateMode": "tmux"
}
```

Or force for a single session:

```bash
claude --teammate-mode tmux
```

### 3. Configure protocol enforcement hooks (recommended)

Copy the hook scripts to your project:

```bash
mkdir -p .claude/hooks

# Or symlink from the saw-teams directory if you keep SAW as a submodule
cp /path/to/scout-and-wave/saw-teams/hooks/teammate-idle-saw.sh .claude/hooks/
cp /path/to/scout-and-wave/saw-teams/hooks/task-completed-saw.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "TeammateIdle": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/teammate-idle-saw.sh"}]}
    ],
    "TaskCompleted": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/task-completed-saw.sh"}]}
    ]
  }
}
```

See `hooks.md` for full hook documentation and scripts.

### 4. Add `"Agent"` to your allow list

The lead spawns teammates via the Agent Teams API. Without this, teammate
spawning prompts for approval on every wave:

```json
{
  "permissions": {
    "allow": ["Agent"]
  }
}
```

### `example-settings.json` field reference

`saw-teams/example-settings.json` contains all required settings in one block.
Copy it to `.claude/settings.json` in your project and adjust as needed.

| Field | Value | Why |
|---|---|---|
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Enables Agent Teams; required |
| `teammateMode` | `"tmux"` | Split-pane display; recommended for SAW |
| `permissions.allow` — `"Agent"` | required | Lead spawns teammates without prompts |
| `permissions.allow` — `"Bash"` | required | Teammates run build/test/git |
| `permissions.allow` — `"Read"`, `"Write"`, `"Edit"` | required | Teammates read and write source files |
| `permissions.allow` — `"Glob"`, `"Grep"` | recommended | Teammates search codebase |
| `hooks.TeammateIdle` | see hooks.md | Enforce completion report before idle |
| `hooks.TaskCompleted` | see hooks.md | Enforce IMPL doc write before task close |

**Note:** `"Agent"` in the allow list is the critical entry. Without it every
teammate spawn blocks on an approval prompt, serializing what should be
parallel launches. Teammates inherit the lead's full permission set; the allow
list applies to all teammates automatically.

## Usage

Same commands as `/saw`, but invoke `/saw-teams`:

```
/saw-teams scout <feature-description>   — run Scout, produce IMPL doc
/saw-teams wave                          — execute next pending wave, pause after
/saw-teams wave --auto                   — execute all waves, pause only on failure
/saw-teams status                        — show progress from IMPL doc
/saw-teams bootstrap <project>           — design-first for new projects
```

The Scout is NOT a teammate. It runs as a background Agent tool call before
any team exists. The IMPL doc it produces is consumed by every wave team.

## Files in this directory

| File | Purpose |
|---|---|
| `saw-teams-skill.md` | Orchestrator/lead skill prompt (replaces `prompts/saw-skill.md`) |
| `teammate-template.md` | 9-field teammate prompt template (replaces `prompts/agent-template.md`) |
| `saw-teams-merge.md` | Merge procedure with teammate messaging supplement |
| `saw-teams-worktree.md` | Worktree lifecycle for Agent Teams execution |
| `hooks.md` | `TeammateIdle` and `TaskCompleted` hook documentation and scripts |
| `DESIGN.md` | Architecture, design decisions, limitations, migration path |

## Key differences from standard SAW

**What Agent Teams adds:**
- Teammates message lead in real time when they find interface deviations
- Lead can see all teammates' progress live, not just at completion
- `TeammateIdle` and `TaskCompleted` hooks enforce protocol compliance as it happens
- Shared task list provides structured work assignment (SAW uses it read-only: tasks are pre-assigned, not self-claimed)

**What SAW adds to Agent Teams:**
- Suitability gate (Scout asks: is this work parallelizable? do interfaces exist? are files decomposable?)
- Scout defines interface contracts in the IMPL doc; Scaffold Agent materializes them as scaffold files committed to HEAD after human review, before any Wave Agent launches (I2)
- Disjoint file ownership enforced before worktrees created (I1)
- Wave structure derived from the dependency DAG (waves run sequentially; within a wave, agents are independent)
- Git worktree isolation per agent (Agent Teams has no worktree primitive)
- Structured YAML completion reports enabling automated conflict prediction
- Post-merge verification gate running the full test suite unscoped (`test_command` from IMPL doc)
- Persistent IMPL doc state that survives team teardown and crash

## Limitations

Agent Teams is experimental. Known limitations affecting SAW:

1. **No session resumption**: if the lead crashes mid-wave, teammates are lost. Use standard `/saw` when crash recovery is critical.
2. **One team per session**: multi-wave runs create and destroy a team per wave. Expected overhead.
3. **Task status can lag**: teammates sometimes fail to mark tasks complete. Use IMPL doc reports (I4) as the authoritative signal, not task status.
4. **Slow shutdown**: teammates finish their current tool call before stopping. Expect brief delays at wave cleanup.

See `DESIGN.md` for full limitations and migration path.
