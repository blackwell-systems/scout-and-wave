# Competitive Analysis: Paperclip vs Scout-and-Wave (SAW)

**Date:** 2026-03-21
**Paperclip Version:** Latest main (paperclipai/paperclip)
**SAW Version:** Protocol v0.15.0+

---

## 1. Overview

### What is Paperclip?

Paperclip is an **open-source control plane for autonomous AI companies**. It is a Node.js server and React UI that orchestrates a team of AI agents organized into a corporate hierarchy -- with org charts, roles, budgets, governance, and goal alignment. You define a company mission, hire agents (CEO, CTO, engineers, marketers), set budgets, and let the agents self-organize work through a ticketing system.

**Problem it solves:** The operational chaos of running many AI agents simultaneously. When you have 20 Claude Code terminals open, you lose track of what each one is doing, costs spiral, and there is no coordination between agents. Paperclip gives agents a corporate structure: reporting lines, task delegation, budget controls, approval gates, and an audit trail.

**Target audience:** People building "autonomous AI companies" -- portfolio operators running multiple AI-driven businesses, solo entrepreneurs deploying agent teams, and anyone who wants agents running 24/7 with human oversight via a dashboard.

**Architecture:**
- **Language:** TypeScript (Node.js)
- **Structure:** pnpm monorepo with server, UI, and packages (db, shared, adapters, plugins SDK)
- **Database:** PostgreSQL (PGlite embedded for dev, real Postgres for production) via Drizzle ORM
- **Frontend:** React + Vite
- **Deployment:** Self-hosted, single-tenant. Local dev with one command (`npx paperclipai onboard --yes`)
- **Agent adapters:** Claude Code, Codex, Cursor, Gemini, OpenClaw, OpenCode, Pi, HTTP, Bash

### What is Scout-and-Wave?

SAW is a **multi-platform, multi-provider coordination protocol** for parallel agent work. It is a language-agnostic specification with formal invariants (I1-I6) and execution rules (E1-E37+), a reference implementation in Go, and a standalone web application. SAW is not tied to any specific LLM provider or orchestration platform.

**Problem it solves:** How to safely decompose complex features into parallel agent work units with formal correctness guarantees -- ensuring agents never conflict on files, interfaces are defined before parallel work begins, and integration failures surface at wave boundaries rather than at the end.

**Target audience:** Anyone coordinating multi-agent implementation of complex features that require structured decomposition, interface contracts, and correctness guarantees.

---

## 2. Strengths (Things Paperclip Does Well)

### 2.1 Cost Tracking and Budget Enforcement is Production-Grade

This is Paperclip's standout strength and the feature most relevant to SAW. Paperclip has a fully realized cost tracking system:

- **`cost_events` table** with per-event granularity: company, agent, issue, project, goal, heartbeat run, provider, biller, billing type, model, input/output/cached tokens, cost in cents, timestamp. Six composite indexes for efficient querying across all dimensions.
- **`finance_events` table** for broader financial tracking beyond token costs: debits/credits, billing codes, external invoices, pricing tiers, regions, estimated vs. actual amounts.
- **Multi-dimensional rollup queries:** cost by agent, by provider, by biller, by model, by project, by agent-model combination, and across rolling time windows (5h, 24h, 7d).
- **Budget policies** with configurable scope (company, agent, project), window kind (monthly, lifetime), warn thresholds, and hard stops.
- **Budget enforcement is atomic and mechanical:** when a cost event is recorded, all applicable budget policies are evaluated in-line. Soft thresholds create incidents with notifications. Hard stops pause the agent/project/company and cancel running work. This is not advisory -- it is enforced at the database level.
- **Budget incidents** create approval requests that the board must resolve (raise budget and resume, or keep paused).
- **Provider quota polling:** adapters can report their provider's rate limit windows, surfaced in the UI alongside internal spend data.

SAW has the event types and rollup functions but no storage backend. Paperclip has the complete pipeline: event recording, budget evaluation, enforcement actions, incident management, and resolution workflow.

### 2.2 Immutable Audit Trail

Every mutating action in Paperclip writes to the `activity_log` table: who did what, when, to which entity, with structured details. The activity log is:

- **Company-scoped** with actor type (agent/user/system) and actor ID
- **Entity-linked** (entity type + entity ID) so you can retrieve all activity for any task, agent, or run
- **Run-linked** when activity occurs during a heartbeat run
- **Real-time** via the `publishLiveEvent` system (in-process EventEmitter) that pushes events to connected UI clients
- **Plugin-forwarded** via the plugin event bus, so external systems can react to domain events

This is a genuine audit trail, not just logging. Every cost report, budget change, task state transition, and governance decision is recorded with full provenance.

### 2.3 Heartbeat Run Observability

Paperclip tracks every agent invocation as a `heartbeat_run` with rich metadata:

- Invocation source (scheduled, on-demand, wakeup request)
- Status lifecycle (queued, running, completed, failed, cancelled)
- Start/finish timestamps, exit code, signal, error details
- Usage JSON (adapter-reported token/cost data)
- Result JSON (adapter-reported summary, cost_usd)
- Session IDs (before and after, for session continuity tracking)
- Full stdout/stderr log capture with SHA256 integrity hashing
- Process PID, retry linkage, process loss retry counts
- Context snapshot at invocation time

The `heartbeat_run_events` table provides a structured event stream within each run: sequenced events with type, stream (stdout/stderr/system), level, color coding, and JSON payloads. This enables both real-time run monitoring and post-hoc analysis.

### 2.4 Hierarchical Goal Alignment

Paperclip's task hierarchy (Initiative -> Project -> Milestone -> Issue -> Sub-issue) means every piece of work traces back to the company mission. This provides:

- **Cost attribution up the goal chain:** billing codes on tasks let you attribute Agent B's costs to Agent A's request
- **Goal-aware execution:** agents always see the "why" behind their work
- **Natural rollup points:** cost and performance metrics aggregate at every level of the hierarchy

SAW's IMPL doc captures a single feature's decomposition. Paperclip captures an entire company's goal hierarchy. These are different scales, but Paperclip's hierarchical attribution model is worth studying.

### 2.5 Multi-Agent Adapter Ecosystem

Paperclip supports seven local adapters (Claude Code, Codex, Cursor, Gemini, OpenClaw, OpenCode, Pi) plus HTTP and Bash. Each adapter implements:

- `invoke()` to start the agent
- `status()` to check liveness
- `cancel()` for graceful shutdown
- Optional `getQuotaWindows()` for provider rate limit reporting
- Session codec for session continuity across heartbeats

The adapter architecture handles session persistence, workspace management, log capture, and cost extraction. New adapters can be registered via the plugin system.

### 2.6 Corporate Governance Model

The "board" concept is genuinely useful for autonomous agent oversight:

- Board approves all agent hires
- Board approves CEO strategy before execution begins
- Budget hard stops require board approval to override
- Board can pause/resume any agent, task, or project at any time
- Full project management access at all times

This is a well-thought-out human-in-the-loop model that maintains human authority without requiring constant attention.

### 2.7 Plugin System with Event Bus

Paperclip's plugin system allows extending the control plane without modifying core:

- Plugin SDK with CLI scaffolding (`create-paperclip-plugin`)
- Event bus for reacting to domain events (task transitions, cost reports, heartbeat completions)
- UI component slots for plugin-rendered widgets
- State store, secrets handler, and job scheduler for plugins
- Webhook support for external integrations

---

## 3. Weaknesses (Gaps and Limitations)

### 3.1 No Formal Correctness Guarantees for Parallel Work

Paperclip has **zero mechanisms for safe parallel agent work on the same feature**:

- **No disjoint file ownership (I1):** Multiple agents can work on the same codebase simultaneously with no file-level conflict prevention. Paperclip's "atomic task checkout" prevents two agents from claiming the same task, but two tasks can easily touch the same files.
- **No interface contracts (I2):** No concept of scaffold files or typed interface definitions before parallel work begins. Agents work independently against the codebase as-is.
- **No wave sequencing (I3):** No concept of dependency-ordered execution phases. All agents run on their own heartbeat schedules.
- **No IMPL doc (I4):** No single coordination artifact that captures the full plan for a complex feature.
- **No commit discipline (I5):** No mechanical enforcement that work is committed before status is reported.

Paperclip assumes agents work on independent tasks. When a complex feature requires coordinated changes across multiple files and modules, Paperclip has no mechanism to decompose, sequence, and verify that work.

### 3.2 Task-Level, Not Feature-Level Coordination

Paperclip maps one agent to one task (issue). The CEO delegates tasks, and agents work them independently. This is excellent for a backlog of independent tasks but fundamentally limited for complex features that require:

- Pre-work codebase analysis
- File ownership assignment to prevent conflicts
- Interface definition before parallel implementation
- Dependency ordering between work units
- Integration verification after parallel work completes

SAW's Scout phase + IMPL doc + wave sequencing + quality gates addresses all of these. Paperclip has none of them.

### 3.3 No Pre-Work Planning Phase

Paperclip jumps from "task exists" to "agent works on it." There is no equivalent to SAW's Scout phase that:

- Analyzes the codebase to understand existing architecture
- Decomposes a complex feature into agents with non-overlapping file ownership
- Defines interfaces between agents before parallel work begins
- Sequences work into waves based on dependencies
- Produces a machine-readable plan that can be validated

The CEO agent can break tasks into subtasks, but this is LLM-driven delegation without codebase analysis or file ownership reasoning.

### 3.4 No Integration Verification

When multiple agents complete their tasks, Paperclip has no mechanism to verify that their collective output is coherent:

- No stub scanning (E20) to detect unfinished interfaces
- No quality gates (E21) at completion boundaries
- No conflict prediction (E11) before merging
- No build verification after integration

Each agent's task is evaluated independently. Whether the aggregate output compiles, passes tests, or even makes sense as a whole is left to manual review or a separate CI process.

### 3.5 Observability is Operational, Not Protocol-Level

Paperclip's observability is excellent for operational questions:
- How much did Agent X cost this month?
- Which provider is consuming the most tokens?
- Is this agent's heartbeat succeeding?
- What's the company's burn rate?

But it has no protocol-level observability:
- Did agents respect file ownership boundaries?
- Did interfaces match across parallel work?
- Did wave sequencing constraints hold?
- Were invariants violated during execution?

This is because Paperclip has no protocol-level invariants to observe. SAW's observability events track invariant violations, not just operational health.

### 3.6 Tight Coupling to PostgreSQL

Paperclip requires PostgreSQL (or PGlite for dev). The entire data model is expressed in Drizzle ORM with Postgres-specific types (uuid, jsonb, bigserial). There is no storage abstraction layer -- the services query Drizzle directly. This makes Paperclip harder to embed as a library or run in constrained environments.

### 3.7 Single-Codebase TypeScript

The entire system is TypeScript. While this is fine for a Node.js server, it limits:
- Embedding in non-Node environments
- Use as a library from other languages
- Protocol-level interoperability (no language-agnostic spec)

SAW's protocol is specified in markdown, the engine is in Go (easily consumed as a library), and the protocol can be implemented in any language.

---

## 4. Head-to-Head Comparison

| Dimension | Paperclip | Scout-and-Wave (SAW) |
|---|---|---|
| **Core abstraction** | Company (org chart of agents with goals, budgets, governance) | Wave (coordinated group of agents per feature) |
| **Problem domain** | Running autonomous AI businesses with human oversight | Safely decomposing complex features into parallel agent work |
| **Parallelism model** | Independent: each agent works its own task on its own schedule | Structured: agents grouped by dependency order, parallel within wave, sequential across waves |
| **Conflict prevention** | None -- tasks are independent, no file-level coordination | Mechanical: disjoint file ownership (I1), pre-launch verification (E3), conflict prediction (E11) |
| **Interface contracts** | None | Formal: Scout defines interfaces, Scaffold Agent materializes typed files, agents implement against committed contracts (I2) |
| **Cost tracking** | Production-grade: per-event granularity, multi-dimensional rollups, budget enforcement with hard stops, provider quota polling | Event types and rollup functions defined, but no concrete storage backend -- all emit calls are no-ops |
| **Budget enforcement** | Atomic: cost event triggers policy evaluation, soft warns, hard stops pause agents, board resolves incidents | Not implemented |
| **Audit trail** | Immutable activity_log table with real-time push, plugin event bus forwarding | ActivityEvent type defined but no storage or query capability |
| **Run observability** | Full heartbeat_run tracking: lifecycle, logs, usage, session continuity, stdout/stderr capture with integrity hashing | Agent journal files (text-based, per-worktree) |
| **Dashboard** | React UI: company dashboard, cost breakdowns by agent/provider/model/project, budget overview, activity feed, run transcripts | React + SSE: IMPL doc visualization, wave progress, agent journals |
| **Provider support** | 7 local adapters + HTTP + Bash + plugin-registered adapters | Any LLM provider (protocol is language-agnostic specification) |
| **Protocol formalism** | None -- no invariants, no execution rules | 6 invariants (I1-I6), 37+ execution rules (E1-E37), formal state machine |
| **Planning phase** | CEO delegates tasks; no codebase analysis or file ownership reasoning | Scout: analyzes codebase, produces IMPL doc with agents, file ownership, interfaces, waves, gates |
| **Integration verification** | None -- each task evaluated independently | Quality gates at wave boundaries (E21), stub scanning (E20), build verification, ownership compliance |
| **Goal hierarchy** | Deep: Initiative -> Project -> Milestone -> Issue -> Sub-issue, all tracing to company mission | IMPL doc per feature, Programs for multi-feature coordination |
| **Governance** | Board approval gates, pause/resume, budget overrides | Human approval at wave boundaries (optional) |
| **Database** | PostgreSQL (required), Drizzle ORM, 55+ schema tables | None for observability (Store interface defined, no implementation) |
| **Language** | TypeScript (server + UI) | Go (engine/SDK), TypeScript (web frontend), Markdown (protocol spec) |
| **Deployment** | Self-hosted Node.js server | CLI (Go binary), web app (Go+React), Claude Code skill, any custom frontend via Go SDK |
| **Multi-tenant** | Yes: one instance, many companies with data isolation | N/A (protocol operates per-repo) |

---

## 5. Things We Can Borrow

### 5.1 Cost Event Schema Design

Paperclip's `cost_events` table is well-designed for multi-dimensional analysis:

- **Biller vs. Provider distinction:** `provider` is who served the request (e.g., Anthropic); `biller` is who charged for it (e.g., a subscription platform). This matters for users on Max Plan, team plans, or third-party API resellers.
- **Billing type classification:** `metered_api`, `subscription_included`, `subscription_overage` -- distinguishing between pay-per-token and subscription-included usage prevents misleading cost dashboards.
- **Cached input tokens as a separate field:** Critical for accurate cost calculation since cached tokens are priced differently.
- **Cost in integer cents, not floating-point dollars:** Avoids floating-point precision issues in financial calculations. SAW's `CostUSD float64` should become `CostCents int`.
- **Composite indexes for common query patterns:** Six purpose-built indexes covering the most common rollup dimensions.

### 5.2 Budget Policy and Enforcement Model

Paperclip's budget system is the most complete we have seen:

- **Scope-agnostic policies:** Same policy model works for company, agent, and project budgets.
- **Window kinds:** Calendar month and lifetime budgets with proper UTC window calculation.
- **Two-tier thresholds:** Soft (configurable percent, creates notification) and hard (100%, pauses agent and cancels work).
- **Incident management:** Budget violations create tracked incidents with approval workflows. The board can raise the budget and resume, or keep the scope paused.
- **Pre-invocation blocking:** Before starting a heartbeat run, the system checks all applicable budget policies and blocks if any hard stop is exceeded.

SAW should implement a similar model. The natural mapping: budget policies scoped to IMPL slugs, program slugs, or agent IDs, with wave-boundary evaluation.

### 5.3 Finance Events for Non-Token Costs

Paperclip's `finance_events` table tracks costs beyond token usage: infrastructure, external services, subscription fees. The debit/credit model with billing codes enables proper cost attribution. SAW's observability should consider a similar non-token cost event type for tracking CI costs, cloud resource usage during wave execution, etc.

### 5.4 Structured Run Log Storage

Paperclip's `RunLogStore` abstraction with NDJSON format, SHA256 integrity hashing, byte-range reads, and structured events (timestamp + stream + chunk) is a solid pattern for agent execution logs. SAW's agent journals are text files without structure. Adopting a similar NDJSON format with integrity hashing would improve auditability and enable efficient streaming reads.

### 5.5 Real-Time Event Push

Paperclip's `publishLiveEvent` system (in-process EventEmitter with company-scoped channels) provides real-time updates to the UI without polling. SAW's web app already uses SSE, but the server-side event generation could adopt Paperclip's pattern of emitting live events from every service mutation for more granular real-time updates.

### 5.6 Rolling Window Spend Queries

Paperclip's `windowSpend` function computing spend across 5h/24h/7d rolling windows by provider is immediately useful for cost velocity monitoring. SAW's `ComputeTrend` function has similar capability but needs a Store implementation to work.

---

## 6. Things They Should Borrow From Us

### 6.1 Formal Invariants and Correctness Guarantees

Paperclip's biggest gap. When multiple agents work on the same codebase (which happens constantly in a "company" of agents), there is no mechanism to prevent file conflicts, ensure interface compatibility, or verify integration. SAW's I1-I6 invariants would transform Paperclip's reliability for complex features.

### 6.2 Scout Phase (Structured Planning Before Execution)

Paperclip's CEO delegates tasks based on role descriptions and goal hierarchy. SAW's Scout phase analyzes the actual codebase, understands existing architecture, and produces a machine-readable plan with file ownership assignments. Paperclip's delegation would be dramatically more effective if it included codebase-aware decomposition.

### 6.3 Wave Sequencing for Dependent Work

Paperclip's agents all work on independent schedules. When tasks have dependencies (and they always do for complex features), there is no mechanism to ensure prerequisite work completes before dependent work begins. SAW's wave model provides this directly.

### 6.4 Quality Gates at Integration Points

Paperclip evaluates each task independently. SAW's quality gates at wave boundaries (build verification, stub scanning, integration tests, ownership compliance) verify that the aggregate output is coherent before proceeding. This would catch integration failures that Paperclip currently misses.

### 6.5 Disjoint File Ownership

When Paperclip's CTO assigns three engineers to work on related parts of a feature, there is no mechanism to ensure they do not edit the same files. SAW's I1 invariant with pre-launch verification (E3) prevents this class of conflict entirely.

### 6.6 IMPL Doc as Coordination Artifact

Paperclip's coordination state is scattered across tasks, comments, agent configs, and the goal hierarchy. SAW's IMPL doc is a single, git-tracked, machine-readable YAML document that captures the entire plan. This is auditable, diffable, and survives agent restarts.

### 6.7 Deterministic Tooling

SAW's deterministic tools (auto-correct IMPL IDs, populate gates, dependency checks) ensure protocol compliance without relying on LLM cooperation. Paperclip relies on prompt instructions (SKILL.md) and LLM decision-making for protocol compliance. Mechanical enforcement is always more reliable.

---

## 7. Observability Deep Dive

This section provides a detailed comparison of Paperclip's observability approach with SAW's current (partially implemented) observability system, and specific recommendations for what SAW should adopt.

### 7.1 How Paperclip Tracks Agent Execution, Costs, and Performance

Paperclip has **four interconnected data systems** for observability:

**1. Cost Events (`cost_events` table)**

Every token-consuming API call produces a cost event with: company, agent, issue, project, goal, heartbeat run, billing code, provider, biller, billing type, model, input/output/cached tokens, cost in cents, and timestamp. This is the raw ledger for all token spend.

Key design decisions:
- **Integer cents, not float dollars.** Eliminates floating-point rounding in financial aggregations.
- **Biller/provider/billing_type triple.** Distinguishes who served the request, who billed for it, and how (metered API vs. subscription). This is critical for users on subscription plans where token usage does not equal token cost.
- **Heartbeat run linkage.** Every cost event can be attributed to a specific agent invocation, enabling per-run cost analysis.
- **Six composite indexes** covering the common query patterns: (company, occurred_at), (company, agent, occurred_at), (company, provider, occurred_at), (company, biller, occurred_at), (company, heartbeat_run), and a general company index.

**2. Finance Events (`finance_events` table)**

Broader financial tracking beyond token costs. Supports debit/credit directions, multiple currencies, estimated vs. actual amounts, external invoice IDs, and arbitrary metadata. This handles infrastructure costs, subscription fees, and other non-token expenses. Linked to cost_events for token-cost-to-finance-event correlation.

**3. Activity Log (`activity_log` table)**

An append-only audit trail for every domain mutation. Each entry records: company, actor (type + ID), action string, entity (type + ID), optional agent and run linkage, and structured JSON details. This is the immutable record of everything that happened. Six composite indexes cover the common query patterns.

The activity log is also the source for:
- Real-time push events to the UI (via in-process EventEmitter)
- Plugin event bus forwarding (so plugins can react to domain events)
- The activity feed on the dashboard

**4. Heartbeat Run Events (`heartbeat_run_events` table)**

A structured event stream within each agent invocation. Sequenced events with type, stream (stdout/stderr/system), level, color, message, and JSON payloads. This is the detailed execution trace for a single run. Separate from the run's stdout/stderr log capture (which is stored as NDJSON files on disk with SHA256 integrity hashes).

### 7.2 Storage and Query Patterns

**Storage:** PostgreSQL, accessed via Drizzle ORM. All observability data lives in the same database as the rest of the application state. No separate time-series database, no log aggregation service. This simplifies deployment (one database) at the cost of scalability (Postgres is not optimized for high-volume time-series writes).

**Query patterns:** The `costService` exposes seven query methods:

| Method | What it returns |
|---|---|
| `summary(companyId, range?)` | Total spend, budget, utilization percent |
| `byAgent(companyId, range?)` | Per-agent totals: cost, tokens (input/cached/output), run counts by billing type |
| `byProvider(companyId, range?)` | Per-provider+model totals with billing type breakdown |
| `byBiller(companyId, range?)` | Per-biller totals with provider/model counts |
| `byAgentModel(companyId, range?)` | Per-agent-per-model cross-tabulation |
| `byProject(companyId, range?)` | Per-project costs (with fallback through activity_log for indirect attribution) |
| `windowSpend(companyId)` | Rolling window (5h/24h/7d) spend by provider |

All queries support date range filtering. The `byProject` query is notable: it uses a CTE to join cost_events through activity_log to find indirect project associations when cost events lack a direct project_id.

**Budget evaluation** happens synchronously on every cost event insertion. The `evaluateCostEvent` function loads all active policies for the company, filters to relevant scopes, computes observed amounts, and creates incidents / pauses agents as needed. This is real-time enforcement, not batch.

### 7.3 Dashboards and Reporting

**Dashboard page:** Shows at-a-glance metrics: agent counts by status (active/running/paused/error), task counts by status, monthly spend with utilization percent, pending approvals, budget incidents, and paused agent/project counts.

**Costs page:** A dedicated cost analysis view with:
- Date range selector with presets (this week, this month, last month, custom)
- Metric tiles: total spend, budget utilization, top provider, finance summary
- Tabbed views: by biller, by provider, by agent, by agent-model, by project
- Budget policy cards with utilization bars and incident status
- Budget incident cards with resolution workflows (raise budget / dismiss)
- Provider quota windows showing external rate limit data
- Finance event timeline with debit/credit visualization
- Rolling window spend cards (5h/24h/7d) per provider

**Agent detail pages** show per-agent: recent runs with status/duration/cost, activity feed, budget status.

**Run transcript pages** show the structured event stream for a specific heartbeat run.

### 7.4 Specific Recommendations for SAW's Observability System

Based on the analysis above, here are concrete recommendations for completing SAW's observability system, ordered by impact.

#### Recommendation 1: Implement a SQLite Store (Highest Priority)

SAW's `Store` interface is well-designed. The highest-priority action is implementing a SQLite-backed store. SQLite is the right choice for SAW because:

- SAW runs locally per-repo, not as a shared server. SQLite's file-per-database model fits perfectly.
- No external database dependency (unlike Paperclip's Postgres requirement).
- Excellent for the write-once, read-many pattern of observability events.
- WAL mode handles concurrent reads during writes (emitter goroutines writing while CLI queries).

Schema recommendation (inspired by Paperclip but adapted to SAW's domain):

```sql
CREATE TABLE events (
    id          TEXT PRIMARY KEY,
    event_type  TEXT NOT NULL,         -- 'cost' | 'agent_performance' | 'activity'
    impl_slug   TEXT,
    program_slug TEXT,
    agent_id    TEXT,
    wave_number INTEGER,
    timestamp   TEXT NOT NULL,         -- ISO 8601
    data_json   TEXT NOT NULL,         -- full event as JSON
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_events_type_time ON events(event_type, timestamp);
CREATE INDEX idx_events_impl ON events(impl_slug, event_type, timestamp);
CREATE INDEX idx_events_program ON events(program_slug, event_type, timestamp);
CREATE INDEX idx_events_agent ON events(agent_id, event_type, timestamp);
```

This single-table design with a JSON data column is simpler than Paperclip's normalized multi-table approach but sufficient for SAW's query patterns. The existing `QueryFilters` and `RollupRequest` types map directly to SQL WHERE clauses on this schema.

#### Recommendation 2: Adopt Integer Cents for Cost Tracking

Change `CostEvent.CostUSD float64` to `CostCents int`. Paperclip learned this lesson: financial calculations with floating-point numbers accumulate rounding errors. All aggregation, comparison, and display logic becomes simpler and more correct with integer cents.

This is a breaking change to the event type but should be done before any Store implementation ships, since changing it later requires data migration.

#### Recommendation 3: Add Biller/BillingType Fields to CostEvent

SAW's `CostEvent` has `Model string` but no biller or billing type. Users on subscription plans (Anthropic Max, OpenAI Pro) have different cost profiles than API users. Adding these fields enables accurate cost reporting:

```go
type CostEvent struct {
    // ... existing fields ...
    Biller      string `json:"biller,omitempty"`       // who charged (e.g., "anthropic", "openai")
    BillingType string `json:"billing_type,omitempty"` // "metered_api" | "subscription_included"
}
```

#### Recommendation 4: Add Budget Policies to SAW

Implement budget policies scoped to IMPL slugs, program slugs, or globally. The natural enforcement points in SAW are:

- **Pre-wave launch:** Check budget before `prepare-wave`. If the IMPL or program has exceeded its budget, block the wave.
- **Post-wave cost recording:** After a wave completes and costs are recorded, evaluate policies and warn/block if thresholds are crossed.
- **Program tier gates:** Budget checks as part of tier gate evaluation.

The policy model can be simpler than Paperclip's (no need for company/agent/project scopes), but the two-tier threshold pattern (soft warn at N%, hard stop at 100%) is directly applicable.

#### Recommendation 5: Wire Cost Extraction from Agent Adapters

Paperclip extracts cost data from adapter-specific outputs (Claude Code's JSONL logs, Codex's SQLite database, etc.) and records cost events automatically. SAW should do the same:

- After a wave agent completes, parse the agent's cost output (Claude Code reports costs in its summary) and emit a `CostEvent` via the Emitter.
- The web app's wave completion handler should extract and record costs.
- The CLI's `finalize-wave` should do the same.

This makes cost tracking automatic rather than requiring agents to self-report.

#### Recommendation 6: Add a Dashboard Costs View to the Web App

SAW's web app should add a costs page similar to Paperclip's, adapted to SAW's domain model:

- **Per-IMPL cost breakdown:** Total cost, cost by agent, cost by wave
- **Per-program cost tracking:** Total cost across all IMPLs in a program
- **Cost trends:** Time-series charts using the existing `ComputeTrend` function
- **Agent efficiency metrics:** Cost per successful agent, cost per failed agent, retry cost overhead

The existing `ComputeCostRollup`, `ComputeSuccessRateRollup`, `GetIMPLMetrics`, and `GetCostBreakdown` functions already implement the query logic -- they just need a Store to query against and a UI to display results.

#### Recommendation 7: Adopt Structured Run Logs

Replace or supplement SAW's text-based agent journals with structured NDJSON logs:

```json
{"ts":"2026-03-21T10:00:00Z","stream":"stdout","chunk":"Starting implementation..."}
{"ts":"2026-03-21T10:00:01Z","stream":"system","chunk":"Files modified: 3"}
{"ts":"2026-03-21T10:00:02Z","stream":"cost","chunk":"{\"input_tokens\":1500,\"output_tokens\":800,\"cost_cents\":12}"}
```

Benefits:
- Machine-parseable (extract costs, errors, file modifications automatically)
- Streamable (byte-range reads for real-time tailing)
- Integrity-verifiable (SHA256 hash on finalization)
- Compatible with the existing SSE infrastructure for live streaming to the web UI

### 7.5 How Paperclip's Patterns Map to SAW's Existing Abstractions

| Paperclip Concept | SAW Equivalent | Gap |
|---|---|---|
| `cost_events` table | `CostEvent` struct + `Store.RecordEvent()` | Need Store implementation (SQLite) |
| `finance_events` table | No equivalent | Could add `InfrastructureCostEvent` for CI/cloud costs |
| `activity_log` table | `ActivityEvent` struct + `Store.RecordEvent()` | Need Store implementation |
| `heartbeat_runs` table | No direct equivalent | Agent journals partially cover this; could add `AgentRunEvent` |
| `heartbeat_run_events` table | No equivalent | Structured NDJSON run logs would serve this purpose |
| `budget_policies` table | No equivalent | Implement as YAML config or SQLite table |
| `budget_incidents` table | No equivalent | Implement as part of budget policy enforcement |
| `costService.byAgent()` | `GetCostBreakdown()` | Already implemented, needs Store |
| `costService.byProvider()` | `ComputeCostRollup(GroupBy: ["model"])` | Already implemented, needs Store |
| `costService.windowSpend()` | `ComputeTrend()` | Already implemented, needs Store |
| `costService.summary()` | `GetIMPLMetrics()` | Already implemented, needs Store |
| `budgetService.evaluateCostEvent()` | No equivalent | Implement budget evaluation in Emitter or post-wave hook |
| `dashboardService.summary()` | Web app dashboard | Needs cost data to populate metrics |
| `publishLiveEvent()` | SSE event system | Already implemented in web app |
| `RunLogStore` (NDJSON + SHA256) | Agent journal files | Upgrade to structured NDJSON format |

**Key insight:** SAW's observability abstractions (Event interface, Emitter, Store, QueryFilters, RollupRequest, rollup functions, trend computation, query functions) are well-designed and closely parallel Paperclip's query patterns. The gap is entirely in the storage layer. A SQLite Store implementation would immediately activate all existing rollup, trend, and query code. The Emitter calls already exist in the engine (finalize.go, runner.go, program_tier_loop.go). Once there is a real Store behind the Emitter, observability data starts flowing with no additional engine changes.

---

## Summary

Paperclip and SAW solve fundamentally different problems with complementary strengths. Paperclip is a **control plane for autonomous AI companies** that excels at cost tracking, budget enforcement, audit trails, and corporate governance. SAW is a **coordination protocol for parallel agent work** that excels at correctness guarantees, conflict prevention, interface contracts, and structured planning.

Paperclip is stronger on: cost tracking, budget enforcement, audit trails, run observability, governance, goal hierarchy, adapter ecosystem, and operational dashboards.

SAW is stronger on: correctness guarantees, conflict prevention, interface contracts, structured planning (Scout), wave sequencing, quality gates, protocol formalism, and provider/platform independence.

**For SAW's observability specifically:** Paperclip validates that SAW's existing observability abstractions are on the right track. The Event/Emitter/Store/Query/Rollup architecture closely mirrors what Paperclip built with Postgres. The critical missing piece is a concrete Store implementation. A SQLite backend would immediately activate all existing observability code. Beyond storage, adopting Paperclip's integer-cents cost model, biller/billing-type fields, budget policies, and structured run logs would bring SAW's observability from "well-designed interface with no backend" to "production-ready system."
