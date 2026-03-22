# Interview Mode: Deterministic Requirements Gathering

**Version:** 0.19.0

This document specifies the interview mode protocol (E39), which provides a structured alternative to the Scout Agent for requirements gathering when the user needs more guidance or wants to build requirements incrementally.

---

## E39: Interview Mode (Deterministic Requirements Gathering)

**Trigger:** User invokes `/saw interview "<description>"` (in Claude Code) or `sawtools interview "<description>"` (CLI)

**Rule:** The orchestrator enters an INTERVIEWING state and conducts a structured question-and-answer session with the user. This is an alternative entry point to the Scout Agent pathway — instead of generating an IMPL doc in one turn, the orchestrator guides the user through explicit requirements gathering, then produces a REQUIREMENTS.md file suitable for `/saw bootstrap` or `/saw scout`.

### State Machine

Interview mode adds a new state to the Scout-and-Wave state machine:

```
IDLE → INTERVIEWING (on /saw interview command)
INTERVIEWING → SCOUT_PENDING (on interview completion, REQUIREMENTS.md written)
```

The INTERVIEWING state is terminal for the interview process — it either completes (writes REQUIREMENTS.md and transitions to SCOUT_PENDING) or the user pauses/abandons it. There is no automatic retry or failure recovery; if the user exits, they must explicitly resume.

### Interview Structure

An interview consists of **6 sequential phases**, each gathering a specific category of requirements:

1. **overview** — Title, goal, success metrics, non-goals
2. **scope** — In-scope items, out-of-scope items, assumptions
3. **requirements** — Functional requirements, non-functional requirements, constraints
4. **interfaces** — Data models, APIs, external dependencies
5. **stories** — User stories or use cases
6. **review** — Summary and confirmation

The interview progresses linearly through phases; each phase asks a deterministic set of questions before advancing to the next. The user cannot skip phases or return to previous phases (this is a simplification vs the LLM-backed mode, which is not yet implemented).

### State Persistence

After each question-answer turn, the orchestrator writes the current state to `docs/INTERVIEW-<slug>.yaml`. This file is the single source of truth for the interview's progress.

**INTERVIEW-<slug>.yaml Schema:**

```yaml
# Metadata
id: string                    # Unique identifier (UUID)
slug: string                  # Feature slug (derived from description)
status: string                # "in_progress" | "complete"
mode: string                  # "deterministic" | "llm"
description: string           # Original user input
created_at: RFC3339           # Timestamp of first question
updated_at: RFC3339           # Timestamp of most recent answer

# Progress
phase: string                 # Current phase: overview | scope | requirements | interfaces | stories | review | complete
question_cursor: int          # Zero-based index of next question
max_questions: int            # Soft cap on total questions (default: 18)
progress: float               # Percentage complete (0.0–1.0)

# Accumulated data
spec_data:
  overview:
    title: string
    goal: string
    success_metrics: []string
    non_goals: []string
  scope:
    in_scope: []string
    out_of_scope: []string
    assumptions: []string
  requirements:
    functional: []string
    non_functional: []string
    constraints: []string
  interfaces:
    data_models: []string
    apis: []string
    external: []string
  stories: []string
  open_questions: []string

# History (full transcript)
history:
  - turn_number: int
    phase: string
    question: string
    answer: string
    timestamp: RFC3339

# Output (populated on completion)
requirements_path: string     # Path to generated REQUIREMENTS.md (set when status=complete)
```

### Resume Capability

The user may pause an interview at any point (Ctrl-C, session timeout, etc.). To resume:

```bash
sawtools interview --resume docs/INTERVIEW-<slug>.yaml
```

Or in Claude Code:

```
/saw interview --resume docs/INTERVIEW-my-feature.yaml
```

The orchestrator:
1. Reads the INTERVIEW doc from disk
2. Restores the phase, question cursor, and accumulated spec data
3. Continues from the next unanswered question

**Resume semantics:**
- If `status: complete`, resume is a no-op (the interview is already done)
- If `status: in_progress`, the orchestrator picks up where it left off
- The history is preserved — all prior question-answer turns remain in the INTERVIEW doc

### Output Contract

On completion (when the final question is answered and `status: complete` is set), the orchestrator calls the interview compiler, which generates `docs/REQUIREMENTS.md`. The format of REQUIREMENTS.md is structured markdown with sections corresponding to the 6 interview phases:

```markdown
# <title>

## Overview
**Goal:** <goal>

**Success Metrics:**
- <metric 1>
- <metric 2>

**Non-Goals:**
- <non-goal 1>

## Scope
**In Scope:**
- <item 1>

**Out of Scope:**
- <item 1>

**Assumptions:**
- <assumption 1>

## Requirements
**Functional:**
- <requirement 1>

**Non-Functional:**
- <requirement 1>

**Constraints:**
- <constraint 1>

## Interfaces
**Data Models:**
- <model 1>

**APIs:**
- <api 1>

**External Dependencies:**
- <dependency 1>

## User Stories
- <story 1>

## Open Questions
- <question 1>
```

This REQUIREMENTS.md file is suitable input for:
- `/saw bootstrap "<feature>" --requirements docs/REQUIREMENTS.md` (bootstrap mode: generate scaffold from requirements)
- `/saw scout "<feature>" --requirements docs/REQUIREMENTS.md` (scout mode: decompose requirements into IMPL doc)

### Error Handling

**Max questions limit exceeded:**
If the user has answered `max_questions` turns and the interview is not complete (some phases have no data), the orchestrator:
1. Compiles the partial requirements into REQUIREMENTS.md anyway
2. Adds a warning section: "## Warnings\n- Interview truncated at max_questions limit. Some phases incomplete."
3. Sets `status: complete` and transitions to SCOUT_PENDING

**Invalid phase transition:**
The deterministic manager enforces linear phase progression. If the internal state machine tries to skip a phase or return to a prior phase, this is a bug and should fail fast with a panic (not a user-recoverable error).

**stdin closed before completion:**
If the CLI detects EOF on stdin before the interview is complete, it:
1. Saves the current state to `docs/INTERVIEW-<slug>.yaml`
2. Prints a resume instruction: `Interview paused. Resume with: sawtools interview --resume docs/INTERVIEW-<slug>.yaml`
3. Exits with code 2 (distinct from success=0 and error=1)

### Implementation Notes

**CLI Implementation:**
- Command: `sawtools interview "<description>"` (in scout-and-wave-go repo)
- Located in: `cmd/saw/interview_cmd.go`
- Uses: `pkg/interview` package (Manager interface, DeterministicManager implementation)

**Claude Code Integration:**
- Skill command: `/saw interview "<description>"`
- Located in: `implementations/claude-code/prompts/saw-skill.md`
- The orchestrator executes the CLI command via Bash tool and manages the question-answer loop interactively

**Question Generation:**
The deterministic mode uses a fixed question bank defined in `pkg/interview/phase_questions.go`. Each phase has a predefined list of questions with field mappings to the SpecData schema. The LLM mode (not yet implemented) will generate questions dynamically based on prior answers.

### Canonical Question Bank (Deterministic Mode)

The deterministic interview mode uses a fixed question bank defined in `pkg/interview/phase_questions.go` (scout-and-wave-go repo). Each phase has a predefined list of questions with field mappings to the SpecData schema. The total question count is 16 (plus 1 confirmation prompt in the review phase).

**Phase 1: Overview (4 questions)**

| Field | Question | Required |
|-------|----------|----------|
| `title` | "What is the title of this project or feature?" | Yes |
| `goal` | "What is the primary goal? (one sentence)" | Yes |
| `success_metrics` | "What are the success metrics? (comma-separated) (or type 'skip' to skip)" | No |
| `non_goals` | "What is explicitly out of scope? (comma-separated) (or type 'skip' to skip)" | No |

**Phase 2: Scope (3 questions)**

| Field | Question | Required |
|-------|----------|----------|
| `in_scope` | "What is in scope? List the key deliverables (comma-separated)" | Yes |
| `out_of_scope` | "What is out of scope? (comma-separated) (or type 'skip' to skip)" | No |
| `assumptions` | "What assumptions are you making? (comma-separated) (or type 'skip' to skip)" | No |

**Phase 3: Requirements (3 questions)**

| Field | Question | Required |
|-------|----------|----------|
| `functional` | "List the functional requirements (one per line or comma-separated)" | Yes |
| `non_functional` | "Any non-functional requirements? (e.g., performance, security) (or type 'skip' to skip)" | No |
| `constraints` | "Any technical constraints? (e.g., Go 1.21+, no CGO) (or type 'skip' to skip)" | No |

**Phase 4: Interfaces (3 questions)**

| Field | Question | Required |
|-------|----------|----------|
| `data_models` | "What are the key data models or types? (or type 'skip' to skip)" | No |
| `apis` | "What are the key APIs or command interfaces? (or type 'skip' to skip)" | No |
| `external` | "Any external integrations? (or type 'skip' to skip)" | No |

**Phase 5: Stories (1 question)**

| Field | Question | Required |
|-------|----------|----------|
| `stories` | "List the key user stories or tasks (one per line) (or type 'skip' to skip)" | No |

**Phase 6: Review (2 questions)**

| Field | Question | Required |
|-------|----------|----------|
| `open_questions` | "Any open questions or unresolved decisions? (or type 'skip' to skip)" | No |
| `_confirm` | "Review complete. Ready to generate REQUIREMENTS.md? (yes/no)" | Yes |

**Phase transition rules:** A phase advances to the next when all its required fields are populated AND all optional fields have been asked (answered or skipped). The `_confirm` field in the review phase is special: it is never considered "populated" and is always asked exactly once. A "yes" answer transitions to `PhaseComplete`; a "no" answer keeps the interview in the review phase (implementation-defined behavior for re-asking).

**Skip semantics:** When the user types "skip" for an optional field, the field is set to an empty slice (`[]`) rather than left as `nil`. This distinguishes "asked and skipped" from "not yet asked" -- a `nil` slice means the question has not been presented.

**LLM mode (not yet implemented):** The LLM-backed mode will generate questions dynamically based on prior answers, enabling follow-up questions and adaptive depth. The deterministic question bank above serves as the baseline; LLM mode may ask these same questions plus additional context-sensitive ones.

### Related Rules

- **E16 (Scout Output Validation):** Both interview mode and Scout produce structured requirements docs; E16 validates the IMPL doc that Scout produces, while interview mode validates its own output via the compiler
- **E17 (Scout Reads Project Memory):** Scout reads docs/CONTEXT.md; interview mode does not (it's earlier in the lifecycle — CONTEXT.md is written after IMPL completion per E18)
- **Scout Agent (Scout.md):** Interview mode is an alternative to the Scout Agent when the user needs more structure; the output (REQUIREMENTS.md) feeds into either bootstrap or Scout

### Rationale

Interview mode solves the "blank canvas" problem for users who:
1. Have a vague feature idea but struggle to articulate requirements in natural language
2. Want to build requirements incrementally rather than all at once
3. Need explicit prompting to consider scope, non-goals, constraints, and interfaces
4. Are unfamiliar with Scout and want a more guided experience

The deterministic question flow (vs LLM-generated questions) ensures:
- Consistency across interviews (same questions for same phases)
- Testability (deterministic output for given inputs)
- No hallucination risk (questions are human-authored and version-controlled)

---

## Cross-References

- See `state-machine.md` for the INTERVIEWING state definition
- See `message-formats.md` for INTERVIEW-<slug>.yaml schema details
- See `implementations/claude-code/prompts/saw-skill.md` for `/saw interview` command usage
- See `participants.md` (Scout Agent) for the alternative requirements gathering pathway
