# SAW Skill Symlink Structure Analysis

**Date:** 2026-03-06

## TL;DR

**Source of truth:** `implementations/claude-code/prompts/` (all actual files live here)

**Installation:** Symlink from source → `~/.claude/skills/saw/` (not commands anymore)

**Pattern:** Same as current setup, just different target directory + skills API features

## Directory Structure Discovery

### Repository Structure (scout-and-wave)

```
scout-and-wave/
├── .claude/
│   └── commands/
│       └── saw.md -> ../../prompts/saw-skill.md (CURRENT - will migrate to skills/)
├── prompts/ -> implementations/claude-code/prompts/ (SYMLINK)
├── hooks/ -> implementations/claude-code/hooks/ (SYMLINK)
├── examples/ -> implementations/claude-code/examples/ (SYMLINK)
└── implementations/
    └── claude-code/
        └── prompts/
            ├── saw-skill.md (ACTUAL FILE - 14,276 bytes)
            ├── saw-bootstrap.md (ACTUAL FILE - 10,601 bytes)
            ├── saw-merge.md (ACTUAL FILE - 11,606 bytes)
            ├── saw-worktree.md (ACTUAL FILE - 8,691 bytes)
            ├── agent-template.md (ACTUAL FILE - 10,977 bytes)
            ├── scout.md (ACTUAL FILE - 22,967 bytes)
            ├── scaffold-agent.md (ACTUAL FILE - 5,642 bytes)
            ├── README.md
            └── agents/
                ├── scout.md (2,616 bytes)
                ├── wave-agent.md (5,637 bytes)
                └── scaffold-agent.md (23,467 bytes)
```

### Workspace Global Structure (Current)

```
/Users/dayna.blackwell/workspace/.claude/
├── commands/
│   └── saw.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/saw-skill.md
└── agents/
    ├── scout.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/scout.md
    ├── wave-agent.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/wave-agent.md
    └── scaffold-agent.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/scaffold-agent.md
```

## Resolution Chain (Current)

### For saw-skill.md

**From workspace global:**
```
/workspace/.claude/commands/saw.md
  → /Users/dayna.blackwell/code/scout-and-wave/prompts/saw-skill.md
  → /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md
  → implementations/claude-code/prompts/saw-skill.md (ACTUAL FILE)
```

## Supporting Files Location

All actual SAW prompt files live in:
```
/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/
```

| File | Size | Purpose |
|------|------|---------|
| saw-skill.md | 14,276 bytes | Main orchestrator skill |
| saw-bootstrap.md | 10,601 bytes | Bootstrap procedure for new projects |
| saw-merge.md | 11,606 bytes | Wave merge procedure |
| saw-worktree.md | 8,691 bytes | Worktree creation protocol |
| agent-template.md | 10,977 bytes | 9-field agent prompt template |
| scout.md | 22,967 bytes | Scout agent full prompt |
| scaffold-agent.md | 5,642 bytes | Scaffold agent prompt |
| agents/scout.md | 2,616 bytes | Scout subagent definition |
| agents/wave-agent.md | 5,637 bytes | Wave subagent definition |
| agents/scaffold-agent.md | 23,467 bytes | Scaffold subagent definition |

## Current Path Resolution Strategy

From `saw-skill.md` line 24:
```markdown
Read the agent template at `prompts/agent-template.md` from the scout-and-wave
repository for the 9-field agent prompt format. If these files are not in the
current project, look for them at the path configured in the SAW_REPO
environment variable, or fall back to `~/code/scout-and-wave/prompts/`.
```

**Problems:**
1. Hardcoded fallback path: `~/code/scout-and-wave/prompts/`
2. Assumes specific installation location
3. Requires SAW_REPO environment variable for portability
4. Complex logic with multiple fallback strategies

## Proposed Solution: Skills API Migration

### What Changes

**Location:**
```
OLD: ~/.claude/commands/saw.md
NEW: ~/.claude/skills/saw/SKILL.md
```

**Supporting files:**
```
OLD: Not co-located, complex path resolution
NEW: Symlinked into skill directory, simple ${CLAUDE_SKILL_DIR} reference
```

**Path resolution:**
```
OLD: 3 fallback strategies (relative, env var, hardcoded)
NEW: 1 strategy (${CLAUDE_SKILL_DIR}/filename.md)
```

### What Stays the Same

- ✅ Source of truth: `implementations/claude-code/prompts/` (unchanged)
- ✅ Symlink-based installation (same pattern)
- ✅ git pull updates everything (same benefit)
- ✅ Single edit point (same as before)

### New Directory Structure

```
~/.claude/skills/saw/
├── SKILL.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md
├── saw-bootstrap.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/saw-bootstrap.md
├── saw-merge.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/saw-merge.md
├── saw-worktree.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/saw-worktree.md
├── agent-template.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md
└── agents/
    ├── scout.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scout.md
    ├── wave-agent.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md
    └── scaffold-agent.md -> ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md
```

## Path References Update

### In saw-skill.md

**Replace all instances like this:**

| Old Reference | New Reference |
|--------------|---------------|
| `prompts/agent-template.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agent-template.md` |
| `prompts/saw-bootstrap.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` |
| `prompts/saw-merge.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-merge.md` |
| `prompts/saw-worktree.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-worktree.md` |
| `prompts/agents/scout.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agents/scout.md` |

**Example before:**
```markdown
Read the agent template at `prompts/agent-template.md` from the scout-and-wave
repository for the 9-field agent prompt format. If these files are not in the
current project, look for them at the path configured in the SAW_REPO
environment variable, or fall back to `~/code/scout-and-wave/prompts/`.
```

**Example after:**
```markdown
Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md` for the
9-field agent prompt format.
```

## Migration Steps

### 1. Update Source File

**File:** `implementations/claude-code/prompts/saw-skill.md`

**Changes:**
1. Add YAML frontmatter at top
2. Replace all path references with `${CLAUDE_SKILL_DIR}/filename.md`
3. Add supporting files section
4. Update version to 0.5.0

### 2. Update Installation Instructions

**File:** `implementations/claude-code/README.md`

**Update Step 3 from:**
```bash
cp ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md \
   ~/.claude/commands/saw.md
```

**To:**
```bash
# Create skill directory
mkdir -p ~/.claude/skills/saw/agents

# Symlink main skill file
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

### 3. Migrate Personal/Workspace Global Installations

```bash
# Remove old command symlink
rm ~/.claude/commands/saw.md 2>/dev/null
rm /workspace/.claude/commands/saw.md 2>/dev/null

# Create new skill directory
mkdir -p ~/.claude/skills/saw/agents

# Run the install commands from step 2
# (Same symlinks, just in ~/.claude/skills/saw/ instead of ~/.claude/commands/)
```

### 4. Test

```bash
# Restart Claude Code

# Test skill discovery
/saw status

# Test supporting file loading
/saw bootstrap test-project

# Verify ${CLAUDE_SKILL_DIR} resolves
# (Check that Claude can find agent-template.md, saw-bootstrap.md, etc.)
```

## Benefits of This Approach

1. **Single source of truth:** All actual files remain in `implementations/claude-code/prompts/`
2. **No hardcoded paths:** Uses `${CLAUDE_SKILL_DIR}` for all references
3. **Portable:** Works regardless of where scout-and-wave is cloned
4. **Skills API compliant:** Follows proper skill structure with supporting files
5. **Discoverable:** All supporting files visible in skill directory
6. **Simple logic:** No complex fallback strategies, no environment variables
7. **Same pattern:** Symlink-based install, git pull updates, single edit point

## Comparison: Before vs After

| Aspect | Before (Command) | After (Skill) |
|--------|------------------|---------------|
| **Location** | `~/.claude/commands/saw.md` | `~/.claude/skills/saw/SKILL.md` |
| **Supporting files** | Not co-located, complex paths | Symlinked into skill dir |
| **Path resolution** | 3 strategies (relative, env, hardcoded) | 1 strategy (`${CLAUDE_SKILL_DIR}`) |
| **Portability** | Requires SAW_REPO env var | Works anywhere |
| **Discoverability** | Supporting files hidden | All files visible |
| **Standards** | Legacy commands API | Skills API with frontmatter |
| **Tool restrictions** | None | Can enforce via frontmatter |
| **Version tracking** | HTML comment | Structured frontmatter |
| **Source of truth** | implementations/... (unchanged) | implementations/... (unchanged) |
| **Install method** | Symlink (unchanged) | Symlink (unchanged) |

## Why This Works

**The key insight:** We're not reorganizing the repository structure. We're just:

1. **Changing the install target:** `commands/` → `skills/saw/`
2. **Adding more symlinks:** Not just SKILL.md, but all supporting files too
3. **Simplifying path logic:** Replace complex fallbacks with `${CLAUDE_SKILL_DIR}`

The source of truth (`implementations/claude-code/prompts/`) never moves.
The installation pattern (symlinks) stays the same.
We just gain all the skills API features.

## Rollback Plan

If something breaks:

```bash
# Remove skill symlinks
rm -rf ~/.claude/skills/saw

# Restore old command symlink
ln -sf ~/code/scout-and-wave/prompts/saw-skill.md ~/.claude/commands/saw.md

# Restart Claude Code
```

The source files are unchanged, so rollback is instant.

## Next Steps

1. ✅ **Documented the pattern** (this file)
2. **Update saw-skill.md** (add frontmatter, fix paths)
3. **Update README.md** (install instructions)
4. **Test migration** (personal install)
5. **Update workspace global** (workspace/.claude/skills/saw/)
6. **Document in CHANGELOG**

## Conclusion

The migration to skills API is straightforward because the existing pattern is already correct:

- Source of truth is centralized ✓
- Installation is via symlinks ✓
- git pull updates everything ✓

We just need to:
- Move symlinks from `commands/` to `skills/saw/`
- Add symlinks for supporting files
- Update path references to use `${CLAUDE_SKILL_DIR}`

No complex reorganization needed. Same pattern, better features.
