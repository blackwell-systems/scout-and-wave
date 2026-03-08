# Scout-and-Wave Message Formats

**Version:** 0.14.0

This document defines the structured data formats exchanged between participants: suitability verdicts, agent prompts, completion reports, and scaffold specifications.

---

## Overview

SAW uses the IMPL doc (Implementation Document) as the single source of truth (I4). All structured messages are written to the IMPL doc, not chat output. The IMPL doc evolves through the protocol lifecycle:

1. **Scout phase:** Scout writes suitability verdict and agent prompts
2. **Scaffold phase:** Scaffold Agent updates Scaffolds section with commit status
3. **Wave execution:** Each agent appends a completion report section

---

## IMPL Doc Structure

The IMPL doc is a markdown file with the following sections in order:

    # IMPL: {Feature Name}

    <!-- SAW:COMPLETE YYYY-MM-DD -->
    <!-- Present only when all waves are merged and verified. Omit entirely for active IMPL docs. -->

    **Feature:** {One-line description}
    **Repository:** {Absolute path to primary repository root}
    **Repositories:** {Comma-separated list of absolute paths — omit for single-repo waves}
    **Plan Reference:** {Path to original plan/audit/issue}

    ---

    ## Suitability Assessment

    {Suitability verdict - see format below}

    ---

    ## Quality Gates

    {Optional — see ## Quality Gates Section Format. Omit if no build toolchain is known or gates are not configured.}

    ---

    ## Scaffolds

    {Scaffold files table - see format below}
    {Omit this section if no scaffold files needed}

    ---

    ## Pre-Mortem

    {Pre-mortem risk table — see Pre-Mortem Section Format below}

    ---

    ## Known Issues

    {Known issues list, or "None identified."}

    ---

    ## Dependency Graph

    ```yaml type=impl-dep-graph
    {dependency graph — see Typed Metadata Blocks below}
    ```

    ---

    ## File Ownership

    ```yaml type=impl-file-ownership
    {file ownership table — see Typed Metadata Blocks below}
    ```

    ---

    ## Wave Structure

    ```yaml type=impl-wave-structure
    {wave structure diagram — see Typed Metadata Blocks below}
    ```

    ---

    ## Wave 1

    {Wave-level introduction}

    ### Agent A - {Role Description}

    {9-field agent prompt - see format below}

    ### Agent B - {Role Description}

    {9-field agent prompt}

    ...

    ---

    ## Wave 2

    {Similar structure for additional waves}

    ---

    ## Completion Reports

    ### Agent A - Completion Report

    ```yaml type=impl-completion-report
    {Structured fields - see Typed Metadata Blocks below}
    ```

    {Free-form notes}

    ### Agent B - Completion Report

    ```yaml type=impl-completion-report
    {Structured fields}
    ```

    {Free-form notes}

    ## Stub Report — Wave {N}

    {Written by Orchestrator after E20 stub scan — see ## Stub Report Section Format. One section per wave, placed after the last completion report for that wave.}

---

## Typed Metadata Blocks

Certain sections of the IMPL doc are machine-parsed by the orchestrator and the IMPL doc validator (E16). These sections use fenced code blocks with a `type=impl-*` annotation on the opening fence, whitespace-separated from the language tag. This annotation serves as a precise parser anchor and enables validation errors to reference specific block types rather than line numbers.

**Why typed blocks exist:**
- Parser anchors: orchestrator locates sections by `type=` annotation, not by heading text or line number
- Precise validation: validator errors reference the block type (e.g., "`impl-file-ownership` block: missing Agent column") instead of "line 47"
- Stability: sections can be reordered or have prose added around them without breaking parsers

**Prose sections remain free-form.** The following sections do NOT use typed blocks and are excluded from validator scope: Suitability Assessment, Pre-Mortem, Scaffolds, Known Issues, Interface Contracts, Wave Execution Loop, Orchestrator Post-Merge Checklist, Status table, and all agent prompt sections.

### Block Types

**`impl-file-ownership` — File Ownership table:**

Single-repo format:
```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/message-formats.md | A | 1 | — |
| protocol/execution-rules.md | B | 1 | — |
| implementations/claude-code/prompts/agents/scout.md | C | 2 | A, B |
```

Cross-repo format (add `Repo` column when agents work in different repositories):
```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On | Repo |
|------|-------|------|------------|------|
| pkg/engine/runner.go | A | 1 | — | saw-engine |
| pkg/engine/types.go | A | 1 | — | saw-engine |
| pkg/api/adapter.go | B | 1 | — | saw-web |
| cmd/saw/main.go | B | 1 | — | saw-web |
```

The `Repo` column value is the short repo name (matches the directory name). E3 ownership verification is performed per-repo: the same file path in different repos is not a conflict.

**`impl-dep-graph` — Dependency Graph:**

```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — foundation spec):
    [A] protocol/message-formats.md
         Defines canonical typed-block syntax and pre-mortem schema.
         ✓ root (no dependencies on other agents)

    [B] protocol/execution-rules.md
         Adds E16: validation + correction loop rule.
         ✓ root (no dependencies on other agents)

Wave 2 (2 parallel agents — consumer files):
    [C] implementations/claude-code/prompts/agents/scout.md
         Updates Scout prompt to use typed blocks. Depends on [A] for syntax spec.
         depends on: [A] [B]
```

**`impl-wave-structure` — Wave Structure diagram:**

```yaml type=impl-wave-structure
Wave 1: [A] [B]                    <- 2 parallel agents (spec foundation)
              | (A+B complete)
Wave 2: [C] [D]                    <- 2 parallel agents (consumer files)
```

**`impl-completion-report` — Completion Report (written by Wave agents):**

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate | timeout  # required when status is partial or blocked; omit when status is complete
repo: /absolute/path/to/repo  # omit for single-repo waves
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}
files_changed:
  - path/to/file
files_created:
  - path/to/file
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL ({command})
```

---

## Suitability Verdict Format

Emitted by the Scout at the end of the suitability gate. Written to the IMPL doc before any agent prompts.

### SUITABLE Verdict

```markdown
**Verdict:** SUITABLE

{One paragraph rationale explaining why work is suitable for SAW}

**Estimated times:**
- Scout phase: ~X min
- Wave 1 execution: ~Y min (N agents in parallel)
- Wave 2 execution: ~Z min (M agents in parallel)
- Merge & verify: ~W min
- Total (SAW): ~T min
- Sequential baseline: ~B min
- Time savings: ~D min (P% faster | slower)

**Recommendation:** Proceed
```

### SUITABLE WITH CAVEATS Verdict

```markdown
**Verdict:** SUITABLE WITH CAVEATS

{One paragraph rationale}

**Caveats:**
- {Caveat 1: description}
- {Caveat 2: description}

**Estimated times:**
{Same structure as SUITABLE}

**Recommendation:** Proceed with caveats acknowledged
```

### NOT SUITABLE Verdict

```markdown
**Verdict:** NOT SUITABLE

{One paragraph rationale explaining why work is not suitable}

**Failed preconditions:**
- Precondition {N} ({name}): {evidence from codebase}
- Precondition {M} ({name}): {evidence from codebase}

**Suggested alternative:** {sequential execution | investigate-first then re-scout | other: describe}

**Estimated times:**
{Same structure, but highlights that SAW would be slower or riskier than alternative}

**Recommendation:** Do not proceed
```

**Required fields for NOT SUITABLE:**
- `Failed preconditions`: Names each precondition that blocked the verdict by number and name, with specific evidence
- `Suggested alternative`: Makes the verdict actionable rather than a stop sign

**Precondition reference (from [preconditions.md](preconditions.md)):**
1. File decomposition
2. No investigation-first blockers
3. Interface discoverability
4. Pre-implementation scan
5. Positive parallelization value

---

## Agent Prompt Format

9-field structure embedded in the IMPL doc. Field 0 is mandatory pre-flight isolation verification. Fields 1–8 are the implementation specification.

**Full field definitions:** See `prompts/agent-template.md` for the complete template with embedded invariant definitions (I1, I2, I4, I5) and execution rule references (E4, E14).

**Brief field summary:**

| Field | Content | Purpose |
|-------|---------|---------|
| **0. Isolation Verification** | Bash commands to verify worktree, branch, working directory | Defense-in-depth: ensure agent operates in correct worktree before modifying files |
| **1. File Ownership** | Exact files the agent owns | Hard constraint (I1: disjoint ownership) |
| **2. Interfaces to Implement** | Exact signatures the agent must deliver | Contract the agent implements |
| **3. Interfaces to Call** | Exact signatures from prior waves or existing code | Dependencies the agent may import |
| **4. What to Implement** | Functional description (what, not how) | Task definition |
| **5. Tests to Write** | Named tests with one-line descriptions | Verification requirements |
| **6. Verification Gate** | Exact commands (build, lint, test), scoped to owned files/packages | Pre-report checklist |
| **7. Constraints** | Hard rules (error handling, compatibility, things to avoid) | Implementation guardrails |
| **8. Report** | Instructions for writing completion report | Structured output format |

**Field 0 structure (isolation verification):**

```markdown
## 0. CRITICAL: Isolation Verification (RUN FIRST)

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd {absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter}
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="{absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave{N}-agent-{letter}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files).
```

**Cross-reference:** Field 0–8 full definitions are in `prompts/agent-template.md` with embedded invariant and execution rule text for self-contained prompts.

---

## Completion Report Format

Structured YAML block written by each agent to the IMPL doc. Machine-readable. Orchestrator parses these before merging.

**E14: Write discipline:** Agents append completion reports at the end of the IMPL doc under `### Agent {letter} - Completion Report`. Agents never edit earlier sections (interface contracts, ownership table, suitability verdict). Those sections are frozen at worktree creation (E2).

**Structure:**

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate | timeout
  # Required when status is partial or blocked.
  # Omit (or set to null) when status is complete.
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
  - path/to/modified/file_test
files_created:
  - path/to/new/file
  - path/to/new/file_test
interface_deviations:
  - description: "Exact description of deviation from specified contract"
    downstream_action_required: true | false
    affects: [agent-letter, ...]  # agents in later waves that depend on this interface
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why it's needed"
  # or []
tests_added:
  - test_function_name
  - test_function_name_edge_case
verification: PASS | FAIL ({command} - N/N tests)
```

**Field definitions:**

- **status:**
  - `complete`: All work done, verification passed, committed
  - `partial`: Some work done, but incomplete or verification failed. Explain what remains in notes.
  - `blocked`: Cannot proceed without changes outside agent's scope (interface contract unimplementable, missing dependency, etc.). Explain blocker in notes.

- **failure_type:**
  - `transient` — intermittent failure (network, git lock, flaky test). Orchestrator may retry automatically (see E19).
  - `fixable` — agent hit a concrete blocker but knows the fix (e.g., missing dependency, wrong import path). Orchestrator applies fix and relaunches.
  - `needs_replan` — agent discovered the IMPL doc decomposition is wrong (ownership conflict, undiscoverable interface, scope larger than estimated). Orchestrator re-engages Scout with agent's findings as additional context.
  - `escalate` — agent cannot continue and has no recovery path. Human intervention required.
  - `timeout` — agent exhausted its turn limit before completing. Orchestrator retries once with an explicit instruction to commit partial work and prioritize essential work only. If retry also times out, escalate — scope reduction in the IMPL doc may be required.
  - Required when `status` is `partial` or `blocked`. Omit when `status` is `complete`.

- **repo:** Absolute path to the repository this agent worked in. Required for cross-repo waves so the Orchestrator knows which repo to merge in. Omit for single-repo waves.

- **worktree:** Canonical worktree path. Must match E5 naming convention: `.claude/worktrees/wave{N}-agent-{letter}`

- **branch:** Branch name. Must match worktree naming: `wave{N}-agent-{letter}`

- **commit:** Git commit SHA if changes were committed. `"uncommitted"` if no changes or commit failed. I5 requires agents commit before reporting.

- **files_changed:** List of files modified (not created). Relative paths from repository root.

- **files_created:** List of files created. Relative paths from repository root.

- **interface_deviations:** List of deviations from Field 2 (Interfaces to Implement). Empty list `[]` if all contracts implemented exactly as specified.
  - `downstream_action_required: true`: Orchestrator must update affected downstream agent prompts before next wave launches.
  - `affects`: List of agent letters in later waves that depend on this interface.

- **out_of_scope_deps:** List of files outside agent's ownership that require changes for correct implementation. Empty list `[]` if no out-of-scope dependencies discovered.

- **tests_added:** List of test function names added. Should correspond to Field 5 (Tests to Write).

- **verification:** `PASS` if all Field 6 commands passed. `FAIL` with details if any command failed.

**Free-form notes section:** After the structured YAML block, agents may add free-form notes for context that doesn't fit structured fields: key decisions, surprises, warnings, recommendations for downstream agents.

**Typed-block annotation:** The opening fence must be `` ```yaml type=impl-completion-report `` (not plain `` ```yaml ``). The orchestrator locates completion reports by finding `type=impl-completion-report` blocks, not by heading text or YAML heuristics. Plain YAML blocks are not machine-parsed.

---

## Scaffolds Section Format

Written by the Scout into the IMPL doc to specify type scaffold files. Read and materialized by the Scaffold Agent after human review.

**Canonical four-column format:**

```markdown
### Scaffolds

[Omit this section if no scaffold files are needed.]

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [exact types, interfaces, structs with signatures] | `module/internal/types` | pending |
| `path/to/shared.go` | [exact interfaces] | `module/pkg/shared` | pending |
```

**Column definitions:**

- **File:** Relative path from repository root. Scaffold Agent creates this file.
- **Contents:** Exact type definitions, interface signatures, struct declarations (no behavior, no function bodies). Inline in table cell or reference to earlier section.
- **Import path:** Module-qualified import path. Agents in the wave import from this path.
- **Status:** Lifecycle indicator.

**Status lifecycle:**

- `pending`: Scout wrote spec, Scaffold Agent not yet run
- `committed (sha)`: Scaffold Agent created, compiled, and committed the file. SHA is the commit hash.
- `FAILED: {reason}`: Scaffold Agent could not compile. No file committed. Orchestrator surfaces failure to human.

**Orchestrator verification:** Before creating worktrees, Orchestrator verifies all scaffold files show `committed (sha)` status. A `FAILED` status is a protocol stop: surface the failure to the human, do not proceed to worktree creation.

**When to omit Scaffolds section:**
- Solo waves (one agent): no shared types across agents
- No cross-agent interfaces: each agent owns fully independent subsystems
- Existing codebase has all needed types: agents import from existing code, no new shared types

**Interface freeze (E2):** Scaffold files are committed to HEAD before worktrees are created. Once worktrees branch from HEAD, interface contracts become immutable. Revising a scaffold file requires recreating all worktrees or descoping the wave.

---

## Stub Report Section Format

Written by the Orchestrator after wave agent completion reports (E20). Human-facing prose — NOT a typed block.

Placement: After the last `### Agent {letter} - Completion Report` section for a wave, before the next wave section or end of document.

Template — no stubs found:

```
## Stub Report — Wave {N}

_Generated by scan-stubs.sh after wave {N} completion. Informational only — does not block merge._

No stub patterns detected.
```

Template — stubs found:

```
## Stub Report — Wave {N}

_Generated by scan-stubs.sh after wave {N} completion. Informational only — does not block merge._

| File | Line | Pattern | Context |
|------|------|---------|---------|
| path/to/file.py | 42 | `pass` | `def process_items(self): pass` |
```

Stubs found at the review checkpoint are surfaced to the human reviewer. They do not automatically block merge — the reviewer decides.

---

## Quality Gates Section Format

Written by the Scout into the IMPL doc between Suitability Assessment and Scaffolds (E21). Optional — omit if no build toolchain is known or gates are not configured.

Schema:

```yaml
## Quality Gates

level: quick | standard | full

gates:
  - type: typecheck | test | lint | custom
    command: {exact shell command}
    required: true | false
    description: {one-line human description}
```

Auto-detection from project marker files:
- `go.mod` → `go build ./...` (typecheck), `go test ./...` (test), `go vet ./...` (lint)
- `package.json` → `tsc --noEmit` (typecheck), `npm test` (test), `eslint .` (lint)
- `Cargo.toml` → `cargo build` (typecheck), `cargo test` (test), `cargo clippy` (lint)
- `pyproject.toml` → `mypy .` (typecheck), `pytest` (test), `ruff check .` (lint)

The section is human-editable at review time. Gate commands should use the same toolchain already identified for the IMPL doc `test_command` field — no new tool discovery needed.

---

## docs/CONTEXT.md — Project Memory

A persistent project-level document at `docs/CONTEXT.md` in the target project. Created by the Orchestrator after the first completed feature (E18). Read by the Scout before every suitability assessment (E17).

**Canonical schema:**

```yaml
# docs/CONTEXT.md — Project memory for Scout-and-Wave
created: YYYY-MM-DD
protocol_version: "x.y.z"

architecture:
  description: string
  modules:
    - name: string
      path: string
      responsibility: string

decisions:
  - decision: string
    rationale: string
    date: YYYY-MM-DD
    feature: string  # IMPL doc slug

conventions:
  naming: string
  error_handling: string
  testing: string

established_interfaces:
  - name: string
    path: string
    signature: string
    introduced_in: string  # IMPL doc slug

features_completed:
  - slug: string
    impl_doc: string
    waves: number
    agents: number
    date: YYYY-MM-DD
```

**Field definitions:**

- **created:** ISO date when this file was first created by the Orchestrator.
- **protocol_version:** SAW protocol version in use when the file was created or last updated.
- **architecture:** High-level description of the project's structure and its constituent modules.
- **decisions:** Log of architectural decisions made during SAW feature work, linked to the IMPL doc that introduced them.
- **conventions:** Project-wide conventions established through SAW waves (naming, error handling, testing patterns).
- **established_interfaces:** Interfaces introduced by prior waves that downstream agents may depend on.
- **features_completed:** Ordered record of all features delivered via SAW, for Scout context and project health tracking.

**Usage note:** The file is optional. Projects that have not completed a SAW feature will not have one. Scout handles absence gracefully (E17). Orchestrator creates it on first completion (E18).

---

## Pre-Mortem Section Format

Written by the Scout into the IMPL doc before the human review checkpoint. Placement: immediately after the Scaffolds section (or immediately after Suitability Assessment if Scaffolds is omitted), before Known Issues and agent prompts.

The Pre-Mortem section uses a markdown table in free-form prose. It is human-facing and is NOT a typed block — it is excluded from validator scope.

**Schema:**

```markdown
## Pre-Mortem

**Overall risk:** low | medium | high

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| {description of what could go wrong} | low | medium | {concrete action to prevent or recover} |
| {description of what could go wrong} | medium | high | {concrete action to prevent or recover} |
```

**Example with realistic SAW failure modes:**

```markdown
## Pre-Mortem

**Overall risk:** medium

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Agent C writes typed-block examples that don't match the syntax Agent A defined in message-formats.md | medium | high | Agent C must read message-formats.md in full before editing; interface contract specifies exact fence annotation |
| Two agents claim ownership of the same file due to ambiguous decomposition | low | high | Scout verifies disjoint ownership before writing prompts; orchestrator checks ownership table for duplicates pre-launch |
| Scaffold file fails to compile, blocking all wave agents | low | high | Scaffold Agent must compile and commit before worktrees are created; FAILED status is a protocol stop |
| Wave 2 agent uses a state name that conflicts with Wave 1 agent's definition | low | medium | Interface contracts lock all shared names verbatim; agents must use these exactly |
```

**Field definitions:**

- **Overall risk:** Single token: `low`, `medium`, or `high`. Reflects aggregate risk across all failure modes.
- **Scenario:** Plain-language description of a specific failure mode. One row per scenario.
- **Likelihood:** `low`, `medium`, or `high`. How probable is this failure?
- **Impact:** `low`, `medium`, or `high`. How bad is the outcome if it occurs?
- **Mitigation:** Concrete action that prevents the failure or reduces its impact. Not "be careful" — a specific protocol step, check, or constraint.

---

## Message Flow Sequence

1. **Scout → IMPL doc:** Writes suitability verdict, Scaffolds section (if needed), agent prompts
1a. **Orchestrator → Scout (E16):** Orchestrator runs validator on typed-block sections of the IMPL doc. If errors are found, feeds a correction prompt back to Scout specifying the exact failing blocks. Scout rewrites only the failing sections. This loop repeats until the doc passes validation or the retry limit (default: 3) is reached. On retry limit exhausted, Orchestrator enters BLOCKED state and surfaces errors to human. On pass, proceeds normally.
2. **Human → Orchestrator:** Approves or rejects IMPL doc
3. **Scaffold Agent → IMPL doc:** Updates Scaffolds section Status column with commit SHAs or FAILED
4. **Orchestrator → Agents:** Launches agents with absolute IMPL doc path (agents read their prompts from IMPL doc)
5. **Agents → IMPL doc:** Append completion reports
5a. **Orchestrator → IMPL doc:** Runs E20 stub scan (collects `files_changed` + `files_created` from all agent reports, runs `scan-stubs.sh`, writes `## Stub Report — Wave {N}` to IMPL doc).
5b. **Orchestrator → (build system):** Runs E21 post-wave verification gates (if `## Quality Gates` section is present in IMPL doc). Required gate failures block merge; optional gate failures warn only.
6. **Orchestrator → Human:** Surfaces completion reports, merge results, verification status

**Anti-pattern:** Completion reports written to chat only (I4 violation). IMPL doc is the single source of truth. Chat output is ephemeral; downstream agents and merge procedures rely on IMPL doc contents.

---

## IMPL Doc Conflict Resolution

**E12: Merge conflict taxonomy:**

1. **Git conflict on agent-owned files:** I1 violation (impossible if invariants hold). Do not merge. Correct ownership table and re-run wave.

2. **Git conflict on orchestrator-owned shared files (IMPL doc completion reports, append-only configs):** Expected. Resolve by accepting all appended sections. E14 ensures each agent owns a distinct named section; no semantic conflict, only git line adjacency conflict.

3. **Semantic conflict (incompatible interface implementations without git conflict):** Surfaces in `interface_deviations` and `out_of_scope_deps`. Resolved by Orchestrator before next wave via interface revision and prompt updates.

**E14 makes IMPL doc conflicts predictable:** Agents only append their named completion report section at the end. They never edit earlier sections (ownership table, interface contracts, wave structure). Two agents appending distinct sections always produce adjacent-section git conflicts with no semantic overlap.

---

---

## IMPL Doc Size

**Threshold:** If the IMPL doc exceeds ~20KB (roughly 500 lines), consider splitting.

**Split strategy:**
- Keep suitability verdict, scaffolds, dependency graph, interface contracts, file ownership, wave structure, and status in the main IMPL doc
- Move agent prompts to separate files: `docs/IMPL/IMPL-<feature>-wave{N}-agent-{X}.md`
- Main IMPL doc links to per-agent files: `See [Agent A prompt](IMPL-<feature>-wave1-agent-A.md)`

**When NOT to split:**
- Documentation-only refactors (agent prompts are small)
- Simple features with <5 agents total
- When unified audit trail is more valuable than file size

---

## Per-Agent Context Payload

The orchestrator constructs a per-agent context payload (E23) before launching each Wave agent. The payload is a markdown string passed as the `prompt` parameter to the Agent tool — agents do not receive the full IMPL doc.

**Sections always included:**

| Section | Source in IMPL doc | Purpose |
|---------|-------------------|---------|
| Agent's 9-field prompt | `### Agent {letter} - {Role}` through next `### Agent` heading | Complete implementation spec |
| Interface contracts | `## Interface Contracts` | Cross-agent boundary definitions |
| File ownership table | `## File Ownership` typed block | Agent verifies its row; sees peers' rows for I1 reasoning |
| Scaffolds | `## Scaffolds` | Pre-built type files the agent imports |
| Quality gates | `## Quality Gates` | Verification commands required before completion report |
| IMPL doc path | Literal string preamble | Agent writes completion report here (I4, I5) |

**Sections excluded:** Other agents' 9-field prompt sections, `## Suitability Assessment`, `## Dependency Graph`, `## Pre-Mortem`, `## Known Issues`, `## Wave Structure` prose, completion reports from prior waves.

**Payload format:**

```markdown
<!-- IMPL doc: /absolute/path/to/docs/IMPL/IMPL-feature.md -->

{agent 9-field prompt section}

## Interface Contracts

{extracted contracts}

## File Ownership

{extracted ownership table}

## Scaffolds

{extracted scaffolds table}

## Quality Gates

{extracted gates}
```

**Stability:** Payload format is identical across waves. Wave 2 agents receive the same structure as Wave 1 agents — their own section extracted, same shared sections included.

---

## Orchestrator Parsing Requirements

Orchestrators must parse these fields from each completion report:

1. **Status values:** `status: complete | partial | blocked` — gates merge decision
2. **Interface deviations:** `interface_deviations` array — identifies blocked downstream agents; items with `downstream_action_required: true` must be propagated before next wave
3. **Out-of-scope dependencies:** `out_of_scope_deps` array — generates post-merge fix list
4. **Verification results:** `verification: PASS | FAIL` — gates merge per agent
5. **File lists:** `files_changed` and `files_created` — used for conflict prediction before touching the working tree
6. **Failure type:** `failure_type: transient | fixable | needs_replan | escalate | timeout` — drives automatic remediation decision tree (E19). Present only when `status` is `partial` or `blocked`.

**Location:** The orchestrator locates completion reports by finding `` ```yaml type=impl-completion-report `` blocks in the IMPL doc — not by heading text, line number, or free-form YAML heuristics. Each such block is associated with the nearest preceding `### Agent {letter} - Completion Report` heading. Plain `` ```yaml `` blocks without the `type=` annotation are not parsed as completion reports.

**Format assumption:** All structured data is in `type=impl-completion-report` typed blocks with consistent field names. Orchestrators should reject malformed YAML or missing required fields.

---

**Reference:** See `state-machine.md` for protocol states and transitions. See `procedures.md` for orchestrator actions when reading and processing these messages.
