#!/usr/bin/env bash
# Scout Boundaries Hook Installer
# Installs I6 enforcement hook for CLI Scout agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/check_scout_boundaries"
SYMLINK_PATH="$HOME/.local/bin/check_scout_boundaries"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🔧 Installing Scout boundaries hook..."
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
HOOK_CONFIG=$(cat <<'EOF'
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
  echo "   ✓ Hook already configured (skipping)"
else
  # Merge the hook config into settings.json
  jq --argjson hook "$HOOK_CONFIG" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [$hook]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  echo "   ✓ Added PreToolUse hook configuration"
fi
echo

# Step 3: Verify installation
echo "3. Verifying installation..."

# Check symlink
if [ -x "$SYMLINK_PATH" ]; then
  echo "   ✓ Hook script executable: $SYMLINK_PATH"
else
  echo "   ✗ Hook script not executable"
  exit 1
fi

# Check settings.json
if jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | contains("check_scout_boundaries"))' "$SETTINGS_FILE" &> /dev/null; then
  echo "   ✓ Hook configured in settings.json"
else
  echo "   ✗ Hook not found in settings.json"
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
echo "The Scout boundaries hook is now active."
echo "Scout agents will be restricted to writing only docs/IMPL/IMPL-*.yaml files."
echo
echo "To uninstall:"
echo "  1. Remove symlink: rm $SYMLINK_PATH"
echo "  2. Edit $SETTINGS_FILE and remove the PreToolUse hook"
