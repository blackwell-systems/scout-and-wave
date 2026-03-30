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

SAW is a coordination protocol for safely parallelizing LLM agent work on shared codebases. It is language-agnostic, provider-agnostic, and enforces correctness through six invariants (I1-I6) and 45 execution rules (E1-E45) that govern every phase from planning through post-merge verification.

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

Model selection is configurable at three levels: per-invocation (`--model`), per-role in `saw.config.json` (separate `scout_model`, `wave_model`, `critic_model`, `integration_model`, `scaffold_model`, `planner_model`), or inherited from the parent session. A single SAW execution can use different models for different roles -- Opus for Scout planning, Sonnet for Wave agents, Haiku for critic review. The web app's ModelPicker UI surfaces this as per-role provider selection: each role (Scout, Wave, Critic, Scaffold, Integration, Planner, Chat) has its own model dropdown, and different roles can use different providers in the same session.

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

### Advanced Progressive Disclosure Architecture

SAW implements a **hook-based deterministic injection architecture** that extends the Agent Skills specification's three-tier model with automatic context loading. Rather than relying on models to follow routing instructions ("read this file when needed"), SAW uses lifecycle hooks and script-based conditional logic to inject references before the model runs. Always-needed content is inlined directly in agent definitions; conditional references (3 total) are injected by scripts when specific scenarios are detected. This section documents the complete architecture.

#### Four-Tier Structure

The skill uses a four-tier progressive disclosure model to keep the Orchestrator's context window lean:

- **Tier 0** (CLAUDE.md) -- discovery index, always present, zero invocation cost
- **Tier 1** (frontmatter metadata, ~20 lines) -- parsed by the Skills API before context construction; standard Skills API fields only (name, description, allowed-tools, etc.)
- **Tier 2** (core skill body, ~183 lines after v0.73.0 simplification) -- loads on invocation; covers scout, wave, status, bootstrap, and interview (the operations needed on >90% of sessions); 50% reduction from original via extraction to reference files
- **Tier 3** (on-demand reference files) -- loads only when a subcommand match fires: program execution, IMPL amendment, and failure routing stay out of context until needed
- **Tier 3 reference files:** `model-selection.md` (81 lines), `pre-wave-validation.md` (151 lines), `wave-agent-contracts.md` (137 lines), `impl-targeting.md` (195 lines)

#### Script-Based Conditional Dispatch

Injection is driven by two scripts with direct conditional logic (no YAML frontmatter parsing):

**Orchestrator triggers** (`inject-context` script) -- Injected via `UserPromptSubmit` hook into orchestrator context:

- `^/saw program` in prompt → inject `references/program-flow.md`
- `^/saw amend` in prompt → inject `references/amend-flow.md`

When a user invokes `/saw program execute`, the `inject_skill_context` hook calls the `inject-context` script, which matches the prompt and returns `additionalContext` containing `program-flow.md` before the model runs. The model receives the reference automatically -- no routing decision required.

**Conditional agent references** (`inject-agent-context` script) -- Injected via `PreToolUse/Agent` hook into subagent prompts. Only 3 conditional references remain:

- `scout` + `--program` in prompt → inject `scout-program-contracts.md`
- `wave-agent` + `baseline_verification_failed` in prompt → inject `wave-agent-build-diagnosis.md`
- `wave-agent` + `frozen_contracts` in prompt → inject `wave-agent-program-contracts.md`

All other agent type content (worktree isolation, completion reports, verification checks, suitability gates, etc.) is inlined directly in the agent definition files. No injection needed for critic-agent, planner, or integration-agent.

**Conditional injection** enables scenario-specific loading. Scout's `scout-program-contracts.md` only injects when `--program` appears in the prompt. Wave agent's `wave-agent-program-contracts.md` only injects when the IMPL doc contains frozen interface contracts. This prevents context pollution for scenarios where the content is irrelevant.

#### Three-Layer Injection Architecture

The injection system has three layers, each targeting a different deployment context:

| Layer | Mechanism | Platform | Enforcement |
|-------|-----------|----------|-------------|
| **Hook** (Layer 1) | `inject_skill_context` (UserPromptSubmit) + `validate_agent_launch` (PreToolUse/Agent) | Claude Code | Deterministic (always fires) |
| **Script** (Layer 2) | `scripts/inject-context` + `scripts/inject-agent-context` | Any platform with Bash | Model-initiated |
| **Fallback** (Layer 3) | Routing table in SKILL.md | Any platform | Convention-based |

**Hook layer** -- Claude Code's lifecycle hooks provide deterministic injection. `UserPromptSubmit` fires before the orchestrator runs; `PreToolUse/Agent` fires before subagent launch. Both delegate to scripts with direct conditional logic. The orchestrator and agents receive context automatically -- no model cooperation required. This is the primary mechanism for Claude Code users.

**Script layer** -- Vendor-neutral Bash scripts bundled in `scripts/`. The skill's instructions include: "Before executing, run `scripts/inject-context` with the user's prompt" (for orchestrator) or call `scripts/inject-agent-context --type <agent-type> --prompt "$prompt"` (for subagents). The scripts use direct conditional logic and output matching reference content. Any agent runtime with Bash support can use this. The model must follow the instruction, making this model-initiated but simpler than a multi-entry routing table.

**Fallback layer** -- The traditional routing table in SKILL.md: "If the argument starts with `program `, read `references/program-flow.md`". Convention-based -- the model must follow routing instructions. This is the always-available fallback for platforms without hooks or script execution.

Adding a new conditional reference requires updating the relevant script's conditional logic.

#### updatedInput vs additionalContext

The hook architecture uses two distinct output fields for different injection targets:

| Field | Target | Hook | Use case |
|-------|--------|------|----------|
| `additionalContext` | Orchestrator's context | `UserPromptSubmit` | Inject orchestrator references (program-flow, amend-flow) |
| `updatedInput.prompt` | Subagent's initial prompt | `PreToolUse/Agent` | Inject conditional agent references (scout-program-contracts, wave-agent-build-diagnosis, wave-agent-program-contracts) |

`additionalContext` in `UserPromptSubmit` adds content to the orchestrator before it starts. `updatedInput.prompt` in `PreToolUse/Agent` modifies the `Agent` tool's `prompt` parameter before Claude Code launches the subagent. The subagent receives the modified prompt as its initial message -- the reference content is present before it takes its first step.

**This distinction is non-obvious.** Early implementations tried `additionalContext` in `PreToolUse` -- this augmented the orchestrator's context, not the subagent's. Three critic review cycles caught the error before any agent ran. The correct mechanism is `updatedInput.prompt` in `PreToolUse/Agent`.

#### Agent Type Definitions

Each agent type (`scout`, `wave-agent`, `critic-agent`, `planner`, `integration-agent`, `scaffold-agent`) has a self-contained definition file. The definition includes all procedures, checklists, and format specifications the agent needs. When Claude Code spawns a subagent, the definition file becomes its system prompt -- everything is there from the first token.

| Agent Type | Definition | What It Contains |
|------------|-----------|-----------------|
| `scout` | ~787 lines | Suitability gate (5-question assessment), implementation process (18-step IMPL production), output format |
| `wave-agent` | ~330 lines | Worktree isolation protocol, completion report format, 9-field execution checklist |
| `critic-agent` | ~210 lines | 8-check verification procedure, structured CriticResult format |
| `planner` | ~557 lines | Suitability gate, PROGRAM manifest process (10 steps), annotated example manifest |
| `integration-agent` | ~233 lines | Connector wiring patterns, integration report format |
| `scaffold-agent` | ~159 lines | Type stub creation rules, scaffold status reporting |

Three references are delivered conditionally via the `inject-agent-context` script, because they apply only in specific scenarios:

| Reference | Agent | Condition | Why conditional |
|-----------|-------|-----------|-----------------|
| `scout-program-contracts.md` | scout | `--program` flag present | PROGRAM mode contract enforcement adds ~2KB irrelevant to single-IMPL scouts |
| `wave-agent-build-diagnosis.md` | wave-agent | Baseline gate failed | Diagnosis patterns only useful when the codebase is already broken |
| `wave-agent-program-contracts.md` | wave-agent | Frozen contracts detected | Contract enforcement only applies in PROGRAM mode waves |

The `validate_agent_launch` hook calls the script before each agent launch. The script checks for the condition (regex match on prompt content) and prepends the reference if matched.

**Go engine parity** -- The Go SDK's `LoadTypePromptWithRefs` reads reference files alongside each agent type definition when constructing prompts for the API or Bedrock path. Both the CLI hook layer and the engine layer deliver agent-type-scoped content -- neither path is a second-class citizen.

#### Observability

**E44: Context Injection Observability.** Scout records how reference files were received (`injection_method`: hook/manual-fallback/unknown), and `prepare-agent` writes `context_source` to each agent entry (prepared-brief/cross-repo-full/fallback-full-context) for telemetry and debugging. This enables detection of hook failures, script fallback usage, and pure convention-based loading.

The `install.sh` script uses wildcard patterns to automatically symlink new reference files as they're added. For always-needed content, inline it in the agent definition. For conditional content, add logic to the relevant script (`inject-context` or `inject-agent-context`). Re-run `install.sh` to symlink new reference files.

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

Batching commands (`run-scout`, `prepare-wave`, `finalize-wave`, `finalize-impl`, `prepare-tier`, `finalize-tier`) package multi-step workflows as atomic operations. Each succeeds or fails as a unit with structured JSON output. Forgotten steps -- the most common source of silent protocol violations -- are eliminated by design.

Additional CLI surface includes 60+ commands across all protocol phases:
- **Validation:** `validate` (E16 with --fix auto-correction), `run-critic` (E37), `check-type-collisions` (E41), `detect-shared-types` (E45), `validate-program`, `validate-integration --wiring` (E35), `check-impl-conflicts` (P1+), `validate-scaffolds`, `freeze-check`
- **Execution:** `run-wave`, `create-worktrees`, `prepare-agent`, `journal-init`, `journal-context` (E23A), `install-hooks`, `verify-hook-installed`
- **Analysis:** `analyze-suitability`, `analyze-deps`, `extract-commands`, `detect-scaffolds`, `detect-cascades`, `diagnose-build-failure` (multi-language error classification), `solve` (wave solver)
- **Verification:** `verify-commits`, `verify-build`, `scan-stubs` (E20), `run-gates` (E21/E21A with caching E38), `code-review` (LLM-powered diff review)
- **Merge:** `merge-agents`, `check-conflicts` (E11), `cleanup`
- **State:** `set-completion`, `check-completion`, `mark-complete`, `close-impl`, `set-impl-state`, `update-status`, `update-context`
- **Amendment:** `amend-impl` (E36: --add-wave, --redirect-agent, --extend-scope)
- **Recovery:** `resume-detect`, `build-retry-context`, `retry`
- **Autonomy:** `daemon`, `queue` (add/list/next)
- **Program:** `create-program` (top-down/bottom-up), `program-execute`, `program-status`, `program-replan`, `list-programs`, `import-impls`, `tier-gate`, `freeze-contracts`, `mark-program-complete`
- **Interview:** `interview` (E39 structured requirements gathering with 6-phase state persistence)
- **Observability:** `metrics`, `query`, `set-injection-method` (E44)
- **Setup:** `init` (zero-config project initialization), `verify-install`, `version`

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

- `engine.RunDaemon()` for continuous autonomous operation -- polls an IMPL queue (`pkg/queue`), picks up work, executes waves, reports results, with auto-remediation loop (configurable retry count before escalation)
- `engine.Chat()` for conversational agent interaction
- `protocol.Validate()`, `protocol.PrepareWave()`, `protocol.FinalizeWave()` for granular control
- Constraint enforcement (`pkg/tools`) that implements I1 file ownership, I2 interface freeze, I5 commit tracking, and I6 role separation at the tool execution boundary
- Wave dependency solver (`pkg/solver`) -- topological sort with level assignment that automatically computes wave numbers from dependency declarations
- Composable pipeline framework (`pkg/pipeline`) -- step sequencing with conditions, retry strategies, and error aggregation for building custom orchestration flows
- Multi-language analysis (`pkg/analyzer`) -- dependency graph construction, shared type detection (E45), cascade detection, suitability scoring
- Build diagnostics (`pkg/builddiag`) -- 27+ error patterns across Go, Rust, JavaScript/TypeScript, Python
- Error parsing (`pkg/errparse`) -- file/line extraction from compiler output with auto-detection
- Scaffold validation (`pkg/scaffoldval`) -- correctness verification before wave launch
- Gate caching (`pkg/gatecache`) -- E38 implementation with 5-minute TTL
- Resume detection (`pkg/resume`) -- interrupted session identification with progress percentage
- Tool journaling (`pkg/journal`) -- E23A checkpoint system with archive policy
- Collision detection (`pkg/collision`) -- E41 AST-based duplicate detection
- Notification system (`pkg/notify`) -- extractable library with Slack/Discord/Telegram adapters, Block Kit/embed/Markdown formatters
- Webhook integration -- unified field names with backward compatibility for old configs

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

Scout receives **pre-execution automation analysis** before launch via `runScoutAutomation()` in the engine or explicit tool calls in the CLI skill:
- **H2: extract-commands** -- detects build/test/lint commands from CI configs (GitHub Actions, GitLab CI, Makefile, package.json, Cargo.toml)
- **H1a: analyze-suitability** -- conditional requirements file analysis when path detected in feature description, produces quantitative score with dimensional breakdown (decomposability, interface clarity, test isolation, dependency depth)
- **H3: analyze-deps** -- multi-language dependency graph construction (Go native, Rust/JavaScript/TypeScript/Python via parsers), cascade detection (Go only), fuzzy path resolution
- **H7: diagnose-build-failure** -- 27+ error patterns across 4 languages, integrated into wave agent workflow for auto-fix when confidence ≥0.85

Results are injected as "Automation Analysis Results" section in Scout prompt. Best-effort execution: tool failures are logged but don't block Scout launch. This shifts Scout from manual codebase exploration to analysis of pre-computed data, reducing scouting time and improving plan quality.

If the Scout determines a feature is not suitable for parallel execution, it says so. The suitability gate is quantitative, not binary, and the gate threshold is configurable. This prevents wasted effort on features where serial implementation is the correct approach.

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
- **PreToolUse (`validate_agent_launch`)**: H5 pre-launch gate -- 8 enforcement checks (SAW tag, IMPL exists, IMPL valid, agent in wave, ownership file match, worktree branch, scaffolds committed, scaffold correctness) before any agent starts; plus conditional reference injection (3 references for scout/wave-agent scenarios) that prepends on-demand reference files into the subagent's initial prompt via `updatedInput` before the subagent launches. Always-needed content is inlined in agent definitions.
- **SubagentStop (`validate_agent_completion`)**: E42 validation -- blocks agent completion if I5 (commit before reporting), I4 (completion report exists), or I1 (ownership audit) obligations are unmet. Agent-type-specific validation matrix.
- **PostToolUse (`check_branch_drift`)**: Detects when an agent has drifted off its assigned worktree branch.
- **PostToolUse (`check_git_ownership`)**: Catches git operations that modify files outside the ownership list -- the layer-2 defense that catches merge conflict resolutions bypassing Write/Edit hooks.
- **PostToolUse (`warn_stubs`)**: E20 stub detection -- non-blocking warnings when Write/Edit creates files containing stub patterns (TODO, FIXME, NotImplementedError, panic("not implemented"), etc.) across 8 languages.

**E43: Hook-Based Worktree Isolation.** Four hooks enforce worktree isolation mechanically rather than through agent instructions:
- `inject_worktree_env` (SubagentStart): Sets 5 environment variables (SAW_AGENT_WORKTREE, SAW_AGENT_ID, SAW_WAVE_NUMBER, SAW_IMPL_PATH, SAW_BRANCH) when wave agents launch
- `inject_bash_cd` (PreToolUse:Bash): Prepends `cd $SAW_AGENT_WORKTREE &&` to every bash command via `updatedInput`, eliminating manual cd commands
- `validate_write_paths` (PreToolUse:Write/Edit): Blocks relative paths and out-of-bounds writes in worktree context
- `verify_worktree_compliance` (SubagentStop): Non-blocking audit trail for post-hoc violation analysis

**E44: Context Injection Observability.** Scout records how reference files were received (`injection_method`: hook/manual-fallback/unknown), and `prepare-agent` writes `context_source` to each agent entry (prepared-brief/cross-repo-full/fallback-full-context) for telemetry and debugging.

Agents cannot violate the protocol even if prompted to. Enforcement lives below the agent's decision layer. The three enforcement layers are:

1. **Claude Code hooks** (Layer 1) -- 18 hooks across PreToolUse/PostToolUse/SubagentStop/UserPromptSubmit: enforcement hooks block protocol violations (ownership I1, role separation I6, worktree isolation E43, branch drift, IMPL validation E16, pre-launch gate H5, git ownership, agent completion E42); injection hooks prepend conditional reference content at two layers (`inject_skill_context` targets the Orchestrator via `UserPromptSubmit` + `additionalContext`, `validate_agent_launch` targets subagents via `PreToolUse` + `updatedInput` for 3 conditional references); observability hooks emit structured events for monitoring and cost tracking.
2. **Git pre-commit hooks** (Layer 2) -- ownership verification at commit time, catching violations that bypass Layer 1.
3. **SDK constraint middleware** (Layer 3) -- `tools.Constraints` on every backend, enforcing the same rules programmatically for CLI and daemon execution where Claude Code hooks are not present.

### The IMPL Doc as Coordination Artifact

**I4: IMPL Doc is the Single Source of Truth.** The IMPL doc is a YAML manifest that serves as both planning document and execution record. It contains the suitability verdict, dependency graph, file ownership table, interface contracts, wave structure, agent briefs, scaffold status, quality gates, critic reports, and completion reports. It is git-tracked, machine-parseable, and validated by the engine (E16 structural validation, E37 critic review).

Chat output is ephemeral. The IMPL doc is the record. Downstream agents, the orchestrator, and post-merge verification all read from it.

### Critic Gate

**E37: Pre-Wave Brief Review.** Before agents launch, a critic agent reviews each brief for symbol accuracy, import conflicts, stale references, and ownership gaps. This catches errors in the plan before agents waste compute implementing against incorrect assumptions. The critic produces a structured report with pass/issues/fail verdict; execution blocks on unresolved errors.

### Type Collision Detection

**E41: Cross-Agent Type Name Conflicts.** When multiple agents in a wave define types that will coexist after merge, name collisions cause compilation failures. `check-type-collisions` statically analyzes agent briefs and file ownership to detect type name conflicts before agents launch. This is a pre-flight check in `prepare-wave` -- collisions are reported with specific agent/file/type details so the orchestrator can revise briefs before wasting compute.

### Shared Data Structure Detection

**E45: Scaffold Detection for Shared Types.** Scout automatically detects data structures (structs, enums, type aliases, traits) referenced by 2+ agents by scanning agent task prompts and file ownership. For each detected shared type, Scout adds an entry to the Scaffolds section. The `detect-shared-types` tool automates this via import pattern matching, fuzzy path resolution, and circular dependency detection across Go, Rust, TypeScript, and Python. This prevents I1 violations from duplicate type definitions -- if Agent A and Agent B both define `PreviewData`, the merge fails. Scaffolding shared types before Wave 1 eliminates this class of failure.

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

For projects spanning multiple features, the PROGRAM layer provides tier-gated execution of multiple IMPLs. Tiers execute sequentially; IMPLs within a tier execute in parallel. This is structural coordination with the same correctness guarantees SAW provides within a single feature.

**PROGRAM invariants:**
- **P1: IMPL Independence Within a Tier** -- no two IMPLs in the same tier share file ownership (greedy graph coloring for disjoint tier assignment)
- **P2: Program Contracts Precede Tier Execution** -- cross-IMPL interface contracts freeze at tier boundaries (E30)
- **P3: Tier Sequencing** -- tier N+1 does not launch until tier N gate verification passes (E29)
- **P4: PROGRAM Manifest is Source of Truth** -- cross-IMPL progress tracking, contract declarations, tier structure (E32)
- **P5: IMPL Branch Isolation** -- each IMPL's wave merges target a dedicated branch (E28B); main advances only when a full tier is verified

**Program creation supports two directions:**

**Top-down:** `/saw program plan "description"` launches a Planner agent that decomposes the project into features, identifies cross-feature dependencies, and produces a PROGRAM manifest with tier assignments before any Scout runs. Scouts then execute with awareness of their tier context. The Planner uses BFS unblocking score to prioritize IMPLs by critical path and assigns concurrency caps per tier.

**Bottom-up:** `/saw program --from-impls slug1 slug2 ...` assembles a PROGRAM manifest from pre-existing IMPL docs via `create-program`. The `check-impl-conflicts` command runs greedy graph coloring to compute disjoint tier assignments. Both paths produce the same PROGRAM manifest format and execute identically from that point forward.

**Program execution:** `program-execute` runs the tier loop (E28): launches Scouts in parallel (E31), tracks cross-IMPL progress (E32), runs tier gate verification (E29), and auto-advances in `--auto` mode (E33). On tier gate failure, `program-replan` re-engages the Planner to revise the PROGRAM manifest (E34). DAG prioritization scores IMPLs by unblocking value within each tier for optimal parallelism.

A program with 5 IMPLs across 3 tiers executes with the same confidence as a single 3-wave IMPL: file ownership is disjoint (P1+), dependencies are ordered (P3), and verification gates fire at every boundary (E29).

### Batching Commands

SAW uses **atomic batching commands** to combine multi-step workflows into single operations with transactional semantics. Each batching command succeeds or fails as a unit with structured JSON output. This pattern eliminates the most common source of silent protocol violations: forgotten steps in manual orchestration.

**Core batching commands:**
- **`run-scout`**: Launch Scout → Validate (E16) → Auto-fix → Finalize gates → Detect shared types (E45) → Return validated IMPL
- **`prepare-wave`**: Baseline gates (E21A) → Repo validation → Create worktrees → Extract briefs → Init journals → Verify hooks (E43) → Type collision check (E41) → Critic review (E37) → Return worktree paths
- **`finalize-wave`**: Verify commits (I5) → Scan stubs (E20) → Run gates (E21) → Merge → Verify build → Integration gaps (E25/E26) → Wiring validation (E35) → Cleanup → Return result
- **`finalize-impl`**: Validate (E16) → Populate gates → Validate again → Return status
- **`prepare-tier`**: Cross-IMPL conflict check (P1+) → Create IMPL branches (E28B, P5) → Coordinate worktree creation → Return tier readiness
- **`finalize-tier`**: Tier gate verification (E29) → Contract freezing (E30) → Cross-IMPL merge coordination → Return tier completion

The web application and CLI orchestrator both consume these batching commands identically -- there is no divergence in business logic between execution paths.

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
- **Notification System** -- browser push notifications and in-app toasts for 9 event types (wave complete, agent failed, merge complete/failed, scaffold complete, build verify pass/fail, plan complete, run failed), with per-event muting and preferences persisted in `saw.config.json`
- **Base16 Theming** -- 200+ color themes with dark/light mode and live preview
- **Bedrock SSO** -- browser-based device authorization for AWS credentials

The observability event schema (E40) defines three event types -- `cost` (token usage and USD estimates per agent), `agent_performance` (execution outcomes), and `activity` (orchestrator actions) -- enabling cost tracking, trend analysis, and performance dashboards.

## Capabilities by Phase

**Planning:** Scout codebase analysis, quantitative suitability scoring, dependency graph construction, automatic wave assignment (topological solver), file ownership assignment, interface contract specification, shared data structure detection (E45), PROGRAM manifests with automatic tiering, structured requirements interviews (E39), IMPL amendment for mid-execution adaptation (E36), `sawtools init` zero-config project initialization with auto-detection (Go/Rust/Node/Python/Ruby/Makefile).

**Validation:** E16 IMPL structural validation with auto-fix (`validate --fix` auto-corrects invalid gate types and strips unknown keys), E37 critic brief review with pass/issues/fail verdict, E41 type collision detection (AST-based duplicate detection in same package), E45 shared data structure detection (prevents duplicate type definitions), P1+ cross-IMPL file ownership conflict detection, E21A/E21B baseline gate verification (pre-wave build/test verification with parallel execution and gate result caching E38, including cross-repo), H5 pre-launch agent validation (8 checks), scaffold correctness verification, E35 wiring obligation enforcement.

**Execution:** Wave agents in git worktrees with E43 hook-based isolation enforcement (4 hooks: environment injection, auto-cd, path validation, compliance verification), solo wave optimization for single-agent waves (executes directly on branch without worktree overhead), 3-layer ownership enforcement (hooks, git pre-commit, SDK middleware), tool journal tracking (E23A) with checkpoint system and prior-work context injection for retries, incremental commits with auto-commit for API/Bedrock agents, cross-repository orchestration with coordinated merge ordering, integration waves (E27) for wiring-only work, LLM-powered code review with dimensional scoring, agent launch prioritization (critical path depth scheduling), per-role model configuration (Scout/Wave/Critic/Scaffold/Integration/Planner each configurable).

**Finalization:** Post-merge build verification (per-repo for cross-repo IMPLs), E20 stub scanning (8 stub patterns across 8 languages), E25/E26 integration gap detection and automated wiring (AST-based export scanning with action prefix/suffix classification), E35 wiring obligation verification (Layer 3B: validates all declared wiring fulfilled), IMPL archival with CONTEXT.md history (E18), gate caching (E38) for idempotent re-runs (5-minute TTL keyed on headCommit+diffStat+command), gate timing split (pre-merge vs post-merge execution), cross-repo merge coordination (branches checked/merged/cleaned in correct sibling repos), worktree reuse for agent reruns.

**Recovery:** E19 failure type classification (transient/fixable/needs_replan/escalate/timeout) with automatic orchestrator action routing; E19.1 per-IMPL `reactions:` block overrides default routing per failure type with custom action and max_attempts; autonomy gating (gated/supervised/autonomous) controls which stages require human approval; daemon-mode auto-remediation loop retries build failures up to a configurable limit before escalating. Session resume detection with progress percentage and suggested actions, structured retry context with error classification, multi-language build failure diagnosis (Go, JS/TS), error parsing with file/line extraction, prior-work context injection via tool journals.

**Observability:** Structured completion reports with context injection metadata (E44), hook enforcement audit trail, cost/agent_performance/activity event schema (E40) with token usage and USD estimates per agent, tool call event streaming (SSE), agent progress tracking, CONTEXT.md project history, web dashboard with 15+ review panels and real-time monitoring, browser push notifications with per-event muting (9 event types: wave complete, agent failed, merge complete/failed, scaffold complete, build verify pass/fail, plan complete, run failed), SQLite observability store with query interface, drift signal detection (stuck reading without implementing).

## Evidence

The protocol is self-hosting. The scout-and-wave protocol repository, Go SDK, and web application were built using SAW. CONTEXT.md records 30+ completed features executed through the protocol, ranging from 1-wave/2-agent documentation fixes to 5-wave/26-agent cross-cutting refactors. The PROGRAM layer's first real execution (a 3-tier, 5-IMPL unification project) drove the discovery and resolution of 13 integration gaps (P1-P13) -- gaps that would not have been found without running the protocol at scale on its own codebase.

Dogfooding surfaces real issues. A Scout analyzing the Go engine's agent prompt loading discovered two pre-existing silent path bugs: `RunScout` was loading from `implementations/claude-code/prompts/scout.md` (does not exist) and `RunPlanner` from `agents/planner.md` (relative to repo root, also does not exist). `RunPlanner` had a fallback string that masked the failure; `RunScout` would have errored on any web/API execution path. Both were caught before execution, fixed in the same IMPL that added reference injection. This is the expected property of a system that analyzes itself before acting.

The critic gate also catches planning errors before compute is wasted. During the progressive disclosure extraction project, a pre-wave critic review caught that the planned hook output format used `additionalContext` (which targets the orchestrator's context) rather than `updatedInput` (which modifies the subagent's prompt). Three critic cycles -- not execution failures -- corrected the mechanism before any agent ran. The correctness of the final implementation is traceable to the review process, not to getting it right on the first try.

The Go SDK contains 34 packages across engine, protocol, hooks, resume, retry, journal, collision detection, autonomy, suitability analysis, wave solver, pipeline framework, build diagnostics, error parsing, code review, scaffold validation, notification system, gate caching, worktree management, four LLM backends (Anthropic API, Bedrock, OpenAI-compatible, CLI), constraint enforcement, and configuration. The CLI exposes 60+ commands. The web app ships 70+ React components with real-time SSE streaming, Base16 theming, and Bedrock SSO -- all embedded in a single Go binary.

This is production infrastructure, not a proof of concept.
