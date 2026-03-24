# SAW-Teams: Agent Teams Execution Layer

Alternate execution layer for the SAW protocol using Claude Code Agent Teams
as the agent runtime. Same invariants (I1–I6), same IMPL doc artifact, same
Scout. Different plumbing for wave execution.

**Status:** Prompt set complete (v0.1.6). Synced to protocol v0.14.5. Hooks,
README, and spawn step fully specified. Blocked on Agent Teams stabilizing
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
| I2: Interface contracts precede parallel implementation | Scout defines contracts in IMPL doc; Scaffold Agent materializes them as type scaffold source files committed to HEAD after human review, before Wave 1 | Same; Scout and Scaffold Agent are not teammates, both run before any team exists. Scaffold files committed to HEAD before any team is created. |
| I3: Wave ordering | Orchestrator blocks between waves | Lead blocks between waves via control flow; future-wave tasks not created (tasks lost during team cleanup) |
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
| Field 0: Isolation | Self-healing cd + verify worktree | Same self-healing cd + verify worktree; lead pre-creates worktrees and passes path in spawn context |
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
`### Agent {ID} - Completion Report`.

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

### Protocol enforcement hooks (`TeammateIdle`, `TaskCompleted`)

Standard SAW discovers protocol violations (missing completion reports,
uncommitted changes) only when reading the IMPL doc after all agents finish.
Agent Teams fires `TeammateIdle` when a teammate tries to idle and
`TaskCompleted` when a task is being closed. SAW-Teams uses both to enforce
protocol compliance in real time:

- **`TeammateIdle`**: blocks idle if the IMPL doc completion report is missing
  or has no `status:` line. Sends the teammate back to complete the protocol.
- **`TaskCompleted`**: blocks task closure if the IMPL doc write hasn't
  happened yet. Enforces the I4 write-before-close ordering.

This is the primary protocol-enforcement advantage of saw-teams over standard
SAW. Hook scripts live in `saw-teams/hooks/` and documentation in `hooks.md`.

Without hooks the protocol still works via lead-reads-reports, but timing
degrades from real-time to post-hoc discovery.

### Dynamic task reassignment (rejected)

Dynamic task reassignment was considered but explicitly rejected: self-claiming
tasks at runtime violates I1 (disjoint file ownership is assigned at IMPL doc
time, not runtime). The teammate-template prohibits self-claiming and prohibits
the lead from reassigning file ownership during a wave. If a teammate finishes
early, it messages the lead; it does not self-assign. This is intentional.

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
  README.md                    ← setup guide (enable flag, display modes, hooks)
  example-settings.json        ← copy to .claude/settings.json; all required fields
  saw-teams-skill.md    v0.1.6 ← alternate skill router (adapts saw-skill v0.3.9)
  teammate-template.md  v0.1.3 ← adapted agent template (adapts agent-template v0.3.8)
  saw-teams-merge.md    v0.1.4 ← teammate-aware merge (adapts saw-merge v0.4.4)
  saw-teams-worktree.md v0.1.4 ← worktree lifecycle (adapts saw-worktree v0.4.3)
  hooks.md              v0.1.0 ← TeammateIdle + TaskCompleted hook documentation
  hooks/
    teammate-idle-saw.sh       ← TeammateIdle enforcement script
    task-completed-saw.sh      ← TaskCompleted enforcement script
```

The Scout prompt (`prompts/scout.md`) and IMPL doc format are unchanged.
The Scout doesn't know or care whether agents execute via raw Agent tool
or Agent Teams; it produces the same coordination artifact either way.
This is by design: the Scout is the planning layer, execution is swappable.
