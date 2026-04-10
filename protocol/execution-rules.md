# Scout-and-Wave Protocol Execution Rules

**Version:** 0.20.0

> **See also:** `procedures.md` (v0.21.0) — operational procedures for Orchestrator, Scout, Scaffold Agent, and Wave Agent participants.

This document defines the execution rules that govern orchestrator behavior during Scout-and-Wave protocol execution. These rules are not captured by the state machine alone.

---

## Overview

Rules are numbered E1–E48 for cross-referencing and audit; the same convention as invariants (I1–I6). When referenced in implementation files, the E-number serves as an anchor; implementations should embed the canonical definition verbatim alongside the reference.

To audit consistency, search implementation files for `E{N}` and verify the embedded definitions match this document.

---

## E1: Background Execution

**Trigger:** Launching any agent, polling CI, or running long-running watch commands

**Required Action:** All such operations must execute asynchronously without blocking the orchestrator's main execution thread.

**Why This Is Not a Performance Preference:** A blocking agent launch serializes the wave; the orchestrator waits for one agent before launching the next, eliminating parallelism. This is a protocol violation. Any implementation that blocks the orchestrator on agent execution or polling is non-conforming.

**Agent launch prioritization:** `sawtools run-wave` uses `engine.PrioritizeAgents` to determine launch order. Agents with a longer critical path depth (more downstream dependents) launch first to unblock downstream work sooner. Tie-breaker: when two agents share equal critical path depth, the agent with fewer owned files launches first (lower implementation risk). To disable this ordering and use declaration order instead, pass `--no-prioritize` to `sawtools run-wave` (sets `SAW_NO_PRIORITIZE=1` internally).

**Failure Handling:** If the runtime does not support asynchronous execution, the implementation is non-conforming.

---

## E2: Interface Freeze

**Trigger:** Worktrees are created

**Required Action:** Interface contracts become immutable. The review window between REVIEWED and WAVE_PENDING is the checkpoint for revising type signatures, adding fields, or restructuring APIs.

**Rationale:** After worktrees branch from HEAD, any interface change requires removing and recreating all worktrees for the wave.

### Recovery Paths When Interface Change Required After Worktrees Exist

When an interface change is required after worktrees exist and some agents have already committed work, two recovery paths are available:

**(a) Recreate and cherry-pick:**
- Record the commit SHAs of agents whose completed work does not implement or call the changed interface
- Remove and recreate all worktrees
- Cherry-pick the unaffected commits onto their new worktrees
- Verify each cherry-picked commit still builds against the new interface
- Re-run only the agents whose work is affected by the change
- Use this path when most agents have completed and the change is narrow (affects 1–2 agents)

**(b) Descope and defer:**
- Leave the current wave to complete against the existing contracts
- Move the interface revision to the next wave boundary, where it becomes the contract for a new wave
- Agents that cannot complete against the current contract report `status: blocked` (E8)
- The orchestrator resolves the contract change at the wave boundary
- Use this path when the change is broad, when few agents have completed, or when cherry-pick safety cannot be confirmed

**Simplified Case:** If no agents have committed work yet, recreate worktrees without cherry-pick.

**Scope:** E2 governs orchestrator-initiated interface changes. E8 governs the same problem from the other direction: agent-discovered contract failures.

**Related Invariants:** See I2 (interface contracts precede parallel implementation)

---

## E3: Pre-Launch Ownership Verification

**Trigger:** Before creating worktrees or launching any agent in a wave

**Required Action:** The orchestrator scans the wave's file ownership table in the IMPL doc and verifies no file appears in more than one agent's ownership list.

**Cross-repo waves:** The file ownership table must include a `Repo` column. Disjointness is checked per-repo — the same filename in different repositories is not a conflict. Files in different repos are inherently disjoint (no shared filesystem). E3 verification runs per-repo: within each repo, no two agents may own the same file.

**Failure Handling:** If an overlap is found within the same repo, the wave does not launch; the IMPL doc must be corrected first.

**Distinction:** This is distinct from post-execution conflict prediction (E11). Pre-launch catches scout planning errors; post-execution catches runtime deviations where an agent touched files outside its declared scope.

**Related Invariants:** See I1 (disjoint file ownership)

---

## E4: Worktree Isolation

**Trigger:** All Wave agents

**Required Action:** All Wave agents MUST use worktree isolation. There are no exceptions for work type (documentation-only, simple refactors, file moves, etc.).

**Failure Handling:** If work is too small to justify worktrees, it is too small for SAW; use sequential implementation instead.

### Rationale for Mandatory Isolation

- Worktrees enforce I1 (disjoint file ownership) mechanically, preventing concurrent writes to the same files on the main branch
- Enable independent verification of each agent's work before merge
- Provide rollback capability via worktree removal without affecting main
- Prevent execution-time interference from concurrent operations (builds, tests, file system operations)

### Five Layers Protecting Against Isolation Failures

**Layer 0 — Pre-commit hook:**
- A git pre-commit hook installed during worktree setup blocks commits to main during active waves
- Agents that attempt to commit to main receive an instructive error with their assigned worktree path
- The orchestrator bypasses the hook for legitimate main commits
- This is infrastructure enforcement: it prevents the violation rather than detecting it
- The hook is shipped as a file and installed ephemerally: copied during worktree creation, removed during cleanup

**Layer 1 — Manual pre-creation:**
- The orchestrator creates all worktrees before launching any agent
- This is the primary mechanism
- It is deterministic and does not depend on agent cooperation

**Layer 2 — Task tool isolation (Claude Code–specific):**
- The `isolation: "worktree"` parameter is a Claude Code Agent tool invocation parameter — it is not a general protocol concept or SDK field. Other orchestration backends (API, programmatic engine) do not have an equivalent; they rely on Layer 1 alone.
- Runtime isolation parameters provide isolation when the orchestrator and target repository are the same
- This is the secondary mechanism
- **Cross-repository waves: omit Layer 2 intentionally.** When agents work in a different repo from the Orchestrator, `isolation: "worktree"` creates worktrees in the Orchestrator's repo (wrong repo). Omit the parameter entirely for cross-repo agents. Layer 1 (manual worktree creation in each target repo) and Layer 3 (Field 0 absolute path navigation) provide the isolation instead. Omitting Layer 2 in a cross-repo wave is correct protocol, not a degraded fallback.
- Layer 2 may also fail silently in same-repo scenarios — do not rely on it alone.

**Layer 3 — Field 0 self-verification:**
- Each agent verifies its working directory at startup (change directory, verify path, verify branch)
- The change directory command is strict (no silent failure suppression) — if navigation to the worktree fails, the agent exits immediately with status 1
- This works correctly in both same-repo and cross-repo scenarios: when Layer 2 positioned the agent correctly (same-repo), the change directory is a no-op that succeeds; when Layer 2 is omitted (cross-repo), change directory performs actual navigation
- All subsequent agent operations inherit this working directory
- If verification fails after successful directory change, the agent exits without modifying files
- This is agent-cooperative defense-in-depth

**Layer 4 — Merge-time trip wire:**
- Before any merge, the orchestrator verifies each agent branch has commits beyond the base
- Empty branch = hard stop
- This catches all isolation failures regardless of cause

**Summary:** Layer 0 prevents the most common failure mode (agent commits to main). Layers 1 and 2 may both fire; this is harmless. If all prevention layers fail, Layer 4 catches it before any incorrect merge.

### Relationship to Disjoint File Ownership

Disjoint file ownership and worktree isolation are complementary layers that protect against different failure modes. Neither substitutes for the other.

- **Disjoint file ownership (I1)** prevents merge conflicts: no two agents produce edits to the same file, so the merge step is always conflict-free.
- **Worktree isolation** prevents execution-time interference: each agent's build, test, and tool-cache writes operate on an independent working tree, so concurrent builds do not race on shared build caches, test caches, lock files, or intermediate object files. Without worktrees, two agents running builds simultaneously on the same directory produce flaky failures that look like code bugs but are actually filesystem races.

**Result:** Disjoint ownership without worktrees: merge is safe, but concurrent execution is flaky. Worktrees without disjoint ownership: execution is clean, but merge produces unresolvable conflicts. Both constraints must hold simultaneously for parallel waves to be correct and reproducible.

**Related Invariants:** See I1 (disjoint file ownership)

---

### E4a: Stale Worktree Cleanup

Before creating worktrees for a wave, the orchestrator SHOULD detect and remove stale worktrees from previous failed runs of the same IMPL slug. A worktree is stale if it references a branch that has been deleted or if its parent IMPL is in a terminal state (COMPLETE or NOT_SUITABLE).

This prevents prepare-wave failures caused by leftover git worktrees from crashed or interrupted previous runs.

---

## E5: Worktree Naming Convention

**Trigger:** Creating worktrees

**Required Action:** Worktrees must be named `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}` where `{slug}` is the IMPL doc's `feature_slug` field, `{N}` is the 1-based wave number, and `{ID}` is the agent identifier. Branch names follow the same pattern: `saw/{slug}/wave{N}-agent-{ID}`. Agent identifiers follow the `[A-Z][2-9]?` pattern: a single uppercase letter (generation 1, e.g., `A`, `B`, `C`) or a letter followed by a digit 2–9 (multi-generation, e.g., `A2`, `B3`). Examples: `saw/my-feature/wave1-agent-A`, `saw/my-feature/wave1-agent-A2`, `saw/my-feature/wave2-agent-B3`.

**Backward compatibility:** Branches created in the legacy format `wave{N}-agent-{ID}` (without slug prefix) are still accepted. The slug-prefix convention was introduced in the scout-and-wave-go engine after protocol v0.20.0. Tools accept both formats.

**Why This Is Not a Style Choice:** This is a canonical requirement. The naming scheme is the mechanism by which external tooling identifies SAW sessions and correlates agents to waves. Deviating from it breaks observability silently. Any tooling that consumes SAW session data must treat this naming scheme as the stable interface.

**Failure Handling:** Non-conforming worktree names prevent monitoring tools from detecting SAW sessions.

---

## E6: Agent Prompt Propagation

**Trigger:** Interface deviation propagation, contract revision, or same-wave interface failure

**Required Action:** When the orchestrator updates an agent prompt, it edits the prompt section in the IMPL doc directly. The agent reads its prompt from the IMPL doc at launch time, so the corrected version is always what runs.

**Rationale:** There is no separate prompt file to keep in sync. The IMPL doc is the single source of truth.

**Note:** Automated deviation propagation (reading interface_deviations from completion reports and auto-updating downstream agent prompts) is intentionally not automated. Interface deviation resolution requires human judgment to determine the correct prompt updates. The orchestrator surfaces deviations; the human applies them via `sawtools update-agent-prompt`.

**Related Invariants:** See I4 (IMPL doc is single source of truth)

---

## E7: Agent Failure Handling

**Trigger:** Any agent in a wave reports `status: partial` or `status: blocked`

**Required Action:** The wave does not merge. The wave goes to BLOCKED. The orchestrator must resolve the failing agent (re-run it, manually fix the issue, or descope it from the wave) before the merge step proceeds.

**Constraint:** Agents that completed successfully are not re-run, but their worktrees are not merged until the full wave is resolved. Partial merges are not permitted.

**Failure Handling:** See E7a for automatic remediation in `--auto` mode

---

## E7a: Automatic Failure Remediation in --auto Mode

**Trigger:** `--auto` mode is active AND an agent fails with a correctable issue

**Required Action:** The orchestrator should automatically re-launch the agent with corrections rather than surfacing the failure to the user.

### Correctable Failures

Failures where the fix is deterministic and requires no human decision:

- **Isolation failures:** Re-launch with explicit repository context (absolute IMPL doc path) so the agent can derive the correct repository root
- **Missing dependencies:** Install the dependency and re-launch
- **Transient build errors:** Re-run after a brief delay (network hiccups, race conditions in parallel builds)

### Non-Correctable Failures

Always surface to the user regardless of `--auto` mode:
- Logic errors
- Test failures
- Interface contract violations

**Distinction:** correctable = environmental/setup issue, non-correctable = code or design issue requiring human judgment.

**Retry Limit:** In `--auto` mode, the orchestrator may retry a correctable failure up to 2 times before escalating to the user. Each retry should include an explanatory note in logs but should not block wave execution. If an agent succeeds after retry, the wave proceeds normally; no user intervention is required.

---

## E8: Same-Wave Interface Failure

**Trigger:** Any agent reports `status: blocked` due to an interface contract being unimplementable as specified

**Required Action:**
- The wave does not merge
- The orchestrator marks the wave BLOCKED
- Revises the affected contracts in the IMPL doc
- Re-issues prompts to all agents whose work depends on the changed contract
- Agents that completed cleanly against unaffected contracts do not re-run
- The wave restarts from WAVE_PENDING with the corrected contracts

**Note:** The `needs_replan` failure type surfaces to the human orchestrator as a pause point. Automatic Scout re-engagement for contract revision is not implemented to prevent cascading contract changes without human review. Use `sawtools update-agent-prompt` and manual wave restart.

**Relationship to E2:** E2 governs orchestrator-initiated interface changes. E8 governs the same problem from the other direction: agent-discovered contract failures.

**Related Invariants:** See I2 (interface contracts precede parallel implementation)

---

## E9: Idempotency

**WAVE_PENDING Re-Entry:** WAVE_PENDING is re-entrant; re-running the wave command checks for existing worktrees before creating new ones and does not duplicate them.

**WAVE_MERGING Non-Idempotency:** WAVE_MERGING is not idempotent. If the orchestrator crashes mid-merge, inspect the state before continuing: check which worktree branches are already present in main's history (search merge commits) and skip those. Do not re-merge a worktree that has already been merged.

**finalize-wave already-merged detection:** When all agent branches are absent (deleted after a previous successful merge), `finalize-wave` treats the wave as already merged and skips VerifyCommits and MergeAgents. However, absent branches alone do not prove the work landed in main — branches can be deleted without merging. `finalize-wave` therefore verifies each agent's commit SHA (from their completion report) is reachable from HEAD using `git merge-base --is-ancestor`. If any SHA is unreachable, `finalize-wave` returns a data-loss error with a recovery command: `git branch recover-<id> <sha>`.

**Failure Handling:** Before continuing a crashed merge, the orchestrator must verify merge state to prevent duplicate merges.

---

## E10: Scoped vs Unscoped Verification

**During Waves (Agent Verification):** Agents run focused verification scoped to the files and packages they own to keep iteration fast.

**Post-Merge (Orchestrator Verification):** The orchestrator's post-merge gate runs unscoped across the full project to catch cross-package cascade failures that no individual agent could see.

### Scout Responsibility

The scout must specify exact verification commands in Field 6 of each agent prompt. Agents run those exact commands; they may not substitute broader ones.

"Scoped" is not self-evident from agent context: a command that tests all packages is unscoped regardless of how fast it runs; the correct scoped command targets only owned packages. The scout knows the project structure and can determine the right target; agents must not guess.

**Non-Conformance:** An agent that substitutes a broader command than specified is non-conforming, even if the command passes.

---

## E11: Conflict Prediction Before Merge

**Trigger:** Before merging any wave

**Required Action:** The orchestrator cross-references all agents' `files_changed` and `files_created` lists before touching the working tree. A file appearing in more than one agent's list is a disjoint ownership violation. It must be resolved before any merge proceeds.

**Merge Order:** Within a valid wave, merge order is arbitrary. Same-wave agents are independent by construction: any agent whose work depends on a file created by another agent belongs in a later wave. If merge order appears to matter, the wave structure is wrong, not the merge sequence.

**Related Invariants:** See I1 (disjoint file ownership). For false positive handling, see E11a. For Scout-time conflict classification, see E11b.

---

## E11b: Scout-Time Conflict Pattern Classification

**Trigger:** Scout is assigning file ownership and a file appears in more than one agent's work scope.

**Required Action:** Scout classifies the overlap using one of the four patterns below before
deciding whether to enforce strict disjoint ownership (I1) or permit controlled shared
ownership (I1 relaxation). The decision determines whether agents can be in the same wave
or must be sequenced.

### When to enforce strict I1 (disjoint ownership, mandatory):
- Agents modify existing function signatures or struct fields
- Agents edit the same lines (both updating the same config value)
- Agents rename or remove exported symbols
- Mixed patterns (one agent appends, another edits existing code in same file)

### When I1 relaxation is permitted (append-only shared ownership):
Only when BOTH conditions hold:
1. The diff is purely additive — no deletions, no modifications to existing lines
2. Each agent's additions are self-contained and independent of the other agent's additions

### Pattern 1: Test file append-only (safe — same wave permitted)

**Scenario:** Multiple agents add new test functions to the same test file.

**Safe when:** Each agent adds distinct, named test functions without modifying existing
tests, shared setup, or teardown. No agent renames or removes existing tests.

**Merge behavior:** Apply agent commits sequentially in any order. Git resolves without
conflict because additions are to independent, named blocks.

**Example:** Agent A adds `TestAutoMergeAppend`, Agent B adds `TestDiffPatternAnalysis`
to the same `finalize_test.go`. Neither touches the other's test or the shared `TestMain`.

**Constraint to include in agent prompt:** "Add new test functions only — do not modify,
rename, or remove existing tests."

### Pattern 2: Registry append-only (safe — same wave permitted)

**Scenario:** Multiple agents register independent entries in a central registry, route
table, or command list.

**Safe when:** Entries are independent key-value pairs or function calls; insertion order
does not affect behavior; no agent modifies the initialization logic or existing entries.

**Merge behavior:** Apply agent commits in any order. Entries accumulate without conflict.

**Example:** Agent A adds `router.Handle("/api/v1/contracts", ...)`, Agent B adds
`router.Handle("/api/v1/patterns", ...)` to the same `routes.go`. Neither touches existing
routes or shared initialization.

**Constraint to include in agent prompt:** "Append new entries only — do not reorder
existing entries or modify shared initialization."

### Pattern 3: Line edits (unsafe — must sequence into separate waves)

**Scenario:** Agents modify existing lines, function signatures, or struct fields in
the same file.

**Never safe:** Two agents editing overlapping line ranges will produce a semantic conflict
that cannot be auto-resolved. The codebase may build but be logically incorrect.

**Resolution:** Place one agent in Wave N and the other in Wave N+1. Wave N+1 agent
receives the merged result of Wave N as its baseline.

**Example:** Agent A changes `func Parse(data []byte) (Result, error)` to return
`Result[Data]`; Agent B changes the same signature to add a parameter. Neither can
complete correctly while the other's change is pending.

### Pattern 4: Mixed (unsafe — must sequence into separate waves)

**Scenario:** One agent appends new content while another edits existing lines in the
same file.

**Never safe:** The append may depend semantically on the edit (e.g., a new test calls
a refactored function). Even if Git merges cleanly, the append may be logically stale.

**Resolution:** Place the editing agent in Wave N, the appending agent in Wave N+1.
The appending agent writes against the already-edited baseline.

**Example:** Agent A refactors `validateInput()`. Agent B adds `TestValidateInputEdgeCases()`
that calls it. Agent B must run after Agent A's refactor is merged.

---

## E11a: Manual Merge Escape Hatch

**Trigger:** E11 blocks merge with false positive (identical edits across agents)

**Required Action:** The orchestrator may bypass E11 block via manual merge + finalize-wave resumption.

### When to Use Manual Merge

Use this escape hatch when:
- E11 blocks merge due to file overlap
- Visual inspection confirms edits are identical (no semantic conflict)
- Git octopus merge would auto-resolve without conflict

Do NOT use when:
- Edits differ semantically (content hashes differ)
- Multiple agents modified same function with different logic
- Test coverage is insufficient to catch semantic conflicts

### Manual Merge Procedure

1. Verify E11 block is false positive:
   ```bash
   # Compare file content between agent branches
   git show saw/{slug}/wave{N}-agent-A:path/to/file.go > /tmp/agent-A.txt
   git show saw/{slug}/wave{N}-agent-B:path/to/file.go > /tmp/agent-B.txt
   diff /tmp/agent-A.txt /tmp/agent-B.txt
   # If diff is empty: identical edits, safe to merge
   ```

2. Perform manual octopus merge:
   ```bash
   git checkout main
   git merge --no-ff saw/{slug}/wave{N}-agent-A saw/{slug}/wave{N}-agent-B ... \
       -m "Merge wave {N}: {description}"
   # Git auto-resolves identical edits
   ```

3. Resume finalize-wave from verify-build:
   ```bash
   sawtools finalize-wave docs/IMPL/IMPL-{slug}.yaml --wave {N} --skip-merge
   ```

4. Integration validation runs automatically in step 5.5 (RunPostMergeGates)

### Normal Pipeline (finalize-wave step reference)

Full step sequence for a standard `finalize-wave` run:
- Step 1: VerifyCommits — each agent branch has ≥1 commit ahead of merge base (I5)
- Step 1.1: Completion report check — every agent has a report in `manifest.completion_reports` (I4). Missing reports are a blocking error: `"finalize-wave: missing completion reports for agents: [...] — agents must call sawtools set-completion before merge"`
- Step 1.5: CheckTypeCollisions — AST-based duplicate type/function/const detection across agent branches (E41)
- Step 2: ScanStubs — scan for hollow implementations (`pass`, `...`, `NotImplementedError`) in changed files (E20)
- Step 3: RunPreMergeGates — required gates block merge; optional gates warn (E21)
- Step 3.5a: ValidateIntegration — scan for unconnected exports pre-merge (E25, CLI path)
- Step 3.5b: Wiring declaration check — verify E35 wiring declarations are satisfied
- Step 4: MergeAgents — no-fast-forward merge per agent branch to main (or `--merge-target`)
- Step 4.5: PopulateIntegrationChecklist — populate `post_merge_checklist` in manifest (M5, non-blocking)
- Step 5: VerifyBuild — run post-merge build/test to catch cross-package failures (E10)
- Step 5.5: RunPostMergeGates — gates scoped to `timing: post-merge`
- Step 6: Cleanup — remove worktrees and branches

### Resumption Pipeline (--skip-merge)

When --skip-merge flag is used, `finalize-wave` jumps directly to the post-merge label, skipping all pre-merge steps:
- Step 1: VerifyCommits - SKIP
- Step 1.1: Completion report check (I4) - SKIP
- Step 1.5: CheckTypeCollisions - SKIP
- Step 2: ScanStubs - SKIP
- Step 3: RunPreMergeGates - SKIP
- Step 3.5a: ValidateIntegration (E25) - SKIP
- Step 3.5b: Wiring declaration check (E35) - SKIP
- Step 4: MergeAgents - SKIP (already merged manually)
- Step 4.5: PopulateIntegrationChecklist (M5) - RUN
- Step 5: VerifyBuild - RUN (catches semantic conflicts)
- Step 5.5: RunPostMergeGates - RUN (includes E25/E26/E35)
- Step 6: Cleanup - RUN

### Safety Guarantees

- VerifyBuild (step 5) catches semantic conflicts missed by hash comparison
- Integration validation (step 5.5) detects unconnected exports
- Full test suite runs post-merge (catches cross-package breakage)

### Alternative: Standalone Integration Validation

If --skip-merge is not used, integration validation can be run separately:
```bash
sawtools validate-integration "<manifest-path>" --wave {N}
```
The `--wiring` flag (default: true) enables wiring declaration checks (E35 Layer 3B). Use `--wiring=false` to skip wiring checks.

**Related Rules:** See E11 (conflict prediction), E7 (agent failure handling)

---

## E12: Merge Conflict Taxonomy

Three distinct conflict types can arise; each has a different resolution path:

### 1. Git Conflict on Agent-Owned Files

**Cause:** an I1 violation. This is impossible if invariants hold.

**Resolution:** If it occurs, the scout produced an incorrect ownership table. Do not merge. Correct the IMPL doc and re-run the wave.

### 2. Git Conflict on Orchestrator-Owned Shared Files

**Cause:** Expected. Multiple agents append to IMPL doc completion report sections or append-only config registries.

**Resolution:** Resolve by accepting all appended sections. Each agent owns a distinct named section; there is no semantic conflict, only a git conflict on adjacent lines.

### 3. Semantic Conflict

**Cause:** Two agents implement incompatible interfaces without a git conflict.

**Detection:** Surfaces in `interface_deviations` and `out_of_scope_deps` in completion reports.

**Resolution:** Resolved by the orchestrator before the next wave launches, via interface contract revision and downstream prompt updates.

---

## E13: Verification Minimum

**Minimum Acceptable Verification Gate:** Build (compile) passing and lint passing.

**Test Requirement:** Tests are required if the project has a test suite. A wave reporting PASS on compile-only when tests exist is a protocol violation.

**Scoping:**
- Agents scope their verification to owned files and packages
- The orchestrator's post-merge gate runs unscoped to catch cross-package cascade failures

**Related Rules:** See E10 (scoped vs unscoped verification)

---

## E14: IMPL Doc Write Discipline

**Trigger:** Agent writes completion report

**Required Action:** Agents write to the IMPL doc exactly once: by appending their named completion report section at the end of the file under `### Agent {ID} - Completion Report`.

**Prohibition:** Agents must not edit any earlier section of the IMPL doc (interface contracts, file ownership table, suitability verdict, wave structure). Those sections are frozen at worktree creation (E2).

**Interface Deviations:** Any apparent need to update an earlier section is an interface deviation; it must be reported in the completion report and resolved by the Orchestrator, not edited in-place by the agent.

**Why This Matters:** This constraint is what makes IMPL doc git conflicts predictably resolvable: two agents appending distinct named sections always produce adjacent-section conflicts with no semantic overlap (E12).

**Related Invariants:** See I4 (IMPL doc is single source of truth) and I5 (agents commit before reporting)

**Related Rules:** See E12 (merge conflict taxonomy)

---

## E15: IMPL Doc Completion Marker

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE transition)

**Required Action:** The orchestrator runs:
```bash
sawtools mark-complete "<manifest-path>" --date "YYYY-MM-DD"
```
This atomically: (1) writes `<!-- SAW:COMPLETE YYYY-MM-DD -->` on the line immediately after the IMPL doc title, (2) archives the manifest to `docs/IMPL/complete/`, and (3) auto-cleans any stale worktrees for the completed IMPL slug. The command does NOT commit — the orchestrator commits the archived file and any E18 CONTEXT.md updates together in a single commit. The marker must be present before reporting completion to the user.

**Format:** HTML comment tag. Invisible in rendered markdown. Parseable with a single regex: `<!-- SAW:COMPLETE (\d{4}-\d{2}-\d{2}) -->`. Tooling can grep a directory of IMPL docs without parsing each file.

**Constraint:** Only the orchestrator writes this marker. Agents never add or modify it (E14 already prohibits agents from editing earlier sections). If the marker is already present, do not overwrite.

**Backward Compatibility:** IMPL docs without the `<!-- SAW:COMPLETE -->` tag are treated as active. No migration is required.

**Related Rules:** See E14 (IMPL doc write discipline). See state-machine.md for the WAVE_VERIFIED → COMPLETE transition guard.

**Amend constraint:** Once the `<!-- SAW:COMPLETE -->` marker is written, `saw amend`
is invalid. The orchestrator must reject any amend attempt against a completed IMPL.
To extend completed work, start a new IMPL doc (E36).

---

## E16: Scout Output Validation

**Trigger:** Scout writes IMPL doc to disk

**Required Action:** Orchestrator runs the IMPL doc validator before entering REVIEWED state.
If validation fails, the specific errors are fed back to Scout as a correction prompt.
Scout rewrites only the failing sections. This loops until the doc passes or a retry limit
(default: 3) is reached.

**Validator scope:** Only typed-block sections (IC-1: `type=impl-*` blocks). Prose sections
are excluded from validation.

**Correction prompt format:** The orchestrator's correction prompt to Scout must list each error with the section name, the specific failure (e.g., "impl-dep-graph block: Wave 2 missing `depends on:` line for agent [C]"), and the line number or block identifier where the error occurred. This gives Scout precise targets for correction without requiring it to re-read the whole doc.

**Retry limit:** Default 3 attempts. After the 3rd failed validation, enter BLOCKED. Implementations may override this default, but the default is 3.

**On retry limit exhausted:** Enter BLOCKED state. Orchestrator surfaces validation errors
to human. Do not enter REVIEWED.

**On validation pass:** Proceed to REVIEWED normally.

**Multi-repo consistency checks:** The validator includes two cross-repo rules:
- `MR01_INCONSISTENT_REPO` — if any `file_ownership` entry has `repo:` set, ALL entries must have it. Mixed tagged/untagged entries fail validation.
- `MR02_UNSCOPED_GATE` — if `file_ownership` spans 2+ distinct repos, every `quality_gates.gates[]` entry must have `repo:` set. Without it, gates run in all repos including docs-only repos with no build system. This catches the common failure where `go build ./...` runs in a protocol-only repo.

**Relationship to structured outputs:** For API-backend runs using structured output enforcement, the validator always passes on first attempt (the output was already schema-validated). E16's correction loop is effectively a no-op in that path but must still be present in the protocol for CLI-backend and hand-edited docs.

### E16A: Required Block Presence

**Trigger:** Document contains at least one typed block (`block_count > 0`)

**Required blocks:** Every IMPL doc that uses typed blocks must contain all three of the following:
- `impl-file-ownership`
- `impl-dep-graph`
- `impl-wave-structure`

**Error format:** One error per missing block:
```
missing required block: impl-dep-graph
missing required block: impl-file-ownership
missing required block: impl-wave-structure
```
(only the missing ones are emitted)

**Exception:** If the document contains no typed blocks at all (`block_count == 0`), E16A does not fire. The existing "no typed blocks found" warning already handles this case. E16A is forward-looking: it enforces completeness on docs that have adopted the typed-block format, without breaking backward compatibility with pre-typed-block docs.

### E16B: Dep Graph Grammar

**Trigger:** An `impl-dep-graph` typed block exists in the document

**Required Action:** Validate the block against the canonical dep graph grammar:

**Canonical dep graph grammar:**

A valid `impl-dep-graph` block is a sequence of Wave sections, each containing agent entries with explicit root or dependency declarations. Formally:

1. **Wave header:** At least one line matching `^Wave [0-9]+` (e.g., `Wave 1 (parallel):`, `Wave 2:`). The header may include a parenthetical descriptor after the number.

2. **Agent entry:** At least one line matching `\[[A-Z]\]` (bracket-enclosed uppercase letter, with leading whitespace). The canonical form is:
   ```
       [A] path/to/file
   ```
   where leading whitespace (4 spaces or 1 tab) precedes the agent letter.

3. **Root or dependency declaration:** Each agent entry must be followed, before the next agent entry, by a line containing either:
   - `✓ root` — agent has no dependencies on other agents in this plan
   - `depends on:` — followed by agent letters (e.g., `depends on: [A] [B]`)

   An agent entry that has neither is an error:
   ```
   impl-dep-graph block (line N): agent [X] has neither '✓ root' nor 'depends on:' — one is required
   ```

**Example of a valid dep graph block:**
```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — foundation):
    [A] pkg/foo/validator.go
        ✓ root
    [B] pkg/bar/handler.go
        ✓ root

Wave 2 (1 agent — consumer):
    [C] pkg/baz/service.go
        depends on: [A] [B]
```

### E16C: Out-of-Band Dep Graph Detection (Warn Only)

**Trigger:** Document contains a plain fenced block (no `type=impl-` annotation) that appears to contain dep graph content.

**Detection criteria:** A plain fenced block whose content contains both:
- At least one line matching the agent pattern `\[[A-Z]\]`
- At least one line containing the word `Wave` (case-sensitive)

**Action:** Emit a warning (not a failure). The document is not rejected. The warning is surfaced to Scout in the correction prompt alongside any errors:
```
WARNING: possible dep-graph content found outside typed block at line N — use `yaml type=impl-dep-graph`
```
where `N` is the 1-based line number of the opening fence of the suspect block.

**Rationale:** Scouts sometimes write dep graph content in plain fenced blocks (e.g., copied from an old template) rather than the required `impl-dep-graph` typed block. E16C catches this pattern early, before E16A would fail on a "missing required block: impl-dep-graph" error, giving Scout a more actionable diagnostic.

**Warning does not cause E16A to fire:** If E16C fires (a plain block looks like a dep graph), the `impl-dep-graph` typed block is still considered missing for E16A purposes. Both E16A and E16C will appear in the correction prompt.

### E16D: Enhanced Validation Checks

**Trigger:** Scout writes IMPL doc to disk OR human runs `sawtools validate`

**Required Action:** Run enhanced validation checks on the manifest:

**1. Duplicate Key Detection**
- Detects duplicate top-level YAML keys (e.g., two `state:` fields)
- Error code: E16_DUPLICATE_KEY
- Example: "duplicate key 'state' at lines 4, 55"
- Rationale: yaml.v3 silently overwrites duplicates, causing state corruption

**2. Action Enum Validation**
- Validates file_ownership action field: must be "new", "modify", or "delete"
- Empty/omitted action is allowed (backward compatibility)
- Error code: E16_INVALID_ACTION
- Example: "file_ownership[3].action has invalid value 'update' — must be new, modify, or delete"

**3. Integration Checklist Warning**
- Warns when new API handlers or React components lack post_merge_checklist
- Detection: action=new files matching pkg/api/*_handler.go or web/src/components/*.tsx
- Warning code: E16_MISSING_CHECKLIST (warning, not blocker)
- Example: "new handlers detected but post_merge_checklist is empty — integration steps may be needed"

**4. File Existence Warning**
- Warns when action=modify files do not exist in repository
- Only runs when repoPath is provided (CLI/web validation, not struct-only validation)
- Warning code: E16_FILE_NOT_FOUND (warning, not blocker)
- Example: "file 'pkg/foo/bar.go' marked action=modify but does not exist"

**Failure Handling:** Errors (duplicate keys, invalid action) block Scout completion. Warnings (missing checklist, file not found) are surfaced to human but do not block.

### E16 Correction Loop (Automatic Re-Prompting)

When validation fails, the orchestrator automatically re-prompts the Scout with the validation errors (up to 3 retries). The correction loop (implemented by `ScoutCorrectionLoop()` in `pkg/engine/`):

1. Runs Scout
2. Validates the IMPL doc directly via `protocol.Validate()` — no auto-fixing inside the loop
3. If errors: builds a correction prompt listing each error (code, message, field) and prepends it to the Scout's feature description for the next attempt
4. Repeats up to 3 times
5. On exhaustion: sets state to `BLOCKED`

Note: `sawtools validate --fix` (which auto-corrects fixable issues like invalid gate types → `custom`) is a useful standalone CLI tool but is NOT called inside the correction loop. The loop sends errors back to Scout for self-correction rather than applying mechanical fixes.

**Key property:** The correction loop is idempotent — running it multiple times on an already-valid IMPL doc is a no-op (validation passes on first attempt, no Scout re-invocation).

**Full `run-scout` pipeline (all steps):**
1. `ScoutCorrectionLoop` — Scout execution + internal E16 validation-retry (up to 3 attempts)
2. Wait for IMPL doc file to appear on disk
3. Post-loop validation pass (`protocol.ValidateIMPLDoc`) — defense-in-depth after the loop exits
4. Agent ID errors: generate suggested correct IDs (advisory only — operator must apply manually; no auto-fix)
5. Finalize IMPL doc — populate verification gates (`engine.FinalizeIMPLEngine` / M4)
6. Critic gate if threshold met (E37) — optional, skipped with `--no-critic`

**Related Rules:** See E16A (required block presence), E16B (dep graph grammar), E16C (out-of-band detection), E37 (critic gate — step 6), E39 (Interview Mode — alternative requirements gathering pathway)

### Scout Pre-Processing Helpers (H-series)

Before launching the Scout agent, the engine runs automation tools that produce context injected into the Scout prompt:

- **H1a (analyze-suitability):** Scans a requirements file against the current codebase to classify each requirement as DONE, PARTIAL, or TODO. Implemented by `sawtools analyze-suitability`.
- **H2 (extract-commands):** Detects project toolchain and extracts build/test/lint/format commands from CI configs, Makefiles, and package manifests. Implemented by `sawtools extract-commands`.
- **H3 (analyze-deps):** Traces import paths and type dependencies to produce a dependency graph with wave candidate assignments. Implemented by `sawtools analyze-deps`.

These helpers are best-effort: failures are logged but do not block Scout execution. Their output appears in the Scout prompt under '## Automation Analysis Results'.

---

## E17: Scout Reads Project Memory

**Trigger:** Scout begins a new suitability assessment

**Required Action:** Before running the suitability gate, the Scout checks for
`docs/CONTEXT.md` in the target project. If the file exists, Scout reads it in
full and uses its contents to inform the suitability assessment:
- `established_interfaces` — avoids proposing types that already exist
- `decisions` — respects prior architectural decisions; does not contradict them
- `conventions` — follows project naming, error handling, and testing conventions
- `features_completed` — understands project history and prior wave structure

**If absent:** Scout proceeds normally without it. `docs/CONTEXT.md` is optional;
projects that have never completed a SAW feature will not have one.

**Rationale:** Without project memory, each Scout run starts cold. After several
features, the project accumulates naming conventions, module boundaries, and
interface decisions that the Scout would otherwise rediscover (expensively) or
miss entirely.

**Related Rules:** See E18 (Orchestrator creates/updates docs/CONTEXT.md after
each completed feature).

---

## E18: Orchestrator Updates Project Memory

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE
transition — same trigger as E15)

**Required Action:** Run:
```bash
sawtools update-context "<manifest-path>" --project-root "<project-root>"
```
This creates or updates `docs/CONTEXT.md`, appending to `features_completed`, `decisions`, and `established_interfaces` as needed. Returns JSON; does NOT commit. The commit is the Orchestrator's responsibility (see Constraint below).

If manual construction is needed, the fields to update are:

1. Append to `features_completed`:
   ```yaml
   - slug: {feature-slug}
     impl_doc: docs/IMPL/IMPL-{feature-slug}.yaml
     waves: {N}
     agents: {N-agents}
     date: {YYYY-MM-DD}
   ```

2. Append any architectural decisions made during this feature to `decisions`.

3. Append any new scaffold-file interfaces to `established_interfaces`.

**Constraint:** E18 runs after E15 (`sawtools mark-complete`). Commit both together:
```bash
git add docs/IMPL/complete/IMPL-{slug}.yaml docs/CONTEXT.md
git commit -m "chore: close {feature-slug} IMPL and update project memory"
```

**When to omit:** If no new decisions, interfaces, or conventions were established
during the feature, E18 still appends to `features_completed` but may omit the
other fields.

**Related Rules:** See E15 (IMPL doc completion marker), E17 (Scout reads project
memory).

---

## E19: Failure Type Decision Tree

**Trigger:** Any agent reports `status: partial` or `status: blocked` with a
`failure_type` field

**Required Action:** The Orchestrator reads `failure_type` and applies the
corresponding action:

| failure_type   | Orchestrator action |
|----------------|---------------------|
| `transient`    | Retry automatically, up to 2 times. If all retries fail, escalate to human. Log each retry attempt. |
| `fixable`      | Read agent's free-form notes for the specific fix. Apply the fix (install dependency, correct path, update config). Relaunch the agent. One retry only; if it fails again, escalate. |
| `needs_replan` | Do not retry. Re-engage Scout with the agent's completion report as additional context. Scout produces a revised IMPL doc. Human reviews before wave re-executes. |
| `escalate`     | Surface immediately to human with agent's full completion report. No automatic action. |
| `timeout`      | Retry once with an explicit note in the retry prompt: "Your previous run exhausted its turn limit. Commit any partial work immediately, then complete only what is essential. Defer non-critical work." If the retry also times out, escalate to human — scope may need to be reduced in the IMPL doc. |

**Backward compatibility:** If `failure_type` is absent from a completion report
that has `status: partial` or `status: blocked`, treat as `escalate` (most
conservative fallback). This preserves compatibility with agents that predate E19.

**Relationship to E7:** E7 defines the general failure handling rule (wave does
not merge, enters BLOCKED state). E19 is the decision tree within that BLOCKED
state — it specifies what the Orchestrator does next based on failure classification.
E7 and E19 are complementary; E19 does not supersede E7.

**Relationship to E7a:** E7a defines automatic remediation for correctable failures
in `--auto` mode. E19 extends this to non-`--auto` mode for `transient` and
`fixable` failures. In `--auto` mode, E7a and E19 apply together; E7a's retry
limit (2 retries) applies.

**Related Rules:** See E7 (agent failure handling), E7a (automatic failure
remediation), message-formats.md (failure_type field definition).

### E19.1 — Per-IMPL Reactions Override

Scout may write a `reactions:` block in the IMPL doc to override E19 defaults
for a specific feature. When present, the orchestrator reads this block at wave
start and uses it instead of the hardcoded constants.

**reactions block schema:**

```yaml
reactions:
  transient:
    action: retry
    max_attempts: 3     # override default (2)
  timeout:
    action: retry
    max_attempts: 1
  fixable:
    action: send-fix-prompt
    max_attempts: 1
  needs_replan:
    action: pause       # surface to human; "auto-scout" is a stretch goal
  escalate:
    action: pause
```

**Valid action values:**
- `retry` — re-launch agent with retry context (transient, timeout)
- `send-fix-prompt` — apply fix from notes and relaunch (fixable)
- `pause` — surface to human, do not auto-retry
- `auto-scout` — re-engage Scout automatically (stretch goal; treat as pause if not implemented)

**Backward compatibility:** IMPL docs without a `reactions:` block get E19
default behavior unchanged. Individual missing entries also fall back to defaults.

**When Scout should write reactions:**
- High pre-mortem risk (overall_risk: high) → increase max_attempts for transient
- Strict/sensitive codebase → reduce max_attempts, prefer pause over auto-retry
- Known flaky CI → increase timeout max_attempts
- needs_replan or escalate: always use `pause` (auto-scout is optional enhancement)

---

## E20: Stub Detection Post-Wave

**Trigger:** After all wave agents in a wave write their completion reports and before the review checkpoint.

**Required Action:** The Orchestrator:
1. Collects the union of all `files_changed` and `files_created` from wave agent completion reports.
2. Runs `sawtools scan-stubs --append-impl "<manifest-path>" --wave {N}` — this writes the report directly into the manifest.
3. The scan report is available in the manifest's stub detection section for that wave.

**Two-phase enforcement:**

1. **Agent-level (SubagentStop, blocking):** The `validate_agent_completion` hook checks each wave agent at exit. If an agent reports `status: complete` but `sawtools scan-stubs` finds stub patterns in their changed files, the agent is blocked (exit 2). The agent must either fix the stubs or change status to `partial`. This prevents agents from self-reporting "complete" while leaving placeholder implementations.

2. **Orchestrator-level (post-wave, informational):** Exit code of `sawtools scan-stubs` at the orchestrator level is always 0 — the post-wave scan is informational. Stubs found are surfaced at the review checkpoint but do not block merge automatically. By this point, agents claiming `status: complete` have already passed the SubagentStop consistency check.

**Note:** `finalize-wave` runs the orchestrator-level stub scanning automatically as step 2 of its pipeline; the orchestrator does not need to invoke this manually when using `finalize-wave`.

**Rationale:** An agent can write a syntactically correct function shell with a stub body (`pass`, `...`, `raise NotImplementedError`) and mark `[COMPLETE]`. The human reviewer approving the plan (not the diff) may not catch it. The SubagentStop gate catches this mechanically; the post-wave scan provides a consolidated view for human review.

**Related Rules:** See E21 (post-wave verification gates), E42 (SubagentStop validation), `message-formats.md` (## Stub Report Section Format).

---

## E21: Automated Post-Wave Verification (Three-Phase Execution)

**Trigger:** After all wave agents in a wave report complete and after E20 stub scan, before merge.

**Required Action:** If the IMPL doc contains a `quality_gates` section, the Orchestrator reads the configured gates and executes them in three phases:

### Phase 1: PRE_VALIDATION (Sequential)

Gates with `phase: PRE_VALIDATION` run sequentially before validation gates. These gates typically auto-fix issues (format, lint --fix) and modify source files in place. Format gates with `fix: true` invalidate the gate cache after running so subsequent phases see the reformatted code.

**CRITICAL CONSTRAINT (BLOCKER 2):** Format gates with `fix: true` MUST be placed in PRE_VALIDATION phase. The validator enforces this at gate execution time. Placing fix-mode gates in VALIDATION or POST_VALIDATION phases will cause validation errors because cache invalidation during parallel execution leads to undefined behavior.

Example:
```yaml
quality_gates:
  level: standard
  gates:
    - type: format
      phase: PRE_VALIDATION
      command: gofmt -w .
      fix: true
      required: true
```

### Phase 2: VALIDATION (Parallel)

Gates with `phase: VALIDATION` (or gates with empty `phase` field, for backward compatibility) run after PRE_VALIDATION completes. Gates in the same `parallel_group` execute concurrently using goroutines. Gates with empty `parallel_group` run sequentially.

Example:
```yaml
quality_gates:
  level: standard
  gates:
    - type: typecheck
      phase: VALIDATION
      parallel_group: validation
      command: go vet ./...
      required: true
    - type: test
      phase: VALIDATION
      parallel_group: validation
      command: go test ./...
      required: true
    - type: lint
      phase: VALIDATION
      parallel_group: validation
      command: golangci-lint run
      required: true
```

All three gates above run simultaneously. Results are collected and reported together.

### Phase 3: POST_VALIDATION (Parallel)

Gates with `phase: POST_VALIDATION` run after VALIDATION completes. These gates typically review code quality but don't affect correctness (code_review, implementation_verify). Parallel execution within POST_VALIDATION follows the same `parallel_group` rules as VALIDATION.

Example:
```yaml
quality_gates:
  level: standard
  gates:
    - type: custom
      phase: POST_VALIDATION
      parallel_group: review
      command: sawtools run-review --impl IMPL-feature.yaml --wave 1
      required: false
```

### Execution Order Summary

1. PRE_VALIDATION gates run sequentially (fix mode gates modify source)
2. VALIDATION gates run in parallel groups (independent checks)
3. POST_VALIDATION gates run in parallel groups (non-blocking reviews)

Phases execute sequentially. Within each phase, gates with the same `parallel_group` run concurrently. Gates with empty `parallel_group` run sequentially in declaration order.

### Backward Compatibility

- Gates with empty `phase` field default to `VALIDATION`
- Gates with empty `parallel_group` run sequentially (no behavior change)
- Existing IMPL docs continue to work without modification

### Thread Safety

The gate cache (`pkg/gatecache`) is protected by `sync.RWMutex` to ensure concurrent gate execution does not cause data races. Multiple goroutines can read from the cache simultaneously (RLock), but cache writes and invalidations acquire exclusive locks (Lock).

### Required vs. Advisory Gates

For each gate:
- `required: true` — non-zero exit code **blocks merge**. Report failure to user.
- `required: false` — non-zero exit code is a **warning only**. Log and continue.

This applies across all phases. A failed PRE_VALIDATION gate with `required: true` blocks execution of VALIDATION and POST_VALIDATION phases.

### Format Gate Fix Mode

Quality gates with `fix: true` in their configuration run in **fix mode** — they auto-apply formatting corrections (e.g., `gofmt -w`, `prettier --write`) rather than merely checking. Fix-mode gates:

1. Execute the fix command (e.g., `gofmt -w ./...`)
2. Report pass/fail based on exit code (0 = pass)
3. Invalidate the gate cache so subsequent gates see the reformatted files

**CRITICAL:** Fix-mode gates MUST be placed in PRE_VALIDATION phase. The validator enforces this constraint. Fix-mode gates modify files in-place but do not `git add` or commit — that is the caller's responsibility.

**Closed-loop gate retry (CLI path only):** When a required pre-merge gate fails, `sawtools finalize-wave` automatically calls `engine.ClosedLoopGateRetry` (up to 2 retries) before reporting failure. The retry spawns a repair agent that receives the gate output and attempts to fix the failing code in the agent's worktree. If the retry succeeds, gates are re-run to confirm before merge proceeds. This auto-retry is a CLI-only behavior — the engine path (`engine.FinalizeWave`) does not retry automatically.

**Cross-repo gate scoping:** Each `QualityGate` has an optional `repo` field. When set, the gate runs only in that repo's directory. When omitted, the gate runs in every repo the IMPL touches. For cross-repo IMPLs (file_ownership spans 2+ repos), every gate MUST include `repo:` — a docs-only repo has no build system and `go build ./...` will fail. The validator enforces this: `MR02_UNSCOPED_GATE` blocks IMPLs with 2+ repos and un-scoped gates at validation time (E16).

**Rationale:** Individual agents run gates in isolation (their own package scope). The orchestrator's post-wave gate runs unscoped — catching cross-package cascade failures that agent-scoped gates miss.

### Related Rules

See E21A (pre-wave baseline verification), E21B (parallel gate execution within phase), message-formats.md (Quality Gates Section Format)

---

## E21A: Pre-Wave Baseline Verification

**Trigger:** `prepare-wave` is about to create worktrees for a multi-agent wave

**Required Action:** Before creating any worktrees, the Orchestrator runs the
IMPL doc's `quality_gates` commands against the current HEAD. If any required
gate fails, `prepare-wave` exits with error code `baseline_verification_failed`
listing which gate commands failed. Wave agents do not launch until the baseline
is green.

**Exemptions:**
- If the IMPL doc defines no `quality_gates` (or the gates list is empty), E21A
  is a no-op. The wave proceeds without a baseline check.
- Solo waves (exactly one agent, no worktrees) are exempt from E21A. Baseline
  verification applies only to multi-agent waves.

**Rationale:** E21 (post-merge) runs gates after all agents have finished. If
the codebase is already broken at wave-start time, agents work on a broken
foundation and E21 fails after all parallel work is wasted. E21A catches this
upfront — a pre-flight check that verifies the baseline is green before
committing parallel agent time to a wave that will fail regardless.

**Failure handling:** On `baseline_verification_failed`, the Orchestrator surfaces
the failing gate commands and their output to the human. The wave does not launch.
The human must fix the codebase baseline (or update the gate configuration) before
re-running `prepare-wave`.

**E21B interaction:** When E21A runs multiple quality gates, E21B applies —
all gates execute concurrently and all failures are reported together before
the wave is blocked.

**Related Rules:** See E21 (post-merge quality gates), E21B (parallel gate
execution), `procedures.md` (Procedure 3, Phase 1: Pre-Launch Verification)

---

## E21B: Parallel Gate Execution

**Trigger:** `run-gates` is invoked with two or more quality gate commands

**Required Action:** Execute all quality gate commands concurrently rather than
sequentially. Collect all results before reporting. Report all failures together
(do not stop at the first failure). This applies to both E21 (post-merge) and
E21A (pre-wave baseline) invocations of `run-gates`.

**Rationale:** Sequential gate execution produces misleading failure reports: a
build gate failure suppresses test gate output, leaving the human uncertain whether
tests would have passed. Running gates concurrently reveals the full failure surface
in one pass, enabling faster diagnosis and fix.

**Failure reporting:** `run-gates` output lists each failing gate command with its
exit code and stderr/stdout excerpt, even when multiple gates fail simultaneously.
The overall exit code is non-zero if any required gate fails.

**Related Rules:** See E21 (post-merge quality gates), E21A (pre-wave baseline),
`message-formats.md` (Quality Gates Section Format)

---

## E22: Scaffold Build Verification

**Trigger:** Scaffold Agent completes file creation, before committing.

**Required Action:** The Scaffold Agent must run, in order:

1. **Dependency resolution** — ensure declared dependencies resolve:
   - Go: `go get ./...`
   - Python: `pip install -e .` or `uv sync`
   - Node: `npm install`
   - Rust: `cargo fetch`

2. **Dependency cleanup** (where applicable):
   - Go: `go mod tidy`

3. **Build verification** — confirm the project compiles with scaffold files present:
   - Go: `go build ./...`
   - Rust: `cargo build`
   - Node: `tsc --noEmit` or `npm run build`
   - Python: `python -m mypy .` or `python -m py_compile`

**Failure behavior:** If any step fails, the Scaffold Agent:
- Does NOT commit the scaffold files
- Marks each failing scaffold file's status as `FAILED: {error output}` in the IMPL doc Scaffolds section
- Reports `status: FAILED` in its completion report

The Orchestrator reads this and halts before creating any worktrees. The user must revise the interface contracts and re-run the Scaffold Agent.

**Note:** Scaffold build verification validates that each scaffold file compiles within its package (`go build ./path/to/package`), not the full project build (`go build ./...`). Full-project verification after scaffold commits is deferred to the prepare-wave baseline gate (E21A), which runs the quality gates against HEAD before worktree creation.

**Rationale:** Scaffold files define types and interfaces that Wave agents import. A scaffold file with a syntax error, wrong import path, or missing dependency causes every Wave agent in the next wave to fail immediately — wasting the full wave execution.

**Related Rules:** See `procedures.md` (Procedure 2: Scaffold Agent), `message-formats.md` (Scaffolds Section Format), `implementations/claude-code/prompts/agents/scaffold-agent.md`.

---

## E23: Per-Agent Context Extraction

**Trigger:** Orchestrator is about to launch a Wave agent.

**Required Action:** The orchestrator constructs a per-agent context payload for each Wave agent instead of passing the full IMPL doc. The payload contains exactly:

1. The agent's 9-field prompt section (extracted from IMPL doc by heading: `### Agent {ID} - {Role}`)
2. The full `## Interface Contracts` section
3. The full `## File Ownership` table
4. The full `## Scaffolds` section (agent needs to know what is pre-built)
5. The full `## Quality Gates` section (agent needs its verification commands)
6. The absolute path to the IMPL doc (agent writes completion report here per I5)

This assembled payload is passed as the `prompt` parameter when launching the agent. The agent does not receive or read the full IMPL doc.

**Excluded sections:** Other agents' 9-field prompt sections, `## Suitability Assessment`, `## Dependency Graph`, `## Pre-Mortem`, `## Known Issues`, `## Wave Structure` prose, completion reports from prior waves.

**Rationale:** Without extraction, N agents each receive N−1 other agents' full prompts — O(N²) token consumption that grows with wave size. With extraction, every agent receives the same payload size regardless of wave count. A 14-agent wave eliminates 182 unnecessary prompt reads (14 × 13). Context quality also improves: agents reason about their own task without unrelated implementation plans in working context.

**E6 interaction:** E6 (Agent Prompt Propagation) is unchanged. When the orchestrator updates an agent's section in the IMPL doc (interface deviation propagation), it re-extracts the updated payload before re-launching. The IMPL doc remains source of truth (I4); E23 describes how agents consume it at launch time.

**I4 interaction:** I4 (IMPL doc is source of truth) is unchanged. Agents write completion reports to the full IMPL doc via the absolute path included in the payload.

**Related:** See Per-Agent Context Payload in `message-formats.md`.

---

## E23A: Tool Journal Recovery

**Trigger:** Before launching a Wave agent, the Orchestrator checks for an existing tool journal at `.saw-state/wave{N}/agent-{ID}/index.jsonl`.

**Required Action:** If found:

1. **Load the journal:** Read all JSONL entries from the index file.

2. **Generate context.md:** Analyze the last 50 entries (or all entries if <50) to produce a summary containing:
   - **Files modified/created:** Extracted from Edit/Write tool entries, with line counts where available
   - **Commands run:** Extracted from Bash tool entries, with exit codes
   - **Tests executed:** Extracted from Bash tool entries matching test patterns (e.g., `go test`, `npm test`, `pytest`), with pass/fail counts
   - **Git commits made:** Extracted from Bash tool entries matching `git commit` commands, with SHAs and branch names
   - **Scaffold files imported:** Extracted from Read tool entries matching scaffold paths from the IMPL doc
   - **Verification gate status:** Extracted from Bash tool entries matching Field 6 verification commands
   - **Completion report status:** Whether the agent has written its completion report to the IMPL doc yet

3. **Prepend to agent prompt:** Insert the generated `context.md` under a `## Session Context (Recovered from Tool Journal)` heading at the beginning of the agent's prompt (before Field 0).

The journal becomes the agent's working memory across context compactions. It is append-only; entries are never deleted during execution.

**Interaction with I4 (IMPL doc as single source of truth):**

- The **IMPL doc** remains the source of truth for *planning*: agent prompts, interface contracts, file ownership, wave structure
- The **tool journal** is the source of truth for *execution history*: what the agent has actually done (tools called, files modified, commands run, tests executed)
- **Completion reports synthesize both**: "I modified these files (from journal), they implement these interfaces (from IMPL doc), tests pass (from journal), here's the commit SHA (from journal)"

This duality does not violate I4. The IMPL doc defines *what should be done*. The journal records *what was done*. Agents consult the IMPL doc for their task specification and write results back to it; they consult the journal to avoid repeating work they've already attempted.

**Failure recovery:** If an agent fails with `failure_type: transient` or `failure_type: fixable` (E19), the Orchestrator relaunches the agent. The journal is preserved across retries — the agent sees what it tried before and can avoid repeating failed operations. For example, if an agent tried a build command that failed due to a transient network error, on retry it sees the failed attempt in its recovered context and can proceed differently (or retry with awareness of the prior failure).

**Related Invariants:** See I4 (IMPL doc and journal duality)

**Related Rules:** See E19 (failure type decision tree), E6 (agent prompt propagation)

---

## E25: Integration Validation

**Trigger:** Wave agents complete. Timing depends on execution path:
- **CLI (`finalize-wave`):** Runs pre-merge at step 3.5a (after quality gates, before `MergeAgents`). Reports gaps in JSON output; does not auto-launch an Integration Agent.
- **Engine (`RunWaveFull`):** Runs post-merge. Gaps trigger automatic Integration Agent launch (E26).

**Required Action:** Scan for unconnected exports using AST analysis. Produce an `IntegrationReport` with gaps classified by severity (`error`, `warning`, `info`).

**Non-fatal:** Integration gaps do not block the pipeline. They are reported to the orchestrator, which decides whether to launch an Integration Agent (E26) to wire gaps automatically.

**Process:**
1. The orchestrator calls `ValidateIntegration` on the codebase for the completed wave.
2. `ValidateIntegration` walks all files changed by wave agents, identifies new exported symbols, and classifies each as an `IntegrationGap` if no caller is found in the existing codebase.
3. Each gap includes: `export_name`, `file_path`, `agent_id`, `category` (function_call, type_usage, field_init), `severity`, `reason`, and `suggested_fix`.
4. The `IntegrationReport` is persisted to the IMPL manifest under `integration_report:` for the completed wave.

**Severity classification:**
- `error` — exported function or type constructor with no callers and naming pattern suggesting it must be called (e.g., `Register*`, `Init*`, `Build*`)
- `warning` — exported symbol with no callers but ambiguous necessity (e.g., `New*` constructors that may be called by later waves)
- `info` — exported symbol with no callers that is likely intentionally public (e.g., types, constants, interfaces)

**Relationship to E21:** E25 runs after E21's post-wave verification gates pass. E21 validates that the build compiles and tests pass; E25 validates that the wave's exports are wired into the broader codebase.

**Related Rules:** See E26 (Integration Agent), E21 (post-wave verification gates)

---

## E26: Integration Agent

**Trigger:** E25 detects integration gaps with severity `error` or `warning`

**Required Action:** Launch a single Integration Agent with:

1. The `IntegrationReport` as input — the agent reads the gaps and their suggested fixes
2. Access restricted to `integration_connectors` files only — the IMPL manifest lists which files the Integration Agent may modify
3. Verification gate: `go build ./...` must pass after wiring

**Execution context:**
- **Engine path (`RunWaveFull`):** Integration Agent is launched automatically post-merge.
- **CLI path (`finalize-wave`):** Integration Agent must be launched manually by the Orchestrator after reading gap report from `finalize-wave` JSON output.
- Runs on the main branch (no worktree)
- Constraint role: `integrator` — may only modify files listed in the IMPL manifest's `integration_connectors` field
- The `integrator` constraint is enforced via `AllowedPathPrefixes` — the agent cannot write to agent-owned files or scaffold files
- Timeout: same as wave agent timeout (30 minutes)

**Failure behavior:** Non-fatal. If the Integration Agent fails (build does not pass, timeout exceeded, or gaps cannot be wired), the gaps are reported to the human via the orchestrator. The pipeline does not block; the next wave may proceed if its dependencies are met.

**Relationship to I1:** The Integration Agent is exempt from I1's disjoint ownership constraint. See I1 Amendment in `invariants.md` for the formal justification.

**Relationship to E25:** E25 produces the report; E26 acts on it. If E25 finds no `error` or `warning` gaps, E26 does not launch.

**Related Rules:** See E25 (Integration Validation), I1 Amendment (invariants.md)

---

## E27: Planned Integration Waves

**Trigger:** Scout identifies a wave whose sole purpose is wiring exports from prior waves into existing caller code (e.g., registering CLI commands in `main.go`, adding function calls in `server.go`).

**Required Action:** The Scout marks the wave with `type: integration` in the IMPL manifest. The Orchestrator dispatches the wave's agent(s) using the **Integration Agent** role (`subagent_type: integration-agent`) instead of the Wave Agent role.

**Distinction from E25/E26:** E25/E26 is reactive — the orchestrator detects integration gaps post-merge and launches an integration agent automatically. E27 is proactive — the Scout identifies integration work at planning time and declares it in the IMPL doc. Both use the same Integration Agent participant (see `participants.md`), but E27 agents receive their task from the IMPL doc's agent brief rather than from an `IntegrationReport`.

**Wave-level field:**
```yaml
waves:
  - number: 2
    type: integration    # Optional. Default: "standard"
    agents:
      - id: D
        task: "Wire new packages into main.go and finalize.go"
        files: [cmd/sawtools/main.go, pkg/engine/finalize.go]
```

**Orchestrator behavior for `type: integration` waves:**
1. Skip worktree creation — integration agents run on the main branch (merged result)
2. Skip isolation verification — no worktree branch to verify
3. Launch agent(s) with `subagent_type: integration-agent` instead of `wave-agent`
4. The agent's `files` list serves as `AllowedPathPrefixes` — same constraint as E26
5. All other wave mechanics apply: completion reports, status tracking, finalize-wave

**When to use `type: integration` vs relying on E25/E26:**
- Use `type: integration` when the Scout can enumerate exactly which files need wiring and what the wiring entails (planned integration). This is preferred because it gives the human a review opportunity during IMPL review.
- Rely on E25/E26 when integration gaps are not predictable at planning time (e.g., agents may or may not create new exports depending on implementation choices).
- Both mechanisms may apply to the same wave: E27 handles planned wiring, then E25/E26 catches any gaps the Scout missed.

**Relationship to I1:** Like E26, agents in `type: integration` waves are exempt from I1's disjoint ownership constraint for their listed files. See I1 Amendment in `invariants.md`.

**Related Rules:** See E25 (Integration Validation), E26 (Integration Agent), I1 Amendment (invariants.md)

---

## E28: Tier Execution Loop

**Trigger:** PROGRAM manifest state transitions to TIER_EXECUTING

**Required Action:** The Orchestrator reads the current tier from the PROGRAM manifest and launches Scout agents for all IMPLs in the tier with status "pending" (in parallel, using the existing `/saw scout` flow per IMPL). Each Scout receives the `--program` flag pointing to the PROGRAM manifest so it can consume frozen program contracts as immutable inputs.

After all IMPLs in the tier are scouted and reviewed, the Orchestrator executes each IMPL's waves using the standard `/saw wave --auto` flow. Track IMPL completion. When all IMPLs in the tier reach "complete", transition to tier gate (E29).

**Relationship to E1:** Scout launches are async (E1 applies)

**Relationship to P1/P3:** Tier structure is defined by PROGRAM manifest; enforcement of P1 (IMPLs are independent within a tier) and P3 (tier N+1 does not begin until tier N's gate passes)

**Enforcement of P1:** IMPLs within the same tier execute in parallel without coordination

**Related Invariants:** See P1 (intra-tier independence), P3 (tier gate sequencing) in `program-invariants.md`

---

## E28A: Pre-Existing IMPL Handling in Tier Execution

**Trigger:** Tier execution begins (E28) and the tier contains IMPLs with status "reviewed" or "complete" (pre-existing IMPLs that were imported into the PROGRAM manifest rather than created fresh by a Planner).

**Required Action:**

1. **Partition IMPLs by status.** Before launching Scouts, call `PartitionIMPLsByStatus(manifest, tierNumber)` to split the tier's IMPLs into two groups:
   - **needsScout:** IMPLs with status "pending" or "scouting" — proceed with normal Scout flow (E31)
   - **preExisting:** IMPLs with status "reviewed" or "complete" — skip Scout, validate instead

2. **Validate pre-existing IMPLs.** For each pre-existing IMPL, run `ValidateProgramImportMode(manifest, repoPath)` which performs:
   - **File existence:** Verify `IMPL-<slug>.yaml` exists at `docs/IMPL/` or `docs/IMPL/complete/`
   - **State consistency:** Parse the IMPL doc and verify its `state` field is consistent with the program-level status (e.g., an IMPL with program status "reviewed" must have IMPL doc state SCOUT_COMPLETE or REVIEWED; program status "complete" must have IMPL doc state COMPLETE)
   - **P1 compliance:** Verify `file_ownership` across all IMPLs in the same tier (both new and pre-existing) is disjoint — no two IMPLs in the tier may claim the same file
   - **P2 compliance:** Verify no pre-existing IMPL redefines a frozen program contract (a contract whose `freeze_at` tier has already completed)

3. **Unified review gate.** Present all IMPLs in the tier for human review together — both newly scouted IMPLs and validated pre-existing IMPLs. The reviewer sees the full tier picture and can reject any IMPL (new or imported) before wave execution begins.

4. **Stale brief check (Tier 2+, pre-existing IMPLs only).** Before proceeding to wave
   execution for Tier N (N ≥ 2), check whether pre-existing IMPLs in this tier have briefs
   that reference symbols modified by Tier N-1. Tier N-1 may have changed function signatures,
   added types, or restructured packages — making Tier N agent task descriptions stale.

   **When to check:** If the tier contains pre-existing IMPLs (status "reviewed") AND any
   Tier N-1 IMPL modified exported symbols in packages that Tier N IMPLs' owned files import.

   **Resolution:** Re-run Scout in brief-refresh mode for the affected IMPL. This re-runs
   Scout's analysis but preserves existing file ownership and wave structure — only agent
   task descriptions are updated to reflect the current (post-Tier-N-1) codebase state.
   The IMPL does not regress to SCOUT_PENDING; it stays at REVIEWED with updated briefs.

   This check is optional in non-auto mode (surface to human as a prompt). In auto mode,
   brief refresh runs automatically when stale briefs are detected.

5. **Proceed to wave execution.** After review approval and stale brief resolution, execute
   waves for all IMPLs in the tier. Pre-existing IMPLs with status "complete" skip wave
   execution entirely. Pre-existing IMPLs with status "reviewed" enter wave execution normally.

**Failure Handling:**

- If a pre-existing IMPL doc is missing from disk, the Orchestrator reports the missing file and enters BLOCKED. The user must either provide the IMPL doc or remove the IMPL from the PROGRAM manifest.
- If P1 validation fails (file ownership conflict between IMPLs in the same tier), the Orchestrator reports the conflicting files and enters BLOCKED. The user must resolve the conflict by moving one IMPL to a different tier or adjusting file ownership.
- If P2 validation fails (pre-existing IMPL redefines a frozen contract), the Orchestrator reports the violation and enters BLOCKED. The IMPL must be revised to consume (not redefine) the frozen contract.
- If state consistency fails (IMPL doc state does not match program status), the Orchestrator reports the mismatch and enters BLOCKED. The user must update either the IMPL doc state or the program status to be consistent.

**Relationship to E28:** E28A extends E28's tier execution loop to handle mixed tiers containing both new and pre-existing IMPLs. When all IMPLs in a tier are "pending", E28A is a no-op and E28 proceeds normally.

**Relationship to E31:** Scouts are only launched for IMPLs in the needsScout partition. Pre-existing IMPLs bypass E31 entirely.

**Related Invariants:** See P1 (intra-tier independence), P2 (contract immutability) in `program-invariants.md`

**Related Rules:** See E28 (tier execution loop), E31 (parallel Scout launching), E16 (IMPL doc validation)

---

## E28B: IMPL Branch Isolation

**Trigger:** The Orchestrator begins wave execution for an IMPL within a program tier (E28).

**Required Action:** Before executing waves for an IMPL in a program tier, the Orchestrator MUST create a long-lived IMPL branch using the `ProgramBranchName()` format:

```
saw/program/{slug}/tier{N}-impl-{implSlug}
```

All wave merges for that IMPL target the IMPL branch, not main. The IMPL branch serves as the baseline for `prepare-wave` verification when running inside a program context.

**Branch Lifecycle:**

```
main ──────────────────────────────────────> (tier gate) ──>
  \                                         /
   └─ IMPL-A branch ── wave1 ── wave2 ──┘
   └─ IMPL-B branch ── wave1 ──────────┘
```

1. `CreateProgramWorktrees` creates the IMPL branch from main at the start of tier execution.
2. `RunWaveFull` receives `MergeTarget` set to the IMPL branch name.
3. `FinalizeWave` / `MergeAgents` checks out the MergeTarget branch before merging agent branches, so wave results accumulate on the IMPL branch rather than main.
4. After ALL IMPLs in the tier complete, `FinalizeTier` merges each IMPL branch to main in sequence, then runs the tier gate (E29).

**MergeTarget Threading:**

The `MergeTarget` field flows through the wave lifecycle to control where agent branches merge:

- `RunTierLoop` sets `MergeTarget` to the IMPL branch name (from `ProgramBranchName()`)
- `RunWaveFull` passes `MergeTarget` through to `FinalizeWave`
- `FinalizeWave` passes `MergeTarget` through to `MergeAgents`
- `MergeAgents` checks out the target branch before performing no-fast-forward merges

When `MergeTarget` is empty (the default), merges target the current HEAD. This preserves backward compatibility for non-program IMPL execution where waves merge directly to main.

**Baseline Verification:**

When `prepare-wave` runs inside a program context, it uses the IMPL branch as the baseline for verification gates rather than main. The `--merge-target` flag controls which branch is checked out before running baseline checks. This ensures that each IMPL's wave preparation validates against the IMPL's own accumulated state, not against main (which may not yet contain any of the tier's work).

**Relationship to E28:** E28B specifies the branch isolation mechanism used during E28's wave execution step. E28 defines when IMPLs are executed; E28B defines where their wave merges land.

**Relationship to E29:** After E28B isolates each IMPL's work on its own branch, E29's tier gate runs after `FinalizeTier` merges all IMPL branches to main.

**Related Invariants:** See P5 (IMPL Branch Isolation) in `invariants.md`

---

## E29: Tier Gate Verification

**Trigger:** All IMPLs in a tier reach "complete"

**Required Action:** Run `sawtools tier-gate <manifest> --tier N`. This verifies all IMPLs are complete and runs the tier_gates quality gate commands from the PROGRAM manifest. If all gates pass, mark the tier as verified. If any required gate fails, enter BLOCKED.

**Enforcement of P3:** Tier N+1 does not begin until tier gate passes

**Failure Handling:** On gate failure, the Orchestrator surfaces the specific gate failure to the user and enters BLOCKED state. The user must resolve the failure (fix code, update gate definition, or descope failing IMPL) before the PROGRAM can advance to the next tier.

**Implementation:** `sawtools tier-gate` is implemented by the `RunTierGate` function (see interface contracts in IMPL doc). The function returns a `TierGateResult` struct with per-gate and per-IMPL status.

**Related Invariants:** See P3 (tier gate sequencing) in `program-invariants.md`

**Related Rules:** See E30 (contract freezing after gate pass), E28 (tier execution loop)

---

## E30: Program Contract Freezing

**Trigger:** Tier gate passes (E29)

**Required Action:** Run `sawtools freeze-contracts <manifest> --tier N`. This identifies program contracts whose `freeze_at` matches the completing tier, verifies their source files exist and are committed to HEAD, and marks them as frozen. Frozen contracts are immutable — any IMPL in a later tier that attempts to redefine a frozen contract violates P2.

**Enforcement of P2:** Contracts are frozen before next tier's Scouts launch. When Scouts in tier N+1 receive the PROGRAM manifest via `--program` flag (E28), they receive all contracts frozen up through tier N. Scouts must not redefine frozen contracts.

**Human gate:** After freezing, pause for human review before advancing to the next tier (unless `--auto` mode is active). The Orchestrator presents the list of newly frozen contracts and waits for confirmation to proceed.

**Implementation:** `sawtools freeze-contracts` is implemented by the `FreezeContracts` function (see interface contracts in IMPL doc). The function returns a `FreezeContractsResult` struct listing which contracts were frozen and any errors.

**Related Invariants:** See P2 (contract immutability) in `program-invariants.md`

**Related Rules:** See E29 (tier gate triggers freezing), E31 (Scouts receive frozen contracts)

---

## E31: Parallel Scout Launching

**Trigger:** Orchestrator is about to scout all IMPLs in a tier

**Required Action:** Launch one Scout agent per IMPL in the tier, all in parallel (E1 applies). Each Scout receives:
- (a) The feature description from the PROGRAM manifest's IMPL entry
- (b) `--program` flag with path to PROGRAM manifest
- (c) Standard Scout inputs (codebase access, CONTEXT.md)

Scout agents are independent — they do not coordinate with each other. The Orchestrator waits for all Scouts to complete, then validates each IMPL doc (E16), then presents all for human review.

**Relationship to E16:** Each IMPL doc is validated independently after its Scout completes

**Relationship to P2:** Scouts receive frozen contracts (E30) and must not redefine them. If a Scout attempts to redefine a frozen contract, the human reviewer catches this during IMPL review before any waves execute.

**Relationship to E28:** E31 defines the "launch Scouts for all IMPLs in the tier" step referenced in E28's tier execution loop

**Implementation:** The `--program` flag is passed to the Scout via `RunScoutOpts.ProgramManifestPath` (see interface contracts in IMPL doc). The engine reads the PROGRAM manifest and injects frozen contracts into the Scout prompt.

**Related Invariants:** See P1 (intra-tier independence), P2 (contract immutability) in `program-invariants.md`

**Related Rules:** See E28 (tier execution loop), E16 (IMPL doc validation), E30 (contract freezing)

---

## E32: Cross-IMPL Progress Tracking

**Trigger:** Any IMPL within a PROGRAM changes state

**Required Action:** The Orchestrator updates the PROGRAM manifest's impl status field and completion counters. Run `sawtools program-status <manifest>` to get a structured report. When reporting status to the user, show tier-level progress (how many IMPLs in each tier are complete) and overall progress.

**Enforcement of P4:** PROGRAM manifest is always up to date. The manifest is the single source of truth for program state, including which IMPLs are pending, in progress, complete, or blocked.

**Status report structure:** The `ProgramStatusResult` (see interface contracts in IMPL doc) includes:
- Current tier number
- Per-tier IMPL statuses (pending, in_progress, complete, blocked)
- Contract freeze states (which contracts are frozen at which tier)
- Completion tracking (N of M IMPLs complete in current tier, overall completion percentage)

**Implementation:** `sawtools program-status` is implemented by the `GetProgramStatus` function (see interface contracts in IMPL doc). The function cross-references IMPL docs on disk for real-time status.

**User reporting:** The Orchestrator displays tier-level progress in the CLI/UI:
```
PROGRAM: my-program (Tier 2 of 3)
  Tier 1: 3/3 complete ✓
  Tier 2: 2/4 complete (IMPL-feature-a, IMPL-feature-b complete; IMPL-feature-c, IMPL-feature-d in progress)
  Tier 3: 0/2 pending
Overall: 5/9 IMPLs complete (56%)
```

**Related Invariants:** See P4 (PROGRAM manifest as source of truth) in `program-invariants.md`

**Related Rules:** See E28 (tier execution loop), E29 (tier gate verification)

---

## E33: Automatic Tier Advancement (--auto mode)

**Trigger:** All IMPLs in a tier reach "complete" and tier gate passes (E29)

**Required Action:** When `--auto` flag is active, the orchestrator automatically advances to the next tier without a human review gate. The advancement sequence is:

1. Run `sawtools freeze-contracts` (E30) to freeze contracts for the completing tier
2. Update PROGRAM manifest state to `TIER_EXECUTING` for the next tier
3. Launch Scout agents for all IMPLs in the next tier in parallel (E31)

If `--auto` is NOT active, pause for human review after contract freezing before advancing to the next tier (standard E30 behavior).

**Enforcement of P3:** Tier N+1 still waits for the tier gate (E29) to pass before any advancement occurs. The `--auto` flag bypasses the human confirmation step at tier boundaries, not the gate itself. Gate failures always surface to the human.

**Human gate exception:** The `PROGRAM_REVIEWED` state (initial plan approval by the human before any tier executes) is NEVER skipped, even in `--auto` mode. `--auto` only bypasses inter-tier human confirmation gates after the initial plan is approved. The human must approve the PROGRAM manifest before execution begins regardless of `--auto`.

**Failure handling:** If the tier gate fails (E29), the orchestrator enters `PROGRAM_BLOCKED` regardless of `--auto` mode. Failures always surface to the human. `--auto` provides no special handling for gate failures — the failure classification and remediation path (E19, E34) apply identically in both modes.

**Implementation:** Implemented by `AdvanceTierAutomatically(manifest, completedTier, repoPath, autoMode)` which returns a `TierAdvanceResult` struct indicating whether the tier was advanced, whether human review is required, and any errors encountered during freeze or state transition.

**Related Invariants:** See P2 (contract immutability), P3 (tier gate sequencing) in `program-invariants.md`

**Related Rules:** See E29 (tier gate triggers freezing), E30 (contract freezing after gate pass), E31 (parallel Scout launching)

---

## E34: Planner Re-Engagement on Failure

**Trigger:** Tier gate fails (E29) OR user explicitly requests re-plan

**Required Action:** Launch a Planner agent with a revision prompt containing:

1. The current PROGRAM manifest (full content)
2. Failure context: which tier failed, which IMPL failed (if applicable), which gate command failed and its output
3. Completion reports from all IMPLs in the failed tier (extracted from their IMPL docs)
4. Instruction to revise PROGRAM contracts or tier structure to address the failure

The Planner produces a revised PROGRAM manifest. The orchestrator validates it (E16) and presents it for human review (`PROGRAM_REVIEWED` state). Execution does NOT resume automatically — the human must approve the revised plan before any tier re-executes.

**Non-destructive:** Completed tiers are NOT re-run. The Planner may revise the failed tier and all subsequent tiers, but must not alter contracts already frozen for completed tiers (P2). The orchestrator validates that the revised manifest does not modify frozen contracts before presenting it for human review.

**Relationship to E8:** E34 is the program-scope analog of E8 (same-wave interface failure). E8 handles intra-wave contract failures by re-engaging Scout to revise an IMPL doc. E34 handles inter-tier failures by re-engaging Planner to revise the PROGRAM manifest. Both require human review of the revised plan before execution resumes.

**Implementation:** Implemented by `ReplanProgram(opts ReplanProgramOpts)` which reads the current manifest, constructs the revision prompt with failure context, launches the Planner agent, and returns a `ReplanResult` struct with the path to the revised manifest and validation status.

**Related Invariants:** See P2 (contract immutability — frozen contracts cannot be revised), P4 (PROGRAM manifest as source of truth) in `program-invariants.md`

**Related Rules:** See E8 (same-wave interface failure — analogous pattern at IMPL scope), E29 (tier gate verification — failure trigger), E16 (IMPL doc validation — applied to revised manifest)

---

## E35: Wiring Obligation Declaration

**Trigger:** Scout identifies that an agent will implement an exported symbol (function, type, method) that must be called from an existing aggregation point in a file not created by that agent.

**Scope:** E35 covers **same-package callers only** — files in the same package as the defining file that call the symbol but are not in the defining agent's ownership. Cross-package callers (files in different packages that import and call the symbol) are handled reactively by E25/E26 post-merge integration gap detection. Test files (`*_test.go`) calling changed symbols are handled separately by E46. This scope boundary tells Scout what must be resolved at planning time vs what can be deferred to post-merge integration.

**Rule:** The Scout MUST:
1. Assign the aggregation file to the implementing agent's `file_ownership` (preferred), OR
2. Write a `wiring:` entry in the IMPL doc if assigning to the same agent creates a same-wave conflict, and assign the caller to an integration agent in a later wave.

**Wiring declaration schema:**
```yaml
wiring:
  - symbol: <exported function or type name>
    defined_in: <relative path to implementing file>
    must_be_called_from: <relative path to caller/aggregator file>
    agent: <agent ID that owns both sides>
    wave: <wave number>
    integration_pattern: append | register | inject | call
```

**Enforcement:**
- **prepare-wave pre-flight (Layer 3A):** fails if `must_be_called_from` is not in the owning agent's `file_ownership`.
- **validate-integration --wiring (Layer 3B):** post-merge grep/AST check that `symbol` actually appears as a call in `must_be_called_from`. Reports severity: error (not info) for declared but missing wiring.
- **Agent brief injection (Layer 3C):** prepare-wave injects all `wiring:` entries for the agent into `.saw-agent-brief.md` with explicit instruction.

**Detection aid:** Scout can auto-generate wiring declarations from agent task prompts using `sawtools detect-wiring <impl-doc-path>`. This command scans for patterns like "calls `FunctionName()`" and cross-references against file_ownership to detect cross-agent function calls. Output is YAML in wiring: schema format. Pattern matching is ~80% reliable; Scout should review and adjust before committing.

**Rationale:** The heuristic export scanner (E25/E26) detects gaps reactively post-merge. E35 makes wiring intent explicit and machine-checkable before and after execution.

**Relationship to E25/E26:** E25/E26 is reactive — it detects integration gaps post-merge via heuristics. E35 is proactive — the Scout declares wiring obligations at planning time, enabling pre-wave verification (Layer 3A) and precise post-merge checking (Layer 3B). Both mechanisms may apply to the same wave: E35 handles declared obligations, E25/E26 catches any gaps the Scout missed.

**Relationship to E27:** E27 allows Scout to create a planned `type: integration` wave for wiring work. E35 is the per-symbol declaration that precedes E27 — the `wiring:` entries drive which files the integration agent needs to modify.

**Related Rules:** See E25 (Integration Validation), E26 (Integration Agent), E27 (Planned Integration Waves)

---

## E36: IMPL Amendment (Living IMPL Docs)

**Trigger:** Orchestrator receives `/saw amend` subcommand on an active IMPL doc
(state is not COMPLETE; no SAW:COMPLETE marker present).

**Three operations:**

### E36a: Add Wave
`sawtools amend-impl <manifest> --add-wave`
- Appends a new wave skeleton (next wave number, empty agents array) to the manifest
- Validates the resulting manifest passes `sawtools validate` before saving
- New wave starts in WAVE_PENDING state after Scout adds agents via Scout-style
  interface contract definition
- Completed waves (all agents status: complete) are immutable — their file_ownership
  and interface_contracts entries cannot be changed by this operation

### E36b: Redirect Agent
`sawtools amend-impl <manifest> --redirect-agent <ID> --wave <N>`
- Valid only if the agent has NOT committed yet (checked by: no completion report
  in completion_reports map AND no git commits on worktree branch beyond base_commit)
- Updates the agent's task field in the manifest with new content (read from
  `--new-task` flag if provided; falls back to reading from stdin if omitted)
- Clears any partial completion report for the agent (if status != "complete")
- Does NOT recreate the worktree (agent re-reads updated task on next launch)
- If agent HAS committed: operation is rejected with ErrAmendBlocked

### E36c: Extend Scope
`sawtools amend-impl <manifest> --extend-scope`
- Returns a JSON hint: `{"operation": "extend-scope", "manifest_path": "<path>", "message": "Re-engage Scout with --impl-context <path>"}` — the CLI does not launch a Scout agent itself.
- The orchestrator is responsible for acting on the hint: launch Scout with `--impl-context <manifest>` so Scout can append new waves without modifying existing waves or contracts.
- Scout produces an updated IMPL doc with additional waves appended; human reviews before any new wave executes.
- The IMPL doc is not mutated by this command; it is a hint-only operation handled entirely in the CLI layer.

**Common preconditions for all E36 operations:**
1. IMPL doc must not have completion_date set (state != COMPLETE)
2. SAW:COMPLETE marker must not be present in the file
3. Resulting manifest must pass `sawtools validate` after mutation
4. File ownership for agents in completed waves is frozen (cannot be changed)
5. Interface contracts listed in frozen_contracts_hash are immutable

**Failure handling:** If any precondition fails, the operation returns an error
with `ErrAmendBlocked` as the sentinel. The IMPL doc is not modified.

**Related Rules:** See E2 (interface freeze), E14 (IMPL doc write discipline),
E15 (completion marker — amend invalid after SAW:COMPLETE)

---

## E37: Pre-Wave Brief Review (Critic Gate)

**Trigger:** After IMPL doc validation passes (E16) and before entering REVIEWED state.
Auto-triggered when wave 1 has 3 or more agents, or when file_ownership contains
entries from 2 or more repos. Optional for smaller IMPLs; can be suppressed with
`--no-critic` flag on `sawtools run-scout`.

**CLI orchestration note:** In CLI orchestration mode (inside a Claude Code session),
use `sawtools run-critic --backend agent-tool "<impl-path>"` to get the assembled
critic prompt without spawning a subprocess. Capture the stdout output and pass it
as the `prompt` parameter when launching the critic via the Agent tool:
`Agent(subagent_type=critic-agent, run_in_background=true, description="[SAW:critic:<slug>]",
prompt="$(sawtools run-critic --backend agent-tool '<impl-path>')")`.
The --backend cli mode (default) spawns a subprocess and fails inside
an active Claude Code session; always use --backend agent-tool in CLI orchestration.

**Required Action:** The orchestrator launches a critic agent with the IMPL doc and
all source files listed in file_ownership. The critic:
1. Reads the IMPL doc in full (all agent briefs, interface contracts, file ownership)
2. For each agent brief, reads every source file listed in that agent's file ownership
3. Verifies each brief against the actual codebase (see verification checks below)
4. Writes a structured CriticResult to the IMPL doc under critic_report field
5. Emits overall verdict: PASS or ISSUES

### Enforcement Point (Added in P5)

After critic writes verdict to IMPL doc, `prepare-wave` checks the verdict before creating worktrees.
The overall `verdict` field is `"PASS"` or `"ISSUES"`. The critic sets `verdict: PASS` when
all issues are warnings (no errors present). Only error-severity issues produce `verdict: ISSUES`.

- **Verdict: PASS** → proceed with worktree creation (even if warnings are noted)
- **Verdict: ISSUES** → exit code 1, block worktree creation (at least one error present)

Error message format:
```
Error: E37: critic found N error(s) in agent briefs — fix before launching wave
```

This ensures agents cannot launch with inaccurate briefs, while warning-only results
do not block execution.

**Verification checks per agent brief (9 universal checks + 1 project-specific slot):**

- Check 1 (file_existence): Every file marked `action: modify` must exist in the repo;
  every file marked `action: new` must NOT exist (would cause conflict at agent write time).
  Files with no action field: skip.

- Check 2 (symbol_accuracy): Symbols (functions, types, methods, constants) referenced in the
  brief must exist in the codebase at the stated location.
  **Scope filter:** Skip entirely for agents whose ALL owned files are `action: new` — the
  symbols do not exist yet and absence is expected. Apply only when the brief references
  symbols in pre-existing files.

- Check 3 (pattern_accuracy): Implementation patterns described in the brief (e.g. "call X to
  register handler", "add field to struct Y") must match the actual patterns in the
  source files. Verify by reading the referenced files directly.

- Check 4 (interface_consistency): Interface contracts specified in the IMPL must be
  syntactically valid for the target language and consistent with types referenced
  in source files.

- Check 5 (import_chains): All packages referenced in interface contracts must be importable
  from the target module (exist in the dependency manifest or as local packages).
  **Scope filter:** Skip for agents with ONLY `action: new` files — import chains cannot be
  validated until the packages exist.

- Check 6 (side_effect_completeness): If a brief creates a new exported symbol that must be
  registered (CLI command, HTTP route, React component, agent type), verify the registration
  file is also in the file_ownership table or in `integration_connectors`.

- Check 7 (complexity_balance): Warning if any agent owns >8 files or >40% of total IMPL
  files. Advisory only — does not block PASS verdict.

- Check 8 (caller_exhaustiveness): Verify all callers of symbols being changed are in
  file_ownership. **Search the full repository** — callers in sibling packages are the most
  commonly missed category; package-scoped search is insufficient.
  - Production callers not in file_ownership = severity: error
  - Test file callers not in file_ownership = severity: warning (test cascade, see E46)

- Check 9 (i1_disjoint_ownership): For each (wave, file) pair with more than one agent ID,
  flag as error — violates I1 disjoint ownership. Catches Scout planning errors before
  agents launch.

**Project-specific checks (implementation-defined):** Implementations may define additional
checks beyond 1–9 for project-specific correctness constraints (e.g., result package
semantics, naming conventions, security patterns). These are not part of the universal
protocol and must be documented in the implementation's critic agent definition.

**Output format:** CriticResult written to IMPL doc critic_report field (see
interface contracts in IMPL-critic-agent.yaml). Per-agent verdict: PASS or ISSUES.
Overall verdict: PASS (all agents pass) or ISSUES (one or more agents have errors).

**Note:** Critic agents write their results to the IMPL manifest via `sawtools set-critic-review` (or equivalent SDK call), not by direct file modification. This preserves the structured `critic_report:` field format.

**Failure path:** If overall verdict is ISSUES, orchestrator does NOT enter REVIEWED
state. Instead:
1. Orchestrator presents issues to human via the CriticResult summary
2. Human (or orchestrator in --auto mode) applies corrections:
   - Wrong file: update file_ownership, re-validate (E16), re-run critic
   - Wrong symbol: update interface contract or agent brief, re-validate, re-run critic
   - Missing registration: add registration file to file_ownership, re-validate, re-run critic
3. After corrections applied, orchestrator re-runs critic (via `sawtools run-critic --backend agent-tool` + Agent tool launch in CLI mode; via `sawtools run-critic` in programmatic/API orchestration)
4. Repeat until verdict is PASS, then enter REVIEWED state normally

**Skip condition:** Pass `--no-critic` to `sawtools run-scout` to disable
auto-triggering.
Manual skip: `sawtools run-critic --skip` writes a PASS result with
summary "Skipped by operator" to satisfy downstream state checks.

**Related rules:** E16 (schema validation precedes critic gate), E36 (amend
--redirect-agent is the recovery mechanism for agent-level brief corrections),
E2 (interface freeze: critic runs before freeze, so corrections are safe)

### Pre-Wave-Gate Standalone Check

`sawtools pre-wave-gate <manifest-path>` runs a structured pre-wave readiness check and returns JSON. Checks performed:

| Check | Description |
|-------|-------------|
| `validation` | Validates manifest structure and content (E16) |
| `critic_review` | Verifies a critic review has been performed (E37). Checks E37 trigger conditions first: if wave 1 has <3 agents AND file_ownership spans <2 repos, the check passes without requiring a critic report. Multi-repo detection counts unique `repo:` values from `file_ownership` entries (not just the top-level `repositories` field). |
| `scaffolds` | Verifies all scaffold files have `status: committed` |
| `state` | Confirms IMPL state allows wave execution |

Exit code 0 if `ready: true`; exit code 1 if any check fails. This is a standalone diagnostic command — it does not modify the manifest and does not create worktrees. It is distinct from `prepare-wave`'s inline pre-flight checks: `prepare-wave` runs a superset of these checks as part of its full pipeline (worktree creation, hook installation, brief extraction), whereas `pre-wave-gate` is a lightweight readiness probe that can be called independently at any time.

---

## E38: Gate Result Caching

**Trigger:** `run-gates` or `finalize-wave` runs quality gates with caching
enabled (the default). Opt out with `--no-cache` on `run-gates`.

**Required Action:** For each quality gate in the manifest:

1. Compute a cache key: `hash(headCommit + stagedDiffStat + unstagedDiffStat + gateCommand)`.
   The gate command string is part of the key, so changing a gate's command
   (e.g. adding a flag) automatically invalidates its cached result.

2. Check `.saw-state/gate-cache.json` for a non-expired entry matching the key.

3. **Cache hit:** Return the cached result immediately without re-executing the
   gate. Emit to stderr: `gate [TYPE]: skipped (cached at SHA <headCommit>)`.
   Set `from_cache: true` and `skip_reason: "cached at SHA <sha>"` in the
   GateResult.

4. **Cache miss:** Execute the gate command normally. Store the result in the
   cache under the computed key with a timestamp.

**TTL:** Cached entries expire after 5 minutes. Expired entries are treated
as misses and re-executed.

**Storage:** `.saw-state/gate-cache.json` — a runtime artifact. This file
MUST be listed in `.gitignore` and is not committed to version control.

**Opt-out:** Pass `--no-cache` to `sawtools run-gates` to bypass caching
entirely for that invocation. `finalize-wave` always uses caching for
pre-merge gates (steps 3, 3.5). Post-merge gates (step 5.5) always execute
fresh via `RunPostMergeGates`, which never consults the cache.

**Rationale:** Quality gate commands on large projects (full test suites,
slow linters) can take minutes per run. When the underlying codebase has not
changed between invocations — same HEAD commit, no staged/unstaged changes,
same command — re-execution produces identical output. Caching eliminates
this redundant work at wave boundaries, especially during iterative
development where gates are run multiple times before merge.

### E38 Cache Completeness Checklist

All gate execution paths must check the cache before running commands. The following paths are covered:

| Execution Path | Cache Consulted | Notes |
|----------------|----------------|-------|
| `sawtools run-gates` | Yes (default) | Opt-out via `--no-cache` |
| `finalize-wave` pre-merge gates (step 3, 3.5) | Yes (always) | Uses cached results from prior `run-gates` invocations |
| `finalize-wave` post-merge gates (step 5.5) | No (never) | Post-merge gates always execute fresh via `RunPostMergeGates` — the merge changes HEAD, invalidating any prior cache |
| E21A pre-wave baseline | Yes | Runs through `run-gates` internally |
| E21 post-wave verification | Yes | Runs through `run-gates` internally |

**Cache invalidation:** The cache key includes `headCommit + stagedDiffStat + unstagedDiffStat + gateCommand`. Any of the following invalidates the cache automatically:
- New commit (changes headCommit)
- Staged or unstaged file changes (changes diffStat)
- Modified gate command in IMPL doc (changes gateCommand)
- TTL expiry (5 minutes)

**Related Rules:** See E21 (post-wave verification gates), E21A (pre-wave
baseline), E21B (parallel gate execution).

---

## E39: Interview Mode (Deterministic Requirements Gathering)

**Trigger:** User invokes `/saw interview "<description>"` (in Claude Code) or `sawtools interview "<description>"` (CLI)

**Rule:** The orchestrator enters an INTERVIEWING state and conducts a structured question-and-answer session with the user. This is an alternative entry point to the Scout Agent pathway — instead of generating an IMPL doc in one turn, the orchestrator guides the user through explicit requirements gathering, then produces a REQUIREMENTS.md file suitable for `/saw bootstrap` or `/saw scout`.

### State Machine

Interview mode adds a new state to the Scout-and-Wave state machine:

```
IDLE → INTERVIEWING (on /saw interview command)
INTERVIEWING → SCOUT_PENDING (on interview completion, REQUIREMENTS.md written)
```

The INTERVIEWING state is terminal for the interview process — it either completes (writes REQUIREMENTS.md and transitions to SCOUT_PENDING) or the user pauses/abandons it. There is no automatic retry or failure recovery; if the user exits, they must explicitly resume.

### Interview Phases

An interview consists of **6 sequential phases**, each gathering a specific category of requirements:

1. **overview** — Title, goal, success metrics, non-goals
2. **scope** — In-scope items, out-of-scope items, assumptions
3. **requirements** — Functional requirements, non-functional requirements, constraints
4. **interfaces** — Data models, APIs, external dependencies
5. **stories** — User stories or use cases
6. **review** — Summary and confirmation

### State Persistence

After each question-answer turn, the orchestrator writes the current state to `docs/INTERVIEW-<slug>.yaml`. This file is the single source of truth for the interview's progress. The schema includes metadata (slug, status, mode), progress (phase, question_cursor), accumulated spec_data (structured answers by phase), and full history (transcript of all Q&A turns).

See `interview-mode.md` for full INTERVIEW-<slug>.yaml schema definition.

### Resume Capability

The user may pause an interview at any point. To resume:

```bash
sawtools interview --resume docs/INTERVIEW-<slug>.yaml
```

The orchestrator reads the INTERVIEW doc, restores the phase and question cursor, and continues from the next unanswered question. The history is preserved across resume operations.

### Output Contract

On completion, the orchestrator compiles the accumulated spec_data into `docs/REQUIREMENTS.md`, a structured markdown file with sections corresponding to the 6 interview phases. This file is suitable input for `/saw bootstrap` or `/saw scout`.

### Error Handling

- **Max questions exceeded:** Compile partial requirements with a warning, mark status=complete
- **Invalid phase transition:** Fail fast (internal bug, not user error)
- **stdin closed before completion:** Save state, print resume instruction, exit code 2

### Related Rules

- **E16 (Scout Output Validation):** Both interview mode and Scout produce structured requirements docs; E16 validates the IMPL doc that Scout produces
- **E17 (Scout Reads Project Memory):** Scout reads docs/CONTEXT.md; interview mode does not (it's earlier in the lifecycle)
- **Scout Agent (Scout.md):** Interview mode is an alternative to the Scout Agent when the user needs more structure

See `interview-mode.md` for full specification, schema details, and implementation notes.

---

## E40: Observability Event Emission

**Trigger:** Orchestrator actions that represent significant lifecycle transitions or resource consumption — specifically: Scout launch, Scout completion, agent start, agent completion (success or failure), wave start, wave merge, wave failure, IMPL completion, quality gate execution (pass or fail), tier advancement, tier gate pass/fail.

**Required Action:** Emit the appropriate observability event to the observability store using the SDK's `observability.RecordEvent()` function. Each trigger maps to a specific event type:

| Trigger               | Event Type           | Key Fields                                              |
|-----------------------|---------------------|---------------------------------------------------------|
| Scout launch          | `activity`          | activity_type=`scout_launch`                            |
| Scout completion      | `activity`          | activity_type=`scout_complete`                          |
| Agent start           | `activity`          | activity_type=`wave_start` (per-wave, not per-agent)    |
| Agent completion      | `agent_performance` | status, failure_type, duration, files_modified, tests   |
| Agent token usage     | `cost`              | model, input_tokens, output_tokens, cost_usd            |
| Wave merge            | `activity`          | activity_type=`wave_merge`                              |
| Wave failure          | `activity`          | activity_type=`wave_failed`                             |
| IMPL completion       | `activity`          | activity_type=`impl_complete`                           |
| Gate executed (pass)  | `activity`          | activity_type=`gate_executed`                           |
| Gate executed (fail)  | `activity`          | activity_type=`gate_failed`                             |
| Tier advanced         | `activity`          | activity_type=`tier_advanced`                           |
| Tier gate pass        | `activity`          | activity_type=`tier_gate_passed`                        |
| Tier gate fail        | `activity`          | activity_type=`tier_gate_failed`                        |

**Non-blocking requirement:** Event emission must not fail orchestrator operations. If the observability store is unavailable or a write fails, log the error and continue. Observability is informational — it must never block Scout launches, wave execution, or merges.

**Batch writes preferred:** When multiple events are generated in quick succession (e.g., multiple agents completing in a wave), implementations should batch writes into a single transaction where possible. This reduces database contention and improves throughput.

**Wire format:** Events are stored as JSONB in the observability database. There is no separate wire protocol — the SDK writes directly to the store. See `observability-events.md` for the complete event schema and JSON examples.

**Implementation guidance:**
1. Use `observability.RecordEvent(ctx, event)` from the SDK
2. Wrap event emission in a goroutine or fire-and-forget pattern to avoid blocking
3. If the store is not configured (e.g., local development without a database), skip emission silently
4. Include the IMPL slug and wave number in all events for cross-referencing
5. For cost events, compute `cost_usd` using the model's published pricing at the time of the call

### E40 Lifecycle Event Coverage Checklist

The following checklist enumerates ALL lifecycle events that must be emitted. Events marked "wired" are implemented in the SDK; events marked "pending" require implementation.

| Lifecycle Event | Event Type | Status | Emitting Location |
|----------------|-----------|--------|-------------------|
| Scout launch | `activity` (scout_launch) | wired | `RunScout()` in engine |
| Scout completion | `activity` (scout_complete) | wired | `RunScout()` in engine |
| Wave start | `activity` (wave_start) | wired | `prepare-wave` command |
| Agent completion (success) | `agent_performance` | wired | `finalize-wave` reads completion reports |
| Agent completion (failure) | `agent_performance` | wired | `finalize-wave` reads completion reports |
| Agent token usage | `cost` | pending | Requires Claude API usage callback integration |
| Wave merge | `activity` (wave_merge) | wired | `finalize-wave` merge step |
| Wave failure | `activity` (wave_failed) | wired | `finalize-wave` on merge failure |
| IMPL completion | `activity` (impl_complete) | wired | State machine COMPLETE transition |
| Gate executed (pass) | `activity` (gate_executed) | wired | `run-gates` command |
| Gate executed (fail) | `activity` (gate_failed) | wired | `run-gates` command |
| Tier advanced | `activity` (tier_advanced) | pending | Requires `RunTierLoop()` implementation |
| Tier gate pass | `activity` (tier_gate_passed) | pending | Requires `RunTierLoop()` implementation |
| Tier gate fail | `activity` (tier_gate_failed) | pending | Requires `RunTierLoop()` implementation |

**Pending events note:** Token/cost events require integration with Claude API response metadata. Tier-level events require the `RunTierLoop()` orchestration function (E28). These will be wired when their respective features are implemented.

**Why This Matters:** Without observability events, operators cannot track cost trends across IMPLs, identify agents with high failure rates, or audit orchestrator actions. E40 makes observability a first-class protocol concern rather than an afterthought.

**Related Rules:** See E19 (failure type classification — used in `agent_performance` events), E21 (quality gate execution — triggers `gate_executed`/`gate_failed` events), E28 (tier execution — triggers tier-level activity events), E29 (tier gate — triggers `tier_gate_passed`/`tier_gate_failed`), E33 (auto tier advancement — triggers `tier_advanced`)

---

## E41: Type Collision Detection

**Trigger:** Two distinct points in the wave lifecycle:

1. **prepare-wave (pre-flight):** Before worktree creation. Blocks wave launch. Run manually with `sawtools check-type-collisions <impl-doc>`.
2. **finalize-wave step 1.5 (pre-merge):** Before agent branches are merged. Blocking — if collisions are found, the merge does not proceed. This second check catches any collisions introduced during wave execution that were absent at launch time.

> **CLI-only note:** The finalize-wave step 1.5 collision check runs in the `sawtools` CLI path only. The programmatic engine path (`sawtools run-wave`) does not run this check; collision detection is not in the engine's step functions.

**Required Action:** Run `sawtools check-type-collisions <impl-doc>` to detect potential type name collisions across agents in the same wave. If two agents define the same type name in different files, the merge will fail with duplicate declarations.

**Implementation:** The `pkg/collision/` package in scout-and-wave-go provides AST-based detection. The prepare-wave check runs as a pre-flight step alongside E3 ownership verification. The finalize-wave step 1.5 check runs per-repo immediately after completion report verification (step 1.1) and conflict prediction (step 1.2).

**Detection mechanism:**
1. Parse all scaffold files and agent-owned files listed in the IMPL doc's file ownership table
2. Extract all top-level type, function, and const declarations from each file
3. Group declarations by Go package (files in the same directory share a package namespace)
4. Flag any type/function/const name that appears in files owned by different agents within the same package

**Failure Handling:** If collisions are detected, the wave does not launch. The Scout must revise the IMPL doc to resolve naming conflicts — either by renaming types to be unique, consolidating shared types into scaffold files (which are committed before worktree creation and thus shared by all agents), or moving conflicting declarations to different packages.

**Relationship to I1:** Type collision detection extends I1 (disjoint file ownership) from file-level to symbol-level. Two agents may own different files in the same package, but if both define `type Config struct{...}`, the merge produces a compilation error despite no file-level conflict.

**Related Rules:** See E3 (pre-launch ownership verification), E22 (scaffold build verification), I1 (disjoint file ownership)

---

## E42: SubagentStop Validation

**Trigger:** SubagentStop lifecycle event fires for any SAW agent (wave, critic, scout, or scaffold).

**Required Action:** A SubagentStop lifecycle hook validates that the completing agent has fulfilled its protocol obligations before the agent session closes. The hook reads the SubagentStop JSON payload from stdin, identifies SAW agents by parsing the `[SAW:...]` tag from `agent_description`, and runs agent-type-specific validation checks. Non-SAW agents pass through immediately (exit 0).

**Validation matrix:**

| Agent Type | Required Checks |
|-----------|----------------|
| Wave (`[SAW:wave*:agent-*]`) | I1 ownership verification, I5 commit verification, completion report in IMPL doc |
| Critic (`[SAW:critic:*]`) | `critic_report:` field present with `verdict`, `agents_reviewed`, and `issues` keys |
| Scout (`[SAW:scout]` or `[SAW:scout:*]`) | IMPL doc exists at expected path and passes `sawtools validate` |
| Scaffold (`[SAW:scaffold:*]`) | All scaffold entries have `status: committed (...)` |
| Other SAW tags | Pass through (exit 0) |

**Active IMPL marker:** Before creating worktrees, `prepare-wave` writes the absolute IMPL doc path to `.saw-state/active-impl` (creating the directory if needed). The E42 SubagentStop hook uses this file to locate the IMPL doc without requiring it as a command-line argument. If this file is absent when a wave agent exits, the hook falls back to extracting the path from `agent_description`.

**Validation sequence (wave agents):**

1. **Parse SAW tag** from `agent_description`. If no `[SAW:...]` tag, exit 0 (not a SAW agent).
2. **Find IMPL doc** via `.saw-state/active-impl` or extraction from `agent_description`.
3. **I1 ownership verification:** Run `git diff --name-only` in the worktree. Compare changed files against the agent's file ownership from `.saw-ownership.json`. Any unowned modified file triggers exit 2 with "I1 violation: agent modified unowned file(s): \<list\>".
4. **I5 commit verification:** Check that the worktree branch has at least 1 commit ahead of the merge base. If zero commits but a completion report exists, exit 2 with "I5 violation: completion report written but no commits found".
5. **Protocol report validation:** Verify the agent's completion report exists in the IMPL doc's `completion_reports:` section. Uses `sawtools check-completion` if available, otherwise falls back to grep-based detection.

**Exit code convention:**
- Exit 0: Pass (agent fulfilled obligations, or is not a SAW agent)
- Exit 2: Block (agent has unfulfilled protocol obligations)
- Stderr: Human-readable error message explaining what is missing
- Stdout: JSON observability event on success (non-blocking, emitted by separate async hook)

**Observability:** On successful validation, a separate async hook (`emit_agent_completion`) emits a structured JSON event containing agent_id, wave, status, files_changed, validation results, and timestamp. This event is consumed by claudewatch hooks and the web app SSE system. The async hook also handles journal archival. Because it runs with `async: true`, it never blocks the agent lifecycle.

**Rationale:** Without E42, agents can "complete" without fulfilling their protocol obligations. I1 ownership violations and I5 commit violations are only detected at wave finalization time (E21), creating a delayed feedback loop. E42 catches these violations at the agent boundary — the earliest possible point — enabling faster feedback and reducing wasted orchestrator time on agents that failed to comply.

**Failure Handling:** If the hook cannot locate the IMPL doc for a SAW-tagged agent, it exits 2 with an actionable error message. If `sawtools` is not on PATH, the hook degrades gracefully to grep-based validation. Performance is critical: non-SAW agents must exit 0 within milliseconds, and SAW agent validation should complete in under 2 seconds.

**Related Rules:** See I1 (disjoint file ownership — verified at agent completion), I4 (IMPL doc as single source of truth — completion reports verified), I5 (agents commit before reporting — commit existence verified), E3 (pre-launch ownership verification — E42 is the post-completion counterpart), E21 (post-wave verification gates — E42 provides earlier feedback), E40 (observability event emission — E42 emits agent_complete events)

---

## E43: Hook-Based Isolation Enforcement

**Trigger:** Wave agents launch in worktree context (multi-agent waves)

**Required Action:** Orchestrator ensures lifecycle hooks are installed and active before launching wave agents. Hook-based enforcement supersedes instruction-based isolation (agents following written protocol).

### Four-Hook Defense-in-Depth

**Hook 1: SubagentStart environment injection (inject_worktree_env)**
- Sets 5 environment variables when wave agents launch:
  - SAW_AGENT_WORKTREE (absolute worktree path)
  - SAW_AGENT_ID (agent identifier, e.g., "A", "B2")
  - SAW_WAVE_NUMBER (1-based wave number)
  - SAW_IMPL_PATH (absolute path to IMPL doc)
  - SAW_BRANCH (agent's branch name, e.g., "saw/{slug}/wave1-agent-A")
- Non-blocking (always exits 0)
- Solo waves and integration waves: SAW_AGENT_WORKTREE is empty string

**Hook 2: PreToolUse:Bash cd auto-injection (inject_bash_cd)**
- Prepends cd $SAW_AGENT_WORKTREE && to every bash command via updatedInput
- Fires only when SAW_AGENT_WORKTREE is non-empty (skips solo waves)
- Skips if command already starts with cd $SAW_AGENT_WORKTREE
- Non-blocking (always exits 0, injection is best-effort)
- Eliminates manual cd commands and $WORKTREE variable usage

**Hook 3: PreToolUse:Write/Edit path validation (validate_write_paths + saw-worktree-boundary.sh)**
- validate_write_paths: blocks relative paths and out-of-worktree writes using SAW_AGENT_WORKTREE (set by SubagentStart inject_worktree_env hook)
- saw-worktree-boundary.sh: hard-denies (exit 2) Write/Edit/MultiEdit calls whose target path resolves to the main repo root instead of the agent's worktree; uses SAW_WORKTREE_ROOT (set by prepare-wave, see E43 Implementation Notes)
- Both hooks fire only when their respective env var is non-empty (skips solo waves, integration waves, orchestrator context)
- Error message format: "[SAW] Write blocked: <path> is in main repo, not agent worktree. Use: <SAW_WORKTREE_ROOT>/..."
- Prevents Agent B leak scenario (files created in main repo instead of worktree)

**Hook 4: SubagentStop compliance verification (verify_worktree_compliance)**
- Checks completion report exists (E42/I4 compliance)
- Checks commits exist on branch (I5 compliance)
- Non-blocking (always exits 0, warnings logged to stderr)
- Creates audit trail for post-hoc violation analysis

### Relationship to E4

E43 enforces E4 mechanically. E4 (Worktree Isolation) states the requirement: all wave agents MUST use worktree isolation. E43 specifies the enforcement mechanism: lifecycle hooks that make isolation violations impossible rather than merely documented.

**Before E43 (instruction-based isolation):** Agents followed written protocol in the worktree isolation section of wave-agent.md (previously a separate reference file, now inlined). Violations were possible via agent error, context compaction loss, or rate-limit recovery gaps.

**After E43 (hook-based enforcement):** Claude Code hooks intercept tool calls before execution. Relative paths and out-of-bounds writes are blocked at the tool boundary. Bash commands run in the correct working directory automatically.

### Implementation Notes

- **Claude Code-specific:** E43 hooks use Claude Code lifecycle API (SubagentStart, PreToolUse, SubagentStop). Other platforms must implement equivalent enforcement at their tool invocation boundary.
- **SAW_WORKTREE_ROOT:** prepare-wave writes `.saw-worktree-env` to each agent's worktree root containing `SAW_WORKTREE_ROOT=<absolute_worktree_path>`. The `hooks/saw-worktree-boundary.sh` PreToolUse hook reads this var to enforce write boundaries independently of the SubagentStart hook. This provides defense-in-depth: boundary enforcement works even if the SubagentStart hook is unavailable.
- **Vendor-neutral fallback:** When hooks are unavailable, fall back to instruction-based isolation (E4 Layer 3: Field 0 self-verification). Agents manually verify working directory at startup.
- **Defense-in-depth:** E43 hooks complement E4 layers (pre-creation, task tool isolation, merge-time trip wire). All layers remain active.

**Related Invariants:** See I1 (disjoint file ownership), E4 (worktree isolation)

**Related Rules:** See E12 (isolation verification at agent startup)

---

## E44: Context Injection Observability

**Scout obligation:** Before completing, the Scout MUST call
`sawtools set-injection-method <impl-doc-path> --method <value>`
to record how reference files were received. Valid values: `hook`, `manual-fallback`, `unknown`.

**Orchestrator obligation:** `sawtools prepare-agent` automatically writes `context_source`
to each agent entry when extracting the brief. Valid values: `prepared-brief`, `cross-repo-full`.
The orchestrator may write `fallback-full-context` manually when the fallback prompt path was used.

**Enforcement:** `sawtools validate` warns (non-blocking) when `injection_method` is absent
on an active IMPL, and warns when `context_source` is absent on wave agents in
`WAVE_EXECUTING`/`WAVE_MERGING`/`WAVE_VERIFIED` state.

---

## E45: Shared Data Structure Scaffold Detection

**Trigger:** Scout phase, after defining agent tasks but before finalizing IMPL doc

**Required Action:** Scout scans agent task prompts, file_ownership, and
interface_contracts to detect data structures (structs, enums, type aliases,
traits) referenced by 2+ agents. For each detected shared type, Scout adds an
entry to the Scaffolds section of the IMPL doc.

**Detection heuristics:**
- Agent A owns file X, Agent B's task says "import TypeName from X"
- Type appears in interface_contracts AND 2+ agent tasks reference it
- Same struct/enum name mentioned in multiple agents' "Interfaces to implement"

**Does NOT trigger for:**
- Types from external packages (stdlib, third-party dependencies)
- Types in existing codebase files not owned by any agent
- Types mentioned in only one agent's task (no cross-agent dependency)

**Automated tool:** `sawtools detect-shared-types <impl-doc>` automates this
detection. Scout should invoke it after writing agent prompts (step 10 of Scout
procedure) and merge the output into the Scaffolds section.

**Rationale:** Agents cannot coordinate at runtime. If Agent A defines
`PreviewData` in fileA and Agent B also defines it in fileB (because B's task
says "create PreviewData struct"), the merge fails with duplicate declarations.
Scaffolding the shared type before Wave 1 prevents this I1 violation.

**Failure Handling:** If Scout omits a shared type from scaffolds and agents
create duplicate definitions, E11 (conflict prediction) will catch it at merge
time. However, this is a late failure — E45 exists to prevent it proactively.

**Related Invariants:** See I2 (interface contracts precede parallel implementation)

---

## E46: Test File Cascade Detection

**Trigger:** Scout planning phase (step 4: dependency analysis) OR pre-wave validation (E35 detection)

**Required Action:** When an interface contract involves signature changes (parameter modifications, return type migration, method removal), detect test files that reference the interface and ensure they are assigned to an agent in the same wave.

**Detection layers:**

1. **Scout-time (primary):** During dependency analysis, Scout scans for `*_test.go` files that reference changed interfaces:
   - For each interface contract with signature change keywords ("migrate", "update signature", "change return type")
   - Run: `sawtools check-callers "<InterfaceName>" --repo-dir <repo-path>` (returns JSON including test files)
   - Filter the output for `_test.go` files; assign unowned test files to the interface-changing agent

2. **Pre-wave validation (E35 extension):** `sawtools pre-wave-validate` runs E35 detection, which includes test cascade detection via `detectTestCascades()`. Reports orphaned test files as E35Gap entries with CalledFrom pointing to test file locations.
   As of E46, pre-wave-validate also runs Step 3: `check-test-cascade`, which performs a whole-repo
   scan for test files calling changed symbols. Exit 1 if any orphaned test callers are found.

3. **Post-merge verification (future work):** Documented as third detection layer, but not implemented in this IMPL. Future enhancement: add `VerifyTestCompilation()` to finalize-wave workflow to run `go test -compile-only` and catch missed test cascades before quality gates.

**Rationale:** Interface signature changes break test files that call the interface, but test files are often not included in file_ownership because Scout focuses on implementation files. Example from deps-review-fixes IMPL: Agent B changed LockFileParser.Parse signature, but 4 test files (cargolock_test.go, gosum_test.go, packagelock_test.go, poetrylock_test.go) were orphaned, causing 30 min of manual post-merge fixes.

**Failure Handling:**
- Scout-time detection prevents the issue (test files assigned to agent)
- E35 pre-wave validation catches missed cases (blocks wave launch)
- Post-merge verification is final safety net (blocks merge if tests don't compile)

**Related Rules:** E35 (same-package caller detection), E3 (pre-launch ownership verification)

---

## E47: Between-Wave Caller Cascade Hotfix

**Trigger:** `finalize-wave` verify-build step completes with
`CallerCascadeOnly=true` in `FinalizeWaveResult` — meaning verify-build
failed but ALL errors are in future-wave-owned or unowned files (caller
cascade side-effects of wave N signature changes, not genuine wave N failures).

**Required Action (automatic):** `sawtools finalize-wave` detects
`CallerCascadeOnly=true` and automatically runs the `apply-cascade-hotfix`
step inline (step 6a, after VerifyBuild). The hotfix agent is restricted
to the files listed in `CallerCascadeErrors` and applies minimal caller
fixes: result.Result[T] unwrapping, ctx param additions, deleted symbol
replacements. It commits as:
  `[SAW:wave{N}:integration-hotfix] fix caller cascade after wave N signature changes`

**Debugging / dry run:** Pass `--dry-run` to `finalize-wave` to see what
cascade errors would be hotfixed without running the agent. Output is a JSON
object with `step`, `dry_run`, `error_count`, `files`, and `errors`.

**Orchestrator behavior:** When `finalize-wave` exits 0 after the
`apply-cascade-hotfix` step, treat the wave as successfully finalized.
No manual Orchestrator action is required. If `finalize-wave` exits 1 with
`"apply-cascade-hotfix: build still fails after hotfix"`, route through
E7/E8 as a genuine build failure.

**Distinction from E26 (Integration Agent):**
- E26 wires unconnected *exports* into callers (missing call-sites).
- E47 fixes *compile errors* in callers caused by signature changes in the
  wave that just completed. E47 errors are compiler failures; E26 gaps are
  logical gaps (no failure, just incomplete wiring).

**Why This Is Not Optional:** Without E47, waves that change exported
function signatures (adding `ctx`, changing return types) will always fail
verify-build due to cascade errors in future-wave files. E47 automates
the repair as a named step in `finalize-wave`.

**Related Rules:** E26 (Integration Agent), E25 (integration gap detection),
E7 (completion verification), E8 (interface change recovery).

---

## E48: Critic Agent IMPL Commit Enforcement

**Trigger:** SubagentStop lifecycle event fires for a critic agent (tag `[SAW:critic:*]`).

**Required Action:** Before the critic agent session closes, the critic MUST commit
the IMPL doc changes produced by `sawtools set-critic-review`. Two enforcement
mechanisms apply:

1. **E42 SubagentStop hook (`validate_agent_completion`):** Extended to include a
   commit check in the critic validation path. After verifying `critic_report`
   content is present, the hook runs `git status --porcelain` on the IMPL doc.
   If dirty (uncommitted changes or staged-but-not-committed), exits 2 with:
   `"E48: Critic agent must commit IMPL doc changes before stopping."`

2. **Standalone SubagentStop hook (`hooks/saw-critic-impl-commit.sh`):** A
   dedicated hook file for critic commit enforcement, parallel to
   `hooks/saw-worktree-boundary.sh` for wave agent write boundaries. Exits 2
   if the critic agent's IMPL doc has uncommitted changes.

**IMPL doc location:** Both hooks locate the IMPL doc via `.saw-state/active-impl`
(written by `prepare-wave`), with fallback to extracting the path from the
agent_description field. The IMPL doc path MUST appear in the critic's
`description` (the `[SAW:critic:<slug>]` string passed to the Agent tool) to
enable fallback detection.

**Commit message format:**
```
chore: critic report for <slug> [SAW:critic:<slug>]
```

**Rationale:** Without E48, critic agents write critic_report to the IMPL doc
(via `sawtools set-critic-review`) but do not commit the file. The next step
in the flow is `sawtools prepare-wave`, which fails if the working directory is
dirty. This creates manual overhead: the orchestrator must commit the IMPL doc
before proceeding. E48 automates this by enforcing the commit at the agent
boundary, the same pattern E42 uses for wave agents (I5).

**Critic branch execution context:** Critics run on the main branch, not in a
worktree. The commit check must use `git -C <repo-root>` (derived from the
IMPL path), not from a worktree-relative path. This is distinct from wave
agents, which run in worktrees and use `.saw-ownership.json` to locate the
worktree root.

**Skip condition:** If the critic runs `sawtools set-critic-review` and the
command writes the critic_report without modifying the IMPL doc on disk (edge
case: no-op write), `git status --porcelain` returns empty and E48 passes
silently. This is correct behavior.

**Related Invariants:** See I4 (IMPL doc as single source of truth — completed
critic work must be committed), I5 (commit before reporting), E37 (critic gate
trigger and validation), E42 (SubagentStop validation matrix)

---

## Supplemental Rule Identifiers

The following identifiers appear in implementation code and comments as
cross-references. They are defined here to prevent documentation drift.

### R3: Pre-Merge Per-Agent Gate Retry

**Definition:** Pre-merge per-agent gate retry with fix attempts. When an
agent's quality gate (build, test, lint) fails before merge, the orchestrator
invokes a fix agent in the agent's worktree (closed-loop: fix attempt +
re-run gate), repeating up to MaxRetries times. Implemented by
`engine.ClosedLoopGateRetry`.

**Related Rules:** E21 (post-wave verification gates), E21B (parallel gate
execution), E42 (SubagentStop validation).

---

### C9: Self-Healing Validation

**Definition:** Self-healing validation — automatic correction loop for Scout
validation failures. When Scout output fails `protocol.Validate()`, the
orchestrator automatically re-prompts Scout with the validation errors (up to
3 retries). On exhaustion, state is set to `BLOCKED`. Implemented by
`engine.ScoutCorrectionLoop`.

**Related Rules:** See E16 (Scout Output Validation) and its correction loop
subsection for the full specification.

---

## Cross-References

- See `preconditions.md` for conditions that must hold before execution begins
- See `invariants.md` for runtime constraints that must hold during execution
- See `state-machine.md` and `message-formats.md` for state machine and message format specifications
- See `state-machine.md` for the SCOUT_VALIDATING state triggered by E16
- E17: Scout reads `docs/CONTEXT.md` before suitability assessment — see also `message-formats.md` (docs/CONTEXT.md schema)
- E18: Orchestrator creates/updates `docs/CONTEXT.md` after WAVE_VERIFIED → COMPLETE — see also E15, `message-formats.md`
- E19: Orchestrator applies `failure_type` decision tree on partial/blocked agents — see also E7, E7a, `message-formats.md`
- E20: Orchestrator runs stub detection after each wave — see also E21, `message-formats.md` (## Stub Report Section Format)
- E21: Orchestrator runs post-wave verification gates before merge — see also E20, E22, `message-formats.md` (## Quality Gates Section Format). See also E21A (pre-wave baseline), E21B (parallel gate execution)
- E21A: runs pre-wave baseline gates before worktree creation — see also E21, E21B, `procedures.md` (Procedure 3 Phase 1), `state-machine.md` (WAVE_PENDING → WAVE_EXECUTING guard)
- E21B: parallel gate execution for run-gates (E21 and E21A) — see also E21, E21A, `message-formats.md` (Quality Gates Section Format)
- E22: Scaffold Agent runs build verification before committing scaffold files — see also `procedures.md` (Procedure 2: Scaffold Agent), `message-formats.md` (Scaffolds Section Format), `implementations/claude-code/prompts/agents/scaffold-agent.md`
- E25: Orchestrator runs integration validation after wave merge — see also E26, `invariants.md` (I1 Amendment)
- E26: Integration Agent wires unconnected exports — see also E25, `invariants.md` (I1 Amendment), `participants.md` (Integration Agent)
- E27: Scout marks wiring-only waves as `type: integration` — see also E25, E26, `participants.md` (Integration Agent)
- E28: Orchestrator executes PROGRAM tiers (launches Scouts per IMPL, tracks completion) — see also `program-invariants.md` (P1, P3), E29, E31
- E29: Orchestrator runs tier gate verification before advancing to next tier — see also `program-invariants.md` (P3), E28, E30
- E30: Orchestrator freezes program contracts at tier boundaries — see also `program-invariants.md` (P2), E29, E31
- E31: Orchestrator launches Scouts in parallel for all IMPLs in a tier — see also `program-invariants.md` (P1, P2), E28, E16
- E32: Orchestrator tracks cross-IMPL progress and updates PROGRAM manifest — see also `program-invariants.md` (P4), E28, E29
- E33: Orchestrator auto-advances to next tier in `--auto` mode after tier gate passes — see also `program-invariants.md` (P2, P3), E29, E30, E31
- E34: Orchestrator re-engages Planner on tier gate failure to revise PROGRAM manifest — see also `program-invariants.md` (P2, P4), E8, E16, E29
- E35: Scout declares wiring obligations for exported symbols that must be called from aggregation files — enforced by prepare-wave (Layer 3A), validate-integration (Layer 3B), and agent brief injection (Layer 3C) — see also E25, E26, E27
- E37: Pre-Wave Brief Review (Critic Gate) — after E16 validation, before REVIEWED state; auto-triggered for large/multi-repo IMPLs; critic agent verifies briefs against actual codebase — see also E16, E36, E2, `participants.md` (Critic Agent)
- E36: IMPL Amendment — see E2, E14, E15
- E38: Gate Result Caching — run-gates/finalize-wave cache gate results keyed on headCommit+diffStat+command; TTL 5 min; --no-cache opt-out; stored in .saw-state/gate-cache.json — see also E21, E21A, E21B
- E39: Interview Mode (Deterministic Requirements Gathering) — /saw interview command; 6-phase structured Q&A; state persistence in INTERVIEW-<slug>.yaml; resume capability; outputs REQUIREMENTS.md for bootstrap/scout — see also E16, E17, Scout Agent, `interview-mode.md`, `state-machine.md` (INTERVIEWING state)
- E40: Observability Event Emission — orchestrator emits cost, agent_performance, and activity events at lifecycle transitions; non-blocking; batch writes preferred; stored as JSONB — see also E19, E21, E28, E29, E33, `observability-events.md`
- E41: Type Collision Detection — pre-flight check during prepare-wave; AST-based detection of duplicate type/function/const names across agents in same package; blocks wave launch on collision — see also E3, E22, I1
- E42: SubagentStop Validation — SubagentStop lifecycle hook validates protocol obligations before agent session closes; checks I1 ownership, I5 commit, and completion reports for wave agents; agent-type-specific validation matrix; exit 2 blocks completion — see also I1, I4, I5, E3, E21, E40
- E45: Shared Data Structure Scaffold Detection — Scout scans agent tasks and file ownership to detect types referenced by 2+ agents; emits scaffold entries before Wave 1; prevents duplicate definitions and merge-time I1 violations — see also I2, E11, E22, `procedures.md` (Scout Agent step 10), `message-formats.md` (Scaffolds Section Format)
- E46: Test File Cascade Detection — Scout and pre-wave validation detect test files referencing changed interfaces; test files assigned to same wave as interface changes to prevent orphaned tests; three detection layers (Scout-time, E35 extension, post-merge verification) — see also E35, E3, `procedures.md` (Scout Agent step 4)
- E47: Between-Wave Caller Cascade Hotfix — finalize-wave step 6a
  auto-applies hotfix when CallerCascadeOnly=true; --dry-run flag for
  diagnosis; distinct from E26 (compile errors vs missing wiring) — see
  also E26, E25, E7, E8
- E48: Critic agent must commit IMPL doc before stopping — see also E37 (critic gate), E42 (SubagentStop validation), `implementations/claude-code/prompts/agents/critic-agent.md`, `hooks/saw-critic-impl-commit.sh`
