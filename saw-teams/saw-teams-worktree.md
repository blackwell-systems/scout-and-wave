<!-- saw-teams-worktree v0.1.1 -->
# SAW-Teams Worktree Lifecycle

Manage git worktree creation, verification, and cleanup for Agent Teams wave
execution. Adapted from `prompts/saw-worktree.md` (v0.4.2): same invariants,
same defense-in-depth model, different execution plumbing.

**Key difference from standard SAW:** Agent Teams does not create worktrees
automatically. The lead (Orchestrator) creates worktrees before spawning
teammates and passes the worktree path in each teammate's spawn context.

## Preflight: Working Tree Check

**Run this before anything else** — before ownership verification, before
creating worktrees.

```bash
git status --porcelain
```

If the output is non-empty, the working tree is dirty. `git worktree add` will
succeed on a dirty tree, but teammates branching from an uncommitted state will
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

   **Crash recovery note:** if the lead crashes mid-wave with a stash active,
   run `git stash list` to find the stash and `git stash pop` to restore it
   after the merge is resolved manually.

Do not proceed until `git status --porcelain` returns empty output.

## Pre-Launch Ownership Verification

Before creating any worktrees, scan the wave's file ownership table in the
IMPL doc and verify no file appears in more than one agent's ownership list.

If an overlap is found, **do not proceed**. Correct the IMPL doc first:
resolve the conflict by splitting the file, extracting an interface, or
reassigning scope. This catches scout planning errors before agents spend
time on conflicting work.

This is distinct from post-execution conflict prediction (Step 2 of
saw-teams-merge.md), which catches runtime deviations where a teammate touched
files outside its declared scope. Both checks are required; they catch
different failure modes.

## Interface Freeze Before Worktree Creation

**Do not create worktrees until interface contracts are finalized.**

The review window between "IMPL doc written" and "teammates spawned" is the
right time to revise type signatures, add fields, or restructure APIs. Once
worktrees branch from HEAD, any interface change in the IMPL doc requires
removing and recreating the worktrees; otherwise teammates run against a stale
version of the contracts.

Checklist before creating worktrees:
- All type signatures in the IMPL doc interface contracts are final
- All `store_embedding`-style multi-param signatures are agreed on
- Any Scout scaffold files are committed to HEAD

**If worktrees already exist from a previous session**, verify their HEAD
matches the current HEAD of main before spawning teammates:

```bash
git worktree list
# Compare commit SHAs - if any worktree SHA differs from main HEAD, remove and recreate:
git worktree remove ".claude/worktrees/wave{N}-agent-{letter}" --force
git branch -D "wave{N}-agent-{letter}"
git worktree add ".claude/worktrees/wave{N}-agent-{letter}" -b "wave{N}-agent-{letter}"
```

Stale worktrees from a previous session will cause teammates to implement
against outdated interfaces, producing merge-time conflicts that are expensive
to untangle.

## Pre-Create Worktrees

Re-running `/saw-teams wave` at this point is safe; WAVE_PENDING is
re-entrant. Before creating worktrees, check whether they already exist from
a previous run:

```bash
git worktree list
```

If the expected worktrees are already present and their HEAD matches the
current HEAD of main, skip creation and proceed to teammate spawn. Do not
duplicate worktrees.

Before spawning any teammates, create a worktree for each agent. The lead
creates worktrees; Agent Teams has no built-in worktree creation mechanism.

```bash
mkdir -p .claude/worktrees

for agent in A B C; do
  git worktree add ".claude/worktrees/wave{N}-agent-${agent}" -b "wave{N}-agent-${agent}"
done
```

Pass the absolute worktree path to each teammate in its spawn context so it
knows where to navigate during Field 0 isolation verification.

## Verify Creation

After creating worktrees, verify they exist:

```bash
git worktree list
```

Expected output: N+1 worktrees (main + N agents). If count doesn't match,
STOP and diagnose before spawning teammates.

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
   teammates can safely work on the same branch (not recommended, but safe if
   ownership is truly disjoint)
3. **Run agents sequentially:** abandon parallelism, run one agent at a time
   on the main branch
4. **Fall back to standard SAW execution:** use `prompts/saw-skill.md` with
   the raw Agent tool instead of Agent Teams. The IMPL doc state machine is
   execution-layer-agnostic; the same IMPL doc works with either execution
   layer. This is always a valid fallback.

## Teammate Self-Healing

Even with pre-created worktrees, teammates may inherit the wrong working
directory from Agent Teams. Teammates include self-healing logic (Section 0
of teammate template):

1. Teammate attempts `cd` to expected worktree path
2. Teammate verifies pwd, git branch, and worktree list
3. If verification fails after cd attempt, teammate writes failure report to
   IMPL doc AND messages the lead with the failure details
4. Teammate exits without modifying files

This is defense-in-depth:

- **Layer 1:** Lead pre-creates worktrees before spawning teammates
- **Layer 1.5:** Teammate attempts self-correction via cd
- **Layer 2:** Teammate verifies isolation and fails fast if incorrect
- **Layer 2.5:** Teammate messages lead about isolation failure (real-time
  awareness; the lead can intervene immediately rather than discovering the
  failure only when reading completion reports after all teammates finish)
- **Layer 3:** Lead checks completion reports for isolation failures

Layer 2.5 is the key addition over standard SAW. In standard SAW, the
Orchestrator only discovers isolation failures when reading completion reports
after all agents complete. With Agent Teams messaging, the lead can intervene
immediately, e.g., spawn a replacement teammate with the correct path.

## Cleanup

After merging a wave, remove all worktrees and branches. Note: team cleanup
(dismissing teammates) is handled by `saw-teams-merge.md` Step 5; this
section handles only git worktree lifecycle.

**Important:** Dismiss the team BEFORE removing worktrees. If a teammate is
still writing to a worktree when it's removed, you get file system errors.

```bash
for agent in A B C; do
  git worktree remove ".claude/worktrees/wave{N}-agent-${agent}" 2>/dev/null || \
    rm -rf ".claude/worktrees/wave{N}-agent-${agent}"
  git branch -d "wave{N}-agent-${agent}" 2>/dev/null || true
done
```

Clean up even if agents failed; stale worktrees and branches will interfere
with future waves.
