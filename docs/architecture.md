# Scout-and-Wave Architecture

## System Overview

Scout-and-Wave is a protocol for parallel agent coordination in software development. It decomposes feature work into independent units with disjoint file ownership, enabling concurrent implementation by multiple AI agents.

```
┌─────────────────────────────────────────────────────────────────┐
│ Orchestrator (synchronous, /saw skill in Claude Code)          │
│ • Launches Scout/Scaffold/Wave/Integration agents              │
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
                                        └────────────────┘
                                             │ (parallel)
                                        ┌────┴────┐
                                        ▼         ▼
                                   Agent A    Agent B
                                   (wave1)    (wave1)
                                        │
                                        ▼ (after merge)
                                  ┌──────────────────┐
                                  │ Integration Agent │
                                  │ (async, serial)   │
                                  │ • Wires exports   │
                                  │   into callers    │
                                  │ • Runs on main    │
                                  └──────────────────┘
```

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

### 3. Protocol SDK (sawtools CLI)

The `sawtools` binary provides all protocol operations:

**Worktree operations:**
- `create-worktrees` — Create isolated worktrees for a wave
- `cleanup` — Remove worktrees after merge
- `verify-isolation` — Check agent is in correct worktree

**Wave execution:**
- `run-wave` — Fully automated wave execution
- `merge-agents` — Merge completed agents to main
- `verify-commits` — Pre-merge commit verification
- `verify-build` — Post-merge build verification

**IMPL management:**
- `list-impls` — Discover IMPL docs
- `validate` — E16 manifest validation
- `extract-context` — E23 per-agent context extraction
- `update-status` — Agent status tracking
- `mark-complete` — E15 completion marker

**Quality assurance:**
- `scan-stubs` — E20 stub detection
- `run-gates` — E21 quality gate verification
- `check-conflicts` — I1 file ownership conflict detection

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
│ │ .saw-state/journals/wave1/agent-A/                       │ │
│ │ ├── cursor.json      (read position)                     │ │
│ │ ├── index.jsonl      (tool execution history)            │ │
│ │ ├── context.md       (generated summary)                 │ │
│ │ ├── recent.jsonl     (last 50 entries)                   │ │
│ │ └── results/         (full tool outputs)                 │ │
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
- `cmd/saw/debug_journal.go` — CLI for debugging failed agents

**Integration points:**
- Orchestrator: `runner.go` calls `observer.Sync()` + `observer.GenerateContext()` before agent launch
- Wave agents: Receive prepended context in prompt (transparent, no agent changes needed)

See [tool-journaling.md](./tool-journaling.md) for full documentation.

## Execution Flow

### Phase 1: Scout

1. User invokes `/saw scout <feature-description>`
2. Orchestrator launches Scout agent (async, `subagent_type: scout`)
3. Scout analyzes codebase, identifies interfaces, writes IMPL manifest
4. Orchestrator validates IMPL manifest (E16: `sawtools validate`)
5. User reviews and approves decomposition

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
│   │   ├── wave1-agent-A/
│   │   └── wave1-agent-B/
│   └── sessions/                   # Claude Code session logs (read by journal)
│       └── 1a2b3c4d.jsonl
├── .saw-state/
│   ├── journals/                   # Tool execution history
│   │   └── wave1/
│   │       ├── agent-A/
│   │       │   ├── index.jsonl
│   │       │   ├── context.md
│   │       │   └── results/
│   │       └── agent-B/
│   └── archives/                   # Compressed journals after merge
│       └── wave1-agent-A.tar.gz
├── docs/
│   ├── IMPL/                       # IMPL manifests (I4)
│   │   └── IMPL-<feature>.yaml
│   └── CONTEXT.md                  # Project memory (E18)
├── saw.config.json                 # Project config (journal settings, model defaults)
└── [source code]
```

## Configuration

Project-local config at `<repo>/saw.config.json` or global default at `~/.claude/saw.config.json`:

```json
{
  "agent": {
    "scout_model": "claude-sonnet-4-5",
    "wave_model": "claude-sonnet-4-5",
    "chat_model": "claude-sonnet-4-5",
    "integration_model": "claude-sonnet-4-5"
  },
  "journal": {
    "enabled": true,
    "retention_days": 30,
    "auto_archive": true,
    "sync_interval_seconds": 30,
    "max_context_entries": 50,
    "max_preview_chars": 800
  },
  "quality_gates": {
    "default_level": "standard",
    "fail_on_stubs": false
  }
}
```

## See Also

- [Protocol Invariants](../protocol/invariants.md) — I1-I6 formal specification
- [Protocol Execution Rules](../protocol/execution-rules.md) — E1-E26 orchestrator rules
- [Tool Journaling](./tool-journaling.md) — Compaction safety system
- [Orchestrator Skill](../implementations/claude-code/prompts/saw-skill.md) — /saw command implementation
