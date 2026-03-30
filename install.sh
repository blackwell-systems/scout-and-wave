#!/usr/bin/env bash
# install.sh — Installs Scout-and-Wave skill files and enforcement hooks.
#
# Usage:
#   ./install.sh                 # auto-detect platform (defaults to --claude-code)
#   ./install.sh --claude-code   # skill files + hooks + settings.json + Agent permission
#   ./install.sh --generic       # skill files to ~/.agents/skills/saw/ + hook scripts only
#   ./install.sh --test          # run smoke tests (requires hooks already installed)
#   ./install.sh --uninstall     # remove everything
#
# Safe to run multiple times (idempotent). Backs up settings files before changes.
#
# Prerequisites:
#   - jq (required for --claude-code; optional for --generic)

set -euo pipefail

# ============================================================
# Constants
# ============================================================
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${REPO_DIR}/implementations/claude-code/prompts"
HOOKS_DIR="${REPO_DIR}/implementations/claude-code/hooks"
BIN_DIR="${HOME}/.local/bin"

# Hook script names (universal — same scripts work on any platform)
HOOK_SCRIPTS=(
  "check_scout_boundaries"
  "validate_impl_on_write"
  "block_claire_paths"
  "check_wave_ownership"
  "check_git_ownership"
  "warn_stubs"
  "check_branch_drift"
  "auto_format_saw_agent_names"
  "validate_agent_launch"
  "validate_agent_completion"
  "emit_agent_completion"
  "inject_skill_context"
  "inject_worktree_env"
  "inject_bash_cd"
  "validate_write_paths"
  "verify_worktree_compliance"
)

# Core skill files: source (relative to PROMPTS_DIR) -> target name
SKILL_FILES=(
  "saw-skill.md:SKILL.md"
  "saw-bootstrap.md:saw-bootstrap.md"
  "agent-template.md:agent-template.md"
)

# ============================================================
# Phase functions (platform-independent)
# ============================================================

# Phase 1: Symlink skill files into a target directory
# Args: $1 = target skill directory
install_skill_files() {
  local skill_dir="$1"
  echo "1. Symlinking skill files to ${skill_dir}..."

  mkdir -p "${skill_dir}" "${skill_dir}/agents" "${skill_dir}/references" "${skill_dir}/scripts"

  # Core files
  for entry in "${SKILL_FILES[@]}"; do
    local src="${PROMPTS_DIR}/${entry%%:*}"
    local dst="${skill_dir}/${entry##*:}"
    if [ ! -f "${src}" ]; then
      echo "   WARN: Source not found: ${src}" >&2
      continue
    fi
    ln -sf "${src}" "${dst}"
  done
  echo "   Core files: SKILL.md, saw-bootstrap.md, agent-template.md"

  # Agent definitions
  for src in "${PROMPTS_DIR}"/agents/*.md; do
    [ -f "$src" ] || continue
    ln -sf "$src" "${skill_dir}/agents/$(basename "$src")"
  done
  AGENT_COUNT=$(ls "${PROMPTS_DIR}"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "   Agent definitions: ${AGENT_COUNT} files"

  # Reference files
  for src in "${PROMPTS_DIR}"/references/*.md; do
    [ -f "$src" ] || continue
    ln -sf "$src" "${skill_dir}/references/$(basename "$src")"
  done
  REF_COUNT=$(ls "${PROMPTS_DIR}"/references/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "   Reference files: ${REF_COUNT} files"

  # Scripts
  for src in "${PROMPTS_DIR}"/scripts/*; do
    [ -f "$src" ] || continue
    ln -sf "$src" "${skill_dir}/scripts/$(basename "$src")"
  done
  SCRIPT_COUNT=$(ls "${PROMPTS_DIR}"/scripts/* 2>/dev/null | wc -l | tr -d ' ')
  echo "   Scripts: ${SCRIPT_COUNT} files (inject-context, inject-agent-context)"
  echo ""
}

# Phase 2: Symlink hook scripts to ~/.local/bin
install_hook_scripts() {
  echo "2. Symlinking hook scripts to ${BIN_DIR}..."
  mkdir -p "${BIN_DIR}"

  local ok=0 warn=0
  for hook in "${HOOK_SCRIPTS[@]}"; do
    local src="${HOOKS_DIR}/${hook}"
    local dst="${BIN_DIR}/${hook}"
    if [ ! -f "$src" ]; then
      echo "   WARN: Hook not found: ${src}" >&2
      warn=$((warn + 1))
      continue
    fi
    chmod +x "$src"
    ln -sf "$src" "$dst"
    ok=$((ok + 1))
  done
  echo "   ${ok} hooks installed${warn:+, ${warn} warnings}"
  echo ""
}

# Phase 3: Verify skill files and hook scripts exist
# Args: $1 = skill directory
verify_installation() {
  local skill_dir="$1"
  local step_num="$2"
  echo "${step_num}. Verifying installation..."

  local errors=0

  # Skill files
  for f in SKILL.md saw-bootstrap.md agent-template.md; do
    if [ -L "${skill_dir}/${f}" ] && [ -e "${skill_dir}/${f}" ]; then
      echo "   OK  ${f}"
    else
      echo "   FAIL  ${f}" >&2
      errors=$((errors + 1))
    fi
  done

  # Agent symlinks
  for f in "${skill_dir}"/agents/*.md; do
    [ -L "$f" ] && [ -e "$f" ] && continue
    echo "   FAIL  agents/$(basename "$f")" >&2
    errors=$((errors + 1))
  done
  echo "   OK  agents/ (${AGENT_COUNT} definitions)"

  # References
  for f in "${skill_dir}"/references/*.md; do
    [ -L "$f" ] && [ -e "$f" ] && continue
    echo "   FAIL  references/$(basename "$f")" >&2
    errors=$((errors + 1))
  done
  echo "   OK  references/ (${REF_COUNT} files)"

  # Critical hooks
  for hook in check_scout_boundaries validate_agent_launch validate_agent_completion inject_skill_context; do
    if [ -x "${BIN_DIR}/${hook}" ]; then
      echo "   OK  ${hook}"
    else
      echo "   FAIL  ${hook}" >&2
      errors=$((errors + 1))
    fi
  done

  echo ""
  return "$errors"
}

# Smoke test: run scout boundary hook with known inputs
smoke_test() {
  local step_num="$1"
  echo "${step_num}. Smoke test..."
  local errors=0

  local valid_input='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}'
  if echo "$valid_input" | "${BIN_DIR}/check_scout_boundaries" &> /dev/null; then
    echo "   OK  Scout boundary hook (valid path accepted)"
  else
    echo "   FAIL  Scout boundary hook" >&2
    errors=$((errors + 1))
  fi

  local invalid_input='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"src/main.go"}}'
  if ! echo "$invalid_input" | "${BIN_DIR}/check_scout_boundaries" &> /dev/null; then
    echo "   OK  Scout boundary hook (invalid path blocked)"
  else
    echo "   FAIL  Scout boundary hook (should have blocked)" >&2
    errors=$((errors + 1))
  fi

  # Test inject_bash_cd passthrough (no worktree)
  local no_worktree='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  if echo "$no_worktree" | "${BIN_DIR}/inject_bash_cd" &> /dev/null; then
    echo "   OK  Bash CD injection hook (passthrough)"
  else
    echo "   FAIL  Bash CD injection hook" >&2
    errors=$((errors + 1))
  fi

  echo ""
  return "$errors"
}

# ============================================================
# Platform: Claude Code
# ============================================================
install_claude_code() {
  local settings_file="${HOME}/.claude/settings.json"
  local skill_dir="${HOME}/.claude/skills/saw"

  echo "Installing Scout-and-Wave for Claude Code..."
  echo ""

  # Phase 1 + 2: universal
  install_skill_files "$skill_dir"
  install_hook_scripts

  # Phase 3: Register hooks in settings.json
  echo "3. Configuring ${settings_file}..."

  if [ ! -f "$settings_file" ]; then
    mkdir -p "$(dirname "$settings_file")"
    echo '{}' > "$settings_file"
    echo "   Created new settings.json"
  fi

  cp "$settings_file" "$settings_file.backup"
  echo "   Backed up to settings.json.backup"

  # Helper: add a hook if not already present
  add_hook() {
    local event="$1" matcher="$2" command="$3" desc="$4" async="${5:-false}"
    local hook_name
    hook_name=$(basename "$command")

    local existing
    existing=$(jq -r ".hooks.${event} // [] | map(select(.hooks[]?.command | contains(\"${hook_name}\"))) | length" "$settings_file")
    [ "$existing" -gt 0 ] && return 0

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
      "$settings_file" > "$settings_file.tmp"
    mv "$settings_file.tmp" "$settings_file"
    echo "   + ${event}: ${hook_name} (${desc})"
  }

  # PreToolUse
  add_hook "PreToolUse" "Write|Edit" "${BIN_DIR}/check_scout_boundaries" "I6 Scout write boundaries"
  add_hook "PreToolUse" "Write|Edit|Bash" "${BIN_DIR}/block_claire_paths" ".claire path blocker"
  add_hook "PreToolUse" "Write|Edit|NotebookEdit" "${BIN_DIR}/check_wave_ownership" "I1 file ownership"
  add_hook "PreToolUse" "Agent" "${BIN_DIR}/validate_agent_launch" "H5 pre-launch validation"
  add_hook "PreToolUse" "Bash" "${BIN_DIR}/inject_bash_cd" "E43 Bash cd injection"
  add_hook "PreToolUse" "Write|Edit" "${BIN_DIR}/validate_write_paths" "E43 Write path validation"

  # PostToolUse
  add_hook "PostToolUse" "Write" "${BIN_DIR}/validate_impl_on_write" "E16 IMPL validation"
  add_hook "PostToolUse" "Bash" "${BIN_DIR}/check_git_ownership" "I1 git ownership" "true"
  add_hook "PostToolUse" "Write|Edit" "${BIN_DIR}/warn_stubs" "H3 stub detection"
  add_hook "PostToolUse" "Bash" "${BIN_DIR}/check_branch_drift" "H4 branch drift"

  # SubagentStart
  add_hook "SubagentStart" "" "${BIN_DIR}/inject_worktree_env" "E43 env var injection"

  # SubagentStop
  add_hook "SubagentStop" "" "${BIN_DIR}/verify_worktree_compliance" "E42/I5 compliance check"
  local comp_existing
  comp_existing=$(jq -r '.hooks.SubagentStop // [] | map(select(.hooks[]?.command | contains("validate_agent_completion"))) | length' "$settings_file")
  if [ "$comp_existing" -eq 0 ]; then
    local comp_hook
    comp_hook=$(jq -n \
      --arg validate "${BIN_DIR}/validate_agent_completion" \
      --arg emit "${BIN_DIR}/emit_agent_completion" \
      '{hooks: [{type: "command", command: $validate, timeout: 10}, {type: "command", command: $emit, async: true}]}')
    jq --argjson hook "$comp_hook" \
      '.hooks.SubagentStop = (.hooks.SubagentStop // []) + [$hook]' \
      "$settings_file" > "$settings_file.tmp"
    mv "$settings_file.tmp" "$settings_file"
    echo "   + SubagentStop: validate_agent_completion + emit_agent_completion (E42)"
  fi

  # UserPromptSubmit
  add_hook "UserPromptSubmit" "" "${BIN_DIR}/inject_skill_context" "Tier 3 context injection"

  # Phase 4: Agent permission
  local has_agent
  has_agent=$(jq -r '.permissions.allow // [] | map(select(. == "Agent")) | length' "$settings_file")
  if [ "$has_agent" -eq 0 ]; then
    jq '.permissions.allow = ((.permissions.allow // []) + ["Agent"] | unique)' \
      "$settings_file" > "$settings_file.tmp"
    mv "$settings_file.tmp" "$settings_file"
    echo "   + permissions.allow: Agent (required for SAW agent launches)"
  else
    echo "   Agent permission already configured"
  fi

  echo ""

  # Phase 5: Verify
  verify_installation "$skill_dir" "4" || true
  local verify_errors=$?

  # Check settings.json hooks
  for event in PreToolUse PostToolUse SubagentStop UserPromptSubmit; do
    local count
    count=$(jq -r ".hooks.${event} // [] | length" "$settings_file")
    if [ "$count" -gt 0 ]; then
      echo "   OK  settings.json ${event} (${count} entries)"
    else
      echo "   FAIL  settings.json ${event} has no entries" >&2
      verify_errors=$((verify_errors + 1))
    fi
  done

  # Check Agent permission
  has_agent=$(jq -r '.permissions.allow // [] | map(select(. == "Agent")) | length' "$settings_file")
  if [ "$has_agent" -gt 0 ]; then
    echo "   OK  permissions.allow includes Agent"
  else
    echo "   FAIL  permissions.allow missing Agent" >&2
    verify_errors=$((verify_errors + 1))
  fi

  echo ""

  if [ "$verify_errors" -gt 0 ]; then
    echo "Installation completed with ${verify_errors} error(s). Check warnings above."
    exit 1
  fi

  # Phase 6: Smoke test
  smoke_test "5" || {
    echo "Smoke test failed."
    exit 1
  }

  echo "Installation complete (Claude Code). 15 hooks active:"
  echo ""
  echo "  SubagentStart:     inject_worktree_env        (E43 env var injection)"
  echo "  PreToolUse:        inject_bash_cd             (E43 Bash cd injection)"
  echo "  PreToolUse:        validate_write_paths       (E43 Write path validation)"
  echo "  PreToolUse:        check_scout_boundaries     (I6 Scout write boundaries)"
  echo "  PreToolUse:        block_claire_paths         (.claire path blocker)"
  echo "  PreToolUse:        check_wave_ownership       (I1 file ownership enforcement)"
  echo "  PreToolUse:        validate_agent_launch      (H5 pre-launch validation gate)"
  echo "  PostToolUse:       validate_impl_on_write     (E16 IMPL doc validation)"
  echo "  PostToolUse:       check_git_ownership        (I1 git-level ownership) [async]"
  echo "  PostToolUse:       warn_stubs                 (H3 stub pattern detection)"
  echo "  PostToolUse:       check_branch_drift         (H4 branch drift detection)"
  echo "  SubagentStop:      verify_worktree_compliance (E42/I5 compliance check)"
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
}

# ============================================================
# Platform: Generic (Agent Skills spec convention)
# ============================================================
install_generic() {
  local skill_dir="${HOME}/.agents/skills/saw"

  echo "Installing Scout-and-Wave (generic / Agent Skills convention)..."
  echo ""

  # Phase 1 + 2: universal
  install_skill_files "$skill_dir"
  install_hook_scripts

  # Phase 3: Verify
  verify_installation "$skill_dir" "3" || true
  local verify_errors=$?
  echo ""

  if [ "$verify_errors" -gt 0 ]; then
    echo "Installation completed with ${verify_errors} error(s)."
    exit 1
  fi

  # Phase 4: Smoke test
  smoke_test "4" || {
    echo "Smoke test failed."
    exit 1
  }

  echo "Installation complete (generic)."
  echo ""
  echo "Skill files: ${skill_dir}/"
  echo "Hook scripts: ${BIN_DIR}/"
  echo ""
  echo "Hook registration is platform-specific. You need to register the hooks"
  echo "in your agent platform's configuration. The hook scripts in ${BIN_DIR}/"
  echo "read JSON from stdin and return JSON — see docs/HOOKS.md for the protocol."
  echo ""
  echo "Next steps:"
  echo "  1. Install sawtools:  go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest"
  echo "  2. Register hooks in your platform's config (see docs/HOOKS.md)"
  echo "  3. Init your project: cd your-project && sawtools init"
  echo ""
  echo "  Full guide: docs/GETTING_STARTED.md"
}

# ============================================================
# Uninstall
# ============================================================
do_uninstall() {
  echo "Uninstalling Scout-and-Wave..."
  echo ""

  # Remove all known skill directories
  for skill_dir in "${HOME}/.claude/skills/saw" "${HOME}/.agents/skills/saw"; do
    if [ -d "$skill_dir" ]; then
      rm -rf "$skill_dir"
      echo "  Removed ${skill_dir}"
    fi
  done

  # Remove hook symlinks
  for hook in "${HOOK_SCRIPTS[@]}"; do
    if [ -L "${BIN_DIR}/${hook}" ]; then
      rm "${BIN_DIR}/${hook}"
      echo "  Removed ${BIN_DIR}/${hook}"
    fi
  done

  echo ""
  echo "Hook registrations in ~/.claude/settings.json were NOT removed."
  echo "Edit that file manually to remove SAW hook entries if desired."
  exit 0
}

# ============================================================
# Entry point
# ============================================================

if [ ! -d "${PROMPTS_DIR}" ]; then
  echo "ERROR: Prompts directory not found at ${PROMPTS_DIR}" >&2
  echo "       Is this script in the scout-and-wave repo root?" >&2
  exit 1
fi

PLATFORM="${1:-}"

case "$PLATFORM" in
  --test)
    # Run smoke tests only (assumes hooks already installed)
    if ! smoke_test "1"; then
      echo "Smoke tests failed." >&2
      exit 1
    fi
    echo "All smoke tests passed."
    exit 0
    ;;
  --uninstall)
    do_uninstall
    ;;
  --claude-code)
    if ! command -v jq &> /dev/null; then
      echo "ERROR: jq not found (required for Claude Code installation)" >&2
      echo "       Install via: brew install jq" >&2
      exit 1
    fi
    install_claude_code
    ;;
  --generic)
    install_generic
    ;;
  "")
    # Auto-detect: if ~/.claude exists, assume Claude Code
    if [ -d "${HOME}/.claude" ]; then
      if ! command -v jq &> /dev/null; then
        echo "ERROR: jq not found (required for Claude Code installation)" >&2
        echo "       Install via: brew install jq" >&2
        exit 1
      fi
      echo "Detected Claude Code (~/.claude exists). Use --generic to override."
      echo ""
      install_claude_code
    else
      echo "No Claude Code detected. Installing with generic Agent Skills layout."
      echo "Use --claude-code to force Claude Code installation."
      echo ""
      install_generic
    fi
    ;;
  *)
    echo "Usage: install.sh [--claude-code | --generic | --test | --uninstall]" >&2
    exit 1
    ;;
esac
