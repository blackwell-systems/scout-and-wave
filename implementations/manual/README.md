# Manual Scout-and-Wave Orchestration

**Audience:** Developers coordinating parallel implementation work without AI orchestration tools.

**Use cases:**
- Learning the SAW protocol through hands-on execution
- Custom CI/CD pipelines implementing SAW steps
- Team coordination for parallel feature development
- Low-complexity scenarios (2-4 agents) where automation overhead exceeds benefit

---

## When to Orchestrate Manually

**Good fit:**
- Small teams (2-4 developers) with clear file boundaries
- One-time refactors where automation setup isn't worth it
- Learning SAW protocol mechanics before adopting AI tools
- Environments where AI tools are unavailable or restricted

**Poor fit:**
- Large waves (5+ parallel agents) - coordination overhead grows quickly
- Tight iteration loops - manual merge procedure is slow
- Complex interface contracts - human tracking of dependencies is error-prone
- Cross-repository orchestration - worktree management becomes tedious

---

## Prerequisites

Before starting manual SAW orchestration, ensure:

1. **Git worktree support:** Git version ≥2.5 (for `git worktree` command)
2. **Project build system:** Functioning build/test commands (verification gates)
3. **Team communication channel:** Real-time chat or video for coordination
4. **Shared repository access:** All team members can push/pull from same remote
5. **Time availability:** Allocate 30-60 min for Scout, 2-4 hours per agent for Wave work

---

## Workflow Overview

```
┌─────────────┐
│ Scout Phase │  30-60 minutes (1 person)
└──────┬──────┘
       │  Produces: IMPL doc with agent prompts
       v
┌─────────────┐
│ Wave Phase  │  2-4 hours per agent (parallel)
└──────┬──────┘
       │  Produces: Branch per agent with commits
       v
┌─────────────┐
│ Merge Phase │  10-20 minutes (1 person)
└──────┬──────┘
       │  Produces: Integrated feature on main
       v
┌─────────────┐
│  Repeat or  │
│  Complete   │
└─────────────┘
```

---

## File Structure

Manual orchestration produces these artifacts:

```
docs/IMPL/
  IMPL-{feature-name}.md         # Scout produces this
    - Suitability verdict
    - Agent prompts (Fields 0-8)
    - File ownership table
    - Wave structure

.claude/worktrees/               # Created during Wave phase
  wave1-agent-A/                 # One worktree per agent
  wave1-agent-B/
  ...
```

---

## Guide Sequence

Read guides in this order:

1. **scout-guide.md** - How to analyze codebase manually, assess suitability, write IMPL doc
2. **wave-guide.md** - Coordinate parallel team work using worktrees
3. **merge-guide.md** - Step-by-step merge procedure with conflict resolution
4. **checklist.md** - Printable checkbox list for tracking progress

---

## Time Estimates

Based on small-to-medium codebases (5-15K lines):

| Phase | Duration (2-3 agents) | Duration (4-5 agents) |
|-------|----------------------|-----------------------|
| Scout | 30-60 minutes | 60-90 minutes |
| Wave (per agent) | 2-4 hours | 2-4 hours |
| Wave (total, parallel) | 2-4 hours | 2-4 hours |
| Merge | 10-20 minutes | 20-40 minutes |
| **Total** | **3-5 hours** | **3.5-6 hours** |

**Note:** Merge time scales linearly with agent count. Scout time increases with codebase complexity and interface discovery difficulty.

---

## Key Differences vs AI Orchestration

| Aspect | Manual | AI Orchestration |
|--------|--------|------------------|
| Scout analysis | Human reads code, draws dependency graph | Scout agent analyzes automatically |
| IMPL doc production | Write by hand following templates | Generated from codebase analysis |
| Wave coordination | Assign work via chat, monitor progress | Launch agents in background, poll completion |
| Verification | Each dev runs their own commands | Agents run verification before reporting |
| Merge | Git commands run manually | Orchestrator executes merge procedure |

**Critical similarity:** Both approaches enforce the same invariants (I1-I6) and execution rules (E1-E14). Manual orchestration is protocol-compliant if you follow the guides.

---

## Success Criteria

Manual orchestration succeeds when:

- ✓ All agents work in separate worktrees (I1: disjoint file ownership)
- ✓ No merge conflicts on agent-owned files (I1 enforcement)
- ✓ Build + tests pass after merge (verification gate)
- ✓ All agents report complete before merge (E7: no partial work merged)
- ✓ Feature integrates cleanly with main branch

---

## Common Pitfalls

1. **Skipping suitability assessment** - Starting Wave without checking preconditions P1-P5 leads to mid-wave blockers
2. **Forgetting worktree isolation** - Having agents work directly on main causes conflicts
3. **Incorrect file ownership** - Overlapping ownership breaks I1, causes merge conflicts
4. **Merging partial work** - If one agent blocked, wait to resolve before merging any agent
5. **Skipping post-merge verification** - Cascade failures surface in production, not during merge

---

## When to Escalate

Stop manual orchestration and use AI tools if:

- File ownership conflicts discovered mid-wave (need to recreate worktrees)
- Interface contracts unimplementable as specified (need E8 recovery)
- Wave blocked for >2 hours (faster to re-scout with AI)
- Team coordination overhead exceeds implementation time

---

## References

- [protocol/preconditions.md](../../protocol/preconditions.md) - P1-P5 suitability gate
- [protocol/invariants.md](../../protocol/invariants.md) - I1-I6 constraints
- [protocol/execution-rules.md](../../protocol/execution-rules.md) - E1-E14 procedures
- [templates/agent-prompt-template.md](../../templates/agent-prompt-template.md) - Field 0-8 structure

---

**Next:** Start with [scout-guide.md](./scout-guide.md) to analyze your codebase and produce an IMPL doc.
