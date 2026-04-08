# Scout-and-Wave Program Invariants

**Version:** 0.3.0

This document defines the invariants that must hold throughout program-level execution in Scout-and-Wave. These invariants extend the IMPL-level invariants (I1-I6 in `invariants.md`) to multi-IMPL orchestration.

---

## Overview

Program invariants are identified by number (P1–P4, plus P1+ and P5). They parallel the structure of IMPL-level invariants but operate at a higher abstraction level: coordinating multiple IMPL documents into tiered execution rather than coordinating agents within a single IMPL. P5 (IMPL Branch Isolation) is defined in `protocol/invariants.md` because it bridges both levels — it is a program-level invariant enforced through IMPL-level git branch mechanics.

When referenced in implementation files, the P-number serves as an anchor for cross-referencing and audit; implementations should embed the canonical definition verbatim alongside the reference so each document remains self-contained without requiring a lookup.

To audit consistency, search implementation files for `P{N}` and verify the embedded definitions match this document.

---

## PROGRAM States

The Go SDK defines the following valid `ProgramState` values for the PROGRAM manifest's `state` field:

| State | Description |
|-------|-------------|
| `PLANNING` | Planner agent is producing the initial manifest |
| `VALIDATING` | Manifest is being validated against P1–P4 |
| `REVIEWED` | Human has reviewed and approved the manifest |
| `SCAFFOLD` | Program contracts are being materialized as source files |
| `TIER_EXECUTING` | Active tier is running (Scouts/agents in progress) |
| `TIER_VERIFIED` | Active tier's gate has passed; ready to advance |
| `COMPLETE` | All tiers complete, all gates passed |
| `BLOCKED` | Execution halted due to gate failure, missing contract, or merge conflict |
| `NOT_SUITABLE` | Planner determined the request is not suitable for program-level execution (e.g., P1 violation after 3 correction retries) |

**Note:** Earlier versions of this document used `PROGRAM_BLOCKED`; the Go implementation uses `BLOCKED`.

## IMPL Statuses Within a PROGRAM

Each `ProgramIMPL` entry in the manifest carries a `status` field (lowercase):

| Status | Description |
|--------|-------------|
| `pending` | IMPL has not been scouted yet |
| `scouting` | Scout agent is actively producing the IMPL doc |
| `reviewed` | Scout output has been reviewed |
| `executing` | Waves are running |
| `complete` | All waves merged and verified |

**Auto-status update:** When `FinalizeTier` successfully merges all IMPL branches, it automatically sets each merged IMPL's status to `complete` in the PROGRAM manifest. This eliminates the need for a manual `update-program-impl --status complete` step.

## ProgramIMPL Extended Fields

Each `ProgramIMPL` also carries these fields used by the prioritization system:

- `priority_score` (int): Computed by `UnblockingScore()` — higher scores indicate IMPLs that unblock more downstream work.
- `priority_reasoning` (string): Human-readable explanation of the score (e.g., `"unblocking(2x+100=+200), age(+0)"`).

These are populated by `ScoreTierIMPLs()` during automatic tier advancement.

## ProgramTier Extended Fields

Each `ProgramTier` carries:

- `concurrency_cap` (int): Maximum number of IMPLs to execute in parallel within this tier. When 0 or omitted, all IMPLs in the tier may execute simultaneously. The caller (Orchestrator or CLI) is responsible for honoring this cap.

---

## Relationship to IMPL-Level Invariants

Program invariants are structural extensions of IMPL-level invariants, applied at a higher layer:

| IMPL Invariant | Program Invariant | Parallel Concept |
|----------------|-------------------|------------------|
| I1: Disjoint File Ownership | P1: IMPL Independence Within a Tier | Parallel execution safety within a tier |
| I1 (extended) | P1+: File Disjointness Within a Tier | No same-tier IMPLs own the same file |
| I2: Interface Contracts Precede Implementation | P2: Program Contracts Precede Tier Execution | Cross-IMPL types frozen before consumption |
| I3: Wave Sequencing | P3: Tier Sequencing | Sequential tier advancement |
| I4: IMPL Doc is Source of Truth | P4: PROGRAM Manifest is Source of Truth | Single coordination artifact |
| (wave merge to HEAD) | P5: IMPL Branch Isolation | IMPL waves merge to IMPL branch, not main (see `protocol/invariants.md`) |

**Key insight:** Tiers are to IMPLs what waves are to agents. Same-tier IMPLs execute in parallel (like same-wave agents). Later tiers depend on earlier tiers (like later waves depend on earlier waves). Program invariants enforce safety at this new layer of parallelism.

---

## P1: IMPL Independence Within a Tier

**Formal Statement:** No two IMPLs in the same tier may have a dependency relationship. If IMPL-A depends on outputs from IMPL-B, they must be in different tiers, with A assigned to a tier strictly greater than B's tier.

**Enforcement:** The Planner agent defines tier assignments when producing the PROGRAM manifest. The Orchestrator validates that no IMPL in tier N has `depends_on` referencing another IMPL also in tier N. Validation occurs:
- When the PROGRAM manifest is first produced (via `ValidateProgram()`)
- Before launching any Scout in the tier (pre-flight check)
- During Planner correction loop retries (analogous to E16 for Scout validation)

**Mechanical Validation:**
The `ValidateProgram()` function in the Go SDK performs this check via `validateP1Independence()`:
1. For each tier T in the manifest
2. For each IMPL I in tier T
3. For each dependency D in I.DependsOn
4. Find the tier of D
5. If D is also in tier T, return a `P1_VIOLATION` validation error with details

Additionally, `validateTierOrdering()` enforces a stricter constraint: if IMPL-A depends on IMPL-B, A's tier must be *strictly greater* than B's tier (not merely different). Violations return a `TIER_ORDER_VIOLATION` error code. This prevents both same-tier dependencies (P1) and reverse-tier dependencies where a consumer is in an earlier tier than its producer.

If P1 is violated, the Planner is issued a correction prompt (analogous to Scout correction in E16) and retries up to 3 times. After 3 failures, the PROGRAM enters `NOT_SUITABLE` state and execution halts.

**Rationale:** This is the same principle as I1 (disjoint file ownership) but applied at the IMPL level. Same-tier IMPLs must be executable in parallel without coordination. If IMPL-A's Scout needs to know what types IMPL-B defined, they cannot be in the same tier — the dependency must be made explicit and B must complete first.

**Cross-IMPL coordination mechanism:**
- **Same tier:** No coordination allowed. IMPLs execute fully independently.
- **Different tiers:** Coordination via committed code. Tier N+1 Scouts read Tier N's committed outputs as ordinary source files.

**Failure isolation guarantee:** When an IMPL within a tier enters BLOCKED state,
execution of other IMPLs in the same tier continues uninterrupted. IMPL failures
do not cascade across same-tier peers. Only tier *progression* is gated — the
Orchestrator cannot advance to Tier N+1 until all IMPLs in Tier N reach "complete".
An IMPL that is permanently blocked may be removed from the tier (and the PROGRAM
re-planned) to unblock tier progression without re-running completed IMPLs.

**Related Rules:**
- See I1 (disjoint file ownership) in `protocol/invariants.md`
- See E28 (Tier Execution Loop), E29 (Tier Gate Verification), E31 (Parallel Scout Launching) in `protocol/execution-rules.md`
- See `protocol/program-manifest.md` for tier and dependency schema

---

## P1+: File Disjointness Within a Tier

**Formal Statement:** No two IMPLs in the same tier may list the same file
(qualified by repo if present) in their `file_ownership` tables. Ownership
of the same file by two co-tier IMPLs guarantees a merge conflict when both
IMPLs complete and their branches are merged to main.

**Relationship to P1:** P1 requires no same-tier *dependency relationships*
(logical independence). P1+ requires no same-tier *file ownership overlap*
(physical independence). Both must hold for parallel tier execution to be safe.
A pair of IMPLs can satisfy P1 (no explicit depends_on relationship) while
violating P1+ (both modify the same file). P1+ is the machine-enforceable
complement to P1's logical constraint.

**Enforcement:** Machine-enforced before launching any IMPL in a tier via
`sawtools check-program-conflicts <PROGRAM.yaml> --tier N`. This command:
1. Loads all IMPL docs for tier N (via `CheckIMPLConflicts()`)
2. Intersects their `file_ownership` tables
3. If any file appears in two or more IMPL ownership tables: BLOCKED with
   structured error output showing conflicting IMPLs and files (exit 1)
4. If all ownership sets are disjoint: exit 0 (proceed)

The `PrepareTier()` batching function also runs this check as its first step (Step 3); if conflicts are found, it aborts immediately with `Success=false`.

Additionally, `ValidateProgramImportMode()` performs P1+ file disjointness checks across all tiers when validating imported IMPL docs, using `ValidateP1FileDisjointness()` which returns errors with code `P1_FILE_OVERLAP`.

**When to run:**
- Before `prepare-wave` for any IMPL in the tier (pre-flight check)
- As part of `program-execute` auto-mode tier setup
- Any time an IMPL is added to or re-scouted within a tier

**Error message format:**
```
check-program-conflicts: BLOCKED — 2 conflict(s) detected in tier 1
Conflicting IMPLs:
  pkg/shared/types.go: [feature-a, feature-b]
Resolve by moving conflicting IMPLs to different tiers (sawtools tier-gate
suggestion: feature-b → tier 2).
```

**Resolution:** When P1+ is violated:
1. Run `sawtools check-impl-conflicts --impls <slugs>` for tier suggestion
2. Move the conflicting IMPL to the suggested tier in the PROGRAM manifest
3. Re-run check-program-conflicts to confirm resolution
4. Alternatively, split the conflicting IMPL into sub-IMPLs with disjoint ownership

**Go implementation types:** The conflict report uses `protocol.ConflictReport` (from `conflict.go`) containing `[]IMPLFileConflict` entries. Each conflict identifies the file path and the list of IMPL slugs that claim ownership.

**Rationale:** P1 (dependency-graph) and P1+ (file-level) together provide the
complete safety guarantee for parallel tier execution. P1 prevents logical
dependency violations. P1+ prevents the physical merge failures that would occur
even if logical dependencies are respected. Without P1+, two IMPLs that logically
don't depend on each other may both modify the same infrastructure file (e.g.,
`cmd/sawtools/main.go` for command registration), causing merge conflicts that block
tier completion.

**Related Rules:**
- See P1 (IMPL Independence Within a Tier) above
- See I1 (Disjoint File Ownership) in `protocol/invariants.md`
- `sawtools check-program-conflicts` is the P1+ equivalent of `sawtools check-conflicts`
  (which enforces I1 at the agent/wave level)

---

## P2: Program Contracts Precede Tier Execution

**Formal Statement:** All cross-IMPL types and APIs that a tier's IMPLs depend on must be:
1. Defined in the PROGRAM manifest's `program_contracts` section
2. Materialized as source code and committed to HEAD
3. Frozen (marked immutable) before any Scout in the consuming tier begins

**Enforcement:** The Orchestrator verifies that program contract files exist and are committed before launching Scout agents for the next tier. This check is analogous to the scaffold file existence check before worktree creation (I2 enforcement at IMPL level).

**Mechanical Verification:**
Before launching any Scout in Tier N:
1. Read all `program_contracts` entries where `freeze_at` references a tier < N
2. For each contract, verify that `contract.location` exists as a committed file
3. Verify the contract file is committed to HEAD via `git status --porcelain` (empty output means committed)
4. If any contract file is missing or uncommitted, enter `BLOCKED` state
5. Surface error to human: which contract is missing, which tier is blocked

The `FreezeContracts()` function in the Go SDK implements this check. It matches contracts to tiers by checking if any IMPL slug in the completing tier appears as a whole word in the contract's `freeze_at` string (word-boundary regex matching). Contracts that match but fail the existence/committed check are recorded as errors, and the overall `Success` is false.

`ValidateProgramImportMode()` also performs a P2 check: if an IMPL doc redefines an interface contract whose name matches a frozen program contract, it returns a `P2_CONTRACT_REDEFINITION` error.

**Program Contract Lifecycle:**
```
Tier 0: Planner defines program contracts in PROGRAM manifest
  ↓
Tier 0: Program Scaffold step materializes contracts as code files
  ↓
Tier 1: IMPLs execute, producing implementations that reference contracts
  ↓
Tier 1 gate passes: Contracts freeze (marked immutable)
  ↓
Tier 2: Scouts receive frozen contracts as input, treat them as unchangeable
```

**Rationale:** This extends I2 (interface contracts precede implementation) to the program level. Without frozen program contracts, separately-scouted IMPLs in Tier 2 may each define incompatible versions of a shared type. The Planner identifies shared types up front; the contracts are materialized before any IMPL executes; Tier N+1 Scouts build on top of frozen contracts from Tier N.

**Program Contract vs IMPL Contract:**
- **Program contract:** Cross-IMPL type (e.g., `UserSession` shared by auth, API, and dashboard IMPLs)
- **IMPL contract:** Cross-agent interface within one IMPL (e.g., `AuthService` defined by Wave 1, consumed by Wave 2)

Program contracts are defined by the Planner. IMPL contracts are defined by the Scout. Both follow the same principle: interfaces must be frozen before consumers execute.

**Related Rules:**
- See I2 (interface contracts precede implementation) in `protocol/invariants.md`
- See E2 (interface freeze) in `protocol/execution-rules.md`
- See E8 (same-wave interface failure handling) in `protocol/execution-rules.md`
- See E30 (Program Contract Freezing), E31 (Parallel Scout Launching) in `protocol/execution-rules.md`
- See `protocol/program-manifest.md` for program contract schema

---

## P3: Tier Sequencing

**Formal Statement:** Tier N+1 does not begin (no Scout launches, no IMPL work starts) until:
1. All IMPLs in Tier N have reached `COMPLETE` state
2. Tier N quality gates have passed
3. Program contracts that freeze at the Tier N boundary are committed and marked immutable

**Enforcement:** The Orchestrator controls state transitions between tiers. Before launching any work in Tier N+1, it performs these checks mechanically:

1. **IMPL completion check:**
   - Read PROGRAM manifest
   - For each IMPL I in Tier N, verify I.status == "complete"
   - If any IMPL is not complete, wait (poll or event-driven)
   - Note: `FinalizeTier()` automatically sets merged IMPLs to `complete` status, so this check typically passes immediately after a successful finalize.

2. **Tier gate check:**
   - `RunTierGate()` reads `tier_gates` from PROGRAM manifest
   - First verifies all IMPLs in the tier are complete; if not, returns `AllImplsDone=false` and `Passed=false`
   - Then executes each gate command with a 5-minute timeout per command
   - If any *required* gate fails, the tier fails (non-required gates are informational)
   - If the gate fails in auto-mode, `AutoTriggerReplan()` invokes the Planner agent to revise the manifest (E34)

3. **Contract freeze check:**
   - `FreezeContracts()` reads all `program_contracts` where `freeze_at` matches an IMPL slug in Tier N
   - For each contract, verifies the file exists and is committed to HEAD
   - If any contract file is missing or uncommitted, returns partial result with errors

Only after all three conditions pass does the Orchestrator transition from `TIER_VERIFIED` (Tier N) to `TIER_EXECUTING` (Tier N+1). In auto-mode, `AdvanceTierAutomatically()` orchestrates all three checks and computes the priority-ordered IMPL list for the next tier via `ScoreTierIMPLs()`.

**Tier Gate Definition:**
Tier gates are defined in the PROGRAM manifest's `tier_gates` section, reusing the existing `QualityGate` schema from IMPL manifests:
```yaml
tier_gates:
  - type: build
    command: "go build ./... && cd web && npm run build"
    required: true
  - type: test
    command: "go test ./... && cd web && npm test"
    required: true
```

These gates run after all Tier N IMPLs complete. Unlike IMPL-level gates (which run per-feature), tier gates run at project scope, verifying that all completed IMPLs integrate correctly.

**Rationale:** This extends I3 (wave sequencing) to the program level. Just as Wave N+1 cannot begin until Wave N is merged and verified, Tier N+1 cannot begin until Tier N is complete, verified, and its contracts are frozen. This prevents cascade failures where Tier 2 work is based on incomplete or incorrect Tier 1 outputs.

**Parallel execution within a tier:**
IMPLs within the same tier execute their full lifecycle in parallel:
```
TIER_EXECUTING (Tier 1)
  ├── IMPL-data-model:  SCOUT_PENDING → ... → COMPLETE
  └── IMPL-auth:        SCOUT_PENDING → ... → COMPLETE
  (Both running simultaneously, following P1 independence constraint)
```

The tier does not advance until BOTH reach COMPLETE.

**Related Rules:**
- See I3 (wave sequencing) in `protocol/invariants.md`
- See `protocol/state-machine.md` for IMPL state transitions
- See E28 (Tier Execution Loop), E29 (Tier Gate Verification), E33 (Automatic Tier Advancement) in `protocol/execution-rules.md`
- See `protocol/program-manifest.md` for tier gate schema

---

## P4: PROGRAM Manifest is Source of Truth

**Formal Statement:** The PROGRAM manifest is the single source of truth for:
- Which IMPLs exist and their execution order (tier assignments)
- Cross-IMPL dependencies (the `depends_on` graph)
- Program contracts (shared types/APIs) and their freeze points
- Tier completion status and overall program progress

The Orchestrator reads the PROGRAM manifest for all tier/IMPL ordering decisions. It never infers IMPL relationships from IMPL docs alone. IMPL docs reference the PROGRAM manifest but do not duplicate its information.

**Enforcement:** The Orchestrator follows this discipline mechanically:

1. **On program execution start:**
   - Read PROGRAM manifest from `docs/PROGRAM-<slug>.yaml`
   - Parse into `PROGRAMManifest` struct (Go SDK type)
   - Validate against schema and invariants P1-P3
   - Store in memory as the authoritative execution plan

2. **For tier advancement:**
   - Check PROGRAM manifest's `tiers` section for current tier number
   - Check each IMPL's status in the manifest (not by scanning disk)
   - Update manifest with new statuses (write back to disk)

3. **For Scout launching:**
   - Read IMPL list from `tiers[N].impls` array
   - Launch Scout for each IMPL slug in the list
   - Pass program contracts as input (read from `program_contracts` section)

4. **For dependency resolution:**
   - Resolve `depends_on` relationships from manifest only
   - Do not scan IMPL doc content to infer dependencies
   - Tier assignment is pre-computed; do not recalculate from depends_on

**Manifest Update Discipline:**
The PROGRAM manifest is updated at specific lifecycle events:
- After Planner completes: initial manifest creation
- After each IMPL state transition: update `impls[i].status`
- After `FinalizeTier` merges all IMPL branches: auto-sets merged IMPLs to `complete` status and persists via `SaveProgramManifest()`
- After tier gate passes: increment `completion.tiers_complete`
- After program completes: set `state: COMPLETE`, write `completion_date`, append `SAW:PROGRAM:COMPLETE` marker, archive to `docs/PROGRAM/complete/`, and update `CONTEXT.md`
- After replan (E34): Planner agent rewrites the manifest in place with revised tier structure

These updates are atomic file writes (read-modify-write), not concurrent edits. The Orchestrator is the sole writer.

**Relationship to IMPL Docs:**
- **PROGRAM manifest** governs cross-IMPL relationships and tier ordering
- **IMPL docs** govern intra-IMPL relationships (agent tasks, waves, file ownership)
- IMPL docs may reference the PROGRAM manifest (e.g., "This IMPL is part of PROGRAM-<slug>, Tier 2")
- IMPL docs do NOT duplicate tier assignments or dependency graphs

**Rationale:** This extends I4 (IMPL doc is source of truth) to the program level. Just as agents must write completion reports to the IMPL doc (not just chat), the Orchestrator must write program state to the PROGRAM manifest (not just in-memory state or logs). The manifest is a git-tracked file visible to all agents, humans, and tools. It provides auditability, recovery, and distributed coordination.

**Context Window Pressure Mitigation:**
The PROGRAM manifest persists state to disk, enabling the Orchestrator to reconstruct state without relying on context window memory:
- Read PROGRAM manifest at each tier boundary
- Load only the current tier's IMPL docs into context
- Use `sawtools program-status` to reconstruct full program state from disk

**Related Rules:**
- See I4 (IMPL doc is source of truth) in `protocol/invariants.md`
- See E14 (IMPL doc write discipline) in `protocol/execution-rules.md`
- See E23A (tool journal recovery) in `protocol/execution-rules.md`
- See `protocol/program-manifest.md` for full manifest schema

---

## Protocol Violations

Conditions that break program-level invariants and invalidate the correctness guarantees:

| Violation | Broken Invariant | Effect |
|-----------|-----------------|--------|
| Two IMPLs in the same tier have a dependency relationship | P1 | One IMPL's Scout plans against incomplete/incorrect outputs from another |
| Two IMPLs in the same tier own the same file | P1+ | Guaranteed merge conflict when both IMPL branches complete |
| Tier 2 Scout begins before Tier 1 program contracts are frozen | P2 | Interface drift; incompatible type definitions across IMPLs |
| Tier 2 begins before all Tier 1 IMPLs reach COMPLETE | P3 | Cascade failures; Tier 2 builds on incomplete foundation |
| Orchestrator infers IMPL relationships from disk scan instead of reading PROGRAM manifest | P4 | State drift; manifest becomes stale, loses value as coordination artifact |

**Cascade Risk without Program Invariants:**
Without P1-P4, multi-IMPL execution degrades into manual sequencing:
- No formal dependency graph → user must mentally track "which IMPL depends on which"
- No contract freeze → separately-scouted IMPLs define incompatible shared types
- No tier gates → integration failures surface at the end, not at tier boundaries
- No single source of truth → Orchestrator state diverges from reality

Program invariants extend SAW's correctness guarantees from feature-level to project-level.

---

## Protocol Guarantees

When all preconditions hold and all invariants (I1-I6 + P1-P5 including P1+) are maintained:

- No two IMPLs in the same tier will have conflicting dependencies
- No two IMPLs in the same tier own the same file; merge conflicts at tier completion are structurally impossible
- Cross-IMPL interface drift is prevented; shared types are defined once and frozen at tier boundaries
- Integration failures surface at tier boundaries, not at the end of all tiers
- The Orchestrator can reconstruct full program state from the PROGRAM manifest at any time
- Multi-IMPL execution is as safe as single-IMPL execution, with additional parallelism

---

## Enforcement Mechanisms

All enforcement mechanisms described below are implemented in the Go SDK (`pkg/protocol/`) and CLI (`cmd/sawtools/`).

### P1 Enforcement: IMPL Independence Validation

**When:**
- During PROGRAM manifest validation (after Planner completes)
- Before launching any Scout in a tier (pre-flight check)
- During import-mode validation (`ValidateProgramImportMode()`)

**How:**
- `ValidateProgram()` calls `validateP1Independence()` — checks depends_on within same tier → `P1_VIOLATION`
- `ValidateProgram()` calls `validateTierOrdering()` — checks dependency tier ordering → `TIER_ORDER_VIOLATION`
- `ValidateProgram()` calls `validateDependencyValidity()` — checks all depends_on targets exist → `INVALID_DEPENDENCY`
- `ValidateProgram()` calls `validateTierIMPLConsistency()` — checks every IMPL appears in exactly one tier → `TIER_MISMATCH`
- Planner correction loop retries up to 3 times (analogous to E16 for Scout)
- After 3 failures, PROGRAM enters `NOT_SUITABLE` state

**Implementation:** `pkg/protocol/program_validation.go` — `ValidateProgram()`, `validateP1Independence()`, `validateTierOrdering()`, `validateDependencyValidity()`, `validateTierIMPLConsistency()`

### P1+ Enforcement: File Ownership Conflict Detection

**When:**
- As Step 3 of `PrepareTier()` — before IMPL validation and branch creation
- Via standalone `sawtools check-program-conflicts <PROGRAM.yaml> --tier N`
- During import-mode validation (`ValidateProgramImportMode()`)

**How:**
- `PrepareTier()` calls `CheckIMPLConflicts()` which loads all IMPL docs for the tier and intersects `file_ownership` tables
- `ValidateProgramImportMode()` calls `ValidateP1FileDisjointness()` per tier → `P1_FILE_OVERLAP`
- If conflicts found, `PrepareTier()` aborts with `Success=false` before any branches are created
- CLI `check-program-conflicts` exits 1 with structured `ConflictReport` JSON and human-readable BLOCKED message on stderr

**Implementation:** `pkg/protocol/program_tier_prepare.go` — `PrepareTier()` Step 3; `pkg/protocol/program_validation.go` — `ValidateP1FileDisjointness()`, `ValidateProgramImportMode()`; `cmd/sawtools/check_program_conflicts_cmd.go`

### P2 Enforcement: Program Contract Freeze and Redefinition Check

**When:**
- After tier completion, before advancing to next tier (`FreezeContracts()`)
- During `AdvanceTierAutomatically()` in auto-mode
- During import-mode validation (`ValidateProgramImportMode()`)

**How:**
- `FreezeContracts()` identifies contracts whose `freeze_at` matches an IMPL slug in the completing tier (word-boundary regex match)
- For each matching contract, verifies file exists at `contract.location` and is committed via `git status --porcelain`
- If any contract file is missing or uncommitted, returns partial result with `Success=false`
- `ValidateProgramImportMode()` checks P2 redefinition: if an IMPL doc's `interface_contracts` redefines a frozen program contract name → `P2_CONTRACT_REDEFINITION`

**Implementation:** `pkg/protocol/program_freeze.go` — `FreezeContracts()`, `matchesSlugInFreezeAt()`; `pkg/protocol/program_validation.go` — `ValidateProgramImportMode()`; `cmd/sawtools/freeze_contracts_cmd.go`

### P3 Enforcement: Tier Completion and Gate Check

**When:**
- Before transitioning from `TIER_VERIFIED` (Tier N) to `TIER_EXECUTING` (Tier N+1)
- As part of `FinalizeTier()` which runs the tier gate after merging all IMPL branches
- In `AdvanceTierAutomatically()` during auto-mode tier advancement

**How:**
- `RunTierGate()` first checks all IMPLs in the tier have status `complete`; if not, returns `AllImplsDone=false`, `Passed=false`
- Then executes each `tier_gates` command via `sh -c` with a 5-minute timeout
- Required gates that fail cause `Passed=false`; non-required gate failures are informational
- `FinalizeTier()` runs `RunTierGate()` after all IMPL branch merges succeed
- In auto-mode, if the tier gate fails, `AutoTriggerReplan()` invokes the Planner agent to revise the manifest (E34)

**Implementation:** `pkg/protocol/program_tier_gate.go` — `RunTierGate()`, `runTierGateCommand()`; `pkg/protocol/program_tier_finalize.go` — `FinalizeTier()`; `pkg/engine/program_auto.go` — `AdvanceTierAutomatically()`, `AutoTriggerReplan()`

### P4 Enforcement: Manifest Read Discipline

**When:**
- All program execution decisions (tier ordering, IMPL discovery, dependency resolution)

**How:**
- Orchestrator always reads from PROGRAM manifest via `ParseProgramManifest()`, never infers from file system
- Manifest is re-read at each tier boundary and after replans to pick up changes
- All status updates write back to manifest atomically via `SaveProgramManifest()`
- `GetProgramStatus()` enriches manifest data with real-time IMPL doc state from disk but uses manifest as the authoritative fallback

**Implementation:** `pkg/protocol/program_parser.go` — `ParseProgramManifest()`, `SaveProgramManifest()`; `pkg/protocol/program_status.go` — `GetProgramStatus()`

### Additional Validations (Not Tied to a Single Invariant)

`ValidateProgram()` also performs these structural checks:

| Check | Error Code | Description |
|-------|-----------|-------------|
| Required fields | `MISSING_FIELD` | `title`, `program_slug`, and `state` must be non-empty |
| Valid state | `INVALID_STATE` | `state` must be one of the 9 defined `ProgramState` values |
| Valid IMPL statuses | `INVALID_STATUS` | Each IMPL status must be one of: pending, scouting, reviewed, executing, complete |
| Contract consumer validity | `INVALID_CONSUMER` | All `program_contracts[].consumers[].impl` must reference existing IMPL slugs |
| Slug format | `INVALID_SLUG_FORMAT` | `program_slug` and all IMPL slugs must be kebab-case |
| Completion bounds | `COMPLETION_BOUNDS` | `tiers_complete <= tiers_total`, `impls_complete <= impls_total` |
| IMPL total consistency | `IMPLS_TOTAL_MISMATCH` | `completion.impls_total` must equal the number of `impls` entries |

### PrepareTier: Atomic Batching Function

`PrepareTier()` combines multiple enforcement steps into a single atomic operation:

1. Parse PROGRAM manifest
2. Find tier by number
3. **P1+ conflict check** — calls `CheckIMPLConflicts()` for all tier IMPLs; aborts if conflicts found
4. **IMPL validation + E37 critic enforcement** — for each IMPL in the tier:
   - If `criticRequired()` (3+ wave 1 agents or file_ownership spans 2+ repos) and critic report is not PASS, aborts with E37 error
   - Runs `FixGateTypes()` auto-correction on gate types
   - Runs `Validate()` on each IMPL doc; aborts on validation errors
5. **Branch creation** — calls `CreateProgramWorktrees()` to create IMPL branches

If any step fails, returns partial result with `Success=false`. Steps are not retried.

**Implementation:** `pkg/protocol/program_tier_prepare.go` — `PrepareTier()`, `criticRequired()`, `criticPassed()`

### FinalizeTier: Atomic Batching Function

`FinalizeTier()` combines merge and gate operations:

1. Parse PROGRAM manifest and find tier
2. For each IMPL in tier order: merge IMPL branch to HEAD via `git merge --no-ff`
   - Branch naming: `saw/program/{program-slug}/tier{N}-impl-{impl-slug}`
   - Idempotent: if branch doesn't exist (already merged), skip
   - Stops on first merge failure
3. **Auto-update IMPL statuses** to `complete` and persist to manifest
4. Run `RunTierGate()` — if gate fails, return failure

**Implementation:** `pkg/protocol/program_tier_finalize.go` — `FinalizeTier()`

### IMPL Branch Isolation

IMPL branches follow the naming convention: `saw/program/{program-slug}/tier{N}-impl-{impl-slug}`

`CreateProgramWorktrees()` creates these as bare branches (not worktrees) — wave agents create their own worktrees; the IMPL branch is a staging merge target. If a branch already exists and is an ancestor of HEAD (already merged), it is auto-cleaned (branch deleted, stale worktree removed). If it exists and is *not* merged, creation fails with an error.

**Implementation:** `pkg/protocol/program_worktree.go` — `ProgramBranchName()`, `CreateProgramWorktrees()`

---

## Cross-References

- See `protocol/invariants.md` for IMPL-level invariants I1-I6 and P5 (IMPL Branch Isolation)
- See `protocol/program-manifest.md` for PROGRAM manifest schema
- See `protocol/participants.md` for Planner role definition
- See `protocol/state-machine.md` for IMPL state transitions
- See `docs/program-layer.md` for user-facing program documentation (autonomy levels, CLI commands, API, web UI)
- Program execution rules E28-E34 (including E28A, E28B) are defined in `protocol/execution-rules.md`

## Go SDK Implementation Map

| File | Key Functions |
|------|--------------|
| `pkg/protocol/program_types.go` | `PROGRAMManifest`, `ProgramState`, `ProgramIMPL`, `ProgramTier`, `ProgramContract` |
| `pkg/protocol/program_validation.go` | `ValidateProgram()`, `ValidateP1FileDisjointness()`, `ValidateProgramImportMode()` |
| `pkg/protocol/program_tier_prepare.go` | `PrepareTier()`, `criticRequired()`, `criticPassed()` |
| `pkg/protocol/program_tier_finalize.go` | `FinalizeTier()` |
| `pkg/protocol/program_tier_gate.go` | `RunTierGate()` |
| `pkg/protocol/program_freeze.go` | `FreezeContracts()` |
| `pkg/protocol/program_worktree.go` | `CreateProgramWorktrees()`, `ProgramBranchName()` |
| `pkg/protocol/program_status.go` | `GetProgramStatus()` |
| `pkg/protocol/program_parser.go` | `ParseProgramManifest()`, `SaveProgramManifest()` |
| `pkg/protocol/program_prioritizer.go` | `UnblockingScore()`, `PrioritizeIMPLs()` |
| `pkg/engine/program_auto.go` | `AdvanceTierAutomatically()`, `ReplanProgram()`, `ScoreTierIMPLs()` |
| `pkg/engine/program_tier_loop.go` | `RunTierLoop()`, `AutoTriggerReplan()` |
| `cmd/sawtools/prepare_tier_cmd.go` | CLI: `sawtools prepare-tier` |
| `cmd/sawtools/finalize_tier_cmd.go` | CLI: `sawtools finalize-tier` (with `--auto` flag) |
| `cmd/sawtools/check_program_conflicts_cmd.go` | CLI: `sawtools check-program-conflicts` |
| `cmd/sawtools/freeze_contracts_cmd.go` | CLI: `sawtools freeze-contracts` |
| `cmd/sawtools/mark_program_complete_cmd.go` | CLI: `sawtools mark-program-complete` |
| `cmd/sawtools/update_program_state_cmd.go` | CLI: `sawtools update-program-state` |
| `cmd/sawtools/update_program_impl_cmd.go` | CLI: `sawtools update-program-impl` |
| `cmd/sawtools/program_status_cmd.go` | CLI: `sawtools program-status` |

---

*Version 0.3.0 — Reconciled against Go SDK implementation. Added PROGRAM states, IMPL statuses, extended ProgramIMPL/ProgramTier fields. Updated enforcement mechanisms from Phase 1 stubs to actual implementation references. Documented PrepareTier/FinalizeTier batching functions, E37 critic enforcement, auto-status updates, IMPL branch isolation mechanics, auto-advance with priority scoring, E34 replan, additional structural validations, and Go SDK implementation map.*
