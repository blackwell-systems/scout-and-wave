# Observability Roadmap

**Version:** 0.2.0
**Date:** 2026-04-04
**Status:** Draft

---

## Current State

The observability pipeline has a working storage layer and query surface, but the engine does not yet write events during normal workflow execution. The result: the store exists, the CLI reads from it, but no data flows through automatically.

### What Exists

**Protocol layer** (`protocol/observability-events.md`):
- Full event schema specification for three event types: `cost`, `agent_performance`, `activity`
- Eleven activity subtypes covering the full lifecycle (scout launch/complete, wave start/merge/fail, gate executed/failed, tier advanced/passed/failed, impl complete)
- Storage requirements defined (append-only, filtered queries, aggregation rollups, batch writes)

**Go SDK** (`scout-and-wave-go/pkg/observability/`):
- `Event` interface with four methods (`EventID`, `EventType`, `Timestamp`, `Metadata`)
- Three concrete event types: `CostEvent`, `AgentPerformanceEvent`, `ActivityEvent`
- `Store` interface with `RecordEvent`, `QueryEvents`, `GetRollup`, `Close`
- `Emitter` — nil-safe, non-blocking wrapper that writes events in background goroutines
- `QueryFilters` struct with filtering by event type, IMPL slug, program slug, agent ID, time range, limit/offset
- `RollupRequest` / `RollupResult` types with group-by support (agent, wave, impl, program, model)
- Full rollup computation functions: `ComputeCostRollup`, `ComputeSuccessRateRollup`, `ComputeRetryRollup`
- Time-series trend computation: `ComputeTrend` with bucketed output
- High-level query functions: `GetAgentHistory`, `GetIMPLMetrics`, `GetProgramSummary`, `GetCostBreakdown`, `GetFailurePatterns`
- 13 helper constructors for common `ActivityEvent` subtypes in `emitter.go`

**SQLite Store** (`scout-and-wave-go/pkg/observability/sqlite/`):
- Concrete `Store` implementation backed by SQLite with WAL mode (pure Go via `modernc.org/sqlite`)
- `Open(path)` creates/opens database, auto-creates schema
- `RecordEvent`, `QueryEvents` (with type/time filtering + in-Go JSON-field filtering for impl/program/agent), `GetRollup` (delegates to SDK rollup functions), `Close`
- Schema uses `(id, type, time, data)` — simpler than the originally planned dimension-indexed schema; JSON-field filtering happens in Go after SQL fetch

**Engine integration** (`scout-and-wave-go/pkg/engine/`):
- `ObsEmitter *observability.Emitter` field on `FinalizeWaveOpts`, `FinalizeIMPLOpts`, `TierLoopOpts`, and the engine config
- Emit calls wired into: `runner.go` (scout launch/complete), `finalize.go` (gate executed, wave failed, wave merge, impl complete), `program_tier_loop.go` (tier gate passed/failed, tier advanced)
- Emit helper functions exist in `cmd/sawtools/finalize_wave_obs.go` and `prepare_wave_obs.go` but are never called — no code constructs an Emitter and passes it through

**CLI** (`sawtools`):
- `sawtools query events` — query observability events with filters (`--type`, `--impl`, `--program`, `--agent`, `--since`, `--format table|json|csv`)
- `sawtools metrics <impl-slug>` — show IMPL metrics (cost, duration, success rate), with `--breakdown` and `--program` flags
- Both commands open a SQLite store (default: `~/.saw/observability.db`) and return real results if events exist in the database
- Events must be recorded externally or via manual testing; the engine pipeline does not yet write events automatically

**Web app** (`scout-and-wave-web/pkg/api/observability.go`):
- Five HTTP endpoints registered: `GET /api/observability/metrics/{impl_slug}`, `GET /api/observability/metrics/program/{program_slug}`, `GET /api/observability/events`, `GET /api/observability/rollup`, `GET /api/observability/cost-breakdown/{impl_slug}`
- `SetObservabilityStore` method on Server for dependency injection
- Full query parameter parsing for filters and rollup requests
- All endpoints return 500 "observability store not configured" because no store is injected at startup

### What Is Missing

1. **No store initialization in engine or web app.** The CLI query commands (`metrics`, `query events`) open a SQLite store per-invocation. But `prepare-wave`, `finalize-wave`, `run-wave`, and `saw serve` do not construct a store or Emitter. The emit helpers in `finalize_wave_obs.go` and `prepare_wave_obs.go` are dead code.
2. **No cost extraction from agents.** No code parses agent output (Claude Code JSONL logs, etc.) to produce `CostEvent` records. Cost events would need to be emitted manually or by a post-wave extraction step.
3. **No invariant violation tracking.** The existing event types track operational metrics (cost, performance, activity) but not protocol-level correctness (did I1 hold? did I2 hold?).
4. **No budget policies.** No mechanism to set spend limits or enforce them at wave boundaries.
5. **Cost is tracked as `float64` dollars.** Accumulation of floating-point costs will produce rounding errors over time.
6. **No dashboard UI.** The web app has API endpoints but no frontend components to display observability data.

---

## Design Decisions

### Storage Format

**SQLite with a single `events` table and a JSON data column.** SQLite is the right choice because SAW runs locally per-repo. WAL mode handles concurrent reads (CLI queries) during writes (Emitter goroutines). No external database dependency.

The shipped schema (`pkg/observability/sqlite/`) is minimal:

```sql
CREATE TABLE IF NOT EXISTS events (
    id   TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    time TEXT NOT NULL,
    data TEXT NOT NULL          -- full event as JSON
);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(type);
CREATE INDEX IF NOT EXISTS idx_events_time ON events(time);
```

This is simpler than the originally planned dimension-indexed schema. Filtering by `impl_slug`, `program_slug`, `agent_id`, and `wave_number` happens in Go after the SQL fetch by deserializing the JSON `data` column. This is adequate for small-to-medium event volumes but may need indexed dimension columns if query performance degrades at scale.

### Event Schema Evolution

The `data_json` column stores the complete event payload. New fields are added to the Go structs with `omitempty` JSON tags. Old events missing new fields deserialize with zero values. No schema migrations are needed for additive changes. Destructive changes (renaming fields, changing types) require a version bump in the event's `metadata.schema_version` field and explicit migration logic in the Store.

### Retention Policy

Events are append-only. No automatic deletion in Tier 1. Tier 3 introduces configurable retention (default: 90 days for raw events, indefinite for rollup summaries). Users can manually purge with `sawtools query purge --before <date>`. The SQLite file can be deleted entirely to reset observability state without affecting protocol operation.

### Multi-Instance Considerations

Each repo has its own `.saw/observability.db` file. If multiple SAW instances (CLI + web app) operate on the same repo concurrently, SQLite WAL mode handles read/write concurrency. The Emitter's fire-and-forget goroutine pattern tolerates transient write conflicts (errors go to stderr, not the caller). Program-level rollups that span multiple repos require explicit aggregation across database files -- this is a Tier 4 concern.

### Cost Representation

**Planned but not yet implemented.** Integer cents (`cost_cents int`) instead of floating-point dollars (`cost_usd float64`). This eliminates rounding errors in financial aggregations. Display logic converts cents to dollars. The protocol spec's `cost_usd` field name is preserved in JSON output for backward compatibility, but the internal representation is integer cents. The SQLite store shipped before this change landed (T1.2), so any cost events already recorded will need migration when the field type changes. Since the engine does not yet write cost events (T1.3 pending), no real data migration is needed as of 2026-04-04.

---

## Non-Goals

- **Not a replacement for claudewatch.** Claudewatch tracks session-level developer productivity (drift, friction, context pressure). SAW observability tracks protocol-level correctness and agent performance. They are complementary systems at different abstraction levels.
- **Not real-time alerting in Tier 1.** Tier 1 focuses on data capture and basic querying. Real-time threshold monitoring and notifications arrive in Tier 3.
- **Not a general-purpose APM.** SAW observability answers protocol-specific questions ("did the invariants hold?", "what did this IMPL cost?"), not generic application performance questions.
- **Not multi-tenant.** SAW operates per-repo. There is no user isolation, access control, or tenant scoping in the observability system.
- **Not a log aggregation system.** Agent journals remain text files. Structured run logs (NDJSON) are a Tier 3 enhancement, not a replacement for the existing journal system.

---

## Tier 1: Foundation (Activate What Exists)

The goal of Tier 1 is to make the existing observability pipeline produce and store real data. The SQLite store is shipped. The remaining work is wiring the store into the engine so events flow automatically, and fixing the cost representation before data accumulates.

### T1.2: Integer Cents for Cost Tracking

**What it is:** Change `CostEvent.CostUSD float64` to `CostCents int` in the Go struct. Update all rollup functions, query functions, and display logic to use integer arithmetic internally and convert to dollars only at display boundaries.

**Why it matters:** Floating-point cost accumulation produces rounding errors. Every financial system uses integer minor units for this reason. This should land before the engine starts writing real cost events to avoid a data migration.

**Dependencies:** None.

**Scope:** Small. Field type change, update ~10 functions that reference `CostUSD`, update protocol spec's CostEvent documentation.

**Repos:** scout-and-wave-go (types + functions), scout-and-wave (protocol spec)

### T1.3: Wire Store into Engine and Web App

**What it is:** Construct a SQLite store at startup in `prepare-wave`, `finalize-wave`, `run-wave`, and `saw serve`. Pass the store to `observability.NewEmitter()` and inject it into the engine's `ObsEmitter` field and the web server's `SetObservabilityStore`. Default database path: `~/.saw/observability.db` or configurable via `--store` flag / environment variable.

**Current state:** The CLI query commands (`sawtools metrics`, `sawtools query events`) already open a SQLite store per-invocation via `openStore()`. The emit helper functions in `finalize_wave_obs.go` and `prepare_wave_obs.go` exist but are never called because no code constructs an Emitter in the workflow commands. The engine's `runner.go` checks `if opts.ObsEmitter != nil` but callers always pass nil.

**What remains:** ~20 lines in each of `prepare_wave.go`, `finalize_wave.go`, and `run_wave_cmd.go` to open the store, create an Emitter, and pass it through. Same for `saw serve` startup to enable web API endpoints.

**Dependencies:** None (SQLite store shipped).

**Scope:** Small.

**Repos:** scout-and-wave-go (CLI wiring), scout-and-wave-web (server wiring)

### T1.4: Verify All Existing Emit Points

**What it is:** Integration test that runs a Scout, executes a wave, finalizes, and verifies that the expected events appear in the store: `scout_launch`, `scout_complete`, `wave_start`, `gate_executed`, `wave_merge`, `impl_complete`. Identifies any lifecycle transitions that lack emit calls and adds them.

**Why it matters:** The existing emit calls were written without a store to verify against. Some lifecycle transitions may be missing emit calls. This test establishes the baseline event stream.

**Dependencies:** T1.3.

**Scope:** Small. One integration test plus any missing emit calls discovered.

**Repos:** scout-and-wave-go

### T1.5: CLI Commands Return Real Results

**What it is:** Verify that `sawtools query events` and `sawtools metrics <slug>` return meaningful data after a wave execution. Fix any serialization or query issues discovered.

**Current state:** Both commands exist with `--format table|json|csv` support and open the SQLite store correctly. They will return real results once T1.3 wires the Emitter into the engine pipeline. This item is primarily a verification pass after T1.3 lands.

**Dependencies:** T1.3, T1.4.

**Scope:** Small. Mostly verification.

**Repos:** scout-and-wave-go

---

## Tier 2: Protocol-Level Intelligence (What Makes SAW Unique)

The goal of Tier 2 is to track things no competitor tracks: whether the protocol's correctness guarantees actually held. Paperclip tracks cost. AO tracks session health. SAW should track invariant compliance -- the thing that justifies the protocol's existence.

### T2.1: Invariant Violation Tracking

**What it is:** A new event type `InvariantCheckEvent` with fields: `invariant` (I1-I6), `passed` (bool), `details` (string), `impl_slug`, `wave_number`. Emit from every mechanical check point: E3 (I1 pre-launch verification), E2 (I2 interface freeze verification), wave sequencing checks (I3), completion report validation (I4, I5), role separation checks (I6).

**Why it matters:** Answers the question "did the protocol hold?" This is SAW's unique value proposition. Over time, the invariant pass/fail history reveals which invariants are most frequently stressed, which IMPL patterns produce violations, and where the protocol needs strengthening.

**Dependencies:** T1.3 (engine must write events to the store).

**Scope:** Medium. New event type, ~6 new emit points in the engine (one per invariant check), update Store deserialization to handle the new type.

**Repos:** scout-and-wave (protocol spec update), scout-and-wave-go (event type + emit points)

### T2.2: Wave Efficiency Metrics

**What it is:** Computed metrics derived from existing events: wall-clock time per wave, agent idle time (time between wave_start and first agent activity), retry rate per failure type, parallelism factor (agents per wave vs. sequential baseline), time saved vs. sequential execution estimate.

**Why it matters:** Answers "is the wave structure actually saving time?" and "which failure types cause the most retries?" These metrics justify the protocol's complexity and identify optimization targets.

**Dependencies:** T1.3, T1.4 (need real event data to compute from).

**Scope:** Medium. New query functions in `pkg/observability/`, new `sawtools efficiency <impl-slug>` command.

**Repos:** scout-and-wave-go

### T2.3: Integration Gap Patterns

**What it is:** Track which integration issues E25 (Integration Validation) and E26 (Integration Agent) detect and fix. Record: gap type (missing import, undefined reference, type mismatch), source agent, target agent, file path, auto-fixed vs. escalated. Aggregate into pattern reports: "Agent A's work consistently requires integration fixes to connect with Agent B's work."

**Why it matters:** Answers "which decomposition patterns produce clean integrations and which produce gaps?" This feeds back into Scout quality -- if certain agent boundary patterns consistently require post-merge integration fixes, the Scout prompt can be updated to avoid those patterns.

**Dependencies:** T1.3, E25/E26 implementation (must be emitting integration events).

**Scope:** Medium. New event subtype for integration gaps, emit points in integration validation/agent code, aggregation query.

**Repos:** scout-and-wave-go

### T2.4: Cost per Correctness

**What it is:** A derived metric: total cost of an IMPL divided by the number of waves that merged successfully on the first attempt (no retries, no gate failures). Variants: cost per successful agent, cost per retry, cost overhead of failed agents.

**Why it matters:** Raw cost is misleading. An IMPL that costs $5 and merges cleanly in 2 waves is more efficient than one that costs $3 but requires 4 retries. This metric captures the true cost of getting correct output.

**Dependencies:** T1.3, T1.4 (need both cost and performance events).

**Scope:** Small. New function in `pkg/observability/query.go` that joins cost and performance data. New field in `IMPLMetrics`.

**Repos:** scout-and-wave-go

### T2.5: Pre-Mortem Calibration

**What it is:** Compare Scout's risk predictions (the `risk_level` and `risk_notes` fields in IMPL docs) against actual outcomes. Did high-risk waves actually fail more often? Did low-risk waves sail through? Track prediction accuracy over time.

**Why it matters:** Answers "is the Scout actually good at predicting difficulty?" If Scout consistently underestimates risk for certain patterns, the Scout prompt can be calibrated. If risk predictions are uncorrelated with outcomes, the field is noise and should be removed or redesigned.

**Dependencies:** T1.3, T2.1 (need invariant and performance data), IMPL docs with risk fields.

**Scope:** Medium. Parse risk fields from IMPL docs, correlate with wave outcomes, produce calibration report.

**Repos:** scout-and-wave-go

---

## Tier 3: Actionable Feedback Loops

The goal of Tier 3 is to close the loop -- use observability data to automatically improve protocol execution, not just report on it.

### T3.1: Budget Policies with Two-Tier Thresholds

**What it is:** Configurable spend limits scoped to IMPL slugs, program slugs, or globally. Two thresholds per policy: soft warn (default 80%) emits a notification, hard stop (100%) blocks the next wave launch. Policies stored as YAML config (`.saw/budget-policies.yaml`) or in the SQLite store. Enforcement at wave boundaries: `prepare-wave` checks all applicable policies before creating worktrees.

**Why it matters:** Answers "how do I prevent runaway costs?" Cost tracking without enforcement is just reporting. Budget policies make cost observability actionable. The wave-boundary enforcement model is natural for SAW -- unlike Paperclip's per-invocation checking, SAW can enforce at the coarser (and less disruptive) wave boundary.

**Dependencies:** T1.3 (need working cost event recording).

**Scope:** Large. New config format, policy evaluation engine, integration into `prepare-wave`, notification emission, web UI for policy management.

**Repos:** scout-and-wave-go (policy engine + CLI), scout-and-wave-web (UI), scout-and-wave (protocol doc for budget enforcement rules)

### T3.2: Real-Time CI Feedback During Wave Execution

**What it is:** Optional polling loop that monitors CI status for agent branches during wave execution. If CI fails on an agent's branch, emit an event and optionally notify the agent (via a marker file in the worktree) before the wave boundary gate. Inspired by AO's reaction engine but constrained to SAW's model: feedback is informational during execution, gates remain the formal checkpoint.

**Why it matters:** Answers "can agents fix CI failures before the wave gate runs?" Currently, agents discover CI failures only at wave finalization. Earlier feedback reduces wasted agent time on doomed approaches.

**Dependencies:** T1.3, CI integration (GitHub Actions API or similar).

**Scope:** Large. New polling subsystem, CI provider abstraction (GitHub, GitLab), event emission, optional agent notification mechanism, web UI for real-time CI status per agent.

**Repos:** scout-and-wave-go (CI polling + events), scout-and-wave-web (real-time CI status UI)

### T3.3: Scout Improvement Signals

**What it is:** Aggregate historical data to identify which Scout decomposition patterns produce the best outcomes. Track: brief clarity score (did the agent ask clarifying questions?), first-try merge rate per brief pattern, file ownership granularity vs. success rate, interface contract completeness vs. integration gap count.

**Why it matters:** Answers "how do I write better IMPL docs?" The Scout prompt can be updated with empirical data: "decompositions with N agents per wave and M files per agent historically produce X% first-try merge rates." This turns observability data into Scout quality improvement.

**Dependencies:** T1.3, T2.1, T2.3, T2.4 (need rich historical data).

**Scope:** Large. Historical data aggregation, pattern extraction, report generation, potentially automatic Scout prompt tuning.

**Repos:** scout-and-wave-go (analysis), scout-and-wave (Scout prompt updates)

### T3.4: Auto-Generated IMPL Risk Assessments

**What it is:** Before a wave launches, automatically assess risk based on historical data: "IMPLs touching this many files in this area of the codebase have historically had X% first-try success rate." Surface the assessment in the web UI and optionally in the IMPL doc.

**Why it matters:** Answers "should I expect this wave to go smoothly?" Gives users calibrated expectations before committing agent compute time. Complements T2.5 (pre-mortem calibration) by feeding historical patterns forward into new IMPLs.

**Dependencies:** T2.4, T2.5 (need historical cost-per-correctness and calibration data).

**Scope:** Medium. Historical pattern matching, risk score computation, web UI integration.

**Repos:** scout-and-wave-go (risk engine), scout-and-wave-web (UI)

### T3.5: Structured Agent Run Logs

**What it is:** Supplement text-based agent journals with structured NDJSON logs. Each line: `{"ts":"...","stream":"stdout|stderr|system|cost","chunk":"..."}`. Finalized with a SHA256 integrity hash. Parseable for automatic cost extraction, error detection, and file modification tracking.

**Why it matters:** Answers "what exactly did the agent do?" Text journals are human-readable but not machine-parseable. Structured logs enable automatic cost extraction (T1 gap: no cost extraction from agents), error pattern detection, and efficient streaming to the web UI.

**Dependencies:** T1.3 (store for indexing), agent adapter changes.

**Scope:** Medium. New log format, writer in engine, parser for cost extraction, integrity hashing.

**Repos:** scout-and-wave-go (log format + writer), scout-and-wave-web (streaming reader)

---

## Tier 4: Dashboards and Reporting

The goal of Tier 4 is to make observability data visible and exportable. The API endpoints already exist in the web app -- this tier adds the frontend components and external integrations.

### T4.1: Web App Observability Dashboard

**What it is:** A new page in the web app displaying: cost trends over time (line chart), wave success rates (bar chart), invariant health summary (pass/fail counts per invariant), top failure patterns, and per-IMPL cost breakdown. Uses the existing `/api/observability/*` endpoints.

**Why it matters:** Answers "what is the overall health of my SAW usage?" at a glance. The API layer is already built; this is purely frontend work.

**Dependencies:** T1.3 (API endpoints need a working store behind them).

**Scope:** Medium. React components, chart library integration, new page in the web app navigation.

**Repos:** scout-and-wave-web

### T4.2: Per-IMPL Execution Timeline

**What it is:** A timeline visualization for a single IMPL showing: Scout phase, each wave (with per-agent bars), gate results, merge events, and total duration. Overlays cost data on the timeline. Clickable to drill into agent journals and event details.

**Why it matters:** Answers "what happened during this IMPL execution?" The timeline view makes wave sequencing, parallelism, and bottlenecks visually obvious.

**Dependencies:** T1.3, T4.1 (dashboard infrastructure).

**Scope:** Medium. Timeline component, event-to-timeline mapping, drill-down navigation.

**Repos:** scout-and-wave-web

### T4.3: Program-Level Cost Rollups

**What it is:** Aggregate cost and performance metrics across all IMPLs in a program, grouped by tier. Show: cost per tier, cumulative cost, success rate trend across tiers, time-to-completion per tier. Uses the existing `GetProgramSummary` function and extends it with tier-level breakdown.

**Why it matters:** Answers "how much did this program cost and how is it trending?" Programs are multi-IMPL efforts that can span weeks; program-level visibility is essential for cost planning.

**Dependencies:** T1.3, T4.1 (dashboard infrastructure), program execution data.

**Scope:** Small. Extend existing `GetProgramSummary`, add tier grouping, frontend component.

**Repos:** scout-and-wave-go (query extension), scout-and-wave-web (UI)

### T4.4: Historical Comparison

**What it is:** Compare the current IMPL's metrics against similar past IMPLs. Similarity based on: agent count, wave count, file count, codebase area (directory prefix). Show: "this IMPL cost 30% less than the average for similar IMPLs" or "this IMPL had 2x the retry rate."

**Why it matters:** Answers "is this IMPL performing normally or is something off?" Context makes individual metrics meaningful.

**Dependencies:** T1.3, T2.4, sufficient historical data (need ~10 completed IMPLs for meaningful comparison).

**Scope:** Medium. Similarity scoring, historical aggregation, comparison UI.

**Repos:** scout-and-wave-go (comparison engine), scout-and-wave-web (UI)

### T4.5: Export to External Systems

**What it is:** Export observability events via OTLP (OpenTelemetry Protocol) or webhook for ingestion into external systems (Grafana, Datadog, custom dashboards). Configurable export filters (e.g., only cost events, only for specific programs). Batch export with retry logic.

**Why it matters:** Answers "how do I integrate SAW metrics into my existing monitoring stack?" Teams with established observability infrastructure should not need to use SAW's built-in dashboard exclusively.

**Dependencies:** T1.3, T1.4 (need reliable event stream to export).

**Scope:** Large. OTLP client implementation, webhook delivery with retry, configuration format, backpressure handling.

**Repos:** scout-and-wave-go (export engine), scout-and-wave (configuration spec)

---

## Implementation Order

The tiers are sequential in priority but not strictly blocking. Recommended execution order:

1. **T1.2** first (integer cents -- must land before real cost data accumulates)
2. **T1.3** immediately after (wire the store into the engine pipeline)
3. **T1.4 + T1.5** to validate the pipeline works end-to-end
4. **T2.1** next (invariant tracking is SAW's differentiator)
5. **T4.1** can start as soon as T1.3 is done (frontend work is independent)
6. **T2.2 through T2.5** as data accumulates
7. **T3.x and T4.x** based on user demand and data volume

The critical path is: T1.2 -> T1.3 -> T1.4 -> T2.1. Everything else builds on that foundation.

---

## Cross-References

- Protocol event schema: `protocol/observability-events.md`
- Go SDK observability package: `scout-and-wave-go/pkg/observability/`
- SQLite store: `scout-and-wave-go/pkg/observability/sqlite/`
- Engine emit points: `scout-and-wave-go/pkg/engine/runner.go`, `finalize.go`, `program_tier_loop.go`
- CLI emit helpers (unwired): `scout-and-wave-go/cmd/sawtools/finalize_wave_obs.go`, `prepare_wave_obs.go`
- Web app API endpoints: `scout-and-wave-web/pkg/api/observability.go`
- CLI commands: `sawtools query events`, `sawtools metrics`
- Protocol invariants: `protocol/invariants.md`
