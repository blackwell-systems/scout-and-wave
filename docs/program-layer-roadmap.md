# Program Layer Roadmap: Multi-IMPL Orchestration

**Date:** 2026-03-17
**Status:** Design Phase
**Author:** Orchestrator + Human (collaborative design session)
**Prerequisite:** Resilient Execution Lifecycle (IMPL-resilient-execution-lifecycle.yaml)

---

## 1. Executive Summary

Scout-and-Wave currently operates at the **feature level**: one IMPL doc decomposes one feature into parallel agents across waves. This works well for incremental development — adding a feature to an existing codebase.

But for **greenfield projects** or **large-scale refactors** that span 5-20 features with cross-cutting dependencies, the user must manually sequence IMPL docs, track cross-feature interfaces, and decide execution order. There is no protocol-level artifact or agent role that coordinates at this scale.

The **Program Layer** introduces a new abstraction tier above the IMPL doc:

```
Program (new)          — coordinates multiple IMPLs
  └── IMPL (existing)  — coordinates multiple agents within a feature
        └── Agent (existing) — implements files within a wave
```

This is the equivalent of adding "epic" or "program" level orchestration while preserving all existing IMPL-level invariants (I1-I6) intact.

**Key deliverables:**
1. **PROGRAM manifest** — new YAML artifact that decomposes a project into ordered IMPL docs
2. **Planner agent** — new participant role that produces the PROGRAM manifest
3. **Program state machine** — outer loop that drives IMPL-level execution
4. **Cross-IMPL interface contracts** — types/APIs that span multiple features
5. **`/saw program` command** — new invocation mode for the orchestrator

**Estimated scope:** 4 implementation phases, ~200-280 hours total

---

## 2. The Problem

### 2.1 Current Bootstrap Limitation

The existing `bootstrap` flow attempts to solve greenfield by cramming everything into a single IMPL doc. This hits practical limits:

- **Agent ceiling:** A single IMPL with >8 agents produces manifests >20KB, increasing Scout error rates and agent context pressure.
- **Wave depth:** Complex projects need 4-6 waves. Each wave blocks on the previous, serializing what could be parallel feature tracks.
- **Interface sprawl:** A single IMPL doc with 15+ interface contracts becomes unwieldy. Contracts for unrelated features pollute each agent's context.
- **Blast radius:** One failed agent in Wave 3 blocks all subsequent waves, even for features with no dependency on that agent's work.
- **No incremental delivery:** The entire project is one atomic unit. You can't ship the auth layer while the dashboard is still in progress.

### 2.2 Manual Sequencing Today

Users currently work around this by:

1. Running `/saw scout` for each feature manually
2. Mentally tracking which features depend on which
3. Executing IMPL docs in the "right" order
4. Hoping that interface contracts between separately-scouted features are compatible

This works for 2-3 features. It breaks down at 5+ features because:
- No single artifact captures the cross-feature dependency graph
- No verification that separately-scouted IMPLs produce compatible interfaces
- No automated sequencing — the user is the scheduler
- CONTEXT.md captures history but doesn't plan forward

### 2.3 Competitive Context

From the Formic comparison (`docs/competitive/formic-comparison.md`):

- **Formic** has "Goal" tasks that decompose into DAG-aware subtasks. SAW has no equivalent above IMPL level.
- **Kiro** (from `docs/ECOSYSTEM.md`) generates requirements → design → tasks for a single agent. No multi-feature coordination.
- **No tool in the ecosystem** provides protocol-level multi-feature orchestration with formal safety guarantees.

The Program Layer would make SAW the first system to offer **verified-safe parallel execution at both the feature level AND the project level**.

---

## 3. New Artifacts

### 3.1 PROGRAM Manifest

**Location:** `docs/PROGRAM-<name>.yaml`

The PROGRAM manifest is to IMPL docs what an IMPL doc is to agent tasks: the single source of truth for project-level decomposition.

**Schema:**

```yaml
# PROGRAM: <project-name>
title: "Human-readable project description"
program_slug: <kebab-case-slug>
state: PLANNING | REVIEWED | EXECUTING | COMPLETE
created: YYYY-MM-DD
updated: YYYY-MM-DD

# Requirements reference (written by Orchestrator before Planner launches)
requirements: "docs/REQUIREMENTS.md"

# Cross-IMPL interface contracts
# These define types/APIs that multiple IMPLs must agree on.
# Unlike IMPL-level contracts (which are intra-feature), these span features.
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
    freeze_at: "IMPL-auth completion"  # When this contract becomes immutable

# IMPL decomposition with dependency graph
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
    status: pending | scouting | reviewed | executing | complete

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

# IMPL tiers (analogous to agent waves within an IMPL)
# All IMPLs in the same tier can be scouted and executed in parallel.
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

# Program-level quality gates (run after each tier completes)
tier_gates:
  - type: build
    command: "go build ./... && cd web && npm run build"
    required: true
  - type: test
    command: "go test ./... && cd web && npm test"
    required: true

# Completion tracking
completion:
  tiers_complete: 0
  tiers_total: 4
  impls_complete: 0
  impls_total: 6
  total_agents: 0   # Populated after all IMPLs are scouted
  total_waves: 0    # Populated after all IMPLs are scouted

# Pre-mortem (program-level risks)
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
```

### 3.2 Cross-IMPL Interface Contracts

These are a new category of contract, distinct from IMPL-level contracts:

| Property | IMPL Contract | Program Contract |
|----------|--------------|-----------------|
| Scope | Within a feature (intra-IMPL) | Across features (inter-IMPL) |
| Defined by | Scout | Planner |
| Consumed by | Wave agents in same IMPL | Scout agents across multiple IMPLs |
| Frozen at | Worktree creation | Tier completion |
| Materialized by | Scaffold Agent | Program Scaffold step (new) |

**Key insight:** Program contracts must be materialized as code *before any IMPL in the consuming tier begins scouting*. This extends I2 (interface contracts precede implementation) to the program level.

**Example flow:**

```
Planner defines UserSession contract (program level)
  → Tier 1 completes (data-model, auth both produce code referencing UserSession)
  → UserSession contract freezes
  → Tier 2 Scouts receive frozen UserSession contract as input
  → Tier 2 IMPL-level contracts build on top of it
```

### 3.3 Relationship to Existing Artifacts

```
REQUIREMENTS.md          (Orchestrator writes, Planner reads)
    ↓
PROGRAM-<name>.yaml      (Planner writes, Orchestrator manages)  ← NEW
    ↓
IMPL-<feature>.yaml      (Scout writes per feature, unchanged)
    ↓
CONTEXT.md               (Updated after each IMPL completes, unchanged)
```

---

## 4. New Participant: Planner Agent

### 4.1 Role Definition

**Execution mode:** Asynchronous (same as Scout)

**Responsibilities:**

An asynchronous agent launched by the orchestrator before any Scout runs.
Analyzes REQUIREMENTS.md (and optionally an existing codebase for refactors),
identifies natural feature boundaries, defines cross-feature dependencies,
produces the PROGRAM manifest, and exits. The Planner is a "super-Scout" that
operates at project scope rather than feature scope.

**Required capabilities:**

- Read REQUIREMENTS.md, CONTEXT.md, existing source code
- Analyze project structure to identify natural boundaries (packages, services, layers)
- Identify cross-feature dependencies and shared types
- Define program contracts for types/APIs that span multiple features
- Produce PROGRAM manifest with IMPL decomposition, tier ordering, and contracts
- Run suitability assessment at the program level

**Forbidden actions:**

- Write IMPL docs (delegated to Scout)
- Write source code (delegated to Scaffold Agent and Wave Agents)
- Launch other agents
- Modify existing source files

### 4.2 Planner vs Scout

| Dimension | Planner | Scout |
|-----------|---------|-------|
| Input | REQUIREMENTS.md + codebase | Feature description + codebase |
| Output | PROGRAM manifest | IMPL manifest |
| Scope | Entire project | Single feature |
| Contracts defined | Cross-IMPL (program contracts) | Cross-agent (interface contracts) |
| Decomposition | Features → tiers | Feature → agents → waves |
| Suitability gate | "Is this project decomposable into independent features?" | "Is this feature decomposable into independent agents?" |
| Runs | Once per project (or on re-plan) | Once per feature |

### 4.3 Planner Suitability Gate

The Planner runs its own suitability assessment before producing the PROGRAM manifest. This gate determines whether the project benefits from multi-IMPL orchestration:

**Questions:**

1. **Feature independence:** Can the project be decomposed into 3+ features with bounded cross-feature dependencies? (If everything depends on everything, a single IMPL is better.)
2. **Tier depth:** Are there at least 2 tiers of features? (If all features are independent, just run separate Scouts — no Program needed.)
3. **Shared types:** Are there cross-feature types/APIs that need formal contracts? (If features are truly independent, program contracts add overhead without value.)
4. **Scale justification:** Is the total estimated work >8 agents? (Below this threshold, a single IMPL handles it fine.)

**Verdicts:**
- `PROGRAM_SUITABLE` — proceed with multi-IMPL orchestration
- `SINGLE_IMPL_SUFFICIENT` — project is small enough for one IMPL, fall back to bootstrap
- `NOT_DECOMPOSABLE` — features are too entangled for safe parallel execution at any level

### 4.4 Planner Agent Prompt Structure

The Planner follows the same 9-field agent prompt format as other SAW agents (per `agent-template.md`), with these specific fields:

- **Field 0 (Navigation):** cd to project root
- **Field 1 (Role):** "You are the Planner agent. You decompose projects into features."
- **Field 2 (IMPL reference):** Path to REQUIREMENTS.md (not an IMPL doc — Planner predates IMPLs)
- **Field 3 (Task):** "Analyze REQUIREMENTS.md and produce PROGRAM-<name>.yaml"
- **Field 4 (Interfaces):** N/A (Planner defines them, doesn't consume them)
- **Field 5 (Files):** PROGRAM manifest only
- **Field 6 (Verification):** Validate PROGRAM manifest schema
- **Field 7 (Completion):** Write to PROGRAM manifest (not IMPL doc)
- **Field 8 (Constraints):** Program-level invariants (see Section 6)

---

## 5. Program State Machine

### 5.1 States

The Program state machine is an outer loop that contains the existing IMPL state machine as an inner loop:

```
PROGRAM_PLANNING          Planner agent analyzing, producing PROGRAM manifest
PROGRAM_VALIDATING        Orchestrator validating PROGRAM manifest
PROGRAM_REVIEWED          Human reviewing and approving PROGRAM manifest
PROGRAM_SCAFFOLD          Materializing program-level contracts as code
TIER_EXECUTING            One or more IMPLs in the current tier are active
TIER_VERIFIED             Current tier complete, gates passed
PROGRAM_COMPLETE          All tiers complete
PROGRAM_BLOCKED           Tier failed, cross-IMPL issue detected
PROGRAM_NOT_SUITABLE      Planner determined project not suitable for multi-IMPL
```

### 5.2 State Transitions

**Primary flow (success path):**

```
PROGRAM_PLANNING
    ↓ (Planner completes, PROGRAM manifest written)
PROGRAM_VALIDATING
    ↓ (Validation passes)
PROGRAM_REVIEWED
    ↓ (Human approves)
PROGRAM_SCAFFOLD (if program contracts exist)
    ↓ (Program-level scaffold files committed)
TIER_EXECUTING (Tier 1)
    ↓ (All Tier 1 IMPLs reach COMPLETE)
TIER_VERIFIED (Tier 1)
    ↓ (Tier gates pass, program contracts freeze)
TIER_EXECUTING (Tier 2)
    ↓ ...
TIER_VERIFIED (Tier N, final tier)
    ↓
PROGRAM_COMPLETE
```

### 5.3 TIER_EXECUTING Inner Loop

Within TIER_EXECUTING, each IMPL follows the existing IMPL state machine independently:

```
TIER_EXECUTING
  ├── IMPL-data-model:  SCOUT_PENDING → ... → COMPLETE
  └── IMPL-auth:        SCOUT_PENDING → ... → COMPLETE
  (Both running in parallel — same tier, independent features)
```

**Critical detail:** IMPLs within the same tier execute their full lifecycle in parallel — Scout, Scaffold, Wave 1, Wave 2, ..., COMPLETE — independently. The tier gate only fires when ALL IMPLs in the tier reach COMPLETE.

### 5.4 Transition Guards

**PROGRAM_REVIEWED → PROGRAM_SCAFFOLD:**
- Human approval received
- Program contracts section is non-empty
- Skip to TIER_EXECUTING if no program contracts

**PROGRAM_SCAFFOLD → TIER_EXECUTING:**
- All program-level scaffold files committed
- Program contracts materialized as source code

**TIER_EXECUTING → TIER_VERIFIED:**
- All IMPLs in the current tier have reached COMPLETE
- Tier-level quality gates pass (full project build + test)

**TIER_VERIFIED → TIER_EXECUTING (next tier):**
- Program contracts that freeze at this tier boundary are now immutable
- Next tier's IMPLs are ready for scouting
- Human approval (or `--auto` mode)

**TIER_VERIFIED → PROGRAM_COMPLETE:**
- Final tier verified
- All IMPLs complete
- Program manifest marked with completion timestamp

### 5.5 Failure and Recovery

**IMPL failure within a tier:**
- Individual IMPL enters BLOCKED per existing state machine
- Other IMPLs in the same tier continue independently (no cascade)
- Tier cannot advance until the blocked IMPL is resolved
- Orchestrator surfaces the specific IMPL's failure, not the whole program

**Cross-IMPL interface mismatch (detected at tier gate):**
- Tier gate finds that IMPL-A's output doesn't match what IMPL-B expected
- Program enters PROGRAM_BLOCKED
- Planner is re-engaged to revise program contracts
- Affected IMPLs in the NEXT tier have their Scout re-run with updated contracts
- Completed IMPLs in the current tier are NOT re-run (their outputs are committed)

**Planner re-engagement:**
- Triggered when: tier gate fails, or user requests program revision
- Planner reads current PROGRAM manifest + CONTEXT.md (updated by each completed IMPL)
- Planner produces revised PROGRAM manifest (may add/remove/reorder IMPLs)
- Revision goes through PROGRAM_REVIEWED again before execution resumes

---

## 6. Program-Level Invariants

The existing invariants I1-I6 continue to apply within each IMPL. The Program Layer adds four new invariants:

### P1: IMPL Independence Within a Tier

No two IMPLs in the same tier may have a dependency relationship. If IMPL-A depends on outputs from IMPL-B, they must be in different tiers (A in a later tier than B).

**Enforcement:** Planner defines tiers. Orchestrator validates that no IMPL in tier N has `depends_on` referencing an IMPL also in tier N.

**Rationale:** Same principle as I1 (disjoint file ownership) but at the IMPL level. Tiers are to IMPLs what waves are to agents.

### P2: Program Contracts Precede Tier Execution

All cross-IMPL types/APIs that a tier's IMPLs depend on must be:
1. Defined in the PROGRAM manifest's `program_contracts` section
2. Materialized as source code (committed to HEAD)
3. Frozen before any Scout in the consuming tier begins

**Enforcement:** Orchestrator verifies program contract files exist and are committed before launching Scouts for the next tier.

**Rationale:** Extension of I2 (interface contracts precede implementation) to the program level. A Scout analyzing a Tier 2 feature needs to know the exact types that Tier 1 produced. Without frozen program contracts, separately-scouted IMPLs may define incompatible interfaces.

### P3: Tier Sequencing

Tier N+1 does not begin (no Scout launches) until:
1. All IMPLs in Tier N have reached COMPLETE
2. Tier N quality gates have passed
3. Program contracts that freeze at Tier N boundary are committed

**Enforcement:** Orchestrator checks tier completion before launching any Tier N+1 work.

**Rationale:** Extension of I3 (wave sequencing) to the program level.

### P4: PROGRAM Manifest is Source of Truth

The PROGRAM manifest is the single source of truth for:
- Which IMPLs exist and their ordering
- Cross-IMPL dependencies
- Program contracts and their freeze points
- Tier completion status

IMPL docs reference the PROGRAM manifest but do not duplicate its information.

**Rationale:** Extension of I4 (IMPL doc is source of truth) to the program level.

---

## 7. Execution Model: Three Autonomy Levels

### 7.1 Level A: Plan Only (Lowest Autonomy)

```
/saw program plan "project description"
```

The Planner produces the PROGRAM manifest. The user reviews it. Execution is entirely manual — the user runs `/saw scout` and `/saw wave` for each IMPL in the order specified by the tiers.

**The PROGRAM manifest is a roadmap, not an executor.**

**Value:** Even without automated execution, the PROGRAM manifest provides:
- Formal cross-IMPL dependency graph
- Program contracts that prevent interface drift
- Tier ordering that the user follows manually
- A persistent artifact that captures the project plan

**Implementation effort:** Lowest. Only needs the Planner agent and PROGRAM manifest schema.

### 7.2 Level B: Tier-Gated Execution (Recommended)

```
/saw program execute "project description"
```

The orchestrator drives execution automatically within each tier (scouting all IMPLs, running all waves) but pauses between tiers for human review.

**Flow:**
1. Planner produces PROGRAM manifest → human reviews
2. Orchestrator auto-scouts all Tier 1 IMPLs (in parallel)
3. Human reviews all Tier 1 IMPL docs
4. Orchestrator executes all Tier 1 IMPLs (waves run per existing protocol)
5. Tier 1 gate runs → human reviews results
6. Orchestrator auto-scouts all Tier 2 IMPLs → human reviews → execute → gate
7. Repeat until all tiers complete

**Human gates:** Between tiers only. Within a tier, `--auto` mode applies.

**Value:** Full parallelism within tiers. Human oversight at tier boundaries where cross-feature integration matters most.

**Implementation effort:** Medium. Needs the outer loop (tier execution), parallel Scout launching, and tier gate verification.

### 7.3 Level C: Full Autonomous (Highest Autonomy)

```
/saw program execute --auto "project description"
```

Same as Level B, but tier gates don't pause for human review. The orchestrator proceeds automatically unless a failure occurs.

**Human gates:** Only on failure (PROGRAM_BLOCKED). All success-path transitions are automatic.

**Prerequisite:** Resilient Execution Lifecycle must be complete. Without step-level recovery, a single failure in a 20-IMPL program has no recovery path except starting over.

**Value:** Maximum throughput for well-defined projects with high confidence in requirements.

**Implementation effort:** Highest. Needs robust error recovery, automatic re-planning, and confidence in the Planner's output.

---

## 8. Orchestrator Changes

### 8.1 New `/saw` Subcommands

| Command | Purpose |
|---------|---------|
| `/saw program plan <description>` | Planner produces PROGRAM manifest, no execution |
| `/saw program execute <description>` | Plan + tier-gated execution (Level B) |
| `/saw program execute --auto <description>` | Plan + fully autonomous execution (Level C) |
| `/saw program status` | Show program-level progress (tier completion, IMPL statuses) |
| `/saw program status --impl <slug>` | Show specific IMPL within program |
| `/saw program replan` | Re-engage Planner to revise PROGRAM manifest |

### 8.2 Orchestrator Responsibilities (Expanded)

The orchestrator gains these additional duties:

1. **Launch Planner** — analogous to launching Scout, but at project scope
2. **Validate PROGRAM manifest** — new validator for program-level schema
3. **Tier management** — track which tier is active, which IMPLs are complete
4. **Parallel Scout launching** — launch multiple Scouts simultaneously for all IMPLs in a tier
5. **Cross-IMPL monitoring** — track progress across multiple concurrent IMPL executions
6. **Tier gate verification** — run program-level quality gates between tiers
7. **Program contract freezing** — enforce immutability of program contracts after tier completion
8. **Program completion** — mark PROGRAM manifest complete, update CONTEXT.md

### 8.3 I6 Extension

I6 (Role Separation) extends to the Planner:

- The Orchestrator does not perform Planner duties (project decomposition)
- The Planner does not perform Scout duties (feature decomposition)
- The Scout does not redefine program contracts (only consumes them)

Each role operates at exactly one level of the hierarchy.

---

## 9. sawtools Extensions

### 9.1 New Commands

```bash
# Program manifest management
sawtools validate-program <program-manifest>       # Schema validation
sawtools list-programs --dir <path>                 # Program discovery

# Tier management
sawtools tier-status <program-manifest> --tier <N>  # Tier completion check
sawtools tier-gate <program-manifest> --tier <N>    # Run tier quality gates
sawtools freeze-contracts <program-manifest> --tier <N>  # Freeze program contracts

# Program lifecycle
sawtools program-status <program-manifest>          # Full program status
sawtools mark-program-complete <program-manifest>   # Terminal marker
```

### 9.2 Existing Command Enhancements

```bash
# Scout receives program contracts as input
sawtools run-scout <feature> --program <program-manifest>
# Scout reads program contracts and treats them as immutable inputs

# IMPL validation checks program contract compatibility
sawtools validate <impl-doc> --program <program-manifest>
# Verifies IMPL doesn't redefine program-level contracts
```

---

## 10. Web App Integration

The scout-and-wave-web app would need:

### 10.1 Program Board View

A new top-level view showing the tier structure:

```
Tier 1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [data-model] ████████████ COMPLETE
  [auth]       ████████░░░░ Wave 2/3

Tier 2 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (blocked on Tier 1)
  [api-routes]     ░░░░░░░░░░░░ Pending
  [frontend-shell] ░░░░░░░░░░░░ Pending

Tier 3 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [dashboard]  ░░░░░░░░░░░░ Pending

Tier 4 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [integration-tests] ░░░░░░░░░░░░ Pending
```

Each IMPL card links to the existing WaveBoard for that IMPL's detailed view.

### 10.2 Program Contracts Panel

Shows cross-IMPL contracts with freeze status:
- `UserSession` — frozen (Tier 1 complete)
- `APIResponse<T>` — pending (freezes after Tier 2)

### 10.3 Cross-IMPL Dependency Graph

Visual DAG showing IMPL dependencies, colored by status. Extends the existing dep graph visualization from feature-level to program-level.

### 10.4 New API Endpoints

```
GET  /api/program/{slug}                   # Program status
GET  /api/program/{slug}/tier/{n}          # Tier status
POST /api/program/{slug}/tier/{n}/execute  # Launch tier execution
GET  /api/program/{slug}/contracts         # Program contracts
POST /api/program/{slug}/replan            # Re-engage Planner
```

### 10.5 SSE Events

```
program_tier_started    {program, tier}
program_tier_complete   {program, tier}
program_impl_started    {program, impl_slug}
program_impl_complete   {program, impl_slug}
program_contract_frozen {program, contract_name, tier}
program_complete        {program}
program_blocked         {program, reason, impl_slug?}
```

---

## 11. Implementation Phases

### Phase 0: Prerequisites (In Progress)

**Resilient Execution Lifecycle** — IMPL-resilient-execution-lifecycle.yaml

Must complete before Program Layer work begins. Without step-level recovery
at the IMPL level, running multiple IMPLs simultaneously is too fragile.

**Estimated effort:** Active (5 agents, 2 waves)

### Phase 1: Planner Agent + PROGRAM Manifest (Level A)

**Goal:** Users can run `/saw program plan` to produce a PROGRAM manifest.
No automated execution — just the planning artifact.

**Deliverables:**
1. PROGRAM manifest YAML schema definition (protocol repo)
2. `sawtools validate-program` command (Go SDK)
3. Planner agent definition (`agents/planner.md`) (protocol repo)
4. Planner `subagent_type: planner` registration (protocol repo)
5. `/saw program plan` orchestrator flow in saw-skill.md (protocol repo)
6. `sawtools list-programs` command (Go SDK)

**Protocol changes:**
- New file: `protocol/program-manifest.md` (schema spec)
- Update: `protocol/participants.md` (add Planner role)
- Update: `protocol/state-machine.md` (add Program states, or separate doc)
- New file: `protocol/program-invariants.md` (P1-P4)

**Estimated effort:** 40-60 hours
**Estimated SAW execution:** 2 IMPLs (schema + Planner agent)

### Phase 2: Tier-Gated Execution (Level B)

**Goal:** `/saw program execute` drives automatic execution within tiers,
pausing between tiers for human review.

**Deliverables:**
1. Tier execution loop in orchestrator (saw-skill.md)
2. Parallel Scout launching (multiple Scouts for same-tier IMPLs)
3. Tier gate verification (`sawtools tier-gate`)
4. Program contract freezing (`sawtools freeze-contracts`)
5. Cross-IMPL progress tracking
6. `sawtools program-status` command
7. Scout receives `--program` flag to consume program contracts

**Protocol changes:**
- Update: `protocol/execution-rules.md` (add E28-E32 for program execution)
- Update: saw-skill.md (add program execution flow)

**Estimated effort:** 60-80 hours
**Estimated SAW execution:** 3 IMPLs (tier loop, contract freezing, Scout integration)

### Phase 3: Web App Integration

**Goal:** Program Board view in the web app, cross-IMPL visualization,
program-level SSE events.

**Deliverables:**
1. Program Board React component
2. Cross-IMPL dependency graph visualization
3. Program contracts panel
4. Program API endpoints (6 endpoints)
5. Program SSE events (7 events)
6. Program runner (background loop analogous to wave_runner.go)

**Estimated effort:** 60-80 hours
**Estimated SAW execution:** 2-3 IMPLs (backend API, frontend components, SSE integration)

### Phase 4: Full Autonomous + Polish (Level C)

**Goal:** `--auto` mode for fully autonomous execution. Automatic re-planning
on failure. Planner re-engagement.

**Deliverables:**
1. Automatic tier advancement (no human gate on success)
2. Planner re-engagement on PROGRAM_BLOCKED
3. Automatic program contract revision on tier gate failure
4. Program completion marker and CONTEXT.md update
5. `sawtools mark-program-complete` command
6. `/saw program replan` command

**Estimated effort:** 40-60 hours
**Estimated SAW execution:** 2 IMPLs (auto mode, re-planning)

---

## 12. Risk Analysis

### 12.1 Planner Quality

**Risk:** The Planner produces a poor decomposition (wrong feature boundaries, missing dependencies, incorrect tier ordering).

**Likelihood:** Medium-High (this is the hardest judgment call in the system)

**Impact:** High (wrong decomposition cascades through all tiers)

**Mitigation:**
- Human review gate (PROGRAM_REVIEWED) is mandatory, not skippable even in `--auto`
- Planner suitability gate catches obviously unsuitable projects
- PROGRAM manifest is a human-readable YAML doc — easy to review and revise
- Re-plan capability allows course correction at any tier boundary

### 12.2 Program Contract Drift

**Risk:** Program contracts defined at planning time don't match what Tier 1 IMPLs actually produce.

**Likelihood:** Medium

**Impact:** Medium (Tier 2 Scouts plan against wrong types)

**Mitigation:**
- Program contracts are materialized as code before any IMPL executes
- Tier gates verify that IMPL outputs are compatible with program contracts
- If drift detected, program enters BLOCKED and Planner revises contracts

### 12.3 Combinatorial Complexity

**Risk:** A 6-IMPL, 4-tier program with 5 agents per IMPL = 30 agents. Managing 30 agents across 6 IMPL lifecycles is complex.

**Likelihood:** Low (this is the happy path — complexity is managed by the tier structure)

**Impact:** Medium (harder to debug failures, more state to track)

**Mitigation:**
- Tiers limit parallelism (max 2-3 concurrent IMPL lifecycles)
- Each IMPL is fully self-contained (existing invariants apply)
- Web app provides program-level dashboard for monitoring
- Failures in one IMPL don't cascade to independent IMPLs in the same tier

### 12.4 Context Window Pressure

**Risk:** The orchestrator managing a multi-IMPL program fills its context window before completing.

**Likelihood:** Medium-High (this is a real constraint)

**Impact:** High (orchestrator loses track of program state)

**Mitigation:**
- PROGRAM manifest persists state to disk (not just context)
- Orchestrator re-reads PROGRAM manifest on each tier boundary
- Tool journaling captures orchestrator execution history
- `/saw program status` can reconstruct state from disk at any time

### 12.5 Over-Engineering for Small Projects

**Risk:** Users invoke Program Layer for a 3-feature project that would have been fine with sequential Scout runs.

**Likelihood:** Medium

**Impact:** Low (wasted overhead but no harm)

**Mitigation:**
- Planner suitability gate returns `SINGLE_IMPL_SUFFICIENT` for small projects
- Documentation clearly states when Program Layer is appropriate vs. overkill
- `/saw bootstrap` remains the recommended flow for <8 agents

---

## 13. Success Criteria

### Phase 1 Complete When:
- [ ] Planner agent produces valid PROGRAM manifests for 3+ test projects
- [ ] `sawtools validate-program` catches schema violations
- [ ] PROGRAM manifest schema is documented in protocol/
- [ ] Planner suitability gate correctly triages small vs. large projects

### Phase 2 Complete When:
- [ ] `/saw program execute` successfully completes a 2-tier, 4-IMPL project
- [ ] Parallel Scout launching works within a tier
- [ ] Tier gates verify cross-IMPL compatibility
- [ ] Program contracts freeze correctly at tier boundaries
- [ ] IMPL-level Scouts correctly consume and respect program contracts

### Phase 3 Complete When:
- [ ] Program Board view shows tier structure with IMPL progress
- [ ] Cross-IMPL dependency graph renders correctly
- [ ] SSE events fire for all program lifecycle transitions
- [ ] Program runner drives execution from web UI

### Phase 4 Complete When:
- [ ] `--auto` mode completes a 3-tier project without human intervention
- [ ] Planner re-engagement produces valid revised PROGRAM manifests
- [ ] Failed tier correctly triggers PROGRAM_BLOCKED and recovery flow
- [ ] CONTEXT.md updated with program-level completion data

---

## 14. Open Questions

1. **Should the Planner produce IMPL docs directly, or just the PROGRAM manifest?**
   Current design: Planner produces PROGRAM manifest only. Scout runs separately for each IMPL. This preserves Scout's focused analysis but adds a round-trip. Alternative: Planner produces stub IMPL docs that Scout refines.

2. **Should program contracts be a separate file or embedded in the PROGRAM manifest?**
   Current design: embedded. Alternative: separate `PROGRAM-CONTRACTS-<name>.yaml` file that both the PROGRAM manifest and IMPL docs reference.

3. **How does the Program Layer interact with cross-repository projects?**
   Current design: each IMPL targets one repo (existing cross-repo support). Program manifest references repos per IMPL. Tier gates run per-repo and cross-repo.

4. **Should there be a "Program Scout" that does both Planner + Scout work for each IMPL?**
   Current design: two separate agents (Planner for project, Scout for feature). Separation preserves I6 and keeps each agent focused. But it means the Planner's feature-level understanding may differ from what Scout discovers.

5. **What is the maximum practical program size?**
   Hypothesis: 10-15 IMPLs across 4-5 tiers is the practical upper bound before orchestrator context pressure becomes the bottleneck. Beyond this, the project should be split into multiple programs.

6. **Should completed tiers enable incremental deployment?**
   After Tier 1 completes, the project may be partially deployable (e.g., data layer + auth layer). The PROGRAM manifest could track deployment readiness per tier.

---

## 15. Relationship to Existing Roadmaps

### Determinism Roadmap (docs/determinism-roadmap.md)

The determinism roadmap focuses on automating Scout judgment within a single IMPL. These tools are complementary:

- **H3 (dependency graph):** Planner uses the same analysis at project scope
- **H6 (dependency conflicts):** Extends to cross-IMPL dependency checking
- **H2 (command extraction):** Planner uses this for tier gate command generation

Phase 1 of the determinism roadmap should complete before Phase 2 of the Program Layer, because the Planner benefits from automated dep graph analysis.

### Resilient Execution Lifecycle (IMPL-resilient-execution-lifecycle.yaml)

Direct prerequisite. Step-level recovery within a single IMPL is foundational for multi-IMPL execution. Without it, a failure in one of 6 concurrent IMPLs has no granular recovery path.

### Competitive Positioning (docs/competitive/formic-comparison.md)

The Program Layer directly addresses two gaps identified in the Formic comparison:
- "No Built-in Self-Healing" — tier-level re-planning provides structured recovery
- "Wave Sequencing Can Be Slow" — parallel IMPL execution within tiers adds a new dimension of parallelism

And extends SAW's existing advantages:
- Multi-provider support scales to program level (different models per tier or per IMPL)
- Formal correctness guarantees (P1-P4) extend I1-I6 to project scope
- Protocol-driven approach remains language-agnostic

---

## 16. Ecosystem Impact

With the Program Layer, SAW would occupy a unique position in the ecosystem:

```
┌─────────────────────────────────────────────────────────────────┐
│  Program: coordinate features into tiers              ← NEW    │
│  (No competitor offers this)                                    │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Methodology: plan before code                            │  │
│  │  (Kiro, Spec Kit, BMAD-METHOD)                            │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  Protocol: plan for safe parallelism          ← SAW │  │  │
│  │  │  (suitability gate, disjoint ownership,             │  │  │
│  │  │   interface contracts, wave ordering)                │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │  Mechanism: run agents in parallel            │  │  │  │
│  │  │  │  (Agent Teams, Cursor, Codex, 1code,          │  │  │  │
│  │  │  │   code-conductor, ccswarm)                    │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

This extends the ecosystem positioning from ECOSYSTEM.md by adding a fourth layer that no other tool occupies: **project-level coordination with formal safety guarantees across multiple parallel feature tracks**.

---

*Design document produced during SAW session 2026-03-17. To be refined through implementation experience.*
