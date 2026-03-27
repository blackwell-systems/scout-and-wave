# Competitive Analysis: Scout-and-Wave vs Agent Orchestrator

**Date:** 2026-03-24
**Last updated:** 2026-03-26 (reactions system update)
**Analyst scope:** Full codebase review of both systems
**AO commit base:** ComposioHQ/agent-orchestrator (main branch, March 2026)

---

## 1. Executive Summary

**Scout-and-Wave (SAW)** is a coordination protocol for parallelizing LLM agent work on shared codebases. It treats parallel agent work as a distributed systems problem and solves it structurally: disjoint file ownership eliminates merge conflicts by construction, interface contracts freeze APIs before agents start, and wave sequencing gates progression on verified boundaries. SAW is split across three repositories (protocol spec, Go SDK/CLI, web dashboard) and targets users who need provable correctness guarantees when running multiple agents on the same codebase. Its primary audience is developers working on complex features that benefit from structured decomposition and parallel execution within a single feature scope.

**Agent Orchestrator (AO)** by Composio is a session management platform for fleets of independent AI coding agents. It treats each agent as an autonomous worker on a separate issue/ticket: one agent per issue, one worktree per agent, one PR per agent. AO is a TypeScript/pnpm monorepo with a plugin architecture spanning 8 plugin slots and 20+ plugins. Its primary audience is teams with large issue backlogs who want to throw agents at many tickets simultaneously and monitor the fleet from a dashboard. AO excels at the operational lifecycle -- spawning, monitoring, reacting to CI failures, routing review comments, and cleaning up completed sessions.

The fundamental philosophical difference: **SAW coordinates agents working on the same feature** (preventing conflicts between agents that must integrate); **AO coordinates agents working on different features** (managing a fleet of independent workers). SAW's core innovation is structural conflict prevention; AO's core innovation is autonomous lifecycle management. They solve different problems and could, in principle, be complementary -- AO could orchestrate multiple SAW executions, or SAW could use AO's lifecycle management for its wave agents.

---

## 2. Architecture Comparison

### SAW Architecture

```
+------------------+     +--------------------+     +--------------------+
|  Protocol Spec   |     |    Go SDK/CLI      |     |    Web App         |
|  (scout-and-wave)|     | (scout-and-wave-go)|     |(scout-and-wave-web)|
+------------------+     +--------------------+     +--------------------+
| Invariants (I1-6)|     | 33 Go packages     |     | React + Go API     |
| Exec Rules (E1-42)     | 4 LLM backends     |     | SSE streaming      |
| Agent Prompts    |     | 60+ CLI commands   |     | 70+ components     |
| /saw Skill       |     | Engine + Pipeline  |     | Embedded binary    |
+------------------+     +--------------------+     +--------------------+
         |                        |                        |
         v                        v                        v
    Language-agnostic         Importable Go module     go:embed assets
    specification             (pkg/engine, etc.)       Single binary deploy
```

Key architectural properties:
- **Three-repo separation**: protocol spec is language-agnostic, SDK is Go, web consumes SDK
- **Three execution modes**: Agent Skill (/saw in Claude Code), CLI (sawtools binary), Go SDK
- **Three enforcement layers**: Claude Code hooks, git pre-commit hooks, SDK constraint middleware
- **Seven participant roles**: Orchestrator, Scout, Human, Scaffold, Wave Agent, Integration Agent, Critic
- **Single source of truth**: IMPL doc is both plan and execution record (I4)

### AO Architecture

```
+----------------------------------------------------------+
|                   pnpm monorepo                          |
+----------------------------------------------------------+
|  packages/core/     |  packages/cli/  |  packages/web/   |
|  - types.ts         |  - ao command   |  - Next.js app   |
|  - session-manager  |  - 13 commands  |  - 11 components |
|  - lifecycle-manager|                 |  - SSE streaming  |
|  - decomposer       |                 |  - API routes     |
|  - config (Zod)     |                 |                   |
|  - observability    |  packages/mobile/                   |
|  - plugin-registry  |  - React Native app                |
+----------------------------------------------------------+
|  packages/plugins/ (20 plugins across 8 slots)           |
|  runtime:   tmux, process                                |
|  agent:     claude-code, codex, aider, opencode          |
|  workspace: worktree, clone                              |
|  tracker:   github, linear, gitlab                       |
|  scm:       github, gitlab                               |
|  notifier:  desktop, slack, webhook, composio, openclaw  |
|  terminal:  iterm2, web                                  |
+----------------------------------------------------------+
```

Key architectural properties:
- **Single monorepo**: all packages colocated, workspace dependencies
- **Plugin-everything**: 8 plugin slots with manifest + create() pattern
- **Orchestrator-worker model**: one orchestrator agent (read-only) spawns N worker agents
- **Polling-based lifecycle**: 30s polling loop detects state transitions, triggers reactions
- **Issue-centric**: each session maps to one issue/ticket
- **Hash-based namespacing**: SHA-256 of config path prevents multi-checkout collisions

---

## 3. Feature Matrix

| Category | SAW | AO | Notes |
|----------|-----|-----|-------|
| **Planning / Decomposition** | | | |
| Dedicated planning phase | Scout agent analyzes codebase, produces IMPL | LLM-based task decomposer (classify atomic/composite) | SAW's Scout is far more sophisticated -- suitability scoring, dependency graphs, file ownership assignment |
| Suitability analysis | Quantitative scoring (pkg/suitability) | None | SAW can say "don't parallelize this" |
| Dependency graph | Explicit dependency declarations, topological solver (pkg/solver) | Implicit via decomposition hierarchy | SAW computes wave assignments automatically |
| File ownership planning | Disjoint ownership per agent per wave | None -- agents work on separate issues | Fundamental difference: SAW prevents intra-feature conflicts |
| Interface contracts | Scaffold agent commits shared types before agents start | None | SAW's I2 invariant prevents API hallucination |
| Plan review | REVIEWED checkpoint, critic review (E37) | Optional human approval of decomposition | SAW has multi-stage review: human + automated critic |
| Requirements gathering | Structured 6-phase interview mode (E39) | None | |
| **Parallel Execution** | | | |
| Parallelism model | Wave-based: agents in same wave run in parallel | Fleet-based: all agents independent, run in parallel | Different goals -- SAW coordinates, AO isolates |
| Worktree isolation | Per-agent per-wave worktrees | Per-session worktrees | Both use git worktrees |
| File ownership enforcement | 3-layer enforcement (hooks, pre-commit, SDK middleware) | None -- not needed since agents work on different issues | |
| Max concurrent agents | Wave-bounded (typically 2-8 per wave) | Unbounded (limited by system resources) | |
| Solo wave optimization | Skips worktree for single-agent waves | N/A | |
| **Conflict Prevention** | | | |
| Merge conflict prevention | Structural (I1 -- impossible by construction) | Structural (separate issues = separate files, usually) | SAW guarantees it; AO relies on issue independence |
| Type collision detection | Pre-flight check (E41) | None | |
| Cross-feature file ownership | PROGRAM layer P1+ validation | None | |
| Interface freeze | I2 -- contracts freeze at worktree creation | None | |
| **Integration / Merge** | | | |
| Merge strategy | Sequential merge at wave boundaries with verification | Each agent creates its own PR, merged independently | |
| Post-merge verification | Build verification, stub scanning (E20), integration gaps (E25/E26) | CI checks via SCM plugin | SAW verifies structural completeness, not just "does it build" |
| Integration agent | Dedicated role for wiring exports (E27) | None | |
| Wiring obligation tracking | E35 -- verifies all exports are connected | None | |
| **Provider Support** | | | |
| LLM providers | Anthropic API, Bedrock, OpenAI-compatible, CLI wrapper | N/A (wraps existing agent tools) | Different approach -- SAW drives LLMs directly, AO wraps tools |
| Agent tools supported | Claude Code (via /saw skill), any via CLI/SDK | Claude Code, Codex, Aider, OpenCode | AO supports more agent tools out of the box |
| Per-role model selection | 7 roles with independent model config | Worker vs orchestrator model config | SAW is more granular |
| Local model support | Via OpenAI-compatible backend (Ollama, etc.) | Via agent tools that support it | |
| **Runtime Environments** | | | |
| Local execution | Direct process, worktrees | tmux, direct process | |
| Container support | None built-in | Docker plugin slot (defined, not implemented) | AO has the abstraction ready |
| Cloud sandbox | None | E2B plugin slot (defined, not implemented) | |
| SSH remote | None | SSH plugin slot (defined, not implemented) | |
| Kubernetes | None | K8s plugin slot (defined, not implemented) | |
| **Issue Tracker Integration** | | | |
| GitHub Issues | None | Full integration (fetch, create, update, close) | **SAW weakness** |
| Linear | None | Full GraphQL integration with Composio SDK fallback | **SAW weakness** |
| GitLab Issues | None | Plugin available | **SAW weakness** |
| Jira | None | Plugin slot available | **SAW weakness** |
| Issue-to-session mapping | None | Core feature -- `ao spawn INT-1234` | **SAW weakness** |
| Batch issue processing | None | `ao batch-spawn INT-1 INT-2 INT-3` | **SAW weakness** |
| **Notification Channels** | | | |
| Desktop notifications | Browser push notifications + in-app toasts (9 event types, per-event muting) | Native desktop notifications (node-notifier) | Both have push notifications |
| Slack | Webhook adapter in `saw.config.json` (Slack, Discord, Telegram) | Slack webhook plugin | SAW added webhook adapter support |
| Generic webhooks | `webhooks.adapters` in `saw.config.json`; configurable via Web UI Settings | Webhook notifier plugin | Gap narrowed; AO's routing-by-priority still more sophisticated |
| Composio integration | None | Composio notifier plugin | |
| Priority-based routing | None | Notification routing by priority level | **SAW weakness** |
| **Web Dashboard** | | | |
| Real-time updates | SSE streaming | SSE streaming | Both use SSE |
| Session/agent cards | Per-wave agent cards with tool feeds | Per-session cards with attention zones | Different focus |
| IMPL/plan review | 15+ panels for deep plan inspection | None -- no plan artifact | SAW's IMPL review is unique |
| PR tracking | None | Full PR table with CI checks, review state, mergeability | **SAW weakness** |
| Kanban-style board | Wave board (per-wave status) | Attention zones (merge/respond/review/pending/working/done) | AO's attention model is operationally superior for fleet management |
| One-click actions | Recovery controls (resume, retry, amend) | Send message, kill, merge PR, restore | Different action sets for different workflows |
| Multi-project support | Single project per execution | Multi-project with sidebar navigation | **SAW weakness for fleet use case** |
| Cost tracking | Per-agent token/USD via E40 events | Per-session token/USD from agent JSONL | Both track costs |
| Theming | 200+ Base16 themes | CSS variables | SAW has more theming options |
| Command palette | Keyboard-driven navigation | None visible | |
| File browser | Tree view with diff viewer | None | |
| Chat panel | Conversational agent interaction | None | |
| **Mobile Support** | | | |
| Mobile app | None | React Native app with 7 screens | **SAW weakness** |
| **CLI Experience** | | | |
| Command count | 60+ commands (sawtools) | ~15 commands (ao) | SAW has more granular commands |
| Quick start | `git clone` + `./install.sh` + `go install sawtools` + `sawtools init` (4 steps, largely automated) | `npm install -g @composio/ao && ao start` | **AO still wins on simplicity; SAW gap narrowed** |
| One-command setup | None; `./install.sh` automates Claude Code config (hooks, settings.json, Agent permission); `sawtools init` auto-detects project | `ao start https://github.com/org/repo` | **AO's killer onboarding feature remains; SAW automation improved** |
| Homebrew install | `brew install blackwell-systems/tap/sawtools` | npm global install | Both support package manager install |
| Install verification | `sawtools verify-install` command | None documented | SAW added structured install verification |
| Daemon mode | sawtools daemon (queue-based) | ao start (lifecycle manager) | Both support long-running operation |
| **Onboarding / Quick Start** | | | |
| Time to first use | `git clone` + `./install.sh` (auto-configures Claude Code) + `brew/go install sawtools` + `sawtools init` | `npm install -g @composio/ao && ao start` | **AO still faster; SAW reduced from 5+ manual steps to 4 with automation** |
| Config complexity | `sawtools init` auto-generates `saw.config.json`; `./install.sh` handles all hook registration | agent-orchestrator.yaml (or auto-generated) | Both now have auto-detection |
| Documentation | Installation guide, quickstart with worked example, protocol spec (13 docs), hooks reference, 4-part blog series | README + SETUP.md + DEVELOPMENT.md + examples/ | SAW documentation substantially more organized than previously |
| **Plugin / Extensibility Model** | | | |
| Extension model | Go SDK (import packages) | TypeScript plugin system (8 slots, manifest+create) | AO's plugin model is more accessible |
| Plugin hot-loading | No | Dynamic import at startup | |
| Custom plugins | Write Go packages | npm packages or local files | |
| **CI/CD Integration** | | | |
| CI-driven execution | sawtools CLI callable from pipelines | ao CLI callable from pipelines | Both support it |
| CI failure handling | E19 failure classification (5 types) + E19.1 per-IMPL reactions override; daemon mode auto-remediation via `pkg/engine/auto_remediate.go` with 3-level autonomy gating (gated/supervised/autonomous) | Reaction system auto-sends fix instructions to agent | Both have automated failure handling; AO's is lifecycle-polling-based and CI-aware; SAW's is classification-based and triggers at wave finalization |
| Webhook support | None | GitHub webhook endpoint for push events | **SAW weakness** |
| **Recovery / Retry** | | | |
| Session resume | resume-detect with progress %, suggested actions | Session restore with workspace recreation | |
| Retry context | Structured error classification, prior-work injection | Auto-send instructions on CI failure (reaction) | SAW provides richer context for retries |
| Build failure diagnosis | Multi-language error parsing (Go, JS/TS) | None -- delegates to agent | |
| **Observability** | | | |
| Structured events | E40 event schema (cost, agent_performance, activity) | Process-level JSON snapshots with metrics, traces, health | |
| Correlation IDs | None visible | UUID-based correlation across operations | AO has better operation tracing |
| Health surfaces | None | Per-component health with ok/warn/error status | |
| Structured logging | None standardized | JSON stderr with log levels | |
| **Code Review** | | | |
| LLM-powered review | pkg/codereview with dimensional scoring | None | |
| Review comment routing | None | Auto-forwards review comments to agent | **AO weakness for proactive review; SAW weakness for reactive review** |
| **Multi-Project Coordination** | | | |
| Multi-feature coordination | PROGRAM layer with tier-gated IMPLs | Multi-project config with project sidebar | Different scope |
| Cross-project dependencies | P1+ cross-IMPL file ownership validation | None | |
| **Testing Infrastructure** | | | |
| Unit tests | Go tests (standard library) | Vitest with ~11K lines of test code, 19 test files in core | |
| Integration tests | Not explored | Dedicated integration-tests package | |
| Test count (claimed) | Not stated | 3,288 test cases (per README badge) | |
| **Documentation** | | | |
| Protocol specification | 13 formal documents in protocol/ | docs/specs/ (2 files), docs/DEVELOPMENT.md | SAW has far more rigorous specification |
| Examples | Self-hosting (dogfooding) | examples/ directory with 5 example configs | AO has more approachable examples |

---

## 4. SAW Strengths (things AO cannot match)

### Structural Conflict Prevention (I1)

SAW's disjoint file ownership invariant makes merge conflicts impossible by construction. This is enforced at three layers (Claude Code hooks, git pre-commit, SDK middleware), not by agent cooperation. AO relies on the assumption that different issues touch different files -- a reasonable assumption for small fixes, but one that breaks down for related features, refactors, or any work that touches shared infrastructure. AO has no mechanism to detect or prevent file conflicts between sessions.

This matters because: at scale, as AO spawns more agents on a codebase, the probability of file conflicts grows. AO currently has no answer for this beyond "each agent makes its own PR and conflicts are resolved during merge."

### Interface Contracts and Scaffold Agent (I2)

SAW materializes shared types as committed source files before any agent starts implementing. This eliminates the class of failures where Agent A expects function signature X but Agent B implements signature Y. AO has no equivalent -- its agents are fully independent and never share interfaces.

### Wave Sequencing with Verified Boundaries (I3)

SAW's wave model ensures that dependent work is sequenced correctly and that each wave boundary is a verification checkpoint (build, test, stub scan, integration gap detection). AO's agents run independently with no ordering guarantees between them.

### The IMPL Doc as Coordination Artifact (I4)

SAW's IMPL doc serves as both planning document and execution record -- a machine-parseable YAML manifest that is git-tracked, validated (E16), and read by all participants. AO has no equivalent coordination artifact. Session metadata files are operational state, not planning documents.

### Critic and Type Collision Detection (E37, E41)

SAW catches errors in the plan before agents waste compute. The critic reviews briefs for symbol accuracy, and type collision detection prevents naming conflicts across agents. AO has no pre-execution validation of this kind.

### Multi-Feature Structural Coordination (PROGRAM Layer)

SAW's PROGRAM layer provides tier-gated execution of multiple IMPLs with cross-IMPL file ownership validation (P1+). This is genuine multi-feature coordination with the same correctness guarantees. AO's multi-project support is operational management (different dashboards), not structural coordination.

### LLM-Powered Code Review (pkg/codereview)

SAW includes dimensional quality scoring of diffs that can gate merges. AO has no equivalent and relies entirely on external CI and human reviewers.

### Formal Protocol Specification

SAW's 13 protocol documents (invariants, execution rules, state machine, participant definitions, etc.) provide a rigorous specification that enables independent implementations. AO has no formal specification -- behavior is defined by the code.

---

## 5. AO Strengths (things SAW should learn from)

### Onboarding is Still Meaningfully Easier

*(Updated 2026-03-26: SAW's installation story has improved substantially; the gap has narrowed.)*

AO's `npm install -g @composio/ao && ao start https://github.com/org/repo` gets a user from zero to working system in under a minute. SAW now has a more automated path: `git clone` + `./install.sh` (which auto-configures Claude Code's settings.json, registers 11 hooks, and adds Agent permission) + `brew install blackwell-systems/tap/sawtools` + `sawtools init` (auto-detects language and build commands). The installer is idempotent, verifiable with `sawtools verify-install`, and includes smoke tests. This is meaningfully better than the previous manual multi-step process.

However, the structural gap remains. SAW requires cloning a separate protocol repo to obtain skill files, then separately installing a Go binary. AO is one npm package. The minimum prerequisite surface for SAW (Git 2.20+, Go 1.25+, jq) is heavier than AO's (npm). Until SAW can be installed without cloning the protocol repo, the first-use experience will remain more involved than AO's one-command flow.

The honest framing: SAW went from "requires reading docs to figure out 5+ manual steps" to "4 commands with automation and verification." AO remains "one command." The difference still matters for first impressions.

**Specific code reference:** `packages/cli/src/commands/start.ts` handles the entire bootstrap: clone repo if URL, find/create config, init workspace hooks, spawn orchestrator, start lifecycle manager, launch dashboard. One command does everything.

### The Reaction Engine is Genuinely Valuable (but the gap has narrowed)

*(Updated 2026-03-26)*

AO's lifecycle manager (`packages/core/src/lifecycle-manager.ts`, 921 lines) implements a polling-based state machine that:
- Detects 14 state transitions (spawning -> working -> pr_open -> ci_failed -> etc.)
- Automatically sends fix instructions to agents when CI fails
- Routes review comments back to the responsible agent
- Escalates to human notification after configurable retry counts
- Tracks reaction attempts per session with fingerprinting to avoid duplicate dispatches

**Specific code reference:** `lifecycle-manager.ts:368-492` -- the `executeReaction` function with attempt tracking, escalation thresholds, and configurable retry counts.

SAW now has a meaningful failure-handling stack of its own, though it works differently:

- **E19 failure classification** (`pkg/protocol/failure.go`, `pkg/orchestrator/failure.go`) — agents tag completion reports with one of 5 failure types (`transient`, `fixable`, `needs_replan`, `escalate`, `timeout`). `RouteFailure()` maps each type to an orchestrator action (retry, apply-fix-and-relaunch, replan, escalate, retry-with-scope). Fully implemented and wired in both `orchestrator.go` and `structured_wave.go`.
- **E19.1 per-IMPL reactions override** (`pkg/protocol/reactions_validation.go`) — the IMPL manifest can include a `reactions:` block that overrides E19 defaults per failure type, specifying action and max_attempts. Validated by `ValidateReactions()` and displayed in the web UI's ReactionsPanel. The override routing functions (`RouteFailureWithReactions`, `MaxAttemptsFor`) are fully implemented and tested but are classified as an advisory gap by the wiring audit — they are not yet called from the production orchestrator code path.
- **Autonomous post-merge remediation** (`pkg/engine/auto_remediate.go`, `pkg/engine/daemon.go`) — in daemon mode with `autonomy: supervised` or `autonomous`, `AutoRemediate()` runs a configurable retry loop after a failed wave finalization, calling a fix agent (`FixBuildFailure`) then re-running `VerifyBuild`. Wired in the daemon run loop at `daemon.go:303`.
- **Three-level autonomy gating** (`pkg/autonomy/`) — `gated` (all stages require human approval), `supervised` (wave advance, gate failure, and queue advance are auto-approved; IMPL review is not), `autonomous` (all stages auto-approved). Controls whether `AutoRemediate` fires automatically.

The remaining gap relative to AO: AO's reaction engine is triggered by external state (CI checks, review comments, PR status changes) detected via polling. SAW's auto-remediation triggers at wave finalization boundaries only and is not yet integrated with external CI state or review comment routing. For pure build/test failures during wave teardown, SAW's daemon mode now handles this automatically. For CI failures that occur asynchronously after merge, or for PR review comment routing, SAW has no equivalent.

### Agent-Agnostic Plugin Architecture

AO's 8-slot plugin system (`packages/core/src/types.ts:204-595`) defines clean interfaces for Runtime, Agent, Workspace, Tracker, SCM, Notifier, and Terminal. Adding a new agent tool requires implementing ~8 methods. Adding a new issue tracker requires implementing ~6 methods. The plugin registry (`packages/core/src/plugin-registry.ts`) handles discovery and loading.

SAW's Go SDK is importable but not plugin-oriented. Adding a new LLM backend requires implementing the Backend interface (3 methods), but adding a new issue tracker or notification channel requires building it from scratch. SAW has no abstraction for these concerns.

**Specific code reference:** `packages/core/src/plugin-registry.ts:26-54` -- 20 built-in plugins registered by name and slot.

### Issue Tracker Integration is a Real Feature

AO's tracker plugins (GitHub, Linear, GitLab) provide:
- Issue fetching with full metadata
- Automatic branch naming from issue identifiers
- Prompt generation from issue content
- Issue state updates (mark completed when PR merges)
- Issue creation (for decomposed subtasks)
- Listing with filters

SAW has zero issue tracker integration. Users must manually describe features in natural language. For teams with existing backlogs in Linear or GitHub Issues, AO lets them point-and-click; SAW requires copy-pasting issue descriptions.

**Specific code reference:** `packages/plugins/tracker-linear/src/index.ts` -- 722 lines of full Linear GraphQL integration including issue CRUD, label management, and dual transport (direct API + Composio SDK fallback).

### Notification Routing by Priority

AO's notification system routes events to different channels based on priority:
```yaml
notificationRouting:
  urgent: [desktop, slack]
  action: [desktop, composio]
  warning: [composio]
  info: [composio]
```

This means urgent events (agent stuck, needs input) trigger desktop notifications, while informational events (session started) go to a log. SAW's web dashboard shows events but has no push notification mechanism.

**Specific code reference:** `packages/core/src/config.ts:192-197` and `lifecycle-manager.ts:687-701`.

### Mobile App

AO has a React Native mobile app (`packages/mobile/`) with 7 screens: Home, Session Detail, Terminal, Orchestrator, Commands, Spawn Session, and Settings. SAW has no mobile presence. For monitoring a fleet of agents while away from the desk, this matters.

### PR Lifecycle Management

AO tracks the full PR lifecycle: creation, CI status, review decision, mergeability, merge conflicts, and auto-detection of PRs by branch name. The dashboard shows a PR table with CI checks, review state, and one-click merge. The lifecycle manager automatically detects when a PR is created (even without hooks) via branch-based PR detection.

SAW has no PR tracking at all. Each wave's merge is handled internally by the engine, but there is no visibility into external CI or review status.

**Specific code reference:** `lifecycle-manager.ts:283-348` -- PR auto-detection and full state polling.

### SSE with Attention-Based Prioritization

AO's dashboard groups sessions into "attention zones" (merge, respond, review, pending, working, done) that tell the operator exactly where to focus. This is better UX than a flat list of sessions.

**Specific code reference:** `packages/web/src/components/AttentionZone.tsx` -- kanban-style grouping by urgency.

### Hash-Based Instance Isolation

AO uses SHA-256 of the config file path to namespace all runtime data. Multiple orchestrator instances on the same machine never collide. SAW does not have this problem (each IMPL creates its own worktrees), but AO's approach is more robust for long-running daemon scenarios.

---

## 6. Things We Could Borrow

### 1. One-Command Start Experience

*(Updated 2026-03-26: Partially addressed. `sawtools init` now exists and auto-detects projects; `./install.sh` handles Claude Code configuration automation. The remaining gap is removing the clone-the-protocol-repo requirement from the install flow.)*

**What it is:** `ao start` bootstraps everything -- config creation, hook installation, dashboard launch, orchestrator spawn -- in a single command.

**Why it matters:** SAW's installation required 5+ manual steps. That is now 4 steps with automation, but still not one command.

**Remaining work:** Package the skill files and install script so users don't need to clone the protocol repo. A `sawtools install-skill` subcommand that downloads skill files from a release artifact would complete this. The `sawtools init` and `./install.sh` work is done; the missing piece is eliminating the manual clone step.

**Rough effort:** Small-Medium (1 week). The scaffolding (`sawtools init`, `./install.sh`) already exists; the remaining work is distributing skill files via the Go binary or a hosted artifact.

**Repos affected:** scout-and-wave-go (embed or download skill files), scout-and-wave (release artifact packaging)

### 2. External CI/Review Feedback Loop (Partially Addressed)

*(Updated 2026-03-26)*

**What it is:** A polling loop that detects CI failures and review comments on open PRs, automatically sends fix instructions to agents, retries with configurable limits, and escalates to human notification.

**What's already built:** SAW's daemon mode now has automated build-failure remediation (`pkg/engine/auto_remediate.go`) with three-level autonomy gating and configurable retries. This handles the most common failure case (build/test fails at wave teardown) automatically.

**Remaining gap:** AO's lifecycle polling detects CI failures that occur asynchronously after push, and routes PR review comments back to agents. SAW has neither. Closing this gap requires: (1) polling GitHub CI check status after wave merge, (2) detecting review comments and routing them to a re-launch of the responsible agent. This is a bounded addition to the existing daemon polling loop.

**Rough effort:** Medium (1-2 weeks). The remediation loop is already built; the remaining work is CI status polling (via gh CLI) and review comment detection. No new autonomy infrastructure is needed.

**Repos affected:** scout-and-wave-go (daemon polling extension), scout-and-wave-web (dashboard integration)

### 3. Issue Tracker Integration

**What it is:** Fetching issues from GitHub/Linear, generating agent prompts from issue content, updating issue state when work completes.

**Why it matters:** Teams with existing backlogs cannot easily feed them into SAW. Adding `/saw scout "fix #123"` where #123 is auto-resolved to full issue context would reduce friction significantly.

**Rough effort:** Medium (2-3 weeks for GitHub, 1-2 more for Linear). Could use gh CLI for GitHub to avoid API complexity.

**Repos affected:** scout-and-wave-go (new pkg/tracker), scout-and-wave (protocol update for issue references)

### 4. Notification Channels (Slack, Desktop, Webhook)

**What it is:** Push notifications for wave completions, failures, and events that need human attention, routed to different channels by priority.

**Why it matters:** SAW's web dashboard requires the user to be watching it. Push notifications enable "fire and forget" workflows where the user is alerted only when needed.

**Rough effort:** Small-Medium (1-2 weeks). Desktop notifications via Go's native notification APIs. Slack via webhook. Generic webhook for extensibility.

**Repos affected:** scout-and-wave-go (new pkg/notify), scout-and-wave-web (notification settings UI)

### 5. Attention-Zone Dashboard Model

**What it is:** Grouping active work items by urgency level (needs merge, needs response, needs review, pending, working) rather than by wave.

**Why it matters:** SAW's wave board shows structure but not urgency. Adding attention zones to the wave board would help operators prioritize their attention, especially during multi-wave executions.

**Rough effort:** Small (1 week). Frontend-only change to add attention classification to existing agent cards.

**Repos affected:** scout-and-wave-web (web components)

### 6. Agent Activity Detection via JSONL

**What it is:** AO reads Claude Code's internal JSONL session files to detect agent state (active, idle, waiting_input, blocked, exited) without relying on terminal output parsing.

**Why it matters:** More reliable than terminal output parsing. Could be used to improve SAW's agent monitoring in the web dashboard.

**Rough effort:** Small (3-5 days). Port the JSONL reading logic to Go.

**Repos affected:** scout-and-wave-go (pkg/agent), scout-and-wave-web (activity display)

---

## 7. SAW Weaknesses Exposed

### The Installation Cliff (Partially Addressed)

*(Updated 2026-03-26)*

AO's one-command start still reveals a gap. SAW's install process has been substantially automated: `./install.sh` now auto-configures Claude Code's settings.json, registers 11 enforcement hooks, and adds the Agent permission. `sawtools init` auto-detects project language and generates `saw.config.json`. `sawtools verify-install` provides structured post-install verification with smoke tests. The process is now 4 commands rather than 5+ manual steps with no verification.

The remaining cliff: users must clone the protocol repo before they can run `./install.sh`. This git clone step — before any functionality is available — is still a barrier AO does not have. A developer who finds SAW via the README cannot install it with a single command.

### No Issue Tracker Integration

SAW has no concept of external work items. Every feature must be described ad hoc in natural language. Teams with hundreds of issues in Linear or GitHub Issues cannot feed them into SAW. AO lets users `ao batch-spawn INT-1 INT-2 INT-3` and walk away.

### Autonomous Feedback Loop: Implemented for Build Failures, Not for External CI

*(Updated 2026-03-26)*

SAW now has automated failure remediation in daemon mode. When a wave finalization fails (build or test failure), `AutoRemediate()` in `pkg/engine/auto_remediate.go` runs a configurable retry loop — calling a fix agent and re-running `VerifyBuild` until the build passes or retries are exhausted. This is wired in the daemon run loop (`pkg/engine/daemon.go`) and gated by the three-level autonomy system: `supervised` or `autonomous` mode enables it automatically; `gated` mode (the default) requires human approval.

What remains unimplemented relative to AO: AO's reaction engine responds to external events — specifically CI check results on open PRs and review comments. SAW's remediation fires only at wave finalization and only for in-process build/test failures it can observe directly. If an agent's work passes local gates but fails CI after being pushed, or if a code reviewer leaves a comment, SAW has no automatic response. AO handles both of these cases via its lifecycle polling loop.

### Push Notifications: Webhook Support Added, Desktop Not Yet

*(Updated 2026-03-26)*

SAW's `saw.config.json` now has a `webhooks` section supporting Slack, Discord, and Telegram adapters, configurable from the Web UI Settings page. This addresses the "no outbound notifications" gap for teams that can configure a webhook endpoint. What remains missing relative to AO: proactive desktop notifications (SAW's web dashboard requires you to have the browser open; AO sends system-level notifications), and priority-based routing (AO routes by urgency level; SAW's webhook config is simpler). The "completely dark" characterization is no longer accurate, but AO's notification story is still more capable for unattended operation.

### No Multi-Agent-Tool Support

SAW's agent skill targets Claude Code specifically. The Go SDK's Backend interface supports different LLM providers (Anthropic, Bedrock, OpenAI), but the agent execution model assumes Claude-like tool use. AO wraps Codex, Aider, and OpenCode as first-class alternatives. Users locked into a specific agent tool may choose AO for compatibility.

*(Note: SAW's README now explicitly references Agent Skills compatibility with Cursor, GitHub Copilot, and other tools, though reference implementations beyond Claude Code are not yet provided.)*

### No Mobile Presence

AO's React Native app allows monitoring from a phone. SAW has no mobile-accessible interface. For autonomous operation where the user walks away, mobile monitoring matters.

### The Fleet Use Case is Unserved

SAW is designed for one feature at a time (or one PROGRAM at a time). A team with 20 issues to fix simultaneously has no SAW workflow for this. AO's fleet model handles this naturally. SAW's PROGRAM layer could theoretically be extended, but it is designed for coordinated multi-feature work, not independent issue farming.

---

## 8. Market Positioning

### Are They in the Same Market?

No. These products overlap in the "AI agents on codebases" space but target fundamentally different use cases:

| Dimension | SAW | AO |
|-----------|-----|-----|
| Primary use case | Complex feature development | Issue backlog processing |
| Agent relationship | Coordinated (shared codebase concern) | Independent (separate issues) |
| Correctness model | Structural guarantees (invariants) | Operational automation (reactions) |
| Planning depth | Deep (Scout, IMPL, dependency graph) | Shallow (decompose into atomic tasks) |
| Human involvement | Heavy at planning, light at execution | Light at spawning, heavy at merge |
| Scale axis | Agents per feature (2-8 typical) | Issues per codebase (10-50+) |
| Value proposition | "Complex features built correctly" | "Issue backlog cleared autonomously" |

### Where They Overlap

- Both use git worktrees for isolation
- Both have web dashboards with SSE
- Both support Claude Code as an agent
- Both have CLI interfaces
- Both track costs

### Where They Diverge

- SAW has no concept of issues/tickets; AO has no concept of interface contracts
- SAW prevents conflicts by construction; AO prevents conflicts by independence
- SAW has formal invariants; AO has configurable reactions
- SAW is Go; AO is TypeScript
- SAW embeds the LLM interaction; AO wraps existing agent tools

### Competitive Threat Level

**Low for SAW's core market.** A team building a complex feature that requires coordinated parallel agents will not find what they need in AO. AO cannot guarantee conflict-free merges between agents working on the same feature. SAW's invariants are structurally inimitable without a fundamental redesign of AO's architecture.

**Moderate for SAW's expansion market.** If SAW wants to move into "general agent fleet management" or "issue backlog processing," AO is already there with a mature product. SAW would need to build issue tracking, reaction engines, and fleet management to compete in that space.

**High for mindshare.** AO's one-command start, 3,288 test cases, active Discord community, and Composio backing give it marketing advantages. A developer who discovers AO first may not look further. SAW's documentation and installation experience have improved (structured install guide, quickstart, Homebrew install, `sawtools init`), and SAW is now published as an [Agent Skills](https://agentskills.io) standard package with positioned compatibility across Claude Code, Cursor, and GitHub Copilot. These improve discoverability and first impressions. The remaining gap is the install flow's repo-clone requirement and the absence of a compelling demo-from-zero experience.

*(Updated 2026-03-26)*

---

## 9. Recommendations

### Priority 1: Complete the Onboarding Story (High — was Critical, now High)

*(Updated 2026-03-26: `sawtools init`, `./install.sh` automation, `sawtools verify-install`, and Homebrew install are all done. Priority reduced from Critical to High. Remaining gap is smaller.)*

**Action:** Eliminate the protocol-repo clone requirement by bundling skill files with the `sawtools` binary (or via a `sawtools install-skill` command that fetches from a release artifact). Goal: reduce installation to 2 steps: `brew install sawtools && sawtools install-skill && sawtools init`.
**Rationale:** The automated install scaffolding is in place. The remaining barrier is requiring users to clone a git repo before any tooling is available. Removing this step would bring SAW's first-use experience to "almost competitive" with AO.
**Effort:** 1 week (scaffolding exists; just needs distribution mechanism)

### Priority 2: External CI/Review Polling (Medium — was High)

*(Updated 2026-03-26: Build-failure auto-remediation in daemon mode is done. Priority and effort reduced.)*

**Action:** Extend the daemon polling loop to detect CI check failures on pushed branches and PR review comments, then trigger the existing `AutoRemediate` machinery or a targeted agent relaunch.
**Rationale:** The auto-remediation engine is built and wired. The remaining gap is hooking external CI state (GitHub check runs) and review comment events into it. This is a bounded addition, not a greenfield build.
**Effort:** 1-2 weeks

### Priority 3: Desktop Push Notifications (Medium — was High)

*(Updated 2026-03-26: Webhook adapters for Slack/Discord/Telegram added. Desktop notifications remain unimplemented.)*

**Action:** Add native desktop notification support (Go notification library) for wave completions, failures, and events requiring human attention.
**Rationale:** Webhook support is now in place for users who configure endpoints. Desktop notifications are the remaining gap for unattended local operation — the common case for individual developers.
**Effort:** 3-5 days

### Priority 4: Issue Tracker Integration (Medium)

**Action:** Add `sawtools scout --issue github:#123` and `sawtools scout --issue linear:INT-456` that fetches issue content and uses it as Scout input.
**Rationale:** Bridges SAW into team workflows with existing backlogs. Low-hanging fruit using gh CLI for GitHub.
**Effort:** 2-3 weeks

### Priority 5: Fleet Mode (Medium)

**Action:** Extend daemon mode to support batch processing of issue lists, where each issue becomes a separate IMPL executed sequentially or in parallel.
**Rationale:** Addresses the use case where AO excels. Could use SAW's existing PROGRAM layer with lightweight IMPLs for independent issues.
**Effort:** 3-4 weeks

### Priority 6: Attention Zones in Dashboard (Low)

**Action:** Add urgency-based grouping to the wave board and program board, supplementing the structural view with an operational view.
**Rationale:** Better operator UX during long-running executions with many agents.
**Effort:** 1 week

### Priority 7: Agent Activity Detection (Low)

**Action:** Port AO's JSONL-based Claude Code activity detection to the Go SDK for more reliable agent state monitoring in the web dashboard.
**Rationale:** Improves observability without changing the protocol. The approach is proven in AO's codebase.
**Effort:** 3-5 days

### Do NOT Borrow

- **AO's plugin architecture.** SAW's Go SDK with importable packages is the right model for SAW. Adding a TypeScript-style plugin registry would add complexity without benefit -- SAW's extension points are at the SDK level, not the runtime level.
- **AO's orchestrator-worker model.** SAW's seven-role participant model is more sophisticated and correctly separates planning from execution from verification. Collapsing to orchestrator-worker would lose SAW's structural advantages.
- **AO's polling-based lifecycle.** For SAW's wave model, event-driven state management (already present via SSE) is more appropriate than polling. Polling makes sense for AO because it monitors external systems (tmux, GitHub); SAW controls the execution directly.
