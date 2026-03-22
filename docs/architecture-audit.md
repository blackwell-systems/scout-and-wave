# Architecture.md Audit Report

**Date:** 2026-03-22
**Audited file:** `docs/architecture.md`
**Verified against:** All 3 repos at HEAD

## Summary

- Claims verified: 48
- Accurate: 30
- Inaccurate: 8
- Outdated: 4
- Missing from doc: 6

---

## Inaccurate Claims

### 1. Journal file structure: `results/` vs `tool-results/`

**Doc says (line 159):**
```
├── results/         (full tool outputs)
```

**Reality:** The directory is named `tool-results/`, not `results/`. Confirmed in `pkg/journal/observer.go`, `pkg/journal/doc.go`, and multiple test files.

**Fix:** Change `results/` to `tool-results/` in both the journal diagram (line 159) and the directory structure (line 360 area).

### 2. Journal file: `recent.jsonl` vs `recent.json`

**Doc says (line 158):**
```
├── recent.jsonl     (last 50 entries)
```

**Reality:** The file is `recent.json` (a JSON array, not JSONL), and it holds the last 30 entries, not 50. Confirmed in `pkg/journal/observer.go`: `RecentPath: filepath.Join(journalDir, "recent.json")` and `updateRecent maintains a sliding window of the last 30 tool entries`.

**Fix:** Change `recent.jsonl` to `recent.json` and `last 50 entries` to `last 30 entries`.

### 3. Journal directory structure in "Directory Structure" section uses `journals/` subdirectory

**Doc says (lines 355-362):**
```
.saw-state/
├── journals/
│   └── wave1/
│       ├── agent-A/
```

**Reality:** Based on the actual `.saw-state/` directory in the protocol repo and the journal code, the structure is `.saw-state/wave1/agent-A/` (no `journals/` intermediate directory). The `pkg/journal/doc.go` confirms: `.saw-state/wave{N}/agent-{ID}/`.

**Fix:** Remove the `journals/` level from the directory tree.

### 4. Config file `saw.config.json` structure is wrong

**Doc says (lines 377-399):** Config has `journal` section with `enabled`, `retention_days`, `auto_archive`, `sync_interval_seconds`, `max_context_entries`, `max_preview_chars`, and a `quality_gates` section with `default_level`, `fail_on_stubs`.

**Reality:** Actual config files in all 3 repos have a different structure:
```json
{
  "repos": [...],
  "repo": { "path": "" },
  "agent": { "scout_model": "", "wave_model": "", ... },
  "quality": { "require_tests": false, "require_lint": false, "block_on_failure": false },
  "appearance": { "theme": "dark" }
}
```
- No `journal` section exists in any config file
- `quality_gates` is actually `quality` with different fields (`require_tests`, `require_lint`, `block_on_failure` instead of `default_level`, `fail_on_stubs`)
- Agent model fields are accurate but documented values (`claude-sonnet-4-5`) are outdated (actual values use `claude-sonnet-4-6`, `claude-opus-4-6`, `bedrock:` prefixes)
- Missing: `repos` array, `repo` object, `appearance` section
- Config has no `critic_model` or `planner_model` in the documented schema (though `planner_model` appears in the protocol repo's config)

**Fix:** Replace entire config example with actual structure.

### 5. sawtools command list is incomplete and partially wrong

**Doc says (lines 90-112):** Lists ~15 commands organized in 4 categories.

**Reality:** `sawtools --help` shows **71 commands**. The doc lists most of the original commands correctly, but:
- Missing ~56 commands including: `amend-impl`, `analyze-deps`, `analyze-suitability`, `assign-agent-ids`, `build-retry-context`, `check-deps`, `check-impl-conflicts`, `check-program-conflicts`, `check-type-collisions`, `cleanup-stale`, `create-program`, `daemon`, `detect-cascades`, `detect-scaffolds`, `diagnose-build-failure`, `extract-commands`, `finalize-impl`, `finalize-tier`, `finalize-wave`, `freeze-check`, `freeze-contracts`, `import-impls`, `interview`, `journal-context`, `journal-init`, `list-programs`, `mark-program-complete`, `metrics`, `populate-integration-checklist`, `prepare-agent`, `prepare-wave`, `program-execute`, `program-replan`, `program-status`, `query`, `resume-detect`, `retry`, `run-critic`, `run-review`, `run-scout`, `run-wave`, `set-completion`, `set-critic-review`, `set-impl-state`, `solve`, `tier-gate`, `update-agent-prompt`, `validate-integration`, `validate-program`, `validate-scaffold`, `validate-scaffolds`, `verify-hook-installed`, `verify-install`, and more.
- `run-wave` exists but doc lists it under "Wave execution" -- accurate
- `update-context` command exists -- accurately listed

**Fix:** Either expand the command list significantly or change the framing to "Key commands include:" with a note that `sawtools --help` shows the full list of 71 commands.

### 6. "See Also" links reference incorrect relative paths

**Doc says (line 404):** `[Protocol Invariants](../protocol/invariants.md)`

**Reality:** Since `architecture.md` lives at `docs/architecture.md` and `invariants.md` lives at `protocol/invariants.md`, the relative path `../protocol/invariants.md` is correct from `docs/`. However, the execution rules link says `../protocol/execution-rules.md` -- also correct. The orchestrator skill link `../implementations/claude-code/prompts/saw-skill.md` -- also correct. These are fine.

**(Retracted -- links are actually correct.)**

### 7. Architecture doc mentions `cmd/saw/debug_journal.go` (line 198)

**Doc says:** `cmd/saw/debug_journal.go` -- CLI for debugging failed agents

**Reality:** File exists at this exact path. **Accurate.**

**(Retracted -- this is correct.)**

### 6 (revised). Execution rules referenced as "E1-E41" but the doc says "E1-E41 orchestrator rules"

**Doc says (line 405):** `E1-E41 orchestrator rules`

**Reality:** Execution rules go from E1 through E41, which is accurate. There are also sub-rules like E7a, E16A-C, E21A-B, E23A, E28A-B. The count of 41 top-level rules is correct.

**(Retracted -- accurate.)**

### 6 (final). `context.md` listed in journal structure but generated differently

**Doc says (line 157):**
```
├── context.md       (generated summary)
```

**Reality:** The `context.go` file in the journal package does generate context, but the output file name produced by the `journal-context` CLI command and `GenerateContext()` method writes to `context.md`. This appears to be accurate based on the code. However, it is NOT listed in `pkg/journal/doc.go`'s file structure documentation, which lists only `cursor.json`, `index.jsonl`, `recent.json`, and `tool-results/`. The `context.md` file is generated on-demand rather than maintained as a persistent journal artifact.

**Fix:** Clarify that `context.md` is generated on-demand (not a persistent file).

### 8. `max_context_entries: 50` in journal config

**Doc says:** Journal config has `max_context_entries: 50`.

**Reality:** No journal configuration section exists in any config file. The recent window is hardcoded to 30 entries in the observer code.

**Fix:** Remove journal config section entirely.

---

## Outdated Claims

### 1. Agent model defaults show `claude-sonnet-4-5`

**Doc says (lines 379-385):** All models default to `claude-sonnet-4-5`.

**Reality:** Actual configs use `claude-sonnet-4-6`, `claude-opus-4-6`, and `bedrock:` prefixed model strings. The `4-5` generation is outdated.

### 2. No mention of Program layer

**Doc was written before** the Program manifest system (multi-IMPL coordination) was added. The protocol now has:
- `protocol/program-invariants.md`, `protocol/program-manifest.md`
- ~15 program-related sawtools commands (`create-program`, `program-execute`, `program-replan`, `program-status`, `list-programs`, `finalize-tier`, `tier-gate`, `freeze-contracts`, `check-program-conflicts`, `import-impls`, `mark-program-complete`, etc.)
- `pkg/protocol/program_*.go` (parser, validation, types, discovery, status, etc.)
- Web app has full program UI (`ProgramBoard`, `ProgramList`, `ProgramDependencyGraph`, etc.)

### 3. No mention of Daemon/Queue/Autonomy system

The architecture has evolved to include:
- A daemon loop (`sawtools daemon`) that processes a queue continuously
- Queue management (`sawtools queue` subcommands)
- Autonomy settings for automated execution
- Web UI components: `DaemonControl`, `QueuePanel`, `AutonomySettings`
- API endpoints: `/api/daemon/*`, `/api/queue/*`, `/api/autonomy`

### 4. No mention of Interview Mode

`E39: Interview Mode` was added as a requirements gathering pathway. Includes:
- `sawtools interview` command
- Web UI: `InterviewLauncher` component
- API endpoints: `/api/interview/*`

---

## Missing from Doc

### 1. 20+ Go packages not mentioned

Architecture.md only mentions `pkg/engine`, `pkg/protocol`, `pkg/agent`, `pkg/journal`, and `internal/git`. The Go engine now has **32 packages** under `pkg/`:

Unmentioned packages: `analyzer`, `autonomy`, `builddiag`, `codereview`, `collision`, `commands`, `deps`, `errparse`, `format`, `gatecache`, `git` (pkg-level, separate from internal/git), `hooks`, `idgen`, `interview`, `observability`, `orchestrator`, `pipeline`, `queue`, `resume`, `retry`, `retryctx`, `scaffold`, `scaffoldval`, `solver`, `suitability`, `tools`, `types`, `worktree`

Key omissions:
- **`pkg/orchestrator`** -- the actual orchestrator implementation (state machine, event publishing, wave management)
- **`pkg/types`** -- shared type definitions used across all packages
- **`pkg/worktree`** -- worktree manager
- **`pkg/suitability`** -- codebase suitability analysis
- **`pkg/solver`** -- dependency solver for wave assignment
- **`pkg/observability`** -- event emission system (E40)

### 2. Web app `pkg/service/` layer not mentioned

The web app has a `pkg/service/` package with service objects (`config_service.go`, `impl_service.go`, `wave_service.go`, `scout_service.go`, `program_service.go`, `merge_service.go`) that sit between the API handlers and the engine. This service layer is architecturally significant but undocumented.

### 3. API endpoint count

The web app has **88 route registrations** in `server.go`. The architecture doc does not state an endpoint count, but the web app section is absent entirely -- no mention of the web application's architecture, API structure, or SSE event system.

### 4. Two binaries produced from Go engine repo

The Go repo produces both `sawtools` (CLI toolkit) and `saw` (same binary, identical size of 21MB). The web repo produces its own `saw` binary (24MB, includes embedded web assets). Architecture.md only mentions `sawtools`.

### 5. Web app's dependency on Go engine

The web app (`scout-and-wave-web`) imports `scout-and-wave-go` via a `replace` directive pointing to the local filesystem. This cross-repo dependency pattern is architecturally significant but not documented in architecture.md.

### 6. Multi-backend agent system

The `pkg/agent` package supports 4 backends (Anthropic API, AWS Bedrock, OpenAI-compatible, Claude CLI), which is a significant architectural feature not mentioned in architecture.md.

---

## Verified Accurate

1. **System overview diagram** -- Orchestrator/Scout/Scaffold/Wave/Integration agent roles are correct
2. **IMPL manifest location** -- `docs/IMPL/IMPL-<feature-slug>.yaml` confirmed
3. **Git worktree isolation model** -- `.claude/worktrees/saw/{slug}/wave1-agent-A/` structure confirmed
4. **I1-I6 invariant descriptions** -- All six invariants accurately described, match `protocol/invariants.md`
5. **E19 failure types** -- `transient`, `fixable`, `needs_replan`, `escalate`, `timeout` all confirmed in types
6. **Worktree commands exist** -- `create-worktrees`, `cleanup`, `verify-isolation` all present in sawtools
7. **IMPL management commands exist** -- `list-impls`, `validate`, `extract-context`, `update-status`, `mark-complete` all present
8. **Quality commands exist** -- `scan-stubs`, `run-gates`, `check-conflicts` all present
9. **Journal component files** -- `observer.go`, `context.go`, `checkpoint.go`, `archive.go` all exist at documented paths
10. **`cmd/saw/debug_journal.go`** -- exists at exact path
11. **Journal observer methods** -- `Sync()`, `GenerateContext()`, `Checkpoint()`, `Archive()` confirmed in code
12. **Journal doc.go** -- External observer pattern description matches architecture.md claims
13. **Execution flow phases** -- Scout -> Scaffold -> Wave loop -> Completion flow is accurate
14. **`protocol/invariants.md`** exists
15. **`protocol/execution-rules.md`** exists with E1-E41
16. **`implementations/claude-code/prompts/saw-skill.md`** exists
17. **`docs/tool-journaling.md`** exists
18. **`internal/git/`** package exists in Go repo (contains `commands.go`)
19. **`pkg/engine/`** -- doc.go confirms it provides Scout, Wave, Scaffold, Chat operations
20. **`pkg/protocol/`** -- doc.go confirms YAML manifest parsing, validation, extraction
21. **`pkg/agent/`** -- doc.go confirms agent execution runtime with tool system and backend abstraction
22. **Web app uses `//go:embed`** -- confirmed via `web/embed.go` embedding `all:dist`
23. **Web app imports scout-and-wave-go** -- confirmed in `go.mod` with replace directive
24. **Scaffold agent description** -- creates type definitions, commits to main branch before Wave 1
25. **Interface freeze concept** -- enforced at worktree creation time
26. **Wave sequencing** -- Wave N+1 waits for Wave N merge
27. **IMPL doc as single source of truth** -- confirmed throughout codebase
28. **Agents commit before reporting (I5)** -- `verify-commits` command exists and enforces this
29. **Role separation (I6)** -- orchestrator delegates to async agents
30. **`saw.config.json` location** -- exists at repo root in all 3 repos
