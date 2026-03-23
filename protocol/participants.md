# Protocol Participants

SAW has seven participant roles. All seven are agents (AI model instances running with tool access). They differ only in execution mode and responsibility.

## Orchestrator

**Execution mode:** Synchronous

**Responsibilities:**

The synchronous agent running in the user's own interactive session. Drives all protocol state transitions: reads the IMPL doc, creates worktrees, launches scouts and wave agents, waits for completion notifications, reads completion reports, executes the merge procedure, verifies the merged result, and advances state. The orchestrator serializes all state changes; it is the single-threaded coordinator that processes completion events and decides what runs next.

**IMPL doc validation (E16):** After the Scout writes the IMPL doc, the Orchestrator runs a deterministic validator on all `type=impl-*` typed-block sections before entering REVIEWED state. If validation fails, the Orchestrator issues a correction prompt to the Scout listing specific errors by section and block. The Orchestrator loops (up to the E16 retry limit) until the doc passes or retry limit is exhausted. On exhaustion, the Orchestrator enters BLOCKED and surfaces the errors to the human. The validator is a protocol-level tool, not an implementation detail — it is part of the Orchestrator's required capabilities.

The only participant that interacts with the human directly. All progress reporting, decision points, approval requests, and error escalation flow through the orchestrator; asynchronous agents never surface information to the human except through the orchestrator's completion handling.

**Repository context responsibility:** When launching any agent (Scout, Scaffold Agent, Wave Agent), the Orchestrator must provide the absolute path to the IMPL doc in the agent's launch parameters. Agents derive the repository root from this path (the directory containing `docs/`). This prevents multi-repository session ambiguity where the session working directory differs from the feature's repository. Relative IMPL doc paths or omitting the path entirely will cause agents to default to the session's working directory, leading to wrong-repository failures.

**Cross-repository orchestration:** The Orchestrator supports two modes:

*Single-repo mode (default):* Orchestrator and all agents work in the same repository. All five isolation layers (E4) are available, including Layer 2 (`isolation: "worktree"`).

*Cross-repo mode:* Agents work in two or more repositories simultaneously. This is supported but requires modified isolation procedure:
- **Omit Layer 2** (`isolation: "worktree"`) for all agents — it would create worktrees in the Orchestrator's repo context, not the target repos. Omitting it is intentional.
- **Apply Layer 1 manually in each target repo** — Orchestrator creates worktrees in each repo before launching any agents (see `saw-worktree.md` Cross-Repo Mode).
- **Layer 0 in each repo** — Pre-commit guard installed in each repo's `.git/hooks/`.
- **Layer 3 unchanged** — Field 0 navigates to the correct repo+worktree via absolute path.
- **Layer 4 per-repo** — Merge-time trip wire runs in each repo independently.
- The IMPL doc file ownership table must include a `Repo` column.
- Merge runs independently in each repo; there is no cross-repo merge operation.

The Orchestrator always provides absolute IMPL doc paths to agents so they can derive repository roots unambiguously, regardless of mode.

Running in the user's session is what makes human checkpoints enforceable. A background orchestrator would have no interactive session to deliver mandatory approvals to. The human is not a separate role; they are present through the orchestrator's session.

Not all checkpoints require human input. The suitability gate and the REVIEWED state (plan review before the first wave) always require explicit approval. Inter-wave checkpoints are optional and can be automated via automation flags. Failures and BLOCKED states always surface to the human regardless of automation mode. The orchestrator being synchronous means the human can intervene at any moment; which specific stops are mandatory is a separate question from whether intervention is possible at all.

**Forbidden actions (Invariant I6 - Role Separation):**

The orchestrator must not implement feature logic itself. All source file modifications (except orchestrator-owned append-only files) must be delegated to wave agents. The orchestrator's role is coordination, not implementation. This separation ensures:
- All feature work is parallelizable (orchestrator is serial by definition)
- Completion reports accurately reflect which agent made which changes
- Merge conflicts are impossible (orchestrator doesn't compete with agents for file ownership)

The orchestrator may modify orchestrator-owned files (append-only shared files like config registries) post-merge, but must not touch any file in any agent's ownership list.

At program scope, the orchestrator launches the Planner role to analyze requirements and produce the PROGRAM manifest. The Planner operates at project scope, identifying feature boundaries and cross-feature dependencies, while Scouts operate at feature scope within individual IMPLs.

**Required capabilities:**

- Read source files and documentation
- Write IMPL docs and completion reports
- Execute git commands (branch, worktree, merge, commit)
- Launch asynchronous agents with specified prompts
- Wait for completion notifications from background agents
- Parse structured messages (completion reports, agent prompts)
- Run IMPL doc validator on typed-block sections and issue correction prompts to Scout (E16)

## Scout

**Execution mode:** Asynchronous

**Responsibilities:**

An asynchronous agent launched by the orchestrator. Analyzes the codebase, produces the IMPL doc, and exits. Defines all interface contracts and specifies any required scaffold files in the IMPL doc Scaffolds section — but does not create source files. Never modifies existing source files. Never participates in wave execution. The orchestrator waits for the scout's completion notification before entering REVIEWED state.

**Required capabilities:**

- Read source files and documentation
- Analyze codebase structure and dependencies
- Write IMPL docs with structured sections (suitability, scaffolds, dependency graph, agent assignments)
- Execute read-only commands (grep, find, list directories)
- Parse build configuration files and test frameworks

**Forbidden actions:**

- Modify any source files
- Create scaffold files (delegated to Scaffold Agent)
- Execute build or test commands that modify state
- Launch other agents
- Participate in wave execution

## Scaffold Agent

**Execution mode:** Asynchronous

**Responsibilities:**

An asynchronous agent launched by the orchestrator after human review of the IMPL doc. Reads the approved interface contracts and Scaffolds section from the IMPL doc, creates the specified type scaffold files (shared interfaces, traits, structs — no behavior), verifies they compile, and commits them to HEAD. Runs once, before the first wave — Invariant I3 (interface freeze) guarantees all cross-agent types are known at REVIEWED, so there is nothing new to scaffold between waves. Runs only when the IMPL doc Scaffolds section is non-empty. Never modifies existing source files. Exits after committing and updating the Scaffolds section status. The orchestrator waits for the Scaffold Agent before creating worktrees.

**Required capabilities:**

- Read IMPL docs (Scaffolds section and interface contracts)
- Write new source files (type definitions, interfaces, traits)
- Execute build commands to verify compilation
- Execute git commands (add, commit)
- Update IMPL doc Scaffolds section status

**Forbidden actions:**

- Modify existing source files
- Implement behavior (only type scaffolds allowed)
- Create files not listed in IMPL doc Scaffolds section
- Launch other agents
- Participate in wave execution

## Wave Agent

**Execution mode:** Asynchronous

**Responsibilities:**

An asynchronous agent launched by the orchestrator. Owns a disjoint set of files, implements against the interface contracts defined in the IMPL doc, runs the verification gate, commits its work, and writes a structured completion report to the IMPL doc. Multiple wave agents run concurrently within a wave. Wave agents never coordinate directly with each other; the IMPL doc is the only coordination surface. The orchestrator collects all completion notifications before advancing to WAVE_MERGING.

**Required capabilities:**

- Read source files (own files + dependency files from prior waves)
- Write source files (only owned files)
- Execute build and test commands (verification gate)
- Execute git commands (add, commit) in isolated worktree
- Parse IMPL docs (interface contracts, dependency information)
- Write structured completion reports

**Forbidden actions:**

- Modify files not in ownership list (Invariant I1 - disjoint file ownership)
- Coordinate directly with other wave agents (use IMPL doc instead)
- Modify interface contracts after REVIEWED state (Invariant I2 - interface freeze)
- Launch other agents
- Merge changes to HEAD (delegated to Orchestrator)

## Integration Agent

**Execution mode:** Asynchronous (serial, after wave agents)

**Responsibilities:**

An asynchronous agent launched by the orchestrator after wave agents complete and merge succeeds. Reads the `IntegrationReport` produced by E25 (Integration Validation), reads completion reports from wave agents, and modifies `integration_connectors` files to wire new exports into caller code. Runs on the main branch (no worktree) because it operates on the merged result. Exits after wiring gaps and verifying the build passes.

The Integration Agent is the only participant that runs after merge but before the next wave starts. It bridges the gap between wave agents producing new exports and the existing codebase consuming them. Its scope is strictly limited to wiring — it does not implement new features or modify agent-owned code.

**Constraint role:** `integrator`

The `integrator` constraint restricts the Integration Agent to files listed in the IMPL manifest's `integration_connectors` field. This is enforced mechanically via `AllowedPathPrefixes`, not by agent cooperation.

**Required capabilities:**

- Read source files (merged codebase, completion reports, IntegrationReport)
- Write source files (only `integration_connectors` files)
- Execute build commands (verification gate: `go build ./...`)
- Execute git commands (add, commit) on the main branch
- Parse IMPL docs (integration_connectors, completion reports)

**Forbidden actions:**

- Modify agent-owned files (files listed in any agent's ownership table)
- Modify scaffold files
- Modify files not listed in `integration_connectors`
- Launch other agents
- Implement new features (wiring only — connecting existing exports to existing callers)

**Launches:** After wave merge + E21 verification + E25 integration validation, before the next wave starts.

**Failure behavior:** Non-fatal. If the Integration Agent fails, gaps are reported to the human via the orchestrator. The pipeline does not block.

**Related Rules:** See E25 (Integration Validation), E26 (Integration Agent), I1 Amendment (Integration Agent Exemption)

## Critic Agent

**Execution mode:** Asynchronous

**Responsibilities:**

An asynchronous agent launched by the orchestrator after IMPL doc validation (E16)
and before REVIEWED state (E37). Reads every agent brief in the IMPL doc, reads
every source file in the file_ownership table, and verifies briefs against the
actual codebase. Produces a structured CriticResult with per-agent verdicts and
an overall PASS/ISSUES decision. Writes the result to the IMPL doc critic_report
field using WriteCriticReview. Never modifies source files. Exits after writing
the review.

The critic closes the gap between schema validation (E16, which checks structure)
and human review (which checks intent). It catches semantic errors: wrong function
names, missing files, patterns that do not exist as described, interfaces incompatible
with existing types, and missing registration wiring.

**Required capabilities:**
- Read IMPL docs and source files
- Execute read-only commands (grep, find, list directories)
- Write structured review results to IMPL doc (WriteCriticReview)
- Parse Go/TypeScript/Markdown source files
- Skip existence checks for files marked `action: new` in file_ownership (files will be created by agents, not errors)

**Forbidden actions:**
- Modify any source files
- Modify IMPL doc fields other than critic_report
- Launch other agents
- Participate in wave execution
- Apply corrections to briefs (correction is orchestrator's responsibility)

## Planner

**Execution mode:** Asynchronous

**Responsibilities:**

An asynchronous agent launched by the orchestrator at program scope. Analyzes REQUIREMENTS.md and the existing codebase, identifies feature boundaries, defines cross-feature dependencies and program contracts, produces the PROGRAM manifest. Functions as a "super-Scout" at project scope rather than feature scope — where the Scout analyzes a single feature and produces an IMPL doc, the Planner analyzes the entire project and produces a PROGRAM manifest that coordinates multiple IMPL docs into tiered execution.

The Planner identifies which features can execute in parallel (same tier) and which must execute sequentially (dependencies across tiers). It defines program-level interface contracts that span multiple features, ensuring that IMPLs can depend on each other's outputs without circular dependencies. The Planner runs a program-level suitability assessment to determine if the requirements can be decomposed into parallelizable features under SAW constraints.

**Required capabilities:**

- Read REQUIREMENTS.md and source files
- Analyze project structure and identify feature boundaries
- Identify cross-feature dependencies and execution order constraints
- Define program contracts (cross-IMPL interface contracts)
- Produce PROGRAM manifest with tier structure, IMPL listings, and contracts
- Run program-level suitability assessment (determine if requirements fit SAW execution model)

**Forbidden actions:**

- Write IMPL docs (delegated to Scout agents for each feature)
- Write source code (delegated to Wave Agents)
- Launch agents (delegated to Orchestrator)
- Modify existing source files

## Correctness Rationale

The protocol's correctness guarantees flow from this structure: the synchronous orchestrator serializes all state transitions while asynchronous agents execute in parallel. Agents can run concurrently precisely because they never write to shared state; only the orchestrator does. The Integration Agent extends this model by running serially after merge — it is the only writer at its execution time, preserving the single-writer guarantee without worktree isolation.

**Key architectural constraints:**

1. **Only orchestrator writes to HEAD.** Wave agents commit to isolated worktrees; orchestrator merges.
2. **Only orchestrator advances protocol state.** Agents report completion; orchestrator decides next state.
3. **Only orchestrator handles failures.** Agents report status (blocked/partial/complete); orchestrator escalates.
4. **Agents never coordinate peer-to-peer.** All coordination flows through IMPL doc + orchestrator.

These constraints enable safe parallelism without distributed coordination protocols.
