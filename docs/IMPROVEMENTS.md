# SAW Pattern Improvements Queue

Lessons learned from real-world usage, pending implementation.

## From brewprune Round 5 Wave 1 (2026-02-28)

### ⚠️ CRITICAL: Worktree Isolation Verification Failed

**Issue discovered:** Wave 1 launched 5 agents with `isolation: "worktree"` parameter, but NO worktrees were created. All agents modified files directly on main branch.

**What happened:**
- Task tool invoked with `isolation: "worktree"` for all 5 agents
- `git worktree list` showed only main worktree (no agent branches created)
- All agent changes appeared as modified files in `git status` on main
- No merge step occurred - changes were already on main

**Why it didn't cause conflicts:**
- File ownership was truly disjoint (A→root.go, B→undo.go, C→stats.go, D→explain.go, E→unused.go)
- Agent E's out-of-scope change (table.go) wasn't touched by other agents
- **Pure luck** - if two agents had modified same file → silent data loss

**Root cause analysis needed:**
1. Is `isolation: "worktree"` parameter actually implemented in Task tool?
2. Does it require additional prerequisites (git repo state, permissions)?
3. Is there error handling if worktree creation fails?
4. Should agents receive feedback if isolation fails?

**Pattern fix required:**

**Priority 1 - Strict Worktree Enforcement (Orchestrator-Level):**

Replace reliance on Task tool's `isolation: "worktree"` parameter with explicit worktree creation:

```bash
# BEFORE launching agents:

# 1. Create worktree directory
mkdir -p .claude/worktrees

# 2. For each agent, explicitly create worktree
for agent in A B C D E; do
  branch="wave1-agent-${agent}"
  worktree_path=".claude/worktrees/${branch}"

  # Remove stale worktree if exists
  git worktree remove "$worktree_path" 2>/dev/null || true

  # Create fresh worktree from current main
  git worktree add "$worktree_path" -b "$branch" || {
    echo "FATAL: Failed to create worktree for Agent $agent"
    exit 1
  }

  # Verify it exists
  [ -d "$worktree_path" ] || {
    echo "FATAL: Worktree directory not found: $worktree_path"
    exit 1
  }

  echo "✓ Agent $agent worktree created: $worktree_path"
done

# 3. Verify count before launching ANY agents
expected=$((5 + 1))  # 5 agents + main
actual=$(git worktree list | wc -l)
if [ "$actual" -ne "$expected" ]; then
  echo "FATAL: Expected $expected worktrees, found $actual"
  git worktree list
  exit 1
fi

# 4. NOW launch agents (without isolation parameter - already isolated)
```

**Priority 2 - Fail-Fast Agent Self-Verification:**

Add mandatory pre-flight check to agent template (BEFORE any file modifications):

```markdown
## 0. CRITICAL: Isolation Verification (RUN FIRST)

**BEFORE ANY WORK:**

Run isolation verification:

\`\`\`bash
# Check location
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/path/to/repo/.claude/worktrees/wave1-agent-A"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-A"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

# Verify worktree exists in git's records
git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "✓ Isolation verified"
\`\`\`

**If verification fails:**
1. Write failure to completion report immediately:
   \`\`\`
   ### Agent X — Completion Report

   **ISOLATION VERIFICATION FAILED**

   Expected: .claude/worktrees/wave1-agent-X on branch wave1-agent-X
   Actual: [paste pwd and git branch output]

   **No work performed.** Cannot proceed without confirmed isolation.
   \`\`\`
2. Exit immediately (do NOT modify any code files)
3. Do NOT attempt recovery (cd, branch switch, etc) - let orchestrator fix

**If verification passes:**
- Document verification success in completion report
- Proceed with assigned file modifications
```

**Priority 3 - Post-Launch Orchestrator Safety Check:**

After launching all agents, check for immediate failures:

```bash
# Give agents 10s to run pre-flight checks
sleep 10

# Check if any completion reports show isolation failures
if grep -r "ISOLATION VERIFICATION FAILED" docs/IMPL-*.md 2>/dev/null; then
  echo "FATAL: One or more agents failed isolation verification"
  echo "Stopping wave execution"
  git worktree list
  exit 1
fi
```

**Priority 2 - Document Failure Mode:**

Add to scout.md and saw-skill.md:

```markdown
## Worktree Isolation Verification

After launching agents, verify worktrees were created:

**Check:** `git worktree list` should show N+1 entries (main + N agents)

**If verification fails:**
- Agents are modifying main branch directly (NO ISOLATION)
- Risk of conflicts if file ownership overlaps
- STOP and investigate before proceeding

**Known failure modes:**
- Task tool version doesn't support isolation parameter
- Git worktree feature disabled or unavailable
- Repository state prevents worktree creation
- Insufficient disk space for worktree copies

**Workaround if worktrees unavailable:**
- Reduce wave size to 1-2 agents (sequential execution)
- Manually verify file ownership is STRICTLY disjoint
- Monitor git status during agent execution
- Run post-merge verification immediately after each agent
```

**Design rationale for self-healing + fail-fast approach:**

Agents can't fix all environment issues, but they CAN attempt self-correction and refuse to work if unsuccessful:
- ❌ Can't create missing worktrees (orchestrator's job, might conflict)
- ❌ Can't kill themselves cleanly (background task, no orchestrator communication)
- ❌ Can't fix permissions or install dependencies (limited scope, no sudo)
- ✅ CAN attempt cd to correct worktree location (self-healing)
- ✅ CAN detect bad state via pwd/git branch checks (verification)
- ✅ CAN write error to completion report (creates audit trail)
- ✅ CAN exit without modifying files (prevents damage)

Self-verification combines self-correction (Layer 1.5) with strict verification (Layer 2). Agents first attempt `cd` to the expected worktree, then verify the environment is correct. If verification fails after the cd attempt, the agent cannot self-correct and must fail fast. Orchestrator reads completion reports after 10s, detects isolation failures, and stops wave execution.

**Defense in depth (4 layers):**
1. **Orchestrator pre-creates worktrees** - fails fast if creation impossible
2. **Agent attempts self-correction** - tries cd to expected worktree location
3. **Agent verifies isolation** - catches tool failures, refuses to work if verification fails
4. **Post-merge verification** - final integration check (existing mechanism)

**Evidence:**
- brewprune Round 5 Wave 1 (2026-02-28)
- 5 agents launched, 0 worktrees created
- Commit: 521b3ec
- Zero conflicts only due to perfect file disjointness (pure luck)

**Impact:** CRITICAL - undermines core safety mechanism of SAW pattern

**Next steps:**
1. ✅ Implemented Priority 1 (explicit worktree creation) in saw-skill.md orchestrator logic
2. ✅ Implemented Priority 2 (fail-fast verification) in agent-template.md section 0 (pre-flight)
3. ✅ Implemented Priority 3 (post-launch safety check) in saw-skill.md after agent launch
4. ✅ Tested with brewprune Round 5 Wave 2 → discovered new failure mode (see below)

### ✓ VALIDATED: Fail-Fast Verification Caught Working Directory Issue (2026-02-28)

**Issue discovered:** Wave 2 launched with worktrees pre-created successfully, but agents still failed isolation verification.

**What happened:**
- Orchestrator created worktrees correctly (verified via `git worktree list`)
- Task agents launched with `isolation: "worktree"` parameter
- Agents inherited parent session's working directory (`/Users/dayna.blackwell/code/gsm`)
- Agent self-verification (Layer 2) detected wrong directory and refused to work
- Zero files modified (fail-fast prevented damage)

**Root cause:** Task tool's `isolation: "worktree"` parameter creates worktrees but doesn't automatically `cd` into them. Agents need to explicitly change directory before working.

**Pattern improvement - Layer 1.5 (Self-Healing):**

Added self-correction step to agent template Section 0:

```bash
# Step 1: Attempt environment correction
cd {absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter} 2>/dev/null || true

# Step 2: Verify isolation (strict fail-fast)
[existing verification checks]
```

**Philosophy shift:** From "detect-only" to "self-healing + detect":
- Agents first attempt `cd` to correct location (self-healing)
- Then run strict verification checks (fail-fast if cd failed)
- Provides redundant protection against Task tool working directory issues
- Maintains strict verification - agents still refuse to work if environment is incorrect

**Updated defense-in-depth (4 layers):**
1. Orchestrator pre-creates worktrees (Layer 1)
2. Agent attempts cd to worktree (Layer 1.5 - self-healing)
3. Agent verifies isolation (Layer 2 - strict fail-fast)
4. Orchestrator checks completion reports (Layer 3)
5. Post-merge verification (Layer 4)

**Evidence:**
- brewprune Round 5 Wave 2 (2026-02-28)
- 2 agents launched, 2 worktrees pre-created successfully
- Both agents detected wrong working directory and refused to work
- Fail-fast verification prevented any file modifications
- Pattern worked exactly as designed (caught issue at Layer 2)

**Impact:** Validates fail-fast design + identifies need for self-healing layer

---

## From brewprune Round 4 Wave 1 (2026-02-28)

### Pattern Validation: What Worked ✓

1. **Pre-implementation check (added after Round 3)** - WORKING AS DESIGNED
   - 7 of 17 findings were already implemented
   - Agents verified existing code instead of duplicating work
   - Saved significant compute, prevented conflicts
   - **No change needed**

2. **Disjoint file ownership as primary safety mechanism** - WORKING AS DESIGNED
   - Worktree isolation gave different Git branches, NOT separate filesystems
   - All 6 agents shared same directory but different branches
   - Zero conflicts due to disjoint file ownership
   - **Validates existing design** - scout.md warning about worktree isolation is correct

3. **Post-merge verification gate** - WORKING AS DESIGNED
   - Caught `root_test.go` expecting old P0 behavior
   - Individual agents passed isolation tests
   - Only merged codebase revealed integration issues
   - **Pattern working correctly** - this is exactly what it's designed to catch

---

## From brewprune Round 4 Wave 2 (2026-02-28)

### Additional Pattern Validations ✓

4. **Justified out-of-scope changes** - WORKING AS DESIGNED
   - Agent H made breaking API change (NewSpinner requires explicit Start())
   - Modified 13 call sites across 5 command files (outside scope)
   - Justification: fixing design flaw (race condition), not convenience
   - All affected files updated atomically
   - Post-merge verification validated the migration
   - **Pattern insight:** Disjoint file ownership is a hard constraint for parallel agents in same wave, but justified API-wide changes that must be atomic are acceptable when clearly documented

5. **Wave sequencing prevents conflicts** - WORKING AS DESIGNED
   - Wave 1 (command files) → Wave 2 (shared modules) ordering was optimal
   - Agent H modified 5 command files that Wave 1 agents had finished with
   - If Wave 2 ran first, Wave 1 would have stale API views
   - **Validates existing guidance:** Structure waves by dependency (leaves → roots)

6. **Recommendation without modification pattern** - WORKING AS DESIGNED
   - Agent I identified that status.go should use new ClassifyConfidence() helper
   - Correctly stayed in scope, documented recommendation instead
   - Creates audit trail without scope creep
   - **Pattern working well:** Agents can identify follow-up work in completion reports

### Observations (No Action Needed)

7. **Agent velocity correlates with scope**
   - Agent I: 170s (simple constants + helper)
   - Agent G: 412s (threshold change + function + tests)
   - Agent H: 475s (API redesign + 13 call site updates)
   - Longer times indicate justified complexity, not inefficiency
   - No max time limit needed

8. **Pre-implementation check ROI varies by layer**
   - Wave 1 (commands): 41% already implemented (7/17)
   - Wave 2 (shared modules): 0% already implemented (0/4)
   - Command-level UX fixes happen incrementally (developers notice and fix)
   - Shared module refactors require deliberate effort (less likely stale)
   - Pre-implementation check has highest value for user-facing improvements

---

## Proposed Improvements

### Priority 1: Document for Next Implementation

#### 1. Known Issues Section in IMPL Template

**Problem:** Pre-existing broken tests block full suite runs, agents can't distinguish "expected failure" vs regression

**Evidence:** `TestDoctorHelpIncludesFixNote` hangs (tries to run test binary as CLI). Agent A documented it but couldn't fix (out of scope). Full test suite timed out at 10 minutes.

**Proposal:** Add to scout.md output format:

```markdown
### Known Issues

List any pre-existing test failures, build warnings, or known bugs that agents should be aware of:

- `TestDoctorHelpIncludesFixNote` - Hangs (tries to execute test binary as CLI)
  - Status: Pre-existing, unrelated to this work
  - Workaround: Skip with `-skip 'TestDoctorHelpIncludesFixNote'`
  - Tracked in: [issue link or "needs cleanup"]
```

**Benefit:**
- Agents know what's "expected failure" vs their regression
- Verification gates can auto-skip known broken tests
- Makes technical debt visible

**Implementation:** Update `prompts/scout.md` output format section (lines 162-237)

---

#### 2. Integration Test Reminder in Agent Prompts

**Problem:** P0 fixes changed command behavior, but related tests weren't updated until post-merge verification caught failures

**Evidence:** Wave 1 post-merge found 2 failing tests (`TestRootCmd_BareInvocationShowsHelp`, `TestBareBrewpruneExitsOne`) that expected old P0 behavior. Could have been caught earlier if agents proactively searched for related tests.

**Proposal:** Add to agent template (prompts/agent-template.md):

```markdown
## 6. Verification gate

[existing verification commands]

**Before running verification:** If your changes modify command behavior, exit codes,
or error handling, search for tests that validate the OLD behavior:

```bash
# Example: if changing exit codes
grep -r "exit.*0" internal/app/*_test.go
grep -r "SilenceErrors" internal/app/*_test.go
```

Update related tests to expect the NEW behavior.
```

**Benefit:**
- Catches test updates proactively
- Reduces post-merge surprises
- Agents take ownership of their behavioral changes

**Implementation:** Update `prompts/agent-template.md` section 6

---

#### 3. Timestamp Metadata in Audit Reports

**Problem:** Can't tell how stale audit findings are. 7 of 17 P1/P2 findings were already fixed by agent execution time.

**Evidence:** Scout ran for Round 4 P1/P2 → P0 manual fixes happened → Wave 1 launched days later → 41% of findings already done

**Proposal:** Add metadata header to cold-start-audit report template:

```markdown
# Cold-Start Audit Report

**Metadata:**
- Audit Date: 2026-02-28
- Tool Version: brewprune dev (commit e447983)
- Container: brewprune-sandbox-r4
- Agent Runtime: 18 minutes
- Agents: 2 parallel

---

[rest of findings...]
```

**Benefit:**
- Makes staleness visible
- Helps prioritize findings
- Tracks tool version for regression comparison

**Implementation:** Update cold-start-audit skill filler agent prompt

---

### Priority 1.5: Clarifications (Low Cost, High Value)

#### 4. Justified Out-of-Scope Changes Guidance

**Context:** Agent H made a justified breaking API change that required modifying files outside scope. This was correct architectural judgment, not scope violation.

**Current state:** Scout.md says "Disjoint file ownership is a hard correctness constraint" with no exceptions.

**Proposal:** Add nuance to agent-template.md:

```markdown
## Disjoint File Ownership

Your assigned files define your scope. DO NOT modify files outside your ownership
EXCEPT in these rare cases:

**Exception: Justified API-wide changes**

If you discover a design flaw requiring atomic changes across multiple files:
1. Document ALL affected files in completion report section 4
2. Justify why the change must be atomic (e.g., fixing race condition, preventing
   breaking state)
3. Update all call sites consistently
4. The post-merge verification will validate your migration

Example: If you add a required parameter to a shared function, you must update
all callers atomically to prevent breaking the build.

**Not justified:** Convenience refactoring, style improvements, "while I'm here"
changes. These can be done incrementally.
```

**Benefit:**
- Makes clear that API-breaking changes sometimes require broader scope
- Provides guard rails (must be atomic, must be justified, must document)
- Prevents agents from being too timid when architectural fixes are needed

**Implementation:** Update `prompts/agent-template.md` section on file ownership

---

### Priority 2: Consider for Future

#### 5. Revalidation Checkpoint (Optional)

**Problem:** Time gap between scout and wave execution can make findings stale

**Proposal:** Add optional flag to SAW skill:

```bash
/saw wave --revalidate  # Quick spot-check of 2-3 findings before launching agents
```

**When useful:** Long gaps (>1 day) between scout and wave, or after manual fixes

**Implementation:** Add to `prompts/saw-skill.md` as opt-in feature

---

#### 5. Post-Fix Validation Pass (QA improvement)

**Problem:** After P0 manual fixes, no verification that user experience actually improved before launching Wave 1

**Proposal:** After committing manual fixes, add optional validation step:

```bash
# Quick spot-check of P0 fixes in container
docker exec <container> <tool> --version  # Should work now
docker exec <container> <tool> blorp 2>&1 | grep -c "Error:"  # Should print once not 4x
```

**Benefit:** Catches if P0 fixes introduced new issues before launching Wave 1

**Implementation:** Add to cold-start-audit workflow documentation

---

#### 6. Test Suite Audit Phase (Expansion)

**Problem:** User-facing audit doesn't see test infrastructure issues

**Proposal:** Optional audit phase 2: "Run test suite and report failures"

**When useful:** Libraries/frameworks where test health matters more than CLI tools

**Implementation:** Add to cold-start-audit skill as optional phase

---

## Implementation Plan

1. **After completing brewprune Wave 2 & 3:** Implement Priority 1 improvements (1-3)
2. **Document in CHANGELOG:** Add "lessons from Round 4" entry
3. **Validate in next project:** Test improved patterns in next SAW execution
4. **Evaluate Priority 2:** Decide which optional improvements are worth the complexity

---

## Validation Criteria

Each improvement should be validated by:
- Does it prevent a real issue we encountered?
- Does it add significant value for future users?
- Is the cost (complexity/maintenance) justified?

If yes to all three: implement. Otherwise: document and revisit after more usage data.
