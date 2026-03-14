# Scout Boundaries Hook (Path B)

**I6 Enforcement for CLI Scout agents** - Blocks Write/Edit operations outside `docs/IMPL/IMPL-*.yaml`

## Installation

### Automated (Recommended)

```bash
cd ~/code/scout-and-wave/implementations/claude-code/hooks
./install.sh
```

The installer:
- Creates symlink: `~/.local/bin/check_scout_boundaries` → script in repo
- Merges PreToolUse hook config into `~/.claude/settings.json` (preserves existing hooks)
- Verifies installation

### Manual

1. Symlink the hook script to your PATH:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_scout_boundaries ~/.local/bin/check_scout_boundaries
   ```

2. Add this to `~/.claude/settings.json` (merge with existing `hooks` section if present):
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [
             {
               "type": "command",
               "command": "/Users/$USER/.local/bin/check_scout_boundaries"
             }
           ]
         }
       ]
     }
   }
   ```

3. Verify installation:
   ```bash
   which check_scout_boundaries
   # Should print: /Users/$USER/.local/bin/check_scout_boundaries
   ```

## Testing

```bash
# Test valid path (should exit 0)
echo '{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}' | \
  check_scout_boundaries
echo $?  # Should be 0

# Test invalid path (should exit 1)
echo '{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"src/main.go"}}' | \
  check_scout_boundaries 2>&1
echo $?  # Should be 1
```

## How It Works

1. Claude Code calls the script before executing Write/Edit tools
2. Script receives JSON on stdin with tool_name, agent_type, tool_input
3. If agent_type != "scout" → allow (exit 0)
4. If tool_name not in [Write, Edit] → allow (exit 0)
5. If file_path matches `docs/IMPL/IMPL-*.yaml` → allow (exit 0)
6. Otherwise → block (exit 1) with I6 violation message

## Maintenance

- **Version control:** This script is tracked in the scout-and-wave repository
- **Updates:** `git pull` in scout-and-wave repo updates the script via symlink
- **Dependencies:** bash, jq, realpath (standard on macOS/Linux)
- **Errors:** Print to stderr and return exit code 1
- **Execution:** Runs synchronously (blocks tool execution if it exits 1)
