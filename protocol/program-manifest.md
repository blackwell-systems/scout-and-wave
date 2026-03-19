# PROGRAM Manifest Schema Specification

**Version:** 0.2.0

This document defines the canonical schema for the PROGRAM manifest YAML format. The PROGRAM manifest is the protocol-level artifact that coordinates multiple IMPL docs into tiered execution for large-scale projects.

---

## 1. Overview

Scout-and-Wave operates at three levels:

```
Program (this document)   — coordinates multiple IMPLs
  └── IMPL (existing)     — coordinates multiple agents within a feature
        └── Agent         — implements files within a wave
```

The PROGRAM manifest extends SAW's parallel execution capabilities from the **feature level** (one IMPL coordinating agents) to the **project level** (one PROGRAM coordinating IMPLs).

**Key Concepts:**

- **PROGRAM manifest:** YAML document defining project-level decomposition
- **IMPL decomposition:** Features grouped into tiers based on dependencies
- **Tiers:** Analogous to waves; same-tier IMPLs execute in parallel
- **Program contracts:** Cross-IMPL interface contracts (types/APIs spanning features)
- **Planner agent:** Produces PROGRAM manifests (see `participants.md`)

---

## 2. File Location Convention

PROGRAM manifests are stored in the project's `docs/` directory with the naming convention:

```
docs/PROGRAM-<name>.yaml
```

Where `<name>` is a kebab-case slug identifying the project. Examples:
- `docs/PROGRAM-greenfield-api.yaml`
- `docs/PROGRAM-refactor-auth-layer.yaml`
- `docs/PROGRAM-dashboard-v2.yaml`

**Rationale:** This convention:
- Co-locates PROGRAM manifests with IMPL docs (also in `docs/`)
- Makes PROGRAM files discoverable via filesystem glob
- Distinguishes PROGRAM manifests from IMPL docs by filename prefix

---

## 3. Top-Level Fields

The PROGRAM manifest root contains these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Human-readable project description |
| `program_slug` | string | Yes | Kebab-case identifier matching filename |
| `state` | ProgramState | Yes | Current program execution state (see Section 9) |
| `created` | string | No | ISO 8601 date (YYYY-MM-DD) when program was created |
| `updated` | string | No | ISO 8601 date (YYYY-MM-DD) of last manifest update |
| `requirements` | string | No | Path to requirements document (typically `docs/REQUIREMENTS.md`) |
| `program_contracts` | array | No | Cross-IMPL interface contracts (see Section 4) |
| `impls` | array | Yes | IMPL entries with dependencies (see Section 5) |
| `tiers` | array | Yes | Tier groupings (see Section 6) |
| `tier_gates` | array | No | Quality gates run after each tier (see Section 7) |
| `completion` | object | Yes | Progress tracking (see Section 8) |
| `pre_mortem` | array | No | Risk analysis (see Section 9) |

**Minimal valid manifest:**

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

---

## 4. Program Contracts Section

Program contracts define types, APIs, and interfaces that **span multiple IMPLs**. They are analogous to interface contracts within an IMPL (which span agents), but at project scope (spanning features).

### 4.1 ProgramContract Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Contract identifier (e.g., `UserSession`, `APIResponse<T>`) |
| `description` | string | No | Purpose and scope of the contract |
| `definition` | string | Yes | Type definition or API signature |
| `consumers` | array | No | IMPLs that use this contract (see 4.2) |
| `location` | string | Yes | File path where contract will be materialized |
| `freeze_at` | string | No | When contract becomes immutable (e.g., "Tier 1 completion") |

### 4.2 ProgramContractConsumer Schema

Each consumer entry identifies an IMPL and how it uses the contract:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `impl` | string | Yes | IMPL slug that consumes this contract |
| `usage` | string | Yes | How the IMPL uses the contract |

### 4.3 Example

```yaml
program_contracts:
  - name: "UserSession"
    description: |
      Core session type shared by auth, dashboard, and API layers.
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
    freeze_at: "Tier 1 completion"
```

### 4.4 Relationship to IMPL Contracts

| Property | IMPL Contract | Program Contract |
|----------|--------------|-----------------|
| **Scope** | Within a feature (intra-IMPL) | Across features (inter-IMPL) |
| **Defined by** | Scout agent | Planner agent |
| **Consumed by** | Wave agents in same IMPL | Scout agents across multiple IMPLs |
| **Frozen at** | Worktree creation | Tier completion |
| **Materialized by** | Scaffold Agent | Program Scaffold step |

**Critical insight:** Program contracts are materialized as code **before any IMPL in the consuming tier begins scouting**. This extends I2 (interface contracts precede implementation) from the IMPL level to the program level.

---

## 5. Impls Section

The `impls` section decomposes the project into features, each represented by an IMPL doc (to be produced by Scout agents).

### 5.1 ProgramIMPL Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `slug` | string | Yes | Kebab-case IMPL identifier (matches future IMPL doc filename) |
| `title` | string | Yes | Human-readable feature description |
| `tier` | integer | Yes | Tier number (determines execution order) |
| `depends_on` | array | No | List of IMPL slugs this feature depends on |
| `estimated_agents` | integer | No | Expected agent count (populated by Scout after analysis) |
| `estimated_waves` | integer | No | Expected wave count (populated by Scout after analysis) |
| `key_outputs` | array | No | Expected file/directory outputs |
| `status` | string | Yes | Current IMPL status (see Section 5.2) |

### 5.2 IMPL Status Values

| Status | Description |
|--------|-------------|
| `pending` | IMPL not yet scouted |
| `scouting` | Scout agent analyzing feature |
| `reviewed` | IMPL doc produced, awaiting approval |
| `executing` | IMPL waves in progress |
| `complete` | All IMPL waves verified and merged |

### 5.3 Example

```yaml
impls:
  - slug: "data-model"
    title: "Core data model and storage layer"
    tier: 1
    depends_on: []
    estimated_agents: 3
    estimated_waves: 1
    key_outputs:
      - "pkg/models/*.go"
      - "pkg/storage/*.go"
    status: pending

  - slug: "auth"
    title: "Authentication and session management"
    tier: 1
    depends_on: []
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "pkg/auth/*.go"
      - "pkg/middleware/auth.go"
    status: pending

  - slug: "api-routes"
    title: "REST API route handlers"
    tier: 2
    depends_on: ["data-model", "auth"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs:
      - "pkg/api/*.go"
    status: pending
```

**Dependency constraints:** IMPLs in `depends_on` must be in earlier tiers. An IMPL may not depend on another IMPL in the same tier (violates P1 invariant, see `protocol/program-invariants.md`).

---

## 6. Tiers Section

Tiers group IMPLs that can execute in parallel. All IMPLs within the same tier are independent (no cross-dependencies).

### 6.1 ProgramTier Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `number` | integer | Yes | Tier number (1-based, sequential) |
| `impls` | array | Yes | List of IMPL slugs in this tier |
| `description` | string | No | Purpose/rationale for this tier grouping |

### 6.2 Example

```yaml
tiers:
  - number: 1
    impls: ["data-model", "auth"]
    description: "Foundation — no dependencies, can execute fully in parallel"
  
  - number: 2
    impls: ["api-routes", "frontend-shell"]
    description: "Core features — depend on Tier 1 outputs"
  
  - number: 3
    impls: ["dashboard"]
    description: "Composite features — depend on Tier 2 outputs"
  
  - number: 4
    impls: ["integration-tests"]
    description: "Verification — depend on all prior tiers"
```

**Validation rules:**
- Tier numbers must be sequential starting from 1
- Each IMPL must appear in exactly one tier
- All IMPLs referenced in `tiers` must exist in `impls` section
- No IMPL may have `depends_on` referencing another IMPL in the same tier

---

## 7. Tier Gates Section

Tier gates are program-level quality gates run after all IMPLs in a tier complete. They verify cross-IMPL integration before proceeding to the next tier.

### 7.1 Schema

Tier gates reuse the `QualityGate` schema from IMPL manifests (see `protocol/message-formats.md`):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Gate type (e.g., `build`, `test`, `lint`) |
| `command` | string | Yes | Shell command to execute |
| `required` | boolean | Yes | If true, gate failure blocks tier completion |
| `description` | string | No | Human-readable gate purpose |

### 7.2 Example

```yaml
tier_gates:
  - type: build
    command: "go build ./... && cd web && npm run build"
    required: true
    description: "Full project build across all languages"
  
  - type: test
    command: "go test ./... && cd web && npm test"
    required: true
    description: "All unit tests must pass"
  
  - type: lint
    command: "go vet ./... && cd web && npm run lint"
    required: false
    description: "Style checks (warnings, not blockers)"
```

**Execution timing:** Tier gates run after **all IMPLs in the current tier reach COMPLETE** and before any IMPL in the next tier begins scouting.

---

## 8. Completion Section

The `completion` section tracks program-level progress.

### 8.1 ProgramCompletion Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tiers_complete` | integer | Yes | Number of tiers with all IMPLs complete |
| `tiers_total` | integer | Yes | Total number of tiers in the program |
| `impls_complete` | integer | Yes | Number of IMPLs in COMPLETE status |
| `impls_total` | integer | Yes | Total number of IMPLs in the program |
| `total_agents` | integer | Yes | Sum of agents across all IMPLs (populated after scouting) |
| `total_waves` | integer | Yes | Sum of waves across all IMPLs (populated after scouting) |

### 8.2 Example

```yaml
completion:
  tiers_complete: 1
  tiers_total: 4
  impls_complete: 2
  impls_total: 6
  total_agents: 18
  total_waves: 9
```

**Update frequency:** The orchestrator updates `completion` after each IMPL state transition and after each tier completes.

---

## 9. State Enum Values

The `state` field tracks the program's current execution phase.

### 9.1 ProgramState Values

| State | Description |
|-------|-------------|
| `PLANNING` | Planner agent analyzing, producing PROGRAM manifest |
| `VALIDATING` | Orchestrator validating PROGRAM manifest schema |
| `REVIEWED` | Human reviewing and approving PROGRAM manifest |
| `SCAFFOLD` | Materializing program-level contracts as code |
| `TIER_EXECUTING` | One or more IMPLs in the current tier are active |
| `TIER_VERIFIED` | Current tier complete, gates passed |
| `COMPLETE` | All tiers complete |
| `BLOCKED` | Tier failed, cross-IMPL issue detected |
| `NOT_SUITABLE` | Planner determined project not suitable for multi-IMPL orchestration |

### 9.2 State Transitions

**Primary success path:**

```
PLANNING → VALIDATING → REVIEWED → SCAFFOLD → 
TIER_EXECUTING (Tier 1) → TIER_VERIFIED (Tier 1) →
TIER_EXECUTING (Tier 2) → TIER_VERIFIED (Tier 2) →
... → COMPLETE
```

**Failure paths:**
- `PLANNING → NOT_SUITABLE` (terminal, Planner suitability gate failed)
- `TIER_EXECUTING → BLOCKED` (IMPL failure or tier gate failure)
- `BLOCKED → TIER_EXECUTING` (recovery, issue resolved)

See `protocol/state-machine.md` for detailed state machine specification (to be updated in subsequent implementation phase).

---

## 10. Re-Planning

When a tier gate fails (E29) or the user explicitly requests it, the
Planner agent can be re-engaged to revise the PROGRAM manifest.

**Triggers:**
- Tier gate failure (required gates fail, tier cannot advance)
- Cross-IMPL interface mismatch detected
- User request (`/saw program replan`)

**Planner receives:**
- Current PROGRAM manifest
- Failure context (tier number, gate results, IMPL completion reports)
- Instruction to revise program contracts or tier structure

**Planner may revise:**
- Program contracts (add/remove/modify shared types)
- Tier structure (reorder IMPLs, add/remove tiers)
- IMPL decomposition (split/merge features)

**Planner may NOT revise:**
- Completed tiers (already executed and merged)
- Frozen program contracts (used by completed IMPLs)

**Output:**
Revised PROGRAM manifest with updated state: PROGRAM_REVIEWED.
Human must approve revised plan before execution resumes.

**Non-destructive guarantee:**
Re-planning does not discard completed work. Completed IMPLs remain
in the manifest with status "complete". Only pending and failed IMPLs
may be revised.

---

## 11. Orchestrator Commands

The following `/saw program` commands are available for program-level orchestration:

| Command | Description |
|---------|-------------|
| `/saw program plan <requirements>` | Launch Planner to produce a PROGRAM manifest from requirements |
| `/saw program status` | Show current program state, tier progress, and IMPL statuses |
| `/saw program execute [--auto]` | Begin or resume program execution (tier-by-tier) |
| `/saw program replan` | Re-engage Planner to revise PROGRAM manifest after failure or on request |

**Command details:**

- **`/saw program plan`** — Runs the Planner agent, which analyzes requirements and produces a `PROGRAM-<name>.yaml` manifest. The Planner also runs a suitability gate; if the project is too small or too simple for multi-IMPL orchestration, the Planner returns `NOT_SUITABLE` with an explanation.

- **`/saw program status`** — Reads the PROGRAM manifest from disk and renders a human-readable summary of tier and IMPL progress without modifying state.

- **`/saw program execute [--auto]`** — Executes the program tier by tier. Without `--auto`, halts at each tier gate for human review. With `--auto`, advances automatically through tier gates that pass, stopping only on failure or program completion.

- **`/saw program replan`** — Re-engages the Planner with the current PROGRAM manifest and any available failure context (tier gate results, blocked IMPL reports). Sets program state to `PLANNING` and produces a revised manifest for human approval before execution resumes. See Section 10 for full re-planning semantics.

---

## 12. Pre-Mortem Section

The `pre_mortem` section captures program-level risk analysis performed by the Planner.

### 12.1 Schema

Pre-mortem entries reuse the `PreMortemRow` schema from IMPL manifests:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `scenario` | string | Yes | Risk description |
| `likelihood` | string | Yes | `low`, `medium`, or `high` |
| `impact` | string | Yes | `low`, `medium`, or `high` |
| `mitigation` | string | Yes | How the program addresses this risk |

### 12.2 Example

```yaml
pre_mortem:
  - scenario: "Cross-IMPL interface drift"
    likelihood: medium
    impact: high
    mitigation: |
      Program contracts freeze at specified tier boundary. Planner
      identifies shared types before any IMPL is scouted. Scout agents
      receive program contracts as input and must not redefine them.
  
  - scenario: "Tier 2 IMPL discovers Tier 1 output is insufficient"
    likelihood: medium
    impact: medium
    mitigation: |
      Program contracts capture the expected outputs. If a Tier 2 Scout
      finds missing capabilities in Tier 1, the Program enters BLOCKED.
      Planner revises the program contracts and the affected Tier 1 IMPL.
  
  - scenario: "Combinatorial state explosion with 10+ IMPLs"
    likelihood: low
    impact: high
    mitigation: |
      Tier structure limits parallelism to 2-3 concurrent IMPLs. Each IMPL
      is fully self-contained per existing I1-I6 invariants. Web dashboard
      provides program-level monitoring.
```

---

## 13. Relationship to IMPL Documents

### 13.1 PROGRAM References IMPL

The PROGRAM manifest **references** IMPL docs by slug in the `impls` section. The Planner does **not** produce IMPL docs; that remains the Scout's responsibility.

**Example reference flow:**

```
PROGRAM-greenfield-api.yaml
  impls:
    - slug: "auth"       ← References future IMPL doc
      tier: 1
      status: pending

(After Scout runs for this IMPL)
→ IMPL-auth.yaml         ← Produced by Scout, not Planner
```

### 13.2 IMPL Docs Are Produced by Scout

The Planner **does not write IMPL docs**. Instead:

1. Planner produces PROGRAM manifest with IMPL slugs and tier assignments
2. Orchestrator launches Scout agents for each IMPL (in tier order)
3. Scout produces `IMPL-<slug>.yaml` for its assigned feature
4. Scout reads program contracts from PROGRAM manifest (if consuming Tier N-1 outputs)

### 13.3 Tiers Are Analogous to Waves

| Concept | Scope | Contains | Execution |
|---------|-------|----------|-----------|
| **Wave** | IMPL-level | Agents | Parallel (within wave) |
| **Tier** | Program-level | IMPLs | Parallel (within tier) |

Within a tier, all IMPLs execute their full lifecycle (Scout → Scaffold → Wave 1 → Wave 2 → ... → COMPLETE) in parallel. Tier gates only fire when **all IMPLs in the tier reach COMPLETE**.

---

## 14. Full Example Manifest

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
    description: |
      Core session type shared by auth, dashboard, and API layers.
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
    freeze_at: "Tier 1 completion"

  - name: "APIResponse<T>"
    description: |
      Generic API response wrapper with pagination and error handling.
    definition: |
      type APIResponse[T any] struct {
        Data       T                 `json:"data,omitempty"`
        Error      *APIError         `json:"error,omitempty"`
        Pagination *PaginationMeta   `json:"pagination,omitempty"`
      }
    consumers:
      - impl: "api-routes"
        usage: "Wraps all handler responses"
      - impl: "dashboard"
        usage: "Parses API responses in frontend"
    location: "pkg/types/response.go"
    freeze_at: "Tier 2 completion"

impls:
  - slug: "data-model"
    title: "Core data model and storage layer"
    tier: 1
    depends_on: []
    estimated_agents: 3
    estimated_waves: 1
    key_outputs:
      - "pkg/models/*.go"
      - "pkg/storage/*.go"
    status: pending

  - slug: "auth"
    title: "Authentication and session management"
    tier: 1
    depends_on: []
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "pkg/auth/*.go"
      - "pkg/middleware/auth.go"
    status: pending

  - slug: "api-routes"
    title: "REST API route handlers"
    tier: 2
    depends_on: ["data-model", "auth"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs:
      - "pkg/api/*.go"
    status: pending

  - slug: "frontend-shell"
    title: "React app shell, routing, and layout"
    tier: 2
    depends_on: ["auth"]
    estimated_agents: 3
    estimated_waves: 1
    key_outputs:
      - "web/src/components/*.tsx"
      - "web/src/App.tsx"
    status: pending

  - slug: "dashboard"
    title: "Dashboard views and data visualization"
    tier: 3
    depends_on: ["api-routes", "frontend-shell"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs:
      - "web/src/components/dashboard/*.tsx"
    status: pending

  - slug: "integration-tests"
    title: "End-to-end integration test suite"
    tier: 4
    depends_on: ["dashboard"]
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "tests/e2e/*.go"
    status: pending

tiers:
  - number: 1
    impls: ["data-model", "auth"]
    description: "Foundation — no dependencies, can execute fully in parallel"
  
  - number: 2
    impls: ["api-routes", "frontend-shell"]
    description: "Core features — depend on Tier 1 outputs"
  
  - number: 3
    impls: ["dashboard"]
    description: "Composite features — depend on Tier 2 outputs"
  
  - number: 4
    impls: ["integration-tests"]
    description: "Verification — depend on all prior tiers"

tier_gates:
  - type: build
    command: "go build ./... && cd web && npm run build"
    required: true
    description: "Full project build"
  
  - type: test
    command: "go test ./... && cd web && npm test"
    required: true
    description: "All unit tests"

completion:
  tiers_complete: 0
  tiers_total: 4
  impls_complete: 0
  impls_total: 6
  total_agents: 0
  total_waves: 0

pre_mortem:
  - scenario: "Cross-IMPL interface drift"
    likelihood: medium
    impact: high
    mitigation: |
      Program contracts freeze at specified tier boundary. Planner
      identifies shared types before any IMPL is scouted. Scout agents
      receive program contracts as input and must not redefine them.
  
  - scenario: "Tier 2 IMPL discovers Tier 1 output is insufficient"
    likelihood: medium
    impact: medium
    mitigation: |
      Program contracts capture the expected outputs. If a Tier 2 Scout
      finds missing capabilities in Tier 1, the Program enters BLOCKED.
      Planner revises the program contracts and the affected Tier 1 IMPL.
  
  - scenario: "Context window pressure with 6 IMPLs"
    likelihood: medium
    impact: medium
    mitigation: |
      PROGRAM manifest persists state to disk. Orchestrator re-reads
      manifest at tier boundaries. Tool journaling captures execution
      history. /saw program status reconstructs state from disk.
```

---

## 15. Validation Rules

The orchestrator validates PROGRAM manifests before proceeding with execution. Validation checks include:

### 15.1 Schema Validation

- All required fields present
- Field types correct (string, integer, array, object)
- Enum values valid (state, IMPL status)

### 15.2 Structural Validation

- `program_slug` matches filename (e.g., `greenfield-api` → `PROGRAM-greenfield-api.yaml`)
- All IMPLs referenced in `tiers` exist in `impls` section
- No IMPL appears in multiple tiers
- Tier numbers are sequential starting from 1

### 15.3 Dependency Validation (P1 Invariant)

- No IMPL in tier N has `depends_on` referencing another IMPL also in tier N
- All `depends_on` references point to IMPLs in earlier tiers
- No circular dependencies in the IMPL dependency graph

### 15.4 Program Contract Validation

- All `consumers[].impl` references point to valid IMPL slugs
- Contract `location` paths do not conflict (no two contracts write to same file)
- `freeze_at` references valid tier boundaries

### 15.5 Completion Consistency

- `tiers_total` matches number of entries in `tiers` section
- `impls_total` matches number of entries in `impls` section
- `tiers_complete` ≤ `tiers_total`
- `impls_complete` ≤ `impls_total`

---

## 16. Protocol-Level Integration

### 16.1 Cross-References

- **Planner agent:** See `protocol/participants.md` for Planner role definition
- **Program invariants:** See `protocol/program-invariants.md` (to be created) for P1-P4
- **Existing invariants:** I1-I6 continue to apply within each IMPL (see `protocol/invariants.md`)
- **IMPL manifest:** See `protocol/message-formats.md` for IMPL doc schema
- **State machine:** See `protocol/state-machine.md` (to be extended with Program states)

### 16.2 Hierarchy

```
protocol/preconditions.md          (prerequisites for SAW execution)
    ↓
protocol/program-manifest.md       (this document — project-level schema)
    ↓
protocol/message-formats.md        (IMPL manifest schema — feature-level)
    ↓
protocol/invariants.md             (agent-level invariants I1-I6)
```

The PROGRAM manifest extends SAW's protocol from feature-level coordination (IMPL docs) to project-level coordination (multi-IMPL orchestration).

---

**Document Status:** Version 0.2.0 — Added Re-Planning section (§10) and Orchestrator Commands section (§11)
**Next Steps:** Define program-level invariants (P1-P4) and extend state machine with Program states
**Related Implementation:** See `pkg/protocol/program_types.go` for Go SDK struct definitions
