# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Completed

- **Tool Journaling / E23A** (v0.27.0) -- External log observer for compaction safety. Core journal in `scout-and-wave-go/pkg/journal/`, CLI via `sawtools journal-init` / `journal-context`.
- **Multi-Generation Agent IDs** -- `[Letter][Generation]` format (A, B, A2, B3, ...) implemented in `scout-and-wave-go/pkg/idgen/`. Supports >26 agents per wave with family-based color grouping.
- **Short IMPL-Referencing Prompts** (saw-skill v0.7.2) -- Wave agent prompts reference the IMPL doc path (~60 tokens) instead of copy-pasting the full brief (~1000 tokens). 10-15x faster parallel launch.
- **Explicit IMPL Targeting** (v0.24.0 / saw-skill v0.9.0) -- `--impl <id>` flag on `/saw wave` and `/saw status`. Supports slug, filename, or path resolution.
- **Engine Extraction** (2026-03-08) -- `scout-and-wave-go` is the standalone engine module; `scout-and-wave-web` imports it. Both the `/saw` skill and web UI are clients on top.

---

## Protocol Enhancements

### Contract Builder Phase

Separate *detecting* cross-agent boundaries from *specifying* contracts at those boundaries. Scout emits integration hints; a Contract Builder phase generates precise API/type/event contracts before agents launch.

**Why:** Currently, API-level contracts are implicit -- agents infer request/response shapes from prose. Type contracts work (Scaffold Agent materializes them), but API contracts need the same rigor.

**Protocol changes:** New integration hint schema in `message-formats.md`, updated Scout to emit hints, new `contract-builder.md` agent type (or extended Scaffold Agent), API contracts section in `agent-template.md`.

### Tier 2 Merge Conflict Resolution Agent

Add tiered resolution to `saw-merge.md` Step 4:
- **Tier 1 (automatic):** Retry merge after brief delay (handles concurrent merge race).
- **Tier 2 (resolver agent):** Spawn a slim Wave Agent variant scoped to conflicting files, with both agents' completion reports as context.
- Tier 2 failure escalates to human (current behavior).

**Protocol changes:** Updated `saw-merge.md` Step 4, new `resolver-agent.md` agent type, new E-rule for conflict resolution tiers.

### NOT SUITABLE Full Research Output

**Status:** UI shipped (v0.17.0, `NotSuitableResearchPanel`). Protocol spec updates pending.

Decouple verdict from research. NOT SUITABLE IMPL docs should contain full file survey, dependency map, risk assessment, actionable "why not suitable" explanation, conditions for re-scouting, and serial implementation notes. Only agent prompts and wave execution loop are omitted.

**Protocol changes:** Updated `message-formats.md` (required sections for NOT SUITABLE), updated `agents/scout.md` (research always completes regardless of verdict).

---

## Protocol Hardening

### Cross-Repo Field 8 Completion Report Path

**Status:** Partially addressed. Wave agent prompt already includes absolute IMPL doc path in payload header and `sawtools set-completion`. Explicit callout in `saw-worktree.md` cross-repo section still needed.

### BUILD STUB Test Discipline

Distinguish BUILD STUB (compiles, body panics/returns zero, tests expected to fail, report `status: partial`) from COMPLETE (fully implemented, tests pass). Agents must not report `status: complete` for stubs.

**Protocol changes:** `agents/wave-agent.md`, `agent-template.md` Field 9 (status values).

### `go.work` for Cross-Repo Worktree LSP

Add note to `saw-worktree.md`: for Go cross-repo waves, a `go.work` file at the workspace root eliminates LSP "module not found" noise in agent worktrees.

---

## Future Work

### Framework Skills Content

Framework-specific best practice documents (500-1000 words each) in `scout-and-wave/skills/`. Auto-detected by project files (e.g., `package.json` with `react` loads `react-best-practices.md`). Protocol provides content; implementations handle detection logic.

### Claude Orchestrator Chat Panel

Add Claude chat panel to `saw serve`. Read-only diagnostic mode first (why did agent B fail?), then write tools (retry, skip), then proactive SSE monitoring. No protocol changes required. Full design in `scout-and-wave-web/docs/ROADMAP.md`.

### IMPL Doc Length Management

Three complementary mitigations for IMPL doc growth:

1. **History Sidecar** -- After wave merges, archive verbose completion reports to `IMPL-slug-history.md`, replace with one-line summaries. Main doc stays bounded.
2. **Structured Doc Splitting** -- Split at creation: `IMPL-slug.md` (live state), `IMPL-slug-scaffolds.md` (scaffold contents), `IMPL-slug-log.md` (completion reports). Agents receive only relevant slices.
3. **Size Gate** -- Informational warning at E16 validation if doc exceeds 50 KB threshold, recommending compaction.

### Constraint-Solving Validator

Replace rule-by-rule `sawtools validate` with a constraint solver: model the manifest as a CSP (agents, files, dependencies as variables/constraints) and prove the execution plan correct. Scout declares dependencies; the solver derives wave assignment. Wave numbers become computed, not guessed -- I2_WAVE_ORDER errors become impossible.

Future phases: interface contracts as compiled types (verify scaffold stubs implement contracts before agents run), then pre-execution simulation (model agents as transactions, prove serializability before worktree creation).

---

## E23A Integration Backlog

Core journal shipped (v0.27.0). Remaining integration work:

- **Backend integration** -- Hook journaling into all agent backends (Anthropic API, CLI, OpenAI). Each has different tool call shapes; journal must normalize to common schema.
- **Runner integration** -- Load journal before agent launch, inject `context.md` into prompt, periodic sync during execution.
- **E19 failure recovery** -- Preserve journal across retries, include "you tried X before" context, detect retry loops from journal.
- **Web UI** -- Real-time journal display in Observatory, agent detail tabs (Tool History, Raw Journal, Checkpoints), failed agent debugging panel.
- **Protocol docs** -- E23A in `execution-rules.md`, I4 clarification in `invariants.md`, journal entry format in `message-formats.md`.
