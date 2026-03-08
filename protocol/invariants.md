# Scout-and-Wave Protocol Invariants

**Version:** 0.9.0

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

**Related Rules:** See E3 (pre-launch ownership verification) and E11 (conflict prediction before merge)

---

## I2: Interface Contracts Precede Parallel Implementation

**Formal Statement:** The Scout defines all interfaces that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches. Agents implement against the spec; they never coordinate directly.

**Enforcement:** The orchestrator verifies all scaffold files show `committed` status before creating worktrees. Interface contracts are frozen when worktrees are created (see E2).

**Mechanism:**
- Scout discovers and specifies interfaces in IMPL doc Scaffolds section
- Human reviews and approves interface contracts
- Scaffold Agent materializes scaffold files and commits to HEAD
- Wave Agents branch from HEAD and import from committed scaffold files
- Agents implement against scaffold files without seeing each other's code

**Related Rules:** See E2 (interface freeze) and E8 (same-wave interface failure handling)

---

## I3: Wave Sequencing

**Formal Statement:** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed.

**Enforcement:** The orchestrator controls state transitions. Waves execute sequentially. When Wave N completes, its implementations are committed to HEAD. Wave N+1 agents branch from that commit and import from the committed codebase directly.

**Cross-Wave Coordination:** Waves execute sequentially. This provides coordination without special mechanisms: later waves always have access to earlier waves' committed work. Scaffold files solve the intra-wave problem (parallel agents that cannot see each other's code); cross-wave coordination is ordinary software development.

**Related Rules:** See [state-machine.md](state-machine.md) for state transitions

---

## I4: IMPL Doc is the Single Source of Truth

**Formal Statement:** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record.

**Enforcement:** See E14 for the write discipline that keeps IMPL doc conflicts predictably resolvable.

**Rationale:** The IMPL doc is a git-tracked file visible to all agents across waves. Chat output exists only in one agent's session and cannot be read by the orchestrator or other agents. Completion reports written to chat only are protocol violations.

**Related Rules:** See E14 (IMPL doc write discipline)

---

## I5: Agents Commit Before Reporting

**Formal Statement:** Each agent commits its changes to its worktree branch before writing a completion report. Uncommitted state at report time is a protocol deviation and must be noted in the report.

**Enforcement:** Completion report format includes `commit: {sha}` field. Value of `"uncommitted"` flags a protocol violation.

**Rationale:** The orchestrator merges from agent branch commits. If work is uncommitted, the merge step cannot proceed without manual intervention.

**Related Rules:** See E4 (worktree isolation) and completion report format in [message-formats.md](message-formats.md)

---

## I6: Role Separation

**Formal Statement:** The Orchestrator does not perform Scout, Scaffold Agent, or Wave Agent duties. Codebase analysis, IMPL doc production, scaffold file creation, and source code implementation are delegated to the appropriate asynchronous agent.

**Enforcement:** If the Orchestrator finds itself doing any of these, it has violated the protocol; it must stop and launch the correct agent.

**Why This Is Not a Style Preference:**
- An Orchestrator performing Scout work bypasses async execution
- Pollutes the orchestrator's context window
- Breaks observability (no Scout agent means no SAW session is detectable by monitoring tools)
- Violates the architectural separation between synchronous coordination and asynchronous work

**Scope:** The solo wave agent must still operate in the Wave Agent role: launched by the Orchestrator as an asynchronous agent, not executed directly by the Orchestrator. Executing solo wave work inline violates I6 regardless of wave size. The absence of worktrees changes the isolation mechanism; it does not change the participant roles.

**Related Rules:** See [participants.md](participants.md)

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
| Orchestrator performs Scout, Scaffold Agent, or Wave Agent duties | I6 | Context pollution, broken observability, async execution bypassed |

---

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:

- No two agents in the same wave will produce conflicting changes
- Direct coordination drift is prevented; deviations from interface contracts must be declared in completion reports and are surfaced at wave boundaries
- Integration failures surface at wave boundaries, not at the end of all waves
- Downstream agents always receive accurate context (IMPL doc reflects actual state)
- The orchestrator can detect disjoint ownership violations before touching the working tree

---

## Cross-References

- See `preconditions.md` for conditions that must hold before execution begins
- See `execution-rules.md` for orchestrator behavior rules that enforce these invariants
- See `state-machine.md` and `message-formats.md` for state machine and message format specifications
