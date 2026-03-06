# IMPL Document Schema

**Version:** 1.0.0

The IMPL doc is the coordination artifact that enables parallel agent execution in the Scout-and-Wave protocol. This document defines its canonical structure, required sections, and constraints that any implementation (automated or manual) must follow.

---

## Purpose

The IMPL doc serves as:
- **Single source of truth** (I4) for all coordination data
- **Contract layer** between Scout planning and Wave execution
- **Merge coordination surface** for orchestrators
- **Audit trail** documenting agent work and decisions

All structured messages (suitability verdicts, agent prompts, completion reports) are written to the IMPL doc, not chat output or separate files.

---

## File Naming Convention

**Pattern:** `docs/IMPL/IMPL-<feature-slug>.md`

**Examples:**
- `docs/IMPL/IMPL-add-caching-layer.md`
- `docs/IMPL/IMPL-refactor-protocol-extraction.md`
- `docs/IMPL/IMPL-fix-race-condition.md`

**Location:** Always in `docs/IMPL/` directory at repository root

**Format:** Markdown with YAML code blocks for structured data

---

## Required Sections (11 Total)

The IMPL doc contains exactly 11 required sections, in order:

1. Suitability Assessment
2. Scaffolds (conditional - omit if not needed)
3. Known Issues (optional but recommended)
4. Dependency Graph
5. Interface Contracts
6. File Ownership
7. Wave Structure
8. Agent Prompts
9. Wave Execution Loop
10. Orchestrator Post-Merge Checklist
11. Status

After agents complete work, they append **Completion Reports** at the end of the document.

---

## Section 1: Suitability Assessment

**Purpose:** Record Scout's verdict on whether work is suitable for parallel execution, before any agents launch.

**Required fields:**
- **Verdict:** `SUITABLE | SUITABLE WITH CAVEATS | NOT SUITABLE`
- **test_command:** Full test suite command for post-merge verification
- **lint_command:** Check-mode lint command (or `"none"` if no linter)
- **Estimated times:** Scout phase, Wave N execution, Merge & verify, Total (SAW), Sequential baseline, Time savings
- **Recommendation:** Clear next action

**Format:**
```markdown
## Suitability Assessment

**Verdict:** SUITABLE

{Rationale paragraph explaining why work is suitable for SAW}

**test_command:** go test ./...

**lint_command:** go vet ./...

**Estimated times:**
- Scout phase: ~8 min
- Wave 1 execution: ~15 min (4 agents in parallel)
- Wave 2 execution: ~10 min (2 agents in parallel)
- Merge & verify: ~5 min
- Total (SAW): ~38 min
- Sequential baseline: ~60 min
- Time savings: ~22 min (58% faster)

**Recommendation:** Proceed
```

**If NOT SUITABLE:**
- Include **Failed preconditions** section listing each failed precondition by number and name, with evidence
- Include **Suggested alternative** (sequential execution, investigate-first, etc.)
- **STOP** - do not include sections 2-11. IMPL doc ends after suitability verdict.

**Precondition reference:** See `protocol/preconditions.md` for P1-P5 definitions.

---

## Section 2: Scaffolds (Conditional)

**Purpose:** Specify type scaffold files that Scaffold Agent must create before Wave 1 launches. These define shared types/interfaces that multiple agents will reference.

**When to include:** If any types, interfaces, or function signatures cross agent boundaries.

**When to omit:** If agents have independent type ownership (solo waves, no cross-agent interfaces, existing codebase has all needed types). Include explicit note: `No scaffolds needed - agents have independent file ownership.`

**Format:** Four-column table

```markdown
## Scaffolds

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [Exact type definitions, interface signatures] | `module/internal/types` | pending |
| `path/to/shared.rs` | [Exact struct and trait definitions] | `crate::shared` | pending |
```

**Column definitions:**
- **File:** Relative path from repository root. Scaffold Agent creates this file.
- **Contents:** Exact type definitions, interface signatures, struct declarations. No behavior, no function bodies. Inline in table cell or reference to earlier section with full definitions.
- **Import path:** Module-qualified import path. Agents in the wave import from this path.
- **Status:** Lifecycle indicator.

**Status lifecycle:**
- `pending` → Scout wrote spec, Scaffold Agent not yet run
- `committed (sha)` → Scaffold Agent created, compiled, and committed the file. SHA is the commit hash.
- `FAILED: {reason}` → Scaffold Agent could not compile. No file committed. Blocks wave launch.

**Orchestrator verification:** Before creating worktrees, orchestrator must verify all scaffold files show `committed (sha)` status. A `FAILED` status is a protocol stop: surface failure to human, do not proceed to worktree creation.

**Interface freeze (E2):** Scaffold files are committed to HEAD before worktrees are created. Once worktrees branch from HEAD, interface contracts become immutable. Revising a scaffold file requires recreating all worktrees or descoping the wave.

---

## Section 3: Known Issues (Optional but Recommended)

**Purpose:** Document pre-existing test failures, build warnings, or known bugs to distinguish them from regressions introduced by agent work.

**Format:** Bulleted list with status and workaround

**Example:**
```markdown
## Known Issues

- TestFoo_Integration - Hangs (tries to execute binary as CLI, blocked on upstream fix)
  - Status: Pre-existing, unrelated to this work
  - Workaround: Skip with `-skip 'TestFoo'`
- Linter warning: "unused variable" in legacy.go
  - Status: Pre-existing, out of scope
  - Workaround: None needed (does not block build)
```

**When to include:**
- Any failing tests that agents should NOT fix
- Build warnings agents should ignore
- Integration test limitations (requires Docker, external service, etc.)

---

## Section 4: Dependency Graph

**Purpose:** Explain the dependency structure between files, modules, and waves. Identifies which work blocks which other work, and why waves are sequenced.

**Required contents:**
- **DAG description:** Roots (no dependencies), leaves (blocks nothing), internal dependencies
- **Wave transition rationale:** Why Wave N+1 depends on Wave N completing
- **Files split or extracted:** When ownership conflicts arise (two agents need to modify same file), document how the file was split and who owns each piece
- **Cascade candidates:** Files NOT changing but referencing changed interfaces (call sites, importers, documentation)

**Format:** Prose with references to File Ownership table

**Example:**
```markdown
## Dependency Graph

**Wave 1 (Foundation):**
- **Roots:** All Wave 1 files are independent and can be created in parallel
  - `protocol/*.md` files extract content from existing PROTOCOL.md
  - `templates/*.md` files are new, no dependencies
- **No dependencies between these files**

**Wave 2 (Depends on Wave 1):**
- **Depends on:** Wave 1 completion (so new `protocol/` structure exists for links)
- **Roots:** File moves from `prompts/` → `implementations/claude-code/prompts/`
- **Internal dependency:** IMPL-SCHEMA.md references `protocol/message-formats.md` (created by Agent C in Wave 1)

**Cascade candidates:**
- `.claude/settings.json` (if present) - references old `prompts/` paths
- Post-merge verification will catch broken references via link checking
```

---

## Section 5: Interface Contracts

**Purpose:** Define binding contracts for cross-agent function signatures, types, and data structures. These are the interfaces agents MUST implement (Field 2) or MAY call (Field 3).

**Requirements:**
- **Language-specific, fully typed:** No pseudocode. Exact signatures agents will implement/call.
- **Explicit import paths:** Module-qualified paths for cross-file references
- **Behavioral contracts:** Return values, error handling, preconditions, postconditions

**Format:** Code blocks with language syntax + prose descriptions

**Example:**
```markdown
## Interface Contracts

**Wave 1 → Wave 2 contracts:**

Wave 2 agents will link to Wave 1's created files:

\`\`\`markdown
# Root README.md links created by Agent F:
- [PROTOCOL.md](PROTOCOL.md)
- [Protocol Documentation](protocol/README.md)
- [Claude Code Implementation](implementations/claude-code/README.md)

# IMPL-SCHEMA.md links created by Agent G:
- See [protocol/message-formats.md](protocol/message-formats.md)
- See [templates/agent-prompt-template.md](templates/agent-prompt-template.md)
\`\`\`

**Content extraction contracts:**

Agents A-C extract content from existing files but must preserve semantics:
- **Agent A** extracts from PROTOCOL.md lines 16-85 (Participants section)
- **Agent B** extracts from PROTOCOL.md lines 89-179 (Preconditions, Invariants, Execution Rules)
- **Agent C** extracts from PROTOCOL.md lines 183-523 (State Machine, Message Formats, Procedures)

Extraction rule: Remove tool names (Read, Write, Bash), keep invariant definitions (I1-I6), execution rule definitions (E1-E14), YAML schemas.
```

**For code interfaces:**

```go
// Agent B must implement (defined in scaffold file `internal/types/cache.go`):
type Cache interface {
    Get(ctx context.Context, key string) ([]byte, error)
    Set(ctx context.Context, key string, val []byte, ttl time.Duration) error
}

// Agent C may call (existing code in `pkg/store/store.go`):
func LoadConfig(path string) (*Config, error)
```

**Cross-reference:** Full YAML schemas for completion reports and suitability verdicts are in `protocol/message-formats.md`.

---

## Section 6: File Ownership

**Purpose:** Enforce disjoint file ownership (I1) by explicitly assigning each file to exactly one agent per wave.

**Format:** Four-column table

```markdown
## File Ownership

| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/README.md | A | 1 | — |
| protocol/participants.md | A | 1 | — |
| protocol/invariants.md | B | 1 | — |
| IMPL-SCHEMA.md | G | 2 | Wave 1 (C, D) |
| implementations/manual/checklist.md | H | 2 | Wave 1 (B, C) |
```

**Column definitions:**
- **File:** Relative path from repository root
- **Agent:** Letter identifier (A, B, C, ...)
- **Wave:** Wave number (1, 2, 3, ...)
- **Depends On:** Which prior wave's work this file requires (or `—` if no dependency)

**Constraints:**
- **I1 enforcement:** No file appears in multiple agent rows within the same wave
- **Exhaustiveness:** Every file that will be created or modified is listed
- **Excludes generated files:** Build artifacts, compiled binaries, dependency lockfiles (unless explicitly versioned)

**Orchestrator-owned files:** Files modified only post-merge (e.g., CHANGELOG.md, VERSION) are listed separately as "Orchestrator-owned files (post-merge only)".

---

## Section 7: Wave Structure

**Purpose:** Visual representation of the parallel execution plan, showing wave sequencing and agent concurrency.

**Format:** ASCII art diagram

**Example:**
```markdown
## Wave Structure

\`\`\`
Wave 1: [A] [B] [C] [D]          <- 4 parallel agents (foundation)
           |
           | (merge Wave 1 to main)
           v
Wave 2:   [E] [F] [G]            <- 3 parallel agents (depends on Wave 1)
           |
           | (merge Wave 2 to main)
           v
Wave 3:    [H]                    <- 1 agent (cleanup)
\`\`\`

**Wave transition rationale:**
- **Wave 1 → Wave 2:** Wave 2 agents create links to protocol/ files, so protocol/ must exist first
- **Wave 2 → Wave 3:** Wave 3 symlinks point to moved files, so file moves must complete first
```

**Contents:**
- Brackets `[X]` denote agents executing in parallel
- Vertical pipes `|` denote merge + verification gates between waves
- Prose explanation of why each wave depends on the prior wave

---

## Section 8: Agent Prompts

**Purpose:** Provide complete, self-contained instructions for each agent. Agents read their prompts from the IMPL doc, not from external files or chat messages.

**Format:** 9-field structure (Field 0-8) per agent

**Section header:** `### Agent {letter} - {Role Description}`

**Field structure:** See `templates/agent-prompt-template.md` for full definitions.

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

**Example snippet:**
```markdown
### Agent A - Protocol README and Participants

**Wave:** 1

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
\`\`\`bash
cd /absolute/path/to/repo/.claude/worktrees/wave1-agent-A
\`\`\`

**Step 2: Verify isolation**
\`\`\`bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/absolute/path/to/repo/.claude/worktrees/wave1-agent-A"
# ... verification script ...
\`\`\`

**Field 1: File Ownership**

You own these files (create new):
- `protocol/README.md`
- `protocol/participants.md`

**Field 2: Interfaces to Implement**

Create the `protocol/` directory and two initial protocol documentation files.

# ... Fields 3-8 follow ...
```

**Cross-reference:** `templates/agent-prompt-template.md` contains the complete template with embedded invariant definitions (I1, I2, I4, I5) and execution rule references (E4, E14).

---

## Section 9: Wave Execution Loop

**Purpose:** Provide rationale for the Orchestrator Post-Merge Checklist. Explains the merge procedure, interface deviation handling, and verification gate strategy.

**Contents:**
- Merge procedure summary (worktree-based or branch-based)
- Interface deviation handling: when to update downstream agent prompts
- Verification gate explanation: why certain commands are run, what failures mean
- Feature-specific considerations (e.g., "no build/test for documentation refactors")

**Format:** Prose with feature-specific notes

**Example:**
```markdown
## Wave Execution Loop

After each wave completes, work through the Orchestrator Post-Merge Checklist below in order. The checklist is the executable form; this loop is the rationale.

**This is a documentation-only refactor.** Standard merge procedures apply, but verification is different:
- **No build/test commands** (no executable code)
- **Verification is link checking:** All internal links must resolve
- **File existence validation:** All referenced files must exist

**Post-Wave 1:** Verify protocol/ and templates/ directories exist, all files have content.

**Post-Wave 2:** Verify file moves completed (old locations empty, new locations populated). Run link checker on all updated docs.
```

---

## Section 10: Orchestrator Post-Merge Checklist

**Purpose:** Executable checklist for orchestrators after each wave completes. Ensures correct merge order, conflict detection, verification gate execution, and status tracking.

**Format:** Markdown checklist with feature-specific steps

**Standard items:**
```markdown
## Orchestrator Post-Merge Checklist

After wave N completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` and `files_created` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — update downstream agent prompts for any item with `downstream_action_required: true`
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave{N}-agent-{X}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove .claude/worktrees/wave{N}-agent-{X}`
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: `{lint-autofix-command}`
      - [ ] Build: `{build-command}`
      - [ ] Tests: `{test-command}`
- [ ] Fix any cascade failures — check call sites of modified interfaces
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Update interface contracts for any deviations logged by agents
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps: {list any custom verification or cleanup steps}
- [ ] Commit: `git commit -m "chore: post-wave{N} verification and cleanup"`
- [ ] Launch next wave (or pause for review if not `--auto`)
```

**Feature-specific steps:** Insert additional checklist items for the specific feature (e.g., update CHANGELOG.md, verify migrations, run integration tests).

---

## Section 11: Status

**Purpose:** Live tracking of agent completion. Updated by orchestrator as agents finish work.

**Format:** Four-column table

```markdown
## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| — | Scaffold | Type scaffold files | TO-DO |
| 1 | A | Protocol README + Participants | TO-DO |
| 1 | B | Preconditions + Invariants + Execution Rules | IN PROGRESS |
| 1 | C | State Machine + Message Formats | DONE |
| 2 | D | Root doc updates | TO-DO |
```

**Status values:**
- `TO-DO` → Agent not yet launched
- `IN PROGRESS` → Agent launched, working
- `DONE` → Agent completed, merged to main
- `BLOCKED` → Agent cannot proceed (interface deviation, out-of-scope dependency, verification failure)

**Orchestrator responsibility:** Update status after reading each completion report and after merging each agent's branch.

---

## Completion Reports (Appended by Agents)

**Purpose:** Structured output from each agent documenting files changed, interface deviations, verification results, and commit SHAs. Orchestrators parse these to automate merge decisions.

**Location:** End of IMPL doc, one section per agent

**Format:** YAML code block + optional free-form notes

**Section header:** `### Agent {letter} - Completion Report`

**YAML schema:**
```yaml
status: complete | partial | blocked
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
files_created:
  - path/to/new/file
interface_deviations:
  - description: "Exact description of deviation from specified contract"
    downstream_action_required: true | false
    affects: [agent-letter, ...]  # agents in later waves that depend on this interface
  # or []
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why it's needed"
  # or []
tests_added:
  - test_function_name
  # or []
verification: PASS | FAIL ({command} - N/N tests)
```

**Field definitions:**
- **status:**
  - `complete`: All work done, verification passed, committed
  - `partial`: Some work done, incomplete or verification failed. Explain in notes.
  - `blocked`: Cannot proceed without changes outside agent's scope. Explain blocker in notes.
- **worktree:** Canonical worktree path (E5 naming: `.claude/worktrees/wave{N}-agent-{letter}`)
- **branch:** Branch name (must match worktree: `wave{N}-agent-{letter}`)
- **commit:** Git commit SHA if changes were committed. `"uncommitted"` if no changes or commit failed. I5 requires agents commit before reporting.
- **files_changed:** List of files modified (not created). Relative paths from repository root.
- **files_created:** List of files created. Relative paths from repository root.
- **interface_deviations:** List of deviations from Field 2 (Interfaces to Implement). Empty list `[]` if all contracts implemented exactly as specified.
  - `downstream_action_required: true`: Orchestrator must update affected downstream agent prompts before next wave launches.
  - `affects`: List of agent letters in later waves that depend on this interface.
- **out_of_scope_deps:** List of files outside agent's ownership that require changes for correct implementation. Empty list `[]` if no out-of-scope dependencies discovered.
- **tests_added:** List of test function names added. Should correspond to Field 5 (Tests to Write).
- **verification:** `PASS` if all Field 6 commands passed. `FAIL` with details if any command failed.

**Free-form notes section:** After the YAML block, agents may add notes for context that doesn't fit structured fields: key decisions, surprises, warnings, recommendations for downstream agents.

**Example:**
```markdown
### Agent B - Completion Report

\`\`\`yaml
status: complete
worktree: .claude/worktrees/wave1-agent-B
branch: wave1-agent-B
commit: 707c1c4
files_changed: []
files_created:
  - protocol/preconditions.md (78 lines)
  - protocol/invariants.md (46 lines)
  - protocol/execution-rules.md (116 lines)
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all 3 files exist, no tool names leaked)
\`\`\`

**Notes:**
- Invariants I1-I6 copied verbatim from PROTOCOL.md lines 133-179 as required
- Execution rules E1-E14 adapted with implementation-agnostic language
- All verification gates passed
```

**Cross-reference:** Full YAML schema and field definitions are in `protocol/message-formats.md`.

**E14 write discipline:** Agents append completion reports at the end of the IMPL doc. Agents never edit earlier sections (interface contracts, ownership table, suitability verdict). Those sections are frozen at worktree creation (E2).

---

## Implementation Notes

### Size Considerations

**Threshold:** If IMPL doc exceeds ~20KB (roughly 500 lines), consider splitting.

**Split strategy:**
- Keep suitability verdict, scaffolds, dependency graph, interface contracts, file ownership, wave structure, and status in the main IMPL doc
- Move agent prompts to separate files: `docs/IMPL/IMPL-<feature>-wave{N}-agent-{X}.md`
- Main IMPL doc links to per-agent files: `See [Agent A prompt](IMPL-<feature>-wave1-agent-A.md)`

**When NOT to split:**
- Documentation-only refactors (agent prompts are small)
- Simple features with <5 agents total
- When unified audit trail is more valuable than file size

### Concurrent Writes (E14)

**Problem:** Multiple agents append completion reports to the same IMPL doc in parallel.

**Solution:** E14 ensures each agent owns a distinct named section (`### Agent {letter} - Completion Report`). Two agents appending distinct sections always produce adjacent-section git conflicts with no semantic overlap.

**Orchestrator action:** Accept all appended sections when resolving IMPL doc merge conflicts. Never choose one agent's report over another's.

### Parsing Requirements

Orchestrators (automated or human) must parse:

1. **Status values:** Extract `status: complete | partial | blocked` from each completion report
2. **Interface deviations:** Parse `interface_deviations` array to identify blocked downstream agents
3. **Out-of-scope dependencies:** Parse `out_of_scope_deps` array to generate post-merge fix list
4. **Verification results:** Parse `verification: PASS | FAIL` to gate merges
5. **File lists:** Parse `files_changed` and `files_created` to predict merge conflicts

**Format assumption:** All structured data is in YAML code blocks with consistent field names. Orchestrators should reject malformed YAML or missing required fields.

---

## Relationship to Other Documents

- **protocol/message-formats.md** — Full YAML schemas for suitability verdicts, completion reports, and scaffold specs
- **templates/agent-prompt-template.md** — Generic 9-field agent prompt template with placeholder notation
- **templates/IMPL-doc-template.md** — Blank IMPL doc with all 11 sections (copy to start new IMPL doc)
- **protocol/invariants.md** — I1-I6 definitions referenced by this schema (file ownership, role separation, etc.)
- **protocol/execution-rules.md** — E1-E14 definitions referenced by this schema (write discipline, worktree naming, etc.)

---

**Version history:**
- v1.0.0 (2026-03-06): Initial schema extracted from existing IMPL docs and protocol definitions
