# Interview Mode: Protocol vs. Implementation Gap Analysis

**Protocol spec:** `protocol/interview-mode.md` (v0.19.0, rule E39)
**Analysis date:** 2026-03-25
**Repos examined:**
- `scout-and-wave-go` — CLI + engine (`cmd/sawtools/interview_cmd.go`, `pkg/interview/`)
- `scout-and-wave-web` — HTTP API + React UI (`pkg/api/interview_handlers.go`, `web/src/components/InterviewLauncher.tsx`)
- `scout-and-wave` — Orchestrator skill (`implementations/claude-code/prompts/saw-skill.md`)

---

## 1. Protocol Summary

E39 specifies an interactive requirements-gathering alternative to the Scout Agent. Key behaviors:

- Command: `sawtools interview "<description>"` / `/saw interview "<description>"`
- 6 sequential phases: overview, scope, requirements, interfaces, stories, review
- State persisted to `docs/INTERVIEW-<slug>.yaml` after each turn
- Resumable via `sawtools interview --resume <path>`
- Output: `docs/REQUIREMENTS.md` (format tailored for `/saw bootstrap` or `/saw scout`)
- Adds `INTERVIEWING` state to the state machine
- `INTERVIEWING → SCOUT_PENDING` on completion
- Error handling: max-questions truncation, invalid phase transition (panic), stdin-EOF exit-code 2
- Skip semantics: empty slice `[]` vs nil means "asked and skipped" vs "not yet asked"
- "back" navigation: not mentioned in protocol
- LLM mode: documented as "not yet implemented" placeholder

---

## 2. What Is Actually Implemented

### 2.1 CLI (`scout-and-wave-go`)

**`cmd/sawtools/interview_cmd.go`** — fully wired `sawtools interview` command.
- Flags: `--mode`, `--max-questions`, `--project-path`, `--resume`, `--output`, `--docs-dir`, `--non-interactive`
- Start and resume flows both implemented
- Question-answer loop with stdin scanning
- Requirements preview before `_confirm` question
- Phase-aware progress formatted as `[overview: 2/4 | Next: Scope]`
- stdin-EOF handling: saves state, prints resume instruction, exits with code 2
- On completion: calls `mgr.Compile()`, saves INTERVIEW doc, prints summary with "Next step: /saw bootstrap or /saw scout"

**`pkg/interview/types.go`** — complete type definitions matching the YAML schema.

**`pkg/interview/deterministic.go`** — `DeterministicManager` fully implements the `Manager` interface:
- `Start`, `Resume`, `Answer`, `Compile`, `Save`
- `ValidateRequiredField`: blocks empty or "skip" on required fields, returns re-prompt with error hint
- `HandleBackCommand`: undocumented "back" navigation (revert cursor, clear last spec field, recalculate phase)
- `splitCSV`: parses comma-separated or newline answers into slices
- Skip semantics: correctly sets empty slice `[]` vs nil
- Phase transition logic via `checkPhaseTransition` and `allXxxQuestionsAsked` helpers

**`pkg/interview/phase_questions.go`** — fixed question bank (15 questions + `_confirm`) matching protocol exactly.

**`pkg/interview/compiler.go`** — `CompileToRequirements` implemented and registered via `init()`.

### 2.2 Web API (`scout-and-wave-web`)

**`pkg/api/interview_handlers.go`** — 4 endpoints registered in `server.go`:

| Endpoint | Method | Handler |
|----------|--------|---------|
| `/api/interview/start` | POST | `handleInterviewStart` |
| `/api/interview/{runID}/events` | GET | `handleInterviewEvents` (SSE) |
| `/api/interview/{runID}/answer` | POST | `handleInterviewAnswer` |
| `/api/interview/{runID}/cancel` | POST | `handleInterviewCancel` |

In-memory run state via `sync.Map`; goroutine-per-interview drives state machine. SSE event types: `question`, `answer_recorded`, `phase_complete`, `complete`, `error`.

**`web/src/components/InterviewLauncher.tsx`** — React component consuming the SSE API with full start/answer/cancel/complete lifecycle.

**`web/src/lib/apiClient.ts`** — `sawClient.interview` namespace with `start`, `subscribeEvents`, `answer`.

---

## 3. Gap Table

| # | Protocol Requirement | Implementation Status | Severity |
|---|---------------------|-----------------------|----------|
| G1 | `INTERVIEWING` state in state machine (`state-machine.md`) | MISSING | HIGH |
| G2 | `INTERVIEWING → SCOUT_PENDING` transition on completion | MISSING | HIGH |
| G3 | REQUIREMENTS.md format matches spec (Overview / Scope / Requirements / Interfaces / User Stories / Open Questions sections) | PARTIAL | HIGH |
| G4 | Web resume: `sawtools interview --resume <path>` equivalent via HTTP API | MISSING | MEDIUM |
| G5 | "Invalid phase transition" panics (not user-recoverable errors) | PARTIAL | MEDIUM |
| G6 | Max-questions truncation: compile partial requirements + add Warnings section | PARTIAL | MEDIUM |
| G7 | `--non-interactive` flag behavior documented | MISSING | LOW |
| G8 | `back` navigation (revert to previous question) documented | MISSING | LOW |
| G9 | Frontend phase labels match protocol phases | PARTIAL | LOW |
| G10 | `phase_complete` SSE event emitted by server | MISSING | LOW |
| G11 | `id` field in YAML is UUID format per spec | PARTIAL | LOW |

---

## 4. Gap Details

### G1 — `INTERVIEWING` state missing from state-machine.md (HIGH)

`protocol/state-machine.md` (v0.21.0) does not mention `INTERVIEWING` at all. Its state catalog lists: `SCOUT_PENDING`, `SCOUT_VALIDATING`, `REVIEWED`, `SCAFFOLD_PENDING`, `WAVE_PENDING`, `WAVE_EXECUTING`, `WAVE_MERGING`, `WAVE_VERIFIED`, `BLOCKED`, `COMPLETE`, `NOT_SUITABLE`.

`interview-mode.md` says: "Interview mode adds a new state to the Scout-and-Wave state machine: `IDLE → INTERVIEWING`" but the state machine document was never updated to include it.

The Go implementation treats interview as an independent execution path (a separate command, separate goroutine, separate in-memory state) with no connection to the SAW state machine as maintained by the orchestrator.

**Recommended action:** Add `INTERVIEWING` to `state-machine.md` with its entry/exit conditions and transitions.

### G2 — `INTERVIEWING → SCOUT_PENDING` transition not wired (HIGH)

The protocol specifies that completing an interview transitions the system to `SCOUT_PENDING`, making the generated `REQUIREMENTS.md` ready for `/saw bootstrap` or `/saw scout`. Neither the CLI nor the web app performs this state transition or signals the orchestrator. The CLI prints a static text prompt ("Next step: /saw bootstrap or /saw scout") but does not invoke `sawtools` or write any state that the SAW orchestrator monitors.

The web UI's completion screen provides a "Launch Scout" button that calls `onLaunchScout(description)` — this is close to the intent, but it passes the original `description` string, not the path to `REQUIREMENTS.md`, which may lose context compared to what the protocol envisions.

**Recommended action:** Either document that the transition is manual (user runs `/saw scout` after interview) or wire the CLI to emit a machine-readable signal the orchestrator can detect.

### G3 — REQUIREMENTS.md output format diverges from protocol (HIGH)

The protocol specifies this section structure:
```
# <title>
## Overview / ## Scope / ## Requirements / ## Interfaces / ## User Stories / ## Open Questions
```

The actual `compiler.go` (`CompileToRequirements`) generates a completely different structure:
```
# Requirements: <title>
## Language & Ecosystem
## Project Type
## Deployment Target
## Key Concerns (3-6 major responsibility areas)
## Storage
## External Integrations
## Source Codebase (if porting/adapting)
## Architectural Decisions Already Made
```

This structure is tailored to the `saw-bootstrap.md` intake format, not the generic markdown the protocol spec describes. The sections are also constructed from field remappings: for example, `Interfaces.External` feeds "Language & Ecosystem" (filtered for "language" keyword), `Scope.InScope` feeds "Key Concerns", `Requirements.Constraints` + `Requirements.NonFunctional` are merged into "Architectural Decisions Already Made".

Critically, the following protocol-specified sections have **no equivalent** in the compiled output:
- `## Overview` (goal, success metrics, non-goals)
- `## Scope` (in-scope, out-of-scope, assumptions as distinct items)
- `## Requirements` (functional requirements)
- `## User Stories`
- `## Open Questions`

The protocol says "The format of REQUIREMENTS.md is structured markdown with sections corresponding to the 6 interview phases." The implementation discards phase structure in favor of bootstrap-specific sections.

**Recommended action:** Align the spec with the actual bootstrap-oriented output format, or add a second compile mode that emits the phase-structured format. The bootstrap format is arguably more useful — the spec may just need updating.

### G4 — Web API has no resume endpoint (MEDIUM)

The CLI implements `--resume <path>` via `mgr.Resume(docPath)` which reads `INTERVIEW-<slug>.yaml` from disk and restores state. The HTTP API (`interview_handlers.go`) has no `/api/interview/resume` endpoint and no mechanism to resume an in-progress interview after a server restart or browser refresh. In-memory `interviewRun` state is lost on server restart. The `InterviewStartRequest` struct has no `resume_path` field.

**Recommended action:** Add `POST /api/interview/resume` with body `{"doc_path": "..."}`, or store run state to disk and reload it on resume. The `DeterministicManager.Resume()` already exists in the Go package — the handler just needs to call it.

### G5 — Invalid phase transition: panic vs. graceful (MEDIUM)

The protocol says: "If the internal state machine tries to skip a phase or return to a prior phase, this is a bug and should fail fast with a panic."

The `checkPhaseTransition` function (`deterministic.go` lines 134–163) transitions forward-only and has no guard that panics on backward or skip transitions. `recalculatePhase` actively resets the phase to `PhaseOverview` and replays transitions, which is a legitimate internal operation but is not guarded against mis-use. No panic path exists anywhere in the interview package for invalid phase transitions.

**Recommended action:** Either add a panic guard in `checkPhaseTransition` for backward transitions, or update the protocol to reflect the actual design (recalculate-from-scratch approach when going back).

### G6 — Max-questions truncation Warnings section not implemented (MEDIUM)

The protocol specifies: if `max_questions` turns are exhausted before all phases are complete, the orchestrator should "Compile the partial requirements into REQUIREMENTS.md anyway" and "Add a warning section: `## Warnings\n- Interview truncated at max_questions limit. Some phases incomplete.`"

The CLI's `Answer` loop runs until `question == nil`, and `CompileToRequirements` never adds a Warnings section under any condition. The truncation path is not tested or handled distinctly from normal completion.

**Recommended action:** Add truncation detection in the compile step (check if not all required fields are populated) and append the Warnings section.

### G7 — `--non-interactive` flag undocumented in protocol (LOW)

The `--non-interactive` flag is implemented but not mentioned in `interview-mode.md`. The flag is accepted by the CLI and visible in `--help` output but has no behavioral difference from normal stdin piping in the current implementation (the flag variable `nonInteractive` is declared but never read in the command body). The `Long` description in `newInterviewCmd` documents it as "Read answers from stdin without prompts (for testing/piping)" but the prompts are printed regardless.

**Recommended action:** Either remove the flag (it's currently a no-op), implement its documented behavior (suppress prompts when set), and add it to the protocol.

### G8 — `back` navigation undocumented (LOW)

`HandleBackCommand` in `deterministic.go` (lines 175–208) accepts the answer "back" to revert to the previous question. The protocol document makes no mention of this feature. The implementation clears the last spec field, decrements `QuestionCursor`, recalculates phase, and saves state. This is a user-visible interaction behavior (typing "back" changes what question is shown) with no protocol coverage.

**Recommended action:** Document "back" navigation in `interview-mode.md` under a "Navigation Commands" section, including the semantics that it cannot go back from the first question.

### G9 — Frontend phase labels don't match protocol phase names (LOW)

`InterviewLauncher.tsx` line 33 defines:
```js
const PHASES = ['Goals', 'Scope', 'Users', 'Constraints', 'Integration', 'Quality']
```

The protocol (and Go types) define 6 phases as: `overview`, `scope`, `requirements`, `interfaces`, `stories`, `review`.

The frontend uses human-friendly aliases — `Goals` for `overview`, `Users` for `stories`, `Constraints` for `requirements`, `Integration` for `interfaces`, `Quality` for `review` — but phase matching logic (`phaseIndex = PHASES.findIndex(p => p.toLowerCase() === phase.toLowerCase())`) will always fail (0 matches) because the server emits Go phase strings (`"overview"`, `"scope"`, etc.) that don't match the frontend aliases. The progress bar will always show Phase 1/6 regardless of actual progress.

**Recommended action:** Either align frontend labels to protocol phase names, or map server phase names to display labels explicitly.

### G10 — `phase_complete` SSE event never emitted by server (LOW)

`InterviewLauncher.tsx` registers a listener for `phase_complete` events (line 120). `interview_handlers.go`'s `runInterviewLoop` never publishes a `phase_complete` event — it only emits `question`, `answer_recorded`, `complete`, and `error`. The frontend handles this gracefully (non-fatal catch block), but the phase transition notification feature is dead.

**Recommended action:** Emit a `phase_complete` SSE event in `runInterviewLoop` when `updatedDoc.Phase` changes between loop iterations.

### G11 — UUID format for `id` field (LOW)

The protocol schema specifies `id: string # Unique identifier (UUID)`. The `newID()` function generates 16 random bytes formatted as lowercase hex (32 hex chars), not a standard UUID (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). This is a cosmetic issue with no behavioral impact.

**Recommended action:** Use `uuid.New().String()` or format the bytes with UUID hyphenation, or update the protocol to say "random hex ID" instead of "UUID".

---

## 5. Behaviors in Code Not Covered by Protocol

| Behavior | Location | Notes |
|----------|----------|-------|
| "back" navigation command | `pkg/interview/deterministic.go:HandleBackCommand` | Allows reverting to previous question; not in spec |
| `--non-interactive` flag | `cmd/sawtools/interview_cmd.go` | No-op currently; not in spec |
| Requirements preview before `_confirm` | `cmd/sawtools/interview_cmd.go:111-114` | Shows preview of REQUIREMENTS.md before final confirmation |
| `phase_complete` SSE event (planned) | `web/src/components/InterviewLauncher.tsx:120` | Frontend handles event but server never emits it |
| Answer timeout in web API | `pkg/api/interview_handlers.go:272` | 5-second timeout on answer channel; returns HTTP 409 if goroutine not ready |
| `cancel` HTTP endpoint | `pkg/api/interview_handlers.go:handleInterviewCancel` | Cancels running interview via context; not in protocol |
| `sawClient.interview` TS namespace cast | `web/src/components/InterviewLauncher.tsx:24-26` | Cast from `any` — TypeScript type safety gap, not a protocol issue |

---

## 6. Recommended Actions by Priority

### High Priority

1. **Update `state-machine.md`** to add the `INTERVIEWING` state, entry/exit conditions, and the `IDLE → INTERVIEWING → SCOUT_PENDING` transition path. This closes G1 and G2 together.

2. **Reconcile REQUIREMENTS.md format** (G3): the actual compiled format is bootstrap-oriented, not phase-mirroring. Either:
   - Update `interview-mode.md` Output Contract section to describe the actual format, or
   - Implement both formats with a `--format bootstrap|phases` flag.

### Medium Priority

3. **Add web resume endpoint** (G4): implement `POST /api/interview/resume` that calls `DeterministicManager.Resume()`. The Go-side method already exists.

4. **Implement max-questions Warnings section** (G6): add truncation detection in `CompileToRequirements` and emit the `## Warnings` section the protocol requires.

5. **Clarify phase-transition panic behavior** (G5): either add the panic guard as specified or update the protocol to describe the recalculate-from-scratch approach that "back" navigation uses.

### Low Priority

6. **Fix frontend phase label matching** (G9): the progress bar is always at Phase 1 due to label mismatch.

7. **Emit `phase_complete` SSE event** (G10): the frontend handler is already there.

8. **Document `back` navigation** (G8) and the `--non-interactive` flag (G7) in `interview-mode.md`.

9. **Fix or remove `--non-interactive` flag** (G7): currently a no-op; either implement prompt suppression or remove it.
