# Protocol Conformity Audit — 2026-03-21

## Executive Summary

- **41 execution rules audited** (E1–E41)
- **6 invariants audited** (I1–I6)
- **9 protocol→engine gaps found** (MISSING or PARTIAL)
- **12 engine→protocol leads found** (engine does more than spec says)
- **5 schema divergences found**
- **3 CLI commands missing or mismatched**

Overall assessment: the Go engine has strong conformity with protocol core (I1–I6, E1–E5, E9, E11, E14–E22, E36–E41). The largest gaps are in E40 (observability events not wired to lifecycle hooks despite the infrastructure existing), E7/E8 (partial/blocked wave handling — `RouteFailure` exists but is not integrated into `finalize-wave` or `run-wave` flows), and E6 (interface deviation propagation — `update-agent-prompt` command exists but downstream deviation propagation is not automated).

---

## Invariant Conformity (I1–I6)

### I1: Disjoint File Ownership
- **Status:** IMPLEMENTED
- **Protocol says:** No two agents in the same wave own the same file. Hard constraint that makes parallel execution safe.
- **Engine does:**
  - `validateI1DisjointOwnership()` in `pkg/protocol/validation.go:53` — called by `Validate()` — checks file ownership table for same-wave duplicates, returns `I1_VIOLATION` error code.
  - `detectOwnershipConflicts()` in `pkg/protocol/conflict.go:22` — post-completion check that cross-references `files_changed`/`files_created` from completion reports.
  - I1 Amendment (Integration Agent exemption) implemented: `pkg/protocol/integration.go` uses `AllowedPathPrefixes` to restrict Integration Agent writes.
- **Gap:** I1 validation runs at schema-validate time and at post-completion time. There is no explicit E3 pre-launch ownership verification run as a discrete step in `prepare-wave` (the disjoint check is embedded in `validate` but prepare-wave does not call `validate` on the manifest before creating worktrees). See E3 below.

### I2: Interface Contracts Precede Parallel Implementation
- **Status:** IMPLEMENTED
- **Protocol says:** Scaffold Agent implements interfaces as committed scaffold files before any Wave Agent launches. Orchestrator verifies all scaffold files show `committed` status before creating worktrees.
- **Engine does:**
  - `prepare-wave` step 0d (line 252): `protocol.AllScaffoldsCommitted(doc)` — if scaffolds exist but any is not committed, preparation fails with `"scaffolds not committed — run Scaffold Agent before creating worktrees"`.
  - `pkg/protocol/scaffold_validation.go` provides `ValidateScaffolds()` and `AllScaffoldsCommitted()`.
  - Freeze enforcement: `WorktreesCreatedAt` timestamp + `FrozenContractsHash`/`FrozenScaffoldsHash` fields in `IMPLManifest`; `CheckFreeze()` in `pkg/protocol/freeze.go` detects post-freeze mutations.
- **Gap:** None significant. Freeze check runs in prepare-wave step 0e.

### I3: Wave Sequencing
- **Status:** IMPLEMENTED
- **Protocol says:** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed.
- **Engine does:**
  - `validateI3WaveOrdering()` in `pkg/protocol/validation.go:148` checks sequential wave numbering (1, 2, 3…).
  - State machine transitions in `pkg/orchestrator/transitions.go`: `WAVE_VERIFIED → WAVE_PENDING` (next wave) enforced; `WAVE_EXECUTING → WAVE_MERGING` enforced. No transition from `WAVE_EXECUTING` directly to another wave's `WAVE_PENDING`.
  - `FinalizeWave` enforces the full pipeline (verify → stub scan → gates → merge → build verify → cleanup) before returning success.
- **Gap:** None significant.

### I4: IMPL Doc is Single Source of Truth
- **Status:** IMPLEMENTED
- **Protocol says:** Completion reports written to IMPL doc. Chat output is not the record.
- **Engine does:**
  - All agent-facing tooling writes completion reports to YAML manifest via `protocol.Save()`.
  - `validateI4RequiredFields()` in `pkg/protocol/validation.go:170` checks required manifest fields (`title`, `feature_slug`, `verdict`).
  - Journal duality (I4 amendment) implemented: `pkg/journal/` package for execution history, IMPL doc for planning/results.
- **Gap:** None significant. I4 field validation is present; the journal/IMPL duality is well-implemented.

### I5: Agents Commit Before Reporting
- **Status:** IMPLEMENTED
- **Protocol says:** Agents commit before writing completion report. `"uncommitted"` in `commit:` field flags a violation.
- **Engine does:**
  - `validateI5CommitBeforeReport()` in `pkg/protocol/validation.go` (line ~229) checks that agents with `status: complete` have non-empty, non-`"uncommitted"` commit SHAs.
  - `protocol.VerifyCommits()` in `pkg/protocol/commit_verify.go` — runs as step 1 of `FinalizeWave`, blocking merge if agents have no commits.
  - `finalize-wave` step 1 (CLI, line 123): VerifyCommits runs per-repo before merge.
- **Gap:** None significant.

### I6: Role Separation
- **Status:** PARTIALLY IMPLEMENTED
- **Protocol says:** Orchestrator does not perform Scout, Scaffold Agent, Wave Agent, or Integration Agent duties.
- **Engine does:**
  - `hooks.ValidateScoutWrites()` in `pkg/hooks/scout_boundaries.go` — called in `RunScout()` after execution (line 113 of `pkg/engine/runner.go`) — validates that Scout only wrote to `docs/IMPL/IMPL-*.yaml`, not other files.
  - `RunScout()`, `RunWave()`, `RunPlanner()` are correctly separated into distinct execution functions that launch sub-agents.
- **Gap (partial):** The I6 check is file-boundary-based (did Scout write only to IMPL docs?) rather than role-behavior-based (did Orchestrator perform Scout analysis inline?). If the Orchestrator calls `RunScout()` from its own goroutine without asynchronous separation, that's an I6 violation that would not be caught. The engine has no check that `RunScout` was dispatched asynchronously (E1 enforcement is missing at the orchestrator level — see E1 below).

---

## Execution Rule Conformity (E1–E41)

### E1: Background Execution
- **Status:** PARTIAL
- **Protocol says:** All agent launches, CI polling, and long-running watch commands MUST execute asynchronously. Blocking the orchestrator violates the protocol.
- **Engine does:** `pkg/orchestrator/orchestrator.go` uses `errgroup` and goroutines for launching multiple Wave agents concurrently. `RunScout()` in `pkg/engine/runner.go` is callable asynchronously but is a synchronous function — callers must wrap it in a goroutine.
- **Gap:** No enforcement that Scout/Wave launches are non-blocking. In the `run-scout` CLI command (`cmd/saw/run_scout_cmd.go`), `RunScout` is called synchronously (blocking the CLI process). This is acceptable for CLI-mode operation, but the protocol requires asynchronous dispatch. The engine does not enforce or document the requirement that callers must wrap in goroutines.

### E2: Interface Freeze
- **Status:** IMPLEMENTED
- **Protocol says:** Worktree creation freezes interface contracts. Post-freeze changes require recreating worktrees or descoping.
- **Engine does:** `WorktreesCreatedAt` timestamp stored in manifest when worktrees are created (`pkg/protocol/worktree.go`). `CheckFreeze()` hashes frozen contracts/scaffolds and detects changes. `prepare-wave` step 0e calls `CheckFreeze()` and blocks if violations found.
- **Gap:** Recovery paths (cherry-pick or descope from E2) are not automated — this is by design (human decision required).

### E3: Pre-Launch Ownership Verification
- **Status:** PARTIAL
- **Protocol says:** Before creating worktrees, orchestrator scans the wave's file ownership table and verifies no file appears in more than one agent's ownership list. If overlap found, wave does not launch.
- **Engine does:** `validateI1DisjointOwnership()` exists in `pkg/protocol/validation.go` and is called by `Validate()`. However, `prepare-wave` does NOT call `Validate()` before creating worktrees (step 0b/0c/0d checks run, but not the full `Validate()` call that includes I1 disjoint check). Cross-repo disjoint ownership check (per-repo) is also present in `DetectOwnershipConflicts()`.
- **Gap:** The E3-mandated pre-launch ownership scan is not explicitly called in `prepare-wave`. The I1 check runs only when `sawtools validate` is invoked separately. If a user calls `prepare-wave` without first running `validate`, ownership overlaps can pass through. This is a conformity gap — E3 requires the check to be part of the launch gate.

### E4: Worktree Isolation
- **Status:** IMPLEMENTED
- **Protocol says:** All Wave agents MUST use worktree isolation (no exceptions).
- **Engine does:**
  - `protocol.CreateWorktrees()` creates worktrees for all agents.
  - Pre-commit hook installed at step 1.5 of `prepare-wave` (line 282) via `verifyHookInstalled()`.
  - Solo wave detection in `finalize-wave` (line 87): skips VerifyCommits/MergeAgents for solo waves without worktrees (correctly documented).
  - Layer 0 (pre-commit hook), Layer 1 (manual creation), Layer 3 (Field 0 self-verification in agent brief), Layer 4 (empty-branch trip wire in VerifyCommits) all implemented.
- **Gap:** Layer 2 (Task tool isolation parameter) is outside engine scope (implemented in the `/saw` skill prompt).

### E5: Worktree Naming Convention
- **Status:** IMPLEMENTED
- **Protocol says:** `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}` format. Branch: `saw/{slug}/wave{N}-agent-{ID}`.
- **Engine does:** `pkg/protocol/branchname.go` implements canonical name generation. `ValidateWorktreeNames()` in `pkg/protocol/validation.go` validates names. Backward compatibility for pre-v0.39.0 legacy format accepted.
- **Gap:** None significant.

### E6: Agent Prompt Propagation
- **Status:** PARTIAL
- **Protocol says:** When orchestrator updates an agent prompt (e.g., due to interface deviation), it edits the IMPL doc directly. Agent reads its prompt at launch time from the IMPL doc.
- **Engine does:** `sawtools update-agent-prompt` command exists (`cmd/saw/update_agent_prompt_cmd.go`) — allows patching an agent's task in the manifest. `prepare-wave` re-extracts briefs from current manifest state, so updated prompts propagate to agents on next launch.
- **Gap:** Propagation of interface deviations is not automated. When an agent reports `interface_deviations` with `downstream_action_required: true`, there is no engine logic that reads the deviation, updates downstream agent prompts in the manifest, and re-issues them. The `update-agent-prompt` command requires manual invocation. E6 as a fully automated protocol step is MISSING.

### E7: Agent Failure Handling
- **Status:** PARTIAL
- **Protocol says:** Wave with any `partial` or `blocked` agent does not merge. Wave goes to BLOCKED state.
- **Engine does:**
  - `RouteFailure()` in `pkg/orchestrator/failure.go` correctly maps `failure_type` values to orchestrator actions (ActionRetry, ActionApplyAndRelaunch, ActionReplan, ActionEscalate, ActionRetryWithScope).
  - State machine supports `WAVE_EXECUTING → BLOCKED` transition.
  - `pkg/orchestrator/orchestrator.go` (the web-app orchestrator) has retry loop logic.
- **Gap:** The `finalize-wave` CLI command does NOT check completion report statuses for `partial`/`blocked` before proceeding with merge. It calls `VerifyCommits` (I5 check for commits) but does not inspect `status` fields from completion reports and block on `partial`/`blocked`. In the CLI workflow, the human is expected to notice and not run `finalize-wave`. This is a conformity gap: E7 requires the engine to enforce the merge block, not rely on human discipline.

### E7a: Automatic Failure Remediation in --auto Mode
- **Status:** IMPLEMENTED
- **Protocol says:** In `--auto` mode, orchestrator auto-relaunches agents for correctable failures (isolation failures, missing deps, transient errors) up to 2 retries.
- **Engine does:** `AutoRemediate()` in `pkg/engine/auto_remediate.go` — loops up to `MaxRetries` calling `FixBuildFailure` then `VerifyBuild`. Wired into `run-wave` and daemon flows. `MaxTransientRetries = 2` constant in orchestrator.
- **Gap:** None significant.

### E8: Same-Wave Interface Failure
- **Status:** PARTIAL
- **Protocol says:** When an agent reports `blocked` due to unimplementable interface contract, wave enters BLOCKED, orchestrator revises contracts, re-issues prompts, wave restarts from WAVE_PENDING with corrected contracts.
- **Engine does:** State machine allows `WAVE_EXECUTING → BLOCKED → WAVE_PENDING`. `RouteFailure(needs_replan)` returns `ActionReplan`. However, there is no engine code that automatically re-engages Scout when `needs_replan` is detected in `finalize-wave`.
- **Gap:** The full E8 recovery loop (detect needs_replan → re-engage Scout → update contracts → restart wave) is not implemented in the engine. `ActionReplan` is defined but there is no code that executes it (no `RelaunchScoutForReplan()` function exists).

### E9: Idempotency
- **Status:** IMPLEMENTED
- **Protocol says:** WAVE_PENDING is re-entrant (no duplicate worktrees). WAVE_MERGING is not idempotent (inspect state if crash mid-merge).
- **Engine does:**
  - `prepare-wave` step 0a2 detects and cleans stale worktrees from same slug before creating new ones (line 150).
  - `protocol.MergeAgents()` uses a merge-log (`pkg/protocol/merge_log.go`) to track which branches have been merged — already-merged branches are skipped, implementing idempotency for re-run scenarios.
  - `validateE9MergeState()` validates `merge_state` enum values.
- **Gap:** None significant.

### E10: Scoped vs Unscoped Verification
- **Status:** PARTIAL
- **Protocol says:** Agents run scoped verification (their own packages only). Orchestrator post-merge gate runs unscoped. Scout must specify exact scoped verification commands in Field 6.
- **Engine does:**
  - `ValidateVerificationField()` in `pkg/protocol/fieldvalidation.go` validates completion report `verification:` field format (`PASS` or `FAIL (...)`) — uses `E10_INVALID_VERIFICATION` error code.
  - Post-wave quality gates run on the merged codebase (unscoped, per E21).
- **Gap:** The engine has no mechanism to enforce that agents ran only scoped commands (it can only validate the format of their self-reported verification). If an agent runs `go test ./...` when it should run `go test ./pkg/mypackage/`, the engine cannot detect this violation from the completion report alone. This is a documentation gap rather than a hard implementation gap — the scout must set Field 6 correctly.

### E11: Conflict Prediction Before Merge
- **Status:** IMPLEMENTED
- **Protocol says:** Before merging, orchestrator cross-references all agents' `files_changed`/`files_created` lists. A file in more than one agent's list is a disjoint ownership violation; resolve before any merge.
- **Engine does:** `predictConflicts()` in `pkg/orchestrator/merge.go:208` cross-references files from all completion reports, returns error if any file is claimed by multiple agents. Called as part of the merge flow in the orchestrator.
- **Gap:** `finalize-wave` CLI (`cmd/saw/finalize_wave.go`) does NOT call `predictConflicts()` before `MergeAgents`. The E11 check lives in the orchestrator (web-app) path but is absent from the `sawtools finalize-wave` CLI path. This is a CLI-path conformity gap.

### E12: Merge Conflict Taxonomy
- **Status:** IMPLEMENTED (documentation level)
- **Protocol says:** Three conflict types with distinct resolution paths (git conflict on agent files = I1 violation; git conflict on shared files = accept appended sections; semantic conflict = resolve before next wave).
- **Engine does:** The merge taxonomy is documented and the merge-agents implementation follows it — IMPL doc conflicts (completion reports) are resolved by accepting all appended sections. No special semantic conflict detection beyond `interface_deviations` parsing.
- **Gap:** None significant.

### E13: Verification Minimum
- **Status:** PARTIAL
- **Protocol says:** Minimum is build+lint passing. Tests required if project has a test suite.
- **Engine does:** `VerifyBuild()` in `pkg/protocol/verify_build.go` runs `test_command` and `lint_command`. Quality gates system (E21) is more flexible.
- **Gap:** No explicit check that a project with a test suite must include a test gate. A scout could configure `quality_gates.gates` with only a build gate on a project that has tests, and E13 would not fire. Enforcement relies on scout judgment.

### E14: IMPL Doc Write Discipline
- **Status:** IMPLEMENTED
- **Protocol says:** Agents append only their named completion report section. Never edit earlier sections.
- **Engine does:**
  - `completion_reports:` map at root level in YAML (keyed by agent ID) — each agent appends under their ID key.
  - `save-completion-report` flow writes only to the `completion_reports` map, never touching other top-level keys.
  - The YAML merge conflict pattern (two agents appending to the same map) is handled by accepting all sections.
- **Gap:** None significant.

### E15: IMPL Doc Completion Marker
- **Status:** IMPLEMENTED
- **Protocol says:** On final wave verified → COMPLETE, write `<!-- SAW:COMPLETE YYYY-MM-DD -->` to IMPL doc.
- **Engine does:** `protocol.WriteCompletionMarker()` in `pkg/protocol/marker.go` — writes the HTML comment marker. Called by `engine.MarkIMPLComplete()` in `pkg/engine/finalize.go:200`. `sawtools mark-complete` command also calls it. Amend guard present: E15 specifies amend is invalid after COMPLETE marker; `pkg/protocol/amend.go` checks for `ErrAmendBlocked` sentinel when `completion_date` is set.
- **Gap:** None significant.

### E16: Scout Output Validation
- **Status:** IMPLEMENTED
- **Protocol says:** After Scout writes IMPL doc, run validator. Feed errors back to Scout for correction. Retry up to 3 times. After 3 failures, enter BLOCKED.
- **Engine does:**
  - `ValidateIMPLDoc()` in `pkg/protocol/validator.go:58` — full typed-block validation including E16A (required blocks), E16B (dep graph grammar), E16C (out-of-band detection).
  - `ScoutCorrectionLoop()` in `pkg/engine/scout_correction_loop.go` — runs Scout → validate → retry up to `MaxScoutCorrectionRetries = 3`. On exhaustion, calls `setIMPLStateBlocked()`.
  - E16D enhanced checks: `ValidateDuplicateKeys()`, `ValidateActionEnums()`, `ValidateIntegrationChecklist()`, `ValidateFileExistence()` all wired into `Validate()`.
  - `sawtools validate` command exists and is used by `finalize-impl` as step 5.
- **Gap:** None significant. Full implementation.

### E17: Scout Reads Project Memory
- **Status:** IMPLEMENTED
- **Protocol says:** Scout checks for `docs/CONTEXT.md` before suitability assessment and uses it.
- **Engine does:** `readContextMD()` called in `RunScout()` (`pkg/engine/runner.go:83`) — prepends full `docs/CONTEXT.md` content to Scout prompt as `## Project Memory` section. Also implemented for Planner (`RunPlanner()` line 153).
- **Gap:** None significant.

### E18: Orchestrator Updates Project Memory
- **Status:** IMPLEMENTED
- **Protocol says:** On WAVE_VERIFIED → COMPLETE, create/update `docs/CONTEXT.md` with new decisions, interfaces, completed feature entry.
- **Engine does:** `engine.MarkIMPLComplete()` calls `protocol.UpdateContext()` (line 206) which is implemented in `pkg/protocol/context_update.go`. `ProjectMemory` struct in `pkg/protocol/memory.go` matches the protocol schema. `sawtools update-context` command also exists.
- **Gap (minor):** `ProjectMemory.Architecture` uses `ArchitectureDescription` struct with `Language`/`Stack`/`Summary` fields, but the protocol schema in `message-formats.md` expects `architecture.description` (string) and `architecture.modules[]`. The Go struct does not include `modules` array. This is a schema divergence — see Schema Divergences section.

### E19: Failure Type Decision Tree
- **Status:** IMPLEMENTED
- **Protocol says:** Read `failure_type` from blocked/partial reports and apply: transient→retry(2x), fixable→fix+relaunch(1x), needs_replan→re-engage Scout, escalate→surface to human, timeout→retry once with scope-reduction note.
- **Engine does:**
  - `RouteFailure()` in `pkg/orchestrator/failure.go:22` correctly maps all 5 failure types to actions.
  - `RouteFailureWithReactions()` consults per-IMPL `reactions:` block override (E19.1) before falling back to defaults.
  - `MaxAttemptsFor()` respects per-IMPL overrides.
  - `MaxTransientRetries = 2` constant matches protocol default.
  - `types.FailureType` enum covers all 5 values.
- **Gap:** `RouteFailure()` logic exists and is correct, but the retry execution is scattered. In `finalize-wave` CLI, there is no code that reads `failure_type` from completion reports and routes accordingly. The routing is used in the web-app orchestrator but the CLI path lacks this integration (same gap as E7).

### E20: Stub Detection Post-Wave
- **Status:** IMPLEMENTED
- **Protocol says:** After all wave agents complete and before review checkpoint, run `scan-stubs.sh` on all changed files, append Stub Report to IMPL doc.
- **Engine does:** `protocol.ScanStubs()` in `pkg/protocol/stubs.go` — called in `FinalizeWave()` step 2 and in `finalize-wave` CLI. Results appended to `stub_reports` in manifest. `sawtools scan-stubs` command exists.
- **Gap:** None significant.

### E21: Automated Post-Wave Verification
- **Status:** IMPLEMENTED
- **Protocol says:** If IMPL doc has Quality Gates section, run each gate. `required: true` failures block merge.
- **Engine does:**
  - `protocol.RunGatesWithCache()` in `pkg/protocol/gates.go` — called in `FinalizeWave()` step 3. Caching via `gatecache.New()` (E38).
  - Fix-mode gates (E21 format gate fix mode) implemented: `gate.Fix` field in `QualityGate` struct, fix-mode gates run before check-only gates.
  - `sawtools run-gates` command exists.
  - Post-merge gates (`timing: "post-merge"`) supported in `finalize-wave` step 5.5.
- **Gap:** None significant.

### E21A: Pre-Wave Baseline Verification
- **Status:** IMPLEMENTED
- **Protocol says:** Before creating worktrees for multi-agent wave, run quality gates against current HEAD. Failure blocks wave launch.
- **Engine does:** `protocol.RunBaselineGates()` called in `prepare-wave` step 0b2 (line 226), before worktree creation. Solo wave exemption: `prepare-wave` documentation notes solo agents should use `prepare-agent --no-worktree`. Cache enabled by default via `gatecache`.
- **Gap:** None significant.

### E21B: Parallel Gate Execution
- **Status:** IMPLEMENTED
- **Protocol says:** Multiple quality gates must execute concurrently. Report all failures together.
- **Engine does:** `RunGatesWithCache()` uses goroutines to execute gates concurrently, collecting all results before returning. Both `run-gates` and `prepare-wave` baseline use this path.
- **Gap:** None significant.

### E22: Scaffold Build Verification
- **Status:** PARTIAL
- **Protocol says:** Scaffold Agent must run dependency resolution, cleanup, and build verification before committing. Failure marks scaffold `FAILED: {error}` and halts orchestrator.
- **Engine does:**
  - `sawtools validate-scaffold` command exists (`cmd/saw/validate_scaffold_cmd.go`) — validates a scaffold file compiles.
  - `pkg/scaffoldval/` package provides scaffold validation logic.
  - `sawtools detect-scaffolds` exists for auto-detecting scaffold file candidates.
- **Gap:** E22 specifies a full 3-step sequence (dependency resolution → dependency cleanup → build verification) run by the Scaffold Agent as an automated pipeline. The engine provides validation tooling but no `run-scaffold-agent` or `validate-scaffold-pipeline` command that enforces the sequence. The Scaffold Agent is an LLM agent (not an automated command), so the sequence is enforced by the agent prompt, not mechanically. This is partially acceptable but `validate-scaffold` only checks compilation of one file, not the full project build after scaffolds are added. The protocol requires `go build ./...` — the engine runs `go build` on the scaffold file's package, not the whole project.

### E23: Per-Agent Context Extraction
- **Status:** IMPLEMENTED
- **Protocol says:** Orchestrator constructs per-agent context payload (agent's prompt + interface contracts + file ownership + scaffolds + quality gates + IMPL path) instead of passing full IMPL doc.
- **Engine does:**
  - `prepare-wave` step 3 builds agent brief as structured markdown with task, files owned, interface contracts, quality gates, wiring section (line 344).
  - Brief written to `.saw-agent-brief.md` in each agent's worktree.
  - Orchestrator (`pkg/orchestrator/orchestrator.go:667`) constructs per-agent context payload via `extractContext()`.
  - `sawtools extract-context` command exists.
- **Gap:** The brief format in `prepare-wave` uses a simplified structure (task + files + contracts + gates), not the exact 9-field prompt format from `message-formats.md`. The 9-field format (Fields 0–8) is used by the `/saw` skill prompt directly; the engine-generated brief is a simpler subset. This may cause agents to miss isolation verification (Field 0) if they only read the brief.

### E23A: Tool Journal Recovery
- **Status:** IMPLEMENTED
- **Protocol says:** Before launching a Wave agent, check for existing journal at `.saw-state/wave{N}/agent-{ID}/index.jsonl`. If found, generate context.md summary and prepend to agent prompt.
- **Engine does:**
  - `pkg/journal/` package with `journal.GenerateContext()` in `pkg/journal/context.go:47` — analyzes last 50 entries (matches spec).
  - `PrepareAgentContext()` in `pkg/orchestrator/journal_integration.go:13` — loads journal and generates recovery context.
  - `pkg/engine/runner.go:904` — journal observers created, context injected into prompt if journal has events.
  - `sawtools journal-context` command for standalone journal context generation.
  - `sawtools debug-journal` command for inspection/debugging.
- **Gap:** None significant.

### E25: Integration Validation
- **Status:** IMPLEMENTED
- **Protocol says:** After wave merge, scan for unconnected exports. Produce `IntegrationReport` with gaps classified by severity. Non-fatal.
- **Engine does:**
  - `protocol.ValidateIntegration()` in `pkg/protocol/integration.go` — AST-based export scanning.
  - Called in `FinalizeWave()` step 3.5 (non-fatal).
  - `IntegrationReport` persisted to manifest under `integration_reports:` map.
  - `sawtools validate-integration` command exists.
- **Gap:** None significant.

### E26: Integration Agent
- **Status:** PARTIAL
- **Protocol says:** When E25 detects `error` or `warning` gaps, launch Integration Agent with `IntegrationReport` as input, restricted to `integration_connectors` files.
- **Engine does:**
  - `IntegrationConnectors` field in `IMPLManifest` exists.
  - Integration agent launch logic exists in `pkg/engine/integration_runner.go`.
  - `AllowedPathPrefixes` constraint implemented in `pkg/protocol/integration_types.go`.
- **Gap:** E26 launch preconditions from `preconditions.md` (E26-P1: integration report must exist and be invalid; E26-P2: integration connectors must be defined) — these preconditions are in the preconditions doc but validation is not enforced before launching the integration agent. If `integration_connectors` is absent, the engine proceeds anyway rather than emitting `integration_agent_failed`.

### E27: Planned Integration Waves
- **Status:** IMPLEMENTED
- **Protocol says:** Scout marks wiring-only waves with `type: integration`. Orchestrator dispatches as Integration Agent role, skips worktree creation.
- **Engine does:**
  - `Wave.Type` field in `IMPLManifest` struct with `"standard"` | `"integration"` values.
  - `prepare-wave` and `finalize-wave` check wave type; integration waves skip worktree creation/isolation.
  - `run-wave` dispatches `integration-agent` subagent type for integration waves.
- **Gap:** None significant.

### E28: Tier Execution Loop
- **Status:** IMPLEMENTED
- **Protocol says:** On `TIER_EXECUTING`, read current tier, launch Scouts for pending IMPLs in parallel, execute waves, track completion, transition to tier gate.
- **Engine does:**
  - `RunTierLoop()` in `pkg/engine/program_tier_loop.go:64` — full tier loop implementing E28–E34.
  - `PartitionIMPLsByStatus()` (E28A) called at line 97.
  - `LaunchParallelScouts()` stub at line 57 — `launchParallelScoutsFunc` is a function variable initialized to a stub returning `"not yet implemented"`. The real implementation is in `pkg/engine/program_parallel_scout.go`.
  - `sawtools program-execute` command exists and wires `RunTierLoop()`.
- **Gap:** `launchParallelScoutsFunc` starts as a stub in the tier loop file and must be overridden by `program_parallel_scout.go`. This pattern works but is brittle — if the injection is not wired at startup, the stub error surfaces at runtime.

### E28A: Pre-Existing IMPL Handling
- **Status:** IMPLEMENTED
- **Protocol says:** Before Scouts launch, partition IMPLs into `needsScout` (pending/scouting) and `preExisting` (reviewed/complete). Validate pre-existing; skip Scout for them.
- **Engine does:**
  - `protocol.PartitionIMPLsByStatus()` exists and is called in `RunTierLoop()`.
  - `protocol.ValidateProgramImportMode()` called for pre-existing IMPLs in step 5 of `RunTierLoop()`.
- **Gap:** None significant.

### E29: Tier Gate Verification
- **Status:** IMPLEMENTED
- **Protocol says:** When all IMPLs in tier complete, run `tier-gate`. Required gate failure enters BLOCKED.
- **Engine does:**
  - `protocol.RunTierGate()` called in `RunTierLoop()` step 9.
  - `sawtools tier-gate` command exists.
- **Gap:** None significant.

### E30: Program Contract Freezing
- **Status:** IMPLEMENTED
- **Protocol says:** After tier gate passes, freeze contracts for that tier via `sawtools freeze-contracts`.
- **Engine does:**
  - `protocol.FreezeContracts()` called in `RunTierLoop()` step 10.
  - `sawtools freeze-contracts` command exists.
- **Gap:** None significant.

### E31: Parallel Scout Launching
- **Status:** IMPLEMENTED
- **Protocol says:** Launch one Scout per IMPL in tier, all in parallel. Each Scout receives feature description + `--program` flag + standard Scout inputs.
- **Engine does:**
  - `LaunchParallelScouts()` in `pkg/engine/program_parallel_scout.go` — goroutine-based parallel Scout launch.
  - `--program` flag passed via `RunScoutOpts.ProgramManifestPath`, read in `RunScout()` to inject program contracts.
- **Gap:** None significant.

### E32: Cross-IMPL Progress Tracking
- **Status:** IMPLEMENTED
- **Protocol says:** Update PROGRAM manifest after each IMPL state change. `sawtools program-status` provides structured report.
- **Engine does:**
  - `protocol.GetProgramStatus()` / `sawtools program-status` command exists.
  - `ProgramCompletion` struct tracks all required counters.
- **Gap:** None significant.

### E33: Automatic Tier Advancement (--auto mode)
- **Status:** IMPLEMENTED
- **Protocol says:** In `--auto` mode, auto-advance to next tier after gate passes (freeze contracts → update state → launch Scouts). Never skip initial `PROGRAM_REVIEWED` gate.
- **Engine does:**
  - `RunTierLoop()` checks `opts.AutoMode` (line 140) — returns `RequiresReview = true` if not auto-mode.
  - Contract freezing, state advance, and next-tier Scout launch all happen automatically in the loop when `AutoMode: true`.
  - Initial `PROGRAM_REVIEWED` requirement enforced by precondition: tier loop only runs if `state == TIER_EXECUTING`, which requires prior human approval.
- **Gap:** None significant.

### E34: Planner Re-Engagement on Failure
- **Status:** IMPLEMENTED
- **Protocol says:** On tier gate failure, launch Planner with revision prompt (current manifest + failure context + completion reports + instruction).
- **Engine does:**
  - `AutoTriggerReplan()` called in `RunTierLoop()` step 11 when gate fails and `AutoMode: true`.
  - `sawtools program-replan` command exists.
- **Gap:** None significant.

### E35: Wiring Obligation Declaration
- **Status:** IMPLEMENTED
- **Protocol says:** Scout declares wiring obligations in `wiring:` block. Enforced at 3 layers: prepare-wave pre-flight (Layer 3A), validate-integration --wiring (Layer 3B), agent brief injection (Layer 3C).
- **Engine does:**
  - `Wiring []WiringDeclaration` field in `IMPLManifest`.
  - Layer 3A: `protocol.CheckWiringOwnership()` in `prepare-wave` step 0c (line 245).
  - Layer 3B: `validate-integration --wiring` flag in `cmd/saw/validate_integration.go:110`.
  - Layer 3C: `protocol.InjectWiringInstructions()` in `prepare-wave` step 3 (line 345).
  - `sawtools wiring` command exists.
- **Gap:** None significant.

### E36: IMPL Amendment (Living IMPL Docs)
- **Status:** IMPLEMENTED
- **Protocol says:** Three operations: add-wave, redirect-agent, extend-scope. Blocked if IMPL is COMPLETE. Agent must not have committed for redirect-agent.
- **Engine does:**
  - `pkg/protocol/amend.go` implements all three operations.
  - `sawtools amend-impl` command exists with `--add-wave`, `--redirect-agent`, `--extend-scope` flags.
  - `ErrAmendBlocked` sentinel returned when IMPL is COMPLETE.
  - `extend-scope` triggers Scout re-engagement (noted in spec as CLI/orchestrator layer, not amend.go).
- **Gap:** None significant.

### E37: Pre-Wave Brief Review (Critic Gate)
- **Status:** IMPLEMENTED
- **Protocol says:** After E16 validation, before REVIEWED state, launch critic agent for IMPLs with 3+ agents or multi-repo. Critic verifies briefs against actual codebase.
- **Engine does:**
  - `sawtools run-critic` command exists (`cmd/saw/run_critic_cmd.go`).
  - `CriticResult` struct and `critic_report` field in `IMPLManifest`.
  - `pkg/protocol/critic.go` provides critic result parsing/storage.
  - Auto-trigger in `run-scout` step 6 (line 244).
  - `sawtools set-critic-review` for critic agents to write results.
  - `--skip` flag to skip critic gate.
- **Gap:** None significant.

### E38: Gate Result Caching
- **Status:** IMPLEMENTED
- **Protocol says:** Cache gate results keyed on `hash(headCommit + stagedDiffStat + unstagedDiffStat + gateCommand)`. TTL 5 minutes. `--no-cache` opt-out. Post-merge gates never cached.
- **Engine does:**
  - `pkg/gatecache/cache.go` — `gatecache.New(stateDir, 5*time.Minute)` used in `FinalizeWave()` and `prepare-wave`.
  - `DefaultTTL = 5 * time.Minute` constant.
  - `--no-cache` flag on `prepare-wave` (line 85).
  - `RunPostMergeGates()` is separate from cached gate execution.
  - `from_cache: true` and `skip_reason` in `GateResult`.
- **Gap:** The protocol specifies the cache key must include `stagedDiffStat + unstagedDiffStat`. Verify that `gatecache` includes both staged and unstaged diff stats (not just HEAD commit hash) in key computation. If the cache only uses HEAD commit, a file modified but not yet committed would get a stale cache hit.

### E39: Interview Mode
- **Status:** IMPLEMENTED
- **Protocol says:** `/saw interview` starts structured 6-phase Q&A. State persisted to `INTERVIEW-<slug>.yaml`. Resume capability. Outputs `REQUIREMENTS.md`.
- **Engine does:**
  - `pkg/interview/` package with `types.go`, `compiler.go`, `phase_questions.go`, `deterministic.go`.
  - `sawtools interview` command exists (`cmd/saw/interview_cmd.go`).
  - `--resume` flag supported.
  - `compiler.go` compiles spec_data into `REQUIREMENTS.md`.
- **Gap:** None significant.

### E40: Observability Event Emission
- **Status:** PARTIAL
- **Protocol says:** Emit observability events at lifecycle transitions (scout_launch, scout_complete, wave_start, agent_performance, wave_merge, wave_failed, impl_complete, gate_executed, gate_failed, tier_advanced, tier_gate_passed, tier_gate_failed). Non-blocking, batch preferred.
- **Engine does:**
  - `pkg/observability/` package with `ActivityEvent`, `AgentPerformanceEvent`, `CostEvent` structs.
  - Event types and field schemas match the protocol's E40 checklist.
  - `observability.RecordEvent()` interface exists.
  - E40 lifecycle checklist in the protocol marks specific events as "wired" vs "pending".
- **Gap (SIGNIFICANT):** Despite the infrastructure existing, there is NO call to `obs.RecordEvent()` or any observability event emission in any of the following:
  - `pkg/engine/runner.go` (RunScout) — no `scout_launch` or `scout_complete` events emitted
  - `cmd/saw/finalize_wave.go` — no `wave_merge`, `wave_failed`, `gate_executed`, or `gate_failed` events emitted
  - `cmd/saw/prepare_wave.go` — no `wave_start` event emitted
  - `pkg/engine/finalize.go` — no `impl_complete` event emitted
  - `pkg/engine/program_tier_loop.go` — no `tier_advanced`, `tier_gate_passed`, or `tier_gate_failed` events emitted
  The observability package exists as dead code — the infrastructure is built but none of the lifecycle hooks call into it. The protocol's own E40 checklist notes "pending" for token/cost events and tier-level events, but the "wired" events (scout_launch, scout_complete, wave_start, agent_performance, wave_merge, wave_failed, impl_complete, gate_executed, gate_failed) are also not wired.

### E41: Type Collision Detection
- **Status:** IMPLEMENTED
- **Protocol says:** Before worktree creation (in `prepare-wave`), run `sawtools check-type-collisions` to detect duplicate type/function/const names across agents in same package. Failure blocks wave launch.
- **Engine does:**
  - `pkg/collision/` package provides AST-based collision detection.
  - `sawtools check-type-collisions` command exists.
  - Called in `finalize-wave` step 1.5 (`CollisionReports` in `FinalizeWaveResult`).
- **Gap:** The protocol specifies E41 runs in `prepare-wave` (before worktree creation), but the implementation runs it in `finalize-wave` (after agents complete). This is a timing mismatch — running collision detection after the fact means agents may have already invested work in conflicting symbols. Running it in `prepare-wave` would catch planning conflicts early. The current placement is reactive rather than proactive.

---

## CLI Command Audit

| Command | Exists | Behavior Matches Spec | Notes |
|---------|--------|----------------------|-------|
| `create-worktrees` | ✓ | ✓ | E4/E5 compliant |
| `verify-commits` | ✓ | ✓ | I5 enforcement |
| `scan-stubs` | ✓ | ✓ | E20 implementation |
| `merge-agents` | ✓ | ✓ | E12 compliant |
| `verify-build` | ✓ | ✓ | E13 |
| `cleanup` | ✓ | ✓ | Post-merge |
| `update-status` | ✓ | ✓ | State tracking |
| `update-context` | ✓ | ✓ | E18 |
| `list-impls` | ✓ | ✓ | |
| `run-wave` | ✓ | ✓ | |
| `validate` | ✓ | ✓ | E16 |
| `extract-context` | ✓ | ✓ | E23 |
| `set-completion` | ✓ | ✓ | |
| `mark-complete` | ✓ | ✓ | E15 |
| `run-gates` | ✓ | ✓ | E21/E21B |
| `check-conflicts` | ✓ | PARTIAL | E11: exists but not wired into `finalize-wave` CLI path |
| `validate-scaffolds` | ✓ | ✓ | E22 |
| `freeze-check` | ✓ | ✓ | E2 |
| `update-agent-prompt` | ✓ | PARTIAL | E6: command exists; automated deviation propagation missing |
| `validate-integration` | ✓ | ✓ | E25/E35 Layer 3B |
| `resume-detect` | ✓ | ✓ | E23A |
| `build-retry-context` | ✓ | ✓ | E19/E7a |
| `tier-gate` | ✓ | ✓ | E29 |
| `freeze-contracts` | ✓ | ✓ | E30 |
| `program-status` | ✓ | ✓ | E32 |
| `run-scout` | ✓ | ✓ | E16 correction loop |
| `mark-program-complete` | ✓ | ✓ | |
| `update-program-state` | ✓ | ✓ | |
| `update-program-impl` | ✓ | ✓ | |
| `amend-impl` | ✓ | ✓ | E36 |
| `list-programs` | ✓ | ✓ | |
| `prepare-wave` | ✓ | PARTIAL | E3: missing explicit I1 disjoint ownership scan before launch |
| `prepare-agent` | ✓ | ✓ | E23 |
| `import-impls` | ✓ | ✓ | E28A |
| `validate-program` | ✓ | ✓ | |
| `finalize-impl` | ✓ | ✓ | E16 + M4 |
| `finalize-wave` | ✓ | PARTIAL | E7: no partial/blocked check before merge; E11: predictConflicts not called |

**Missing commands from `/saw` skill spec check:**
- `run-critic` — exists (`sawtools run-critic`) ✓
- `check-type-collisions` — exists ✓
- `wiring` — exists (`sawtools wiring`) ✓
- `program-execute` — exists ✓
- `create-program` — exists ✓

All `/saw` skill-referenced commands are present in `sawtools`. No commands are missing.

---

## Schema Divergences

### 1. `IMPLManifest.SuitabilityAssessment` vs Protocol
- **Protocol:** `suitability_assessment:` is a structured YAML block with `verdict:` and `reasoning:` subfields.
- **Go struct:** `SuitabilityAssessment string yaml:"suitability_assessment,omitempty"` — stored as a raw string, not a structured object with `verdict`/`reasoning` fields. The `Verdict` field is separately promoted to the top level: `Verdict string yaml:"verdict"`.
- **Impact:** Minor. The protocol spec in `message-formats.md` shows `suitability_assessment:` as a block with sub-fields, but the engine stores it as a prose string while promoting `verdict` separately. Scouts that write `verdict: SUITABLE` to the root manifest satisfy the Go schema, but the structured suitability_assessment block is lost.

### 2. `ProjectMemory.Architecture` struct vs Protocol
- **Protocol:** `architecture:` should have `description: string` and `modules: [{name, path, responsibility}]` (message-formats.md §docs/CONTEXT.md).
- **Go struct:** `ArchitectureDescription` has `Language`, `Stack`, and `Summary` fields — no `modules` array, `description` is renamed `Summary`.
- **Impact:** Moderate. Agents reading `docs/CONTEXT.md` through the structured API will see different field names than what the protocol promises. `modules` data is never captured.

### 3. `KnownIssue.Title` optionality
- **Protocol:** `impl-known-issues` typed block shows `title: {short title}` as a required field.
- **Go struct:** `KnownIssue.Title string yaml:"title,omitempty"` — tagged `omitempty`, making it optional.
- **Impact:** Minor. Validation will not flag missing titles.

### 4. `IMPLManifest` missing `plan_reference` in schema validation
- **Protocol:** `plan_reference: "path/to/original/plan.md"` is documented as optional root-level field.
- **Go struct:** `PlanReference string yaml:"plan_reference,omitempty"` is present. No divergence — this one is correct.

### 5. `ProgramIMPL` extra fields not in spec
- **Protocol:** `program-manifest.md` section 5.1 lists `slug, title, tier, depends_on, estimated_agents, estimated_waves, key_outputs, status` as the complete schema.
- **Go struct:** `PROGRAMManifest.ProgramIMPL` also has `PriorityScore int` and `PriorityReasoning string` — fields not in the protocol schema.
- **Impact:** Engine-leads-protocol. These are useful scheduling fields added by the engine without protocol backing.

### 6. `ProgramTier.ConcurrencyCap` not in spec
- **Protocol:** `program-manifest.md` section 6.1 lists `number, impls, description` as the complete ProgramTier schema.
- **Go struct:** `ProgramTier` also has `ConcurrencyCap int yaml:"concurrency_cap,omitempty"` — not in protocol schema.
- **Impact:** Engine-leads-protocol. See below.

### 7. `QualityGate.Timing` field not in spec
- **Protocol:** The quality gate schema in `message-formats.md` lists `type, command, required, description, repo, fix` — no `timing` field.
- **Go struct:** `QualityGate.Timing string yaml:"timing,omitempty"` — supports `"pre-merge"` | `"post-merge"`.
- **Impact:** Engine-leads-protocol. The engine's timing separation is a useful feature but not documented in the protocol.

---

## Engine-Leads-Protocol (Notable)

These behaviors are implemented in the engine but not documented in the protocol. Each should be evaluated for promotion to the protocol or explicit documentation.

### 1. Stale Worktree Detection and Cleanup
- **What:** `prepare-wave` step 0a2 calls `protocol.DetectStaleWorktrees()` and `CleanStaleWorktrees()` to clean up worktrees from previous failed runs of the same slug. `sawtools cleanup-stale` command exists.
- **File:** `cmd/saw/prepare_wave.go:150`, `pkg/protocol/stale_worktree.go`
- **Decision:** This is mature and useful defensive behavior. Should be documented as part of E4's Layer 0 or as a new E4a (Stale Worktree Cleanup).

### 2. Go Module Replace Path Fix
- **What:** After merge, `FinalizeWave()` step 4.5 calls `protocol.FixGoModReplacePaths()` to auto-correct `go.mod` replace directives that became incorrect when a worktree is removed.
- **File:** `pkg/engine/finalize.go:137`, `pkg/protocol/gomod_fixup.go`
- **Decision:** Go-specific implementation detail. Worth documenting as implementation guidance for Go projects.

### 3. Build Failure Diagnosis (H7 pattern matching)
- **What:** After failed VerifyBuild, the engine auto-diagnoses the error using language-specific pattern matching (`pkg/builddiag/`). Diagnosis appended to `FinalizeWaveResult`.
- **File:** `pkg/engine/finalize.go:164`, `pkg/builddiag/`
- **Decision:** Valuable but Go-ecosystem specific. Could be a general protocol rule for "orchestrator should provide structured error context on build failure."

### 4. ProgramIMPL Priority Fields
- **What:** `PriorityScore int` and `PriorityReasoning string` in `ProgramIMPL` enable priority-based IMPL scheduling within a tier.
- **File:** `pkg/protocol/program_types.go:61`
- **Decision:** Should be documented in `program-manifest.md` section 5.1 as optional scheduling fields.

### 5. ProgramTier ConcurrencyCap
- **What:** `ConcurrencyCap int` in `ProgramTier` limits how many IMPLs in a tier can execute simultaneously (rate limiting).
- **File:** `pkg/protocol/program_types.go:70`
- **Decision:** Should be documented in `program-manifest.md` section 6.1.

### 6. QualityGate Timing (pre-merge/post-merge)
- **What:** The `timing: "post-merge"` gate runs after MergeAgents completes, enabling content/integration gates that require the merged state.
- **File:** `pkg/protocol/types.go:148`, `cmd/saw/finalize_wave.go`
- **Decision:** Should be documented in `message-formats.md` Quality Gates Section Format.

### 7. Repo Match Validation in prepare-wave
- **What:** `protocol.ValidateRepoMatch()` verifies the manifest's `repository:` path matches the actual project root. Fails hard before baseline gates.
- **File:** `cmd/saw/prepare_wave.go:168`
- **Decision:** Should be formalized as a precondition check (analogous to E3) in the protocol.

### 8. Daemon Mode
- **What:** `sawtools daemon` provides a persistent polling loop that processes a job queue, running Scout and FinalizeWave automatically.
- **File:** `pkg/engine/daemon.go`
- **Decision:** An operational pattern not described in the protocol. Worth documenting as an implementation pattern for unattended execution.

### 9. Autonomy Config
- **What:** `pkg/autonomy/` package configures autonomy levels (how much the orchestrator decides vs prompts human). Used by daemon.
- **File:** `pkg/autonomy/`
- **Decision:** Relates to E7a's `--auto` mode concept. Could formalize "autonomy levels" in the protocol.

### 10. Interview Mode Deterministic Engine
- **What:** `pkg/interview/deterministic.go` provides a structured, programmatic interview engine (not just CLI I/O). More than the protocol specifies.
- **File:** `pkg/interview/deterministic.go`
- **Decision:** Implementation detail. E39 is well-specified; this is a legitimate implementation choice.

### 11. Scout Automation Context (H1a/H2/H3)
- **What:** `runScoutAutomation()` in `pkg/engine/runner.go:68` runs helper tools (H1a: dependency analysis, H2: output verification, H3: command extraction) before launching Scout and injects their output as context.
- **File:** `pkg/engine/runner.go`
- **Decision:** These are labeled as H-numbered helpers that reference a `helpers.md` or similar (not visible in the protocol repo). Should be documented as Scout pre-processing tools.

### 12. `set-critic-review` Command
- **What:** `sawtools set-critic-review` allows critic agents to write their results directly to the IMPL manifest — a separate command from `run-critic`.
- **File:** `cmd/saw/run_critic_cmd.go` (newSetCriticReviewCmd)
- **Decision:** Correct pattern for E37. Critic agent writes results via tool calls to `set-critic-review`, not by patching the file directly. Should be documented explicitly in E37.

---

## Recommendations

### Must Fix (protocol-engine gap with correctness impact)

1. **E3 gap in prepare-wave:** Add explicit `validateI1DisjointOwnership()` call (or `Validate()`) to `prepare-wave` before worktree creation. Currently, ownership overlaps discovered by `sawtools validate` can slip through if the user skips that step.
   - Fix: Call `protocol.Validate(doc)` in `prepare-wave` before step 1 (Create worktrees). Return error on `I1_VIOLATION`.

2. **E7/E19 gap in finalize-wave CLI:** Add a pre-merge check in `finalize-wave` that reads completion reports for the wave and blocks merge if any agent reports `status: partial` or `status: blocked`.
   - Fix: After step 1 (VerifyCommits), scan `manifest.CompletionReports` for the wave; if any has status != "complete", return early with structured error listing the blocking agents.

3. **E11 gap in finalize-wave CLI:** Call `predictConflicts()` (already implemented in `pkg/orchestrator/merge.go`) in the `finalize-wave` CLI path before calling `MergeAgents`. Currently E11 enforcement only exists in the web-app orchestrator path.
   - Fix: Extract `predictConflicts()` to `pkg/protocol` (or call it via orchestrator) and wire it into `finalize-wave` step 1.5.

4. **E40 observability not wired:** The observability infrastructure (`pkg/observability/`) exists but no lifecycle event emission calls are present in any engine path. Wire `RecordEvent()` calls to:
   - `RunScout()`: emit `scout_launch` on entry, `scout_complete` on success
   - `prepare-wave`: emit `wave_start`
   - `finalize-wave`: emit `wave_merge` (success), `wave_failed` (failure), `gate_executed`/`gate_failed` per gate
   - `engine.MarkIMPLComplete()`: emit `impl_complete`
   - `RunTierLoop()`: emit `tier_advanced`, `tier_gate_passed`, `tier_gate_failed`
   All emissions must be non-blocking (goroutine fire-and-forget). A `nil` store should silently no-op.

5. **E41 timing mismatch:** `check-type-collisions` runs in `finalize-wave` (step 1.5) but the protocol requires it to run in `prepare-wave` (before worktree creation). Move or add the collision check to `prepare-wave`.
   - Fix: Add `protocol.CheckTypeCollisions(doc, waveNum)` call to `prepare-wave` after step 0c (wiring ownership check) and before step 1 (Create worktrees).

### Should Document (engine-leads mature enough to encode)

1. **QualityGate timing field:** Add `timing: "pre-merge" | "post-merge"` to the Quality Gates schema in `message-formats.md`. This is a stable, used feature with clear semantics.

2. **ProgramIMPL priority fields:** Document `priority_score` and `priority_reasoning` as optional scheduling fields in `program-manifest.md` section 5.1.

3. **ProgramTier concurrency cap:** Document `concurrency_cap` in `program-manifest.md` section 6.1.

4. **Stale worktree cleanup:** Add as E4a or extend E4 with a note that orchestrators should detect and clean stale worktrees from previous failed runs before creating new ones.

5. **E37: `set-critic-review` command:** Explicitly mention in E37 that critic agents write results via `sawtools set-critic-review` (or equivalent SDK call), not by direct file modification.

6. **Scout pre-processing helpers (H-series):** If H1a, H2, H3 have formal specs, they should cross-reference E31 and the Scout prompt. If not, add a brief mention in E31 or E16 about pre-Scout automation tools.

7. **`ProjectMemory.Architecture` schema:** Align `message-formats.md` CONTEXT.md schema with the Go struct, or update the Go struct to match the spec. The `modules[]` array is in the spec but absent from the implementation.

### Consider (gaps that may be intentional)

1. **E6 automated deviation propagation:** The protocol describes propagating interface deviations by updating downstream agent prompts. The engine provides `sawtools update-agent-prompt` but no automated propagation. This may be intentionally a human-in-the-loop step. If so, document it explicitly in E6 ("requires human judgment to determine correct updates").

2. **E8 needs_replan loop:** `RouteFailure(needs_replan)` returns `ActionReplan` but no engine code executes the replan. In practice, this surfaces to the user. Consider whether auto-Scout-relaunch should be implemented or whether it's correctly a "pause" operation per E19.1.

3. **E26 precondition validation:** The E26-P1/P2 preconditions in `preconditions.md` are documented but not mechanically enforced before Integration Agent launch. May be acceptable if the operator is expected to configure `integration_connectors` before launch.

4. **E22 full-project build verification:** The engine verifies individual scaffold files compile but not the full project build (`go build ./...`). This is more work but prevents one class of wave-wasting failures. Evaluate whether full-project verification is worth the overhead for large codebases.

5. **E38 cache key completeness:** Verify that `gatecache` includes staged and unstaged diff stats (not just HEAD commit) in cache keys. If only HEAD commit is used, uncommitted file changes would produce incorrect cache hits.

---

*Audit produced by protocol conformity analysis. All file references are relative to `/Users/dayna.blackwell/code/scout-and-wave-go`.*
