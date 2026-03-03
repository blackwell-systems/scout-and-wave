#!/bin/bash
# teammate-idle-saw.sh
# SAW TeammateIdle enforcement hook.
#
# Fires when a teammate is about to go idle. Checks whether the teammate
# has written a structured completion report to the IMPL doc. If not,
# exits 2 to send feedback and keep the teammate working.
#
# Install:
#   cp teammate-idle-saw.sh /path/to/project/.claude/hooks/
#   chmod +x /path/to/project/.claude/hooks/teammate-idle-saw.sh
#
# Configure in .claude/settings.json:
#   "hooks": {
#     "TeammateIdle": [
#       {"hooks": [{"type": "command",
#                   "command": "bash .claude/hooks/teammate-idle-saw.sh"}]}
#     ]
#   }
#
# Exit codes:
#   0  — allow idle (report present or not a SAW session)
#   2  — block idle; stdout sent to teammate as feedback

set -euo pipefail

# Find the active IMPL doc (most recently modified docs/IMPL-*.md).
IMPL_DOC=$(find docs -maxdepth 1 -name "IMPL-*.md" 2>/dev/null \
  | xargs ls -t 2>/dev/null \
  | head -1)

if [ -z "$IMPL_DOC" ]; then
  # No IMPL doc — not a SAW session. Allow idle.
  exit 0
fi

# Check whether a structured completion report section exists.
# Format: "### Agent {letter} - Completion Report"
if grep -q "^### Agent .* - Completion Report" "$IMPL_DOC" 2>/dev/null; then
  # Report section exists. Check for status line.
  if grep -q "^status: complete\|^status: partial\|^status: blocked" "$IMPL_DOC" 2>/dev/null; then
    # A status has been declared. Allow idle regardless of pass/fail —
    # a blocked/partial report is still a valid report.
    exit 0
  fi
fi

# No completion report or no status line found. Block idle and redirect.
cat <<'EOF'
Your SAW task is not complete. Before going idle you must complete all of
these steps in order:

  1. Run your verification gate (build + lint + tests). All must pass.
     If verification fails, fix the failures first.

  2. Commit your changes to your worktree branch:
       git add .
       git commit -m "wave{N}-agent-{letter}: {short description}"

  3. Append your structured completion report to the IMPL doc under
     "### Agent {letter} - Completion Report" (see Field 8 of your prompt).
     The report must include a "status:" line.

  4. Mark your task as completed in the shared task list.

  5. Message the lead:
     "Agent {letter} complete. Status: {status}. Verification: {PASS|FAIL}.
      Interface deviations: {count}. Out-of-scope deps: {count}."

Do not idle until all five steps are complete.
EOF
exit 2
