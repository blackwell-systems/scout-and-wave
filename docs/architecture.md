# Scout-and-Wave Architecture

## System Overview

Scout-and-Wave is a protocol for parallel agent coordination in software development. It decomposes feature work into independent units with disjoint file ownership, enabling concurrent implementation by multiple AI agents.

```
┌─────────────────────────────────────────────────────────────────┐
│ Orchestrator (synchronous, /saw skill in Claude Code)          │
│ • Launches Scout/Scaffold/Wave/Integration/Critic agents       │
│ • Enforces invariants (I1-I6)                                  │
│ • Manages wave lifecycle                                       │
│ • Does NOT perform analysis or implementation itself           │
└─────────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ Scout Agent    │  │ Scaffold Agent │  │ Wave Agents    │
│ (async)        │  │ (async)        │  │ (async)        │
│ • Analyzes     │  │ • Creates type │  │ • Implement    │
│   codebase     │  │   scaffolds    │  │   features     │
│ • Writes IMPL  │  │ • Commits to   │  │ • Run tests    │
│   manifest     │  │   main branch  │  │ • Write to     │
└────────────────┘  └────────────────┘  │   worktrees    │
         │                              └────────────────┘
         │ (after E16 validation)            │ (parallel)
         ▼                             ┌────┴────┐
┌────────────────┐                     ▼         ▼
│ Critic Agent   │                Agent A    Agent B
│ (async, E37)   │                (wave1)    (wave1)
│ • Reviews IMPL │                     │
│   briefs vs    │                     ▼ (after merge)
│   codebase     │           ┌──────────────────┐
│ • Writes       │           │ Integration Agent │
│   CriticResult │           │ (async, serial)   │
│ • Never edits  │           │ • Wires exports   │
│   source files │           │   into callers    │
└────────────────┘           │ • Runs on main    │
                             └──────────────────┘
```

## Agent Types

Scout-and-Wave coordinates seven asynchronous agent roles plus the synchronous Orchestrator. Each type has mechanically enforced boundaries; a model prompted to violate its role is blocked before the tool executes.

| Agent Type | Subagent Tag | Role | Tool Access |
|------------|-------------|------|-------------|
| **Scout** | `scout` | Analyzes codebase, produces IMPL manifest with file ownership and interface contracts | Read, Glob, Grep, Bash (no Write/Edit on source files) |
| **Scaffold Agent** | `scaffold-agent` | Materializes shared type stubs as committed source files before Wave 1 | Read, Write, Edit, Bash |
| **Wave Agent** | `wave-agent` | Implements assigned files in an isolated git worktree | Read, Write, Edit, Bash, Glob, Grep |
| **Critic Agent** | `critic-agent` | Reviews IMPL doc agent briefs against the actual codebase (E37); never modifies source files | Read, Glob, Grep, Bash |
| **Integration Agent** | `integration-agent` | Wires new exports into caller code post-merge; restricted to `integration_connectors` files. Also serves as hotfix agent for between-wave caller cascade fixes (E47). | Read, Write, Edit, Bash |
| **Planner** | `planner` | Decomposes a program into features, assigns tiers, produces PROGRAM manifest | Read, Glob, Grep, Bash |

### Critic Agent (E37)

The Critic Agent is a pre-wave quality gate that runs **after E16 IMPL validation** and **before the REVIEWED state**. It is auto-triggered when wave 1 has 3 or more agents, or when `file_ownership` contains entries from 2 or more repos. It can be suppressed with `--no-critic`.

**What it does:**

1. Reads the full IMPL manifest (all agent briefs, interface contracts, file ownership table)
2. For each agent brief, reads every source file in that agent's ownership list
3. Runs 10 verification checks against the actual codebase:
   - Check 1 (`file_existence`): `action=modify` files must exist; `action=new` files must not
   - Check 2 (`symbol_accuracy`): Function/type/method names in briefs must exist as stated
   - Check 3 (`pattern_accuracy`): Implementation patterns described must match actual source patterns
   - Check 4 (`interface_consistency`): Interface contracts must be syntactically valid and consistent with source types
   - Check 5 (`import_chains`): All packages referenced in interface contracts must be importable
   - Check 6 (`side_effect_completeness`): New exported symbols that require registration (CLI commands, HTTP routes, React components) must have their registration file in `file_ownership`
   - Check 7 (`complexity_balance`): Warning if any agent owns >8 files or >40% of total IMPL files
   - Check 8 (`caller_exhaustiveness`): All callers of changed symbols must be in `file_ownership`; uses `sawtools check-callers` to enumerate call sites
   - Check 9 (`i1_disjoint_ownership`): Validates `file_ownership` table for I1 violations before worktrees are created
   - Check 10 (`result_code_semantics`): Verifies correct `result.Result[T]` usage in agent briefs
4. Writes a structured `CriticResult` to the IMPL doc's `critic_report` field via `sawtools set-critic-review`
5. Emits overall verdict: `PASS` (all agents pass, or only warnings present) or `ISSUES` (one or more agents have errors)

**Enforcement:** `prepare-wave` checks the critic verdict before creating worktrees. Verdict `ISSUES` blocks worktree creation with exit code 1. Verdict `PASS` (including warning-only) proceeds.

**What it does NOT do:** The Critic Agent never modifies source files or fixes briefs. It verifies accuracy only. Brief corrections are applied by the Orchestrator or human after reviewing the `CriticResult` summary; the critic is then re-run until verdict is `PASS`.

**CLI note (Claude Code sessions):** In CLI orchestration mode, the Orchestrator uses `Agent(subagent_type=critic-agent, ...)` rather than `sawtools run-critic`. The `sawtools run-critic` command is only valid for programmatic/API orchestration outside of a Claude Code session.

See E37 in `protocol/execution-rules.md` for full specification.

## Core Components

### 1. IMPL Manifest

The single source of truth for feature decomposition. Written by Scout, consumed by all agents.

**Location:** `docs/IMPL/IMPL-<feature-slug>.yaml`

**Key sections:**
- File ownership table (I1: disjoint file ownership)
- Interface contracts (I2: contracts precede implementation)
- Wave structure (I3: sequential wave execution)
- Scaffolds (type/interface definitions)
- Quality gates (build, test, lint requirements)

**Format:** YAML manifest with typed structured sections (fenced blocks with `type=impl-*` attributes).

### 2. Git Worktree Isolation

Each Wave agent operates in an isolated git worktree with its own branch. No shared state, no merge conflicts during implementation.

**Structure:**
```
repo/
├── .git/                     # Main git directory
├── main branch files...
└── .claude/
    └── worktrees/
        └── saw/
            └── {slug}/
                ├── wave1-agent-A/    # Isolated worktree
                │   ├── .git -> ...   # Links to main .git
                │   └── [files]       # Agent A's workspace
                └── wave1-agent-B/    # Isolated worktree
                    ├── .git -> ...
                    └── [files]       # Agent B's workspace
```

**Benefits:**
- Agents cannot interfere with each other's work
- Each agent has full git history and can commit independently
- Merge happens after all agents complete (I3: wave sequencing)

**E43 Hook-Based Enforcement (v0.65.0+):**

In Claude Code implementations, worktree isolation is enforced mechanically via six lifecycle hooks rather than relying on agent cooperation:

1. **SubagentStart: Environment injection** — Sets `SAW_AGENT_WORKTREE`, `SAW_AGENT_ID`, `SAW_WAVE_NUMBER`, `SAW_IMPL_PATH`, `SAW_BRANCH` when wave agents launch
2. **SubagentStart: Worktree isolation validation** (`validate_worktree_isolation`) — Two-phase check: Phase 1 validates pwd+branch pattern; Phase 2 verifies exact branch via `.saw-agent-brief.md` frontmatter
3. **PreToolUse:Bash: CD auto-injection** — Prepends `cd $SAW_AGENT_WORKTREE &&` to every bash command, ensuring commands run in the correct working directory automatically
4. **PreToolUse:Write/Edit: Path validation** — Blocks relative paths and paths outside worktree boundaries at the tool boundary (exit 2), preventing the "Agent B leak" scenario where files are created in the main repo instead of the worktree
5. **SubagentStop: Compliance verification** — Checks completion report exists and commits exist on branch, creating an audit trail for post-hoc violation analysis
6. **Stop: Orchestrator stop warning** (`saw_orchestrator_stop`) — Warns when the session ends with an active IMPL in WAVE_PENDING or WAVE_EXECUTING state, or with active worktrees present. Non-blocking (exit 0 always); uses `stop_hook_active` to prevent re-trigger loops.

This defense-in-depth approach makes isolation violations impossible at the tool boundary rather than merely detected after merge. Other implementations must provide equivalent enforcement at their tool invocation boundary or fall back to instruction-based isolation (Field 0 self-verification).

See E43 in `protocol/execution-rules.md` for full specification.

### 3. Protocol SDK (sawtools CLI)

The `sawtools` binary provides 75+ commands covering all protocol operations. Key commands include:

**Batching commands (atomic multi-step workflows):**
- `run-scout` — Launch Scout, validate IMPL, auto-correct IDs, finalize gates
- `prepare-wave` — Check deps, create worktrees, extract briefs, init journals, verify hooks
- `finalize-wave` — Verify commits, scan stubs, run gates, merge, verify build, apply cascade hotfix (E47), cleanup; supports `--dry-run` flag
- `finalize-impl` — Validate, populate gates, re-validate
- `run-wave` — Fully automated wave execution

**Worktree operations:**
- `create-worktrees` — Create isolated worktrees for a wave
- `cleanup` / `cleanup-stale` — Remove worktrees after merge
- `verify-isolation` — Check agent is in correct worktree

**IMPL management:**
- `list-impls` — Discover IMPL docs
- `validate` — E16 manifest validation
- `extract-context` — E23 per-agent context extraction
- `update-status` / `set-impl-state` — Agent and IMPL status tracking
- `mark-complete` / `set-completion` — E15 completion marker
- `amend-impl` / `check-impl-conflicts` — IMPL modification and conflict detection

**Quality assurance:**
- `scan-stubs` / `detect-scaffolds` / `validate-scaffolds` — E20 stub and scaffold detection
- `run-gates` / `tier-gate` — E21 quality gate verification
- `check-conflicts` / `check-type-collisions` — I1 ownership and type collision detection
- `run-critic` / `set-critic-review` / `set-critic-verdict` / `run-review` — Code review system

**Program layer (multi-IMPL coordination):**
- `create-program` / `list-programs` / `program-status` — Program lifecycle
- `program-execute` / `program-replan` — Program execution and replanning
- `finalize-tier` / `mark-program-complete` — Program completion
- `freeze-contracts` / `freeze-check` — Contract management
- `check-program-conflicts` / `validate-program` — Program validation
- `import-impls` — Import existing IMPLs into a program

**Agent and execution:**
- `prepare-agent` / `update-agent-prompt` — Agent setup
- `interview` — E39 requirements gathering mode
- `retry` / `build-retry-context` / `diagnose-build-failure` — Failure recovery
- `resume-detect` — Session resumption detection
- `daemon` — Continuous queue-processing daemon

**Analysis and utilities:**
- `analyze-deps` / `check-deps` / `detect-cascades` — Dependency analysis (`analyze-deps` is a thin CLI wrapper over `BuildGraph` + `ToOutput`; the `AnalyzeDeps` Go function was deleted and replaced by `BuildGraph(ctx, repoRoot, files)` + `ToOutput(graph)`)
- `analyze-suitability` — Codebase suitability assessment
- `assign-agent-ids` / `extract-commands` — IMPL utilities
- `journal-init` / `journal-context` — Journal management
- `metrics` / `query` / `solve` — Metrics, queries, and dependency solving
- `verify-hook-installed` / `verify-install` — Installation verification
- `update-context` — E18 project memory update

Run `sawtools --help` for the complete command list.

See `protocol/execution-rules.md` for detailed command specifications.

### 4. Interface Contracts

All cross-agent dependencies are defined as interface contracts in the IMPL manifest before parallel work begins.

**Scaffold Agent creates:**
- Type definitions (structs, interfaces, enums)
- Function signatures (no implementation, just signatures)
- Package documentation

**Committed to main branch** before Wave 1 launches. This enforces I2: interface contracts precede parallel implementation.

**Interface freeze:** When `create-worktrees` runs, contracts become immutable. Any interface change after this point requires recreating all worktrees.

### 5. Tool Journaling Subsystem

External observer pattern that preserves agent execution context across Claude Code's context window compaction events.

```
┌──────────────────────────────────────────────────────────────┐
│ Claude Code Session (wave1-agent-A)                         │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Agent executes tools:                                    │ │
│ │ • Read, Write, Edit, Bash                               │ │
│ │ • Context compaction erases history after ~45 min      │ │
│ └──────────────────────────────────────────────────────────┘ │
│                     │                                         │
│                     │ logs to                                 │
│                     ▼                                         │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ .claude/sessions/1a2b3c4d.jsonl                          │ │
│ │ (Claude Code's internal session log)                    │ │
│ └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                      │
                      │ tailed by (external observer)
                      ▼
┌──────────────────────────────────────────────────────────────┐
│ JournalObserver (pkg/journal/)                               │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ .saw-state/wave1/agent-A/                                │ │
│ │ ├── cursor.json      (read position)                     │ │
│ │ ├── index.jsonl      (tool execution history)            │ │
│ │ ├── context.md       (generated on-demand summary)       │ │
│ │ ├── recent.json      (last 30 entries)                   │ │
│ │ └── tool-results/    (full tool outputs)                 │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                               │
│ Methods:                                                      │
│ • Sync() - Update index from session log                     │
│ • GenerateContext() - Create markdown summary                │
│ • Checkpoint(name) - Create named snapshot                   │
│ • Archive() - Compress after merge                           │
└──────────────────────────────────────────────────────────────┘
                      │
                      │ generates
                      ▼
┌──────────────────────────────────────────────────────────────┐
│ Agent Prompt (before launch)                                 │
│                                                               │
│ ## Prior Work                                                │
│ You have already modified:                                   │
│ - pkg/journal/observer.go (created)                          │
│                                                               │
│ Test results:                                                │
│ - TestSync: PASS                                             │
│                                                               │
│ [Agent's full brief follows...]                              │
└──────────────────────────────────────────────────────────────┘
```

**Why it exists:** Long-running agents (45+ minutes) hit context compaction, losing memory of prior work. The journal system preserves execution history externally and injects it as context before agent launch.

**Key properties:**
- External observer (no Claude Code modifications)
- Automatic recovery (orchestrator loads journal before agent launch)
- Checkpoint system (named snapshots at milestones)
- Archive policy (compressed after merge, 30-day retention)

**Components:**
- `pkg/journal/observer.go` — Core observer (tail session log, extract tools)
- `pkg/journal/context.go` — Context generator (analyze history, produce markdown)
- `pkg/journal/checkpoint.go` — Checkpoint manager (create/restore snapshots)
- `pkg/journal/archive.go` — Archive policy (compress, retain, cleanup)
- `cmd/sawtools/debug_journal.go` — CLI for debugging failed agents

**Integration points:**
- `prepare-wave` / `prepare-agent`: JSON output includes `journal_context_available` and `journal_context_file` per agent, enabling the orchestrator to prepend journal context to agent prompts
- `launchAgent`: Prepends journal context to the agent's launch prompt when available (restores working memory after compaction or interruption)
- Periodic sync: 30-second goroutine runs during agent execution to keep journals current
- Wave agents: Receive prepended context in prompt (transparent, no agent changes needed)

See [tool-journaling.md](./tool-journaling.md) for full documentation.

## Execution Flow

### Phase 1: Scout

1. User invokes `/saw scout <feature-description>` (optionally with `--repo <path>` to target a different repo than the session cwd)
2. Orchestrator launches Scout agent (async, `subagent_type: scout`)
3. Scout analyzes codebase, identifies interfaces, writes IMPL manifest
4. Orchestrator validates IMPL manifest (E16: `sawtools validate`)
5. Orchestrator checks E37 trigger conditions: if wave 1 has 3+ agents or `file_ownership` spans 2+ repos, launches Critic Agent (async, `subagent_type: critic-agent`)
6. Critic reads every brief and owned file, runs 10 verification checks, writes `CriticResult` to IMPL doc; execution blocks if `verdict: ISSUES`
7. User reviews and approves decomposition; IMPL transitions to `REVIEWED` state

### Phase 2: Scaffold (if needed)

1. If IMPL manifest has scaffolds with `Status: pending`:
2. Orchestrator launches Scaffold Agent (async, `subagent_type: scaffold-agent`)
3. Scaffold Agent creates type definitions and commits to main branch
4. User reviews scaffold files
5. Orchestrator verifies all scaffolds show `Status: committed` before proceeding

### Phase 3: Wave Execution Loop

For each wave (1..N):

1. **Worktree creation:**
   - `sawtools create-worktrees` creates isolated worktrees for each agent
   - Enforces interface freeze (I2: no contract changes after this point)

2. **Journal initialization:**
   - Orchestrator creates `JournalObserver` for each agent
   - Syncs from existing session log (if resuming)
   - Generates context summary

3. **Agent launch:**
   - Orchestrator prepends journal context to agent prompt
   - Launches all wave agents in parallel (`run_in_background: true`)
   - Each agent works in its own worktree branch

4. **Journal sync (periodic):**
   - Observer syncs every 30 seconds during execution
   - No re-injection (context is static after launch)

5. **Agent completion:**
   - Agents commit to worktree branches (I5: commit before reporting)
   - Agents write completion reports to IMPL manifest
   - Orchestrator reads completion reports (I4: IMPL doc is source of truth)

6. **Quality gates:**
   - `sawtools scan-stubs` (E20: detect unimplemented stubs)
   - `sawtools run-gates` (E21: verify build/test/lint)

7. **Merge verification:**
   - `sawtools verify-commits` (all agents committed)
   - `sawtools merge-agents` (merge to main with --no-ff)
   - `sawtools verify-build` (post-merge build check)

8. **Journal archiving:**
   - `observer.Archive()` compresses journals
   - Removes worktrees via `sawtools cleanup`

9. **Next wave:**
   - If more waves remain: repeat from step 1
   - If final wave: `sawtools mark-complete` (E15)

### Phase 4: Completion

1. Orchestrator runs `sawtools mark-complete` on IMPL manifest
2. Orchestrator runs `sawtools update-context` (E18: update project memory)
3. IMPL doc is marked `state: COMPLETE`
4. Feature is done

## Invariants

The protocol enforces six core invariants:

**I1: Disjoint File Ownership**
- No two agents in the same wave own the same file
- Checked by `sawtools check-conflicts` before worktree creation
- Violated IMPL docs are rejected at validation time

**I2: Interface Contracts Precede Implementation**
- All cross-agent dependencies defined in IMPL manifest before Wave 1
- Scaffold Agent commits contracts to main branch
- Contracts freeze when worktrees are created (no changes allowed)

**I3: Wave Sequencing**
- Wave N+1 does not launch until Wave N merges successfully
- Post-merge verification must pass before proceeding
- Enforced by orchestrator (not bypassed even in `--auto` mode)

**I4: IMPL Doc is Single Source of Truth**
- Completion reports written to IMPL doc, not chat
- Status updates via `sawtools update-status`
- Orchestrator reads IMPL doc to determine wave state

**I5: Agents Commit Before Reporting**
- Each agent commits to worktree branch before writing completion report
- Orchestrator verifies commits exist via `sawtools verify-commits`
- Missing commits flag protocol deviation

**I6: Role Separation**
- Orchestrator does not perform Scout/Scaffold/Wave work
- All analysis and implementation delegated to async agents
- Orchestrator only manages protocol state transitions

See `protocol/invariants.md` for full specification.

## Error Handling

### Engine Error Pattern (`result.Result[T]`)

All engine functions that can partially succeed use the `result.Result[T]` generic wrapper from `pkg/result`. A `Result[T]` carries a `Status` (`SUCCESS`, `PARTIAL`, or `FATAL`), a typed `Value`, and an `Errors` slice of `SAWError` structs. Each `SAWError` has a structured `Code` (domain-prefixed constant from `pkg/result/codes.go`), a human-readable `Message`, and an optional `Cause`.

The `.Code` field on a `Result` holds the top-level status code (`SUCCESS`/`PARTIAL`/`FATAL`). Domain-specific error codes live in `result.Errors[0].Code`. Agent briefs that compare `.Code` against domain error constants (e.g., `result.Code == V001`) are flagged by Critic Check 10 (`result_code_semantics`).

### Agent Failure Types (E19)

Agents report failure via `failure_type` field in completion report:

- `transient` — Retry automatically (up to 2 times)
- `fixable` — Read agent notes, apply fix, relaunch
- `needs_replan` — Re-engage Scout with agent findings
- `escalate` — Surface to human immediately
- `timeout` — Agent approaching turn limit, stopped cleanly

Orchestrator response:
- `transient`/`fixable` → automatic retry in `--auto` mode
- `needs_replan`/`escalate` → stop and surface to user
- `timeout` → read partial work, decide on manual completion or retry

### Journal Recovery on Failure

When an agent fails mid-wave:

1. Journal preserves full execution history (not lost to compaction)
2. User inspects via `sawtools debug-journal wave<N>/agent-<ID>`
3. User identifies root cause from tool history
4. User reverts worktree to last good commit (if needed)
5. Orchestrator re-launches agent with updated prompt
6. Journal context includes prior attempt (agent learns from failure)

See [tool-journaling.md](./tool-journaling.md) for debugging workflow.

## Directory Structure

```
repo/
├── .git/                           # Main git directory
├── .claude/
│   ├── worktrees/                  # Isolated worktrees (I3)
│   │   └── saw/
│   │       └── {slug}/
│   │           ├── wave1-agent-A/
│   │           └── wave1-agent-B/
│   └── sessions/                   # Claude Code session logs (read by journal)
│       └── 1a2b3c4d.jsonl
├── .saw-state/
│   ├── wave1/                      # Tool execution history
│   │   ├── agent-A/
│   │   │   ├── cursor.json
│   │   │   ├── index.jsonl
│   │   │   ├── recent.json
│   │   │   └── tool-results/
│   │   └── agent-B/
│   └── archives/                   # Compressed journals after merge
│       └── wave1-agent-A.tar.gz
├── docs/
│   ├── IMPL/                       # IMPL manifests (I4)
│   │   └── IMPL-<feature>.yaml
│   └── CONTEXT.md                  # Project memory (E18)
├── saw.config.json                 # Project config (model defaults, quality settings)
└── [source code]
```

## Configuration

Project-local config at `<repo>/saw.config.json` or global default at `~/.claude/saw.config.json`:

```json
{
  "repos": [],
  "repo": {
    "path": ""
  },
  "agent": {
    "scout_model": "claude-sonnet-4-6",
    "wave_model": "claude-sonnet-4-6",
    "chat_model": "claude-sonnet-4-6",
    "critic_model": "claude-sonnet-4-6",
    "integration_model": "claude-sonnet-4-6",
    "scaffold_model": "claude-sonnet-4-6",
    "planner_model": "claude-sonnet-4-6"
  },
  "quality": {
    "require_tests": false,
    "require_lint": false,
    "block_on_failure": false
  },
  "appearance": {
    "theme": "dark"
  }
}
```

## Program Layer (Multi-IMPL Coordination)

The Program manifest system coordinates multiple related IMPLs that together deliver a larger initiative. A Program defines tiers of IMPLs with dependency relationships, enabling ordered execution across features.

**Key concepts:**
- **Program manifest** — YAML file defining tiers, IMPL references, and dependency graph
- **Tiers** — Ordered groups of IMPLs; Tier N+1 waits for Tier N completion
- **Contract freezing** — Cross-IMPL interfaces are frozen before dependent tiers execute
- **Cascade detection** — Identifies when changes in one IMPL affect others

**Tier-gated execution (T-series rules):** The PROGRAM manifest defines tiers with ordered execution. `program-execute` drives the tier loop: for each tier it runs Scouts in parallel (E31), tracks cross-IMPL progress (E32), runs the tier gate (E29), freezes cross-IMPL contracts (E30), and auto-advances in `--auto` mode (E33). Tier N+1 does not launch until tier N's gate verification passes (P3).

**Tier batching commands:**
- `prepare-tier` — Cross-IMPL conflict check (P1+), create IMPL branches (E28B/P5), coordinate worktree creation, return tier readiness
- `finalize-tier` — Tier gate verification (E29), contract freezing (E30), cross-IMPL merge coordination, return tier completion

**Protocol spec:** `protocol/program-invariants.md`, `protocol/program-manifest.md`

**Commands:** `create-program`, `program-execute`, `program-replan`, `program-status`, `list-programs`, `prepare-tier`, `finalize-tier`, `tier-gate`, `freeze-contracts`, `freeze-check`, `check-program-conflicts`, `import-impls`, `mark-program-complete`, `validate-program`

## Protocol State Machine

IMPL manifests track lifecycle state via 12 states (including SCOUT_VALIDATING) with enforced transition guards. Invalid transitions are rejected by `protocol.SetImplState()`.

```
INTERVIEWING ──> SCOUT_PENDING ──> REVIEWED ──> SCAFFOLD_PENDING ──> WAVE_PENDING
                                      │                                    │
                                      v                                    v
                                NOT_SUITABLE                        WAVE_EXECUTING
                                                                          │
                                                                          v
                                                                    WAVE_MERGING
                                                                          │
                                                                          v
                                                                   WAVE_VERIFIED ──> COMPLETE
                                                                          │
                                                                          v
                                                              (next wave: WAVE_EXECUTING)

Any active state ──> BLOCKED (recoverable)
```

**State descriptions:**

| State | Meaning |
|-------|---------|
| `INTERVIEWING` | Requirements-gathering session in progress (E39); transitions to `SCOUT_PENDING` when REQUIREMENTS.md is written |
| `SCOUT_PENDING` | Scout agent is running or IMPL manifest is being written |
| `REVIEWED` | IMPL manifest has passed E16 validation and E37 critic gate; awaiting wave execution approval |
| `SCAFFOLD_PENDING` | Scaffold Agent is materializing shared types; transitions to `WAVE_PENDING` when all scaffolds are `committed` |
| `WAVE_PENDING` | Ready to execute the current wave; worktrees not yet created |
| `WAVE_EXECUTING` | Wave agents are running in their worktrees |
| `WAVE_MERGING` | Agent branches are being merged to main |
| `WAVE_VERIFIED` | Post-merge verification (build, tests, stubs) passed; either advances to next wave or to `COMPLETE` |
| `BLOCKED` | Recoverable error state; requires human intervention before execution can resume |
| `COMPLETE` | All waves merged and verified; IMPL archived |
| `NOT_SUITABLE` | Scout determined the feature is not suitable for parallel execution |

The Program state machine wraps these with 9 program-level states: `PROGRAM_PLANNING`, `PROGRAM_REVIEWED`, `PROGRAM_EXECUTING`, `PROGRAM_TIER_GATE`, `PROGRAM_BLOCKED`, `PROGRAM_REPLANNING`, `PROGRAM_COMPLETE`, `PROGRAM_NOT_SUITABLE`, and `PROGRAM_CONTRACTED`.

## Daemon, Queue, and Autonomy

The system supports continuous automated execution through a daemon loop:

- **Daemon** (`sawtools daemon`) — Long-running process that pulls work from a queue and executes Scout/Wave workflows continuously
- **Queue** — Ordered list of pending work items (features to scout, waves to execute)
- **Autonomy settings** — Controls how much the daemon can do without human approval (e.g., auto-approve scouts, auto-merge waves)

## Interview Mode (E39)

A requirements-gathering pathway that launches an interactive interview session before Scout. The interview agent asks clarifying questions to refine a vague feature request into a well-specified Scout input.

**Command:** `sawtools interview`

## Go Engine Package Structure

The Go engine (`scout-and-wave-go`) contains 40 packages under `pkg/`. Key packages beyond the core:

| Package | Purpose |
|---------|---------|
| `pkg/engine` | High-level Scout, Wave, Scaffold, Chat operations |
| `pkg/protocol` | YAML manifest parsing, validation, extraction |
| `pkg/agent` | Agent execution runtime with tool system and 4 backends (Anthropic API, AWS Bedrock, OpenAI-compatible, Claude CLI) |
| `pkg/journal` | External observer for tool execution history |
| `pkg/orchestrator` | State machine, event publishing, wave management |
| `pkg/types` | Shared type definitions used across all packages |
| `pkg/worktree` | Git worktree creation and management |
| `pkg/suitability` | Codebase suitability analysis and pre-implementation scanning |
| `pkg/analyzer` | Multi-language dependency graph construction; key API: `BuildGraph(ctx, repoRoot, files)` → `*DepGraph`; `CascadeCandidate` is the unified cascade type (`CascadeFile` removed); `DetectCascades`, `DetectWiring` |
| `pkg/solver` | Dependency solver for wave agent assignment (topological sort, Kahn's algorithm) |
| `pkg/observability` | Event emission system (E40) |
| `pkg/queue` | Work queue for daemon mode |
| `pkg/autonomy` | Autonomy level settings and enforcement |
| `pkg/interview` | E39 interview mode implementation |
| `pkg/resume` | Session resumption detection and context recovery |
| `pkg/retry` / `pkg/retryctx` | Failure retry logic and context building |
| `pkg/scaffold` / `pkg/scaffoldval` | Scaffold creation and validation |
| `pkg/result` | Unified `result.Result[T]` generic for consistent error handling; `SUCCESS`/`PARTIAL`/`FATAL` status codes; 280+ named error constants across 20 domains (V/W/B/G/A/N/O/P/T/S/C/K/I/D/E/X/Q/R/J/Z) |
| `pkg/collision` | Type collision detection across agents (AST-based, E41) |
| `pkg/deps` | Dependency conflict detection (lock files: go.mod, Cargo.lock, package-lock.json) |
| `pkg/builddiag` | Build failure diagnosis |
| `pkg/codereview` | LLM-powered diff review (`run-review`); scores diffs across quality dimensions; separate from the E37 critic agent (which is a prompt-based subagent, not an SDK package) |
| `pkg/hooks` | Git hook installation and verification |
| `pkg/pipeline` | Execution pipeline management |
| `pkg/format` | Output formatting |
| `pkg/gatecache` | Quality gate result caching |
| `internal/git` | Low-level git command execution |

## Web Application Architecture

The web application (`scout-and-wave-web`) provides an HTTP/SSE interface for the protocol engine.

**Dependency:** Imports `scout-and-wave-go` via a `replace` directive pointing to the local filesystem in `go.mod`.

**Structure:**
- `pkg/api/` — HTTP route handlers (88 route registrations)
- `pkg/service/` — Service layer between API handlers and engine (`config_service.go`, `impl_service.go`, `wave_service.go`, `scout_service.go`, `program_service.go`, `merge_service.go`)
- `web/` — React frontend (TypeScript)
- `cmd/saw/` — Server binary entry point
- `web/embed.go` — `//go:embed` directive embeds built frontend assets into the Go binary

**Binaries produced:**
- `scout-and-wave-go` produces `sawtools` (CLI toolkit, ~21MB)
- `scout-and-wave-web` produces `saw` (web server with embedded assets, ~24MB)

**Build requirement:** Web assets are embedded at compile time. Any frontend change requires `cd web && npm run build` followed by `go build -o saw ./cmd/saw` to produce an updated binary.

**Key UI components:** `ProgramBoard`, `ProgramDependencyGraph`, `DaemonControl`, `QueuePanel`, `AutonomySettings`, `InterviewLauncher`

**API surface:** REST endpoints under `/api/` covering IMPLs, waves, programs, daemon control, queue management, autonomy settings, and interviews. Server-Sent Events (SSE) provide real-time progress updates during Scout and Wave execution.

## See Also

- [Protocol Invariants](../protocol/invariants.md) — I1-I6 formal specification
- [Protocol Execution Rules](../protocol/execution-rules.md) — E1-E47 orchestrator rules
- [Tool Journaling](./tool-journaling.md) — Compaction safety system
- [Orchestrator Skill](../implementations/claude-code/prompts/saw-skill.md) — /saw command implementation
