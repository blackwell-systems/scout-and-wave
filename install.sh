#!/usr/bin/env bash
# install.sh — Installs Scout-and-Wave skill files for Claude Code.
#
# Usage:
#   ./install.sh          # from the repo root
#   /path/to/install.sh   # from anywhere
#
# Creates ~/.claude/skills/saw/ and symlinks the required prompt files.
# Safe to run multiple times (idempotent).

set -euo pipefail

# Resolve the repo root (directory containing this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/implementations/claude-code/prompts"
SKILL_DIR="${HOME}/.claude/skills/saw"

if [ ! -d "${PROMPTS_DIR}" ]; then
  echo "ERROR: Prompts directory not found at ${PROMPTS_DIR}" >&2
  echo "       Is this script in the scout-and-wave repo root?" >&2
  exit 1
fi

# Files to symlink: source (relative to PROMPTS_DIR) -> target name in SKILL_DIR
declare -a FILES=(
  "saw-skill.md:SKILL.md"
  "saw-bootstrap.md:saw-bootstrap.md"
  "saw-merge.md:saw-merge.md"
  "saw-worktree.md:saw-worktree.md"
  "agent-template.md:agent-template.md"
  "scout.md:scout.md"
  "scaffold-agent.md:scaffold-agent.md"
)

echo "Installing Scout-and-Wave skill files..."
echo ""

# Create skill directory
mkdir -p "${SKILL_DIR}"
echo "  Created ${SKILL_DIR}"

# Create symlinks
for entry in "${FILES[@]}"; do
  src="${PROMPTS_DIR}/${entry%%:*}"
  dst="${SKILL_DIR}/${entry##*:}"

  if [ ! -f "${src}" ]; then
    echo "  WARNING: Source file not found: ${src}" >&2
    continue
  fi

  ln -sf "${src}" "${dst}"
  echo "  Linked ${dst} -> ${src}"
done

echo ""
echo "Done. Restart Claude Code to pick up the new skill."
echo ""
echo "Next steps:"
echo "  1. Add \"Agent\" to your allow list in ~/.claude/settings.json"
echo "  2. Run: /saw scout \"your feature description\""
