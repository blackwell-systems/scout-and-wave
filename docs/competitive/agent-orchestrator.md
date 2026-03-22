# Competitive Analysis: Agent Orchestrator (AO) vs Scout-and-Wave (SAW)

**Date:** 2026-03-21
**AO Version:** 0.1.0 (ComposioHQ/agent-orchestrator)
**SAW Version:** Protocol v0.15.0+

---

## 1. Overview

### What is Agent Orchestrator?

Agent Orchestrator (AO) is a **session management and feedback routing layer** for parallel AI coding agents. Built by Composio (ComposioHQ), it manages fleets of AI agents working on separate issues/tasks across a codebase. Each agent gets its own git worktree, branch, and PR. The system monitors CI results and code review comments, automatically routing feedback back to agents.

**Problem it solves:** The operational overhead of running many AI coding agents simultaneously -- creating branches, starting agents, monitoring CI, forwarding review comments, tracking PR status, and cleaning up when done.

**Target audience:** Engineering teams and individuals who want to throw many AI agents at a backlog of GitHub/Linear issues and have those agents work autonomously with minimal supervision.

**Architecture:**
- **Language:** TypeScript (Node.js 20+, ESM)
- **Structure:** pnpm monorepo with 4 main packages (core, cli, web, plugins) plus 20 plugin packages
- **Deployment:** Local CLI + Next.js web dashboard on localhost:3000
- **Runtime dependencies:** tmux (default), Docker, or Kubernetes for session isolation
- **Package:** `@composio/ao` on npm

### What is Scout-and-Wave?

SAW is a **multi-platform, multi-provider coordination protocol** for parallel agent work. It is a language-agnostic specification with formal invariants (I1-I6) and execution rules (E1-E37+), a reference implementation in Go, and a standalone web application. SAW is not tied to any specific LLM provider or orchestration platform.

**Problem it solves:** How to safely decompose complex features into parallel agent work units with formal correctness guarantees -- ensuring agents never conflict on files, interfaces are defined before parallel work begins, and integration failures surface at wave boundaries rather than at the end.

**Target audience:** Anyone coordinating multi-agent implementation of complex features that require structured decomposition, interface contracts, and correctness guarantees.

---

## 2. Strengths (Things AO Does Well)

### 2.1 Plugin Architecture is Genuinely Excellent

AO's 8-slot plugin system is well-designed. Every major abstraction is swappable via a clean TypeScript interface:

- **Runtime:** tmux, Docker, Kubernetes, SSH, E2B sandboxes, child processes
- **Agent:** Claude Code, Codex, Aider, OpenCode
- **Workspace:** worktree, clone
- **Tracker:** GitHub Issues, Linear, GitLab
- **SCM:** GitHub, GitLab
- **Notifier:** desktop, Slack, webhook, Composio
- **Terminal:** iTerm2, web

This is a genuinely better extensibility story than SAW currently offers. Adding a new agent runtime or notification channel is a matter of implementing one interface and exporting a `PluginModule`. The plugin registry with auto-detection (`detect()` method) is a nice touch.

### 2.2 Issue Tracker Integration is First-Class

AO deeply integrates with issue trackers. You point it at a GitHub issue or Linear ticket and it:
- Fetches the issue details
- Generates a branch name from the issue ID
- Builds a context-rich prompt incorporating the issue description
- Tracks PR-to-issue linkage
- Can auto-close issues on merge

SAW's issue tracker integration is comparatively minimal. AO treats the issue backlog as the primary input; SAW treats the IMPL doc as the primary input.

### 2.3 Reaction Engine for CI/Review Feedback

AO's lifecycle manager implements a sophisticated reaction engine:
- CI fails -> agent automatically gets the failure logs and retries (configurable retry count)
- Reviewer requests changes -> comments are forwarded to the agent
- Agent gets stuck -> escalation to human notification after configurable timeout
- PR approved + CI green -> notification (or auto-merge if configured)

This is a real-time feedback loop that SAW does not have an equivalent for. SAW's quality gates (E21) run at wave boundaries, not continuously during agent execution.

### 2.4 Zero-Config Onboarding

`ao start https://github.com/your-org/your-repo` clones the repo, auto-generates config, and launches the dashboard. The convention-over-configuration approach (hash-based namespacing, auto-derived session prefixes, auto-detected project IDs) means users can be productive immediately.

SAW requires understanding the protocol concepts (Scout, IMPL doc, waves, file ownership) before being productive. The learning curve is steeper.

### 2.5 Session Lifecycle State Machine

AO has a detailed session lifecycle with 15+ states and orthogonal activity detection:
```
spawning -> working -> pr_open -> ci_failed / review_pending -> changes_requested -> approved -> mergeable -> merged
```

Activity states (active, ready, idle, waiting_input, blocked, exited) are detected via agent-native mechanisms (JSONL logs, SQLite) rather than terminal scraping. This is robust and well-thought-out.

### 2.6 Task Decomposition

AO includes an LLM-driven task decomposer that classifies tasks as atomic vs. composite and recursively breaks composite tasks into subtasks. It tracks lineage (ancestor chain) and sibling awareness, passing both to agent prompts so agents understand their place in the hierarchy.

### 2.7 Web Dashboard

AO ships a Next.js dashboard with real-time session monitoring, terminal access, and session management. This is a production-quality web UI that ships out of the box.

### 2.8 Multi-Project Support

A single AO instance can manage multiple repositories simultaneously, each with independent agent pools, tracker configs, and reaction settings. Hash-based namespacing prevents collisions across multiple orchestrator checkouts on the same machine.

---

## 3. Weaknesses (Gaps and Limitations)

### 3.1 No Formal Correctness Guarantees

This is the most significant gap. AO has **zero formal invariants**. There is no equivalent to SAW's I1-I6:

- **No disjoint file ownership (I1):** AO spawns one agent per issue. If two issues happen to touch the same files, agents will silently conflict. There is no pre-launch ownership verification, no file-level conflict prediction, and no mechanism to prevent two agents from editing the same file. The merge is left to git, which means conflicts surface at PR merge time rather than being prevented.

- **No interface contracts (I2):** AO has no concept of scaffold files or interface definitions that precede parallel work. Agents work independently against the codebase as-is. If two agents need to interact through a shared interface, there is no mechanism to define that interface before work begins.

- **No wave sequencing (I3):** AO does not have waves. All agents run in a flat pool. There is no concept of "wave N must complete before wave N+1 launches." Dependencies between tasks are not modeled -- the decomposer breaks tasks into subtasks but does not order them.

- **No single source of truth (I4):** Agent state is scattered across flat metadata files, tmux sessions, and PR descriptions. There is no equivalent to the IMPL doc as a coordination artifact.

- **No commit-before-report discipline (I5):** Agents are told to create PRs, but there is no mechanical enforcement that work is committed before status is reported.

- **No role separation (I6):** The orchestrator agent is an LLM running in a tmux session. There is no formal constraint preventing it from doing work that should be delegated.

### 3.2 Issue-Level Granularity, Not Feature-Level

AO maps one agent to one issue. This works for independent bug fixes and small features but fails for complex features that require coordinated changes across multiple files and modules. SAW's Scout phase analyzes the entire feature, decomposes it into agents with non-overlapping file ownership, and defines interfaces between them. AO's decomposer breaks tasks into subtasks but does not reason about file ownership or interface boundaries.

### 3.3 No Pre-Merge Conflict Detection

AO relies on git merge to detect conflicts after the fact. SAW's E11 (conflict prediction before merge) and E3 (pre-launch ownership verification) prevent conflicts from ever occurring. This is a fundamental architectural difference: AO is optimistic (merge and hope), SAW is pessimistic (prevent conflicts by construction).

### 3.4 Observability is Operational, Not Protocol-Level

AO has solid operational observability (correlation IDs, structured logging, health surfaces, metric counters). But it has no protocol-level observability -- no way to audit whether correctness guarantees held, because there are no correctness guarantees to audit. SAW's observability events (observability-events.md) track protocol-level invariant violations, not just operational health.

### 3.5 Anthropic SDK Dependency in Core

The decomposer directly imports `@anthropic-ai/sdk` and hardcodes `claude-sonnet-4-20250514` as the default model. Despite the "agent-agnostic" branding, core planning functionality is Anthropic-specific. SAW's protocol is truly provider-agnostic -- the specification is in markdown, and any LLM can implement it.

### 3.6 No Scaffold / Interface Contract Mechanism

When parallel agents need to call each other's code, AO has no mechanism for this. The prompt builder includes sibling task awareness ("do not duplicate work that sibling tasks handle, define reasonable stubs"), but this is advisory text to an LLM, not a mechanical guarantee. SAW's scaffold agent materializes type-checked interface files before any wave agent launches.

### 3.7 Flat Task Model

AO models tasks as independent issues. There is no concept of a feature-level plan that coordinates multiple agents toward a coherent outcome. The decomposer adds hierarchy but does not enforce ordering or file ownership boundaries. SAW's IMPL doc is a rich coordination artifact that captures the full plan: agents, file ownership, interfaces, wave ordering, quality gates, and dependencies.

---

## 4. Head-to-Head Comparison

| Dimension | Agent Orchestrator (AO) | Scout-and-Wave (SAW) |
|---|---|---|
| **Core abstraction** | Session (one agent per issue) | Wave (coordinated group of agents per feature) |
| **Parallelism model** | Flat pool: all agents run independently, one per issue | Structured waves: agents grouped by dependency order, parallel within wave, sequential across waves |
| **Isolation guarantees** | Git worktree per agent (filesystem isolation only) | Git worktree per agent + disjoint file ownership (I1) + interface contracts (I2) |
| **Conflict prevention** | None -- relies on git merge conflict detection | Mechanical: pre-launch ownership verification (E3), conflict prediction (E11), disjoint file ownership invariant (I1) |
| **Interface contracts** | None -- advisory prompt text only ("define reasonable stubs") | Formal: Scout defines interfaces, Scaffold Agent materializes typed files, agents implement against committed contracts (I2) |
| **Failure handling** | CI failure -> auto-retry with logs; review comments -> auto-forward; stuck -> escalate after timeout | Quality gates at wave boundaries (E21); stub scanning (E20); completion report verification; remediation procedures |
| **Real-time feedback** | Yes: polling loop monitors CI, reviews, agent activity continuously | No: gates run at wave boundaries, not during execution |
| **Provider support** | Claude Code, Codex, Aider, OpenCode (agent plugins) | Any LLM provider (protocol is language-agnostic specification) |
| **Platform support** | CLI + Next.js dashboard | CLI (Go), web app (Go+React HTTP/SSE), Claude Code skill, any custom frontend via Go SDK |
| **Protocol formalism** | None -- no invariants, no execution rules | 6 invariants (I1-I6), 37+ execution rules (E1-E37), formal state machine, message format spec |
| **Observability** | Operational: correlation IDs, structured logs, health checks, metric counters | Protocol-level: invariant violation detection, execution rule audit trail, plus operational metrics |
| **Web UI** | Next.js dashboard with real-time session monitoring, terminal access | React + SSE dashboard with IMPL doc visualization, wave progress, agent journals |
| **SDK / extensibility** | TypeScript plugin system (8 slots, 20 plugins) | Go SDK (importable module), language-agnostic protocol spec |
| **Multi-repo support** | Yes: multi-project config, hash-based namespacing | Yes: cross-repo waves with per-repo I1 enforcement |
| **Task decomposition** | LLM-driven recursive decomposer (classify atomic/composite, generate subtasks) | Scout agent: analyzes codebase, produces IMPL doc with agents, file ownership, interfaces, waves, gates |
| **Issue tracker integration** | Deep: GitHub Issues, Linear, GitLab; auto-prompt from issue, branch naming, PR linkage | Minimal: IMPL doc is the coordination artifact, not the issue tracker |
| **Onboarding friction** | Low: `ao start <url>` and go | Higher: must understand protocol concepts (Scout, IMPL, waves, ownership) |
| **Language** | TypeScript (Node.js) | Go (engine/SDK), TypeScript (web frontend), Markdown (protocol spec) |
| **Maturity** | Active development, 61 merged PRs, 3,288 tests | Active development, formal protocol versioning |

---

## 5. Things We Can Borrow

### 5.1 Plugin Architecture for Agent Adapters

AO's plugin system for agent adapters is worth studying. Each agent adapter knows how to:
- Generate a launch command
- Detect activity state (via JSONL, SQLite, or terminal output)
- Extract session info (summary, cost, agent session ID)
- Restore a previous session
- Set up workspace hooks

SAW's Go SDK could benefit from a similar plugin interface for agent adapters, making it easier to support new LLM providers and coding agents without modifying core code.

### 5.2 Real-Time CI/Review Feedback Loop

AO's reaction engine that automatically forwards CI failures and review comments to agents during execution is genuinely useful. SAW currently waits until wave boundaries to evaluate quality gates. Adding optional real-time feedback routing within a wave (while maintaining wave-boundary gates as the formal checkpoint) would improve agent productivity without compromising correctness.

### 5.3 Issue Tracker as Input Source

AO's deep issue tracker integration (auto-prompt from issue, branch naming, PR linkage) is a better developer experience for the common case of "I have a backlog of issues, deploy agents against them." SAW could offer an optional issue-to-Scout pipeline where pointing at an issue triggers a Scout that produces an IMPL doc.

### 5.4 Session Activity Detection

AO's multi-strategy activity detection (prefer agent-native JSONL/SQLite, fall back to terminal output parsing) with configurable idle thresholds and stuck detection is more sophisticated than SAW's current approach. The orthogonal activity state model (active/ready/idle/waiting_input/blocked/exited) separate from lifecycle state is a clean design.

### 5.5 Notification and Escalation

AO's notification routing by priority level (urgent/action/warning/info) with configurable escalation (retry N times, then escalate to human after M minutes) is well-designed. SAW could add similar notification infrastructure for wave completion events, gate failures, and protocol violations.

### 5.6 Convention-over-Configuration for Paths

AO's hash-based namespacing for runtime data is elegant: `SHA256(configDir)[0:12]` as a prefix prevents collisions across multiple orchestrator checkouts without any user configuration. SAW's `.saw-state/` directory could adopt a similar scheme for multi-instance safety.

---

## 6. Things They Should Borrow From Us

### 6.1 Formal Invariants and Correctness Guarantees

AO's biggest gap. Without I1 (disjoint file ownership), parallel agents will silently conflict on files. Without I2 (interface contracts), parallel agents working on related code have no coordination mechanism beyond "define reasonable stubs." Without I3 (wave sequencing), there is no way to ensure dependent work runs after its prerequisites.

AO's decomposer could be extended to produce file ownership assignments and verify disjoint ownership before spawning agents. This would be the single highest-impact improvement they could make.

### 6.2 Scout Phase (Structured Planning)

AO jumps straight from "here's an issue" to "spawn an agent." For complex features, this means agents are flying blind -- no codebase analysis, no architectural plan, no interface definitions. SAW's Scout phase (analyze codebase, produce IMPL doc with agents/ownership/interfaces/waves) produces a plan that makes parallel execution safe. AO's decomposer is a step in this direction but lacks the codebase analysis and file ownership reasoning.

### 6.3 Scaffold Agent and Interface Freeze

AO tells agents "define reasonable stubs" for cross-agent interfaces. SAW materializes typed scaffold files before any wave agent launches, ensuring all agents implement against the same interface contracts. This is the difference between hoping agents agree and mechanically ensuring they agree.

### 6.4 IMPL Doc as Coordination Artifact

AO's coordination state is scattered across flat key=value metadata files, PR descriptions, and agent memory. SAW's IMPL doc is a single, git-tracked, machine-readable YAML document that captures the entire plan: agents, file ownership, interfaces, wave ordering, quality gates, dependencies, and completion status. This is auditable, diffable, and survives agent restarts.

### 6.5 Pre-Merge Conflict Prediction (E11)

AO merges and hopes. SAW predicts conflicts before merge using file ownership manifests. When you know exactly which files each agent will touch (because you assigned them), you can detect conflicts before any code is written. AO cannot do this because it does not track file ownership.

### 6.6 Quality Gates at Wave Boundaries (E21)

AO monitors CI and reviews continuously, which is useful for individual PR health. But it has no concept of wave-boundary gates that verify the overall feature is coherent before proceeding. SAW's gates (build verification, stub scanning, integration tests, ownership compliance) ensure each wave's output is sound before the next wave begins.

### 6.7 Protocol-Level Observability

AO tracks operational health (is the session alive? is CI passing?). SAW tracks protocol-level correctness (did the agents respect file ownership? did interfaces match? did the wave complete without invariant violations?). These are different levels of observability, and AO would benefit from the protocol level.

### 6.8 Deterministic Tooling (M1, M4, H-series)

SAW's deterministic tools (auto-correct IMPL IDs, populate gates, dependency checks) ensure protocol compliance without relying on LLM cooperation. AO relies on prompt instructions for protocol compliance. Mechanical enforcement is always more reliable than advisory text.

---

## Summary

AO and SAW solve related but different problems. AO is a **session manager** that excels at the operational problem of running many agents against a backlog of independent issues. SAW is a **coordination protocol** that excels at the correctness problem of safely decomposing complex features into parallel agent work.

AO is stronger on: developer experience, plugin extensibility, real-time feedback loops, issue tracker integration, and zero-config onboarding.

SAW is stronger on: correctness guarantees, conflict prevention, interface contracts, structured planning, protocol formalism, and provider/platform independence.

The ideal system would combine AO's operational polish with SAW's protocol rigor. For SAW, the highest-value borrowings are the plugin architecture pattern, real-time CI/review feedback, and issue tracker integration. For AO, the highest-value borrowings are formal invariants, file ownership tracking, and pre-work planning.
