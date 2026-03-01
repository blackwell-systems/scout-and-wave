# SAW Pipeline Proposal: Cross-Feature Scout Pipelining

**Status:** Proposal — observed in practice, not yet canonical

**Discovered:** claudewatch session, 2026-03-01 — session project tagging feature (Wave 2 running) overlapped with live-session-read scout

---

## Participant Model

All three SAW participants are agents — AI model instances with tool access. What distinguishes them is execution mode:

- **Orchestrator** — synchronous. Drives all state transitions. Launches scouts and wave agents, waits for completion, reads results, and decides what runs next. The sole reporting channel to the human: all progress, decisions, approval requests, and errors surface through the orchestrator. Async agents are invisible to the human except through the orchestrator's completion handling.
- **Scout** — asynchronous. Launched by the orchestrator, analyzes the codebase, writes the IMPL doc, and exits. Never modifies source.
- **Wave agents** — asynchronous. Launched by the orchestrator in parallel, own disjoint file sets, commit their work, and write completion reports to the IMPL doc.

Pipelining does not change any of these roles. The orchestrator remains the synchronous agent throughout. It simply makes a different scheduling decision during what would otherwise be an idle wait window: rather than doing nothing while async wave agents run, it launches the next feature's scout as an additional async agent. The protocol structure is unchanged — only the orchestrator's time is used more efficiently.

---

## The Idea

SAW optimizes parallelism *within* a feature (multiple agents per wave). This proposal addresses parallelism *across* features: starting the next feature's scout while the current feature's agents are still executing.

The normal mental model:

```
Feature A: scout → wave 1 → wave 2 → done
Feature B:                              scout → wave 1 → ...
```

The pipelined model:

```
Feature A: scout → wave 1 → wave 2 ↘
Feature B:                 scout ────→ wave 1 → wave 2 → done
```

The scout for Feature B runs during Feature A's wave 2 execution. By the time Feature A merges and you're ready to move, Feature B's IMPL doc is already written and waiting for approval.

---

## Why This Works

A SAW scout is an asynchronous, read-only agent — it analyzes source files and writes only the IMPL doc, never source code. Because the orchestrator is synchronous and the scout is asynchronous, they can overlap without any coordination: the orchestrator launches the scout, registers its completion notification, and continues waiting for the active wave's agents. When both the wave and the scout complete, the orchestrator handles both results in sequence.

The write safety is structural:

- Scout writes only to the IMPL doc — no conflict with active wave agents possible
- The only risk is reading code that an active wave agent is simultaneously modifying in a worktree
- If the scout reads stale (pre-modification) source for files an active agent owns, its interface contracts may be wrong when the next wave launches

That risk is controlled by a single constraint.

---

## The Safety Constraint: Disjoint Read Domain

**Before launching a pipelined scout, verify:** the next feature's expected file changes do not overlap with the active wave's file ownership table.

If the active wave's Agent B owns `internal/mcp/tools.go`, the incoming scout must not read `internal/mcp/tools.go` as a *file it will change* — because the scout would produce contracts against the pre-B version, and those contracts would be stale by the time the next feature's agents run.

The scout reading a file to *understand context* (not change it) is safe — it will read the current main HEAD version, which is what the next feature's agents will also start from after the merge.

The check is: **files the scout expects to modify** must not appear in **active wave ownership lists**.

---

## The Timing Model

```
[Wave N executing]     [Scout for Feature N+1]    [Review window]     [Wave 1 of N+1]
        ████████████████████    ←────────────────→       ███░░░░░░░░           ████
                                Scout runs here.          Orchestrator          Agents
                                Writes IMPL doc.          reviews IMPL,         launch.
                                                          checks for B+C
                                                          interface deviations
                                                          from Feature N merge.
```

The review window — merge, verify, tick checkboxes, read agent reports — is dead time for the synchronous orchestrator. Launching the pipelined scout fills that gap. The orchestrator's role doesn't change: it launched async agents (the wave), it launches another async agent (the scout), and it processes both results when they complete. By the time the orchestrator finishes reviewing Wave N's merge, the IMPL doc for Feature N+1 is waiting.

---

## What This Looks Like in Practice

Session project tagging (Feature A) and live-session-read (Feature B) ran this way:

- Feature A Wave 2 (agents B + C): `internal/mcp/`, `internal/app/tag.go`
- Feature B scout expected files: `internal/claude/active.go`, `internal/mcp/tools.go`, `internal/app/scan.go`

The overlap check: Feature A's Wave 2 owned `internal/mcp/tools.go`. The scout would also read `internal/mcp/tools.go` as a file it will change.

This is a **partial overlap** — the scout would read the pre-B version of `tools.go`. In this specific case it was acceptable because:
1. Agent B was additive (new helper functions and a new tool registration)
2. The scout's contracts on `tools.go` describe changes to `handleGetSessionStats` — a different function from what Agent B modified
3. The risk was assessed as low and the scout proceeded

A stricter interpretation would delay the scout until after Agent B's merge. The right call depends on how much the active agent's changes affect the files the scout is targeting.

---

## Proposed Protocol Changes

Three changes would make this canonical:

### 1. New `prompts/saw-pipeline.md`

A reference doc describing:
- The trigger condition (next feature known + disjoint read domain check passes)
- The safety check procedure (cross-reference expected-to-change files vs active ownership)
- The timing model diagram above
- What to do when there's partial overlap (assess, accept risk, or delay scout)

### 2. Amendment to `prompts/saw-skill.md`

After launching a wave, add a section:

> **Pipeline opportunity:** If the next feature is known, check whether its expected file changes are disjoint from this wave's ownership. If so, an asynchronous scout for the next feature can run during this wave's execution time. See `saw-pipeline.md`.

### 3. Amendment to `prompts/scout.md`

Scouts should emit a **"Files Read"** section alongside "Files Changed" in the IMPL doc. The distinction:

- **Files Changed** — files the agents will modify (required for disjoint ownership enforcement)
- **Files Read** — files the scout read to understand context (needed for the incoming pipeline safety check)

The orchestrator checks "Files Read" of the incoming scout against "Files Changed" of the active wave, not "Files Changed" of the incoming scout. This is more conservative and catches cases where the scout's interface contracts depend on understanding a file that an active agent is rewriting.

---

## Intentional Upfront Planning: The Session-Level DAG

The opportunistic model — discover a feature mid-session, check disjointness, fill the gap — works but leaves value on the table. If the full change landscape is known at the start of a session, a more powerful approach is available: plan the entire pipeline before writing any code.

### The Principle Lifts One Level

SAW applies the same reasoning at every level:

```
Files    → dependency graph → wave structure  → parallel agents
Features → dependency graph → pipeline schedule → parallel scouts + waves
```

The structure is identical. The granularity changes. A feature DAG determines which scouts can run in parallel and which must wait, the same way a file DAG determines which agents can run in parallel and which must wait.

### What Upfront Planning Produces

Given five features at session start, a lightweight survey produces a feature DAG before any code is touched:

```
Feature A (store layer)   ──→  Feature C (MCP surface)
Feature B (live read)     ──→  Feature C (MCP surface)
Feature D (CLI commands)  [independent]
Feature E (docs/tests)    [independent]
```

From that graph, an optimal pipeline schedule falls out:

```
t=0m:   Scout A, Scout B, Scout D, Scout E          ← all independent, all parallel
t=10m:  Wave1-A, Wave1-B  |  Scout C (A+B interfaces locked)  |  Wave1-D
t=20m:  Wave2-A, Wave2-B  |  Wave1-C                          |  Wave2-D
t=30m:  merge A+B         |  Wave2-C
t=35m:  merge C, merge D, merge E
```

Compare to the sequential baseline:

```
t=0m:   Scout A
t=10m:  Wave1-A, Wave2-A
t=25m:  merge A → Scout B
t=35m:  Wave1-B, Wave2-B
t=50m:  merge B → Scout C
...
```

The pipeline schedule gets to the same endpoint in roughly half the wall-clock time. The savings are not from faster agents — they are from eliminating the serial dependency between features that don't actually depend on each other.

### The New Artifact: Session Plan

Upfront planning requires a **session plan** — a coordination artifact at the feature level, above individual IMPL docs. It records:

- The feature list with brief descriptions and expected file domains
- The feature DAG (which features depend on others' outputs)
- The conflict matrix (which features cannot pipeline due to file overlap)
- The pipeline schedule with time estimates
- The baseline sequential time for comparison

The session plan becomes the document the orchestrator consults when deciding whether to launch a pipelined scout. Rather than checking disjointness on the fly, the schedule was worked out upfront. The runtime decision becomes: "is the schedule still valid, or did an earlier feature's merge change something unexpected?"

### The New Entry Point: `/saw session`

A natural entry point for this mode:

```
/saw session
  - fix session project attribution
  - add live session reading
  - add cost alerting
  - update docs
```

The session command:
1. Takes a list of feature descriptions
2. Runs lightweight file-domain estimates on all of them simultaneously (not full scouts — just enough to identify which packages each feature will likely touch)
3. Builds the feature DAG from stated dependencies and inferred file conflicts
4. Produces the pipeline schedule with estimated times
5. Writes a `docs/SESSION-<date>.md` session plan
6. Asks for human review before launching anything

After approval, the session plan drives the orchestrator. Each time a wave completes, the orchestrator consults the session plan to determine what can launch next — which scouts, which Wave 1s, which merges are unblocked.

### Feature-Level vs. File-Level Conflict Detection

The upfront plan catches **feature-level conflicts** — two features that both touch the same subsystem, making them impossible to pipeline. This is distinct from the **file-level conflicts** SAW already manages within a feature.

The upfront plan doesn't eliminate the file-level check — it supplements it. The session plan says "features A and C can pipeline"; the runtime disjointness check says "Agent B in feature A's Wave 2 owns `tools.go`; confirm the pipelined scout for C doesn't also change `tools.go` at this moment."

Two levels of conflict detection, each operating at its appropriate granularity.

### Feature Reordering for Throughput

With the full landscape visible upfront, features can be **reordered** to minimize pipeline bubbles. A feature with no file conflicts and a fast Wave 1 is a high-value fill feature — slot its scout and Wave 1 into gaps created by longer-running features. This is CPU scheduling applied to development work.

Example: if Feature D (CLI commands) is independent and takes 15 minutes, it should fill the gap during Feature A's 20-minute Wave 2 rather than running sequentially after Feature A completes. The session planner can see this and schedule accordingly. An ad-hoc orchestrator cannot.

### Two Modes, One Protocol

Upfront session planning and opportunistic pipelining are not competing approaches — they are the same technique applied at different information levels:

| Mode | When to use | Information required |
|------|-------------|---------------------|
| **Session planning** | Full feature list known at session start | All features + their approximate file domains |
| **Opportunistic pipelining** | Feature discovered mid-session | Just the next feature |

Both use the same disjointness check. Both produce IMPL docs that feed into `/saw wave`. The session plan is simply the upfront version of the decision the orchestrator would otherwise make one feature at a time.

The canonical form of the protocol should describe both modes clearly and treat session planning as the preferred approach when the full picture is available.

---

## Open Questions

1. **Should the orchestrator automatically launch pipelined scouts**, or should it always be a manual decision? The risk of getting it wrong (stale contracts) argues for manual. The overhead of always checking argues for automation.

2. **What is the right overlap policy?** Strict (no shared files at all) vs. assessed (scout reads the file but the agent's changes don't affect the scout's contracts). The strict policy is simpler and safer.

3. **Does the scout need a "disjoint read domain" declaration in the IMPL doc?** If the IMPL doc declared "this scout assumed main HEAD at commit {sha} for file X," the orchestrator could invalidate and re-run the scout if that file changed before Wave 1 launches.

4. **How does this interact with the human review step?** The orchestrator is the sole human-facing channel, so the pipeline launch decision is always the orchestrator's to make — not the human's directly. But if the human must approve each IMPL doc before waves launch, the benefit only materializes if that approval happens before the active wave finishes. When human review is the bottleneck, the review window is not dead time and the pipelined scout yields no wall-clock savings — the IMPL doc simply sits ready earlier than it can be used.

---

## Summary

Pipeline scouting is a scheduling optimization on the synchronous orchestrator — not a structural change to the protocol. The orchestrator's role, execution model, and status as the sole human-facing reporting channel are unchanged. The only difference is what the orchestrator does during wave execution gaps: rather than waiting idle, it launches the next feature's scout as an additional async agent and processes that result alongside the wave completion.

The prerequisite is a single disjoint-read-domain check. The bottleneck it eliminates is the serial dependency between independent features. The benefit compounds: each pipelined scout removes one wait window from the critical path, and with upfront session planning, multiple scouts can run in parallel before any code is written.
