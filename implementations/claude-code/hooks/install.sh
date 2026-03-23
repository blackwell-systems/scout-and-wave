#!/usr/bin/env bash
# Scout Boundaries Hook Installer
# Installs I6 enforcement hook for CLI Scout agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/check_scout_boundaries"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate_impl_on_write"
CLAIRE_SCRIPT="$SCRIPT_DIR/block_claire_paths"
WAVE_OWNERSHIP_SCRIPT="$SCRIPT_DIR/check_wave_ownership"
GIT_OWNERSHIP_SCRIPT="$SCRIPT_DIR/check_git_ownership"
SYMLINK_PATH="$HOME/.local/bin/check_scout_boundaries"
VALIDATE_SYMLINK="$HOME/.local/bin/validate_impl_on_write"
CLAIRE_SYMLINK="$HOME/.local/bin/block_claire_paths"
WAVE_OWNERSHIP_SYMLINK="$HOME/.local/bin/check_wave_ownership"
GIT_OWNERSHIP_SYMLINK="$HOME/.local/bin/check_git_ownership"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🔧 Installing SAW hooks..."
echo

# Step 1: Create symlink
echo "1. Creating symlink..."
mkdir -p "$HOME/.local/bin"
if [ -L "$SYMLINK_PATH" ]; then
  echo "   ✓ Symlink already exists (updating target)"
  ln -sf "$HOOK_SCRIPT" "$SYMLINK_PATH"
elif [ -e "$SYMLINK_PATH" ]; then
  echo "   ✗ Error: $SYMLINK_PATH exists but is not a symlink"
  echo "     Move or delete it, then re-run installer"
  exit 1
else
  ln -sf "$HOOK_SCRIPT" "$SYMLINK_PATH"
  echo "   ✓ Created symlink: $SYMLINK_PATH"
fi
chmod +x "$HOOK_SCRIPT"

# Validate IMPL on write hook
echo "   Installing validate_impl_on_write..."
if [ -L "$VALIDATE_SYMLINK" ]; then
  ln -sf "$VALIDATE_SCRIPT" "$VALIDATE_SYMLINK"
  echo "   ✓ Symlink updated: $VALIDATE_SYMLINK"
elif [ -e "$VALIDATE_SYMLINK" ]; then
  echo "   ✗ Error: $VALIDATE_SYMLINK exists but is not a symlink"
  exit 1
else
  ln -sf "$VALIDATE_SCRIPT" "$VALIDATE_SYMLINK"
  echo "   ✓ Created symlink: $VALIDATE_SYMLINK"
fi
chmod +x "$VALIDATE_SCRIPT"

# block_claire_paths hook (known model hallucination: .claire instead of .claude)
echo "   Installing block_claire_paths..."
if [ -L "$CLAIRE_SYMLINK" ]; then
  ln -sf "$CLAIRE_SCRIPT" "$CLAIRE_SYMLINK"
  echo "   ✓ Symlink updated: $CLAIRE_SYMLINK"
elif [ -e "$CLAIRE_SYMLINK" ]; then
  echo "   ✗ Error: $CLAIRE_SYMLINK exists but is not a symlink"
  exit 1
else
  ln -sf "$CLAIRE_SCRIPT" "$CLAIRE_SYMLINK"
  echo "   ✓ Created symlink: $CLAIRE_SYMLINK"
fi
chmod +x "$CLAIRE_SCRIPT"

# check_wave_ownership hook (I1 enforcement for Wave agents)
echo "   Installing check_wave_ownership..."
if [ -L "$WAVE_OWNERSHIP_SYMLINK" ]; then
  ln -sf "$WAVE_OWNERSHIP_SCRIPT" "$WAVE_OWNERSHIP_SYMLINK"
  echo "   ✓ Symlink updated: $WAVE_OWNERSHIP_SYMLINK"
elif [ -e "$WAVE_OWNERSHIP_SYMLINK" ]; then
  echo "   ✗ Error: $WAVE_OWNERSHIP_SYMLINK exists but is not a symlink"
  exit 1
else
  ln -sf "$WAVE_OWNERSHIP_SCRIPT" "$WAVE_OWNERSHIP_SYMLINK"
  echo "   ✓ Created symlink: $WAVE_OWNERSHIP_SYMLINK"
fi
chmod +x "$WAVE_OWNERSHIP_SCRIPT"

# check_git_ownership hook (I1 layer 2: catch git-level modifications outside ownership)
echo "   Installing check_git_ownership..."
if [ -L "$GIT_OWNERSHIP_SYMLINK" ]; then
  ln -sf "$GIT_OWNERSHIP_SCRIPT" "$GIT_OWNERSHIP_SYMLINK"
  echo "   ✓ Symlink updated: $GIT_OWNERSHIP_SYMLINK"
elif [ -e "$GIT_OWNERSHIP_SYMLINK" ]; then
  echo "   ✗ Error: $GIT_OWNERSHIP_SYMLINK exists but is not a symlink"
  exit 1
else
  ln -sf "$GIT_OWNERSHIP_SCRIPT" "$GIT_OWNERSHIP_SYMLINK"
  echo "   ✓ Created symlink: $GIT_OWNERSHIP_SYMLINK"
fi
chmod +x "$GIT_OWNERSHIP_SCRIPT"
echo

# Step 2: Configure settings.json
echo "2. Configuring ~/.claude/settings.json..."

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "   Creating $SETTINGS_FILE (did not exist)"
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "   ✗ Error: jq not found (required for JSON manipulation)"
  echo "     Install via: brew install jq"
  exit 1
fi

# Backup settings.json
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
echo "   Backed up to: $SETTINGS_FILE.backup"

# Define the hook configuration to merge
HOOK_CONFIG=$(cat <<EOF
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.local/bin/check_scout_boundaries"
    }
  ]
}
EOF
)

# Check if PreToolUse hook already exists
EXISTING=$(jq -r '.hooks.PreToolUse // [] | map(select(.hooks[]?.command | contains("check_scout_boundaries"))) | length' "$SETTINGS_FILE")

if [ "$EXISTING" -gt 0 ]; then
  echo "   ✓ PreToolUse hook already configured (skipping)"
else
  # Merge the hook config into settings.json
  jq --argjson hook "$HOOK_CONFIG" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PreToolUse hook configuration"
fi

# Add PostToolUse validation hook
VALIDATE_HOOK_CONFIG=$(cat <<EOF
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.local/bin/validate_impl_on_write"
    }
  ]
}
EOF
)

VALIDATE_EXISTING=$(jq -r '.hooks.PostToolUse // [] | map(select(.hooks[]?.command | contains("validate_impl_on_write"))) | length' "$SETTINGS_FILE")

if [ "$VALIDATE_EXISTING" -gt 0 ]; then
  echo "   ✓ PostToolUse validation hook already configured (skipping)"
else
  jq --argjson hook "$VALIDATE_HOOK_CONFIG" '
    .hooks.PostToolUse = (.hooks.PostToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PostToolUse IMPL validation hook"
fi

# Add .claire path blocker hook
CLAIRE_HOOK_CONFIG=$(cat <<EOF
{
  "matcher": "Write|Edit|Bash",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.local/bin/block_claire_paths"
    }
  ]
}
EOF
)

CLAIRE_EXISTING=$(jq -r '.hooks.PreToolUse // [] | map(select(.hooks[]?.command | contains("block_claire_paths"))) | length' "$SETTINGS_FILE")

if [ "$CLAIRE_EXISTING" -gt 0 ]; then
  echo "   ✓ .claire path blocker already configured (skipping)"
else
  jq --argjson hook "$CLAIRE_HOOK_CONFIG" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PreToolUse .claire path blocker"
fi

# Add wave ownership hook (I1 enforcement for Wave agents)
WAVE_OWNERSHIP_HOOK_CONFIG=$(cat <<EOF
{
  "matcher": "Write|Edit|NotebookEdit",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.local/bin/check_wave_ownership"
    }
  ]
}
EOF
)

WAVE_OWNERSHIP_EXISTING=$(jq -r '.hooks.PreToolUse // [] | map(select(.hooks[]?.command | contains("check_wave_ownership"))) | length' "$SETTINGS_FILE")

if [ "$WAVE_OWNERSHIP_EXISTING" -gt 0 ]; then
  echo "   ✓ Wave ownership hook already configured (skipping)"
else
  jq --argjson hook "$WAVE_OWNERSHIP_HOOK_CONFIG" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PreToolUse wave ownership hook (I1)"
fi
echo

# Add git ownership hook (I1 layer 2: PostToolUse on Bash for git operations)
GIT_OWNERSHIP_HOOK_CONFIG=$(cat <<EOF
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.local/bin/check_git_ownership"
    }
  ]
}
EOF
)

GIT_OWNERSHIP_EXISTING=$(jq -r '.hooks.PostToolUse // [] | map(select(.hooks[]?.command | contains("check_git_ownership"))) | length' "$SETTINGS_FILE")

if [ "$GIT_OWNERSHIP_EXISTING" -gt 0 ]; then
  echo "   ✓ Git ownership hook already configured (skipping)"
else
  jq --argjson hook "$GIT_OWNERSHIP_HOOK_CONFIG" '
    .hooks.PostToolUse = (.hooks.PostToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PostToolUse git ownership hook (I1 layer 2)"
fi
echo

# Step 3: Verify installation
echo "3. Verifying installation..."

# Check symlinks
if [ -x "$SYMLINK_PATH" ]; then
  echo "   ✓ Scout boundaries hook executable: $SYMLINK_PATH"
else
  echo "   ✗ Scout boundaries hook not executable"
  exit 1
fi

if [ -x "$VALIDATE_SYMLINK" ]; then
  echo "   ✓ IMPL validation hook executable: $VALIDATE_SYMLINK"
else
  echo "   ✗ IMPL validation hook not executable"
  exit 1
fi

if [ -x "$WAVE_OWNERSHIP_SYMLINK" ]; then
  echo "   ✓ Wave ownership hook executable: $WAVE_OWNERSHIP_SYMLINK"
else
  echo "   ✗ Wave ownership hook not executable"
  exit 1
fi

if [ -x "$GIT_OWNERSHIP_SYMLINK" ]; then
  echo "   ✓ Git ownership hook executable: $GIT_OWNERSHIP_SYMLINK"
else
  echo "   ✗ Git ownership hook not executable"
  exit 1
fi

# Check settings.json
if jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | contains("check_scout_boundaries"))' "$SETTINGS_FILE" &> /dev/null; then
  echo "   ✓ PreToolUse hook configured in settings.json"
else
  echo "   ✗ PreToolUse hook not found in settings.json"
  exit 1
fi

if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("validate_impl_on_write"))' "$SETTINGS_FILE" &> /dev/null; then
  echo "   ✓ PostToolUse validation hook configured in settings.json"
else
  echo "   ✗ PostToolUse validation hook not found in settings.json"
  exit 1
fi

# Test hook execution
echo
echo "4. Testing hook..."
TEST_INPUT='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}'
if echo "$TEST_INPUT" | "$SYMLINK_PATH" &> /dev/null; then
  echo "   ✓ Valid path test passed"
else
  echo "   ✗ Valid path test failed"
  exit 1
fi

TEST_INPUT='{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"src/main.go"}}'
if ! echo "$TEST_INPUT" | "$SYMLINK_PATH" &> /dev/null; then
  echo "   ✓ Invalid path test passed (correctly blocked)"
else
  echo "   ✗ Invalid path test failed (should have blocked)"
  exit 1
fi

echo
echo "✅ Installation complete!"
echo
echo "Active hooks:"
echo "  PreToolUse:  check_scout_boundaries (I6 — Scouts can only write IMPL docs)"
echo "  PreToolUse:  block_claire_paths (blocks .claire typo, suggests .claude)"
echo "  PreToolUse:  check_wave_ownership (I1 — Wave agents can only write owned files)"
echo "  PostToolUse: validate_impl_on_write (E16 — IMPL docs validated on write)"
echo "  PostToolUse: check_git_ownership (I1 layer 2 — catch git-level ownership violations)"
echo
echo "To uninstall:"
echo "  1. Remove symlinks: rm $SYMLINK_PATH $VALIDATE_SYMLINK $CLAIRE_SYMLINK $WAVE_OWNERSHIP_SYMLINK $GIT_OWNERSHIP_SYMLINK"
echo "  2. Edit $SETTINGS_FILE and remove the PreToolUse/PostToolUse hook entries"
