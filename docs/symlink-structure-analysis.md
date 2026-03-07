# SAW Skill Symlink Structure Analysis

**Date:** 2026-03-06

## Directory Structure Discovery

### Repository Structure (scout-and-wave)

```
scout-and-wave/
├── .claude/
│   └── commands/
│       └── saw.md -> ../../prompts/saw-skill.md (SYMLINK)
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

### Workspace Global Structure

```
/Users/dayna.blackwell/workspace/.claude/
├── commands/
│   └── saw.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/saw-skill.md (SYMLINK)
└── agents/
    ├── scout.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/scout.md (SYMLINK)
    ├── wave-agent.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/wave-agent.md (SYMLINK)
    └── scaffold-agent.md -> /Users/dayna.blackwell/code/scout-and-wave/prompts/agents/scaffold-agent.md (SYMLINK)
```

### Personal ~/.claude Directory

```
/Users/dayna.blackwell/.claude/
├── skills/ (DOES NOT EXIST)
└── commands/ (DOES NOT EXIST)
```

**Note:** No personal global skills/commands for SAW. All access is through:
1. Local repo `.claude/commands/` (when working in scout-and-wave)
2. Workspace global `/workspace/.claude/commands/` (when working in any project under /workspace)

## Resolution Chain

### For saw-skill.md

**From repo local:**
```
.claude/commands/saw.md
  → ../../prompts/saw-skill.md
  → ../../implementations/claude-code/prompts/saw-skill.md (via prompts/ symlink)
  → implementations/claude-code/prompts/saw-skill.md (ACTUAL FILE)
```

**From workspace global:**
```
/workspace/.claude/commands/saw.md
  → /Users/dayna.blackwell/code/scout-and-wave/prompts/saw-skill.md
  → /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md
  → implementations/claude-code/prompts/saw-skill.md (ACTUAL FILE)
```

Both resolve to the same actual file.

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

## Implications for ${CLAUDE_SKILL_DIR}

### Current Setup (Command-based)

```
Location: .claude/commands/saw.md
${CLAUDE_SKILL_DIR}: NOT AVAILABLE (only available for skills/)
Relative path to supporting files: ../../../implementations/claude-code/prompts/
```

### Option A: Convert to Proper Skill (Project-local)

```
New location: .claude/skills/saw/SKILL.md
${CLAUDE_SKILL_DIR}: /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw
Relative to supporting files: ../../../implementations/claude-code/prompts/
```

**File structure:**
```
.claude/skills/saw/
└── SKILL.md -> ../../../implementations/claude-code/prompts/saw-skill.md
```

**Supporting file reference in SKILL.md:**
```markdown
Read the agent template at `${CLAUDE_SKILL_DIR}/../../../implementations/claude-code/prompts/agent-template.md`
```

### Option B: Convert to Proper Skill (Workspace global)

```
New location: /workspace/.claude/skills/saw/SKILL.md
${CLAUDE_SKILL_DIR}: /Users/dayna.blackwell/workspace/.claude/skills/saw
Absolute reference: /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/
```

**Still requires absolute path or environment variable.**

### Option C: Bundle Supporting Files with Skill

```
.claude/skills/saw/
├── SKILL.md
├── saw-bootstrap.md -> ../../../implementations/claude-code/prompts/saw-bootstrap.md
├── saw-merge.md -> ../../../implementations/claude-code/prompts/saw-merge.md
├── saw-worktree.md -> ../../../implementations/claude-code/prompts/saw-worktree.md
├── agent-template.md -> ../../../implementations/claude-code/prompts/agent-template.md
└── agents/
    ├── scout.md -> ../../../../implementations/claude-code/prompts/agents/scout.md
    ├── wave-agent.md -> ../../../../implementations/claude-code/prompts/agents/wave-agent.md
    └── scaffold-agent.md -> ../../../../implementations/claude-code/prompts/agents/scaffold-agent.md
```

**Supporting file reference in SKILL.md:**
```markdown
Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md`
```

**Advantages:**
- Simplest path resolution
- All supporting files discoverable from skill directory
- No complex fallback logic needed
- Works with `${CLAUDE_SKILL_DIR}` naturally

**Disadvantages:**
- More symlinks to manage
- Duplication of structure (but not content, thanks to symlinks)

## Recommended Approach

### Phase 1: Add to Enhancement Analysis (Completed)

Document the symlink structure and path resolution implications.

### Phase 2: Create Skill Directory Structure (Immediate)

**Convert from command to skill while maintaining current source location:**

```bash
# Create skill directory
mkdir -p .claude/skills/saw

# Move the command symlink to skill location
mv .claude/commands/saw.md .claude/skills/saw/SKILL.md

# Create symlinks for supporting files in skill directory
cd .claude/skills/saw
ln -s ../../../implementations/claude-code/prompts/saw-bootstrap.md saw-bootstrap.md
ln -s ../../../implementations/claude-code/prompts/saw-merge.md saw-merge.md
ln -s ../../../implementations/claude-code/prompts/saw-worktree.md saw-worktree.md
ln -s ../../../implementations/claude-code/prompts/agent-template.md agent-template.md

# Create agents subdirectory
mkdir -p agents
cd agents
ln -s ../../../../implementations/claude-code/prompts/agents/scout.md scout.md
ln -s ../../../../implementations/claude-code/prompts/agents/wave-agent.md wave-agent.md
ln -s ../../../../implementations/claude-code/prompts/agents/scaffold-agent.md scaffold-agent.md
```

**Result:**
```
.claude/skills/saw/
├── SKILL.md -> ../../../implementations/claude-code/prompts/saw-skill.md
├── saw-bootstrap.md -> ../../../implementations/claude-code/prompts/saw-bootstrap.md
├── saw-merge.md -> ../../../implementations/claude-code/prompts/saw-merge.md
├── saw-worktree.md -> ../../../implementations/claude-code/prompts/saw-worktree.md
├── agent-template.md -> ../../../implementations/claude-code/prompts/agent-template.md
└── agents/
    ├── scout.md -> ../../../../implementations/claude-code/prompts/agents/scout.md
    ├── wave-agent.md -> ../../../../implementations/claude-code/prompts/agents/wave-agent.md
    └── scaffold-agent.md -> ../../../../implementations/claude-code/prompts/agents/scaffold-agent.md
```

### Phase 3: Update saw-skill.md Path References

**Replace this (line 24):**
```markdown
Read the agent template at `prompts/agent-template.md` from the scout-and-wave
repository for the 9-field agent prompt format. If these files are not in the
current project, look for them at the path configured in the SAW_REPO
environment variable, or fall back to `~/code/scout-and-wave/prompts/`.
```

**With this:**
```markdown
Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md` for the
9-field agent prompt format.
```

**Similarly, all supporting file references:**

| Old Reference | New Reference |
|--------------|---------------|
| `prompts/saw-bootstrap.md` | `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` |
| `prompts/saw-merge.md` | `${CLAUDE_SKILL_DIR}/saw-merge.md` |
| `prompts/saw-worktree.md` | `${CLAUDE_SKILL_DIR}/saw-worktree.md` |
| `prompts/agent-template.md` | `${CLAUDE_SKILL_DIR}/agent-template.md` |
| `prompts/agents/scout.md` | `${CLAUDE_SKILL_DIR}/agents/scout.md` |

### Phase 4: Update Workspace Global Symlink

```bash
# Remove old command symlink
rm /Users/dayna.blackwell/workspace/.claude/commands/saw.md

# Create new skills directory if needed
mkdir -p /Users/dayna.blackwell/workspace/.claude/skills/saw

# Create symlink to project skill directory
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/SKILL.md \
      /Users/dayna.blackwell/workspace/.claude/skills/saw/SKILL.md

# Symlink supporting files too
cd /Users/dayna.blackwell/workspace/.claude/skills/saw
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-bootstrap.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-merge.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-worktree.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/agent-template.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/agents agents
```

## Benefits of This Approach

1. **Single source of truth:** All actual files remain in `implementations/claude-code/prompts/`
2. **No hardcoded paths:** Uses `${CLAUDE_SKILL_DIR}` for all references
3. **Portable:** Works regardless of where scout-and-wave is cloned
4. **Skills API compliant:** Follows proper skill structure with supporting files
5. **Discoverable:** All supporting files visible in skill directory
6. **Simple logic:** No complex fallback strategies, no environment variables

## Testing After Migration

1. **From scout-and-wave repo:**
   ```bash
   cd /Users/dayna.blackwell/code/scout-and-wave
   # Test that skill is discoverable
   # /saw status should work
   ```

2. **From another project:**
   ```bash
   cd /Users/dayna.blackwell/workspace/some-other-project
   # Test that skill is discoverable from workspace global
   # /saw status should work
   ```

3. **Verify supporting files load:**
   ```bash
   # Run bootstrap and check that agent-template.md is found
   # /saw bootstrap test-project
   ```

## Migration Checklist

- [ ] Create `.claude/skills/saw/` directory
- [ ] Move `.claude/commands/saw.md` to `.claude/skills/saw/SKILL.md`
- [ ] Create symlinks for all supporting files in skill directory
- [ ] Update path references in `saw-skill.md` to use `${CLAUDE_SKILL_DIR}`
- [ ] Add YAML frontmatter to `saw-skill.md`
- [ ] Test from scout-and-wave repo
- [ ] Update workspace global symlinks
- [ ] Test from other projects
- [ ] Update documentation

## Conclusion

The current symlink structure already provides a single source of truth in `implementations/claude-code/prompts/`. Converting to the skills API with proper symlinks maintains this architecture while adding portability through `${CLAUDE_SKILL_DIR}`.

The key insight: **symlink the supporting files into the skill directory**, not just the main SKILL.md file. This makes all references relative to `${CLAUDE_SKILL_DIR}` and eliminates complex path resolution logic.
