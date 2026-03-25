#!/usr/bin/env bash
# install.sh — Installs Scout-and-Wave for Claude Code.
#
# Usage:
#   ./install.sh          # from the repo root
#   /path/to/install.sh   # from anywhere
#
# Installs:
#   1. Skill files symlinked to ~/.claude/skills/saw/
#   2. Enforcement hooks symlinked to ~/.local/bin/
#   3. Hook registrations in ~/.claude/settings.json
#
# Safe to run multiple times (idempotent). Backs up settings.json before changes.
#
# Prerequisites:
#   - jq (for settings.json manipulation)
#   - Claude Code installed
#
# To uninstall, run: ./install.sh --uninstall

set -euo pipefail

# Resolve the repo root (directory containing this script)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${REPO_DIR}/implementations/claude-code/prompts"
HOOKS_DIR="${REPO_DIR}/implementations/claude-code/hooks"
SKILL_DIR="${HOME}/.claude/skills/saw"
BIN_DIR="${HOME}/.local/bin"
SETTINGS_FILE="${HOME}/.claude/settings.json"

if [ ! -d "${PROMPTS_DIR}" ]; then
  echo "ERROR: Prompts directory not found at ${PROMPTS_DIR}" >&2
  echo "       Is this script in the scout-and-wave repo root?" >&2
  exit 1
fi

# --- Uninstall mode ---
if [ "${1:-}" = "--uninstall" ]; then
  echo "Uninstalling Scout-and-Wave..."
  echo ""

  # Remove skill directory
  if [ -d "${SKILL_DIR}" ]; then
    rm -rf "${SKILL_DIR}"
    echo "  Removed ${SKILL_DIR}"
  fi

  # Remove hook symlinks
  for hook in check_scout_boundaries validate_impl_on_write block_claire_paths \
              check_wave_ownership check_git_ownership warn_stubs check_branch_drift \
              validate_agent_launch validate_agent_completion emit_agent_completion \
              inject_skill_context; do
    if [ -L "${BIN_DIR}/${hook}" ]; then
      rm "${BIN_DIR}/${hook}"
      echo "  Removed ${BIN_DIR}/${hook}"
    fi
  done

  echo ""
  echo "Hook registrations in ${SETTINGS_FILE} were NOT removed."
  echo "Edit that file manually to remove SAW hook entries if desired."
  exit 0
fi

# --- Check prerequisites ---
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq not found (required for settings.json manipulation)" >&2
  echo "       Install via: brew install jq" >&2
  exit 1
fi

echo "Installing Scout-and-Wave for Claude Code..."
echo ""

# ============================================================
# Step 1: Skill files
# ============================================================
echo "1. Symlinking skill files to ${SKILL_DIR}..."

mkdir -p "${SKILL_DIR}" "${SKILL_DIR}/agents" "${SKILL_DIR}/references" "${SKILL_DIR}/scripts"

# Core skill files
declare -a SKILL_FILES=(
  "saw-skill.md:SKILL.md"
  "saw-bootstrap.md:saw-bootstrap.md"
  "agent-template.md:agent-template.md"
)

for entry in "${SKILL_FILES[@]}"; do
  src="${PROMPTS_DIR}/${entry%%:*}"
  dst="${SKILL_DIR}/${entry##*:}"
  if [ ! -f "${src}" ]; then
    echo "   WARN: Source not found: ${src}" >&2
    continue
  fi
  ln -sf "${src}" "${dst}"
done
echo "   Core files: SKILL.md, saw-bootstrap.md, agent-template.md"

# Agent definitions (all .md files in agents/)
for src in "${PROMPTS_DIR}"/agents/*.md; do
  [ -f "$src" ] || continue
  ln -sf "$src" "${SKILL_DIR}/agents/$(basename "$src")"
done
agent_count=$(ls "${PROMPTS_DIR}"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "   Agent definitions: ${agent_count} files"

# Reference files (all .md files in references/)
for src in "${PROMPTS_DIR}"/references/*.md; do
  [ -f "$src" ] || continue
  ln -sf "$src" "${SKILL_DIR}/references/$(basename "$src")"
done
ref_count=$(ls "${PROMPTS_DIR}"/references/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "   Reference files: ${ref_count} files"

# Scripts (inject-context etc.)
for src in "${PROMPTS_DIR}"/scripts/*; do
  [ -f "$src" ] || continue
  ln -sf "$src" "${SKILL_DIR}/scripts/$(basename "$src")"
done
echo "   Scripts: inject-context"

echo ""

# ============================================================
# Step 2: Hook scripts
# ============================================================
echo "2. Symlinking hook scripts to ${BIN_DIR}..."

mkdir -p "${BIN_DIR}"

# Hook scripts to install: filename in hooks/ directory
declare -a HOOK_SCRIPTS=(
  "check_scout_boundaries"
  "validate_impl_on_write"
  "block_claire_paths"
  "check_wave_ownership"
  "check_git_ownership"
  "warn_stubs"
  "check_branch_drift"
  "validate_agent_launch"
  "validate_agent_completion"
  "emit_agent_completion"
  "inject_skill_context"
)

hook_ok=0
hook_warn=0
for hook in "${HOOK_SCRIPTS[@]}"; do
  src="${HOOKS_DIR}/${hook}"
  dst="${BIN_DIR}/${hook}"
  if [ ! -f "$src" ]; then
    echo "   WARN: Hook not found: ${src}" >&2
    hook_warn=$((hook_warn + 1))
    continue
  fi
  chmod +x "$src"
  ln -sf "$src" "$dst"
  hook_ok=$((hook_ok + 1))
done
echo "   ${hook_ok} hooks installed${hook_warn:+, ${hook_warn} warnings}"
echo ""

# ============================================================
# Step 3: Register hooks in settings.json
# ============================================================
echo "3. Configuring ${SETTINGS_FILE}..."

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
  echo "   Created new settings.json"
fi

# Backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
echo "   Backed up to settings.json.backup"

# Helper: add a hook if not already present
# Usage: add_hook <event> <matcher> <command> <description> [async]
add_hook() {
  local event="$1" matcher="$2" command="$3" desc="$4" async="${5:-false}"

  local hook_name
  hook_name=$(basename "$command")

  # Check if already registered
  local existing
  existing=$(jq -r ".hooks.${event} // [] | map(select(.hooks[]?.command | contains(\"${hook_name}\"))) | length" "$SETTINGS_FILE")

  if [ "$existing" -gt 0 ]; then
    return 0  # Already configured
  fi

  local hook_json
  if [ "$async" = "true" ]; then
    hook_json=$(jq -n --arg cmd "$command" --arg m "$matcher" \
      'if $m == "" then {hooks: [{type: "command", command: $cmd, async: true}]}
       else {matcher: $m, hooks: [{type: "command", command: $cmd, async: true}]} end')
  else
    hook_json=$(jq -n --arg cmd "$command" --arg m "$matcher" \
      'if $m == "" then {hooks: [{type: "command", command: $cmd}]}
       else {matcher: $m, hooks: [{type: "command", command: $cmd}]} end')
  fi

  jq --argjson hook "$hook_json" \
    ".hooks.${event} = (.hooks.${event} // []) + [\$hook]" \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   + ${event}: ${hook_name} (${desc})"
}

# PreToolUse hooks
add_hook "PreToolUse" "Write|Edit" "${BIN_DIR}/check_scout_boundaries" "I6 Scout write boundaries"
add_hook "PreToolUse" "Write|Edit|Bash" "${BIN_DIR}/block_claire_paths" ".claire path blocker"
add_hook "PreToolUse" "Write|Edit|NotebookEdit" "${BIN_DIR}/check_wave_ownership" "I1 file ownership"
add_hook "PreToolUse" "Agent" "${BIN_DIR}/validate_agent_launch" "H5 pre-launch validation"

# PostToolUse hooks
add_hook "PostToolUse" "Write" "${BIN_DIR}/validate_impl_on_write" "E16 IMPL validation"
add_hook "PostToolUse" "Bash" "${BIN_DIR}/check_git_ownership" "I1 git ownership" "true"
add_hook "PostToolUse" "Write|Edit" "${BIN_DIR}/warn_stubs" "H3 stub detection"
add_hook "PostToolUse" "Bash" "${BIN_DIR}/check_branch_drift" "H4 branch drift"

# SubagentStop hooks — use combined hook entry (validation + emit)
COMPLETION_EXISTING=$(jq -r '.hooks.SubagentStop // [] | map(select(.hooks[]?.command | contains("validate_agent_completion"))) | length' "$SETTINGS_FILE")
if [ "$COMPLETION_EXISTING" -eq 0 ]; then
  COMPLETION_HOOK=$(jq -n \
    --arg validate "${BIN_DIR}/validate_agent_completion" \
    --arg emit "${BIN_DIR}/emit_agent_completion" \
    '{hooks: [{type: "command", command: $validate, timeout: 10}, {type: "command", command: $emit, async: true}]}')
  jq --argjson hook "$COMPLETION_HOOK" \
    '.hooks.SubagentStop = (.hooks.SubagentStop // []) + [$hook]' \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   + SubagentStop: validate_agent_completion + emit_agent_completion (E42)"
fi

# UserPromptSubmit hook
add_hook "UserPromptSubmit" "" "${BIN_DIR}/inject_skill_context" "Tier 3 context injection"

echo ""

# ============================================================
# Step 4: Verify
# ============================================================
echo "4. Verifying installation..."

errors=0

# Check skill files
for f in SKILL.md saw-bootstrap.md agent-template.md; do
  if [ -L "${SKILL_DIR}/${f}" ] && [ -e "${SKILL_DIR}/${f}" ]; then
    echo "   OK  ${f}"
  else
    echo "   FAIL  ${f}" >&2
    errors=$((errors + 1))
  fi
done

# Check agent symlinks
for f in "${SKILL_DIR}"/agents/*.md; do
  [ -L "$f" ] && [ -e "$f" ] && continue
  echo "   FAIL  agents/$(basename "$f")" >&2
  errors=$((errors + 1))
done
echo "   OK  agents/ (${agent_count} definitions)"

# Check references
for f in "${SKILL_DIR}"/references/*.md; do
  [ -L "$f" ] && [ -e "$f" ] && continue
  echo "   FAIL  references/$(basename "$f")" >&2
  errors=$((errors + 1))
done
echo "   OK  references/ (${ref_count} files)"

# Check critical hooks
for hook in check_scout_boundaries validate_agent_launch validate_agent_completion inject_skill_context; do
  if [ -x "${BIN_DIR}/${hook}" ]; then
    echo "   OK  ${hook}"
  else
    echo "   FAIL  ${hook}" >&2
    errors=$((errors + 1))
  fi
done

# Check settings.json has hooks
for event in PreToolUse PostToolUse SubagentStop UserPromptSubmit; do
  count=$(jq -r ".hooks.${event} // [] | length" "$SETTINGS_FILE")
  if [ "$count" -gt 0 ]; then
    echo "   OK  settings.json ${event} (${count} entries)"
  else
    echo "   FAIL  settings.json ${event} has no entries" >&2
    errors=$((errors + 1))
  fi
done

echo ""

if [ "$errors" -gt 0 ]; then
  echo "Installation completed with ${errors} error(s). Check warnings above."
  exit 1
fi

# Quick smoke test
echo "5. Smoke test..."
TEST_INPUT='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}'
if echo "$TEST_INPUT" | "${BIN_DIR}/check_scout_boundaries" &> /dev/null; then
  echo "   OK  Scout boundary hook (valid path accepted)"
else
  echo "   FAIL  Scout boundary hook" >&2
  errors=$((errors + 1))
fi

TEST_INPUT='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"src/main.go"}}'
if ! echo "$TEST_INPUT" | "${BIN_DIR}/check_scout_boundaries" &> /dev/null; then
  echo "   OK  Scout boundary hook (invalid path blocked)"
else
  echo "   FAIL  Scout boundary hook (should have blocked)" >&2
  errors=$((errors + 1))
fi

echo ""

if [ "$errors" -gt 0 ]; then
  echo "Installation completed with ${errors} error(s)."
  exit 1
fi

echo "Installation complete. 11 hooks active:"
echo ""
echo "  PreToolUse:        check_scout_boundaries    (I6 Scout write boundaries)"
echo "  PreToolUse:        block_claire_paths         (.claire path blocker)"
echo "  PreToolUse:        check_wave_ownership       (I1 file ownership enforcement)"
echo "  PreToolUse:        validate_agent_launch      (H5 pre-launch validation gate)"
echo "  PostToolUse:       validate_impl_on_write     (E16 IMPL doc validation)"
echo "  PostToolUse:       check_git_ownership        (I1 git-level ownership) [async]"
echo "  PostToolUse:       warn_stubs                 (H3 stub pattern detection)"
echo "  PostToolUse:       check_branch_drift         (H4 branch drift detection)"
echo "  SubagentStop:      validate_agent_completion  (E42 protocol compliance)"
echo "  SubagentStop:      emit_agent_completion      (E42 observability) [async]"
echo "  UserPromptSubmit:  inject_skill_context       (Tier 3 context injection)"
echo ""
echo "Next steps:"
echo "  1. Install sawtools:  go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest"
echo "  2. Init your project: cd your-project && sawtools init"
echo "  3. First scout:       /saw scout \"your feature description\""
echo ""
echo "  Full guide: docs/GETTING_STARTED.md"
