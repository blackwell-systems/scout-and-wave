# Scout-and-Wave Pattern Documentation

This directory contains the complete evolution and lessons learned from the Scout-and-Wave parallel agent coordination pattern.

## Quick Links

### For Users
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and improvements timeline
- **[LESSONS-ROUND4.md](LESSONS-ROUND4.md)** - Complete Round 4 execution narrative (brewprune, Feb 2026)

### For Contributors
- **[IMPROVEMENTS.md](IMPROVEMENTS.md)** - Prioritized queue of pattern enhancements
- **[THEORY.md](../THEORY.md)** - Mathematical convergence proof (if exists)

### For Implementation
- **[../prompts/scout.md](../prompts/scout.md)** - Scout agent prompt template
- **[../prompts/agent-template.md](../prompts/agent-template.md)** - Wave agent 8-field template
- **[../prompts/saw-skill.md](../prompts/saw-skill.md)** - Claude Code skill definition

## Installation

The `/saw` skill is installed at:
```
~/.claude/commands/saw.md
```

To update after pattern improvements:
```bash
cd ~/code/scout-and-wave
cp prompts/saw-skill.md ~/.claude/commands/saw.md
```

Restart Claude Code to load updated skill.

## Documentation Structure

### CHANGELOG.md
- **Purpose:** Track what changed and when
- **Audience:** Users wanting to understand pattern evolution
- **Format:** Keep a Changelog 1.0.0
- **Update:** After implementing improvements from IMPROVEMENTS.md

### IMPROVEMENTS.md
- **Purpose:** Queue of lessons learned, pending implementation
- **Audience:** Pattern contributors
- **Sections:**
  - Pattern Validations (what worked)
  - Priority 1 (implement next)
  - Priority 2 (evaluate later)
- **Update:** After each SAW execution that reveals insights

### LESSONS-ROUND4.md (and future LESSONS-RoundN.md)
- **Purpose:** Complete narrative of specific execution
- **Audience:** Pattern researchers, case study readers
- **Sections:**
  - Timeline
  - Pattern validations
  - Agent performance
  - Architectural decisions
  - Anti-patterns avoided
  - Recommendations
- **Update:** After completing full multi-wave SAW execution

## Pattern Evolution Cycle

```
Real Usage → Lessons Learned → IMPROVEMENTS.md → Implementation → CHANGELOG.md → Real Usage
                                                       ↓
                                                 LESSONS-RoundN.md
```

1. **Real Usage:** Execute SAW on actual project (e.g., brewprune Round 4)
2. **Lessons Learned:** Document gaps, validations, insights during/after execution
3. **IMPROVEMENTS.md:** Capture prioritized queue of pattern enhancements
4. **Implementation:** Apply Priority 1 improvements to prompts/skill
5. **CHANGELOG.md:** Document what changed and why
6. **LESSONS-RoundN.md:** Write complete narrative for posterity
7. **Real Usage:** Validate improvements in next execution

## Case Studies

### brewprune Round 4 (February 2026)

**Scope:** 31 P1/P2 UX findings from cold-start audit

**Execution:**
- Wave 1: 6 agents (command files) - 17 findings, 10 fixes
- Wave 2: 3 agents (shared modules) - 4 findings, 4 fixes
- Wave 3: 1 agent (test coverage) - 1 finding, 1 test

**Results:**
- 22 findings addressed (7 already done, 15 new improvements)
- +3027/-167 lines across 30 files
- Zero merge conflicts
- 2 integration issues caught by post-merge verification

**Key Learnings:**
- Pre-implementation check prevented 32% wasted work
- Justified out-of-scope changes for API fixes work well
- Wave sequencing (commands → shared modules) prevents conflicts
- Agent velocity correlates with justified complexity

**Documentation:** [LESSONS-ROUND4.md](LESSONS-ROUND4.md)

## Contributing

When adding lessons learned from new SAW executions:

1. **During execution:** Add observations to IMPROVEMENTS.md
2. **After each wave:** Document pattern validations
3. **After completion:** Write comprehensive LESSONS-RoundN.md
4. **Before next execution:** Implement Priority 1 improvements
5. **After implementation:** Update CHANGELOG.md

Keep IMPROVEMENTS.md focused on *actionable* items. Use LESSONS-RoundN.md for complete narratives.

## Version History

- **v0.1.0** (2026-02-27): Initial pattern release
- **Round 4 improvements** (2026-02-28): Out-of-scope conflict detection, performance guidance, pre-implementation check, scout file-writing clarification

See [CHANGELOG.md](CHANGELOG.md) for complete history.

## Related Resources

- **Cold-Start Audit Pattern:** `~/code/scout-and-wave/prompts/cold-start-audit.md` (if exists)
- **Claude Code Skills:** `~/.claude/commands/`
- **brewprune Case Study:** `/Users/dayna.blackwell/code/brewprune/docs/IMPL-audit-round4-p1p2.md`
