# Scout-and-Wave Procedures

**Version:** 0.14.0

This document defines the operational procedures executed by the Orchestrator and other participants: suitability assessment, scaffold materialization, wave execution, and merge operations.

---

## Overview

SAW procedures are executed by the Orchestrator (synchronous agent in the user's session) with cooperation from asynchronous agents (Scout, Scaffold Agent, Wave Agents). The Orchestrator serializes all state transitions while asynchronous agents execute work in parallel.

**Participant roles:**
- **Orchestrator:** Drives all state transitions, launches agents, reads completion reports, executes merge procedure
- **Scout:** Analyzes codebase, produces IMPL doc, defines interface contracts
- **Scaffold Agent:** Materializes approved interface contracts as type scaffold files
- **Wave Agents:** Implement features in parallel against frozen interface contracts

---

## Procedure 1: Scout (Suitability Gate + IMPL Doc Production)

**Entry state:** SCOUT_PENDING
**Exit state:** SCOUT_VALIDATING (transitions to REVIEWED on validation pass, or BLOCKED on retry exhaustion)
**Executor:** Scout agent (asynchronous)

### Steps

1. **Launch:** Orchestrator launches Scout agent with absolute IMPL doc path
   - Agent runtime must provide repository context to avoid multi-repository ambiguity
   - Scout derives repository root from IMPL doc path (directory containing `docs/`)

2. **Suitability assessment:** Scout evaluates five preconditions (P1–P5)
   - **P1: File decomposition:** Work decomposes into ≥2 disjoint file groups
   - **P2: No investigation-first blockers:** No root cause analysis required before specification
   - **P3: Interface discoverability:** All cross-agent interfaces can be defined before implementation
   - **P4: Pre-implementation scan:** If working from audit/findings, classify each item as TO-DO/DONE/PARTIAL
   - **P5: Positive parallelization value:** `(sequential_time - slowest_agent_time) > (scout_time + merge_time)`

3. **Verdict emission:** Scout writes suitability verdict to IMPL doc (see `message-formats.md`)
   - If `NOT SUITABLE`: Include failed preconditions with evidence, suggest alternatives, terminate
   - If `SUITABLE` or `SUITABLE WITH CAVEATS`: Proceed to step 4

4. **Dependency mapping:** Scout analyzes cross-agent interfaces and dependencies
   - Identifies shared types needed by multiple agents
   - Groups agents into waves based on dependency chains
   - Wave N+1 depends on Wave N's outputs → sequential wave execution

5. **Interface contract definition:** Scout specifies exact signatures for all cross-agent interfaces
   - Function signatures with parameter types and return types
   - Type definitions (structs, interfaces, enums)
   - Import paths where contracts will be available

6. **Scaffold specification:** If shared types needed within a wave, Scout writes Scaffolds section to IMPL doc
   - Four-column table: File | Contents | Import path | Status
   - Status starts as `pending`
   - Solo waves: omit Scaffolds section (one agent cannot conflict with itself)

7. **Agent prompt generation:** Scout writes 9-field agent prompts to IMPL doc (Fields 0–8)
   - Field 0: Isolation verification (mandatory pre-flight)
   - Field 1: File ownership (disjoint, verified by E3 pre-launch check)
   - Field 2: Interfaces to implement
   - Field 3: Interfaces to call
   - Field 4: What to implement
   - Field 5: Tests to write
   - Field 6: Verification gate (scoped commands)
   - Field 7: Constraints
   - Field 8: Report instructions

8. **Completion:** Scout reports completion, Orchestrator reads IMPL doc, transitions to SCOUT_VALIDATING

### Orchestrator Actions After Scout Completes

- Read IMPL doc suitability verdict
- If `NOT SUITABLE`: Surface verdict to human with failed preconditions and alternatives, terminate protocol
- If `SUITABLE`: Run IMPL doc validator on all `type=impl-*` typed-block sections (E16)
  - **Validation pass:** Transition to REVIEWED; surface IMPL doc to human for review and approval
  - **Validation fail:** Issue correction prompt to Scout listing each error (block type, failure description, line/block location); Scout rewrites only the failing sections; re-run validator (up to 3 attempts)
  - **Retry limit exhausted:** Transition to BLOCKED; surface validation errors to human; do not enter REVIEWED
- Await explicit human approval before advancing to SCAFFOLD_PENDING or WAVE_PENDING

---

## Procedure 2: Scaffold Agent (Type Scaffold Materialization)

**Entry state:** SCAFFOLD_PENDING
**Exit state:** WAVE_PENDING (if all scaffolds committed) or BLOCKED (if compilation fails)
**Executor:** Scaffold Agent (asynchronous)
**Skip condition:** If IMPL doc Scaffolds section empty, skip directly to WAVE_PENDING

### Steps

1. **Launch:** Orchestrator launches Scaffold Agent with absolute IMPL doc path after human approves IMPL doc

2. **Read contracts:** Scaffold Agent reads IMPL doc Scaffolds section
   - Each row specifies: File path, Contents (exact types/interfaces), Import path, Status

3. **Create scaffold files:** For each row with `status: pending`:
   - Create file at specified path
   - Write exact type definitions from Contents column (no behavior, no function bodies)
   - Interfaces: method signatures only
   - Structs: field names and types only
   - No implementations, no test files

4. **Verify compilation:** Scaffold Agent runs build command to verify types are valid
   - If compilation fails: Update Status to `FAILED: {reason}`, report to IMPL doc, exit with status blocked
   - If compilation passes: Proceed to step 5

5. **Commit scaffold files:** Scaffold Agent commits all scaffold files to HEAD
   - Commit message: `scaffold: add type scaffolds for Wave {N}`
   - Record commit SHA

6. **Update IMPL doc:** For each successfully committed file, update Status column
   - Change `pending` → `committed (sha)`
   - If compilation failed for a file, Status shows `FAILED: {reason}`

7. **Completion:** Scaffold Agent exits, Orchestrator reads updated IMPL doc

### Orchestrator Actions After Scaffold Agent Completes

- Read IMPL doc Scaffolds section
- Verify all files show `committed (sha)` status
- If any file shows `FAILED: {reason}`:
  - Enter BLOCKED state
  - Surface failure to human with reason
  - Human revises interface contracts in IMPL doc
  - Re-run Scaffold Agent after revision
- If all files committed: Transition to WAVE_PENDING

### Interface Freeze (E2)

Scaffold files are committed to HEAD before worktrees are created. Once worktrees branch from HEAD, interface contracts become immutable. Revising a scaffold after worktrees exist requires:

**Option A (recreate and cherry-pick):** Remove worktrees, revise scaffold, recreate worktrees, cherry-pick unaffected agents' completed work

**Option B (descope and defer):** Leave current wave to complete against existing contracts, move interface revision to next wave boundary

---

## Procedure 3: Wave Execution Loop

**Entry state:** WAVE_PENDING
**Exit state:** WAVE_VERIFIED (if all agents succeed and verification passes) or BLOCKED (if any agent fails)
**Executor:** Orchestrator (launches agents), Wave Agents (execute work)

### Phase 1: Pre-Launch Verification

1. **Ownership verification (E3):** Orchestrator scans wave's file ownership table in IMPL doc
   - Check: No file appears in more than one agent's Field 1 (File Ownership) list
   - If overlap found: Protocol stop, surface error to human, correct IMPL doc before continuing

2. **Repository context check:** Determine whether this is a single-repo or cross-repo wave.

   **Single-repo wave:** Orchestrator and all agents work in the same repository. Use all five isolation layers (E4). Layer 2 (`isolation: "worktree"`) is available.

   **Cross-repo wave:** Agents work in two or more repositories simultaneously (e.g., engine extraction where Agent A works in `saw-engine/` and Agent B works in `saw-web/`). Cross-repo waves are supported with modified isolation procedure:
   - **Omit Layer 2** (`isolation: "worktree"` on the Agent tool) — it creates worktrees in the Orchestrator's repo, not the target repo. Omitting it is intentional, not a failure.
   - **Apply Layer 1 in each repo** — Orchestrator manually creates worktrees in every repo that agents touch before launching any agents (see `saw-worktree.md` Cross-Repo Mode section).
   - **Layer 0 in each repo** — Install pre-commit guard in each repo's `.git/hooks/pre-commit`.
   - **Layer 3 applies unchanged** — Each agent's Field 0 navigates to its repo+worktree via absolute path.
   - **Layer 4 applies per-repo** — Merge-time trip wire runs independently in each repo.
   - The IMPL doc file ownership table must include a `Repo` column identifying which repository each file belongs to.

### Phase 2: Worktree Creation

**Solo wave exception:** If wave contains exactly one agent, skip worktree creation. Agent runs on main branch directly. Proceed to Phase 3.

1. **Create worktrees:** For each agent in wave (excluding solo waves):
   ```
   git worktree add .claude/worktrees/wave{N}-agent-{ID} -b wave{N}-agent-{ID}
   ```
   - **E5: Naming convention:** `.claude/worktrees/wave{N}-agent-{ID}` is mandatory (observability requirement)
   - Branch name: `wave{N}-agent-{ID}` (matches worktree name)
   - All worktrees branch from current HEAD (includes committed scaffolds from Scaffold Agent)

2. **Install pre-commit hook (Layer 0 isolation):** Copy `hooks/pre-commit-guard.sh` to `.git/hooks/pre-commit`
   - Blocks commits to main during active waves
   - Provides instructive error with correct worktree path if agent attempts to commit to main
   - Orchestrator bypasses via `SAW_ALLOW_MAIN_COMMIT=1` for legitimate main commits

### Phase 3: Agent Launch (E1: Background Execution)

1. **Launch agents in parallel:** For each agent in wave:
   - Orchestrator launches agent asynchronously (background execution, non-blocking)
   - Construct per-agent context payload (E23): extract from the IMPL doc the agent's 9-field section + `## Interface Contracts` + `## File Ownership` table + `## Scaffolds` + `## Quality Gates` + absolute IMPL doc path. Pass assembled payload as the `prompt` parameter.
   - Agent receives extracted payload — does not read the full IMPL doc for instructions. Writes completion report to the provided IMPL doc path (I4, I5).
   - **E1 requirement:** All launches must be non-blocking. Blocking on one agent before launching the next eliminates parallelism (protocol violation).

2. **Monitor for completion:** Orchestrator monitors for completion notifications
   - Agent completion = completion report written to IMPL doc
   - Orchestrator polls asynchronously (does not block on individual agents)

### Phase 4: Agent Execution (Agent Responsibilities)

**Each agent independently:**

1. **Field 0: Isolation verification (mandatory pre-flight):**
   - Step 1: Navigate to worktree via strict `cd` (fails fast if worktree doesn't exist)
   - Step 2: Verify working directory matches expected worktree path
   - Step 3: Verify git branch matches expected branch name
   - Step 4: Verify worktree appears in `git worktree list`
   - If any check fails: Write isolation failure report to IMPL doc, exit immediately without modifying files

2. **Implementation:** Agent implements Field 4 (What to Implement) against interface contracts
   - Field 1: Only modify owned files (I1: disjoint ownership)
   - Field 2: Implement specified interfaces exactly
   - Field 3: Call interfaces from prior waves or scaffolds
   - Field 5: Write specified tests

3. **Verification gate (Field 6):** Agent runs exact scoped commands
   - Build (compile)
   - Lint
   - Tests (scoped to owned packages)
   - **E10: Scoped verification:** Agents run focused verification. Orchestrator runs unscoped post-merge verification to catch cascade failures.

4. **Commit (I5):** Agent commits changes to worktree branch before reporting
   - `git add .`
   - `git commit -m "wave{N}-agent-{ID}: {description}"`
   - Record commit SHA

5. **Completion report (E14):** Agent appends structured completion report to IMPL doc
   - Append under `### Agent {ID} - Completion Report` at end of file
   - Never edit earlier IMPL doc sections (ownership table, interface contracts, wave structure)
   - Write discipline makes IMPL doc conflicts predictably resolvable

### Phase 5: Completion Collection

1. **Wait for all agents:** Orchestrator waits until all agents in wave have written completion reports

2. **Read completion reports:** Orchestrator parses structured YAML blocks from IMPL doc

3. **Check for failures:**
   - Any agent `status: partial` → enter BLOCKED (see `failure_type` field and E19 for automatic remediation decision tree)
   - Any agent `status: blocked` → enter BLOCKED (see `failure_type` field and E19 for automatic remediation decision tree)
   - Any agent isolation verification failed → enter BLOCKED
   - All agents `status: complete` → proceed to steps 4–5

4. **E20: Stub detection.** After all agents complete:
   - Collect union of all `files_changed` and `files_created` from completion reports
   - Run `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" {file1} {file2} ...`
   - Append output to IMPL doc under `## Stub Report — Wave {N}` (exit code is always 0 — informational only)
   - Surface stubs at the review checkpoint; they do not automatically block merge

5. **E21: Quality gates.** If IMPL doc contains a `## Quality Gates` section:
   - Run all gates with `required: true`
   - Required gate failures → enter BLOCKED
   - Optional gate failures → warn only; do not block merge

### Phase 6: Failure Handling (If Blocked)

**E7: Agent failure handling:** Wave does not merge if any agent failed. Orchestrator resolves failing agents before merge.

**E7a: Automatic remediation in --auto mode:** For correctable failures (isolation, missing deps, transient build errors), Orchestrator automatically re-launches agent with corrections. Non-correctable failures (logic errors, test failures, contract violations) surface to human.

**Resolution paths:**
- **Isolation failure:** Re-launch with explicit repository context (absolute IMPL doc path)
- **Interface contract unimplementable (E8):** Revise contracts in IMPL doc, update affected prompts, restart wave from WAVE_PENDING
- **Partial completion:** Re-run agent after addressing blockers, or descope agent and defer to next wave
- **Out-of-scope dependency:** Surface to human, decide whether to expand agent's scope or defer

### Phase 7: Transition

- If any agent blocked: Enter BLOCKED state, await resolution
- If all agents complete: Transition to WAVE_MERGING (multi-agent) or WAVE_VERIFIED (solo wave)

---

## Procedure 4: Merge

**Entry state:** WAVE_MERGING
**Exit state:** WAVE_VERIFIED (if merge succeeds and verification passes) or BLOCKED (if conflicts or verification fails)
**Executor:** Orchestrator
**Skip condition:** Solo waves skip merge entirely (one agent on main, nothing to merge)
**Cross-repo note:** For cross-repo waves, all phases of this procedure run independently in each repository. The orchestrator merges each repo's agent branches into that repo's main branch. There is no cross-repo merge operation. Post-merge verification runs in each repo independently.

### Phase 1: Pre-Merge Conflict Prediction (E11)

1. **Read completion reports:** Orchestrator parses all agents' `files_changed` and `files_created` lists

2. **Cross-reference file lists:** Check if any file appears in multiple agents' lists
   - If overlap found: I1 violation (disjoint ownership broken)
   - Enter BLOCKED, surface error to human
   - Resolution: Correct IMPL doc ownership table, recreate worktrees, re-run wave

3. **Verify commits exist:** For each agent branch, verify it has commits beyond base
   - `git log main..wave{N}-agent-{ID} --oneline`
   - Empty branch = isolation failure (agent committed to main instead of worktree)
   - Layer 4 trip wire: catches isolation failures regardless of cause

### Phase 2: Per-Agent Merge

**E11: Merge order is arbitrary within a valid wave.** Same-wave agents are independent by construction. If merge order appears to matter, wave structure is wrong.

For each agent (in any order):

1. **Switch to main:** `git checkout main`

2. **Merge agent branch:** `git merge --no-ff wave{N}-agent-{ID} -m "Merge wave{N}-agent-{ID}: {description}"`
   - `--no-ff` preserves branch history for observability

3. **Handle conflicts:**
   - **Conflict on agent-owned files:** I1 violation (should not occur). Abort merge, enter BLOCKED.
   - **Conflict on IMPL doc completion reports:** Expected (E14). Resolve by accepting all appended sections. Each agent owns distinct named section.
   - **Conflict on orchestrator-owned append-only files (configs, registries):** Expected. Resolve by accepting all additions.

4. **Verify merge:** Check `git status` shows clean working tree

### Phase 3: Post-Merge Verification

**E10: Unscoped verification.** Orchestrator runs project-wide verification to catch cross-package cascade failures that no individual agent could see.

1. **Build:** Run project-wide build command (e.g., `go build ./...`)
   - If fails: Enter BLOCKED, surface error to human

2. **Lint:** Run project-wide lint command (e.g., `go vet ./...`)
   - If fails: Enter BLOCKED, surface error to human

3. **Tests:** Run project-wide test suite (e.g., `go test ./...`)
   - If fails: Enter BLOCKED, surface error to human

4. **Interface deviation propagation:** Check completion reports for `interface_deviations` with `downstream_action_required: true`
   - If found: Update affected downstream agent prompts in IMPL doc before next wave launches

5. **Out-of-scope dependency resolution:** Check completion reports for `out_of_scope_deps`
   - Orchestrator applies changes to orchestrator-owned files (append-only configs, registries)
   - Or defers to next wave if changes require new agent

### Phase 4: Worktree Cleanup

1. **Remove worktrees:** For each agent:
   ```
   git worktree remove .claude/worktrees/wave{N}-agent-{ID}
   ```

2. **Delete branches (optional):**
   ```
   git branch -d wave{N}-agent-{ID}
   ```
   - Keep branches if history preservation desired

3. **Remove pre-commit hook:** Delete `.git/hooks/pre-commit` (or restore original if existed)

### Phase 5: Transition

- If verification passes: Transition to WAVE_VERIFIED
- If verification fails: Transition to BLOCKED, await human resolution

---

## Procedure 5: Inter-Wave Checkpoint

**Entry state:** WAVE_VERIFIED
**Exit state:** WAVE_PENDING (next wave) or COMPLETE (no more waves)
**Executor:** Orchestrator

### Steps

1. **Check IMPL doc:** Determine if additional waves defined

2. **Human checkpoint (optional):**
   - If `--auto` mode active: Skip human checkpoint, proceed automatically
   - If manual mode: Surface wave completion to human, request approval to continue
   - Human may review completion reports, post-merge verification results

3. **Interface propagation:** If previous wave had interface deviations with `downstream_action_required: true`:
   - Update affected agent prompts in IMPL doc with revised contracts
   - Document changes in wave frontmatter

4. **Transition:**
   - If more waves exist: Transition to WAVE_PENDING (next wave)
   - If no more waves: Transition to COMPLETE

---

## Procedure 6: Protocol Completion

**Entry state:** WAVE_VERIFIED (final wave)
**Exit state:** COMPLETE (terminal)
**Executor:** Orchestrator

### Steps

1. **Final verification:** Confirm all waves verified, no outstanding blockers

2. **Cleanup:** Remove any remaining worktrees or temporary artifacts

3. **E15: Write completion marker.** Write `<!-- SAW:COMPLETE YYYY-MM-DD -->` (with the current ISO date) on the line immediately after the IMPL doc title (`# IMPL: ...`), then commit the update. This must be written before reporting completion to the user. If the marker is already present, do not overwrite it.

4. **E18: Update project memory.** Read `docs/CONTEXT.md` in the project root (create it if absent). Update the `features_completed` list with this feature slug and summary. Update `established_interfaces` if any new cross-cutting interfaces were defined. Update `architecture.description` and `architecture.modules` list if the feature introduced structural changes (see schema in `message-formats.md`). Update `decisions` with any key architectural choices made during this wave. Commit the updated `docs/CONTEXT.md`. See E18 in `execution-rules.md` and the schema in `message-formats.md` (## docs/CONTEXT.md — Project Memory section).

5. **Report to human:**
   - Protocol complete
   - Total time elapsed
   - Number of waves executed
   - Number of agents launched
   - Link to IMPL doc with all completion reports

6. **Transition:** Enter COMPLETE (terminal state)

---

## Error Recovery Procedures

### Recovery from BLOCKED State

**Cause:** Agent failure, verification failure, merge conflict, interface contract issue

**Steps:**

1. **Identify failure type:**
   - Read completion reports for `status: partial` or `status: blocked` (see `failure_type` field and E19 for automatic remediation decision tree)
   - Read verification output for build/lint/test failures
   - Check merge procedure output for git conflicts

2. **Correctable failures (E7a, --auto mode only):**
   - Isolation failure: Re-launch with absolute IMPL doc path
   - Missing dependency: Install, re-launch agent
   - Transient build error: Re-launch after delay
   - `failure_type: timeout`: Retry once with explicit instruction to commit partial work and prioritize essential work only; if retry also times out, escalate — scope may need reduction in the IMPL doc
   - Up to 2 automatic retries before surfacing to human

3. **Non-correctable failures (always surface to human):**
   - Interface contract unimplementable: Revise contracts, update prompts, restart wave
   - Logic errors: Agent must fix implementation
   - Test failures: Agent must fix tests or implementation
   - I1 violation (ownership conflict): Correct ownership table, recreate worktrees, restart wave

4. **Execute fix:** Re-run verification after fix applied

5. **Transition:** If verification passes, transition to WAVE_VERIFIED. If still failing, remain in BLOCKED.

### Recovery from Interface Contract Failure (E8)

**Cause:** Agent reports `status: blocked` due to unimplementable interface contract (see `failure_type` field and E19 for automatic remediation decision tree)

**Steps:**

1. **Read agent's completion report:** Identify which contract is problematic and why

2. **Revise interface contracts:** Edit IMPL doc to update affected interfaces in Field 2/Field 3 sections

3. **Identify affected agents:** Determine which agents in current and future waves depend on revised contract

4. **Update prompts:** Edit affected agents' prompts in IMPL doc with corrected contracts

5. **Restart wave:** Transition back to WAVE_PENDING
   - Agents that completed cleanly against unaffected contracts do not re-run
   - Only agents affected by contract revision re-run

### Recovery from Cross-Repository Mismatch

**Cause:** Layer 2 (`isolation: "worktree"`) was used in a cross-repo wave, creating worktrees in the wrong repository.

**Distinguish from intentional cross-repo waves:** An intentional cross-repo wave omits Layer 2 and pre-creates worktrees manually in each target repo. This failure mode occurs when Layer 2 was mistakenly applied.

**Steps:**

1. **Detect:** Field 0 isolation verification fails for agents — worktree paths resolve to the Orchestrator's repo, not the target repo.

2. **Do not retry with Layer 2.** Remove any incorrectly created worktrees from the Orchestrator's repo:
   ```bash
   git worktree remove .claude/worktrees/wave{N}-agent-{ID} --force
   git branch -D wave{N}-agent-{ID}
   ```

3. **Re-create worktrees manually** in the correct target repos following the Cross-Repo Mode procedure in `saw-worktree.md`.

4. **Re-launch agents** without `isolation: "worktree"` parameter.

---

**Reference:** See `state-machine.md` for state transitions and terminal conditions. See `message-formats.md` for completion report parsing and IMPL doc structure.
