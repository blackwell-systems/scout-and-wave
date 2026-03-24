# Parallel Systems Audit: Scout-and-Wave Codebase

**Date:** 2026-03-24
**Scope:** All 3 repositories (protocol, SDK, web)

---

## Remaining Findings

### 1. Command/API Interface Duplication — HIGH PRIORITY

**Status:** Unaddressed. No `pkg/operations` package exists.

**Problem:** Business logic is duplicated between CLI commands (`cmd/sawtools/`) and web service handlers (`pkg/service/`, `pkg/api/`). Both layers independently call `protocol.Load`, run validation, and format errors — rather than delegating to a shared operations layer.

**Example:** `protocol.Load()` + validation + error formatting is repeated in:
- CLI: `cmd/sawtools/prepare_wave.go`, `cmd/sawtools/run_scout_cmd.go`, `cmd/sawtools/merge_wave.go`, etc.
- Web: `pkg/service/wave_service.go`, `pkg/service/merge_service.go`, `pkg/api/impl.go`, etc.

**Impact:**
- Adding new features requires updating 2 places
- CLI and web can (and do) diverge in behavior
- No single source of truth for business logic

**Proposed Fix:** Create `pkg/operations` package in scout-and-wave-go. Extract business logic from CLI commands. Make both CLI and web handlers thin wrappers that call `pkg/operations`.

**Effort:** Medium (1-2 weeks). No breaking changes.

---

### 2. Configuration Management — MEDIUM PRIORITY

**Status:** Unaddressed. Config loading logic still duplicated in 2 packages.

**Problem:** Two separate config loading implementations exist:
- `pkg/agent/backend/configfile.go`: `LoadProvidersFromConfig()` — walks filesystem for `saw.config.json`
- `pkg/autonomy/config.go`: `LoadConfig()` — reads `saw.config.json` from a given path (no walking)

No unified `pkg/config` package exists.

**Impact:**
- Different behavior (one walks filesystem, the other does not)
- No single "load config" function
- Adding new config sections requires touching multiple packages

**Proposed Fix:** Create `pkg/config` package with unified `Load(startDir string)` function. Migrate both callers.

**Effort:** Low (2-3 days). Moderate breaking changes (callers need updating).

---

### 3. State Tracking — MEDIUM PRIORITY

**Status:** Unaddressed. State remains scattered across 3 locations.

**Problem:** Runtime state is split across:
- IMPL manifest files (`docs/IMPL/*.yaml`) — protocol state machine, wave status
- `.saw-state/` directory — gate cache, session files, journal archives
- In-memory web app state — SSE event cache, agent snapshots

Answering "what is the current state of wave N?" requires checking all 3 sources.

**Proposed Fix:** Make IMPL manifest the single source of truth. Keep `.saw-state/` as cache-only (rebuildable). Web SSE snapshots remain ephemeral.

**Effort:** Medium (1 week). Low breaking changes.

---

### 4. Validation Logic — MEDIUM PRIORITY

**Status:** Unaddressed. Validation still duplicated across CLI and web layers.

**Problem:** Both CLI commands and web API handlers independently call `protocol.Load()` + `protocol.Validate()` with their own error formatting and response construction. Adding a new validation rule requires updating multiple call sites.

**Proposed Fix:** Centralize all validation in SDK with a single `ValidateManifest()` function that returns structured results. CLI and web become thin wrappers that format the output.

**Effort:** Low (3-4 days). No breaking changes.

**Note:** This overlaps significantly with Finding #1 (Command/API Duplication). Solving #1 with a `pkg/operations` layer would largely resolve this as well.

---

### 5. Logging / Observability Cleanup — LOW PRIORITY

**Status:** Partially addressed. Observability system (`pkg/observability`) is unified, but 282 occurrences of `fmt.Fprintf(os.Stderr, ...)` remain across 67 files in scout-and-wave-go (count has grown since initial audit).

**Problem:** Errors and warnings written directly to stderr bypass the observability system and are not queryable or analyzable.

**Proposed Fix:** Migrate remaining `fmt.Fprintf(os.Stderr, ...)` calls to the observability emitter.

**Effort:** Very Low (1-2 days). No breaking changes.

---

## Completed / Resolved Findings (removed from audit)

| Finding | Resolution | Date |
|---|---|---|
| Result/Response Types (60+ types) | `result.Result[T]` universal across SDK and web | 2026-03-23 |
| Error Handling (3 parallel systems) | `result.SAWError` with 78 error codes; `ValidationError` and `StructuredError` deleted | 2026-03-23 |
| File Ownership / Path Resolution | Already centralized in SDK; `internal/git` directory removed | 2026-03-24 |

---

## Priority Summary

| # | Finding | Priority | Effort | Breaking |
|---|---|---|---|---|
| 1 | Command/API Duplication | High | 1-2 weeks | No |
| 2 | Configuration Management | Medium | 2-3 days | Moderate |
| 3 | State Tracking | Medium | 1 week | Low |
| 4 | Validation Logic | Medium | 3-4 days | No |
| 5 | Logging Cleanup | Low | 1-2 days | No |

---

**Last reviewed:** 2026-03-24
