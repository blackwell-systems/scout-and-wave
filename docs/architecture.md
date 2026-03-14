# Scout-and-Wave Architecture

## System Overview

Scout-and-Wave is a protocol for parallel agent coordination in software development. It decomposes feature work into independent units with disjoint file ownership, enabling concurrent implementation by multiple AI agents.

```
┌─────────────────────────────────────────────────────────────────┐
│ Orchestrator (synchronous, /saw skill in Claude Code)          │
│ • Launches Scout/Scaffold/Wave agents                          │
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
```

## Execution Models

Scout-and-Wave supports two distinct execution models, each with different orchestration mechanisms:

### Model 1: CLI Orchestration (LLM-Driven)

**Context:** Inside a Claude Code session with Max plan or AWS Bedrock credentials.

**How it works:**
- Orchestrator (Claude, using `/saw` skill) launches agents via the Agent tool
- Agents inherit parent session credentials (Max plan or Bedrock)
- Orchestrator uses `subagent_type: scout|wave-agent|scaffold-agent` to specify agent role
- Manual worktree flow: orchestrator calls `sawtools create-worktrees`, launches agents, then calls `sawtools merge-agents`

**Key constraint:** Cannot use automated `sawtools run-wave` (requires programmatic agent launching via API)

**Use case:** Development workflows inside Claude Code, exploratory work, debugging

### Model 2: Webapp/Native App Orchestration (Programmatic)

**Context:** User in web browser or native app (Wails).

**How it works:**
- Backend HTTP server launches agents programmatically via multiprovider backend
- Agents use configured LLM provider (see Configuration section for supported providers)
- Fully automated: `saw run-wave` or API endpoints handle worktree creation, agent launch, verification, merge
- Web app imports `scout-and-wave-go/pkg/engine` directly (Go library imports, not CLI subprocesses)

**Key features:**
- SSE streaming for real-time agent output
- React UI for visual progress tracking
- Approval workflows (review/approve/reject waves)
- Parallel execution dashboard

**Use case:** Team workflows, production deployments, code review, wave monitoring

## Web Application Architecture

The `scout-and-wave-web` repository provides the primary user interface for wave orchestration.

**Architecture:**
- HTTP server on port 7432 (default, configurable via `--port`)
- React frontend embedded via `//go:embed all:dist` (Vite build, ~20MB binary)
- SSE (Server-Sent Events) for real-time agent streaming
- API-first design: all operations exposed via HTTP endpoints

**Key components:**

**Backend (`pkg/api/`):**
- 36 Go files implementing ~47 HTTP routes
- SSE broker for agent output streaming (`/api/events`)
- Wave runner integrating with `pkg/engine` from scout-and-wave-go
- File serving, IMPL manifest parsing, worktree management

**Frontend (`web/`):**
- React 18 + TypeScript
- Tailwind CSS 3 (JIT mode)
- Real-time wave execution dashboard
- Dependency graph visualization (SVG)
- Approval workflow UI (approve/request-changes/reject)

**Build requirement:**
```bash
cd web && npm run build              # Build React assets
cd .. && go build -o saw ./cmd/saw   # Embed assets into binary
```

**Critical:** Web assets are embedded at build time. Any frontend change requires rebuilding the Go binary for changes to take effect.

**Import relationship:**
- `scout-and-wave-web` imports `scout-and-wave-go/pkg/engine` and `pkg/protocol` as Go libraries
- No CLI subprocess calls to `sawtools` binary
- Direct Go function calls for all protocol operations

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
        │   ├── .git          # File with gitdir: pointer to main .git
        │   └── [files]       # Agent A's workspace
        └── wave1-agent-B/    # Isolated worktree
            ├── .git          # File with gitdir: pointer to main .git
            └── [files]       # Agent B's workspace
```

**Benefits:**
- Agents cannot interfere with each other's work
- Each agent has full git history and can commit independently
- Merge happens after all agents complete (I3: wave sequencing)

### 3. Protocol SDK and Binaries

Scout-and-Wave provides two binaries with different purposes:

#### sawtools (SDK Toolkit)

**Location:** `~/.local/bin/sawtools` (installed from `scout-and-wave-go/cmd/saw`)
**Size:** 11 MB
**Purpose:** Full protocol SDK, operator utilities, CI/CD integration
**Commands:** 38 commands organized by category

**Worktree operations:**
- `create-worktrees` — Create isolated worktrees for a wave
- `cleanup` — Remove worktrees after merge
- `verify-isolation` — Check agent is in correct worktree

**Wave execution:**
- `run-wave` — Fully automated wave execution (requires multiprovider backend)
- `merge-agents` — Merge completed agents to main
- `verify-commits` — Pre-merge commit verification
- `verify-build` — Post-merge build verification
- `prepare-agent` — Prepare agent context with journal
- `prepare-wave` — Prepare wave execution environment
- `finalize-wave` — Finalize wave after merge
- `assign-agent-ids` — Assign stable IDs to agents
- `run-scout` — Launch Scout agent

**IMPL management:**
- `list-impls` — Discover IMPL docs
- `validate` — E16 manifest validation
- `extract-context` — E23 per-agent context extraction
- `update-status` — Agent status tracking
- `update-context` — E18 update project memory
- `update-agent-prompt` — Update agent task prompt in manifest
- `mark-complete` — E15 completion marker
- `set-completion` — Register completion report

**Quality assurance:**
- `scan-stubs` — E20 stub detection
- `run-gates` — E21 quality gate verification
- `check-conflicts` — I1 file ownership conflict detection
- `check-deps` — Dependency analysis
- `validate-scaffolds` — Validate scaffold file status (plural)
- `validate-scaffold` — Validate single scaffold file (singular)
- `freeze-check` — Check for interface contract freeze violations

**Analysis and diagnostics:**
- `solve` — Interactive problem solver
- `debug-journal` — Inspect agent execution history
- `journal-init` — Initialize journal directory
- `journal-context` — Generate context from journal
- `detect-cascades` — Detect cascade candidates from type renames
- `detect-scaffolds` — Detect shared types needing scaffolds
- `analyze-deps` — Analyze Go repository dependencies
- `analyze-suitability` — Scan codebase for requirement status
- `extract-commands` — Extract build/test/lint commands from CI configs
- `diagnose-build-failure` — Diagnose post-merge build failures
- `verify-hook-installed` — Check if Scout boundaries hook is installed

**Target audience:** Protocol implementers, power users, CI/CD pipelines

#### saw (Orchestration + Web UI)

**Location:** `/Users/dayna.blackwell/code/scout-and-wave-web/saw` (project-local)
**Size:** 20 MB (includes embedded React bundle via `//go:embed all:dist`)
**Purpose:** User-facing orchestration, web UI, HTTP server
**Primary command:** `serve` (HTTP server on port 7432, 47 API endpoints)
**Commands:** 23 commands (subset focused on user workflows)

**High-level orchestration:**
- `serve` — Start HTTP server with embedded React UI
- `scout` — Launch Scout agent (CLI or API)
- `scaffold` — Launch Scaffold agent
- `wave` — Execute wave agents
- `merge` — Merge agent worktrees
- `merge-wave` — Check wave merge readiness (JSON output)
- `current-wave` — Return first incomplete wave number
- `status` — Show wave/agent status

**IMPL operations:**
- `render` — Render YAML IMPL as markdown
- `validate` — Validate IMPL manifest
- `extract-context` — Extract agent-specific context
- `set-completion` — Register completion report
- `mark-complete` — Write SAW:COMPLETE marker
- `update-agent-prompt` — Update agent prompt

**Quality assurance:**
- `run-gates` — Run quality gate checks
- `check-conflicts` — Detect file ownership conflicts
- `validate-scaffolds` — Validate scaffold status
- `freeze-check` — Check interface freeze violations

**Analysis:**
- `analyze-deps` — Dependency graph analysis
- `analyze-suitability` — Requirement status scan
- `detect-cascades` — Cascade candidate detection
- `detect-scaffolds` — Shared type detection
- `extract-commands` — Extract CI commands

**Target audience:** Feature developers, code reviewers, team leads

**Command overlap:** 11 commands appear in both binaries (validation, manifest ops, gates) — intentional, as both contexts need them.

See `protocol/execution-rules.md` for detailed command specifications.

### 4. Multiprovider Backend System

The web application and `sawtools run-wave` command use a multiprovider backend for launching agents programmatically.

**Location:** `scout-and-wave-go/pkg/agent/backend/`

**Supported providers:**
- **Anthropic Messages API** (`backend/api/`) — Official Anthropic endpoint, requires `ANTHROPIC_API_KEY`
- **AWS Bedrock** (`backend/bedrock/`) — AWS Bedrock using AWS SDK v2, requires AWS credentials
- **OpenAI-compatible API** (`backend/openai/`) — Supports:
  - OpenAI (`openai:gpt-4o`) — requires `OPENAI_API_KEY`
  - Groq (`openai:mixtral-8x7b`) — set `BaseURL: "https://api.groq.com/openai/v1"`
  - Ollama (`ollama:qwen2.5-coder:32b`) — local LLM at `http://localhost:11434/v1`
  - LM Studio (`lmstudio:phi-4`) — local LLM at `http://localhost:1234/v1`
- **Claude Code CLI** (`backend/cli/`) — Subprocess execution for local development

**Configuration:** Model names with provider prefixes route to the appropriate backend:
```
anthropic:claude-opus-4-6     → Anthropic API
bedrock:claude-sonnet-4-5     → AWS Bedrock
openai:gpt-4o                 → OpenAI API
ollama:qwen2.5-coder:32b      → Ollama (localhost:11434)
lmstudio:phi-4                → LM Studio (localhost:1234)
cli:claude-sonnet-4-6         → Claude Code CLI subprocess
claude-sonnet-4-6             → Anthropic API (default)
```

**Backend interface:**
```go
type Backend interface {
    Run(ctx context.Context, systemPrompt, userMessage, workDir string) (string, error)
    RunStreaming(ctx context.Context, systemPrompt, userMessage, workDir string, onChunk ChunkCallback) (string, error)
    RunStreamingWithTools(ctx context.Context, systemPrompt, userMessage, workDir string, onChunk ChunkCallback, onToolCall ToolCallCallback) (string, error)
}
```

**Tool call loop:** `RunStreamingWithTools` implements the agentic loop:
1. Send messages + tools to LLM
2. LLM responds with text or tool_use
3. If tool_use: execute tool, append result, loop back to step 1
4. If text (finish_reason: "stop"): return final answer

**Project configuration:** Providers configured in `saw.config.json` (see Configuration section).

### 5. Interface Contracts

All cross-agent dependencies are defined as interface contracts in the IMPL manifest before parallel work begins.

**Scaffold Agent creates:**
- Type definitions (structs, interfaces, enums)
- Function signatures (no implementation, just signatures)
- Package documentation

**Committed to main branch** before Wave 1 launches. This enforces I2: interface contracts precede parallel implementation.

**Interface freeze:** When `create-worktrees` runs, contracts become immutable. Any interface change after this point requires recreating all worktrees.

### 6. Tool Journaling Subsystem

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

**CLI Orchestration (Model 1):**
1. User invokes `/saw scout <feature-description>` in Claude Code session
2. Orchestrator launches Scout agent (async, `subagent_type: scout`) via Agent tool
3. Scout analyzes codebase, identifies interfaces, writes IMPL manifest
4. Orchestrator validates IMPL manifest (E16: `sawtools validate`)
5. User reviews and approves decomposition

**Webapp Orchestration (Model 2):**
1. User clicks "New Feature" in web UI or runs `saw scout <feature>` CLI
2. Backend launches Scout agent via multiprovider backend
3. Scout analyzes codebase, writes IMPL manifest
4. Backend validates manifest, streams progress via SSE
5. User reviews and approves in web UI or terminal

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
3. Orchestrator runs `sawtools update-agent-prompt` (if agent prompts need updates based on learnings)
4. IMPL doc is marked `state: COMPLETE`
5. Feature is done

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
│   │   ├── IMPL-<feature>.yaml     # Active work
│   │   └── complete/               # Completed IMPL docs
│   │       └── IMPL-<done>.yaml
│   └── CONTEXT.md                  # Project memory (E18)
├── saw.config.json                 # Project config (journal settings, model defaults)
└── [source code]
```

**Note:** IMPL manifests support optional `repo:` field for cross-repo waves (when a single feature spans multiple repositories).

## Configuration

Project-local config at `<repo>/saw.config.json` or global default at `~/.claude/saw.config.json`:

```json
{
  "agent": {
    "scout_model": "claude-sonnet-4-5",
    "wave_model": "claude-sonnet-4-5",
    "chat_model": "claude-sonnet-4-5",
    "backend": "anthropic",
    "anthropic_api_key": "${ANTHROPIC_API_KEY}",
    "openai_api_key": "${OPENAI_API_KEY}",
    "bedrock_region": "us-east-1"
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
  },
  "providers": {
    "anthropic": {
      "api_key": "${ANTHROPIC_API_KEY}"
    },
    "openai": {
      "api_key": "${OPENAI_API_KEY}",
      "base_url": ""
    },
    "bedrock": {
      "region": "us-east-1",
      "profile": "default"
    },
    "ollama": {
      "base_url": "http://localhost:11434/v1"
    },
    "lmstudio": {
      "base_url": "http://localhost:1234/v1"
    }
  }
}
```

**Provider selection:**
- Model names with provider prefixes (`anthropic:`, `openai:`, `bedrock:`, `ollama:`, `lmstudio:`, `cli:`) route to specific backends
- Models without prefix default to Anthropic Messages API
- `${VAR}` syntax expands environment variables
- Web application uses `providers` config for multiprovider backend
- CLI orchestration (Model 1) uses parent session credentials (ignores `providers` config)

## See Also

- [Protocol Invariants](../protocol/invariants.md) — I1-I6 formal specification
- [Protocol Execution Rules](../protocol/execution-rules.md) — E1-E23 orchestrator rules
- [Tool Journaling](./tool-journaling.md) — Compaction safety system
- [Orchestrator Skill](../implementations/claude-code/prompts/saw-skill.md) — /saw command implementation
