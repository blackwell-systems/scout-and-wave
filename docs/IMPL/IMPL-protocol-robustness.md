# IMPL: Protocol Robustness — Typed Metadata Blocks, Validation Loop, Pre-Mortem
<!-- SAW:COMPLETE 2026-03-07 -->

**Feature:** Three protocol-level improvements: typed metadata blocks in IMPL docs, Scout output validation + correction loop (E16), and a Pre-Mortem section requirement.
**Repository:** /Users/dayna.blackwell/code/scout-and-wave
**Plan Reference:** ROADMAP.md § "Structured Output Parsing" — "Validation + Correction Loop", "Structured Metadata Blocks"; § "Protocol Enhancements" — "Pre-Mortem in Scout Output"

---

## Suitability Assessment

Verdict: SUITABLE WITH CAVEATS
test_command: none (documentation-only project; no build system)
lint_command: none

The work decomposes cleanly across 7 `.md` files in `protocol/` and `implementations/claude-code/prompts/`. Each file is owned by exactly one agent, and no two agents need conflicting changes to the same file. All three features are fully specified in `ROADMAP.md` — no investigation-first items. The cross-agent interface (the typed block syntax: `` ```yaml type=impl-* ``) is entirely defined by Agent A's work on `protocol/message-formats.md`; all downstream agents reference this spec, creating a Wave 1 / Wave 2 dependency. Parallelization savings are modest for documentation edits, but the coordination value is real: without disjoint ownership tracking, inconsistencies in how each file defines or references the typed block syntax are the primary failure mode. SUITABLE WITH CAVEATS: value is coordination consistency, not raw speed.

**Caveats:**
- No build system exists, so verification gates are markdown consistency checks only (agents must re-read their own output and cross-check against the spec in `message-formats.md`).
- The two legacy `prompts/scout.md` and `implementations/claude-code/prompts/agents/scout.md` files contain near-identical content. Agent C must update both — these are separate files with separate ownership, so this is not a conflict, but the agent must be aware both exist and keep them synchronized.

**Estimated times:**
- Scout phase: ~10 min
- Wave 1 execution: ~15 min (2 parallel agents)
- Wave 2 execution: ~15 min (3 parallel agents)
- Merge & verification: ~5 min
- Total (SAW): ~45 min
- Sequential baseline: ~60 min (5 agents × ~12 min sequential)
- Time savings: ~15 min (25% faster)

**Recommendation:** Proceed. Coordination value exceeds overhead; parallel agents reduce risk of typed-block syntax inconsistencies across files.

Pre-implementation scan results:
- Total items: 3 features (7 files)
- Already implemented: 0 items (0% of work)
- Partially implemented: 0 items
- To-do: 3 features (7 files)

Agent adjustments:
- All agents proceed as planned (to-do)

---

## Pre-Mortem

**Overall risk:** Medium

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Agent C writes mismatched typed-block examples in `scout.md` vs what Agent A defined in `message-formats.md` | medium | high | Agent C must read `message-formats.md` in full before editing; the interface contract below specifies exact syntax |
| Agent D (state-machine) or Agent E (participants) uses a state name that conflicts with Agent B's E16 definition | low | medium | Interface contract below locks the state name as `SCOUT_VALIDATING` and transition names; agents must use these verbatim |
| Legacy `prompts/scout.md` and `implementations/claude-code/prompts/agents/scout.md` diverge | medium | medium | Agent C owns both files and must synchronize them; orchestrator should diff them post-merge |
| Pre-Mortem section placement varies across scout prompt files | low | low | Interface contract specifies exact heading `## Pre-Mortem` and placement (before human review checkpoint) |
| wave-agent.md completion report typed-block format not aligned with message-formats.md schema | medium | medium | Agent F must read message-formats.md completion report schema before editing; contract below specifies the exact block annotation |

---

## Scaffolds

No scaffolds needed — agents have independent file ownership with no shared types. All coordination is through the interface contracts below (prose spec, not code types).

---

## Known Issues

None identified. This is a documentation-only project with no pre-existing build failures, test suite, or CI.

---

## Dependency Graph

```
Wave 1 (2 parallel agents — foundation spec):
    [A] protocol/message-formats.md
         Defines the canonical typed-block syntax, pre-mortem schema, and
         validation spec. All other agents depend on this definition.
         ✓ root (no dependencies on other agents)

    [B] protocol/execution-rules.md
         Adds E16: validation + correction loop rule. Standalone addition;
         does not depend on message-formats.md changes (E16 references the
         validator conceptually, not the typed-block format specifics).
         ✓ root (no dependencies on other agents)

Wave 2 (3 parallel agents — consumer files):
    [C] implementations/claude-code/prompts/agents/scout.md
        implementations/claude-code/prompts/scout.md
         Updates both Scout prompt files to use typed blocks in output format
         and add Pre-Mortem section template. Depends on [A] for typed-block
         syntax spec and [B] for E16 reference.
         depends on: [A] [B]

    [D] protocol/state-machine.md
         Adds SCOUT_VALIDATING state between SCOUT_COMPLETE and PENDING_REVIEW.
         Depends on [B] (E16 defines the trigger and transitions for this state).
         depends on: [B]

    [E] protocol/participants.md
        implementations/claude-code/prompts/saw-skill.md
         Updates Orchestrator responsibilities to include the E16 validation
         step; updates saw-skill.md to implement the E16 correction loop in
         the orchestrator skill. Depends on [B] for E16 definition.
         depends on: [B]

Wave 2 also (same wave, separate agent):
    [F] implementations/claude-code/prompts/agents/wave-agent.md
         Updates completion report format to use typed block annotation.
         Depends on [A] for the completion report typed-block spec.
         depends on: [A]
```

No files were split to resolve ownership conflicts. The two scout prompt files (`prompts/scout.md` and `prompts/agents/scout.md`) are assigned to the same agent (C) because they contain near-identical content and must stay synchronized — giving them to separate agents would create a coordination problem.

**Cascade candidates (files that reference changed interfaces but are not in scope):**
- `implementations/claude-code/prompts/saw-skill.md` — now in scope (Agent E). The E16 correction loop must be implemented in the orchestrator skill, not just described in participants.md.
- `implementations/claude-code/prompts/scaffold-agent.md` — does not parse IMPL docs but references the Scaffolds section. No change required unless typed blocks are added to the Scaffolds section (they are not, per this feature scope).
- `protocol/procedures.md` — describes orchestrator actions at each state. Adding SCOUT_VALIDATING may require a matching entry here. Check post-merge.

---

## Interface Contracts

### IC-1: Typed Metadata Block Syntax

This is the canonical syntax that all agents must use and reference. It is defined in `message-formats.md` (Agent A) and consumed by Agents C and F.

Machine-parsed sections of the IMPL doc must use fenced code blocks with a `type=impl-*` annotation on the opening fence. The annotation is whitespace-separated from the language tag.

**File ownership table block:**
```
```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| path/to/file.md | A | 1 | — |
```
```

**Dependency graph block:**
```
```yaml type=impl-dep-graph
Wave 1 (N parallel agents):
    [A] path/to/file
         (description)
         ✓ root

Wave 2 (M parallel agents):
    [B] path/to/file
         (description)
         depends on: [A]
```
```

**Wave structure block:**
```
```yaml type=impl-wave-structure
Wave 1: [A] [B]          <- 2 parallel agents
           | (A+B complete)
Wave 2: [C]              <- 1 agent
```
```

**Completion report block (used by Wave agents):**
```
```yaml type=impl-completion-report
status: complete | partial | blocked
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
```

**Prose sections remain free-form.** The following sections do NOT use typed blocks: Suitability Assessment, Scaffolds, Known Issues, Interface Contracts, Wave Execution Loop, Orchestrator Post-Merge Checklist, Pre-Mortem, Status table.

### IC-2: Pre-Mortem Section Schema

Added to IMPL docs by Scout before the human review checkpoint. The section uses a markdown table inside free-form prose (not a typed block — it is human-facing, not machine-parsed).

```markdown
## Pre-Mortem

**Overall risk:** low | medium | high

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| {description} | low | medium | {action} |
| {description} | medium | high | {action} |
```

Placement: immediately after the Scaffolds section (or after Suitability Assessment if Scaffolds is omitted), before Known Issues and agent prompts. It appears at the top of the human review screen.

### IC-3: E16 Rule Definition

The new execution rule added to `protocol/execution-rules.md` (Agent B). Downstream references in `state-machine.md` (Agent D) and `participants.md` (Agent E) must use the E16 label and reference it consistently.

**Rule heading and trigger:**
```
## E16: Scout Output Validation

**Trigger:** Scout writes IMPL doc to disk

**Required Action:** Orchestrator runs the IMPL doc validator before entering REVIEWED state.
If validation fails, the specific errors are fed back to Scout as a correction prompt.
Scout rewrites only the failing sections. This loops until the doc passes or a retry limit
(default: 3) is reached.

**Validator scope:** Only typed-block sections (IC-1: `type=impl-*` blocks). Prose sections
are excluded from validation.

**On retry limit exhausted:** Enter BLOCKED state. Orchestrator surfaces validation errors
to human. Do not enter REVIEWED.

**On validation pass:** Proceed to REVIEWED normally.
```

### IC-4: SCOUT_VALIDATING State Definition

New state added to `protocol/state-machine.md` (Agent D). Must be named exactly `SCOUT_VALIDATING`.

**State catalog entry:**

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **SCOUT_VALIDATING** | Orchestrator running validator on Scout output; feeding errors back to Scout if needed. | Scout writes IMPL doc | Validation passes OR retry limit exhausted |

**Transition: SCOUT_PENDING → SCOUT_VALIDATING**
Guard: Scout completion notification received AND IMPL doc written to disk.
(Previously this went directly to REVIEWED; now SCOUT_VALIDATING is interposed.)

**Transition: SCOUT_VALIDATING → REVIEWED**
Guard: Validator reports no errors on all typed-block sections.

**Transition: SCOUT_VALIDATING → SCOUT_VALIDATING** (self-loop)
Guard: Validator reports errors AND retry count < retry limit. Orchestrator issues correction prompt to Scout; Scout rewrites failing sections; validator re-runs.

**Transition: SCOUT_VALIDATING → BLOCKED**
Guard: Validator reports errors AND retry count >= retry limit. Orchestrator surfaces errors to human.

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/message-formats.md | A | 1 | — |
| protocol/execution-rules.md | B | 1 | — |
| implementations/claude-code/prompts/agents/scout.md | C | 2 | A, B |
| implementations/claude-code/prompts/scout.md | C | 2 | A, B |
| protocol/state-machine.md | D | 2 | B |
| protocol/participants.md | E | 2 | B |
| implementations/claude-code/prompts/saw-skill.md | E | 2 | B |
| implementations/claude-code/prompts/agents/wave-agent.md | F | 2 | A |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B]                          <- 2 parallel agents (spec foundation)
              | (A+B complete)
Wave 2: [C] [D] [E] [F]                 <- 4 parallel agents (consumer files)
```

---

## Wave 1

Wave 1 establishes the foundational spec that all Wave 2 agents depend on. Agent A defines the canonical typed-block syntax and the Pre-Mortem schema in `message-formats.md`. Agent B adds E16 (the validation + correction loop rule) to `execution-rules.md`. These two changes are independent of each other and can run in parallel.

### Agent A — Update message-formats.md: Typed Blocks + Pre-Mortem Schema

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-A"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly one file:
- `protocol/message-formats.md`

Do not modify any other file.

**2. Interfaces to Implement**

You are defining the canonical spec that all other agents will reference. Implement exactly as specified in Interface Contracts IC-1 and IC-2 above.

- **IC-1: Typed metadata block syntax** — Add a new section to `message-formats.md` defining the `type=impl-*` annotation syntax, listing all four block types: `impl-file-ownership`, `impl-dep-graph`, `impl-wave-structure`, and `impl-completion-report`. For each, provide the exact format (as shown in IC-1 above). State clearly that prose sections remain free-form.
- **IC-2: Pre-Mortem section schema** — Add a new section to `message-formats.md` defining the Pre-Mortem section format: heading `## Pre-Mortem`, `**Overall risk:**` field, and the failure modes table with columns Scenario / Likelihood / Impact / Mitigation. Specify placement (after Scaffolds, before Known Issues).

**3. Interfaces to Call**

None. This is a root agent with no dependencies on other agents' new work.

**4. What to Implement**

Make the following changes to `protocol/message-formats.md`:

(a) **Update the IMPL Doc Structure section.** The existing structure shows a code block with the markdown skeleton. Update this skeleton to show typed-block annotations on the File Ownership table, Dependency Graph, and Wave Structure sections. Keep all prose sections unchanged (free-form).

(b) **Add a new "Typed Metadata Blocks" section** after the IMPL Doc Structure overview. This section is the canonical spec for IC-1. Include:
- Why typed blocks exist (parser anchors, precise validation errors)
- The four block types and their exact fence annotations
- Example of each block type with realistic sample content (use the format from IC-1 exactly)
- Statement that prose sections remain free-form and are excluded from validation

(c) **Update the Completion Report Format section.** The existing section shows a YAML code block without a typed-block annotation. Update it to use `` ```yaml type=impl-completion-report `` as the opening fence. Update the "Format assumption" note at the bottom of the section to reference typed blocks.

(d) **Update the Orchestrator Parsing Requirements section** to note that the orchestrator locates completion reports by finding `` ```yaml type=impl-completion-report `` blocks, not by free-form YAML parsing.

(e) **Add a new "Pre-Mortem Section Format" section** after the Scaffolds Section Format section. Define the schema exactly per IC-2. Include a complete example using realistic SAW failure modes as sample content.

(f) **Update the Message Flow Sequence section** to add: "1a. Scout phase (post-write): Orchestrator runs validator on typed-block sections; if errors, feeds correction prompt to Scout (E16)." This documents where E16 fits in the message flow.

**5. Tests to Write**

This is a documentation file; there are no automated tests. Instead, perform a self-consistency check before committing:
- Read your completed `message-formats.md` and verify every typed-block example uses the exact annotation syntax you defined in the Typed Metadata Blocks section
- Verify the Pre-Mortem section format matches IC-2 exactly
- Verify the Completion Report Format section uses `type=impl-completion-report` on its fenced block

**6. Verification Gate**

This is a documentation-only project with no build system.

```bash
# Verify file exists and is non-empty
wc -l /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A/protocol/message-formats.md

# Verify the typed-block annotation appears in the file
grep -n "type=impl-" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A/protocol/message-formats.md

# Verify Pre-Mortem section was added
grep -n "Pre-Mortem" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A/protocol/message-formats.md

# Verify completion report block was updated
grep -n "impl-completion-report" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A/protocol/message-formats.md
```

All four grep commands must return matches. If any returns empty, fix before committing.

**7. Constraints**

- Do not remove or rewrite existing content unless necessary to integrate the new sections. Extend the existing document; do not replace it.
- Do not use `type=impl-*` annotations on any prose sections. Only the four specific machine-parsed sections (file-ownership, dep-graph, wave-structure, completion-report) use typed blocks.
- The Pre-Mortem section uses a prose table (no typed-block annotation) because it is human-facing, not machine-parsed.
- Keep the version number at the top of the file unchanged (it is updated by the orchestrator, not by wave agents).
- Do not modify the IMPL Doc Size section, Message Flow Sequence section title, or existing section headings unless adding new ones.

**8. Report**

After committing, append your completion report to the IMPL doc at `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under the heading `### Agent A - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

### Agent B — Update execution-rules.md: Add E16

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-B"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly one file:
- `protocol/execution-rules.md`

Do not modify any other file.

**2. Interfaces to Implement**

Implement E16 exactly as defined in Interface Contract IC-3 above. The rule heading, trigger, required action, validator scope, retry limit behavior, and on-pass behavior must match IC-3 verbatim or with only minor prose improvements. The E-number label `E16` is binding.

**3. Interfaces to Call**

None. This is a root agent with no dependencies on other agents' new work. E16 references the concept of typed-block sections (from message-formats.md) but does not depend on Agent A's edits to compile; it references them by name only.

**4. What to Implement**

Make the following changes to `protocol/execution-rules.md`:

(a) **Update the Overview section.** The first paragraph says "Rules are numbered E1–E15". Update to "E1–E16".

(b) **Add E16 section** at the end of the file, before the Cross-References section. Use the rule format established by E1–E15: heading `## E16: Scout Output Validation`, then the four standard fields (Trigger, Required Action, Validator scope, failure handling). Use the exact text from IC-3, expanding it with the following additional detail:

- **Correction prompt format:** The orchestrator's correction prompt to Scout must list each error with the section name, the specific failure (e.g., "impl-dep-graph block: Wave 2 missing `depends on:` line for agent [C]"), and the line number or block identifier where the error occurred. This gives Scout precise targets for correction without requiring it to re-read the whole doc.
- **Retry limit:** Default 3 attempts. After the 3rd failed validation, enter BLOCKED.
- **Relationship to structured outputs:** For API-backend runs using structured output enforcement, the validator always passes on first attempt (the output was already schema-validated). E16's correction loop is effectively a no-op in that path but must still be present in the protocol for CLI-backend and hand-edited docs.

(c) **Update the Cross-References section** at the end of the file to include: "See `state-machine.md` for the SCOUT_VALIDATING state triggered by E16."

**5. Tests to Write**

Documentation file; no automated tests. Self-consistency checks:
- Verify E16 appears in the Cross-References section reference
- Verify the Overview section says E1–E16 (not E1–E15)
- Verify the E16 heading format matches the pattern of E1–E15

**6. Verification Gate**

```bash
# Verify E16 section was added
grep -n "## E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B/protocol/execution-rules.md

# Verify overview was updated
grep -n "E1–E16\|E1-E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B/protocol/execution-rules.md

# Verify cross-reference was added
grep -n "SCOUT_VALIDATING" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B/protocol/execution-rules.md
```

All three grep commands must return matches.

**7. Constraints**

- Use the same heading level and field format as all existing E-rules (E1–E15). Deviation in format will fail validation.
- Do not modify any existing E-rule text. Append only.
- Keep the version number at the top unchanged.
- The retry limit is 3 (not configurable in this version; mention it as the default with a note that implementations may override).

**8. Report**

After committing, append your completion report to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under `### Agent B - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

## Wave 2

Wave 2 launches after both Wave 1 agents (A and B) complete and are merged. Agents C, D, E, and F run in parallel. Each depends on the specs established in Wave 1. Before launching Wave 2, the orchestrator must verify:
- Agent A's `message-formats.md` changes are merged and contain the IC-1 typed-block definitions
- Agent B's `execution-rules.md` changes are merged and contain E16

Wave 2 agents should read `protocol/message-formats.md` and `protocol/execution-rules.md` from the merged main branch before beginning work.

### Agent C — Update Scout Prompt Files: Typed Blocks + Pre-Mortem + E16 Reference

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-C"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly two files:
- `implementations/claude-code/prompts/agents/scout.md`
- `implementations/claude-code/prompts/scout.md`

These files contain near-identical content. You must update both and keep them synchronized. Do not modify any other file.

**2. Interfaces to Implement**

- **IC-1 (typed blocks):** Update the Output Format section in both scout prompt files to use typed-block annotations (`type=impl-file-ownership`, `type=impl-dep-graph`, `type=impl-wave-structure`) on the corresponding fenced code blocks in the IMPL doc output format template.
- **IC-2 (Pre-Mortem):** Add the Pre-Mortem section to the IMPL doc output format template in both scout prompt files. Placement: after the Scaffolds section template, before the Known Issues section template.
- **E16 (validation loop):** Add a note in the Process section and/or the Rules section of both scout prompt files informing the Scout that after writing the IMPL doc, the orchestrator will run a validator (E16) and may re-engage Scout with a correction prompt listing specific errors. Scout should respond by rewriting only the failing sections, not the entire document.

**3. Interfaces to Call**

- Read `protocol/message-formats.md` (merged from Wave 1, Agent A) to get the authoritative typed-block syntax before updating the output format templates.
- Read `protocol/execution-rules.md` (merged from Wave 1, Agent B) to get the authoritative E16 text before writing the correction-loop note.

**4. What to Implement**

Both `implementations/claude-code/prompts/agents/scout.md` and `implementations/claude-code/prompts/scout.md` need the same changes (apply to both files):

(a) **Update the Output Format section — Dependency Graph block.** The current template shows a bare fenced block for the dep graph. Update it to use `` ```yaml type=impl-dep-graph `` as the opening fence.

(b) **Update the Output Format section — File Ownership block.** The current template shows a markdown table for file ownership without a typed-block wrapper. Wrap the file ownership table in a `` ```yaml type=impl-file-ownership `` fenced block.

(c) **Update the Output Format section — Wave Structure block.** The current template shows the wave structure as a bare fenced block or plain text. Update it to use `` ```yaml type=impl-wave-structure `` as the opening fence.

(d) **Add Pre-Mortem section template** to the Output Format section. Insert it after the Scaffolds section template and before the Known Issues section template. Use the format from IC-2: heading `## Pre-Mortem`, `**Overall risk:**` field, and the failure modes table. Include a brief instruction to the Scout: "Write the Pre-Mortem before the human review checkpoint. Think adversarially about what could go wrong with your plan."

(e) **Add correction-loop awareness note** to the Process section (as a new final step or addendum to step 9) or the Rules section: "After you write the IMPL doc, the orchestrator runs a validator on all `type=impl-*` blocks (E16). If the validator reports errors, you will receive a correction prompt listing specific failures by section and line. Rewrite only the failing sections — do not regenerate the entire document."

(f) **Synchronization check:** After editing both files, diff them mentally to confirm the Output Format section and Process section are identical between the two files. If they diverge, correct until they match.

**5. Tests to Write**

Documentation file; no automated tests. Self-consistency checks:
- After editing both files, verify the Output Format sections are identical between `prompts/scout.md` and `prompts/agents/scout.md`
- Verify all three typed-block annotations appear in the output format template of each file
- Verify the Pre-Mortem section appears between Scaffolds and Known Issues in the template

**6. Verification Gate**

```bash
# Verify typed-block annotations in agents/scout.md
grep -n "type=impl-" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/agents/scout.md

# Verify Pre-Mortem in agents/scout.md
grep -n "Pre-Mortem" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/agents/scout.md

# Verify E16 reference in agents/scout.md
grep -n "E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/agents/scout.md

# Verify same in prompts/scout.md
grep -n "type=impl-" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/scout.md
grep -n "Pre-Mortem" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/scout.md
grep -n "E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-C/implementations/claude-code/prompts/scout.md
```

All six grep commands must return matches.

**7. Constraints**

- Do not change the overall structure of the scout prompt (sections, 9-field format reference, rules). Add and update only what is specified.
- Keep the version tag at the top of each file (`<!-- scout v0.4.0 -->`) unchanged.
- The two files must remain synchronized. Do not introduce content in one that is absent from the other.
- Do not update the IMPL Doc Size section in the scout prompts (it does not need typed-block changes).

**8. Report**

After committing, append your completion report to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under `### Agent C - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

### Agent D — Update state-machine.md: SCOUT_VALIDATING State

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-D
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-D"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-D"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly one file:
- `protocol/state-machine.md`

Do not modify any other file.

**2. Interfaces to Implement**

Implement IC-4 (SCOUT_VALIDATING state) exactly as defined above. The state name `SCOUT_VALIDATING`, all four transition definitions, and the entry action must match IC-4 verbatim or with only minor prose improvements.

**3. Interfaces to Call**

- Read `protocol/execution-rules.md` (merged from Wave 1, Agent B) to get the authoritative E16 text and ensure the state machine transitions are consistent with E16's retry limit and BLOCKED escalation behavior.

**4. What to Implement**

Make the following changes to `protocol/state-machine.md`:

(a) **Update the State Catalog table.** Add a new row for `SCOUT_VALIDATING` between `SCOUT_PENDING` and `REVIEWED`. Use the exact row from IC-4.

(b) **Update the Primary Flow (Success Path) diagram.** The current flow shows `SCOUT_PENDING → REVIEWED`. Insert `SCOUT_VALIDATING` between them:
```
SCOUT_PENDING
    ↓ (Scout completes, IMPL doc written)
SCOUT_VALIDATING
    ↓ (Validation passes)
REVIEWED
```

(c) **Add a "Validation Failure Path" diagram** to the Failure Paths section:
```
SCOUT_VALIDATING
    ↓ (Validation fails, retries remain)
SCOUT_VALIDATING (self-loop: correction prompt → Scout rewrites → revalidate)
    ↓ (Retry limit exhausted)
BLOCKED
```

(d) **Add transition guards** for the three new transitions (SCOUT_PENDING → SCOUT_VALIDATING, SCOUT_VALIDATING → REVIEWED, SCOUT_VALIDATING → BLOCKED) to the State Transition Guards section. Use the guard format established by existing transitions. Reference E16 for the retry limit.

(e) **Update the SCOUT_PENDING → REVIEWED guard.** This guard previously fired on Scout completion. Now it must be replaced: SCOUT_PENDING transitions to SCOUT_VALIDATING on Scout completion; SCOUT_VALIDATING transitions to REVIEWED on validation pass. Update the existing guard text to reflect this two-step sequence.

(f) **Update the State Entry Actions table.** Add an entry for SCOUT_VALIDATING:

| State | Entry Actions |
|-------|---------------|
| **SCOUT_VALIDATING** | Orchestrator runs validator on all `type=impl-*` blocks in IMPL doc; on failure, issues correction prompt to Scout (E16); on pass, advances to REVIEWED |

(g) **Update the State Machine Correctness Properties section.** The final sentence says "When all invariants (I1–I6) and execution rules (E1–E15) are maintained". Update to `E1–E16`.

**5. Tests to Write**

Documentation file; no automated tests. Self-consistency checks:
- Verify `SCOUT_VALIDATING` appears in the State Catalog, Primary Flow diagram, Failure Paths, Transition Guards, and Entry Actions table
- Verify E16 is referenced in at least one transition guard
- Verify the correctness properties section says E1–E16

**6. Verification Gate**

```bash
# Verify SCOUT_VALIDATING state appears throughout
grep -n "SCOUT_VALIDATING" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-D/protocol/state-machine.md

# Verify E16 reference
grep -n "E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-D/protocol/state-machine.md

# Verify E1-E16 in correctness properties
grep -n "E1–E16\|E1-E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-D/protocol/state-machine.md
```

All three grep commands must return matches. `SCOUT_VALIDATING` must appear at least 5 times (catalog, flow diagram, failure paths, transition guards, entry actions).

**7. Constraints**

- Do not change the state names of any existing states.
- Do not remove or rewrite existing transition guards; only add new ones and update the `SCOUT_PENDING → REVIEWED` guard as described.
- Keep the version number at the top unchanged.
- The self-loop on SCOUT_VALIDATING (correction prompt → Scout rewrites → revalidate) must be clearly shown in the diagram. Use the same diagram notation as existing failure paths.

**8. Report**

After committing, append your completion report to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under `### Agent D - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

### Agent E — Update participants.md: Orchestrator Validation Responsibility

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-E"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly two files:
- `protocol/participants.md`
- `implementations/claude-code/prompts/saw-skill.md`

Do not modify any other file.

**2. Interfaces to Implement**

Add the orchestrator's E16 validation responsibility to the Orchestrator section. Reference E16 by name. The description must be consistent with IC-3 (the E16 rule text) and IC-4 (the SCOUT_VALIDATING state).

**3. Interfaces to Call**

- Read `protocol/execution-rules.md` (merged from Wave 1, Agent B) to get the authoritative E16 text before writing the responsibilities update.

**4. What to Implement**

Make the following targeted change to `protocol/participants.md`:

(a) **Update the Orchestrator Responsibilities section.** The current text lists orchestrator responsibilities as a prose paragraph. After the sentence describing state transitions, add or integrate the following responsibility:

> **IMPL doc validation (E16):** After the Scout writes the IMPL doc, the Orchestrator runs a deterministic validator on all `type=impl-*` typed-block sections before entering REVIEWED state. If validation fails, the Orchestrator issues a correction prompt to the Scout listing specific errors by section and block. The Orchestrator loops (up to the E16 retry limit) until the doc passes or retry limit is exhausted. On exhaustion, the Orchestrator enters BLOCKED and surfaces the errors to the human. The validator is a protocol-level tool, not an implementation detail — it is part of the Orchestrator's required capabilities.

(b) **Update the Required Capabilities list** for the Orchestrator. Add: "Run IMPL doc validator on typed-block sections and issue correction prompts to Scout (E16)."

(c) **No changes needed** to the Scout, Scaffold Agent, or Wave Agent sections of `participants.md`. This feature adds orchestrator responsibility only.

(d) **Update `implementations/claude-code/prompts/saw-skill.md`** to implement the E16 correction loop. Find the scout flow section (after Scout completes and the IMPL doc is written, before "Report the suitability verdict to the user") and add a new step:

> **E16: Validate IMPL doc before review.** After Scout writes the IMPL doc, parse all `` ```yaml type=impl-* `` typed blocks and validate each against the schema in `protocol/message-formats.md`. If all pass, proceed to human review. If any fail, issue a correction prompt to Scout listing each error (block type, failure description, line/block location) and retry (up to 3 attempts). On retry limit exhaustion, enter BLOCKED and surface the validation errors to the human. Do not present the doc for human review until validation passes.

Read the existing `saw-skill.md` carefully to find the exact insertion point and preserve the surrounding step numbering and formatting.

**5. Tests to Write**

Documentation file; no automated tests. Self-consistency checks:
- Verify E16 appears in the Orchestrator section
- Verify the validator is described as a required capability, not an optional one
- Verify no other participant section was modified

**6. Verification Gate**

```bash
# Verify E16 reference in orchestrator section
grep -n "E16" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E/protocol/participants.md

# Verify validator/validation mention
grep -n "validator\|validation\|typed-block" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E/protocol/participants.md

# Verify E16 step added to saw-skill.md
grep -n "E16\|typed-block\|correction prompt" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E/implementations/claude-code/prompts/saw-skill.md
```

All three grep commands must return matches.

**7. Constraints**

- Make minimal targeted changes. The Orchestrator section is dense with cross-references to invariants (I1–I6) and E-rules. Do not rewrite or reorganize existing content.
- Keep the Correctness Rationale section unchanged.
- Do not add any content to the Scout, Scaffold Agent, or Wave Agent sections.

**8. Report**

After committing, append your completion report to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under `### Agent E - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

### Agent F — Update wave-agent.md: Typed Completion Report Format

**0. Isolation Verification**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F"
if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory. Expected: $EXPECTED_DIR, Actual: $ACTUAL_DIR"
  exit 1
fi
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-F"
if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch. Expected: $EXPECTED_BRANCH, Actual: $ACTUAL_BRANCH"
  exit 1
fi
echo "Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately without modifying files.

**1. File Ownership**

You own exactly one file:
- `implementations/claude-code/prompts/agents/wave-agent.md`

Do not modify any other file.

**2. Interfaces to Implement**

Update the completion report format in `wave-agent.md` to use the `type=impl-completion-report` typed-block annotation from IC-1. The completion report block opening fence must change from ` ``` ` (bare) to `` ```yaml type=impl-completion-report ``.

**3. Interfaces to Call**

- Read `protocol/message-formats.md` (merged from Wave 1, Agent A) to get the authoritative `impl-completion-report` block format and field definitions before updating the wave-agent completion report template.

**4. What to Implement**

Make the following changes to `implementations/claude-code/prompts/agents/wave-agent.md`:

(a) **Update the Completion Report template.** The current template in the "Completion Report" section uses a bare fenced code block. Change the opening fence to `` ```yaml type=impl-completion-report ``. The content of the block should be updated to match the structured YAML format defined in `protocol/message-formats.md` (IC-1: completion report block). Specifically, the block should contain the fields: `status`, `worktree`, `branch`, `commit`, `files_changed`, `files_created`, `interface_deviations`, `out_of_scope_deps`, `tests_added`, `verification`.

(b) **Update the Field 8 / Report instruction pattern.** The wave-agent.md provides instructions to agents about how to write their completion report. Add a note that the YAML block must use `` ```yaml type=impl-completion-report `` as the opening fence, consistent with IC-1.

(c) **No other changes.** Do not modify the Worktree Isolation Protocol, Critical Rules, If You Get Stuck, or Verification Gates sections.

**5. Tests to Write**

Documentation file; no automated tests. Self-consistency checks:
- Verify the completion report template uses `type=impl-completion-report`
- Verify the field list in the template matches the fields in `message-formats.md`

**6. Verification Gate**

```bash
# Verify typed-block annotation appears in wave-agent.md
grep -n "impl-completion-report" /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F/implementations/claude-code/prompts/agents/wave-agent.md
```

This grep must return at least one match.

**7. Constraints**

- The completion report block content must match the field names in `message-formats.md` exactly. If Agent A changed any field names, use Agent A's final field names.
- Do not change the "If You Get Stuck" guidance or the overall structure of the wave-agent prompt.
- Keep the version tag (`<!-- wave-agent v0.2.0 -->`) unchanged.

**8. Report**

After committing, append your completion report to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-protocol-robustness.md` under `### Agent F - Completion Report` using a `` ```yaml type=impl-completion-report `` block.

---

## Wave Execution Loop

After each wave completes, work through the Orchestrator Post-Merge Checklist below in order. The merge procedure detail is in `saw-merge.md`. Key principles:
- Read completion reports first — a `status: partial` or `status: blocked` blocks the merge entirely. No partial merges.
- Interface deviations with `downstream_action_required: true` must be propagated to downstream agent prompts before that wave launches.
- Post-merge verification is the real gate. Agents pass in isolation; merged state surfaces cross-file inconsistencies.
- Fix before proceeding. Do not launch Wave 2 with inconsistent typed-block definitions.

## Orchestrator Post-Merge Checklist

After Wave 1 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — update Wave 2 agent prompts (C, D, E, F) for any item with `downstream_action_required: true`
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave1-agent-{X}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (no linter configured)
      - [ ] Consistency check: `grep -n "type=impl-" protocol/message-formats.md` — verify typed-block annotations appear
      - [ ] Consistency check: `grep -n "## E16" protocol/execution-rules.md` — verify E16 was added
- [ ] Cross-check: verify typed-block syntax in `message-formats.md` (Agent A) is consistent with E16 retry description in `execution-rules.md` (Agent B) — they reference the same concept independently; confirm no contradiction
- [ ] Fix any cascade failures — check `protocol/procedures.md` for SCOUT_VALIDATING state entry (cascade candidate)
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Update interface contracts for any deviations logged by agents
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
      - [ ] None beyond the cross-check above
- [ ] Commit: `git commit -m "feat: wave1 — typed metadata block spec (message-formats) and E16 validation rule (execution-rules)"`
- [ ] Launch Wave 2

After Wave 2 completes:

- [ ] Read all agent completion reports (C, D, E, F) — confirm all `status: complete`
- [ ] Conflict prediction — confirm no file appears in >1 agent's `files_changed` list
- [ ] Review `interface_deviations` — no Wave 3 exists, but note any deviations for manual follow-up
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave2-agent-{X}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a
      - [ ] Cross-consistency check: `grep -n "type=impl-" implementations/claude-code/prompts/agents/scout.md` — verify typed blocks appear in scout prompt
      - [ ] Cross-consistency check: `grep -n "SCOUT_VALIDATING" protocol/state-machine.md` — verify state was added
      - [ ] Cross-consistency check: `grep -n "E16" protocol/participants.md` — verify orchestrator responsibility added
      - [ ] Cross-consistency check: `grep -n "impl-completion-report" implementations/claude-code/prompts/agents/wave-agent.md` — verify completion report format updated
      - [ ] Diff check: confirm `prompts/scout.md` and `prompts/agents/scout.md` Output Format sections are identical (Agent C's sync responsibility)
- [ ] Check cascade candidate: `protocol/procedures.md` — add SCOUT_VALIDATING entry if missing
- [ ] Verify `implementations/claude-code/prompts/saw-skill.md` (Agent E) contains E16 correction loop step
- [ ] Tick status checkboxes in this IMPL doc
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
      - [ ] None
- [ ] Commit: `git commit -m "feat: wave2 — typed blocks in scout prompts, SCOUT_VALIDATING state, orchestrator validation responsibility, wave-agent completion report format"`
- [ ] Write SAW:COMPLETE marker: `<!-- SAW:COMPLETE 2026-03-07 -->` on line 2 of this IMPL doc, then commit

---

## Status

```yaml type=impl-wave-structure
Wave 1: [A] [B]             <- 2 parallel agents (spec foundation)
              | (A+B complete)
Wave 2: [C] [D] [E] [F]    <- 4 parallel agents (consumer files)
```

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | message-formats.md — typed block syntax + pre-mortem schema | TO-DO |
| 1 | B | execution-rules.md — add E16 validation loop rule | TO-DO |
| 2 | C | scout.md + agents/scout.md — typed blocks + pre-mortem template + E16 note | TO-DO |
| 2 | D | state-machine.md — SCOUT_VALIDATING state | TO-DO |
| 2 | E | participants.md — orchestrator validation responsibility | TO-DO |
| 2 | F | agents/wave-agent.md — typed completion report format | TO-DO |
| — | Orch | Post-merge integration, cascade candidate checks, SAW:COMPLETE marker | TO-DO |

---

### Agent B - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-B
branch: wave1-agent-B
commit: aa5ec92
files_changed:
  - protocol/execution-rules.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (grep -n "## E16" | grep -n "E1–E16" | grep -n "SCOUT_VALIDATING" — all three returned matches)
```

---

### Agent A - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-A
branch: wave1-agent-A
commit: 7c9397a
files_changed:
  - protocol/message-formats.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (wc -l returned 545 lines; grep type=impl- returned 12 matches; grep Pre-Mortem returned 8 matches; grep impl-completion-report returned 10 matches)
```

All six changes implemented per the agent prompt:
- (a) IMPL Doc Structure skeleton updated to use indented-block format with typed-block annotations shown on File Ownership, Dependency Graph, Wave Structure, and Completion Reports sections
- (b) New "Typed Metadata Blocks" section added after IMPL Doc Structure, defining all four block types (impl-file-ownership, impl-dep-graph, impl-wave-structure, impl-completion-report) with exact fence annotations and realistic examples per IC-1
- (c) Completion Report Format section updated: opening fence changed from plain ```yaml to ```yaml type=impl-completion-report; typed-block annotation note added at end of section
- (d) Orchestrator Parsing Requirements updated with Location paragraph explaining typed-block lookup method
- (e) New "Pre-Mortem Section Format" section added after Scaffolds Section Format, with full schema, placement rule, realistic example, and field definitions per IC-2
- (f) Message Flow Sequence updated with step 1a documenting E16 validation loop between Scout write and human review

Downstream agents (C and F) must read the Typed Metadata Blocks section in full before editing their files — the exact fence annotations are defined there.

---

### Agent C - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-C
branch: wave2-agent-C
commit: 7632ffa
files_changed:
  - implementations/claude-code/prompts/agents/scout.md
  - implementations/claude-code/prompts/scout.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (grep type=impl- returned 3 matches per file; grep Pre-Mortem returned 2 matches per file; grep E16 returned 2 matches per file — all 6 verification gate greps returned matches)
```

All changes applied identically to both owned files and kept in sync:
- (a) Dependency Graph block: bare fence replaced with `` ```yaml type=impl-dep-graph ``
- (b) File Ownership table: wrapped in `` ```yaml type=impl-file-ownership `` fenced block
- (c) Wave Structure: replaced with `` ```yaml type=impl-wave-structure `` fenced block; `scout.md` required adding a new `## Wave Structure` section before `## Wave 1` since that file had no prior Wave Structure block in its output template
- (d) Pre-Mortem section template added after Scaffolds, before Known Issues, with overall risk field and failure modes table; includes Scout instruction to think adversarially before human review checkpoint
- (e) Step 10 added to Process section of both files: E16 correction loop note directing Scout to rewrite only failing sections on correction prompt
- (f) Both files verified synchronized on all changed sections

---

### Agent D - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-D
branch: wave2-agent-D
commit: 8be4487
files_changed:
  - protocol/state-machine.md (modified, +31/-4 lines)
files_created: []
interface_deviations: []
out_of_scope_deps:
  - protocol/procedures.md may need a SCOUT_VALIDATING entry added to match the new state.
    Suggested owner: Orchestrator post-merge (cascade candidate flagged in IMPL doc checklist).
tests_added: []
verification:
  - "grep -n SCOUT_VALIDATING protocol/state-machine.md: PASS (9 matches — catalog, primary flow diagram x2, failure path x3, transition guards x3, entry actions)"
  - "grep -n E16 protocol/state-machine.md: PASS (3 matches in transition guards and entry actions)"
  - "grep -n E1-E16 protocol/state-machine.md: PASS (1 match in correctness properties)"
```

---

### Agent F - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-F
branch: wave2-agent-F
commit: 26122a6
files_changed:
  - implementations/claude-code/prompts/agents/wave-agent.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (grep -n "impl-completion-report" wave-agent.md returned 3 matches)
```

All three changes implemented per agent prompt:
- (a) Completion Report template updated from bare fenced block to structured YAML using `yaml type=impl-completion-report` opening fence, with fields matching message-formats.md exactly: status, worktree, branch, commit, files_changed, files_created, interface_deviations, out_of_scope_deps, tests_added, verification
- (b) Introductory note added to the Completion Report section explicitly stating the YAML block must use `yaml type=impl-completion-report` as the opening fence, with rationale (orchestrator parses by type annotation, not heading text)
- (c) Rules section updated to reference the typed-block annotation requirement inline with the "Update IMPL doc with completion report" bullet

---

### Agent E - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave2-agent-E
branch: wave2-agent-E
commit: 3205480
files_changed:
  - protocol/participants.md (modified, +7/-0 lines)
  - implementations/claude-code/prompts/saw-skill.md (modified, +5/-4 lines)
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification:
  - "grep -n E16 protocol/participants.md: PASS (2 matches)"
  - "grep -n 'validator|validation|typed-block' protocol/participants.md: PASS (2 matches)"
  - "grep -n 'E16|typed-block|correction prompt' implementations/claude-code/prompts/saw-skill.md: PASS (3 matches)"
```
