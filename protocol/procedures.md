# Scout-and-Wave Procedures

**Version:** 0.21.0

> **See also:** `execution-rules.md` (v0.20.0) — numbered execution rules (E1–E45) referenced throughout these procedures.

This document defines the operational procedures executed by the Orchestrator and other participants: suitability assessment, scaffold materialization, wave execution, and merge operations.

---

## Overview

SAW procedures are executed by the Orchestrator (synchronous agent in the user's session) with cooperation from asynchronous agents (Scout, Scaffold Agent, Wave Agents, Integration Agent). The Orchestrator serializes all state transitions while asynchronous agents execute work in parallel.

**Participant roles:**
- **Orchestrator:** Drives all state transitions, launches agents, reads completion reports, executes merge procedure
- **Scout:** Analyzes codebase, produces IMPL doc, defines interface contracts
- **Critic Agent:** Reviews agent briefs against the actual codebase before REVIEWED state (E37)
- **Scaffold Agent:** Materializes approved interface contracts as type scaffold files
- **Wave Agents:** Implement features in parallel against frozen interface contracts
- **Integration Agent:** Wires new exports into caller code after wave merge (E26)
- **Planner:** Analyzes requirements and produces PROGRAM manifests at project scope

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

   **4a. Test file cascade detection (mandatory):** After mapping which symbols will change
   signature or be removed, Scout MUST search the entire repository — not just the
   package containing the change — for test files that reference those symbols.

   Algorithm:
   1. For each interface contract that changes an existing signature (parameter types,
      return types, method removal — not additive-only changes), identify the symbol name
      and the file where it is defined.
   2. Search the full repository for all callers of that symbol, including test files
      in other packages. A package-scoped search is insufficient — callers in sibling
      packages are the most commonly missed category.
   3. For each test file found that is NOT already in `file_ownership`:
      - Assign it to the same agent as the interface change (same wave), OR
      - Create a dedicated test-update agent in the same wave.
   4. Document the cascade in the agent task or pre-mortem. Test cascades not assigned
      to an agent will cause post-merge compilation failures that no individual agent
      could detect in isolation.

   **Skip condition:** Additive-only changes (new methods added, existing signatures
   unchanged) do not require cascade detection — existing callers continue to compile.

   **4b. Symbol rename cascade detection:** If any interface contract renames a type,
   function, or struct (not merely adds fields), Scout must classify all references:
   - **Syntax cascade (high):** Import statements, type declarations, function signatures,
     variable declarations — will cause compilation failure. Must be assigned to an agent.
   - **Semantic cascade (low):** Comments, string literals — does not affect compilation.
     Document but agent assignment is optional.

   **4c. Cross-wave migration safety:** When a feature consolidates, removes, or renames
   a module or package, naive wave assignment produces waves where the codebase does not
   compile between waves. Apply the following rules:

   - **Prefer single-wave consolidation:** If all callers of the old module fit within one
     wave (≤6 agents), place the signature changes and all caller updates in the same wave.
     This eliminates intermediate build breaks.
   - **Re-export bridge pattern (when callers span multiple waves):** Wave N changes the
     target package AND adds re-export bridges in the old package (type aliases, wrapper
     functions, or re-exports) that forward to the new signatures. Wave N+1 updates
     callers to import directly from the new package. Wave N+2 removes the bridges.
     The bridge keeps every wave buildable by preserving the old import path.
   - **Detection heuristic:** If file_ownership places files from the same
     package/directory in different waves, AND any agent changes exported signatures or
     type definitions in that package, flag as a potential migration boundary and apply
     one of the above rules.

5. **Interface contract definition:** Scout specifies exact signatures for all cross-agent interfaces
   - Function signatures with parameter types and return types
   - Type definitions (structs, interfaces, enums)
   - Import paths where contracts will be available
   - Contracts are binding — agents implement against them without seeing each other's code
   - If a signature cannot be determined before implementation starts, flag as a blocker;
     do not emit a speculative contract

6. **Scaffold specification:** If shared types needed within a wave, Scout writes Scaffolds section to IMPL doc
   - Four-column table: File | Contents | Import path | Status
   - Status starts as `pending`
   - Solo waves: omit Scaffolds section (one agent cannot conflict with itself)
   - **Shared same-package types are also scaffold triggers:** When two agents in the same
     wave work in the same package, each agent's worktree is isolated — Agent B cannot see
     Agent A's not-yet-merged types. If Agent A defines a type that Agent B references,
     declare it as a scaffold before worktrees are created. Do not assign a shared type to
     one agent and instruct the other to stub it — this produces duplicate declarations at
     merge time.

6a. **Integration completeness audit:** Before writing agent prompts, Scout verifies
   that every new artifact has its full wiring chain assigned. For each file in
   file_ownership, check whether it defines something that must be *registered* in
   another file:

   - New CLI commands → command registration file (e.g., `root.go`, `main.go`) must be
     in file_ownership, assigned to an agent or integration wave
   - New API handlers → route registration file must be assigned
   - New agent types → orchestrator configuration must be updated
   - New exported functions marked `integration_required` → caller file must be in an
     integration wave or `integration_connectors`

   If any wiring point is unassigned: add it to an agent's ownership, create an
   integration wave (`type: integration`), or add to `integration_connectors`.
   Unassigned wiring points are the leading cause of post-merge runtime failures where
   the codebase compiles but the feature is silently unreachable.

## Phase 0: Manual Merge Escape Hatch (E11a)

**When to use:** E11 blocks merge with false positive (identical edits)

**Trigger condition:** `sawtools finalize-wave` exits with E11 error but visual inspection confirms edits are identical

**Procedure:**
1. Verify E11 block is false positive (compare file hashes between branches)
2. Perform manual octopus merge: `git merge --no-ff {branches}`
3. Resume finalization: `sawtools finalize-wave --skip-merge`
4. Integration validation (E25/E26) runs automatically in step 5.5

**See also:** E11a in execution-rules.md for detailed steps

## Phase 1: Scout Phase

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

   **Text anchor requirement (mandatory for insertion instructions):** For every
   instruction in an agent task that describes inserting, adding, or modifying content
   at a specific location in an existing file (e.g., "insert after X", "add before Y",
   "modify the block at Z"), Scout MUST:
   1. Read the actual file before writing the agent brief.
   2. Extract the 3–5 lines of surrounding context at the insertion point.
   3. Embed that context verbatim in the task as the insertion anchor.

   **Do not use line numbers as anchors.** Line numbers drift whenever any other change
   is made to the file. Verbatim text context does not drift. Agents use exact string
   matching when applying edits — the anchor must be the exact string that will exist
   in the file at execution time.

   **Constraint derivation from pre-mortem (mandatory):** For each agent task, Scout
   must include explicit "do not" constraints derived from the pre-mortem scenarios for
   that agent. These are the top 2–3 most likely wrong actions. Make them visually
   distinct — buried constraints in prose are not followed. Example:
   ```
   Constraints:
   - Do NOT define FooType — it is owned by Agent B. If your branch fails to
     compile without it, declare it as a scaffold.
   - Do NOT modify files outside your ownership list.
   ```

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
**Skip condition:** If IMPL doc Scaffolds section empty OR all types already exist in the codebase (scaffold status: 'exists'), skip directly to WAVE_PENDING

### Steps

1. **Launch:** Orchestrator launches Scaffold Agent with absolute IMPL doc path after human approves IMPL doc

2. **Read contracts:** Scaffold Agent reads IMPL doc Scaffolds section
   - Each row specifies: File path, Contents (exact types/interfaces), Import path, Status
   - Scaffolds may include types from interface_contracts section AND shared data structures detected by E45 (shared data structure scaffold detection)

   **Shared data structures:** Scaffolds section may contain types that are not in interface_contracts but were detected by Scout because multiple agents reference them. Example: Agent A owns models.rs and defines PreviewData; Agent B's task says "import PreviewData from models". Scout detects this cross-agent reference and adds PreviewData to scaffolds even if it's not a function signature. Scaffold Agent treats these types identically to interface contract types — create the file, define the type, commit to HEAD.

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

0a. **Resume detection (pre-flight):** Before all other pre-flight steps, `prepare-wave` runs `resume.Detect` to identify orphaned worktrees from crashed or interrupted previous runs of any SAW session in this repo. If orphaned worktrees are found, a warning is emitted (step `resume_detection: warning`) but execution continues — this is distinct from the stale worktree cleanup in E4a, which removes worktrees for the current IMPL slug.

0. **Baseline verification (E21A):** For multi-agent waves with quality gates defined in the IMPL doc:
   - `prepare-wave` runs baseline gate verification automatically as part of its pre-flight checks. There is no standalone `--baseline` flag on `run-gates`; this step is internal to `prepare-wave`.
   - If all required gates pass (or no gates defined): proceed to Step 1.
   - If any required gate fails: Protocol stop. `prepare-wave` reports `baseline_verification_failed` with the failing gate commands and their output. Do not proceed. The human must fix the codebase or gate configuration before re-running `prepare-wave`.
   - E21A is a no-op for solo waves (Step 3 solo wave exception applies; skip this step if the wave has exactly one agent).

1. **Ownership verification (E3):** Orchestrator scans wave's file ownership table in IMPL doc
   - Check: No file appears in more than one agent's Field 1 (File Ownership) list
   - If overlap found: Protocol stop, surface error to human, correct IMPL doc before continuing

2. **Repository context check:** Determine whether this is a single-repo or cross-repo wave.

   **Single-repo wave:** Orchestrator and all agents work in the same repository. Use all five isolation layers (E4). Layer 2 (`isolation: "worktree"`) is available.

   **Cross-repo wave:** Agents work in two or more repositories simultaneously (e.g., engine extraction where Agent A works in `saw-engine/` and Agent B works in `saw-web/`). Cross-repo waves are supported with modified isolation procedure:
   - **Omit Layer 2** (`isolation: "worktree"` on the Agent tool) — it creates worktrees in the Orchestrator's repo, not the target repo. Omitting it is intentional, not a failure.
   - **Apply Layer 1 in each repo** — Orchestrator manually creates worktrees in every repo that agents touch before launching any agents (see Cross-Repo Mode details below).
   - **Layer 0 in each repo** — Install pre-commit guard in each repo's `.git/hooks/pre-commit`.
   - **Layer 3 applies unchanged** — Each agent's Field 0 navigates to its repo+worktree via absolute path.
   - **Layer 4 applies per-repo** — Merge-time trip wire runs independently in each repo.
   - The IMPL doc file ownership table must include a `Repo` column identifying which repository each file belongs to.

   **Cross-Repo Mode Details:**

   The single-repo procedure applies independently to each repository. Run every step (preflight, ownership verification, worktree creation, hook installation) in each repo before launching any agents.

   **IMPL doc convention:** File ownership table includes a `Repo` column:
   ```yaml
   file_ownership:
     - file: "pkg/engine/runner.go"
       agent: "A"
       wave: 1
       action: "new"
       repo: "saw-engine"
     - file: "pkg/api/adapter.go"
       agent: "B"
       wave: 1
       action: "modify"
       repo: "saw-web"
   ```

   **sawtools cross-repo support:** All sawtools commands accept `--repo-dir` parameter. Run once per repository:
   ```bash
   sawtools create-worktrees "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
   sawtools create-worktrees "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
   ```

   **Merge step:** Run merge procedure separately in each repo:
   ```bash
   sawtools merge-agents "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
   sawtools merge-agents "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
   ```

   Each repo's agent branches merge into that repo's main branch independently. There is no cross-repo merge operation.

   **Cleanup:** Run cleanup per repository:
   ```bash
   sawtools cleanup "<manifest-path>" --wave <N> --repo-dir "~/code/saw-engine"
   sawtools cleanup "<manifest-path>" --wave <N> --repo-dir "~/code/saw-web"
   ```

   **Key constraint:** Prefer agents that own files in exactly one repo. If an agent must own files in multiple repos, provide explicit absolute paths for each repo's worktree in Field 0. Keep cross-repo agent ownership minimal — single-repo agents have cleaner isolation boundaries.

3. **Repo match validation:** `prepare-wave` calls `ValidateRepoMatch` to verify the IMPL doc's declared repo (via `repo:` fields in `file_ownership` and `saw.config.json`) matches the working directory passed as `--repo-dir`. A mismatch (e.g., running prepare-wave for a saw-web IMPL while in the saw-engine directory) produces a blocking error with a message referencing `saw.config.json`.

4. **File existence validation:** `prepare-wave` calls `ValidateFileExistenceMultiRepo` to check that all `action: modify` files exist in their resolved repos. Missing files produce non-blocking warnings, with one exception: if ALL `action: modify` files are absent, `prepare-wave` emits `E16_REPO_MISMATCH_SUSPECTED` and exits with a blocking error — this pattern indicates the IMPL targets a different repository than the one being used.

### Phase 2: Worktree Creation

**Solo wave exception:** If wave contains exactly one agent, do NOT use `prepare-wave` — it always creates worktrees regardless of agent count. Instead, run:
```bash
sawtools prepare-agent "<manifest-path>" --wave <N> --agent <ID> --repo-dir "<repo-path>" --no-worktree
```
The agent runs on the main branch directly. `finalize-wave` auto-detects that no worktrees exist and skips VerifyCommits and MergeAgents automatically. Proceed to Phase 3.

1. **Create worktrees:** For each agent in multi-agent waves (2+ agents):
   ```
   git worktree add .claude/worktrees/saw/{slug}/wave{N}-agent-{ID} -b saw/{slug}/wave{N}-agent-{ID}
   ```
   - **E5: Naming convention:** `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}` is mandatory (observability requirement)
   - Branch name: `saw/{slug}/wave{N}-agent-{ID}` (matches worktree name)
   - All worktrees branch from current HEAD (includes committed scaffolds from Scaffold Agent)

2. **Install pre-commit hooks:** Two hooks are installed during wave setup:
   - **Isolation hook (Layer 0):** Installed per-worktree by `sawtools create-worktrees` (via `internal/git/commands.go`). Blocks commits to main/master unless `SAW_ALLOW_MAIN_COMMIT=1` is set. Orchestrator bypasses this for legitimate main commits.
   - **Quality gate hook (M4):** Installed to the project root by `prepare-wave` (via `sawtools install-hooks`). Runs `sawtools pre-commit-check` on every commit to enforce quality gates inline.
   - Note: The `pkg/orchestrator/` programmatic path installs a simplified isolation hook variant (`pkg/worktree/manager.go`) — the CLI path above is authoritative for `sawtools`-based orchestration.

### Phase 3: Agent Launch (E1: Background Execution)

1. **Launch agents in parallel:** For each agent in wave:
   - Orchestrator launches agent asynchronously (background execution, non-blocking)
   - Construct per-agent context payload (E23): extract from the IMPL doc the agent's 9-field section (Fields 0–8) + `## Interface Contracts` + `## File Ownership` table + `## Scaffolds` + `## Quality Gates` + absolute IMPL doc path. Pass assembled payload as the `prompt` parameter.
   - Agent receives extracted payload — does not read the full IMPL doc for instructions. Writes completion report to the provided IMPL doc path (I4, I5).
   - **E1 requirement:** All launches must be non-blocking. Blocking on one agent before launching the next eliminates parallelism (protocol violation).

2. **Monitor for completion:** Orchestrator monitors for completion notifications
   - Agent completion = completion report written to IMPL doc
   - Orchestrator polls asynchronously (does not block on individual agents)

### Phase 4: Agent Execution (Agent Responsibilities)

**Each agent independently:**

1. **Field 0: Isolation verification (mandatory pre-flight):**
   - **E43 hook-based enforcement:** For Claude Code implementations, lifecycle hooks automatically inject environment variables (SAW_AGENT_WORKTREE, SAW_AGENT_ID, SAW_WAVE_NUMBER, SAW_IMPL_PATH, SAW_BRANCH), prepend cd commands to bash calls, and block out-of-bounds writes. Agents still verify isolation, but violations are now prevented mechanically rather than detected after-the-fact.
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

   **Call site discovery before modifying exports (mandatory):** Before modifying any
   exported or public symbol (function, type, method, constant), the agent must discover
   all call sites across the full repository — not just owned files. This prevents
   missing callers outside the agent's ownership scope. Any caller found outside owned
   files must be reported in the completion report as `out_of_scope_deps` for the
   Integration Agent (E26) to wire after merge.

   **Parallel wave compilation isolation:** Agents in the same wave compile against
   HEAD plus committed scaffolds — not against each other's unmerged work. If
   compilation fails solely because a different agent's owned files contain unreleased
   signature changes, the agent MUST commit the current state anyway. This is an
   expected consequence of parallel isolation, not an error condition. The post-merge
   verification step (E10) catches cross-agent compilation issues after merge.

   **Conditions for bypassing pre-commit build checks in parallel isolation:**
   An agent may bypass the pre-commit build gate (without affecting correctness) only
   when ALL THREE of the following hold:
   1. The failing check concerns a type, import, or symbol that will be satisfied
      post-merge when a peer agent's branch is merged (not a bug in the agent's own code)
   2. The agent's own implementation is correct and complete for its owned files
   3. The agent's worktree branch remains intact and will be included in the wave merge

   Bypassing is not permitted when the agent's own code is incorrect, when the failure
   indicates a missing interface contract, or when the agent is uncertain which condition
   is causing the failure.

3. **Verification gate (Field 6):** Agent runs exact scoped commands
   - Build (compile)
   - Lint
   - Tests (scoped to owned packages)
   - **E10: Scoped verification:** Agents run focused verification. Orchestrator runs unscoped post-merge verification to catch cascade failures.

4. **Commit (I5):** Agent commits changes to worktree branch before reporting
   - Commit after completing each file, not in a single batch at the end
   - Record commit SHA
   - Final commit before completion report must include all remaining changes

5. **Completion report (E14):** Agent appends structured completion report to IMPL doc
   - Append under `### Agent {ID} - Completion Report` at end of file
   - Never edit earlier IMPL doc sections (ownership table, interface contracts, wave structure)
   - Write discipline makes IMPL doc conflicts predictably resolvable

   **BUILD STUB vs COMPLETE (mandatory distinction):** An agent must not report
   `status: complete` for stub implementations. The distinction:
   - **COMPLETE:** Fully implemented. All specified tests pass. Verification gate passes
     without bypass.
   - **BUILD STUB:** Compiles and passes compilation gates, but function bodies
     panic, return zero values, or are otherwise unimplemented. Tests for stub
     functionality are expected to fail. Report `status: partial` with a stub inventory
     listing each stubbed symbol and its file location.
   Reporting `status: complete` for a stub causes finalize-wave to proceed on a false
   baseline, silently shipping unimplemented behavior.

### Phase 5: Completion Collection

1. **Wait for all agents:** Orchestrator waits until all agents in wave have written completion reports

2. **Read completion reports:** Orchestrator parses structured YAML blocks from IMPL doc

3. **Check for failures:**
   - Any agent `status: partial` → enter BLOCKED (see `failure_type` field and E19 for automatic remediation decision tree)
   - Any agent `status: blocked` → enter BLOCKED (see `failure_type` field and E19 for automatic remediation decision tree)
   - Any agent isolation verification failed → enter BLOCKED
   - All agents `status: complete` → proceed to steps 4–5

4. **E20: Stub detection.** After all agents complete:
   - **Note:** Agents claiming `status: complete` have already passed the SubagentStop stub consistency check — any remaining stubs in their files were caught at agent exit time.
   - Collect union of all `files_changed` and `files_created` from completion reports
   - Run `sawtools scan-stubs --append-impl "<manifest-path>" --wave {N}` (exit code is always 0 — informational only)
   - **Note:** `finalize-wave` runs this automatically as step 2; no manual invocation needed when using `finalize-wave`
   - Surface stubs at the review checkpoint (includes stubs from `partial` agents that were not required to clear them)

5. **E21: Quality gates.** If IMPL doc contains a `## Quality Gates` section:
   - Run all gates with `required: true`
   - Required gate failures → enter BLOCKED
   - Optional gate failures → warn only; do not block merge

6. **E25: Validate integration (pre-merge).** After quality gates pass and before merge, scan for unconnected exports:
   - `finalize-wave` runs `StepValidateIntegration()` automatically at step 3.5a (after gates, before merge). This produces an `IntegrationReport`.
   - If `report.Valid == true`: No integration gaps detected, proceed to merge
   - If `report.Valid == false`: Integration gaps detected. `finalize-wave` reports the gaps in its JSON output but does not automatically launch an Integration Agent.

7. **E26: Integration Agent (if gaps detected).** If E25 reports gaps:
   - In programmatic/engine flows (`RunWaveFull`): the engine automatically launches an Integration Agent post-merge.
   - In CLI orchestration (`finalize-wave` direct use): the Orchestrator must manually launch an Integration Agent after merge, constraining it to files listed in `integration_connectors`.
   - On success: proceed; on failure: enter BLOCKED

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
   - `git log main..saw/{slug}/wave{N}-agent-{ID} --oneline`
   - Empty branch = isolation failure (agent committed to main instead of worktree)
   - Layer 4 trip wire: catches isolation failures regardless of cause

### Phase 2: Per-Agent Merge

**Automated merge via `finalize-wave`:** The merge phase is handled by `sawtools finalize-wave <manifest> --wave N --repo-dir <path>`. For program-mode IMPL branch isolation (E28B), pass `--merge-target <branch>` to merge agent branches into the IMPL branch rather than main. Manual invocation of the individual git commands below is only needed when `finalize-wave` is unavailable or when the octopus merge fallback (Phase 0 above) is in use.

**E11: Merge order is arbitrary within a valid wave.** Same-wave agents are independent by construction. If merge order appears to matter, wave structure is wrong.

For each agent (in any order):

1. **Switch to main:** `git checkout main`

2. **Merge agent branch:** `git merge --no-ff saw/{slug}/wave{N}-agent-{ID} -m "Merge saw/{slug}/wave{N}-agent-{ID}: {description}"`
   - `--no-ff` preserves branch history for observability

3. **Handle conflicts:**
   - **Conflict on agent-owned files:** I1 violation (should not occur). Abort merge, enter BLOCKED.
   - **Conflict on IMPL doc completion reports:** Expected (E14). Resolve by accepting all appended sections. Each agent owns distinct named section.
   - **Conflict on orchestrator-owned append-only files (configs, registries):** Expected. Resolve by accepting all additions.

4. **Verify merge:** Check `git status` shows clean working tree

### Phase 2.5: Integration Checklist Population (M5)

After merge and before post-merge verification, `finalize-wave` automatically runs `protocol.PopulateIntegrationChecklist()` (step 4.5). This scans `file_ownership` for integration-requiring patterns (new API handlers, React components, CLI commands) and writes integration tasks to the manifest's `post_merge_checklist` field.

- **Non-blocking:** Errors are logged to stderr but do not fail finalization
- **Idempotent:** Appends new groups if `post_merge_checklist` already has items
- **Manual invocation not needed:** This runs inside `finalize-wave` automatically

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

Use `sawtools cleanup` — three modes available:

```bash
# Manifest-based (standard post-wave):
sawtools cleanup "<manifest-path>" --wave <N> --repo-dir "<repo-path>"

# Slug-based (no manifest required):
sawtools cleanup --slug <slug> --repo-dir "<repo-path>"

# All stale across all slugs (recovery / maintenance):
sawtools cleanup --all-stale --repo-dir "<repo-path>"
```

Add `--force` to skip safety checks for uncommitted changes. `finalize-wave` runs manifest-based cleanup automatically as its final step — manual invocation is only needed for recovery scenarios.

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

3. **E15: Mark complete.** Run:
   ```bash
   sawtools mark-complete "<manifest-path>" --date "YYYY-MM-DD"
   ```
   This writes the `<!-- SAW:COMPLETE YYYY-MM-DD -->` marker, archives the manifest to `docs/IMPL/complete/`, and auto-cleans stale worktrees. It does NOT commit. If the marker is already present, do not re-run. Commit the archived file together with the E18 CONTEXT.md update in the next step.

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

3. **Re-create worktrees manually** in the correct target repos following the Cross-Repo Mode procedure documented above (Procedure 2, Phase 1, Cross-Repo Mode Details).

4. **Re-launch agents** without `isolation: "worktree"` parameter.

---

**Reference:** See `state-machine.md` for state transitions and terminal conditions. See `message-formats.md` for completion report parsing and IMPL doc structure.
