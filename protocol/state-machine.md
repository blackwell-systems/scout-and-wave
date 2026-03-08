# Scout-and-Wave State Machine

**Version:** 0.14.0

This document defines the lifecycle states, transitions, and terminal conditions for Scout-and-Wave protocol execution.

---

## State Overview

SAW execution progresses through a series of states orchestrated by the synchronous Orchestrator. Each state represents a checkpoint where specific conditions must be satisfied before advancing.

### State Catalog

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **SCOUT_PENDING** | Initial state. Scout analysis not yet complete. | Protocol invoked | Scout completes, produces IMPL doc |
| **SCOUT_VALIDATING** | Orchestrator running validator on Scout output; feeding errors back to Scout if needed. | Scout writes IMPL doc | Validation passes OR retry limit exhausted |
| **REVIEWED** | IMPL doc produced, awaiting human review and approval. | Scout complete | Human approves plan |
| **SCAFFOLD_PENDING** | Scaffold Agent creating type scaffold files from approved contracts. | Human approved IMPL doc, Scaffolds section non-empty | Scaffold Agent commits all files, updates IMPL doc |
| **WAVE_PENDING** | Ready to launch wave agents. Worktrees not yet created. | Scaffolds committed (or no scaffolds needed) | Orchestrator creates worktrees, launches all agents |
| **WAVE_EXECUTING** | Agents running in parallel. | All agents launched | All agents report completion |
| **WAVE_MERGING** | All agents complete, orchestrator merging worktrees. | All completion reports written | All worktrees merged to main |
| **WAVE_VERIFIED** | Merge complete, post-merge verification passed. | Merge complete, verification passed | Next wave launches OR protocol complete |
| **BLOCKED** | Wave failed verification or agent reported failure. | Any agent status: partial/blocked, OR verification failure | Issue resolved, verification re-run |
| **COMPLETE** | All waves verified, feature complete. | Final wave verified, no more waves | Terminal state |
| **NOT_SUITABLE** | Scout determined work not suitable for SAW. | Scout suitability gate failed | Terminal state |

---

## State Transitions

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

**Interface Contract Revision:**
```
WAVE_EXECUTING
    ↓ (Agent reports status: blocked due to unimplementable contract)
BLOCKED
    ↓ (Orchestrator revises contracts in IMPL doc, updates affected prompts)
WAVE_PENDING (wave restarts with corrected contracts)
```

---

## State Transition Guards

Transitions are conditional. The following guards determine whether a transition may proceed.

### SCOUT_PENDING → SCOUT_VALIDATING

**Guard:** Scout completion notification received AND IMPL doc written to disk.

**Note:** SCOUT_VALIDATING is now interposed between SCOUT_PENDING and REVIEWED. The previous direct transition from SCOUT_PENDING to REVIEWED no longer fires on Scout completion; validation must pass first.

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

### SCAFFOLD_PENDING → WAVE_PENDING

**Guard:** Scaffold Agent completion notification received AND all scaffold files in IMPL doc Scaffolds section show `status: committed (sha)`.

**Failure:** If any scaffold file shows `FAILED: {reason}`, enter BLOCKED. Orchestrator must surface the failure to the human. Human revises interface contracts in IMPL doc and re-runs Scaffold Agent.

### WAVE_PENDING → WAVE_EXECUTING

**Guard:** File ownership verification passes (no file appears in multiple agents' ownership lists) AND all worktrees created successfully AND all agents launched.

**Solo wave exception:** If wave contains exactly one agent, no worktrees are created. Agent runs on main branch directly. Transition still proceeds through WAVE_EXECUTING but skips WAVE_MERGING.

### WAVE_EXECUTING → WAVE_MERGING

**Guard:** All agents in the wave have written completion reports to IMPL doc AND E20 stub scan has run and results appended to IMPL doc AND E21 quality gates have run (required gates passing).

**Failure conditions:**
- Any agent reports `status: partial` → enter BLOCKED (see `failure_type` field and E19 decision tree)
- Any agent reports `status: blocked` → enter BLOCKED (see `failure_type` field and E19 decision tree)
- Agent failed isolation verification (Field 0) → enter BLOCKED
- E21 required quality gate fails → enter BLOCKED

**Solo wave exception:** Skip WAVE_MERGING entirely. Proceed directly to WAVE_VERIFIED for post-wave verification.

### WAVE_MERGING → WAVE_VERIFIED

**Guard:** Conflict prediction passes (E11: no file appears in multiple agents' `files_changed` or `files_created` lists) AND all worktree branches merged to main AND post-merge verification commands pass.

**Failure:** If merge conflicts occur OR verification fails, enter BLOCKED.

### WAVE_VERIFIED → WAVE_PENDING (next wave)

**Guard:** IMPL doc specifies additional waves AND human approval granted (or `--auto` mode active).

### WAVE_VERIFIED → COMPLETE

**Guard:** No additional waves defined in IMPL doc AND orchestrator has written `<!-- SAW:COMPLETE YYYY-MM-DD -->` to the IMPL doc (E15).

### BLOCKED → WAVE_VERIFIED

**Guard:** Orchestrator resolves the blocking issue AND re-runs verification AND verification passes.

**Resolution paths:**
- Agent failure: re-run failing agent with corrections
- Interface contract unimplementable: revise contracts, update prompts, restart wave from WAVE_PENDING
- Merge conflict: correct ownership table in IMPL doc, recreate worktrees, restart wave
- Verification failure: fix root cause, re-run verification

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
| **SCOUT_PENDING** | Orchestrator launches Scout agent with absolute IMPL doc path |
| **SCOUT_VALIDATING** | Orchestrator runs validator on all `type=impl-*` blocks in IMPL doc; on failure, issues correction prompt to Scout (E16); on pass, advances to REVIEWED |
| **REVIEWED** | Orchestrator surfaces IMPL doc to human, requests approval |
| **SCAFFOLD_PENDING** | Orchestrator launches Scaffold Agent with absolute IMPL doc path |
| **WAVE_PENDING** | Orchestrator runs pre-launch ownership verification (E3) |
| **WAVE_EXECUTING** | Orchestrator monitors for completion notifications (async) |
| **WAVE_MERGING** | Orchestrator runs conflict prediction (E11), executes merge procedure per agent |
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

When all invariants (I1–I6) and execution rules (E1–E22) are maintained:

- **Progress:** The state machine always advances or terminates. No infinite loops.
- **Human checkpoints enforced:** REVIEWED state requires explicit approval. Suitability gate requires human review of NOT SUITABLE verdicts.
- **Isolation enforced:** WAVE_EXECUTING → WAVE_MERGING transition verifies all agents wrote completion reports. WAVE_MERGING → WAVE_VERIFIED verifies merge conflicts resolved.
- **Failure recovery:** BLOCKED is re-entrant. Orchestrator can resolve and retry without data loss.
- **Observability:** Every state transition is logged. External monitoring can track progress via worktree naming convention (E5).

---

**Reference:** See `message-formats.md` for IMPL doc structure and completion report schema. See `procedures.md` for orchestrator actions at each state.
