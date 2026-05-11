#!/usr/bin/env bash
# migrate-phase1.sh — Mechanical changes for polywave-go (was polywave-go)
# Run AFTER LSP symbol renames are complete (SAWError, SAWConfig, SAWStateDir, etc.)
# Idempotent: safe to re-run.
#
# Usage: ./scripts/migrate-phase1.sh /path/to/polywave-go
# Or from within the repo: ./scripts/migrate-phase1.sh .

set -euo pipefail

REPO="${1:-.}"
REPO="$(cd "$REPO" && pwd)"

echo "==> Phase 1: polywave-go mechanical migration"
echo "    Repo: $REPO"
echo ""

# Verify we're in the right repo
if ! grep -q "polywave-go\|polywave-go" "$REPO/go.mod" 2>/dev/null; then
  echo "ERROR: $REPO does not look like the polywave-go repo (no matching go.mod)"
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

# ── Step 1: Go module rename ───────────────────────────────────────────────────
echo "==> Step 1: Renaming Go module path"
go mod edit -module github.com/blackwell-systems/polywave-go
echo "    go.mod module line updated"

echo "    Replacing import paths in .go files..."
find . -name '*.go' \
  -not -path './.claude/*' \
  -not -path './docs/IMPL/*' \
  | xargs sed -i '' \
    's|github.com/blackwell-systems/polywave-go|github.com/blackwell-systems/polywave-go|g'
echo "    Done."

# ── Step 2: Config filename ────────────────────────────────────────────────────
echo ""
echo "==> Step 2: Replacing polywave.config.json references"
FILES=$(grep -rl 'saw\.config\.json' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  --exclude-dir='docs' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' 's|saw\.config\.json|polywave.config.json|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
else
  echo "    Already updated or not found"
fi

# ── Step 3: State directory ────────────────────────────────────────────────────
echo ""
echo "==> Step 3: Replacing .polywave-state path literals"
FILES=$(grep -rl '\.polywave-state' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  --exclude-dir='docs' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' 's|\.polywave-state|.polywave-state|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
else
  echo "    Already updated or not found"
fi

# ── Step 4: Branch prefix and worktree path ────────────────────────────────────
echo ""
echo "==> Step 4: Replacing branch prefix and worktree path strings"
TARGETED_FILES=(
  "pkg/protocol/branchname.go"
  "pkg/resume/worktree_status.go"
  "pkg/resume/detect.go"
  "pkg/protocol/cleanup.go"
  "pkg/protocol/worktree_resolve.go"
  "pkg/protocol/program_worktree.go"
  "pkg/hooks/prelaunch_gate.go"
  "pkg/collision/detector.go"
  "cmd/sawtools/close_impl_cmd.go"
  "pkg/worktree/manager_test.go"
)
for f in "${TARGETED_FILES[@]}"; do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|"saw/"|"polywave/"|g' \
      -e 's|"worktrees", "saw"|"worktrees", "polywave"|g' \
      -e 's|strings\.HasPrefix(currentBranch, "saw/")|strings.HasPrefix(currentBranch, "polywave/")|g' \
      -e 's|saw/%s/wave|polywave/%s/wave|g' \
      -e 's|(?:saw/\([a-z0-9\]\[^/\]*/\))|(?:polywave/\1)|g' \
      -e 's|`\^saw/|`^polywave/|g' \
      "$f"
  fi
done

# Broader test file sweep: filepath.Join args and branch format strings
find . -name '*_test.go' \
  -not -path './.git/*' \
  -not -path './.claude/*' \
  | xargs sed -i '' \
    -e 's|"worktrees", "saw"|"worktrees", "polywave"|g' \
    -e 's|saw/\([a-z0-9-]*\)/wave|polywave/\1/wave|g' \
    -e 's|refs/heads/saw/|refs/heads/polywave/|g' \
    -e 's|sawtools pre-commit-check|polywave-tools pre-commit-check|g' \
    2>/dev/null || true
echo "    Done."

# ── Step 5: Skills dir ─────────────────────────────────────────────────────────
echo ""
echo "==> Step 5: Replacing skills dir path"
if [ -f "pkg/engine/verify_install.go" ]; then
  sed -i '' \
    's|\.claude/skills/saw|.claude/skills/polywave|g' \
    pkg/engine/verify_install.go
  echo "    Updated verify_install.go"
fi

# ── Step 6: Verify-install check names ────────────────────────────────────────
echo ""
echo "==> Step 6: Updating verify-install check names"
if [ -f "pkg/engine/verify_install.go" ]; then
  sed -i '' \
    's|"sawtools_binary"|"polywave_tools_binary"|g' \
    pkg/engine/verify_install.go
fi

# ── Step 7: Environment variables ─────────────────────────────────────────────
echo ""
echo "==> Step 7: Replacing SAW_* environment variable names"
FILES=$(grep -rl 'POLYWAVE_REPO\|POLYWAVE_ALLOW_MAIN_COMMIT\|POLYWAVE_WORKTREE_ROOT\|POLYWAVE_CLI_BINARY\|POLYWAVE_LOG_LEVEL\|POLYWAVE_NO_PRIORITIZE\|SAW_CONFLICT_MODEL\|SAW_FIX_BUILD_MODEL' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  --exclude-dir='docs' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' \
    -e 's|POLYWAVE_REPO|POLYWAVE_REPO|g' \
    -e 's|POLYWAVE_ALLOW_MAIN_COMMIT|POLYWAVE_ALLOW_MAIN_COMMIT|g' \
    -e 's|POLYWAVE_WORKTREE_ROOT|POLYWAVE_WORKTREE_ROOT|g' \
    -e 's|POLYWAVE_CLI_BINARY|POLYWAVE_CLI_BINARY|g' \
    -e 's|POLYWAVE_LOG_LEVEL|POLYWAVE_LOG_LEVEL|g' \
    -e 's|POLYWAVE_NO_PRIORITIZE|POLYWAVE_NO_PRIORITIZE|g' \
    -e 's|SAW_CONFLICT_MODEL|POLYWAVE_CONFLICT_MODEL|g' \
    -e 's|SAW_FIX_BUILD_MODEL|POLYWAVE_FIX_BUILD_MODEL|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
fi

# ── Step 8: Pre-commit hook template + .polywave-agent-brief.md write sites ────────
echo ""
echo "==> Step 8: Updating hook templates and .polywave-agent-brief.md references"
if [ -f "internal/git/commands.go" ]; then
  sed -i '' \
    -e 's|# SAW pre-commit guard|# Polywave pre-commit guard|g' \
    -e 's|SAW isolation violation|Polywave isolation violation|g' \
    -e 's|\.saw-agent-brief\.md|.polywave-agent-brief.md|g' \
    internal/git/commands.go
fi

# .polywave-agent-brief.md write/read sites (GAP-C1 — must stay in sync with hook checks)
for f in \
  "pkg/engine/prepare_agent.go" \
  "pkg/engine/prepare.go" \
  "cmd/sawtools/run_integration_wave_cmd.go" \
  "cmd/sawtools/run_integration_wave_cmd_test.go"
do
  if [ -f "$f" ]; then
    sed -i '' 's|\.saw-agent-brief\.md|.polywave-agent-brief.md|g' "$f"
  fi
done

# Verify-hook detection strings
if [ -f "cmd/sawtools/verify_hook_installed.go" ]; then
  sed -i '' \
    -e 's|"SAW pre-commit guard"|"Polywave pre-commit guard"|g' \
    cmd/sawtools/verify_hook_installed.go
fi

# Install hooks snippet + Short description (GAP-H8)
if [ -f "cmd/sawtools/install_hooks_cmd.go" ]; then
  sed -i '' \
    -e 's|# SAW pre-commit quality gate|# Polywave pre-commit quality gate|g' \
    -e 's|sawtools pre-commit-check|polywave-tools pre-commit-check|g' \
    -e 's|Install SAW |Install Polywave |g' \
    cmd/sawtools/install_hooks_cmd.go
fi

# finalize_wave.go "SAW-owned state files" help text (GAP-M9)
if [ -f "pkg/engine/finalize_wave.go" ]; then
  sed -i '' 's|SAW-owned state files|Polywave-owned state files|g' pkg/engine/finalize_wave.go
fi
echo "    Done."

# ── Step 9: GitHub URL literals + local-build instruction ─────────────────────
echo ""
echo "==> Step 9: Updating GitHub URL literals in init_cmd.go"
if [ -f "cmd/sawtools/init_cmd.go" ]; then
  sed -i '' \
    -e 's|polywave#quick-start|polywave#quick-start|g' \
    -e 's|polywave-go/cmd/sawtools@latest|polywave-go/cmd/polywave-tools@latest|g' \
    -e 's|polywave-go\.git|polywave-go.git|g' \
    -e 's|-o ~/.local/bin/sawtools|-o ~/.local/bin/polywave-tools|g' \
    -e 's|cd polywave-go|cd polywave-go|g' \
    cmd/sawtools/init_cmd.go
fi

# Integration test exec calls
if [ -f "pkg/scaffold/integration_test.go" ]; then
  sed -i '' \
    's|exec\.Command("sawtools"|exec.Command("polywave-tools"|g' \
    pkg/scaffold/integration_test.go
fi
echo "    Done."

# ── Step 9a2: --saw-repo CLI flag → --protocol-repo (GAP-M3) ───────────────────
echo ""
echo "==> Step 9a2: Renaming --saw-repo CLI flag to --protocol-repo"
for f in \
  "cmd/sawtools/run_scout_cmd.go" \
  "cmd/sawtools/auto_cmd.go"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|"saw-repo"|"protocol-repo"|g' \
      -e 's|Polywave protocol repo path|Polywave protocol repo path|g' \
      "$f"
  fi
done
echo "    Done."

# ── Step 9b: [SAW:...] protocol markers in Go engine (GAP-C5) ─────────────────
echo ""
echo "==> Step 9b: Updating [SAW:...] protocol markers in Go source"
for f in \
  "cmd/sawtools/agent_status_cmd.go" \
  "cmd/sawtools/close_impl_cmd.go" \
  "pkg/engine/caller_cascade.go" \
  "pkg/engine/prepare_agent.go" \
  "pkg/engine/prepare.go"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|\[SAW:critic:|[polywave:critic:|g' \
      -e 's|\[SAW:complete\]|[polywave:complete]|g' \
      -e 's|\[SAW:wave|[polywave:wave|g' \
      -e 's|\[SAW:scout:|[polywave:scout:|g' \
      -e 's|\[SAW:scaffold:|[polywave:scaffold:|g' \
      -e 's|\[SAW:integration:|[polywave:integration:|g' \
      "$f"
  fi
done
echo "    Done."

# ── Step 9c: Hardcoded ~/code/polywave fallback paths (GAP-C2) ──────────
echo ""
echo "==> Step 9c: Updating hardcoded polywave fallback paths"
FILES=$(grep -rl '"code", "polywave"' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' \
    's|"code", "polywave"|"code", "polywave"|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
fi

# ── Step 9d: verify_install.go saw-bootstrap.md required files list (GAP-H7) ──
echo ""
echo "==> Step 9d: Updating verify_install.go required skill files list"
if [ -f "pkg/engine/verify_install.go" ]; then
  sed -i '' \
    's|"saw-bootstrap\.md"|"polywave-bootstrap.md"|g' \
    pkg/engine/verify_install.go
fi

# verify_install_cmd_test.go assertions (GAP-M1)
if [ -f "cmd/sawtools/verify_install_cmd_test.go" ]; then
  sed -i '' \
    -e 's|"sawtools_binary"|"polywave_tools_binary"|g' \
    -e 's|~/.claude/skills/saw/|~/.claude/skills/polywave/|g' \
    cmd/sawtools/verify_install_cmd_test.go
fi
echo "    Done."

# ── Step 9e: git mv polywave.config.json (GAP-H1) ─────────────────────────────────
echo ""
echo "==> Step 9e: Renaming polywave.config.json → polywave.config.json"
if [ -f "polywave.config.json" ] && [ ! -f "polywave.config.json" ]; then
  git mv polywave.config.json polywave.config.json
  sed -i '' \
    -e 's|"polywave"|"polywave"|g' \
    -e 's|polywave-go|polywave-go|g' \
    -e 's|polywave-web|polywave-web|g' \
    polywave.config.json
  echo "    Renamed and updated polywave.config.json"
elif [ -f "polywave.config.json" ]; then
  echo "    Already renamed"
fi

# ── Step 9f: .github/workflows/ (GAP-C4) ─────────────────────────────────────
echo ""
echo "==> Step 9f: Updating .github/workflows/"
if [ -d ".github/workflows" ]; then
  find .github/workflows -name '*.yml' -o -name '*.yaml' | xargs sed -i '' \
    -e 's|./cmd/sawtools|./cmd/polywave-tools|g' \
    -e 's|-o.*sawtools|-o polywave-tools|g' \
    -e 's|polywave-go|polywave-go|g' \
    -e 's|polywave-web|polywave-web|g' \
    -e 's|\bsawtools\b|polywave-tools|g'
  echo "    Updated .github/workflows/"
else
  echo "    No .github/workflows/ found — skipping"
fi

# ── Step 10: File renames ─────────────────────────────────────────────────────
echo ""
echo "==> Step 10: Renaming cmd/sawtools/ → cmd/polywave-tools/"
if [ -d "cmd/sawtools" ] && [ ! -d "cmd/polywave-tools" ]; then
  git mv cmd/sawtools cmd/polywave-tools
  echo "    Renamed cmd/sawtools → cmd/polywave-tools"
elif [ -d "cmd/polywave-tools" ]; then
  echo "    Already renamed"
fi

for f in \
  "pkg/pipeline/saw_steps.go" \
  "pkg/pipeline/saw_steps_test.go" \
  "pkg/commands/saw_config.go" \
  "pkg/commands/saw_config_test.go"
do
  new="${f/saw_/polywave_}"
  if [ -f "$f" ] && [ ! -f "$new" ]; then
    git mv "$f" "$new"
    echo "    Renamed $f → $new"
  fi
done

# ── Step 11: .goreleaser.yaml ─────────────────────────────────────────────────
echo ""
echo "==> Step 11: Updating .goreleaser.yaml"
if [ -f ".goreleaser.yaml" ]; then
  sed -i '' \
    -e 's|id: sawtools|id: polywave-tools|g' \
    -e 's|main: ./cmd/sawtools|main: ./cmd/polywave-tools|g' \
    -e 's|binary: sawtools|binary: polywave-tools|g' \
    -e 's|sawtools_|polywave-tools_|g' \
    .goreleaser.yaml
  echo "    Updated .goreleaser.yaml"
fi

# ── Step 12: Build verification ───────────────────────────────────────────────
echo ""
echo "==> Step 12: Build verification"
# GOWORK=off: go.work may reference other modules (e.g. shelfctl) but not this
# one; bypass workspace mode so go build resolves against go.mod only.
GOWORK=off go build ./...
echo "    Build: PASSED"
GOWORK=off go test ./... -count=1 -timeout 120s
echo "    Tests: PASSED"

echo ""
echo "==> Phase 1 complete."
echo "    Next: run migrate-phase2.sh for the web repo"
