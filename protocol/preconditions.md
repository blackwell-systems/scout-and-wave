# Scout-and-Wave Protocol Preconditions

**Version:** 0.21.0

This document defines the preconditions that must hold before the Scout-and-Wave protocol may execute. The scout's suitability gate checks these before producing agent prompts.

---

## Overview

The protocol may only run when ALL of the following preconditions hold. If any precondition fails, the scout emits `NOT SUITABLE` and the protocol does not proceed.

> **Note:** Precondition labels (P1-P5) in this document refer to suitability
> preconditions, not program invariants. Program invariants P1-P4 are defined in
> [program-invariants.md](program-invariants.md). The naming collision is
> historical; context disambiguates.

---

## P1: File Decomposition

The work decomposes into ≥2 disjoint file groups. No two agents require conflicting modifications to the same file.

Append-only additions to a shared file (config registries, module manifests, index files) are not a decomposition blocker; the scout makes such files orchestrator-owned and the orchestrator applies them post-merge. Generated files (build artifacts, compiled outputs) are excluded from ownership and must not appear in any agent's ownership list.

**E43 enforcement:** In Claude Code implementations, lifecycle hooks mechanically prevent agents from modifying files outside their ownership via path validation at the tool boundary (PreToolUse:Write/Edit). This turns P1 violations from detection-after-merge into prevention-at-write-time.

### Append-Only Definition

An agent's change to a shared file qualifies as append-only if and only if:

- (a) the diff is purely additive — no deletions, no modifications to existing entries, no reformatting, no reordering; and
- (b) the new entries are self-contained and do not depend on changes to existing entries in the same file.

Any change that touches an existing line (even whitespace or comment cleanup) disqualifies the file from orchestrator-owned treatment and makes it a decomposition blocker.

**Verification:** The diff for the file must contain only `+` lines, no `-` lines.

### Consequences if Violated

- Multiple agents assigned to modify the same file
- Merge conflicts during wave merging phase
- Manual conflict resolution required, breaking automation

---

## P2: No Investigation-First Blockers

No part of the work requires root cause analysis before it can be specified. Agents must be fully specifiable before the protocol begins.

### Consequences if Violated

- Agents cannot be given complete specifications
- Work must be paused mid-wave for investigation
- Agent prompts become invalid as new information is discovered

---

## P3: Interface Discoverability

All cross-agent interfaces can be defined before any agent starts. Interfaces that cannot be known until implementation is underway are blockers.

### Consequences if Violated

- Agents implement incompatible interfaces
- Integration failures surface after wave completion
- Requires wave restart with revised contracts

---

## P4: Pre-Implementation Scan

If working from an audit or findings list, each item must be classified as TO-DO, DONE, or PARTIAL before agents are assigned. DONE items are excluded from agent scope.

### Consequences if Violated

- Agents spend time implementing already-completed work
- Duplicate implementations conflict during merge
- Wasted agent effort and session cost

---

## P5: Positive Parallelization Value

The parallelization gain must exceed fixed overhead (scout + merge). Evaluated by:

```
(sequential_time - slowest_agent_time) > (scout_time + merge_time)
```

**High parallelization value** (proceed as SUITABLE): Agents are independent AND at least one of:
- Build/test cycle is long (>30 seconds per agent) — each agent runs it independently, amplifying savings
- Average files per agent ≥ 3 — more implementation time per agent, more to parallelize
- Tasks involve non-trivial logic, tests, and edge cases

**Low parallelization value** (consider NOT SUITABLE): Tasks are simple edits, documentation-only,
or trivially fast to implement sequentially. Protocol overhead (scout, merge, verification)
dominates. Recommend sequential implementation.

**Coordination value independent of speed:** Even when parallelization savings are marginal,
the IMPL doc provides value as an audit trail, interface spec, and progress tracker. Emit
SUITABLE WITH CAVEATS and note that the value is coordination, not speed.

### Consequences if Violated

- Parallel execution takes longer than sequential execution
- Protocol overhead (scout, merge, verification) outweighs time saved
- False economy: more complex process with worse performance

---

## Suitability Verdict Format

When preconditions fail, the scout produces:

```
Verdict: NOT SUITABLE

Failed preconditions:
  - Precondition N ([name]): [evidence: what was found in the codebase]

Suggested alternative: [sequential execution | investigate-first then re-scout |
                        other: describe]
```

The `Failed preconditions` field names each precondition that blocked the verdict (by number and name) and states the specific evidence. The `Suggested alternative` field makes the verdict actionable rather than a stop sign.

The IMPL doc contains only this verdict. No agent prompts are written. The protocol terminates.

**Time-to-value estimate (SUITABLE and SUITABLE WITH CAVEATS verdicts):** When the verdict
is positive, the scout includes an estimated time comparison so the human can make an
informed decision about whether to proceed:

```
Estimated times:
- Scout phase: ~X min
- Wave execution: ~Y min (N agents × M min avg, accounting for parallelism)
- Merge & verification: ~Z min
- Total (SAW): ~T min

Sequential baseline: ~B min (N agents × S min avg sequential time)
Time savings: ~D min (~P% faster)

Recommendation: [Marginal gains | Clear speedup | Overhead dominates]
```

The sequential baseline uses the same per-agent time estimate as SAW but multiplied by
agent count (no parallelism). The recommendation is a plain-language summary of whether
the time savings justify the coordination overhead.

---

## E26: Integration Agent Launch Preconditions

The Integration Agent (E26) may only be launched when both of the following conditions hold:

### E26-P1: Integration Report Exists and Is Invalid

An `IntegrationReport` produced by `ValidateIntegration()` (E25) must exist for the current wave, AND `report.Valid` must be `false` (i.e., integration gaps were detected).

If `report.Valid == true`, no Integration Agent is needed — all exports are connected. The Orchestrator proceeds directly to merge.

### E26-P2: Integration Connectors Defined

The IMPL manifest must contain an `integration_connectors` field listing the files the Integration Agent is permitted to modify. Each connector specifies a file path and the reason it needs modification.

```yaml
integration_connectors:
  - file: "cmd/main.go"
    reason: "Wire new service into application startup"
  - file: "pkg/registry/init.go"
    reason: "Register new handler type"
```

If `integration_connectors` is absent or empty, the Integration Agent cannot be launched — it would have no files to modify. The Orchestrator should emit `integration_agent_failed` with an error indicating missing connectors and enter BLOCKED.

### Consequences if Violated

- **E26-P1 violated (no report or report valid):** Integration Agent launched unnecessarily, wastes resources, may make incorrect modifications
- **E26-P2 violated (no connectors):** Integration Agent has no file ownership, cannot make any changes, will fail or produce no output

---

## Cross-References

- See `invariants.md` for runtime constraints that must hold during execution
- See `execution-rules.md` for orchestrator behavior rules
- See [message-formats.md](message-formats.md) for complete message format specification
