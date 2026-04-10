#!/usr/bin/env bash
# SubagentStop hook: Enforces IMPL doc commit for SAW critic agents (E48).
# Critic agents must commit the critic_report changes to git before stopping.
# Non-critic agents pass through immediately (exit 0).
#
# Exit codes:
#   0 — allow (pass-through or critic committed clean)
#   2 — hard block (critic has uncommitted IMPL doc changes)
#
# Environment: reads JSON from stdin (SubagentStop payload)

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract agent_description from the SubagentStop payload
agent_description=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_description',''))" 2>/dev/null || true)

# Non-critic agents pass through immediately
if [[ "$agent_description" != \[SAW:critic:* ]]; then
  exit 0
fi

# --- Critic agent: enforce E48 ---

# Step 1: Find the IMPL doc path
impl_path=""

# Try .saw-state/active-impl starting from cwd, walk up to repo root
search_dir="$(pwd)"
while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
  candidate="$search_dir/.saw-state/active-impl"
  if [[ -f "$candidate" ]]; then
    impl_path=$(cat "$candidate")
    break
  fi
  search_dir="$(dirname "$search_dir")"
done

# Try extracting from agent_description if not found yet
if [[ -z "$impl_path" ]]; then
  impl_path=$(printf '%s' "$agent_description" | grep -oE 'docs/IMPL/IMPL-[^]" ]+\.yaml' | head -1 || true)
  # If we got a relative path, try to resolve it from cwd or repo root
  if [[ -n "$impl_path" && "$impl_path" != /* ]]; then
    # Try cwd first
    if [[ -f "$(pwd)/$impl_path" ]]; then
      impl_path="$(pwd)/$impl_path"
    else
      # Walk up looking for the file
      search_dir="$(pwd)"
      while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/$impl_path" ]]; then
          impl_path="$search_dir/$impl_path"
          break
        fi
        search_dir="$(dirname "$search_dir")"
      done
    fi
  fi
fi

# If still not found, hard block
if [[ -z "$impl_path" || ! -f "$impl_path" ]]; then
  echo "E48: Cannot locate IMPL doc for critic agent." >&2
  echo "     agent_description: $agent_description" >&2
  exit 2
fi

# Step 2: Derive repo root from IMPL doc path
impl_dir="$(dirname "$impl_path")"
repo_root=$(git -C "$impl_dir" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$repo_root" ]]; then
  echo "E48: Cannot determine repo root from IMPL doc path: $impl_path" >&2
  exit 2
fi

# Step 3: Check if IMPL doc is dirty (unstaged or staged-but-not-committed)
unstaged=$(git -C "$repo_root" status --porcelain "$impl_path" 2>/dev/null || true)
staged=$(git -C "$repo_root" diff --cached --name-only 2>/dev/null | grep -F "$(basename "$impl_path")" || true)

if [[ -n "$unstaged" || -n "$staged" ]]; then
  slug=$(basename "$impl_path" .yaml | sed 's/^IMPL-//')
  echo "E48: Critic agent must commit IMPL doc changes before stopping." >&2
  echo "     Run: git -C $repo_root add $impl_path && git -C $repo_root commit -m \"chore: critic report for $slug [SAW:critic:$slug]\"" >&2
  exit 2
fi

# IMPL doc is clean — allow
exit 0
