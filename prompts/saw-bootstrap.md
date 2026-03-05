<!-- saw-bootstrap v0.3.3 -->
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

## Pre-Flight: Ensure Git Repo Exists

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

This costs nothing and prevents bootstrap from failing silently mid-execution
when agents try to create worktrees or branches.

## Phase 0: Gather Requirements

Before designing anything, ask the user:

1. **Language + ecosystem:** Go? Python? TypeScript? Determines package/module
   structure conventions.
2. **Project type:** CLI tool? REST API? Library? Background worker?
3. **Key concerns:** What are the 3-5 major responsibilities?
   (e.g., "CLI parsing, business logic, storage, output formatting")
4. **Storage needs:** File system? Database? In-memory only?
5. **External integrations:** APIs, auth systems, message queues?

Use the answers to identify the major concerns that become packages/modules.
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
The Scout defines these contracts in the IMPL doc Scaffolds section. The
Scaffold Agent creates the scaffold source files after human review.

**Scout defines the types scaffold in the IMPL doc:**
- Specifies file location: Go: `internal/types/`, Rust: `crates/types/`,
  TS: `src/types/`, Python: `src/types.py`
- Lists all interfaces/traits that cross module boundaries
- Lists all shared structs, enums, error types with exact signatures
- No source files created at this stage — specification only

**Scaffold Agent creates the types scaffold (after human review):**
- Reads the approved Scaffolds section from `docs/IMPL/IMPL-bootstrap.md`
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

Write `docs/IMPL/IMPL-bootstrap.md`:

```markdown
### Project Architecture

**Language:** [language]
**Project type:** [CLI / API / library / worker]
**Key concerns:** [comma-separated list]

### Package Structure

[Directory tree with one-line description per package]

### Suitability Assessment

Verdict: SUITABLE

[One paragraph: N concerns identified, clean seams at [boundary descriptions].
Scout specifies types scaffold in IMPL doc; Scaffold Agent creates source files after human review.]

Estimated times:
- Design phase: ~X min (this scout)
- Wave 1 (parallel): ~Z min (N agents × M min, fully parallel)
- Wave 2 (wiring): ~W min
Total: ~T min

Sequential baseline: ~B min
Time savings: ~D min (P% faster/slower)

### Interface Contracts

[Exact, language-native, fully typed signatures for every cross-package boundary.
No pseudocode. These are binding contracts.]

### File Ownership

| File | Agent | Wave | Depends On |
|------|-------|------|------------|

### Scaffolds

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [list exact types, interfaces, structs] | `module/path/types` | pending |

### Wave Structure

Scaffold Agent: [Types scaffold] - shared interfaces and types (created after human review)
              | (types package compiles cleanly)
Wave 1: [B][C][D]      - package implementations (parallel)
              | (all packages build, unit tests pass)
Wave 2: [A]            - entry point wiring and integration

### Agent Prompts

[Full 9-field prompt for each agent.]
[Wave 1 agents: implement against Scaffold Agent-produced type contracts, stub internals are fine.]
[Wave 2 agent: wire packages together, write integration test.]

### Verification Gates

Scaffold Agent: [build types module only, e.g., `go build ./internal/types` or `cargo build -p types`]
Wave 1: [build all modules] + [focused unit tests per module]
Wave 2: [build full project] + [full test suite]

### Status

- [ ] Scaffold Agent: Types scaffold - [description]
- [ ] Wave 1 Agent B - [package: description]
- [ ] Wave 1 Agent C - [package: description]
- [ ] Wave 1 Agent D - [package: description]
- [ ] Wave 2 Agent A - [entry point wiring]
```

## Rules

- You may create one artifact: the IMPL doc at `docs/IMPL/IMPL-bootstrap.md`. Do not create, modify, or delete any source files. Specify scaffold file contents in the IMPL doc Scaffolds section — the Scaffold Agent will create them after human review.
- Every interface you define is a binding contract. Wave 1 agents implement
  against these without seeing each other's code.
- The Scout must specify a types scaffold in the IMPL doc Scaffolds section. Do not skip it even if
  interfaces seem obvious; it creates the foundation all agents depend on. The Scaffold Agent will
  create the source files after human review.
- Prefer more packages with smaller scopes over fewer with larger ones.
  An agent owning 1-3 files is ideal.
- Design for the project's actual current needs, not hypothetical future ones.
  A CLI tool with 3 concerns needs 3 packages, not 8.
- If fewer than 3 concerns are identified, flag as NOT SUITABLE and recommend
  sequential implementation or a redesign that produces more separable concerns.
