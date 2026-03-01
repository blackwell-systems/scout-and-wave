# Scout-and-Wave Protocol Specification

**Version:** 0.3.2
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

**Scout** — Analyzes the codebase, produces the IMPL doc, and exits. Never
modifies source files. Never participates in wave execution.

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
   analysis before it can be specified. Agents must be fully specifiable before
   the protocol begins.

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

Note: a single agent modifying files outside its declared ownership scope is
distinct from an I1 violation. A single agent cannot conflict with itself.
Such out-of-scope changes must be justified, documented in the completion
report, and verified by the post-merge gate.

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
  │                                    (human reviews;
  │                                     interface freeze
  │                                     checkpoint)
  │                                          │
  │                                     human approves
  │                                          │
  │                                          ▼
  └──────────────────────────────────► WAVE_PENDING
                                            │
                                   ┌────────┴────────┐
                               solo │               multi│
                               wave │               wave │
                                    ▼                    ▼
                             WAVE_EXECUTING      orchestrator
                           (agent runs on      pre-creates worktrees,
                             main directly)    launches agents
                                    │                    │
                                    │              WAVE_EXECUTING
                                    │           (agents run in parallel)
                                    │                    │
                                    │           all agents report complete
                                    │                    │
                                    │              WAVE_MERGING
                                    │           (conflict prediction →
                                    │            merge sequence →
                                    │            worktree cleanup)
                                    │                    │
                                    └──────┬─────────────┘
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

**Solo wave:** A wave containing exactly one agent runs the agent directly on
the main branch with no worktrees. There is nothing to conflict with. The
WAVE_MERGING state is skipped. Post-wave verification is still required before
advancing. Wave 0 in bootstrap projects is always a solo wave.

---

## Execution Rules

These rules govern orchestrator behavior during wave execution. They are not
captured by the state machine alone.

**Interface freeze.** Interface contracts become immutable when worktrees are
created. The review window between REVIEWED and WAVE_PENDING is the checkpoint
for revising type signatures, adding fields, or restructuring APIs. After
worktrees branch from HEAD, any interface change requires removing and
recreating all worktrees for the wave.

**Worktree pre-creation.** For multi-agent waves, the orchestrator creates all
worktrees before launching any agent. Do not rely on the Task tool's
`isolation: "worktree"` parameter alone — it does not guarantee each agent
starts in the correct worktree. Pre-creation is the mechanism that enforces
isolation; agent-side isolation verification (Field 0) is defense-in-depth.

**Scoped vs unscoped verification.** Agents run focused verification during
waves (scoped to the files and packages they own) to keep iteration fast.
The orchestrator's post-merge gate runs unscoped across the full project to
catch cross-package cascade failures that no individual agent could see.

**Conflict prediction before merge.** The orchestrator cross-references all
agents' `files_changed` and `files_created` lists before touching the working
tree. A file appearing in more than one agent's list is a disjoint ownership
violation. It must be resolved before any merge proceeds.

---

## Message Formats

### Suitability Verdict

Emitted by the scout at the end of the suitability gate. Written to the IMPL
doc before any agent prompts.

```
Verdict: SUITABLE | NOT SUITABLE | SUITABLE WITH CAVEATS

[One paragraph rationale]

Estimated times:
  Scout phase:         ~X min
  Agent execution:     ~Y min (N agents, accounting for parallelism)
  Merge & verify:      ~Z min
  Total (SAW):         ~T min
  Sequential baseline: ~B min
  Time savings:        ~D min (P% faster | slower)

Recommendation: [Proceed | Do not proceed | Proceed with caveats]
```

If `NOT SUITABLE`, the IMPL doc contains only this verdict. No agent prompts
are written. The protocol terminates.

### Agent Prompt

9-field structure: Field 0 is a mandatory pre-flight run by the agent before
any file modifications. Fields 1–8 are the implementation spec stamped
per-agent from the IMPL doc by the scout.

| Field | Content |
|-------|---------|
| 0. Isolation Verification | Mandatory pre-flight: verify worktree, branch, and working directory before touching any files. Self-heal via `cd` to expected worktree path, then fail fast if verification still fails. |
| 1. File Ownership | Exact files the agent owns. Hard constraint. |
| 2. Interfaces to Implement | Exact signatures the agent must deliver. |
| 3. Interfaces to Call | Exact signatures from prior waves or existing code. |
| 4. What to Implement | Functional description. What, not how. |
| 5. Tests to Write | Named tests with one-line descriptions. |
| 6. Verification Gate | Exact commands, scoped to owned files/packages. All must pass before reporting. |
| 7. Constraints | Hard rules: error handling, compatibility, things to avoid. |
| 8. Report | Instructions for writing the completion report. |

### Completion Report

Structured YAML block written by each agent to the IMPL doc. Machine-readable.
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
  - description: "Exact description"
    downstream_action_required: true | false
    affects: [agent-letter, ...]  # agents in later waves that depend on this interface
out_of_scope_deps:
  - "file: path, change: description, reason: why"  # or []
tests_added:
  - test_name
verification: PASS | FAIL ({command} — N/N tests)
```

Free-form notes follow the structured block for anything that doesn't fit.

`interface_deviations` is `[]` if the agent implemented all contracts exactly
as specified. `downstream_action_required: true` means the orchestrator must
update affected downstream agent prompts before the next wave launches.

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

---

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:

- No two agents in the same wave will produce conflicting changes
- Interface drift between agents is structurally impossible (contracts precede implementation)
- Integration failures surface at wave boundaries, not at the end
- Downstream agents always receive accurate context (IMPL doc reflects actual state)
- The orchestrator can detect disjoint ownership violations before touching the working tree

---

## Variants

**Quick mode** (`prompts/saw-quick.md`): Lightweight execution for 2–3 agents
with fully disjoint files and no cross-agent interfaces. Uses a 3-field template
(files, task, verification). No IMPL doc. No structured completion reports. No
interface contracts. Suitable when the coordination overhead of full SAW exceeds
the value. If merge conflicts occur in quick mode, the work needs full SAW.

**Bootstrap mode** (`prompts/saw-bootstrap.md`): Design-first execution for new
projects with no existing codebase. The scout acts as architect: gathers
requirements, designs package structure, and defines interface contracts before
any code is written. Always begins with a mandatory solo Wave 0 that creates the
shared types module. All subsequent agents implement against Wave 0 contracts
without seeing each other's code.

---

## Reference Implementation

The canonical prompts that implement this protocol:

| File | Role |
|------|------|
| `prompts/scout.md` | Scout participant — suitability gate + IMPL doc production |
| `prompts/agent-template.md` | Agent participant — 9-field prompt template |
| `prompts/saw-skill.md` | Orchestrator — command routing and wave execution |
| `prompts/saw-worktree.md` | Orchestrator — worktree lifecycle |
| `prompts/saw-merge.md` | Orchestrator — merge procedure |
| `prompts/saw-quick.md` | Quick mode variant — 2-3 agents, no IMPL doc |
| `prompts/saw-bootstrap.md` | Bootstrap mode variant — design-first for new projects |
