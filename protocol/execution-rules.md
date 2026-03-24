# Scout-and-Wave Protocol Execution Rules

**Version:** 0.20.0

This document defines the execution rules that govern orchestrator behavior during Scout-and-Wave protocol execution. These rules are not captured by the state machine alone.

---

## Overview

Rules are numbered E1–E42 for cross-referencing and audit; the same convention as invariants (I1–I6). When referenced in implementation files, the E-number serves as an anchor; implementations should embed the canonical definition verbatim alongside the reference.

To audit consistency, search implementation files for `E{N}` and verify the embedded definitions match this document.

---

## E1: Background Execution

**Trigger:** Launching any agent, polling CI, or running long-running watch commands

**Required Action:** All such operations must execute asynchronously without blocking the orchestrator's main execution thread.

**Why This Is Not a Performance Preference:** A blocking agent launch serializes the wave; the orchestrator waits for one agent before launching the next, eliminating parallelism. This is a protocol violation. Any implementation that blocks the orchestrator on agent execution or polling is non-conforming.

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

**Layer 2 — Task tool isolation:**
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

**Backward compatibility:** Branches created before v0.39.0 use the legacy format `wave{N}-agent-{ID}` without slug prefix. Tools accept both formats.

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

**Related Invariants:** See I1 (disjoint file ownership). For false positive handling, see E11a.

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

### Resumption Pipeline (--skip-merge)

When --skip-merge flag is used:
- Step 1: VerifyCommits - SKIP
- Step 2: ScanStubs - SKIP
- Step 3: RunPreMergeGates - SKIP
- Step 4: MergeAgents - SKIP (already merged manually)
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
sawtools detect-integration-gaps docs/IMPL/IMPL-{slug}.yaml --wave {N}
sawtools wire-integration docs/IMPL/IMPL-{slug}.yaml --wave {N} [--dry-run]
```

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

**Required Action:** The orchestrator writes `<!-- SAW:COMPLETE YYYY-MM-DD -->` (with the current ISO date) on the line immediately after the IMPL doc title, then commits the update. This is the formal close of the IMPL lifecycle. The marker must be written before the orchestrator reports completion to the user.

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

When validation fails, the orchestrator may automatically re-prompt the Scout with the validation errors (up to 3 retries). The correction loop:

1. Runs `sawtools validate --fix` on the IMPL doc to apply auto-correctable fixes (e.g., normalizing field names, fixing YAML indentation)
2. If errors remain after `--fix`, constructs a correction prompt listing each specific error with section name, failure description, and block identifier
3. Re-launches the Scout with the correction prompt prepended to its original context
4. Repeats up to 3 times (configurable via retry limit)
5. After 3 failures, sets state to `SCOUT_VALIDATION_FAILED` (enters BLOCKED)

The correction loop is implemented by `ScoutCorrectionLoop()` in the engine (`pkg/engine/` in scout-and-wave-go). The function reads validation errors from `sawtools validate`, formats them into a targeted correction prompt, and re-invokes the Scout agent with only the failing sections highlighted for revision.

**Key property:** The correction loop is idempotent — running it multiple times on an already-valid IMPL doc is a no-op (validation passes on first attempt, no Scout re-invocation).

**Related Rules:** See E16A (required block presence), E16B (dep graph grammar), E16C (out-of-band detection), E39 (Interview Mode — alternative requirements gathering pathway)

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

**Required Action:** The Orchestrator creates or updates `docs/CONTEXT.md` in the
target project:

1. If `docs/CONTEXT.md` does not exist, create it with the schema defined in
   `message-formats.md` (## docs/CONTEXT.md — Project Memory section).

2. Append to `features_completed`:
   ```yaml
   - slug: {feature-slug}
     impl_doc: docs/IMPL/IMPL-{feature-slug}.md
     waves: {N}
     agents: {N-agents}
     date: {YYYY-MM-DD}
   ```

3. Append any architectural decisions made during this feature to `decisions`.
   Decisions are identified from interface contracts and any `out_of_scope_deps`
   resolutions that reveal project conventions.

4. Append any new scaffold-file interfaces to `established_interfaces`. An
   interface is "established" if it was committed as a scaffold file and is now
   part of the project's public module boundary.

5. Commit: `git commit -m "chore: update docs/CONTEXT.md for {feature-slug}"`

**Constraint:** E18 runs after E15 (IMPL doc completion marker). The commit order
is: E15 writes `<!-- SAW:COMPLETE -->` to the IMPL doc, then E18 updates
`docs/CONTEXT.md`, then a single commit captures both.

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
2. Runs `bash ${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh {file1} {file2} ...` with that file list.
3. Appends the scan output to the IMPL doc under `## Stub Report — Wave {N}` (after the last completion report section for this wave).

Exit code of `scan-stubs.sh` is always 0 — stub detection is informational only. Stubs found are surfaced at the review checkpoint but do not block merge automatically.

**Note:** The script carries the comment `# scan-stubs.sh — SAW stub detection scanner (E20)` — E20 was reserved in the script header before this rule was written.

**Rationale:** An agent can write a syntactically correct function shell with a stub body (`pass`, `...`, `raise NotImplementedError`) and mark `[COMPLETE]`. The human reviewer approving the plan (not the diff) may not catch it. Stub detection surfaces hollow implementations before they ship.

**Related Rules:** See E21 (post-wave verification gates), `message-formats.md` (## Stub Report Section Format).

---

## E21: Automated Post-Wave Verification

**Trigger:** After all wave agents in a wave report complete and after E20 stub scan, before merge.

**Required Action:** If the IMPL doc contains a `## Quality Gates` section, the Orchestrator reads the configured gates and runs each command:

| Gate type   | Example command              |
|-------------|------------------------------|
| `typecheck` | `tsc --noEmit`, `mypy .`     |
| `test`      | `go test ./...`, `npm test`  |
| `lint`      | `go vet ./...`, `ruff check` |
| `custom`    | Any command in the IMPL doc  |

For each gate:
- `required: true` — non-zero exit code **blocks merge**. Report failure to user.
- `required: false` — non-zero exit code is a **warning only**. Log and continue.

**Flow levels** (set in `## Quality Gates` section):
- `quick` — skip all gates
- `standard` — run all gates; failures warn
- `full` — run all gates; required failures block merge

### Format Gate Fix Mode

Quality gates with `fix: true` in their configuration run in **fix mode** — they auto-apply formatting corrections (e.g., `gofmt -w`, `prettier --write`) rather than merely checking. Fix-mode gates:

1. Execute the fix command (e.g., `gofmt -w ./...`)
2. Stage any modified files (`git add` the formatted files)
3. Report the fix as a pass (exit code 0 after formatting)

Fix-mode gates run **before** check-only gates in the gate execution order. This ensures that formatting is applied before lint/test gates verify correctness.

**When to use fix mode:**
- Formatting tools with deterministic, safe auto-fix (gofmt, prettier, black)
- Import sorting tools (goimports, isort)

**When NOT to use fix mode:**
- Linters with opinionated auto-fix that may change logic (eslint --fix with non-style rules)
- Test commands (never fix mode)
- Build commands (never fix mode)

**Default:** `fix: false`. Gates are check-only unless explicitly configured with `fix: true`.

**Out of scope:** AI Verification Gate (an agent that reviews implementation correctness). Subprocess-based gates only.

**Rationale:** Individual agents run gates in isolation (their own package scope). The orchestrator's post-wave gate runs unscoped — catching cross-package cascade failures that agent-scoped gates miss.

**Related Rules:** See E20 (stub detection), E22 (scaffold build verification), `message-formats.md` (## Quality Gates Section Format). See also E21A (pre-wave baseline), E21B (parallel gate execution).

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

**Trigger:** Wave agents complete and merge succeeds

**Required Action:** Scan the merged result for unconnected exports using AST analysis. Produce an `IntegrationReport` with gaps classified by severity (`error`, `warning`, `info`).

**Non-fatal:** Integration gaps do not block the pipeline. They are reported to the orchestrator, which decides whether to launch an Integration Agent (E26) to wire gaps automatically.

**Process:**
1. The orchestrator calls `ValidateIntegration` on the merged codebase for the completed wave.
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
- The Integration Agent runs AFTER merge, on the main branch (no worktree)
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

4. **Proceed to wave execution.** After review approval, execute waves for all IMPLs in the tier. Pre-existing IMPLs with status "complete" skip wave execution entirely. Pre-existing IMPLs with status "reviewed" enter wave execution normally.

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
- Updates the agent's task field in the manifest with new content (read from stdin
  or --new-task flag)
- Clears any partial completion report for the agent (if status != "complete")
- Does NOT recreate the worktree (agent re-reads updated task on next launch)
- If agent HAS committed: operation is rejected with ErrAmendBlocked

### E36c: Extend Scope
`sawtools amend-impl <manifest> --extend-scope`
- Re-engages Scout with the current IMPL YAML injected as context
- Scout receives the full IMPL as a "current plan" and is instructed to append
  new waves only (not modify existing waves or contracts)
- Scout produces an updated IMPL doc with additional waves appended
- Human reviews before any new wave executes
- The extend-scope path is handled by the CLI/orchestrator layer (not amend.go);
  `--extend-scope` triggers a Scout agent launch, not a direct mutation

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
`--no-review` flag or `min_agents_for_review: 0` in saw.config.json.

**CLI orchestration note:** In CLI orchestration mode (inside a Claude Code session),
do NOT use `sawtools run-critic` — that command spawns a `claude` subprocess which
fails inside an active session. Use the Agent tool instead:
`Agent(subagent_type=critic-agent, run_in_background=true, description="[SAW:critic:<slug>]",
prompt="<absolute-impl-path>\n<repo-root>")`. The `sawtools run-critic` command is
only valid for programmatic/API orchestration outside of a Claude Code session.

**Required Action:** The orchestrator launches a critic agent with the IMPL doc and
all source files listed in file_ownership. The critic:
1. Reads the IMPL doc in full (all agent briefs, interface contracts, file ownership)
2. For each agent brief, reads every source file listed in that agent's file ownership
3. Verifies each brief against the actual codebase (see verification checks below)
4. Writes a structured CriticResult to the IMPL doc under critic_report field
5. Emits overall verdict: PASS or ISSUES

### Enforcement Point (Added in P5)

After critic writes verdict to IMPL doc, `prepare-wave` checks the verdict before creating worktrees:

- **Verdict: PASS** → proceed with worktree creation
- **Verdict: WARNING** → emit warning, proceed (orchestrator can override with --no-review)
- **Verdict: ISSUES** → exit code 1, block worktree creation

Error message format:
```
Error: E37 blocking: Critic found errors in agent briefs.
Fix via: sawtools amend-impl --redirect-agent <ID> --wave <N>
Agent IDs with errors: [C, D]
```

This ensures agents cannot launch with inaccurate briefs.

**Verification checks per agent brief:**
- file_existence: Every file marked action=modify must exist in the repo; every file
  marked action=new must NOT exist (would cause conflict)
- symbol_accuracy: Function names, type names, method signatures referenced in the
  brief must exist in the codebase as stated (for modify files) or must not conflict
  with existing symbols (for new files)
- pattern_accuracy: Implementation patterns described in the brief (e.g. "call X to
  register handler", "add field to struct Y") must match the actual patterns in the
  source files
- interface_consistency: Interface contracts specified in the IMPL must be
  syntactically valid for the target language and consistent with types referenced
  in source files
- import_chains: For new files, all packages referenced in interface contracts must
  be importable from the target module (exist in go.mod or local packages)
- side_effect_completeness: If a brief creates a new exported symbol that must be
  registered (CLI command in root.go, HTTP route in server.go, React component in
  a page), verify the registration file is also in the file_ownership table
- action_new_awareness: For files marked `action: new` in file_ownership, skip
  existence checks. The file WILL be created by the agent - flagging "file does
  not exist" is a false positive.

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
3. After corrections applied, orchestrator re-runs critic (via Agent tool in CLI orchestration; via `sawtools run-critic` in programmatic/API orchestration)
4. Repeat until verdict is PASS, then enter REVIEWED state normally

**Skip condition:** Pass `--no-review` to `sawtools run-scout` or set
`min_agents_for_review: 0` in saw.config.json to disable auto-triggering.
Manual skip: `sawtools run-critic --skip` writes a PASS result with
summary "Skipped by operator" to satisfy downstream state checks.

**Related rules:** E16 (schema validation precedes critic gate), E36 (amend
--redirect-agent is the recovery mechanism for agent-level brief corrections),
E2 (interface freeze: critic runs before freeze, so corrections are safe)

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

**Trigger:** Before worktree creation (during prepare-wave)

**Required Action:** Run `sawtools check-type-collisions <impl-doc>` to detect potential type name collisions across agents in the same wave. If two agents define the same type name in different files, the merge will fail with duplicate declarations.

**Implementation:** The `pkg/collision/` package in scout-and-wave-go provides AST-based detection. The check runs as a pre-flight step in prepare-wave alongside E3 ownership verification.

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
