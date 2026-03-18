<!-- saw-bootstrap v0.4.0 -->
# SAW Bootstrap: Design-First Project Architecture

Use this mode when starting a new project from scratch with no existing codebase.
The bootstrap scout acts as **architect**, not analyst: designing disjoint file
ownership before any code is written.

## When to Use

- Starting a new project from an empty or near-empty repo
- No existing codebase for the scout to analyze
- Want SAW-compatible structure from day one

## When NOT to Use

- Existing codebase with features to add (use `/saw scout` instead)
- Single-file or trivially small projects
- Prototypes where structure doesn't matter yet

---

## Pre-Flight: Ensure Git Repo Exists (Orchestrator Duty)

**Note:** This section is for the orchestrator, not the Scout. The Scout begins at Step 0 below.

Before gathering requirements, check whether a git repository is initialized:

```bash
git status
```

If this fails (no repo), initialize one before proceeding. An empty first
commit is fine; it gives agents a clean branch to work from:

```bash
git init
git commit --allow-empty -m "chore: initial commit"
```

If there are already untracked files in the directory, stage and commit them:

```bash
git init
git add .
git commit -m "chore: initial commit"
```


**Bootstrap sequencing note:** In bootstrap mode, the target project path is learned from `docs/REQUIREMENTS.md` (Step 6: Source Codebase). If the requirements specify a source codebase path, check for `docs/CONTEXT.md` in that path. Otherwise, check the current working directory.
This costs nothing and prevents bootstrap from failing silently mid-execution
when agents try to create worktrees or branches.

## Step 0: Read Project Memory (E17)

Before reading requirements or running the suitability gate, check for
`docs/CONTEXT.md` in the target project. If it exists, read it in full:

- `established_interfaces` — avoid proposing types that already exist
- `decisions` — respect prior architectural decisions; do not contradict them
- `conventions` — follow project naming, error handling, and testing patterns
- `features_completed` — understand what waves have already shipped

If `docs/CONTEXT.md` does not exist, proceed normally.

---

## Phase 0: Read Requirements

The Orchestrator writes `docs/REQUIREMENTS.md` in the target project directory
before launching you. This file captures decisions already made by the user —
language, deployment target, external integrations, source codebase to analyze,
and architectural constraints you must respect.

**Read `docs/REQUIREMENTS.md` first.** If it does not exist, stop and report
the error — the Orchestrator must create it before launching the Scout.

Extract from the requirements doc:
1. **Language + ecosystem** — determines package/module structure conventions
2. **Project type** — CLI, API, library, web app, etc.
3. **Key concerns** — the 3-6 major responsibility areas that become packages
4. **Storage needs** — file system, database, in-memory
5. **External integrations** — APIs, auth systems, message queues
6. **Source codebase** (if any) — path to existing repo for domain model extraction
7. **Architectural decisions already made** — constraints to respect, not rediscover

If the requirements doc references a source codebase (e.g., "porting from
~/code/myproject/"), read the relevant source files to understand the domain
model before designing the architecture. The requirements doc should list
specific files or directories to analyze.

Use the requirements to identify the major concerns that become packages/modules.
Aim for 3-6 concerns: fewer means nothing to parallelize, more means
over-engineering a bootstrap.

## Architecture Design Principles

Design for disjoint ownership before writing a line of code:

1. **One concern = one module/crate/package/directory.** Each major
   responsibility lives in isolation. No module reaches into another's internals.

   Go:
   ```
   cmd/             ← Entry point (CLI wiring)
   internal/
     app/           ← Business logic
     store/         ← Storage/persistence
     output/        ← Formatting/display
     types/         ← Shared interfaces and types (Scaffold Agent)
   ```

   Rust (workspace):
   ```
   src/main.rs      ← Entry point (CLI wiring)
   crates/
     app/           ← Business logic
     store/         ← Storage/persistence
     output/        ← Formatting/display
     types/         ← Shared traits and types (Scaffold Agent)
   Cargo.toml       ← ORCHESTRATOR OWNED - do not touch in agent prompts
   ```

   TypeScript / Python: equivalent `src/` subdirectories per concern.

   **Rust workspace rule:** The root `Cargo.toml` `[workspace] members` list is
   a single file that every Wave 1 agent needs to modify (to register their
   crate). This is a guaranteed conflict if agents touch it directly. Declare
   it **orchestrator-owned**: exclude it from every agent's file ownership list,
   and have the orchestrator add all crates to the workspace after the Scout
   phase completes and before Wave 1 launches.

   Agent prompts for Rust bootstrap must include an explicit constraint:
   > "Do not modify the root `Cargo.toml`. The orchestrator will register your
   > crate in the workspace members list before you launch."

   The orchestrator's pre-Wave-1 step:
   ```bash
   # Add all Wave 1 crates to workspace before launching agents
   # Edit Cargo.toml members = ["crates/types", "crates/app", "crates/store", ...]
   ```

2. **Shared types as foundation.** All shared interfaces, traits, and structs
   live in a types module/crate that no other module *defines*; only
   implements. This creates a stable contract layer all agents implement against
   independently. In Go this is `internal/types`; in Rust this is a `types`
   workspace crate; in TypeScript this is a `types.ts` or `types/` directory.

3. **No god files.** Avoid files that everything imports. If something is needed
   everywhere, it belongs in the types layer. If two places need the same thing,
   extract an interface or trait, don't share a concrete implementation.

4. **Tests alongside implementations.** Each module has its own test files.
   Agents run focused tests without touching other modules.

## Scout Types Phase (Always Required)

Bootstrap projects always require shared contracts before any agent starts.
The Scout defines these contracts in the manifest's `scaffolds` section. The
Scaffold Agent creates the scaffold source files after human review.

**Scout defines the types scaffold in the manifest:**
- Specifies file location: Go: `internal/types/`, Rust: `crates/types/`,
  TS: `src/types/`, Python: `src/types.py`
- Lists all interfaces/traits that cross module boundaries
- Lists all shared structs, enums, error types with exact signatures
- No source files created at this stage — specification only

**Scaffold Agent creates the types scaffold (after human review):**
- Reads the approved Scaffolds section from `docs/IMPL/IMPL-bootstrap.yaml`
- Creates the scaffold source files with the specified types
- No implementation — interfaces, traits, and types only
- Verifies the scaffold compiles, then commits to HEAD
- Wave 1 agents must have a compiling types module to build against

**Why Scaffold Agent, not Scout:** The Scout's job is analysis and planning.
Producing source files is implementation work that benefits from a human review
gate: the user approves the interface contracts in the IMPL doc before any code
is written. The Scaffold Agent materializes the approved contracts. This
restores the same structural checkpoint that Wave 0 previously provided
(human review of interface contracts before any implementation), without the
overhead of full wave machinery.

## Wave 1+ Pattern

After types exist, Wave 1 agents are truly parallel:
- Each agent implements exactly one module/crate against the typed contracts
- Agents create compilable stubs (internals may be TODO, but signatures match contracts)
- Each agent writes at least one passing test per interface/trait method
- No agent touches another agent's directory

Wave 2 wires everything together (entry point, dependency injection, main function).
This is inherently integrative work and may have only one or two agents.

## Output Format

Write `docs/IMPL/IMPL-bootstrap.yaml`:

```yaml
# IMPL: bootstrap
title: "<Project Name> Bootstrap"
feature_slug: "bootstrap"
verdict: "SUITABLE"
test_command: "<full test suite command>"
lint_command: "<check-mode lint command or 'none'>"
state: "SCOUT_PENDING"

# Project Architecture (bootstrap-specific metadata)
project:
  language: "<language>"
  type: "<CLI | API | library | worker | web app>"
  concerns:
    - "<concern 1>"
    - "<concern 2>"
    - "<concern 3>"
  package_structure: |
    cmd/             <- Entry point (CLI wiring)
    internal/
      types/         <- Shared interfaces and types (Scaffold Agent)
      app/           <- Business logic
      store/         <- Storage/persistence

# Quality Gates
quality_gates:
  level: "standard"
  gates:
    - type: "build"
      command: "<e.g. go build ./...>"
      required: true
    - type: "test"
      command: "<e.g. go test ./...>"
      required: true
    - type: "lint"
      command: "<e.g. go vet ./...>"
      required: false

# Scaffolds (bootstrap always has a types scaffold)
scaffolds:
  - file_path: "path/to/types.go"
    contents: |
      package types

      // Exact interfaces, structs, enums — binding contracts
      type FooInterface interface {
        DoThing() error
      }
    import_path: "module/path/types"
    status: "pending"

# Interface Contracts
interface_contracts:
  - name: "FooInterface"
    description: "Cross-package boundary contract"
    definition: |
      type FooInterface interface {
        DoThing(ctx context.Context) error
      }
    location: "path/to/types.go"

# File Ownership (I1: disjoint within waves)
file_ownership:
  - file: "internal/types/types.go"
    agent: "scaffold"
    wave: 0
    action: "new"
  - file: "internal/app/app.go"
    agent: "B"
    wave: 1
    action: "new"
  - file: "internal/store/store.go"
    agent: "C"
    wave: 1
    action: "new"
  - file: "cmd/main.go"
    agent: "A"
    wave: 2
    action: "new"
    depends_on: ["B", "C"]

# Waves
waves:
  - number: 1
    agents:
      - id: "B"
        task: |
          ## What to Implement
          <Module description — implements against types scaffold>

          ## Interfaces to Implement
          <Exact signatures this agent delivers>

          ## Interfaces to Call
          <Types from scaffold this agent depends on>

          ## Tests to Write
          1. TestFunctionName_Scenario - what it verifies

          ## Verification Gate
          go build ./internal/app && go test ./internal/app

          ## Constraints
          <Hard rules, edge cases, things to avoid>
        files:
          - "internal/app/app.go"
          - "internal/app/app_test.go"
      - id: "C"
        task: |
          <Implementation spec for agent C — same structure as above>
        files:
          - "internal/store/store.go"
          - "internal/store/store_test.go"
  - number: 2
    agents:
      - id: "A"
        task: |
          <Entry point wiring — wire all packages together, integration test>
        files:
          - "cmd/main.go"
        dependencies: ["B", "C"]

# Pre-Mortem
pre_mortem:
  overall_risk: "low"
  rows:
    - scenario: "Scaffold compilation fails (wrong import path or missing dependency)"
      likelihood: "low"
      impact: "high"
      mitigation: "Scaffold Agent runs go build before committing; fix reported before Wave 1 launches"
    - scenario: "Wave 2 wiring agent has implicit dependency on Wave 1 internals not in interface contracts"
      likelihood: "medium"
      impact: "medium"
      mitigation: "Add required internals to contracts during review; agents must not access unexported symbols"

# Known Issues (omit if none)
known_issues: []

# Completion Reports (empty at scout time — agents populate via saw set-completion)
completion_reports: {}
```

**Agent task field:** The `task` field per agent is a multi-line string containing
the implementation specification (Fields 2-7). Include: what to implement, interfaces
to implement and call, tests to write, verification gate commands, and constraints.
The orchestrator wraps this with the 9-field agent template (isolation verification,
file ownership, completion report format) at launch time via `saw extract-context`.

**Self-validation (mandatory):** After writing the manifest, run:
```bash
sawtools validate --fix "<absolute-path-to-impl-doc>"
```
If exit code is 1, read the JSON errors and fix only the failing fields. Re-run
validation until it passes (max 3 attempts). If all 3 attempts fail, set
`state: "SCOUT_VALIDATION_FAILED"` and report remaining errors in your final output.
The orchestrator also validates as defense-in-depth.

## Rules

- You may create one artifact: the IMPL manifest at `docs/IMPL/IMPL-bootstrap.yaml`. Do not create, modify, or delete any source files. Specify scaffold file contents in the manifest Scaffolds section — the Scaffold Agent will create them after human review.
- Every interface you define is a binding contract. Wave 1 agents implement
  against these without seeing each other's code.
- The Scout must specify a types scaffold in the manifest Scaffolds section. Do not skip it even if
  interfaces seem obvious; it creates the foundation all agents depend on. The Scaffold Agent will
  create the source files after human review.
- Prefer more packages with smaller scopes over fewer with larger ones.
  An agent owning 1-3 files is ideal.
- Design for the project's actual current needs, not hypothetical future ones.
  A CLI tool with 3 concerns needs 3 packages, not 8.
- If fewer than 3 concerns are identified, flag as NOT SUITABLE and recommend
  sequential implementation or a redesign that produces more separable concerns.
- After writing the manifest, self-validate via `sawtools validate --fix` (see
  Output Format above). If the orchestrator returns additional errors as
  defense-in-depth, fix only the failing fields — do not regenerate the entire
  manifest.
