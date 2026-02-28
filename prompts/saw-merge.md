<!-- saw-merge v0.3.0 -->
# SAW Merge Procedure

Merge agent worktrees back into the main branch after a wave completes.

## Step 1: Parse Completion Reports

Read each agent's structured completion report from the IMPL doc
(`### Agent {letter} — Completion Report`). Extract:

- `status` — skip agents with `blocked`; flag agents with `partial` for review
- `worktree` — path used for merge
- `commit` — sha for `git merge`, or "uncommitted" (requires manual copy)
- `files_changed` + `files_created` — used for conflict prediction
- `interface_deviations` — flag for orchestrator review before merging
- `out_of_scope_deps` — queue for post-merge fixes

## Step 2: Conflict Prediction

Before touching the working tree, cross-reference all agents' `files_changed`
and `files_created` lists. If any file appears in more than one agent's list:

1. Flag the conflict explicitly — show which agents both modified the file
2. Do not proceed until resolved (decide which version wins or merge manually)
3. This is a disjoint ownership violation — note it in the IMPL doc

Also check `out_of_scope_deps` across agents. If two agents flagged the same
file as an out-of-scope dependency with different required changes, flag for
review before merging.

**Expected conflict: IMPL doc completion reports.** Multiple agents appending
to the same IMPL doc will produce merge conflicts in that file. This is
expected — resolve by accepting all appended sections (each agent owns a
distinct `### Agent {letter} — Completion Report` section). For waves with
≥5 agents, use per-agent report files (`docs/reports/agent-{letter}.md`)
instead.

## Step 3: Review Interface Deviations

Before merging, review each agent's `interface_deviations` list. For each
deviation:

1. Assess whether downstream agents (in later waves) depend on the original
   contract
2. If yes: update the interface contract in the IMPL doc before those agents
   launch
3. If no: note the deviation and proceed

Do not skip this step — downstream agents read the IMPL doc, not worktrees.

## Step 4: Merge Each Agent

For each agent with `status: complete`, in any order (order is safe when file
ownership is disjoint):

```bash
worktree=".claude/worktrees/wave{N}-agent-{letter}"
branch="wave{N}-agent-{letter}"
commit="{sha from completion report}"

if [ "$commit" != "uncommitted" ]; then
  # Agent committed — use git merge
  git merge --no-ff "$branch" -m "Merge wave{N}-agent-{letter}: {short description}"
else
  # Agent left uncommitted changes — copy files manually
  for file in {files_changed} {files_created}; do
    cp "$worktree/$file" "./$file"
    git add "./$file"
  done
  git commit -m "Apply agent {letter} changes from worktree"
fi
```

## Step 5: Worktree Cleanup

After merging each agent:

```bash
git worktree remove "$worktree" 2>/dev/null || rm -rf "$worktree"
git branch -d "$branch" 2>/dev/null || true
```

Clean up even if agents failed — stale worktrees interfere with future waves.

## Step 6: Post-Merge Verification

Run the verification gate commands from the IMPL doc against the merged result.

Individual agents pass their gates in isolation, but the merged codebase can
surface issues none of them saw individually. This post-merge verification is
the real gate.

Pay particular attention to cascade candidates listed in the IMPL doc — files
outside agent scope that reference changed interfaces.

If verification fails, fix before proceeding. Do not launch the next wave
with a broken build.

## Step 7: IMPL Doc Updates

After verification passes:

1. Tick status checkboxes for completed agents (based on `status: complete`)
2. Update interface contracts where `interface_deviations` were logged
3. Queue `out_of_scope_deps` fixes — apply before launching the next wave
4. Commit the wave's changes
5. Launch the next wave (or pause if not `--auto`)
