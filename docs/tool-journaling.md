# Tool Journaling for Compaction Safety

## Overview

Tool journaling is an **external log observer pattern** that preserves agent execution context across Claude Code's context window compaction events. When long-running wave agents approach their context limits, Claude Code automatically compacts the conversation history, removing older tool use/result blocks. This can leave agents disoriented — they lose visibility into what they've already done, which files they've modified, and what test results they've seen.

The journal system solves this by:
1. **Tailing Claude Code session logs** (`.claude/sessions/*.jsonl`) in real-time
2. **Extracting tool execution history** into a persistent, indexed format
3. **Generating context summaries** that are injected into agent prompts before launch
4. **Providing recovery checkpoints** for debugging failed agents

This is not a backend modification — it's an external observer that requires zero changes to Claude Code's internal architecture.

## Why It Exists

**Problem:** Context compaction in long-running waves erases agent memory. An agent that has spent 45 minutes implementing a feature, running tests, and iterating on failures can suddenly lose all that history when Claude Code compacts the conversation. The next tool call after compaction operates with amnesia — no knowledge of prior work, no awareness of files already modified, no memory of test failures already encountered.

**Solution:** The journal observer runs alongside the wave execution loop. Before launching each agent, the orchestrator:
1. Starts the journal observer for that agent (`journal.NewObserver(projectRoot, agentID)`)
2. Generates a context summary from the journal (`observer.GenerateContext()`)
3. Prepends the summary to the agent's prompt as a `## Prior Work` section

When Claude Code compacts the agent's conversation, the journal-generated context remains in the prompt — the agent retains memory of its own execution history.

**When recovery happens:** Automatic, before every agent launch. The orchestrator calls `observer.Sync()` to update the journal index, then `observer.GenerateContext()` to produce the markdown summary. No manual intervention required.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Claude Code Session                                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Wave Agent (wave1-agent-A)                          │ │
│ │ • Read, Write, Edit, Bash tool calls                │ │
│ │ • Compaction events erase history after ~30-45 min │ │
│ └─────────────────────────────────────────────────────┘ │
│                        │                                 │
│                        │ (logs to)                       │
│                        ▼                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ .claude/sessions/1a2b3c4d.jsonl                     │ │
│ │ {"type":"tool_use","name":"Read",...}               │ │
│ │ {"type":"tool_result","tool_use_id":"...",...}      │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         │ (tailed by)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ JournalObserver (external process)                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ .saw-state/journals/wave1/agent-A/                  │ │
│ │ ├── cursor.json        (read position tracker)      │ │
│ │ ├── index.jsonl        (full tool history)          │ │
│ │ ├── context.md         (generated summary)          │ │
│ │ ├── recent.jsonl       (last 50 entries, fast scan) │ │
│ │ └── results/           (full tool output files)     │ │
│ │     ├── tool_001.txt                                │ │
│ │     └── tool_002.txt                                │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         │ (generates)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Agent Prompt (before launch)                            │
│ ## Prior Work                                           │
│ You have already modified:                              │
│ - pkg/journal/observer.go (created)                     │
│ - pkg/journal/observer_test.go (created)                │
│                                                          │
│ Test results:                                           │
│ - TestSync: PASS                                        │
│ - TestGenerateContext: FAIL (line 42: nil pointer)     │
│                                                          │
│ Git commits:                                            │
│ - abc1234 "implement journal sync"                      │
└─────────────────────────────────────────────────────────┘
```

**External observer pattern:** The journal system never modifies Claude Code's session logs. It reads them as an external observer, extracting tool execution events into its own index. This design keeps the journal system decoupled — it can be disabled, upgraded, or debugged without affecting Claude Code's operation.

## Journal Structure

### Directory Layout

All journal state lives in `.saw-state/journals/<wave>/<agent>/`:

```
.saw-state/
└── journals/
    └── wave1/
        ├── agent-A/
        │   ├── cursor.json       # Read position in session log
        │   ├── index.jsonl       # Full tool execution history
        │   ├── context.md        # Generated summary for prompt injection
        │   ├── recent.jsonl      # Last 50 entries (fast scan for debugging)
        │   ├── results/          # Full tool outputs (>800 chars)
        │   │   ├── tool_001.txt  # Read tool output
        │   │   └── tool_002.txt  # Bash tool output
        │   └── checkpoints/      # Named snapshots
        │       ├── pre-test-run.tar.gz
        │       └── post-merge.tar.gz
        └── agent-B/
            └── ... (same structure)
```

### File Formats

**cursor.json** — Tracks read position in Claude Code's session log:
```json
{
  "session_file": "1a2b3c4d.jsonl",
  "offset": 2048
}
```

**index.jsonl** — One line per tool use/result pair:
```json
{"ts":"2026-03-10T19:30:15Z","kind":"tool_use","tool_name":"Read","tool_use_id":"toolu_01ABC","input":{"file_path":"/path/to/file.go"}}
{"ts":"2026-03-10T19:30:16Z","kind":"tool_result","tool_use_id":"toolu_01ABC","content_file":"results/tool_001.txt","preview":"package journal\n\nimport...","truncated":true}
```

**context.md** — Generated summary for agent prompt injection:
```markdown
## Prior Work

You are resuming work on Wave 1, Agent A (branch: wave1-agent-A).

### Files Modified
- pkg/journal/observer.go (created, 234 lines)
- pkg/journal/observer_test.go (created, 89 lines)

### Test Results
- TestSync: PASS
- TestGenerateContext: FAIL
  Error: line 42: nil pointer dereference in extractFilesModified

### Git Commits
- abc1234 (2026-03-10 19:25): implement journal sync
- def5678 (2026-03-10 19:40): add context generation

### Recent Activity (last 10 tool calls)
1. Read pkg/journal/types.go
2. Write pkg/journal/observer.go
3. Bash: go test ./pkg/journal/...
4. Read pkg/journal/observer_test.go
5. Edit pkg/journal/observer.go (fix nil check)
...
```

**recent.jsonl** — Last 50 entries from index.jsonl (for fast debugging without scanning full history).

**results/** — Full tool outputs for entries where `truncated: true` in index.jsonl (preview is first 800 chars; full output lives here).

## Context Recovery

### How Context is Generated

The `GenerateContext()` function analyzes the journal index and produces a markdown summary with:

1. **Files modified** — Extracted from Write/Edit tool calls and `git diff` outputs
2. **Test results** — Parsed from Bash tool calls that ran test commands (exit codes + failure messages)
3. **Git commits** — Extracted from `git log` and `git commit` outputs
4. **Recent activity** — Last 10 tool calls (tool name + input summary)

**Filtering logic:**
- Only includes tool calls from the current wave/agent (filters by directory/branch context)
- Prioritizes failures over successes (failed tests appear before passed tests)
- Deduplicates files (if a file was modified 5 times, shows only the latest state)

### When Context is Injected

**Before agent launch:** The orchestrator runs:
```go
observer := journal.NewObserver(projectRoot, agentID)
observer.Sync() // Update index from session log
contextMd, _ := observer.GenerateContext()
prompt := contextMd + "\n\n" + agentPrompt // Prepend to agent brief
```

**During execution:** The journal observer syncs periodically (every 30 seconds) to keep the index up-to-date. If the agent is re-launched mid-wave (e.g., after a transient failure), the context regenerates with the latest state.

**No re-injection during compaction:** The context is injected once, at agent launch. Claude Code's compaction events don't trigger re-injection — the context summary stays in the prompt as static text. This is intentional: re-injecting after every compaction would be expensive and unnecessary (the summary already captures the full history up to launch).

## Debugging Failed Agents

### CLI Command: `sawtools debug-journal`

When an agent fails mid-wave, inspect its journal to understand what it did before failure:

```bash
# Full summary (same as context.md)
sawtools debug-journal wave1/agent-A

# Show only failed tool calls
sawtools debug-journal wave1/agent-A --failures-only

# Show last N entries
sawtools debug-journal wave1/agent-A --last 20

# Export as HTML timeline (opens in browser)
sawtools debug-journal wave1/agent-A --export timeline.html
```

**Output format:**
```
=== Journal Summary: wave1/agent-A ===
Branch: wave1-agent-A
Total entries: 142
Duration: 45m 32s

Files Modified:
  pkg/journal/observer.go (created, 234 lines)
  pkg/journal/observer_test.go (created, 89 lines)

Test Results:
  PASS: TestSync (3 runs)
  FAIL: TestGenerateContext (line 42: nil pointer)

Recent Activity (last 10):
  19:55:12 | Read | pkg/journal/types.go
  19:55:18 | Write | pkg/journal/observer.go
  19:56:02 | Bash | go test ./pkg/journal/...
  ...
```

**Failures-only mode** (`--failures-only`):
- Filters to Bash tool calls with non-zero exit codes
- Filters to Read tool calls that returned errors
- Shows full error output (no truncation)

**HTML timeline export** (`--export timeline.html`):
- Generates an interactive timeline with collapsible tool outputs
- Color-codes by tool type (Read = blue, Write/Edit = green, Bash = orange)
- Highlights failures in red
- Embeds full tool outputs inline (expands on click)

### Manual Journal Inspection

For deep debugging, inspect journal files directly:

```bash
# View full index (JSONL format)
cat .saw-state/journals/wave1/agent-A/index.jsonl

# View last 50 entries (fast scan)
cat .saw-state/journals/wave1/agent-A/recent.jsonl

# View specific tool output
cat .saw-state/journals/wave1/agent-A/results/tool_042.txt

# Check cursor position
cat .saw-state/journals/wave1/agent-A/cursor.json
```

## Checkpoints

Checkpoints are named snapshots of journal state at key milestones. Use them to restore an agent's context to a known-good state.

### Creating Checkpoints

**Automatic checkpoints** (created by orchestrator):
- `pre-wave` — Before agent launch
- `post-commit` — After agent commits to worktree branch
- `pre-merge` — Before merge to main

**Manual checkpoints** (created by user):
```bash
sawtools checkpoint wave1/agent-A pre-test-run
```

**What's captured:**
- Full `index.jsonl` at checkpoint time
- `context.md` snapshot
- Cursor position
- Checkpoint metadata (name, timestamp, entry count)

Checkpoint files are stored as `.tar.gz` archives in `.saw-state/journals/<wave>/<agent>/checkpoints/`.

### Listing Checkpoints

```bash
sawtools list-checkpoints wave1/agent-A
```

**Output:**
```
=== Checkpoints: wave1/agent-A ===
1. pre-wave (2026-03-10 19:30:15, 0 entries)
2. post-first-commit (2026-03-10 19:45:22, 67 entries)
3. pre-test-run (2026-03-10 19:50:10, 89 entries)
4. pre-merge (2026-03-10 20:15:30, 142 entries)
```

### Restoring Checkpoints

**Use case:** Agent diverged into a bad path after a test failure. Restore to the checkpoint before the test run, revise the approach, and re-launch.

```bash
sawtools restore-checkpoint wave1/agent-A pre-test-run
```

**What happens:**
1. Current journal state is archived (as `backup-<timestamp>.tar.gz`)
2. Checkpoint archive is unpacked into the journal directory
3. `context.md` is regenerated from the restored index
4. Agent can be re-launched with the restored context

**Warning:** Restoring a checkpoint does not revert code changes or git commits — it only restores the journal state. You must manually revert the worktree to the desired commit before re-launching the agent.

## Archive Policy

After a wave merges successfully, journals are archived to save disk space.

### Automatic Archiving

The orchestrator calls `observer.Archive()` after merge verification passes:

```bash
sawtools cleanup "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
```

This command:
1. Compresses each agent's journal directory into `.saw-state/archives/wave<N>-agent-<ID>.tar.gz`
2. Removes the original journal directory
3. Logs archive location to stdout

**Archive location:** `.saw-state/archives/` in project root.

### Retention Policy

Archives are retained based on `saw.config.json` settings:

```json
{
  "journal": {
    "retention_days": 30,
    "auto_archive": true
  }
}
```

- `retention_days` — Archives older than this are deleted (default: 30)
- `auto_archive` — Enable/disable automatic archiving on merge (default: true)

**Manual cleanup:**
```bash
sawtools clean-archives --older-than 30
```

This scans `.saw-state/archives/` and deletes archives older than 30 days.

### Restoring from Archive

If you need to inspect a past wave's journal after it's been archived:

```bash
sawtools restore-archive wave1-agent-A
```

This unpacks the archive back into `.saw-state/journals/wave1/agent-A/` for inspection. The original archive is preserved.

## Configuration

All journal settings live in `saw.config.json` (project-local) or `~/.claude/saw.config.json` (global default):

```json
{
  "journal": {
    "enabled": true,
    "retention_days": 30,
    "auto_archive": true,
    "sync_interval_seconds": 30,
    "max_context_entries": 50,
    "max_preview_chars": 800
  }
}
```

**Settings:**
- `enabled` — Enable/disable journal observer (default: true)
- `retention_days` — Archive retention in days (default: 30)
- `auto_archive` — Archive journals after successful merge (default: true)
- `sync_interval_seconds` — How often to sync journal from session log (default: 30)
- `max_context_entries` — Max entries to include in context.md "Recent Activity" section (default: 50)
- `max_preview_chars` — Max chars to include in index.jsonl preview field (default: 800)

**Disabling journaling:**
```json
{
  "journal": {
    "enabled": false
  }
}
```

When disabled, agents run without context recovery. This is not recommended for long-running waves but may be useful for debugging orchestrator issues.

## See Also

- [Architecture](./architecture.md) — Full system architecture with journal subsystem diagram
- [Orchestrator Skill](../implementations/claude-code/prompts/saw-skill.md) — How orchestrator loads journals before agent launch
- [Protocol Execution Rules](../protocol/execution-rules.md) — E19 agent failure handling
