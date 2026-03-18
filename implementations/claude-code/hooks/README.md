# SAW Claude Code Hooks

Two enforcement hooks for CLI-based SAW agents.

## Hook 1: Scout Boundaries (I6)

**PreToolUse** — Blocks Scout Write/Edit operations outside `docs/IMPL/IMPL-*.yaml`

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

---

## Hook 2: IMPL Validation on Write (E16)

**PostToolUse** — Validates IMPL docs after every Write, blocks on schema errors.

### How It Works

1. Claude Code calls the script after a Write tool completes
2. Script checks if the written file matches `docs/IMPL/IMPL-*.yaml` (skips archived `/complete/` docs)
3. Runs `sawtools validate` (read-only, no `--fix`)
4. If validation fails → blocks with error list; agent must fix before continuing
5. If `sawtools` or `jq` not on PATH → exits silently (non-blocking)

### Defense-in-Depth

Three layers of IMPL validation:

| Layer | When | Mechanism |
|-------|------|-----------|
| Scout self-validation (Step 16) | After Scout writes IMPL | Scout runs `sawtools validate --fix` |
| Orchestrator E16 | After Scout completes | Orchestrator runs `sawtools validate --fix` |
| **PostToolUse hook** | On every Write to IMPL doc | Hook runs `sawtools validate` (read-only) |

The hook is the hard enforcement layer — it fires even if the Scout skips Step 16.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/validate_impl_on_write ~/.local/bin/validate_impl_on_write
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Write",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/validate_impl_on_write"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Write a valid IMPL doc — should exit 0
echo '{"tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}' | validate_impl_on_write
echo $?  # 0

# Archived docs are skipped — should exit 0
echo '{"tool_input":{"file_path":"docs/IMPL/complete/IMPL-old.yaml"}}' | validate_impl_on_write
echo $?  # 0
```

---

## Maintenance

- **Version control:** Both scripts are tracked in the scout-and-wave repository
- **Updates:** `git pull` updates the scripts via symlink
- **Dependencies:** bash, jq, sawtools (graceful degradation if missing)
- **Errors:** Print to stderr and return exit code 1
- **Execution:** Runs synchronously (blocks tool execution if it exits 1)
