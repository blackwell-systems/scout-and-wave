# Scout-and-Wave Protocol Invariants

**Version:** 0.26.0

This document defines the invariants that must hold throughout the entire Scout-and-Wave protocol execution. Violations break the correctness guarantees.

---

## Overview

Invariants are identified by number (I1–I6). When referenced in implementation files, the I-number serves as an anchor for cross-referencing and audit; implementations should embed the canonical definition verbatim alongside the reference so each document remains self-contained without requiring a lookup.

To audit consistency, search implementation files for `I{N}` and verify the embedded definitions match this document.

---

## I1: Disjoint File Ownership

**Formal Statement:** No two agents in the same wave own the same file.

**Enforcement:** This is a hard constraint, not a preference. It is the mechanism that makes parallel execution safe. Worktree isolation does not substitute for it.

**Scope:** A single agent modifying files outside its declared ownership scope is distinct from an I1 violation. A single agent cannot conflict with itself. Such out-of-scope changes must be justified, documented in the completion report, and verified by the post-merge gate.

**Cross-repo scope:** In cross-repo waves, I1 applies per-repository. Files in different repositories are inherently disjoint — no two agents can conflict on a file that exists in only one repo's filesystem. The disjoint ownership constraint still applies within each repository: no two agents in the same wave may own the same file path within the same repository.

**Related Rules:** See E3 (pre-launch ownership verification), E11 (conflict prediction before merge), E42 (post-completion I1 ownership verification at SubagentStop time), and E43 (hook-based isolation enforcement prevents violations at tool boundary)

### I1 Enforcement Layers (Defense-in-Depth)

I1 is protected by multiple enforcement layers that work together to prevent, detect, and audit ownership violations:

- **Layer 0 (E43 hooks):** PreToolUse validation blocks writes outside worktree boundaries at the tool invocation boundary. This is the **primary enforcement mechanism** in Claude Code orchestration. The `validate_write_paths` hook (E43) prevents violations before they occur by blocking relative paths and out-of-bounds writes with exit code 2. Other platforms must implement equivalent tool-boundary enforcement or rely on Layer 3 (Field 0 self-verification).
- **Layer 1 (E3 validation):** Pre-launch ownership table validation. The orchestrator validates the `file_ownership` table for disjoint ownership before creating worktrees, catching Scout planning errors early.
- **Layer 2 (E11 conflict prediction):** Pre-merge `files_changed` intersection check. Before any merge proceeds, the orchestrator cross-references all agents' `files_changed` and `files_created` lists to detect runtime deviations where an agent touched files outside its declared scope.
- **Layer 3 (E42 SubagentStop):** Post-completion ownership audit. The SubagentStop hook runs `git diff --name-only` in the worktree and compares changed files against the agent's ownership list from `.saw-ownership.json`. Any unowned modified file triggers exit 2 with an I1 violation message.

**Result:** I1 violations are structurally prevented (Layer 0), validated at planning time (Layer 1), detected at merge time (Layer 2), and audited at completion time (Layer 3). All layers remain active; E43 does not replace the others.

### I1 Amendment: Integration Agent Exemption

The Integration Agent (E26) is exempt from I1's disjoint ownership constraint because it runs after all wave agents complete and after merge. It operates on the merged main branch, not a worktree. Its writes are restricted to `integration_connectors` files via the `integrator` constraint role (`AllowedPathPrefixes` enforcement).

This is not an I1 violation because there is no concurrent execution — the Integration Agent is the only writer at the time it runs. The disjoint ownership invariant exists to prevent concurrent conflicting writes; when only a single agent is active and all wave agents have already committed and merged, the concurrency hazard that I1 guards against does not exist.

**Constraint enforcement:** The `integrator` role restricts the Integration Agent to files explicitly listed in the IMPL manifest's `integration_connectors` field. It cannot write to agent-owned files, scaffold files, or any file outside the connector list. This is enforced mechanically via `AllowedPathPrefixes`, not by agent cooperation.

**Related Rules:** See E25 (Integration Validation), E26 (Integration Agent)

### I1 Amendment: Post-Hoc Undeclared-Modification Detection

The engine cross-references completion report `files_changed` and `files_created` fields against the declared `file_ownership` table after each wave completes. Files modified by an agent outside its declared ownership are flagged as I1 violations even if no other agent owns that file — the constraint covers declared accountability, not only concurrent conflict avoidance.

This detection runs at wave finalization via `protocol.DetectOwnershipConflicts()` and surfaces in the `finalize-wave` output.

**Related Rules:** See E7 (agent failure handling), E42 (SubagentStop ownership verification)

### I1 Amendment: Identical-Edit Allowance at Merge Time

At merge time, if two agents have modified the same file and the resulting content is byte-identical (verified via SHA256 hash comparison in `conflict_predict.go`), the conflict is treated as non-blocking. This is a pragmatic allowance: formatting changes or comments applied consistently by multiple agents produce no functional conflict and would otherwise require manual merge resolution.

This allowance applies only at merge time. The declared ownership table must still be disjoint — no two agents may declare ownership of the same file in the IMPL doc. Identical-edit allowance is a safety valve for accidental identical edits, not a license for shared ownership.

---

## I2: Interface Contracts Precede Parallel Implementation

**Formal Statement:** The Scout defines all interfaces that cross agent boundaries in the IMPL doc. This includes function signatures, method contracts, AND shared data structures (structs, enums, type aliases, traits) referenced by 2+ agents. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches. Agents implement against the spec; they never coordinate directly.

**Enforcement:** The orchestrator verifies all scaffold files show `committed` status before creating worktrees. Interface contracts are frozen when worktrees are created (see E2).

**Mechanism:**
- Scout discovers and specifies interfaces in IMPL doc Scaffolds section
- Human reviews and approves interface contracts
- Scaffold Agent materializes scaffold files and commits to HEAD
- Wave Agents branch from HEAD and import from committed scaffold files
- Agents implement against scaffold files without seeing each other's code

**Shared Data Structure Detection:** Scout detects types that multiple agents reference by scanning agent task prompts for import statements, type references, and data structure definitions. When Agent B imports a type from a file in Agent A's ownership, Scout creates a scaffold for that type to prevent duplicate definitions and I1 violations.

Detection applies to:
- Structs/classes defined in one agent's file and imported by another
- Enums/sum types used across agent boundaries
- Type aliases shared between agents
- Traits/interfaces implemented or consumed by multiple agents

Does NOT apply to:
- Types from external dependencies (stdlib, third-party packages)
- Types in existing codebase files not owned by any agent
- Types mentioned in only one agent's task (no cross-agent dependency)

**Freeze Enforcement:** `PrepareWave` records a `worktrees_created_at` timestamp and computes JSON hashes of `interface_contracts` and `scaffolds` when worktrees are first created. On subsequent calls (re-entrant resume), `CheckFreeze()` (`pkg/protocol/freeze.go`) recomputes those hashes and compares them. Any modification to interface contracts or scaffold entries after the freeze timestamp is a blocking violation — the wave cannot re-enter preparation with modified contracts.

**Related Rules:** See E2 (interface freeze), E8 (same-wave interface failure handling), and E45 (shared data structure scaffold detection)

---

## I3: Wave Sequencing

**Formal Statement:** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed.

**Enforcement:** The orchestrator controls state transitions. Waves execute sequentially. When Wave N completes, its implementations are committed to HEAD. Wave N+1 agents branch from that commit and import from the committed codebase directly.

**Engine enforcement:** `PrepareWave` enforces I3 at the execution layer: when `WaveNum > 1`, it verifies that all agents in wave `WaveNum - 1` have completion reports with `status: complete` before creating any worktrees. This prevents Wave N from launching if Wave N-1 is still executing, has blocked or partial agents, or has not been finalized. The check surfaces as a blocking `wave_sequencing` step failure with a message identifying the specific agent and its current status.

**Cross-Wave Coordination:** Waves execute sequentially. This provides coordination without special mechanisms: later waves always have access to earlier waves' committed work. Scaffold files solve the intra-wave problem (parallel agents that cannot see each other's code); cross-wave coordination is ordinary software development.

**Related Rules:** See [state-machine.md](state-machine.md) for state transitions

---

## I4: IMPL Doc is the Single Source of Truth

**Formal Statement:** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record.

**Enforcement:** See E14 for the write discipline that keeps IMPL doc conflicts predictably resolvable.

**Rationale:** The IMPL doc is a git-tracked file visible to all agents across waves. Chat output exists only in one agent's session and cannot be read by the orchestrator or other agents. Completion reports written to chat only are protocol violations.

**IMPL Doc and Journal Duality:** The tool journal (E23A) complements the IMPL doc without violating I4's single-source-of-truth constraint:

- **IMPL doc** = source of truth for *planning*: What work should be done (agent prompts, interface contracts, file ownership, wave structure, quality gates)
- **Tool journal** = source of truth for *execution history*: What work has been done (tools called, files modified, commands executed, tests run, commits made)
- **Completion reports** = synthesis of both: Agents read their task from the IMPL doc, execute it (recorded in journal), then write results back to the IMPL doc referencing work captured in the journal

The journal is agent-private working memory. It is not distributed to other agents. Only the completion report (written to the IMPL doc) becomes visible cross-agent. The IMPL doc remains the coordination point; the journal is the execution trace that enables agent recovery and context reconstruction across sessions.

E42 enforces I4 at agent completion time by verifying that completion reports exist in the IMPL doc before the agent session closes. This catches agents that "complete" without writing their completion report — a violation that would otherwise only be detected at wave finalization.

**Related Rules:** See E14 (IMPL doc write discipline), E23A (tool journal recovery), E42 (SubagentStop validation)

---

## I5: Agents Commit Before Reporting

**Formal Statement:** Each agent commits its changes to its worktree branch before writing a completion report. Uncommitted state at report time is a protocol deviation and must be noted in the report.

**Enforcement:** Completion report format includes `commit: {sha}` field. Value of `"uncommitted"` flags a protocol violation.

**Rationale:** The orchestrator merges from agent branch commits. If work is uncommitted, the merge step cannot proceed without manual intervention.

E42 performs post-hoc I5 commit verification at SubagentStop time, checking that the agent's worktree branch has at least one commit ahead of the merge base before the agent session closes. E43's `verify_worktree_compliance` SubagentStop hook enforces I5 at the tool boundary, creating an audit trail for post-hoc violation analysis.

**Cross-repo agents:** Agents working in a different repository from the orchestrator may commit directly to that repo's default branch without creating a worktree branch. For these agents, the `commit` field in the completion report serves as I5 proof. `VerifyCommits()` detects this scenario via the completion report's `repo` field and validates the commit SHA is reachable in that repository. This handles cases like documentation agents that commit to a protocol repo while the orchestrator runs in an implementation repo.

**Related Rules:** See E4 (worktree isolation), E43 (hook-based isolation enforcement), completion report format in [message-formats.md](message-formats.md), and E42 (SubagentStop I5 commit verification)

---

## I6: Role Separation

**Formal Statement:** The Orchestrator does not perform Scout, Scaffold Agent, Wave Agent, or Integration Agent duties. Codebase analysis, IMPL doc production, scaffold file creation, source code implementation, and post-merge wiring are delegated to the appropriate asynchronous agent.

**Enforcement:** If the Orchestrator finds itself doing any of these, it has violated the protocol; it must stop and launch the correct agent.

**Why This Is Not a Style Preference:**
- An Orchestrator performing Scout work bypasses async execution
- Pollutes the orchestrator's context window
- Breaks observability (no Scout agent means no SAW session is detectable by monitoring tools)
- Violates the architectural separation between synchronous coordination and asynchronous work

**Scope:** The solo wave agent must still operate in the Wave Agent role: launched by the Orchestrator as an asynchronous agent, not executed directly by the Orchestrator. Executing solo wave work inline violates I6 regardless of wave size. The absence of worktrees changes the isolation mechanism; it does not change the participant roles.

**Enforcement limitation:** I6 is enforced via orchestrator prompt instructions (saw-skill.md line 66) and agent type restrictions (custom `subagent_type` values like `scout`, `wave-agent`, `integration-agent`), not via SDK validators or lifecycle hooks. The orchestrator must self-detect I6 violations by recognizing when it's performing work that should be delegated to an async agent. Unlike I1-I5, which have mechanical enforcement through validators (I1, I2, I3), hooks (I1, I5), and commit checks (I5), I6 relies on orchestrator discipline.

**Future enforcement:** A PreToolUse hook could block the orchestrator's agent session from using Write/Edit tools on files listed in any IMPL doc's `file_ownership` table, providing mechanical I6 enforcement equivalent to I1's E43 hooks.

**Related Rules:** See [participants.md](participants.md)

---

## P5: IMPL Branch Isolation

**Formal Statement:** Within a program tier, each IMPL's wave merges target the IMPL's dedicated branch, not main. Main is only updated by `FinalizeTier` after all IMPLs in the tier complete and the tier gate passes.

**Enforcement:** The Orchestrator creates a long-lived IMPL branch using `ProgramBranchName()` before executing waves for each IMPL. The `MergeTarget` field is threaded through `RunWaveFull`, `FinalizeWave`, and `MergeAgents` to ensure all agent branch merges land on the IMPL branch. `FinalizeTier` is the sole operation that merges IMPL branches to main.

**Rationale:** Without branch isolation, a wave merge from IMPL-A could land on main while IMPL-B's waves are still in progress. IMPL-B's next wave would then branch from a main that contains IMPL-A's partial work, creating implicit coupling between supposedly independent IMPLs. This violates P1 (intra-tier independence) in practice even when file ownership is disjoint, because build state, test state, and transitive dependencies can leak across IMPL boundaries.

Branch isolation ensures that each IMPL develops against a stable baseline (its own branch forked from main at the start of the tier) and that main only advances when the full tier is verified.

**Backward Compatibility:** When `MergeTarget` is empty (the default for non-program execution), waves merge to the current HEAD as before. P5 only applies when the Orchestrator is executing within a program tier context.

**Related Rules:** See E28B (IMPL Branch Isolation) in `execution-rules.md`, E29 (Tier Gate Verification), P1 (intra-tier independence) in `program-invariants.md`

---

## Protocol Violations

Conditions that break invariants and invalidate the correctness guarantees:

| Violation | Broken Invariant | Effect |
|-----------|-----------------|--------|
| Two agents modify the same file | I1 | Merge conflict, undefined output |
| Agent calls undefined interface | I2 | Interface drift, integration failure |
| Wave N+1 launched before Wave N verified | I3 | Cascade failures surface at end |
| Completion report written to chat only | I4 | Downstream agents get stale context |
| Agent reports complete with uncommitted changes | I5 | Merge requires manual copy |
| Orchestrator performs Scout, Scaffold Agent, Wave Agent, or Integration Agent duties | I6 | Context pollution, broken observability, async execution bypassed |
| IMPL wave merged to main during tier execution | P5 | Other IMPLs see partial state, potential breakage |

---

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:

- No two agents in the same wave will produce conflicting changes
- Direct coordination drift is prevented; deviations from interface contracts must be declared in completion reports and are surfaced at wave boundaries
- Integration failures surface at wave boundaries, not at the end of all waves
- Downstream agents always receive accurate context (IMPL doc reflects actual state)
- The orchestrator can detect disjoint ownership violations before touching the working tree
- No IMPL's in-progress wave merge can break another IMPL's work within the same tier

---

## Cross-References

- See `preconditions.md` for conditions that must hold before execution begins
- See `execution-rules.md` for orchestrator behavior rules that enforce these invariants
- See `state-machine.md` and `message-formats.md` for state machine and message format specifications
