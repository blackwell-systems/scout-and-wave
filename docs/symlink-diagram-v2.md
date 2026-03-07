# SAW Skill Symlink Diagram

Visual representation of the symlink structure for scout-and-wave skill migration.

## Current State (Commands API)

```
scout-and-wave/implementations/claude-code/prompts/
├── saw-skill.md          ← ACTUAL FILE (source of truth)
├── saw-bootstrap.md      ← ACTUAL FILE
├── saw-merge.md          ← ACTUAL FILE
├── saw-worktree.md       ← ACTUAL FILE
├── agent-template.md     ← ACTUAL FILE
└── agents/
    ├── scout.md          ← ACTUAL FILE
    ├── wave-agent.md     ← ACTUAL FILE
    └── scaffold-agent.md ← ACTUAL FILE

                    ↓
                    ↓ symlink via prompts/ directory
                    ↓

scout-and-wave/prompts/   ← SYMLINK to implementations/claude-code/prompts/

                    ↓
                    ↓ symlink to command
                    ↓

~/.claude/commands/saw.md ← SYMLINK to prompts/saw-skill.md


/workspace/.claude/commands/saw.md ← SYMLINK to scout-and-wave/prompts/saw-skill.md
```

**Problem:** Complex path resolution with hardcoded fallbacks.

## Proposed State (Skills API)

```
scout-and-wave/implementations/claude-code/prompts/
├── saw-skill.md          ← ACTUAL FILE (source of truth - unchanged)
├── saw-bootstrap.md      ← ACTUAL FILE
├── saw-merge.md          ← ACTUAL FILE
├── saw-worktree.md       ← ACTUAL FILE
├── agent-template.md     ← ACTUAL FILE
└── agents/
    ├── scout.md          ← ACTUAL FILE
    ├── wave-agent.md     ← ACTUAL FILE
    └── scaffold-agent.md ← ACTUAL FILE

                    ↓
                    ↓ ALL symlinked into skill directory
                    ↓

~/.claude/skills/saw/
├── SKILL.md ──────────────> scout-and-wave/.../saw-skill.md
├── saw-bootstrap.md ──────> scout-and-wave/.../saw-bootstrap.md
├── saw-merge.md ──────────> scout-and-wave/.../saw-merge.md
├── saw-worktree.md ───────> scout-and-wave/.../saw-worktree.md
├── agent-template.md ─────> scout-and-wave/.../agent-template.md
└── agents/
    ├── scout.md ──────────> scout-and-wave/.../agents/scout.md
    ├── wave-agent.md ─────> scout-and-wave/.../agents/wave-agent.md
    └── scaffold-agent.md ─> scout-and-wave/.../agents/scaffold-agent.md
```

**Solution:** All supporting files co-located, simple `${CLAUDE_SKILL_DIR}` references.

## Side-by-Side Comparison

### Current: Commands API

```
Installation:
  ln -sf scout-and-wave/prompts/saw-skill.md ~/.claude/commands/saw.md

Path in saw-skill.md:
  "prompts/agent-template.md" OR
  "$SAW_REPO/prompts/agent-template.md" OR
  "~/code/scout-and-wave/prompts/agent-template.md"

Issues:
  ❌ Hardcoded fallback paths
  ❌ Requires SAW_REPO environment variable
  ❌ Complex 3-strategy resolution
  ❌ Not portable
```

### Proposed: Skills API

```
Installation:
  mkdir -p ~/.claude/skills/saw/agents
  ln -sf scout-and-wave/.../saw-skill.md ~/.claude/skills/saw/SKILL.md
  ln -sf scout-and-wave/.../agent-template.md ~/.claude/skills/saw/agent-template.md
  # ... etc for all supporting files

Path in saw-skill.md:
  "${CLAUDE_SKILL_DIR}/agent-template.md"

Benefits:
  ✅ No hardcoded paths
  ✅ No environment variables needed
  ✅ Simple single-strategy resolution
  ✅ Portable
  ✅ Skills API features (frontmatter, hooks, tool restrictions)
```

## Resolution Flow

### Current (3 strategies)

```
1. Try relative path: ./prompts/agent-template.md
   └─> Fails if not in scout-and-wave repo

2. Try environment variable: $SAW_REPO/prompts/agent-template.md
   └─> Fails if SAW_REPO not set

3. Fallback to hardcoded: ~/code/scout-and-wave/prompts/agent-template.md
   └─> Fails if cloned elsewhere
```

### Proposed (1 strategy)

```
${CLAUDE_SKILL_DIR}/agent-template.md
  └─> Always works, resolved by Claude Code
  └─> Points to symlink in ~/.claude/skills/saw/
  └─> Symlink points to actual file in implementations/
```

## What Changes

| Aspect | What Changes |
|--------|-------------|
| Source files | Nothing - stay in implementations/claude-code/prompts/ |
| Install method | Target directory: commands/ → skills/saw/ |
| Supporting files | Now symlinked into skill directory |
| Path references | Complex fallbacks → ${CLAUDE_SKILL_DIR} |
| git pull | Still updates everything (source unchanged) |
| Single edit point | Still implementations/ (unchanged) |

## Installation Commands

### Remove Old

```bash
rm ~/.claude/commands/saw.md
rm /workspace/.claude/commands/saw.md
```

### Install New

```bash
# Create skill directory
mkdir -p ~/.claude/skills/saw/agents

# Symlink main skill
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md \
       ~/.claude/skills/saw/SKILL.md

# Symlink supporting files
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-bootstrap.md \
       ~/.claude/skills/saw/saw-bootstrap.md

ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-merge.md \
       ~/.claude/skills/saw/saw-merge.md

ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-worktree.md \
       ~/.claude/skills/saw/saw-worktree.md

ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md \
       ~/.claude/skills/saw/agent-template.md

# Symlink agent files
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scout.md \
       ~/.claude/skills/saw/agents/scout.md

ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md \
       ~/.claude/skills/saw/agents/wave-agent.md

ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md \
       ~/.claude/skills/saw/agents/scaffold-agent.md
```

### Verify

```bash
# Check symlinks exist
ls -la ~/.claude/skills/saw/

# Check they resolve
readlink -f ~/.claude/skills/saw/SKILL.md

# Test skill works
# (Restart Claude Code first)
/saw status
```

## File Tree After Migration

```
~/.claude/skills/saw/
├── SKILL.md               → .../implementations/claude-code/prompts/saw-skill.md
├── agent-template.md      → .../implementations/claude-code/prompts/agent-template.md
├── saw-bootstrap.md       → .../implementations/claude-code/prompts/saw-bootstrap.md
├── saw-merge.md           → .../implementations/claude-code/prompts/saw-merge.md
├── saw-worktree.md        → .../implementations/claude-code/prompts/saw-worktree.md
└── agents/
    ├── scout.md           → .../implementations/claude-code/prompts/agents/scout.md
    ├── wave-agent.md      → .../implementations/claude-code/prompts/agents/wave-agent.md
    └── scaffold-agent.md  → .../implementations/claude-code/prompts/agents/scaffold-agent.md

All arrows point to actual files in:
scout-and-wave/implementations/claude-code/prompts/
```

## Why Symlink Supporting Files?

**Before:** Only SKILL.md was symlinked, supporting files found via complex path logic

**After:** All files symlinked into skill directory

**Benefits:**
1. **Discoverability** - `ls ~/.claude/skills/saw/` shows everything
2. **Simplicity** - `${CLAUDE_SKILL_DIR}/filename.md` always works
3. **Portability** - No hardcoded paths or environment variables
4. **Consistency** - Same pattern for all supporting files

## Pattern Consistency

This matches the existing pattern for agents:

```
Current:
  ~/.claude/agents/scout.md → scout-and-wave/prompts/agents/scout.md

Proposed (same pattern):
  ~/.claude/skills/saw/agents/scout.md → scout-and-wave/.../agents/scout.md
```

Same approach, just organized under the skill directory.

## Verification Checklist

After migration:

- [ ] Old command symlink removed (`~/.claude/commands/saw.md`)
- [ ] New skill directory created (`~/.claude/skills/saw/`)
- [ ] SKILL.md symlink exists and resolves
- [ ] All 7 supporting file symlinks exist
- [ ] `/saw status` command works
- [ ] `${CLAUDE_SKILL_DIR}` resolves correctly in skill execution
- [ ] Supporting files load when needed (test with `/saw bootstrap test`)
- [ ] Workspace global updated (if using `/workspace/.claude/`)

## Rollback

If issues occur:

```bash
# Remove new structure
rm -rf ~/.claude/skills/saw

# Restore old command
ln -sf ~/code/scout-and-wave/prompts/saw-skill.md ~/.claude/commands/saw.md

# Restart Claude Code
```

Source files unchanged, so rollback is instant.

## Summary

**Migration pattern:**
1. Source files stay in `implementations/claude-code/prompts/` (unchanged)
2. Installation target changes: `commands/` → `skills/saw/`
3. All supporting files get symlinked (not just main file)
4. Path references simplified: complex fallbacks → `${CLAUDE_SKILL_DIR}`

**Same pattern, better structure:**
- Symlink-based installation ✓
- Single source of truth ✓
- git pull updates everything ✓
- Plus: Skills API features (frontmatter, tool restrictions, hooks)

Total migration time: ~30 minutes
Rollback time: ~2 minutes
