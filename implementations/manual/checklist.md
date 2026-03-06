# Manual Scout-and-Wave Checklist

**Purpose:** Printable checkbox checklist for tracking manual SAW execution.

**Instructions:** Print this checklist and check boxes as you complete each step. Reference detailed guides for procedures.

---

## Scout Phase (30-90 minutes)

**Goal:** Assess suitability and produce IMPL doc with agent prompts.

### Suitability Assessment

- [ ] **P1: File Decomposition** - Work splits into ≥2 disjoint file groups ([scout-guide.md](./scout-guide.md) §P1)
- [ ] **P2: No Investigation-First** - All work fully specifiable before starting ([scout-guide.md](./scout-guide.md) §P2)
- [ ] **P3: Interface Discoverability** - All cross-agent interfaces definable upfront ([scout-guide.md](./scout-guide.md) §P3)
- [ ] **P4: Pre-Implementation Scan** - All audit items classified (TO-DO/DONE/PARTIAL) ([scout-guide.md](./scout-guide.md) §P4)
- [ ] **P5: Positive Parallelization Value** - Time savings exceed overhead ([scout-guide.md](./scout-guide.md) §P5)

**If any precondition fails → Write "NOT SUITABLE" verdict, stop protocol**

### IMPL Doc Production

- [ ] Write suitability verdict (SUITABLE or NOT SUITABLE) in IMPL doc
- [ ] Draw dependency graph (which agents depend on which)
- [ ] Define interface contracts (exact function signatures)
- [ ] Create file ownership table (no file in >1 agent's list)
- [ ] Write agent prompts (Field 0-8 for each agent) ([templates/agent-prompt-template.md](../../templates/agent-prompt-template.md))
- [ ] Verify no file ownership overlap (E3: pre-launch check)
- [ ] Save IMPL doc to `docs/IMPL/IMPL-{feature-name}.md`
- [ ] Review and approve IMPL doc

**Time estimate:** Scout phase complete _____:_____ (date/time)

---

## Wave Phase (2-4 hours per agent, parallel)

**Goal:** Execute parallel implementation in isolated worktrees.

### Coordinator Setup (10-15 minutes)

- [ ] Create `.claude/worktrees/` directory
- [ ] Verify file ownership (no overlap) before creating worktrees (E3)
- [ ] Create worktree for Agent A: `git worktree add .claude/worktrees/wave{N}-agent-A -b wave{N}-agent-A`
- [ ] Create worktree for Agent B: `git worktree add .claude/worktrees/wave{N}-agent-B -b wave{N}-agent-B`
- [ ] Create worktree for Agent C: `git worktree add .claude/worktrees/wave{N}-agent-C -b wave{N}-agent-C`
- [ ] Create worktree for Agent ___ (if more agents)
- [ ] Install pre-commit hook: `cp hooks/pre-commit-guard.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
- [ ] Verify worktrees created: `git worktree list`
- [ ] Assign agent prompts to team members (print or share via chat)

### Per-Agent Execution (each team member independently)

**Agent ___ (team member: _______________)**

- [ ] Navigate to worktree: `cd .claude/worktrees/wave{N}-agent-{letter}`
- [ ] Verify working directory: `pwd` matches expected path
- [ ] Verify branch: `git branch --show-current` matches expected branch
- [ ] Read agent prompt (Fields 0-8) from IMPL doc
- [ ] Implement feature (Field 4) - only modify files from Field 1
- [ ] Write tests (Field 5)
- [ ] Run verification commands (Field 6):
  - [ ] Build passes
  - [ ] Lint passes
  - [ ] Tests pass
- [ ] Commit changes: `git add . && git commit -m "wave{N}-agent-{letter}: description"`
- [ ] Record commit SHA: _______________
- [ ] Write completion report in IMPL doc (status: complete)
- [ ] Notify coordinator: "Agent ___ complete"

**Repeat checklist for each agent in wave**

### Coordinator Monitoring

- [ ] Agent A reported complete (commit SHA: _______________)
- [ ] Agent B reported complete (commit SHA: _______________)
- [ ] Agent C reported complete (commit SHA: _______________)
- [ ] Agent ___ reported complete (commit SHA: _______________)
- [ ] All agents have `status: complete` (not partial or blocked)
- [ ] All agents have commit SHAs (not "uncommitted")
- [ ] All agents have `verification: PASS`

**Time estimate:** Wave phase complete _____:_____ (date/time)

---

## Merge Phase (10-40 minutes)

**Goal:** Integrate agent branches into main.

### Pre-Merge Checks (E11)

- [ ] Extract file lists from all completion reports
- [ ] Check for file overlap (any file in >1 agent's list?)
  - [ ] If overlap found: Investigate, resolve before merging
- [ ] Verify all agent branches have commits: `git log main..wave{N}-agent-{letter}`
  - [ ] Agent A branch has commits (not empty)
  - [ ] Agent B branch has commits (not empty)
  - [ ] Agent C branch has commits (not empty)
  - [ ] Agent ___ branch has commits (if applicable)

### Per-Agent Merge

- [ ] Checkout main: `git checkout main`
- [ ] Merge Agent A: `git merge --no-ff wave{N}-agent-A -m "Merge wave{N}-agent-A: description"`
  - [ ] Handle conflicts if any (E12: see [merge-guide.md](./merge-guide.md) §2.2)
  - [ ] Verify clean: `git status` shows "nothing to commit"
- [ ] Merge Agent B: `git merge --no-ff wave{N}-agent-B -m "Merge wave{N}-agent-B: description"`
  - [ ] Handle conflicts if any
  - [ ] Verify clean
- [ ] Merge Agent C: `git merge --no-ff wave{N}-agent-C -m "Merge wave{N}-agent-C: description"`
  - [ ] Handle conflicts if any
  - [ ] Verify clean
- [ ] Merge Agent ___ (if more agents)

### Post-Merge Verification (E10)

- [ ] Project-wide build passes: `go build ./...` (or equivalent)
- [ ] Project-wide lint passes: `go vet ./...` (or equivalent)
- [ ] Project-wide tests pass: `go test ./...` (or equivalent)
- [ ] Read interface_deviations from completion reports
  - [ ] Update affected agent prompts for future waves (E6)
- [ ] Apply out_of_scope_deps fixes
  - [ ] Commit fixes: `git commit -m "chore: apply out-of-scope deps"`

### Worktree Cleanup

- [ ] Remove Agent A worktree: `git worktree remove .claude/worktrees/wave{N}-agent-A`
- [ ] Remove Agent B worktree: `git worktree remove .claude/worktrees/wave{N}-agent-B`
- [ ] Remove Agent C worktree: `git worktree remove .claude/worktrees/wave{N}-agent-C`
- [ ] Remove Agent ___ worktree (if more)
- [ ] Delete agent branches (optional): `git branch -d wave{N}-agent-{letter}`
- [ ] Remove pre-commit hook: `rm .git/hooks/pre-commit`
- [ ] Verify cleanup: `git worktree list` shows only main

### Wave Completion

- [ ] Update IMPL doc status table (mark wave as MERGED)
- [ ] Commit IMPL doc: `git commit -m "docs: mark Wave {N} complete"`
- [ ] Notify team: "Wave {N} merged successfully"

**Time estimate:** Merge phase complete _____:_____ (date/time)

---

## Inter-Wave Checkpoint (if multi-wave project)

- [ ] Review Wave {N} completion reports
- [ ] Check if more waves defined in IMPL doc
- [ ] If interface deviations exist:
  - [ ] Update affected agent prompts in IMPL doc for Wave {N+1}
  - [ ] Document changes in wave frontmatter
- [ ] Approve continuation to next wave (or pause for review)
- [ ] **Return to Wave Phase section above for Wave {N+1}**

---

## Project Completion

- [ ] All waves merged and verified
- [ ] No outstanding blockers or partial work
- [ ] Final project-wide verification:
  - [ ] Build passes
  - [ ] Tests pass
  - [ ] Lint passes
- [ ] Update CHANGELOG.md (if applicable)
- [ ] Update README.md (if feature requires documentation)
- [ ] Create git tag (optional): `git tag -a v1.0.0-feature-name -m "description"`
- [ ] Push to remote: `git push origin main && git push origin --tags`
- [ ] Close related issues/tickets

**Total time:** Scout ___h + Wave ___h + Merge ___h = ___h total

---

## Common Issues and Recovery

### Issue: Agent Reported Blocked

- [ ] Read agent's completion report for blocker details
- [ ] Identify blocker type:
  - [ ] Interface contract unimplementable (E8) → Revise contracts, update prompts, re-run wave
  - [ ] Out-of-scope dependency → Expand ownership or defer to next wave
  - [ ] Verification failure → Agent fixes and re-runs
- [ ] Do NOT merge until all agents report `status: complete`

### Issue: Merge Conflict on Agent-Owned Files

- [ ] **STOP** - This is I1 violation (should not happen)
- [ ] Abort merge: `git merge --abort`
- [ ] Investigate: Check IMPL doc file ownership table
- [ ] Fix: Correct ownership, recreate worktrees, re-run wave

### Issue: Post-Merge Verification Failed

- [ ] Read error message carefully
- [ ] Identify failure type:
  - [ ] Build error → Missing import, type mismatch → Fix manually
  - [ ] Test error → Integration issue → Fix manually
  - [ ] Lint error → Code quality → Fix manually
- [ ] Commit fix: `git commit -m "fix: description"`
- [ ] Re-run verification
- [ ] If can't fix immediately: `git reset --hard HEAD~{N}` to undo merges, fix issue, retry

### Issue: Forgot to Create Worktree

- [ ] Check if agent committed to main: `git log main --oneline`
- [ ] If yes:
  - [ ] Create worktree: `git worktree add .claude/worktrees/wave{N}-agent-{letter} -b wave{N}-agent-{letter}`
  - [ ] Cherry-pick commits to worktree branch: `git cherry-pick <commit-sha>`
  - [ ] Reset main: `git reset --hard HEAD~{N}` to remove commits
  - [ ] Continue with proper workflow

---

## Reference Timeline (typical 3-agent wave)

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Scout | 1 hour | 1h |
| Coordinator setup worktrees | 15 min | 1h 15m |
| Wave execution (parallel) | 3 hours | 4h 15m |
| Merge | 20 min | 4h 35m |
| **Total** | **~4.5 hours** | |

**Note:** Wave execution is parallel (all agents work simultaneously), so total time is max(agent times) not sum(agent times).

---

## References

- [scout-guide.md](./scout-guide.md) - Detailed Scout phase procedures
- [wave-guide.md](./wave-guide.md) - Detailed Wave phase procedures
- [merge-guide.md](./merge-guide.md) - Detailed Merge phase procedures
- [protocol/preconditions.md](../../protocol/preconditions.md) - P1-P5 suitability gate
- [protocol/invariants.md](../../protocol/invariants.md) - I1-I6 constraints
- [protocol/execution-rules.md](../../protocol/execution-rules.md) - E1-E14 procedures
