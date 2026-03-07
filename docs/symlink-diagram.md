# SAW Skill Symlink Diagram

Visual representation of the complete symlink structure for scout-and-wave skill.

## Current State (Command-based)

```
scout-and-wave/
│
├── .claude/
│   └── commands/
│       └── saw.md ───────────┐
│                             │
├── prompts/ ─────────────────┼──> (SYMLINK to implementations/claude-code/prompts/)
│                             │
└── implementations/          │
    └── claude-code/          │
        └── prompts/          │
            ├── saw-skill.md <┘ (ACTUAL FILE)
            ├── saw-bootstrap.md
            ├── saw-merge.md
            ├── saw-worktree.md
            ├── agent-template.md
            ├── scout.md
            ├── scaffold-agent.md
            └── agents/
                ├── scout.md
                ├── wave-agent.md
                └── scaffold-agent.md


/workspace/.claude/
└── commands/
    └── saw.md ──> /Users/.../scout-and-wave/prompts/saw-skill.md
                      │
                      └──> implementations/claude-code/prompts/saw-skill.md


/workspace/.claude/
└── agents/
    ├── scout.md ──────────> scout-and-wave/prompts/agents/scout.md
    ├── wave-agent.md ─────> scout-and-wave/prompts/agents/wave-agent.md
    └── scaffold-agent.md ─> scout-and-wave/prompts/agents/scaffold-agent.md
```

## Proposed State (Skill-based with bundled supporting files)

```
scout-and-wave/
│
├── .claude/
│   └── skills/
│       └── saw/
│           ├── SKILL.md ──────────────┐
│           ├── saw-bootstrap.md ──────┼──┐
│           ├── saw-merge.md ──────────┼──┼──┐
│           ├── saw-worktree.md ───────┼──┼──┼──┐
│           ├── agent-template.md ─────┼──┼──┼──┼──┐
│           └── agents/                │  │  │  │  │
│               ├── scout.md ──────────┼──┼──┼──┼──┼──┐
│               ├── wave-agent.md ─────┼──┼──┼──┼──┼──┼──┐
│               └── scaffold-agent.md ─┼──┼──┼──┼──┼──┼──┼──┐
│                                      │  │  │  │  │  │  │  │
└── implementations/                   │  │  │  │  │  │  │  │
    └── claude-code/                   │  │  │  │  │  │  │  │
        └── prompts/                   │  │  │  │  │  │  │  │
            ├── saw-skill.md <─────────┘  │  │  │  │  │  │  │
            ├── saw-bootstrap.md <────────┘  │  │  │  │  │  │
            ├── saw-merge.md <───────────────┘  │  │  │  │  │
            ├── saw-worktree.md <────────────────┘  │  │  │  │
            ├── agent-template.md <──────────────────┘  │  │  │
            ├── scout.md                                │  │  │
            ├── scaffold-agent.md                       │  │  │
            └── agents/                                 │  │  │
                ├── scout.md <──────────────────────────┘  │  │
                ├── wave-agent.md <────────────────────────┘  │
                └── scaffold-agent.md <───────────────────────┘


/workspace/.claude/
└── skills/
    └── saw/
        ├── SKILL.md ──────────────> scout-and-wave/.claude/skills/saw/SKILL.md
        ├── saw-bootstrap.md ──────> scout-and-wave/.claude/skills/saw/saw-bootstrap.md
        ├── saw-merge.md ──────────> scout-and-wave/.claude/skills/saw/saw-merge.md
        ├── saw-worktree.md ───────> scout-and-wave/.claude/skills/saw/saw-worktree.md
        ├── agent-template.md ─────> scout-and-wave/.claude/skills/saw/agent-template.md
        └── agents/ ───────────────> scout-and-wave/.claude/skills/saw/agents/
```

## Path Resolution in SKILL.md

### Current (Complex with fallbacks)

```
saw-skill.md line 24:
"Read the agent template at `prompts/agent-template.md` from the scout-and-wave
repository for the 9-field agent prompt format. If these files are not in the
current project, look for them at the path configured in the SAW_REPO
environment variable, or fall back to `~/code/scout-and-wave/prompts/`."

Resolution logic:
1. Try: ./prompts/agent-template.md
2. Try: $SAW_REPO/prompts/agent-template.md
3. Fallback: ~/code/scout-and-wave/prompts/agent-template.md
```

### Proposed (Simple with ${CLAUDE_SKILL_DIR})

```
saw-skill.md with frontmatter:
"Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md` for the
9-field agent prompt format."

Resolution logic:
1. ${CLAUDE_SKILL_DIR} = /path/to/.claude/skills/saw
2. File at: ${CLAUDE_SKILL_DIR}/agent-template.md
3. Symlink resolves to actual file
```

## Supporting File References

| File Referenced | Current Path | Proposed Path |
|----------------|--------------|---------------|
| Agent template | `prompts/agent-template.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agent-template.md` |
| Bootstrap procedure | `prompts/saw-bootstrap.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` |
| Merge procedure | `prompts/saw-merge.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-merge.md` |
| Worktree setup | `prompts/saw-worktree.md` + fallbacks | `${CLAUDE_SKILL_DIR}/saw-worktree.md` |
| Scout agent | `prompts/agents/scout.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agents/scout.md` |
| Wave agent | `prompts/agents/wave-agent.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agents/wave-agent.md` |
| Scaffold agent | `prompts/agents/scaffold-agent.md` + fallbacks | `${CLAUDE_SKILL_DIR}/agents/scaffold-agent.md` |

## Benefits of Proposed Structure

### 1. Discoverability
All supporting files are visible in the skill directory structure.

```bash
$ ls .claude/skills/saw/
SKILL.md
saw-bootstrap.md
saw-merge.md
saw-worktree.md
agent-template.md
agents/
```

### 2. Portability
Works regardless of installation location.

```bash
# Clone to anywhere
$ git clone git@github.com:user/scout-and-wave.git /any/path
$ cd /any/path/scout-and-wave

# Skill just works - no environment variables needed
$ /saw status
```

### 3. Simplicity
Single path resolution strategy, no fallbacks.

```markdown
Before: 3 strategies (relative, env var, hardcoded fallback)
After: 1 strategy (${CLAUDE_SKILL_DIR})
```

### 4. Standards Compliance
Follows Agent Skills open standard and Claude Code best practices.

```yaml
---
name: saw
description: Scout-and-Wave protocol
---

## Supporting Files

- [saw-bootstrap.md](saw-bootstrap.md) - Bootstrap procedure
- [agent-template.md](agent-template.md) - Agent prompt template
```

## Single Source of Truth

Despite the symlink indirection, there is ONE actual location for each file:

```
implementations/claude-code/prompts/
├── saw-skill.md          ← ACTUAL FILE
├── saw-bootstrap.md      ← ACTUAL FILE
├── saw-merge.md          ← ACTUAL FILE
├── saw-worktree.md       ← ACTUAL FILE
├── agent-template.md     ← ACTUAL FILE
└── agents/
    ├── scout.md          ← ACTUAL FILE
    ├── wave-agent.md     ← ACTUAL FILE
    └── scaffold-agent.md ← ACTUAL FILE
```

All other paths are symlinks pointing here.

Edit one place, changes reflect everywhere.

## Migration Commands

```bash
# Create skill directory
mkdir -p .claude/skills/saw/agents

# Move command to skill
mv .claude/commands/saw.md .claude/skills/saw/SKILL.md

# Symlink supporting files
cd .claude/skills/saw
ln -s ../../../implementations/claude-code/prompts/saw-bootstrap.md saw-bootstrap.md
ln -s ../../../implementations/claude-code/prompts/saw-merge.md saw-merge.md
ln -s ../../../implementations/claude-code/prompts/saw-worktree.md saw-worktree.md
ln -s ../../../implementations/claude-code/prompts/agent-template.md agent-template.md

# Symlink agent files
cd agents
ln -s ../../../../implementations/claude-code/prompts/agents/scout.md scout.md
ln -s ../../../../implementations/claude-code/prompts/agents/wave-agent.md wave-agent.md
ln -s ../../../../implementations/claude-code/prompts/agents/scaffold-agent.md scaffold-agent.md

# Update workspace global
rm /workspace/.claude/commands/saw.md
mkdir -p /workspace/.claude/skills/saw
cd /workspace/.claude/skills/saw
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/SKILL.md SKILL.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-bootstrap.md saw-bootstrap.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-merge.md saw-merge.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/saw-worktree.md saw-worktree.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/agent-template.md agent-template.md
ln -s /Users/dayna.blackwell/code/scout-and-wave/.claude/skills/saw/agents agents
```

## Verification

```bash
# Verify symlinks
$ ls -la .claude/skills/saw/
SKILL.md -> ../../../implementations/claude-code/prompts/saw-skill.md
saw-bootstrap.md -> ../../../implementations/claude-code/prompts/saw-bootstrap.md
...

# Test path resolution
$ cd .claude/skills/saw
$ readlink -f SKILL.md
/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md

# Test skill invocation
$ /saw status
```

## Comparison: Before vs After

| Aspect | Before (Command) | After (Skill) |
|--------|------------------|---------------|
| **Location** | `.claude/commands/saw.md` | `.claude/skills/saw/SKILL.md` |
| **Supporting files** | Scattered, need fallback logic | Co-located via symlinks |
| **Path resolution** | Complex (3 strategies) | Simple (`${CLAUDE_SKILL_DIR}`) |
| **Portability** | Requires env var or hardcoded path | Works anywhere |
| **Discoverability** | Supporting files hidden | All files visible in skill dir |
| **Standards** | Basic command | Full skill with metadata |
| **Tool restrictions** | None | Can enforce via frontmatter |
| **Version tracking** | HTML comment | Structured frontmatter |
