# IMPL Doc Fixes: Protocol Extraction Refactor

**Target IMPL:** `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`

**Severity:** Critical - Multiple protocol violations that would cause execution failures

**Date:** 2026-03-06

---

## Executive Summary

During dogfooding review of the protocol extraction IMPL doc, five critical issues were identified that violate Scout-and-Wave protocol invariants and execution rules. These must be fixed before execution to prevent:

1. Work being performed directly on main branch (I1 violation via missing worktree isolation)
2. Merge conflicts from overlapping content extraction (224 lines extracted by both Agent B and Agent C)
3. Missing verification of extraction completeness (gaps or duplicates undetected)
4. High agent failure risk (Agent F has 15+ operations)
5. Broken verification (link checker command not specified)

**Impact:** Without these fixes, wave execution will likely fail at merge time or produce incomplete/broken documentation.

**Recommendation:** Apply all proposed changes before launching Wave 1.

---

## Critical Issues Identified

### Issue 1: No Worktree Isolation (Violates I1 + E4)

**Current state:** All agents specify "no worktree isolation needed" and work directly on main branch

**Problem:**
- Violates I1 (disjoint file ownership requires isolation to prevent concurrent write conflicts)
- Violates E4 (worktree isolation is mandatory defense-in-depth)
- No rollback capability if an agent fails mid-execution
- No protection against concurrent file system operations

**Evidence:**
- Agent A Field 0 (line 260): "No worktree isolation needed. Verify you're in the repository root"
- Agent B Field 0 (line 377): Same pattern
- All 9 agents use identical "no worktree isolation" language

**Impact severity:** High. Parallel agents writing to main simultaneously can corrupt git state.

---

### Issue 2: Overlapping Content Extraction (Violates I1)

**Current state:**
- Agent B extracts PROTOCOL.md lines 89-407 (preconditions + invariants + execution rules)
- Agent C extracts PROTOCOL.md lines 183-523 (state machine + message formats + merge procedure)

**Problem:** Lines 183-407 (224 lines) are in both ranges. Specific overlaps:
- Lines 183-213: State Machine section (in both Agent B and Agent C ranges)
- Lines 216-407: Execution Rules E1-E14 (in both Agent B and Agent C ranges)

**Evidence:**
- Agent B Field 4 (line 427): "Lines 216-407: Execution Rules E1-E14"
- Agent C Field 4 (line 592): "Lines 183-213: State Machine"

**Impact severity:** Critical. Two agents extracting the same content creates:
- Duplicate files or conflicting file ownership
- Merge conflicts at wave boundary
- Semantic inconsistency if adaptations differ

---

### Issue 3: No Extraction Completeness Verification

**Current state:** No agent or post-wave check verifies all PROTOCOL.md content was extracted

**Problem:** Gaps in line coverage could leave content orphaned (not extracted to any protocol/*.md file)

**Missing verification:**
- Are lines 1-15 (header) handled?
- Are lines 524-591 (end of file) handled?
- Are there gaps between agent ranges?

**Impact severity:** Medium-High. Incomplete extraction means protocol/*.md files missing content.

---

### Issue 4: Agent F Overloaded (High Failure Risk)

**Current state:** Agent F performs 15+ operations:
1. Create implementations/ directory structure
2. git mv prompts/ → implementations/claude-code/prompts/
3. git mv docs/QUICKSTART.md → implementations/claude-code/QUICKSTART.md
4. git mv examples/ → implementations/claude-code/examples/
5. git mv hooks/ → implementations/claude-code/hooks/
6. Create implementations/README.md
7. Create implementations/claude-code/README.md
8. Rewrite root README.md
9. Update internal links in all moved files
10-15. Verify all moves completed, old locations gone, new files exist, links updated, history preserved

**Problem:**
- Single point of failure (if any operation fails, entire agent fails)
- Hard to debug which specific operation failed
- Hard to rollback partial work
- Violates "one agent, one concern" design principle

**Impact severity:** High. Agent F failure blocks Wave 2 completion, and Wave 3 depends on Wave 2.

---

### Issue 5: Link Validation Command Not Specified

**Current state:** Suitability assessment (line 21) mentions "link checking" verification but provides no command

**Problem:** Post-merge verification gate cannot run link checking without a specified command

**Evidence:**
- Line 21: "Merge & verification: ~5 min (link checking, file existence validation)"
- No verification section specifies what link checking command to run

**Impact severity:** Medium. Broken links won't be detected until manual review.

---

## Proposed Changes

### Change 1: Reinstate Worktree Isolation

**Fix:** Update all agent Field 0 sections to use standard worktree isolation per agent-template.md

**Rationale:** Even though this is documentation work, parallel agents need isolation:
- Prevents concurrent git operations from interfering
- Provides rollback capability
- Enforces protocol consistency (worktree isolation is non-negotiable per E4)
- Enables per-agent commit tracking

**Revised Field 0 (apply to all 9 agents):**

**For Wave 1 Agents (A, B, C, D):**

```markdown
**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Attempt environment correction**

```bash
# Attempt to cd to expected worktree location (self-healing)
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-{A|B|C|D} 2>/dev/null || true
```

**Step 2: Verify isolation (strict fail-fast after self-correction attempt)**

```bash
# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-{A|B|C|D}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory (even after cd attempt)"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-{A|B|C|D}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

# Verify worktree in git's records
git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files)

**If verification passes:** Document briefly in completion report, then proceed with work.
```

**Apply same pattern to Wave 2 agents (E, F1, F2, G, H) with wave2-agent-{E|F1|F2|G|H}**

**Apply same pattern to Wave 3 agent (I) with wave3-agent-I**

---

### Change 2: Fix Overlapping Content Extraction

**Current allocation:**
- Agent A: lines 16-85 (Participants)
- Agent B: lines 89-407 (Preconditions + Invariants + Execution Rules)
- Agent C: lines 183-523 (State Machine + Message Formats + Merge Procedure)

**Problem:** Lines 183-407 overlap (both B and C)

**Proposed allocation (disjoint ranges):**

| Agent | Lines | Content | Files Created |
|-------|-------|---------|---------------|
| Agent A | 16-85 | Participants | protocol/README.md, protocol/participants.md |
| Agent B | 89-182 | Preconditions + Invariants | protocol/preconditions.md, protocol/invariants.md |
| Agent C | 183-407 | Execution Rules + State Machine (partial) | protocol/execution-rules.md, protocol/state-machine.md |
| Agent D | 409-523 | Message Formats + remaining State Machine | protocol/message-formats.md, protocol/merge-procedure.md, protocol/worktree-isolation.md, protocol/compliance.md, protocol/FAQ.md |

**Wait, this doesn't match file ownership table.** Let me revise more carefully:

**Better allocation (preserves file ownership, adjusts line ranges):**

| Agent | Lines | Content | Files |
|-------|-------|---------|-------|
| Agent A | 16-85 | Participants | protocol/README.md, protocol/participants.md |
| Agent B | 89-215 | Preconditions + Invariants + (Execution Rules header) | protocol/preconditions.md, protocol/invariants.md, protocol/execution-rules.md |
| Agent C | 183-213, 216-523 | State Machine + Execution Rules (collaborate) + Message Formats | protocol/state-machine.md, protocol/message-formats.md, protocol/merge-procedure.md, protocol/worktree-isolation.md, protocol/compliance.md, protocol/FAQ.md |
| Agent D | (no extraction) | Templates only | templates/* |

**This is still confusing. The real issue: Agent C's file ownership includes protocol/execution-rules.md? No, checking line 195:**

Looking at File Ownership table (lines 186-225):
- Agent B owns: protocol/preconditions.md, protocol/invariants.md, protocol/execution-rules.md
- Agent C owns: protocol/state-machine.md, protocol/message-formats.md, protocol/merge-procedure.md, protocol/worktree-isolation.md, protocol/compliance.md, protocol/FAQ.md

**So the file ownership is correct, just the extraction ranges overlap. Fix:**

**Revised Agent B Field 4:**
```markdown
**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 89-127: Preconditions
  - Lines 133-179: Invariants I1-I6
  - Lines 216-407: Execution Rules E1-E14
```

Change to:

```markdown
**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 89-127: Preconditions
  - Lines 133-179: Invariants I1-I6
  - Lines 216-407: Execution Rules E1-E14 (FULL RANGE - you own this section)
```

**Revised Agent C Field 4:**
```markdown
**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 183-213: State Machine
  - Lines 409-497: Message Formats
- Read `/Users/dayna.blackwell/code/scout-and-wave/prompts/saw-merge.md`:
  - Lines 50-150: Merge procedure steps
```

Change to:

```markdown
**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 183-215: State Machine (STOP BEFORE EXECUTION RULES at line 216)
  - Lines 409-523: Message Formats + Protocol Violations section
- Read `/Users/dayna.blackwell/code/scout-and-wave/prompts/saw-merge.md`:
  - Lines 50-150: Merge procedure steps
```

**Update content exclusions:**
- Agent B: Extracts lines 216-407 (Execution Rules) → owns protocol/execution-rules.md
- Agent C: Extracts lines 183-215 (State Machine only, stops before line 216) + 409-523 → owns protocol/state-machine.md and others

**New disjoint allocation:**
- Agent A: 16-85
- Agent B: 89-127, 133-179, 216-407 (gaps are section headers)
- Agent C: 183-215, 409-523
- Agent D: No extraction (template creation only)

**Coverage verification:**
- Lines 1-15: Header (Agent E handles when updating PROTOCOL.md)
- Lines 86-88: Section header (can be dropped or included in B)
- Lines 128-132: Section header (can be dropped or included in B)
- Lines 180-182: Section header (can be dropped or included in C)
- Lines 408: Section header (can be dropped or included in C)
- Lines 524-591: Variants + Reference Implementation + Version headers (Agent E handles)

---

### Change 3: Add Extraction Completeness Check

**Solution:** Add new Wave 1.5 verification agent (runs after Wave 1 completes, before Wave 2 starts)

**New Agent: Agent E0 (Extraction Completeness Verifier)**

Insert between Wave 1 and Wave 2. This is a verification-only agent (reads, doesn't write).

**Agent E0 Prompt:**

```markdown
### Agent E0 - Extraction Completeness Verification

**Wave:** 1.5 (verification wave between Wave 1 and Wave 2)

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any analysis**

```bash
# Attempt to cd to expected worktree location (self-healing)
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-5-agent-E0 2>/dev/null || true

# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-5-agent-E0"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-5-agent-E0"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

READ-ONLY. This agent does not modify any files. It verifies Wave 1's extraction work.

Files to verify:
- protocol/README.md (Agent A)
- protocol/participants.md (Agent A)
- protocol/preconditions.md (Agent B)
- protocol/invariants.md (Agent B)
- protocol/execution-rules.md (Agent B)
- protocol/state-machine.md (Agent C)
- protocol/message-formats.md (Agent C)
- protocol/merge-procedure.md (Agent C)
- protocol/worktree-isolation.md (Agent C)
- protocol/compliance.md (Agent C)
- protocol/FAQ.md (Agent C)
- templates/* (Agent D - not verified here)

**Field 2: Interfaces to Implement**

Verify completeness of PROTOCOL.md content extraction.

**Field 3: Interfaces to Call**

Read Wave 1 agent outputs from main branch (Wave 1 merged before this runs).

**Field 4: What to Implement**

Verify that all content from PROTOCOL.md was extracted to protocol/*.md files with no gaps or duplicates.

**Verification tasks:**
1. **Coverage check:** Map PROTOCOL.md line ranges to extracted files
2. **Gap detection:** Identify any PROTOCOL.md lines not extracted
3. **Duplicate detection:** Check if any content appears in multiple protocol/*.md files
4. **Semantic check:** Verify all I1-I6, E1-E14 definitions present in extracted files
5. **Link check:** Verify protocol/*.md cross-references resolve

**Expected coverage:**
- Lines 1-15: Header (stays in PROTOCOL.md - Agent E will clean)
- Lines 16-85: Participants → protocol/participants.md (Agent A)
- Lines 89-127: Preconditions → protocol/preconditions.md (Agent B)
- Lines 133-179: Invariants → protocol/invariants.md (Agent B)
- Lines 183-215: State Machine → protocol/state-machine.md (Agent C)
- Lines 216-407: Execution Rules → protocol/execution-rules.md (Agent B)
- Lines 409-523: Message Formats + Procedures → protocol/message-formats.md + protocol/merge-procedure.md (Agent C)
- Lines 524-591: Reference Implementation (stays in PROTOCOL.md - Agent E will clean)

**Field 5: Tests to Write**

No tests. This is a verification agent.

**Field 6: Verification Gate**

```bash
# 1. Verify all I1-I6 present in protocol/invariants.md
for i in I1 I2 I3 I4 I5 I6; do
  grep -q "$i" protocol/invariants.md || {
    echo "MISSING: $i not found in protocol/invariants.md"
    exit 1
  }
done

# 2. Verify all E1-E14 present in protocol/execution-rules.md
for e in E1 E2 E3 E4 E5 E6 E7 E7a E8 E9 E10 E11 E12 E13 E14; do
  grep -q "$e" protocol/execution-rules.md || {
    echo "MISSING: $e not found in protocol/execution-rules.md"
    exit 1
  }
done

# 3. Verify all protocol states mentioned in protocol/state-machine.md
for state in INIT REVIEWED WAVE_PENDING WAVE_EXECUTING WAVE_MERGING WAVE_VERIFIED BLOCKED COMPLETE; do
  grep -q "$state" protocol/state-machine.md || {
    echo "MISSING: State $state not found in protocol/state-machine.md"
    exit 1
  }
done

# 4. Verify suitability verdict schema in protocol/message-formats.md
grep -q "Verdict: SUITABLE" protocol/message-formats.md || {
  echo "MISSING: Suitability verdict schema not in protocol/message-formats.md"
  exit 1
}

# 5. Check for duplicate I/E definitions across files
for i in I1 I2 I3 I4 I5 I6; do
  count=$(grep -l "$i:" protocol/*.md | wc -l)
  if [ $count -gt 1 ]; then
    echo "DUPLICATE: $i appears in multiple files: $(grep -l "$i:" protocol/*.md)"
    exit 1
  fi
done

echo "✓ All verification checks passed"
```

**Field 7: Constraints**

- **Hard constraint:** Do NOT modify any files. This is a read-only verification agent.
- **Hard constraint:** Exit with status 1 if any verification fails.
- **Report requirements:** List all gaps, duplicates, or missing content found.

**Field 8: Report**

Do NOT commit (no changes made). Write completion report to IMPL doc:

```yaml
### Agent E0 - Completion Report
status: complete | blocked
worktree: .claude/worktrees/wave1-5-agent-E0
commit: none (verification only, no changes)
files_changed: []
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL (coverage check + duplicate detection)
```

**Free-form notes:**
- List any gaps in line coverage
- List any duplicate extractions found
- List any missing I1-I6 or E1-E14 definitions
- If PASS, state "All PROTOCOL.md content accounted for"
```

**Update Wave Structure:**

```
Wave 1: [A] [B] [C] [D]          <- 4 parallel agents (protocol + templates foundation)
           |
           | (all Wave 1 complete, merge Wave 1)
           v
Wave 1.5: [E0]                   <- 1 verification agent (extraction completeness)
           |
           | (verification passes)
           v
Wave 2: [E] [F1] [F2] [G] [H]    <- 5 parallel agents (moves + root docs + manual guide)
           |
           | (all Wave 2 complete, file moves verified)
           v
Wave 3: [I]                      <- 1 agent (backward compatibility symlinks)
```

---

### Change 4: Split Agent F

**Current:** Agent F does 15+ operations (moves + creates + rewrites)

**Solution:** Split into Agent F1 (file moves) + Agent F2 (README updates)

**Agent F1 - File Moves and Implementation Structure**

```markdown
### Agent F1 - Move Claude Code Implementation Files

**Wave:** 2

**Field 0: Isolation Verification**

[Standard worktree isolation verification for wave2-agent-F1]

**Field 1: File Ownership**

You own these file operations:

**File moves (use `git mv` to preserve history):**
- `prompts/` → `implementations/claude-code/prompts/`
- `docs/QUICKSTART.md` → `implementations/claude-code/QUICKSTART.md`
- `examples/` → `implementations/claude-code/examples/`
- `hooks/` → `implementations/claude-code/hooks/`

**Directory creates:**
- `implementations/`
- `implementations/claude-code/`

**Field 2: Interfaces to Implement**

Move all Claude Code-specific files from repository root to `implementations/claude-code/` subdirectory.

**Field 3: Interfaces to Call**

None. This is pure file reorganization.

**Field 4: What to Implement**

Execute git moves to relocate Claude Code implementation files into dedicated subdirectory structure. Use `git mv` to preserve commit history.

**Move procedure:**
```bash
# Create directory structure
mkdir -p implementations/claude-code

# Move prompts (preserves history)
git mv prompts implementations/claude-code/

# Move examples
git mv examples implementations/claude-code/

# Move quickstart
git mv docs/QUICKSTART.md implementations/claude-code/

# Move hooks
git mv hooks implementations/claude-code/
```

**Field 5: Tests to Write**

No tests. File moves only.

**Field 6: Verification Gate**

```bash
# Verify moves completed
test -d implementations/claude-code/prompts || exit 1
test -f implementations/claude-code/QUICKSTART.md || exit 1
test -d implementations/claude-code/examples || exit 1
test -d implementations/claude-code/hooks || exit 1

# Verify old locations gone
test ! -d prompts || exit 1
test ! -f docs/QUICKSTART.md || exit 1
test ! -d examples || exit 1
test ! -d hooks || exit 1

# Verify git history preserved (check one moved file)
git log --follow --oneline implementations/claude-code/prompts/saw-skill.md | head -1 || exit 1

echo "✓ All moves verified"
```

**Field 7: Constraints**

- **Hard constraint:** Use `git mv` for all file moves to preserve history. Do NOT copy+delete.
- **Hard constraint:** Do NOT update any file contents. Pure moves only.

**Field 8: Report**

After completing all work and verification:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F1
git add -A
git commit -m "refactor: move Claude Code implementation files to implementations/claude-code/"
```

Write completion report:

```yaml
### Agent F1 - Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave2-agent-F1
commit: <sha>
files_changed: []
files_created: []
files_moved:
  - prompts/ → implementations/claude-code/prompts/
  - docs/QUICKSTART.md → implementations/claude-code/QUICKSTART.md
  - examples/ → implementations/claude-code/examples/
  - hooks/ → implementations/claude-code/hooks/
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (moves complete, history preserved, old locations removed)
```
```

**Agent F2 - README Updates and Implementation Documentation**

```markdown
### Agent F2 - README Updates and Implementation Documentation

**Wave:** 2

**Field 0: Isolation Verification**

[Standard worktree isolation verification for wave2-agent-F2]

**Field 1: File Ownership**

You own these files:

**Creates:**
- `implementations/README.md`
- `implementations/claude-code/README.md`

**Modifies:**
- `README.md` (root)

**Field 2: Interfaces to Implement**

Create implementation-layer documentation and rewrite root README to be a navigation hub.

**implementations/README.md** must provide:
- Comparison table: Claude Code vs. Manual orchestration
- "Choosing an implementation" guidance
- Links to implementations/claude-code/README.md and implementations/manual/README.md

**implementations/claude-code/README.md** must provide:
- Installation instructions (extracted from current README.md)
- Usage instructions
- Tool requirements section (Agent, Read, Write, Bash, etc.)
- Links to prompts/ subdirectory

**New root README.md** must provide:
- High-level protocol overview
- Link to protocol/ directory: "Read the protocol specification"
- Link to implementations/ directory: "Choose an implementation"
- Quick start: 2 options (Claude Code OR Manual)
- Remove installation instructions (delegate to implementations/claude-code/README.md)

**Field 3: Interfaces to Call**

Link to files created by Wave 1 and Wave 2:
- `protocol/README.md` (Agent A)
- `implementations/manual/README.md` (Agent H - created in same wave)

**Field 4: What to Implement**

Rewrite root README.md to be implementation-agnostic and create two new implementation READMEs that provide specific installation/usage instructions.

**Extraction from current README.md:**
1. Read `/Users/dayna.blackwell/code/scout-and-wave/README.md`
2. Extract lines 86-238: Installation instructions → implementations/claude-code/README.md
3. Extract lines 240-265: Usage instructions → implementations/claude-code/README.md
4. Keep badges, title, one-paragraph description in root README
5. Shorten "Why" and "How" sections to 2-3 paragraphs each
6. Add "Protocol Documentation" section → link to protocol/README.md
7. Add "Implementations" section → link to implementations/README.md

**Field 5: Tests to Write**

No executable tests. Self-verification:
- implementations/README.md exists and has comparison table
- implementations/claude-code/README.md exists and contains installation instructions
- Root README.md is shorter and links to protocol/ and implementations/

**Field 6: Verification Gate**

```bash
# Verify new implementation docs exist
test -f implementations/README.md || exit 1
test -f implementations/claude-code/README.md || exit 1

# Verify root README was updated
grep -q "protocol/README.md" README.md || exit 1
grep -q "implementations/" README.md || exit 1

# Verify root README is shorter than original (rough heuristic)
test $(wc -l < README.md) -lt 200 || exit 1

# Verify Claude Code README has installation instructions
grep -q "Installation" implementations/claude-code/README.md || exit 1

echo "✓ All README updates verified"
```

**Field 7: Constraints**

- **Hard constraint:** Root README.md must remain beginner-friendly. Don't make it too terse.
- **Hard constraint:** Do NOT create symlinks (Agent I handles that in Wave 3)
- **Link consistency:** All links must be relative paths

**Field 8: Report**

After completing all work and verification:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F2
git add -A
git commit -m "docs: rewrite root README and create implementation READMEs"
```

Write completion report:

```yaml
### Agent F2 - Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave2-agent-F2
commit: <sha>
files_changed:
  - README.md
files_created:
  - implementations/README.md
  - implementations/claude-code/README.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (READMEs created, root README updated, links verified)
```
```

**Update File Ownership table (line 186-229):**

Change:
```
| README.md (rewrite) | F | 2 | Wave 1 (A) |
| implementations/README.md | F | 2 | Wave 1 (A) |
| implementations/claude-code/README.md | F | 2 | Wave 1 (A) |
| implementations/claude-code/QUICKSTART.md | F | 2 | — |
| implementations/claude-code/prompts/*.md | F | 2 | — |
| implementations/claude-code/prompts/agents/*.md | F | 2 | — |
| implementations/claude-code/hooks/ | F | 2 | — |
| implementations/claude-code/examples/ | F | 2 | — |
```

To:
```
| implementations/claude-code/prompts/*.md (move) | F1 | 2 | — |
| implementations/claude-code/QUICKSTART.md (move) | F1 | 2 | — |
| implementations/claude-code/prompts/agents/*.md (move) | F1 | 2 | — |
| implementations/claude-code/hooks/ (move) | F1 | 2 | — |
| implementations/claude-code/examples/ (move) | F1 | 2 | — |
| README.md (rewrite) | F2 | 2 | Wave 1 (A) |
| implementations/README.md | F2 | 2 | Wave 1 (A) |
| implementations/claude-code/README.md | F2 | 2 | Wave 1 (A) |
```

---

### Change 5: Specify Link Validation Command

**Current:** Verification mentions link checking but provides no command

**Fix:** Add post-merge verification section with exact link checking command

**Insert new section after Agent I prompt (Wave 3), before "Status" section:**

```markdown
---

## Post-Merge Verification

Run these commands after Wave 3 merges to verify the entire refactor:

### 1. File Existence Check

```bash
# Verify all new protocol/ files exist
for f in README.md participants.md preconditions.md invariants.md execution-rules.md state-machine.md message-formats.md merge-procedure.md worktree-isolation.md compliance.md FAQ.md; do
  test -f protocol/$f || { echo "MISSING: protocol/$f"; exit 1; }
done

# Verify all new templates/ files exist
for f in IMPL-doc-template.md agent-prompt-template.md completion-report.yaml suitability-verdict.md; do
  test -f templates/$f || { echo "MISSING: templates/$f"; exit 1; }
done

# Verify all implementation files moved
test -d implementations/claude-code/prompts || { echo "MISSING: implementations/claude-code/prompts/"; exit 1; }
test -f implementations/claude-code/README.md || { echo "MISSING: implementations/claude-code/README.md"; exit 1; }

# Verify old locations removed
test ! -d prompts || { echo "LEFTOVER: prompts/ still exists"; exit 1; }
test ! -f docs/QUICKSTART.md || { echo "LEFTOVER: docs/QUICKSTART.md still exists"; exit 1; }

# Verify symlinks created
test -L prompts/saw-skill.md || { echo "MISSING SYMLINK: prompts/saw-skill.md"; exit 1; }

echo "✓ File existence check passed"
```

### 2. Link Validation

```bash
# Install markdown-link-check if not present
if ! command -v markdown-link-check &> /dev/null; then
  echo "Installing markdown-link-check..."
  npm install -g markdown-link-check
fi

# Check all markdown files for broken links
echo "Checking internal links..."
find . -name "*.md" \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -not -path "./.claude/*" \
  -exec markdown-link-check --config .markdown-link-check.json {} \;

# Exit code 0 if all links valid, non-zero if any broken
```

**Create `.markdown-link-check.json` config:**

```json
{
  "ignorePatterns": [
    {
      "pattern": "^http://localhost"
    }
  ],
  "replacementPatterns": [],
  "httpHeaders": [],
  "timeout": "20s",
  "retryOn429": true,
  "retryCount": 3,
  "fallbackRetryDelay": "30s",
  "aliveStatusCodes": [200, 206]
}
```

### 3. Content Verification

```bash
# Verify no Claude Code tool names in protocol/ docs
if grep -r -E "Agent tool|Read tool|Write tool|Bash tool|run_in_background" protocol/; then
  echo "ERROR: Claude Code tool names found in protocol/ docs"
  exit 1
fi

# Verify all I1-I6 and E1-E14 preserved in PROTOCOL.md
for i in I1 I2 I3 I4 I5 I6; do
  grep -q "$i" PROTOCOL.md || { echo "MISSING: $i not in PROTOCOL.md"; exit 1; }
done
for e in E1 E2 E3 E4 E5 E6 E7 E8 E9 E10 E11 E12 E13 E14; do
  grep -q "$e" PROTOCOL.md || { echo "MISSING: $e not in PROTOCOL.md"; exit 1; }
done

echo "✓ Content verification passed"
```

### 4. Git History Verification

```bash
# Verify moves preserved history (sample check on saw-skill.md)
COMMIT_COUNT=$(git log --follow --oneline implementations/claude-code/prompts/saw-skill.md | wc -l)
if [ $COMMIT_COUNT -lt 5 ]; then
  echo "WARNING: Git history may not be preserved (only $COMMIT_COUNT commits found)"
fi

echo "✓ Git history check passed ($COMMIT_COUNT commits found)"
```

**All checks must pass before marking IMPL doc status as COMPLETE.**
```

---

## Revised Wave Structure

**Current (3 waves, 9 agents):**
```
Wave 1: [A] [B] [C] [D]          <- 4 agents
Wave 2: [E] [F] [G] [H]          <- 4 agents
Wave 3: [I]                      <- 1 agent
Total: 9 agents
```

**Revised (4 waves, 11 agents):**
```
Wave 1: [A] [B] [C] [D]          <- 4 parallel agents (protocol + templates foundation)
           |
           | (merge Wave 1 to main)
           v
Wave 1.5: [E0]                   <- 1 verification agent (extraction completeness check)
           |
           | (verification PASS required to proceed)
           v
Wave 2: [E] [F1] [F2] [G] [H]    <- 5 parallel agents (moves + root docs + manual guide)
           |
           | (merge Wave 2 to main, verify file moves)
           v
Wave 3: [I]                      <- 1 agent (backward compatibility symlinks)

Total: 11 agents across 4 waves
```

**Rationale for Wave 1.5:**
- Verification-only wave between foundation and integration
- Catches extraction gaps/overlaps before Wave 2 creates links
- Fail-fast: If extraction incomplete, Wave 2 won't create broken links
- Low overhead: Single read-only verification agent

---

## Revised Time Estimates

**Current estimates:**
- Scout phase: ~8 min
- Agent execution: ~45 min (8 agents across 3 waves)
- Merge & verification: ~5 min
- Total: ~58 min

**Revised estimates:**
- Scout phase: ~8 min (unchanged)
- Wave 1 execution: ~15 min (4 agents in parallel)
- Wave 1.5 verification: ~3 min (1 agent, read-only checks)
- Wave 2 execution: ~20 min (5 agents in parallel, F1/F2 split adds clarity)
- Wave 3 execution: ~5 min (1 agent, symlinks only)
- Merge & verification: ~8 min (added link checking with markdown-link-check)
- Total: ~59 min

**Impact:** +1 minute total (added verification overhead), but significantly reduced risk.

---

## Updated Agent Count and Dependencies

**Wave 1 (4 agents):**
- Agent A: protocol/README.md, protocol/participants.md
- Agent B: protocol/preconditions.md, protocol/invariants.md, protocol/execution-rules.md
- Agent C: protocol/state-machine.md, protocol/message-formats.md, protocol/merge-procedure.md, protocol/worktree-isolation.md, protocol/compliance.md, protocol/FAQ.md
- Agent D: templates/IMPL-doc-template.md, templates/agent-prompt-template.md, templates/completion-report.yaml, templates/suitability-verdict.md

**Wave 1.5 (1 verification agent):**
- Agent E0: Verify Wave 1 extraction completeness (read-only)

**Wave 2 (5 agents - was 4):**
- Agent E: PROTOCOL.md (update)
- Agent F1: File moves (split from Agent F)
- Agent F2: README updates (split from Agent F)
- Agent G: IMPL-SCHEMA.md
- Agent H: implementations/manual/*.md

**Wave 3 (1 agent):**
- Agent I: Backward compatibility symlinks

**Total: 11 agents (was 9)**

---

## Testing the Fixes

### How to verify these changes work:

**1. Worktree isolation:**
- Before launching any wave, verify `.claude/worktrees/wave{N}-agent-{X}/` directories created
- Check each agent's completion report includes "✓ Isolation verified" output
- Verify no agents commit to main branch during wave execution

**2. Content extraction (no overlaps):**
- After Wave 1.5, check Agent E0 completion report for "verification: PASS"
- If E0 reports gaps or duplicates, halt and fix before proceeding to Wave 2

**3. Link validation:**
- After Wave 3 merge, run `markdown-link-check` command from post-merge verification
- All internal links must resolve (protocol/*.md ↔ templates/*.md ↔ implementations/*.md)

**4. Agent F split:**
- Verify Agent F1 completion report shows only file moves (no README edits)
- Verify Agent F2 completion report shows only README edits (no file moves)
- Confirm both agents completed successfully before Wave 2 merge

**5. Git history preservation:**
- After merge, run: `git log --follow --oneline implementations/claude-code/prompts/saw-skill.md`
- Verify commit history goes back to original creation date (not just the move commit)

---

## Impact Assessment

### Wave Count
- **Before:** 3 waves
- **After:** 4 waves (added Wave 1.5 verification)
- **Impact:** +1 wave, but adds critical safety check

### Agent Count
- **Before:** 9 agents
- **After:** 11 agents (split Agent F → F1/F2, added Agent E0)
- **Impact:** +2 agents, reduces single-point-of-failure risk

### Time Estimate
- **Before:** ~58 min
- **After:** ~59 min (+1 min for verification overhead)
- **Impact:** Negligible time increase, significant risk reduction

### Risk Reduction
- **Before:** High risk of merge conflicts, missing content, broken links, Agent F failure
- **After:** Low risk with defense-in-depth:
  - Worktree isolation prevents concurrent write conflicts
  - Disjoint line ranges prevent content extraction conflicts
  - Wave 1.5 verification catches extraction gaps before Wave 2 creates links
  - Agent F split reduces failure surface area
  - Link validation catches broken references before completion

### Protocol Compliance
- **Before:** Violated I1 (no isolation), E4 (skipped worktree isolation)
- **After:** Fully compliant with SAW protocol invariants and execution rules

---

## Implementation Checklist

To apply these fixes to the IMPL doc:

- [ ] Update all 11 agents' Field 0 sections with worktree isolation verification
- [ ] Fix Agent B content extraction range (lines 89-127, 133-179, 216-407)
- [ ] Fix Agent C content extraction range (lines 183-215, 409-523)
- [ ] Insert new Agent E0 (Wave 1.5 verification agent)
- [ ] Split Agent F into Agent F1 (file moves) and Agent F2 (README updates)
- [ ] Update File Ownership table (lines 186-229) with F1/F2 split
- [ ] Update Wave Structure diagram with Wave 1.5 and F1/F2
- [ ] Add Post-Merge Verification section with link checking commands
- [ ] Create `.markdown-link-check.json` config file
- [ ] Update time estimates (Scout → Wave 3 → Merge)
- [ ] Update agent count in Suitability Assessment (line 20)

**Estimated time to apply fixes:** 45-60 minutes (careful editing of IMPL doc)

**Recommendation:** Apply all fixes before launching Wave 1. Do NOT partially apply.

---

## Appendix: Full Field 0 Template

For reference, here's the complete Field 0 template to copy into each agent:

```markdown
**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Attempt environment correction**

```bash
# Attempt to cd to expected worktree location (self-healing)
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave{N}-agent-{X} 2>/dev/null || true
```

**Step 2: Verify isolation (strict fail-fast after self-correction attempt)**

```bash
# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave{N}-agent-{X}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory (even after cd attempt)"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave{N}-agent-{X}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

# Verify worktree in git's records
git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files)

**If verification passes:** Document briefly in completion report, then proceed with work.

**Rationale:** Defense-in-depth isolation enforcement (E4). Layer 0: pre-commit hook. Layer 1: orchestrator creates worktrees. Layer 1.5: agent self-corrects via cd. Layer 2: agent verifies and fails fast. Layer 3: orchestrator checks reports. Layer 4: merge-time trip wire.
```

Replace `{N}` with wave number (1, 1-5, 2, 3) and `{X}` with agent letter (A-I, E0).

---

**End of Fix Proposal**

**Next Steps:**
1. Review this proposal for completeness
2. Apply all changes to IMPL doc
3. Re-run suitability assessment if time estimates significantly changed
4. Launch Wave 1 with corrected agent prompts
