# Scout-and-Wave Protocol Specification

**Version:** 0.8.0
**Status:** Active

Scout-and-Wave (SAW) is a protocol for safely parallelizing human-guided agentic workflows. It defines preconditions, invariants, participant roles, state transitions, and message formats that guarantee agents can work concurrently without conflicts. Human review checkpoints are structural: the protocol does not advance past the suitability gate or between waves without human approval.

This document provides a high-level protocol overview. Detailed specifications are in the `protocol/` directory.

---

## Navigation

**Core Specifications:**
- [Participants](protocol/participants.md) — Four agent roles and their responsibilities
- [Invariants](protocol/invariants.md) — I1–I6: Runtime constraints that must hold during execution
- [Execution Rules](protocol/execution-rules.md) — E1–E14: Orchestrator behavior rules
- [State Machine](protocol/state-machine.md) — Protocol states, transitions, and terminal conditions
- [Message Formats](protocol/message-formats.md) — Suitability verdicts, agent prompts, completion reports

**Additional Documentation:**
- [Preconditions](protocol/preconditions.md) — Five conditions that must hold before execution begins

---

## Quick Reference

### Invariants (I1–I6)

| ID | Name | Enforcement |
|----|------|------------|
| **I1** | Disjoint File Ownership | No two agents in same wave own the same file |
| **I2** | Interface Contracts Precede Parallel Implementation | Scout defines interfaces, Scaffold Agent materializes before Wave Agents launch |
| **I3** | Wave Sequencing | Wave N+1 does not launch until Wave N merged and verified |
| **I4** | IMPL Doc is Single Source of Truth | Completion reports, interface contracts, status written to IMPL doc |
| **I5** | Agents Commit Before Reporting | Each agent commits to worktree branch before writing completion report |
| **I6** | Role Separation | Orchestrator does not perform Scout, Scaffold Agent, or Wave Agent duties |

See [protocol/invariants.md](protocol/invariants.md) for full definitions, enforcement mechanisms, and violation effects.

### Execution Rules (E1–E14)

| ID | Name | Applies To |
|----|------|-----------|
| **E1** | Background Execution | All agent launches, CI polling |
| **E2** | Interface Freeze | Worktree creation |
| **E3** | Pre-Launch Ownership Verification | Before creating worktrees or launching agents |
| **E4** | Worktree Isolation | All Wave Agents |
| **E5** | Worktree Naming Convention | Worktree creation |
| **E6** | Agent Prompt Propagation | Interface deviation propagation |
| **E7** | Agent Failure Handling | Any agent reports partial/blocked |
| **E7a** | Automatic Failure Remediation in --auto Mode | Correctable failures in --auto mode |
| **E8** | Same-Wave Interface Failure | Agent reports blocked due to unimplementable contract |
| **E9** | Idempotency | WAVE_PENDING and WAVE_MERGING states |
| **E10** | Scoped vs Unscoped Verification | Agent verification (scoped) vs post-merge verification (unscoped) |
| **E11** | Conflict Prediction Before Merge | Before merging any wave |
| **E12** | Merge Conflict Taxonomy | Three conflict types with distinct resolution paths |
| **E13** | Verification Minimum | Build + lint + tests (if test suite exists) |
| **E14** | IMPL Doc Write Discipline | Agents append completion reports, never edit earlier sections |

See [protocol/execution-rules.md](protocol/execution-rules.md) for full definitions, triggers, required actions, and failure handling.

---

## Participants

SAW has four participant roles. All are agents (AI model instances with tool access) that differ only in execution mode and responsibility.

**Orchestrator:** Synchronous agent running in the user's interactive session. Drives all protocol state transitions, launches asynchronous agents, waits for completion notifications, reads completion reports, executes merge procedures, verifies merged results, and advances state. The single-threaded coordinator that serializes all state changes. Only participant that interacts with the human directly.

**Scout:** Asynchronous agent that analyzes the codebase, produces the IMPL doc with suitability verdict and agent prompts, defines interface contracts, and specifies required scaffold files. Never modifies source files. Exits after producing IMPL doc.

**Scaffold Agent:** Asynchronous agent that reads approved interface contracts from IMPL doc, creates type scaffold files (shared interfaces, traits, structs), verifies compilation, and commits to HEAD. Runs once before first wave. Exits after committing and updating Scaffolds section status.

**Wave Agent:** Asynchronous agent that owns a disjoint set of files, implements against interface contracts, runs verification gate, commits work to worktree branch, and writes structured completion report to IMPL doc. Multiple wave agents run concurrently within a wave. Never coordinate directly; IMPL doc is the only coordination surface.

See [protocol/participants.md](protocol/participants.md) for detailed responsibilities, required capabilities, forbidden actions, and architectural constraints.

---

## Preconditions

The protocol may only run when ALL of the following hold. The scout's suitability gate checks these before producing agent prompts.

1. **File decomposition:** Work decomposes into ≥2 disjoint file groups. Append-only additions to shared files are orchestrator-owned.
2. **No investigation-first blockers:** No part requires root cause analysis before specification.
3. **Interface discoverability:** All cross-agent interfaces can be defined before any agent starts.
4. **Pre-implementation scan:** If working from audit/findings, classify each item as TO-DO/DONE/PARTIAL before assignment.
5. **Positive parallelization value:** `(sequential_time - slowest_agent_time) > (scout_time + merge_time)`

If any precondition fails, scout emits `NOT SUITABLE` and protocol does not proceed.

See [protocol/preconditions.md](protocol/preconditions.md) for detailed definitions, evidence requirements, and suitability gate algorithm.

---

## State Machine

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/saw-state-machine-dark.svg">
  <img src="docs/diagrams/saw-state-machine-light.svg" alt="SAW protocol state machine">
</picture>

**Primary flow (success path):**
```
SCOUT_PENDING → REVIEWED → SCAFFOLD_PENDING (if needed) → WAVE_PENDING →
WAVE_EXECUTING → WAVE_MERGING → WAVE_VERIFIED →
  (if more waves) WAVE_PENDING OR (if complete) COMPLETE
```

**Failure paths:**
- Suitability gate failure: `SCOUT_PENDING → NOT_SUITABLE (terminal)`
- Agent/verification failure: `WAVE_EXECUTING → BLOCKED → (fixed) → WAVE_VERIFIED`
- Interface contract revision: `WAVE_EXECUTING → BLOCKED → (revised) → WAVE_PENDING`

**BLOCKED** is not terminal. Orchestrator fixes the failure and re-runs verification. BLOCKED → WAVE_VERIFIED on verification pass.

**Solo wave:** A wave with exactly one agent runs on main branch (no worktrees). WAVE_MERGING is skipped. Post-wave verification still required.

See [protocol/state-machine.md](protocol/state-machine.md) for complete state catalog, transition guards, entry actions, and correctness properties.

---

## Message Formats

### Suitability Verdict

Emitted by Scout, written to IMPL doc before agent prompts. Three outcomes:
- `SUITABLE`: Proceed
- `SUITABLE WITH CAVEATS`: Proceed with caveats acknowledged
- `NOT SUITABLE`: Do not proceed (includes failed preconditions and suggested alternative)

### Agent Prompt (9-field structure)

| Field | Content |
|-------|---------|
| 0. Isolation Verification | Mandatory pre-flight: verify worktree, branch, working directory |
| 1. File Ownership | Exact files the agent owns |
| 2. Interfaces to Implement | Exact signatures the agent must deliver |
| 3. Interfaces to Call | Exact signatures from prior waves or existing code |
| 4. What to Implement | Functional description (what, not how) |
| 5. Tests to Write | Named tests with one-line descriptions |
| 6. Verification Gate | Exact commands, scoped to owned files/packages |
| 7. Constraints | Hard rules: error handling, compatibility, things to avoid |
| 8. Report | Instructions for writing completion report |

### Completion Report

Structured YAML block appended to IMPL doc by each agent:

```yaml
### Agent {letter} - Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}
files_changed: [...]
files_created: [...]
interface_deviations: [...]
out_of_scope_deps: [...]
tests_added: [...]
verification: PASS | FAIL
```

### Scaffolds Section

Four-column table specifying type scaffold files:

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [exact types, interfaces, structs] | `module/internal/types` | pending → committed (sha) |

See [protocol/message-formats.md](protocol/message-formats.md) for complete format specifications, field definitions, and conflict resolution strategies.

---

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:

- No two agents in the same wave will produce conflicting changes
- Direct coordination drift is prevented; deviations from interface contracts must be declared in completion reports and are surfaced at wave boundaries
- Integration failures surface at wave boundaries, not at the end of all waves
- Downstream agents always receive accurate context (IMPL doc reflects actual state)
- The orchestrator can detect disjoint ownership violations before touching the working tree

---

## Protocol Violations

| Violation | Broken Invariant | Effect |
|-----------|-----------------|--------|
| Two agents modify the same file | I1 | Merge conflict, undefined output |
| Agent calls undefined interface | I2 | Interface drift, integration failure |
| Wave N+1 launched before Wave N verified | I3 | Cascade failures surface at end |
| Completion report written to chat only | I4 | Downstream agents get stale context |
| Agent reports complete with uncommitted changes | I5 | Merge requires manual copy |
| Orchestrator performs Scout, Scaffold Agent, or Wave Agent duties | I6 | Context pollution, broken observability, async execution bypassed |

---

## Variants

**Bootstrap mode** (`prompts/saw-bootstrap.md`): Design-first execution for new projects with no existing codebase. Scout acts as architect: gathers requirements, designs package structure, defines interface contracts, and specifies a types scaffold in the IMPL doc Scaffolds section. Scaffold Agent materializes it after human review. Wave 1 agents implement in parallel against those contracts without seeing each other's code.

---

## Reference Implementation

The canonical prompts that implement this protocol for Claude Code:

| File | Role |
|------|------|
| `prompts/scout.md` | Scout participant: suitability gate + IMPL doc production |
| `prompts/scaffold-agent.md` | Scaffold Agent participant: materializes approved interface contracts |
| `prompts/agent-template.md` | Wave Agent participant: 9-field prompt template |
| `prompts/saw-skill.md` | Orchestrator: command routing and wave execution |
| `prompts/saw-worktree.md` | Orchestrator: worktree lifecycle |
| `prompts/saw-merge.md` | Orchestrator: merge procedure |
| `prompts/saw-bootstrap.md` | Bootstrap mode variant: design-first for new projects |

**Version headers:** Each prompt file must carry a machine-readable version identifier on line 1 in the format `<name> v<major>.<minor>.<patch>` using appropriate comment syntax. This is a normative requirement for mid-session identification by orchestrator and monitoring tools.

---

## Conformance

An implementation of SAW (in any agent runtime) is conforming if it preserves:

- **All six invariants (I1–I6)** with equivalent enforcement — definitions may be adapted for target runtime's idioms but semantics must be identical
- **All fourteen execution rules (E1–E14)** at their enforcement points — background execution, interface freeze, ownership verification, IMPL doc write discipline, etc.
- **State machine transitions** including mandatory human checkpoints at suitability gate and REVIEWED state
- **Message formats** — suitability verdict, completion report YAML schema, IMPL doc section structure
- **Suitability gate** — five-question assessment with NOT SUITABLE as first-class outcome
- **Scaffold file support** — Scout may produce type scaffold files committed to HEAD before worktrees created; agents implement against them; post-merge gate verifies scaffold files present and unmodified (I2)

**What may vary:** Agent runtime primitives (tool names, parameter syntax, isolation mechanism), programming language of target project, specific verification commands, UI surface for human checkpoints.

**Forking:** You may adapt prompt files for a different agent runtime. Invariant definitions (I1–I6) and execution rule definitions (E1–E14) must be preserved verbatim or with semantically equivalent language — they are the normative core. Remove implementation-specific examples if they do not apply, but do not remove the rules themselves. Carry a conforming version identifier and, if your fork diverges meaningfully, a new name to avoid confusion with this reference implementation.
