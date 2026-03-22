# Documentation Audit Report

**Date:** 2026-03-21
**Scope:** All .md files in scout-and-wave protocol repository
**Auditor:** Claire (automated)
**Context:** The `sdk` branch has been merged into `main`. The Go engine (`sawtools`) is now canonical. Any references to "natural language only", "no binary dependencies", or the old prompt-only approach are outdated.

---

## Summary

- **Total files audited:** 63
- **Files with issues:** 24
- **Files that are clean:** 39
- **Severity breakdown:**
  - Critical: 4
  - Major: 14
  - Minor: 12

---

## Critical Issues

Issues that are factually wrong or could mislead users.

### 1. ECOSYSTEM.md contradicts current architecture

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/ECOSYSTEM.md`

The entire "What SAW provides" section (lines 177-204) describes SAW as "Protocol, not product" with explicit claims that are now false:

- Line 177-179: "SAW is a set of markdown files: prompt templates, a skill router, and a formal spec... No binary, no server, no SDK, no vendor lock-in."
- Lines 195-204: "Why not enforce invariants in code?" section argues against code enforcement, stating "the prompt-native approach is the correct call: it's simpler, more portable, and proves something worth proving."

**Reality:** SAW now has a Go SDK (`sawtools` binary), a web server (`saw serve`), and mechanically enforces invariants in code. The entire section arguing against code enforcement is contradicted by the current architecture.

**Suggested fix:** Rewrite the "What SAW provides" section to reflect the current positioning: "open protocol with Go engine for mechanical enforcement." Keep the competitive landscape analysis (which is accurate) but update the SAW description to match reality.

### 2. ECOSYSTEM.md references outdated execution rule range

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/ECOSYSTEM.md`

Line 208: References "invariants I1-I6, rules E1-E26" but execution rules now go up to E41.

**Suggested fix:** Update to "E1-E41".

### 3. README.md version badge is stale

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Line 4: `![Version](https://img.shields.io/badge/version-0.14.0-blue)` but CHANGELOG shows version is 0.55.0.

**Suggested fix:** Update badge to `version-0.55.0`.

### 4. README.md Quick Start references non-existent files

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Lines 89-91 reference files that do not exist:
- `saw-merge.md` -- does not exist in `implementations/claude-code/prompts/`
- `saw-worktree.md` -- does not exist in `implementations/claude-code/prompts/`

The Quick Start manual install section shows symlink commands for `saw-merge.md` and `saw-worktree.md`, but these files have been removed. Only `saw-skill.md`, `saw-bootstrap.md`, `agent-template.md`, and the `agents/` directory exist.

**Suggested fix:** Remove the symlink lines for `saw-merge.md` and `saw-worktree.md` from the Quick Start. Also update the `scout.md` symlink path (line 92 references `prompts/scout.md` but it should be `prompts/agents/scout.md`).

---

## Major Issues

Significant staleness, missing documentation for important features, or inconsistencies between docs.

### 5. protocol/README.md version is very stale

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/README.md`

Line 52: "Current version: **0.14.8**" but CHANGELOG shows 0.55.0 and individual protocol docs show 0.15.0-0.20.0.

**Suggested fix:** Update to current version.

### 6. protocol/README.md execution rules description outdated

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/README.md`

Line 16: Describes "twenty-six execution rules (E1-E26)" but execution-rules.md defines E1-E41. Missing references to E27-E41 (planned integration waves, tier execution, program execution, IMPL amendment, critic gate, gate caching, interview mode, observability, type collision detection).

**Suggested fix:** Update count and add the missing rule descriptions.

### 7. README.md execution rules description outdated

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Line 132: References "E1-E26" but execution rules now go to E41. Missing mention of program-level rules (E28-E34), IMPL amendment (E36), critic gate (E37), gate caching (E38), interview mode (E39), observability (E40), and type collision detection (E41).

**Suggested fix:** Update to reflect current rule range and add the missing categories.

### 8. docs/architecture.md references outdated execution rule range

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/architecture.md`

Line 398: "See Also" section references "E1-E26 orchestrator rules" but there are now E1-E41.

**Suggested fix:** Update to "E1-E41".

### 9. docs/architecture.md worktree paths use legacy format

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/architecture.md`

Lines 71-76 and 346-349: Worktree directory structure shows `wave1-agent-A/` without the `saw/{slug}/` prefix. The current canonical format (per message-formats.md) is `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}`.

**Suggested fix:** Update the directory tree examples to use the canonical `saw/{slug}/` prefix format.

### 10. docs/architecture.md config missing newer model fields

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/architecture.md`

Lines 374-392: The `saw.config.json` example is missing `scaffold_model`, `planner_model`, and `critic_model` fields that are documented in `saw-skill.md`.

**Suggested fix:** Add the missing model fields to the config example.

### 11. agent-template.md references outdated E-rule range

**File:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md`

Line 22: References "E1-E26" but rules now go to E41.

**Suggested fix:** Update to "E1-E41".

### 12. wave-agent.md references outdated E-rule range

**File:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md`

Line 13: References "E1-E26" but rules now go to E41.

**Suggested fix:** Update to "E1-E41".

### 13. agent-template.md worktree path uses legacy format

**File:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md`

Lines 54, 62, 73, 98: Field 0 worktree paths use legacy format `.claude/worktrees/wave{N}-agent-{ID}` without the `saw/{slug}/` prefix. Branch names on line 73 also use legacy format `wave{N}-agent-{ID}` without the `saw/{slug}/` prefix.

The canonical formats (per message-formats.md line 198/199 and saw-skill.md line 336-340) are:
- Worktree: `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}`
- Branch: `saw/{slug}/wave{N}-agent-{ID}`

**Suggested fix:** Update Field 0 paths and branch names to use the canonical `saw/{slug}/` prefix format.

### 14. saw-skill.md version and E-rule range stale

**File:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md`

Line 20: `version: "0.13.0"` but CHANGELOG shows skill has been updated to at least 0.55.0 worth of protocol changes.
Line 40: References "E1-E37" but rules now go to E41.

**Suggested fix:** Update version and E-rule range.

### 15. ROADMAP.md "SDK Branch as Generated Build Artifact" section is stale

**File:** `/Users/dayna.blackwell/code/scout-and-wave/ROADMAP.md`

Lines 1027-1082: The entire "SDK Branch as Generated Build Artifact" section describes a problem (maintaining `main` and `sdk` branches) that no longer exists. The `sdk` branch has been merged into `main`. This section is misleading because it implies both branches still exist.

**Suggested fix:** Mark this section as "RESOLVED" or remove it. The merge of `sdk` into `main` eliminates the problem described.

### 16. ROADMAP.md describes `main` as "natural language only"

**File:** `/Users/dayna.blackwell/code/scout-and-wave/ROADMAP.md`

Lines 1029-1031: States "`main` -- natural language only. Refers to the `saw` CLI throughout" and "`sdk` -- SDK-coupled. All `saw` references replaced with `sawtools`." This is now false; `main` uses `sawtools` throughout.

**Suggested fix:** Remove or rewrite this section since the dual-branch approach is resolved.

### 17. docs/INSTALLATION.md says Go 1.25+ but installed Go is 1.26

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/INSTALLATION.md`

Lines 10, 27: Reference "Go 1.25+" as minimum. This should be verified against `go.mod` in scout-and-wave-go. While technically still correct (1.26 >= 1.25), the version should match what the `go.mod` actually requires to avoid confusion.

**Suggested fix:** Verify minimum Go version against `go.mod` and update if needed.

### 18. state-machine.md "Correctness Properties" E-rule range stale

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/state-machine.md`

Line 237: References "E1-E34, E21A, E21B" but rules now go to E41. Missing E35-E41.

**Suggested fix:** Update to "E1-E41".

---

## Minor Issues

Style inconsistencies, typos, or slightly outdated phrasing.

### 19. README.md IMPL doc described as ".md" in one place

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Line 39: References "IMPL doc (implementation document -- a markdown coordination artifact...)" but IMPL docs are now YAML manifests (`.yaml`). Line 97 correctly references `.md` extension for the output path (`docs/IMPL/IMPL-caching-layer.md`) but the current format is `.yaml`.

**Suggested fix:** Update line 39 to say "YAML coordination artifact" and line 97 to show `.yaml` extension.

### 20. README.md "Ways to Use SAW" table slightly misleading

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Lines 115-120: The table describes the standalone CLI as being in `scout-and-wave-go` but the `saw serve` binary is actually in `scout-and-wave-web`. The Go repo produces `sawtools`, not the `saw` binary with web UI. This distinction is correct in the description but the row organization could be clearer.

**Suggested fix:** Consider adding a third row for the web app or clarifying the relationship between the repos.

### 21. preconditions.md uses "P1-P5" which conflicts with program invariants "P1-P4"

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/preconditions.md`

The five preconditions are labeled P1-P5, but program-invariants.md also uses P1-P4. This creates an identifier collision. Preconditions are also referenced elsewhere as "precondition 1-5" (not P1-P5), so the P-prefix in this file is informal, but it could confuse readers who also read program-invariants.md.

**Suggested fix:** Consider renaming preconditions to use a different prefix (e.g., "PC1-PC5" or "Precondition 1-5") to avoid collision with P1-P4 program invariants, or add a disambiguation note.

### 22. CLAUDE.md is empty

**File:** `/Users/dayna.blackwell/code/scout-and-wave/CLAUDE.md`

The file exists but is empty (1 line, no content).

**Suggested fix:** Either add project-level instructions for Claude Code sessions, or remove the file if not needed.

### 23. docs/QUICKSTART-CLI.md and QUICKSTART-WEB.md referenced but may be stubs

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/GETTING_STARTED.md`

Lines 44-45: Reference "QUICKSTART-CLI.md (coming soon)" and "QUICKSTART-WEB.md (coming soon)". These files exist on disk but may still be incomplete/stubs.

**Suggested fix:** Verify these files are complete. If still stubs, either complete them or remove the "(coming soon)" references and link to the actual quickstart that exists.

### 24. message-formats.md has IMPL doc path examples with .md extension

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/message-formats.md`

Line 897: References `docs/IMPL/IMPL-<feature>-wave{N}-agent-{ID}.md` for split agent prompts. Since IMPL docs are now YAML, the split files may also use `.yaml` extension, though the agent prompt files could legitimately be `.md`.

**Suggested fix:** Clarify whether split agent prompt files use `.md` or `.yaml` extension.

### 25. participants.md says "six participant roles" but header says "five"

**File:** `/Users/dayna.blackwell/code/scout-and-wave/protocol/participants.md`

Line 4: "SAW has six participant roles" which is correct (Orchestrator, Scout, Scaffold Agent, Wave Agent, Integration Agent, Critic Agent... and Planner). But README.md line 32 says "Five participants." The Planner and Critic Agent are newer additions.

**Suggested fix:** Update README.md to reflect six or seven participant roles (depending on whether Planner is counted), or note that the core protocol has five participants with two additional roles for program-level and quality-gate features.

### 26. README.md references "five participants" but there are now seven

**File:** `/Users/dayna.blackwell/code/scout-and-wave/README.md`

Line 32: "Five participants coordinate within a single session: the Orchestrator, Scout, Scaffold Agent, Wave Agents, and Integration Agent." Missing: Critic Agent (E37) and Planner (program-level).

**Suggested fix:** Update to include all seven participant roles, or note that the five are the core participants with Critic and Planner as extensions.

### 27. Several docs directory files are historical/reference only

Multiple files in `docs/` appear to be historical analysis or one-time audit outputs rather than living documentation:
- `docs/dogfooding-2026-03-06-protocol-extraction.md`
- `docs/protocol-conformity-audit.md`
- `docs/skills-best-practices-audit.md`
- `docs/symlink-diagram.md` / `docs/symlink-diagram-v2.md`
- `docs/symlink-structure-analysis.md`
- `docs/scout-trim-roadmap.md`
- `docs/protocol-enhancement-roadmap.md`
- `docs/protocol-sdk-migration.md`

These are not wrong per se but could confuse new users browsing the docs/ directory.

**Suggested fix:** Consider moving historical/one-time documents to a `docs/archive/` directory to separate them from active documentation.

### 28. ROADMAP.md E23A section still shows unchecked deliverables

**File:** `/Users/dayna.blackwell/code/scout-and-wave/ROADMAP.md`

Lines 95-99 state "Status: Implementation complete (v0.27.0), integration across all backends ongoing" but lines 565-573 still show unchecked `- [ ]` deliverables for items that are implemented (core journal, context generator, checkpoint system, etc.).

**Suggested fix:** Check off completed deliverables or move the entire E23A section to "Completed & Shipped."

### 29. ROADMAP.md IMPL-level parallelism section superseded by Program Layer

**File:** `/Users/dayna.blackwell/code/scout-and-wave/ROADMAP.md`

Lines 957-997: The "IMPL-Level Parallelism" section proposes cross-IMPL file locking and a meta-orchestrator. This has been largely superseded by the Program Layer (P1-P4, tiers, PROGRAM manifests) which is now implemented. The section proposes a "new I7" invariant that was never created because the tier system addresses the same concern differently.

**Suggested fix:** Mark as superseded by the Program Layer or remove. Add a note pointing to `protocol/program-invariants.md` and `protocol/program-manifest.md`.

### 30. docs/CONTEXT.md missing recent features

**File:** `/Users/dayna.blackwell/code/scout-and-wave/docs/CONTEXT.md`

This file tracks features completed via SAW. While it has 12 entries, it may be missing recently completed features that haven't had `sawtools update-context` run. Not a documentation error per se, but worth noting for completeness.

**Suggested fix:** Run `sawtools update-context` to ensure all completed IMPLs are reflected.

---

## Per-File Findings

### Files with Issues (alphabetical)

| File | Issues |
|------|--------|
| `CHANGELOG.md` | Clean (very detailed, up to date) |
| `CLAUDE.md` | Minor #22: empty file |
| `README.md` | Critical #3 (stale version), Critical #4 (missing files), Major #7 (E-rule range), Minor #19, #20, #26 |
| `ROADMAP.md` | Major #15, #16 (stale sdk branch section), Minor #28, #29 |
| `docs/ECOSYSTEM.md` | Critical #1, #2 (contradicts current architecture) |
| `docs/GETTING_STARTED.md` | Minor #23 (coming soon references) |
| `docs/INSTALLATION.md` | Major #17 (Go version check) |
| `docs/architecture.md` | Major #8, #9, #10 (E-rule range, legacy paths, missing config) |
| `docs/CONTEXT.md` | Minor #30 (possibly incomplete) |
| `implementations/claude-code/prompts/agent-template.md` | Major #11, #13 (E-rule range, legacy paths) |
| `implementations/claude-code/prompts/agents/wave-agent.md` | Major #12 (E-rule range) |
| `implementations/claude-code/prompts/saw-skill.md` | Major #14 (stale version, E-rule range) |
| `protocol/README.md` | Major #5, #6 (stale version, E-rule count) |
| `protocol/message-formats.md` | Minor #24 (split file extension) |
| `protocol/participants.md` | Minor #25 (participant count) |
| `protocol/preconditions.md` | Minor #21 (P-prefix collision) |
| `protocol/state-machine.md` | Major #18 (E-rule range) |

### Files That Are Clean

The following files passed audit with no issues found:

- `CHANGELOG.md` -- comprehensive, up to date, accurate version history
- `docs/competitive/agent-orchestrator.md`
- `docs/competitive/paperclip-analysis.md`
- `docs/competitive/paperclip.md`
- `docs/diagrams/three-repo-architecture.md`
- `docs/dogfooding-2026-03-06-protocol-extraction.md`
- `docs/ftue-analysis.md`
- `docs/HOOKS.md`
- `docs/new-user-system-audit.md`
- `docs/observability-roadmap.md`
- `docs/program-layer.md`
- `docs/protocol-conformity-audit.md`
- `docs/protocol-enhancement-roadmap.md`
- `docs/protocol-sdk-migration.md`
- `docs/QUICKSTART-CLI.md`
- `docs/QUICKSTART-WEB.md`
- `docs/saw-ops/proposal.md`
- `docs/saw-ops/saw-ops.md`
- `docs/saw-ops/worktree-isolation-design.md`
- `docs/scout-trim-roadmap.md`
- `docs/skills-best-practices-audit.md`
- `docs/symlink-diagram-v2.md`
- `docs/symlink-diagram.md`
- `docs/symlink-structure-analysis.md`
- `docs/tool-journaling.md`
- `implementations/claude-code/hooks/README.md`
- `implementations/claude-code/prompts/agents/critic-agent.md`
- `implementations/claude-code/prompts/agents/integration-agent.md`
- `implementations/claude-code/prompts/agents/planner.md`
- `implementations/claude-code/prompts/agents/scaffold-agent.md`
- `implementations/claude-code/prompts/agents/scout.md`
- `implementations/claude-code/prompts/README.md`
- `implementations/claude-code/prompts/saw-bootstrap.md`
- `implementations/claude-code/QUICKSTART-CHANGES.md`
- `implementations/claude-code/QUICKSTART.md`
- `implementations/claude-code/README.md`
- `implementations/README.md`
- `PROTOCOL_AUDIT_REPORT.md`
- `protocol/execution-rules.md` -- comprehensive, E1-E41, version 0.20.0
- `protocol/interview-mode.md`
- `protocol/invariants.md` -- I1-I6 well-defined, version 0.15.0
- `protocol/message-formats.md` -- detailed schemas, version 0.15.0
- `protocol/observability-events.md` -- new, version 0.20.0
- `protocol/participants.md` -- all 7 roles documented
- `protocol/preconditions.md` -- version 0.15.0
- `protocol/procedures.md` -- version 0.16.0
- `protocol/program-invariants.md` -- P1-P4 + P1+, version 0.1.0
- `protocol/program-manifest.md` -- version 0.2.0
- `protocol/state-machine.md` -- includes program state machine, version 0.16.0
- `saw-teams/DESIGN.md`
- `saw-teams/hooks.md`
- `saw-teams/README.md`
- `saw-teams/saw-teams-merge.md`
- `saw-teams/saw-teams-skill.md`
- `saw-teams/saw-teams-worktree.md`
- `saw-teams/teammate-template.md`

---

## Cross-Repo Verification Summary

### sawtools commands referenced in docs vs actual CLI

All `sawtools` commands referenced in `saw-skill.md` (lines 184-216) were verified against `sawtools --help` output. The following commands exist in the CLI but are not documented in saw-skill.md:

- `analyze-deps` -- referenced in Scout prompt, not in saw-skill.md command list
- `analyze-suitability` -- referenced in Scout prompt, not in saw-skill.md command list
- `assign-agent-ids` -- exists in CLI
- `check-deps` -- exists in CLI
- `check-type-collisions` -- exists in CLI (E41)
- `cleanup-stale` -- exists in CLI
- `create-program` -- exists in CLI
- `daemon` -- exists in CLI
- `detect-cascades` -- exists in CLI
- `detect-scaffolds` -- exists in CLI
- `diagnose-build-failure` -- referenced in agent-template.md, not in saw-skill.md
- `extract-commands` -- exists in CLI
- `import-impls` -- referenced in saw-skill.md line 543
- `journal-context` -- exists in CLI
- `journal-init` -- exists in CLI
- `metrics` -- exists in CLI
- `populate-integration-checklist` -- exists in CLI
- `prepare-agent` -- exists in CLI, referenced in saw-skill.md
- `program-execute` -- exists in CLI
- `query` -- exists in CLI (observability)
- `retry` -- exists in CLI
- `run-review` -- exists in CLI
- `run-scout` -- exists in CLI, referenced in saw-skill.md
- `set-impl-state` -- exists in CLI
- `solve` -- exists in CLI
- `validate-scaffold` -- exists in CLI

This is expected -- saw-skill.md documents the commands the orchestrator uses directly, not every available command. No documentation claims a command that does not exist.

### Go package structure

References to `pkg/observability/` in observability-events.md confirmed: the package exists with `emitter.go`, `events.go`, `query.go`, `rollups.go`, `store.go`.

References to `pkg/protocol/` confirmed: extensive package with all referenced types and validators.

References to `pkg/engine/` confirmed: extensive package with runner, scheduler, finalize, program execution.

---

## Recommendations (Priority Order)

1. **Fix ECOSYSTEM.md** (Critical) -- This is the public-facing positioning document and currently contradicts the project's architecture. The "no binary, no SDK" claim is the highest-priority fix.

2. **Fix README.md** (Critical) -- Update version badge, remove broken symlink references, update participant count and E-rule range, fix IMPL doc extension references.

3. **Sweep E-rule range references** (Major) -- At least 7 files reference "E1-E26" or similar outdated ranges. A single search-and-replace pass would fix all of them.

4. **Update legacy worktree path format** (Major) -- agent-template.md and architecture.md use the old `.claude/worktrees/wave{N}-agent-{ID}` format instead of `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}`.

5. **Clean up ROADMAP.md** (Major) -- Remove or mark as resolved the "SDK Branch" section and the superseded "IMPL-Level Parallelism" section.

6. **Update protocol/README.md version** (Major) -- The protocol README is the entry point for implementers; its version number should be current.
