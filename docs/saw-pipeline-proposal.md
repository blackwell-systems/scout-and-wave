# SAW Pipeline Proposal: Cross-Feature Scout Pipelining

**Status:** Proposal — observed in practice, not yet canonical

**Discovered:** claudewatch session, 2026-03-01 — session project tagging feature (Wave 2 running) overlapped with live-session-read scout

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

A SAW scout is always read-only — it analyzes source files and writes only the IMPL doc. It never modifies source. This means:

- No write conflict with active agents possible
- The only risk is reading code that an active agent is simultaneously modifying in a worktree
- If the scout reads stale (pre-modification) source for files an active agent owns, its interface contracts may be wrong

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

The review window — merge, verify, tick checkboxes, read agent reports — is dead time for the orchestrator. The scout fills it. By the time the orchestrator finishes reviewing Wave N's merge, the IMPL doc for Feature N+1 is waiting.

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

> **Pipeline opportunity:** If the next feature is known, check whether its expected file changes are disjoint from this wave's ownership. If so, a background scout for the next feature can run during this wave's execution time. See `saw-pipeline.md`.

### 3. Amendment to `prompts/scout.md`

Scouts should emit a **"Files Read"** section alongside "Files Changed" in the IMPL doc. The distinction:

- **Files Changed** — files the agents will modify (required for disjoint ownership enforcement)
- **Files Read** — files the scout read to understand context (needed for the incoming pipeline safety check)

The orchestrator checks "Files Read" of the incoming scout against "Files Changed" of the active wave, not "Files Changed" of the incoming scout. This is more conservative and catches cases where the scout's interface contracts depend on understanding a file that an active agent is rewriting.

---

## Open Questions

1. **Should the orchestrator automatically launch pipelined scouts**, or should it always be a manual decision? The risk of getting it wrong (stale contracts) argues for manual. The overhead of always checking argues for automation.

2. **What is the right overlap policy?** Strict (no shared files at all) vs. assessed (scout reads the file but the agent's changes don't affect the scout's contracts). The strict policy is simpler and safer.

3. **Does the scout need a "disjoint read domain" declaration in the IMPL doc?** If the IMPL doc declared "this scout assumed main HEAD at commit {sha} for file X," the orchestrator could invalidate and re-run the scout if that file changed before Wave 1 launches.

4. **How does this interact with the human review step?** The proposal assumes the orchestrator (Claude) makes the pipeline launch decision. If the human reviews IMPL docs before every wave, the pipeline benefit only materializes if the human approves the pipelined scout before the active wave finishes — otherwise the review is the bottleneck, not scout time.

---

## Summary

Pipeline scouting is the observation that the bottleneck in multi-feature SAW work is human review time, not AI execution time. By filling wave execution gaps with the next feature's scout, the IMPL doc is ready for review at the same moment the previous wave's merge completes. The cost is a single disjoint-read-domain check before launching the scout. The constraint is light and the benefit compounds across features.
