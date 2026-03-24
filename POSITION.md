# Scout-and-Wave: Position Statement

## The Problem

LLM agents can write code. That stopped being the bottleneck. The bottleneck is what happens when you run multiple agents simultaneously on the same codebase: merge conflicts, ownership violations, hallucinated APIs, integration failures discovered only after all agents finish, and no reliable way to know whether the assembled result actually works.

Most approaches to parallel agent coordination fall into one of four failure modes:

1. **No coordination.** Spawn N agents, hope their outputs merge cleanly. They won't. File conflicts are probabilistic; at scale, they're guaranteed.
2. **File locking or optimistic merging.** Reactive conflict handling borrowed from version control. Detects conflicts after agents have already done the work. Wasted compute, wasted context windows.
3. **Human orchestration.** A person manually partitions work, reviews each agent's output, resolves conflicts, and sequences merges. Correct, but the person is now the bottleneck the agents were supposed to remove.
4. **Coarse serialization.** Run agents one at a time. No conflicts, but no parallelism either.

Scout-and-Wave (SAW) treats parallel agent work as a distributed systems problem and solves it structurally: disjoint ownership eliminates conflicts by construction, interface contracts eliminate coordination drift, and wave sequencing eliminates cascade failures.

## What SAW Is

SAW is a coordination protocol for safely parallelizing LLM agent work on shared codebases. It is language-agnostic, provider-agnostic, and enforces correctness through six invariants (I1-I6) and 40+ execution rules (E1-E42) that govern every phase from planning through post-merge verification.

The protocol has three layers:

- **IMPL execution** -- a single feature decomposed into waves of parallel agents
- **PROGRAM execution** -- multiple features (IMPLs) coordinated across tiers with cross-IMPL file ownership validation and tier-gated progression
- **Lifecycle hooks** -- PreToolUse/PostToolUse/SubagentStop enforcement that blocks protocol violations at the tool boundary, not after the fact

The architecture is three repositories:

| Repository | Purpose | Contents |
|---|---|---|
| **scout-and-wave** | Language-agnostic protocol spec | Invariants, execution rules, agent prompts, `/saw` skill |
| **scout-and-wave-go** | Go SDK + CLI engine | 30+ packages: engine, protocol, hooks, resume, retry, journal, collision detection, autonomy, suitability analysis, 4 LLM backends |
| **scout-and-wave-web** | Web application | HTTP/SSE real-time dashboard, React UI, Go API server |

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
- Subagent types (`scout`, `wave-agent`, `scaffold-agent`, `critic-agent`, `integration-agent`) carry tool-level enforcement -- a Scout agent cannot `Edit` source files, a Wave agent cannot spawn sub-agents
- Because the skill conforms to the open standard, it is not structurally locked to Claude Code. Any agent runtime that supports the skills standard can load the same `saw-skill.md` file

### CLI (`sawtools` binary)

A standalone Go binary with no Claude Code dependency. Every protocol operation is a CLI command:

```
sawtools run-scout <feature>              # Full Scout phase: launch, validate, finalize
sawtools prepare-wave <impl> --wave N     # Atomic wave setup: deps, worktrees, briefs, journals
sawtools finalize-wave <impl> --wave N    # Atomic wave teardown: verify, merge, build, cleanup
sawtools run-wave <impl> --wave N         # Fully automated wave execution (any backend)
sawtools daemon                           # Continuous autonomous operation from queue
```

The CLI is callable from CI/CD pipelines, shell scripts, cron jobs, or other orchestrators. `sawtools run-wave` drives agents through the API or Bedrock backend without a Claude Code session -- this is the path for fully automated pipelines.

Batching commands (`prepare-wave`, `finalize-wave`, `prepare-tier`, `finalize-tier`) package multi-step workflows as atomic operations. Each succeeds or fails as a unit with structured JSON output. Forgotten steps -- the most common source of silent protocol violations -- are eliminated by design.

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

- `engine.RunDaemon()` for continuous autonomous operation -- polls a queue, picks up IMPLs, executes waves, reports results
- `engine.Chat()` for conversational agent interaction
- `protocol.Validate()`, `protocol.PrepareWave()`, `protocol.FinalizeWave()` for granular control
- Constraint enforcement (`pkg/tools`) that implements I1 file ownership, I2 interface freeze, I5 commit tracking, and I6 role separation at the tool execution boundary

## What Makes SAW Different

### Scout Before You Parallelize

Most systems skip planning entirely -- they decompose work at launch time or let agents self-organize. SAW runs a dedicated Scout phase that analyzes the codebase, evaluates suitability for parallelization (some features should not be parallelized), builds a dependency graph, assigns disjoint file ownership, and specifies interface contracts. The planning artifact (the IMPL doc) becomes the execution artifact -- there is no divergence between plan and reality (I4).

If the Scout determines a feature is not suitable for parallel execution, it says so. The suitability gate prevents wasted effort on features where serial implementation is the correct approach.

### Conflicts Are Structurally Impossible

**I1: Disjoint File Ownership.** No two agents in the same wave own the same file. This is not optimistic concurrency -- it is a hard constraint enforced before agents launch (E3 pre-launch verification), during execution (PreToolUse hooks block writes to unowned files), and after completion (E42 post-completion ownership audit). Merge conflicts between agents in the same wave cannot occur because the file sets are provably disjoint.

This extends to multi-feature coordination: the PROGRAM layer's P1+ conflict check validates that no two IMPLs in the same tier share file ownership before any agent in the tier launches.

### Interface Contracts Before Implementation

**I2: Interface Contracts Precede Parallel Implementation.** The Scout identifies all cross-agent boundaries. A Scaffold Agent materializes shared types as real source files committed to HEAD before any Wave Agent launches. Agents compile against committed types, not hallucinated APIs. Interface contracts freeze when worktrees are created (E2) -- no mid-wave drift.

This is the mechanism that eliminates "agent A expected function signature X, agent B implemented signature Y" failures. Both agents import from the same committed scaffold files.

### Wave Sequencing With Verified Boundaries

**I3: Wave Sequencing.** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed. Each wave boundary is a verification checkpoint: stub scanning (E20), quality gate execution (E21), build verification, and integration gap detection (E25/E26). Failures surface at wave boundaries, not at the end of all waves.

This is dependency-aware execution. The Scout's dependency graph determines which work can safely parallelize (same wave) and which must sequence (later wave).

### Tool-Level Enforcement

Protocol compliance is not advisory. Lifecycle hooks enforce invariants mechanically:

- **PreToolUse (`check_wave_ownership`)**: Blocks Write/Edit operations on files the agent does not own. I1 violations are rejected before the tool executes.
- **PreToolUse (`check_scout_boundaries`)**: Prevents Scout agents from writing source code. I6 role separation enforced at the tool boundary.
- **PreToolUse (`validate_agent_launch`)**: H5 pre-launch gate -- 8 checks (SAW tag, IMPL exists, IMPL valid, wave exists, agent exists, worktree branch, scaffolds committed, critic review) before any agent starts.
- **SubagentStop (`validate_agent_completion`)**: Blocks agent completion if I5 (commit before reporting), I4 (completion report exists), or I1 (ownership audit) obligations are unmet.
- **PostToolUse (`check_branch_drift`)**: Detects when an agent has drifted off its assigned worktree branch.
- **PostToolUse (`check_git_ownership`)**: Catches git operations that modify files outside the ownership list -- the layer-2 defense that catches merge conflict resolutions bypassing Write/Edit hooks.

Agents cannot violate the protocol even if prompted to. Enforcement lives below the agent's decision layer. In the SDK, the same constraints are enforced programmatically via `tools.Constraints` middleware on every backend.

### The IMPL Doc as Coordination Artifact

**I4: IMPL Doc is the Single Source of Truth.** The IMPL doc is a YAML manifest that serves as both planning document and execution record. It contains the suitability verdict, dependency graph, file ownership table, interface contracts, wave structure, agent briefs, scaffold status, quality gates, critic reports, and completion reports. It is git-tracked, machine-parseable, and validated by the engine (E16 structural validation, E37 critic review).

Chat output is ephemeral. The IMPL doc is the record. Downstream agents, the orchestrator, and post-merge verification all read from it.

### Critic Gate

**E37: Pre-Wave Brief Review.** Before agents launch, a critic agent reviews each brief for symbol accuracy, import conflicts, stale references, and ownership gaps. This catches errors in the plan before agents waste compute implementing against incorrect assumptions. The critic produces a structured report with pass/issues/fail verdict; execution blocks on unresolved errors.

### Resume and Retry Intelligence

SAW does not just detect interrupted sessions -- it provides structured failure context for recovery. `resume-detect` identifies interrupted sessions with progress percentage and suggested actions. `build-retry-context` produces error classification and fix suggestions rather than raw error dumps. Failed agents get prior-work context injected via tool journals (E23A), so retries build on previous progress instead of starting from scratch.

The autonomy system (`pkg/autonomy`) supports graduated levels: supervised (human confirms each wave), semi-autonomous (`--auto` with human checkpoints at wave boundaries), and fully autonomous (daemon mode with queue-based continuous operation).

### PROGRAM Layer for Multi-Feature Coordination

For projects spanning multiple features, the PROGRAM layer provides tier-gated execution. A Planner agent decomposes the project into IMPLs, assigns them to tiers based on dependency analysis, and the engine executes tiers sequentially with parallel IMPL execution within each tier. P1+ validates cross-IMPL file ownership at tier boundaries. P5 (IMPL branch isolation) ensures each IMPL's wave merges target a dedicated branch -- main only advances when a full tier is verified.

### Real-Time Observability

The web application (`scout-and-wave-web`) provides a real-time SSE-based dashboard for monitoring parallel agent execution. Built on the Go SDK, it streams tool call events, agent progress, wave state transitions, and build verification results as they happen. The API server (`pkg/api`) exposes the same operations available through CLI, making the web app a visual orchestrator rather than a separate system.

## Capabilities by Phase

**Planning:** Scout codebase analysis, suitability gate, dependency graph construction, file ownership assignment, interface contract specification, PROGRAM manifests with automatic tiering, structured requirements interviews.

**Validation:** E16 IMPL structural validation with auto-fix, E37 critic brief review, P1+ cross-IMPL file ownership conflict detection, E21A/E21B baseline gate verification (pre-wave build/test verification, including cross-repo), H5 pre-launch agent validation (8 checks).

**Execution:** Wave agents in git worktrees with verified isolation, PreToolUse ownership enforcement, tool journal tracking (E23A), incremental commits, cross-repository orchestration with coordinated merge ordering, integration waves (E27) for wiring-only work.

**Finalization:** Post-merge build verification, E20 stub scanning, E25/E26 integration gap detection and automated wiring, IMPL archival with CONTEXT.md history, gate caching for idempotent re-runs.

**Observability:** Structured completion reports, hook enforcement audit trail, session resume detection with diagnostic context, tool call event streaming (SSE), agent progress tracking, CONTEXT.md project history.

## Evidence

The protocol is self-hosting. The scout-and-wave protocol repository, Go SDK, and web application were built using SAW. CONTEXT.md records 30+ completed features executed through the protocol, ranging from 1-wave/2-agent documentation fixes to 5-wave/26-agent cross-cutting refactors. The PROGRAM layer's first real execution (a 3-tier, 5-IMPL unification project) drove the discovery and resolution of 13 integration gaps (P1-P13) -- gaps that would not have been found without running the protocol at scale on its own codebase.

The Go SDK contains 30+ packages across engine, protocol, hooks, resume, retry, journal, collision detection, autonomy, suitability analysis, four LLM backends (Anthropic API, Bedrock, OpenAI-compatible, CLI), constraint enforcement, and more. The CLI exposes 60+ commands. The web app ships a React frontend with real-time SSE streaming embedded in a single Go binary.

The protocol version is 0.64.0. This is production infrastructure, not a proof of concept.
