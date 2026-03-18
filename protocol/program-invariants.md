# Scout-and-Wave Program Invariants

**Version:** 0.1.0

This document defines the invariants that must hold throughout program-level execution in Scout-and-Wave. These invariants extend the IMPL-level invariants (I1-I6 in `invariants.md`) to multi-IMPL orchestration.

---

## Overview

Program invariants are identified by number (P1–P4). They parallel the structure of IMPL-level invariants but operate at a higher abstraction level: coordinating multiple IMPL documents into tiered execution rather than coordinating agents within a single IMPL.

When referenced in implementation files, the P-number serves as an anchor for cross-referencing and audit; implementations should embed the canonical definition verbatim alongside the reference so each document remains self-contained without requiring a lookup.

To audit consistency, search implementation files for `P{N}` and verify the embedded definitions match this document.

---

## Relationship to IMPL-Level Invariants

Program invariants are structural extensions of IMPL-level invariants, applied at a higher layer:

| IMPL Invariant | Program Invariant | Parallel Concept |
|----------------|-------------------|------------------|
| I1: Disjoint File Ownership | P1: IMPL Independence Within a Tier | Parallel execution safety within a tier |
| I2: Interface Contracts Precede Implementation | P2: Program Contracts Precede Tier Execution | Cross-IMPL types frozen before consumption |
| I3: Wave Sequencing | P3: Tier Sequencing | Sequential tier advancement |
| I4: IMPL Doc is Source of Truth | P4: PROGRAM Manifest is Source of Truth | Single coordination artifact |

**Key insight:** Tiers are to IMPLs what waves are to agents. Same-tier IMPLs execute in parallel (like same-wave agents). Later tiers depend on earlier tiers (like later waves depend on earlier waves). Program invariants enforce safety at this new layer of parallelism.

---

## P1: IMPL Independence Within a Tier

**Formal Statement:** No two IMPLs in the same tier may have a dependency relationship. If IMPL-A depends on outputs from IMPL-B, they must be in different tiers, with A assigned to a tier strictly greater than B's tier.

**Enforcement:** The Planner agent defines tier assignments when producing the PROGRAM manifest. The Orchestrator validates that no IMPL in tier N has `depends_on` referencing another IMPL also in tier N. Validation occurs:
- When the PROGRAM manifest is first produced (via `ValidateProgram()`)
- Before launching any Scout in the tier (pre-flight check)
- During Planner correction loop retries (analogous to E16 for Scout validation)

**Mechanical Validation:**
The `ValidateProgram()` function in the Go SDK performs this check:
1. For each tier T in the manifest
2. For each IMPL I in tier T
3. For each dependency D in I.DependsOn
4. Find the tier of D
5. If D is also in tier T, return a `P1_VIOLATION` validation error with details

If P1 is violated, the Planner is issued a correction prompt (analogous to Scout correction in E16) and retries up to 3 times. After 3 failures, the PROGRAM enters `NOT_SUITABLE` state and execution halts.

**Rationale:** This is the same principle as I1 (disjoint file ownership) but applied at the IMPL level. Same-tier IMPLs must be executable in parallel without coordination. If IMPL-A's Scout needs to know what types IMPL-B defined, they cannot be in the same tier — the dependency must be made explicit and B must complete first.

**Cross-IMPL coordination mechanism:**
- **Same tier:** No coordination allowed. IMPLs execute fully independently.
- **Different tiers:** Coordination via committed code. Tier N+1 Scouts read Tier N's committed outputs as ordinary source files.

**Related Rules:**
- See I1 (disjoint file ownership) in `protocol/invariants.md`
- See future E27+ (program execution rules) in Phase 2
- See `protocol/program-manifest.md` for tier and dependency schema

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
3. Verify the contract file is committed to HEAD (not in a worktree or uncommitted)
4. If any contract file is missing or uncommitted, enter `PROGRAM_BLOCKED` state
5. Surface error to human: which contract is missing, which tier is blocked

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
- See future E28+ (program contract materialization) in Phase 2
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

2. **Tier gate check:**
   - Read `tier_gates` from PROGRAM manifest
   - Execute each gate command for Tier N
   - Collect exit codes and output
   - If any required gate fails, enter `PROGRAM_BLOCKED` state

3. **Contract freeze check:**
   - Read all `program_contracts` where `freeze_at` references Tier N
   - For each contract, mark as frozen in PROGRAM manifest (or separate state file)
   - Verify contract files are committed (git log confirms commit exists)
   - Update contract metadata to indicate immutability

Only after all three conditions pass does the Orchestrator transition from `TIER_VERIFIED` (Tier N) to `TIER_EXECUTING` (Tier N+1).

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
- See future program state machine documentation in Phase 2
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
- After tier gate passes: increment `completion.tiers_complete`
- After program completes: set `state: COMPLETE`, write completion timestamp

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

When all preconditions hold and all invariants (I1-I6 + P1-P4) are maintained:

- No two IMPLs in the same tier will have conflicting dependencies
- Cross-IMPL interface drift is prevented; shared types are defined once and frozen at tier boundaries
- Integration failures surface at tier boundaries, not at the end of all tiers
- The Orchestrator can reconstruct full program state from the PROGRAM manifest at any time
- Multi-IMPL execution is as safe as single-IMPL execution, with additional parallelism

---

## Enforcement Mechanisms (Phase 1)

Phase 1 of the Program Layer defines invariants and validation logic. Enforcement is documented here so Phase 2 implementors know exactly what to build.

### P1 Enforcement: IMPL Independence Validation

**When:**
- During PROGRAM manifest validation (after Planner completes)
- Before launching any Scout in a tier (pre-flight check)

**How:**
- `ValidateProgram()` function in Go SDK checks depends_on within same tier
- If violation found, return `ValidationError` with code `P1_VIOLATION`
- Planner correction loop retries up to 3 times (analogous to E16 for Scout)
- After 3 failures, PROGRAM enters `NOT_SUITABLE` state

**Phase 2 Implementation:**
The Orchestrator will integrate this validation into the program execution loop.

### P2 Enforcement: Program Contract Existence Check

**When:**
- Before launching any Scout in Tier N+1
- After Tier N completes and gates pass

**How:**
- Orchestrator reads `program_contracts` section from manifest
- For each contract where `freeze_at` references a tier < N+1
- Verify `contract.location` file exists and is committed to HEAD
- If any contract file missing, enter `PROGRAM_BLOCKED` state

**Phase 2 Implementation:**
The Orchestrator will implement this check in the tier advancement logic.

### P3 Enforcement: Tier Completion Check

**When:**
- Before transitioning from `TIER_VERIFIED` (Tier N) to `TIER_EXECUTING` (Tier N+1)

**How:**
- Orchestrator reads PROGRAM manifest's `impls` section
- For each IMPL in Tier N, check `status == "complete"`
- Execute all `tier_gates` commands
- If all pass, update manifest and advance to next tier
- If any fail, enter `PROGRAM_BLOCKED` state

**Phase 2 Implementation:**
The Orchestrator will implement this as a state transition guard in the program state machine.

### P4 Enforcement: Manifest Read Discipline

**When:**
- All program execution decisions (tier ordering, IMPL discovery, dependency resolution)

**How:**
- Orchestrator always reads from PROGRAM manifest, never infers from file system
- Manifest is re-read at each tier boundary to handle manual edits
- All status updates write back to manifest atomically

**Phase 2 Implementation:**
This is a discipline enforced by code structure, not a single validation function.

---

## Cross-References

- See `protocol/invariants.md` for IMPL-level invariants I1-I6
- See `protocol/program-manifest.md` for PROGRAM manifest schema
- See `protocol/participants.md` for Planner role definition
- See `protocol/state-machine.md` for IMPL state transitions
- See `docs/program-layer-roadmap.md` for full Program Layer design (Section 6)
- Future: `protocol/program-execution-rules.md` (Phase 2) for E27+ rules

---

*Version 0.1.0 — Phase 1 of Program Layer. Enforcement mechanisms documented for Phase 2 implementation.*
