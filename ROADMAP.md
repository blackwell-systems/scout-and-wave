# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

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

**Status:** UI shipped (v0.17.0, `NotSuitableResearchPanel`). **Protocol spec updates still pending.**

Decouple verdict from research. NOT SUITABLE IMPL docs should contain full file survey, dependency map, risk assessment, actionable "why not suitable" explanation, conditions for re-scouting, and serial implementation notes. Only agent prompts and wave execution loop are omitted.

**Protocol changes needed:** Update `message-formats.md` (required sections for NOT SUITABLE), update `agents/scout.md` (research always completes regardless of verdict).

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

### ~~P1: `prepare-wave` Branch Restoration~~ ✅ FIXED

**Status:** Fixed in scout-and-wave-go@ad87f05

`prepare-wave` now saves the current branch before checking out merge-target and restores it via defer on all exit paths (success or failure). Added `OriginalBranch` field to `PrepareWaveResult` for observability.

**Implementation:** `pkg/engine/prepare.go` lines 253-265 — saves branch with `git branch --show-current`, deferred restore in all cases. `pkg/engine/step_types.go` line 40 — added `OriginalBranch string` field to result struct.

### P2: Cross-Repo Build in `finalize-wave`

`finalize-wave` only verifies the merged repo builds. Cross-repo dependents (e.g., web repo importing go repo) can break silently. Currently caught at next wave's `prepare-wave` (E21B), which is correct but late — the integration gap is already merged.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/engine/wave_finalize.go` — add `CrossRepoVerify bool` to `FinalizeWaveOpts`. When true, after primary repo merge + verify-build, run `RunCrossRepoBaselineGates` on all repos from the IMPL's `file_ownership`. Add `CrossRepoResults map[string]*BaselineData` to `FinalizeWaveResult`. |
| **CLI** | `cmd/sawtools/finalize_wave.go` — add `--cross-repo-verify` flag, pass to SDK. Include cross-repo results in JSON output. |
| **Web** | `pkg/api/wave_runner.go` — always enable cross-repo verify in web flows (web users can't easily fix post-merge). Emit `cross_repo_verify` SSE event with per-repo pass/fail status. Add red/green indicators to wave finalization UI. |

### P3: Stale Briefs in Pre-Existing IMPLs (Program Mode Only)

**Scope:** Pre-existing IMPLs (status "reviewed") imported into Tier 2+ via `import-impls`. Newly scouted IMPLs don't have this problem — E31 launches Scouts per-tier, so they see the post-Tier-1 codebase.

**Problem:** Tier 1 changes function names, deletes types, and adds new APIs — but pre-existing Tier 2 briefs still reference the old state. Required 20 manual replacements in repo-entry-unification.

**Root cause:** Pre-existing IMPLs skip Scout (E28A) — they were scouted outside program context and imported wholesale. Their briefs reference the codebase state at their original Scout time, not at tier-boundary time.

| Layer | Scope |
|-------|-------|
| **Protocol** | Document the limitation in `program-flow.md` E28A section: "Pre-existing IMPLs imported to Tier 2+ may have stale briefs if Tier 1 modifies their dependencies. Recommend re-scouting with `--refresh-brief` after importing." |
| **CLI** | Add `sawtools run-scout --resume <impl-doc> --refresh-brief` flag: re-runs Scout but preserves file ownership/wave structure, only updates agent briefs to reflect current codebase state. |
| **Orchestrator** | Add tier-boundary checklist after Tier N completes: list pre-existing IMPLs in Tier N+1, ask "These IMPLs may have stale briefs. Re-scout? (y/n)", run `--refresh-brief` if confirmed. |
| **Alternative (rejected)** | Symbol validation at prepare-wave time: high false-positive rate (briefs may reference symbols the agent will create), doesn't fix stale briefs (user still does 20 manual replacements), language-specific. |

### P4: Cross-Tier Dependency Graph Validation

Tier 1 created `config/state.go` importing `protocol`, making `protocol → config` impossible for Tier 2 (import cycle). The dependency graph across tiers was never validated.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/tier_deps.go` (new) — `CheckTierDependencyGraph(manifest *PROGRAMManifest, repoDir string) result.Result[*TierDepsData]`. For each tier boundary, analyze Go import graphs: collect packages modified by Tier N IMPLs, check if Tier N+1 IMPL files can import them without cycles. Uses `go list -json ./...` to build the import graph. Returns cycle details if found. |
| **CLI** | `cmd/sawtools/check_tier_deps_cmd.go` (new) — `sawtools check-tier-deps <program-manifest> --repo-dir <path>`. Integrate into `prepare-tier` as a pre-flight step (after P1+ conflict check, before IMPL validation). |
| **Web** | `pkg/api/program_handler.go` — add `POST /api/program/{slug}/check-tier-deps` endpoint. Call `CheckTierDependencyGraph`. Display cycle warnings in program status panel (no graph library currently in web app — use text/table format, not directed graph visualization). |

### ~~P5: Critic Verdict "ISSUES" with 0 Errors Should Auto-Pass~~ ✅ FIXED

**Status:** Fixed in scout-and-wave-go@[commit-sha] (friction-fixes-phase1-execution IMPL)

**Implementation:** Created `pkg/protocol/CriticGatePasses(m *IMPLManifest, autoMode bool)` helper function. Updated prepare-wave CLI and prepare-tier SDK to use severity-aware logic. ISSUES verdicts with warnings-only now pass in auto mode. ISSUES verdicts with any errors always block, regardless of mode.

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


### ~~P11: `mark-program-complete` Archive~~ ✅ ALREADY IMPLEMENTED

**Status:** `mark-program-complete` already archives to `docs/PROGRAM/complete/` (line 89 in mark_program_complete_cmd.go). No code changes needed.

**Fix:** Update `program-flow.md` Phase 4 to document that mark-program-complete is a batching command (archives + updates CONTEXT.md + commits).

### ~~P12: Orchestrator Auto-Call~~ ✅ DOCUMENTATION FIX ONLY

**Status:** `mark-program-complete` already updates CONTEXT.md (line 98) and commits atomically (line 106). The command exists and works correctly.

**Fix:** Remove outdated hedge "(or update state to COMPLETE manually if command not yet available)" from `program-flow.md` Phase 4. Remove redundant step 2 (update-context) since mark-program-complete handles it.

### P13: E37 Enforcement Divergence Between `prepare-tier` and `prepare-wave`

`prepare-tier` and `prepare-wave` both enforce E37 critic gate but with different logic. `prepare-tier` uses `criticPassed()` (checks `CriticReport.Verdict == "PASS"`). `prepare-wave` at lines 116-138 checks `CriticVerdictIssues` and blocks on ANY issues regardless of severity. These should be unified into a single SDK function.

| Layer | Scope |
|-------|-------|
| **SDK** | `pkg/protocol/critic.go` — add `CriticGatePasses(m *IMPLManifest, autoMode bool) bool` that encapsulates the E37 verdict logic for both callers. Handles PASS, ISSUES-with-warnings-only (auto-pass when `autoMode`), and ISSUES-with-errors (always block). |
| **CLI** | Both `prepare_wave.go` and `prepare_tier_cmd.go` call `CriticGatePasses()` instead of inline checks. |
| **Web** | Web wave/program runners call the same SDK function. |

### ~~F3: REVIEWED → COMPLETE State Transition~~ ✅ FIXED

**Status:** Fixed in scout-and-wave-go@[commit-sha] (friction-fixes-phase1-execution IMPL)

Added REVIEWED → COMPLETE to allowed state transitions in `pkg/protocol/state_transition.go`. Allows `close-impl` to complete IMPLs without wave execution (e.g., manual closure, or cancelled work after review). Protocol documentation updated in `protocol/state-machine.md`.

### ~~F4: Cross-Repo finalize-wave Support~~ ✅ FIXED

**Status:** Fixed in scout-and-wave-go@[commit-sha] (friction-fixes-phase1-execution IMPL)

Updated `cmd/sawtools/finalize_wave.go` to properly aggregate merge results across multiple repos. Detects cross-repo waves from file_ownership `repo:` values and runs merge-agents per repo. Cross-repo IMPL docs now finalize correctly without manual intervention.

---

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

**Status:** Core journal shipped (v0.27.0). E23A documented in execution-rules.md. CLI commands (`journal-init`, `journal-context`) exist.

Remaining integration work:

- **Backend integration** -- Hook journaling into all agent backends (Anthropic API, CLI, OpenAI). Each has different tool call shapes; journal must normalize to common schema.
- **Runner integration** -- Load journal before agent launch, inject `context.md` into prompt, periodic sync during execution.
- **E19 failure recovery** -- Preserve journal across retries, include "you tried X before" context, detect retry loops from journal.
- **Web UI** -- Real-time journal display in Observatory, agent detail tabs (Tool History, Raw Journal, Checkpoints), failed agent debugging panel.
