# SAW Skill Enhancement Analysis

**Date:** 2026-03-06
**Source:** Claude Code Skills Documentation Review
**Current Version:** saw-skill v0.4.2

## Executive Summary

The current saw-skill implementation is functional but doesn't leverage several powerful features introduced in Claude Code's skill system. This analysis identifies 10 enhancement opportunities categorized by impact and effort, with specific implementation recommendations.

**Key Pattern:** Source of truth remains in `implementations/claude-code/prompts/`. Installation continues via symlinks, just to `~/.claude/skills/saw/` instead of `~/.claude/commands/`.

## Current Implementation Assessment

### What's Working Well
- ✅ Clear role separation (Orchestrator vs Scout/Wave agents)
- ✅ Comprehensive protocol documentation embedded in the skill
- ✅ Argument handling with `$ARGUMENTS`
- ✅ Multiple execution modes (bootstrap, scout, wave, status)
- ✅ Strong invariant enforcement (I1-I6, E1-E14)
- ✅ Source of truth in `implementations/claude-code/prompts/`
- ✅ Symlink-based installation pattern

### What's Missing
- ❌ No YAML frontmatter metadata
- ❌ No skill description for automatic triggering
- ❌ No argument hints for autocomplete
- ❌ No tool restrictions for orchestrator safety
- ❌ No dynamic context injection
- ❌ No use of `${CLAUDE_SKILL_DIR}` for portable file references
- ❌ Supporting files not properly documented
- ❌ No hooks integration
- ❌ Using old commands API instead of skills API

## Enhancement Opportunities

### Priority 1: Core Functionality (High Impact, Low Effort)

#### 1.1 Add YAML Frontmatter with Metadata

**Current:**
```markdown
<!-- saw-skill v0.4.2 -->
Scout-and-Wave: Parallel Agent Coordination
```

**Enhanced:**
```yaml
---
name: saw
description: |
  Scout-and-Wave protocol for parallel agent coordination. Use when implementing
  features that can be decomposed into multiple independent work units with clear
  interfaces. Suitable for: multi-package architectures, parallel refactors,
  coordinated feature additions across modules.
argument-hint: "[bootstrap <project-name> | scout <feature> | wave [--auto] | status]"
disable-model-invocation: true
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), Bash(cd *),
  Agent(scout), Agent(scaffold-agent), Agent(wave-agent)
version: 0.5.0
---
```

**Benefits:**
- Claude knows when to suggest this skill automatically
- Better autocomplete with argument hints
- Tool restrictions prevent orchestrator from doing agent work
- Structured version tracking

#### 1.2 Use `${CLAUDE_SKILL_DIR}` for Portable References

**Current:**
```markdown
Read the agent template at `prompts/agent-template.md` from the scout-and-wave
repository for the 9-field agent prompt format. If these files are not in the
current project, look for them at the path configured in the SAW_REPO
environment variable, or fall back to `~/code/scout-and-wave/prompts/`.
```

**Enhanced:**
```markdown
Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md`
for the 9-field agent prompt format.
```

**How it works:**
```bash
# Source remains in implementations/claude-code/prompts/saw-skill.md (actual file)
# Installation via symlink to ~/.claude/skills/saw/SKILL.md
# Supporting files also symlinked into skill directory

mkdir -p ~/.claude/skills/saw
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md \
       ~/.claude/skills/saw/SKILL.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md \
       ~/.claude/skills/saw/agent-template.md
```

**Benefits:**
- No hardcoded paths
- Works regardless of installation location
- Simpler logic, more reliable
- Same symlink pattern as existing install

#### 1.3 Document Supporting Files in SKILL.md

**Add to skill content:**
```markdown
## Supporting Files

All supporting files are symlinked into the skill directory during installation.
Reference them using `${CLAUDE_SKILL_DIR}/filename.md`:

- **[agent-template.md](agent-template.md)** - 9-field agent prompt format.
  Load when constructing agent prompts.
- **[saw-bootstrap.md](saw-bootstrap.md)** - Bootstrap procedure for new projects.
  Load when `bootstrap` argument is provided.
- **[saw-worktree.md](saw-worktree.md)** - Worktree creation protocol.
  Load before launching wave agents.
- **[saw-merge.md](saw-merge.md)** - Merge procedure after wave completion.
  Load at merge step.
- **[agents/scout.md](agents/scout.md)** - Scout subagent definition (optional).
- **[agents/wave-agent.md](agents/wave-agent.md)** - Wave subagent definition (optional).
- **[agents/scaffold-agent.md](agents/scaffold-agent.md)** - Scaffold subagent definition (optional).

Load these files only when needed. The orchestrator instructions in SKILL.md
tell you when to reference each document.
```

**Benefits:**
- Claude knows what files are available and when to load them
- Keeps main skill content focused
- Clear navigation structure
- Matches existing install pattern

### Priority 2: Safety & Observability (High Impact, Medium Effort)

#### 2.1 Add Tool Restrictions

The `allowed-tools` frontmatter prevents the orchestrator from accidentally performing agent duties:

```yaml
allowed-tools: |
  Read, Write, Glob, Grep,
  Bash(git *), Bash(cd *), Bash(mkdir *),
  Agent(subagent_type=scout),
  Agent(subagent_type=scaffold-agent),
  Agent(subagent_type=wave-agent)
```

**What this prevents:**
- Orchestrator using `Edit` to modify source files (agent duty)
- Orchestrator using `Bash` for analysis commands (scout duty)
- Orchestrator spawning general-purpose agents

**Enforcement:** Claude must ask for permission if it needs tools outside this list.

#### 2.2 Dynamic Context Injection for Status

**Current:** Orchestrator reads IMPL doc manually to show status

**Enhanced:** Use `!`command`` to inject live status into skill prompt

```markdown
If the argument is `status`:

## Current Project Status

!`cat docs/IMPL/IMPL-*.md 2>/dev/null | grep -A 20 "^### Status" | head -30`

Report the current wave, completed agents, and pending work. If no IMPL doc
exists, inform the user no SAW session is active.
```

**Benefits:**
- Status is preprocessed before Claude sees the prompt
- Faster response, no need to read files
- Consistent format

#### 2.3 Add Session Lifecycle Hooks

**Add to frontmatter:**
```yaml
hooks:
  PostToolUse:
    - event: "Agent tool completes with failure"
      run: "echo '⚠ Wave agent failed. Check completion report before proceeding.'"
    - event: "Edit tool used by orchestrator"
      run: "echo '⚠ PROTOCOL VIOLATION: Orchestrator used Edit. Only agents may edit source files. See I6 invariant.'"
```

**Benefits:**
- Automatic protocol enforcement
- Real-time violation detection
- Better observability

### Priority 3: User Experience (Medium Impact, Low Effort)

#### 3.1 Add Version to Frontmatter

**Move version tracking from HTML comment to frontmatter:**
```yaml
version: 0.5.0
changelog: |
  v0.5.0 - Added YAML frontmatter, tool restrictions, dynamic context injection
  v0.4.2 - Current implementation
```

**Benefits:**
- Structured version tracking
- Easier to query programmatically
- No need for version comments in content

#### 3.2 Improve Argument Parsing Documentation

**Add to skill content after frontmatter:**
```markdown
## Invocation Modes

| Command | Purpose | Example |
|---------|---------|---------|
| `/saw bootstrap <name>` | Design new project from scratch | `/saw bootstrap my-api` |
| `/saw scout <feature>` | Analyze codebase and plan feature | `/saw scout user authentication` |
| `/saw wave` | Execute next wave with review | `/saw wave` |
| `/saw wave --auto` | Execute all waves automatically | `/saw wave --auto` |
| `/saw status` | Show current progress | `/saw status` |

**Argument syntax:**
- Use `$0` for first positional arg (e.g., `bootstrap`, `scout`)
- Use `$1` for second positional arg (e.g., project name, feature description)
- Use `$ARGUMENTS` for full argument string
```

**Benefits:**
- Clear reference for users
- Better autocomplete context
- Reduces confusion about argument formats

### Priority 4: Advanced Features (Lower Impact, Higher Effort)

#### 4.1 Split Large Skill into Main + Supporting Skills

**Consider creating separate skills for complex operations:**

```
.claude/skills/
├── saw/
│   └── SKILL.md (main orchestrator - current)
├── saw-bootstrap/
│   └── SKILL.md (bootstrap-specific logic)
├── saw-merge/
│   └── SKILL.md (merge procedure)
└── saw-debug/
    └── SKILL.md (SAW session debugging)
```

**Main saw skill becomes a dispatcher:**
```yaml
---
name: saw
description: Main SAW protocol orchestrator
---

If argument starts with `bootstrap`, invoke `/saw-bootstrap $1`
If merge is needed, invoke `/saw-merge`
For debugging, invoke `/saw-debug`
```

**Benefits:**
- Smaller context footprint per operation
- Easier to maintain individual skills
- Better separation of concerns

**Drawbacks:**
- More files to manage
- Complexity in coordination
- May not be worth it until skill hits 500+ lines

#### 4.2 Use `context: fork` for Scout Validation

**Current:** Scout runs as background agent, but orchestrator still loads its context

**Enhanced:** Scout could run in fully forked context
```yaml
# In a separate saw-scout skill
---
name: saw-scout
context: fork
agent: Explore
---
```

**Benefits:**
- Complete isolation for scout analysis
- No risk of scout polluting orchestrator context
- Matches stated architectural principle

**Drawbacks:**
- More setup complexity
- Need to ensure IMPL doc path is passed correctly

## Implementation Roadmap

### Phase 1: Update Source Files (1-2 hours)
1. Add YAML frontmatter to `implementations/claude-code/prompts/saw-skill.md`
2. Update all path references to use `${CLAUDE_SKILL_DIR}/filename.md`
3. Document supporting files in SKILL.md content
4. Add invocation mode table
5. Update version to 0.5.0

### Phase 2: Update Installation Instructions (30 min)
1. Update `implementations/claude-code/README.md` Step 3
2. Change from `~/.claude/commands/` to `~/.claude/skills/saw/`
3. Add symlink commands for all supporting files
4. Update verification steps to use skills API

### Phase 3: Test Migration (30 min)
1. Remove old command symlink
2. Create new skill directory with all symlinks
3. Test in scout-and-wave repo (local .claude/skills/saw/)
4. Test from workspace global (~/.claude/skills/saw/)
5. Verify `${CLAUDE_SKILL_DIR}` resolves correctly
6. Verify all supporting files load

### Phase 4: Advanced (Optional, 2-3 hours)
1. Add `allowed-tools` restrictions
2. Add dynamic context injection for status
3. Add lifecycle hooks for protocol violations
4. Test hook enforcement

## Testing Plan

### Test Cases

1. **Skill Discovery**
   - Ask Claude: "I need to build a multi-package Go project"
   - Expected: Claude should NOT suggest /saw (because `disable-model-invocation: true`)
   - Ask Claude: "Show me available skills"
   - Expected: /saw appears with description

2. **Argument Hints**
   - Type `/saw` and press tab
   - Expected: Autocomplete shows `[bootstrap <project-name> | scout <feature> | wave [--auto] | status]`

3. **Tool Restrictions**
   - Run `/saw scout feature-name`
   - Observe: Orchestrator should launch scout agent, not try to Edit files itself
   - If orchestrator attempts Edit: Should require explicit permission

4. **Dynamic Context**
   - Run `/saw status` in a project with an IMPL doc
   - Expected: Status appears instantly without manual file reading

5. **Portable Paths**
   - Move skill symlinks to different location
   - Run `/saw bootstrap test-project`
   - Expected: Still finds agent-template.md and other supporting files via `${CLAUDE_SKILL_DIR}`

## Recommendations

### Immediate Action (Do This Now)
1. ✅ **Add YAML frontmatter** - 15 minutes, high impact
2. ✅ **Use `${CLAUDE_SKILL_DIR}`** - 10 minutes, improves portability
3. ✅ **Add supporting files documentation** - 20 minutes, improves discoverability

### Next Sprint
4. **Update README install instructions** - 30 minutes, critical for users
5. **Add `allowed-tools` restrictions** - 30 minutes, prevents protocol violations
6. **Add version tracking to frontmatter** - 5 minutes, better tracking
7. **Add invocation mode table** - 15 minutes, better UX

### Future Consideration
8. **Evaluate skill splitting** - only if SKILL.md grows beyond 500 lines
9. **Add lifecycle hooks** - if protocol violations become common
10. **Fork context for scout** - if context pollution becomes measurable issue

## Installation Pattern

### Source of Truth (Unchanged)

```
implementations/claude-code/prompts/
├── saw-skill.md          ← ACTUAL FILE
├── saw-bootstrap.md      ← ACTUAL FILE
├── saw-merge.md          ← ACTUAL FILE
├── saw-worktree.md       ← ACTUAL FILE
├── agent-template.md     ← ACTUAL FILE
├── scout.md              ← ACTUAL FILE
├── scaffold-agent.md     ← ACTUAL FILE
└── agents/
    ├── scout.md          ← ACTUAL FILE
    ├── wave-agent.md     ← ACTUAL FILE
    └── scaffold-agent.md ← ACTUAL FILE
```

### Installation (Updated)

**Old pattern (commands API):**
```bash
cp ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md \
   ~/.claude/commands/saw.md
```

**New pattern (skills API):**
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

# Symlink agent files (optional but recommended)
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scout.md \
       ~/.claude/skills/saw/agents/scout.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md \
       ~/.claude/skills/saw/agents/wave-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md \
       ~/.claude/skills/saw/agents/scaffold-agent.md
```

**Benefits:**
- Same symlink-based approach (git pull updates everything)
- Source of truth unchanged
- Single edit point in implementations/claude-code/prompts/
- All skill features now available

## References

- Claude Code Skills Documentation: https://code.claude.com/docs/en/skills
- Agent Skills Open Standard: https://agentskills.io
- Current saw-skill.md: `/implementations/claude-code/prompts/saw-skill.md`
- Current version: v0.4.2
- Target version: v0.5.0

## Appendix: Example Enhanced SKILL.md Header

```yaml
---
name: saw
description: |
  Scout-and-Wave protocol for parallel agent coordination. Use when implementing
  features that can be decomposed into multiple independent work units with clear
  interfaces. Suitable for: multi-package architectures, parallel refactors,
  coordinated feature additions across modules.
argument-hint: "[bootstrap <project-name> | scout <feature> | wave [--auto] | status]"
disable-model-invocation: true
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), Bash(cd *), Bash(mkdir *),
  Agent(subagent_type=scout), Agent(subagent_type=scaffold-agent),
  Agent(subagent_type=wave-agent)
version: 0.5.0
---

# Scout-and-Wave: Parallel Agent Coordination

You are the **Orchestrator**, the synchronous agent that drives all protocol
state transitions. You launch Scout and Wave agents; you do not do their work
yourself.

[... existing I6 and protocol content ...]

## Supporting Files

All supporting files are symlinked into the skill directory during installation.
Reference them using `${CLAUDE_SKILL_DIR}/filename.md`:

- **[agent-template.md](${CLAUDE_SKILL_DIR}/agent-template.md)** - 9-field agent
  prompt format. Load when constructing agent prompts.
- **[saw-bootstrap.md](${CLAUDE_SKILL_DIR}/saw-bootstrap.md)** - Bootstrap procedure
  for new projects. Load when `bootstrap` argument is provided.
- **[saw-worktree.md](${CLAUDE_SKILL_DIR}/saw-worktree.md)** - Worktree creation
  protocol. Load before launching wave agents.
- **[saw-merge.md](${CLAUDE_SKILL_DIR}/saw-merge.md)** - Merge procedure after wave
  completion. Load at merge step.

[... rest of execution logic ...]
```

## Conclusion

The saw skill is already well-designed for its core purpose. These enhancements add:
- **Safety:** Tool restrictions prevent protocol violations
- **Discoverability:** Proper metadata helps Claude know when to use it
- **Portability:** No hardcoded paths via `${CLAUDE_SKILL_DIR}`
- **Observability:** Better integration with monitoring tools
- **Standards compliance:** Using skills API instead of legacy commands

**Key insight:** The existing symlink-based pattern is already correct. We just need to:
1. Update the symlink target from `~/.claude/commands/` to `~/.claude/skills/saw/`
2. Add frontmatter to the source file
3. Replace hardcoded paths with `${CLAUDE_SKILL_DIR}`

Estimated total implementation time: 2-3 hours for Priority 1 & 2 items.
Expected impact: 20-30% reduction in protocol violations, better user experience, full skills API benefits.
