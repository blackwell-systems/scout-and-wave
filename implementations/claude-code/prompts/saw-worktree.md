<!-- saw-worktree v0.6.1 -->
# SAW Worktree Lifecycle

Manage git worktree creation, verification, and cleanup for wave agents.

## Cross-Repo Mode

When a wave spans multiple repositories — for example, an engine extraction
where Agent A works in `scout-and-wave-engine/` and Agent B works in
`scout-and-wave-web/` — the single-repo procedure applies independently to
each repository. Run every step (preflight, ownership verification, worktree
creation, hook installation) in each repo before launching any agents.

**IMPL doc convention for cross-repo waves:**

The file ownership table must include a `Repo` column identifying which
repository each file belongs to:

| File | Agent | Wave | Action | Repo |
|------|-------|------|--------|------|
| pkg/engine/runner.go | A | 1 | new | saw-engine |
| pkg/api/adapter.go | B | 1 | modify | saw-web |

Agents use Field 0 (`cd /absolute/path/to/repo/.claude/worktrees/...`) to
navigate to their repo+worktree. The Orchestrator is responsible for ensuring
each repo's worktrees exist before launching agents.

**CLI cross-repo support:**

All CLI commands accept a `--repo-dir` parameter for cross-repo scenarios.
Run `saw create-worktrees` once per repository:

```bash
saw create-worktrees "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
saw create-worktrees "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
```

The CLI handles preflight checks, worktree creation, and hook installation
for each repo independently.

**Merge step:**

Run the merge procedure separately in each repo:

```bash
saw merge-agents "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
saw merge-agents "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
```

The Orchestrator merges each repo's agent branches into that repo's main
branch. There is no cross-repo merge operation — each repo is an independent
merge unit.

**Cleanup:**

```bash
saw cleanup "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
saw cleanup "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
```

**Key constraint:** An agent that owns files in multiple repos must be given
explicit absolute paths for each repo's worktree in its prompt. Field 0
should cd to the primary repo; subsequent sections should reference the
secondary repo by absolute path. Keep cross-repo agent ownership to a minimum
— prefer agents that own files in exactly one repo so isolation boundaries
stay clean.

---

## Preflight: Working Tree Check

**Run this before anything else** — before ownership verification, before
creating worktrees.

The `saw create-worktrees` command performs this check automatically, ensuring
the working tree is clean before creating any worktrees. If the tree is dirty,
the CLI will exit with an error and guidance.

Manual preflight check (if not using CLI):

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

**YAML mode verification (recommended):** Run these CLI checks before creating worktrees:
```bash
# Verify all scaffolds are committed (exit 1 = not ready)
saw validate-scaffolds "<manifest-path>"

# Verify no freeze violations (exit 1 = contracts changed after freeze)
saw freeze-check "<manifest-path>"

# Verify no file ownership conflicts (exit 1 = I1 violation in IMPL doc)
saw check-conflicts "<manifest-path>"
```
All three must exit 0 before proceeding. These replace manual inspection of
the Scaffolds section and file ownership table for YAML manifests.

**If worktrees already exist from a previous session**, verify their HEAD
matches the current HEAD of main before launching agents:

```bash
git worktree list
# Compare commit SHAs - if any worktree SHA differs from main HEAD, remove and recreate:
git worktree remove ".claude/worktrees/wave{N}-agent-{ID}" --force
git branch -D "wave{N}-agent-{ID}"
git worktree add ".claude/worktrees/wave{N}-agent-{ID}" -b "wave{N}-agent-{ID}"
```

Stale worktrees from a previous session will cause agents to implement
against outdated interfaces, producing merge-time conflicts that are expensive
to untangle.

## Create Worktrees

Re-running `/saw wave` at this point is safe; WAVE_PENDING is re-entrant.

Before launching any agents in a multi-agent wave, create worktrees:

```bash
saw create-worktrees "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
```

The CLI creates a worktree for each agent in the wave, handling:
- Directory creation (`.claude/worktrees/`)
- Worktree branching from current HEAD
- Pre-commit hook installation (see below)
- Verification that worktrees exist and match current HEAD

If worktrees already exist from a previous run and their HEAD matches the
current HEAD of main, the command is idempotent — it skips creation and
proceeds to verification. Do not duplicate worktrees.

### Fail-Fast Hook Installation

The `saw create-worktrees` command automatically installs a git pre-commit
hook that blocks agent commits to main. This is Layer 0: infrastructure
enforcement that prevents isolation violations before they occur.

The hook (`hooks/pre-commit-guard.sh` in the SAW repository) checks: if
branch is `main` AND SAW worktrees exist AND `SAW_ALLOW_MAIN_COMMIT` is
not set, block the commit with an instructive error listing available
worktrees. The Orchestrator sets `SAW_ALLOW_MAIN_COMMIT=1` before its own
legitimate commits to main (scaffold commits, post-merge commits, lint fix
commits).

Manual hook installation (if not using CLI):

```bash
# Back up existing pre-commit hook if present
if [ -f .git/hooks/pre-commit ]; then
  cp .git/hooks/pre-commit .git/hooks/pre-commit.saw-backup
fi

# Install the SAW isolation guard from the repository
cp "${CLAUDE_SKILL_DIR}/hooks/pre-commit-guard.sh" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Why Pre-Creation Alongside isolation: "worktree"

Always pre-create worktrees (via CLI or manually) even when using
`isolation: "worktree"` on the Agent tool. The two mechanisms are
complementary, not redundant:

1. Pre-creation provides a fallback when the Task tool's isolation fails
   silently — agents can still navigate to the pre-created worktree via Field 0
2. Enables Field 0 agent self-verification (the worktree must exist for the
   agent to cd into it and verify)
3. Negligible overhead
4. Harmless if the Task tool also creates worktrees — git will not duplicate
   a worktree that already exists at the expected path

Do not rely solely on `isolation: "worktree"`. It may fail silently. The merge
procedure's trip wire (Step 1.5 in saw-merge.md) is the final safety net that
catches all isolation failures before any incorrect merge occurs.

Do not add `isolation: worktree` frontmatter to wave-agent definitions as a
replacement for this step. See `docs/saw-ops/worktree-isolation-design.md`.

## Verify Creation

The `saw create-worktrees` command verifies creation automatically, checking
that each expected worktree exists and is on the correct branch.

Manual verification (if not using CLI):

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
saw cleanup "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
```

The CLI removes each agent's worktree, deletes its branch, and restores the
original pre-commit hook (if one existed before SAW installation).

Clean up even if agents failed; stale worktrees and branches will interfere
with future waves.

Manual cleanup (if not using CLI):

```bash
for agent in A B C; do
  git worktree remove ".claude/worktrees/wave{N}-agent-${agent}" 2>/dev/null || \
    rm -rf ".claude/worktrees/wave{N}-agent-${agent}"
  git branch -d "wave{N}-agent-${agent}" 2>/dev/null || true
done

# Restore original pre-commit hook
if [ -f .git/hooks/pre-commit.saw-backup ]; then
  mv .git/hooks/pre-commit.saw-backup .git/hooks/pre-commit
else
  rm -f .git/hooks/pre-commit
fi
```
