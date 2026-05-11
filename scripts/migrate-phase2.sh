#!/usr/bin/env bash
# migrate-phase2.sh — Mechanical changes for polywave-web (was polywave-web)
# Requires Phase 1 complete and polywave-go built successfully.
# Idempotent: safe to re-run.
#
# Usage: ./scripts/migrate-phase2.sh /path/to/polywave-web [/path/to/polywave-go]
# Or from within polywave repo: ./scripts/migrate-phase2.sh ../polywave-web ../polywave-go

set -euo pipefail

WEB_REPO="${1:-.}"
GO_REPO="${2:-../polywave-go}"
WEB_REPO="$(cd "$WEB_REPO" && pwd)"
GO_REPO="$(cd "$GO_REPO" && pwd)"

echo "==> Phase 2: polywave-web mechanical migration"
echo "    Web repo: $WEB_REPO"
echo "    Go repo:  $GO_REPO"
echo ""

# Verify we're in the right repo
if ! grep -q "polywave-web\|polywave-web" "$WEB_REPO/go.mod" 2>/dev/null; then
  echo "ERROR: $WEB_REPO does not look like the polywave-web repo"
  exit 1
fi

cd "$WEB_REPO"

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
echo "==> Step 1: Renaming Go module paths"
go mod edit -module github.com/blackwell-systems/polywave-web
go mod edit -require github.com/blackwell-systems/polywave-go@v0.98.0
go mod edit -replace github.com/blackwell-systems/polywave-go="$GO_REPO"
# Drop old polywave-go directives (may already be absent — idempotent)
go mod edit -droprequire github.com/blackwell-systems/polywave-go 2>/dev/null || true
go mod edit -dropreplace github.com/blackwell-systems/polywave-go 2>/dev/null || true
echo "    go.mod updated"

echo "    Replacing import paths in .go files..."
find . -name '*.go' \
  -not -path './.claude/*' \
  -not -path './docs/IMPL/*' \
  | xargs sed -i '' \
    -e 's|github.com/blackwell-systems/polywave-go|github.com/blackwell-systems/polywave-go|g' \
    -e 's|github.com/blackwell-systems/polywave-web|github.com/blackwell-systems/polywave-web|g'
echo "    Done."

# ── Step 1b: Go type renames (follow Phase 1 symbol renames in polywave-go) ──
echo ""
echo "==> Step 1b: Renaming SAW* Go types in web repo"
find . -name '*.go' \
  -not -path './.git/*' \
  -not -path './.claude/*' \
  | xargs sed -i '' \
    -e 's/SAWConfig/PolywaveConfig/g' \
    -e 's/SAWError/PolywaveError/g' \
    -e 's/SAWProviders/PolywaveProviders/g' \
    -e 's/fallbackSAWConfig/fallbackPolywaveConfig/g' \
    -e 's/FallbackSAWConfig/FallbackPolywaveConfig/g'
echo "    Done."

# ── Step 2: Root cobra command ────────────────────────────────────────────────
echo ""
echo "==> Step 2: Updating root cobra command strings"
if [ -f "cmd/saw/root.go" ]; then
  sed -i '' \
    -e 's|Use: "saw"|Use: "polywave"|g' \
    -e 's|SAW Orchestration CLI|Polywave Orchestration CLI|g' \
    cmd/saw/root.go
fi

# ── Step 3: Environment variables ─────────────────────────────────────────────
echo ""
echo "==> Step 3: Replacing SAW_* environment variable names"
FILES=$(grep -rl 'POLYWAVE_REPO\|POLYWAVE_BACKEND' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  --exclude-dir='docs' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' \
    -e 's|POLYWAVE_REPO|POLYWAVE_REPO|g' \
    -e 's|POLYWAVE_BACKEND|POLYWAVE_BACKEND|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
fi

# ── Step 4: Config filename ────────────────────────────────────────────────────
echo ""
echo "==> Step 4: Replacing polywave.config.json references"
FILES=$(grep -rl 'saw\.config\.json' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  --exclude-dir='docs' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' 's|saw\.config\.json|polywave.config.json|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
fi

# ── Step 5: State directory ────────────────────────────────────────────────────
echo ""
echo "==> Step 5: Replacing .polywave-state path literals"
for f in \
  "pkg/api/journal_handler.go" \
  "pkg/api/stage_state.go" \
  "pkg/api/global_events.go" \
  "pkg/api/wave_runner.go" \
  "pkg/api/recovery_handlers.go" \
  "pkg/api/pipeline_state.go"
do
  if [ -f "$f" ]; then
    sed -i '' 's|\.polywave-state|.polywave-state|g' "$f"
  fi
done
echo "    Done."

# ── Step 6: TypeScript frontend ───────────────────────────────────────────────
echo ""
echo "==> Step 6: Updating TypeScript frontend strings"

# index.html
if [ -f "web/index.html" ]; then
  sed -i '' \
    -e 's|<title>SAW - Polywave</title>|<title>Polywave</title>|g' \
    -e "s|'saw-theme'|'polywave-theme'|g" \
    -e "s|'saw-contrast'|'polywave-contrast'|g" \
    web/index.html
  echo "    Updated web/index.html"
fi

# App.tsx
if [ -f "web/src/App.tsx" ]; then
  sed -i '' \
    -e 's|Welcome to Polywave|Welcome to Polywave|g' \
    -e 's|Polywave uses AI agents|Polywave uses AI agents|g' \
    web/src/App.tsx
fi

# Hook files — storage keys only (GAP-C3: contrast-changed handled explicitly below)
for f in \
  "web/src/hooks/useDarkMode.ts" \
  "web/src/hooks/useContrast.ts"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e "s|'saw-theme'|'polywave-theme'|g" \
      -e "s|'saw-contrast'|'polywave-contrast'|g" \
      -e "s|'saw:contrast-changed'|'polywave:contrast-changed'|g" \
      "$f"
  fi
done

# Other TS files (brand strings, event names, SAWConfig type)
for f in \
  "web/src/contexts/ReviewContext.tsx" \
  "web/src/contexts/ReviewContext.test.tsx" \
  "web/src/lib/themes.ts" \
  "web/src/lib/apiClient.ts" \
  "web/src/components/ScoutLauncher.tsx" \
  "web/src/components/SettingsScreen.tsx" \
  "web/src/components/PipelineView.tsx" \
  "web/src/components/WorktreePanel.tsx" \
  "web/src/components/AmendPanel.tsx" \
  "web/src/types.ts" \
  "web/src/types/program.ts" \
  "web/src/types/autonomy.ts" \
  "web/src/lib/entityColors.ts" \
  "web/src/api.ts"
do
  if [ -f "$f" ]; then
    sed -i '' \
      -e "s|'saw-review-panels'|'polywave-review-panels'|g" \
      -e "s|'saw-themes'|'polywave-themes'|g" \
      -e "s|'saw-scout-context'|'polywave-scout-context'|g" \
      -e "s|'saw:contrast-changed'|'polywave:contrast-changed'|g" \
      -e 's|sawtools init|polywave-tools init|g' \
      -e 's|SAW Pipeline|Polywave Pipeline|g' \
      -e 's|No SAW branches found|No Polywave branches found|g' \
      -e 's|interface SAWConfig|interface PolyConfig|g' \
      -e 's|SAWConfig|PolyConfig|g' \
      -e 's|polywave-go|polywave-go|g' \
      -e 's|polywave-web|polywave-web|g' \
      -e 's|/polywave amend|/polywave amend|g' \
      -e 's|/polywave scout|/polywave scout|g' \
      "$f"
  fi
done
echo "    TypeScript frontend updated."

# ── Step 7: File renames ──────────────────────────────────────────────────────
echo ""
echo "==> Step 7: Renaming cmd/saw/ → cmd/polywave/"
if [ -d "cmd/saw" ] && [ ! -d "cmd/polywave" ]; then
  git mv cmd/saw cmd/polywave
  echo "    Renamed cmd/saw → cmd/polywave"
elif [ -d "cmd/polywave" ]; then
  echo "    Already renamed"
fi

# ── Step 7b: git mv polywave.config.json (GAP-H1) ─────────────────────────────────
echo ""
echo "==> Step 7b: Renaming polywave.config.json → polywave.config.json"
if [ -f "polywave.config.json" ] && [ ! -f "polywave.config.json" ]; then
  git mv polywave.config.json polywave.config.json
  sed -i '' \
    -e 's|"polywave-go"|"polywave-go"|g' \
    -e 's|"polywave-web"|"polywave-web"|g' \
    -e 's|"polywave"|"polywave"|g' \
    polywave.config.json
  echo "    Renamed and updated polywave.config.json"
elif [ -f "polywave.config.json" ]; then
  echo "    Already renamed"
fi

# ── Step 7c: Hardcoded ~/code/polywave fallback paths (GAP-C2) ──────────
echo ""
echo "==> Step 7c: Updating hardcoded polywave fallback paths"
FILES=$(grep -rl '"code", "polywave"' . \
  --include='*.go' \
  --exclude-dir='.claude' \
  2>/dev/null || true)
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs sed -i '' \
    's|"code", "polywave"|"code", "polywave"|g'
  echo "    Updated $(echo "$FILES" | wc -l | tr -d ' ') files"
fi

# ── Step 7d: .github/workflows/ (GAP-C4) ─────────────────────────────────────
echo ""
echo "==> Step 7d: Updating .github/workflows/"
if [ -d ".github/workflows" ]; then
  find .github/workflows -name '*.yml' -o -name '*.yaml' | xargs sed -i '' \
    -e 's|repository: blackwell-systems/polywave-go|repository: blackwell-systems/polywave-go|g' \
    -e 's|polywave-go|polywave-go|g' \
    -e 's|polywave-web|polywave-web|g' \
    -e 's|\bsawtools\b|polywave-tools|g'
  echo "    Updated .github/workflows/"
else
  echo "    No .github/workflows/ found — skipping"
fi

# ── Step 8: Makefile ──────────────────────────────────────────────────────────
echo ""
echo "==> Step 8: Updating Makefile"
if [ -f "Makefile" ]; then
  sed -i '' \
    -e 's|go build -o saw ./cmd/saw|go build -o polywave ./cmd/polywave|g' \
    -e 's|rm -f saw$|rm -f polywave|g' \
    Makefile
fi

# ── Step 9: Build verification ────────────────────────────────────────────────
echo ""
echo "==> Step 9: Build verification"
echo "    Building frontend..."
(cd web && npm run build)
echo "    Frontend build: PASSED"
GOWORK=off go build ./...
echo "    Go build: PASSED"
GOWORK=off go test ./... -count=1 -timeout 120s
echo "    Tests: PASSED"

echo ""
echo "==> Phase 2 complete."
echo "    Next: run migrate-phase3.sh for the protocol repo"
