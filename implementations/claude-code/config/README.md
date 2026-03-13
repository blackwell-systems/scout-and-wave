# Claude Code Configuration Backup

This directory contains version-controlled backups of Claude Code configuration files.

## Files

- **settings.json** - Claude Code settings (hooks, permissions, plugins)
  - Backup of: `~/.claude/settings.json`
  - Restore: `cp settings.json ~/.claude/settings.json`

## Usage

### Backup (Manual)
```bash
cp ~/.claude/settings.json /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/config/settings.json
cd /Users/dayna.blackwell/code/scout-and-wave
git add implementations/claude-code/config/settings.json
git commit -m "config: backup Claude Code settings"
```

### Restore
```bash
cp /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/config/settings.json ~/.claude/settings.json
```

## Notes

- The PreToolUse hook for Scout boundaries is managed by `../hooks/install.sh`
- Running the installer will recreate the hook configuration if it's missing
- This backup serves as a reference for manual recovery or new machine setup
