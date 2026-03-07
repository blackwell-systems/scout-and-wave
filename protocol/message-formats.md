# Scout-and-Wave Message Formats

**Version:** 0.8.0

This document defines the structured data formats exchanged between participants: suitability verdicts, agent prompts, completion reports, and scaffold specifications.

---

## Overview

SAW uses the IMPL doc (Implementation Document) as the single source of truth (I4). All structured messages are written to the IMPL doc, not chat output. The IMPL doc evolves through the protocol lifecycle:

1. **Scout phase:** Scout writes suitability verdict and agent prompts
2. **Scaffold phase:** Scaffold Agent updates Scaffolds section with commit status
3. **Wave execution:** Each agent appends a completion report section

---

## IMPL Doc Structure

The IMPL doc is a markdown file with the following sections in order:

```markdown
# IMPL: {Feature Name}

**Feature:** {One-line description}
**Repository:** {Absolute path to repository root}
**Plan Reference:** {Path to original plan/audit/issue}

---

## Suitability Assessment

{Suitability verdict - see format below}

---

## Scaffolds

{Scaffold files table - see format below}
{Omit this section if no scaffold files needed}

---

## Wave 1

{Wave-level introduction}

### Agent A - {Role Description}

{9-field agent prompt - see format below}

### Agent B - {Role Description}

{9-field agent prompt}

...

---

## Wave 2

{Similar structure for additional waves}

---

## Completion Reports

### Agent A - Completion Report

{Structured YAML block - see format below}

{Free-form notes}

### Agent B - Completion Report

{Structured YAML block}

{Free-form notes}
```

---

## Suitability Verdict Format

Emitted by the Scout at the end of the suitability gate. Written to the IMPL doc before any agent prompts.

### SUITABLE Verdict

```markdown
**Verdict:** SUITABLE

{One paragraph rationale explaining why work is suitable for SAW}

**Estimated times:**
- Scout phase: ~X min
- Wave 1 execution: ~Y min (N agents in parallel)
- Wave 2 execution: ~Z min (M agents in parallel)
- Merge & verify: ~W min
- Total (SAW): ~T min
- Sequential baseline: ~B min
- Time savings: ~D min (P% faster | slower)

**Recommendation:** Proceed
```

### SUITABLE WITH CAVEATS Verdict

```markdown
**Verdict:** SUITABLE WITH CAVEATS

{One paragraph rationale}

**Caveats:**
- {Caveat 1: description}
- {Caveat 2: description}

**Estimated times:**
{Same structure as SUITABLE}

**Recommendation:** Proceed with caveats acknowledged
```

### NOT SUITABLE Verdict

```markdown
**Verdict:** NOT SUITABLE

{One paragraph rationale explaining why work is not suitable}

**Failed preconditions:**
- Precondition {N} ({name}): {evidence from codebase}
- Precondition {M} ({name}): {evidence from codebase}

**Suggested alternative:** {sequential execution | investigate-first then re-scout | other: describe}

**Estimated times:**
{Same structure, but highlights that SAW would be slower or riskier than alternative}

**Recommendation:** Do not proceed
```

**Required fields for NOT SUITABLE:**
- `Failed preconditions`: Names each precondition that blocked the verdict by number and name, with specific evidence
- `Suggested alternative`: Makes the verdict actionable rather than a stop sign

**Precondition reference (from [preconditions.md](preconditions.md)):**
1. File decomposition
2. No investigation-first blockers
3. Interface discoverability
4. Pre-implementation scan
5. Positive parallelization value

---

## Agent Prompt Format

9-field structure embedded in the IMPL doc. Field 0 is mandatory pre-flight isolation verification. Fields 1–8 are the implementation specification.

**Full field definitions:** See `prompts/agent-template.md` for the complete template with embedded invariant definitions (I1, I2, I4, I5) and execution rule references (E4, E14).

**Brief field summary:**

| Field | Content | Purpose |
|-------|---------|---------|
| **0. Isolation Verification** | Bash commands to verify worktree, branch, working directory | Defense-in-depth: ensure agent operates in correct worktree before modifying files |
| **1. File Ownership** | Exact files the agent owns | Hard constraint (I1: disjoint ownership) |
| **2. Interfaces to Implement** | Exact signatures the agent must deliver | Contract the agent implements |
| **3. Interfaces to Call** | Exact signatures from prior waves or existing code | Dependencies the agent may import |
| **4. What to Implement** | Functional description (what, not how) | Task definition |
| **5. Tests to Write** | Named tests with one-line descriptions | Verification requirements |
| **6. Verification Gate** | Exact commands (build, lint, test), scoped to owned files/packages | Pre-report checklist |
| **7. Constraints** | Hard rules (error handling, compatibility, things to avoid) | Implementation guardrails |
| **8. Report** | Instructions for writing completion report | Structured output format |

**Field 0 structure (isolation verification):**

```markdown
## 0. CRITICAL: Isolation Verification (RUN FIRST)

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd {absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter}
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="{absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave{N}-agent-{letter}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files).
```

**Cross-reference:** Field 0–8 full definitions are in `prompts/agent-template.md` with embedded invariant and execution rule text for self-contained prompts.

---

## Completion Report Format

Structured YAML block written by each agent to the IMPL doc. Machine-readable. Orchestrator parses these before merging.

**E14: Write discipline:** Agents append completion reports at the end of the IMPL doc under `### Agent {letter} - Completion Report`. Agents never edit earlier sections (interface contracts, ownership table, suitability verdict). Those sections are frozen at worktree creation (E2).

**Structure:**

```yaml
### Agent {letter} - Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
  - path/to/modified/file_test
files_created:
  - path/to/new/file
  - path/to/new/file_test
interface_deviations:
  - description: "Exact description of deviation from specified contract"
    downstream_action_required: true | false
    affects: [agent-letter, ...]  # agents in later waves that depend on this interface
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why it's needed"
  # or []
tests_added:
  - test_function_name
  - test_function_name_edge_case
verification: PASS | FAIL ({command} - N/N tests)
```

**Field definitions:**

- **status:**
  - `complete`: All work done, verification passed, committed
  - `partial`: Some work done, but incomplete or verification failed. Explain what remains in notes.
  - `blocked`: Cannot proceed without changes outside agent's scope (interface contract unimplementable, missing dependency, etc.). Explain blocker in notes.

- **worktree:** Canonical worktree path. Must match E5 naming convention: `.claude/worktrees/wave{N}-agent-{letter}`

- **branch:** Branch name. Must match worktree naming: `wave{N}-agent-{letter}`

- **commit:** Git commit SHA if changes were committed. `"uncommitted"` if no changes or commit failed. I5 requires agents commit before reporting.

- **files_changed:** List of files modified (not created). Relative paths from repository root.

- **files_created:** List of files created. Relative paths from repository root.

- **interface_deviations:** List of deviations from Field 2 (Interfaces to Implement). Empty list `[]` if all contracts implemented exactly as specified.
  - `downstream_action_required: true`: Orchestrator must update affected downstream agent prompts before next wave launches.
  - `affects`: List of agent letters in later waves that depend on this interface.

- **out_of_scope_deps:** List of files outside agent's ownership that require changes for correct implementation. Empty list `[]` if no out-of-scope dependencies discovered.

- **tests_added:** List of test function names added. Should correspond to Field 5 (Tests to Write).

- **verification:** `PASS` if all Field 6 commands passed. `FAIL` with details if any command failed.

**Free-form notes section:** After the structured YAML block, agents may add free-form notes for context that doesn't fit structured fields: key decisions, surprises, warnings, recommendations for downstream agents.

---

## Scaffolds Section Format

Written by the Scout into the IMPL doc to specify type scaffold files. Read and materialized by the Scaffold Agent after human review.

**Canonical four-column format:**

```markdown
### Scaffolds

[Omit this section if no scaffold files are needed.]

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [exact types, interfaces, structs with signatures] | `module/internal/types` | pending |
| `path/to/shared.go` | [exact interfaces] | `module/pkg/shared` | pending |
```

**Column definitions:**

- **File:** Relative path from repository root. Scaffold Agent creates this file.
- **Contents:** Exact type definitions, interface signatures, struct declarations (no behavior, no function bodies). Inline in table cell or reference to earlier section.
- **Import path:** Module-qualified import path. Agents in the wave import from this path.
- **Status:** Lifecycle indicator.

**Status lifecycle:**

- `pending`: Scout wrote spec, Scaffold Agent not yet run
- `committed (sha)`: Scaffold Agent created, compiled, and committed the file. SHA is the commit hash.
- `FAILED: {reason}`: Scaffold Agent could not compile. No file committed. Orchestrator surfaces failure to human.

**Orchestrator verification:** Before creating worktrees, Orchestrator verifies all scaffold files show `committed (sha)` status. A `FAILED` status is a protocol stop: surface the failure to the human, do not proceed to worktree creation.

**When to omit Scaffolds section:**
- Solo waves (one agent): no shared types across agents
- No cross-agent interfaces: each agent owns fully independent subsystems
- Existing codebase has all needed types: agents import from existing code, no new shared types

**Interface freeze (E2):** Scaffold files are committed to HEAD before worktrees are created. Once worktrees branch from HEAD, interface contracts become immutable. Revising a scaffold file requires recreating all worktrees or descoping the wave.

---

## Message Flow Sequence

1. **Scout → IMPL doc:** Writes suitability verdict, Scaffolds section (if needed), agent prompts
2. **Human → Orchestrator:** Approves or rejects IMPL doc
3. **Scaffold Agent → IMPL doc:** Updates Scaffolds section Status column with commit SHAs or FAILED
4. **Orchestrator → Agents:** Launches agents with absolute IMPL doc path (agents read their prompts from IMPL doc)
5. **Agents → IMPL doc:** Append completion reports
6. **Orchestrator → Human:** Surfaces completion reports, merge results, verification status

**Anti-pattern:** Completion reports written to chat only (I4 violation). IMPL doc is the single source of truth. Chat output is ephemeral; downstream agents and merge procedures rely on IMPL doc contents.

---

## IMPL Doc Conflict Resolution

**E12: Merge conflict taxonomy:**

1. **Git conflict on agent-owned files:** I1 violation (impossible if invariants hold). Do not merge. Correct ownership table and re-run wave.

2. **Git conflict on orchestrator-owned shared files (IMPL doc completion reports, append-only configs):** Expected. Resolve by accepting all appended sections. E14 ensures each agent owns a distinct named section; no semantic conflict, only git line adjacency conflict.

3. **Semantic conflict (incompatible interface implementations without git conflict):** Surfaces in `interface_deviations` and `out_of_scope_deps`. Resolved by Orchestrator before next wave via interface revision and prompt updates.

**E14 makes IMPL doc conflicts predictable:** Agents only append their named completion report section at the end. They never edit earlier sections (ownership table, interface contracts, wave structure). Two agents appending distinct sections always produce adjacent-section git conflicts with no semantic overlap.

---

**Reference:** See `state-machine.md` for protocol states and transitions. See `procedures.md` for orchestrator actions when reading and processing these messages.
