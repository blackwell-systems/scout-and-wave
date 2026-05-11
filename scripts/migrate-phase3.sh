#!/usr/bin/env bash
# migrate-phase3.sh — Mechanical changes for polywave (was polywave, protocol repo)
# Documentation-only repo — no Go build. Safe to run in parallel with Phase 2 after Phase 1 lands.
# Idempotent: safe to re-run.
#
# Usage: ./scripts/migrate-phase3.sh [/path/to/protocol-repo]
# Or from within repo: ./scripts/migrate-phase3.sh

set -euo pipefail

REPO="${1:-.}"
REPO="$(cd "$REPO" && pwd)"

echo "==> Phase 3: polywave (protocol repo) migration"
echo "    Repo: $REPO"
echo ""

# Verify we're in the right repo
if [ ! -f "$REPO/polywave.config.json" ] && [ ! -f "$REPO/polywave.config.json" ]; then
  echo "ERROR: $REPO does not look like the protocol repo (no polywave.config.json)"
  exit 1
fi

cd "$REPO"

# ── Branch setup ──────────────────────────────────────────────────────────────
BRANCH="rename/polywave"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" = "$BRANCH" ]; then
  echo "    Already on branch $BRANCH"
elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "ERROR: Branch $BRANCH already exists. Switch to it manually or delete it."
  echo "    git checkout $BRANCH"
  exit 1
else
  git checkout -b "$BRANCH"
  echo "    Created and switched to branch $BRANCH"
fi
echo ""

# ── Step 1: Rename hook files and skill files ─────────────────────────────────
echo "==> Step 1: Renaming hook and skill source files"
# Main hooks
for pair in \
  "hooks/saw-critic-impl-commit.sh:hooks/polywave-critic-impl-commit.sh" \
  "hooks/saw-worktree-boundary.sh:hooks/polywave-worktree-boundary.sh"
do
  old="${pair%%:*}"
  new="${pair##*:}"
  if [ -f "$old" ] && [ ! -f "$new" ]; then
    git mv "$old" "$new"
    echo "    Renamed $old → $new"
  elif [ -f "$new" ]; then
    echo "    Already renamed: $new"
  fi
done

# Skill source files (referenced by install.sh SKILL_FILES array)
for pair in \
  "implementations/claude-code/prompts/saw-skill.md:implementations/claude-code/prompts/polywave-skill.md" \
  "implementations/claude-code/prompts/saw-bootstrap.md:implementations/claude-code/prompts/polywave-bootstrap.md"
do
  old="${pair%%:*}"
  new="${pair##*:}"
  if [ -f "$old" ] && [ ! -f "$new" ]; then
    git mv "$old" "$new"
    echo "    Renamed $old → $new"
  elif [ -f "$new" ]; then
    echo "    Already renamed: $new"
  fi
done

# Hook identifier scripts in implementations/claude-code/hooks/ (symlink targets)
IMPL_HOOKS_DIR="implementations/claude-code/hooks"
if [ -d "$IMPL_HOOKS_DIR" ]; then
  for pair in \
    "auto_format_saw_agent_names:auto_format_polywave_agent_names" \
    "saw_orchestrator_stop:polywave_orchestrator_stop" \
    "saw_critic_impl_commit:polywave_critic_impl_commit" \
    "saw_agent_name:polywave_agent_name"
  do
    old="${pair%%:*}"
    new="${pair##*:}"
    if [ -f "$IMPL_HOOKS_DIR/$old" ] && [ ! -f "$IMPL_HOOKS_DIR/$new" ]; then
      git mv "$IMPL_HOOKS_DIR/$old" "$IMPL_HOOKS_DIR/$new"
      echo "    Renamed $IMPL_HOOKS_DIR/$old → $new"
    fi
  done
fi

# Proposals hook files (self-referential filenames)
for pair in \
  "docs/proposals/saw-teams/hooks/task-completed-saw.sh:docs/proposals/saw-teams/hooks/task-completed-polywave.sh" \
  "docs/proposals/saw-teams/hooks/teammate-idle-saw.sh:docs/proposals/saw-teams/hooks/teammate-idle-polywave.sh"
do
  old="${pair%%:*}"
  new="${pair##*:}"
  if [ -f "$old" ] && [ ! -f "$new" ]; then
    git mv "$old" "$new"
    echo "    Renamed $old → $new"
  fi
done

# ── Step 2: Update hook content ───────────────────────────────────────────────
echo ""
echo "==> Step 2: Updating hook content"
if [ -f "hooks/polywave-critic-impl-commit.sh" ]; then
  sed -i '' \
    -e 's|\[SAW:critic:\*|\[polywave:critic:*|g' \
    -e 's|\[SAW:critic:\([^]]*\)\]|[polywave:critic:\1]|g' \
    -e 's|\[SAW\]|[Polywave]|g' \
    -e 's|\bSAW\b critic|Polywave critic|g' \
    -e 's|\.polywave-state|.polywave-state|g' \
    -e 's|worktrees/saw/|worktrees/polywave/|g' \
    hooks/polywave-critic-impl-commit.sh
  echo "    Updated polywave-critic-impl-commit.sh"
fi

if [ -f "hooks/polywave-worktree-boundary.sh" ]; then
  sed -i '' \
    -e 's|POLYWAVE_WORKTREE_ROOT|POLYWAVE_WORKTREE_ROOT|g' \
    -e 's|\[SAW\]|[Polywave]|g' \
    -e 's|\bSAW\b wave|Polywave wave|g' \
    -e 's|sawDir|polywaveDir|g' \
    -e 's|worktrees/saw/|worktrees/polywave/|g' \
    hooks/polywave-worktree-boundary.sh
  echo "    Updated polywave-worktree-boundary.sh"
fi

# saw_agent_name → polywave_agent_name content update (GAP-H6)
IMPL_HOOKS_DIR="implementations/claude-code/hooks"
if [ -f "$IMPL_HOOKS_DIR/polywave_agent_name" ]; then
  sed -i '' \
    -e 's|\[SAW:wave|\[polywave:wave|g' \
    -e 's|\[SAW:scout:|\[polywave:scout:|g' \
    -e 's|\[SAW:critic:|\[polywave:critic:|g' \
    -e 's|\[SAW:scaffold:|\[polywave:scaffold:|g' \
    -e 's|\[SAW:integration:|\[polywave:integration:|g' \
    "$IMPL_HOOKS_DIR/polywave_agent_name"
  echo "    Updated polywave_agent_name hook"
fi

# Update ALL impl hooks content (env vars, paths, brand references)
if [ -d "$IMPL_HOOKS_DIR" ]; then
  find "$IMPL_HOOKS_DIR" -type f | xargs sed -i '' \
    -e 's|POLYWAVE_AGENT_WORKTREE|POLYWAVE_AGENT_WORKTREE|g' \
    -e 's|POLYWAVE_AGENT_ID|POLYWAVE_AGENT_ID|g' \
    -e 's|POLYWAVE_WAVE_NUMBER|POLYWAVE_WAVE_NUMBER|g' \
    -e 's|POLYWAVE_IMPL_PATH|POLYWAVE_IMPL_PATH|g' \
    -e 's|POLYWAVE_BRANCH|POLYWAVE_BRANCH|g' \
    -e 's|POLYWAVE_WORKTREE_ROOT|POLYWAVE_WORKTREE_ROOT|g' \
    -e 's|\.saw-agent-brief\.md|.polywave-agent-brief.md|g' \
    -e 's|\.polywave-state|.polywave-state|g' \
    -e 's|skills/saw|skills/polywave|g' \
    -e 's|\bSAW\b |Polywave |g' \
    2>/dev/null || true
  echo "    Updated all implementation hook files"
fi

# Update proposals hook files (self-referential comments)
for f in \
  "docs/proposals/saw-teams/hooks/task-completed-polywave.sh" \
  "docs/proposals/saw-teams/hooks/teammate-idle-polywave.sh"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|task-completed-saw\.sh|task-completed-polywave.sh|g' \
      -e 's|teammate-idle-saw\.sh|teammate-idle-polywave.sh|g' \
      "$f"
    echo "    Updated $f"
  fi
done

# ── Step 3: Rename polywave.config.json ────────────────────────────────────────────
echo ""
echo "==> Step 3: Renaming polywave.config.json → polywave.config.json"
if [ -f "polywave.config.json" ] && [ ! -f "polywave.config.json" ]; then
  git mv polywave.config.json polywave.config.json
  echo "    Renamed polywave.config.json → polywave.config.json"
elif [ -f "polywave.config.json" ]; then
  echo "    Already renamed"
fi

# ── Step 4: Update polywave.config.json / polywave.config.json content ─────────────
echo ""
echo "==> Step 4: Updating polywave.config.json content"
if [ -f "polywave.config.json" ]; then
  sed -i '' \
    -e 's|"polywave-go"|"polywave-go"|g' \
    -e 's|"polywave-web"|"polywave-web"|g' \
    -e 's|"polywave"|"polywave"|g' \
    -e 's|polywave-go|polywave-go|g' \
    -e 's|polywave-web|polywave-web|g' \
    -e 's|polywave|polywave|g' \
    polywave.config.json
  echo "    Updated polywave.config.json"
fi

# ── Step 5: Atomic protocol marker update ─────────────────────────────────────
# WARNING: These three files must stay in sync — the hook parses the literal
# marker string emitted by the prompts.
echo ""
echo "==> Step 5: Atomic protocol marker update (hook + skill prompt + critic prompt)"
MARKER_FILES=(
  "hooks/polywave-critic-impl-commit.sh"
  "implementations/claude-code/prompts/polywave-skill.md"
  "implementations/claude-code/prompts/agents/critic-agent.md"
)
for f in "${MARKER_FILES[@]}"; do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|\[SAW:critic:|[polywave:critic:|g' \
      -e 's|\[SAW:complete\]|[polywave:complete]|g' \
      -e 's|\[SAW:state:|[polywave:state:|g' \
      "$f"
    echo "    Updated $f"
  fi
done

# Also update documentation examples (non-behavioral)
for f in \
  "protocol/wave-agent-contracts.md" \
  "protocol/pre-wave-validation.md"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|\[SAW:critic:|[polywave:critic:|g' \
      "$f"
    echo "    Updated $f (doc examples)"
  fi
done

# ── Step 6: install.sh ────────────────────────────────────────────────────────
echo ""
echo "==> Step 6: Updating install.sh"
if [ -f "install.sh" ]; then
  sed -i '' \
    -e 's|Polywave|Polywave|g' \
    -e 's|polywave-go/cmd/sawtools@latest|polywave-go/cmd/polywave-tools@latest|g' \
    -e 's|blackwell-systems/tap/sawtools|blackwell-systems/tap/polywave-tools|g' \
    -e 's|~/.claude/skills/saw|~/.claude/skills/polywave|g' \
    -e 's|~/.agents/skills/saw|~/.agents/skills/polywave|g' \
    -e 's|${HOME}/.claude/skills/saw|${HOME}/.claude/skills/polywave|g' \
    -e 's|${HOME}/.agents/skills/saw|${HOME}/.agents/skills/polywave|g' \
    -e 's|saw-critic-impl-commit\.sh|polywave-critic-impl-commit.sh|g' \
    -e 's|saw-worktree-boundary\.sh|polywave-worktree-boundary.sh|g' \
    -e 's|saw-skill\.md|polywave-skill.md|g' \
    -e 's|saw-bootstrap\.md|polywave-bootstrap.md|g' \
    -e 's|"auto_format_saw_agent_names"|"auto_format_polywave_agent_names"|g' \
    -e 's|"saw_orchestrator_stop"|"polywave_orchestrator_stop"|g' \
    -e 's|"saw_critic_impl_commit"|"polywave_critic_impl_commit"|g' \
    -e 's|/saw_critic_impl_commit|/polywave_critic_impl_commit|g' \
    -e 's|/saw_orchestrator_stop|/polywave_orchestrator_stop|g' \
    -e 's|/auto_format_saw_agent_names|/auto_format_polywave_agent_names|g' \
    -e 's|polywave repo root|polywave repo root|g' \
    -e 's|/polywave scout|/polywave scout|g' \
    install.sh
  echo "    Updated install.sh"
fi

# ── Step 7: Prose docs sed pass ───────────────────────────────────────────────
echo ""
echo "==> Step 7: Prose docs sed pass (README, ROADMAP, GLOSSARY, POSITION, protocol/, docs/, implementations/)"

# Build file list — exclude: CHANGELOG historical entries dir, IMPL archives, .claude worktrees
PROSE_FILES=$(find . \
  \( -name '*.md' -o -name '*.yaml' -o -name '*.sh' -o -name '*.json' \) \
  -not -path './.claude/*' \
  -not -path './docs/IMPL/complete/*' \
  -not -path './docs/IMPL/.polywave-state/*' \
  -not -path './docs/PROGRAM/complete/*' \
  -not -name 'CHANGELOG.md' \
  2>/dev/null)

echo "$PROSE_FILES" | xargs sed -i '' \
  -e 's|polywave-go|polywave-go|g' \
  -e 's|polywave-web|polywave-web|g' \
  -e 's|polywave|polywave|g' \
  -e 's|Polywave|Polywave|g' \
  -e 's|Polywave|Polywave|g' \
  -e 's|\bsawtools\b|polywave-tools|g' \
  -e 's|POLYWAVE_REPO|POLYWAVE_REPO|g' \
  -e 's|POLYWAVE_ALLOW_MAIN_COMMIT|POLYWAVE_ALLOW_MAIN_COMMIT|g' \
  -e 's|POLYWAVE_WORKTREE_ROOT|POLYWAVE_WORKTREE_ROOT|g' \
  -e 's|POLYWAVE_CLI_BINARY|POLYWAVE_CLI_BINARY|g' \
  -e 's|POLYWAVE_LOG_LEVEL|POLYWAVE_LOG_LEVEL|g' \
  -e 's|POLYWAVE_NO_PRIORITIZE|POLYWAVE_NO_PRIORITIZE|g' \
  -e 's|POLYWAVE_BACKEND|POLYWAVE_BACKEND|g' \
  -e 's|POLYWAVE_AGENT_WORKTREE|POLYWAVE_AGENT_WORKTREE|g' \
  -e 's|POLYWAVE_AGENT_ID|POLYWAVE_AGENT_ID|g' \
  -e 's|POLYWAVE_WAVE_NUMBER|POLYWAVE_WAVE_NUMBER|g' \
  -e 's|POLYWAVE_IMPL_PATH|POLYWAVE_IMPL_PATH|g' \
  -e 's|POLYWAVE_BRANCH|POLYWAVE_BRANCH|g' \
  -e 's|saw\.config\.json|polywave.config.json|g' \
  -e 's|\.polywave-state|.polywave-state|g' \
  -e 's|\.saw-agent-brief\.md|.polywave-agent-brief.md|g' \
  -e 's|`polywave |`polywave |g' \
  -e 's|`polywave`|`polywave`|g' \
  -e 's| polywave serve| polywave serve|g' \
  -e 's| polywave scout| polywave scout|g' \
  -e 's| polywave wave| polywave wave|g' \
  -e 's| polywave scaffold| polywave scaffold|g' \
  -e 's| polywave status| polywave status|g' \
  -e 's| polywave amend| polywave amend|g' \
  -e 's|/polywave scout|/polywave scout|g' \
  -e 's|/polywave wave|/polywave wave|g' \
  -e 's|/polywave amend|/polywave amend|g' \
  -e 's|/polywave auto|/polywave auto|g' \
  -e 's|/polywave bootstrap|/polywave bootstrap|g' \
  -e 's|/polywave status|/polywave status|g' \
  -e 's|/polywave interview|/polywave interview|g' \
  -e 's|/polywave program|/polywave program|g' \
  2>/dev/null || true

echo "    Prose docs updated."

# CHANGELOG: update only title line, leave historical entries
if [ -f "CHANGELOG.md" ]; then
  sed -i '' \
    -e '1s|# Changelog.*|# Changelog|' \
    -e 's|All notable changes to the Polywave protocol|All notable changes to the Polywave protocol|g' \
    CHANGELOG.md
  echo "    Updated CHANGELOG.md title (historical entries preserved)"
fi

echo ""
echo "==> Phase 3 complete."
echo ""
echo "==> Full migration verification:"
echo "    Run: grep -r 'polywave' . --include='*.go' (should return 0 results in Go repos)"
echo "    Run: grep -r 'sawtools' . --include='*.go' (should return 0 results in Go repos)"
echo "    Run: ./polywave-tools --help (should show polywave-tools)"
echo "    Run: ./polywave serve (should start on :7432 with title 'Polywave')"
echo "    Run: bash -n hooks/polywave-critic-impl-commit.sh (shell syntax check)"
