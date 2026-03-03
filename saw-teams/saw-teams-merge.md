<!-- saw-teams-merge v0.1.2 -->
# SAW-Teams Merge Procedure

Merge teammate worktrees back into the main branch after a wave completes.
Adapted from `prompts/saw-merge.md` (v0.4.4): same merge mechanics, same
invariants, with teammate messaging as a supplement.

## Step 1: Parse Completion Reports

Read each teammate's structured completion report from the IMPL doc
(`### Agent {letter} - Completion Report`). Extract:

- `status`: if **any** teammate in the wave has `status: partial` or
  `status: blocked`, the wave does not proceed to merge. Stop here. Mark the
  wave BLOCKED in the IMPL doc. The failing teammate must be resolved (re-run,
  manually fixed, or descoped) before the merge step proceeds. Teammates that
  completed successfully are not re-run, but their worktrees are not merged
  until the full wave is resolved. Partial merges are not permitted.
- `worktree`: path used for merge
- `commit`: sha for `git merge`, or "uncommitted" (requires manual copy)
- `files_changed` + `files_created`: used for conflict prediction
- `interface_deviations`: flag for lead review before merging
- `out_of_scope_deps`: queue for post-merge fixes

**Cross-reference with teammate messages.** During wave execution, teammates
may have messaged the lead about interface deviations in real time. Verify
that every deviation reported via message also appears in the IMPL doc's
`interface_deviations` list. If a teammate messaged about a deviation but
it is missing from their IMPL doc report, add it to the report before
proceeding. The IMPL doc is the record of truth (I4); messages are
notifications, not records.

## Step 2: Conflict Prediction

Before touching the working tree, cross-reference all teammates'
`files_changed` and `files_created` lists. If any file appears in more than
one teammate's list:

1. Flag the conflict explicitly: show which teammates both modified the file
2. Do not proceed until resolved (decide which version wins or merge manually)
3. This is a disjoint ownership violation; note it in the IMPL doc

Also check `out_of_scope_deps` across teammates. If two teammates flagged the
same file as an out-of-scope dependency with different required changes, flag
for review before merging.

**Expected conflict: IMPL doc completion reports.** Multiple teammates
appending to the same IMPL doc will produce merge conflicts in that file.
This is expected; resolve by accepting all appended sections (each teammate
owns a distinct `### Agent {letter} - Completion Report` section). For waves
with ≥5 agents, use per-agent report files (`docs/reports/agent-{letter}.md`)
instead.

## Step 3: Review Interface Deviations

Before merging, review each teammate's `interface_deviations` list. For each
deviation:

1. Assess whether downstream agents (in later waves) depend on the original
   contract
2. If yes: update the interface contract in the IMPL doc **and** the affected
   agent's prompt section in the IMPL doc before that agent launches. Agent
   prompts are sections within the IMPL doc; updating a prompt means editing
   that section in-place. There is no separate prompt file to keep in sync.
3. If no: note the deviation and proceed

Do not skip this step; downstream agents read the IMPL doc, not worktrees.

**Teammate clarification (best-effort).** If a deviation is ambiguous, the
lead can message the responsible teammate to clarify before merging. In
standard SAW, the Orchestrator must guess from the report. In saw-teams, the
teammate may still be alive (Agent Teams shutdown can be slow) and can
respond. However, this is best-effort; teammates may already be shut down by
the time the lead reviews. The merge procedure must work without teammate
clarification. The clarification is an optimization, not a requirement.

### Downstream Propagation Flag

Deviations that require action in downstream agent prompts should be marked
with `downstream_action_required: true` in the completion report:

```yaml
interface_deviations:
  - description: "store_embedding requires #[allow(clippy::too_many_arguments)] - 9 params exceeds clippy default"
    downstream_action_required: true
    affects: [wave2b]
```

When `downstream_action_required: true` appears, the lead must update
the affected downstream agent prompts before launching that wave. Common
examples:
- Lint suppression attributes that must appear on all stub implementations
- Serialization annotations required by a changed type
- API call patterns that differ from the spec (e.g. library rejects `INSERT OR REPLACE`)

If the completion report uses freeform `interface_deviations` (no structured
flag), manually assess each one for downstream impact before proceeding.

## Same-Wave Interface Failure

If a teammate reports `status: blocked` because a contract in the current wave
is fundamentally unimplementable (not a deviation to document; the spec is
wrong), the wave halts before merge:

1. Mark the wave BLOCKED in the IMPL doc
2. Revise the affected interface contracts in the IMPL doc
3. Re-issue prompts to all teammates whose work depends on the changed contract
   (edit their prompt sections in the IMPL doc in-place)
4. Teammates that completed cleanly against unaffected contracts do not re-run;
   their worktrees remain valid
5. Re-launch only the affected teammates from WAVE_PENDING with the corrected
   contracts (spawn new teammates in a new team)

This is distinct from a future-wave deviation (`downstream_action_required: true`),
which propagates to the next wave without halting the current one.

## Step 4: Merge Each Teammate

For each teammate with `status: complete`, in any order (order is safe when
file ownership is disjoint):

```bash
worktree=".claude/worktrees/wave{N}-agent-{letter}"
branch="wave{N}-agent-{letter}"
commit="{sha from completion report}"

if [ "$commit" != "uncommitted" ]; then
  # Teammate committed - use git merge
  git merge --no-ff "$branch" -m "Merge wave{N}-agent-{letter}: {short description}"
else
  # Teammate left uncommitted changes - copy files manually
  for file in {files_changed} {files_created}; do
    cp "$worktree/$file" "./$file"
    git add "./$file"
  done
  git commit -m "Apply agent {letter} changes from worktree"
fi
```

## Step 5: Team Cleanup and Worktree Removal

Two cleanup phases in strict order:

**Phase A: Dismiss the team.** End the Agent Team. All teammates must be
stopped before their worktrees are removed; a teammate still writing to a
worktree during removal causes file system errors.

**Phase B: Remove worktrees.**

```bash
for agent in A B C; do
  git worktree remove ".claude/worktrees/wave{N}-agent-${agent}" 2>/dev/null || \
    rm -rf ".claude/worktrees/wave{N}-agent-${agent}"
  git branch -d "wave{N}-agent-${agent}" 2>/dev/null || true
done
```

Clean up even if teammates failed; stale worktrees and branches interfere
with future waves.

**Note on one-team-per-session:** Agent Teams currently supports one team per
session. If more waves remain after this merge, the lead must create a new
team for the next wave. This is expected overhead; document it, accept it.
The IMPL doc state persists across teams (it's a file, not team state).

## Step 6: Post-Merge Verification

Run the verification gate commands from the IMPL doc against the merged result.

Individual teammates pass their gates in isolation, but the merged codebase
can surface issues none of them saw individually. This post-merge verification
is the real gate.

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

This is the correct place for auto-fix: one centralized pass on the merged
result is cleaner and more reliable than requiring every teammate to know and
run the exact auto-fix command in their individual verification gates.

**Run tests unscoped using `test_command` from the IMPL doc.** Teammates
naturally scope their own verification to the packages they own. The lead's
post-merge gate must run without package scoping so cross-package cascade
failures are caught. Use the `test_command` field from the IMPL doc's
Suitability Assessment — the Scout derived it from the project's build system:

```bash
# Correct - catches cross-crate failures:
cargo test

# Insufficient - only catches failures within that crate:
cargo test -p commitmux-store
```

A common failure mode: a teammate adds a field to a shared type, scoped tests
pass in the teammate's worktree, but unscoped tests fail because a test in a
different crate constructs the type without the new field.

Pay particular attention to cascade candidates listed in the IMPL doc: files
outside agent scope that reference changed interfaces.

**Scaffold files:** If the Scaffold Agent produced type scaffold files for this wave,
verify they are present and unchanged in the merged result. Scaffold files are
committed to HEAD before worktrees branch; teammates implement against them but
do not own them. If a scaffold file is missing or was modified by a teammate,
this is a protocol deviation — investigate before proceeding.

If verification fails, fix before proceeding. Do not launch the next wave
with a broken build.

## Step 7: IMPL Doc Updates

After verification passes:

1. Tick status checkboxes for completed agents (based on `status: complete`)
2. Update interface contracts where `interface_deviations` were logged
3. Queue `out_of_scope_deps` fixes; apply before launching the next wave
4. Commit the wave's changes
5. Launch the next wave (create a new team) or pause if not `--auto`

## Crash Recovery

If the lead crashes mid-merge, do not re-run the full merge step;
it is not idempotent. Before continuing:

```bash
git log --merges --oneline
```

Identify which worktree branches have already been merged into main. Skip
those. Proceed only with worktrees whose branches do not yet appear in merge
history. Re-merging an already-merged worktree will duplicate commits or
produce conflicts.

### Agent Teams Crash Recovery (Lead Crash Mid-Wave)

Agent Teams has no session resumption. If the lead crashes mid-wave (before
merge), all in-progress teammates are lost. Their worktree branches may have
partial commits.

Recovery procedure:

1. Check `git worktree list`: identify any worktrees from the crashed wave
2. For each worktree, check if the branch has commits:
   ```bash
   git log wave{N}-agent-{letter} --oneline -1
   ```
3. If commits exist:
   - Read the IMPL doc for a completion report from this teammate
   - If a report exists: the teammate finished. Proceed with merge for this
     teammate.
   - If no report: the teammate crashed mid-work. The commits may be partial.
     Inspect the worktree (`git diff`, `git status` in the worktree path).
     Decide: merge partial work, discard and re-run, or fix manually.
4. If no commits: the teammate made no progress. Discard the worktree and
   re-run.

**This is worse than standard SAW's crash recovery.** In standard SAW, Agent
tool background agents may survive an orchestrator crash if the session is
resumed. In saw-teams, teammates are tied to the team's lifecycle; no team,
no teammates. The worktree branches and IMPL doc are the only surviving state.
This is a known limitation (DESIGN.md blocking issue 1).

**Mitigation:** If crash recovery is critical for your use case, use standard
SAW (`prompts/saw-skill.md`) instead of saw-teams. The IMPL doc is
execution-layer-agnostic; the same IMPL doc works with either execution
layer.
