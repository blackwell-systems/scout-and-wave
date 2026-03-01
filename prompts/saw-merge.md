<!-- saw-merge v0.4.2 -->
# SAW Merge Procedure

Merge agent worktrees back into the main branch after a wave completes.

## Step 1: Parse Completion Reports

Read each agent's structured completion report from the IMPL doc
(`### Agent {letter} — Completion Report`). Extract:

- `status` — if **any** agent in the wave has `status: partial` or `status: blocked`,
  the wave does not proceed to merge. Stop here. Mark the wave BLOCKED in the IMPL doc.
  The failing agent must be resolved (re-run, manually fixed, or descoped) before
  the merge step proceeds. Agents that completed successfully are not re-run, but
  their worktrees are not merged until the full wave is resolved. Partial merges
  are not permitted.
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
2. If yes: update the interface contract in the IMPL doc **and** the affected
   agent's prompt section in the IMPL doc before that agent launches. Agent
   prompts are sections within the IMPL doc — updating a prompt means editing
   that section in-place. There is no separate prompt file to keep in sync.
3. If no: note the deviation and proceed

Do not skip this step — downstream agents read the IMPL doc, not worktrees.

### Downstream Propagation Flag

Deviations that require action in downstream agent prompts should be marked
with `downstream_action_required: true` in the completion report:

```yaml
interface_deviations:
  - description: "store_embedding requires #[allow(clippy::too_many_arguments)] — 9 params exceeds clippy default"
    downstream_action_required: true
    affects: [wave2b]
```

When `downstream_action_required: true` appears, the orchestrator must update
the affected downstream agent prompts before launching that wave. Common
examples:
- Lint suppression attributes that must appear on all stub implementations
- Serialization annotations required by a changed type
- API call patterns that differ from the spec (e.g. library rejects `INSERT OR REPLACE`)

If the completion report uses freeform `interface_deviations` (no structured
flag), manually assess each one for downstream impact before proceeding.

## Same-Wave Interface Failure

If an agent reports `status: blocked` because a contract in the current wave is
fundamentally unimplementable (not a deviation to document — the spec is wrong),
the wave halts before merge:

1. Mark the wave BLOCKED in the IMPL doc
2. Revise the affected interface contracts in the IMPL doc
3. Re-issue prompts to all agents whose work depends on the changed contract
   (edit their prompt sections in the IMPL doc in-place)
4. Agents that completed cleanly against unaffected contracts do not re-run —
   their worktrees remain valid
5. Re-launch only the affected agents from WAVE_PENDING with the corrected contracts

This is distinct from a future-wave deviation (`downstream_action_required: true`),
which propagates to the next wave without halting the current one.

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

**Linter auto-fix pass (run first, before build and tests):**
If the project's CI config includes an auto-fix linter step, run it now on
the merged codebase before anything else. Common patterns:

```bash
# Go
golangci-lint run --fix ./...

# Python
ruff --fix . && black .

# JavaScript / TypeScript
eslint --fix src/ && prettier --write .

# Rust
cargo fmt

# Any project with a Makefile target
make lint-fix   # or: make fmt
```

After the auto-fix runs, check whether it changed any files:

```bash
git diff --name-only
```

If it did, commit those changes before running build and tests:

```bash
git add -A
git commit -m "style: post-merge lint/format fix"
```

This is the correct place for auto-fix — one centralized pass on the merged
result is cleaner and more reliable than requiring every agent to know and run
the exact auto-fix command in their individual verification gates.

**Run tests unscoped.** Agents naturally scope their own verification to the
packages they own. The orchestrator's post-merge gate must run without package
scoping so cross-package cascade failures are caught:

```bash
# Correct — catches cross-crate failures:
cargo test

# Insufficient — only catches failures within that crate:
cargo test -p commitmux-store
```

A common failure mode: an agent adds a field to a shared type, scoped tests
pass in the agent's worktree, but unscoped tests fail because a test in a
different crate constructs the type without the new field.

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

## Crash Recovery

If the orchestrator crashes mid-merge, do not re-run the full merge step —
it is not idempotent. Before continuing:

```bash
git log --merges --oneline
```

Identify which worktree branches have already been merged into main. Skip those.
Proceed only with worktrees whose branches do not yet appear in merge history.
Re-merging an already-merged worktree will duplicate commits or produce conflicts.
