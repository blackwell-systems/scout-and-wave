<!-- saw-bootstrap v0.3.0 -->
# SAW Bootstrap: Design-First Project Architecture

Use this mode when starting a new project from scratch with no existing codebase.
The bootstrap scout acts as **architect**, not analyst — designing disjoint file
ownership before any code is written.

## When to Use

- Starting a new project from an empty or near-empty repo
- No existing codebase for the scout to analyze
- Want SAW-compatible structure from day one

## When NOT to Use

- Existing codebase with features to add (use `/saw scout` instead)
- Single-file or trivially small projects
- Prototypes where structure doesn't matter yet

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
Aim for 3-6 concerns — fewer means nothing to parallelize, more means
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
     types/         ← Shared interfaces and types (Wave 0)
   ```

   Rust (workspace):
   ```
   src/main.rs      ← Entry point (CLI wiring)
   crates/
     app/           ← Business logic
     store/         ← Storage/persistence
     output/        ← Formatting/display
     types/         ← Shared traits and types (Wave 0)
   ```

   TypeScript / Python: equivalent `src/` subdirectories per concern.

2. **Shared types as foundation.** All shared interfaces, traits, and structs
   live in a types module/crate that no other module *defines* — only
   implements. This creates a stable contract layer all agents implement against
   independently. In Go this is `internal/types`; in Rust this is a `types`
   workspace crate; in TypeScript this is a `types.ts` or `types/` directory.

3. **No god files.** Avoid files that everything imports. If something is needed
   everywhere, it belongs in the types layer. If two places need the same thing,
   extract an interface or trait, don't share a concrete implementation.

4. **Tests alongside implementations.** Each module has its own test files.
   Agents run focused tests without touching other modules.

## Wave 0 Pattern (Always Required)

Bootstrap projects always start with a types wave because all other agents
depend on shared contracts.

**Wave 0:** Single agent, not parallel.
- Creates the shared types module (Go: `internal/types/`, Rust: `crates/types/`,
  TS: `src/types/`, Python: `src/types.py`)
- Defines all interfaces/traits that cross module boundaries
- Defines shared structs, enums, error types
- No implementation — interfaces, traits, and types only

**Why solo:** Wave 1+ agents implement against these definitions. You cannot
parallelize against contracts that don't exist yet.

**Post-Wave 0 gate:** Build the types module only. Must pass before Wave 1 launches.

## Wave 1+ Pattern

After types exist, Wave 1 agents are truly parallel:
- Each agent implements exactly one module/crate against the typed contracts
- Agents create compilable stubs (internals may be TODO, but signatures match contracts)
- Each agent writes at least one passing test per interface/trait method
- No agent touches another agent's directory

Wave 2 wires everything together (entry point, dependency injection, main function).
This is often a single solo agent since it's inherently integrative.

## Output Format

Write `docs/IMPL-bootstrap.md`:

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
Wave 0 required because [all agents depend on shared types].]

Estimated times:
- Design phase: ~X min (this scout)
- Wave 0 (types): ~Y min (single agent, defines contracts)
- Wave 1 (parallel): ~Z min (N agents × M min, fully parallel)
- Wave 2 (wiring): ~W min (single agent)
Total: ~T min

Sequential baseline: ~B min
Time savings: ~D min (P% faster/slower)

### Interface Contracts

[Exact, language-native, fully typed signatures for every cross-package boundary.
No pseudocode. These are binding contracts.]

### File Ownership

| File | Agent | Wave | Depends On |
|------|-------|------|------------|

### Wave Structure

Wave 0: [Types]        — shared interfaces and types (prerequisite)
              | (types package compiles cleanly)
Wave 1: [B][C][D]     — package implementations (parallel)
              | (all packages build, unit tests pass)
Wave 2: [A]            — entry point wiring and integration

### Agent Prompts

[Full 8-field prompt for each agent.]
[Wave 0 agent: create types only, zero implementation.]
[Wave 1 agents: implement against Wave 0 contracts, stub internals are fine.]
[Wave 2 agent: wire packages together, write integration test.]

### Verification Gates

Wave 0: [build types module only — e.g., `go build ./internal/types` or `cargo build -p types`]
Wave 1: [build all modules] + [focused unit tests per module]
Wave 2: [build full project] + [full test suite]

### Status

- [ ] Wave 0: Types — [description]
- [ ] Wave 1 Agent B — [package: description]
- [ ] Wave 1 Agent C — [package: description]
- [ ] Wave 1 Agent D — [package: description]
- [ ] Wave 2 Agent A — [entry point wiring]
```

## Rules

- Do not write any source code. Write only `docs/IMPL-bootstrap.md`.
- Every interface you define is a binding contract. Wave 1 agents implement
  against these without seeing each other's code.
- Wave 0 is mandatory. Do not skip it even if interfaces seem obvious — it
  creates the foundation all other agents depend on.
- Prefer more packages with smaller scopes over fewer with larger ones.
  An agent owning 1-3 files is ideal.
- Design for the project's actual current needs, not hypothetical future ones.
  A CLI tool with 3 concerns needs 3 packages, not 8.
- If fewer than 3 concerns are identified, flag as SUITABLE WITH CAVEATS and
  recommend saw-quick mode or sequential implementation instead.
