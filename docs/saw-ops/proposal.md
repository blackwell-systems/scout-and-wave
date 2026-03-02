# SAW Operations Agent — Design Proposal

**Status:** Proposal
**Date:** 2026-03-02

---

## Motivation

The Orchestrator is synchronous by design: it serializes all protocol state transitions and is the sole reporting channel to the human. That property is non-negotiable. But it creates a latency window during the merge phase where the Orchestrator is unavailable: it is executing `go build`, `go test`, copying files, and cleaning up worktrees while the user waits with no way to interact.

For small waves with fast builds, this window is acceptable. For waves with ≥2 agents and build/test cycles over 30 seconds, it is a meaningful gap. The user cannot ask questions, inspect status, or redirect work while the Orchestrator is blocked on mechanical steps.

The Operations Agent is an optional fourth participant that handles those mechanical steps as an asynchronous agent, freeing the Orchestrator to remain interactive while verification runs. The Orchestrator delegates; it does not execute.

---

## Role Definition

### What the Operations Agent owns

| Responsibility | Notes |
|---|---|
| Parse completion report statuses | Halt if any agent status is `partial` or `blocked` |
| Conflict prediction | Flag overlapping file lists; do not resolve |
| File copy or merge from worktrees to main | `cp` for uncommitted; `git merge --no-ff` if agents committed |
| Post-merge verification | `go build ./...`, `go test ./... -race`, `go vet ./...` (or project-equivalent) |
| Worktree cleanup | `git worktree remove`, `git branch -d` |
| Tick IMPL doc status checkboxes | `- [ ]` → `- [x]` for completed agents |
| Write structured merge report | See Merge Report Format below |

### What the Operations Agent does not own

| Responsibility | Owner |
|---|---|
| Reviewing interface deviations | Orchestrator judgment |
| Deciding whether a deviation breaks downstream agents | Orchestrator judgment |
| Go/no-go decisions between waves | Orchestrator judgment |
| Modifying agent prompt sections in the IMPL doc | Orchestrator |
| Launching any other agents (Scout, Wave, or another Ops Agent) | Orchestrator |
| Advancing protocol state | Orchestrator |
| `git push` or any remote operations | Out of protocol scope |
| Modifying source files except by copying from agent worktrees | Hard constraint |

The boundary is the same boundary that distinguishes Scout from Wave Agent: execution is delegated, but decision authority stays with the Orchestrator. The Operations Agent produces a structured report; the Orchestrator reads it and decides.

---

## Invariant I7

**I7: Operations Agent state isolation.** The Operations Agent executes the mechanical merge procedure and produces a merge report. It does not advance protocol state, does not make go/no-go decisions, does not launch Wave or Scout agents, and does not modify agent prompts. Only the Orchestrator reads the merge report and advances state.

I7 is the enforcement boundary for the Operations Agent's scope. Any action the Ops Agent takes that causes a state transition — including launching another agent or updating an agent's prompt section in the IMPL doc — is an I7 violation. If the Ops Agent finds itself about to take such an action, it must stop and report the situation to the Orchestrator in the merge report instead.

---

## Merge Report Format

The Operations Agent writes a structured merge report into the IMPL doc under the heading `### Ops Agent — Wave N Merge Report`. The report is machine-readable YAML; the Orchestrator parses it before advancing state.

```yaml
wave: N
status: complete | failed | partial
files_merged:
  - internal/store/attribution.go
  - internal/store/replay.go
build: pass | fail
build_output: ""        # truncated stderr if fail
tests: pass | fail
test_output: ""         # truncated stderr if fail
worktrees_cleaned:
  - wave1-agent-A
  - wave1-agent-B
deviations:
  - agent: A
    description: "store.ModelPricing defined locally (circular import)"
    downstream_action_required: true
    affects: [wave2-agent-C, wave2-agent-E]
recommendation: proceed | halt
halt_reason: ""         # populated if recommendation is halt
```

**`recommendation: halt`** when: any agent status is `partial` or `blocked`, build fails, or tests fail.

**`recommendation: proceed`** otherwise.

The recommendation is advisory. The Orchestrator reviews the report and makes the final go/no-go decision. The Orchestrator must review `deviations` regardless of the recommendation; a `recommendation: proceed` with unresolved downstream deviations does not mean those deviations can be skipped.

---

## When to Use It

The Operations Agent pays for itself when all three conditions hold:

1. The wave has ≥2 agents (single-agent waves are fast to merge manually)
2. The build/test cycle is >30 seconds
3. The user may want to interact with the Orchestrator during verification

When a wave has only one agent or the build cycle is fast, the overhead of launching and coordinating an additional async agent exceeds the interactivity gain. The Operations Agent is optional. The base merge procedure in `prompts/saw-merge.md` remains valid and is the default.

The Orchestrator makes the decision to use an Ops Agent at the start of the merge phase, after all wave agents have reported. It is not a session-level configuration; it is a per-wave decision.

---

## Workflow

### Current: Orchestrator blocked during merge

```
Wave agents complete
        ↓
Orchestrator: parse reports
Orchestrator: conflict prediction         ← user cannot interact
Orchestrator: go build ./...             ← user cannot interact
Orchestrator: go test ./... -race        ← user cannot interact
Orchestrator: worktree cleanup           ← user cannot interact
Orchestrator: tick checkboxes
Orchestrator: review deviations
        ↓
Orchestrator: go/no-go → launch next wave
```

### With Operations Agent: Orchestrator interactive during verification

```
Wave agents complete
        ↓
Orchestrator: launch Ops Agent (background) → [Orchestrator is interactive]
        ↓                                              ↓
Ops Agent: parse reports                    User can ask questions,
Ops Agent: conflict prediction              inspect status, redirect work
Ops Agent: go build ./...
Ops Agent: go test ./... -race
Ops Agent: worktree cleanup
Ops Agent: tick checkboxes
Ops Agent: write merge report
        ↓
Orchestrator: read merge report
Orchestrator: review deviations
Orchestrator: go/no-go → launch next wave
```

The Orchestrator's responsibilities at wave boundaries do not shrink. Deviation review, downstream prompt updates, and the go/no-go decision stay with the Orchestrator. The only change is that the mechanical steps run asynchronously instead of inline.

The SAW tag for the Ops Agent launch: `[SAW:ops:wave{N}] merge + verify wave N`.

---

## claudewatch Integration

The `[SAW:ops:wave{N}]` tag gives claudewatch a new event type. Session dashboards can report per-phase timing rather than only per-agent timing:

```
Wave 1:  Agent A   45s  $0.18
         Agent B   52s  $0.21
         Ops       23s  $0.04   ← merge + verify phase
```

The Ops Agent appears as a distinct participant in `get_saw_wave_breakdown`, making the merge phase visible and measurable. This is the same observability rationale as the Scout tag and Wave agent tags: structured tagging at launch time, zero additional overhead.

---

## Failure Handling

If the Operations Agent crashes mid-merge:

1. The Orchestrator runs crash recovery directly following `saw-merge.md` Step 7 (Crash Recovery).
2. Do not re-launch the Ops Agent. The merge procedure is not idempotent; re-running it risks double-merging commits.
3. Use `git log --merges --oneline` to identify which worktree branches are already in main's history. Skip those. Proceed only with worktrees not yet merged.

To make crash recovery per-agent rather than per-wave, the Ops Agent must merge each agent's worktree individually and commit before moving to the next. A batch merge (all agents in one commit) makes recovery impossible without revert. Individual merges mean a crash can be recovered from the last successful per-agent commit.

---

## v1 Scope and Implementation Plan

### v1: Mechanical steps only

The first implementation covers steps 1–5 of the merge procedure:

1. Parse completion report statuses (halt on `partial` or `blocked`)
2. Conflict prediction (flag overlaps; do not resolve)
3. Merge each agent individually (`git merge --no-ff` or `cp`)
4. Run post-merge verification (`go build`, `go test`, `go vet`)
5. Worktree cleanup
6. Tick IMPL doc status checkboxes
7. Write merge report

Deviation analysis stays with the Orchestrator in v1. The Ops Agent surfaces deviations in the `deviations` field of the merge report; the Orchestrator reviews them and decides on downstream prompt updates. The latency window is eliminated without touching the boundary where Orchestrator judgment is required.

### Files to create or update

| File | Change |
|---|---|
| `prompts/saw-ops.md` | New. The Operations Agent prompt, parallel to `saw-merge.md`. Contains the v1 scope above. |
| `PROTOCOL.md` | Add Operations Agent as optional participant in the Participants section. Add I7 to the Invariants section. Add to the Protocol Violations table: `Ops Agent launches another agent → I7`. Update the Reference Implementation table. |
| `prompts/saw-skill.md` | Add optional Ops Agent launch in the merge step of the wave execution block. Describe the decision criteria (≥2 agents, build >30s, interactivity needed). |

### Deferred to v2

**Deviation proposal generation.** In v2, the Ops Agent proposes prompt patches for downstream agents (based on detected deviations) and includes them in the merge report for Orchestrator approval. The Orchestrator approves or modifies the patches, then applies them to the IMPL doc. This reduces the Orchestrator's post-merge work while preserving its decision authority.

This scope is intentionally excluded from v1. The deviation-to-prompt-patch reasoning requires the same judgment that currently lives in `saw-merge.md` Step 3. Delegating it before the v1 boundary is proven would mix two concerns. Prove the mechanical delegation first; add reasoning delegation once the report format and Orchestrator review workflow are stable.
