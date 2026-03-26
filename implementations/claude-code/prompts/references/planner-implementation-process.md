<!-- Part of planner agent procedure. Loaded by validate_agent_launch hook. -->
# Implementation Process (Steps 1-10)

### Step 1: Read Project Context

Before running the suitability gate, check for `docs/CONTEXT.md`. If present, read it in full:
- `established_interfaces` — do not propose types that already exist
- `decisions` — respect prior architectural decisions
- `conventions` — follow project naming and structure
- `features_completed` — understand project history

Also check for existing REQUIREMENTS.md. If it exists, read it. If not, you'll receive the project description in your prompt.

### Step 2: Run Suitability Gate

Answer the four suitability questions above. If the verdict is NOT_SUITABLE or SINGLE_IMPL_SUFFICIENT, write a minimal manifest and stop. Do not proceed with full analysis.

### Step 3: Identify Feature Boundaries

Analyze the project structure (if refactoring existing code) or requirements (if greenfield) to identify natural feature boundaries:

**For existing codebases:**
- Package/module structure (e.g., `pkg/auth`, `pkg/api`, `pkg/storage`)
- Service boundaries (e.g., microservices, separate binaries)
- Layer boundaries (e.g., data layer, business logic, presentation)
- Distinct functional areas (e.g., user management, billing, reporting)

**For greenfield projects:**
- Functional requirements clusters (features that share a common purpose)
- Architectural layers (frontend, backend, database, infrastructure)
- Deployment units (separate services, separate repos)

Each boundary becomes a candidate IMPL. Aim for 3-8 IMPLs — fewer is better for coordination overhead, but ensure each IMPL is focused and cohesive.

### Step 4: Define Cross-IMPL Dependencies

For each IMPL candidate, identify what it depends on:
- **Data dependencies:** Needs database schema or storage layer from another IMPL
- **API dependencies:** Calls functions or APIs defined in another IMPL
- **Type dependencies:** Uses types or interfaces defined in another IMPL
- **Infrastructure dependencies:** Requires shared components (auth, config, logging)

Build a dependency graph. If IMPL-A depends on IMPL-B, A must be in a later tier than B.

### Step 5: Identify Program Contracts

Program contracts are types, interfaces, or APIs that span multiple IMPLs. These must be defined, materialized as code, and frozen before any consuming IMPL begins scouting.

Look for:
- **Core domain types** shared by 3+ IMPLs (e.g., User, Session, Account)
- **Protocol definitions** (e.g., API response format, message schemas)
- **Infrastructure interfaces** (e.g., Database, Logger, Config)
- **Cross-cutting concerns** (e.g., error types, validation rules)

For each program contract, specify:
- **Name:** Type or interface name
- **Description:** Purpose and scope
- **Definition:** Exact signature (language-specific, fully typed)
- **Consumers:** Which IMPLs use it and how
- **Location:** File path where it will be created
- **Freeze point:** Which tier boundary locks this contract

**Critical:** Program contracts must be materialized as code files BEFORE any IMPL in the consuming tier begins. Scout agents will receive these contracts as immutable inputs.

### Step 6: Group IMPLs into Tiers

Tiers are analogous to waves within an IMPL: IMPLs in the same tier can be scouted and executed in parallel.

**Tier assignment rules:**
- **Tier 1:** IMPLs with no dependencies (foundation layer)
- **Tier N+1:** IMPLs that depend only on outputs from Tier 1..N

Use topological sort on the dependency graph. Maximize parallelism by placing as many IMPLs as possible in the same tier, subject to the constraint that dependencies must be satisfied.

**Tier description:** For each tier, write a brief description explaining what unifies the IMPLs in that tier and what they depend on from prior tiers.

### Step 7: Estimate Complexity Per IMPL

For each IMPL, estimate:
- **Agents:** How many parallel agents will Scout produce? (rough guess based on file count, module complexity)
- **Waves:** How many sequential waves? (rough guess based on dependency depth within the feature)
- **Key outputs:** What files or packages will this IMPL produce?

These are estimates to help humans understand project scale. They don't need to be precise.

### Step 8: Define Tier Gates

Tier gates are quality checks that run after each tier completes, before the next tier begins. These verify cross-IMPL integration.

Extract commands from the project build system:
```bash
sawtools extract-commands <repo-root>
```

Map the output to tier gates:
- `commands.build` → tier gate (type: build) — full project build
- `commands.test.full` → tier gate (type: test) — full test suite

Use the same commands for every tier, or customize per tier if certain tests only become relevant in later tiers.

### Step 9: Write Pre-Mortem Risk Assessment

Identify program-level risks (distinct from IMPL-level risks that Scout will identify):
- **Cross-IMPL interface drift:** Program contracts don't match what Tier 1 actually produces
- **Tier dependency misjudgment:** Tier 2 discovers it needs Tier 1 outputs that weren't planned
- **Program contract incompleteness:** Shared type missing fields that Tier 2 needs
- **Combinatorial complexity:** Too many concurrent IMPLs to track
- **Context window pressure:** Orchestrator loses track of program state

For each risk, estimate likelihood, impact, and mitigation strategy.

### Step 10: Write the PROGRAM Manifest

Use pure YAML format. Write to `docs/PROGRAM-<slug>.yaml`. No markdown headers (`##`), no fenced code blocks. Use YAML comments (`#`) for explanatory text.

**Schema:**

```yaml
# PROGRAM: <project-name>
title: "Human-readable project description"
program_slug: <kebab-case-slug>
state: PLANNING
created: YYYY-MM-DD
updated: YYYY-MM-DD

# Requirements reference
requirements: "docs/REQUIREMENTS.md"

# Cross-IMPL interface contracts
program_contracts:
  - name: "TypeName"
    description: |
      Multi-line description of purpose and scope.
    definition: |
      type TypeName struct {
        Field1 string
        Field2 int
      }
    consumers:
      - impl: "impl-slug-1"
        usage: "Creates instances"
      - impl: "impl-slug-2"
        usage: "Reads and validates"
    location: "pkg/types/typename.go"
    freeze_at: "Tier 1 completion"

# IMPL decomposition with dependency graph
impls:
  - slug: "impl-slug"
    title: "Feature description"
    tier: 1
    depends_on: []
    estimated_agents: 3
    estimated_waves: 1
    key_outputs:
      - "pkg/feature/*.go"
    status: pending

  - slug: "impl-slug-2"
    title: "Dependent feature"
    tier: 2
    depends_on: ["impl-slug"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs:
      - "pkg/feature2/*.go"
    status: pending

# Tier structure (grouping IMPLs for parallel execution)
tiers:
  - number: 1
    impls: ["impl-slug"]
    description: "Foundation — no dependencies"
  - number: 2
    impls: ["impl-slug-2"]
    description: "Core features — depend on Tier 1"

# Tier gates (quality checks between tiers)
tier_gates:
  - type: build
    command: "go build ./..."
    required: true
  - type: test
    command: "go test ./..."
    required: true

# Completion tracking
completion:
  tiers_complete: 0
  tiers_total: 2
  impls_complete: 0
  impls_total: 2
  total_agents: 0
  total_waves: 0

# Pre-mortem (program-level risks)
pre_mortem:
  - scenario: "Description of risk"
    likelihood: high | medium | low
    impact: high | medium | low
    mitigation: |
      How to mitigate this risk.
```

**Valid IMPL status values:**
- `pending` — IMPL not yet scouted
- `scouting` — Scout agent analyzing
- `reviewed` — IMPL doc reviewed, ready to execute
- `executing` — Wave agents active
- `complete` — IMPL finished, merged

**Valid program state values:**
- `PLANNING` — You are producing this manifest now
- `VALIDATING` — Orchestrator validating schema
- `REVIEWED` — Human reviewed and approved
- `SCAFFOLD` — Materializing program contracts as code
- `TIER_EXECUTING` — One or more tiers active
- `TIER_VERIFIED` — Tier complete, gates passed
- `COMPLETE` — All tiers complete
- `BLOCKED` — Tier failed or cross-IMPL issue detected
- `NOT_SUITABLE` — Project not suitable for multi-IMPL orchestration

Set `state: PLANNING` when you write the manifest. The orchestrator will advance it through the lifecycle.
