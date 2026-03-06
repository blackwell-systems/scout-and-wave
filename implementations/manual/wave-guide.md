# Manual Wave Coordination Guide

**Role:** Coordinate parallel implementation work across team members using git worktrees.

**Time estimate:** 2-4 hours per agent (parallel execution).

**Prerequisites:** IMPL doc complete with agent prompts (from scout-guide.md).

---

## Overview

The Wave phase executes parallel implementation work. Each team member:
1. Receives an agent prompt (Fields 0-8 from IMPL doc)
2. Works in an isolated git worktree
3. Implements against frozen interface contracts
4. Runs verification before reporting complete
5. Commits to their worktree branch

**Coordinator role:** One person (usually the Scout) sets up worktrees and monitors progress. Team members execute their agent prompts independently.

---

## Phase 1: Pre-Launch Setup (Coordinator, 10-15 minutes)

### Step 1.1: Create Worktree Directory

```bash
cd /path/to/your/repo
mkdir -p .claude/worktrees
```

**Why this structure:** `.claude/worktrees/` is the canonical location. Monitoring tools expect this path (E5: worktree naming convention). See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E5.

---

### Step 1.2: Verify File Ownership (E3)

Before creating worktrees, check for file overlap:

```bash
# Extract file lists from IMPL doc
grep "Agent A" docs/IMPL/IMPL-feature.md -A 10 | grep "\.go"
grep "Agent B" docs/IMPL/IMPL-feature.md -A 10 | grep "\.go"
grep "Agent C" docs/IMPL/IMPL-feature.md -A 10 | grep "\.go"

# Manually check: any file appear in >1 agent's list?
```

**If overlap found:**
- STOP - do not create worktrees
- Correct IMPL doc file ownership table
- Re-run verification

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E3 for pre-launch ownership verification.

---

### Step 1.3: Create Worktrees for Each Agent

For a wave with 3 agents:

```bash
# Agent A worktree
git worktree add .claude/worktrees/wave1-agent-A -b wave1-agent-A

# Agent B worktree
git worktree add .claude/worktrees/wave1-agent-B -b wave1-agent-B

# Agent C worktree
git worktree add .claude/worktrees/wave1-agent-C -b wave1-agent-C
```

**Naming convention (E5):**
- Directory: `.claude/worktrees/wave{N}-agent-{letter}`
- Branch: `wave{N}-agent-{letter}`

**Why worktrees are mandatory (E4):**
- Prevents concurrent file system operations from interfering (build caches, lock files)
- Enables independent verification without affecting main branch
- Provides rollback capability (remove worktree = discard work)
- See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E4 for 5-layer isolation defense

---

### Step 1.4: Install Pre-Commit Hook (Layer 0 Isolation)

Copy the pre-commit hook to prevent accidental commits to main:

```bash
# If hooks/pre-commit-guard.sh exists in repo
cp hooks/pre-commit-guard.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Test it works
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test"  # Should BLOCK with error message
git checkout -
rm test.txt
```

**What the hook does:**
- Blocks commits to main during active waves
- Shows agent their correct worktree path if they try
- Coordinator can bypass with `SAW_ALLOW_MAIN_COMMIT=1` for legitimate main commits

**See:** [protocol/execution-rules.md](../../protocol/execution-rules.md) §E4 Layer 0 for hook rationale.

---

### Step 1.5: Verify Worktrees Created

```bash
git worktree list

# Expected output:
# /path/to/repo              <commit-sha>  [main]
# /path/to/repo/.claude/worktrees/wave1-agent-A  <commit-sha>  [wave1-agent-A]
# /path/to/repo/.claude/worktrees/wave1-agent-B  <commit-sha>  [wave1-agent-B]
# /path/to/repo/.claude/worktrees/wave1-agent-C  <commit-sha>  [wave1-agent-C]
```

If any worktree missing, re-run `git worktree add` command.

---

## Phase 2: Assign Work to Team Members (Coordinator, 5 minutes)

### Option A: In-Person Team

Print agent prompts from IMPL doc:

```bash
# Extract Agent A's prompt (Fields 0-8)
awk '/### Agent A -/,/### Agent B -/' docs/IMPL/IMPL-feature.md > /tmp/agent-A-prompt.md

# Give printed prompt to team member Alice
# Give Agent B prompt to Bob
# Give Agent C prompt to Carol
```

### Option B: Remote Team

Share via chat/email:

```
@alice: Your agent prompt is in docs/IMPL/IMPL-feature.md, section "### Agent A - Auth Handlers"
       Work in: .claude/worktrees/wave1-agent-A
       Report when complete or blocked

@bob: Your agent prompt is section "### Agent B - Database Layer"
      Work in: .claude/worktrees/wave1-agent-B

@carol: Your agent prompt is section "### Agent C - Config Updates"
        Work in: .claude/worktrees/wave1-agent-C
```

---

## Phase 3: Independent Implementation (Team Members, 2-4 hours)

Each team member independently:

### Step 3.1: Navigate to Worktree (Field 0 - Isolation Verification)

```bash
# Agent A example
cd /path/to/repo/.claude/worktrees/wave1-agent-A

# Verify working directory
pwd
# Expected: /path/to/repo/.claude/worktrees/wave1-agent-A

# Verify branch
git branch --show-current
# Expected: wave1-agent-A

# If either fails, STOP and notify coordinator
```

**Critical:** Do NOT skip this step. Working in wrong directory breaks isolation (I1 violation). See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E4 Layer 3.

---

### Step 3.2: Read Agent Prompt

Open IMPL doc and read your assigned section (Fields 0-8):
- **Field 1:** What files you own (ONLY modify these)
- **Field 2:** Interfaces you must implement
- **Field 3:** Interfaces you can call (from other agents or scaffolds)
- **Field 4:** Feature description (what to build)
- **Field 5:** Tests to write
- **Field 6:** Verification commands to run
- **Field 7:** Constraints and rules
- **Field 8:** How to report completion

---

### Step 3.3: Implement Feature (Field 4)

Write code following Field 4 instructions:

```bash
# Example: Agent A implementing auth handlers

# Create new files (if Field 1 says "new")
touch internal/auth/handler.go
touch internal/auth/middleware.go

# Edit files with your editor
vim internal/auth/handler.go

# Implement exactly what Field 4 specifies
```

**Rules:**
- Only modify files in Field 1 (your ownership list)
- Implement interfaces from Field 2 exactly as specified
- Import interfaces from Field 3 (scaffolds or prior waves)
- Do NOT change interface signatures without notifying coordinator (E8: interface deviation)

---

### Step 3.4: Write Tests (Field 5)

```bash
# Example: Agent A writing tests

touch internal/auth/handler_test.go
vim internal/auth/handler_test.go

# Write tests specified in Field 5
# - TestRegisterHandler_Success
# - TestRegisterHandler_InvalidEmail
# - etc.
```

---

### Step 3.5: Run Verification Gate (Field 6)

**Critical:** Run exact commands from Field 6, not project-wide commands.

```bash
# Example: Agent A verification (Field 6 says)

# Build
go build ./internal/auth
# Must pass (exit code 0)

# Lint
go vet ./internal/auth
# Must pass

# Tests
go test ./internal/auth -v
# Must pass
```

**If verification fails:**
- Fix the issue
- Re-run verification
- Do NOT report complete until all commands pass

**Why scoped commands:** Scoped verification (E10) keeps iteration fast. Post-merge gate runs unscoped to catch cross-package failures. See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E10.

---

### Step 3.6: Commit Changes (I5)

```bash
# Stage changes
git add .

# Verify what's staged
git status

# Commit
git commit -m "wave1-agent-A: implement auth handlers with tests"

# Record commit SHA
git log -1 --oneline
# Example output: abc1234 wave1-agent-A: implement auth handlers with tests
```

**Critical:** Commit BEFORE reporting complete (I5: agents commit before reporting). Uncommitted work cannot be merged. See [protocol/invariants.md](../../protocol/invariants.md) §I5.

---

### Step 3.7: Report Completion (Field 8)

Update IMPL doc with completion report:

```yaml
### Agent A - Completion Report

status: complete
worktree: .claude/worktrees/wave1-agent-A
branch: wave1-agent-A
commit: abc1234
files_changed:
  - internal/auth/handler.go (created, 87 lines)
  - internal/auth/middleware.go (created, 34 lines)
  - internal/auth/handler_test.go (created, 156 lines)
interface_deviations: []
out_of_scope_deps: []
tests_added:
  - TestRegisterHandler_Success
  - TestRegisterHandler_InvalidEmail
  - TestRegisterHandler_DuplicateUser
verification: PASS (build + lint + tests)
```

**How to add report:**
1. Open `docs/IMPL/IMPL-feature.md`
2. Scroll to end of file
3. Add your completion report (copy template from Field 8)
4. Save file
5. Notify coordinator: "Agent A complete, commit abc1234, all checks passed"

**If blocked or partial:** Set `status: blocked` or `status: partial`, explain what's wrong, notify coordinator immediately.

---

## Phase 4: Coordinator Monitoring (Coordinator, Ongoing)

### Track Progress

Keep a checklist of agent status:

```
Wave 1:
- [ ] Agent A (Alice)  - started 2:00 PM
- [ ] Agent B (Bob)    - started 2:00 PM
- [ ] Agent C (Carol)  - started 2:15 PM (late start)
```

### When Agent Reports Complete

1. Read their completion report in IMPL doc
2. Check `status: complete` (not `partial` or `blocked`)
3. Check `commit:` has SHA (not "uncommitted")
4. Check `verification: PASS`
5. Update checklist: `- [x] Agent A (Alice) - complete at 4:30 PM`

### When Agent Reports Blocked

**E7: Agent failure handling** - Do not merge until resolved.

**Common blockers:**

1. **Interface contract unimplementable (E8):**
   - Example: "Field 2 says implement `UserService.CreateUser(email string)` but we also need `password` parameter"
   - Resolution: Stop wave, revise interface contract in IMPL doc, notify all affected agents
   - See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E8

2. **Out-of-scope dependency:**
   - Example: "Need to modify `internal/config/loader.go` but it's not in my Field 1 ownership"
   - Resolution: Coordinator decides - expand ownership, or defer to next wave, or apply post-merge

3. **Verification failure:**
   - Example: "Tests pass locally but `go vet` reports errors"
   - Resolution: Agent fixes issue, re-runs verification, updates status to complete

**Action:** Do NOT proceed to merge until all agents report `status: complete`.

---

## Phase 5: Wave Completion (Coordinator, 5 minutes)

When all agents report complete:

### Step 5.1: Verify All Reports

```bash
# Check IMPL doc has all completion reports
grep "### Agent A - Completion Report" docs/IMPL/IMPL-feature.md
grep "### Agent B - Completion Report" docs/IMPL/IMPL-feature.md
grep "### Agent C - Completion Report" docs/IMPL/IMPL-feature.md

# Check all status: complete
grep "status:" docs/IMPL/IMPL-feature.md
# Expected:
# status: complete
# status: complete
# status: complete
```

### Step 5.2: Read Completion Reports

Check each report for:
- `interface_deviations: []` (empty is good)
- `out_of_scope_deps: []` (empty is good)
- `verification: PASS`

If any deviations or dependencies:
- Read details
- Decide how to handle (revise contracts, apply post-merge, defer to next wave)
- Document decision

---

## Common Wave Mistakes

1. **Working directly on main** → Breaks isolation, causes conflicts (Layer 0 hook should catch this)
2. **Running project-wide verification** → Slow iteration, violates E10 scoping rule
3. **Not committing before reporting** → I5 violation, merge cannot proceed
4. **Modifying files outside Field 1 ownership** → I1 violation, causes merge conflicts
5. **Reporting complete while tests fail** → Wastes merge time discovering failures later
6. **Changing interface signatures without notification** → E8 interface contract failure, blocks dependent agents

---

## Team Communication Tips

### Daily Standup (for long waves)

```
Alice: Agent A at 60% - auth handlers done, writing tests
Bob: Agent B blocked - need `password` param in CreateUser interface
Carol: Agent C at 90% - just running final verification

Action: Coordinator to resolve Bob's interface issue (E8 recovery)
```

### Slack/Chat Channel

```
#wave1-coordination

[2:00 PM] Coordinator: Wave 1 launched. Worktrees ready.
[2:01 PM] Alice: Agent A started
[2:01 PM] Bob: Agent B started
[2:15 PM] Carol: Agent C started (sorry for delay)
[3:30 PM] Bob: BLOCKED - need interface change (details in IMPL doc)
[3:35 PM] Coordinator: Reviewing Bob's blocker
[4:30 PM] Alice: Agent A complete, commit abc1234, all checks passed
[4:45 PM] Carol: Agent C complete, commit def5678, all checks passed
[5:00 PM] Coordinator: Bob's issue resolved, revised contract in IMPL
[5:30 PM] Bob: Agent B complete (retry), commit ghi9012, all checks passed
[5:35 PM] Coordinator: All agents complete, moving to merge phase
```

---

## Solo Wave Exception

If wave has exactly 1 agent:
- **Skip worktree creation** (agent works on main branch directly)
- **Skip merge phase** (nothing to merge)
- Agent still follows Fields 0-8, but Field 0 verifies `main` branch instead of worktree

Solo waves are rare (violate parallelization value P5), but occur when:
- Wave 1 has multiple agents, Wave 2 has only 1 agent (depends on Wave 1)
- Investigation phase (1 agent analyzes, next wave parallelizes fixes)

---

## Next Steps

After all agents report complete:
1. Proceed to [merge-guide.md](./merge-guide.md) for integration
2. Or if multi-wave: repeat Wave phase for next wave after verifying current wave

---

**References:**
- [protocol/invariants.md](../../protocol/invariants.md) - I1 (disjoint ownership), I5 (commit before reporting)
- [protocol/execution-rules.md](../../protocol/execution-rules.md) - E3 (ownership verification), E4 (worktree isolation), E5 (naming convention), E7 (failure handling), E8 (interface contract issues), E10 (scoped verification)
- [templates/completion-report.yaml](../../templates/completion-report.yaml) - Completion report structure
