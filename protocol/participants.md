# Protocol Participants

SAW has four participant roles. All four are agents (AI model instances running with tool access). They differ only in execution mode and responsibility.

## Orchestrator

**Execution mode:** Synchronous

**Responsibilities:**

The synchronous agent running in the user's own interactive session. Drives all protocol state transitions: reads the IMPL doc, creates worktrees, launches scouts and wave agents, waits for completion notifications, reads completion reports, executes the merge procedure, verifies the merged result, and advances state. The orchestrator serializes all state changes; it is the single-threaded coordinator that processes completion events and decides what runs next.

The only participant that interacts with the human directly. All progress reporting, decision points, approval requests, and error escalation flow through the orchestrator; asynchronous agents never surface information to the human except through the orchestrator's completion handling.

**Repository context responsibility:** When launching any agent (Scout, Scaffold Agent, Wave Agent), the Orchestrator must provide the absolute path to the IMPL doc in the agent's launch parameters. Agents derive the repository root from this path (the directory containing `docs/`). This prevents multi-repository session ambiguity where the session working directory differs from the feature's repository. Relative IMPL doc paths or omitting the path entirely will cause agents to default to the session's working directory, leading to wrong-repository failures.

**Cross-repository orchestration limitation:** The orchestrator and target repository must be the same. When the orchestrator runs from repository A but needs to coordinate work in repository B, worktree isolation mechanisms fail: runtime isolation parameters (e.g., `isolation: "worktree"`) create worktrees relative to the orchestrator's repository context (A), not the target repository (B). Manually-created worktrees in B cannot be used because agents spawn in A's context. Field 0 verification will correctly detect and block this mismatch. To orchestrate work in repository B, the orchestrator must run from B's working directory. This is an architectural constraint, not a fixable bug.

Running in the user's session is what makes human checkpoints enforceable. A background orchestrator would have no interactive session to deliver mandatory approvals to. The human is not a separate role; they are present through the orchestrator's session.

Not all checkpoints require human input. The suitability gate and the REVIEWED state (plan review before the first wave) always require explicit approval. Inter-wave checkpoints are optional and can be automated via automation flags. Failures and BLOCKED states always surface to the human regardless of automation mode. The orchestrator being synchronous means the human can intervene at any moment; which specific stops are mandatory is a separate question from whether intervention is possible at all.

**Forbidden actions (Invariant I6 - Role Separation):**

The orchestrator must not implement feature logic itself. All source file modifications (except orchestrator-owned append-only files) must be delegated to wave agents. The orchestrator's role is coordination, not implementation. This separation ensures:
- All feature work is parallelizable (orchestrator is serial by definition)
- Completion reports accurately reflect which agent made which changes
- Merge conflicts are impossible (orchestrator doesn't compete with agents for file ownership)

The orchestrator may modify orchestrator-owned files (append-only shared files like config registries) post-merge, but must not touch any file in any agent's ownership list.

**Required capabilities:**

- Read source files and documentation
- Write IMPL docs and completion reports
- Execute git commands (branch, worktree, merge, commit)
- Launch asynchronous agents with specified prompts
- Wait for completion notifications from background agents
- Parse structured messages (completion reports, agent prompts)

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

- Modify files not in ownership list (Invariant I2 - disjoint file ownership)
- Coordinate directly with other wave agents (use IMPL doc instead)
- Modify interface contracts after REVIEWED state (Invariant I3 - interface freeze)
- Launch other agents
- Merge changes to HEAD (delegated to Orchestrator)

## Correctness Rationale

The protocol's correctness guarantees flow from this structure: the synchronous orchestrator serializes all state transitions while asynchronous agents execute in parallel. Agents can run concurrently precisely because they never write to shared state; only the orchestrator does.

**Key architectural constraints:**

1. **Only orchestrator writes to HEAD.** Wave agents commit to isolated worktrees; orchestrator merges.
2. **Only orchestrator advances protocol state.** Agents report completion; orchestrator decides next state.
3. **Only orchestrator handles failures.** Agents report status (blocked/partial/complete); orchestrator escalates.
4. **Agents never coordinate peer-to-peer.** All coordination flows through IMPL doc + orchestrator.

These constraints enable safe parallelism without distributed coordination protocols.
