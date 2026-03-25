# Parallel Systems Audit: Scout-and-Wave Codebase

**Date:** 2026-03-24
**Scope:** All 3 repositories (protocol, SDK, web)

---

## Remaining Findings

### 1. Command/API Interface Duplication — Residual Items

**Status:** Substantially resolved. 4 of 6 specific duplications fixed, 2 residual items remain.

**Residual item A: Web app skips critical enforcement steps during wave finalization. ⚠️ MEDIUM priority, not low.**

Reviewed 2026-03-25. The CLI `finalize_wave.go` has 8 enforcement steps that are explicitly labeled "CLI-only" and are NOT called by `engine.FinalizeWave()` (the path the web app uses):

| Missing step | Protocol rule | Risk |
|---|---|---|
| I4 completion report verification | I4 | Web can merge a wave with no completion reports |
| E7 status check before merge | E7 | Web can merge a `partial`/`blocked` agent's work |
| E11 conflict prediction | E11 | Merge conflicts not predicted before attempt |
| Type collision detection (Step 1.5) | E21 | Type name collisions across agent branches undetected |
| C2 closed-loop gate retry | C2 | Failed gates not auto-retried in web UI |
| E35 wiring declaration check | E35 | Wiring gaps not caught post-merge in web UI |
| M5 populate-integration-checklist | M5 | Integration checklist not populated after wave |
| Cross-repo iteration (`extractReposFromManifest`) | — | Web finalizes only one repo even for cross-repo IMPLs |

The most dangerous gaps are I4 and E7 — the web app can merge a wave where agents reported `blocked` or wrote no completion report. These should be moved into the engine so both paths enforce them.

Note: the web app also needs cross-repo file browser awareness (separate from finalization). The `/api/files/resolve` endpoint was added 2026-03-25 for that case.

**Residual item B: Two wave execution paths (RunWaveFull vs PrepareWave+RunWave).**
CLI's `RunWaveFull()` is a separate code path from the web's `PrepareWave()` + `orchestrator.RunWave()`. `RunWaveFull` is also used by `program_tier_loop.go:172`. Both work, but they don't share the same composition. Runner.go decomposition scout (in flight) may address this.

~~**Residual item C: Scout finalization inconsistency.**~~ — **RESOLVED**
CLI `finalize_impl_cmd.go` and `run_scout_cmd.go` now call `engine.FinalizeIMPLEngine()` instead of `protocol.FinalizeIMPL()` directly. Both paths use the same engine wrapper.

**Effort:** Item A (I4+E7 into engine) is medium effort, high correctness value. Item B is low urgency — both paths work.

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
