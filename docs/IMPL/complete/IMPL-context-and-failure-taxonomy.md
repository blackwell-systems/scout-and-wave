# IMPL: Project Memory (CONTEXT.md) + Failure Taxonomy
<!-- SAW:COMPLETE 2026-03-08 -->

**Feature:** Two protocol enhancements — persistent project memory document (`docs/CONTEXT.md`) and `failure_type` field in completion reports
**Repository:** /Users/dayna.blackwell/code/scout-and-wave
**Plan Reference:** ROADMAP.md §§ "Failure Taxonomy", "docs/SAW.md — Project Memory"

---

## Suitability Assessment

**Verdict:** SUITABLE WITH CAVEATS

test_command: none (markdown-only repo — no build or test suite)
lint_command: none

This repo is a pure markdown protocol spec. No compiled code changes; no build or test cycle. File decomposition is clean: four files change across two agents in Wave 1 (protocol spec layer) and two agents in Wave 2 (implementation prompt layer). Each agent owns a fully disjoint file set. Both features are TO-DO — neither `failure_type` nor `docs/CONTEXT.md` appears anywhere in the codebase outside `ROADMAP.md`. Cross-agent interfaces are fully discoverable from the ROADMAP spec before implementation begins.

The caveat is parallelization value. Markdown-only edits have no build cycle to amortize — the raw speed benefit of parallelism is small. However, the IMPL doc provides meaningful coordination value: it locks consistent terminology (`CONTEXT.md` not `SAW.md`, `failure_type` value set, E-rule numbering) across four files that will be edited in parallel. Without coordination, agents risk inconsistent cross-references between spec and prompt files. Value is coordination, not speed.

**Pre-implementation scan results:**
- Total items: 2 features
- Already implemented: 0 items
- Partially implemented: 0 items
- To-do: 2 items (both features clean TO-DO)

**Caveats:**
- No automated verification gate exists (pure markdown). Agents verify by reading their output and cross-checking references manually.
- Wave 2 agents depend on Wave 1 for correct E-rule numbers and exact `failure_type` value spelling. Wave 1 must fully complete before Wave 2 launches.

**Estimated times:**
- Scout phase: ~15 min (done)
- Wave 1 execution: ~15 min (2 agents in parallel)
- Wave 2 execution: ~15 min (2 agents in parallel)
- Merge & verify: ~5 min
- Total (SAW): ~50 min
- Sequential baseline: ~60 min (4 agents × 15 min sequential)
- Time savings: ~10 min (17% faster)

**Recommendation:** Proceed with caveats acknowledged. Primary value is coordination consistency, not speed.

---

## Scaffolds

No scaffolds needed — agents have independent type ownership. No shared types cross agent boundaries; this is a markdown spec repo with no compiled types.

---

## Pre-Mortem

**Overall risk:** low

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Wave 2 agents reference E-rule numbers that Wave 1 assigned differently (e.g., Wave 1 uses E17, Wave 2 writes E18) | medium | high | Interface contract locks the exact E-rule number assignments before Wave 1 launches; Wave 2 agents must use those numbers verbatim |
| Wave 2 agent for scout.md uses "SAW.md" instead of "CONTEXT.md" (ROADMAP uses both names) | medium | medium | Agent prompts explicitly flag the rename: "Use CONTEXT.md everywhere; ignore SAW.md name in ROADMAP" |
| Agent B (execution-rules.md) writes orchestrator behavior that contradicts Agent A's message-formats.md schema (e.g., different `failure_type` values) | low | high | Interface contract specifies the exact four `failure_type` values verbatim; both agents implement against that contract |
| Agent C (scout.md) and Agent D (wave-agent.md) both add CONTEXT.md reading instructions with inconsistent descriptions | low | medium | Agent C owns the canonical CONTEXT.md schema description; Agent D's prompt references it with a cross-link, not a re-definition |
| Cascade: `saw-skill.md` references `status: partial/blocked` handling that should be updated for `failure_type` | low | low | Listed as cascade candidate; orchestrator updates it post-merge if needed |

---

## Known Issues

None identified. This is a markdown-only repo with no existing test suite or build system.

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — protocol spec foundation):
    [A] protocol/message-formats.md
         Add CONTEXT.md schema section and failure_type field to completion-report schema.
         ✓ root (no dependencies on other agents)

    [B] protocol/execution-rules.md
         Add E17 (Scout reads CONTEXT.md), E18 (Orchestrator updates CONTEXT.md), E19 (failure_type orchestrator decision tree).
         ✓ root (no dependencies on other agents)

Wave 2 (2 parallel agents — implementation prompt layer, depends on Wave 1):
    [C] implementations/claude-code/prompts/agents/scout.md
         Update scout prompt: read CONTEXT.md before suitability gate, reference E17/E18, document CONTEXT.md schema.
         depends on: [A] [B]

    [D] implementations/claude-code/prompts/agents/wave-agent.md
         implementations/claude-code/prompts/agent-template.md
         Update wave-agent prompt and agent template: add failure_type to completion report format, reference E19.
         depends on: [A] [B]
```

Cascade candidates (files NOT in any agent's scope but referencing interfaces that will change semantically):
- `implementations/claude-code/prompts/saw-skill.md` — references `status: partial/blocked` handling in orchestrator logic (step 4 of wave execution loop). After merge, orchestrator should verify whether E19's new decision tree needs a brief mention here.
- `protocol/procedures.md` — references `status: partial` / `status: blocked` at lines 233–236 and 398–420. E19's failure_type decision tree may warrant a note here.
- `implementations/claude-code/prompts/saw-merge.md` — references `status: blocked` handling at lines 11, 35, 158, 175. Failure taxonomy affects merge behavior; orchestrator should review post-merge.
- `saw-teams/saw-teams-skill.md`, `saw-teams/saw-teams-merge.md` — parallel saw-teams implementation also uses `status: partial/blocked` pattern; may need `failure_type` added in a future pass.

---

## Interface Contracts

These are the binding contracts that both waves implement against. Wave 2 agents must use these values verbatim.

### Contract 1: `failure_type` enumeration

The four valid `failure_type` values (from ROADMAP.md):

```
transient   — intermittent failure (network, git lock, flaky test). Orchestrator retries automatically.
fixable     — agent hit a concrete blocker but knows the fix. Orchestrator applies fix and relaunches.
needs_replan — agent found IMPL doc decomposition is wrong. Orchestrator re-engages Scout.
escalate    — no recovery path. Human intervention required.
```

**Completion report schema addition** (Agent A defines in message-formats.md, Agent D uses in agent-template.md):

```yaml
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate  # required when status is partial or blocked; omit when status is complete
```

`failure_type` is OPTIONAL when `status: complete`. It is REQUIRED when `status: partial` or `status: blocked`. Agent A must document this conditionality in message-formats.md.

### Contract 2: E-rule number assignments

Wave 1 agents must assign these exact E-rule numbers (E16 is the last existing rule):

- **E17** — Scout reads `docs/CONTEXT.md` if present (Agent B defines in execution-rules.md)
- **E18** — Orchestrator updates `docs/CONTEXT.md` after each completed feature (Agent B defines in execution-rules.md)
- **E19** — Orchestrator failure_type decision tree (Agent B defines in execution-rules.md)

Wave 2 agents (C and D) must reference E17, E18, E19 by these exact numbers.

### Contract 3: `docs/CONTEXT.md` schema

Agent A defines the schema in message-formats.md. Agent C references it in scout.md. The canonical schema (from ROADMAP.md, translated to CONTEXT.md naming):

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

**Key naming rule:** The file is `docs/CONTEXT.md`. ROADMAP.md uses `docs/SAW.md` — that name is superseded. All agents must use `CONTEXT.md` everywhere.

### Contract 4: Orchestrator update trigger (E18)

After each feature's final wave post-merge verification passes (WAVE_VERIFIED → COMPLETE transition, same trigger as E15), orchestrator appends to `docs/CONTEXT.md`:
- `decisions` — any architectural decisions made during this feature
- `established_interfaces` — any new cross-agent interfaces committed as scaffold files
- `features_completed` — one entry for this feature

If `docs/CONTEXT.md` does not exist, orchestrator creates it with the schema above before appending.

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/message-formats.md | A | 1 | — |
| protocol/execution-rules.md | B | 1 | — |
| implementations/claude-code/prompts/agents/scout.md | C | 2 | A, B |
| implementations/claude-code/prompts/agents/wave-agent.md | D | 2 | A, B |
| implementations/claude-code/prompts/agent-template.md | D | 2 | A, B |
| implementations/claude-code/prompts/saw-skill.md | E | 2 | A, B |
| implementations/claude-code/prompts/saw-merge.md | E | 2 | A, B |
| protocol/procedures.md | E | 2 | A, B |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B]                 <- 2 parallel agents (protocol spec foundation)
              | (A+B complete)
Wave 2: [C] [D] [E]             <- 3 parallel agents (implementation prompt layer)
```

---

## Wave 1

Wave 1 delivers the protocol spec foundation: the `docs/CONTEXT.md` schema in `message-formats.md` (Agent A) and the three new E-rules (E17, E18, E19) in `execution-rules.md` (Agent B). These two files are fully independent — neither references the other for these additions. Both agents run in parallel.

Wave 2 cannot launch until both A and B complete, because Wave 2 agents must cross-reference the exact E-rule numbers and `failure_type` values that Wave 1 defines.

### Agent A — Protocol Spec: message-formats.md

You are Wave 1 Agent A. Your task is to add two new protocol spec sections to `protocol/message-formats.md`: the `docs/CONTEXT.md` schema definition and the `failure_type` field addition to the completion report schema.

#### 0. CRITICAL: Isolation Verification (RUN FIRST)

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-a

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-a"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-a"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

If verification fails: write error to completion report and stop. Do NOT modify files.

#### 1. File Ownership

You own exactly one file:
- `protocol/message-formats.md` — modify

Do not touch any other file.

#### 2. Interfaces You Must Implement

**Addition 1: `failure_type` field in the completion report schema**

In the `## Typed Metadata Blocks` section, under `impl-completion-report`, add `failure_type` to the YAML schema example:

```yaml
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate  # required when status is partial or blocked; omit when status is complete
```

In the `## Completion Report Format` section (the canonical schema block), add the same field and document its conditionality:

```yaml
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate
  # Required when status is partial or blocked.
  # Omit (or set to null) when status is complete.
```

Add a field definition entry for `failure_type` in the Field definitions list:

- **failure_type:**
  - `transient` — intermittent failure (network, git lock, flaky test). Orchestrator may retry automatically (see E19).
  - `fixable` — agent hit a concrete blocker but knows the fix (e.g., missing dependency, wrong import path). Orchestrator applies fix and relaunches.
  - `needs_replan` — agent discovered the IMPL doc decomposition is wrong (ownership conflict, undiscoverable interface, scope larger than estimated). Orchestrator re-engages Scout with agent's findings as additional context.
  - `escalate` — agent cannot continue and has no recovery path. Human intervention required.
  - Required when `status` is `partial` or `blocked`. Omit when `status` is `complete`.

Also update the Orchestrator Parsing Requirements section to add `failure_type` as a parsed field:

> **6. Failure type:** `failure_type: transient | fixable | needs_replan | escalate` — drives automatic remediation decision tree (E19). Present only when `status` is `partial` or `blocked`.

**Addition 2: `docs/CONTEXT.md` schema section**

Add a new top-level section `## docs/CONTEXT.md — Project Memory` to the document. Place it after the `## Scaffolds Section Format` section and before the `## Pre-Mortem Section Format` section (or at the end of the document if that ordering is cleaner — your judgment). The section must contain:

1. A brief description: what CONTEXT.md is, when it is created (first `/saw scout` run on a project), and when it is updated (after each feature completes, E18).
2. The canonical schema (from Interface Contracts §Contract 3 above — use exactly that YAML structure).
3. A note: "Scout reads `docs/CONTEXT.md` before the suitability gate if the file is present (E17). If absent, Scout proceeds normally. The Orchestrator creates or updates the file after each completed feature (E18)."
4. A note on the file name: "The file is named `docs/CONTEXT.md`. This name was chosen because it describes what the file is (project context). Do not use `docs/SAW.md`."

#### 3. Interfaces You May Call

No cross-agent dependencies. Read the current `protocol/message-formats.md` in full before editing to understand document structure and placement.

#### 4. What to Implement

Read `protocol/message-formats.md` in full first. Then make two surgical additions:

1. Add `failure_type` to the completion report schema in two places: the `impl-completion-report` typed block example (in `## Typed Metadata Blocks`) and the canonical schema block in `## Completion Report Format`. Add field definitions and update the Orchestrator Parsing Requirements.

2. Add the `## docs/CONTEXT.md — Project Memory` section with the canonical schema. The section is self-contained prose + YAML, not a typed block (it is excluded from validator scope like other prose sections).

Do not restructure or reformat any existing content. Add only what is specified. Maintain the document's existing style (version header, horizontal rules between sections, field definition lists).

#### 5. Tests to Write

This is a markdown spec file — no automated tests. Instead, verify by inspection:

1. Read your changes back and confirm `failure_type` appears in both the typed block example and the canonical schema.
2. Confirm the field definitions list includes all four `failure_type` values with descriptions matching the Interface Contracts verbatim.
3. Confirm the `docs/CONTEXT.md` schema section contains all top-level keys: `created`, `protocol_version`, `architecture`, `decisions`, `conventions`, `established_interfaces`, `features_completed`.
4. Confirm E17, E18, E19 are referenced correctly (you are documenting they exist; the E-rule text itself lives in execution-rules.md which Agent B owns).
5. Confirm the file uses `CONTEXT.md` and not `SAW.md` everywhere.

#### 6. Verification Gate

```bash
# Navigate to worktree and verify the file renders as valid markdown
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-a

# Confirm failure_type appears in the completion report schema
grep -n "failure_type" protocol/message-formats.md

# Confirm CONTEXT.md schema section exists
grep -n "CONTEXT.md" protocol/message-formats.md

# Confirm SAW.md is NOT used (should return nothing or only ROADMAP references)
grep -n "docs/SAW\.md" protocol/message-formats.md

# Confirm E17, E18 are referenced
grep -n "E17\|E18\|E19" protocol/message-formats.md
```

All checks must pass (failure_type present, CONTEXT.md schema present, no docs/SAW.md, E-rule references present).

#### 7. Constraints

- Use `CONTEXT.md` exclusively. Do not write `SAW.md` anywhere.
- The four `failure_type` values must be spelled exactly: `transient`, `fixable`, `needs_replan`, `escalate`. No variations.
- `failure_type` is OPTIONAL when `status: complete`, REQUIRED when `status: partial` or `status: blocked`. Document this conditionality explicitly.
- E-rule numbers E17, E18, E19 are assigned in execution-rules.md (Agent B's file). You reference them but do not define their text. Write them as cross-references only: "(see E17)", "(E18)", "(E19)".
- Do not add the `## docs/CONTEXT.md` section as a typed block. It is free-form prose, like Pre-Mortem and Scaffolds sections.
- Do not modify any existing schema fields or completion report fields — only add new ones.

#### 8. Report

Commit your changes to the worktree branch before writing the report:

```bash
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-a add protocol/message-formats.md
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-a commit -m "wave1-agent-a: add failure_type to completion report + CONTEXT.md schema to message-formats.md"
```

Then append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-context-and-failure-taxonomy.md`:

```
### Agent A - Completion Report

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: .claude/worktrees/wave1-agent-a
branch: wave1-agent-a
commit: {sha}
files_changed:
  - protocol/message-formats.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL
```

{Free-form notes}
```

---

### Agent B — Protocol Spec: execution-rules.md

You are Wave 1 Agent B. Your task is to add three new execution rules (E17, E18, E19) to `protocol/execution-rules.md`.

#### 0. CRITICAL: Isolation Verification (RUN FIRST)

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-b

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-b"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-b"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

If verification fails: write error to completion report and stop. Do NOT modify files.

#### 1. File Ownership

You own exactly one file:
- `protocol/execution-rules.md` — modify

Do not touch any other file.

#### 2. Interfaces You Must Implement

Add three new rules after the existing E16 rule. The E-rule numbers are binding — use exactly E17, E18, E19.

**E17: Scout Reads Project Memory**

```
## E17: Scout Reads Project Memory

**Trigger:** Scout begins a new suitability assessment

**Required Action:** Before running the suitability gate, the Scout checks for
`docs/CONTEXT.md` in the target project. If the file exists, Scout reads it in
full and uses its contents to inform the suitability assessment:
- `established_interfaces` — avoids proposing types that already exist
- `decisions` — respects prior architectural decisions; does not contradict them
- `conventions` — follows project naming, error handling, and testing conventions
- `features_completed` — understands project history and prior wave structure

**If absent:** Scout proceeds normally without it. `docs/CONTEXT.md` is optional;
projects that have never completed a SAW feature will not have one.

**Rationale:** Without project memory, each Scout run starts cold. After several
features, the project accumulates naming conventions, module boundaries, and
interface decisions that the Scout would otherwise rediscover (expensively) or
miss entirely.

**Related Rules:** See E18 (Orchestrator creates/updates docs/CONTEXT.md after
each completed feature).
```

**E18: Orchestrator Updates Project Memory**

```
## E18: Orchestrator Updates Project Memory

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE
transition — same trigger as E15)

**Required Action:** The Orchestrator creates or updates `docs/CONTEXT.md` in the
target project:

1. If `docs/CONTEXT.md` does not exist, create it with the schema defined in
   `message-formats.md` (## docs/CONTEXT.md — Project Memory section).

2. Append to `features_completed`:
   ```yaml
   - slug: {feature-slug}
     impl_doc: docs/IMPL/IMPL-{feature-slug}.md
     waves: {N}
     agents: {total agent count}
     date: {YYYY-MM-DD}
   ```

3. Append any architectural decisions made during this feature to `decisions`.
   Decisions are identified from interface contracts and any `out_of_scope_deps`
   resolutions that reveal project conventions.

4. Append any new scaffold-file interfaces to `established_interfaces`. An
   interface is "established" if it was committed as a scaffold file and is now
   part of the project's public module boundary.

5. Commit: `git commit -m "chore: update docs/CONTEXT.md for {feature-slug}"`

**Constraint:** E18 runs after E15 (IMPL doc completion marker). The commit order
is: E15 writes `<!-- SAW:COMPLETE -->` to the IMPL doc, then E18 updates
`docs/CONTEXT.md`, then a single commit captures both.

**When to omit:** If no new decisions, interfaces, or conventions were established
during the feature, E18 still appends to `features_completed` but may omit the
other fields.

**Related Rules:** See E15 (IMPL doc completion marker), E17 (Scout reads project
memory).
```

**E19: Failure Type Decision Tree**

```
## E19: Failure Type Decision Tree

**Trigger:** Any agent reports `status: partial` or `status: blocked` with a
`failure_type` field

**Required Action:** The Orchestrator reads `failure_type` and applies the
corresponding action:

| failure_type   | Orchestrator action |
|----------------|---------------------|
| `transient`    | Retry automatically, up to 2 times. If all retries fail, escalate to human. Log each retry attempt. |
| `fixable`      | Read agent's free-form notes for the specific fix. Apply the fix (install dependency, correct path, update config). Relaunch the agent. One retry only; if it fails again, escalate. |
| `needs_replan` | Do not retry. Re-engage Scout with the agent's completion report as additional context. Scout produces a revised IMPL doc. Human reviews before wave re-executes. |
| `escalate`     | Surface immediately to human with agent's full completion report. No automatic action. |

**Backward compatibility:** If `failure_type` is absent from a completion report
that has `status: partial` or `status: blocked`, treat as `escalate` (most
conservative fallback). This preserves compatibility with agents that predate E19.

**Relationship to E7:** E7 defines the general failure handling rule (wave does
not merge, enters BLOCKED state). E19 is the decision tree within that BLOCKED
state — it specifies what the Orchestrator does next based on failure classification.
E7 and E19 are complementary; E19 does not supersede E7.

**Relationship to E7a:** E7a defines automatic remediation for correctable failures
in `--auto` mode. E19 extends this to non-`--auto` mode for `transient` and
`fixable` failures. In `--auto` mode, E7a and E19 apply together; E7a's retry
limit (2 retries) applies.

**Related Rules:** See E7 (agent failure handling), E7a (automatic failure
remediation), message-formats.md (failure_type field definition).
```

#### 3. Interfaces You May Call

No cross-agent dependencies. Read `protocol/execution-rules.md` in full before editing.

#### 4. What to Implement

Read `protocol/execution-rules.md` in full first. Append the three new rules (E17, E18, E19) after the existing E16 rule block. Each rule follows the document's established format: `## E{N}: {Name}`, trigger, required action, rationale, cross-references. Maintain the document's existing style exactly.

Update the `## Cross-References` section at the bottom to add references to the new E-rules and their related files.

Do not modify any existing rules. Add only the three new rules and update the cross-references footer.

#### 5. Tests to Write

Verification by inspection:

1. Confirm E17, E18, E19 appear in the file with exactly those numbers.
2. Confirm E17 trigger is "Scout begins a new suitability assessment."
3. Confirm E18 trigger is the WAVE_VERIFIED → COMPLETE transition (matching E15's trigger).
4. Confirm E19 contains a decision table with all four `failure_type` values: `transient`, `fixable`, `needs_replan`, `escalate`.
5. Confirm backward-compatibility note is present in E19 (absent `failure_type` → treat as `escalate`).
6. Confirm cross-references section is updated.
7. Confirm no existing E-rules were modified.

#### 6. Verification Gate

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-b

# Confirm E17, E18, E19 exist
grep -n "^## E17\|^## E18\|^## E19" protocol/execution-rules.md

# Confirm all four failure_type values appear in E19
grep -n "transient\|fixable\|needs_replan\|escalate" protocol/execution-rules.md

# Confirm E16 is still present and unchanged
grep -n "^## E16" protocol/execution-rules.md

# Confirm no SAW.md reference (should be CONTEXT.md)
grep -n "docs/SAW\.md" protocol/execution-rules.md

# Confirm CONTEXT.md is referenced correctly
grep -n "CONTEXT\.md" protocol/execution-rules.md
```

All checks must pass (E17/E18/E19 present, all four failure_type values present, E16 intact, no SAW.md, CONTEXT.md references correct).

#### 7. Constraints

- Use rule numbers E17, E18, E19 exactly. These are binding (Wave 2 agents reference them).
- The four `failure_type` values must be spelled exactly: `transient`, `fixable`, `needs_replan`, `escalate`.
- Use `CONTEXT.md` (not `SAW.md`) in all E-rule text.
- E18 commit order constraint: after E15, not before. Document this explicitly.
- E19 backward compatibility note is required: absent `failure_type` → treat as `escalate`.
- Do not modify E1–E16. Append only.

#### 8. Report

Commit before reporting:

```bash
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-b add protocol/execution-rules.md
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-b commit -m "wave1-agent-b: add E17 (read CONTEXT.md), E18 (update CONTEXT.md), E19 (failure_type decision tree) to execution-rules.md"
```

Then append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-context-and-failure-taxonomy.md`:

```
### Agent B - Completion Report

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: .claude/worktrees/wave1-agent-b
branch: wave1-agent-b
commit: {sha}
files_changed:
  - protocol/execution-rules.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL
```

{Free-form notes}
```

---

## Wave 2

Wave 2 delivers the implementation prompt layer: updates to `scout.md` (Agent C) and `wave-agent.md` + `agent-template.md` (Agent D). These agents MUST wait for both Wave 1 agents to complete because they reference E17, E18 (defined by Agent B) and the `failure_type` values and `CONTEXT.md` schema (defined by Agent A).

Before launching Wave 2: read Agent A and Agent B's completion reports from this IMPL doc. Confirm both show `status: complete`. Then merge Wave 1 branches to main and create Wave 2 worktrees from the updated main.

### Agent C — Scout Prompt: scout.md

You are Wave 2 Agent C. Your task is to update `implementations/claude-code/prompts/agents/scout.md` to add CONTEXT.md reading to the Scout's pre-flight process.

#### 0. CRITICAL: Isolation Verification (RUN FIRST)

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-c

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-c"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-c"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

If verification fails: write error to completion report and stop. Do NOT modify files.

#### 1. File Ownership

You own exactly one file:
- `implementations/claude-code/prompts/agents/scout.md` — modify

Do not touch any other file.

#### 2. Interfaces You Must Implement

Add a new step to the Scout's `## Process` section. The new step must be inserted as the first step, before the current "Step 1: Read the project first." Renumber existing steps accordingly (current Step 1 becomes Step 2, etc.). The new step text:

```
1. **Read project memory.** Before running the suitability gate, check for
   `docs/CONTEXT.md` in the target project. If present, read it in full (E17).
   Use its contents to inform your analysis:
   - `established_interfaces` — do not propose types that already exist here
   - `decisions` — respect prior architectural decisions; do not contradict them
   - `conventions` — follow the project's naming, error handling, and testing style
   - `features_completed` — understand project history and avoid repeating approaches

   If `docs/CONTEXT.md` is absent, proceed normally. The file is optional; new
   projects will not have one.
```

Also update the `## Suitability Gate` section to add a note in step 4 (Pre-implementation status check) referencing CONTEXT.md:

> **CONTEXT.md cross-check:** After reading `docs/CONTEXT.md` (Step 1 of Process), also check `established_interfaces` for any interfaces that overlap with the feature being planned. If an interface already exists and matches what you would define, reference it in the IMPL doc's Interface Contracts section rather than redefining it.

#### 3. Interfaces You May Call

Read `protocol/execution-rules.md` (specifically E17 and E18, added by Wave 1 Agent B) and `protocol/message-formats.md` (specifically the `## docs/CONTEXT.md — Project Memory` section added by Wave 1 Agent A) to understand the canonical schema before writing your additions.

#### 4. What to Implement

Read `implementations/claude-code/prompts/agents/scout.md` in full first. Then:

1. Insert the new Step 1 (CONTEXT.md reading) at the top of the `## Process` section.
2. Renumber all existing steps (old 1→2, 2→3, ..., 10→11).
3. Update any internal step references within the document (e.g., "step 4" cross-references in the suitability gate section may need updating).
4. Add the CONTEXT.md cross-check note to the suitability gate step 4.
5. Bump the version comment at the top of the file: `<!-- scout v0.5.0 -->` (was v0.4.0).

Do not change the suitability gate logic, wave structure guidance, agent prompt format, or any other section. Add only the CONTEXT.md reading step and the cross-check note.

#### 5. Tests to Write

Verification by inspection:

1. Confirm new Step 1 appears at the top of the `## Process` section.
2. Confirm the old steps are renumbered (old Step 1 "Read the project first" is now Step 2, and so on up to Step 11).
3. Confirm E17 is referenced in the new step.
4. Confirm `CONTEXT.md` appears and `SAW.md` does not appear in your additions.
5. Confirm version is bumped to v0.5.0.
6. Confirm the CONTEXT.md cross-check note appears in the suitability gate step 4.

#### 6. Verification Gate

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-c

# Confirm CONTEXT.md reading step is present
grep -n "CONTEXT\.md\|project memory" implementations/claude-code/prompts/agents/scout.md

# Confirm E17 is referenced
grep -n "E17" implementations/claude-code/prompts/agents/scout.md

# Confirm SAW.md is not used
grep -n "docs/SAW\.md" implementations/claude-code/prompts/agents/scout.md

# Confirm version bump
grep -n "scout v" implementations/claude-code/prompts/agents/scout.md

# Confirm step renumbering (old Step 1 is now Step 2)
grep -n "^2\. \*\*Read the project first" implementations/claude-code/prompts/agents/scout.md
```

All checks must pass.

#### 7. Constraints

- Use `CONTEXT.md` (not `SAW.md`) everywhere.
- Reference E17 by number in the new step.
- Do not alter the suitability gate logic or any existing section content beyond the targeted additions.
- Renumber ALL steps — do not leave gaps or duplicates.
- The new step is Step 1; it runs before "Read the project first" (which becomes Step 2).
- Version bump to v0.5.0 is required.

#### 8. Report

Commit before reporting:

```bash
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-c add implementations/claude-code/prompts/agents/scout.md
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-c commit -m "wave2-agent-c: add CONTEXT.md reading step to scout.md (E17)"
```

Then append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-context-and-failure-taxonomy.md`:

```
### Agent C - Completion Report

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: .claude/worktrees/wave2-agent-c
branch: wave2-agent-c
commit: {sha}
files_changed:
  - implementations/claude-code/prompts/agents/scout.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL
```

{Free-form notes}
```

---

### Agent D — Wave Agent Prompts: wave-agent.md + agent-template.md

You are Wave 2 Agent D. Your task is to add `failure_type` to the completion report format in both `implementations/claude-code/prompts/agents/wave-agent.md` and `implementations/claude-code/prompts/agent-template.md`.

#### 0. CRITICAL: Isolation Verification (RUN FIRST)

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-d

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-d"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-d"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

If verification fails: write error to completion report and stop. Do NOT modify files.

#### 1. File Ownership

You own these two files:
- `implementations/claude-code/prompts/agents/wave-agent.md` — modify
- `implementations/claude-code/prompts/agent-template.md` — modify

Do not touch any other file.

#### 2. Interfaces You Must Implement

**In `wave-agent.md`:** In the `## Completion Report` section, add `failure_type` to the YAML template block:

```yaml
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate  # required when status is partial or blocked
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

Also update the `## If You Get Stuck` section to reference `failure_type`:

- Under "Partial completion": add "Set `failure_type` to `fixable` if you know what needs fixing, or `needs_replan` if the IMPL doc decomposition itself is wrong."
- Under "Blocked on interface contract": add "Set `failure_type: needs_replan` — this signals the Orchestrator to re-engage Scout with your findings."

**In `agent-template.md`:** In the Field 8 (Report) section, update the YAML template block to add `failure_type`:

```yaml
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate
  # Required when status is partial or blocked. Omit when status is complete.
worktree: .claude/worktrees/wave{N}-agent-{letter}
branch: wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
files_created:
  - path/to/new/file
interface_deviations:
  - "Exact description of any deviation from the spec contract, or []"
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why"  # or []
tests_added:
  - test_function_name
verification: PASS | FAIL ({command} - N/N tests)
```

Add a brief note after the YAML block:

> **failure_type guidance:** When `status` is `partial` or `blocked`, choose the `failure_type` that best describes why:
> - `transient` — you hit a network error, git lock, or flaky test; retrying would likely succeed
> - `fixable` — you know the specific fix (missing dependency, wrong path); describe it in your notes
> - `needs_replan` — the IMPL doc decomposition is wrong (ownership conflict, undiscoverable interface); describe what the Scout got wrong
> - `escalate` — no path forward; human judgment required

Also update the version comment: `<!-- agent-template v0.3.9 -->` (was v0.3.8).

Also update the E14 cross-reference note in Field 8 to mention E19:

> **E14: IMPL doc write discipline.** [...existing text...] **E19: Failure type.** When reporting `status: partial` or `status: blocked`, the `failure_type` field enables the Orchestrator to apply the appropriate remediation strategy automatically rather than always surfacing to the human.

#### 3. Interfaces You May Call

Read `protocol/message-formats.md` (the `failure_type` field definition added by Wave 1 Agent A) and `protocol/execution-rules.md` (E19 added by Wave 1 Agent B) before writing your additions. These define the canonical behavior that your prompt additions must document accurately.

#### 4. What to Implement

Read both files in full first. Then make targeted additions:

1. `wave-agent.md`: Add `failure_type` to the YAML completion report template. Update the "If You Get Stuck" section with failure_type guidance. Keep all existing content intact.

2. `agent-template.md`: Add `failure_type` to the Field 8 YAML template. Add the failure_type guidance note. Add the E19 cross-reference. Bump version to v0.3.9.

Do not change Field 0–7 content, the isolation verification logic, the verification gate section, or any other section. Add only what is specified.

#### 5. Tests to Write

Verification by inspection:

1. Confirm `failure_type` appears in both files' YAML template blocks.
2. Confirm the four values `transient`, `fixable`, `needs_replan`, `escalate` appear in both files.
3. Confirm `failure_type` is positioned immediately after `status` in the YAML (before `worktree`).
4. Confirm conditionality note ("required when status is partial or blocked") appears in both files.
5. Confirm E19 is referenced in `agent-template.md`.
6. Confirm version bump to v0.3.9 in `agent-template.md`.
7. Confirm `wave-agent.md`'s "If You Get Stuck" section has been updated.

#### 6. Verification Gate

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-d

# Confirm failure_type in wave-agent.md
grep -n "failure_type" implementations/claude-code/prompts/agents/wave-agent.md

# Confirm failure_type in agent-template.md
grep -n "failure_type" implementations/claude-code/prompts/agent-template.md

# Confirm all four values appear in agent-template.md
grep -n "transient\|fixable\|needs_replan\|escalate" implementations/claude-code/prompts/agent-template.md

# Confirm E19 referenced in agent-template.md
grep -n "E19" implementations/claude-code/prompts/agent-template.md

# Confirm version bump in agent-template.md
grep -n "agent-template v" implementations/claude-code/prompts/agent-template.md

# Confirm no SAW.md references
grep -n "docs/SAW\.md" implementations/claude-code/prompts/agents/wave-agent.md implementations/claude-code/prompts/agent-template.md
```

All checks must pass.

#### 7. Constraints

- The four `failure_type` values must be spelled exactly: `transient`, `fixable`, `needs_replan`, `escalate`.
- `failure_type` must appear immediately after `status` in the YAML (this ordering matters for readability and parsers).
- Conditionality ("required when status is partial or blocked; omit when complete") must be explicit.
- Reference E19 by number in agent-template.md.
- Do not alter Field 0–7 content in agent-template.md.
- Version bump in agent-template.md is required (v0.3.9).
- Do not touch `scout.md` (Agent C's file).

#### 8. Report

Commit before reporting:

```bash
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-d add implementations/claude-code/prompts/agents/wave-agent.md implementations/claude-code/prompts/agent-template.md
git -C /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-d commit -m "wave2-agent-d: add failure_type to wave-agent.md and agent-template.md (E19)"
```

Then append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-context-and-failure-taxonomy.md`:

```
### Agent D - Completion Report

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate  # if not complete
worktree: .claude/worktrees/wave2-agent-d
branch: wave2-agent-d
commit: {sha}
files_changed:
  - implementations/claude-code/prompts/agents/wave-agent.md
  - implementations/claude-code/prompts/agent-template.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL
```

{Free-form notes}
```

---

### Agent E — Orchestrator Files: saw-skill.md + saw-merge.md + procedures.md

You are Wave 2 Agent E. Your task is to update three orchestrator-facing files to reference the new `failure_type` field and CONTEXT.md E-rules defined by Wave 1.

#### 0. CRITICAL: Isolation Verification (RUN FIRST)

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-e

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claire/worktrees/wave2-agent-e"
# Accept either .claude or .claire path
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ] && [ "$ACTUAL_DIR" != "/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-e" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
if [ "$ACTUAL_BRANCH" != "wave2-agent-e" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

#### 1. File Ownership

You own exactly three files:
- `implementations/claude-code/prompts/saw-skill.md` — modify
- `implementations/claude-code/prompts/saw-merge.md` — modify
- `protocol/procedures.md` — modify

Do not touch any other file.

#### 2. Read Wave 1 Output First

Before making any edits, read the current state of these files (Wave 1 agents may have modified them — they did not, but verify):
- `protocol/execution-rules.md` — find E17, E18, E19 and their exact wording
- `protocol/message-formats.md` — find the exact `failure_type` values and conditionality rules

Use those exact E-rule numbers and `failure_type` values in your edits. Do not invent or change them.

#### 3. Changes to `saw-skill.md`

This is the Orchestrator skill prompt. It references `status: partial/blocked` handling in the wave execution loop (step 4). Update it to:

1. **Wave execution loop step 4** — where it currently says agents with `status: partial` or `status: blocked` cause the wave to go BLOCKED, add: "Read the `failure_type` field on any non-complete agent (see E19 in `protocol/execution-rules.md`). The failure type drives automatic remediation: `transient` → retry automatically; `fixable` → apply fix and relaunch; `needs_replan` → re-engage Scout with agent's findings; `escalate` → surface to human immediately."

2. **CONTEXT.md update step** — after the E15 completion marker step (step 6), add a new step: "**E18: Update CONTEXT.md.** If `docs/CONTEXT.md` exists in the project root, append this feature's architectural decisions, any new established interfaces from scaffold files, and a `features_completed` entry. If `docs/CONTEXT.md` does not exist, create it using the schema defined in `protocol/message-formats.md`. Commit the update."

Keep the surrounding text and structure intact. Only insert the new content; do not rewrite sections you are not adding to.

#### 4. Changes to `saw-merge.md`

This is the merge procedure document. It references `status: blocked` handling (Step 1, the completion report parsing step). Update it to:

In the Step 1 section where it says "if any agent has `status: partial` or `status: blocked`, the wave does not proceed to merge", add: "Also read `failure_type` on any non-complete agent and record it in your assessment. `failure_type: transient` or `fixable` may be automatically remediable before escalating to BLOCKED — see E19 in `protocol/execution-rules.md`. `failure_type: needs_replan` or `escalate` always surface to the human."

Do not restructure the merge procedure. Only insert the failure_type reference at the appropriate point.

#### 5. Changes to `procedures.md`

Read the file first to find the sections at lines ~233–236 and ~398–420 that reference `status: partial` / `status: blocked` handling. Add a parenthetical note at each occurrence: "(see `failure_type` field in E19 for automatic remediation decision tree)".

If the line numbers have shifted, search for "status: partial" and "status: blocked" to find the right locations.

#### 6. Verification

After all edits:
1. Re-read each file you modified and confirm `failure_type` is referenced correctly
2. Confirm E17, E18, E19 numbers match what you read from `protocol/execution-rules.md`
3. Confirm `CONTEXT.md` (not `SAW.md`) is used everywhere you wrote it

#### 7. Commit

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-e
git add implementations/claude-code/prompts/saw-skill.md \
        implementations/claude-code/prompts/saw-merge.md \
        protocol/procedures.md
git commit -m "feat(wave2-agent-e): failure_type + CONTEXT.md refs in saw-skill, saw-merge, procedures"
```

#### 8. Completion Report

Append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-context-and-failure-taxonomy.md`:

```
### Agent E - Completion Report

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate  # if not complete
worktree: .claude/worktrees/wave2-agent-e
branch: wave2-agent-e
commit: {sha}
files_changed:
  - implementations/claude-code/prompts/saw-skill.md
  - implementations/claude-code/prompts/saw-merge.md
  - protocol/procedures.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL
```

{Free-form notes}
```

---

## Wave Execution Loop

After each wave completes, work through the checklist below in order.

Key principles:
- Read completion reports first — a `status: partial` or `status: blocked` blocks the merge entirely. No partial merges.
- No automated build/test cycle for this repo (markdown only). Verification is manual inspection by the agent.
- Cascade candidates (saw-skill.md, procedures.md, saw-merge.md) are NOT in any agent's scope — review them post-merge and update manually if needed.

### Orchestrator Post-Merge Checklist

After Wave 1 completes:

- [ ] Read Agent A and Agent B completion reports — confirm both `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; A owns message-formats.md, B owns execution-rules.md — no overlap expected
- [ ] Review `interface_deviations` — if Agent A or B deviated from the binding E-rule numbers or `failure_type` values, update downstream agent prompts (C and D) before Wave 2 launches
- [ ] Merge Agent A: `git merge --no-ff wave1-agent-a -m "Merge wave1-agent-a: failure_type + CONTEXT.md schema to message-formats.md"`
- [ ] Merge Agent B: `git merge --no-ff wave1-agent-b -m "Merge wave1-agent-b: E17/E18/E19 to execution-rules.md"`
- [ ] Worktree cleanup: `git worktree remove .claude/worktrees/wave1-agent-a && git branch -d wave1-agent-a`; same for wave1-agent-b
- [ ] Post-merge verification (manual):
  - [ ] Linter auto-fix pass: n/a (markdown only)
  - [ ] Read `protocol/message-formats.md` — confirm `failure_type` field and `docs/CONTEXT.md` section are present and correct
  - [ ] Read `protocol/execution-rules.md` — confirm E17, E18, E19 are present with correct trigger/action/cross-reference text
  - [ ] Confirm `CONTEXT.md` (not `SAW.md`) used throughout
- [ ] Fix any cascade failures — check cascade candidates if references seem inconsistent
- [ ] Tick status checkboxes in this IMPL doc for A and B
- [ ] Update interface contracts if any deviations were logged
- [ ] Feature-specific steps:
  - [ ] Verify E-rule numbers in merged execution-rules.md match the binding contracts (E17, E18, E19) — if Agent B deviated, update Wave 2 agent prompts C and D before launch
- [ ] Commit: `git commit -m "merge: wave1 — CONTEXT.md schema + failure_type in message-formats.md, E17/E18/E19 in execution-rules.md"`
- [ ] Create Wave 2 worktrees from updated main
- [ ] Launch Wave 2 (Agents C and D)

After Wave 2 completes:

- [ ] Read Agent C and Agent D completion reports — confirm both `status: complete`
- [ ] Conflict prediction — C owns scout.md, D owns wave-agent.md + agent-template.md — no overlap expected
- [ ] Review `interface_deviations`
- [ ] Merge Agent C: `git merge --no-ff wave2-agent-c -m "Merge wave2-agent-c: CONTEXT.md reading step in scout.md (E17)"`
- [ ] Merge Agent D: `git merge --no-ff wave2-agent-d -m "Merge wave2-agent-d: failure_type in wave-agent.md + agent-template.md (E19)"`
- [ ] Worktree cleanup: same pattern as Wave 1
- [ ] Post-merge verification (manual):
  - [ ] Read `scout.md` — confirm new Step 1 (CONTEXT.md reading) is present, existing steps renumbered, version is v0.5.0
  - [ ] Read `wave-agent.md` — confirm `failure_type` in YAML template and "If You Get Stuck" guidance updated
  - [ ] Read `agent-template.md` — confirm `failure_type` in Field 8 YAML, guidance note, E19 reference, version v0.3.9
  - [ ] Spot-check cascade candidates: `saw-skill.md` (status handling), `procedures.md` (failure handling procedures), `saw-merge.md` (blocked state handling) — note any that should be updated in a follow-on
- [ ] Feature-specific steps:
  - [ ] Consider whether `protocol/procedures.md` lines 233–236 and 420 should reference E19 (out of scope for this wave; flag for follow-on if needed)
  - [ ] Consider whether `saw-skill.md` step 4 wave execution loop should mention `failure_type` (out of scope; flag for follow-on)
  - [ ] Create `docs/CONTEXT.md` for this repo (scout-and-wave) as a demonstration — optional, can be done manually
- [ ] Commit: `git commit -m "merge: wave2 — CONTEXT.md reading in scout.md, failure_type in wave-agent.md + agent-template.md"`
- [ ] Write E15 completion marker to IMPL doc
- [ ] Write E18 update to `docs/CONTEXT.md` (or create it for the first time for this repo)

### Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Add `failure_type` + `docs/CONTEXT.md` schema to `protocol/message-formats.md` | TO-DO |
| 1 | B | Add E17, E18, E19 to `protocol/execution-rules.md` | TO-DO |
| 2 | C | Add CONTEXT.md reading step to `implementations/claude-code/prompts/agents/scout.md` | TO-DO |
| 2 | D | Add `failure_type` to `wave-agent.md` and `agent-template.md` | TO-DO |
| — | Orch | Post-merge cascade review + optional docs/CONTEXT.md creation for this repo | TO-DO |

---

### Agent B - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-b
branch: wave1-agent-b
commit: 874e068
files_changed:
  - protocol/execution-rules.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All three rules appended after E16 in the established document format. E17, E18, and E19 headers confirmed present; all four `failure_type` values (`transient`, `fixable`, `needs_replan`, `escalate`) confirmed spelled correctly; E16 confirmed untouched; no `docs/SAW.md` references; all CONTEXT.md references use the correct filename. The Cross-References section was extended with entries for E17, E18, and E19 pointing to `message-formats.md` and related rules. No deviations from the specified rule text.

## Completion Reports

### Agent A - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-a
branch: wave1-agent-a
commit: 097e76d
files_changed:
  - protocol/message-formats.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All three additions landed in the correct locations:

1. `failure_type` added to the `impl-completion-report` typed block in the Typed Metadata Blocks section — matches the exact inline comment form specified.
2. `failure_type` added to the canonical schema in Completion Report Format with the three-line conditionality comment block, followed by a full field definition entry listing all four values with descriptions.
3. Item 6 added to the Orchestrator Parsing Requirements section covering `failure_type` and its E19 reference.
4. New `## docs/CONTEXT.md — Project Memory` section added between Scaffolds Section Format and Pre-Mortem Section Format, containing the description, canonical YAML schema, per-field documentation, and the usage/optionality note.

No existing content was modified beyond the four insertion points. `CONTEXT.md` naming (not `SAW.md`) is used consistently throughout. All four `failure_type` values (`transient`, `fixable`, `needs_replan`, `escalate`) are present and spelled exactly as specified.

### Agent D - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-d
branch: wave2-agent-d
commit: 1f92ea5ad9f90b7f1233fe21f1fc668defd93449
files_changed:
  - implementations/claude-code/prompts/agents/wave-agent.md
  - implementations/claude-code/prompts/agent-template.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All changes applied as specified. `failure_type` added immediately after `status` in the YAML completion report template in both files. The "If You Get Stuck" section in wave-agent.md updated with `failure_type` guidance for both partial and blocked cases. agent-template.md received the full `failure_type guidance` block, the E19 cross-reference note, and the version bump to v0.3.9. The E1–E16 reference in the preamble was also updated to E1–E19 for accuracy. No `docs/SAW.md` references found or introduced. All four `failure_type` values (`transient`, `fixable`, `needs_replan`, `escalate`) spelled exactly as specified.

### Agent C - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-c
branch: wave2-agent-c
commit: 1ed1313033970d7c2e0166ed0c9e9bef59b0745c
files_changed:
  - implementations/claude-code/prompts/agents/scout.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

New Step 1 inserted at top of Process section with E17 reference and all four CONTEXT.md sub-fields (`established_interfaces`, `decisions`, `conventions`, `features_completed`). Existing steps renumbered 1-10 to 2-11. Internal cross-reference "contracts in step 4" updated to "contracts in step 5" (in step 6 body). CONTEXT.md cross-check blockquote added inside Suitability Gate step 4. Version bumped to v0.5.0. No SAW.md references introduced. All five verification gate checks passed.

### Agent E - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-e
branch: wave2-agent-e
commit: 30e6cef
files_changed:
  - implementations/claude-code/prompts/saw-skill.md
  - implementations/claude-code/prompts/saw-merge.md
  - protocol/procedures.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All three insertions applied as specified. `failure_type`/E19 added to step 4 of the IMPL-exists wave execution loop in `saw-skill.md` (appended to the E8 paragraph). E18/CONTEXT.md step added to step 6 of `saw-skill.md` (appended to the E15 paragraph). `failure_type`/E19 note added to Step 1 of `saw-merge.md` in the `status` bullet. Parenthetical `(see failure_type field and E19 for automatic remediation decision tree)` added at all three distinct occurrences in `protocol/procedures.md`: Phase 5 check-for-failures bullets (two lines), error recovery step 1 read-completion-reports line, and the E8 recovery section cause line. No `docs/SAW.md` references introduced. All four `failure_type` values spelled exactly as in `message-formats.md`.
