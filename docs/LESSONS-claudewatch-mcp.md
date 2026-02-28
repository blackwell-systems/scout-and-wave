# SAW Execution Log: claudewatch MCP Server

**Project:** claudewatch — MCP server for session self-awareness
**Date:** 2026-02-28
**Purpose:** Capture raw execution experience for article writeups and pattern improvements.
**Related:** See `docs/LESSONS-ROUND4.md` for brewprune data.

---

## Pre-Scout Context

### Feature Description
MCP stdio server exposing claudewatch data as tools Claude Code can query during a session. Implemented in Go as a new `claudewatch mcp` subcommand. Three tools in v1:
- `get_session_stats` — tokens, cost, duration for current session
- `get_cost_budget` — daily spend vs configured budget
- `get_recent_sessions` — last N sessions with cost/friction/duration

### Suitability Check Result
**Verdict:** SUITABLE WITH CAVEATS
**Key finding:** Tool list scope was open. Resolved by scoping to 3 tools before scout.
**Caveat resolved:** With 3 tools, estimated 2-3 agents — borderline for full SAW vs quick mode.
**Decision to proceed:** Go build/test cycle >30s, non-trivial JSON-RPC protocol layer, interfaces definable upfront. Full SAW justified.

### Pre-Scout Questions Resolved
- Tool list: finalized to 3 (session stats, cost budget, recent sessions)
- Language: Go (same binary, all parsers already exist)
- Interface: MCP stdio JSON-RPC (published spec, no investigation needed)
- New subcommand: `claudewatch mcp` via Cobra

---

## Scout Phase

### Start Time
~05:41

### Scout Duration
~10 min (255s actual agent runtime per usage stats)

### Suitability Assessment (from IMPL doc)
**SUITABLE.** All 5 gate questions passed cleanly. No investigation-first items,
no existing code to interfere, clean file decomposition, interfaces fully
specifiable upfront.

Estimated times from scout:
- Scout: ~10 min | Agents: ~25 min | Merge: ~5 min | Total: ~40 min
- Sequential baseline: ~30 min
- Assessment: "marginal on speed; primary value is interface contracts and progress tracking"

### Wave Structure Produced
```
Wave 1: [A] [B]    ← parallel (disjoint files, no shared state)
Wave 2:    [C]     ← sequential (depends on internal/mcp package existing)
```

### Agent Count
3 agents, 2 waves.

### Interface Contracts Defined
Clean. The key coupling point: `NewServer` (Agent A) calls `addTools(s)` (Agent B).
Both live in `package mcp`, different files. Scout resolved the cross-file
function definition issue correctly: Agent A declares the call, Agent B provides
the body. Each agent carries a temporary stub of the other's file so their
worktree compiles independently.

### Surprises / Deviations from Expected Decomposition
- Scout correctly identified that Agent C touches zero existing files (registers
  via `init()` pattern matching other commands) — no cascade candidates require
  modification.
- Scout added `gofmt -l` to the Wave Execution Loop verification gate
  (learned from previous gofmt failures in claudewatch CI). Good pattern absorption.
- Scout estimated build/test cycle as "~1-2s (SQLite CGO-disabled)" which is
  accurate — noted this means speed benefit is low; value is coordination clarity.

---

## Wave Execution

### Wave 1

**Start time:** ~06:00
**Agents launched:** A (JSON-RPC transport) + B (tool handlers), parallel
**Worktree creation:** Pre-creation worked correctly — 3 worktrees confirmed before agent launch
**Agent isolation:** Both agents passed isolation verification on first attempt. No self-healing needed.
**Completion time:** ~06:05 (both ~288s runtime, roughly simultaneous)
**Merge result:** Both agents committed to their branches. CONFLICT on `docs/IMPL-mcp-server.md` (both agents wrote completion reports to same file) and on `jsonrpc.go`/`tools.go` (each carried a stub of the other's file). Resolved by: taking A's real jsonrpc.go, B's real tools.go, manually splicing both completion reports into IMPL doc.
**Post-merge verification:** Failed initially — `newTestServer` helper function declared in both `jsonrpc_test.go` and `tools_test.go` (different signatures). Renamed jsonrpc_test.go version to `newEmptyServer`. All 13 mcp tests pass after fix.
**Out-of-scope dependencies flagged:** None. Both agents stayed within their file ownership.

**New pattern observation:** IMPL doc conflicts are inevitable when both agents write completion reports to the same file. The current merge procedure handles `--ours`/`--theirs` for code files cleanly, but the IMPL doc requires manual splicing every time. Consider pre-splitting completion report sections into separate files, or having agents write to agent-specific files (`docs/IMPL-mcp-server-agent-a.md`) that the orchestrator assembles post-wave.

### Wave 2

**Start time:** ~06:10
**Agents launched:** C (Cobra subcommand), solo
**Worktree creation:** Pre-creation worked, 1 worktree confirmed before launch
**Agent isolation:** Passed on first attempt
**Completion time:** ~06:12 (104s runtime)
**Merge result:** Clean — no conflicts. Agent C committed to branch; `git merge --no-ff` succeeded immediately. Agent C wrote completion report to IMPL doc without conflict (was the only one touching it in Wave 2).
**Post-merge verification:** All tests pass, gofmt clean, smoke test confirmed MCP wire protocol working (`initialize` and `tools/list` both return correct JSON-RPC responses).

---

## Observations

### What worked well
- Pre-creation of worktrees worked perfectly both waves — no isolation failures
- Agent isolation verification passed first attempt for all 3 agents
- Agent C merge was completely clean (no conflicts at all)
- Agents read each other's completion reports and confirmed interface contracts before writing code (Agent C explicitly noted this)
- Scout's interface contracts were accurate — no deviations reported by any agent
- `gofmt -l` in the verification gate caught nothing (no formatting issues this run)
- Smoke test confirmed real MCP wire protocol works end-to-end

### What required manual intervention
- **IMPL doc conflict resolution (Wave 1):** Both Agent A and Agent B wrote completion reports to `docs/IMPL-mcp-server.md`. Required manual `git checkout --theirs` + Edit to splice both reports into the merged file. Took ~5 min.
- **`jsonrpc.go`/`tools.go` stub conflict (Wave 1):** Each agent carried a stub of the other's file. Resolved cleanly with `git checkout --ours`/`--theirs` but required understanding which version to keep.
- **`newTestServer` name collision (post-Wave-1):** Both test files declared a helper with the same name but different signatures. Required renaming one (`newEmptyServer`). Classic post-merge integration issue that individual agent gates couldn't catch.
- **IMPL doc pre-commit required:** The IMPL doc was untracked in main when the first merge ran — `git merge` aborted with "untracked file would be overwritten." Had to commit it first. SAW orchestrator should commit the IMPL doc immediately after scout writes it.

### Unexpected issues
- None beyond the above. The `addTools` cross-file coupling (A calls B's function) worked exactly as designed — no surprise at merge.

### Time estimates vs actuals
Scout estimated: ~40 min total | Actual: ~25 min wall-clock
- Scout: ~10 min (accurate)
- Wave 1 agents: ~5 min parallel (accurate)
- Wave 1 merge + fix: ~10 min (scout estimated 5 min — IMPL doc conflict and name collision added time)
- Wave 2 agent: ~2 min (scout estimated 5 min — was faster)
- Wave 2 merge: ~1 min (clean)
Sequential baseline estimated: ~30 min | Likely accurate given task complexity

---

## Pattern Observations for Enhancement

1. **IMPL doc conflict is structural, not accidental.** When two agents both write completion reports to the same file, a merge conflict is guaranteed — not a failure, just overhead. The current workaround (manual splice) works but adds 5 min per wave with ≥2 agents. Options: (a) agents write to separate files (`docs/reports/agent-a.md`) that the orchestrator assembles, or (b) orchestrator merges reports sequentially rather than in parallel. Option (a) is cleaner.

2. **IMPL doc must be committed before first merge.** If the scout writes the IMPL doc and the orchestrator doesn't commit it before running `git merge`, git will abort with "untracked file would be overwritten." The skill should explicitly commit the IMPL doc as the last step of the scout phase, not leave it untracked.

3. **Stub file conflicts are predictable and mechanical.** Both agents carry stubs of each other's files. The resolution rule is always: keep the file owned by the agent who just merged. Could be automated in the merge script: "for each conflicted file, if it's in this agent's ownership list, use `--theirs`; otherwise use `--ours`."

4. **Name collision in shared test package.** `newTestServer` declared in both test files — both agents wrote the same natural helper name independently. The IMPL doc could specify shared test helper names upfront in the Interface Contracts section to prevent this.

5. **Wave 2 was faster and cleaner than Wave 1 in every dimension.** Solo agent, single file, no cross-file stubs, no conflicts. Suggests that Wave 2+ overhead is much lower than Wave 1 when Wave 1 handles all the cross-agent coordination complexity.

---

## Final Result

**Total wall-clock time (SAW):** ~25 min
**Estimated sequential time:** ~30 min
**Time saved:** ~5 min (modest — value was coordination clarity, not speed)
**Lines added:** ~600 (jsonrpc.go, tools.go, tests, mcp.go, IMPL doc)
**Files touched:** 6 new files, 0 existing files modified
**Merge conflicts:** 3 (all in docs/IMPL-mcp-server.md — completion report splicing), 2 code file conflicts (stub vs real — resolved mechanically)
**Integration issues caught post-merge:** 1 (`newTestServer` name collision)
