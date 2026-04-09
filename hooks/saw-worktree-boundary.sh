#!/usr/bin/env bash
# PreToolUse hook: Enforces worktree write boundaries for SAW wave agents.
# Uses SAW_WORKTREE_ROOT (injected by prepare-wave) to hard-deny any
# Write/Edit/MultiEdit call whose target path resolves to the main repo
# instead of the agent's assigned worktree.
#
# Exit codes:
#   0 — allow (pass-through)
#   2 — hard block (Claude Code will not execute the tool call)
#
# Environment:
#   SAW_WORKTREE_ROOT — absolute path to the agent's worktree (set by prepare-wave)
#                       When not set, this hook is a no-op (exit 0).

set -euo pipefail

# No-op when not in a worktree agent context
if [[ -z "${SAW_WORKTREE_ROOT:-}" ]]; then
  exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Only enforce on Write, Edit, MultiEdit tool calls
tool_name=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || true)
if [[ "$tool_name" != "Write" && "$tool_name" != "Edit" && "$tool_name" != "MultiEdit" ]]; then
  exit 0
fi

# Extract file_path from tool input
file_path=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Resolve relative paths against cwd
if [[ "$file_path" != /* ]]; then
  file_path="$(pwd)/$file_path"
fi

# Normalize (remove trailing slashes, resolve . and ..)
# Use Python since realpath may not handle non-existent paths on macOS
file_path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$file_path" 2>/dev/null || printf '%s' "$file_path")
worktree_root=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$SAW_WORKTREE_ROOT" 2>/dev/null || printf '%s' "$SAW_WORKTREE_ROOT")

# Determine main repo root: walk up from worktree_root to find the repo that
# contains the .claude/worktrees/ directory (the main repo is 3 levels above
# the worktree: main_repo/.claude/worktrees/saw/<slug>/wave<N>-agent-<ID>)
# Pattern: worktree is at <main_repo>/.claude/worktrees/saw/*/wave*-agent-*
main_repo=""
if [[ "$worktree_root" =~ ^(.*)/\.claude/worktrees/ ]]; then
  main_repo="${BASH_REMATCH[1]}"
fi

# If target path is under the worktree, allow it
if [[ "$file_path" == "$worktree_root"/* || "$file_path" == "$worktree_root" ]]; then
  exit 0
fi

# If target path is under the main repo and we identified one, block it
if [[ -n "$main_repo" && ( "$file_path" == "$main_repo"/* || "$file_path" == "$main_repo" ) ]]; then
  echo "[SAW] Write blocked: $file_path is in main repo, not agent worktree." >&2
  echo "[SAW] Use: $SAW_WORKTREE_ROOT/$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$file_path" "$main_repo" 2>/dev/null || printf '%s' "$file_path")" >&2
  exit 2
fi

# Path is outside both main repo and worktree — allow (not our concern)
exit 0
