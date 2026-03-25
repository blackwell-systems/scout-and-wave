# Parallel Systems Audit: Scout-and-Wave Codebase

**Date:** 2026-03-24
**Scope:** All 3 repositories (protocol, SDK, web)

---

## Remaining Findings

### 1. Command/API Interface Duplication — Residual Items

**Status:** Substantially resolved. 4 of 6 specific duplications fixed, 2 residual items remain.

**Residual item A: CLI finalize_wave.go orchestration outside engine.**
CLI `finalize_wave.go` still has cross-repo iteration, closed-loop gate retry, and collision detection logic that isn't in `engine.FinalizeWave()`. These are CLI-specific concerns (the web app doesn't need cross-repo iteration because it handles one repo at a time). Low priority — the engine step functions exist, the CLI just hasn't migrated its extra orchestration into them yet.

**Residual item B: Two wave execution paths (RunWaveFull vs PrepareWave+RunWave).**
CLI's `RunWaveFull()` is a separate code path from the web's `PrepareWave()` + `orchestrator.RunWave()`. Both work, but they don't share the same composition. Runner.go decomposition scout (in flight) may address this.

~~**Residual item C: Scout finalization inconsistency.**~~ — **RESOLVED**
CLI `finalize_impl_cmd.go` and `run_scout_cmd.go` now call `engine.FinalizeIMPLEngine()` instead of `protocol.FinalizeIMPL()` directly. Both paths use the same engine wrapper.

**Effort:** Low for each residual item. No urgency — both paths work correctly.

---

### ~~4. Validation Logic~~ — **RESOLVED**

Both `cmd/sawtools/validate_cmd.go` (157→43 lines) and `cmd/saw/validate.go` (74→59 lines) now delegate to `protocol.FullValidate()`. All validation — duplicate keys, unknown keys, struct invariants, typed-block checks — flows through the single entry point. Resolved 2026-03-24.

---

## Completed / Resolved Findings

| Finding | Resolution | Date |
|---|---|---|
| Result/Response Types (60+ types) | `result.Result[T]` universal across SDK and web | 2026-03-23 |
| Error Handling (3 parallel systems) | `result.SAWError` with 78 error codes; `ValidationError` and `StructuredError` deleted | 2026-03-23 |
| File Ownership / Path Resolution | Already centralized in SDK; `internal/git` directory removed | 2026-03-24 |
| **#1: prepare-wave no engine function** | `engine.PrepareWave()` created (618 lines). CLI reduced to 87-line wrapper. Web app calls it directly. | 2026-03-24 |
| **#1: Finalization in three places** | Engine decomposed into 8 step functions (`finalize_steps.go`). Web calls `engine.FinalizeWave()` with `OnEvent` callback. | 2026-03-24 |
| **#1: Merge post-processing duplicate** | `service.PostMergeCleanup()` helper replaces 3 identical cleanup blocks. | 2026-03-24 |
| **#1: Test execution duplicate** | Consolidated into `service.RunTestCommand()` with streaming. `handleWaveTest` delegates. | 2026-03-24 |
| **#1: Web bypasses pre-flight checks** | Web app now calls `engine.PrepareWave()` + `orchestrator.RunWave()` instead of `RunSingleWave`. All 20+ pre-flight checks active. | 2026-03-24 |
| **#2: Configuration Management** | 3 config loaders → 1 `config.Load()`. `configfile.go` deleted, `autonomy.LoadConfig`/`SaveConfig` removed. (IMPL-unify-config-management) | 2026-03-24 |
| **#3: State Tracking** | Disk-status endpoint enriched with pipeline steps, completion reports, run state. Frontend seeds from IMPL doc on mount; SSE overrides when live. (IMPL-waveboard-state-persistence) | 2026-03-24 |
| **#5: Logging / Observability** | Migrated to `log/slog` with dependency injection. (IMPL-logging-slog) | 2026-03-24 |

---

## Priority Summary

| # | Finding | Priority | Status |
|---|---|---|---|
| 1 | Command/API Duplication | Low (residual) | 2 items remain (A, B). C resolved. |
| 4 | Validation Logic | — | **Resolved** |

---

**Last reviewed:** 2026-03-24 (all 5 original findings resolved or residual-only. #4 and #1C closed directly. Runner.go decomposed into 3 files — IMPL-runner-decomposition complete.)
