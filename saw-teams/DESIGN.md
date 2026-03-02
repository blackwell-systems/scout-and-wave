# SAW-Teams: Agent Teams Execution Layer

Alternate execution layer for the SAW protocol using Claude Code Agent Teams
as the agent runtime. Same invariants (I1–I6), same IMPL doc artifact, same
Scout. Different plumbing for wave execution.

**Status:** Prompt set complete (v0.1.0). Blocked on Agent Teams stabilizing
(currently experimental with known limitations). Ready for integration testing
when Agent Teams is stable.

## Motivation

SAW today uses the raw Agent tool with `run_in_background` and manual git
worktrees. This works but has friction:

- No inter-agent communication during execution
- Opaque agent progress until completion
- Manual worktree lifecycle (create, verify, cleanup)
- One-way communication: prompt in, completion report out

Agent Teams provides the primitives that would eliminate this friction:
teammate spawning, inter-agent messaging, shared task list with dependencies,
progress visibility, and native worktree management.

## Design Principle

**Same protocol, different execution.** The invariants don't change:

| Invariant | SAW (current) | SAW-Teams |
|-----------|--------------|-----------|
| I1: Disjoint file ownership | Scout verifies, Orchestrator enforces | Scout verifies, lead enforces via spawn prompts |
| I2: Verification gates | Agent runs build/test in worktree | Teammate runs build/test in worktree |
| I3: Wave ordering | Orchestrator blocks between waves | Lead blocks between waves via task dependencies |
| I4: IMPL doc is source of truth | Agents read IMPL doc | Teammates read IMPL doc |
| I5: Agents commit before reporting | Agent commits to worktree branch | Teammate commits to worktree branch |
| I6: Role separation | Orchestrator doesn't do agent work | Lead doesn't do teammate work |

The IMPL doc, Scout phase, suitability gate, and merge procedure are
unchanged. Only the wave execution step differs.

## What Changes

### Skill router (`saw-teams-skill.md`)

Replaces `saw-skill.md` for users who have Agent Teams enabled. The key
difference is in wave execution:

**Current SAW:**
```
For each agent in the wave:
  Launch Agent tool with run_in_background: true, isolation: "worktree"
Wait for all agents to complete
Read completion reports from IMPL doc
```

**SAW-Teams:**
```
Create an Agent Team for the wave
For each agent in the wave:
  Spawn teammate with IMPL doc agent prompt as spawn context
  Assign tasks with file ownership constraints
Wait for all teammates to finish
Collect completion reports (structured messages or IMPL doc sections)
Clean up team
```

### Agent template → Teammate prompt

The 9-field agent template needs adaptation:

| Field | Current (Agent tool) | SAW-Teams (teammate) |
|-------|---------------------|---------------------|
| Field 0: Isolation | Self-healing cd + verify worktree | Agent Teams manages worktree natively |
| Field 1: File ownership | Listed in prompt | Listed in prompt + enforced by lead |
| Field 2: Interfaces to implement | Exact signatures | Exact signatures (unchanged) |
| Field 3: Interfaces to call | Prior wave output | Prior wave output + can message teammate to clarify |
| Field 4: What to implement | Functional description | Functional description (unchanged) |
| Field 5: Tests | Named tests | Named tests (unchanged) |
| Field 6: Verification gate | Build/vet/test commands | Build/vet/test commands (unchanged) |
| Field 7: Constraints | Hard rules | Hard rules (unchanged) |
| Field 8: Report | Append YAML to IMPL doc | Message lead with structured report |

### Completion reports

Current: agents append structured YAML to the IMPL doc under
`### Agent {letter} - Completion Report`.

SAW-Teams option A: teammates message the lead with structured completion
data. The lead writes all reports to the IMPL doc.

SAW-Teams option B: teammates still write to the IMPL doc directly (they
have filesystem access). Same as current, but with the option to message
the lead about deviations in real time rather than waiting for the report.

**Recommendation:** Option B (keep IMPL doc writes) with option A as a
supplement (message the lead about interface deviations immediately so the
lead can propagate to other active teammates). This gets the best of both:
persistent artifact + real-time deviation handling.

### Merge procedure

Largely unchanged. The lead (Orchestrator) runs the same merge protocol
from `saw-merge.md`. Agent Teams doesn't have a built-in merge concept;
the lead still needs to:

1. Parse completion reports
2. Predict conflicts from file lists
3. Review interface deviations
4. Merge each worktree branch
5. Run post-merge verification
6. Update IMPL doc

The difference: if a merge issue is found, the lead can message the
responsible teammate to clarify rather than guessing from the report.

### Wave barriers

Agent Teams uses task dependencies (task B is blocked by task A). SAW uses
strict wave barriers (all of wave N completes before wave N+1 starts).

Mapping: create all wave N tasks first. Create wave N+1 tasks with
`blockedBy` pointing to all wave N tasks. Teammates self-claim within their
wave. The dependency system enforces the barrier.

**Risk:** Agent Teams task dependencies are "fluid"; a teammate that
finishes early might idle instead of waiting cleanly for the barrier.
The lead may need to explicitly hold teammates between waves.

## What's New (SAW-Teams only)

### Live interface clarification

The biggest upgrade. When a teammate discovers a minor deviation from the
IMPL doc's interface contract, it can message the affected teammate directly:

```
Teammate B → Teammate A: "What's the exact field name for consecutive
errors? IMPL doc says ConsecutiveErrs but I see you exported
ConsecutiveErrors in the type."
```

This eliminates the most common source of post-merge friction: interface
deviations that are only discovered at merge time.

### Progress visibility

The lead can see all teammates' progress in real time. If a teammate is
stuck, the lead can redirect or spawn a replacement. Currently, the
Orchestrator has no visibility into agent progress until completion.

### Dynamic task reassignment

If a teammate finishes early, it can self-claim the next available task.
If a teammate is struggling, the lead can reassign work. Currently, agent
scope is fixed at launch time.

## Blocking Issues

Agent Teams is experimental with limitations that affect SAW-Teams:

1. **No session resumption:** if the lead crashes mid-wave, there's no way
   to resume teammates. SAW's current approach (worktree branches + IMPL
   doc state) survives crashes. SAW-Teams would lose in-progress teammates.

2. **One team per session:** multi-wave execution would need to create and
   clean up a team per wave. The overhead of team creation/cleanup per wave
   could negate the messaging benefits.

3. **No nested teams:** teammates can't spawn sub-agents. This is fine for
   SAW (wave agents don't spawn children), but limits future extensions.

4. **Permissions set at spawn:** all teammates inherit the lead's
   permissions. SAW agents currently get the same permissions anyway, so
   this is fine.

5. **Shutdown can be slow:** teammates finish their current tool call
   before shutting down. Could cause delays at wave boundaries.

## Migration Path

1. **Phase 0 (now):** Track Agent Teams stabilization. Watch for session
   resumption and multi-team support.

2. **Phase 1:** Prototype `saw-teams-skill.md` with the current Agent Teams
   API. Test on a real SAW-suitable feature. Measure: does inter-agent
   messaging reduce post-merge interface deviations?

3. **Phase 2:** If Phase 1 validates, develop the full prompt set
   (`saw-teams-skill.md`, adapted agent template, teammate-aware merge
   procedure).

4. **Phase 3:** Document when to use `saw` vs `saw-teams`. The default
   recommendation: `saw` for maximum portability and crash recovery,
   `saw-teams` when inter-agent communication is worth the experimental
   risk.

## File Plan

```
saw-teams/
  DESIGN.md                    ← this file
  saw-teams-skill.md    v0.1.0 ← alternate skill router (adapts saw-skill v0.3.4)
  teammate-template.md  v0.1.0 ← adapted agent template (adapts agent-template v0.3.4)
  saw-teams-merge.md    v0.1.0 ← teammate-aware merge (adapts saw-merge v0.4.2)
  saw-teams-worktree.md v0.1.0 ← worktree lifecycle (adapts saw-worktree v0.4.1)
```

The Scout prompt (`prompts/scout.md`) and IMPL doc format are unchanged.
The Scout doesn't know or care whether agents execute via raw Agent tool
or Agent Teams; it produces the same coordination artifact either way.
This is by design: the Scout is the planning layer, execution is swappable.
