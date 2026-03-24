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

## PROGRAM Execution Hardening

Issues discovered during first real PROGRAM execution (unification-phase3, 2026-03-24). All are integration gaps between independently-built features.

Each item specifies SDK (engine function in `scout-and-wave-go`), CLI (`sawtools` command), and Web (API route + UI in `scout-and-wave-web`) implementation scope. The pattern: SDK provides business logic, CLI and Web are thin I/O wrappers over the same SDK function.

### P1: `prepare-wave` Branch Restoration (Critical)

`prepare-wave` checks out the merge-target branch for baseline verification but never restores the original branch. Leaves HEAD on a transient IMPL branch, causing downstream chaos when the orchestrator makes inline fixes on the wrong branch. **Must fix before P7** — wrong-branch state affects P7's worktree/branch detection logic.

| Layer | Scope |
|-------|-------|
| **SDK** | No engine-level `PrepareWave` function exists yet — the logic is in the CLI command. Either: (a) extract `PrepareWave` into `pkg/engine/wave_prepare.go` with branch save/restore built in, or (b) fix directly in `cmd/sawtools/prepare_wave.go` lines 222-226 (the `--merge-target` checkout path). Save `git branch --show-current` before checkout, restore with `git checkout <saved>` in a `defer` after baseline verification completes (success or failure). Add `OriginalBranch string` to the CLI's `PrepareWaveResult` for observability. |
| **CLI** | `cmd/sawtools/prepare_wave.go` — primary fix location. The checkout + restore logic lives here. |
| **Web** | `pkg/api/wave_runner.go` — if SDK extraction (option a), web calls the same function. If CLI-only fix (option b), web's `runPrepareWave` needs the same save/restore pattern. Add `original_branch` field to SSE `wave_prepare_complete` event. |

### P2: Cross-Repo Build in `finalize-wave`

`finalize-wave` only verifies the merged repo builds. Cross-repo dependents (e.g., web repo importing go repo) can break silently. Currently caught at next wave's `prepare-wave` (E21B), which is correct but late — the integration gap is already merged.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/engine/wave_finalize.go` — add `CrossRepoVerify bool` to `FinalizeWaveOpts`. When true, after primary repo merge + verify-build, run `RunCrossRepoBaselineGates` on all repos from the IMPL's `file_ownership`. Add `CrossRepoResults map[string]*BaselineData` to `FinalizeWaveResult`. |
| **CLI** | `cmd/sawtools/finalize_wave.go` — add `--cross-repo-verify` flag, pass to SDK. Include cross-repo results in JSON output. |
| **Web** | `pkg/api/wave_runner.go` — always enable cross-repo verify in web flows (web users can't easily fix post-merge). Emit `cross_repo_verify` SSE event with per-repo pass/fail status. Add red/green indicators to wave finalization UI. |

### P3: Brief Re-Validation at `prepare-wave` Time

IMPL briefs scouted before prerequisite tiers run go stale. Tier 1 changes function names, deletes types, and adds new APIs — but Tier 2 briefs still reference the old state. Required 20 manual replacements in repo-entry-unification.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/brief_validate.go` (new) — `ValidateBriefSymbols(briefPath, repoDir string) []BriefWarning`. Parse the brief markdown for Go symbol references (function names, type names, import paths). Verify each exists in the codebase via `go doc` or grep. Return warnings for missing symbols. Non-blocking (informational). |
| **CLI** | `cmd/sawtools/prepare_wave.go` — add `--revalidate-briefs` flag. When set, run `ValidateBriefSymbols` on each extracted brief before creating worktrees. Print warnings but don't block (briefs may reference symbols the agent will create). |
| **Web** | `pkg/api/wave_runner.go` — always run brief validation before wave launch. Display warnings in the wave preparation UI panel. User can dismiss and proceed. |
| **Alternative** | Add `sawtools revalidate-briefs <impl-doc> --wave N` standalone command for manual use. Re-scout Tier 2 IMPLs after Tier 1 completes (heavier but more accurate). |

### P4: Cross-Tier Dependency Graph Validation

Tier 1 created `config/state.go` importing `protocol`, making `protocol → config` impossible for Tier 2 (import cycle). The dependency graph across tiers was never validated.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/tier_deps.go` (new) — `CheckTierDependencyGraph(manifest *PROGRAMManifest, repoDir string) result.Result[*TierDepsData]`. For each tier boundary, analyze Go import graphs: collect packages modified by Tier N IMPLs, check if Tier N+1 IMPL files can import them without cycles. Uses `go list -json ./...` to build the import graph. Returns cycle details if found. |
| **CLI** | `cmd/sawtools/check_tier_deps_cmd.go` (new) — `sawtools check-tier-deps <program-manifest> --repo-dir <path>`. Integrate into `prepare-tier` as a pre-flight step (after P1+ conflict check, before IMPL validation). |
| **Web** | `pkg/api/program_handler.go` — add `POST /api/program/{slug}/check-tier-deps` endpoint. Call `CheckTierDependencyGraph`. Display cycle warnings in program status panel (no graph library currently in web app — use text/table format, not directed graph visualization). |

### P5: Critic Verdict "ISSUES" with 0 Errors Should Auto-Pass

`criticPassed()` only accepts verdict "PASS". The critic returns "ISSUES" when there are warnings but 0 errors — which is advisory per protocol ("ISSUES (warnings only): Advisory"). In autonomous mode, this blocks execution unnecessarily.

**Two code paths need the same fix:**
1. `pkg/protocol/program_tier_prepare.go` — `criticPassed()` at line 166 (PROGRAM flow)
2. `cmd/sawtools/prepare_wave.go` — E37 enforcement at lines 116-138 (standalone wave flow, blocks on ANY "ISSUES" verdict)

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/program_tier_prepare.go` — update `criticPassed()` to return true when `CriticReport.Verdict == "PASS"` OR (`Verdict == "ISSUES"` AND all `AgentReviews[*].Issues[*].Severity == "warning"`). Note: issues are nested per-agent in `CriticData.AgentReviews`, not at the top level. Add `AutoMode bool` to `PrepareTierOpts` — when true, auto-pass warnings. |
| **CLI** | `cmd/sawtools/prepare_wave.go` lines 116-138 — apply the same severity-aware logic. Currently blocks on any ISSUES verdict without checking severity. `cmd/sawtools/prepare_tier_cmd.go` — add `--auto` flag that sets `AutoMode: true`. |
| **Web** | `pkg/api/program_handler.go` — web always presents warnings to user with "proceed anyway?" dialog. On user confirmation, re-run `prepare-tier` with `AutoMode: true`. |
| **Protocol** | Update `execution-rules.md` E37 to explicitly state: "ISSUES verdict with 0 errors (warnings only) does not block `prepare-tier --auto`. Warnings are surfaced to the orchestrator but do not require correction." |

### P6: Incremental Agent Commits (Rate-Limit Resilience)

Rate-limited agents lose all uncommitted work when the worktree is cleaned up for retry. Agent A did 7/8 files but couldn't commit — the retry found a clean worktree and only fixed 1 file.

| Layer | Scope |
|-------|-------|
| **Protocol** | Update `agents/wave-agent.md` Field 4: "Commit incrementally. After each owned file is modified and verified, run `git add <file> && git commit -m 'partial: <file description>'`. Do not accumulate all changes for a single final commit. This ensures work survives rate limits, crashes, and context compaction." |
| **SDK** | `pkg/protocol/merge_agents.go` — `MergeAgents` already handles multi-commit branches via no-fast-forward merge (`git.MergeNoFFWithOwnership`). All commits on the branch are preserved. No SDK changes needed. |
| **CLI** | No changes — the `/saw` skill already uses `sawtools set-completion` which works with multi-commit branches. |
| **Web** | `pkg/api/wave_runner.go` — no changes. The web agent runner already collects all commits on the branch. Add real-time commit count to the agent progress SSE event: `{"agent": "A", "commits": 3, "status": "running"}`. |
| **Hook** | Consider a `PostToolUse` hook on `Write|Edit` that auto-commits after each file write in worktree context. Aggressive but guarantees no work is lost. |

### P7: `finalize-wave` Solo-Wave Merge Bug (High — data loss)

`finalize-wave` skips merge when worktree branches exist but worktree directories are gone. **Depends on P1** — if P1 leaves HEAD on the wrong branch, P7's detection logic runs against the wrong base.

The code at `cmd/sawtools/finalize_wave.go` has two checks: `WorktreesAbsent()` (line 111) and `AllBranchesAbsent()` (line 129). The bug is ordering: `WorktreesAbsent` runs first and short-circuits — if worktree directories were cleaned up but branches still exist, merge is skipped. The `AllBranchesAbsent` path only handles the idempotent re-run case (already merged AND cleaned), not the "worktrees gone, branches remain" case.

**Fix:** Check branches first, worktree directories second. If `git branch --list 'saw/{slug}/wave{N}-agent-*'` returns any branches, proceed to merge regardless of worktree directory state.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/engine/wave_finalize.go` — reorder: branch check before worktree check. If branches exist, merge them. If branches don't exist AND worktrees don't exist, skip (idempotent). |
| **CLI** | `cmd/sawtools/finalize_wave.go` — same reorder at lines 109-143. |
| **Web** | `pkg/api/wave_runner.go` — no changes (SDK fix). |

### P8: `finalize-tier` Auto-Update IMPL Statuses

`finalize-tier` required manual `update-program-impl --status complete` for each IMPL before the tier gate would pass. Successfully-merged IMPL branches are by definition complete.

**Status:** Fixed (2026-03-24). `finalize-tier` now auto-updates IMPL statuses to "complete" via `SaveProgramManifest` before running the tier gate. Works identically from CLI and web.

### P9: `CreateProgramWorktrees` Creates Branches, Not Worktrees

IMPL branches are merge targets — nobody works directly in them. The function was creating checked-out worktrees, which conflicted with `prepare-wave`'s own worktree creation.

**Status:** Fixed (2026-03-24). Now uses `git branch` instead of `git worktree add`. SDK function (`protocol.CreateProgramWorktrees`), CLI (`sawtools create-program-worktrees`), and web all use the same SDK function.

### P10: Cross-Repo IMPL Resolution in `prepare-tier`

`prepare-tier` resolved IMPL docs relative to `--repo-dir` (code repo), but IMPL docs live in the protocol repo. Cross-repo setups are the norm, not the exception.

**Status:** Fixed (2026-03-24). SDK function (`protocol.PrepareTier`) derives IMPL path from the PROGRAM manifest's directory. CLI and web both call the same SDK function.

### P11: `mark-program-complete` Should Archive PROGRAM Manifest

`mark-program-complete` sets state to COMPLETE and updates CONTEXT.md but does NOT move the manifest to an archive directory. `close-impl` archives to `docs/IMPL/complete/` — `mark-program-complete` should do the same to `docs/PROGRAM/complete/`.

| Layer | Scope |
|-------|-------|
| **SDK** | Add archival step to the engine function: `os.MkdirAll("docs/PROGRAM/complete/", 0755)` + `os.Rename`. Same pattern as `CloseIMPL` in `pkg/protocol/close_impl.go`. |
| **CLI** | `mark-program-complete` CLI command calls the same SDK function. No separate changes. |
| **Web** | Web's program completion handler should call the same SDK function. Add archive path to API response. |
| **Protocol** | Update `program-flow.md` Phase 4 step 1 to state the command archives the manifest. |

### P12: Orchestrator Should Call `mark-program-complete` Automatically

The `/saw program execute` flow (skill prompt) doesn't call `mark-program-complete` after the final tier gate passes. Currently the orchestrator uses `update-program-state --state COMPLETE` which skips CONTEXT.md update and archival.

| Layer | Scope |
|-------|-------|
| **Protocol** | Update `references/program-flow.md` Phase 4 to use `mark-program-complete` instead of `update-program-state`. Remove the "(or update state to COMPLETE manually if command not yet available)" hedge — the command exists. |
| **CLI** | `/saw` skill prompt — after `finalize-tier` succeeds for the final tier, call `sawtools mark-program-complete` instead of `sawtools update-program-state`. |
| **Web** | Web program runner should call `mark-program-complete` as the final step after tier gate passes. |

### P13: E37 Enforcement Divergence Between `prepare-tier` and `prepare-wave`

`prepare-tier` and `prepare-wave` both enforce E37 critic gate but with different logic. `prepare-tier` uses `criticPassed()` (checks `CriticReport.Verdict == "PASS"`). `prepare-wave` at lines 116-138 checks `CriticVerdictIssues` and blocks on ANY issues regardless of severity. These should be unified into a single SDK function.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/critic.go` — add `CriticGatePasses(m *IMPLManifest, autoMode bool) bool` that encapsulates the E37 verdict logic for both callers. Handles PASS, ISSUES-with-warnings-only (auto-pass when `autoMode`), and ISSUES-with-errors (always block). |
| **CLI** | Both `prepare_wave.go` and `prepare_tier_cmd.go` call `CriticGatePasses()` instead of inline checks. |
| **Web** | Web wave/program runners call the same SDK function. |

---

## Technical Debt

Items found via codebase `TODO` scan. Not P-priority but should be tracked.

- **`merge_agents.go:149`** — `MergeAgentsData.Success` backward-compat field should be removed once all consumers use `result.Result[T].IsSuccess()`
- **`engine/chat.go:109`** — `TODO: Extend backend.Backend interface to accept message arrays` (multi-turn chat support)
- **`engine/resolve_conflicts.go:172`** — `TODO: Filter contracts based on file location or agent dependencies` (contract filtering for conflict resolution)
- **Undocumented `sawtools` commands** — `freeze-contracts`, `detect-cascades`, `solve`, `daemon`, `run-review`, `interview`, `import-impls`, `create-program` exist but are not referenced in ROADMAP or protocol docs

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
