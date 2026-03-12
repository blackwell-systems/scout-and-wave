# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Completed & Shipped

### ✅ Tool Journaling for Compaction Safety (SHIPPED 2026-03-10)

**Status:** Complete. IMPL-tool-journaling.yaml finished, external log observer pattern implemented in scout-and-wave-go v0.27.0, E23A integration across backends ongoing.

**What shipped:**
- External log observer pattern (tails Claude Code session logs)
- Journal structure: cursor tracking, index.jsonl, recent.json, tool-results/
- Context markdown generation from journal entries
- Checkpoint system for milestone snapshots
- Archive policy with 10:1 compression
- CLI commands: `sawtools journal-init`, `sawtools journal-context`

**Moved to:** Production use. See scout-and-wave-go CHANGELOG v0.27.0+ for implementation details.

---

## Protocol Enhancements

### Contract Builder Phase

**Insight:** Forge separates *detecting* cross-agent boundaries from *specifying* the contracts at those boundaries. The planner emits **integration hints** — lightweight annotations flagging where tasks interact ("task-1 produces this API, task-2 consumes it"). A dedicated **Contract Builder** phase reads those hints and generates precise binding contracts before any agent launches.

**Current SAW state:** The Scout generates interface contracts in a single pass. It detects seams AND specifies contracts simultaneously. This works for type-level contracts (where the Scaffold Agent materializes them) but leaves API-level contracts implicit — agents infer request/response shapes from prose descriptions, not machine-readable specs.

**Proposed:** Add integration hints as a structured field in the IMPL doc. Scout emits hints during analysis; a Contract Builder phase (analogous to Scaffold Agent but for API contracts) generates precise specs:
- API contracts: method, path, request/response field types, auth requirements, producer/consumer task mapping
- Type contracts: shared data structures used across agent boundaries (already handled by Scaffold Agent)
- Event/message contracts: for event-driven interfaces

Contracts are injected into agent prompts as binding requirements. The reviewer verifies contract compliance as a distinct check.

**Protocol changes required:**
- `message-formats.md` — integration hint schema, API contract format
- `agents/scout.md` — emit integration hints alongside interface contracts
- New `contract-builder.md` agent type (or extend Scaffold Agent scope)
- `agent-template.md` — API contracts section in per-agent payload

---

### Tier 2 Merge Conflict Resolution Agent

**Insight:** Forge uses a tiered merge conflict strategy: Tier 1 auto-retries the merge (in case main advanced and the conflict resolves on retry); Tier 2 spawns a dedicated resolver agent that reads conflict markers and edits them to produce a clean merge.

**Current SAW state:** `saw-merge.md` Step 4 detects conflicts and surfaces them to the user but has no automated resolution path. The human must resolve manually.

**Proposed:** Add tiered resolution to the merge procedure:
- **Tier 1 (automatic):** Retry the merge after a brief delay — handles the common case where another agent merged concurrently and the working branch advanced
- **Tier 2 (resolver agent):** If Tier 1 fails, spawn a Wave Agent variant with: the conflicting files (with conflict markers), both agents' completion reports, and instructions to resolve by choosing or synthesizing the correct version
- Tier 2 resolver agent commits the resolved files and reports its decision rationale
- If Tier 2 also fails: escalate to human (current behavior)

**Protocol changes required:**
- `saw-merge.md` Step 4 — tiered resolution procedure
- New `resolver-agent.md` agent type (slim variant of wave-agent, owned-file scope is the conflicting files only)
- `execution-rules.md` — new E-rule for conflict resolution tiers

---

### Full Research Output on NOT SUITABLE Verdicts (Protocol changes pending, UI shipped)

> **UI SHIPPED — 2026-03-08 (scout-and-wave-web v0.17.0):** `NotSuitableResearchPanel` renders the full research output. Protocol spec updates to scout.md and message-formats.md still needed to require full research regardless of verdict.

**Current state:** When Scout returns NOT SUITABLE, it writes a short verdict with a brief rationale and stops. The IMPL doc is minimal — just the verdict and a sentence or two explaining why.

**Problem:** The Scout has already done the work — it analyzed the codebase, mapped the files, identified the dependency structure, assessed the risks. All of that research is discarded. The user gets a dead end with no actionable information.

**Proposed:** Decouple the **verdict** from the **research**. The verdict gates whether the protocol proceeds to waves; the research is always written in full regardless of verdict.

A NOT SUITABLE IMPL doc should contain everything a SUITABLE one does, except agent prompts:

- Full file survey — what exists, what would need to change, what the blast radius is
- Dependency map — what depends on what, which files are entangled
- Risk assessment — what makes it unsuitable (scope too large, ownership conflicts, missing interfaces, architectural mismatch)
- **Why not suitable** — specific, actionable: "this requires touching 23 files across 6 packages with no clean seam for disjoint ownership" is more useful than "NOT SUITABLE"
- **What would make it suitable** — conditions under which a future Scout run could return SUITABLE. E.g., "extract `pkg/agent/runner.go` first as a prerequisite, then re-scout"
- **Serial implementation notes** — if the work isn't suitable for parallel wave execution, what's the recommended serial order? This surfaces value for users who want to implement manually or in a single agent rather than in waves.

The verdict badge on the review screen changes color (red/amber/green) but the research panels all populate. NOT SUITABLE is not a dead end — it's a detailed map of why the work is hard and what to do about it.

**Protocol changes required:**
- `protocol/message-formats.md` — NOT SUITABLE IMPL docs required to contain full research sections; only `## Agent Prompts` and `## Wave Execution Loop` are omitted
- `agents/scout.md` and `prompts/scout.md` — suitability gate updated: verdict is written early, but research sections are always completed regardless of verdict
- Web UI review screen — NOT SUITABLE verdict shown prominently but research panels still render; "What would make it suitable" section displayed as a callout

---

## In Progress

### E23A: Tool Journal Recovery Integration

**Status:** Implementation complete (v0.27.0), integration across all backends ongoing.

- **Files already modified** — Agent might re-edit the same file, causing duplicate work or conflicts
- **Test results from 30 minutes ago** — Agent might re-run expensive test suites unnecessarily
- **Git commits created** — Agent can't reference commit SHAs in completion report (I5 violation)
- **Scaffold imports discovered** — Agent might re-discover which interfaces to import, wasting time
- **Verification gates already passed** — Agent forgets which gates passed and might skip reporting them
- **Blockers already hit** — Agent retries operations that already failed, entering error loops

**Protocol deviation risk:** Without execution history, agents can inadvertently violate core invariants:
- **I4 violation** — Forget to write completion report (or write incomplete report missing commit SHA)
- **I5 violation** — Report `commit: "uncommitted"` after actually committing 30 minutes ago
- **E14 violation** — Lose draft completion report and fail to append it to IMPL doc

### The Solution: External Log Observer

**Architecture:** Tail Claude Code's session logs (`~/.claude/projects/<project>/*.jsonl`) and extract tool execution history externally, rather than instrumenting tool middleware. This provides:
- **Zero backend modifications** — Works with any agent implementation (Anthropic API, CLI, OpenAI) without changes
- **Crash resilience** — Session logs persist even if agent crashes mid-execution
- **Complete capture** — Gets everything Claude Code logs, not just what we instrument
- **Future-proof** — New backends automatically get journaling for free

**File structure:**
```
.saw-state/wave1/agent-A/
├── cursor.json              # Tracks read position in Claude Code session log
├── index.jsonl              # Tool use + result metadata (append-only)
├── recent.json              # Last 30 events (JSON array for fast access)
├── context.md               # Human-readable summary (generated from index)
└── tool-results/
    ├── toolu_abc123.txt     # Full output for tool use abc123 (separate file)
    └── toolu_def456.txt     # Full output for tool use def456
```

**Index entry schema (JSONL):**
```json
{"ts":"2026-03-10T14:23:45Z","kind":"tool_use","tool_name":"edit_file","tool_use_id":"toolu_abc123","input":{"file":"pkg/api/routes.go","operation":"insert"},"session_id":"sess_xyz"}
{"ts":"2026-03-10T14:25:12Z","kind":"tool_result","tool_use_id":"toolu_abc123","content_file":".saw-state/wave1/agent-A/tool-results/toolu_abc123.txt","preview":"✓ Inserted 12 lines","truncated":false}
{"ts":"2026-03-10T14:26:03Z","kind":"tool_use","tool_name":"bash","tool_use_id":"toolu_def456","input":{"command":"go test ./pkg/api"},"session_id":"sess_xyz"}
```

**Context markdown (generated from journal, injected into agent on resume):**
```markdown
## Session Context (Recovered from Tool Journal)

**Last activity:** 2026-03-10 14:35:22 (12 minutes ago)
**Total tool calls:** 47
**Session duration:** 1h 23m

### Files Modified (4)
- `pkg/api/routes.go` (added 3 endpoints, 45 lines) — last edited 14:23
- `pkg/api/handlers.go` (fixed type error, 3 lines) — last edited 14:24
- `pkg/api/routes_test.go` (added tests, 78 lines) — last edited 14:25
- `go.mod` (updated dependency) — last edited 14:22

### Tests Run
- `go test ./pkg/api` → 12 passed, 2 failed (cache_test timeout) — 14:25
- Fixed timeout in cache_test.go, retried — 14:28
- `go test ./pkg/api` → 14 passed ✓ — 14:29

### Git Commits
- **abc123d** "feat: add REST endpoints for user API"
  (committed 14:26, branch: wave1-agent-A, 4 files changed, 126 insertions)

### Scaffold Files Imported
- `pkg/types/user.go` (User, UserRequest, UserResponse types)
  Imported at line 8 of routes.go — 14:23
- `pkg/types/response.go` (APIResponse, ErrorResponse types)
  Imported at line 9 of routes.go — 14:23

### Verification Status (Field 6 Gates)
- ✓ Build: `go build ./pkg/api` — PASS (14:30)
- ✓ Tests: `go test ./pkg/api` — PASS, 14 tests (14:29)
- ⏳ Lint: `go vet ./pkg/api` — Not yet run

### Completion Report Status
- ⏳ Not yet written (next step after lint gate passes)

**What's next:** Run lint gate (`go vet ./pkg/api`), then write completion report to IMPL doc.
```

### Implementation Spec

**New package: `pkg/journal/` - External Log Observer**

```go
// pkg/journal/observer.go
package journal

import (
    "bufio"
    "encoding/json"
    "io"
    "os"
    "path/filepath"
    "time"
)

// SessionCursor tracks read position in Claude Code session log
type SessionCursor struct {
    SessionFile string `json:"session_file"` // e.g., "1a2b3c4d.jsonl"
    Offset      int64  `json:"offset"`       // Byte offset in file
}

// JournalObserver tails Claude Code session logs and extracts tool history
type JournalObserver struct {
    ProjectRoot Path
    JournalDir  Path
    AgentID     string

    cursorPath  Path
    indexPath   Path
    recentPath  Path
    resultsDir  Path
}

// NewObserver creates a journal observer for an agent
func NewObserver(projectRoot Path, agentID string) (*JournalObserver, error) {
    journalDir := projectRoot.Join(".saw-state", agentID)
    if err := os.MkdirAll(journalDir, 0755); err != nil {
        return nil, err
    }

    return &JournalObserver{
        ProjectRoot: projectRoot,
        JournalDir:  journalDir,
        AgentID:     agentID,
        cursorPath:  journalDir.Join("cursor.json"),
        indexPath:   journalDir.Join("index.jsonl"),
        recentPath:  journalDir.Join("recent.json"),
        resultsDir:  journalDir.Join("tool-results"),
    }, nil
}

// Sync incrementally reads from Claude Code session log and updates journal
func (o *JournalObserver) Sync() (*SyncResult, error) {
    // 1. Find latest session log: ~/.claude/projects/<project-id>/*.jsonl
    sessionFile, err := o.findLatestSessionFile()
    if err != nil {
        return nil, err
    }

    // 2. Load cursor (tracks where we last read)
    cursor, err := o.loadCursor()
    if err != nil {
        cursor = &SessionCursor{SessionFile: sessionFile.Name(), Offset: 0}
    }

    // 3. If session file changed (new Claude Code session), reset cursor
    if cursor.SessionFile != sessionFile.Name() {
        cursor.SessionFile = sessionFile.Name()
        cursor.Offset = 0
    }

    // 4. Open session log and seek to cursor position
    f, err := os.Open(sessionFile)
    if err != nil {
        return nil, err
    }
    defer f.Close()

    if _, err := f.Seek(cursor.Offset, io.SeekStart); err != nil {
        return nil, err
    }

    // 5. Read new lines and extract tool_use + tool_result entries
    scanner := bufio.NewScanner(f)
    newEvents := []Event{}

    for scanner.Scan() {
        line := scanner.Bytes()
        cursor.Offset, _ = f.Seek(0, io.SeekCurrent) // Update cursor

        var entry map[string]interface{}
        if err := json.Unmarshal(line, &entry); err != nil {
            continue // Skip malformed lines
        }

        // Extract tool_use blocks
        for _, toolUse := range extractToolUses(entry) {
            newEvents = append(newEvents, Event{
                Kind:      "tool_use",
                Timestamp: entry["timestamp"].(string),
                ToolName:  toolUse["name"].(string),
                ToolUseID: toolUse["id"].(string),
                Input:     truncateDeep(toolUse["input"], maxDepth),
            })
        }

        // Extract tool_result blocks
        for _, toolResult := range extractToolResults(entry) {
            toolUseID := toolResult["tool_use_id"].(string)
            content := toolResult["content"].(string)

            // Save full output to separate file
            resultFile := o.resultsDir.Join(toolUseID + ".txt")
            os.WriteFile(resultFile, []byte(content), 0644)

            newEvents = append(newEvents, Event{
                Kind:        "tool_result",
                Timestamp:   entry["timestamp"].(string),
                ToolUseID:   toolUseID,
                ContentFile: resultFile.String(),
                Preview:     truncate(content, 800),
            })
        }
    }

    // 6. Append new events to index.jsonl
    if err := o.appendToIndex(newEvents); err != nil {
        return nil, err
    }

    // 7. Update recent.json (last 30 events, fast access cache)
    if err := o.updateRecent(newEvents); err != nil {
        return nil, err
    }

    // 8. Save cursor
    if err := o.saveCursor(cursor); err != nil {
        return nil, err
    }

    return &SyncResult{
        NewToolUses:    countToolUses(newEvents),
        NewToolResults: countToolResults(newEvents),
        NewBytes:       cursor.Offset,
    }, nil
}

// GenerateContext creates markdown summary from journal
func (o *JournalObserver) GenerateContext() (string, error) {
    // Read recent events from recent.json (fast)
    events, err := o.readRecent(30)
    if err != nil {
        return "", err
    }

    // Analyze events to extract:
    // - Files modified (from edit_file/write_file tool_use)
    // - Commands run (from bash tool_use)
    // - Test results (parse bash tool_result for test output)
    // - Git commits (parse bash tool_result for commit SHAs)
    // - Scaffold imports (from read_file tool_use matching scaffold paths)

    return buildContextMarkdown(events), nil
}

func (o *JournalObserver) findLatestSessionFile() (Path, error) {
    // ~/.claude/projects/<project-hash>/
    claudeDir := os.UserHomeDir() + "/.claude/projects"

    // Find directory matching project root hash
    projectHash := hashPath(o.ProjectRoot)
    sessionDir := filepath.Join(claudeDir, projectHash)

    // Find latest *.jsonl file by mtime
    files, _ := filepath.Glob(filepath.Join(sessionDir, "*.jsonl"))
    if len(files) == 0 {
        return "", errors.New("no session file found")
    }

    // Return most recent
    latest := files[0]
    latestMtime := time.Unix(0, 0)
    for _, f := range files {
        info, _ := os.Stat(f)
        if info.ModTime().After(latestMtime) {
            latest = f
            latestMtime = info.ModTime()
        }
    }

    return Path(latest), nil
}
```

**Integration points:**

1. **Before agent launch** (in `pkg/engine/runner.go`):
```go
func (r *Runner) launchWaveAgent(wave int, agentID string, prompt string) error {
    // Create journal observer for this agent
    observer, err := journal.NewObserver(r.repoPath, fmt.Sprintf("wave%d/agent-%s", wave, agentID))
    if err != nil {
        return err
    }

    // Sync from Claude Code session logs (incremental tail)
    result, err := observer.Sync()
    if err != nil {
        r.logger.Warn("Failed to sync journal", "error", err)
        // Non-fatal: continue without journal recovery
    }

    // If journal has events, generate context and prepend to prompt
    if result != nil && result.NewToolUses > 0 {
        contextMd, err := observer.GenerateContext()
        if err == nil {
            prompt = contextMd + "\n\n---\n\n" + prompt
            r.logger.Info("Recovered session context",
                "agent", agentID,
                "tool_calls", result.NewToolUses,
            )
        }
    }

    // Launch agent with enriched prompt (no context needed in agent - observer runs externally)
    return r.agentBackend.Execute(prompt)
}
```

2. **Periodic sync during execution** (background goroutine):
```go
// In runner.go, after launching agent
go func() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            // Sync journal from Claude Code session logs
            observer.Sync()
        case <-ctx.Done():
            return
        }
    }
}()
```

3. **No middleware needed** - Tool calls are captured by Claude Code's native session logging, not by our middleware. This makes the journal:
   - ✓ Backend-agnostic (works with Anthropic API, CLI, OpenAI without changes)
   - ✓ Crash-resilient (session logs survive agent crashes)
   - ✓ Complete (captures everything Claude Code logs)
   - ✓ Zero instrumentation cost (no middleware overhead)

### Retention Policy

**During wave execution:**
- Keep full journal in `.saw-state/wave{N}/agent-{ID}/tools.jsonl`
- Checkpoints accumulate in `checkpoints/` subdirectory

**After wave merges:**
- Archive journal: `tar -czf .saw-state/archive/wave1-agent-A-tools.jsonl.gz .saw-state/wave1/agent-A/`
- Original journal remains for debugging (archived journals are compressed ~10:1)

**After IMPL doc gets SAW:COMPLETE marker:**
- Optionally delete non-archived journals: `rm -rf .saw-state/wave*/`
- Keep archives: `.saw-state/archive/*.tar.gz` (typically <1MB per agent)
- Configurable via `sawtools config set journal.retention <days>` (default: 30 days after completion)

### Protocol Changes Required

**New execution rule: E23A (Tool Journal Recovery)**

Add to `protocol/execution-rules.md`:

```markdown
## E23A: Tool Journal Recovery

Before launching a Wave agent, the Orchestrator checks for an existing tool journal at `.saw-state/wave{N}/agent-{ID}/tools.jsonl`.

If found:
1. Load the journal (all JSONL entries)
2. Generate `context.md` by analyzing the last 50 entries (or all entries if <50):
   - Files modified/created (from Edit/Write tools) with line counts
   - Commands run (from Bash tool) with exit codes
   - Tests executed (from Bash tool matching `test` pattern) with pass/fail counts
   - Git commits made (from Bash tool matching `git commit`) with SHAs and branch names
   - Scaffold files imported (from Read tool matching scaffold paths)
   - Verification gate status (from Bash tool matching Field 6 commands)
   - Completion report status (whether written yet)
3. Prepend `context.md` to the agent's prompt under `## Session Context (Recovered from Tool Journal)`

The journal becomes the agent's working memory across context compactions. It is append-only; entries are never deleted during execution.

**Interaction with I4 (IMPL doc as single source of truth):**
- The IMPL doc remains the source of truth for *planning* (agent prompts, interface contracts, file ownership)
- The tool journal is the source of truth for *execution history* (what the agent has actually done)
- Completion reports synthesize both: "I modified these files (from journal), they implement these interfaces (from IMPL doc), tests pass (from journal), here's the commit SHA (from journal)"

**Failure recovery:** If an agent fails with `failure_type: transient` or `failure_type: fixable` (E19), the Orchestrator relaunches the agent. The journal is preserved across retries — the agent sees what it tried before and can avoid repeating failed operations.
```

**Update to I4 (IMPL Doc as Single Source of Truth):**

Extend `protocol/invariants.md` I4 to clarify duality:

```markdown
## I4: IMPL Doc as Single Source of Truth

The IMPL doc is the canonical source of truth for **planning**:
- Agent prompts (Fields 0-8)
- Interface contracts (what agents must implement)
- File ownership (which agent owns which files)
- Wave structure (dependency graph, execution order)
- Completion reports (agent outcomes, written after execution)

The **tool journal** (`.saw-state/wave{N}/agent-{ID}/tools.jsonl`) is the canonical source of truth for **execution history**:
- Which files the agent has actually modified
- Which commands the agent has run
- Which tests have passed/failed
- Which git commits the agent has made
- How long operations took

Completion reports synthesize both: agents read their plan from the IMPL doc, execute it while journaling every action, then write a report to the IMPL doc that references the journal (commit SHAs, file counts, test results).

Chat output is not the record for either planning or execution. Observers (humans, UIs, monitoring tools) read from the IMPL doc and tool journals, not from the conversation transcript.
```

### CLI Tooling

**New command: `sawtools debug-journal`**

Inspect journal contents for debugging failed agents:

```bash
# Dump full journal (JSONL to stdout)
sawtools debug-journal wave1/agent-A

# Show human-readable summary
sawtools debug-journal wave1/agent-A --summary

# Show only failed tool calls
sawtools debug-journal wave1/agent-A --failures-only

# Show last N entries
sawtools debug-journal wave1/agent-A --last 20

# Export to HTML timeline (visual debugging)
sawtools debug-journal wave1/agent-A --export timeline.html
```

**Example output (summary mode):**
```
Journal: wave1/agent-A
Duration: 1h 23m (14:02:15 - 15:25:38)
Total tool calls: 47

Files modified: 4
  pkg/api/routes.go      (45 lines added)
  pkg/api/handlers.go    (3 lines added)
  pkg/api/routes_test.go (78 lines added)
  go.mod                 (1 line added)

Commands run: 12
  go test ./pkg/api      (2 runs: 1 failed, 1 passed)
  go build ./pkg/api     (1 run: passed)
  go vet ./pkg/api       (1 run: passed)
  git add ...            (1 run: passed)
  git commit ...         (1 run: passed)

Commits: 1
  abc123d "feat: add REST endpoints" (wave1-agent-A)

Verification gates:
  ✓ Build (14:30)
  ✓ Tests (14:29, 14 passed)
  ✓ Lint  (14:31)

Completion report: ✓ Written (15:25)
```

### Deliverables

- [ ] **Core journal implementation** — `pkg/journal/journal.go` (ToolJournal, ToolEntry, JSONL persistence)
- [ ] **Context generator** — `pkg/journal/context.go` (analyze entries, generate markdown summary)
- [ ] **Checkpoint system** — `pkg/journal/checkpoint.go` (named snapshots at key milestones)
- [ ] **Workshop integration** — `pkg/tools/workshop.go` (JournalingMiddleware, inject journal into context)
- [ ] **Runner integration** — `pkg/engine/runner.go` (load journal before launch, inject context into prompt)
- [ ] **CLI tooling** — `cmd/sawtools/debug_journal.go` (inspect, summarize, export journals)
- [ ] **Archive policy** — `pkg/journal/archive.go` (compress after merge, cleanup after completion)
- [ ] **Protocol documentation** — E23A in `protocol/execution-rules.md`, I4 clarification in `protocol/invariants.md`
- [ ] **Tests** — `pkg/journal/journal_test.go` (append, load, checkpoint, context generation)

### Integration & Downstream Work

After the core journal system is implemented, significant integration work is required across the entire stack:

#### 1. Backend Integration (All Backends Must Journal)

**Anthropic API backend** (`pkg/agent/backend/api/`)
- [ ] Hook `JournalingMiddleware` into tool execution pipeline
- [ ] Pass journal context from runner to backend via `backend.Config`
- [ ] Ensure streaming responses don't bypass journaling

**CLI backend** (`pkg/agent/backend/cli/`)
- [ ] Wrap subprocess tool calls with journal logging
- [ ] Capture stdin/stdout for Bash tool entries
- [ ] Handle cases where CLI agent spawns its own subagents

**OpenAI backend** (`pkg/agent/backend/openai/`)
- [ ] Adapt tool call format differences (OpenAI uses `function` objects)
- [ ] Journal both single-turn and multi-turn tool calls
- [ ] Handle parallel tool calls (log each independently)

**Challenge:** Each backend has different tool call/response shapes. Journal must normalize these to a common schema.

#### 2. Orchestrator Integration (`pkg/engine/`)

**Wave launch** (`pkg/engine/runner.go`)
- [ ] Load journal before constructing agent prompt
- [ ] Inject `context.md` as preamble if journal exists
- [ ] Create journal instance per agent (keyed by `wave{N}/agent-{ID}`)
- [ ] Pass journal to backend via context

**Checkpoint triggers**
- [ ] After Field 0 verification passes → `journal.Checkpoint("001-isolation")`
- [ ] After first Edit/Write succeeds → `journal.Checkpoint("002-first-edit")`
- [ ] After first test run → `journal.Checkpoint("003-tests")`
- [ ] Before completion report write → `journal.Checkpoint("004-pre-report")`

**Failure recovery** (E19 integration)
- [ ] Preserve journal when retrying `transient` failures
- [ ] Include journal summary in retry prompt ("You tried X before, it failed with Y")
- [ ] Detect retry loops (same tool failing >3 times) from journal

**Merge procedure** (`saw-merge.md`)
- [ ] Archive journals to `.saw-state/archive/wave{N}-agent-{ID}.tar.gz` after merge
- [ ] Optionally delete uncompressed journals after archival
- [ ] Keep archives for N days (configurable retention policy)

#### 3. Agent Prompt Updates

**Scout** (`agents/scout.md`)
- [ ] Scout agents typically don't journal (read-only, no long-running operations)
- [ ] Exception: if Scout runs >30min, journal should be enabled
- [ ] Document when Scout should/shouldn't journal

**Wave Agent** (`agents/wave-agent.md`)
- [ ] Add section explaining journal recovery in Field 0 preamble
- [ ] "If you see '## Session Context (Recovered from Tool Journal)', this is your execution history from a prior session. You've already performed these operations — don't repeat them."
- [ ] Update Field 8 (completion report) to reference journal for file counts/commit SHAs

**Scaffold Agent** (`agents/scaffold-agent.md`)
- [ ] Enable journaling (scaffold creation can take 10-20min)
- [ ] Journal helps debug why scaffold compilation failed
- [ ] Completion report can reference journal for build command outputs

#### 4. Web UI Integration (`scout-and-wave-web`)

**Observatory panel** (`web/src/components/Observatory.tsx`)
- [ ] Display real-time journal entries as they append
- [ ] Show tool call history alongside SSE events
- [ ] Visual timeline: dots for each tool call, colored by success/failure

**Agent detail view** (new component)
- [ ] Tab: "Tool History" — renders `context.md` from journal
- [ ] Tab: "Raw Journal" — paginated JSONL viewer
- [ ] Tab: "Checkpoints" — list named snapshots with restore option

**Failed agent debugging** (new panel)
- [ ] When agent status is `blocked` or `partial`, show journal summary
- [ ] Highlight failed tool calls in red
- [ ] "View full context" expands to complete journal

**API endpoints** (new routes)
```go
GET  /api/journal/:wave/:agent          // Get full journal (JSONL)
GET  /api/journal/:wave/:agent/summary  // Get context.md
GET  /api/journal/:wave/:agent/checkpoints // List checkpoints
POST /api/journal/:wave/:agent/restore  // Restore from checkpoint
```

#### 5. Testing Strategy

**Unit tests** (`pkg/journal/journal_test.go`)
- [ ] Append entry, verify JSONL persistence
- [ ] Load existing journal, verify entries restored
- [ ] Checkpoint creation, verify snapshot saved
- [ ] Context generation from diverse tool calls

**Integration tests** (`test/integration/journal_test.go`)
- [ ] Simulate wave execution with journaling enabled
- [ ] Trigger artificial context compaction mid-wave
- [ ] Verify agent recovers context after compaction
- [ ] Verify completion report includes data from journal (commit SHA, file counts)

**E2E tests** (`test/e2e/compaction_test.go`)
- [ ] Real wave with intentionally small context window
- [ ] Force compaction after N tool calls
- [ ] Agent must complete successfully despite compaction
- [ ] Completion report must reference pre-compaction work

#### 6. Migration & Compatibility

**Existing waves in progress**
- [ ] Gracefully handle agents with no journal (first execution)
- [ ] Don't break if `.saw-state/` doesn't exist
- [ ] Backward compatibility: old completion reports without journal references

**Version detection**
- [ ] Journal format version field (v1 initially)
- [ ] Future schema changes handled via version check
- [ ] Loader rejects unsupported versions with clear error

**Opt-out mechanism**
- [ ] Config flag: `sawtools config set journal.enabled false`
- [ ] Useful for debugging journal itself
- [ ] Documented reason: "Disable only for testing; breaks long-running waves"

#### 7. Documentation Updates

**User-facing** (`docs/`)
- [ ] New doc: `docs/tool-journaling.md` — what it is, why it exists, how to debug with it
- [ ] Update `docs/architecture.md` — add journal subsystem to diagram
- [ ] Update `docs/troubleshooting.md` — "If agent lost context, check journal"

**Protocol** (`protocol/`)
- [ ] E23A in `execution-rules.md` (already specified above)
- [ ] I4 clarification in `invariants.md` (already specified above)
- [ ] New section in `message-formats.md`: Journal Entry Format

**Implementation guide** (`implementations/claude-code/`)
- [ ] Update `saw-skill.md` — orchestrator must load journals before launch
- [ ] Update `saw-worktree.md` — journals persist across worktree operations
- [ ] Update `saw-merge.md` — archive journals after merge

#### 8. Monitoring & Observability

**Metrics to track**
- [ ] Journal file sizes (alert if >5MB per agent)
- [ ] Journal append latency (p50, p99)
- [ ] Context recovery rate (% of agents that loaded prior journal)
- [ ] Compaction survival rate (agents that completed after compaction)

**Logging**
- [ ] Log when journal is created (wave{N}/agent-{ID}, first tool call)
- [ ] Log when journal is loaded (wave{N}/agent-{ID}, N entries recovered)
- [ ] Log checkpoint creation (checkpoint name, entry count at snapshot)
- [ ] Log archive operations (compressed size, retention days remaining)

**Alerts**
- [ ] Journal append failures (disk full, permission denied)
- [ ] Corrupt journal files (malformed JSONL)
- [ ] Missing journals on retry (E19 retry without journal = suspicious)

### Dependencies

**External:** None (self-contained implementation)

**Internal:**
- Tool System Refactoring (v0.19.0) — `pkg/tools/` Workshop with middleware support ✓ shipped
- Middleware wiring (v0.20.0) — `OnToolCall` hook for timing/logging ✓ shipped

### Impact

**Reliability:** Eliminates execution history loss during compaction. Agents can resume mid-task without rediscovering prior work.

**Debuggability:** Full tool history persisted to disk. Failed agents leave complete audit trails.

**Protocol compliance:** Reduces I4/I5 violations by preserving completion report drafts and commit SHAs across compactions.

**Critical for production:** Long-running waves (>2 hours) will compact at least once. Without journaling, agents in hour 3 lose all context from hours 1-2.

**Performance:** Append-only JSONL writes are <1ms each. Minimal overhead. Journal files typically <500KB per agent (50-100 tool calls @ ~5KB/entry).

---

## Framework Skills Content

### Framework-Specific Guidance Documents

**Proposal:** The protocol repo should provide framework-specific best practice documents that implementations MAY inject into agent prompts. These documents capture common patterns, anti-patterns, and conventions for popular frameworks.

**Skill directory structure:**
```
scout-and-wave/skills/
  react-best-practices.md        # Hooks, component composition, prop types
  vue-best-practices.md          # Composition API, reactivity, lifecycle
  rust-ownership.md              # Borrowing, lifetimes, ownership patterns
  rust-error-handling.md         # Result, Option, ? operator
  go-idioms.md                   # Interfaces, error handling, goroutines
  go-error-handling.md           # Error wrapping, sentinel errors
  python-type-hints.md           # Type annotations, generics, protocols
  fastapi-patterns.md            # Dependency injection, async, validation
```

**Skill file format:**
- Markdown documents (500-1000 words each)
- Common patterns (with code examples)
- Anti-patterns to avoid (with explanations)
- Framework-specific best practices

**Detection trigger examples:**
- `package.json` with `react` dependency → load `react-best-practices.md`
- `Cargo.toml` exists → load `rust-ownership.md`, `rust-error-handling.md`
- `go.mod` exists → load `go-idioms.md`
- `pyproject.toml` with `fastapi` → load `fastapi-patterns.md`

**Protocol stance:** Implementations MAY auto-detect frameworks and inject skills, or require manual configuration. The protocol provides the content but does not mandate detection logic. This keeps framework knowledge centralized while allowing implementation flexibility.

**Implementation note:** Detection and injection logic belongs in orchestrator implementations (e.g., `scout-and-wave-go`), not in the protocol repo.

---

## Orchestration UX

*`scout-and-wave-web` implementation work. Full designs in `scout-and-wave-web/docs/ROADMAP.md`.*

### Claude Orchestrator Chat Panel

Add a Claude chat panel to `saw serve`. Read-only diagnostic mode first (why did agent B fail?), then write tools (retry, skip), then proactive SSE monitoring. No protocol changes required.

### ✅ Explicit IMPL Targeting in `/saw` Skill — SHIPPED (v0.24.0 / saw-skill v0.9.0)

`--impl <id>` flag added to `/saw wave` and `/saw status` for explicit IMPL doc selection. Supports slug, filename, or path resolution. Auto-selects when exactly 1 pending IMPL exists.

---

## Multi-Generation Agent IDs

### Extended Agent Identifier Format (A2, B3, ...)

**Current state:** Agent identifiers are single uppercase letters A–Z, giving a maximum of 26 agents per wave. The IMPL doc format, parser, and all agent prompts assume single-character IDs.

**Problem:** 26 agents per wave is a practical ceiling. Large features with many parallel work streams, or a future meta-orchestrator running multiple concurrent IMPLs, could exceed this. There is also no systematic color/identity scheme for agents — single letters were sufficient when the number was small.

**Proposed identifier format:** `[Letter][Generation]` where Generation is omitted for generation 1:

| ID | Letter | Generation | Meaning |
|----|--------|------------|---------|
| `A` | A | 1 | First agent of A-family |
| `B` | B | 1 | First agent of B-family |
| `A2` | A | 2 | Second agent of A-family (same hue, different shade) |
| `B3` | B | 3 | Third agent of B-family |

Letter families provide color identity continuity (see web UI roadmap). Generation distinguishes agents within a family while keeping the visual grouping clear — A and A2 are related; A and B are not.

**When to use multi-generation IDs:** The Scout assigns them when a feature requires more agents than available letters (>26), or when agents within a letter family share a logical sub-domain (e.g., A handles API layer; A2 handles API tests for the same subsystem). The Scout decides — the orchestrator does not assign IDs manually.

**Protocol changes required:**

- `protocol/message-formats.md` — Agent ID field definition updated: `[A-Z][2-9]?` (letter + optional digit 2–9; generation 1 is the bare letter). Examples in file ownership table and wave structure sections updated.
- `protocol/execution-rules.md` — E-rules referencing "agent letter" updated to "agent ID". SAW tag format updated: `[SAW:wave1:agent-A2]` is valid.
- `implementations/claude-code/prompts/agents/scout.md` — Scout briefing updated to explain multi-generation IDs and when to assign them.
- `implementations/claude-code/prompts/agents/wave-agent.md` — Wave agent briefing updated to accept multi-char `letter` field in Field 0.
- Parser (`pkg/protocol/parser.go` in scout-and-wave-web) — regex for agent letter updated from `[A-Z]` to `[A-Z][2-9]?`.
- Web UI (`lib/agentColors.ts`) — color derivation updated to decompose multi-char IDs into `(letter, generation)` and apply tonal variation. See web UI roadmap.

**Non-change:** Worktree branch names already use the full agent ID as a string (`wave1-agent-A2`), so no branch naming changes are needed.

---

## Protocol Hardening (Cross-Repo Lessons)

Items identified during the engine extraction (Wave 2, 2026-03-08) that should be added to the protocol.

### Cross-Repo Field 8 Completion Report Path

**Current state:** The agent template Field 8 (completion report) instructs agents to write the report to the IMPL doc. In cross-repo waves, the IMPL doc is in repo A (the spec repo) while the agent works in repo B. Agents that don't receive an absolute IMPL doc path write their report to the wrong location — or not at all.

**Proposed:** In cross-repo mode, the agent prompt must always include an absolute path to the IMPL doc (not relative). Add an explicit callout to `saw-worktree.md` cross-repo section:

> "When constructing wave agent prompts for cross-repo waves, Field 8 must include the **absolute path** to the IMPL doc in the orchestrating repo. Example: `/Users/dev/code/spec-repo/docs/IMPL/IMPL-feature.md`. A relative path will resolve to the wrong directory in the agent's worktree."

**Protocol changes required:** `saw-worktree.md` cross-repo mode section, `agents/wave-agent.md` Field 8 description.

---

### BUILD STUB Test Discipline

**Current state:** When agents write functions that compile but intentionally leave out implementation (e.g., stubs that will be filled by a later wave), tests that exercise those functions will fail. Agents sometimes mark these as `status: complete` anyway.

**Problem:** Stub functions with passing test suites are misleading. A BUILD STUB is not a COMPLETE stub — it is a deliberate placeholder. Treating it as complete conflates "code compiles" with "feature works."

**Proposed:** Distinguish two stub states in agent prompts:
- **BUILD STUB** — function is declared, compiles, body panics/returns zero values. Tests are expected to fail. Mark `status: partial` with `failure_type: fixable`.
- **COMPLETE** — function is fully implemented and tests pass.

Agents MUST NOT report `status: complete` if their functions are BUILD STUBs. The completion report should list each BUILD STUB explicitly.

**Protocol changes required:** `agents/wave-agent.md`, `agent-template.md` Field 9 (status values).

---

### ✅ Short IMPL-Referencing Prompts for Wave Agent Launches — SHIPPED (saw-skill v0.7.2)

**Current state:** The orchestrator copy-pastes the full agent brief (file ownership table, interface contracts, verification gate, completion report format) into each `Agent` tool call's `prompt` parameter. Each prompt is 800–1200 tokens, generated token-by-token before any tool calls fire.

**Problem:** Prompt generation is the bottleneck when launching parallel wave agents, not API latency. All 5 agents in a wave are launched in a single message, but each long prompt must be fully generated in sequence before the tool calls fire. A 1000-token prompt takes 5–10 seconds to generate; 5 agents × 1000 tokens = 5000 tokens of generation before anything executes.

**Proposed:** Use short IMPL-referencing prompts instead of copy-pasting the brief:

```
Read the agent prompt for Wave 2 Agent F from the IMPL doc at:
  /path/to/docs/IMPL/IMPL-feature.md

Find the section "### Agent F — ..." and follow it exactly.
The worktree branch wave2-agent-F is already checked out at
.claude/worktrees/wave2-agent-F. Begin immediately.
```

~60 tokens per agent vs ~1000. For 5 parallel agents: 300 tokens total vs 5000, firing ~10–15× faster. The agent reads the full brief from the IMPL doc on its first tool call — no information is lost.

**Protocol changes required:** `saw-skill.md` orchestration section — note that wave agent `prompt` parameters should be short IMPL-referencing stubs, not copy-pasted briefs. The IMPL doc is already the single source of truth (I4); the prompt should reference it, not duplicate it.

---

### `go.work` Recommendation for Cross-Repo Worktree LSP

**Current state:** When the orchestrating repo and target repo are different Go modules, wave agents working in worktrees of the target repo get LSP errors for cross-repo imports because the `replace` directive in `go.mod` points to a path that doesn't match the worktree layout.

**Proposed:** Add a note to `saw-worktree.md`:

> "For Go cross-repo waves: if the target repo uses a `replace` directive to point at the engine repo, consider creating a `go.work` file at the workspace root that includes both modules. This eliminates LSP 'module not found' noise in agent worktrees and improves IDE diagnostics without affecting production builds."

**Protocol changes required:** `saw-worktree.md` cross-repo mode section.

---

## IMPL Doc Length Management

As IMPL docs accumulate completion reports across many waves, they can grow large enough to create context pressure for agents reading them. Three complementary mitigations:

### History Sidecar (Completion Report Archiving)

**Problem:** Completion reports are verbose (file lists, gate outputs, deviation notes). After a wave merges, these reports are historical record — no future agent needs them. Yet they stay in the main IMPL doc, growing it with each wave.

**Proposed:** Once a wave merges successfully, the Orchestrator appends that wave's completion reports to a sidecar file (`docs/IMPL/IMPL-slug-history.md`) and replaces the verbose sections in the main doc with a one-line summary:

```markdown
### Agent A - Completion Report
<!-- compressed: status=complete, files=3, gate=pass, 2026-03-08 -->
```

The main doc stays bounded at roughly `(base_size) + (N_waves × ~50 bytes)` regardless of wave count. The history file holds the full record for auditing and is never passed as agent context.

**Protocol changes required:** `saw-teams-merge.md` post-merge procedure — add "compact completed wave reports" step after verification passes.

---

### Structured Doc Splitting

**Problem:** All IMPL doc concerns live in one file. Scaffold contents in particular can be large and are never re-read after Wave 1.

**Proposed:** Split by concern at creation time:
- `IMPL-slug.md` — live state: wave structure, file ownership, interface contracts, quality gates, current wave
- `IMPL-slug-scaffolds.md` — scaffold file contents (extracted by Scaffold Agent, referenced from main doc)
- `IMPL-slug-log.md` — append-only completion reports and deviation records

Agents receive only the slices relevant to them (E23 extraction becomes trivial — the right content is already in a separate file).

**Protocol changes required:** `protocol/message-formats.md` — IMPL doc format note on optional split layout; `agents/scaffold-agent.md` — write scaffold contents to sidecar.

---

### IMPL Doc Size Gate

**Problem:** Doc growth is currently invisible. There is no enforcement point that catches a bloated IMPL doc before agents consume it.

**Proposed:** Add a `validate-impl.sh` check: if the doc exceeds a configurable byte threshold (default 50 KB), emit a warning recommending history compaction. Not a hard failure — informational only, surfaced at the E16 validation step and in the web UI reviewer.

**Protocol changes required:** `scripts/validate-impl.sh` — size check with configurable threshold; `saw-teams-skill.md` — surface size warning in E16 validation output.

---

## IMPL-Level Parallelism (Concurrent Feature Execution)

**Current state:** SAW enforces disjoint file ownership within a wave (I1), but IMPL docs are always executed serially. One feature completes and merges before the next begins.

**Problem:** The serial constraint is too conservative. Two features that touch completely different files could execute in parallel — their wave agents would never conflict. But today SAW has no way to express or enforce this, so everything queues.

**The insight:** SAW already solves this problem one level down. I1 enforces disjoint ownership across agents within a wave. The same invariant, lifted one level up, gives you disjoint ownership across concurrent IMPL docs. The constraint is identical — the scope is wider.

**Proposed architecture:**

```
Current:  agents → waves → IMPL docs (always serial)
Next:     agents → waves → IMPL docs (parallel where disjoint, sequenced where overlapping)
```

**Cross-IMPL ownership registry:** Before any IMPL's Wave 1 launches, register its complete file ownership set. A file locked by IMPL-A cannot enter any wave of IMPL-B until A merges that file. The lock is file-granular, not IMPL-granular — IMPL-A and IMPL-B can run concurrently if their file sets are disjoint; they sequence only on the files they share.

**IMPL dependency graph (computed, not declared):** The meta-orchestrator computes which IMPLs block which others from their file ownership intersection. No manual dependency declarations needed — if IMPL-A owns `execution-rules.md` and IMPL-B also needs it, IMPL-B's waves that touch that file wait until IMPL-A releases it. IMPL-B's waves on unrelated files proceed immediately.

**Meta-orchestrator:** A new protocol layer above the current orchestrator. Manages IMPL lifecycle the same way the orchestrator manages wave lifecycle:
- Tracks active IMPLs and their file lock sets
- Computes unblocked IMPLs (no file conflicts with any running IMPL)
- Launches unblocked IMPLs in parallel
- Releases file locks as IMPLs merge; re-evaluates what's unblocked

**Partial-overlap case:** The common case. IMPL-A and IMPL-B both need `execution-rules.md`. Resolution: whichever IMPL starts first locks the file. The other IMPL's wave that needs it is WAVE_PENDING until the lock releases. Waves in IMPL-B that don't need the locked file are unblocked and run in parallel.

**Concrete example (what triggered this):**
- `IMPL-context-and-failure-taxonomy` — edits `execution-rules.md`, `message-formats.md`, `wave-agent.md`, `scout.md`, `agent-template.md`, `saw-skill.md`
- `IMPL-quality-gates` — edits `execution-rules.md`, `message-formats.md`, `scaffold-agent.md`, `scout.md`, `saw-skill.md`

With file-granular locking: IMPL-A runs first, locks those six files. IMPL-B waits on shared files but could immediately run any wave that only touches `scaffold-agent.md` (which IMPL-A doesn't own). After IMPL-A merges, IMPL-B's blocked waves resume. Net result: faster than serial, safe by construction.

**Protocol changes required:**
- New protocol layer: `protocol/meta-orchestrator.md` — IMPL registry, file lock semantics, dependency graph computation, unblocked IMPL selection
- `protocol/invariants.md` — new I7: no two concurrently active IMPLs may have overlapping file ownership for any currently-running wave
- `protocol/message-formats.md` — IMPL status field: `active | waiting_on_lock | complete`
- `protocol/execution-rules.md` — E-rules for lock acquisition, release, and partial-overlap sequencing
- `implementations/claude-code/prompts/saw-skill.md` — meta-orchestrator invocation mode (`/saw multi` or automatic when multiple IMPLs are active)

**Relationship to existing invariants:** I1–I6 are unchanged. They govern agent behavior within a wave. I7 governs IMPL behavior across features. The two levels compose: I1 ensures agents within a wave don't conflict; I7 ensures waves across features don't conflict.

---

**Insight:** Every E-rule and invariant in the protocol is a retroactive constraint — built after an agent produced something malformed and we caught it post-hoc. Structured output parsing is the first time we push a constraint *before* generation. The next phase extends this: the IMPL doc stops being a document that *describes* coordination and becomes a program that *is* coordination.

**Phase 1 — Constraint-solving validator (immediate next step after structured outputs):**

Right now `sawtools validate` checks rules one at a time. Replace it with a constraint solver: model the manifest as a CSP — agents, files, and dependencies as variables and constraints — and *prove* the execution plan is correct rather than checking it's not-wrong. Topological sort over the dep graph catches I2 violations today; extending it to prove optimal wave grouping is a small step. The validator stops being a linter and becomes a proof system.

This also means Scout stops making scheduling decisions. Scout declares *what* agents need (file dependencies, interface dependencies). The solver derives *when* they run — which wave, which agents are parallel. The `wave:` numbers in `file_ownership` are computed, not guessed. I2_WAVE_ORDER errors become impossible because wave assignment is never hand-written.

**Phase 2 — Interface contracts as compiled types:**

The Scaffold Agent already proto-implements this — it materializes contracts as stub Go files. The missing piece: after scaffolds are written, compile a verification program that proves the stubs implement the contracts. A mismatched interface contract is caught before any Wave agent sees it, not after merge when tests fail.

**Phase 3 — Pre-execution simulation:**

Model each agent as a transaction over its owned files. Before worktrees are created, simulate the execution: prove that no two transactions conflict, that all interface consumers have exactly one producer, that every agent's dependencies are satisfied before it runs. This is database isolation theory (serializable transaction isolation) applied to agent coordination.

The full vision: Scout is a dependency mapper, not a scheduler. The scheduler is a deterministic program derived from the dependency graph. The validator is a proof system. Agents execute transactions. The IMPL doc is a formal specification that can be run, simulated, and verified before any real work happens.

**Protocol changes required:**
- `sawtools validate` → constraint solver (replaces rule-by-rule checking with CSP proof)
- `message-formats.md` — `wave:` numbers in file_ownership become optional (solver derives them)
- `agents/scout.md` — Scout emits dependency graph only; does not assign wave numbers
- New `protocol/solver.md` — documents the wave-derivation algorithm and constraint model

---

## SDK Branch as Generated Build Artifact

**Current state:** The `scout-and-wave` repo has two long-lived branches:
- `main` — natural language only. Refers to the `saw` CLI throughout (e.g., `saw validate`, `saw create-worktrees`).
- `sdk` — SDK-coupled. All `saw` references replaced with `sawtools` (the Go toolkit binary). This branch is hand-maintained: every commit to `main` that touches an NL reference must be ported to `sdk` manually.

**Problem:** The `main` → `sdk` substitutions are entirely mechanical. Every `saw ` becomes `sawtools `, every "run `saw`" becomes "run `sawtools`", with occasional CLI flag and path adjustments. There is no semantic difference — it is a textual transformation. Hand-maintaining two branches for a mechanical transformation means:
- Every PR requires a parallel `sdk` version
- Merge discipline must be enforced by convention, not tooling
- Contributors must know about the split and remember to port changes

**Proposed:** Treat the `sdk` branch as a **generated build artifact**, not a hand-edited branch. Define a substitution manifest (e.g., `sdk-substitutions.yaml`) that specifies:

```yaml
substitutions:
  - pattern: "run `saw "
    replace: "run `sawtools "
  - pattern: "exec saw "
    replace: "exec sawtools "
  - pattern: "`saw "
    replace: "`sawtools "
  # ... other mechanical substitutions

file_includes:
  - "implementations/claude-code/**/*.md"
  - "implementations/claude-code/**/*.sh"

# Optionally: files that need non-mechanical edits (override substitution for specific files)
overrides:
  - file: "implementations/claude-code/scripts/install.sh"
    manual: true   # This file is maintained manually in both branches
```

A CI step (GitHub Actions) generates the `sdk` branch on every push to `main`:
1. Checkout `main`
2. Apply all substitutions to all included files
3. Apply any manual overrides
4. Force-push the result to `sdk`

The `sdk` branch becomes a read-only generated artifact — never committed to directly. PRs target `main` only. The substitution manifest is the diff between `main` and `sdk`.

**Benefits:**
- `main` is the only branch contributors touch
- `sdk` is always up-to-date (generated on every push, not manually ported)
- Substitution rules are explicit and auditable (the manifest makes the transformation inspectable)
- Adding new binary-split variants in the future (e.g., a different package manager name) requires only a new manifest entry, not a new hand-maintained branch

**Long-term extension:** If the binary split ever deepens (e.g., different config file paths, different env vars), the manifest grows but the workflow is unchanged. Multiple "flavor" branches (sdk, sdk-docker, sdk-ci) could each have their own manifest.

**Implementation scope:** CI/CD only (`scout-and-wave` repo). No protocol changes required — the protocol content is unchanged; only the tooling that generates the SDK-coupled distribution changes.

**Protocol changes required:** None for the protocol itself. New files:
- `scripts/generate-sdk-branch.sh` — applies the substitution manifest and commits to `sdk`
- `.github/workflows/generate-sdk.yml` — triggers on push to `main`
- `sdk-substitutions.yaml` — the substitution manifest

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

**Engine extraction complete (2026-03-08).** `scout-and-wave-go` is the standalone engine module (agent runner, protocol parser, orchestrator, git, worktree management, types). `scout-and-wave-web` is the web UI + `saw` CLI server, importing the engine via Go module. The `/saw` Claude Code skill and the web UI are both clients on top of it.
