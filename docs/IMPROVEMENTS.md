# SAW Pattern Improvements Queue

Lessons learned from real-world usage, pending implementation.

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

### Priority 2: Consider for Future

#### 4. Revalidation Checkpoint (Optional)

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
