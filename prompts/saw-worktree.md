<!-- saw-worktree v0.4.0 -->
# SAW Worktree Lifecycle

Manage git worktree creation, verification, and cleanup for wave agents.

## Solo Agent Check

**Before creating any worktrees**, count the agents in the current wave.

If the wave has exactly **1 agent**, skip worktree creation entirely. Run the
agent directly on the main branch with no isolation overhead. Worktree
isolation exists to prevent inter-agent file conflicts — a solo agent cannot
conflict with itself, so the overhead is pure waste.

Additional benefit: a solo Wave 0 agent running on main makes its output
(new types, interfaces) immediately readable by Wave 1 agents without waiting
for a worktree merge.

Proceed to worktree creation only when the wave has **≥2 agents**.

## Interface Freeze Before Worktree Creation

**Do not create worktrees until interface contracts are finalized.**

The review window between "IMPL doc written" and "agents launched" is the
right time to revise type signatures, add fields, or restructure APIs. Once
worktrees branch from HEAD, any interface change in the IMPL doc requires
removing and recreating the worktrees — otherwise agents run against a stale
version of the contracts.

Checklist before creating worktrees:
- All type signatures in the IMPL doc interface contracts are final
- All `store_embedding`-style multi-param signatures are agreed on
- Any schema changes (Wave 0) are committed to HEAD

**If worktrees already exist from a previous session**, verify their HEAD
matches the current HEAD of main before launching agents:

```bash
git worktree list
# Compare commit SHAs — if any worktree SHA differs from main HEAD, remove and recreate:
git worktree remove ".claude/worktrees/wave{N}-agent-{letter}" --force
git branch -D "wave{N}-agent-{letter}"
git worktree add ".claude/worktrees/wave{N}-agent-{letter}" -b "wave{N}-agent-{letter}"
```

Stale worktrees from a previous session will cause agents to implement
against outdated interfaces, producing merge-time conflicts that are expensive
to untangle.

## Pre-Create Worktrees

Before launching any agents in a multi-agent wave, create a worktree for each
agent. Do NOT rely on the Task tool's `isolation: "worktree"` parameter alone
— it may not create worktrees in all environments.

```bash
mkdir -p .claude/worktrees

for agent in A B C; do
  git worktree add ".claude/worktrees/wave{N}-agent-${agent}" -b "wave{N}-agent-${agent}"
done
```

## Verify Creation

After creating worktrees, verify they exist:

```bash
git worktree list
```

Expected output: N+1 worktrees (main + N agents). If count doesn't match,
STOP and diagnose before launching agents.

## Diagnose Creation Failures

If worktree creation fails, run these checks in order:

### 1. Test basic worktree support

```bash
git worktree add .claude/worktrees/test-worktree -b test-branch
git worktree remove .claude/worktrees/test-worktree
git branch -d test-branch
```

If this fails, git worktrees are not supported or the repo has issues.

### 2. Check repo state

```bash
git status
```

Must be clean. Uncommitted changes can interfere with worktree creation.
If dirty, stash or commit before proceeding.

### 3. Check for branch name conflicts

```bash
git branch | grep "wave{N}-agent"
```

Pre-existing branches with the same names will prevent worktree creation.
Delete stale branches from previous runs.

## Fallback Options

If worktrees cannot be created:

1. **Reduce wave size** — Fewer agents means less risk of conflict
2. **Verify file ownership is strictly disjoint** — With perfect disjointness,
   agents can safely work on the same branch (not recommended, but safe if
   ownership is truly disjoint)
3. **Run agents sequentially** — Abandon parallelism, run one agent at a time
   on the main branch

## Agent Self-Healing

Even with pre-created worktrees, agents may inherit the wrong working directory
from the Task tool. Agents include self-healing logic (Section 0 of agent
template):

1. Agent attempts `cd` to expected worktree path
2. Agent verifies pwd, git branch, and worktree list
3. If verification fails after cd attempt, agent exits without modifying files

This is defense-in-depth: the orchestrator pre-creates worktrees (Layer 1),
agents self-correct (Layer 1.5), agents verify (Layer 2), and the orchestrator
checks completion reports (Layer 3).

## Cleanup

After merging a wave, remove all worktrees and branches:

```bash
for agent in A B C; do
  git worktree remove ".claude/worktrees/wave{N}-agent-${agent}" 2>/dev/null || \
    rm -rf ".claude/worktrees/wave{N}-agent-${agent}"
  git branch -d "wave{N}-agent-${agent}" 2>/dev/null || true
done
```

Clean up even if agents failed — stale worktrees and branches will interfere
with future waves.
