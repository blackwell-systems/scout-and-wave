#!/bin/sh
# SAW worktree isolation guard (Layer 0).
# Installed ephmerally during worktree setup, removed during cleanup.
# Blocks agent commits to main while SAW worktrees are active.
# Orchestrator bypasses via SAW_ALLOW_MAIN_COMMIT=1.

branch=$(git symbolic-ref --short HEAD 2>/dev/null)

if [ "$branch" = "main" ] && [ -z "$SAW_ALLOW_MAIN_COMMIT" ]; then
  if ls .claude/worktrees/wave*-agent-* 1>/dev/null 2>&1; then
    echo ""
    echo "BLOCKED: commit to main during active SAW wave."
    echo ""
    echo "You are an agent in a SAW wave. Commits to main are not"
    echo "permitted during wave execution. Your assigned worktree:"
    echo ""
    for wt in .claude/worktrees/wave*-agent-*; do
      echo "  $wt (branch: $(basename $wt))"
    done
    echo ""
    echo "cd to your assigned worktree and commit there."
    exit 1
  fi
fi
