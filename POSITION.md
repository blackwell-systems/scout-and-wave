# Scout-and-Wave: Position Statement

## The Problem

LLM agents can write code. That stopped being the bottleneck. The bottleneck is what happens when you run multiple agents simultaneously on the same codebase: merge conflicts, ownership violations, hallucinated APIs, integration failures discovered only after all agents finish, and no reliable way to know whether the assembled result actually works.

Most approaches to parallel agent coordination fall into one of four failure modes:

1. **No coordination.** Spawn N agents, hope their outputs merge cleanly. They won't. File conflicts are probabilistic; at scale, they're guaranteed.
2. **File locking or optimistic merging.** Reactive conflict handling borrowed from version control. Detects conflicts after agents have already done the work. Wasted compute, wasted context windows.
3. **Human orchestration.** A person manually partitions work, reviews each agent's output, resolves conflicts, and sequences merges. Correct, but the person is now the bottleneck the agents were supposed to remove.
4. **Coarse serialization.** Run agents one at a time. No conflicts, but no parallelism either.

Scout-and-Wave (SAW) treats parallel agent work as a distributed systems problem and solves it structurally: disjoint ownership eliminates conflicts by construction, interface contracts eliminate coordination drift, and wave sequencing eliminates cascade failures.

The distinction is mechanical, not philosophical. Systems in categories 1-3 rely on probabilistic outcomes -- files might not conflict, merges might succeed, humans might catch issues. SAW eliminates the probability: I1 makes conflicts impossible by construction, I2 makes API drift impossible by construction, and I3 makes cascade failures detectable at wave boundaries rather than at the end. The protocol's correctness properties are enforced by tool-level hooks, not by agent cooperation -- a model prompted to violate ownership will be blocked before the tool executes.

## What SAW Is

SAW is a coordination protocol for safely parallelizing LLM agent work on shared codebases. It is language-agnostic, provider-agnostic, and enforces correctness through six invariants (I1-I6) and 42 execution rules (E1-E42) that govern every phase from planning through post-merge verification.

The protocol has three layers:

- **IMPL execution** -- a single feature decomposed into waves of parallel agents, with living IMPL docs that support mid-execution amendment (E36: add waves, redirect agents, extend scope)
- **PROGRAM execution** -- multiple features (IMPLs) coordinated across tiers with cross-IMPL file ownership validation and tier-gated progression
- **Lifecycle hooks** -- PreToolUse/PostToolUse/SubagentStop enforcement that blocks protocol violations at the tool boundary, not after the fact

The architecture is three repositories:

| Repository | Purpose | Contents |
|---|---|---|
| **scout-and-wave** | Language-agnostic protocol spec | Invariants, execution rules, agent prompts, `/saw` skill |
| **scout-and-wave-go** | Go SDK + CLI engine | 30+ packages: engine, protocol, hooks, resume, retry, journal, collision detection, autonomy, suitability analysis, wave solver, build diagnostics, error parsing, code review, 4 LLM backends |
| **scout-and-wave-web** | Web application | HTTP/SSE real-time dashboard, React UI with command palette and Base16 theming, Go API server with Bedrock SSO device auth |

CLI commands and web API routes are thin I/O wrappers over the same SDK functions. There is one source of truth for business logic.

### Provider Independence

SAW does not assume a specific LLM provider. The protocol specifies *what* agents must do, not which model does it. The Go SDK's `Backend` interface abstracts all LLM interaction behind three methods (`Run`, `RunStreaming`, `RunStreamingWithTools`), and the engine ships four implementations:

| Backend | Module | Use Case |
|---|---|---|
| **Anthropic API** | `pkg/agent/backend/api` | Direct Anthropic API access (claude-sonnet-4-6, claude-opus-4-6, etc.) |
| **AWS Bedrock** | `pkg/agent/backend/bedrock` | Claude models via AWS Bedrock; supports SSO profiles, temporary credentials, regional endpoints |
| **OpenAI-compatible** | `pkg/agent/backend/openai` | Any OpenAI-compatible endpoint: OpenAI, Groq, Ollama (local models), or custom deployments |
| **CLI** | `pkg/agent/backend/cli` | Wraps any CLI binary (`claude`, or any compatible CLI via `BinaryPath` config) |

Model selection is configurable at three levels: per-invocation (`--model`), per-role in `saw.config.json` (separate `scout_model`, `wave_model`, `critic_model`, `integration_model`, `scaffold_model`, `planner_model`), or inherited from the parent session. A single SAW execution can use different models for different roles -- Opus for Scout planning, Sonnet for Wave agents, Haiku for critic review.

The `Backend` config accepts `BaseURL` for endpoint override, meaning any API-compatible service works without code changes: `http://localhost:11434/v1` for local Ollama, `https://api.groq.com/openai/v1` for Groq, or a corporate proxy endpoint.

For AWS environments, the web application includes a Bedrock SSO device auth flow -- users authenticate via browser-based device authorization and the engine obtains temporary credentials automatically. No API keys to manage or rotate.

## Execution Modes

SAW has three distinct execution modes, each serving different use cases. All three execute the same protocol with the same invariants.

### Agent Skill (`/saw` in Claude Code)

The primary interactive experience. The `/saw` skill is a YAML-frontmatter + markdown file that conforms to the **agent skills open standard** -- the same format adopted by most frontier model agent frameworks. The skill turns a Claude Code session into a SAW Orchestrator.

```
/saw scout "add caching layer"     # Scout analyzes codebase, produces IMPL plan
/saw wave --auto                   # Execute all waves with human checkpoints
/saw program execute "refactor"    # Multi-feature tier-gated execution
```

- Human-in-the-loop by default; `--auto` for autonomous wave progression
- Access to Claude Code's full tool suite (file I/O, shell, subagents, MCP)
- Subagent types (`scout`, `wave-agent`, `scaffold-agent`, `critic-agent`, `integration-agent`, `planner`) carry tool-level enforcement -- a Scout agent cannot `Edit` source files, a Wave agent cannot spawn sub-agents
- Interview mode (E39): structured 6-phase requirements gathering (`/saw interview`) that produces a REQUIREMENTS.md for Scout consumption -- an alternative entry point when the user needs guided decomposition before planning
- Because the skill conforms to the open standard, it is not structurally locked to Claude Code. Any agent runtime that supports the skills standard can load the same `saw-skill.md` file

The skill uses a four-tier progressive disclosure model to keep the Orchestrator's context window lean:

- **Tier 0** (CLAUDE.md) -- discovery index, always present, zero invocation cost
- **Tier 1** (frontmatter metadata, ~17 lines) -- parsed by the Skills API before context construction
- **Tier 2** (core skill body, ~310 lines) -- loads on invocation; covers scout, wave, status, bootstrap, and interview (the operations needed on >90% of sessions)
- **Tier 3** (on-demand reference files) -- loads only when a subcommand match fires: program execution, IMPL amendment, and failure routing stay out of context until needed

The `triggers:` frontmatter extension enables deterministic Tier 3 injection via the `UserPromptSubmit` hook. A `/saw wave` invocation never pays the context cost of program coordination logic.

### CLI (`sawtools` binary)

A standalone Go binary with no Claude Code dependency. Every protocol operation is a CLI command:

```
sawtools run-scout <feature>              # Full Scout phase: launch, validate, finalize
sawtools prepare-wave <impl> --wave N     # Atomic wave setup: deps, worktrees, briefs, journals
sawtools finalize-wave <impl> --wave N    # Atomic wave teardown: verify, merge, build, cleanup
sawtools run-wave <impl> --wave N         # Fully automated wave execution (any backend)
sawtools daemon                           # Continuous autonomous operation from queue
```

The CLI is callable from CI/CD pipelines, shell scripts, cron jobs, or other orchestrators. `sawtools run-wave` drives agents through the API or Bedrock backend without a Claude Code session -- this is the path for fully automated pipelines. Pre-built binaries for macOS, Linux, and Windows (amd64/arm64) are published via GoReleaser on each release.

Batching commands (`prepare-wave`, `finalize-wave`, `prepare-tier`, `finalize-tier`) package multi-step workflows as atomic operations. Each succeeds or fails as a unit with structured JSON output. Forgotten steps -- the most common source of silent protocol violations -- are eliminated by design.

Additional CLI surface includes: `interview` (E39 structured requirements gathering), `amend-impl` (E36 living IMPL mutation), `check-type-collisions` (E41 cross-agent type name conflicts), `validate-integration --wiring` (E35 wiring obligation verification), `solve` (automatic wave assignment from dependency graph), `diagnose-build-failure` (multi-language build error classification), `run-critic` (E37 pre-wave brief review), `code-review` (LLM-powered diff review with dimensional scoring), `queue` (IMPL queue management for daemon mode), and `verify-install` (hook installation verification). Over 60 commands total.

### Go SDK (`pkg/protocol/`, `pkg/engine/`)

Importable Go packages for building custom orchestrators:

```go
import (
    "github.com/blackwell-systems/scout-and-wave-go/pkg/engine"
    "github.com/blackwell-systems/scout-and-wave-go/pkg/protocol"
    "github.com/blackwell-systems/scout-and-wave-go/pkg/agent/backend/bedrock"
)

eng := engine.New(engine.Opts{
    RepoPath: "/path/to/repo",
    Backend:  bedrock.New(bedrock.Config{Region: "us-east-1"}),
})

// Scout, validate, execute waves
result := eng.RunScout(ctx, "add caching layer")
eng.RunWaveFull(ctx, result.IMPLPath, 1)
```

The web application (`scout-and-wave-web`) is built on this SDK. Every CLI command is a thin wrapper over an SDK function. The SDK also provides:

- `engine.RunDaemon()` for continuous autonomous operation -- polls an IMPL queue (`pkg/queue`), picks up work, executes waves, reports results
- `engine.Chat()` for conversational agent interaction
- `protocol.Validate()`, `protocol.PrepareWave()`, `protocol.FinalizeWave()` for granular control
- Constraint enforcement (`pkg/tools`) that implements I1 file ownership, I2 interface freeze, I5 commit tracking, and I6 role separation at the tool execution boundary
- Wave dependency solver (`pkg/solver`) -- topological sort with level assignment that automatically computes wave numbers from dependency declarations
- Composable pipeline framework (`pkg/pipeline`) -- step sequencing with conditions, retry strategies, and error aggregation for building custom orchestration flows

## What Makes SAW Different

### Seven Participants, One Pipeline

SAW coordinates seven participant roles through a single Orchestrator:

1. **Orchestrator** -- synchronous coordinator in the user's session; drives all state transitions
2. **Scout** -- analyzes codebase, produces IMPL doc with disjoint file ownership and interface contracts
3. **Human** -- reviews the plan at the REVIEWED checkpoint; last point where changing architecture is cheap
4. **Scaffold Agent** -- materializes shared types as committed source files before any Wave Agent launches
5. **Wave Agents** -- implement in parallel, each in an isolated worktree with disjoint file ownership
6. **Integration Agent** -- wires new exports into caller code post-merge; restricted to `integration_connectors` files
7. **Critic Agent** -- reviews briefs for symbol accuracy, import conflicts, and ownership gaps before agents launch

The Planner role coordinates at program scope when multiple features execute as a PROGRAM. Each role has mechanically enforced boundaries: Scouts cannot edit source files, Wave Agents cannot spawn sub-agents, Integration Agents cannot touch agent-owned files.

### Scout Before You Parallelize

Most systems skip planning entirely -- they decompose work at launch time or let agents self-organize. SAW runs a dedicated Scout phase that analyzes the codebase, evaluates suitability for parallelization (some features should not be parallelized), builds a dependency graph, assigns disjoint file ownership, and specifies interface contracts. The planning artifact (the IMPL doc) becomes the execution artifact -- there is no divergence between plan and reality (I4).

If the Scout determines a feature is not suitable for parallel execution, it says so. The suitability gate is quantitative, not binary -- `pkg/suitability` computes a score with dimensional breakdown (decomposability, interface clarity, test isolation, dependency depth), and the gate threshold is configurable. This prevents wasted effort on features where serial implementation is the correct approach.

### Conflicts Are Structurally Impossible

**I1: Disjoint File Ownership.** No two agents in the same wave own the same file. This is not optimistic concurrency -- it is a hard constraint enforced before agents launch (E3 pre-launch verification), during execution (PreToolUse hooks block writes to unowned files), and after completion (E42 post-completion ownership audit). Merge conflicts between agents in the same wave cannot occur because the file sets are provably disjoint.

This extends to multi-feature coordination: the PROGRAM layer's P1+ conflict check validates that no two IMPLs in the same tier share file ownership before any agent in the tier launches.

### Interface Contracts Before Implementation

**I2: Interface Contracts Precede Parallel Implementation.** The Scout identifies all cross-agent boundaries. A Scaffold Agent materializes shared types as real source files committed to HEAD before any Wave Agent launches. Agents compile against committed types, not hallucinated APIs. Interface contracts freeze when worktrees are created (E2) -- no mid-wave drift.

This is the mechanism that eliminates "agent A expected function signature X, agent B implemented signature Y" failures. Both agents import from the same committed scaffold files. Scaffold correctness is verified programmatically (`pkg/scaffoldval`) before wave launch.

### Wave Sequencing With Verified Boundaries

**I3: Wave Sequencing.** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed. Each wave boundary is a verification checkpoint: stub scanning (E20), quality gate execution (E21), build verification, and integration gap detection (E25/E26). Failures surface at wave boundaries, not at the end of all waves.

This is dependency-aware execution. The Scout's dependency graph determines which work can safely parallelize (same wave) and which must sequence (later wave). The wave solver (`pkg/solver`) automates this: given agent dependency declarations, it computes optimal wave assignments via topological sort with level assignment -- minimizing total waves while respecting all ordering constraints.

Solo wave optimization: when a wave contains a single agent, SAW skips worktree creation entirely and executes directly on the branch. This avoids the overhead of worktree setup/teardown for waves where isolation provides no benefit.

### Tool-Level Enforcement

Protocol compliance is not advisory. Lifecycle hooks enforce invariants mechanically:

- **PreToolUse (`check_wave_ownership`)**: Blocks Write/Edit operations on files the agent does not own. I1 violations are rejected before the tool executes.
- **PreToolUse (`check_scout_boundaries`)**: Prevents Scout agents from writing source code. I6 role separation enforced at the tool boundary.
- **PreToolUse (`validate_agent_launch`)**: H5 pre-launch gate -- 8 checks (SAW tag, IMPL exists, IMPL valid, wave exists, agent exists, worktree branch, scaffolds committed, critic review) before any agent starts.
- **SubagentStop (`validate_agent_completion`)**: Blocks agent completion if I5 (commit before reporting), I4 (completion report exists), or I1 (ownership audit) obligations are unmet.
- **PostToolUse (`check_branch_drift`)**: Detects when an agent has drifted off its assigned worktree branch.
- **PostToolUse (`check_git_ownership`)**: Catches git operations that modify files outside the ownership list -- the layer-2 defense that catches merge conflict resolutions bypassing Write/Edit hooks.

Agents cannot violate the protocol even if prompted to. Enforcement lives below the agent's decision layer. The three enforcement layers are:

1. **Claude Code hooks** (Layer 1) -- PreToolUse/PostToolUse/SubagentStop scripts that block violations in the agent runtime. 11 hooks covering ownership (I1), role separation (I6), branch drift (I4), IMPL schema validation (E16), pre-launch gates (H5), stub warnings (E20), git ownership (I1 Layer 2), agent completion (I4/I5), context injection (Tier 3 progressive disclosure), and observability event emission.
2. **Git pre-commit hooks** (Layer 2) -- ownership verification at commit time, catching violations that bypass Layer 1.
3. **SDK constraint middleware** (Layer 3) -- `tools.Constraints` on every backend, enforcing the same rules programmatically for CLI and daemon execution where Claude Code hooks are not present.

### The IMPL Doc as Coordination Artifact

**I4: IMPL Doc is the Single Source of Truth.** The IMPL doc is a YAML manifest that serves as both planning document and execution record. It contains the suitability verdict, dependency graph, file ownership table, interface contracts, wave structure, agent briefs, scaffold status, quality gates, critic reports, and completion reports. It is git-tracked, machine-parseable, and validated by the engine (E16 structural validation, E37 critic review).

Chat output is ephemeral. The IMPL doc is the record. Downstream agents, the orchestrator, and post-merge verification all read from it.

### Critic Gate

**E37: Pre-Wave Brief Review.** Before agents launch, a critic agent reviews each brief for symbol accuracy, import conflicts, stale references, and ownership gaps. This catches errors in the plan before agents waste compute implementing against incorrect assumptions. The critic produces a structured report with pass/issues/fail verdict; execution blocks on unresolved errors.

### Type Collision Detection

**E41: Cross-Agent Type Name Conflicts.** When multiple agents in a wave define types that will coexist after merge, name collisions cause compilation failures. `check-type-collisions` statically analyzes agent briefs and file ownership to detect type name conflicts before agents launch. This is a pre-flight check in `prepare-wave` -- collisions are reported with specific agent/file/type details so the orchestrator can revise briefs before wasting compute.

### Wiring Obligation Tracking

**E35: Integration Completeness.** Agents must declare `wiring:` blocks for every exported symbol that requires integration by downstream code. `prepare-wave` enforces ownership of wiring targets (Layer 3A), `validate-integration --wiring` verifies post-merge that all declared wiring obligations were fulfilled (Layer 3B), and agent briefs inject the wiring table so agents know their integration responsibilities (Layer 3C). This closes the gap between "code exists" and "code is reachable" -- the most common class of post-merge integration failure.

### IMPL Amendment

**E36: Living IMPL Docs.** IMPL documents are not frozen after Scout approval. Three amendment operations allow controlled mid-execution mutation: `add-wave` appends an empty wave skeleton, `redirect-agent` re-queues an uncommitted agent with revised brief, and `extend-scope` re-engages the Scout with the current IMPL as context. Amendments are blocked after `SAW:COMPLETE`, and completed-wave ownership is frozen -- the protocol allows adaptation without compromising already-verified work.

### Resume and Retry Intelligence

SAW does not just detect interrupted sessions -- it provides structured failure context for recovery. `resume-detect` identifies interrupted sessions with progress percentage and suggested actions. `build-retry-context` produces error classification and fix suggestions rather than raw error dumps. Failed agents get prior-work context injected via tool journals (E23A), so retries build on previous progress instead of starting from scratch.

Build failure diagnosis (`pkg/builddiag`) classifies errors across languages (Go, JavaScript/TypeScript) with pattern-matched error parsers (`pkg/errparse`) that extract file paths, line numbers, and error categories from compiler output. This structured diagnosis feeds into retry context so agents receive actionable fix guidance rather than raw stderr.

### Autonomy Levels

The autonomy system (`pkg/autonomy`) supports graduated levels: supervised (human confirms each wave), semi-autonomous (`--auto` with human checkpoints at wave boundaries), and fully autonomous (daemon mode with queue-based continuous operation). Autonomy level is configurable per-project in `saw.config.json` and can be overridden per-invocation.

### PROGRAM Layer for Multi-Feature Coordination

For projects spanning multiple features, the PROGRAM layer provides tier-gated execution of multiple IMPLs. A Planner agent decomposes the project into features, identifies cross-feature dependencies, and assigns IMPLs to execution tiers. Tiers execute sequentially; IMPLs within a tier execute in parallel. P1+ validates that no two IMPLs in the same tier share file ownership -- the same disjoint ownership guarantee that prevents conflicts within a wave, applied at the multi-feature scale. P5 ensures each IMPL's wave merges target a dedicated branch; main advances only when a full tier is verified.

This is not multi-feature task management -- it is structural coordination with the same correctness guarantees SAW provides within a single feature. A program with 5 IMPLs across 3 tiers executes with the same confidence as a single 3-wave IMPL: file ownership is disjoint, dependencies are ordered, and verification gates fire at every boundary.

### LLM-Powered Code Review

The engine includes an LLM-powered code review system (`pkg/codereview`) that scores diffs across multiple quality dimensions and produces a structured verdict with per-dimension scores, an overall rating, and a narrative summary. This can gate wave merges or run as a standalone quality check. The review model defaults to a fast model (Haiku) for cost efficiency but is configurable.

### Real-Time Observability

The web application (`scout-and-wave-web`) provides a real-time SSE-based dashboard for monitoring parallel agent execution. Built on the Go SDK, it streams tool call events, agent progress, wave state transitions, and build verification results as they happen. The API server (`pkg/api`) exposes the same operations available through CLI, making the web app a visual orchestrator rather than a separate system.

The web application includes:

- **Program Board** -- multi-IMPL coordination view with tier visualization and cross-IMPL dependency graph
- **Wave Board** -- per-wave agent cards with live status, tool feeds, and completion tracking; state persistence reconstructs from the IMPL doc on reconnect so browser refreshes and disconnections are non-destructive
- **IMPL Review Screen** -- 15+ panels (overview, file ownership, dependency graph, interface contracts, scaffolds, quality gates, wiring obligations, critic reports, stub reports, agent contexts, reactions, pre-mortem, post-merge checklist) for deep plan inspection
- **Interview Launcher** -- guided requirements gathering with phase progression
- **Planner and Scout Launchers** -- one-click program/feature initiation with model selection
- **Pipeline View** -- step-by-step execution visualization with metrics
- **Recovery Controls** -- resume, retry, and amend operations from the UI
- **Command Palette** -- keyboard-driven navigation across all operations
- **File Browser** -- tree view with diff viewer and file content inspection
- **Chat Panel** -- conversational agent interaction via `engine.Chat()`
- **Notification System** -- configurable alerts for wave completions, failures, and state transitions
- **Base16 Theming** -- 200+ color themes with dark/light mode and live preview
- **Bedrock SSO** -- browser-based device authorization for AWS credentials

The observability event schema (E40) defines three event types -- `cost` (token usage and USD estimates per agent), `agent_performance` (execution outcomes), and `activity` (orchestrator actions) -- enabling cost tracking, trend analysis, and performance dashboards.

## Capabilities by Phase

**Planning:** Scout codebase analysis, quantitative suitability scoring, dependency graph construction, automatic wave assignment (topological solver), file ownership assignment, interface contract specification, PROGRAM manifests with automatic tiering, structured requirements interviews (E39), IMPL amendment for mid-execution adaptation (E36).

**Validation:** E16 IMPL structural validation with auto-fix, E37 critic brief review, E41 type collision detection, P1+ cross-IMPL file ownership conflict detection, E21A/E21B baseline gate verification (pre-wave build/test verification, including cross-repo), H5 pre-launch agent validation (8 checks), scaffold correctness verification, E35 wiring obligation enforcement.

**Execution:** Wave agents in git worktrees with verified isolation (solo wave optimization for single-agent waves), 3-layer ownership enforcement (hooks, git pre-commit, SDK middleware), tool journal tracking (E23A), incremental commits, cross-repository orchestration with coordinated merge ordering, integration waves (E27) for wiring-only work, LLM-powered code review with dimensional scoring.

**Finalization:** Post-merge build verification, E20 stub scanning, E25/E26 integration gap detection and automated wiring, E35 wiring obligation verification, IMPL archival with CONTEXT.md history (E18), gate caching (E38) for idempotent re-runs.

**Recovery:** Session resume detection with progress percentage and suggested actions, structured retry context with error classification, multi-language build failure diagnosis (Go, JS/TS), error parsing with file/line extraction, prior-work context injection via tool journals.

**Observability:** Structured completion reports, hook enforcement audit trail, cost/agent_performance/activity event schema (E40), tool call event streaming (SSE), agent progress tracking, CONTEXT.md project history, web dashboard with 15+ review panels and real-time monitoring.

## Evidence

The protocol is self-hosting. The scout-and-wave protocol repository, Go SDK, and web application were built using SAW. CONTEXT.md records 30+ completed features executed through the protocol, ranging from 1-wave/2-agent documentation fixes to 5-wave/26-agent cross-cutting refactors. The PROGRAM layer's first real execution (a 3-tier, 5-IMPL unification project) drove the discovery and resolution of 13 integration gaps (P1-P13) -- gaps that would not have been found without running the protocol at scale on its own codebase.

The Go SDK contains 33 packages across engine, protocol, hooks, resume, retry, journal, collision detection, autonomy, suitability analysis, wave solver, pipeline framework, build diagnostics, error parsing, code review, scaffold validation, four LLM backends (Anthropic API, Bedrock, OpenAI-compatible, CLI), constraint enforcement, and configuration. The CLI exposes 60+ commands. The web app ships 70+ React components with real-time SSE streaming, Base16 theming, and Bedrock SSO -- all embedded in a single Go binary.

This is production infrastructure, not a proof of concept.
