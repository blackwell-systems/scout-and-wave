# Competitive Analysis: Scout-and-Wave vs Paperclip

**Date:** 2026-03-20
**Analyst:** Claude (Sonnet 4.5)
**Repositories Analyzed:**
- Paperclip: `/Users/dayna.blackwell/code/paperclip` (Node.js/TypeScript, ~26k LOC server)
- Scout-and-Wave: `/Users/dayna.blackwell/code/scout-and-wave` (Protocol spec)
- Scout-and-Wave Go SDK: `/Users/dayna.blackwell/code/scout-and-wave-go` (~3,254 Go files)
- Scout-and-Wave Web: `/Users/dayna.blackwell/code/scout-and-wave-web` (Go + React)

---

## Executive Summary

**Paperclip** and **Scout-and-Wave (SAW)** operate in adjacent but distinct problem spaces:

- **Paperclip** = **Company orchestration control plane**. Multi-agent coordination system for building autonomous AI companies. Manages org charts, budgets, task hierarchies, heartbeat scheduling, and board governance. Think "operating system for AI companies."

- **Scout-and-Wave** = **Parallel code generation protocol**. Tactical execution framework for decomposing features into parallel agents with disjoint file ownership and worktree isolation. Think "make parallelism safe for LLM code generation."

**Key Insight:** These are **complementary, not competitive**. Paperclip orchestrates long-running autonomous companies; SAW executes specific parallelizable coding tasks within those companies. A Paperclip agent could use SAW to execute complex features in parallel.

**Integration Opportunity:** High. SAW could become a "skill" that Paperclip agents invoke for parallelizable work.

---

## Paperclip Overview

### Core Value Proposition
"The control plane for autonomous AI companies" — infrastructure for running multi-agent companies with real org structure, governance, budgets, and accountability.

### Architecture
**Node.js/TypeScript monorepo** with:
- `server/`: Express REST API (~26k LOC services)
- `ui/`: React board UI (35+ pages)
- `packages/db/`: Drizzle ORM + PostgreSQL schema
- `packages/shared/`: Shared types/validators
- `packages/adapters/`: Agent runtime adapters (OpenClaw, Claude, Codex, Cursor, Gemini, Pi, OpenCode)

**Data stores:**
- PostgreSQL (embedded PGlite for local dev, hosted for production)
- S3-compatible object storage for files/attachments
- Local encrypted secrets with master key

### Key Features

#### 1. Company Model (First-Order Object)
- Multi-company support in single deployment
- Complete data isolation per company
- Company-level budgets, goals, and governance
- Exportable company templates (ClipMart vision)

#### 2. Agent Management
- **Org structure:** Hierarchical reporting tree (CEO → CTO → engineers)
- **Agent lifecycle:** hire, pause, terminate, budget allocation
- **Adapter system:** Pluggable runtimes (process, HTTP, OpenClaw gateway, local Claude/Codex/Cursor)
- **Context modes:** Fat payload (bundle context) vs thin ping (agent fetches context)
- **Capabilities registry:** Agents describe what they can do for discoverability

#### 3. Heartbeat System
- **Scheduled invocations:** Cron-style agent wake-ups
- **Event-driven triggers:** Task assignment, @-mentions, wake requests
- **Status tracking:** queued, running, succeeded, failed, cancelled, timed_out
- **Session persistence:** Resume same task context across heartbeats
- **Atomic execution:** Task checkout prevents double-work

#### 4. Task/Issue Management
- **Hierarchical tasks:** Parent-child chains trace back to company goal
- **Single-assignee model:** Atomic checkout semantics (prevents conflicts)
- **Status workflow:** backlog → todo → in_progress → in_review → done/blocked/cancelled
- **Comments system:** All communication attached to work objects
- **Cross-team delegation:** Agents can assign work outside reporting lines
- **Request depth tracking:** Track delegation hops
- **Billing codes:** Cost attribution across org

#### 5. Budget & Cost Control
- **Monthly UTC calendar budgets** per agent
- **Cost event ingestion:** Token/model usage from agents
- **Rollups:** Agent/task/project/company cost aggregation
- **Hard-stop enforcement:** Auto-pause agents at budget limit
- **Burn rate monitoring:** Real-time cost velocity tracking

#### 6. Board Governance
- **Approval gates:** Agent hires, CEO strategy proposals
- **Unrestricted intervention:** Board can pause/override any decision
- **Activity logging:** Immutable audit trail for all mutations

#### 7. Plugin System (In Progress)
- **Out-of-process plugins:** Worker-based isolation
- **Capability system:** Named permissions for host RPC
- **UI extension surfaces:** Custom widgets, dashboards, tools
- **Event/job/webhook surfaces:** React to control plane events
- **Plugin-to-plugin communication:** SDK for inter-plugin RPC

#### 8. Workspace Management
- **Project workspaces:** Git worktree creation for execution isolation
- **Execution workspace policies:** Per-project workspace strategies
- **Provision commands:** Project-defined bootstrap scripts
- **Runtime service tracking:** Dev servers, preview URLs, runtime state

#### 9. Developer Experience
- **Zero-config local dev:** Embedded PostgreSQL, no setup required
- **Worktree-local instances:** Isolated Paperclip instances per git worktree
- **Hot reload:** File watching + optional guarded auto-restart
- **CLI + Web UI:** Both interfaces for control plane operations
- **Deployment modes:** `local_trusted` (no auth) and `authenticated` (private/public)

---

## Scout-and-Wave Overview

### Core Value Proposition
"Parallel AI agents that don't break each other's code" — protocol for safe parallel code generation via disjoint file ownership and worktree isolation.

### Architecture
**Three-repo separation:**

1. **scout-and-wave (Protocol):** Language-agnostic spec (invariants I1-I6, execution rules E1-E26, agent prompts)
2. **scout-and-wave-go (SDK/Engine):** Go implementation (~3,254 Go files, importable SDK)
3. **scout-and-wave-web (Web App):** HTTP/SSE web UI + Go server (imports SDK)

### Key Features

#### 1. Scout Phase (Planning)
- **Suitability gate:** Five precondition checks before decomposition
  1. Work decomposes into independent files
  2. No investigation-first blockers
  3. Discoverable interfaces
  4. Pre-scanned for already-implemented items
  5. Parallelization provides value
- **IMPL doc generation:** Structured coordination artifact defining:
  - File ownership table (which agent owns which files)
  - Interface contracts (shared types, function signatures)
  - Wave structure (parallel execution groups)
  - Agent prompts (task-specific instructions)
- **Conflict resolution at planning time:** Not merge time

#### 2. Scaffold Agent (Interface Materialization)
- **Runs before Wave 1:** Creates shared type files from IMPL contracts
- **Compilation verification:** Ensures scaffolds compile before any wave launches
- **Interface freeze:** Scaffolds committed to HEAD, waves branch from frozen interfaces

#### 3. Wave Execution (Parallel Implementation)
- **Disjoint file ownership (I1):** No two agents in same wave own same file
- **Worktree isolation (I4):** Each agent works in separate git worktree directory
- **Sequential wave execution (I3):** Wave N+1 starts after Wave N merge+verification
- **Commit-before-report (I5):** Agents commit work before writing completion report
- **Tool journaling (E23):** Per-agent execution trace for session recovery

#### 4. Integration Agent (Post-Wave Wiring)
- **Runs after wave merge:** Wires new exports into caller code
- **Restricted to connectors:** Only touches `integration_connectors` files
- **Non-fatal failures:** Reports gaps if wiring fails

#### 5. Worktree Isolation Defense (5 Layers)
- **Layer 0 (Prevention):** Pre-commit hook blocks commits to main
- **Layer 1 (Deterministic):** Manual worktree pre-creation by orchestrator
- **Layer 2 (Tool-level):** `isolation: "worktree"` parameter on agent launch
- **Layer 3 (Cooperative):** Agents verify own branch/cwd on startup
- **Layer 4 (Deterministic):** Merge-time trip wire detects zero-commit failures

#### 6. Quality Gates
- **E16 (Scout validation):** IMPL doc structure validation
- **E20 (Stub detection):** Scan for incomplete implementations
- **E21 (Post-wave gates):** Configurable quality checks after merge
- **E22 (Scaffold verification):** Ensure scaffolds compile before wave launch
- **E25 (Integration validation):** Verify integration agent restrictions

#### 7. State Management
- **IMPL doc (I4):** Single source of truth for planning
- **Tool journals:** Execution history for recovery
- **Completion reports:** Synthesis written back to IMPL doc
- **Wave status tracking:** Disk-persisted state for resumption

#### 8. Cross-Repo Support
- **Multi-repo waves:** Agents work across different repositories
- **Per-repo file ownership:** I1 applies within each repo independently
- **Repo-specific worktrees:** Isolation maintained across repos

---

## Feature Comparison Matrix

| Feature | SAW | Paperclip | Winner | Notes |
|---------|-----|-----------|--------|-------|
| **Problem Space** | Tactical: Parallel code generation for single features | Strategic: Company-level agent orchestration | **Complementary** | Different abstraction levels |
| **Execution Scope** | Minutes-hours (one feature) | Days-weeks-months (ongoing company) | **Complementary** | SAW is per-task, Paperclip is continuous |
| **Parallelism Model** | Disjoint file ownership + worktree isolation | Task-based concurrency via checkout atomicity | **SAW** | SAW's file-level disjointness prevents merge conflicts structurally |
| **Conflict Prevention** | Structural (I1 invariant enforced at planning time) | Operational (single assignee, checkout locks) | **SAW** | SAW eliminates conflicts; Paperclip prevents double-work |
| **Agent Coordination** | Sequential waves, frozen interfaces, no direct communication | Hierarchical org, cross-team delegation, task assignment | **Paperclip** | Paperclip designed for long-running coordination |
| **State Management** | IMPL doc + tool journals + completion reports | PostgreSQL (companies, agents, issues, heartbeats, costs) | **Paperclip** | Paperclip built for persistent multi-agent state |
| **Cost Control** | No built-in budget tracking | Monthly budgets, cost events, hard-stop enforcement | **Paperclip** | Paperclip designed for budget governance |
| **Human Governance** | Review IMPL doc before execution, approve plan | Board approval gates, pause/override any decision | **Paperclip** | Paperclip built for continuous oversight |
| **Task Management** | Single IMPL doc per feature | Hierarchical issues, parent-child chains, comments | **Paperclip** | Paperclip is a full task management system |
| **Observability** | Completion reports, tool journals, wave status | Activity logs, heartbeat events, cost rollups, live dashboard | **Paperclip** | Paperclip has richer long-term observability |
| **Recovery Model** | Tool journals enable session resumption | Heartbeat retry, session persistence, stuck run detection | **Paperclip** | Paperclip handles long-running agent failures |
| **UI/UX** | Web dashboard for IMPL browsing, wave execution, SSE progress | Full board UI: org chart, task board, approvals, costs, agents | **Paperclip** | Paperclip is a complete control plane UI |
| **Adapter System** | Protocol-agnostic (any Agent Skills-compatible tool) | 8+ built-in adapters (OpenClaw, Claude, Codex, Cursor, etc.) | **Paperclip** | Paperclip has more mature adapter ecosystem |
| **Plugin System** | No plugin system | Out-of-process plugins with capability system | **Paperclip** | Paperclip designed for extensibility |
| **Local Dev Experience** | Go CLI + web UI, Claude Code skill, Claude Max support | Embedded PostgreSQL, zero-config dev, worktree-local instances | **Paperclip** | Paperclip's local dev is more polished |
| **Deployment Complexity** | Single Go binary + optional web UI | Node.js server + PostgreSQL + optional S3 | **SAW** | SAW is lighter weight |
| **Multi-Tenancy** | Single user/project focus | Multi-company in single deployment | **Paperclip** | Paperclip designed for multi-company operation |
| **Documentation** | Protocol spec with 6 invariants, 26 execution rules | Product spec + implementation spec + AGENTS.md + DATABASE.md | **Tie** | Both well-documented, different styles |
| **Testing/Validation** | Suitability gate (5 preconditions), quality gates (E20/E21) | Budget enforcement, approval gates, activity auditing | **Tie** | Different validation concerns |
| **Codebase Maturity** | 3,254 Go files (SDK), protocol-first design | ~26k LOC services, 35+ UI pages, production-ready | **Paperclip** | Paperclip is more feature-complete |

---

## Borrowable Ideas (Priority Ranked)

### 1. **Disjoint File Ownership Model** (High Value, Medium Effort)

**What it does in Paperclip:** Currently, Paperclip uses single-assignee task checkout to prevent double-work. If two agents try to work on the same task, only one gets it (atomic checkout).

**How SAW's model differs:** SAW enforces disjoint file ownership at planning time. The Scout assigns every file that will change to exactly one agent before execution begins. No two agents in the same wave can produce edits to the same file, making merge conflicts structurally impossible.

**How it could improve Paperclip:**
- When a Paperclip agent creates subtasks, it could specify which files each subtask touches
- Paperclip could validate that subtasks don't overlap on files before agents start work
- This would enable safe parallel execution within a single project/task context
- Could be exposed as a "parallel execution policy" on projects

**Implementation effort:** Medium
- Schema: Add `file_ownership` JSONB field to `issues` table
- Validation: Add pre-execution ownership conflict check in heartbeat service
- UI: File ownership editor in task creation/editing
- Agent skill: Update Paperclip skill to guide agents on declaring file ownership

**Dependencies:**
- Requires project workspace model (already exists in Paperclip)
- Would benefit from git worktree support (see #2)

---

### 2. **Git Worktree Isolation for Parallel Agents** (High Value, High Effort)

**What it does in Paperclip:** Currently, agents work on the same git checkout. If two agents modify the same project simultaneously, they race on build artifacts, lock files, and tool caches.

**How SAW does it:** Each SAW wave agent works in its own git worktree — a separate directory with an independent file tree but shared git history. This prevents:
- Concurrent `go build` / `npm install` conflicts
- Race conditions on `.cache/` directories
- Lock file contention
- Flaky test runs from shared state

**How it could improve Paperclip:**
- Enable true parallel agent execution within a project
- Each agent gets isolated workspace with independent build cache
- Merge only happens after all agents report completion
- Pairs perfectly with disjoint file ownership (#1)

**Implementation effort:** High
- Core: Worktree creation/management utilities
- Schema: Track worktree paths per heartbeat run in `heartbeat_runs`
- Execution: Modify workspace realization to support worktree mode
- Cleanup: Worktree deletion after merge
- Pre-commit hook: Block commits to main during parallel work (SAW's Layer 0 defense)

**Dependencies:**
- Project workspace model (exists)
- Git operations service (needs enhancement)
- Requires disjoint file ownership (#1) to be truly safe

---

### 3. **IMPL Doc Pattern for Complex Task Decomposition** (Medium Value, Medium Effort)

**What it does in Paperclip:** Currently, task hierarchy is freeform. Agents create subtasks as they see fit, but there's no structured planning artifact.

**How SAW does it:** The Scout produces an IMPL doc before any implementation begins. This is a structured markdown file that defines:
- Which files each agent will modify (disjoint ownership table)
- What interfaces agents will implement (contracts section)
- How agents are grouped into waves (parallel execution groups)
- What each agent should do (agent prompts)

**How it could improve Paperclip:**
- For complex features, CEO/CTO agents could produce an "implementation plan" document
- Board reviews plan before agents start work (checkpoint for architectural decisions)
- Provides clear visibility: "Here's what will change and who's doing it"
- Enables human intervention at planning time when it's cheap

**Implementation effort:** Medium
- Schema: Add `implementation_plan` JSONB field to `issues` or new `issue_plans` table
- Service: Plan generation/validation service
- UI: Plan viewer/editor in issue detail page
- Skill: Guide agents on creating structured plans for complex work

**Dependencies:**
- Would benefit from disjoint file ownership (#1)
- Could integrate with approval system (board approves plans)

---

### 4. **Suitability Gate for Task Decomposition** (Low Value, Low Effort)

**What it does in Paperclip:** Currently, agents attempt all assigned work. There's no automatic "this task isn't suitable for the current approach" detection.

**How SAW does it:** Before producing an IMPL doc, the Scout runs a suitability gate checking five preconditions:
1. Work decomposes into independent files
2. No investigation-first blockers
3. Discoverable interfaces
4. Pre-scanned for already-implemented items
5. Parallelization provides value

If preconditions fail, Scout emits "NOT SUITABLE" and stops.

**How it could improve Paperclip:**
- CEO/manager agents could evaluate whether a task is "ready to delegate"
- Prevents wasted work on poorly-defined tasks
- Could surface as "task readiness score" in UI
- Agents could refuse tasks with low readiness

**Implementation effort:** Low
- Service: Task readiness evaluator (simple heuristics or LLM call)
- Schema: Add `readiness_score` or `decomposition_viable` field to `issues`
- UI: Display readiness indicator, block task start if not ready
- Skill: Guide agents on checking task readiness

**Dependencies:** None (standalone feature)

---

### 5. **Tool Journaling for Session Recovery** (Medium Value, Medium Effort)

**What it does in Paperclip:** Currently, heartbeat runs store `context_snapshot` JSONB and session data in `agent_runtime_state` / `agent_task_sessions`. Recovery relies on adapter-managed session persistence.

**How SAW does it:** Each wave agent maintains a tool journal — an append-only log of every tool call, file modification, command executed, and test run. If an agent session crashes, it can:
- Resume from where it left off by reading the journal
- Reconstruct "what I've already done" without re-executing
- Provide deterministic replay for debugging

**How it could improve Paperclip:**
- More robust agent recovery after crashes/timeouts
- Better observability: "Exactly what did this agent do during its heartbeat?"
- Enable partial work credit (agent made progress even if didn't finish)
- Could power "show me the execution trace" debugging UI

**Implementation effort:** Medium
- Schema: New `heartbeat_run_journal_entries` table or file-based append log
- Service: Journal append/read operations
- Integration: Adapters emit journal entries for major operations
- UI: Journal viewer in heartbeat run detail page

**Dependencies:**
- Adapter cooperation (adapters need to emit journal entries)
- Could integrate with existing `heartbeat_run_events` table

---

### 6. **Pre-Commit Hook for Isolation Enforcement** (High Value, Low Effort)

**What it does in Paperclip:** Currently, agents are trusted to work in their assigned workspace. If an agent accidentally commits to the wrong branch, Paperclip doesn't prevent it.

**How SAW does it:** SAW's Layer 0 isolation defense is a pre-commit hook installed in every worktree. It:
- Blocks commits to `main` branch during active waves
- Provides instructive error message: "You're in a wave worktree, commit to your branch"
- Orchestrator bypasses via `SAW_ALLOW_MAIN_COMMIT=1` environment variable

**How it could improve Paperclip:**
- Prevent agents from accidentally committing to main during parallel work
- Structural guarantee rather than relying on agent cooperation
- Simple to implement, high reliability

**Implementation effort:** Low
- Git hooks: Create pre-commit hook template
- Installation: Install hook when creating execution workspaces
- Bypass mechanism: Environment variable for orchestrator commits

**Dependencies:**
- Git worktree support (#2) — otherwise no worktrees to protect
- Project workspace model (exists)

---

### 7. **Structured Completion Reports** (Low Value, Low Effort)

**What it does in Paperclip:** Currently, agents report completion via status updates and comments. Format is freeform.

**How SAW does it:** SAW defines a structured completion report format in the protocol:
```yaml
agent: agent-id
status: success | blocked | partial
commit: git-sha | uncommitted
summary: Human-readable summary
files_modified: [list]
tests_run: [list]
verification_status: {build, tests, gates}
blockers: [list if blocked]
notes: Additional context
```

**How it could improve Paperclip:**
- Machine-readable work summaries for rollup/dashboard
- Easier to detect incomplete work (uncommitted changes, failed tests)
- Could populate activity log automatically from completion reports
- Enables richer "work done this sprint" summaries

**Implementation effort:** Low
- Schema: Define completion report JSON schema in `packages/shared`
- Service: Completion report parser/validator
- UI: Structured completion report renderer in issue comments
- Skill: Update Paperclip skill to guide agents on report format

**Dependencies:** None (standalone feature)

---

### 8. **Wave-Style Parallel Execution Mode** (High Value, High Effort)

**What it does in Paperclip:** Currently, agents execute tasks sequentially (one agent per task, first-come-first-served).

**How SAW does it:** Scout groups agents into "waves" — sets of agents that execute in parallel with disjoint file ownership. Wave N+1 doesn't start until Wave N merges and verifies.

**How it could improve Paperclip:**
- Enable "parallel sprint" execution mode
- Manager agent creates wave plan: "These 5 agents will work in parallel on these subtasks"
- Board approves wave plan before execution
- Agents execute in parallel, orchestrator merges when all complete
- Next wave branches from merged result

**Implementation effort:** High (requires #1 and #2 first)
- Schema: Wave tracking table, wave membership
- Execution: Wave lifecycle state machine
- Merge: Wave merge procedure (merge all agent branches to main)
- Verification: Post-wave quality gates
- UI: Wave dashboard, wave status visualization

**Dependencies:**
- Disjoint file ownership (#1) — required for safety
- Git worktree isolation (#2) — required for clean parallel execution
- IMPL doc pattern (#3) — helpful for planning

---

### 9. **Protocol-First Design for Portability** (Low Value, High Effort)

**What it does in Paperclip:** Paperclip is a single implementation (Node.js/TypeScript server with React UI).

**How SAW does it:** SAW separates protocol specification from implementation:
- **scout-and-wave repo:** Protocol spec (invariants, execution rules, agent prompts) — language-agnostic
- **scout-and-wave-go repo:** Go SDK implementation of protocol
- **scout-and-wave-web repo:** Web UI consuming Go SDK

This enables:
- Multiple implementations (Go SDK, potential Rust/Python/TypeScript SDKs)
- Protocol evolution independent of implementation
- Clear contracts for what "correct SAW execution" means

**How it could improve Paperclip:**
- Formalize Paperclip protocol (what must every Paperclip-compatible system do?)
- Enable alternative implementations (lightweight CLI, embedded library, etc.)
- Clearer contracts for adapter authors

**Implementation effort:** High
- Documentation: Extract protocol spec from code
- Validation: Define compliance tests
- Refactoring: Separate protocol concerns from implementation details

**Dependencies:** None, but low immediate value (Paperclip is stable as single implementation)

---

### 10. **Quality Gate System** (Medium Value, Medium Effort)

**What it does in Paperclip:** Currently, agents self-report success/failure. There's no automatic quality validation.

**How SAW does it:** SAW defines several quality gates:
- **E20 (Stub detection):** Scan merged code for TODO/FIXME/stub implementations
- **E21 (Post-wave gates):** Configurable checks after merge (tests pass, linting, compilation)
- **E22 (Scaffold verification):** Ensure shared types compile before wave launches
- **E25 (Integration validation):** Verify integration agent stayed in bounds

**How it could improve Paperclip:**
- Automatic verification that work is actually complete
- Detect when agents claim success but left incomplete code
- Block task closure until quality gates pass
- Could integrate with CI/CD systems

**Implementation effort:** Medium
- Service: Quality gate runner (execute checks, collect results)
- Schema: Gate results table, gate configuration per project
- UI: Gate status in issue detail, gate failure alerts
- Integration: Hook into task completion flow

**Dependencies:**
- Project workspace model (exists)
- Could integrate with plugin system for custom gates

---

## Strategic Insights

### 1. Market Positioning Differences

**Paperclip** = **Infrastructure play**
- Target: People building autonomous AI companies
- Vision: "Paperclip becomes the default foundation that autonomous companies are built on"
- Revenue model: Self-hosted (open source), potential cloud offering, ClipMart marketplace
- Competitive moat: Control plane completeness, adapter ecosystem, plugin system

**Scout-and-Wave** = **Developer tool / protocol**
- Target: AI coding agents (Claude Code, Cursor, GitHub Copilot, etc.)
- Vision: "Standard protocol for safe parallel code generation"
- Revenue model: Open source protocol, commercial implementations/services
- Competitive moat: Protocol correctness guarantees (6 invariants), worktree isolation, Agent Skills standard

### 2. Complementary vs Competitive Relationship

**High complementarity:**
- Paperclip agents could invoke SAW as a "skill" for complex parallelizable features
- SAW provides the tactical execution layer; Paperclip provides strategic coordination
- Integration path: Paperclip's Codex/Claude adapters could include SAW protocol skill
- Example flow:
  1. Paperclip CEO assigns "implement caching layer" to engineer agent
  2. Engineer agent recognizes this is parallelizable
  3. Engineer invokes SAW Scout to create IMPL doc
  4. Engineer submits IMPL doc to Paperclip board for approval
  5. Board approves, engineer executes SAW waves
  6. Waves complete, engineer reports back to Paperclip with completion report

**Low competition:**
- Different time horizons (Paperclip: continuous, SAW: per-feature)
- Different abstraction levels (Paperclip: company/org, SAW: files/worktrees)
- Different user personas (Paperclip: entrepreneurs, SAW: developers)

### 3. Partnership/Integration Opportunities

#### Opportunity A: SAW as Paperclip Skill
- **What:** Package SAW protocol as a Paperclip agent skill
- **Value:** Paperclip agents gain ability to execute complex features in parallel
- **Implementation:**
  - SAW IMPL doc becomes an artifact type in Paperclip (stored in `issue_documents` or similar)
  - Paperclip board reviews/approves IMPL docs
  - Paperclip heartbeat service invokes SAW wave execution
  - SAW completion reports flow back to Paperclip activity log
- **Effort:** Medium (requires defining integration contract)

#### Opportunity B: Paperclip Adapter for SAW Agents
- **What:** Create a Paperclip adapter that runs as SAW wave agents
- **Value:** SAW wave agents can participate in Paperclip companies
- **Implementation:**
  - `paperclip_wave_agent` adapter type
  - SAW IMPL doc specifies Paperclip task assignments for each wave agent
  - Wave agents report progress/costs back to Paperclip
- **Effort:** Medium (adapter development + protocol mapping)

#### Opportunity C: Shared Observability Model
- **What:** Align SAW tool journals with Paperclip activity logs
- **Value:** Unified execution trace across both systems
- **Implementation:**
  - SAW journal entries → Paperclip activity log format
  - Paperclip UI can render SAW-originated events
- **Effort:** Low (mostly format alignment)

#### Opportunity D: Joint Budget Management
- **What:** SAW wave agents report token/cost usage to Paperclip budget system
- **Value:** Paperclip's budget enforcement works for SAW-executed work
- **Implementation:**
  - SAW agents emit cost events in Paperclip format
  - SAW orchestrator enforces Paperclip budget limits
- **Effort:** Low (cost reporting format already exists in Paperclip)

### 4. Where Each System Excels

**Paperclip excels at:**
- Long-running autonomous operation
- Multi-agent coordination across time (days/weeks/months)
- Cost/budget governance
- Human oversight and approval workflows
- Task hierarchy and goal alignment
- Adapter ecosystem maturity
- Production deployment (auth, multi-tenancy, plugins)

**Scout-and-Wave excels at:**
- Conflict-free parallel execution (structural guarantee via I1)
- Execution safety (worktree isolation, quality gates)
- Deterministic planning (suitability gate, IMPL doc review)
- Session recovery (tool journals)
- Protocol clarity (6 invariants, 26 execution rules)
- Lightweight deployment (single Go binary)

---

## Technical Pattern Comparison

| Pattern | Paperclip Approach | SAW Approach | Key Difference |
|---------|-------------------|--------------|----------------|
| **Parallelism** | Task-based (multiple agents work on different tasks) | File-based (multiple agents work on disjoint files in same feature) | SAW parallelizes within a feature; Paperclip parallelizes across features |
| **Conflict Prevention** | Single assignee + atomic checkout | Disjoint file ownership + worktree isolation | SAW prevents merge conflicts structurally; Paperclip prevents task conflicts operationally |
| **State Persistence** | PostgreSQL (companies, agents, issues, heartbeats) | IMPL doc + tool journals (git-tracked + per-agent logs) | Paperclip: database-centric; SAW: file-centric |
| **Human Checkpoints** | Approval gates for hires/strategy, always-available intervention | IMPL doc review before wave execution | Paperclip: continuous oversight; SAW: upfront architectural approval |
| **Agent Communication** | Tasks, comments, @-mentions, cross-team delegation | No direct communication (frozen interfaces, completion reports) | Paperclip: rich coordination; SAW: isolated execution |
| **Execution Model** | Heartbeat invocations (scheduled + event-driven) | Sequential waves (wave N+1 after wave N merge) | Paperclip: continuous; SAW: batch-oriented |
| **Recovery** | Session persistence, heartbeat retry, stuck run detection | Tool journals enable session resumption | Both support recovery, different mechanisms |
| **Observability** | Activity logs, cost rollups, live dashboard, heartbeat events | Completion reports, tool journals, wave status | Paperclip: real-time operational; SAW: post-completion analytical |

---

## Codebase Architecture Comparison

### Paperclip Architecture
```
server/src/
  services/          (~26k LOC core business logic)
    agents.ts        (agent lifecycle, adapter invocation)
    heartbeat.ts     (scheduling, execution, session management)
    issues.ts        (task CRUD, checkout atomicity)
    costs.ts         (cost event ingestion, rollups)
    budgets.ts       (budget enforcement, hard-stops)
    approvals.ts     (governance workflow)
    workspace-*.ts   (workspace management, runtime services)
  adapters/          (8+ adapter implementations)
    openclaw-gateway/, claude-local/, codex-local/, etc.
  routes/            (REST API endpoints)
  middleware/        (auth, logging, error handling)

ui/src/pages/        (35+ React pages)
  Dashboard.tsx      (company overview)
  Agents.tsx         (org chart, agent list)
  AgentDetail.tsx    (agent config, heartbeat history)
  Issues.tsx         (task board)
  Costs.tsx          (budget tracking, cost visualization)
  Approvals.tsx      (governance queue)

packages/
  db/                (Drizzle schema, migrations)
  shared/            (types, validators, API paths)
  adapters/          (adapter implementations)
  plugins/           (plugin system runtime)
```

**Strengths:**
- Comprehensive service layer (agents, heartbeats, issues, costs, budgets, approvals)
- Rich UI (35+ pages covering entire control plane)
- Mature adapter ecosystem (8+ adapters)
- Production-ready (auth, logging, error handling, migrations)

**Weaknesses:**
- Monolithic server (all services in one process)
- No explicit protocol specification (implementation is the spec)
- Heavy deployment (Node.js + PostgreSQL + optional S3)

---

### Scout-and-Wave Architecture
```
scout-and-wave/                (Protocol repo)
  protocol/
    invariants.md              (I1-I6: correctness rules)
    execution-rules.md         (E1-E26: operational procedures)
    participants.md            (Scout, Scaffold, Wave, Integration, Orchestrator)
    preconditions.md           (5-question suitability gate)
    state-machine.md           (protocol state transitions)
    message-formats.md         (IMPL doc schema, completion report format)

scout-and-wave-go/             (Go SDK)
  pkg/
    protocol/                  (IMPL parsing, validation, state management)
    engine/                    (wave execution, merge, verification)
    worktree/                  (git worktree manager, isolation enforcement)
    agent/                     (agent prompt generation, context extraction)
  cmd/sawtools/                (CLI commands: run-scout, prepare-wave, finalize-wave)

scout-and-wave-web/            (Web UI)
  pkg/api/                     (HTTP handlers, SSE publisher, wave runner)
  web/src/                     (React UI: IMPL browser, wave dashboard)
  cmd/saw/                     (server binary)
```

**Strengths:**
- Protocol-first design (spec separate from implementation)
- Clear correctness guarantees (6 invariants)
- Lightweight deployment (single Go binary)
- Strong isolation mechanisms (worktree + pre-commit hook)

**Weaknesses:**
- Narrower scope (only parallel code generation, not full orchestration)
- No built-in cost/budget tracking
- No multi-agent long-running coordination
- Simpler UI (focused on IMPL browsing and wave status)

---

## Recommendations for Scout-and-Wave

Based on Paperclip's strengths, SAW could benefit from:

### 1. **Add Cost Tracking to Tool Journals** (High Priority)
- Wave agents already log tool calls; extend to include token/cost metadata
- Enable cost rollups per agent, per wave, per IMPL
- Makes SAW more attractive for production use where costs matter

### 2. **Consider Heartbeat-Style Resumption** (Medium Priority)
- Paperclip's heartbeat system handles long-running agents well
- SAW could add "pause/resume wave" capability using tool journals
- Useful for multi-hour wave executions that need to pause for CI/deploys

### 3. **Explore Plugin System for Custom Quality Gates** (Low Priority)
- Paperclip's plugin system is powerful for extensibility
- SAW could allow custom E21 gate implementations
- Enables project-specific verification without changing core protocol

### 4. **Add Hierarchical Task Decomposition** (Low Priority)
- Paperclip's parent-child task chains provide good context
- SAW's IMPL doc could include "parent task" reference
- Helps agents understand "why am I doing this work?"

---

## Recommendations for Paperclip

Based on SAW's strengths, Paperclip could benefit from:

### 1. **Adopt Disjoint File Ownership for Parallel Work** (High Priority)
- Implement ideas #1, #2, #6 from borrowable ideas list
- Enable safe parallel agent execution within projects
- Major differentiation vs other orchestration systems

### 2. **Add Structured Planning Artifacts** (High Priority)
- Implement idea #3 (IMPL doc pattern)
- Give board visibility into "what will change" before agents start
- Reduces cost of architectural pivots (change plan, not code)

### 3. **Improve Session Recovery with Tool Journaling** (Medium Priority)
- Implement idea #5
- More robust agent recovery after crashes
- Better "show me what this agent did" observability

### 4. **Add Suitability Gate for Task Delegation** (Low Priority)
- Implement idea #4
- CEO/manager agents evaluate whether task is "ready to delegate"
- Reduces wasted work on poorly-defined tasks

### 5. **Consider SAW Integration** (Low Priority)
- Implement opportunity A (SAW as Paperclip skill)
- Gives Paperclip agents access to proven parallel execution protocol
- Differentiates Paperclip as "orchestration + execution" not just orchestration

---

## Conclusion

**Paperclip** and **Scout-and-Wave** are **highly complementary systems** solving problems at different abstraction levels:

- **Paperclip** = Strategic layer (company/org/budget/governance)
- **Scout-and-Wave** = Tactical layer (parallel code generation with safety guarantees)

**Best integration path:** SAW becomes a skill that Paperclip agents invoke for parallelizable work. This gives Paperclip agents access to SAW's proven conflict-prevention mechanisms while maintaining Paperclip's strategic coordination capabilities.

**Key borrowable ideas for Paperclip:**
1. Disjoint file ownership (#1) — structural conflict prevention
2. Git worktree isolation (#2) — clean parallel execution
3. IMPL doc pattern (#3) — upfront planning visibility
4. Pre-commit hook (#6) — enforcement at infrastructure level
5. Tool journaling (#5) — robust session recovery

**Key borrowable ideas for SAW:**
1. Cost tracking in tool journals — production readiness
2. Heartbeat-style resumption — long-running wave support
3. Plugin system for quality gates — extensibility

**Strategic opportunity:** Position SAW as the "parallel execution layer" for AI orchestration systems like Paperclip. Market SAW to orchestration platform builders as "how to safely parallelize agent work."

---

**Analysis completed:** 2026-03-20
**Files analyzed:** README.md, AGENTS.md, SPEC.md, SPEC-implementation.md, PRODUCT.md, GOAL.md, DATABASE.md, DEVELOPING.md, protocol/* (from both repos)
**Total lines reviewed:** ~15,000+ lines of documentation and code
