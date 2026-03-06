# IMPL Doc Fixes Applied: Summary

**Date:** 2026-03-06
**Target:** `docs/IMPL/IMPL-refactor-protocol-extraction.md`
**Status:** PARTIAL - Critical structural changes applied, detailed agent prompt updates in progress

---

## Changes Applied

### ✅ 1. Suitability Assessment Updated
- Added note about protocol compliance fixes
- Updated time estimates (58 min → 59 min)
- Updated wave/agent counts (3 waves/9 agents → 4 waves/11 agents)

### ✅ 2. Wave Structure Updated
```
Before: Wave 1 → Wave 2 → Wave 3 (9 agents)
After:  Wave 1 → Wave 1.5 → Wave 2 → Wave 3 (11 agents)
```
- Added Wave 1.5 with Agent E0 (extraction verification)
- Updated transition rationale

### ✅ 3. File Ownership Table Updated
- Added Agent E0 (Wave 1.5, read-only verification)
- Split Agent F into:
  - F1: File moves only
  - F2: README updates only
- Updated Wave 3 symlink dependencies (F → F1)

### ✅ 4. Content Extraction Contracts Fixed
**Before:**
- Agent B: lines 89-407
- Agent C: lines 183-523
- **OVERLAP:** 224 lines (183-407)

**After:**
- Agent B: lines 89-127, 133-179, 216-407 (DISJOINT)
- Agent C: lines 183-215, 409-523 (STOPS BEFORE 216)
- **NO OVERLAP**

### ✅ 5. Status Table Updated
- Added Wave 1.5 / Agent E0 row
- Split Agent F into F1 / F2 rows
- Updated descriptions

---

## Changes IN PROGRESS

### ⏳ 6. Agent Field 0 Sections (11 agents)

**Required update pattern for ALL agents:**

```markdown
**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Attempt environment correction**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave{N}-agent-{X} 2>/dev/null || true
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave{N}-agent-{X}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave{N}-agent-{X}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```
```

**Agents requiring this update:**
- [ ] Agent A (wave1-agent-A)
- [ ] Agent B (wave1-agent-B) - ALSO needs extraction range fix
- [ ] Agent C (wave1-agent-C) - ALSO needs extraction range fix
- [ ] Agent D (wave1-agent-D)
- [ ] Agent E0 (wave1-5-agent-E0) - NEW AGENT, needs full prompt
- [ ] Agent E (wave2-agent-E)
- [ ] Agent F1 (wave2-agent-F1) - SPLIT from F, needs new prompt
- [ ] Agent F2 (wave2-agent-F2) - SPLIT from F, needs new prompt
- [ ] Agent G (wave2-agent-G)
- [ ] Agent H (wave2-agent-H)
- [ ] Agent I (wave3-agent-I) - ALSO needs F→F1 reference update

### ⏳ 7. Agent B Content Extraction Fix

**Current (in IMPL doc):**
```markdown
Lines 89-407: Preconditions + Invariants + Execution Rules
```

**Required:**
```markdown
Lines 89-127: Preconditions
Lines 133-179: Invariants I1-I6
Lines 216-407: Execution Rules E1-E14 (FULL RANGE - you own this section)
```

### ⏳ 8. Agent C Content Extraction Fix

**Current:**
```markdown
Lines 183-523: State Machine + Message Formats + Merge Procedure
```

**Required:**
```markdown
Lines 183-215: State Machine (STOP BEFORE line 216 - Agent B owns Execution Rules)
Lines 409-523: Message Formats + remaining content
```

### ⏳ 9. Agent E0 Full Prompt (NEW)

Complete prompt needed based on IMPL-FIXES template:
- Field 0: Worktree isolation (wave1-5-agent-E0)
- Field 1: Read-only verification (no file ownership)
- Field 4: Check all I1-I6, E1-E14 present in extracted files
- Field 6: Verification gate (grep for invariants, check line counts)

### ⏳ 10. Agent F Split (F1 + F2 prompts)

Original Agent F needs splitting into two complete prompts:

**F1 (file moves):**
- git mv prompts/ → implementations/claude-code/prompts/
- git mv examples/, hooks/, docs/QUICKSTART.md
- Verification: old locations gone, new locations exist, history preserved

**F2 (README updates):**
- Create implementations/README.md
- Create implementations/claude-code/README.md
- Rewrite root README.md
- Verification: link checking on all READMEs

### ⏳ 11. Agent I Reference Update

Agent I creates symlinks pointing to files moved by Agent F.
- Update dependencies: "Wave 2 (F)" → "Wave 2 (F1)"
- Verify paths point to implementations/claude-code/prompts/

---

## Execution Strategy

**Option 1: Manual completion (recommended)**
- Apply remaining fixes before `/saw wave`
- Estimated time: 30-45 min to update 11 agent Field 0 sections + detailed fixes
- Safest approach

**Option 2: Progressive execution**
- Execute Wave 1 with current fixes (structural changes done)
- If Field 0 isolation failures occur, agents will report in completion reports
- Apply fixes between waves
- Higher risk but gathers empirical data on failure modes

**Option 3: Automated script**
- Write sed/awk script to apply Field 0 pattern to all 11 agents
- Faster but requires validation
- Estimated time: 15-20 min to write + test script

---

## Recommendation

Apply **Option 1** - Complete all fixes before execution. The structural changes (wave structure, file ownership, content extraction ranges) are done. Remaining work is applying the worktree isolation template to 11 agent sections, which is mechanical but critical for I1/E4 compliance.

**Status:** Ready to complete remaining fixes before wave execution.
