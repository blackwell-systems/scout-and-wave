# Scout-and-Wave Protocol Specification

**Version:** 0.6.0
**Status:** Active

Scout-and-Wave (SAW) is a protocol for safely parallelizing human-guided
agentic workflows. It defines preconditions, invariants, participant roles, state
transitions, and message formats that guarantee agents can work concurrently
without conflicts. Human review checkpoints are structural: the protocol does
not advance past the suitability gate or between waves without human approval.

The prompts in `prompts/` are reference implementations of this protocol.

---

## Participants

SAW has four participant roles. All four are agents (AI model instances
running with tool access). They differ only in execution mode and responsibility.

**Orchestrator:** The synchronous agent running in the user's own interactive
session. Drives all protocol state transitions: reads the IMPL doc, creates
worktrees, launches scouts and wave agents, waits for completion notifications,
reads completion reports, executes the merge procedure, verifies the merged
result, and advances state. The orchestrator serializes all state changes; it
is the single-threaded coordinator that processes completion events and decides
what runs next.

The only participant that interacts with the human directly. All progress
reporting, decision points, approval requests, and error escalation flow through
the orchestrator; asynchronous agents never surface information to the human
except through the orchestrator's completion handling.

Running in the user's session is what makes human checkpoints enforceable. A
background orchestrator would have no interactive session to deliver mandatory
approvals to. The human is not a separate role; they are present through the
orchestrator's session.

Not all checkpoints require human input. The suitability gate and the REVIEWED
state (plan review before the first wave) always require explicit approval.
Inter-wave checkpoints are optional and can be automated via `/saw wave --auto`.
Failures and BLOCKED states always surface to the human regardless of automation
mode. The orchestrator being synchronous means the human can intervene at any
moment; which specific stops are mandatory is a separate question from whether
intervention is possible at all.

**Scout:** An asynchronous agent launched by the orchestrator. Analyzes the
codebase, produces the IMPL doc, and exits. Defines all interface contracts and
specifies any required scaffold files in the IMPL doc Scaffolds section — but
does not create source files. Never modifies existing source files. Never
participates in wave execution. The orchestrator waits for the scout's
completion notification before entering REVIEWED state.

**Scaffold Agent:** An asynchronous agent launched by the orchestrator after
human review of the IMPL doc. Reads the approved interface contracts and
Scaffolds section from the IMPL doc, creates the specified type scaffold files
(shared interfaces, traits, structs — no behavior), verifies they compile, and
commits them to HEAD. Runs only when the IMPL doc Scaffolds section is
non-empty. Never modifies existing source files. Exits after committing and
updating the Scaffolds section status. The orchestrator waits for the Scaffold
Agent before creating worktrees.

**Wave Agent:** An asynchronous agent launched by the orchestrator. Owns a
disjoint set of files, implements against the interface contracts defined in the
IMPL doc, runs the verification gate, commits its work, and writes a structured
completion report to the IMPL doc. Multiple wave agents run concurrently within
a wave. Wave agents never coordinate directly with each other; the IMPL doc is
the only coordination surface. The orchestrator collects all completion
notifications before advancing to WAVE_MERGING.

The protocol's correctness guarantees flow from this structure: the synchronous
orchestrator serializes all state transitions while asynchronous agents execute
in parallel. Agents can run concurrently precisely because they never write to
shared state; only the orchestrator does.

---

## Preconditions

The protocol may only run when ALL of the following hold. The scout's
suitability gate checks these before producing agent prompts.

1. **File decomposition.** The work decomposes into ≥2 disjoint file groups.
   No two agents require conflicting modifications to the same file.
   Append-only additions to a shared file (config registries, module manifests,
   index files) are not a decomposition blocker; the scout makes such files
   orchestrator-owned and the orchestrator applies them post-merge. Generated
   files (build artifacts, compiled outputs) are excluded from ownership and
   must not appear in any agent's ownership list.

   **Append-only defined.** An agent's change to a shared file qualifies as
   append-only if and only if: (a) the diff is purely additive — no deletions,
   no modifications to existing entries, no reformatting, no reordering; and
   (b) the new entries are self-contained and do not depend on changes to
   existing entries in the same file. Any change that touches an existing line
   (even whitespace or comment cleanup) disqualifies the file from
   orchestrator-owned treatment and makes it a decomposition blocker. To
   verify: the diff for the file must contain only `+` lines, no `-` lines.

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

Invariants are identified by number (I1–I6). When referenced in prompt files,
the I-number serves as an anchor for cross-referencing and audit; the canonical
definition is embedded verbatim alongside it so each document remains
self-contained without requiring a lookup. To audit consistency, grep prompt
files for `I{N}` and `E{N}` and verify the embedded definitions match this
section and the Execution Rules section.

**I1: Disjoint file ownership.** No two agents in the same wave own the same
file. This is a hard constraint, not a preference. It is the mechanism that
makes parallel execution safe. Worktree isolation does not substitute for it.

Note: a single agent modifying files outside its declared ownership scope is
distinct from an I1 violation. A single agent cannot conflict with itself.
Such out-of-scope changes must be justified, documented in the completion
report, and verified by the post-merge gate.

**I2: Interface contracts precede parallel implementation.** The Scout defines
all interfaces that cross agent boundaries in the IMPL doc. The Scaffold Agent
implements them as type scaffold files committed to HEAD after human review,
before any Wave Agent launches. Agents implement against the spec; they never
coordinate directly.

**I3: Wave sequencing.** Wave N+1 does not launch until Wave N has been
merged and post-merge verification has passed.

**I4: IMPL doc is the single source of truth.** Completion reports, interface
contract updates, and status are written to the IMPL doc. Chat output is not
the record. See E14 for the write discipline that keeps IMPL doc conflicts
predictably resolvable.

**I5: Agents commit before reporting.** Each agent commits its changes to its
worktree branch before writing a completion report. Uncommitted state at report
time is a protocol deviation and must be noted in the report.

**I6: Role separation.** The Orchestrator does not perform Scout, Scaffold
Agent, or Wave Agent duties. Codebase analysis, IMPL doc production, scaffold
file creation, and source code implementation are delegated to the appropriate
asynchronous agent. If the Orchestrator finds itself doing any of these, it has
violated the protocol; it must stop and launch the correct agent. This invariant
is not a style preference: an Orchestrator performing Scout work bypasses async
execution, pollutes the orchestrator's context window, and breaks observability
(no Scout agent means no SAW session is detectable by monitoring tools).

---

## State Machine

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/saw-state-machine-dark.svg">
  <img src="docs/diagrams/saw-state-machine-light.svg" alt="SAW protocol state machine">
</picture>

**BLOCKED** is not a terminal state. The orchestrator fixes the failure and
re-runs verification. BLOCKED → WAVE_VERIFIED on verification pass.

**Solo wave:** A wave containing exactly one agent runs the agent on the main
branch with no worktrees. There is nothing to conflict with. The WAVE_MERGING
state is skipped. Post-wave verification is still required before advancing.

The solo wave agent must still operate in the Wave Agent role: launched by the
Orchestrator as an asynchronous agent, not executed directly by the
Orchestrator. Executing solo wave work inline violates I6 regardless of wave
size. The absence of worktrees changes the isolation mechanism; it does not
change the participant roles.

---

## Execution Rules

These rules govern orchestrator behavior during wave execution. They are not
captured by the state machine alone. Rules are numbered E1–E14 for
cross-referencing and audit; the same convention as invariants (I1–I6).

**E1: Background execution.** All agent launches, CI polling, and long-running watch commands must execute asynchronously without blocking the orchestrator's main execution thread (e.g. Claude Code's `run_in_background: true` on the Agent and Bash tools). A blocking agent launch serializes the wave; the orchestrator waits for one agent before launching the next, eliminating parallelism. This is a protocol violation, not a performance preference. Any implementation that blocks the orchestrator on agent execution or polling is non-conforming.

**E2: Interface freeze.** Interface contracts become immutable when worktrees are
created. The review window between REVIEWED and WAVE_PENDING is the checkpoint
for revising type signatures, adding fields, or restructuring APIs. After
worktrees branch from HEAD, any interface change requires removing and
recreating all worktrees for the wave.

When an interface change is required after worktrees exist and some agents have
already committed work, two recovery paths are available:

- **(a) Recreate and cherry-pick.** Record the commit SHAs of agents whose
  completed work does not implement or call the changed interface. Remove and
  recreate all worktrees. Cherry-pick the unaffected commits onto their new
  worktrees. Verify each cherry-picked commit still builds against the new
  interface. Re-run only the agents whose work is affected by the change.
  Use this path when most agents have completed and the change is narrow
  (affects 1–2 agents).

- **(b) Descope and defer.** Leave the current wave to complete against the
  existing contracts. Move the interface revision to the next wave boundary,
  where it becomes the contract for a new wave. Agents that cannot complete
  against the current contract report `status: blocked` (E8); the orchestrator
  resolves the contract change at the wave boundary. Use this path when the
  change is broad, when few agents have completed, or when cherry-pick safety
  cannot be confirmed.

If no agents have committed work yet, recreate worktrees without cherry-pick.
E2 governs orchestrator-initiated interface changes. E8 governs the same
problem from the other direction: agent-discovered contract failures.

**E3: Pre-launch ownership verification.** Before creating worktrees or launching
any agent in a wave, the orchestrator scans the wave's file ownership table in
the IMPL doc and verifies no file appears in more than one agent's ownership
list. If an overlap is found, the wave does not launch; the IMPL doc must be
corrected first. This is distinct from post-execution conflict prediction:
pre-launch catches scout planning errors; post-execution catches runtime
deviations where an agent touched files outside its declared scope.

**E4: Worktree pre-creation.** For multi-agent waves, the orchestrator creates all
worktrees before launching any agent. Do not rely on agent runtime isolation
primitives alone (e.g. Claude Code's `isolation: "worktree"` Agent parameter);
they do not guarantee each agent starts in the correct worktree. Explicit
pre-creation is the mechanism that enforces isolation; agent-side isolation
verification (Field 0) is defense-in-depth.
Disjoint file ownership and worktree isolation are complementary layers that protect against different failure modes. Neither substitutes for the other.

- **Disjoint file ownership (I1)** prevents merge conflicts: no two agents produce edits to the same file, so the merge step is always conflict-free.
- **Worktree isolation** prevents execution-time interference: each agent's `go build`, `go test`, and tool-cache writes operate on an independent working tree, so concurrent builds do not race on shared build caches, test caches, lock files, or intermediate object files. Without worktrees, two agents running `go build ./...` simultaneously on the same directory produce flaky failures that look like code bugs but are actually filesystem races.

Disjoint ownership without worktrees: merge is safe, but concurrent execution is flaky. Worktrees without disjoint ownership: execution is clean, but merge produces unresolvable conflicts. Both constraints must hold simultaneously for parallel waves to be correct and reproducible.

**E5: Worktree naming convention.** Worktrees must be named `.claude/worktrees/wave{N}-agent-{letter}` where `{N}` is the 1-based wave number and `{letter}` is the agent identifier (A, B, C...). This is a canonical requirement, not a style choice. The naming scheme is the mechanism by which external tooling identifies SAW sessions and correlates agents to waves. Deviating from it breaks observability silently. Any tooling that consumes SAW session data must treat this naming scheme as the stable interface.

**E6: Agent prompt propagation.** Agent prompts are sections within the IMPL doc.
When the orchestrator updates an agent prompt (due to interface deviation
propagation, contract revision, or same-wave interface failure), it edits the
prompt section in the IMPL doc directly. The agent reads its prompt from the
IMPL doc at launch time, so the corrected version is always what runs. There
is no separate prompt file to keep in sync.

**E7: Agent failure handling.** If any agent in a wave reports `status: partial`
or `status: blocked`, the wave does not merge. The wave goes to BLOCKED. The
orchestrator must resolve the failing agent (re-run it, manually fix the
issue, or descope it from the wave) before the merge step proceeds. Agents
that completed successfully are not re-run, but their worktrees are not merged
until the full wave is resolved. Partial merges are not permitted.

**E8: Same-wave interface failure.** If any agent reports `status: blocked` due to
an interface contract being unimplementable as specified, the wave does not
merge. The orchestrator marks the wave BLOCKED, revises the affected contracts
in the IMPL doc, and re-issues prompts to all agents whose work depends on the
changed contract. Agents that completed cleanly against unaffected contracts do
not re-run. The wave restarts from WAVE_PENDING with the corrected contracts.

**E9: Idempotency.** WAVE_PENDING is re-entrant; re-running `/saw wave` checks
for existing worktrees before creating new ones and does not duplicate them.
WAVE_MERGING is not idempotent. If the orchestrator crashes mid-merge, inspect
the state before continuing: check which worktree branches are already present
in main's history (`git log --merges`) and skip those. Do not re-merge a
worktree that has already been merged.

**E10: Scoped vs unscoped verification.** Agents run focused verification during
waves (scoped to the files and packages they own) to keep iteration fast.
The orchestrator's post-merge gate runs unscoped across the full project to
catch cross-package cascade failures that no individual agent could see.

The scout must specify exact verification commands in Field 6 of each agent
prompt. Agents run those exact commands; they may not substitute broader ones.
"Scoped" is not self-evident from agent context: `go test ./...` is unscoped
in Go regardless of how fast it runs; the correct scoped command is
`go test ./pkg/owned/...` or equivalent. The scout knows the project structure
and can determine the right target; agents must not guess. An agent that
substitutes a broader command than specified is non-conforming, even if the
command passes.

**E11: Conflict prediction before merge.** The orchestrator cross-references all
agents' `files_changed` and `files_created` lists before touching the working
tree. A file appearing in more than one agent's list is a disjoint ownership
violation. It must be resolved before any merge proceeds.

Within a valid wave, merge order is arbitrary. Same-wave agents are independent
by construction: any agent whose work depends on a file created by another
agent belongs in a later wave. If merge order appears to matter, the wave
structure is wrong, not the merge sequence.

**E12: Merge conflict taxonomy.** Three distinct conflict types can arise; each has
a different resolution path:

1. **Git conflict on agent-owned files:** an I1 violation. This is impossible
   if invariants hold. If it occurs, the scout produced an incorrect ownership
   table. Do not merge. Correct the IMPL doc and re-run the wave.

2. **Git conflict on orchestrator-owned shared files** (IMPL doc completion
   report sections, append-only config registries): expected. Resolve by
   accepting all appended sections. Each agent owns a distinct named section;
   there is no semantic conflict, only a git conflict on adjacent lines.

3. **Semantic conflict** (two agents implement incompatible interfaces without
   a git conflict): surfaces in `interface_deviations` and `out_of_scope_deps`
   in completion reports. Resolved by the orchestrator before the next wave
   launches, via interface contract revision and downstream prompt updates.

**E13: Verification minimum.** The minimum acceptable verification gate is: build
(compile) passing and lint passing. Tests are required if the project has a
test suite; a wave reporting PASS on compile-only when tests exist is a
protocol violation. Agents scope their verification to owned files and packages;
the orchestrator's post-merge gate runs unscoped to catch cross-package cascade
failures.

**E14: IMPL doc write discipline.** Agents write to the IMPL doc exactly once:
by appending their named completion report section at the end of the file under
`### Agent {letter} - Completion Report`. Agents must not edit any earlier
section of the IMPL doc (interface contracts, file ownership table, suitability
verdict, wave structure). Those sections are frozen at worktree creation (E2).
Any apparent need to update an earlier section is an interface deviation; it
must be reported in the completion report and resolved by the Orchestrator, not
edited in-place by the agent. This constraint is what makes IMPL doc git
conflicts predictably resolvable: two agents appending distinct named sections
always produce adjacent-section conflicts with no semantic overlap (E12).

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

If `NOT SUITABLE`, the verdict must include two additional fields:

```
Failed preconditions:
  - Precondition N ([name]): [evidence: what was found in the codebase]

Suggested alternative: [sequential execution | investigate-first then re-scout |
                        other: describe]
```

`Failed preconditions` names each precondition that blocked the verdict (by
number and name) and states the specific evidence. `Suggested alternative`
makes the verdict actionable rather than a stop sign. The IMPL doc contains
only this verdict. No agent prompts are written. The protocol terminates.

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
### Agent {letter} - Completion Report
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
verification: PASS | FAIL ({command} - N/N tests)
```

Free-form notes follow the structured block for anything that doesn't fit.

`interface_deviations` is `[]` if the agent implemented all contracts exactly
as specified. `downstream_action_required: true` means the orchestrator must
update affected downstream agent prompts before the next wave launches.

### Scaffolds Section

Written by the Scout into the IMPL doc to specify type scaffold files. Read and
materialized by the Scaffold Agent after human review. Canonical four-column
format:

```markdown
### Scaffolds

[Omit this section if no scaffold files are needed.]

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [exact types, interfaces, structs with signatures] | `module/internal/types` | pending |
```

`Status` lifecycle: `pending` (Scout wrote spec, Scaffold Agent not yet run) →
`committed (sha)` (Scaffold Agent created, compiled, and committed the file) →
`FAILED: {reason}` (Scaffold Agent could not compile; no file committed).

The Orchestrator verifies all files show `committed` status before creating
worktrees. A `FAILED` status is a protocol stop: report the failure to the
human, surface the reason, and do not proceed to worktree creation. The human
must revise the interface contracts in the IMPL doc and re-run the Scaffold Agent.

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

## Variants

**Bootstrap mode** (`prompts/saw-bootstrap.md`): Design-first execution for new
projects with no existing codebase. The Scout acts as architect: gathers
requirements, designs package structure, defines interface contracts, and
specifies a types scaffold in the IMPL doc Scaffolds section. The Scaffold Agent
materializes it after human review. Wave 1 agents implement in parallel against
those contracts without seeing each other's code.

---

## Reference Implementation

The canonical prompts that implement this protocol for Claude Code:

| File | Role |
|------|------|
| `prompts/scout.md` | Scout participant: suitability gate + IMPL doc production |
| `prompts/scaffold-agent.md` | Scaffold Agent participant: materializes approved interface contracts as type scaffold source files |
| `prompts/agent-template.md` | Wave Agent participant: 9-field prompt template |
| `prompts/saw-skill.md` | Orchestrator: command routing and wave execution |
| `prompts/saw-worktree.md` | Orchestrator: worktree lifecycle |
| `prompts/saw-merge.md` | Orchestrator: merge procedure |
| `prompts/saw-bootstrap.md` | Bootstrap mode variant: design-first for new projects |

**Version headers.** Each prompt file must carry a machine-readable version identifier on line 1 in the format `<name> v<major>.<minor>.<patch>` (e.g. `saw-skill v0.3.4`), using whatever comment syntax the implementation supports (e.g. `<!-- saw-skill v0.3.4 -->` in Claude Code markdown skills). This is a normative requirement. The version identifier is how the active skill is identified mid-session by the orchestrator and by monitoring tools. Prompt files without version identifiers are unidentifiable. Any implementation or fork of a prompt file must carry a conforming version identifier.

**Conformance.** An implementation of SAW (in any agent runtime) is conforming if it preserves:

- All six invariants (I1–I6) with equivalent enforcement — the definitions may be adapted for the target runtime's idioms but the semantics must be identical
- All fourteen execution rules (E1–E14) at their enforcement points — background execution, interface freeze, ownership verification, IMPL doc write discipline, and so on
- The state machine transitions, including mandatory human checkpoints at the suitability gate and REVIEWED state
- The message formats: suitability verdict, completion report YAML schema, and IMPL doc section structure
- The suitability gate: five-question assessment with NOT SUITABLE as a first-class outcome
- Scaffold file support: the Scout may produce type scaffold files committed to HEAD before worktrees are created; agents implement against them; the post-merge gate verifies scaffold files are present and unmodified (I2)

What may vary across implementations: the agent runtime primitives (tool names, parameter syntax, isolation mechanism), the programming language of the target project, the specific verification commands, and the UI surface for human checkpoints.

**Forking.** You may adapt the prompt files for a different agent runtime. The invariant definitions (I1–I6) and execution rule definitions (E1–E14) must be preserved verbatim or with semantically equivalent language — they are the normative core, not implementation detail. Remove the Claude Code-specific examples if they do not apply, but do not remove the rules themselves. Carry a conforming version identifier and, if your fork diverges meaningfully, a new name to avoid confusion with this reference implementation.
