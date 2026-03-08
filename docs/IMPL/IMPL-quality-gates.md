# IMPL: Quality Gate Enhancements (Stub Detection, Post-Wave Verification, Scaffold Build Check)
<!-- SAW:COMPLETE 2026-03-08 -->

**Feature:** Three protocol quality gate enhancements: E20 stub-detection rule, E21 post-wave verification rule, E22 scaffold build verification rule; corresponding schema additions to `message-formats.md`; orchestrator wiring in `saw-skill.md`; and scaffold agent hardening in `scaffold-agent.md`.
**Repository:** /Users/dayna.blackwell/code/scout-and-wave
**Plan Reference:** ROADMAP.md — "Quality Gates" and "Protocol Hardening" sections

---

## Suitability Assessment

**Verdict:** SUITABLE WITH CAVEATS

test_command: none (markdown-only repo — no build toolchain)
lint_command: none

This work touches 5 markdown files across two coherent groups: protocol spec files (`execution-rules.md`, `message-formats.md`) and agent prompt files (`scaffold-agent.md`, `saw-skill.md`, `scout.md`). These groups have no shared sections requiring simultaneous edits, enabling clean two-agent parallel decomposition. No compiled code changes; verification is correctness checking against spec by a human reviewer.

**Caveats:**
- A concurrent scout is simultaneously scouting "failure taxonomy and CONTEXT.md" and will also touch `execution-rules.md` and `saw-skill.md`. Section-level ownership is sufficient to avoid conflicts: this IMPL adds only *new* E-rule sections (E20, E21, E22) and *new* schema sections to `message-formats.md`. The failure taxonomy scout adds different sections. Agents must read the current file state and append/insert only in their designated areas.
- Parallelization saves minimal wall-clock time (markdown edits have no build cycle). The value here is the coordination artifact — section-level ownership contracts prevent the two concurrent scouts from producing conflicting IMPL docs that both claim `execution-rules.md`.

**Estimated times:**
- Scout phase: ~10 min
- Agent execution: ~8 min (2 agents × ~4 min avg, in parallel)
- Merge & verify: ~5 min
- Total SAW time: ~23 min
- Sequential baseline: ~20 min (2 agents × 10 min sequential)
- Time savings: ~-3 min (marginal overhead)

**Recommendation:** Proceed. Coordination value (section-level ownership with concurrent scout) exceeds the marginal overhead.

**Pre-implementation scan results:**
- Total items: 3 features (stub detection, post-wave verification, scaffold build check)
- Already implemented: 1 partial item — `scan-stubs.sh` script exists; E20 rule, `## Stub Report` schema, and orchestrator wiring do NOT exist
- To-do: 3 sub-items across the two files per feature (all spec/prompt additions are unimplemented)

Agent adjustments:
- Agent A proceeds as planned (protocol spec additions — all TO-DO)
- Agent B proceeds as planned (prompt file additions — all TO-DO)
- Estimated time saved: ~0 min (no duplicate work avoided; script already existed before this IMPL)

---

## Scaffolds

No scaffolds needed — agents have independent type ownership. This is a markdown-only repo with no shared type definitions.

---

## Pre-Mortem

**Overall risk:** low

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Agent B references E20/E21/E22 rule numbers that Agent A defined differently (e.g., numbering gap) | medium | medium | Interface contract below locks the E-rule numbers and section titles verbatim; Agent B must use exactly those strings |
| Concurrent failure-taxonomy scout inserts new E-rules that collide with E20/E21/E22 numbering | low | high | E-rule numbers E20/E21/E22 are claimed in this IMPL; orchestrator should inform both scouts of their claimed number ranges before launch |
| Agent B edits `saw-skill.md` in the same location where failure-taxonomy scout edits it | low | medium | Agent B inserts stub-scan step in the specific post-wave checklist location; failure taxonomy scout adds `failure_type` logic elsewhere. Review `saw-skill.md` section ownership carefully |
| `scan-stubs.sh` path assumption in saw-skill.md is wrong for the installed skill directory | low | medium | Agent B uses `${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh` — verify actual script path relative to skill dir during implementation |
| Agent A introduces `## Stub Report` schema with typed block annotation, but the parser does not handle new block types gracefully | low | low | `## Stub Report` is human-facing prose only (not a typed block) — no parser change needed |

---

## Known Issues

None identified. No pre-existing test failures (markdown-only repo has no test suite).

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — spec foundation and prompt wiring):
    [A] protocol/execution-rules.md
         Adds E20 (stub detection), E21 (post-wave verification), E22 (scaffold build verification) rule sections.
         Also adds `## Stub Report` section and `quality_gates` schema to protocol/message-formats.md.
         ✓ root (no dependencies on other agents)

    [B] implementations/claude-code/prompts/agents/scaffold-agent.md
         Adds build verification step (go get, go mod tidy, go build) to Scaffold Agent procedure.
         Also wires stub scan and quality gates into saw-skill.md orchestrator flow.
         Also updates scout.md to emit quality_gates config in IMPL doc.
         ✓ root (no dependencies on other agents — but must use E-rule numbers from interface contracts below)
```

No files were split or extracted to resolve ownership conflicts. Agent A owns all protocol spec files; Agent B owns all agent prompt files. The only coordination boundary is the E-rule numbers and section titles defined in the interface contracts.

---

## Interface Contracts

These are the binding contracts that both agents must implement against. Agent A writes the definitions; Agent B references them by exact name.

### E-Rule Numbers (reserved by this IMPL)

The following E-rule numbers are reserved. The concurrent failure-taxonomy scout must use different numbers.

- **E20** — Stub Detection Post-Wave
- **E21** — Automated Post-Wave Verification
- **E22** — Scaffold Build Verification

### E20: Stub Detection Post-Wave (in `execution-rules.md`)

Section title: `## E20: Stub Detection Post-Wave`

Trigger: After all wave agents in a wave write `[COMPLETE]` and before the review checkpoint.

Required Action: Orchestrator collects the union of all `files_changed` and `files_created` from wave agent completion reports. Runs `scan-stubs.sh` with those files as arguments. Writes the output to the IMPL doc under `## Stub Report` (appended after the wave's completion reports, before the next wave section). If stubs are found, they are surfaced at the review checkpoint — they do not block merge automatically but are visible to the reviewer.

Reference: Script at `scripts/scan-stubs.sh` (relative to skill dir). Exit code is always 0 (informational).

### E21: Automated Post-Wave Verification (in `execution-rules.md`)

Section title: `## E21: Automated Post-Wave Verification`

Trigger: After all wave agents in a wave report complete, before merge.

Required Action: Orchestrator runs configured quality gates from the IMPL doc `quality_gates` section. Gate types: `typecheck`, `test`, `lint`, `custom`. Each gate has a `required` boolean. Required gate failure blocks merge; optional gate failure is a warning only. AI Verification Gate is out of scope for this rule — subprocess-based gates only.

Flow levels: `quick` (no gates), `standard` (all gates, failure warns), `full` (all gates, required failure blocks).

### E22: Scaffold Build Verification (in `execution-rules.md`)

Section title: `## E22: Scaffold Build Verification`

Trigger: Scaffold Agent completes file creation, before committing.

Required Action: Scaffold Agent must run (in order): dependency resolution (`go get ./...` or language equivalent), dependency cleanup (`go mod tidy` or language equivalent), build verification (`go build ./...` or language equivalent). If any step fails, Scaffold Agent reports `status: FAILED` with error output and does not commit. Orchestrator reads this and halts before creating worktrees.

### `## Stub Report` Section (in `message-formats.md`)

Placement: Written by the Orchestrator after wave agent completion reports, before the next wave section (or at end of doc if final wave). Human-facing prose, NOT a typed block.

Schema:
```markdown
## Stub Report — Wave {N}

_Generated by scan-stubs.sh after wave {N} completion. Informational only — does not block merge._

{Either "No stub patterns detected." or the markdown table from scan-stubs.sh output}
```

### `quality_gates` IMPL Doc Section (in `message-formats.md`)

Placement: Written by the Scout into the IMPL doc, between the Suitability Assessment and Scaffolds sections. Optional — omit if no gates are configured.

Schema:
```markdown
## Quality Gates

level: quick | standard | full

gates:
  - type: typecheck | test | lint | custom
    command: {exact shell command}
    required: true | false
    description: {one-line human description}
```

### Scout Emission Point (in `scout.md`)

The Scout optionally emits the `## Quality Gates` section after Suitability Assessment. It auto-detects project type from marker files (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`) and proposes appropriate gate commands. The section is advisory — the human can edit gate config at review time.

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/execution-rules.md | A | 1 | — |
| protocol/message-formats.md | A | 1 | — |
| implementations/claude-code/prompts/agents/scaffold-agent.md | B | 1 | — |
| implementations/claude-code/prompts/saw-skill.md | B | 1 | — |
| implementations/claude-code/prompts/scout.md | B | 1 | — |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B]                    <- 2 parallel agents (all work independent)
              | (A+B complete)
Orch:  Post-merge review + commit
```

---

## Wave 1

Both agents are fully independent. Agent A writes the protocol spec additions (new E-rule sections in `execution-rules.md` and new schema sections in `message-formats.md`). Agent B wires those rules into the agent prompts (`scaffold-agent.md`, `saw-skill.md`, `scout.md`). No compile-time dependency exists between them — B references the E-rule numbers by name (which are fixed in the interface contracts above).

### Agent A - Protocol Spec Additions

**0. Isolation Verification**

This is a markdown-only repo. No worktree isolation is required. Verify you are in the correct repo root:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave
git rev-parse --show-toplevel   # must print /Users/dayna.blackwell/code/scout-and-wave
git branch --show-current       # must print wave1-agent-A
```

If either check fails, stop and report in your completion report.

**1. File Ownership**

You own exactly these files:
- `protocol/execution-rules.md`
- `protocol/message-formats.md`

Do not modify any other file.

**2. Interfaces to Implement**

You must deliver, with exact section titles and E-rule numbers as specified:

- In `protocol/execution-rules.md`:
  - New section `## E20: Stub Detection Post-Wave` — see interface contracts for required content
  - New section `## E21: Automated Post-Wave Verification` — see interface contracts for required content
  - New section `## E22: Scaffold Build Verification` — see interface contracts for required content
  - Update the `## Cross-References` section at the bottom to add E20, E21, E22 references

- In `protocol/message-formats.md`:
  - New section `## Stub Report Section Format` describing the `## Stub Report — Wave {N}` schema (human-facing, not a typed block)
  - New section `## Quality Gates Section Format` describing the `quality_gates` schema (written by Scout, read by Orchestrator)
  - Update the `## IMPL Doc Structure` section to include `## Quality Gates` and `## Stub Report` in the canonical section order

**3. Interfaces to Call**

You do not depend on any other agent's output. Read the existing content of both files before editing to understand the current section order and E-rule numbering (existing rules end at E16).

**4. What to Implement**

In `protocol/execution-rules.md`:

Add three new E-rule sections after the existing `## E16: Scout Output Validation` section. Each section must follow the same structural pattern as existing rules (Trigger, Required Action, and explanatory content). Use the interface contracts above as the authoritative content source.

For **E20 (Stub Detection Post-Wave):**
- Trigger: after all wave agents complete, before review checkpoint
- Required Action: orchestrator collects file lists from completion reports, runs `scan-stubs.sh` with those files, writes output to IMPL doc under `## Stub Report` section
- Clarify: exit code is always 0 (informational); stubs surface at review, do not block merge automatically
- Note that the script is at `scripts/scan-stubs.sh` (E20 was pre-announced in the script's header comment — validate the comment matches)

For **E21 (Automated Post-Wave Verification):**
- Trigger: after all wave agents report complete, before merge
- Required Action: orchestrator runs configured quality gates from IMPL doc `quality_gates` section
- Document gate types (typecheck, test, lint, custom), required vs optional behavior, and flow levels (quick/standard/full)
- Explicitly note: AI Verification Gate is out of scope for this rule

For **E22 (Scaffold Build Verification):**
- Trigger: Scaffold Agent completes file creation, before committing
- Required Action: run dependency resolution, dependency cleanup, build verification (with language-specific commands)
- Document failure behavior: report `status: FAILED`, do not commit, orchestrator halts before worktrees

Update `## Cross-References` to add entries for E20, E21, E22 pointing to `message-formats.md` and `scaffold-agent.md`.

In `protocol/message-formats.md`:

Add two new schema sections:

1. **`## Stub Report Section Format`** — document the `## Stub Report — Wave {N}` schema. It is a prose section written by the orchestrator, not a typed block. Show the template with "No stub patterns detected." and the table variant. Place this section near the existing completion report section (it is a related orchestrator output).

2. **`## Quality Gates Section Format`** — document the `quality_gates` schema written by the Scout. Show the full YAML structure (level, gates array with type/command/required/description fields). Describe auto-detection behavior from marker files. Note that the section is optional and human-editable at review time.

Update the `## IMPL Doc Structure` section to insert `## Quality Gates` between Suitability Assessment and Scaffolds, and to note that `## Stub Report` sections appear after wave completion reports.

Update the `## Message Flow Sequence` section to add:
- After step 5 (agents write completion reports): "5a. Orchestrator runs E20 stub scan, writes `## Stub Report` to IMPL doc."
- Before step 6: "5b. Orchestrator runs E21 post-wave verification gates (if configured)."

**5. Tests to Write**

This is a markdown spec repo with no automated test suite. Verification is human review of the spec text for internal consistency. No tests to write.

**6. Verification Gate**

```bash
# Verify files exist and are non-empty
ls -la /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md
ls -la /Users/dayna.blackwell/code/scout-and-wave/protocol/message-formats.md

# Verify new E-rule sections are present
grep -n "## E20" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md
grep -n "## E21" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md
grep -n "## E22" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md

# Verify new schema sections are present in message-formats.md
grep -n "Stub Report" /Users/dayna.blackwell/code/scout-and-wave/protocol/message-formats.md
grep -n "Quality Gates" /Users/dayna.blackwell/code/scout-and-wave/protocol/message-formats.md

# Verify IMPL doc structure section was updated
grep -n "quality_gates\|Quality Gates\|Stub Report" /Users/dayna.blackwell/code/scout-and-wave/protocol/message-formats.md
```

**7. Constraints**

- Do NOT renumber existing E-rules (E1–E16). New rules append after E16.
- Do NOT edit sections owned by other agents or sections that the concurrent failure-taxonomy scout will touch. Read the existing content carefully before editing.
- The `## Stub Report` schema must NOT be a typed block (no `type=impl-*` annotation) — it is human-facing prose only.
- The `quality_gates` section in the IMPL doc structure is written by the Scout; Agent A documents the schema but does not change scout.md (that is Agent B's file).
- Follow existing style conventions in each file (same heading levels, same Trigger/Required Action pattern for E-rules, same YAML examples formatting in message-formats.md).
- E20 must note that `scan-stubs.sh` already carries the comment `# scan-stubs.sh — SAW stub detection scanner (E20)` — the rule number was reserved in the script. The rule definition confirms that reservation.

**8. Report**

When complete, append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-quality-gates.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: .claude/worktrees/wave1-agent-A
branch: wave1-agent-A
commit: {sha}
files_changed:
  - protocol/execution-rules.md
  - protocol/message-formats.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL ({command})
```

Follow with free-form notes on any spec decisions or open questions for Agent B.

---

### Agent B - Agent Prompt Wiring

**0. Isolation Verification**

This is a markdown-only repo. Verify you are in the correct repo root and branch:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave
git rev-parse --show-toplevel   # must print /Users/dayna.blackwell/code/scout-and-wave
git branch --show-current       # must print wave1-agent-B
```

If either check fails, stop and report in your completion report.

**1. File Ownership**

You own exactly these files:
- `implementations/claude-code/prompts/agents/scaffold-agent.md`
- `implementations/claude-code/prompts/saw-skill.md`
- `implementations/claude-code/prompts/scout.md`

Do not modify any other file. Do NOT touch `protocol/execution-rules.md` or `protocol/message-formats.md` — those are Agent A's files.

**2. Interfaces to Implement**

You must wire the three quality gate features into the agent prompts, referencing these exact rule numbers (defined by Agent A in `execution-rules.md`):
- **E20** — Stub Detection Post-Wave
- **E21** — Automated Post-Wave Verification
- **E22** — Scaffold Build Verification

The E-rule numbers and section titles above are fixed. Use them exactly as written when referencing in prose.

**3. Interfaces to Call**

- `scan-stubs.sh` is at `implementations/claude-code/scripts/scan-stubs.sh` relative to repo root. In orchestrator prompts, reference it as `${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh` (skills are installed with their scripts directory).
- Read `implementations/claude-code/prompts/agents/scaffold-agent.md` in full before editing.
- Read `implementations/claude-code/prompts/saw-skill.md` in full before editing. It is a long file (~158 lines); the post-wave checklist area is the primary insertion point.
- Read `implementations/claude-code/prompts/scout.md` in full before editing.

**4. What to Implement**

In `implementations/claude-code/prompts/agents/scaffold-agent.md`:

Add a new **"Build Verification"** step between the current "Commit each scaffold file" step and the "Update the IMPL doc" step (currently steps 3 and 4 in "## Your Task"). The new step must:

1. Run dependency resolution: language-specific command (Go: `go get ./...`, Python: `pip install -e .` or `uv sync`, Node: `npm install`, Rust: `cargo fetch`)
2. Run dependency cleanup: Go: `go mod tidy`, others: describe equivalent if applicable
3. Run build verification: Go: `go build ./...`, Rust: `cargo build`, Node: `npm run build` or `tsc --noEmit`, Python: `python -m py_compile **/*.py` or type check
4. If any step fails: do NOT commit, mark IMPL doc scaffold status as `FAILED: {reason}` with the error output, exit

Also update the `## Verification` section to add a pre-commit item: "Build passes (`go build ./...` or language equivalent) with scaffold files present."

Also update the `## Rules` section to add: "Before committing, verify the project builds with scaffold files in place (E22). A scaffold that introduces syntax errors wastes the entire next wave."

Reference E22 by number in this section.

In `implementations/claude-code/prompts/saw-skill.md`:

The orchestrator must run E20 and E21 after wave agents complete. Locate the section in the existing IMPL-exists flow where agents complete and the orchestrator reads completion reports (currently step 4 in the "If a `docs/IMPL/IMPL-*.md` file already exists" flow). After the existing completion-report reading logic, add:

- **E20 stub scan:** After reading all completion reports, collect the union of `files_changed` and `files_created` from all agent reports. Run `bash ${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh {file1} {file2} ...`. Append the output to the IMPL doc under `## Stub Report — Wave {N}` (after the last completion report section for this wave). Reference E20.

- **E21 post-wave verification:** If the IMPL doc contains a `## Quality Gates` section, read the configured gates and run each command. For `required: true` gates, a non-zero exit code blocks merge (report to user). For `required: false` gates, a non-zero exit code is a warning only. Reference E21.

Place these two steps between step 4 (read completion reports) and step 5 (merge and verify) in the existing IMPL-exists flow.

In `implementations/claude-code/prompts/scout.md`:

Add guidance for emitting an optional `## Quality Gates` section. Insert this as a new step (after step 9 "Determine verification gates" and before step 10 "Expect validation feedback"). The new step should:

- Describe auto-detection from project marker files (`go.mod` → Go gates, `package.json` → Node gates, `Cargo.toml` → Rust gates, `pyproject.toml` → Python gates)
- Show the YAML schema for the quality_gates section (level + gates array)
- Note that the section is optional — omit if the project has no known build toolchain or if the user has not configured gates
- Remind Scout that the section appears between Suitability Assessment and Scaffolds in the IMPL doc structure
- State that gate commands should use the same toolchain commands already identified for the verification gate (Field 6) — no new tool discovery needed

**5. Tests to Write**

This is a markdown spec repo with no automated test suite. No tests to write.

**6. Verification Gate**

```bash
# Verify scaffold-agent.md has the new build verification step
grep -n "go get\|go build\|Build Verification\|E22" /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md

# Verify saw-skill.md has E20 and E21 references
grep -n "E20\|E21\|scan-stubs\|Stub Report\|quality_gates\|Quality Gates" /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md

# Verify scout.md has the Quality Gates emission step
grep -n "quality_gates\|Quality Gates\|auto-detect" /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/scout.md
```

**7. Constraints**

- The concurrent failure-taxonomy scout will also edit `saw-skill.md` (for `failure_type` logic in completion report handling). Your edits to `saw-skill.md` are in the post-agent-completion area (between steps 4 and 5 of the IMPL-exists flow). Do NOT touch step 4's failure handling logic or the E7/E7a/E8 text — those are the failure taxonomy scout's territory.
- The concurrent failure-taxonomy scout will also edit `execution-rules.md`. Do not touch that file; Agent A owns it.
- Do NOT change the structure of the 9-field agent prompt format in `scaffold-agent.md` — only add the build verification step within the existing "## Your Task" procedure.
- When referencing `scan-stubs.sh` in `saw-skill.md`, use `${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh` (not an absolute path) so the prompt works across different installation directories.
- Keep changes minimal and surgical. Add only what is specified — do not refactor existing prose or restructure sections you are not required to change.

**8. Report**

When complete, append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-quality-gates.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: .claude/worktrees/wave1-agent-B
branch: wave1-agent-B
commit: {sha}
files_changed:
  - implementations/claude-code/prompts/agents/scaffold-agent.md
  - implementations/claude-code/prompts/saw-skill.md
  - implementations/claude-code/prompts/scout.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL ({command})
```

Follow with free-form notes on any decisions, especially around `saw-skill.md` insertion point selection (which paragraph/step you inserted after).

---

## Wave Execution Loop

After Wave 1 completes, work through the checklist below.

The merge procedure detail is in `saw-merge.md`. Key principles:
- Read completion reports first — a `status: partial` or `status: blocked` blocks the merge entirely. No partial merges.
- This is a markdown-only repo. Post-merge verification is a human review of the spec for internal consistency, not an automated build.

### Orchestrator Post-Merge Checklist

After wave 1 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree (should be zero overlap by design)
- [ ] Review `interface_deviations` — if Agent A used different E-rule numbers or section titles than specified in interface contracts, update Agent B's prompts before merging Agent B's branch
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave1-agent-{X}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (markdown-only)
      - [ ] Human review: verify E20/E21/E22 sections in `execution-rules.md` are internally consistent with the schema sections added to `message-formats.md`
      - [ ] Human review: verify `scaffold-agent.md` build verification step matches E22 rule
      - [ ] Human review: verify `saw-skill.md` stub scan and quality gate wiring matches E20 and E21 rules
      - [ ] Human review: verify `scout.md` quality gate emission guidance is consistent with `message-formats.md` schema
- [ ] Check for conflicts with the concurrent failure-taxonomy scout's changes to `execution-rules.md` and `saw-skill.md`. If the failure-taxonomy IMPL doc merges first, re-read both files before merging this IMPL's branches.
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Feature-specific steps:
      - [ ] Verify E-rule numbering does not conflict with failure-taxonomy scout's new rules (both scouts must use non-overlapping E-numbers)
      - [ ] Update the version number in `execution-rules.md` header if the project follows semantic versioning for the protocol spec
- [ ] Commit: `git commit -m "feat: E20 stub detection, E21 post-wave verification, E22 scaffold build check"`
- [ ] Launch next wave (none — this is a single-wave IMPL)

### Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | E20/E21/E22 rules in execution-rules.md + schema in message-formats.md | COMPLETE |
| 1 | B | Scaffold-agent build verification + saw-skill.md wiring + scout.md emission | COMPLETE |
| — | Orch | Post-merge consistency review + commit | TO-DO |

---

### Agent A - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-a
branch: wave1-agent-a
commit: 5efca99
files_changed:
  - protocol/execution-rules.md
  - protocol/message-formats.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All three E-rules (E20, E21, E22) added to `protocol/execution-rules.md` after E19, following the existing Trigger/Required Action/Rationale/Related Rules pattern. Cross-References updated with entries for all three.

Two new schema sections added to `protocol/message-formats.md`: `## Stub Report Section Format` (human-facing prose, not a typed block, with both the no-stubs and stubs-found table templates) and `## Quality Gates Section Format` (YAML schema with auto-detection table for go.mod/package.json/Cargo.toml/pyproject.toml). IMPL Doc Structure updated to insert `## Quality Gates` between Suitability Assessment and Scaffolds, and to show `## Stub Report — Wave {N}` placement after completion reports. Message Flow Sequence updated with steps 5a (E20 stub scan) and 5b (E21 gates).

One decision: placed `## Stub Report Section Format` and `## Quality Gates Section Format` together after the existing `## Scaffolds Section Format` section, before `## docs/CONTEXT.md` — this groups all "orchestrator-written IMPL doc sections" together and keeps the file's section order consistent with how an IMPL doc flows top-to-bottom.

Note for Agent B: the `## Quality Gates` section in IMPL doc structure uses the YAML schema defined in `## Quality Gates Section Format`. The `level` field and `gates` array structure are canonical — Agent B's scout.md additions should reference the same schema verbatim or by cross-reference to `message-formats.md`.

---

### Agent B - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-b
branch: wave1-agent-b
commit: 79e3b58
files_changed:
  - implementations/claude-code/prompts/agents/scaffold-agent.md
  - implementations/claude-code/prompts/saw-skill.md
  - implementations/claude-code/prompts/agents/scout.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
```

All three files updated as specified. Key decisions:

- scaffold-agent.md: inserted Build Verification (E22) as step 3 between file creation and commit; renumbered old steps 3 and 4 to 4 and 5. Updated Verification section (pre-commit build check added as item 2) and Rules section (E22 rationale appended as final bullet).

- saw-skill.md: E20 and E21 steps inserted immediately before "5. Merge and verify" — after the step 4 completion-report reading block closes. The existing failure-handling logic (E7, E7a, E8 text) within step 4 was not touched.

- agents/scout.md: new step 11 (Quality Gates emission) inserted between old step 10 (verification gates / lint command) and old step 11 (E16 validation feedback, now renumbered step 12). Uses marker-file auto-detection table as specified. Scout is directed to reuse commands already identified for test_command — no redundant tool discovery.

One discrepancy to flag: the IMPL doc File Ownership table lists `implementations/claude-code/prompts/scout.md` but the actual file path is `implementations/claude-code/prompts/agents/scout.md`. The agent prompt text correctly specifies the agents/ path. Recommend the orchestrator correct the file ownership table entry at post-merge.
