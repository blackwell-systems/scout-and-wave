# Scout-and-Wave Protocol Specification

**Version:** 0.3.1
**Status:** Active

Scout-and-Wave (SAW) is a coordination protocol for parallel AI agent execution
against a shared codebase. It defines preconditions, invariants, participant
roles, state transitions, and message formats that guarantee agents can work
concurrently without conflicts.

The prompts in `prompts/` are reference implementations of this protocol.

---

## Participants

**Orchestrator** — Runs the `/saw` skill. Creates worktrees, launches agents,
reads completion reports, executes the merge procedure, verifies the merged
result, and advances the protocol state.

**Scout** — A read-only agent. Analyzes the codebase, produces the IMPL doc,
and exits. Never modifies source files. Never participates in execution.

**Agent** — An implementation agent. Owns a disjoint set of files, implements
against defined interface contracts, runs the verification gate, and writes a
structured completion report.

---

## Preconditions

The protocol may only run when ALL of the following hold. The scout's
suitability gate checks these before producing agent prompts.

1. **File decomposition.** The work decomposes into ≥2 disjoint file groups.
   No two tasks require modification of the same file.

2. **No investigation-first blockers.** No part of the work requires root cause
   analysis before it can be specified. Agents must be writable before the
   protocol begins.

3. **Interface discoverability.** All cross-agent interfaces can be defined
   before any agent starts. Interfaces that cannot be known until implementation
   is underway are blockers.

4. **Pre-implementation scan.** If working from an audit or findings list, each
   item must be classified as TO-DO, DONE, or PARTIAL before agents are
   assigned. DONE items are excluded from agent scope.

5. **Positive parallelization value.** The parallelization gain must exceed
   fixed overhead (scout + merge). Evaluated by:
   `(sequential_time - slowest_agent_time) > (scout_time + merge_time)`

If any precondition fails, the scout emits `NOT SUITABLE` and the protocol
does not proceed.

---

## Invariants

These must hold throughout the entire protocol execution. Violations break the
correctness guarantees.

**I1 — Disjoint file ownership.** No two agents in the same wave own the same
file. This is a hard constraint, not a preference. It is the mechanism that
makes parallel execution safe. Worktree isolation does not substitute for it.

**I2 — Interface contracts precede implementation.** All interfaces that cross
agent boundaries are defined in the IMPL doc before any agent launches.
Agents implement against the spec; they never coordinate directly.

**I3 — Wave sequencing.** Wave N+1 does not launch until Wave N has been
merged and post-merge verification has passed.

**I4 — IMPL doc is the single source of truth.** Completion reports, interface
contract updates, and status are written to the IMPL doc. Chat output is not
the record.

**I5 — Agents commit before reporting.** Each agent commits its changes to its
worktree branch before writing a completion report. Uncommitted state at report
time is a protocol deviation and must be noted in the report.

---

## State Machine

```
IDLE
  │
  ├─ /saw check  ──────────────────────► CHECKING
  │                                          │
  │                                     verdict only,
  │                                     no state written
  │
  ├─ /saw scout  ──────────────────────► SCOUTING
  │                                          │
  │                                     IMPL doc written
  │                                          │
  │                                          ▼
  │                                       REVIEWED
  │                                    (human reviews)
  │                                          │
  │                                     human approves
  │                                          │
  │                                          ▼
  └──────────────────────────────────► WAVE_PENDING
                                            │
                                    orchestrator pre-creates
                                    worktrees, launches agents
                                            │
                                            ▼
                                     WAVE_EXECUTING
                                    (agents run in parallel)
                                            │
                                    all agents report complete
                                            │
                                            ▼
                                      WAVE_MERGING
                                   (conflict prediction →
                                    merge sequence →
                                    worktree cleanup)
                                            │
                                    post-merge verification
                                            │
                                   ┌────────┴────────┐
                               PASS │                │ FAIL
                                    ▼                ▼
                              WAVE_VERIFIED       BLOCKED
                                    │          (fix required
                             ┌──────┴──────┐    before next
                         more │            │ no  wave)
                        waves │            │ more
                              ▼            ▼
                         WAVE_PENDING   COMPLETE
```

**BLOCKED** is not a terminal state. The orchestrator fixes the failure and
re-runs verification. BLOCKED → WAVE_VERIFIED on verification pass.

---

## Message Formats

### Suitability Verdict

Emitted by the scout at the end of the suitability gate. Written to the IMPL
doc before any agent prompts.

```
Verdict: SUITABLE | NOT SUITABLE | SUITABLE WITH CAVEATS

[One paragraph rationale]

Estimated times:
  Scout phase:        ~X min
  Agent execution:    ~Y min (N agents, accounting for parallelism)
  Merge & verify:     ~Z min
  Total (SAW):        ~T min
  Sequential baseline: ~B min
  Time savings:       ~D min (P% faster | slower)

Recommendation: [Proceed | Do not proceed | Proceed with caveats]
```

If `NOT SUITABLE`, the IMPL doc contains only this verdict. No agent prompts
are written. The protocol terminates.

### Agent Prompt

8-field structure, stamped per-agent from the IMPL doc by the scout.

| Field | Content |
|-------|---------|
| 1. File Ownership | Exact files the agent owns. Hard constraint. |
| 2. Interfaces to Implement | Exact signatures the agent must deliver. |
| 3. Interfaces to Call | Exact signatures from prior waves or existing code. |
| 4. What to Implement | Functional description. What, not how. |
| 5. Tests to Write | Named tests with one-line descriptions. |
| 6. Verification Gate | Exact commands. All must pass before reporting. |
| 7. Constraints | Hard rules: error handling, compatibility, things to avoid. |
| 8. Report | Instructions for writing the completion report. |

### Completion Report

Structured block written by each agent to the IMPL doc. Machine-readable.
Orchestrator parses these before merging.

```yaml
### Agent {letter} — Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted"
files_changed:
  - path/to/file
files_created:
  - path/to/file
interface_deviations:
  - "Exact description"  # or []
out_of_scope_deps:
  - "file: path, change: description, reason: why"  # or []
tests_added:
  - test_name
verification: PASS | FAIL ({command} — N/N tests)
```

Free-form notes follow the structured block for anything that doesn't fit.

---

## Protocol Violations

These are conditions that break invariants and invalidate the correctness
guarantees.

| Violation | Broken Invariant | Effect |
|-----------|-----------------|--------|
| Two agents modify the same file | I1 | Merge conflict, undefined output |
| Agent calls undefined interface | I2 | Interface drift, integration failure |
| Wave N+1 launched before Wave N verified | I3 | Cascade failures surface at end |
| Completion report written to chat only | I4 | Downstream agents get stale context |
| Agent reports complete with uncommitted changes | I5 | Merge requires manual copy |
| Root Cargo.toml touched by Wave 1 agents (Rust) | I1 | Guaranteed workspace member conflict |

---

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:

- No two agents in the same wave will produce conflicting changes
- Interface drift between agents is structurally impossible (contracts precede implementation)
- Integration failures surface at wave boundaries, not at the end
- Downstream agents always receive accurate context (IMPL doc reflects actual state)
- The orchestrator can detect disjoint ownership violations before touching the working tree

---

## Reference Implementation

The canonical prompts that implement this protocol:

| File | Role |
|------|------|
| `prompts/scout.md` | Scout participant — suitability gate + IMPL doc production |
| `prompts/agent-template.md` | Agent participant — 8-field prompt template |
| `prompts/saw-skill.md` | Orchestrator — command routing and wave execution |
| `prompts/saw-worktree.md` | Orchestrator — worktree lifecycle |
| `prompts/saw-merge.md` | Orchestrator — merge procedure |
| `prompts/saw-quick.md` | Lightweight variant — 2-3 agents, no IMPL doc |
| `prompts/saw-bootstrap.md` | Bootstrap variant — design-first for new projects |
