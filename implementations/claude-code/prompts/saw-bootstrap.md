<!-- saw-bootstrap v0.3.4 -->
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
## Project Architecture

**Language:** [language]
**Project type:** [CLI / API / library / worker]
**Key concerns:** [comma-separated list]

## Package Structure

[Directory tree with one-line description per package]

## Suitability Assessment

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

## Quality Gates

level: standard

gates:
  - type: test
    command: [e.g. go test ./... | npm test | cargo test | pytest]
    required: true
  - type: lint
    command: [e.g. golangci-lint run | cargo clippy | ruff check .]
    required: false

## Scaffolds

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [list exact types, interfaces, structs] | `module/path/types` | pending |

## Pre-Mortem

**Overall risk:** low | medium | high

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Scaffold compilation fails (wrong import path or missing dependency) | low | high | Scaffold Agent runs go build before committing; fix reported before Wave 1 launches |
| Wave 2 wiring agent has implicit dependency on Wave 1 internals not in interface contracts | medium | medium | Add required internals to contracts during review; agents must not access unexported symbols |

## Known Issues

[Optional. Document any known risks or ambiguities discovered during analysis
that do not rise to Pre-Mortem level but should be tracked. Format:
`- {issue}: {mitigation or note}`. Omit if none.]

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (N parallel agents — package implementations):
    [B] path/to/module
         Implements [module] against types scaffold.
         ✓ root (no dependencies on other agents)

    [C] path/to/module
         Implements [module] against types scaffold.
         ✓ root (no dependencies on other agents)

Wave 2 (1 agent — entry point wiring):
    [A] cmd/main.go
         Wires all packages together.
         depends on: [B] [C] [D]
```

## Interface Contracts

[Exact, language-native, fully typed signatures for every cross-package boundary.
No pseudocode. These are binding contracts.]

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| path/to/file | B | 1 | — |
```

## Wave Structure

```yaml type=impl-wave-structure
Scaffold Agent: [Types scaffold]
              | (types package compiles cleanly)
Wave 1: [B] [C] [D]    <- N parallel agents (package implementations)
              | (all packages build, unit tests pass)
Wave 2: [A]            <- 1 agent (entry point wiring and integration)
```

## Wave 1

[Wave-level introduction: what this wave delivers. Each Wave 1 agent implements one module/crate against the Scaffold Agent-produced type contracts. Stub internals are fine; signatures must match contracts.]

### Agent B - {Module description}

[Full 9-field prompt.]

### Agent C - {Module description}

[Full 9-field prompt.]

### Agent D - {Module description}

[Full 9-field prompt.]

## Wave 2

[What this wave delivers: entry point wiring and integration. Wire packages together, write integration test.]

### Agent A - Entry point wiring

[Full 9-field prompt.]

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

## Wave Execution Loop

After each wave completes, work through the Orchestrator Post-Merge Checklist
below. The merge procedure detail is in `saw-merge.md`. Key principles:
- Read completion reports first — a `status: partial` or `status: blocked` blocks
  the merge entirely. No partial merges.
- Post-merge verification is the real gate. Agents pass in isolation; the merged
  codebase surfaces cross-package failures none of them saw individually.

## Orchestrator Post-Merge Checklist

After each wave completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any
      `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists
- [ ] Review `interface_deviations` — update downstream agent prompts for any
      item with `downstream_action_required: true`
- [ ] Run E20 stub scan: `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" {files}`
      Append output to IMPL doc under `## Stub Report — Wave {N}`
- [ ] Run E21 quality gates (if `## Quality Gates` section present)
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave{N}-agent-{X}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification: `[build + test command from Verification Gates]`
- [ ] Fix any cascade failures
- [ ] Tick status checkboxes in this IMPL doc
- [ ] Feature-specific steps:
      - [ ] Register new crate in root `Cargo.toml` members (Rust only)
- [ ] Commit: `git commit -m "[wave N merge message]"`
- [ ] Launch next wave (or pause for review)
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
- After writing the IMPL doc, expect validation feedback (E16). If the
  orchestrator returns errors for typed-block sections (`impl-file-ownership`,
  `impl-dep-graph`, `impl-wave-structure`), rewrite only the failing sections.
  Do not regenerate the entire document.
