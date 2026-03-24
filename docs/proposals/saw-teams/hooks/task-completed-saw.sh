#!/bin/bash
# task-completed-saw.sh
# SAW TaskCompleted enforcement hook.
#
# Fires when a task is being marked complete in the shared task list.
# Checks whether the teammate has written a structured completion report
# to the IMPL doc. If not, exits 2 to block task completion.
#
# Install:
#   cp task-completed-saw.sh /path/to/project/.claude/hooks/
#   chmod +x /path/to/project/.claude/hooks/task-completed-saw.sh
#
# Configure in .claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [
#       {"hooks": [{"type": "command",
#                   "command": "bash .claude/hooks/task-completed-saw.sh"}]}
#     ]
#   }
#
# Exit codes:
#   0  — allow task completion
#   2  — block task completion; stdout sent to teammate as feedback

set -euo pipefail

# Find the active IMPL doc.
IMPL_DOC=$(find docs/IMPL -name "IMPL-*.md" 2>/dev/null \
  | xargs ls -t 2>/dev/null \
  | head -1)

if [ -z "$IMPL_DOC" ]; then
  # Not a SAW session. Allow.
  exit 0
fi

# Block task completion if no structured completion report exists.
# The IMPL doc write must happen before the task list update (I4).
if ! grep -q "^### Agent .* - Completion Report" "$IMPL_DOC" 2>/dev/null; then
  cat <<EOF
Cannot mark task complete: no completion report found in the IMPL doc.

The task list is ephemeral — it is lost when the team is cleaned up.
The IMPL doc is the permanent record (I4). The doc write must come first.

Before marking this task done:
  1. Append your completion report to $IMPL_DOC under
     "### Agent {letter} - Completion Report"
  2. Include the structured YAML block (status, worktree, commit,
     files_changed, files_created, interface_deviations, out_of_scope_deps,
     tests_added, verification)
  3. Then mark the task complete

EOF
  exit 2
fi

# Report exists. Also check that a status line is present.
if ! grep -q "^status: complete\|^status: partial\|^status: blocked" "$IMPL_DOC" 2>/dev/null; then
  echo "Completion report found but missing 'status:' line."
  echo "Add 'status: complete', 'status: partial', or 'status: blocked' to your report."
  exit 2
fi

exit 0
