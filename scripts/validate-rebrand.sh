#!/usr/bin/env bash
# validate-rebrand.sh — Confirm all old brand names are gone across all three repos.
# Read-only: makes no changes. Exit code 0 = clean, 1 = gaps remain.
#
# Usage:
#   ./scripts/validate-rebrand.sh
#   ./scripts/validate-rebrand.sh /path/to/polywave /path/to/polywave-go /path/to/polywave-web

set -uo pipefail

PROTO_REPO="${1:-/Users/dayna.blackwell/code/polywave}"
GO_REPO="${2:-/Users/dayna.blackwell/code/polywave-go}"
WEB_REPO="${3:-/Users/dayna.blackwell/code/polywave-web}"

PASS=0
FAIL=0
WARN=0

green() { printf '\033[32m✓\033[0m %s\n' "$*"; }
red()   { printf '\033[31m✗\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m~\033[0m %s\n' "$*"; }

check() {
  local label="$1"
  local count="$2"
  local detail="${3:-}"
  if [ "$count" -eq 0 ]; then
    green "$label"
    PASS=$((PASS + 1))
  else
    red "$label ($count occurrences)"
    [ -n "$detail" ] && echo "    $detail"
    FAIL=$((FAIL + 1))
  fi
}

check_warn() {
  local label="$1"
  local count="$2"
  local detail="${3:-}"
  if [ "$count" -eq 0 ]; then
    green "$label"
    PASS=$((PASS + 1))
  else
    warn "$label ($count occurrences — manual review needed)"
    [ -n "$detail" ] && echo "    $detail"
    WARN=$((WARN + 1))
  fi
}

grep_count() {
  # Usage: grep_count <pattern> <path> [extra grep args...]
  local pattern="$1"; shift
  local path="$1"; shift
  grep -rn "$pattern" "$path" "$@" 2>/dev/null | \
    grep -v '\.claude/worktrees' | \
    grep -v 'docs/IMPL/complete' | \
    grep -v 'docs/IMPL/\.saw-state' | \
    grep -v 'docs/PROGRAM/complete' | \
    grep -v '\.git/' \
    | wc -l | tr -d ' '
}

grep_show() {
  local pattern="$1"; shift
  local path="$1"; shift
  grep -rn "$pattern" "$path" "$@" 2>/dev/null | \
    grep -v '\.claude/worktrees' | \
    grep -v 'docs/IMPL/complete' | \
    grep -v 'docs/IMPL/\.saw-state' | \
    grep -v 'docs/PROGRAM/complete' | \
    grep -v '\.git/' | head -5 || true
}

echo "========================================"
echo " Polywave Rebrand Validation"
echo "========================================"
echo ""

# ── Repo 1: polywave-go ───────────────────────────────────────────────────────
echo "── polywave-go ($GO_REPO)"
echo ""

# Module path
N=$(grep_count 'scout-and-wave-go' "$GO_REPO" --include='*.go' --include='go.mod' --include='go.sum')
check "Go module path: no scout-and-wave-go imports" "$N" "$(grep_show 'scout-and-wave-go' "$GO_REPO" --include='*.go' -l | head -3)"

# Old binary name in Go source
N=$(grep_count '"sawtools"' "$GO_REPO" --include='*.go')
check "Binary name: no \"sawtools\" string literals in .go" "$N" "$(grep_show '"sawtools"' "$GO_REPO" --include='*.go' | head -3)"

# Old exported symbols (post-LSP rename)
for sym in SAWError SAWConfig SAWProviders SawConfigParser SAWStateDir SAWStateArchiveDir SAWStateAgentDir; do
  N=$(grep_count "\b${sym}\b" "$GO_REPO" --include='*.go')
  check "Symbol: no ${sym}" "$N" "$(grep_show "\b${sym}\b" "$GO_REPO" --include='*.go' | head -3)"
done

# SAWRepoPath field
N=$(grep_count '\bSAWRepoPath\b' "$GO_REPO" --include='*.go')
check "Struct field: no SAWRepoPath" "$N"

# Env vars
for var in SAW_REPO SAW_ALLOW_MAIN_COMMIT SAW_WORKTREE_ROOT SAW_CLI_BINARY SAW_LOG_LEVEL SAW_NO_PRIORITIZE SAW_CONFLICT_MODEL SAW_FIX_BUILD_MODEL; do
  N=$(grep_count "\"${var}\"" "$GO_REPO" --include='*.go')
  check "Env var: no ${var}" "$N"
done

# Config filename
N=$(grep_count 'saw\.config\.json' "$GO_REPO" --include='*.go')
check "Config: no polywave.config.json in .go files" "$N"

# State dir
N=$(grep_count '\.saw-state' "$GO_REPO" --include='*.go')
check "State dir: no .saw-state in .go files" "$N"

# Branch prefix
N=$(grep_count '"saw/"' "$GO_REPO" --include='*.go')
check "Branch prefix: no \"saw/\" string literal" "$N"

# Worktree path
N=$(grep_count '"worktrees", "saw"' "$GO_REPO" --include='*.go')
check "Worktree path: no \"worktrees\", \"saw\"" "$N"

# Skills path
N=$(grep_count 'skills/saw' "$GO_REPO" --include='*.go')
check "Skills path: no skills/saw in .go files" "$N"

# Pre-commit hook template
N=$(grep_count 'SAW pre-commit' "$GO_REPO" --include='*.go')
check "Hook template: no 'SAW pre-commit' in .go files" "$N"

# .goreleaser.yaml
if [ -f "$GO_REPO/.goreleaser.yaml" ]; then
  N=$(grep -c 'sawtools' "$GO_REPO/.goreleaser.yaml" 2>/dev/null || true)
  check "GoReleaser: no sawtools" "$N"
fi

# .polywave-agent-brief.md (GAP-C1)
N=$(grep_count '\.saw-agent-brief' "$GO_REPO" --include='*.go')
check "Agent brief: no .saw-agent-brief in .go files" "$N"

# Hardcoded fallback path (GAP-C2)
N=$(grep_count '"code", "scout-and-wave"' "$GO_REPO" --include='*.go')
check "Fallback path: no hardcoded ~/code/scout-and-wave" "$N"

# Protocol markers in Go source (GAP-C5)
N=$(grep_count '\[SAW:' "$GO_REPO" --include='*.go')
check "Markers: no [SAW:...] in .go files" "$N"

# polywave.config.json file existence (GAP-H1)
if [ -f "$GO_REPO/saw.config.json" ]; then
  red "File: saw.config.json still exists in polywave-go (should be polywave.config.json)"
  FAIL=$((FAIL + 1))
else
  green "File: polywave.config.json renamed in polywave-go"
  PASS=$((PASS + 1))
fi

# CI workflows (GAP-C4)
if [ -d "$GO_REPO/.github/workflows" ]; then
  N=$(grep_count 'sawtools\|scout-and-wave' "$GO_REPO/.github/workflows" --include='*.yml' --include='*.yaml')
  check "CI: no old names in .github/workflows/" "$N"
fi

# .goreleaser.yaml
if [ -f "$GO_REPO/.goreleaser.yaml" ]; then
  N=$(grep -c 'sawtools' "$GO_REPO/.goreleaser.yaml" 2>/dev/null || true)
  check "GoReleaser: no sawtools" "$N"
fi

# cmd directory name
if [ -d "$GO_REPO/cmd/sawtools" ]; then
  red "Directory: cmd/sawtools still exists (should be cmd/polywave-tools)"
  FAIL=$((FAIL + 1))
else
  green "Directory: cmd/sawtools renamed"
  PASS=$((PASS + 1))
fi

echo ""

# ── Repo 2: polywave-web ──────────────────────────────────────────────────────
echo "── polywave-web ($WEB_REPO)"
echo ""

# Module paths
N=$(grep_count 'scout-and-wave-go\|scout-and-wave-web' "$WEB_REPO" --include='*.go' --include='go.mod')
check "Go module paths: no scout-and-wave-* in .go/go.mod" "$N"

# Env vars
for var in SAW_REPO SAW_BACKEND; do
  N=$(grep_count "\"${var}\"" "$WEB_REPO" --include='*.go')
  check "Env var: no ${var} in .go files" "$N"
done

# Config filename
N=$(grep_count 'saw\.config\.json' "$WEB_REPO" --include='*.go')
check "Config: no polywave.config.json in .go files" "$N"

# State dir
N=$(grep_count '\.saw-state' "$WEB_REPO" --include='*.go')
check "State dir: no .saw-state in .go files" "$N"

# Hardcoded fallback path (GAP-C2)
N=$(grep_count '"code", "scout-and-wave"' "$WEB_REPO" --include='*.go')
check "Fallback path: no hardcoded ~/code/scout-and-wave" "$N"

# saw.config.json file existence (GAP-H1)
if [ -f "$WEB_REPO/saw.config.json" ]; then
  red "File: saw.config.json still exists in polywave-web (should be polywave.config.json)"
  FAIL=$((FAIL + 1))
else
  green "File: polywave.config.json renamed in polywave-web"
  PASS=$((PASS + 1))
fi

# CI workflows (GAP-C4)
if [ -d "$WEB_REPO/.github/workflows" ]; then
  N=$(grep_count 'scout-and-wave' "$WEB_REPO/.github/workflows" --include='*.yml' --include='*.yaml')
  check "CI: no old names in .github/workflows/" "$N"
fi

# cmd/saw directory
if [ -d "$WEB_REPO/cmd/saw" ]; then
  red "Directory: cmd/saw still exists (should be cmd/polywave)"
  FAIL=$((FAIL + 1))
else
  green "Directory: cmd/saw renamed"
  PASS=$((PASS + 1))
fi

# TypeScript: localStorage keys and brand strings
for pattern in 'saw-theme' 'saw-contrast' 'saw-review-panels' 'saw-themes' 'saw-scout-context' 'saw:contrast-changed' 'SAW Pipeline' 'No SAW branches' 'Scout-and-Wave' 'SAWConfig' '/saw amend' '/saw scout'; do
  N=$(grep_count "$pattern" "$WEB_REPO" --include='*.ts' --include='*.tsx' --include='*.html')
  check "TS/HTML: no '$pattern'" "$N"
done

# Page title
N=$(grep_count 'SAW - Scout and Wave' "$WEB_REPO" --include='*.html')
check "HTML title: no 'SAW - Scout and Wave'" "$N"

# Makefile
if [ -f "$WEB_REPO/Makefile" ]; then
  N=$(grep -c '\bsaw\b' "$WEB_REPO/Makefile" 2>/dev/null || true)
  check "Makefile: no bare 'saw' binary reference" "$N"
fi

echo ""

# ── Repo 3: polywave (protocol) ───────────────────────────────────────────────
echo "── polywave protocol ($PROTO_REPO)"
echo ""

# Config file existence
if [ -f "$PROTO_REPO/saw.config.json" ]; then
  red "File: saw.config.json still exists (should be polywave.config.json)"
  FAIL=$((FAIL + 1))
else
  green "File: saw.config.json renamed"
  PASS=$((PASS + 1))
fi

# Hook files
for old in \
  "$PROTO_REPO/hooks/saw-critic-impl-commit.sh" \
  "$PROTO_REPO/hooks/saw-worktree-boundary.sh"
do
  if [ -f "$old" ]; then
    red "Hook file still exists: $old"
    FAIL=$((FAIL + 1))
  else
    green "Hook file renamed: $(basename "$old")"
    PASS=$((PASS + 1))
  fi
done

# Skill source files
for old in \
  "$PROTO_REPO/implementations/claude-code/prompts/saw-skill.md" \
  "$PROTO_REPO/implementations/claude-code/prompts/saw-bootstrap.md"
do
  if [ -f "$old" ]; then
    red "Skill file still exists: $(basename "$old")"
    FAIL=$((FAIL + 1))
  else
    green "Skill file renamed: $(basename "$old")"
    PASS=$((PASS + 1))
  fi
done

# Hook identifier scripts
IMPL_HOOKS="$PROTO_REPO/implementations/claude-code/hooks"
if [ -d "$IMPL_HOOKS" ]; then
  for old in auto_format_saw_agent_names saw_orchestrator_stop saw_critic_impl_commit saw_agent_name; do
    if [ -f "$IMPL_HOOKS/$old" ]; then
      red "Hook identifier still exists: $old"
      FAIL=$((FAIL + 1))
    else
      green "Hook identifier renamed: $old"
      PASS=$((PASS + 1))
    fi
  done
fi

# Protocol markers in behavioral files (must be updated)
for f in \
  "$PROTO_REPO/hooks/polywave-critic-impl-commit.sh" \
  "$PROTO_REPO/implementations/claude-code/prompts/polywave-skill.md" \
  "$PROTO_REPO/implementations/claude-code/prompts/agents/critic-agent.md"
do
  if [ -f "$f" ]; then
    N=$(grep -c '\[SAW:critic:' "$f" 2>/dev/null || true)
    check "Marker in $(basename "$f"): no [SAW:critic:] pattern" "$N"
  fi
done

# SAW_ env vars in hooks and implementation hooks (GAP-H3)
for var in SAW_WORKTREE_ROOT SAW_AGENT_WORKTREE SAW_AGENT_ID SAW_WAVE_NUMBER SAW_IMPL_PATH SAW_BRANCH; do
  N=$(grep_count "$var" "$PROTO_REPO/hooks" "$PROTO_REPO/implementations" --include='*.sh' 2>/dev/null)
  check "Hook env var: no $var" "$N"
done

# .polywave-agent-brief.md in implementation hooks
N=$(grep_count '\.saw-agent-brief' "$PROTO_REPO/implementations" --include='*.sh' 2>/dev/null)
check "Agent brief: no .saw-agent-brief in implementation hooks" "$N"

# [SAW:...] markers in implementation hooks (GAP-H6)
IMPL_HOOKS="$PROTO_REPO/implementations/claude-code/hooks"
if [ -d "$IMPL_HOOKS" ]; then
  N=$(grep_count '\[SAW:' "$IMPL_HOOKS")
  check "Markers: no [SAW:...] in implementation hooks" "$N"
fi

# install.sh ${HOME} form of skills path (GAP-S1)
if [ -f "$PROTO_REPO/install.sh" ]; then
  N=$(grep -c 'skills/saw' "$PROTO_REPO/install.sh" 2>/dev/null || true)
  check "install.sh: no skills/saw (tilde or HOME form)" "$N"
fi

# install.sh hook identifiers
if [ -f "$PROTO_REPO/install.sh" ]; then
  for pattern in 'saw_orchestrator_stop' 'saw_critic_impl_commit' 'auto_format_saw_agent_names' 'saw-skill\.md' 'saw-bootstrap\.md' '/saw scout'; do
    N=$(grep -c "$pattern" "$PROTO_REPO/install.sh" 2>/dev/null || true)
    check "install.sh: no '$pattern'" "$N"
  done
fi

# Prose: broad scan (warn, not fail — historical docs may legitimately have old names)
echo ""
echo "── Broad scan (warnings only — historical IMPL docs and CHANGELOG excluded)"
echo ""

N=$(grep_count 'polywave' "$PROTO_REPO" \
  --include='*.md' --include='*.yaml' --include='*.sh' --include='*.json' \
  --exclude='CHANGELOG.md')
check_warn "Protocol docs: no polywave (excl. CHANGELOG)" "$N" \
  "$(grep_show 'polywave' "$PROTO_REPO" --include='*.md' --include='*.yaml' --include='*.sh' --include='*.json' --exclude='CHANGELOG.md' | head -5)"

N=$(grep_count '\bsawtools\b' "$PROTO_REPO" \
  --include='*.md' --include='*.yaml' --include='*.sh' \
  --exclude='CHANGELOG.md')
check_warn "Protocol docs: no sawtools (excl. CHANGELOG)" "$N" \
  "$(grep_show '\bsawtools\b' "$PROTO_REPO" --include='*.md' | head -5)"

# Shell syntax check on renamed hooks
echo ""
echo "── Shell syntax check"
echo ""
for f in \
  "$PROTO_REPO/hooks/polywave-critic-impl-commit.sh" \
  "$PROTO_REPO/hooks/polywave-worktree-boundary.sh" \
  "$PROTO_REPO/install.sh"
do
  if [ -f "$f" ]; then
    if bash -n "$f" 2>/dev/null; then
      green "Syntax OK: $(basename "$f")"
      PASS=$((PASS + 1))
    else
      red "Syntax error: $f"
      bash -n "$f" 2>&1 | head -5
      FAIL=$((FAIL + 1))
    fi
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Run the migration scripts and re-validate:"
  echo "  scripts/migrate-phase1.sh $GO_REPO"
  echo "  scripts/migrate-phase2.sh $WEB_REPO $GO_REPO"
  echo "  scripts/migrate-phase3.sh $PROTO_REPO"
  exit 1
fi

if [ "$WARN" -gt 0 ]; then
  echo ""
  echo "Warnings require manual review (grep for specifics above)."
  echo "Likely sources: CHANGELOG historical entries, archived IMPL docs."
  exit 0
fi

echo ""
echo "All checks passed. Ready to merge rename/polywave branches."
