# Scout-and-Wave Protocol Execution Rules

**Version:** 0.8.0

This document defines the execution rules that govern orchestrator behavior during Scout-and-Wave protocol execution. These rules are not captured by the state machine alone.

---

## Overview

Rules are numbered E1–E15 for cross-referencing and audit; the same convention as invariants (I1–I6). When referenced in implementation files, the E-number serves as an anchor; implementations should embed the canonical definition verbatim alongside the reference.

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

**Failure Handling:** If an overlap is found, the wave does not launch; the IMPL doc must be corrected first.

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
- **Cross-repository limitation:** When orchestrating repo B from repo A, such parameters may create worktrees in repo A's context (wrong). In cross-repository scenarios, omit this parameter and rely on Layer 1 (manual worktree creation in target repo) and Layer 3 (Field 0 navigation). Layer 2 may fail silently — do not rely on it alone even in same-repository scenarios.

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

## E5: Worktree Naming Convention

**Trigger:** Creating worktrees

**Required Action:** Worktrees must be named `.claude/worktrees/wave{N}-agent-{letter}` where `{N}` is the 1-based wave number and `{letter}` is the agent identifier (A, B, C...).

**Why This Is Not a Style Choice:** This is a canonical requirement. The naming scheme is the mechanism by which external tooling identifies SAW sessions and correlates agents to waves. Deviating from it breaks observability silently. Any tooling that consumes SAW session data must treat this naming scheme as the stable interface.

**Failure Handling:** Non-conforming worktree names prevent monitoring tools from detecting SAW sessions.

---

## E6: Agent Prompt Propagation

**Trigger:** Interface deviation propagation, contract revision, or same-wave interface failure

**Required Action:** When the orchestrator updates an agent prompt, it edits the prompt section in the IMPL doc directly. The agent reads its prompt from the IMPL doc at launch time, so the corrected version is always what runs.

**Rationale:** There is no separate prompt file to keep in sync. The IMPL doc is the single source of truth.

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

**Related Invariants:** See I1 (disjoint file ownership)

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

**Required Action:** Agents write to the IMPL doc exactly once: by appending their named completion report section at the end of the file under `### Agent {letter} - Completion Report`.

**Prohibition:** Agents must not edit any earlier section of the IMPL doc (interface contracts, file ownership table, suitability verdict, wave structure). Those sections are frozen at worktree creation (E2).

**Interface Deviations:** Any apparent need to update an earlier section is an interface deviation; it must be reported in the completion report and resolved by the Orchestrator, not edited in-place by the agent.

**Why This Matters:** This constraint is what makes IMPL doc git conflicts predictably resolvable: two agents appending distinct named sections always produce adjacent-section conflicts with no semantic overlap (E12).

**Related Invariants:** See I4 (IMPL doc is single source of truth) and I5 (agents commit before reporting)

**Related Rules:** See E12 (merge conflict taxonomy)

---

## E15: IMPL Doc Completion Marker

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE transition)

**Required Action:** The orchestrator writes `**Status:** COMPLETE` and `**Completed:** {ISO date}` to the IMPL doc header, then commits the update. This is the formal close of the IMPL lifecycle. The marker must be written before the orchestrator reports completion to the user.

**Constraint:** Only the orchestrator writes this marker. Agents never modify the Status field (E14 already prohibits agents from editing earlier sections). If Status is already COMPLETE, do not overwrite.

**Backward Compatibility:** IMPL docs without a `**Status:**` field are treated as ACTIVE. No migration is required.

**Related Rules:** See E14 (IMPL doc write discipline). See state-machine.md for the WAVE_VERIFIED → COMPLETE transition guard.

---

## Cross-References

- See `preconditions.md` for conditions that must hold before execution begins
- See `invariants.md` for runtime constraints that must hold during execution
- See `state-machine.md` and `message-formats.md` for state machine and message format specifications
