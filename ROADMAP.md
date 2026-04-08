# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Protocol Enhancements

### Contract Builder Phase

Separate *detecting* cross-agent boundaries from *specifying* contracts at those boundaries. Scout emits integration hints; a Contract Builder phase generates precise API/type/event contracts before agents launch.

**Why:** Currently, API-level contracts are implicit — agents infer request/response shapes from prose. Type contracts work (Scaffold Agent materializes them), but API contracts need the same rigor.

**Protocol changes:** New integration hint schema in `message-formats.md`, updated Scout to emit hints, new `contract-builder.md` agent type (or extended Scaffold Agent), API contracts section in `agent-template.md`.

**Potential:** High. API-shape inference from prose is the current leading cause of cross-agent type mismatches. This is the right structural fix.

### Tier 2 Merge Conflict Resolution Agent

Add tiered resolution to `saw-merge.md` Step 4:
- **Tier 1 (automatic):** Retry merge after brief delay (handles concurrent merge race).
- **Tier 2 (resolver agent):** Spawn a slim Wave Agent variant scoped to conflicting files, with both agents' completion reports as context.
- Tier 2 failure escalates to human (current behavior).

**Protocol changes:** Updated `saw-merge.md` Step 4, new `resolver-agent.md` agent type, new E-rule for conflict resolution tiers.

**Potential:** Medium. Conflicts are rare with disjoint ownership, but when they happen the current UX is fully manual. Worth doing when conflict frequency increases.

### NOT SUITABLE Full Research Output

**Status:** UI shipped (v0.17.0, `NotSuitableResearchPanel`). **Protocol spec updates still pending.**

Decouple verdict from research. NOT SUITABLE IMPL docs should contain full file survey, dependency map, risk assessment, actionable "why not suitable" explanation, conditions for re-scouting, and serial implementation notes. Only agent prompts and wave execution loop are omitted.

**Protocol changes needed:** Update `message-formats.md` (required sections for NOT SUITABLE), update `agents/scout.md` (research always completes regardless of verdict).

**Potential:** High effort/reward ratio. UI already built — protocol doc update is the only blocker. Quick win.

---

## Protocol Hardening

### Cross-Repo Field 8 Completion Report Path

Wave agent prompt already includes absolute IMPL doc path in payload header and `sawtools set-completion`. Explicit callout in `saw-worktree.md` cross-repo section still needed.

**Potential:** Trivial — one doc paragraph. Should be done alongside any cross-repo work.

### BUILD STUB Test Discipline

Distinguish BUILD STUB (compiles, body panics/returns zero, tests expected to fail, report `status: partial`) from COMPLETE (fully implemented, tests pass). Agents must not report `status: complete` for stubs.

**Protocol changes:** `agents/wave-agent.md`, `agent-template.md` Field 9 (status values).

**Potential:** Medium. Addresses a real correctness gap — stubs reported complete are a persistent source of false finalize-wave passes.

---

## PROGRAM Execution Hardening

### P4: Cross-Tier Dependency Graph Validation

Tier 1 created `config/state.go` importing `protocol`, making `protocol → config` impossible for Tier 2 (import cycle). The dependency graph across tiers was never validated.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/tier_deps.go` (new) — `CheckTierDependencyGraph(manifest *PROGRAMManifest, repoDir string) result.Result[*TierDepsData]`. For each tier boundary, analyze Go import graphs: collect packages modified by Tier N IMPLs, check if Tier N+1 IMPL files can import them without cycles. Uses `go list -json ./...` to build the import graph. Returns cycle details if found. |
| **CLI** | `cmd/sawtools/check_tier_deps_cmd.go` (new) — `sawtools check-tier-deps <program-manifest> --repo-dir <path>`. Integrate into `prepare-tier` as a pre-flight step (after P1+ conflict check, before IMPL validation). |
| **Web** | `pkg/api/program_handler.go` — add `POST /api/program/{slug}/check-tier-deps` endpoint. Display cycle warnings in program status panel (text/table format). |

**Potential:** Medium. Only matters in PROGRAM mode. Import cycles are catch-at-compile-time anyway — this just catches them earlier (pre-wave). Worth doing before the next large PROGRAM.

### P13: E37 Enforcement Divergence Between `prepare-tier` and `prepare-wave`

**Partially addressed by P5** — `CriticGatePasses()` function exists. Unification into a single call site may still be incomplete.

`prepare-tier` uses `criticPassed()` (checks `CriticReport.Verdict == "PASS"`). `prepare-wave` at lines 116-138 checks `CriticVerdictIssues` and blocks on ANY issues regardless of severity. These should be unified into a single SDK function.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/critic.go` — verify `CriticGatePasses(m *IMPLManifest, autoMode bool) bool` is the single call site for both callers. |
| **CLI** | Both `prepare_wave.go` and `prepare_tier_cmd.go` call `CriticGatePasses()` instead of inline checks. |
| **Web** | Web wave/program runners call the same SDK function. |

**Potential:** Low-medium. P5 fixed the behavioral issue. This is a code hygiene cleanup to prevent future divergence. Worth folding into any prepare-wave/prepare-tier work.

### Web UI Remaining (P2 + P6)

Two features have complete SDK/CLI but no web layer:

- **P2 Cross-Repo Build:** `pkg/api/wave_runner.go` — always enable `CrossRepoVerify` in web flows, emit SSE event, add red/green indicators.
- **P6 Incremental Commits:** Real-time commit count in agent progress SSE event.

**Potential:** Medium. Low implementation cost (SSE events already wired), high observability value during long waves.

---

## Future Work

### Framework Skills Content

Language/framework-specific best practice documents in `scout-and-wave/skills/` (e.g., `go.md`, `react.md`, `python.md`). Scout detects the project language at step 2 (reads go.mod, package.json, etc.) and conditionally includes the relevant skill reference in agent task fields. Scout-injected rather than globally auto-loaded — Scout already knows the language at planning time, so no separate detection mechanism needed.

Content examples: Go — `go work use` for cross-module worktrees, `GOWORK=off` for isolated builds; React — hook dependency arrays, component split guidelines; Python — `__init__.py` implications, virtual env isolation.

**Potential:** High adoption leverage per doc. Scout-injection means no global noise — agents only see the skill content relevant to their project. Low implementation cost: skill files are just markdown, injection is a Scout step-2 addition.

### Claude Orchestrator Chat Panel

Add Claude chat panel to `saw serve`. Read-only diagnostic mode first (why did agent B fail?), then write tools (retry, skip), then proactive SSE monitoring. No protocol changes required. Full design in `scout-and-wave-web/docs/ROADMAP.md`.

**Potential:** High UX value. "Why did agent B fail?" is the most-asked question during wave execution. Read-only mode is a quick win that unblocks the rest.


### Constraint-Solving Validator

Replace rule-by-rule `sawtools validate` with a constraint solver: model the manifest as a CSP (agents, files, dependencies as variables/constraints) and prove the execution plan correct. Scout declares dependencies; the solver derives wave assignment. Wave numbers become computed, not guessed — I2_WAVE_ORDER errors become impossible.

**Potential:** High long-term value, high implementation cost. The right end-state for validation. Defer until current rule-based validator shows consistent false-negative patterns.

---

## E23A Integration Backlog

**Status:** Core journal shipped (v0.27.0). Runner integration shipped (journal-integration IMPL, 2026-04-04).

Remaining integration work:

- **Backend integration** — Hook journaling into all agent backends (Anthropic API, CLI, OpenAI). Each has different tool call shapes; journal must normalize to common schema.
- **E19 failure recovery** — Preserve journal across retries, include "you tried X before" context, detect retry loops from journal.
- **Web UI** — Real-time journal display in Observatory, agent detail tabs (Tool History, Raw Journal, Checkpoints), failed agent debugging panel.

**Potential:** High. Failed agent debugging is the #1 observability gap. E19 recovery directly reduces retry cost. Backend integration is table-stakes for multi-backend support.
