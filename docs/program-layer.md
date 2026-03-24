# Program Layer Reference

**Version:** 0.2.0 (Protocol), Phase 3 implementation (Web App)
**Status:** Phases 1-3 implemented; Phase 4 (full autonomous + re-planning) partially implemented

---

## Table of Contents

1. [Overview](#1-overview)
2. [Autonomy Levels](#2-autonomy-levels)
3. [PROGRAM Manifest Schema](#3-program-manifest-schema)
4. [Program State Machine](#4-program-state-machine)
5. [Program Invariants](#5-program-invariants-p1p4)
6. [CLI Commands — /saw program](#6-cli-commands--saw-program)
7. [sawtools Commands](#7-sawtools-commands)
8. [API Reference](#8-api-reference)
9. [SSE Events](#9-sse-events)
10. [Web UI Guide](#10-web-ui-guide)
11. [Execution Rules](#11-execution-rules-e28e34)
12. [Re-Planning](#12-re-planning)
13. [Cross-IMPL Contracts](#13-cross-impl-contracts)
14. [End-to-End Example](#14-end-to-end-example)

---

## 1. Overview

Scout-and-Wave operates at three levels of abstraction:

```
Program               — coordinates multiple IMPLs across tiers
  └── IMPL (existing) — coordinates multiple agents within a feature
        └── Agent     — implements files within a wave
```

The **Program Layer** is the top tier. It introduces a new protocol artifact — the **PROGRAM manifest** — that decomposes a large project into multiple IMPL docs organized into sequenced tiers, where IMPLs within the same tier execute in parallel. The Program Layer is analogous to how an IMPL doc coordinates agents: tiers are to IMPLs what waves are to agents.

### When to Use the Program Layer

Use the Program Layer when:

- The project spans **3 or more distinct features** with cross-feature dependencies
- The total estimated work exceeds **8 agents**
- Features share types or APIs that must be formally defined before implementation begins
- There are **at least 2 tiers** of features (some depend on others)

Do not use the Program Layer when:
- A single IMPL doc would handle the project (use `/saw bootstrap` instead)
- Features are fully independent with no shared interfaces (use sequential Scout runs)
- The Planner's suitability gate returns `NOT_SUITABLE`

### The Three-Tier Hierarchy in Practice

| Level | Artifact | Produces | Parallelism |
|-------|----------|----------|-------------|
| Program | `PROGRAM-<name>.yaml` | Planner agent | IMPLs within a tier |
| IMPL | `IMPL-<feature>.yaml` | Scout agent | Agents within a wave |
| Agent | Source code + completion report | Wave/Scaffold Agent | None (each agent owns distinct files) |

### Relationship to Existing Artifacts

```
docs/REQUIREMENTS.md         — Orchestrator writes before launching Planner
    ↓
docs/PROGRAM-<name>.yaml     — Planner writes (NEW)
    ↓
docs/IMPL/IMPL-<slug>.yaml   — Scout writes per feature (unchanged)
    ↓
docs/CONTEXT.md              — Updated after each IMPL completes (unchanged)
```

---

## 2. Autonomy Levels

The Program Layer offers three autonomy levels controlled by the command used.

### Level A: Plan Only

```
/saw program plan "<project-description>"
```

The Planner agent analyzes requirements and produces the PROGRAM manifest. No execution occurs automatically. The manifest serves as a formal roadmap: tier ordering, cross-IMPL dependency graph, and program contracts. The user manually runs `/saw scout` and `/saw wave` for each IMPL in the order specified by the tiers.

**Value even without automated execution:** The PROGRAM manifest provides a persistent, validated artifact capturing the project decomposition. Cross-IMPL contracts prevent interface drift even under manual execution.

### Level B: Tier-Gated Execution (Recommended)

```
/saw program execute "<project-description>"
```

The Orchestrator drives execution automatically within each tier — scouting all IMPLs in parallel, executing all waves — but **pauses at each tier boundary** for human review before advancing. Human gates fire:

1. After the initial PROGRAM manifest is produced (always required, even in `--auto`)
2. After each tier completes and contracts are frozen (waits for human confirmation)

This is the recommended mode for most projects. It provides full parallelism within tiers while preserving human oversight at the integration points that matter most.

### Level C: Full Autonomous

```
/saw program execute --auto "<project-description>"
```

Same as Level B, but the inter-tier human confirmation gates are bypassed when tier gates pass. The Orchestrator advances automatically through tier boundaries. The initial PROGRAM manifest review (`PROGRAM_REVIEWED`) is **never skipped**, even in `--auto` mode. Failures always surface to the human regardless of `--auto`.

**Prerequisite:** The Resilient Execution Lifecycle (`IMPL-resilient-execution-lifecycle`) should be complete before relying on Level C for large programs, because step-level recovery at the IMPL level provides the safety net for multi-IMPL concurrent execution.

---

## 3. PROGRAM Manifest Schema

PROGRAM manifests are stored at `docs/PROGRAM-<name>.yaml` in the project repository.

### 3.1 Go Struct Definition

The canonical type is `protocol.PROGRAMManifest` in `pkg/protocol/program_types.go`:

```go
type PROGRAMManifest struct {
    Title            string            `yaml:"title"`
    ProgramSlug      string            `yaml:"program_slug"`
    State            ProgramState      `yaml:"state"`
    Created          string            `yaml:"created,omitempty"`
    Updated          string            `yaml:"updated,omitempty"`
    Requirements     string            `yaml:"requirements,omitempty"`
    ProgramContracts []ProgramContract `yaml:"program_contracts,omitempty"`
    Impls            []ProgramIMPL     `yaml:"impls"`
    Tiers            []ProgramTier     `yaml:"tiers"`
    TierGates        []QualityGate     `yaml:"tier_gates,omitempty"`
    Completion       ProgramCompletion `yaml:"completion"`
    PreMortem        []PreMortemRow    `yaml:"pre_mortem,omitempty"`
}
```

### 3.2 Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Human-readable project description |
| `program_slug` | string | Yes | Kebab-case identifier; must match filename (e.g., `greenfield-api` in `PROGRAM-greenfield-api.yaml`) |
| `state` | ProgramState | Yes | Current execution state (see Section 4) |
| `created` | string | No | ISO 8601 date (YYYY-MM-DD) |
| `updated` | string | No | ISO 8601 date (YYYY-MM-DD) |
| `requirements` | string | No | Path to requirements document (e.g., `docs/REQUIREMENTS.md`) |
| `program_contracts` | array | No | Cross-IMPL interface contracts |
| `impls` | array | Yes | IMPL entries with dependency declarations |
| `tiers` | array | Yes | Tier groupings |
| `tier_gates` | array | No | Quality gate commands run after each tier |
| `completion` | object | Yes | Progress counters |
| `pre_mortem` | array | No | Risk analysis entries |

### 3.3 ProgramContract Schema

Go type: `protocol.ProgramContract`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Contract identifier (e.g., `UserSession`, `APIResponse<T>`) |
| `description` | string | No | Purpose and scope |
| `definition` | string | Yes | Type definition or API signature (verbatim source code) |
| `consumers` | array | No | List of `ProgramContractConsumer` entries |
| `location` | string | Yes | File path where contract will be materialized as source |
| `freeze_at` | string | No | When contract becomes immutable (e.g., `"Tier 1 completion"` or `"IMPL-auth completion"`) |

`ProgramContractConsumer`:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `impl` | string | Yes | IMPL slug that consumes this contract |
| `usage` | string | Yes | How the IMPL uses the contract |

**Freeze matching:** The `freeze_at` field is matched against IMPL slugs using word-boundary regex. `"IMPL-auth completion"` matches the slug `auth`. `"Tier 1 completion"` does not match by IMPL slug — contracts using tier-description `freeze_at` strings are skipped by `FreezeContracts` unless they contain a matching IMPL slug as a whole word.

### 3.4 ProgramIMPL Schema

Go type: `protocol.ProgramIMPL`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `slug` | string | Yes | Kebab-case IMPL identifier; corresponds to future `IMPL-<slug>.yaml` |
| `title` | string | Yes | Human-readable feature description |
| `tier` | integer | Yes | Tier number this IMPL belongs to |
| `depends_on` | array | No | List of IMPL slugs this feature depends on (must be in earlier tiers) |
| `estimated_agents` | integer | No | Expected agent count (populated by Scout after analysis) |
| `estimated_waves` | integer | No | Expected wave count (populated by Scout after analysis) |
| `key_outputs` | array | No | Expected file/directory patterns |
| `status` | string | Yes | Current IMPL status (see below) |

**IMPL status values:**

| Status | Description |
|--------|-------------|
| `pending` | Not yet scouted |
| `scouting` | Scout agent running |
| `reviewed` | IMPL doc produced, awaiting human approval |
| `executing` | Waves in progress |
| `complete` | All waves verified and merged |

### 3.5 ProgramTier Schema

Go type: `protocol.ProgramTier`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `number` | integer | Yes | Tier number (1-based, sequential) |
| `impls` | array | Yes | List of IMPL slugs in this tier |
| `description` | string | No | Human-readable tier purpose |

**Validation rules enforced by `ValidateProgram`:**
- Tier numbers must be sequential starting from 1
- Each IMPL must appear in exactly one tier
- All IMPL slugs referenced in `tiers` must exist in `impls`
- No IMPL may have `depends_on` referencing another IMPL in the same tier (P1 invariant)
- If IMPL-A `depends_on` IMPL-B, then A's tier must be strictly greater than B's tier

### 3.6 QualityGate Schema (Tier Gates)

Tier gates reuse the `QualityGate` struct from IMPL manifests:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Gate type: `build`, `test`, `lint`, or `custom` |
| `command` | string | Yes | Shell command to execute |
| `required` | boolean | Yes | If true, non-zero exit blocks tier completion |
| `description` | string | No | Human-readable purpose |

Tier gate commands run with a **5-minute timeout**. The working directory is set to `repoPath`.

### 3.7 ProgramCompletion Schema

Go type: `protocol.ProgramCompletion`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tiers_complete` | integer | Yes | Number of tiers with all IMPLs complete |
| `tiers_total` | integer | Yes | Total tier count |
| `impls_complete` | integer | Yes | Number of IMPLs at status `complete` |
| `impls_total` | integer | Yes | Total IMPL count |
| `total_agents` | integer | Yes | Sum of agents across all IMPLs (0 until scouted) |
| `total_waves` | integer | Yes | Sum of waves across all IMPLs (0 until scouted) |

**Validation:** `tiers_complete` must not exceed `tiers_total`; `impls_complete` must not exceed `impls_total`.

### 3.8 Minimal Valid Manifest

```yaml
title: "Minimal project"
program_slug: minimal
state: PLANNING
impls:
  - slug: single-feature
    title: "Single feature"
    tier: 1
    status: pending
tiers:
  - number: 1
    impls: [single-feature]
completion:
  tiers_complete: 0
  tiers_total: 1
  impls_complete: 0
  impls_total: 1
  total_agents: 0
  total_waves: 0
```

### 3.9 Full Example Manifest

```yaml
# PROGRAM: greenfield-api
title: "Greenfield API and Dashboard"
program_slug: greenfield-api
state: PLANNING
created: 2026-03-17
updated: 2026-03-17
requirements: "docs/REQUIREMENTS.md"

program_contracts:
  - name: "UserSession"
    description: "Core session type shared by auth, dashboard, and API layers."
    definition: |
      type UserSession struct {
        ID        string
        UserID    string
        ExpiresAt time.Time
        Claims    map[string]interface{}
      }
    consumers:
      - impl: "auth"
        usage: "Creates and validates sessions"
      - impl: "api-routes"
        usage: "Extracts session from middleware context"
      - impl: "dashboard"
        usage: "Reads session for display"
    location: "pkg/types/session.go"
    freeze_at: "IMPL-auth completion"

impls:
  - slug: "data-model"
    title: "Core data model and storage layer"
    tier: 1
    depends_on: []
    estimated_agents: 3
    estimated_waves: 1
    key_outputs: ["pkg/models/*.go", "pkg/storage/*.go"]
    status: pending

  - slug: "auth"
    title: "Authentication and session management"
    tier: 1
    depends_on: []
    estimated_agents: 2
    estimated_waves: 1
    key_outputs: ["pkg/auth/*.go", "pkg/middleware/auth.go"]
    status: pending

  - slug: "api-routes"
    title: "REST API route handlers"
    tier: 2
    depends_on: ["data-model", "auth"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs: ["pkg/api/*.go"]
    status: pending

tiers:
  - number: 1
    impls: ["data-model", "auth"]
    description: "Foundation — no dependencies, can execute fully in parallel"
  - number: 2
    impls: ["api-routes"]
    description: "Core features — depend on Tier 1 outputs"

tier_gates:
  - type: build
    command: "go build ./..."
    required: true
  - type: test
    command: "go test ./..."
    required: true

completion:
  tiers_complete: 0
  tiers_total: 2
  impls_complete: 0
  impls_total: 3
  total_agents: 0
  total_waves: 0
```

---

## 4. Program State Machine

### 4.1 ProgramState Constants

Go type: `protocol.ProgramState` (a `string` typedef)

| Constant | YAML Value | Description |
|----------|------------|-------------|
| `ProgramStatePlanning` | `PLANNING` | Planner agent running, producing manifest |
| `ProgramStateValidating` | `VALIDATING` | Orchestrator validating manifest schema |
| `ProgramStateReviewed` | `REVIEWED` | Human has approved the manifest |
| `ProgramStateScaffold` | `SCAFFOLD` | Materializing program contracts as source code |
| `ProgramStateTierExecuting` | `TIER_EXECUTING` | One or more IMPLs in current tier active |
| `ProgramStateTierVerified` | `TIER_VERIFIED` | Current tier complete, gates passed |
| `ProgramStateComplete` | `COMPLETE` | All tiers complete |
| `ProgramStateBlocked` | `BLOCKED` | Tier failed or cross-IMPL issue detected |
| `ProgramStateReplanning` | `REPLANNING` | Planner re-engaged to revise manifest after failure (E34) |
| `ProgramStateNotSuitable` | `NOT_SUITABLE` | Planner determined project not suitable (terminal) |

### 4.2 Primary Success Path

```
PLANNING
  ↓ (Planner writes manifest)
VALIDATING
  ↓ (sawtools validate-program passes)
REVIEWED
  ↓ (Human approves)
SCAFFOLD  ← skipped if no program_contracts
  ↓ (Contract scaffold files committed to HEAD)
TIER_EXECUTING  [Tier 1]
  ↓ (All Tier 1 IMPLs reach status "complete")
TIER_VERIFIED  [Tier 1]
  ↓ (Tier gates pass, contracts frozen)
TIER_EXECUTING  [Tier 2]
  ↓ ...
TIER_VERIFIED  [Tier N, final]
  ↓
COMPLETE
```

### 4.3 Failure Paths

- `PLANNING → NOT_SUITABLE`: Terminal. Planner's suitability gate determined the project is too small or too entangled for multi-IMPL orchestration. A minimal manifest is written with `state: NOT_SUITABLE` and an explanation. The user should use `/saw bootstrap` or `/saw scout` instead.
- `TIER_EXECUTING → BLOCKED`: An IMPL in the tier failed, or the tier gate failed. Recovery is possible (fix the IMPL, then resume).
- `BLOCKED → TIER_EXECUTING`: Issue resolved, execution resumes.
- `BLOCKED → REPLANNING`: Re-planning triggered (E34). Planner produces revised manifest.
- `REPLANNING → REVIEWED`: Revised manifest produced; returns to `REVIEWED` after human approval.

### 4.4 TIER_EXECUTING Inner Loop

Within `TIER_EXECUTING`, each IMPL in the tier runs its full lifecycle independently and in parallel:

```
TIER_EXECUTING
  ├── IMPL-data-model:  SCOUT_PENDING → REVIEWED → WAVE_PENDING → WAVE_EXECUTING → COMPLETE
  └── IMPL-auth:        SCOUT_PENDING → REVIEWED → WAVE_PENDING → WAVE_EXECUTING → COMPLETE
      (both run their full IMPL state machine concurrently)
```

The tier gate fires only when **all** IMPLs in the tier reach `complete`. An individual IMPL failure enters `BLOCKED` but does not cascade to other IMPLs in the same tier. The tier cannot advance until all IMPLs resolve.

### 4.5 Completion Marker

When `sawtools mark-program-complete` runs successfully, it writes to the manifest:
- `state: COMPLETE`
- `completion_date: "YYYY-MM-DD"` (inserted after `state:`)
- `SAW:PROGRAM:COMPLETE` on its own line at the end of the file

This is analogous to `<!-- SAW:COMPLETE -->` for IMPL docs (E15).

---

## 5. Program Invariants (P1–P5)

These invariants extend I1–I6 from the IMPL level to the program level. I1–I6 continue to apply within each IMPL. P1-P4 and P1+ are defined in `protocol/program-invariants.md`; P5 is defined in `protocol/invariants.md`.

### P1: IMPL Independence Within a Tier

No two IMPLs in the same tier may have a dependency relationship. If IMPL-A depends on outputs from IMPL-B, they must be in different tiers, with B in a strictly earlier tier.

**Enforcement:** `ValidateProgram` checks `P1_VIOLATION` errors: for each IMPL, if any `depends_on` entry points to another IMPL in the same tier number, validation fails.

**Rationale:** Same principle as I1 (disjoint file ownership) but at the IMPL level. Tiers are to IMPLs what waves are to agents. Intra-tier dependencies would serialize what should execute in parallel.

### P2: Program Contracts Precede Tier Execution

All cross-IMPL types/APIs that a tier's IMPLs depend on must be:
1. Defined in the PROGRAM manifest's `program_contracts` section
2. Materialized as source code committed to HEAD
3. Frozen before any Scout in the consuming tier begins

**Enforcement:** The Orchestrator verifies contract files exist and are committed before launching Scouts for the next tier. `FreezeContracts` checks both `os.Stat` (file exists) and `git status --porcelain` (file committed). Scouts receive the PROGRAM manifest via `--program` flag and must not redefine frozen contracts.

**Rationale:** Extension of I2 (interface contracts precede implementation) to the program level.

### P3: Tier Sequencing

Tier N+1 does not begin (no Scout launches) until:
1. All IMPLs in Tier N have reached `complete`
2. Tier N quality gates have passed
3. Program contracts that freeze at Tier N boundary are committed

**Enforcement:** The Orchestrator checks tier completion in `RunTierGate` before advancing. `AdvanceTierAutomatically` calls `RunTierGate` first; if it fails, `RequiresReview = true` and no advancement occurs. The `--auto` flag bypasses the human confirmation but not the gate itself.

**Rationale:** Extension of I3 (wave sequencing) to the program level.

### P4: PROGRAM Manifest is Source of Truth

The PROGRAM manifest is the single source of truth for:
- Which IMPLs exist and their ordering
- Cross-IMPL dependencies
- Program contracts and their freeze points
- Tier completion status

IMPL docs reference the PROGRAM manifest but do not duplicate its information. The Orchestrator updates the manifest after each IMPL state transition (E32).

**Rationale:** Extension of I4 (IMPL doc is source of truth) to the program level.

### P5: IMPL Branch Isolation

Within a program tier, each IMPL's wave merges target the IMPL's dedicated branch (`saw/program/{slug}/tier{N}-impl-{implSlug}`), not main. Main is only updated by `FinalizeTier` after all IMPLs in the tier complete and the tier gate passes. This prevents partial state leakage between co-tier IMPLs.

**Enforcement:** `CreateProgramWorktrees` creates the IMPL branch; `MergeTarget` is threaded through `RunWaveFull` / `FinalizeWave` / `MergeAgents`. `FinalizeTier` merges IMPL branches to main.

**Rationale:** Without branch isolation, a wave merge from one IMPL could land on main while another IMPL's waves are still running, creating implicit coupling between supposedly independent IMPLs (E28B).

---

## 6. CLI Commands — `/saw program`

These commands are defined in `implementations/claude-code/prompts/saw-skill.md`. They are invoked via the `/saw` skill in Claude Code.

### `/saw program plan "<project-description>"`

Analyze a project and produce a PROGRAM manifest. No execution occurs.

**Orchestrator flow:**
1. If the user provides a project description (not a reference to existing `REQUIREMENTS.md`), write `docs/REQUIREMENTS.md` using the bootstrap template. Ask user to review.
2. Launch Planner agent: `Agent(subagent_type: planner, run_in_background: true)`. Falls back to `subagent_type: general-purpose` with `agents/planner.md` contents if `planner` type fails.
3. Wait for Planner completion. If the Planner writes a manifest with `state: NOT_SUITABLE`, surface the explanation and recommend `/saw bootstrap` or `/saw scout` instead.
4. Validate: `sawtools validate-program "<absolute-path-to-manifest>"`. On failure, send errors back to Planner with a resume prompt (up to 3 attempts). On retry limit exhaustion, enter BLOCKED.
5. Present tier structure, program contracts, dependency graph, estimated complexity, and tier gates for human review.
6. On approval: `sawtools update-program-state "<manifest>" --state REVIEWED`

### `/saw program execute "<project-description>"`

Plan and execute with tier-gated progression (Level B). Extends the planning flow with automated execution.

**Phase 1:** Reuses steps 1–6 from `/saw program plan`.

**Phase 2: Program Scaffold** (if `program_contracts` is non-empty):
1. Launch Scaffold Agent (`subagent_type: scaffold-agent`, `run_in_background: true`) with the PROGRAM manifest path as the prompt parameter.
2. The Scaffold Agent reads `program_contracts` and creates the specified source files.
3. Verify all contract files show `Status: committed`. If any show `Status: FAILED`, stop and surface the failure.
4. Commit scaffold files to HEAD and transition manifest state to `TIER_EXECUTING`.

**Phase 3: Tier Execution Loop** (for each tier N from 1 to `tiers_total`):

- **3a — Parallel Scout Launching (E31):** For each IMPL in tier N with status `pending`, launch a Scout agent with the `--program` flag. All Scouts launch simultaneously. Validate each IMPL doc (E16) after completion. Present all IMPL docs for human review.
- **3b — IMPL Execution:** Execute each reviewed IMPL's full lifecycle (`/saw wave --auto` flow). Update IMPL status in PROGRAM manifest as each completes via `sawtools update-program-impl`.
- **3c — Tier Gate (E29):** `sawtools tier-gate "<manifest>" --tier N`. On failure, enter BLOCKED and surface to user.
- **3d — Contract Freezing (E30):** `sawtools freeze-contracts "<manifest>" --tier N`. On failure, enter BLOCKED.
- **3e — Tier Boundary:** Run `sawtools program-status`. If `--auto`: call `AdvanceTierAutomatically` to advance automatically. If not `--auto`: pause for human confirmation.

**Phase 4: Program Completion:**
1. `sawtools mark-program-complete "<manifest>"`
2. `sawtools update-context "<manifest>" --project-root "<repo-path>"`

**Error handling:** A blocked IMPL in one tier does not cascade to other IMPLs in the same tier (P1). If the tier cannot complete because one IMPL is blocked, enter BLOCKED and surface the specific failure.

### `/saw program execute --auto "<project-description>"`

Same as `/saw program execute` but with `--auto` flag active. Tier boundaries advance automatically when gates pass. The initial `PROGRAM_REVIEWED` gate is never skipped.

### `/saw program status`

Show program-level progress without modifying state.

**Orchestrator flow:**
1. `sawtools list-programs --dir "<repo-path>/docs"` — discover PROGRAM manifests. If none found, report and suggest `/saw program plan`.
2. If multiple found, ask user to specify. If exactly one, use it.
3. Display:
   - Tier structure with IMPL statuses per tier
   - Program contracts and freeze status
   - Overall progress (tiers, IMPLs, agents, waves)
   - Current `state`
4. If `BLOCKED`, read completion reports from blocked IMPLs and surface failures.

**Example output:**
```
PROGRAM: greenfield-api (Tier 2 of 3)
  Tier 1: 2/2 complete
  Tier 2: 1/2 complete (api-routes complete; frontend-shell in progress)
  Tier 3: 0/1 pending
Overall: 3/5 IMPLs complete (60%)
```

### `/saw program replan`

Re-engage the Planner to revise the PROGRAM manifest after a tier gate failure or user request.

**Orchestrator flow:**
1. Parse existing PROGRAM manifest.
2. Construct revision prompt: current manifest content, failure reason, failed tier number (if applicable), completion reports from IMPLs in failed tier.
3. Launch Planner agent with revision prompt (`subagent_type: planner`, `run_in_background: true`).
4. Validate revised manifest (`sawtools validate-program`). Send errors back to Planner on failure (up to 3 attempts).
5. Present revised manifest for human review (show what changed).
6. On approval, update state to `REVIEWED` and resume execution.

**Non-destructive guarantee:** Completed tiers and their IMPLs remain with status `complete`. Only pending and failed tiers may be revised. Frozen contracts cannot be modified.

---

## 7. sawtools Commands

All program-related `sawtools` commands are registered in the Go SDK (`cmd/sawtools/`).

### `sawtools validate-program <program-manifest>`

Validates a PROGRAM manifest against all schema rules.

**Checks performed by `ValidateProgram` in `pkg/protocol/program_validation.go`:**

| Check | Error Code | Description |
|-------|------------|-------------|
| Required fields | `MISSING_FIELD` | `title`, `program_slug`, `state` must be non-empty |
| Valid state | `INVALID_STATE` | `state` must be a valid `ProgramState` constant |
| Valid IMPL statuses | `INVALID_STATUS` | Each IMPL status must be one of: `pending`, `scouting`, `reviewed`, `executing`, `complete` |
| P1 independence | `P1_VIOLATION` | No IMPL may depend on another IMPL in the same tier |
| Tier-IMPL consistency | `TIER_MISMATCH` | All IMPL slugs in `tiers` must exist in `impls`; each IMPL must appear in exactly one tier |
| Dependency validity | `INVALID_DEPENDENCY` | All `depends_on` slugs must reference defined IMPLs |
| Tier ordering | `TIER_ORDER_VIOLATION` | If A depends on B, A's tier must be strictly greater than B's tier |
| Contract consumers | `INVALID_CONSUMER` | All `consumers[].impl` slugs must reference defined IMPLs |
| Slug formats | `INVALID_SLUG_FORMAT` | `program_slug` and IMPL slugs must be kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`) |
| Completion bounds | `COMPLETION_BOUNDS` | `tiers_complete` ≤ `tiers_total`; `impls_complete` ≤ `impls_total` |

**Exit codes:** 0 = valid, non-zero = validation errors.

**Note:** `validate-program` does NOT run full schema validation on the PROGRAM structure (it validates the Go struct, not the YAML raw parsing). Parse errors are reported separately by `ParseProgramManifest`.

### `sawtools list-programs --dir <path>`

Scans the specified directory for `PROGRAM-*.yaml` files and returns a JSON array of `ProgramDiscovery` summaries.

**Output:** JSON array of `protocol.ProgramDiscovery`:
```json
[
  {
    "path": "/abs/path/docs/PROGRAM-greenfield-api.yaml",
    "slug": "greenfield-api",
    "state": "TIER_EXECUTING",
    "title": "Greenfield API and Dashboard"
  }
]
```

**Behavior:** Files that fail to parse are silently skipped. Results are sorted by filename for deterministic output. Returns empty array (not an error) if the directory contains no matching files or does not exist.

### `sawtools tier-gate <manifest> --tier N`

Verifies all IMPLs in a tier are complete and runs the tier-level quality gates.

**Flags:**
- `<manifest>`: Path to PROGRAM manifest
- `--tier N`: Tier number (1-based)

**Logic (implemented by `protocol.RunTierGate`):**
1. Locate tier N in the manifest.
2. For each IMPL in the tier, check its `status` field. If any IMPL is not `complete`, `AllImplsDone = false` and the gate fails immediately without running commands.
3. If all IMPLs are complete, run each `tier_gates` command via `sh -c` with a 5-minute timeout. Required gates that fail set `Passed = false`.

**Output JSON** (`protocol.TierGateResult`):
```json
{
  "tier_number": 1,
  "passed": true,
  "gate_results": [
    {
      "type": "build",
      "command": "go build ./...",
      "required": true,
      "passed": true,
      "stdout": "",
      "stderr": ""
    }
  ],
  "impl_statuses": [
    {"slug": "data-model", "status": "complete"},
    {"slug": "auth", "status": "complete"}
  ],
  "all_impls_done": true
}
```

**Exit codes:** 0 = gate passed, 1 = gate failed or IMPLs incomplete.

### `sawtools freeze-contracts <manifest> --tier N`

Freezes program contracts at a tier boundary. Identifies contracts whose `freeze_at` field matches an IMPL slug in the completing tier, verifies their source files exist and are committed to HEAD, and marks them as frozen.

**Flags:**
- `<manifest>`: Path to PROGRAM manifest
- `--tier N`: Tier number completing

**Freeze matching:** Uses word-boundary regex (`\b<slug>\b`) against `freeze_at`. Example: IMPL slug `auth` matches `freeze_at: "IMPL-auth completion"`.

**File verification:** For each matching contract, checks:
1. `os.Stat(filepath.Join(repoPath, contract.Location))` — file must exist
2. `git -C repoPath status --porcelain <location>` — output must be empty (file committed, no uncommitted changes)

**Output JSON** (`protocol.FreezeContractsResult`):
```json
{
  "tier_number": 1,
  "contracts_frozen": [
    {
      "name": "UserSession",
      "location": "pkg/types/session.go",
      "freeze_at": "IMPL-auth completion",
      "file_exists": true,
      "committed": true
    }
  ],
  "contracts_skipped": ["APIResponse<T>"],
  "success": true,
  "errors": []
}
```

`success` is `true` only if all matching contracts are successfully frozen (no errors). A contract with `file_exists: false` or `committed: false` adds to `errors` and sets `success: false`.

### `sawtools program-status <manifest>`

Returns a full structured status report for a PROGRAM manifest.

**Logic (implemented by `protocol.GetProgramStatus`):**
1. Reads manifest and attempts to enrich IMPL statuses from disk (reads actual IMPL docs from `docs/IMPL/` and `docs/IMPL/complete/`). Falls back to manifest `status` field if IMPL doc is not found.
2. IMPL doc states are mapped: `COMPLETE` → `complete`, `WAVE_EXECUTING`/`WAVE_MERGING`/`WAVE_VERIFIED`/`WAVE_PENDING` → `in-progress`, `SCOUT_PENDING`/`REVIEWED`/`SCAFFOLD_PENDING` → `pending`, `BLOCKED` → `blocked`.
3. Computes current tier (lowest-numbered tier with at least one incomplete IMPL).
4. Builds contract statuses by checking if each contract's `freeze_at` IMPL is in a completed tier.

**Output JSON** (`protocol.ProgramStatusResult`):
```json
{
  "program_slug": "greenfield-api",
  "title": "Greenfield API and Dashboard",
  "state": "TIER_EXECUTING",
  "current_tier": 2,
  "tier_statuses": [
    {
      "number": 1,
      "description": "Foundation",
      "impl_statuses": [
        {"slug": "data-model", "status": "complete"},
        {"slug": "auth", "status": "complete"}
      ],
      "complete": true
    },
    {
      "number": 2,
      "description": "Core features",
      "impl_statuses": [
        {"slug": "api-routes", "status": "in-progress"}
      ],
      "complete": false
    }
  ],
  "contract_statuses": [
    {
      "name": "UserSession",
      "location": "pkg/types/session.go",
      "freeze_at": "IMPL-auth completion",
      "frozen": true,
      "frozen_at_tier": 1
    }
  ],
  "completion": {
    "tiers_complete": 1,
    "tiers_total": 2,
    "impls_complete": 2,
    "impls_total": 3,
    "total_agents": 5,
    "total_waves": 2
  }
}
```

**Note:** `buildContractStatuses` (used by `GetProgramStatus`) determines frozen status by matching the `freeze_at` string directly against IMPL slugs in the `implToTier` map. This is a simpler check than `FreezeContracts` — it only checks whether the referenced IMPL's tier is complete, not whether the file exists on disk.

### `sawtools mark-program-complete <manifest>`

Marks a PROGRAM manifest as complete and updates `CONTEXT.md`.

**Flags:**
- `<manifest>`: Path to PROGRAM manifest
- `--date "YYYY-MM-DD"`: Completion date (defaults to today)
- `--repo-dir <path>`: Repository directory (defaults to current working directory)

**Steps:**
1. Parse manifest. Exit code 2 on parse error.
2. Verify all IMPLs in all tiers have `status: "complete"`. Exit code 1 if incomplete, listing incomplete IMPLs.
3. Update manifest file: set `state: COMPLETE`, insert `completion_date: "<date>"` after state line, append `SAW:PROGRAM:COMPLETE` marker at end.
4. Update `docs/CONTEXT.md` (creates if absent). Appends entry: `- Program: <title> (<slug>) — <N> tiers, <M> IMPLs, <date>` under `## Features Completed`. Non-fatal if CONTEXT.md update fails.
5. `git add` both files and `git commit -m "chore: mark PROGRAM <slug> complete"`. Returns commit SHA. Non-fatal if commit fails.

**Output JSON** (`MarkProgramCompleteResult`):
```json
{
  "completed": true,
  "program_slug": "greenfield-api",
  "date": "2026-03-17",
  "manifest_path": "/abs/path/docs/PROGRAM-greenfield-api.yaml",
  "context_updated": true,
  "context_path": "/abs/path/docs/CONTEXT.md",
  "commit_sha": "abc1234",
  "tiers_complete": 2,
  "impls_complete": 3
}
```

### `sawtools program-replan <manifest>`

Re-engages the Planner agent to revise a PROGRAM manifest. Implemented in `cmd/sawtools/program_replan_cmd.go`.

**Flags:**
- `<manifest>`: Path to PROGRAM manifest
- `--reason <string>`: Why re-planning was triggered (required)
- `--tier <N>`: Tier number that failed (0 if user-initiated, default 0)
- `--model <string>`: Model override for the Planner agent (optional)

**Current implementation status:** The CLI command parses arguments and calls `engine.ReplanProgram(opts)`, which constructs the revision prompt but returns `"not yet implemented"` for the Planner agent launch step. The stub reads the manifest and builds the prompt via `buildRevisionPrompt` but the actual agent launch is deferred to Wave 3 integration. See note in Section 12.

**Exit codes:** 0 = success, 1 = re-planning/validation failed, 2 = parse error.

### `sawtools run-scout "<impl-title>" --program "<manifest>"`

Launches a Scout agent for a specific IMPL with access to the PROGRAM manifest's frozen contracts. Referenced in E31 and `saw-skill.md`. Implementation details in the Go SDK.

---

## 8. API Reference

The web app exposes 6 HTTP endpoints for program management, registered in `pkg/api/program_handler.go`.

### GET /api/programs

List all PROGRAM manifests across all configured repositories.

**Response:** `application/json`
```json
{
  "programs": [
    {
      "path": "/abs/path/docs/PROGRAM-greenfield-api.yaml",
      "slug": "greenfield-api",
      "state": "TIER_EXECUTING",
      "title": "Greenfield API and Dashboard"
    }
  ]
}
```

**Behavior:** Scans each configured repo's `docs/` directory via `protocol.ListPrograms`. Files that fail to parse are silently skipped. Returns `{"programs": []}` if none found. Non-fatal per-repo errors are logged and skipped.

### GET /api/program/{slug}

Get comprehensive status for a single PROGRAM manifest.

**Path parameter:** `slug` — the `program_slug` value from the manifest.

**Response:** `application/json` (`ProgramStatusResponse`)
```json
{
  "program_slug": "greenfield-api",
  "title": "Greenfield API and Dashboard",
  "state": "TIER_EXECUTING",
  "current_tier": 2,
  "tier_statuses": [...],
  "contract_statuses": [...],
  "completion": {...},
  "is_executing": false
}
```

`is_executing` is `true` if a tier execution goroutine is currently running for this program (tracked via `activeProgramRuns sync.Map`).

**Errors:** 404 if slug not found in any configured repo. 500 if manifest parsing or status computation fails.

### GET /api/program/{slug}/tier/{n}

Get status for a single tier.

**Path parameters:**
- `slug` — program slug
- `n` — tier number (1-based integer)

**Response:** `application/json` (`protocol.TierStatusDetail`)
```json
{
  "number": 1,
  "description": "Foundation",
  "impl_statuses": [
    {"slug": "data-model", "status": "complete"},
    {"slug": "auth", "status": "complete"}
  ],
  "complete": true
}
```

**Errors:** 400 if `n` is not a valid positive integer. 404 if slug not found or tier N not in manifest.

### POST /api/program/{slug}/tier/{n}/execute

Launch tier execution in a background goroutine.

**Path parameters:** `slug`, `n` (same as above).

**Request body** (optional, `application/json`):
```json
{"auto": false}
```

**Response:** `202 Accepted` (no body) on success. `409 Conflict` if a tier execution is already running for this program.

**Behavior:** Uses `activeProgramRuns.LoadOrStore` to prevent concurrent executions. Launches `runProgramTier` in a background goroutine. Broadcasts `program_list_updated` to the global broker on start and completion.

**Current implementation status:** The background goroutine in `handleExecuteTier` currently emits a `program_tier_started` followed immediately by `program_tier_complete` as a stub. The actual call to `runProgramTier` is commented out with `// TODO: Call runProgramTier(...)`. The `runProgramTier` function in `program_runner.go` is fully implemented and wires up IMPL execution, tier gates, and contract freezing — it simply is not yet called from `handleExecuteTier`.

### GET /api/program/{slug}/contracts

Get all program contracts with their freeze status.

**Response:** `application/json` (array of `protocol.ContractStatus`)
```json
[
  {
    "name": "UserSession",
    "location": "pkg/types/session.go",
    "freeze_at": "IMPL-auth completion",
    "frozen": true,
    "frozen_at_tier": 1
  }
]
```

**Note:** Freeze status is computed by `GetProgramStatus` which checks whether the contract's `freeze_at` IMPL is in a completed tier. This is a derived status, not a separate freeze state stored in the manifest.

### POST /api/program/{slug}/replan

Re-engage the Planner to revise the PROGRAM manifest.

**Response:** `501 Not Implemented` with body:
```json
{"message": "Planner re-engagement not yet implemented (Phase 4)"}
```

This endpoint is a placeholder. The `/saw program replan` CLI command is the current path for re-planning.

### GET /api/program/events

Persistent SSE stream for program lifecycle events. Filters the global event stream to `program_*` events only.

**Connection:** `text/event-stream`. Sends `event: connected\ndata: {}\n\n` immediately on connect. Keepalive `: ping\n\n` every 30 seconds.

**Event format:**
```
event: program_tier_started
data: {"program_slug":"greenfield-api","tier":1}

event: program_impl_complete
data: {"program_slug":"greenfield-api","impl_slug":"auth"}
```

---

## 9. SSE Events

Seven program lifecycle event types are defined as constants in `pkg/api/program_events.go`.

All events are broadcast through the `globalBroker` and are accessible on both `/api/events` (all events) and `/api/program/events` (program-only filter). The frontend subscribes via `EventSource('/api/program/events')`.

### program_tier_started

Fired when tier execution begins.

**Payload:**
```json
{"program_slug": "greenfield-api", "tier": 1}
```

### program_tier_complete

Fired when all IMPLs in a tier complete and tier gates pass.

**Payload:**
```json
{"program_slug": "greenfield-api", "tier": 1}
```

### program_impl_started

Fired when an IMPL within a tier begins execution.

**Payload:**
```json
{"program_slug": "greenfield-api", "impl_slug": "auth"}
```

### program_impl_complete

Fired when a single IMPL completes all its waves.

**Payload:**
```json
{"program_slug": "greenfield-api", "impl_slug": "auth"}
```

### program_contract_frozen

Fired for each contract successfully frozen at a tier boundary.

**Payload:**
```json
{"program_slug": "greenfield-api", "contract_name": "UserSession", "tier": 1}
```

### program_complete

Fired when all tiers complete. Not yet emitted by the current implementation (the program runner emits tier-level events but program-level completion depends on the CLI `mark-program-complete` command).

**Payload:**
```json
{"program_slug": "greenfield-api"}
```

### program_blocked

Fired when an IMPL fails, a tier gate fails, or contract freezing fails.

**Payload:**
```json
{
  "program_slug": "greenfield-api",
  "impl_slug": "auth",           // optional — only if an IMPL caused the block
  "tier": 1,                     // optional — present for tier-level failures
  "reason": "IMPL doc not found: ...",
  "gate_results": {...},         // optional — present on tier gate failures
  "errors": [...]                // optional — present on freeze failures
}
```

### Frontend SSE Usage Pattern

From `programApi.ts`:
```typescript
const es = new EventSource('/api/program/events')
es.addEventListener('program_tier_complete', (e: MessageEvent) => {
  const data = JSON.parse(e.data)
  console.log('Tier complete:', data.program_slug, data.tier)
})
```

`ProgramBoard.tsx` subscribes to all program events on mount, refetches program status on any event matching the current `programSlug`, and closes the `EventSource` on unmount. `ProgramContractsPanel.tsx` subscribes only to `program_contract_frozen` events.

---

## 10. Web UI Guide

### Accessing the Program Board

The web app includes a Programs button in the navigation. Clicking it opens the Program selection UI, which calls `GET /api/programs` to list all discovered PROGRAM manifests across configured repos.

Selecting a program opens the `ProgramBoard` component, which calls `GET /api/program/{slug}`.

### ProgramBoard Component

`web/src/components/ProgramBoard.tsx`

**Displays:**
- Program title and overall progress summary (e.g., `Tier 2 active • 3/5 IMPLs complete`)
- Overall progress bar using `ProgressBar` component (tiers complete / tiers total)
- Program complete banner (shown when `state === 'complete'`) with total IMPL count
- Per-tier `TierSection` cards

**TierSection shows:**
- Tier number and optional description
- Completion status badge (`Complete` in green)
- Blocked indicator (shown when tier.number > current_tier and prior tier not complete)
- "Execute Tier" button: visible only for the active tier when it's not complete; calls `POST /api/program/{slug}/tier/{n}/execute`
- Grid of `ImplCard` entries for each IMPL in the tier

**ImplCard shows:**
- IMPL slug and status badge (Complete/Running/Failed/Blocked/Pending)
- Color-coded border (green=complete, blue=running, red=failed, gray=pending/blocked)
- Animated blue progress bar when status is `running`
- Glow effect on the running card border
- Clickable — calls `onSelectImpl(impl.slug)` if provided (allows parent to navigate to the WaveBoard for that IMPL)

**Real-time updates:** `ProgramBoard` opens an `EventSource('/api/program/events')` on mount and refetches program status on any event for the current program slug. The SSE connection status is shown in the header — `Reconnecting...` in amber if disconnected.

**Executing banner:** A fixed bottom-right banner with a pulsing blue indicator appears when `status.is_executing` is true.

### ProgramContractsPanel Component

`web/src/components/ProgramContractsPanel.tsx`

Displays a table of cross-IMPL contracts with their freeze status. Fetches from `GET /api/program/{slug}/contracts`.

**Table columns:**
- **Name** — contract identifier (e.g., `UserSession`)
- **Location** — file path where the contract is materialized (monospace)
- **Freeze At** — `freeze_at` string from the manifest; includes `(Tier N)` annotation when `frozen_at_tier` is present
- **Status** — lock icon badge: `Frozen` (green) or `Pending` (yellow)

**Real-time updates:** Subscribes to `program_contract_frozen` events and refetches on any matching event.

Empty state: Shows `"No cross-IMPL contracts defined"` when the contracts array is empty.

### ProgramDependencyGraph Component

`web/src/components/ProgramDependencyGraph.tsx`

Renders an SVG dependency graph of IMPLs organized by tier. Fetches from `GET /api/program/{slug}` if `status` prop is not provided.

**Layout:**
- Tiers rendered as columns left-to-right (Tier 1 at left, highest tier at right)
- Column spacing: `TIER_GAP = 180` pixels between tier columns
- Node size: `NODE_W = 80`, `NODE_H = 56` pixels
- Node spacing: `IMPL_GAP = 80` pixels vertically within a tier
- Color-coded tier column backgrounds (blue, violet, pink, amber, green, teal, indigo cycling)
- Tier labels at top of each column

**Nodes:**
- Abbreviated IMPL slug as label: multi-word slugs (`user-auth`) become initials (`UA`); single-word slugs use first 3 characters uppercased
- Status-colored border and fill: green (complete), blue (executing), red (blocked), gray (pending)
- Status badge: checkmark circle for complete, pulsing blue dot for executing
- Hover tooltip: shows full slug, tier, status, and dependency count

**Edges:**
- Bezier curves connecting dependent IMPLs across tiers
- **Dependency simplification:** The graph infers dependencies from tier structure — all IMPLs in a prior tier are treated as potential dependencies. This is an approximation; the actual `depends_on` field from the IMPL manifest is not currently passed through the API. Transitive reduction is applied: if A can reach C through B, the A→C edge is omitted.
- Arrowheads on the target end

**Known limitation:** The dependency edges shown are a simplified approximation based on tier groupings, not the precise `depends_on` fields from each IMPL's manifest. An IMPL in Tier 2 is shown as depending on all IMPLs in Tier 1 even if its actual `depends_on` is only a subset.

---

## 11. Execution Rules E28–E34

Rules E28–E34 govern orchestrator behavior for program-level execution. They are defined verbatim in `protocol/execution-rules.md` and summarized here.

### E28: Tier Execution Loop

**Trigger:** PROGRAM manifest state transitions to `TIER_EXECUTING`

The Orchestrator reads the current tier from the PROGRAM manifest and launches Scout agents for all IMPLs in the tier with status `pending` in parallel (E1 applies — async). Each Scout receives the `--program` flag pointing to the PROGRAM manifest to consume frozen program contracts as immutable inputs.

After all IMPLs are scouted and reviewed, the Orchestrator executes each IMPL's waves using the standard `/saw wave --auto` flow. When all IMPLs reach `complete`, transition to tier gate (E29).

**Enforces:** P1 (IMPLs within the same tier execute without coordination), P3 (tier N+1 does not begin until E29 passes).

### E29: Tier Gate Verification

**Trigger:** All IMPLs in a tier reach `complete`

Run `sawtools tier-gate <manifest> --tier N`. This verifies all IMPLs are complete and runs the `tier_gates` quality gate commands. If all required gates pass, mark the tier verified and advance to contract freezing (E30). If any required gate fails, enter `BLOCKED` and surface to the user.

**Enforces:** P3 (tier N+1 does not begin until gate passes). Gate failures always surface to the human regardless of `--auto` mode.

### E30: Program Contract Freezing

**Trigger:** Tier gate passes (E29)

Run `sawtools freeze-contracts <manifest> --tier N`. Identifies contracts whose `freeze_at` matches an IMPL in the completing tier, verifies their source files exist and are committed to HEAD, and marks them as frozen. Frozen contracts are immutable — any IMPL in a later tier attempting to redefine a frozen contract violates P2.

**Human gate:** After freezing, pause for human review before advancing (unless `--auto` is active).

**Enforces:** P2 (contracts are frozen before next tier's Scouts launch).

### E31: Parallel Scout Launching

**Trigger:** Orchestrator is about to scout all IMPLs in a tier

Launch one Scout agent per IMPL in the tier, all in parallel. Each Scout receives:
- (a) The feature description from the PROGRAM manifest's IMPL entry
- (b) `--program` flag with path to PROGRAM manifest
- (c) Standard Scout inputs (codebase access, `CONTEXT.md`)

Scout agents are independent — they do not coordinate with each other. After all Scouts complete, validate each IMPL doc (E16) independently, then present all for human review.

The `--program` flag is passed via `RunScoutOpts.ProgramManifestPath` in the engine. Scouts must not redefine frozen contracts (P2 enforcement via human review during IMPL review).

### E32: Cross-IMPL Progress Tracking

**Trigger:** Any IMPL within a PROGRAM changes state

The Orchestrator updates the PROGRAM manifest's IMPL status field and completion counters. Run `sawtools program-status <manifest>` to get a structured report. Display tier-level progress:

```
PROGRAM: my-program (Tier 2 of 3)
  Tier 1: 3/3 complete
  Tier 2: 2/4 complete (IMPL-feature-a, IMPL-feature-b complete; ...)
  Tier 3: 0/2 pending
Overall: 5/9 IMPLs complete (56%)
```

**Enforces:** P4 (PROGRAM manifest always up to date).

### E33: Automatic Tier Advancement (--auto mode)

**Trigger:** All IMPLs in a tier reach `complete` and tier gate passes (E29), with `--auto` active

Advancement sequence:
1. `sawtools freeze-contracts` (E30)
2. Update PROGRAM manifest state to `TIER_EXECUTING` for next tier
3. Launch Scout agents for all IMPLs in the next tier in parallel (E31)

Without `--auto`: pause for human review after contract freezing.

**Implemented by** `engine.AdvanceTierAutomatically(manifest, completedTier, repoPath, autoMode)`:
1. Calls `protocol.RunTierGate`. If gate fails: `RequiresReview = true`, `AdvancedToNext = false`.
2. If gate passes but `autoMode = false`: `RequiresReview = true` (human gate).
3. If gate passes and `autoMode = true`: calls `protocol.FreezeContracts`. If freeze fails: `RequiresReview = true`.
4. If freeze succeeds: checks `isFinalTier` (highest-numbered tier in manifest). If final: `ProgramComplete = true`. Otherwise: `AdvancedToNext = true`, `NextTier = completedTier + 1`.

**Returns** `engine.TierAdvanceResult`:
```go
type TierAdvanceResult struct {
    TierNumber      int
    GateResult      *protocol.TierGateResult
    FreezeResult    *protocol.FreezeContractsResult
    AdvancedToNext  bool
    RequiresReview  bool
    NextTier        int
    ProgramComplete bool
    Errors          []string
}
```

**Critical:** The `PROGRAM_REVIEWED` state (initial plan approval) is NEVER skipped even in `--auto` mode. Gate failures always surface to the human.

### E34: Planner Re-Engagement on Failure

**Trigger:** Tier gate fails (E29) OR user explicitly requests re-plan

Launch a Planner agent with a revision prompt containing:
1. The current PROGRAM manifest (full content)
2. Failure context: tier that failed, which IMPL failed, which gate command failed and its output
3. Completion reports from all IMPLs in the failed tier
4. Instruction to revise program contracts or tier structure

The Planner produces a revised manifest. The Orchestrator validates it (E16) and presents it for human review (`PROGRAM_REVIEWED`). Execution does NOT resume automatically.

**Non-destructive:** Completed tiers are not re-run. Frozen contracts cannot be revised.

**Implemented by** `engine.ReplanProgram(opts ReplanProgramOpts)`. As of the current implementation, this function builds the revision prompt via `buildRevisionPrompt` but returns `"not yet implemented"` for the Planner agent launch step (the TODO references Wave 3 wiring). `sawtools program-replan` exposes this function as a CLI command but will return exit code 1 with the "not yet implemented" error until the Planner launch is wired.

**Analog:** E34 is the program-scope analog of E8 (same-wave interface failure). E8 handles intra-wave contract failures by re-engaging Scout. E34 handles inter-tier failures by re-engaging Planner.

---

## 12. Re-Planning

### When Re-Planning Triggers

1. **Tier gate failure (E29):** A required quality gate command fails after all IMPLs in a tier complete.
2. **Cross-IMPL interface mismatch:** Tier gate finds incompatible outputs between IMPLs.
3. **User request:** `/saw program replan` invoked explicitly.

### What Re-Planning Does

The Planner agent receives the current PROGRAM manifest plus failure context and produces a **revised** manifest. The Planner may:
- Revise program contracts (add, remove, or modify shared type definitions)
- Revise tier structure (reorder IMPLs, add or remove tiers)
- Revise IMPL decomposition (split or merge features)

The Planner **may not** revise:
- Completed tiers (already executed and merged)
- Frozen program contracts (used by completed IMPLs)

The revised manifest goes through `PROGRAM_REVIEWED` before any execution resumes. The human must approve the revised plan.

### AdvanceTierAutomatically vs Manual Flow

**Automated path (`--auto`):** `AdvanceTierAutomatically` is called after each tier completes. It runs the gate, freezes contracts, and advances automatically if everything passes. If the gate fails, it sets `RequiresReview = true` and the Orchestrator enters BLOCKED regardless of `--auto`.

**Manual path (no `--auto`):** The Orchestrator runs `sawtools tier-gate` and `sawtools freeze-contracts` as separate steps and pauses for human confirmation at each tier boundary before launching the next tier's Scouts.

### Current Implementation Status of ReplanProgram

`engine.ReplanProgram` in `pkg/engine/program_auto.go` is partially implemented:

- **Implemented:** Reading the manifest, constructing the revision prompt via `buildRevisionPrompt` (includes reason, failed tier, and current manifest content with instructions not to modify frozen contracts)
- **Not implemented:** Launching the Planner agent (returns `"not yet implemented"`)

Tests for re-planning should mock Planner completion by writing a revised manifest file directly. The CLI command `sawtools program-replan` calls this function and will return exit code 1 until the agent launch is wired.

---

## 13. Cross-IMPL Contracts

### What Program Contracts Are

Program contracts are cross-IMPL interface contracts: types, APIs, or other shared definitions that multiple IMPLs must agree on. They are distinct from IMPL-level interface contracts (which span agents within a single feature).

| Property | IMPL Contract | Program Contract |
|----------|--------------|-----------------|
| Scope | Within a feature (intra-IMPL) | Across features (inter-IMPL) |
| Defined by | Scout agent | Planner agent |
| Consumed by | Wave agents in same IMPL | Scout agents across multiple IMPLs |
| Frozen at | Worktree creation | Tier completion |
| Materialized by | Scaffold Agent | Program Scaffold step |

### How They Differ from IMPL Contracts

IMPL contracts are defined by the Scout in the IMPL doc's `## Interface Contracts` section and are visible only to agents within that IMPL. Program contracts are defined by the Planner in the PROGRAM manifest and are visible to Scout agents across all IMPLs in later tiers.

Program contracts extend I2 (interface contracts precede implementation) from the feature level to the project level. A Scout analyzing a Tier 2 feature needs to know the exact types that Tier 1 will produce. Without frozen program contracts, separately-scouted IMPLs may define incompatible interfaces.

### Freeze Semantics

A program contract is frozen when the tier specified in its `freeze_at` field completes and `sawtools freeze-contracts` runs successfully. Freezing requires:
1. The source file at `contract.Location` exists in the repository
2. The file is committed to HEAD (no uncommitted changes)

Once frozen, a contract is immutable. No IMPL in a later tier may redefine it. The human reviewer enforces this during IMPL review — if a Scout attempts to redefine a frozen contract, the reviewer rejects the IMPL doc before any waves execute.

### Materialization

Program contracts are not automatically created — they must be materialized as source code before any IMPL in the consuming tier begins scouting. This is done by the Scaffold Agent in the PROGRAM_SCAFFOLD phase, or manually by the user.

In the `/saw program execute` flow, after human approval of the PROGRAM manifest, a Scaffold Agent is launched with the PROGRAM manifest path. It reads `program_contracts` and creates the source files at the specified `location` paths. The Scaffold Agent commits these files before any tier execution begins.

---

## 14. End-to-End Example

A walkthrough of a 2-tier, 3-IMPL project from `/saw program plan` through `COMPLETE`.

### Project: Simple REST API

**IMPLs:**
- `data-model` (Tier 1) — storage types and DB layer
- `auth` (Tier 1) — authentication middleware
- `api-routes` (Tier 2) — HTTP handlers depending on both Tier 1 IMPLs

**Program contract:** `UserSession` type, materialized at `pkg/types/session.go`, frozen when `auth` completes.

### Step 1: Write Requirements

The Orchestrator writes `docs/REQUIREMENTS.md` with project description. User confirms.

### Step 2: /saw program plan "Simple REST API"

The Orchestrator launches the Planner agent (`subagent_type: planner`). The Planner:
1. Reads `docs/REQUIREMENTS.md`
2. Runs suitability gate — 3 features, 2 tiers, 1 shared type — returns `PROGRAM_SUITABLE`
3. Writes `docs/PROGRAM-simple-rest-api.yaml` with state `PLANNING`

Manifest state after Planner completes:
```yaml
state: PLANNING
program_slug: simple-rest-api
impls:
  - slug: data-model
    tier: 1
    status: pending
  - slug: auth
    tier: 1
    status: pending
  - slug: api-routes
    tier: 2
    depends_on: [data-model, auth]
    status: pending
```

### Step 3: Validate and Review

The Orchestrator runs `sawtools validate-program docs/PROGRAM-simple-rest-api.yaml`. No errors. Presents tier structure and contracts to user. User approves.

Orchestrator updates state to `REVIEWED`.

### Step 4: Scaffold Program Contracts

The Orchestrator launches a Scaffold Agent with the PROGRAM manifest path. Scaffold Agent creates `pkg/types/session.go` with the `UserSession` type definition and commits it. Manifest state transitions to `TIER_EXECUTING`.

### Step 5: Tier 1 — Parallel Scout Launching (E31)

The Orchestrator launches two Scout agents simultaneously:
- Scout for `data-model` with `--program docs/PROGRAM-simple-rest-api.yaml`
- Scout for `auth` with `--program docs/PROGRAM-simple-rest-api.yaml`

Both Scouts read the frozen `UserSession` contract from the PROGRAM manifest and must not redefine it in their IMPL contracts.

Scouts produce:
- `docs/IMPL/IMPL-data-model.yaml`
- `docs/IMPL/IMPL-auth.yaml`

Orchestrator validates both (E16), presents for human review. User approves both.

### Step 6: Tier 1 — IMPL Execution

The Orchestrator executes both IMPLs in parallel using the standard `/saw wave --auto` flow:
- `data-model`: Wave 1 (2 agents) → merge → COMPLETE
- `auth`: Wave 1 (2 agents) → merge → COMPLETE

As each IMPL completes, the Orchestrator updates its status in the PROGRAM manifest:
```yaml
impls:
  - slug: data-model
    status: complete
  - slug: auth
    status: complete
```

### Step 7: Tier 1 Gate (E29)

Orchestrator runs `sawtools tier-gate docs/PROGRAM-simple-rest-api.yaml --tier 1`.

`RunTierGate` checks both IMPLs have status `complete` (`AllImplsDone = true`). Runs `go build ./...` (passes) and `go test ./...` (passes). Returns `TierGateResult{Passed: true}`.

### Step 8: Contract Freezing (E30)

Orchestrator runs `sawtools freeze-contracts docs/PROGRAM-simple-rest-api.yaml --tier 1`.

`FreezeContracts` finds the `UserSession` contract with `freeze_at: "IMPL-auth completion"`. Word-boundary match: slug `auth` matches in `"IMPL-auth completion"`. Checks `pkg/types/session.go` exists and is committed. Both pass. Returns `FreezeContractsResult{Success: true}`.

SSE event emitted: `program_contract_frozen {program_slug: "simple-rest-api", contract_name: "UserSession", tier: 1}`.

### Step 9: Tier Boundary (Human Gate)

The Orchestrator runs `sawtools program-status` and presents:
```
Tier 1: 2/2 complete
  UserSession contract: FROZEN (pkg/types/session.go)
Tier 2: 0/1 pending
```

User reviews and confirms to advance to Tier 2.

### Step 10: Tier 2 — Scout Launching

Orchestrator launches Scout for `api-routes` with `--program docs/PROGRAM-simple-rest-api.yaml`. The Scout sees the frozen `UserSession` type and must use it (not redefine it). Scout produces `docs/IMPL/IMPL-api-routes.yaml`. User reviews and approves.

### Step 11: Tier 2 — IMPL Execution

`api-routes` executes: Wave 1 (2 agents) → Wave 2 (2 agents) → merge → COMPLETE.

### Step 12: Tier 2 Gate

`sawtools tier-gate --tier 2` runs. `api-routes` is complete. Build and tests pass. Gate passes.

`sawtools freeze-contracts --tier 2` runs. No contracts with `freeze_at` matching Tier 2 IMPLs. `ContractsSkipped: ["APIResponse<T>"]` (if it existed). `Success: true`.

SSE: `program_tier_complete {program_slug: "simple-rest-api", tier: 2}`.

### Step 13: Program Complete

The Orchestrator runs:
```bash
sawtools mark-program-complete docs/PROGRAM-simple-rest-api.yaml
```

Verifies all 3 IMPLs have status `complete`. Updates manifest to `state: COMPLETE` with `completion_date`. Appends `SAW:PROGRAM:COMPLETE` marker. Updates `docs/CONTEXT.md`. Commits both files with message `chore: mark PROGRAM simple-rest-api complete`.

SSE: `program_complete {program_slug: "simple-rest-api"}`.

**Final manifest state:**
```yaml
state: COMPLETE
completion_date: "2026-03-18"
completion:
  tiers_complete: 2
  tiers_total: 2
  impls_complete: 3
  impls_total: 3
  total_agents: 8
  total_waves: 4

SAW:PROGRAM:COMPLETE
```
