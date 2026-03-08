<!-- saw-teams-hooks v0.1.0 -->
# SAW-Teams Protocol Enforcement Hooks

Claude Code hooks for enforcing SAW protocol compliance during Agent Teams
wave execution. Two hooks matter for SAW: `TeammateIdle` and `TaskCompleted`.

These are optional but strongly recommended. Without them, the lead only
discovers protocol violations when reading completion reports after all
teammates finish. With them, violations surface at the moment they occur.

## Hook Overview

| Hook | Fires when | SAW use | Exit code 2 effect |
|---|---|---|---|
| `TeammateIdle` | teammate about to go idle | enforce completion report written | keep teammate working |
| `TaskCompleted` | task being marked complete | verify IMPL doc report exists | block task completion |

Both hooks are configured in `.claude/settings.json`.

> **Experimental note:** `TeammateIdle` and `TaskCompleted` are part of the
> experimental Agent Teams feature. Exact environment variable names and hook
> context may change as the feature stabilizes. Verify against current Claude
> Code docs before deploying.

---

## `TeammateIdle`: Enforce Completion Report Before Idle

### What it does

Runs when a teammate is about to stop working (go idle). If the hook exits
with code 2, the teammate receives the hook's stdout as feedback and keeps
working. If the hook exits 0, the teammate shuts down normally.

### SAW use case

Teammates that finish implementation sometimes idle without writing their
completion report (IMPL doc append + task marked complete + message to lead).
Without this hook, the lead only discovers the missing report when it reads
the IMPL doc after all teammates finish — too late to redirect in real time.

With this hook, the teammate is sent back to complete the report the moment
it tries to idle. The lead learns about it immediately via the idle
notification being suppressed.

### Example hook script

```bash
#!/bin/bash
# .claude/hooks/teammate-idle-saw.sh
#
# SAW TeammateIdle enforcement hook.
# Exit 0: allow idle (teammate is done, report exists)
# Exit 2: block idle, send feedback (report is missing)
#
# This hook checks whether the going-idle teammate has written a structured
# completion report to the IMPL doc. If not, it sends the teammate back.

set -euo pipefail

# Find the active IMPL doc (most recently modified).
IMPL_DOC=$(find docs/IMPL -name "IMPL-*.md" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
if [ -z "$IMPL_DOC" ]; then
  # No IMPL doc found — not a SAW session or doc is missing.
  # Allow idle; don't block non-SAW teammates.
  exit 0
fi

# Check whether ANY completion report section exists.
# In a multi-agent wave the teammate's specific letter is not reliably
# available here, so we check for the presence of any report as a proxy.
# A stricter check would parse the teammate name from the hook context.
if grep -q "^### Agent .* - Completion Report" "$IMPL_DOC" 2>/dev/null; then
  # At least one report exists. Check if verification passed.
  if grep -q "^verification: PASS" "$IMPL_DOC" 2>/dev/null; then
    exit 0  # report present and verification passed — allow idle
  fi
fi

# No completion report or verification not passed. Send teammate back.
echo "Your work is not complete. Before going idle you must:"
echo ""
echo "1. Run your verification gate (build + lint + tests). All must pass."
echo "2. Commit your changes to your worktree branch."
echo "3. Append your structured completion report to the IMPL doc under"
echo "   '### Agent {letter} - Completion Report' (see Field 8 of your prompt)."
echo "4. Mark your task as completed in the shared task list."
echo "5. Message the lead with your completion summary."
echo ""
echo "Do not idle until all five steps are complete."
exit 2
```

### Configuration

Add to `.claude/settings.json` in the project:

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/teammate-idle-saw.sh"
          }
        ]
      }
    ]
  }
}
```

---

## `TaskCompleted`: Verify IMPL Doc Report Before Task Closes

### What it does

Runs when a task is being marked as completed in the shared task list. If
the hook exits with code 2, task completion is blocked and the teammate
receives the hook's stdout as feedback.

### SAW use case

The shared task list is ephemeral — it is lost when the team is cleaned up.
The IMPL doc is the permanent record (I4). If a teammate marks its task
complete without writing to the IMPL doc, the task closure provides false
confidence and the report is never written (the teammate has already idled).

This hook enforces the dual-write contract: both the IMPL doc write AND the
task status update must happen; the hook ensures the doc write came first.

### Example hook script

```bash
#!/bin/bash
# .claude/hooks/task-completed-saw.sh
#
# SAW TaskCompleted enforcement hook.
# Exit 0: allow task completion (IMPL doc report exists)
# Exit 2: block task completion, send feedback (report missing)

set -euo pipefail

IMPL_DOC=$(find docs/IMPL -name "IMPL-*.md" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
if [ -z "$IMPL_DOC" ]; then
  exit 0  # not a SAW session — allow
fi

# Block task completion if no structured completion report exists.
if ! grep -q "^### Agent .* - Completion Report" "$IMPL_DOC" 2>/dev/null; then
  echo "Cannot mark task complete: no completion report found in the IMPL doc."
  echo ""
  echo "Append your structured completion report to $IMPL_DOC under"
  echo "'### Agent {letter} - Completion Report' BEFORE marking this task done."
  echo ""
  echo "The task list is ephemeral. The IMPL doc is the permanent record (I4)."
  echo "The doc write must happen first."
  exit 2
fi

exit 0
```

### Configuration

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/task-completed-saw.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Combined Configuration

To enable both hooks, add to `.claude/settings.json`:

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/teammate-idle-saw.sh"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/task-completed-saw.sh"
          }
        ]
      }
    ]
  }
}
```

Store the scripts at `.claude/hooks/teammate-idle-saw.sh` and
`.claude/hooks/task-completed-saw.sh`. Make them executable:

```bash
chmod +x .claude/hooks/teammate-idle-saw.sh
chmod +x .claude/hooks/task-completed-saw.sh
```

---

## Relationship to Standard SAW

Standard SAW (`prompts/saw-skill.md`) has no equivalent hooks; the `Agent`
tool does not fire `TeammateIdle` or `TaskCompleted` events. Those background
agents complete (or fail silently), and the Orchestrator reads reports after
all agents finish.

Agent Teams hooks close the real-time gap: the lead can intervene the moment
a teammate tries to idle without a report. This is Layer 2.5 of the
defense-in-depth model (see `saw-teams-worktree.md`), and it is the primary
protocol-enforcement advantage of the saw-teams execution layer over standard
SAW.

## Protocol Compliance Without Hooks

Hooks are optional. If not configured, the protocol still works: the lead
reads completion reports from the IMPL doc, cross-references with messages,
and blocks the merge if any report is missing or incomplete (I4, E7). The
difference is timing:

| Approach | When violation surfaces |
|---|---|
| No hooks | After all teammates finish (lead reads IMPL doc) |
| `TeammateIdle` hook | The moment a teammate tries to idle |
| `TaskCompleted` hook | The moment a teammate tries to close its task |

For production SAW-Teams usage, configure both hooks.
