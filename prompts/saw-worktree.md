<!-- saw-worktree v0.4.5 -->
# SAW Worktree Lifecycle

Manage git worktree creation, verification, and cleanup for wave agents.

## Preflight: Working Tree Check

**Run this before anything else** — before ownership verification, before
creating worktrees.

```bash
git status --porcelain
```

If the output is non-empty, the working tree is dirty. `git worktree add` will
succeed on a dirty tree, but agents branching from an uncommitted state will
carry unstaged changes into their isolation boundary, which produces confusing
merge results. Resolve before proceeding.

**Two options:**

1. **Commit (preferred):** If the changes are complete work, commit them now.
   This is the most common case — the previous feature was just finished and
   the changes weren't committed before starting the next wave.

   ```bash
   git add <files>
   git commit -m "<message>"
   ```

2. **Stash (for genuine WIP):** If the changes are incomplete and shouldn't be
   committed, stash with a descriptive message so recovery is unambiguous:

   ```bash
   git stash push -u -m "SAW pre-wave stash: <brief description>"
   ```

   After the wave completes and the merge is done, restore:

   ```bash
   git stash pop
   ```

   **Crash recovery note:** if the Orchestrator crashes mid-wave with a stash
   active, run `git stash list` to find the stash and `git stash pop` to restore
   it after the merge is resolved manually.

Do not proceed until `git status --porcelain` returns empty output.

## Pre-Launch Ownership Verification

Before creating any worktrees, scan the wave's file ownership table in the
IMPL doc and verify no file appears in more than one agent's ownership list.

If an overlap is found, **do not proceed**. Correct the IMPL doc first:
resolve the conflict by splitting the file, extracting an interface, or
reassigning scope. This catches scout planning errors before agents spend
time on conflicting work.

This is distinct from post-execution conflict prediction (Step 2 of
saw-merge.md), which catches runtime deviations where an agent touched files
outside its declared scope. Both checks are required; they catch different
failure modes.

## Interface Freeze Before Worktree Creation

**Do not create worktrees until interface contracts are finalized.**

The review window between "IMPL doc written" and "agents launched" is the
right time to revise type signatures, add fields, or restructure APIs. Once
worktrees branch from HEAD, any interface change in the IMPL doc requires
removing and recreating the worktrees; otherwise agents run against a stale
version of the contracts.

Checklist before creating worktrees:
- All type signatures in the IMPL doc interface contracts are final
- All multi-parameter function signatures and complex return types are agreed on
- Any Scaffold Agent scaffold files are committed to HEAD

**If worktrees already exist from a previous session**, verify their HEAD
matches the current HEAD of main before launching agents:

```bash
git worktree list
# Compare commit SHAs - if any worktree SHA differs from main HEAD, remove and recreate:
git worktree remove ".claude/worktrees/wave{N}-agent-{letter}" --force
git branch -D "wave{N}-agent-{letter}"
git worktree add ".claude/worktrees/wave{N}-agent-{letter}" -b "wave{N}-agent-{letter}"
```

Stale worktrees from a previous session will cause agents to implement
against outdated interfaces, producing merge-time conflicts that are expensive
to untangle.

## Pre-Create Worktrees

Re-running `/saw wave` at this point is safe; WAVE_PENDING is re-entrant.
Before creating worktrees, check whether they already exist from a previous
run:

```bash
git worktree list
```

If the expected worktrees are already present and their HEAD matches the
current HEAD of main, skip creation and proceed to launch. Do not duplicate
worktrees.

Before launching any agents in a multi-agent wave, create a worktree for each
agent manually. This is the primary isolation mechanism.

```bash
mkdir -p .claude/worktrees

for agent in A B C; do
  git worktree add ".claude/worktrees/wave{N}-agent-${agent}" -b "wave{N}-agent-${agent}"
done
```

### Install Fail-Fast Hook

After creating worktrees, install a git pre-commit hook that blocks agent
commits to main. This is Layer 0: infrastructure enforcement that prevents
isolation violations before they occur.

```bash
# Back up existing pre-commit hook if present
if [ -f .git/hooks/pre-commit ]; then
  cp .git/hooks/pre-commit .git/hooks/pre-commit.saw-backup
fi

# Install the SAW isolation guard from the repository
cp "${SAW_REPO:-~/code/scout-and-wave}/hooks/pre-commit-guard.sh" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook (`hooks/pre-commit-guard.sh` in the SAW repository) checks: if
branch is `main` AND SAW worktrees exist AND `SAW_ALLOW_MAIN_COMMIT` is
not set, block the commit with an instructive error listing available
worktrees. The Orchestrator sets `SAW_ALLOW_MAIN_COMMIT=1` before its own
legitimate commits to main (scaffold commits, post-merge commits, lint fix
commits).

### Why Manual Pre-Creation Alongside isolation: "worktree"

Always pre-create worktrees manually even when using `isolation: "worktree"`
on the Agent tool. The two mechanisms are complementary, not redundant:

1. Manual creation provides a fallback when the Task tool's isolation fails
   silently — agents can still navigate to the pre-created worktree via Field 0
2. Enables Field 0 agent self-verification (the worktree must exist for the
   agent to cd into it and verify)
3. Costs one bash loop (negligible overhead)
4. Harmless if the Task tool also creates worktrees — git will not duplicate
   a worktree that already exists at the expected path

Do not rely solely on `isolation: "worktree"`. It may fail silently. The merge
procedure's trip wire (Step 1.5 in saw-merge.md) is the final safety net that
catches all isolation failures before any incorrect merge occurs.

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
git status --porcelain
```

Must be clean (empty output). If dirty, the preflight check at the top of
this document should have caught this — return there and resolve it.

### 3. Check for branch name conflicts

```bash
git branch | grep "wave{N}-agent"
```

Pre-existing branches with the same names will prevent worktree creation.
Delete stale branches from previous runs.

## Fallback Options

If worktrees cannot be created:

1. **Reduce wave size:** fewer agents means less risk of conflict
2. **Verify file ownership is strictly disjoint:** with perfect disjointness,
   agents can safely work on the same branch (not recommended, but safe if
   ownership is truly disjoint)
3. **Run agents sequentially:** abandon parallelism, run one agent at a time
   on the main branch

## Agent Self-Healing

Even with pre-created worktrees, agents may inherit the wrong working directory
from the Task tool. Agents include self-healing logic (Section 0 of agent
template):

1. Agent attempts `cd` to expected worktree path
2. Agent verifies pwd, git branch, and worktree list
3. If verification fails after cd attempt, agent exits without modifying files

This is defense-in-depth: a pre-commit hook blocks agent commits to main
(Layer 0), the orchestrator pre-creates worktrees (Layer 1), the Task tool's
`isolation: "worktree"` provides runtime isolation (Layer 2), agents
self-correct and verify (Layer 3, Field 0), and the merge procedure's trip
wire (Step 1.5) catches all failures before any merge occurs (Layer 4).

## Cleanup

After merging a wave, remove all worktrees and branches:

```bash
for agent in A B C; do
  git worktree remove ".claude/worktrees/wave{N}-agent-${agent}" 2>/dev/null || \
    rm -rf ".claude/worktrees/wave{N}-agent-${agent}"
  git branch -d "wave{N}-agent-${agent}" 2>/dev/null || true
done
```

Clean up even if agents failed; stale worktrees and branches will interfere
with future waves.

After removing worktrees, restore the original pre-commit hook:

```bash
if [ -f .git/hooks/pre-commit.saw-backup ]; then
  mv .git/hooks/pre-commit.saw-backup .git/hooks/pre-commit
else
  rm -f .git/hooks/pre-commit
fi
```
