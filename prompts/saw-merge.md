<!-- saw-merge v0.2.0 -->
# SAW Merge Procedure

Merge agent worktrees back into the main branch after a wave completes.

## Pre-Merge: Conflict Detection

Before merging any agent, scan all completion reports for out-of-scope file
changes (section 8 of each agent's report). If multiple agents modified the
same out-of-scope file:

1. Flag the conflict and show both changes to the user
2. Ask which version to keep or if manual merge is needed
3. Do not proceed to merge until conflicts are resolved

**Expected conflict: IMPL doc completion reports.** Multiple agents appending
to the same IMPL doc in the same wave will produce merge conflicts in that
file. This is expected and manageable — resolve by accepting all appended
sections (each agent owns a distinct `### Agent {letter} — Completion Report`
section). For waves with many agents (≥5), consider using per-agent report
files (`docs/reports/agent-{letter}.md`) instead, with the orchestrator
reading and consolidating them after the wave. Specify this in the scout's
output if agent count warrants it.

## Merge Each Agent

For each agent in the wave:

```bash
worktree=".claude/worktrees/wave{N}-agent-{letter}"
branch="wave{N}-agent-{letter}"

cd "$worktree"

# Check if agent committed their changes or left them uncommitted
if git diff --quiet && git diff --cached --quiet; then
  # Agent committed to branch — use git merge
  cd /path/to/main/repo
  git merge --no-ff "$branch" -m "Merge wave{N}-agent-{letter}: {short description}"
else
  # Agent left uncommitted changes — copy files manually
  cd /path/to/main/repo
  # Copy each changed file from worktree to main
  cp "$worktree"/path/to/changed/file ./path/to/changed/file
  git add ./path/to/changed/file
  git commit -m "Apply agent {letter} changes from worktree"
fi
```

Merge all agents before running post-merge verification. Order does not matter
when file ownership is disjoint.

## Worktree Cleanup

After merging each agent:

```bash
git worktree remove "$worktree" 2>/dev/null || rm -rf "$worktree"
git branch -d "$branch" 2>/dev/null || true
```

## Post-Merge Verification

Run the verification gate commands from the IMPL doc against the merged result.

Individual agents pass their gates in isolation, but the merged codebase can
surface issues none of them saw individually. This post-merge verification is
the real gate.

Pay particular attention to cascade candidates listed in the IMPL doc — files
outside agent scope that reference changed interfaces.

If verification fails, fix before proceeding. Do not launch the next wave
with a broken build.

## After Verification Passes

1. Update the IMPL doc: tick status checkboxes, correct any interface contracts
   that changed during implementation
2. Apply any out-of-scope fixes flagged by agents in their reports
3. Commit the wave's changes
4. Launch the next wave (or report results and pause if not `--auto`)
