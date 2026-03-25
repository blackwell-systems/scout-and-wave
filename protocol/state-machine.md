# Scout-and-Wave State Machine

**Version:** 0.21.0

This document defines the lifecycle states, transitions, and terminal conditions for Scout-and-Wave protocol execution.

---

## State Overview

SAW execution progresses through a series of states orchestrated by the synchronous Orchestrator. Each state represents a checkpoint where specific conditions must be satisfied before advancing.

### State Catalog

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **INTERVIEWING** | User is being guided through structured requirements gathering via `/saw interview`. | `/saw interview` command invoked | Interview completes, REQUIREMENTS.md written (manual: user runs `/saw scout` or `/saw bootstrap` after) |
| **SCOUT_PENDING** | Initial state. Scout analysis not yet complete. | Protocol invoked | Scout completes, produces IMPL doc |
| **SCOUT_VALIDATING** | Orchestrator running validator on Scout output; feeding errors back to Scout if needed. | Scout writes IMPL doc | Validation passes OR retry limit exhausted |
| **REVIEWED** | IMPL doc produced, awaiting human review and approval. | Scout complete | Human approves plan |
| **SCAFFOLD_PENDING** | Scaffold Agent creating type scaffold files from approved contracts. | Human approved IMPL doc, Scaffolds section non-empty | Scaffold Agent commits all files, updates IMPL doc |
| **WAVE_PENDING** | Ready to launch wave agents. Worktrees not yet created. | Scaffolds committed (or no scaffolds needed) | Orchestrator creates worktrees, launches all agents |
| **WAVE_EXECUTING** | Agents running in parallel. | All agents launched | All agents report completion |
| **WAVE_MERGING** | All agents complete, orchestrator merging worktrees. Integration validation (E25) and Integration Agent (E26) execute within this state, after quality gates pass and before merge. | All completion reports written | All worktrees merged to main |
| **WAVE_VERIFIED** | Merge complete, post-merge verification passed. | Merge complete, verification passed | Next wave launches OR protocol complete |
| **BLOCKED** | Wave failed verification or agent reported failure. | Any agent status: partial/blocked, OR verification failure | Issue resolved, verification re-run |
| **COMPLETE** | All waves verified, feature complete. | Final wave verified, no more waves | Terminal state |
| **NOT_SUITABLE** | Scout determined work not suitable for SAW. | Scout suitability gate failed | Terminal state |

---

## State Transitions

### Interview Path (Optional Pre-Scout Entry)

```
INTERVIEWING
    ↓ (Interview completes, REQUIREMENTS.md written)
(manually) SCOUT_PENDING
```

The INTERVIEWING → SCOUT_PENDING transition is manual: after the interview
completes, the user invokes `/saw scout "<feature>" --requirements docs/REQUIREMENTS.md`
(or `/saw bootstrap`) to enter SCOUT_PENDING. There is no automatic state signal
from the interview tool to the SAW orchestrator.

### Primary Flow (Success Path)

```
SCOUT_PENDING
    ↓ (Scout completes, IMPL doc written)
SCOUT_VALIDATING
    ↓ (Validation passes)
REVIEWED
    ↓ (Human approves)
SCAFFOLD_PENDING (if Scaffolds section non-empty)
    ↓ (Scaffold Agent commits)
WAVE_PENDING
    ↓ (Orchestrator launches agents)
WAVE_EXECUTING
    ↓ (All agents complete)
WAVE_MERGING
    ↓ (Merge successful)
WAVE_VERIFIED
    ↓ (If more waves exist)
WAVE_PENDING (next wave)
    ↓ (If no more waves)
COMPLETE
```

### Alternate Success Paths

**Interview path (bypasses normal SCOUT_PENDING start):**
The INTERVIEWING state is an optional precursor. After completing the interview,
the user manually invokes `/saw scout` or `/saw bootstrap` with the generated
REQUIREMENTS.md, entering SCOUT_PENDING. The interview path bypasses the normal
SCOUT_PENDING entry and feeds a REQUIREMENTS.md into it instead.

**Solo wave skip (no merge needed):**
```
REVIEWED → WAVE_EXECUTING (solo wave: skip WAVE_PENDING worktree creation)
SCAFFOLD_PENDING → WAVE_EXECUTING (solo wave after scaffold)
WAVE_EXECUTING → WAVE_VERIFIED (solo wave: skip WAVE_MERGING)
WAVE_EXECUTING → COMPLETE (solo wave on final wave: direct completion)
```

**Direct REVIEWED skip (structured output mode):**
```
SCOUT_PENDING → REVIEWED (when structured output enforcement makes E16 validation a no-op — the output is already schema-validated, so SCOUT_VALIDATING is bypassed)
```

**Next-wave loop:**
```
WAVE_VERIFIED → WAVE_EXECUTING (solo next-wave: skip WAVE_PENDING)
WAVE_VERIFIED → WAVE_PENDING (multi-agent next-wave)
```

### Failure Paths

**Validation Failure Path:**
```
SCOUT_VALIDATING
    ↓ (Validation fails, retries remain)
SCOUT_VALIDATING (self-loop: correction prompt → Scout rewrites → revalidate)
    ↓ (Retry limit exhausted)
BLOCKED
```

**Suitability Gate Failure:**
```
SCOUT_PENDING
    ↓ (Preconditions fail)
NOT_SUITABLE (terminal)
```

**Agent or Verification Failure:**
```
WAVE_EXECUTING
    ↓ (Agent reports partial/blocked OR verification fails)
BLOCKED
    ↓ (Orchestrator fixes issue, re-runs verification)
WAVE_VERIFIED (resume success path)
```

**Post-Verification Failure:**
```
WAVE_VERIFIED
    ↓ (Post-verification issue discovered, e.g. integration gap)
BLOCKED
    ↓ (Orchestrator resolves issue)
WAVE_VERIFIED (resume success path)
```

**Interface Contract Revision:**
```
WAVE_EXECUTING
    ↓ (Agent reports status: blocked due to unimplementable contract)
BLOCKED
    ↓ (Orchestrator revises contracts in IMPL doc, updates affected prompts)
WAVE_PENDING (wave restarts with corrected contracts)
```

**BLOCKED Recovery to REVIEWED (contract revision requiring re-review):**
```
BLOCKED
    ↓ (Orchestrator determines contracts must be revised and re-reviewed)
REVIEWED (re-enter plan review before restarting waves)
```

---

## State Transition Guards

Transitions are conditional. The following guards determine whether a transition may proceed.

### SCOUT_PENDING → SCOUT_VALIDATING

**Guard:** Scout completion notification received AND IMPL doc written to disk.

**Note:** SCOUT_VALIDATING is typically interposed between SCOUT_PENDING and REVIEWED.

### SCOUT_PENDING → REVIEWED (direct)

**Guard:** Scout completion notification received AND IMPL doc written to disk AND structured output enforcement is active (API-backend runs where the output is already schema-validated).

**When this fires:** In structured output mode, the validator always passes on first attempt because the output was already schema-validated by the API. The SCOUT_VALIDATING state is effectively skipped. This transition is also valid when the engine determines that validation is unnecessary (e.g., the IMPL doc was produced by a trusted pipeline).

### SCOUT_VALIDATING → REVIEWED

**Guard:** Validator reports no errors on all `type=impl-*` typed-block sections in the IMPL doc AND suitability verdict is SUITABLE or SUITABLE WITH CAVEATS.

**Failure:** If verdict is NOT SUITABLE, transition to NOT_SUITABLE (terminal).

### SCOUT_VALIDATING → SCOUT_VALIDATING (self-loop)

**Guard:** Validator reports errors AND retry count < retry limit (default: 3, per E16). Orchestrator issues correction prompt to Scout identifying each error with section name and location; Scout rewrites only the failing sections; validator re-runs.

### SCOUT_VALIDATING → BLOCKED

**Guard:** Validator reports errors AND retry count >= retry limit (default: 3, per E16). Orchestrator surfaces validation errors to human. Do not enter REVIEWED.

### REVIEWED → SCAFFOLD_PENDING

**Guard:** Human approval received AND IMPL doc Scaffolds section is non-empty.

**Skip condition:** If Scaffolds section is empty (solo wave or no shared types), skip directly to WAVE_PENDING.

### REVIEWED → WAVE_EXECUTING (solo wave skip)

**Guard:** Human approval received AND Scaffolds section empty AND wave contains exactly one agent. The orchestrator skips WAVE_PENDING (no worktrees to create) and launches the solo agent directly on the main branch.

### REVIEWED → BLOCKED

**Guard:** Human approval received but pre-launch validation fails (E3 ownership conflict, E21A baseline failure, or other pre-wave check failure).

### SCAFFOLD_PENDING → WAVE_PENDING

**Guard:** Scaffold Agent completion notification received AND all scaffold files in IMPL doc Scaffolds section show `status: committed (sha)`.

**Failure:** If any scaffold file shows `FAILED: {reason}`, enter BLOCKED. Orchestrator must surface the failure to the human. Human revises interface contracts in IMPL doc and re-runs Scaffold Agent.

### SCAFFOLD_PENDING → WAVE_EXECUTING (solo wave skip)

**Guard:** Scaffold Agent completes AND wave contains exactly one agent. Skips WAVE_PENDING (no worktrees) and launches the solo agent directly.

### SCAFFOLD_PENDING → BLOCKED

**Guard:** Scaffold Agent fails (compilation error, scaffold file creation failure).

### WAVE_PENDING → WAVE_EXECUTING

**Guard:** E21A baseline verification passes (or is exempt per E21A) AND file ownership verification passes (no file appears in multiple agents' ownership lists) AND all worktrees created successfully AND all agents launched.

**E21A baseline verification:** Before creating worktrees, `prepare-wave` runs the IMPL doc's quality gates against current HEAD. If any required gate fails, this transition does not fire — the wave enters BLOCKED with error `baseline_verification_failed`. If the IMPL doc has no quality gates, or if the wave is a solo wave, E21A is a no-op and this guard proceeds without a baseline check.

**Solo wave exception:** If wave contains exactly one agent, no worktrees are created. Agent runs on main branch directly. E21A does not apply (solo wave exemption). Transition still proceeds through WAVE_EXECUTING but skips WAVE_MERGING.

### WAVE_EXECUTING → WAVE_MERGING

**Guard:** All agents in the wave have written completion reports to IMPL doc AND E20 stub scan has run and results appended to IMPL doc AND E21 quality gates have run (required gates passing).

**Failure conditions:**
- Any agent reports `status: partial` → enter BLOCKED (see `failure_type` field and E19 decision tree)
- Any agent reports `status: blocked` → enter BLOCKED (see `failure_type` field and E19 decision tree)
- Agent failed isolation verification (Field 0) → enter BLOCKED
- E21 required quality gate fails → enter BLOCKED

**Solo wave exception:** Skip WAVE_MERGING entirely. Proceed directly to WAVE_VERIFIED for post-wave verification. If this is the final wave, may proceed directly to COMPLETE.

### WAVE_EXECUTING → COMPLETE (direct completion)

**Guard:** Solo wave on the final wave (no more waves defined) AND all verification passes. The orchestrator skips both WAVE_MERGING and WAVE_VERIFIED, transitioning directly to COMPLETE. This is valid because a solo wave has nothing to merge and nothing to verify beyond the agent's own verification gate.

### WAVE_MERGING → WAVE_VERIFIED

**Guard:** Conflict prediction passes (E11) OR manual merge completed (E11a) AND integration validation passes or Integration Agent completes successfully (E25/E26) AND all worktree branches merged to main AND post-merge verification commands pass.

**Integration validation (E25/E26):** Before merge, the Orchestrator runs `ValidateIntegration()` to scan for unconnected exports. If integration gaps are detected (`report.Valid == false`), the Integration Agent (E26) is launched to wire the gaps. The Integration Agent runs within WAVE_MERGING state. If the Integration Agent fails, transition to BLOCKED.

**Failure:** If merge conflicts occur OR verification fails OR Integration Agent fails, enter BLOCKED.

### WAVE_VERIFIED → WAVE_PENDING (next wave, multi-agent)

**Guard:** IMPL doc specifies additional waves AND next wave has multiple agents AND human approval granted (or `--auto` mode active).

### WAVE_VERIFIED → WAVE_EXECUTING (next wave, solo agent)

**Guard:** IMPL doc specifies additional waves AND next wave has exactly one agent AND human approval granted (or `--auto` mode active). Skips WAVE_PENDING because solo waves do not need worktree creation.

### WAVE_VERIFIED → COMPLETE

**Guard:** No additional waves defined in IMPL doc AND orchestrator has written `<!-- SAW:COMPLETE YYYY-MM-DD -->` to the IMPL doc (E15).

### WAVE_VERIFIED → BLOCKED

**Guard:** Post-verification discovers an issue (e.g., integration gap that cannot be auto-resolved, post-merge test failure discovered after initial verification passed, or inter-wave dependency problem).

### BLOCKED → WAVE_VERIFIED

**Guard:** Orchestrator resolves the blocking issue AND re-runs verification AND verification passes.

### BLOCKED → WAVE_EXECUTING

**Guard:** Orchestrator resolves the blocking issue by re-launching an agent (e.g., after fixing a correctable failure per E7a/E19). The wave transitions directly to WAVE_EXECUTING without going through WAVE_PENDING because worktrees already exist.

### BLOCKED → WAVE_PENDING

**Guard:** Orchestrator resolves the blocking issue but worktrees must be recreated (e.g., ownership table corrected, interface contracts revised). The wave restarts from WAVE_PENDING.

### BLOCKED → REVIEWED

**Guard:** Orchestrator determines that the blocking issue requires re-review of the IMPL doc (e.g., fundamental contract revision, scope change requiring human re-approval). Transitions back to REVIEWED for human re-approval before any waves restart.

**Resolution paths (summary):**
- Agent failure (correctable): re-run agent → BLOCKED → WAVE_EXECUTING
- Agent failure (worktrees invalid): recreate worktrees → BLOCKED → WAVE_PENDING
- Interface contract unimplementable: revise contracts, update prompts → BLOCKED → REVIEWED or BLOCKED → WAVE_PENDING
- Merge conflict: correct ownership table in IMPL doc, recreate worktrees → BLOCKED → WAVE_PENDING
- Verification failure: fix root cause, re-run verification → BLOCKED → WAVE_VERIFIED

---

## Terminal States

**COMPLETE:** All waves verified, feature fully implemented. The IMPL doc carries `<!-- SAW:COMPLETE YYYY-MM-DD -->` as the permanent record of closure (E15). Protocol execution ends successfully.

**NOT_SUITABLE:** Scout determined preconditions not satisfied. No IMPL doc produced. No waves executed. Orchestrator surfaces suitability verdict to human with failed preconditions and suggested alternatives.

**BLOCKED (quasi-terminal):** Not truly terminal. Orchestrator can resolve and advance to WAVE_VERIFIED. But human intervention is required. Automated `--auto` mode cannot proceed past BLOCKED for non-correctable failures.

---

## State Entry Actions

These actions occur automatically when entering each state.

| State | Entry Actions |
|-------|---------------|
| **INTERVIEWING** | CLI prints question prompts to stdout and reads answers from stdin. Web UI emits SSE `question` events and waits for `/api/interview/{runID}/answer` POSTs. State persisted to `docs/INTERVIEW-<slug>.yaml` after each turn. |
| **SCOUT_PENDING** | Orchestrator launches Scout agent with absolute IMPL doc path |
| **SCOUT_VALIDATING** | Orchestrator runs validator on all `type=impl-*` blocks in IMPL doc; on failure, issues correction prompt to Scout (E16); on pass, advances to REVIEWED |
| **REVIEWED** | Orchestrator surfaces IMPL doc to human, requests approval |
| **SCAFFOLD_PENDING** | Orchestrator launches Scaffold Agent with absolute IMPL doc path |
| **WAVE_PENDING** | Orchestrator runs E21A baseline gate verification (if gates defined and multi-agent wave); then pre-launch ownership verification (E3) |
| **WAVE_EXECUTING** | Orchestrator monitors for completion notifications (async) |
| **WAVE_MERGING** | Orchestrator runs integration validation (E25), launches Integration Agent if gaps detected (E26), runs conflict prediction (E11), executes merge procedure per agent |
| **WAVE_VERIFIED** | Orchestrator runs post-merge verification (unscoped), updates IMPL doc state |
| **BLOCKED** | Orchestrator surfaces failure details to human, awaits resolution |
| **COMPLETE** | Orchestrator writes `<!-- SAW:COMPLETE -->` tag to IMPL doc (E15); updates `docs/CONTEXT.md` with feature summary (E18); reports final status; cleans up worktrees |
| **NOT_SUITABLE** | Orchestrator surfaces suitability verdict, suggests alternatives |

---

## Solo Wave Variant

A wave containing exactly one agent follows a modified state flow:

```
WAVE_PENDING
    ↓ (Agent runs on main, no worktrees)
WAVE_EXECUTING
    ↓ (Agent completes)
WAVE_VERIFIED (skip WAVE_MERGING)
```

**Rationale:** One agent cannot conflict with itself. Worktree isolation and merge steps are unnecessary. Post-wave verification is still required.

**Scaffolding:** Solo waves do not require scaffold files. Scaffold files exist to enable multiple agents in the same wave to compile against shared types. Scout leaves the Scaffolds section empty for solo waves.

---

## Cross-Wave Coordination

Waves execute sequentially (I3: Wave sequencing). When Wave N completes, its implementations are committed to HEAD. Wave N+1 agents branch from that commit and import from the committed codebase directly.

**No special coordination mechanism needed:** Later waves always have access to earlier waves' committed work through normal imports. Scaffolds solve the intra-wave problem (parallel agents that cannot see each other's code); cross-wave coordination is just sequential development.

---

## State Machine Correctness Properties

When all invariants (I1–I6, P5) and execution rules (E1–E42, E21A, E21B) are maintained:

- **Progress:** The state machine always advances or terminates. No infinite loops.
- **Human checkpoints enforced:** REVIEWED state requires explicit approval. Suitability gate requires human review of NOT SUITABLE verdicts.
- **Isolation enforced:** WAVE_EXECUTING → WAVE_MERGING transition verifies all agents wrote completion reports. WAVE_MERGING → WAVE_VERIFIED verifies merge conflicts resolved.
- **Failure recovery:** BLOCKED is re-entrant. Orchestrator can resolve and retry without data loss.
- **Observability:** Every state transition is logged. External monitoring can track progress via worktree naming convention (E5).

---

## Program State Machine

The PROGRAM layer adds an outer state machine that coordinates multiple IMPL executions. Where the IMPL state machine governs a single feature's lifecycle (SCOUT_PENDING → REVIEWED → WAVE_EXECUTING → COMPLETE), the Program state machine governs an entire project composed of multiple features.

### Program State Catalog

| State | Description |
|-------|-------------|
| **PROGRAM_PLANNING** | Planner analyzing requirements and codebase, producing PROGRAM manifest |
| **PROGRAM_VALIDATING** | Orchestrator validating PROGRAM manifest structure and dependencies |
| **PROGRAM_REVIEWED** | PROGRAM manifest approved, awaiting execution launch |
| **PROGRAM_SCAFFOLD** | Creating program-level scaffolds (program contracts) |
| **TIER_EXECUTING** | One or more IMPLs executing in parallel within current tier |
| **TIER_VERIFIED** | Current tier complete, all IMPLs verified |
| **PROGRAM_COMPLETE** | All tiers complete, all IMPLs complete |
| **PROGRAM_BLOCKED** | Program execution blocked (IMPL failure, dependency failure, etc.) |
| **PROGRAM_NOT_SUITABLE** | Requirements not suitable for SAW program execution |

### Program State Flow

```
PROGRAM_PLANNING
    ↓ (Planner completes)
PROGRAM_VALIDATING
    ↓ (Validation passes)
PROGRAM_REVIEWED
    ↓ (Human approves)
PROGRAM_SCAFFOLD (if program contracts exist)
    ↓ (Scaffolds committed)
TIER_EXECUTING (Tier 1)
    ↓ (All Tier 1 IMPLs complete)
TIER_VERIFIED
    ↓ (More tiers exist)
TIER_EXECUTING (Tier N)
    ↓ (All tiers complete)
PROGRAM_COMPLETE
```

### Relationship to IMPL State Machine

The Program state machine is an **outer loop** containing the IMPL state machine. When the Program enters `TIER_EXECUTING`, one or more IMPLs launch concurrently. Each IMPL progresses through its own state machine (SCOUT_PENDING → REVIEWED → WAVE_EXECUTING → COMPLETE). The Program waits for all IMPLs in the current tier to reach COMPLETE before advancing to TIER_VERIFIED.

**Key properties:**
- IMPLs within the same tier execute in parallel (P1: IMPL independence within tier)
- IMPLs in different tiers execute sequentially (tier N+1 depends on tier N outputs)
- Program contracts defined at PROGRAM_REVIEWED freeze before any IMPL executes (interface freeze applies at program scope)
- Each IMPL has its own Scout, Scaffold Agent, and Wave Agents — the Planner does not write IMPL docs

### Phase 2 Scope

Full program execution rules, invariants, and orchestrator procedures for the Program layer will be defined in **Phase 2** of the Program Layer implementation. This section provides the state catalog and conceptual model. Phase 2 will define:
- Program state transition guards
- Program-level invariants (P1, P2, P3, etc.)
- Orchestrator procedures for tier execution
- Program completion criteria
- Cross-tier dependency validation

**Related documents:**
- `protocol/program-manifest.md` — PROGRAM manifest structure and schema
- `protocol/program-invariants.md` — Program-level invariants (P1, P2, P3)

---

### Canonical Allowed Transitions Table

The following table is the canonical reference for all allowed state transitions, matching the Go engine's `allowedTransitions` map in `pkg/protocol/state_transition.go`:

| From State | Allowed Targets |
|-----------|----------------|
| **INTERVIEWING** | *(manual: user invokes /saw scout after interview completes)* |
| **SCOUT_PENDING** | REVIEWED, NOT_SUITABLE |
| **SCOUT_VALIDATING** | REVIEWED, NOT_SUITABLE |
| **REVIEWED** | SCAFFOLD_PENDING, WAVE_PENDING, WAVE_EXECUTING, BLOCKED |
| **SCAFFOLD_PENDING** | WAVE_PENDING, WAVE_EXECUTING, BLOCKED |
| **WAVE_PENDING** | WAVE_EXECUTING, BLOCKED |
| **WAVE_EXECUTING** | WAVE_MERGING, WAVE_VERIFIED, BLOCKED, COMPLETE |
| **WAVE_MERGING** | WAVE_VERIFIED, BLOCKED |
| **WAVE_VERIFIED** | WAVE_PENDING, WAVE_EXECUTING, COMPLETE, BLOCKED |
| **BLOCKED** | REVIEWED, WAVE_EXECUTING, WAVE_PENDING |
| **COMPLETE** | *(terminal — no transitions)* |
| **NOT_SUITABLE** | *(terminal — no transitions)* |

---

**Reference:** See `message-formats.md` for IMPL doc structure and completion report schema. See `procedures.md` for orchestrator actions at each state.
