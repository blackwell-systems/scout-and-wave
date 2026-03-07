# Manual Merge Procedure Guide

**Role:** Integrate parallel agent work into main branch.

**Time estimate:** 10-40 minutes depending on agent count (2 agents: 10 min, 5 agents: 40 min).

**Prerequisites:** All agents in wave report `status: complete` with commits.

---

## Overview

The Merge phase integrates agent branches into main. Steps:
1. Conflict prediction (E11) - check for file overlap before touching git
2. Per-agent merge - integrate one agent at a time
3. Post-merge verification - run project-wide build/test/lint
4. Worktree cleanup - remove worktrees and branches

**Executor:** Coordinator (same person who ran Scout and launched Wave).

---

## Phase 1: Pre-Merge Conflict Prediction (E11)

**Goal:** Detect I1 violations (file ownership overlap) before running git merge.

### Step 1.1: Extract File Lists from Completion Reports

```bash
# Read each agent's completion report from IMPL doc
# Extract files_changed and files_created lists

# Example:
Agent A changed: internal/auth/handler.go, internal/auth/middleware.go
Agent B changed: internal/database/user_repo.go, internal/database/migrations/003_users.sql
Agent C changed: cmd/api/routes.go, internal/config/config.go
```

### Step 1.2: Check for File Overlap

```bash
# Manual check: Any file appear in >1 agent's list?

Agent A: internal/auth/handler.go, internal/auth/middleware.go
Agent B: internal/database/user_repo.go, internal/database/migrations/003_users.sql
Agent C: cmd/api/routes.go, internal/config/config.go

→ No overlap, safe to proceed
```

**If overlap found:**
```
Agent A: internal/config/config.go (line added)
Agent C: internal/config/config.go (different line added)

→ OVERLAP DETECTED: I1 violation
```

**Recovery:**
- Stop merge immediately
- Check if both changes are append-only (different sections of file, no line conflicts)
- If append-only: Proceed with merge, resolve conflict manually (accept both changes)
- If not append-only: Scout error, should not have assigned same file to multiple agents

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E11 for conflict prediction rationale.

---

### Step 1.3: Verify All Agents Committed (Layer 4 Trip Wire)

```bash
# For each agent, verify their branch has commits beyond base

git log main..wave1-agent-A --oneline
# Should show ≥1 commit
# Example: abc1234 wave1-agent-A: implement auth handlers

git log main..wave1-agent-B --oneline
# Should show ≥1 commit

git log main..wave1-agent-C --oneline
# Should show ≥1 commit
```

**If any branch empty:**
```
git log main..wave1-agent-A --oneline
# (no output)

→ ISOLATION FAILURE: Agent A committed to main instead of worktree
```

**Recovery:**
- Check if agent's work is on main (they bypassed hook somehow)
- If yes: Cherry-pick commits to worktree branch, continue
- If no: Agent didn't commit (I5 violation), cannot merge

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E4 Layer 4 for trip wire rationale.

---

## Phase 2: Per-Agent Merge

**E11:** Merge order is arbitrary within a valid wave. Pick any order.

### Step 2.1: Merge First Agent

```bash
# Switch to main
git checkout main

# Merge Agent A
git merge --no-ff wave1-agent-A -m "Merge wave1-agent-A: implement auth handlers"
```

**Why `--no-ff`:** Preserves branch history for observability. Shows which commits came from which agent.

---

### Step 2.2: Handle Conflicts (E12)

Git merge can produce three types of conflicts:

#### Type 1: Conflict on Agent-Owned Files

```
Auto-merging internal/auth/handler.go
CONFLICT (content): Merge conflict in internal/auth/handler.go
```

**What it means:** I1 violation. Two agents modified same file (should not happen if Scout did file ownership correctly).

**Recovery:**
```bash
# Abort merge
git merge --abort

# Investigate: Why did two agents touch this file?
# Check IMPL doc file ownership table

# Fix: Correct ownership table, recreate worktrees, re-run wave
```

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E12 for conflict taxonomy.

---

#### Type 2: Conflict on IMPL Doc (Completion Reports)

```
Auto-merging docs/IMPL/IMPL-feature.md
CONFLICT (content): Merge conflict in docs/IMPL/IMPL-feature.md
```

**What it means:** Expected. Multiple agents appended completion reports to same file (E14: write discipline).

**Resolution:**
```bash
# Open conflict file
vim docs/IMPL/IMPL-feature.md

# Git shows:
<<<<<<< HEAD
### Agent A - Completion Report
status: complete
...
=======
### Agent B - Completion Report
status: complete
...
>>>>>>> wave1-agent-B

# Resolution: Accept BOTH sections (they don't conflict semantically)
### Agent A - Completion Report
status: complete
...

### Agent B - Completion Report
status: complete
...

# Save file, stage, continue
git add docs/IMPL/IMPL-feature.md
git commit -m "Merge wave1-agent-B: resolve completion report ordering"
```

**Why this works:** Each agent writes to their own named section (E14). No semantic conflict, only git adjacent-line conflict.

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E12 Type 2, §E14 for write discipline.

---

#### Type 3: Conflict on Orchestrator-Owned Append-Only Files

```
Auto-merging internal/registry/handlers.go
CONFLICT (content): Merge conflict in internal/registry/handlers.go
```

**What it means:** Expected if Scout marked file as orchestrator-owned (append-only config registry).

**Resolution:**
```bash
# Open conflict file
vim internal/registry/handlers.go

# Git shows:
<<<<<<< HEAD
var handlers = []Handler{
    {Path: "/users", Handler: usersHandler},
    {Path: "/auth", Handler: authHandler},  // Agent A added this
}
=======
var handlers = []Handler{
    {Path: "/users", Handler: usersHandler},
    {Path: "/auth", Handler: authHandler},  // Agent B also added this (different)
}
>>>>>>> wave1-agent-B

# If both additions are different, accept both:
var handlers = []Handler{
    {Path: "/users", Handler: usersHandler},
    {Path: "/auth", Handler: authHandler},
    {Path: "/auth", Handler: authHandler},  // Duplicate line, fix manually
}

# Remove duplicate, keep distinct entries
var handlers = []Handler{
    {Path: "/users", Handler: usersHandler},
    {Path: "/auth", Handler: authHandler},
}

# Stage and commit
git add internal/registry/handlers.go
git commit -m "Merge wave1-agent-B: resolve registry append conflict"
```

**See:** [protocol/preconditions.md](../../protocol/preconditions.md) §P1 for append-only definition.

---

### Step 2.3: Verify Merge Success

```bash
# Check working tree is clean
git status
# Expected: "nothing to commit, working tree clean"

# Check merge commit created
git log -1 --oneline
# Expected: <sha> Merge wave1-agent-A: implement auth handlers
```

---

### Step 2.4: Repeat for Remaining Agents

```bash
# Merge Agent B
git merge --no-ff wave1-agent-B -m "Merge wave1-agent-B: implement database layer"
# (handle conflicts if any, verify clean)

# Merge Agent C
git merge --no-ff wave1-agent-C -m "Merge wave1-agent-C: update config"
# (handle conflicts if any, verify clean)
```

**Note:** If a conflict occurs mid-merge and you can't resolve it immediately, run:
```bash
git merge --abort
# Investigate issue, fix IMPL doc if needed, restart merge procedure
```

---

## Phase 3: Post-Merge Verification

**E10:** Orchestrator runs unscoped (project-wide) verification to catch cascade failures that scoped agent verification missed.

### Step 3.1: Project-Wide Build

```bash
# Example: Go project
go build ./...

# Example: TypeScript project
npm run build

# Example: Rust project
cargo build --all
```

**If build fails:**
```
internal/service/user_service.go:23:15: undefined: User

→ Cascade failure: Agent B's code calls type from Agent A that wasn't imported
```

**Recovery:**
- Identify root cause (missing import, type mismatch, incompatible interfaces)
- Fix manually (add import, adjust type)
- Commit fix: `git commit -m "fix: add missing User import after merge"`
- Re-run verification

---

### Step 3.2: Project-Wide Lint

```bash
# Example: Go project
go vet ./...

# Example: TypeScript project
npm run lint

# Example: Rust project
cargo clippy --all
```

**If lint fails:**
```
internal/auth/handler.go:45:2: unused variable: ctx

→ Agent code has lint issues that passed scoped verification but fail project-wide
```

**Recovery:**
- Fix lint issues
- Commit fix: `git commit -m "fix: remove unused variable after merge"`
- Re-run verification

---

### Step 3.3: Project-Wide Tests

```bash
# Example: Go project
go test ./...

# Example: TypeScript project
npm test

# Example: Rust project
cargo test --all
```

**If tests fail:**
```
--- FAIL: TestUserService_CreateUser (0.00s)
    user_service_test.go:34: got nil, want error

→ Integration failure: Agent A's handler calls Agent B's service with wrong parameters
```

**Recovery:**
- Identify root cause (interface mismatch, wrong parameter types, missing error handling)
- Fix manually
- Commit fix: `git commit -m "fix: correct CreateUser parameter types after merge"`
- Re-run verification

---

### Step 3.4: Check Interface Deviations (E6)

Read completion reports for `interface_deviations` field:

```yaml
### Agent A - Completion Report
interface_deviations:
  - Field 2 specified CreateUser(email string), implemented as CreateUser(email, password string)
  - Reason: Password required for user creation, was missing from interface contract
  - Downstream action required: yes
  - Affected agents: [C, D] in Wave 2
```

**Action:**
- Update IMPL doc Field 3 for affected agents in future waves
- Document change in IMPL doc wave frontmatter
- No immediate fix needed (Wave 1 already merged)

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E6 for agent prompt propagation.

---

### Step 3.5: Apply Out-of-Scope Dependencies

Read completion reports for `out_of_scope_deps` field:

```yaml
### Agent A - Completion Report
out_of_scope_deps:
  - File internal/middleware/logger.go needs to be updated to log auth events
  - Suggested owner: Orchestrator post-merge
```

**Action:**
```bash
# Orchestrator applies the change manually
vim internal/middleware/logger.go
# Add auth event logging

git add internal/middleware/logger.go
git commit -m "chore: add auth event logging (out-of-scope dep from Agent A)"
```

---

## Phase 4: Worktree Cleanup

### Step 4.1: Remove Worktrees

```bash
# Remove Agent A worktree
git worktree remove .claude/worktrees/wave1-agent-A

# Remove Agent B worktree
git worktree remove .claude/worktrees/wave1-agent-B

# Remove Agent C worktree
git worktree remove .claude/worktrees/wave1-agent-C

# Verify all removed
git worktree list
# Should only show main worktree
```

---

### Step 4.2: Delete Agent Branches (Optional)

```bash
# Keep branches if you want to preserve history
# Delete branches if you want clean branch list

git branch -d wave1-agent-A
git branch -d wave1-agent-B
git branch -d wave1-agent-C
```

**Note:** Branches are already merged into main, so `-d` (safe delete) works. If branch not merged, git refuses deletion.

---

### Step 4.3: Remove Pre-Commit Hook

```bash
# Remove the hook installed during wave setup
rm .git/hooks/pre-commit

# Or restore original if existed
# mv .git/hooks/pre-commit.backup .git/hooks/pre-commit
```

---

## Phase 5: Wave Completion

### Step 5.1: Update IMPL Doc Status Table

```markdown
## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Auth handlers | ✓ MERGED |
| 1 | B | Database layer | ✓ MERGED |
| 1 | C | Config updates | ✓ MERGED |
```

---

### Step 5.2: Commit IMPL Doc Update

```bash
git add docs/IMPL/IMPL-feature.md
git commit -m "docs: mark Wave 1 complete in IMPL doc"
```

---

### Step 5.3: Celebrate and Report

Wave 1 complete! Notify team:

```
Wave 1 merged successfully:
- 3 agents integrated
- 12 files changed
- Build + tests + lint: PASS
- Merge time: 15 minutes
- Total time: 3.5 hours (scout 1h + wave 2h parallel + merge 0.5h)

Next: Review completion for next wave or mark feature complete
```

---

## Multi-Wave Projects

If IMPL doc defines multiple waves:

### After Wave N Completes

**I3: Wave sequencing** - Wave N+1 does not launch until Wave N verified.

```
Wave 1: MERGED ✓
  → main branch now has Wave 1 code

Wave 2: TO-DO
  → Wave 2 agents will branch from current main (includes Wave 1)
  → Repeat wave-guide.md and merge-guide.md for Wave 2
```

**See:** [protocol/invariants.md](../../protocol/invariants.md) §I3 for wave sequencing rationale.

---

## Common Merge Mistakes

1. **Merging before all agents complete** → E7 violation, partial work in main
2. **Skipping post-merge verification** → Cascade failures surface in production
3. **Forgetting to remove worktrees** → Disk space bloat, confusion in future waves
4. **Resolving conflicts incorrectly** → Deleting one agent's work instead of integrating both
5. **Not reading interface_deviations** → Future waves implement against outdated contracts

---

## Error Recovery

### Merge Went Wrong

```bash
# If you merged but verification fails and can't fix immediately
git reset --hard HEAD~3  # Undo last 3 merge commits (if 3 agents)
# WARNING: This discards merge commits, not agent work (worktrees still exist)

# Fix issue (correct IMPL doc, re-run agents if needed)
# Retry merge procedure from Phase 1
```

### Accidentally Deleted Agent Work

```bash
# If you removed worktree before merging
git worktree add .claude/worktrees/wave1-agent-A wave1-agent-A
# Recreates worktree from existing branch

# Continue merge procedure
```

---

## Non-Idempotent Warning (E9)

**Critical:** Merge phase is NOT idempotent. Do not re-run merge commands after partial success.

**If merge crashes mid-way:**
```bash
# Check which agents already merged
git log --oneline --graph

# Example output:
* def5678 (HEAD -> main) Merge wave1-agent-B: database layer
* abc1234 Merge wave1-agent-A: auth handlers

→ Agent A and B already merged, only Agent C remains
```

**Continue from where you stopped:**
```bash
# Skip already-merged agents, merge remaining
git merge --no-ff wave1-agent-C -m "Merge wave1-agent-C: config updates"
```

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E9 for idempotency warning.

---

## Next Steps

### If More Waves Exist

Repeat the cycle:
1. Return to [wave-guide.md](./wave-guide.md) for next wave
2. Create new worktrees (wave2-agent-X)
3. Launch agents with prompts from IMPL doc Wave 2 section
4. Merge using this guide again

### If Feature Complete

```bash
# Optional: Create feature branch tag
git tag -a v1.0.0-feature-auth -m "User authentication feature complete"

# Optional: Push to remote
git push origin main
git push origin --tags

# Update project documentation (README, CHANGELOG)
```

---

**References:**
- [protocol/invariants.md](../../protocol/invariants.md) - I1 (disjoint ownership), I3 (wave sequencing), I5 (commit before reporting)
- [protocol/execution-rules.md](../../protocol/execution-rules.md) - E6 (agent prompt propagation), E7 (failure handling), E9 (idempotency), E10 (scoped vs unscoped verification), E11 (conflict prediction), E12 (merge conflict taxonomy), E14 (IMPL doc write discipline)
- [protocol/procedures.md](../../protocol/procedures.md) - Complete merge procedure specification
