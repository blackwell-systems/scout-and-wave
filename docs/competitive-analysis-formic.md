# Competitive Analysis: Formic vs Scout-and-Wave

**Date:** 2026-03-28
**Formic Version Analyzed:** v0.5.0
**SAW Version Analyzed:** v0.26.0

---

## Executive Summary

**Verdict:** Both systems solve parallel agent coordination but address fundamentally different problems with different tradeoffs.

### When to Use Formic
- **Rapid prototyping** — Minimal setup, no planning phase, agents start working immediately
- **Small teams/solo developers** — Simple Kanban UI, conversational task creation
- **Iterative/exploratory work** — Goal decomposition with DAG dependencies, self-healing loops
- **Shared-file workloads** — Optimistic concurrency with collision detection handles shared resources

### When to Use SAW
- **Production-critical work** — Formal protocol with 6 invariants and 45+ execution rules
- **Large-scale parallelization** — Wave-based execution with deterministic conflict prevention
- **Cross-repository coordination** — Multi-repo IMPLs with cross-repo gate verification
- **Distributed teams** — Provider-agnostic (Anthropic API, Bedrock, OpenAI-compatible, CLI wrappers)
- **Auditable execution** — Lifecycle hooks, observability events, protocol compliance enforcement

**Architectural Philosophy:**
- **Formic:** "Move fast, detect conflicts optimistically, self-heal when things break"
- **SAW:** "Plan first, prevent conflicts by construction, verify at every boundary"

---

## 1. Architecture Comparison

### 1.1 Core Coordination Model

| Aspect | Formic | Scout-and-Wave |
|--------|--------|----------------|
| **Conflict Prevention** | Optimistic concurrency (file leases + collision detection) | Disjoint file ownership (I1 invariant, enforced at 4 layers) |
| **Planning Phase** | Optional (Brief/Plan skills, but can skip for quick tasks) | Mandatory Scout phase with suitability analysis |
| **Execution Model** | Task queue with lease acquisition → execute → verify → self-heal | Wave sequencing: Scout → Scaffold → Wave N → Verify → Wave N+1 |
| **State Management** | JSON file (`board.json`) + task doc folders in `.formic/` | YAML IMPL doc (git-tracked, I4 single source of truth) |
| **Isolation Strategy** | None (all agents work in same workspace, leases prevent conflicts) | Git worktrees per agent with E43 hook-based enforcement |
| **Interface Contracts** | Implicit (agents discover patterns in codebase) | Explicit (I2: Scaffold Agent materializes interfaces before Wave 1) |

**Key Insight:** Formic assumes conflicts are rare and detectable after-the-fact. SAW assumes conflicts are inevitable without structural prevention.

---

### 1.2 Agent Coordination Patterns

#### Formic: Lease-Based Concurrency

```typescript
// Formic workflow
1. Task queued → Queue processor picks task
2. Execute "declare" skill → Agent identifies files needed
3. Acquire exclusive/shared leases atomically (all-or-nothing)
   - Exclusive: single writer, blocks all others
   - Shared: multiple readers, optimistic collision detection
4. Execute → Agent works on files
5. Detect collisions (git hash-object comparison for shared files)
6. Verify (run test command) → If fail, create Fix task
7. Release leases → Broadcast to wake waiting tasks
```

**Strengths:**
- Flexible: Agents don't need to know all files upfront (can declare mid-execution)
- Simple: No worktree setup, all agents in same workspace
- Dynamic: Lease duration/renewal handles long-running tasks

**Weaknesses:**
- Race conditions: Agent A can modify shared file before Agent B detects collision
- No guarantees: Leases expire, watchdog can forcibly release stale leases
- Merge conflicts: If two agents modify same file and produce different content, manual resolution required

---

#### SAW: Disjoint Ownership + Worktrees

```yaml
# SAW workflow
1. Scout analyzes codebase → Produces IMPL doc with file_ownership table
2. Human reviews → Approves ownership + interface contracts
3. Scaffold Agent creates shared types → Commits to HEAD
4. Orchestrator validates I1 (no two agents own same file in same wave)
5. Orchestrator creates worktrees (git worktree add) per agent
6. Wave agents execute in parallel (isolation = no conflicts possible)
7. Orchestrator merges sequentially (E11 conflict prediction pre-merge)
8. Post-merge verification (E20 stub scan, E21 quality gates, E25 integration gaps)
9. Wave N+1 launches only after Wave N verification passes (I3)
```

**Strengths:**
- Deterministic: I1 violations structurally impossible (defense-in-depth: hooks, pre-launch validation, post-completion audit)
- Safe: Agents cannot see each other's uncommitted work (true isolation)
- Auditable: 4-layer enforcement (E43 hooks, E3 validation, E11 conflict prediction, E42 ownership audit)

**Weaknesses:**
- Overhead: Worktree creation/cleanup, git operations per agent
- Rigidity: Ownership must be declared upfront in IMPL doc
- Complexity: 42,000+ lines of Go protocol enforcement code

---

### 1.3 State Management

| Feature | Formic | SAW |
|---------|--------|-----|
| **State Storage** | JSON file (`board.json`) | YAML IMPL doc (git-tracked) |
| **Task Tracking** | Kanban statuses (todo, queued, briefing, planning, declaring, running, verifying, review, done, blocked, architecting) | Wave-based (SAW:NOT_STARTED, SAW:IN_PROGRESS:WAVEN, SAW:COMPLETED, SAW:COMPLETE) |
| **Dependency Model** | DAG (depends_on/dependsOnResolved with Kahn's topological sort) | Wave sequencing (waves execute serially, dependencies via wave number) |
| **Conflict Resolution** | Optimistic (detect conflicts post-execution via hash comparison) | Preventive (I1 disjoint ownership + 4-layer enforcement) |
| **Persistence** | Local JSON + task documentation folders | Git-tracked YAML + completion reports inline |

**Formic's Advantage:** Simpler state model, no git requirements beyond basic commits.
**SAW's Advantage:** Git-native state = audit trail, time-travel debugging, distributed coordination.

---

## 2. Formic Strengths

### 2.1 Developer Experience

**Onboarding:**
```bash
# Formic
npm install -g @rickywo/formic
cd my-project
formic start
# Open http://localhost:8000 → Start creating tasks

# SAW
# Install sawtools CLI + Claude Code + configure hooks + init project
# Learning curve: 6 invariants, 45+ execution rules, protocol documentation
```

**Task Creation:**
- **Formic:** Conversational AI Task Manager — "Add dark mode toggle" → Agent understands context, creates optimized task
- **SAW:** Structured `/saw scout "add dark mode"` → Scout analyzes, produces multi-page IMPL doc with ownership table

**Iteration Speed:**
- **Formic:** Quick tasks skip brief/plan → Execute immediately
- **SAW:** Every feature goes through full Scout → Review → Scaffold → Wave cycle

---

### 2.2 Self-Healing Architecture

**Formic's Critic Loop:**
```typescript
1. Task executes
2. Verification fails (npm test fails)
3. Auto-create Fix task (HIGH priority) with error context
4. Re-queue original task (retryCount++)
5. After 3 failures → Kill switch (revert to safe-point, pause queue)
```

**SAW's Equivalent:**
- E19 failure classification (transient/fixable/needs_replan/escalate/timeout)
- E19.1 per-IMPL reactions block (custom routing per failure type)
- Retry context injection via E23A tool journals
- No automatic Fix task creation — requires orchestrator intervention

**Insight:** Formic's self-healing is more automated but less structured. SAW requires explicit failure handling logic.

---

### 2.3 Goal Decomposition (DAG Mode)

**Formic's Architect Skill:**
```json
// Goal: "Implement user authentication system"
// → Agent analyzes codebase, produces:
[
  {
    "task_id": "auth-service",
    "title": "Create auth service",
    "depends_on": []
  },
  {
    "task_id": "jwt-middleware",
    "title": "Add JWT middleware",
    "depends_on": ["auth-service"]
  },
  {
    "task_id": "integration-test",
    "title": "Integration testing",
    "depends_on": ["jwt-middleware"]
  }
]
```

**SAW's Equivalent:**
- `/saw program plan` → Planner agent decomposes into IMPLs with tier assignments
- Wave solver (`pkg/solver`) computes wave numbers from dependency declarations
- Cross-IMPL dependencies handled via P1+ conflict detection

**Formic's Advantage:** Simpler for single-feature decomposition. Kahn's algorithm with BFS unblocking score.
**SAW's Advantage:** Scales to multi-feature programs with tier-gated execution.

---

### 2.4 Memory System (Hippocampus)

**Formic's Reflection:**
```typescript
// After every task completion:
1. Agent reflects on learnings
2. Extracts patterns/pitfalls/preferences
3. Stores in .formic/memory.json with relevance_tags
4. Auto-injects matching memories into future task contexts
```

**SAW's Equivalent:**
- CONTEXT.md history (E18) — human-written project chronicle
- E44 context injection observability — tracks how reference files were received
- No automatic memory extraction

**Insight:** Formic's memory system is agent-driven and self-improving. SAW relies on human curation of CONTEXT.md.

---

### 2.5 Mobile-First PWA

**Formic's UI:**
- Progressive Web App (installable on iOS/Android/desktop)
- Touch-optimized controls (44px+ tap targets)
- Tailscale-compatible for remote development
- Real-time WebSocket updates for parallel agent monitoring

**SAW's UI:**
- scout-and-wave-web (Base16 theming, command palette, SSE streaming)
- Desktop-first (no mobile optimization documented)
- Browser-based dashboard with 15+ IMPL review panels

**Insight:** Formic prioritizes mobile developer experience. SAW prioritizes deep IMPL inspection.

---

## 3. SAW Strengths

### 3.1 Protocol-Driven Correctness

**SAW's Invariants:**
```yaml
I1: Disjoint File Ownership  # No two agents in same wave own same file
I2: Interface Contracts Precede Parallel Implementation  # Scaffolds before Wave 1
I3: Wave Sequencing  # Wave N+1 only after Wave N verified
I4: IMPL Doc is Single Source of Truth  # Completion reports in IMPL, not chat
I5: Agents Commit Before Reporting  # No uncommitted state at report time
I6: Role Separation  # Orchestrator delegates to async agents

P5: IMPL Branch Isolation (programs)  # IMPL waves merge to IMPL branch, not main
```

**Enforcement:**
- **Hooks:** E43 (PreToolUse, PostToolUse, SubagentStop) — 18 hooks across Claude Code lifecycle
- **Validators:** E3 (pre-launch ownership check), E11 (pre-merge conflict prediction), E42 (post-completion audit)
- **SDK Middleware:** `tools.Constraints` on every backend (CLI, daemon, web)

**Formic's Equivalent:** None. No formal invariants. Leases + collision detection + self-healing is reactive, not preventive.

**Insight:** SAW's correctness properties are mechanically enforced. Formic relies on agents to cooperate.

---

### 3.2 Cross-Repository Coordination

**SAW's Cross-Repo IMPL:**
```yaml
# IMPL doc with repo: field per agent
agents:
  - id: A1
    repo: github.com/org/protocol
    files: [docs/SPEC.md]
  - id: A2
    repo: github.com/org/implementation
    files: [pkg/engine/executor.go]
```

**Capabilities:**
- I1 applies per-repository (files in different repos = inherently disjoint)
- E21A baseline gate verification (pre-wave build/test across repos)
- Coordinated merge ordering (merge protocol repo before implementation repo)
- Cross-repo completion reports (I5 commit verification via repo field)

**Formic's Equivalent:** None. Single workspace assumption. `.formic/` directory in one project root.

**Insight:** SAW is designed for multi-repo systems. Formic assumes monorepo or single-project scope.

---

### 3.3 Quality Gates & Verification

**SAW's Gate System:**
```yaml
# IMPL doc quality_gates section (populated by M4 determinism tool)
quality_gates:
  pre_merge:
    - command: "go test ./..."
      type: test
      reason: "Unit test coverage"
  post_merge:
    - command: "go build ./cmd/sawtools"
      type: build
      reason: "Binary compilation check"
```

**Execution:**
- E21A: Baseline gate verification (pre-wave) — ensures clean starting state
- E21: Post-wave gate execution — catches regressions before next wave
- E38: Gate result caching (5-minute TTL) — avoids re-running unchanged gates
- Cross-repo gate support — gates run in each repository affected by IMPL

**Formic's Equivalent:**
```typescript
// Single verifyCommand configured in settings
verifyCommand: "npm test"  // Runs after every task execution
skipVerify: false          // Toggle in UI
```

**Insight:** SAW's gates are declarative, per-IMPL, and run at multiple checkpoints. Formic has one global verify command.

---

### 3.4 Integration Gap Detection

**SAW's E25/E26 Wiring System:**
```yaml
# Agent declares wiring obligations in IMPL doc
agents:
  - id: A1
    wiring:
      - symbol: "NewCacheLayer"
        action: "import and call in pkg/api/handler.go"
```

**Enforcement:**
- E25: Integration validation (Layer 3B) — verifies all declared wiring fulfilled post-merge
- E26: Integration Agent — restricted to `integration_connectors` files, runs after merge
- E35: Wiring obligation tracking — Layer 3A (ownership validation), Layer 3C (brief injection)

**Capabilities:**
- AST-based export scanning (detects new public symbols)
- Action prefix/suffix classification (add/update/remove wiring actions)
- Automated wiring for simple cases, manual for complex

**Formic's Equivalent:** None. Agents expected to handle all integration inline during execution.

**Insight:** SAW treats integration as a first-class concern with dedicated agent role. Formic assumes agents "just do it."

---

### 3.5 Provider Independence

**SAW's Backend Abstraction:**
```go
// pkg/agent/backend/backend.go
type Backend interface {
    Run(ctx context.Context, input Input) (*Result, error)
    RunStreaming(ctx context.Context, input Input, callback func(Event)) error
    RunStreamingWithTools(ctx context.Context, input Input, tools []Tool, callback func(Event)) error
}

// Implementations:
// - Anthropic API (claude-sonnet-4-6, claude-opus-4-6)
// - AWS Bedrock (SSO device auth, regional endpoints)
// - OpenAI-compatible (OpenAI, Groq, Ollama, custom)
// - CLI wrapper (claude, any compatible CLI)
```

**Per-Role Model Configuration:**
```json
// saw.config.json
{
  "scout_model": "claude-opus-4-6",
  "wave_model": "claude-sonnet-4-6",
  "critic_model": "claude-haiku-3-5",
  "integration_model": "claude-sonnet-4-6"
}
```

**Formic's Equivalent:**
```typescript
// Agent adapter supports Claude Code CLI or GitHub Copilot CLI
AGENT_TYPE=claude   // or AGENT_TYPE=copilot
// Single agent type per Formic instance, no per-role configuration
```

**Insight:** SAW is designed for heterogeneous LLM environments. Formic assumes homogeneous agent runtime.

---

### 3.6 PROGRAM Layer (Multi-IMPL Coordination)

**SAW's Tier-Gated Execution:**
```yaml
# Program manifest (created by Planner or assembled bottom-up)
program:
  tiers:
    - tier: 1
      impls: [authentication, user-model]  # Disjoint file ownership (P1)
    - tier: 2
      impls: [api-routes, frontend-integration]  # Depends on tier 1
```

**Invariants:**
- P1: IMPL independence within tier (greedy graph coloring for disjoint assignment)
- P2: Program contracts precede tier execution (E30 contract freezing)
- P3: Tier sequencing (tier N+1 waits for tier N gate verification)
- P4: PROGRAM manifest is source of truth (E32 cross-IMPL progress tracking)
- P5: IMPL branch isolation (E28B, waves merge to IMPL branch, main advances per-tier)

**Formic's Equivalent:**
- DAG dependencies at task level (depends_on/dependsOnResolved)
- No tier concept, no cross-task file ownership validation
- Prioritizer BFS unblocking score for queue ordering

**Insight:** SAW's PROGRAM layer scales to 10+ features with automatic tiering. Formic's DAG handles 3-8 tasks per goal.

---

## 4. Formic Weaknesses

### 4.1 Race Conditions on Shared Files

**Problem:** Optimistic concurrency = conflicts detected AFTER execution

```typescript
// Scenario:
// Task A: Modify src/utils.ts (shared file)
// Task B: Modify src/utils.ts (shared file)

// Timeline:
1. Both tasks acquire shared lease (✓ allowed)
2. Task A modifies utils.ts, hashes recorded
3. Task B modifies utils.ts (different changes)
4. Task A completes → hash comparison shows collision
5. Task B completes → hash comparison shows collision
6. Both tasks marked with fileConflicts
7. Manual merge resolution required
```

**Impact:**
- Wasted compute: Both agents did work that conflicts
- Human intervention: Developer must manually merge
- Unpredictable: Can't know upfront if conflicts will occur

**SAW's Advantage:** I1 prevents this scenario by construction. Scout assigns disjoint ownership upfront.

---

### 4.2 No Cross-Repository Support

**Limitation:** Formic assumes all work happens in one workspace

```
# Cannot coordinate:
- Protocol changes in scout-and-wave repo
- Engine implementation in scout-and-wave-go repo
- Web UI updates in scout-and-wave-web repo

# Would require 3 separate Formic instances, manual coordination
```

**SAW's Advantage:** Cross-repo IMPLs with coordinated merge ordering and per-repo gate verification.

---

### 4.3 Limited Quality Gate System

**Formic's Gates:**
- Single global `verifyCommand` (e.g., `npm test`)
- Runs after every task execution
- Binary pass/fail (no per-task gate customization)

**Limitations:**
- Can't have different gates per task type (e.g., lint for docs, test for code)
- No baseline verification (can't ensure clean state before task starts)
- No gate caching (re-runs full suite every time)

**SAW's Gates:**
- Per-IMPL declarative gates (test, build, lint, custom)
- Pre-merge and post-merge execution phases
- E38 gate result caching (5-minute TTL, keyed on headCommit+diffStat+command)
- Cross-repo gate support

---

### 4.4 No Formal Protocol

**Consequence:** Behavioral drift between UI, queue processor, workflow engine

**Examples:**
- UI displays task as "running" but queue processor hasn't picked it up yet
- Lease expiration handled by watchdog → forceful termination, no agent cleanup
- No specification for "what should happen if agent crashes mid-execution"

**SAW's Advantage:**
- 22 invariants/execution rules define correct behavior
- Protocol documentation (42,000+ lines of spec + implementation)
- State machine specification (`state-machine.md`)
- Auditability: Search for `I{N}` or `E{N}` in code, verify against protocol docs

---

### 4.5 No Worktree Isolation

**Risk:** Agents can accidentally interfere despite leases

```typescript
// Agent A: Leased src/api.ts (exclusive)
// Agent B: Leased src/models.ts (exclusive)

// But both agents run in same workspace, so:
// - Agent A can accidentally modify src/models.ts (outside its lease)
// - Agent B can accidentally modify src/api.ts (outside its lease)
// - No mechanical prevention, only post-hoc collision detection
```

**SAW's Advantage:** E43 hook-based worktree isolation prevents out-of-bounds writes at tool boundary.

---

## 5. SAW Weaknesses

### 5.1 Heavyweight Setup & Onboarding

**Barrier to Entry:**
```bash
# Install requirements
- sawtools CLI (Go binary, 60+ commands)
- Claude Code with lifecycle hooks support
- Protocol knowledge (6 invariants, 45+ rules)

# Initialize project
sawtools init  # Creates .saw/ directory, config file

# Configure backends (if not using default)
# Edit saw.config.json for AWS Bedrock, OpenAI-compatible, etc.

# Learn orchestration patterns
# Read /saw skill documentation, agent type contracts, progressive disclosure
```

**Formic's Advantage:** `npm install -g @rickywo/formic && formic start` — productive in 2 minutes.

---

### 5.2 Rigid Planning Phase

**Overhead:** Every feature requires Scout → Review → Scaffold cycle

```yaml
# Small features still need full IMPL doc:
# - 2-agent change to add logging: Full Scout analysis, ownership table, scaffolds
# - Typo fix in documentation: Scout must produce IMPL doc with Wave 1 agent

# Time cost:
# - Scout: 30-90 seconds (with H1a/H2/H3/H7 automation)
# - Human review: 1-5 minutes (approve ownership, validate interface contracts)
# - Scaffold (if needed): 30-60 seconds
```

**Formic's Advantage:** Quick tasks skip brief/plan, execute immediately. Goal tasks decompose dynamically.

---

### 5.3 Wave Sequencing Overhead

**I3 Constraint:** Wave N+1 waits for Wave N verification to pass

```yaml
# Scenario: 3-wave IMPL
Wave 1: Agents A1, A2 (2 minutes each, parallel)
  → Merge + verify (1 minute)
Wave 2: Agents A3, A4 (2 minutes each, parallel)
  → Merge + verify (1 minute)
Wave 3: Agent A5 (2 minutes)
  → Merge + verify (1 minute)

Total: ~9 minutes (2 + 1 + 2 + 1 + 2 + 1)

# If Wave 1 verification fails:
# - Re-run Wave 1 agents → +2 minutes
# - All subsequent waves delayed
```

**Formic's Advantage:** No wave concept. All independent tasks can run in parallel (subject to lease availability).

---

### 5.4 Worktree Management Complexity

**Overhead:**
```bash
# Per agent:
git worktree add /path/to/worktrees/IMPL-wave1-A1 -b saw/IMPL/wave1-A1

# Post-merge:
git worktree remove /path/to/worktrees/IMPL-wave1-A1
git branch -D saw/IMPL/wave1-A1

# Cross-repo:
# - Must track worktrees in multiple repositories
# - Cleanup can fail (stale locks, filesystem issues)
# - Disk space: 100MB+ per worktree for large repos
```

**Solo Wave Optimization:** SAW skips worktree creation for single-agent waves, executes directly on branch.

**Formic's Advantage:** No worktrees, no cleanup, agents work directly in main workspace.

---

### 5.5 Hook Dependency (Claude Code Specific)

**Limitation:** E43 enforcement requires Claude Code lifecycle hooks

```yaml
# Hooks that don't transfer to other platforms:
- PreToolUse (check_wave_ownership, validate_agent_launch)
- PostToolUse (check_branch_drift, check_git_ownership)
- SubagentStop (validate_agent_completion, verify_worktree_compliance)

# Other platforms must:
# - Implement equivalent tool-boundary enforcement, OR
# - Rely on SDK middleware (Layer 3), OR
# - Rely on agent self-discipline (Field 0 self-verification)
```

**Formic's Advantage:** Platform-agnostic. Works with any agent CLI (claude, copilot).

---

## 6. Borrowable Ideas (SAW ← Formic)

### 6.1 Memory System (Hippocampus)

**What:** Automatic learning extraction and context injection

**Formic's Implementation:**
```typescript
// After task completion:
1. Reflection step: Agent extracts patterns/pitfalls/preferences
2. Store in memory.json with relevance_tags (file paths, keywords)
3. Auto-inject matching memories into future task contexts

// Example memory:
{
  "type": "pitfall",
  "content": "ESM imports require .js extension even for .ts source files",
  "relevance_tags": ["typescript", "esm", "imports"],
  "source_task": "t-42"
}
```

**How SAW Could Adopt:**
```yaml
# New execution rule: E46: Agent Memory System
# 1. Add memory/ directory to .saw/
# 2. After wave completion, Critic extracts learnings via structured prompt
# 3. Store memories as YAML files keyed by relevance_tags
# 4. Inject matching memories into agent briefs via H5 pre-launch analysis

# Example:
# docs/IMPL/authentication.yml wave 1 completes
# → Critic extracts: "JWT token expiry must be configurable per environment"
# → Store: .saw/memory/jwt-patterns.yml
# → Future IMPL with "jwt" tag gets memory auto-injected
```

**Benefit:** Self-improving system without human curation of CONTEXT.md.

---

### 6.2 Conversational Task Creation

**What:** AI Task Manager with codebase-aware task optimization

**Formic's Implementation:**
```typescript
// POST /api/chat
// Input: "Add user profile editing with avatar upload"
// Output: Task with:
//   - Optimized prompt (includes file references, patterns, guidelines)
//   - Appropriate priority suggestion
//   - Context-rich description

// Agent analyzes:
// - Existing components (Settings.tsx, UserProfile.tsx)
// - API patterns (REST endpoints in routes/users.ts)
// - Data models (User schema in models/user.ts)
```

**How SAW Could Adopt:**
```bash
# New skill: /saw describe "add user profile editing"
# → Launches a "description agent" that:
#   1. Analyzes codebase for related files
#   2. Generates initial feature description (like REQUIREMENTS.md from E39 interview)
#   3. Suggests affected areas, complexity estimate
#   4. User reviews, refines, then launches Scout with enriched description

# Reduces "cold start" cost of Scout by providing better input
```

**Benefit:** Lowers barrier to entry, improves Scout input quality.

---

### 6.3 Self-Healing Fix Task Creation

**What:** Automatic Fix task generation on verification failure

**Formic's Implementation:**
```typescript
// Verify fails (npm test fails):
1. Capture stderr (last 100 lines)
2. Create Fix task:
   - Title: "Fix: [original task title]"
   - Context: "Verification failed with:\n```\n[error snippet]\n```"
   - Priority: HIGH
   - Type: QUICK (skips brief/plan)
   - fixForTaskId: [original task]
3. Auto-queue Fix task
4. Re-queue original task (retryCount++)
5. After 3 failures → Kill switch (revert to safe-point, pause queue)
```

**How SAW Could Adopt:**
```yaml
# E19.1 extension: reactions: with auto_fix strategy
# When E21 gate fails:
1. Check reactions: block for failure_type: build
2. If action: auto_fix:
   - Extract build errors via H7 diagnose-build-failure
   - Create mini-IMPL (single-agent Wave 1) targeting broken files
   - Agent brief: "Fix build errors: [error classification]"
   - Retry count tracked in original IMPL
3. After max_attempts exceeded → escalate to human

# Benefits: Faster recovery, less orchestrator intervention
```

**Benefit:** Reduces human-in-the-loop for transient failures, faster iteration.

---

### 6.4 Priority-Based Queue Reordering

**What:** Dynamic task prioritization with dependency-aware scoring

**Formic's Implementation:**
```typescript
// prioritizer.ts: 4-tier scoring system
1. Fix bonus: +1000 if fixForTaskId is set
2. Unblocking score: +100 per transitively blocked task
   - BFS over reverse dependency graph
   - Counts tasks that become runnable once this task completes
3. Manual priority: high=+30, medium=+20, low=+10
4. FIFO age bonus: +min(ageMs/1000, 10)

// Result: Critical path tasks execute first, maximizing throughput
```

**How SAW Could Adopt:**
```bash
# Current: Wave dependencies via Scout-assigned wave numbers (static)
# New: sawtools reorder-wave <impl-doc> --wave N
# → Analyzes agent dependencies within wave
# → Suggests optimal agent launch order (critical path depth scheduling)
# → Already planned as future feature per POSITION.md "agent launch prioritization"

# Also: PROGRAM tier reordering
# → prioritizeQueue() equivalent for IMPLs in same tier
# → Score by: unblocking potential, tier gate criticality, cross-IMPL dependencies
```

**Benefit:** Better resource utilization, faster completion times.

---

### 6.5 Lease Preemption

**What:** High-priority tasks can preempt low-priority lease holders

**Formic's Implementation:**
```typescript
// Task A (LOW priority) holds lease on file X
// Task B (HIGH priority) needs file X
// Preemption:
1. Watchdog detects conflict
2. Compare priorities: HIGH > LOW
3. Send SIGTERM to Task A → graceful shutdown
4. Release Task A's leases
5. Grant lease to Task B
6. Re-queue Task A (yieldCount++)

// Prevents starvation of high-priority work
```

**How SAW Could Adopt:**
```yaml
# E47: Wave Agent Preemption
# Scenario: Wave 1 agent A1 (implementing feature)
#           Wave 1 agent A2 (fixing critical bug, priority: HIGH)
# → If A2 depends on completing first (file dependencies), orchestrator can:
#   1. Pause A1 (send signal via agent session API)
#   2. Wait for A1 to checkpoint (commit in-progress work)
#   3. Resume A2
#   4. Resume A1 after A2 completes

# Requires: Agent checkpoint/resume protocol (not yet implemented)
```

**Benefit:** Unblocks urgent work, prevents low-priority tasks from blocking high-priority ones.

---

## 7. Borrowable Ideas (Formic ← SAW)

### 7.1 Interface Contract System (I2 + Scaffold Agent)

**What:** Explicit interface specification before parallel implementation

**SAW's Implementation:**
```yaml
# IMPL doc scaffolds section:
scaffolds:
  - file: "pkg/types/preview.go"
    type: "struct"
    agents: ["A1", "A3"]  # Multiple agents reference this type
    status: "committed"
    commit_sha: "abc123"

# Workflow:
1. Scout detects shared data structures (E45)
2. Human reviews interface contracts
3. Scaffold Agent materializes as source files
4. Worktrees branch from scaffolded HEAD (I2 freeze enforcement)
```

**How Formic Could Adopt:**
```typescript
// New workflow phase: SCAFFOLD (between PLAN and DECLARE)
1. After PLAN, detect shared types:
   - Parse subtasks.json for import statements
   - Identify types referenced by 2+ tasks in same goal
2. Create scaffold tasks:
   - Title: "Scaffold: [type name]"
   - Priority: CRITICAL (blocks dependent tasks)
   - Type: QUICK
3. Execute scaffolds first (before dependent tasks can start)
4. Dependent tasks declare dependsOn: [scaffold-task-id]
5. DAG ensures scaffolds complete before consumers

// Benefits:
// - Eliminates duplicate type definitions
// - Prevents merge conflicts on shared interfaces
```

**Benefit:** Reduces integration failures, clearer contracts.

---

### 7.2 Pre-Launch Ownership Validation (E3 + I1)

**What:** Validate disjoint file ownership BEFORE agents launch

**SAW's Implementation:**
```go
// pkg/protocol/ownership.go
func ValidateOwnership(agents []Agent) error {
    ownershipMap := make(map[string]string)  // file → agentID
    for _, agent := range agents {
        for _, file := range agent.Files {
            if existingOwner, exists := ownershipMap[file]; exists {
                return fmt.Errorf("I1 violation: %s owned by both %s and %s",
                    file, existingOwner, agent.ID)
            }
            ownershipMap[file] = agent.ID
        }
    }
    return nil
}
```

**How Formic Could Adopt:**
```typescript
// New step after DECLARE: VALIDATE
1. All tasks in same goal complete DECLARE
2. Build ownership map: filePath → [taskId1, taskId2, ...]
3. Check for conflicts:
   - If 2+ tasks declare EXCLUSIVE on same file → ERROR (halt, ask human to revise)
   - If task declares EXCLUSIVE on file with existing SHARED lease → WARN
4. Only proceed to EXECUTE if validation passes

// Benefits:
// - Catch conflicts upfront (before wasted compute)
// - Human can revise task decomposition before execution
```

**Benefit:** Prevents wasted work, forces better task decomposition.

---

### 7.3 Worktree Isolation (E4 + E43)

**What:** Git worktrees with hook-based boundary enforcement

**SAW's Implementation:**
```bash
# Per agent:
git worktree add /path/to/worktrees/IMPL-wave1-A1 -b saw/IMPL/wave1-A1

# E43 hooks enforce isolation:
# - inject_bash_cd (PreToolUse:Bash): Prepends "cd $SAW_AGENT_WORKTREE &&" to every bash command
# - validate_write_paths (PreToolUse:Write/Edit): Blocks relative paths, out-of-bounds writes
# - verify_worktree_compliance (SubagentStop): Audit trail for post-hoc analysis

# Benefits:
# - Agents cannot see each other's uncommitted work
# - No risk of mid-execution file conflicts
# - Clean separation: main branch = verified, worktree = in-progress
```

**How Formic Could Adopt:**
```typescript
// Hybrid approach (worktrees + leases):
1. For EXCLUSIVE file leases:
   - Create git worktree per task: .formic/worktrees/{task-id}
   - Agent executes in isolated worktree
   - Post-completion: merge worktree → main (conflict-free guaranteed)
2. For SHARED file leases:
   - Keep current optimistic concurrency
   - Collision detection catches conflicts post-execution

// Benefits:
// - Eliminates race conditions on exclusive files
// - Maintains flexibility for shared-file workflows
// - Cleaner merge history (no manual conflict resolution)
```

**Benefit:** Stronger isolation guarantees, prevents entire class of conflicts.

---

### 7.4 Quality Gate System (E21 + E21A + E38)

**What:** Declarative gates with caching and multi-phase execution

**SAW's Implementation:**
```yaml
# Per-IMPL quality_gates (populated by M4):
quality_gates:
  pre_merge:
    - command: "go test ./..."
      type: test
    - command: "golangci-lint run"
      type: lint
  post_merge:
    - command: "go build ./cmd/sawtools"
      type: build
    - command: "./scripts/integration-test.sh"
      type: integration

# Execution:
# - E21A: Baseline verification (before wave 1) → ensures clean state
# - E21: Post-wave verification (after each wave) → catches regressions
# - E38: Gate result caching (5-min TTL) → avoids redundant re-runs
```

**How Formic Could Adopt:**
```typescript
// New: quality_gates in task metadata
// Generated during PLAN phase:
task.qualityGates = {
  pre_execute: [
    { command: "npm run lint", type: "lint" },
    { command: "npm run type-check", type: "type" }
  ],
  post_execute: [
    { command: "npm test", type: "test" },
    { command: "npm run build", type: "build" }
  ]
}

// Cache results: hash(command + git-diff-stat) → result + timestamp
// Reuse if cache hit within 5 minutes

// Benefits:
// - Per-task gate customization (docs tasks skip build, code tasks run full suite)
// - Faster feedback (cached gates skip redundant work)
// - Baseline verification (catch pre-existing failures before task starts)
```

**Benefit:** Better quality enforcement, faster verification cycles.

---

### 7.5 IMPL Doc as Git-Tracked State

**What:** Version-controlled execution state with audit trail

**SAW's Implementation:**
```yaml
# docs/IMPL/authentication.yml (git-tracked YAML)
feature: "User Authentication"
status: "SAW:IN_PROGRESS:WAVE1"
agents:
  - id: A1
    files: [src/auth/service.ts]
    status: complete
    completion_report:
      status: complete
      commit: abc123
      files_changed: [src/auth/service.ts]

# Benefits:
# - Time-travel debugging (git log docs/IMPL/)
# - Distributed coordination (agents read IMPL doc from git)
# - Audit trail (who changed what, when, why)
```

**How Formic Could Adopt:**
```typescript
// Replace JSON board.json with git-tracked YAML:
// .formic/tasks/{task-id}.yml (one file per task)

// Workflow:
1. Task created → Write .formic/tasks/t-42.yml
2. Git commit: "Add task: Implement user auth"
3. Task status changes → Update YAML, git commit
4. Completion → Final commit with completion report inline

// Benefits:
// - Full history of task lifecycle
// - Better multi-developer coordination (git merge handles concurrent updates)
// - Easy to revert bad task decompositions
```

**Benefit:** Better audit trail, distributed coordination, version control integration.

---

## 8. Architecture Comparison Table

| Feature | Formic | SAW |
|---------|--------|-----|
| **Setup Time** | 2 minutes (npm install + start) | 15-30 minutes (sawtools + hooks + protocol learning) |
| **Planning Phase** | Optional (brief/plan skills, can skip) | Mandatory (Scout + human review) |
| **Conflict Prevention** | Reactive (leases + collision detection) | Proactive (I1 disjoint ownership, 4-layer enforcement) |
| **Isolation** | None (same workspace, leases) | Git worktrees + E43 hook enforcement |
| **Interface Contracts** | Implicit (agent discovery) | Explicit (I2 Scaffold Agent) |
| **Quality Gates** | Single global verify command | Per-IMPL declarative gates (pre/post merge, cached) |
| **Cross-Repo Support** | No | Yes (cross-repo IMPLs, coordinated merges) |
| **Dependency Model** | Task DAG (Kahn's algorithm) | Wave sequencing + PROGRAM tiers |
| **Self-Healing** | Automatic Fix task creation (3 retries + kill switch) | E19 reactions block (custom per-IMPL) |
| **Memory System** | Auto-reflection + memory.json | Human-curated CONTEXT.md |
| **Multi-Agent Runtime** | Claude Code CLI, GitHub Copilot CLI | Anthropic API, Bedrock, OpenAI-compatible, CLI |
| **Mobile UI** | Yes (PWA, touch-optimized) | No (desktop browser only) |
| **Protocol Spec** | None (implementation-defined behavior) | 22 invariants/rules, 42K lines of spec + implementation |
| **State Storage** | JSON file (board.json) | Git-tracked YAML (IMPL doc) |
| **Observability** | WebSocket logs, task status | E40 event schema (cost, performance, activity), SSE streaming |
| **Total Codebase Size** | ~10,000 lines TypeScript | ~80,000 lines (protocol + Go SDK + web) |

---

## 9. Use Case Recommendations

### Choose Formic If:
1. **Solo developer or small team (2-4 people)**
   - Quick onboarding, minimal setup
   - Conversational task creation
   - Mobile-first UI for on-the-go monitoring

2. **Rapid prototyping / MVPs**
   - No upfront planning overhead
   - Quick tasks execute immediately
   - Self-healing handles mistakes

3. **Single repository**
   - No need for cross-repo coordination
   - Simple project structure
   - Monorepo or small multi-package setup

4. **Exploratory work**
   - Goal decomposition with DAG dependencies
   - Iterative refinement (retries, fixes)
   - Memory system learns patterns over time

5. **Shared-file workloads**
   - Multiple tasks touching same configuration files
   - Optimistic concurrency acceptable
   - Manual merge resolution when conflicts occur

---

### Choose SAW If:
1. **Production-critical systems**
   - Formal protocol with correctness guarantees
   - 4-layer I1 enforcement prevents conflicts
   - Audit trail via git-tracked IMPL docs

2. **Large-scale parallelization (5+ agents)**
   - Wave-based execution maximizes concurrency
   - Wave solver optimizes wave assignments
   - Post-wave verification catches regressions

3. **Multi-repository systems**
   - Cross-repo IMPLs with coordinated merges
   - Per-repo quality gate verification
   - Cross-repo ownership tracking

4. **Distributed teams**
   - Provider-agnostic (any LLM backend)
   - Per-role model configuration (Opus for planning, Sonnet for execution)
   - Git-native state = no central server

5. **Compliance/audit requirements**
   - Protocol-driven correctness (I1-I6 invariants)
   - Observability event schema (E40)
   - Lifecycle hooks (E43) enforce boundaries

6. **Complex integration scenarios**
   - E25/E26 wiring system
   - Integration Agent restricted to connector files
   - AST-based export scanning

---

## 10. Hybrid Approach (Best of Both Worlds)

### Proposed: "SAW Lite" Mode

**Concept:** Combine Formic's DX with SAW's correctness guarantees

```yaml
# New SAW execution mode: --lite
sawtools scout "add feature" --lite
# → Skips human review checkpoint (auto-approve Scout IMPL)
# → Skips worktree creation (execute directly on branch, like solo wave optimization)
# → Keeps I1 validation (reject if agents share files)
# → Keeps E43 ownership enforcement hooks

# Benefits:
# - Faster iteration (no worktrees, no review)
# - Stronger guarantees than Formic (I1 enforced)
# - Simpler than full SAW (no PROGRAM layer, no multi-wave complexity)

# Use case: Small features (1-2 agents), solo developers, rapid prototyping
```

---

### Proposed: "Formic Pro" Mode

**Concept:** Add SAW's structural prevention to Formic

```typescript
// New: strict_mode in settings
{
  "strict_mode": true,
  "enforce_disjoint_ownership": true,
  "require_scaffolds": true
}

// Behavior changes:
1. Pre-launch ownership validation (E3 equivalent)
   - Reject task if declares EXCLUSIVE on already-leased file
2. Interface scaffolding (I2 equivalent)
   - Detect shared types during PLAN
   - Create scaffold tasks (CRITICAL priority)
3. Worktree isolation (E4 equivalent, opt-in)
   - For tasks with EXCLUSIVE leases, use git worktrees
   - Merge back to main on completion

// Benefits:
// - Stronger guarantees (closer to SAW's I1/I2)
// - Opt-in (backwards compatible)
// - Keeps Formic's DX (conversational task creation, mobile UI)
```

---

## 11. Conclusion

### Summary of Tradeoffs

**Formic = Speed & Simplicity**
- Optimistic concurrency: "Move fast, detect conflicts late, self-heal when needed"
- Best for: Solo devs, rapid prototyping, exploratory work, mobile-first workflows
- Weakness: No formal correctness guarantees, manual conflict resolution required

**SAW = Correctness & Scale**
- Preventive isolation: "Plan first, prevent conflicts by construction, verify at boundaries"
- Best for: Production systems, large-scale parallelization, distributed teams, audit trails
- Weakness: Heavyweight setup, rigid planning phase, complex protocol

### Final Recommendation

**For new users:**
- Start with Formic to learn parallel agent patterns
- Graduate to SAW when hitting Formic's limitations (cross-repo, correctness requirements)

**For production use:**
- Use SAW for critical features (authentication, payments, security)
- Use Formic for internal tools, prototypes, experiments

**For open-source projects:**
- SAW's protocol-driven approach is better for community contributions (clear contracts, audit trails)
- Formic's mobile UI is better for maintainer ergonomics (manage work from phone)

---

## 12. Action Items for SAW Team

### High-Priority Borrowable Ideas

1. **Memory System (E46)** — Automatic learning extraction, 1-2 week implementation
2. **Conversational Task Creation** — `/saw describe` skill, enriches Scout input, 3-5 days
3. **Self-Healing Fix Task** — E19.1 auto_fix strategy, reduces orchestrator load, 1 week
4. **Priority-Based Reordering** — Already planned, critical path scheduling, 3-5 days

### Medium-Priority Borrowable Ideas

5. **Lease Preemption (E47)** — Requires agent checkpoint/resume protocol, 2-3 weeks
6. **SAW Lite Mode** — Skip review, skip worktrees, keep I1/E43, 1 week

### Low-Priority / Research

7. **Mobile UI** — Desktop-first is fine for current users, revisit if mobile demand grows
8. **Hybrid Worktree Mode** — Complexity doesn't justify benefit, keep full worktree isolation

---

**Document Version:** 1.0
**Last Updated:** 2026-03-28
**Analyzed By:** Claude (Sonnet 4.5)
**Analysis Duration:** ~45 minutes (deep codebase exploration)
