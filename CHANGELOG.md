# Changelog

All notable changes to the Scout-and-Wave protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Version History

| Version | Date | Headline |
|---------|------|----------|
| [0.22.0] | 2026-03-10 | saw-skill v0.7.3, saw-worktree v0.6.3, saw-merge v0.6.2 — strip markdown dual-mode language; IMPL docs are YAML-only |
| [0.21.0] | 2026-03-10 | saw-skill v0.7.2 — short IMPL-referencing prompts: wave agents receive ~60-token stub instead of copy-pasted brief; 10–15× faster parallel wave launch |
| [0.20.0] | 2026-03-10 | E16A/B/C enforcement — E16C bash validator bug fixed, execution-rules.md sub-rules documented, saw-skill.md E16A note added |
| [0.19.0] | 2026-03-10 | saw-skill.md fixes — correct `extract-context` and `set-completion` CLI syntax; remove stale "Scout does not yet generate YAML" text; ROADMAP updates |
| [0.18.0] | 2026-03-10 | fix: validate-impl.sh delegates to `sawtools validate` — unblocks E16 YAML manifest validation |
| [0.17.0] | 2026-03-10 | sawtools rename in skill files — saw-skill v0.7.1, saw-merge v0.6.1, saw-worktree v0.6.2 |
| [0.16.0] | 2026-03-09 | Worktree isolation design doc + saw-worktree v0.6.1 — documents why native agent-definition isolation: worktree doesn't replace SAW orchestration |
| [0.15.1] | 2026-03-09 | Scout YAML migration — all Scout prompts now generate YAML manifests (.yaml) instead of markdown IMPL docs |
| [0.15.0] | 2026-03-09 | Protocol SDK conformance — 44-gap audit, 3-wave remediation (12 agents), skill prompts v0.6.0 with CLI command integration |
| [0.14.9] | 2026-03-09 | Agent Observatory — real-time tool call stream per wave agent |
| [0.14.8] | 2026-03-08 | E16D: Column order validation hardening — validator now enforces File\|Agent\|Wave column order to prevent silent data corruption at runtime. |
| [0.14.7] | 2026-03-08 | Seventh-pass convergence — 1 finding: protocol version 0.14.5→0.14.6 in README.md. 98% reduction from pass 6 signals convergence. Zero P0 issues. |
| [0.14.6] | 2026-03-08 | Sixth-pass audit — 41 findings + 6 verification fixes + 3 follow-ups: {X}→{ID} final cleanup, repo: field in completion reports, E16 in bootstrap flows, E20/E21 in merge procedures, invariant numbers, template consistency, historical docs |
| [0.14.5] | 2026-03-08 | Fifth-pass audit — 20 findings: {letter}→{ID} in merge/worktree/hooks/DESIGN/QUICKSTART/skill files, saw-bootstrap.md section order canonical, saw-teams-merge parity (failure_type/timeout, Step 1.75 File Ownership Verification), saw-teams-skill bootstrap Scaffold Agent step |
| [0.14.4] | 2026-03-08 | Fourth-pass audit — 17 findings: {letter}→{ID} propagation, Interface Contracts in IMPL structure, E20/E21 in procedures/checklist, saw-skill CLAUDE_SKILL_DIR note, brewprune attribution removed |
| [0.14.3] | 2026-03-08 | Third-pass audit — 25 findings: hooks path, saw-teams I6/E16/E15/E18/paths, scaffold 2-pass build, scout Step 0/cross-check, solo agent check |
| [0.14.2] | 2026-03-08 | Second-pass audit — saw-teams parity (E23 payload, IMPL paths, E19/E20/E21), bootstrap completeness |
| [0.14.1] | 2026-03-08 | First-pass audit — E1–E23 propagation, failure_type timeout, Quality Gates template, E17 fallback |
| [0.14.0] | 2026-03-08 | E23 per-agent context extraction — eliminates O(N²) token waste in large IMPL docs |
| [0.13.0] | 2026-03-08 | Quality gates (E20 stub detection, E21 post-wave verification, E22 scaffold build check) |
| [0.12.0] | 2026-03-08 | Project memory (docs/CONTEXT.md, E17/E18) + failure taxonomy (failure_type field, E19) |
| [0.11.2] | 2026-03-08 | Fix: validate-impl.sh path in saw-skill.md — use absolute symlink path |
| [0.11.1] | 2026-03-08 | Roadmap: engine extraction complete; protocol hardening items from cross-repo wave |
| [0.11.0] | 2026-03-08 | Cross-repo wave support: multi-repo worktree coordination, Repo column in file ownership, updated isolation layers |
| [0.10.4] | 2026-03-07 | Second consistency pass — scout heading levels, layer labels, suitability gate, invariant examples |
| [0.10.3] | 2026-03-07 | Documentation consistency pass; roadmap pruned to outstanding items only |
| [0.10.2] | 2026-03-07 | E16A required block presence enforcement; E16C out-of-band dep graph warning |
| [0.10.1] | 2026-03-07 | E16 validator script (scripts/validate-impl.sh); saw-skill.md calls script by path |
| [0.10.0] | 2026-03-07 | Typed metadata blocks (type=impl-*), E16 validation+correction loop, Pre-Mortem section, SCOUT_VALIDATING state |
| [0.9.5] | 2026-03-07 | Scout dep graph format prescribed; structured Wave/Agent/depends-on template replaces free-form prose |
| [0.9.4] | 2026-03-07 | E15: IMPL doc completion lifecycle; Scout output requires ## Wave N headers; documentation audit fixes |
| [0.9.3] | 2026-03-06 | Cleanup: templates/ deleted, IMPL-SCHEMA merged into protocol/message-formats.md, manual implementation removed |
| [0.9.2] | 2026-03-06 | Protocol drift fixes: branch field in completion reports, PROTOCOL.md ref, heading levels, IMPL-SCHEMA discoverability |
| [0.9.1] | 2026-03-06 | Open standard repositioning: Agent Skills badge, dual MIT/Apache-2.0 license, PROTOCOL.md removed |
| [0.9.0] | 2026-03-06 | Claude Code implementation: Skills API migration with YAML frontmatter, portable paths, tool restrictions |
| [0.8.0] | 2026-03-06 | Refactor: protocol extraction into protocol/ directory; implementations layer separation; manual orchestration guides |
| [0.7.2] | 2026-03-06 | Protocol: mandatory worktree isolation (E4) and cross-repository orchestration limitation documented |
| [0.7.1] | 2026-03-06 | Documentation: new-user onboarding gaps addressed; critical concepts defined on first mention |
| [0.7.0] | 2026-03-06 | Bootstrap: Scaffold Agent + Wave 1 handoff steps added; bootstrap now fully continuous |
| [0.6.9] | 2026-03-06 | Bootstrap: structured requirements intake via docs/REQUIREMENTS.md |
| [0.6.8] | 2026-03-05 | IMPL docs moved to docs/IMPL/ subdirectory to reduce clutter |
| [0.6.7] | 2026-03-05 | Wave Agent: explicit worktree isolation protocol using git -C flag |
| [0.6.6] | 2026-03-04 | Custom agent subtypes (optional); scout agent definition synced to v0.4.0; suitability gate question count fix |
| [0.6.5] | 2026-03-04 | SAW skill implements E7a: automatic retry logic for correctable agent failures |
| [0.6.4] | 2026-03-04 | E7a protocol rule: automatic failure remediation in --auto mode (spec) |
| [0.6.3] | 2026-03-04 | Scaffold Agent: repository context derivation from IMPL doc location |
| [0.6.2] | 2026-03-04 | Scout automatically detects shared types for scaffold files |
| [0.6.1] | 2026-03-03 | Scout status table includes scaffold rows with commit SHAs |
| [0.6.0] | 2026-03-03 | Scaffold Agent: new participant; Scout defines contracts, Scaffold Agent materializes them after review |
| [0.5.3] | 2026-03-03 | Deep consistency pass: 15 issues across 12 files |
| [0.5.2] | 2026-03-03 | I2 invariant updated: Scout defines and implements interface contracts |
| [0.5.1] | 2026-03-03 | Consistency pass: E-rule count, scaffold handling, Scout definition |
| [0.5.0] | 2026-03-03 | Wave 0 collapsed into Scout phase; solo-agent short-circuit removed |
| [0.4.4] | 2026-03-03 | saw-teams/example-settings.json; all required config fields in one copyable block |
| [0.4.3] | 2026-03-03 | saw-teams hooks, README, and spawn step; complete Agent Teams integration |
| [0.4.2] | 2026-03-03 | saw-teams prompt set synced to protocol v0.4.1; all invariants/E-rules propagated |
| [0.4.1] | 2026-03-03 | `test_command` field in IMPL doc; post-merge gate explicitly runs it unscoped |
| [0.4.0] | 2026-03-02 | Spec completeness pass: E1–E14 numbered, six spec holes patched, state machine diagram, all invariants embedded in skill, conformance criteria |
| [0.3.7] | 2026-03-01 | Orchestrator owns linter auto-fix post-merge; agents run check-only |
| [0.3.6] | 2026-03-01 | SAW tag format for claudewatch wave/agent observability |
| [0.3.5] | 2026-03-01 | I-number anchors for cross-referencing; I6 role separation invariant added |
| [0.3.4] | 2026-03-01 | Eight protocol gaps closed; Execution Rules section added |
| [0.3.3] | 2026-03-01 | Solo wave path formalized; 9-field agent template; conflict taxonomy |
| [0.3.2] | 2026-02-28 | Draw.io flow diagrams with light/dark SVG exports |
| [0.3.1] | 2026-02-28 | Structured YAML completion reports; automated conflict prediction |
| [0.3.0] | 2026-02-28 | Bootstrap mode for new projects; Wave 0 pattern |
| [0.2.0] | 2026-02-28 | Decomposed skill prompt; complexity-based suitability heuristic |
| [0.1.0] | 2026-02-27 | Initial release |

---

## [0.20.0] - 2026-03-10

### Fixed

- **`validate-impl.sh` E16C bug** — plain-block scanner was incorrectly treating typed block closing fences as plain block openers, causing false positives (typed block content accumulated as plain block). Fixed by tracking `e16c_in_typed_block` state and restructuring fence detection order.

### Added

- **`execution-rules.md` E16A/B/C sub-rules** — replaced inline bold markers with proper `###` sub-headings; documented E16A (required block presence with trigger condition, error format, backward-compat exception), E16B (canonical dep graph grammar with formal spec and example), E16C (out-of-band detection criteria, warning format, rationale, E16A interaction)
- **`saw-skill.md` E16A note** — one-sentence note inserted after "If exit code is 0, proceed to human review" informing orchestrators that validation now enforces required-block presence

---

## [0.19.0] - 2026-03-10

### Fixed

- **`saw-skill.md` — `extract-context` syntax** — was `--impl "<path>" --agent "<id>"` (wrong); correct form is positional arg `"<path>" --agent "<id>"`
- **`saw-skill.md` — `set-completion` syntax** — was heredoc pipe to stdin (not supported); correct form uses individual flags `--agent`, `--status`, `--commit`
- **`saw-skill.md` — stale dual-mode text** — removed "Scout does not yet generate YAML manifests; YAML mode is present for forward compatibility" (Scout has generated YAML since v0.6.0)

### Changed

- **ROADMAP.md** — removed completed "Per-Agent Context Slicing" section; added "Formally Executable IMPL Docs" (constraint-solving validator, auto-derived wave structure, compiled contracts, pre-execution simulation); added "SDK Branch as Generated Build Artifact" (generate `sdk` branch from `main` + substitutions manifest via CI)

---

## [0.16.0] - 2026-03-09

### Added

- **`docs/saw-ops/worktree-isolation-design.md`** — design rationale document explaining why SAW uses explicit `saw create-worktrees` orchestration rather than Claude Code's native `isolation: worktree` agent frontmatter. Covers four reasons: branch naming is load-bearing, pre-validation before parallel work, I1 enforcement at creation time, and protocol chain integrity.
- **`saw-worktree v0.6.1`** — adds one-liner reference to `worktree-isolation-design.md` in the "Why Pre-Creation" section, pointing operators to the full rationale without cluttering the agent prompt.

## [0.15.1] - 2026-03-09

### Changed

- **agents/scout.md** v0.5.0 → v0.6.0 — Output Format section replaced: markdown IMPL doc template → YAML manifest template matching `pkg/protocol/types.go` schema. Agent `task` field now contains Fields 2-7 only; orchestrator wraps with 9-field template via `saw extract-context`. Fixed corrupted duplicate lines in Your Task section. NOT_SUITABLE verdict now writes minimal `.yaml` manifest.
- **scout.md** (fallback) — synced to agents/scout.md v0.6.0 body (minus YAML frontmatter). Was v0.5.0, now matches v0.6.0 canonical content.
- **saw-bootstrap.md** v0.3.4 → v0.4.0 — Output Format section replaced: markdown template → YAML manifest template with bootstrap-specific `project` metadata (language, type, concerns, package_structure). All `IMPL-bootstrap.md` references → `.yaml`. Rules section updated for manifest terminology.
- **scaffold-agent.md** + **agents/scaffold-agent.md** — IMPL doc path examples updated from `.md` to `.yaml`
- **saw-merge.md** — IMPL doc exception glob updated to dual-mode (`.yaml` or `.md`)
- **saw-skill.md** — Scout verdict path updated from `.md` to `.yaml`
- **README.md** — bootstrap entry updated: version v0.4.0, description reflects YAML manifest output

### Summary

This completes the Scout YAML migration: the last piece needed to activate the full SDK CLI pipeline. With scouts generating `.yaml` manifests, the entire flow — `saw validate` → `saw extract-context` → `saw set-completion` → `saw mark-complete` — works end-to-end without any markdown parsing fallbacks.

---

## [0.15.0] - 2026-03-09

### Added

- **Protocol SDK conformance audit** (`docs/IMPL/IMPL-protocol-sdk-conformance.md`) — deep audit comparing protocol spec (I1–I6, E1–E23, SM-01/SM-02, message formats) against Go SDK implementation. Identified 44 gaps across 6 domains. 3-wave remediation plan with 12 agents (A–L) executed via SAW protocol. Post-remediation re-audit: 91% conformance, zero critical gaps remaining.
- **Skill prompts v0.6.0** — all 6 new SDK CLI commands (`saw mark-complete`, `saw run-gates`, `saw check-conflicts`, `saw validate-scaffolds`, `saw freeze-check`, `saw update-agent-prompt`) integrated into YAML-mode orchestrator flow across `saw-skill.md`, `saw-merge.md`, and `saw-worktree.md`. Dual-mode command inventory expanded from 3 to 9 CLI commands.

### Changed

- **saw-skill.md** v0.5.0 → v0.6.0 — E15 completion marker uses `saw mark-complete`; E21 quality gates use `saw run-gates`; E8 interface failure uses `saw update-agent-prompt` + `saw check-conflicts`; worktree setup uses `saw validate-scaffolds` + `saw freeze-check`
- **saw-merge.md** v0.4.6 → v0.5.0 — YAML-mode blocks for quality gates, conflict prediction, and scaffold integrity verification
- **saw-worktree.md** v0.5.0 → v0.5.1 — pre-worktree 3-command verification checklist for YAML manifests

---

## [0.14.8] - 2026-03-08

### Fixed

**E16D: Column order validation hardening**

- **`validate-impl.sh` column order enforcement** — E16 validator now validates that `impl-file-ownership` tables have columns in canonical order: `File | Agent | Wave | ...`. Previously validator only checked that header contained "| File " somewhere, which allowed Scout to write tables with wrong column order (`File | Repo | Agent | ...`). Parser reads by column position (not header name), so wrong order caused silent data corruption at runtime (Repo data appeared in Agent field). New validation extracts first three columns from header row and enforces `File` in col 1, `Agent` in col 2, `Wave` in col 3. Prevents recurrence of IMPL-engine-extraction.md bug where Scout wrote `| File | Repo | Agent | Wave | Depends On |` format that passed validation but broke at runtime.

**Context:** Discovered during multi-repo display debugging in scout-and-wave-web. IMPL-engine-extraction.md had wrong column order that validator didn't catch. This is a pre-validation gap — doc was written before E16 existed, but exposes validator weakness. Hardening prevents future occurrences.

---

## [0.14.7] - 2026-03-08

### Fixed

**Seventh-pass convergence audit — protocol hardening complete**

- **Protocol version number** — `protocol/README.md` still referenced v0.14.5; updated to v0.14.6 to match CHANGELOG current version.

**Convergence achieved:** Seventh-pass audit found only 1 issue (98% reduction from pass 6's 50 findings). Zero P0 protocol-breaking issues. Zero semantic inconsistencies. Zero cross-reference failures. All E1-E23 + E7a execution rules and I1-I6 invariants verified consistent across 26 core files. Protocol is production-ready.

---
## [0.14.6] - 2026-03-08

### Fixed

**Sixth-pass audit — 41 findings from comprehensive protocol consistency review**

- **`{X}` → `{ID}` final cleanup (7 findings)** — `saw-skill.md`, `saw-teams-skill.md`, `agents/scout.md`, `saw-bootstrap.md` all had remaining `{X}` placeholders in SAW tags, merge commit messages, worktree paths, and step descriptions. All replaced with `{ID}` to complete the multi-generation agent ID rollout.
- **`repo:` field missing from completion report templates (3 findings)** — `agent-template.md`, `teammate-template.md`, `wave-agent.md` completion report YAML blocks all omitted the `repo:` field required for cross-repo waves. Added `repo: /absolute/path/to/repo  # omit for single-repo waves` after `failure_type:` in all three templates.
- **E16 validation absent from bootstrap flows (2 findings)** — `saw-skill.md` and `saw-teams-skill.md` bootstrap branches (steps 1–4/1–5) had no E16 IMPL doc validation step between Scout completion and human review. Inserted E16 validation block matching the standard scout flow.
- **Wrong invariant numbers in `participants.md` (2 findings)** — Wave Agent forbidden actions cited "Invariant I2 - disjoint file ownership" (should be I1) and "Invariant I3 - interface freeze" (should be I2). Fixed both.
- **E20/E21 missing from merge procedures (2 findings)** — `saw-merge.md` and `saw-teams-merge.md` had no stub scan (E20) or quality gates (E21) steps. Added Step 1.9 (E20) and Step 1.95 (E21) between file ownership verification and conflict prediction.
- **Wrong agent file paths (2 findings)** — `saw-skill.md` fallback paths referenced `${CLAUDE_SKILL_DIR}/scaffold-agent.md` and `${CLAUDE_SKILL_DIR}/scout.md` but both files live in `agents/` subdirectory. Fixed to `agents/scaffold-agent.md` and `agents/scout.md`.
- **Stale version references (2 findings)** — `DESIGN.md` still said "Synced to protocol v0.6.0" (current: v0.14.5) and file plan listed `saw-teams-merge.md v0.1.2` / `saw-teams-worktree.md v0.1.2` (actual: v0.1.4). `saw-teams-worktree.md` referenced `saw-worktree.md (v0.4.2)` (actual: v0.5.0). All updated.
- **`validate-impl.sh` improvements (3 findings)** — Added note that `failure_type` is conditionally required but not checked (Finding 12). Fixed E16C plain-block fence regex to tolerate trailing whitespace (Finding 28). Changed no-typed-blocks case from `exit 0` to `exit 1` so orchestrator sends it back to Scout for correction (Finding 33).
- **QUICKSTART.md file ownership table wrong headers (1 finding)** — Table used `| File | Owner | Status |` instead of canonical `| File | Agent | Wave | Depends On |`. Fixed headers and example rows.
- **IMPL doc template issues (4 findings)** — `saw-bootstrap.md` had `### Verification Gates` and `### Status` as subsections of Wave 2 instead of top-level `##` sections (Finding 8). `message-formats.md` showed `## Completion Reports` as a wrapper section but E14/procedures say agents append `### Agent {ID}` directly; removed wrapper (Finding 20). Quality Gates example was wrapped in code fence but spec says it's prose YAML; removed fence (Finding 31). `SAW:COMPLETE` marker was in structure template; moved to separate "Completion Marker" subsection after template with E15 note (Finding 38). Pre-Mortem placement description omitted Quality Gates; updated to "after Scaffolds, or after Quality Gates if Scaffolds omitted, or after Suitability Assessment if both omitted" (Finding 44).
- **Layer numbering inconsistencies (2 findings)** — `agent-template.md` used "Layer 1.5" and skipped Layer 3; fixed to match E4's 5-layer model (Layers 0–4) with note that Layers 0 and 2 are orchestrator-side (Finding 40). `teammate-template.md` used saw-teams-specific numbering (Layer 2.5 for messaging); added note that saw-teams omits E4 Layer 2 (`isolation: "worktree"`) and renumbers accordingly (Finding 41).
- **Other structural issues (12 findings)** — Scout "six sections" stale count updated to full section list (Finding 25). `saw-bootstrap.md` Pre-Flight section marked as "Orchestrator Duty" (Finding 27). E17 sequencing note added to bootstrap Step 0 about checking CONTEXT.md after reading requirements (Finding 34). E7a added to `protocol/README.md` execution rules summary (Finding 35). E18 placeholder `{total agent count}` → `{N-agents}` for consistency (Finding 39). `saw-skill.md` IMPL-exists flow had duplicate step 3; renumbered second to step 4 (Finding 42). `agents/scout.md` changed "Agent X" to "Agent {ID} - {Role Description}" (Finding 43).

---

## [0.14.5] - 2026-03-08


**Post-commit verification:** Automated verification audit found 6 additional issues (4 remaining `{X}` in prose, 1 version mismatch, 1 dead code line). All corrected via commit amend. Follow-up fixes: `{X}/{letter}→{ID}` in 5 historical IMPL docs and `saw-ops.md`, `failure_type` comment placement in `agent-template.md`.
### Fixed

**Fifth-pass deep audit — 20 findings across merge procedures, worktree files, hooks, skill files, and bootstrap flow**

- **`{letter}` → `{ID}` final propagation** — `saw-merge.md`, `saw-teams-merge.md`, `saw-worktree.md`, `wave-agent.md` (`### Agent [X]` heading), `hooks.md` (2 occurrences), `DESIGN.md`, `QUICKSTART.md` (worktree path example), `saw-skill.md` (completion report section reference), `saw-teams-skill.md` (completion report section reference) all still used `{letter}` or `[X]` after v0.14.4. All replaced with `{ID}` to complete the `[A-Z][2-9]?` scheme rollout across the full file set.
- **`saw-bootstrap.md`: section order inverted** — Output Format template had `## Interface Contracts` and `## File Ownership` placed before `## Scaffolds`, inverting the canonical IMPL doc section order (Scaffolds → Dependency Graph → Interface Contracts → File Ownership). Moved to canonical position after `## Dependency Graph`.
- **`saw-teams-merge.md`: failure_type/timeout handling absent** — Step 1 (Parse Completion Reports) was missing the `failure_type` decision text and the `timeout` retry-with-scope-reduction rule present in `saw-merge.md` v0.4.6. Added to restore parity.
- **`saw-teams-merge.md`: Step 1.75 File Ownership Verification missing** — `saw-merge.md` v0.4.6 includes a pre-merge ownership verification step (compare each teammate's actual changed files against the File Ownership table, flag I1 violations). This step was entirely absent from the teams merge procedure. Added as Step 1.75.
- **`saw-teams-skill.md`: bootstrap flow missing Scaffold Agent step** — The `bootstrap` branch (steps 1–4) had no Scaffold Agent conditional launch after human review, unlike the standard scout flow (step 5) and the IMPL-exists branch. Added step 5 with `[SAW:scaffold:bootstrap]` tag prefix.
- **`protocol/README.md`: version still at 0.14.0** — Not bumped during v0.14.1–v0.14.4 releases. Updated to 0.14.5.

---

## [0.14.4] - 2026-03-08

### Fixed

- **{letter} → {ID} propagation** — `agent-template.md`, `teammate-template.md`, `procedures.md`, `message-formats.md`, `execution-rules.md` (E23), `saw-teams-worktree.md` all used `{letter}` as the placeholder for agent IDs. v0.14.3 fixed `worktree`/`branch` YAML fields but missed template titles, bash scripts, git commit messages, heading names, and worktree path examples. All occurrences replaced with `{ID}` to support the full `[A-Z][2-9]?` scheme (A, A2, B3, etc.)
- **message-formats.md: Interface Contracts missing from IMPL Doc Structure** — The IMPL Doc Structure section listed Dependency Graph → File Ownership but omitted `## Interface Contracts` between them; added to match scout.md output format and protocol prose
- **procedures.md: E20/E21 absent from Phase 5** — Completion Collection phase (Procedure 3) had no stub scan or quality gates steps; added E20 (stub detection) and E21 (quality gates) as steps 4–5 after all-complete confirmation
- **agents/scout.md: E20/E21 absent from Post-Merge Checklist** — Two checklist items added: stub scan (`scan-stubs.sh`) and quality gates (required gates block merge)
- **agents/scout.md: Step 0 cross-reference** — CONTEXT.md cross-check blockquote referenced "Step 1 of Process"; corrected to "Step 0" to match the `## Step 0: Read Project Memory` heading added in v0.14.3
- **saw-skill.md: CLAUDE_SKILL_DIR fallback missing** — Supporting Files section documented the env var but not the fallback path; added `if unset, fall back to ~/.claude/skills/saw/` note to match saw-teams-skill.md
- **saw-teams-skill.md: E16 relative path** — Validator invocation used `bash scripts/validate-impl.sh`; corrected to `bash "${CLAUDE_SKILL_DIR}/scripts/validate-impl.sh"` (absolute, portable)
- **saw-teams-skill.md: step cross-reference off-by-one** — E16 insertion in v0.14.3 shifted Scaffold Agent to step 5 but the IMPL-exists branch still said "see step 4 of the Scout flow above"; corrected to step 5
- **teammate-template.md: brewprune attribution removed** — Rationale section contained "discovered in brewprune Round 5 Waves 1-2" attribution; removed (private project history, not relevant to users)
- **scan-stubs.sh: usage comment path** — Header comment showed `bash scripts/scan-stubs.sh` (incorrect relative path from repo root); corrected to `bash implementations/claude-code/scripts/scan-stubs.sh`

## [0.14.3] - 2026-03-08

### Fixed

- **hooks: IMPL doc path** — `teammate-idle-saw.sh`, `task-completed-saw.sh`, `hooks.md` all used pre-v0.6.8 `find docs -name "IMPL-*.md"` pattern; updated to `find docs/IMPL -name "IMPL-*.md"` (F3)
- **saw-teams-skill: path resolution** — Replaced hardcoded `SAW_REPO` env var / `~/code/scout-and-wave/` fallback with `${CLAUDE_SKILL_DIR}/` matching saw-skill.md v0.9.0 approach for `scout.md`, `scaffold-agent.md`, `saw-bootstrap.md`, `saw-teams-merge.md` references (F17)
- **saw-teams-skill: bootstrap I6 violation** — Step 3 instructed Orchestrator to "design the package structure and interface contracts" directly; replaced with Scout agent delegation (F18)
- **saw-teams-skill: E16 validation** — Added IMPL doc validation step between Scout completion and human review, matching saw-skill.md (F15)
- **saw-teams-skill: E20 stub scan** — `${SAW_SKILL_DIR}` corrected to `${CLAUDE_SKILL_DIR}` (F4)
- **saw-teams-skill: E15/E18 post-final-wave** — Added IMPL doc completion marker (E15) and project memory update (E18) steps after final wave merge; were present in saw-skill.md but absent here (F25)
- **saw-teams-skill: merge file reference** — Updated `saw-teams/saw-teams-merge.md` to `${CLAUDE_SKILL_DIR}/saw-teams-merge.md`
- **agents/scaffold-agent.md: E22 two-pass build** — Added explicit Pass 1 (scaffold package only) before Pass 2 (full project build) to match `prompts/scaffold-agent.md` and `execution-rules.md` E22 spec (F2)
- **agents/scaffold-agent.md: version marker** — Bumped `v0.1.1` → `v0.1.2` (F19)
- **prompts/scaffold-agent.md: heading levels** — `### Scaffolds` and `### Interface Contracts` corrected to `## Scaffolds` and `## Interface Contracts` to match canonical IMPL doc heading levels (F9)
- **execution-rules.md: E22 cross-references footer** — Removed stale `E5` reference; corrected short path `agents/scaffold-agent.md` to full path `implementations/claude-code/prompts/agents/scaffold-agent.md`; added `procedures.md (Procedure 2)` (F1)
- **agents/scout.md: Step 0 E17 block** — Added standalone `## Step 0: Read Project Memory (E17)` section before Suitability Gate, matching `prompts/scout.md` v0.5.0 structure (F5)
- **prompts/scout.md: CONTEXT.md cross-check** — Added `> CONTEXT.md cross-check` blockquote to suitability gate step 4 matching the equivalent already present in `agents/scout.md` (F6)
- **saw-skill.md: solo agent check** — Added step 2 solo agent check (1-agent wave → skip worktrees, launch directly) before worktree setup step, matching saw-teams-skill.md (F7)
- **saw-bootstrap.md: Known Issues section** — Added `## Known Issues` template section between Pre-Mortem and Dependency Graph to match canonical IMPL doc structure (F8)
- **scout.md: Orchestrator Post-Merge Checklist** — Added explicit E20 stub scan and E21 quality gates checkboxes; bootstrap template already had them but scout-generated IMPL docs did not (F12)
- **procedures.md: E18 architecture field** — Clarified "update architecture" to "update `architecture.description` and `architecture.modules` list" with schema cross-reference (F14)
- **message-formats.md: Quality Gates validator exclusion** — Added "Quality Gates" to prose-sections exclusion list; it uses free-form YAML, not a typed block (F13)
- **protocol/README.md: procedures.md description** — Updated from merge-only description to full scope: Scout, Scaffold Agent, wave execution, merge, checkpoint, completion (F21)
- **agent-template.md: Scaffold Agent attribution** — Corrected "Scout produces type scaffold files" to "Scaffold Agent creates shared type scaffold files (specified by the Scout)" (F23)
- **agents/wave-agent.md: field numbering** — Updated "Your Task" spec from 1-indexed custom field names to canonical Field 0–8 numbering matching agent-template.md (F24)
- **teammate-template.md: worktree field** — `{letter}` placeholder corrected to `{ID}` in worktree field of completion report template (F16)

---

## [0.14.2] - 2026-03-08

### Fixed

**Second-pass deep audit — saw-teams layer parity and bootstrap completeness**

- **`saw-teams/teammate-template.md` completion report** — block was using bare `` ```yaml `` fence; changed to `` ```yaml type=impl-completion-report `` so the lead can machine-parse it. Added missing `failure_type` and `branch` fields. Moved `### Agent {letter} - Completion Report` heading outside the fence (was incorrectly embedded inside the YAML block).
- **`saw-teams-skill.md` step 3c — E23 payload construction** — spawn context previously passed the raw agent section only; now explicitly extracts the 6 E23 fields (agent section, Interface Contracts, File Ownership, Scaffolds, Quality Gates, absolute IMPL doc path header). Teams layer now matches standard SAW E23 behavior.
- **`saw-teams-skill.md` IMPL doc paths** — all five references used pre-v0.6.8 path format `docs/IMPL-*.md`; updated to `docs/IMPL/IMPL-*.md` throughout.
- **`saw-teams-skill.md` step 5 — missing E19/E20/E21/E7a** — added failure_type decision tree (E19), stub scan (E20), quality gate verification (E21), and automatic failure remediation in --auto mode (E7a). Teams orchestrator now has full parity with standard SAW step 4.
- **`saw-bootstrap.md` — E17 missing** — added "Step 0: Read Project Memory (E17)" before Phase 0. Bootstrap scouts now check `docs/CONTEXT.md` to avoid contradicting prior architectural decisions.
- **`saw-bootstrap.md` — E16 validation feedback missing** — added note to Rules section: after writing the IMPL doc, expect validator correction prompts; rewrite only failing sections.
- **`saw-bootstrap.md` — Wave Execution Loop and Orchestrator Post-Merge Checklist missing** — added both sections to the Output Format template. Bootstrap IMPL docs now include the post-merge checklist (E20 stub scan, E21 quality gates, merge, verification, commit steps) that multi-wave projects require.
- **`protocol/execution-rules.md` E22 cross-ref** — `agents/scaffold-agent.md` (ambiguous relative path) corrected to full path `implementations/claude-code/prompts/agents/scaffold-agent.md`.
- **`saw-teams-merge.md` attribution** — updated from v0.4.4 to v0.4.6 to match current `saw-merge.md`.
- **`implementations/claude-code/prompts/scaffold-agent.md` Step 3** — E22-noncompliant: was performing two-pass compile only. Added Step 3a dependency resolution (`go get ./...` + `go mod tidy`, `cargo fetch`, `npm install`, `pip install -e .`) before the build passes, matching the three-step order required by E22.
- **`implementations/claude-code/prompts/agent-template.md`** — removed project-specific history note "(discovered in brewprune Round 5 Waves 1-2; refined in protocol extraction dogfooding 2026-03-06)" from the Field 0 rationale. Replaced with generic description.

---

## [0.14.1] - 2026-03-08

### Fixed

**First-pass deep audit — E-rule range propagation and doc consistency**

- **E-rule range E1–E22 → E1–E23** in seven files that weren't updated when E23 was added in v0.14.0: `saw-skill.md`, `agent-template.md`, `wave-agent.md`, `prompts/scaffold-agent.md`, `docs/ECOSYSTEM.md`, `saw-teams/teammate-template.md`, `saw-teams/saw-teams-skill.md`.
- **E20–E22 → E20–E23** (orchestrator-only rule annotation) + "per-agent context extraction" description added in: `wave-agent.md`, `agent-template.md`, `teammate-template.md`.
- **`wave-agent.md` `failure_type`** — `timeout` value was missing from the completion report template enum; added alongside `transient | fixable | needs_replan | escalate`.
- **`scout.md` version marker** — was still `v0.4.0`; updated to `v0.5.0` (E17 content was added in v0.12.0 but version comment not bumped).
- **`saw-skill.md` step 3 wave launch** — described passing "the agent prompt from the IMPL doc" (raw section); updated to describe E23 payload construction with all 6 fields. Corrects the inconsistency between the spec and the orchestrator's instruction.
- **`scout.md` Output Format template** — `## Quality Gates` section was absent from the IMPL doc template; added between Suitability Assessment and Scaffolds, matching `message-formats.md` canonical section order. Scout following the template literally would have placed Quality Gates in the wrong position or omitted it.
- **`protocol/procedures.md` E18 cross-reference** — pointed to `execution-rules.md` for the full CONTEXT.md schema; schema actually lives in `message-formats.md` (## docs/CONTEXT.md — Project Memory section). Cross-reference corrected.
- **`protocol/execution-rules.md` E22** — Related Rules contained "E5 (scaffold agent gate)"; E5 is Worktree Naming Convention, not a scaffold gate. Replaced with correct reference to `procedures.md` (Procedure 2: Scaffold Agent).
- **`scout.md` fallback (prompts/)** — E17 "Step 0: Read Project Memory" was missing. The `agents/scout.md` custom type had it; the fallback prompt used when the custom type fails to load did not. Added equivalent Step 0 section.

---

## [0.14.0] - 2026-03-08

### Added
- **E23 — Per-Agent Context Extraction:** Orchestrator constructs a trimmed per-agent context payload for each wave agent instead of passing the full IMPL doc. Payload contains only: (1) that agent's 9-field prompt section, (2) Interface Contracts, (3) File Ownership table, (4) Scaffolds, (5) Quality Gates, (6) absolute IMPL doc path. Eliminates O(N²) token waste where N agents each consumed N-1 other agents' full prompts.
- **Per-Agent Context Payload schema** in `protocol/message-formats.md` — defines exactly which sections are included/excluded in each agent's launch context payload, the payload format (markdown with `<!-- IMPL doc: {path} -->` header), and the fallback behavior when extraction fails.
- **E23 in `protocol/execution-rules.md`** — trigger: Orchestrator is about to launch a Wave agent. Required action: extract and format per-agent context payload; pass as agent prompt parameter rather than raw IMPL doc contents.
- **E23 in `protocol/procedures.md`** — Phase 3 Agent Launch step updated: "Construct per-agent context payload (E23)" replaces "Pass absolute IMPL doc path / Agent reads 9-field prompt from IMPL doc".
- **`agent-template.md` updated** — intro clarifies that agents receive a trimmed E23 payload, not the full IMPL doc; all required context is included in the prompt.
- **`saw-skill.md` updated** — orchestrator wave launch step updated to describe E23 extraction before passing prompt to each agent.
- **`wave-agent.md` updated** — "Your Task" section describes per-agent context payload (E23).
- **Roadmap:** "Per-Agent Context Slicing for Large IMPL Docs", "Contract Builder Phase", "Tier 2 Merge Conflict Resolution Agent" entries added.

### Changed
- Protocol version: 0.13.0 → 0.14.0 across all protocol files.
- README badge: 0.13.0 → 0.14.0; E-rule description updated to E1–E23.

---

## [0.13.0] - 2026-03-08

### Added
- **E20 — Stub Detection Post-Wave:** Orchestrator runs `scan-stubs.sh` against all files touched by wave agents after wave completes; writes `## Stub Report — Wave {N}` section to IMPL doc. Stub patterns: `TODO`, `FIXME`, `pass`, `...`, `NotImplementedError`, `raise NotImplementedError`, `throw new Error("not implemented")`, `unimplemented!()`, `todo!()`, `panic("not implemented")`.
- **E21 — Automated Post-Wave Verification:** IMPL doc `## Quality Gates` section defines gates (typecheck, test, lint, custom). Orchestrator runs configured gates after stub scan; required gates failing block merge, optional gates warn only. Level field (`quick`/`standard`/`full`) controls which gates run.
- **E22 — Scaffold Build Verification:** Scaffold Agent runs `go mod tidy` + `go build ./...` (or equivalent) after creating scaffold files. Build failure sets scaffold status to `FAILED` and blocks wave launch.
- `## Stub Report Section Format` and `## Quality Gates Section Format` schemas in `protocol/message-formats.md`.
- Scout emits `## Quality Gates` section with auto-detected gate config (`go.mod` → `go test ./...`, `package.json` → `npm test`, `Cargo.toml` → `cargo test`, `pyproject.toml` → `pytest`).
- Scaffold Agent build verification step wired into scaffold commit procedure.
- `saw-skill.md` orchestrator wiring: E20 stub scan and E21 gate run between wave completion and human review.

---

## [0.12.0] - 2026-03-08

### Added

- **E17: Scout reads project memory** — before running the suitability gate, Scout checks for `docs/CONTEXT.md` in the target project. If present, reads it in full: `established_interfaces` prevents proposing types that already exist, `decisions` prevents contradicting prior architectural choices, `conventions` enforces project style, `features_completed` informs history.
- **E18: Orchestrator updates project memory** — after a feature's final wave post-merge verification passes (same trigger as E15), Orchestrator creates or updates `docs/CONTEXT.md`: appends to `features_completed`, `decisions`, and `established_interfaces`. File is optional; created on first completion.
- **E19: Failure type decision tree** — agents reporting `status: partial` or `status: blocked` now include `failure_type: transient | fixable | needs_replan | escalate`. Orchestrator action per type: `transient` → retry automatically (up to 2×); `fixable` → apply agent's noted fix, relaunch; `needs_replan` → re-engage Scout with agent findings; `escalate` → surface to human immediately. Backward compat: absent `failure_type` treated as `escalate`.
- **`docs/CONTEXT.md` schema** in `protocol/message-formats.md` — canonical YAML schema for the project memory file with field documentation.
- **`failure_type` field** in completion report schema (`message-formats.md`), `wave-agent.md`, and `agent-template.md` (v0.3.9). Conditionality: required when `status: partial | blocked`, omitted when `status: complete`.
- **Scout prompt updated** (`scout.md` v0.5.0) — CONTEXT.md reading inserted as new Step 1; existing steps renumbered 2–11; CONTEXT.md cross-check added to suitability gate.
- **Orchestrator files updated** — `saw-skill.md`, `saw-merge.md`, `procedures.md` all reference `failure_type` and E19 decision tree.

---

## [0.11.2] - 2026-03-08

### Fixed

- **`validate-impl.sh` path in `saw-skill.md`** — the E16 validation step referenced `bash scripts/validate-impl.sh` (relative path, only worked from specific directories). Changed to the absolute symlink path `bash /Users/dayna.blackwell/.claude/skills/saw/scripts/validate-impl.sh`, which resolves correctly from any project directory. The symlink at `~/.claude/skills/saw/scripts/validate-impl.sh` already pointed to the correct script; only the prompt path was wrong.

---

## [0.11.1] - 2026-03-08

### Changed

- **Roadmap: engine extraction complete** — `scout-and-wave-go` is the standalone engine module; `scout-and-wave-web` is the web UI client. Implementation Notes updated to reflect this. "Partially implemented" section repo name corrected from `scout-and-wave-go` to `scout-and-wave-web`.
- **Roadmap: Protocol Hardening section added** — Four hardening items surfaced during the engine extraction cross-repo wave:
  1. **Scaffold Agent build verification** — Scaffold Agent must run `go get ./...`, `go mod tidy`, and `go build ./...` after creating stubs; reports `FAILED` if any step fails before committing.
  2. **Cross-repo Field 8 absolute path** — `saw-worktree.md` and `wave-agent.md` must document that cross-repo agents require an absolute IMPL doc path in the prompt.
  3. **BUILD STUB test discipline** — Agents must report `status: partial` (not `complete`) when functions are BUILD STUBs; completion report must list each stub explicitly.
  4. **`go.work` for cross-repo LSP** — Recommendation to add `go.work` workspace file to reduce LSP noise in cross-repo worktrees.

---

## [0.11.0] - 2026-03-08

### Added

- **Cross-repo wave support** (`saw-worktree.md`): New "Cross-Repo Mode" section covering multi-repo preflight, per-repo worktree creation, hook installation, merge, and cleanup. Agents in different repositories work simultaneously within a single wave.
- **`Repo` column in `impl-file-ownership`** (`message-formats.md`): Cross-repo IMPL docs include a `Repo` column identifying which repository each file belongs to. Single-repo format unchanged.
- **`Repositories:` frontmatter field** (`message-formats.md`): IMPL docs for cross-repo waves list all repository paths in the frontmatter.
- **`repo` field in completion report** (`message-formats.md`): Cross-repo agents include the absolute repo path in their structured completion report. Optional for single-repo waves.

### Changed

- **E3 ownership verification** (`execution-rules.md`): Disjointness check is now per-repo; same filename in different repositories is not a conflict. Cross-repo tables must include `Repo` column.
- **E4 Layer 2 documentation** (`execution-rules.md`): Cross-repo omission of `isolation: "worktree"` is now described as intentional correct protocol, not a degraded fallback.
- **I1 disjoint ownership** (`invariants.md`): Added cross-repo scope note — I1 applies per-repository; files in different repos are inherently disjoint.
- **Orchestrator participant** (`participants.md`): "Cross-repository orchestration limitation" section replaced with "Cross-repository orchestration" describing both single-repo and cross-repo modes.
- **Procedure 3, Phase 1, Step 2** (`procedures.md`): Repository context check now describes cross-repo mode procedure instead of treating it as an error.
- **Merge procedure** (`procedures.md`): Cross-repo note added — merge runs independently per-repo.
- **Recovery from Cross-Repository Mismatch** (`procedures.md`): Now describes recovery from accidental Layer 2 use in cross-repo context, not treatment of cross-repo as an unrecoverable error.
- Protocol document versions bumped to 0.9.0 (`procedures.md`, `execution-rules.md`, `invariants.md`, `message-formats.md`).
- `saw-worktree.md` bumped to v0.5.0.

---

## [0.10.4] - 2026-03-07

### Fixed

- **`agents/scout.md` output format heading levels** — top-level IMPL doc sections used `###` instead of `##`; flat `### Agent Prompts` replaced with correct per-wave `## Wave N` / `### Agent X - {Role}` structure. A scout using the custom-type agent would have produced malformed IMPL docs.
- **`agent-template.md` isolation layer label** — "Layer 3" applied to the merge-time orchestrator trip wire; corrected to "Layer 4" matching E4's canonical 5-layer model.
- **`README.md` P4 suitability description** — "Doesn't require pre-implementation scanning" inverted the meaning of P4; corrected to "Has been pre-scanned for already-implemented items."
- **`protocol/README.md` invariant examples** — listed "worktree isolation" and "interface freeze" as invariant examples; neither is an invariant (they are E4 and E2). Replaced with accurate examples from I1–I6.
- **`implementations/claude-code/QUICKSTART.md` scaffold table** — used a non-canonical 3-column format; replaced with the canonical 4-column `| File | Contents | Import path | Status |` from `protocol/message-formats.md`.
- **`agents/scout.md` Step 8** — missing explicit `## Wave N` headers requirement; added to match the fallback `prompts/scout.md`.

---

## [0.10.3] - 2026-03-07

### Fixed

- **I1/I2 invariant labels swapped** across four files (`README.md`, `protocol/README.md`, `implementations/README.md`, `implementations/claude-code/README.md`). Every occurrence said "I1: worktree isolation" — corrected to "I1: Disjoint File Ownership" and "I2: Interface Contracts Precede Parallel Implementation." A broken anchor `#i1-worktree-isolation` in `claude-code/README.md` was also fixed.
- **Dead `PROTOCOL.md` references** in `saw-skill.md` and `docs/ECOSYSTEM.md` — `PROTOCOL.md` was removed in v0.9.1; references updated to `protocol/invariants.md` and `protocol/execution-rules.md`.
- **`agent-template.md` completion report fence** — plain `` ```yaml `` → `` ```yaml type=impl-completion-report `` so the orchestrator can locate completion reports by type annotation.
- **Stale version table** in `implementations/claude-code/prompts/README.md` — six version numbers and the install path (`~/.claude/commands/saw.md` → `~/.claude/skills/saw/SKILL.md`) corrected.
- **QUICKSTART IMPL doc path** — two occurrences of `docs/IMPL-simple-cache.md` corrected to `docs/IMPL/IMPL-simple-cache.md`.
- **`protocol/README.md` version** — still showed `0.8.0`; updated to `0.10.2`.
- **`ECOSYSTEM.md` Further Reading link** — pointed to removed `PROTOCOL.md`; updated to `protocol/README.md`.
- **Scout agent E16A awareness** — `agents/scout.md` step 10 now explicitly states that omitting any of the three required typed blocks is itself a validator failure, not just something to fix reactively.

### Changed

- **`ROADMAP.md`** — completed items removed (Pre-Mortem, IMPL doc completion lifecycle, validation+correction loop, structured metadata blocks, E16 validator script); `saw serve` entry updated to reflect what's shipped vs what remains.

---

## [0.10.2] - 2026-03-07

### Added

- **E16A: required block presence enforcement.** Both `validate-impl.sh` and `ValidateIMPLDoc` (Go) now require `impl-file-ownership`, `impl-dep-graph`, and `impl-wave-structure` blocks to be present whenever any typed block appears in the doc. Only fires when `block_count > 0`, so pre-v0.10.0 docs without typed blocks are unaffected. Missing blocks are reported as distinct errors (one per missing type).

- **E16C: out-of-band dep graph detection.** A second scan pass checks all plain fenced blocks (no `type=` annotation) for content matching the dep graph pattern (`[A-Z]` agent refs + the word `Wave`). When found, a `WARNING` is emitted to stdout but does not cause exit 1. The Orchestrator E16 step now includes E16C warnings in the Scout correction prompt so that dep graph content inadvertently placed in a prose block gets moved into a typed `impl-dep-graph` block.

### Changed

- **`protocol/execution-rules.md`** — E16 "Validator scope" section updated with canonical E16A/B/C sub-rule documentation, including dep graph grammar (Wave N section header + indented `[X]` entries + `✓ root` or `depends on:` annotations).
- **`implementations/claude-code/prompts/saw-skill.md`** — E16 step now includes an E16A note explaining the required-block enforcement and E16C warning handling.

---

## [0.10.1] - 2026-03-07

### Added

- **E16 validator script (`implementations/claude-code/scripts/validate-impl.sh`).** Deterministic bash script that validates all `type=impl-*` typed blocks in an IMPL doc. Checks `impl-file-ownership` (header row, data rows, column count), `impl-dep-graph` (Wave headers, agent lines, root/depends-on annotations), `impl-wave-structure` (Wave lines, agent letters), and `impl-completion-report` (required fields, valid status values). Exits 0 on pass, 1 on failure with plain-text error list suitable for direct use as a Scout correction prompt. Per the Agent Skills cross-platform spec — deterministic logic in `scripts/`, LLM reasoning in skill instructions.

### Changed

- **`implementations/claude-code/prompts/saw-skill.md`** — E16 step updated from prose description to concrete script call: `bash scripts/validate-impl.sh "<impl-doc-path>"`. Orchestrator reads exit code and stdout; on failure, sends error output directly to Scout as correction prompt.

---

## [0.10.0] - 2026-03-07

### Added

- **Typed metadata blocks (`type=impl-*`).** Machine-parsed sections of the IMPL doc now use typed fenced code blocks with a `type=impl-*` annotation on the opening fence. Four block types defined: `impl-file-ownership`, `impl-dep-graph`, `impl-wave-structure`, `impl-completion-report`. Prose sections remain free-form. Defined in `protocol/message-formats.md`.

- **E16: Scout Output Validation.** New execution rule requiring the Orchestrator to run a deterministic validator on all `type=impl-*` typed-block sections after the Scout writes the IMPL doc, before human review. On validation failure, the Orchestrator issues a correction prompt to the Scout listing specific errors by block type and location. Scout rewrites only the failing sections. Loop continues up to 3 attempts; on exhaustion, enters BLOCKED. Added to `protocol/execution-rules.md`.

- **SCOUT_VALIDATING state.** New protocol state interposed between SCOUT_PENDING and REVIEWED. Covers the validation + correction loop lifecycle: self-loop on correction, transitions to REVIEWED on pass or BLOCKED on retry exhaustion. Added to `protocol/state-machine.md` (catalog, flow diagram, failure paths, transition guards, entry actions).

- **Pre-Mortem section.** New required Scout output section (`## Pre-Mortem`) written before the human review checkpoint. Contains an overall risk rating (low/medium/high) and a failure modes table (Scenario / Likelihood / Impact / Mitigation). Forces adversarial thinking before human approval. Schema defined in `protocol/message-formats.md`; output template added to both scout prompt files.

### Changed

- **`protocol/participants.md`** — Orchestrator Responsibilities section updated: E16 validation responsibility and required capability ("Run IMPL doc validator on typed-block sections") added.

- **`implementations/claude-code/prompts/saw-skill.md`** — E16 correction loop step added to the scout flow (between IMPL doc read and human review); step numbering updated; E-rule range updated to E1–E16.

- **`implementations/claude-code/prompts/agents/scout.md`** and **`implementations/claude-code/prompts/scout.md`** — Output format template updated: dep graph, file ownership, and wave structure sections now use `type=impl-*` fence annotations. Pre-Mortem section template added. E16 correction-loop awareness note added as Step 10.

- **`implementations/claude-code/prompts/agents/wave-agent.md`** — Completion report template updated to use `type=impl-completion-report` opening fence; YAML fields aligned with `message-formats.md` schema.

- **`protocol/procedures.md`** — Procedure 1 (Scout) exit state updated from REVIEWED to SCOUT_VALIDATING; Orchestrator Actions section updated with validation loop steps.

---

## [0.9.5] - 2026-03-07

### Changed

- **Scout dep graph format prescribed.** Both `agents/scout.md` and `prompts/scout.md` now specify an exact structured format for the `### Dependency Graph` section — a fenced code block with `Wave N (...):` headers, `[A] description` agent lines, and `depends on: [X]` dependency annotations. Previously the section was free-form prose, which caused the SAW web UI dep graph panel to fall back to raw `<pre>` text rendering.

## [0.9.4] - 2026-03-07

### Added

- **E15: IMPL Doc Completion Marker** — new execution rule. After the final wave's post-merge verification passes, the orchestrator writes `<!-- SAW:COMPLETE YYYY-MM-DD -->` to the IMPL doc. HTML comment tag: invisible in rendered markdown, parseable with one regex, greppable across a directory.
  - `protocol/execution-rules.md`: E15 definition with trigger, required action, constraints
  - `protocol/message-formats.md`: IMPL doc schema updated with `<!-- SAW:COMPLETE -->` tag
  - `protocol/state-machine.md`: COMPLETE entry action, WAVE_VERIFIED->COMPLETE guard, terminal state description all reference E15
  - `protocol/README.md`: execution rule count updated to E1-E15
  - Orchestrator skill (`saw-skill.md`): step 6 writes completion marker after final wave
  - All active prompt files updated from E1-E14 to E1-E15

### Changed

- **Scout output format requires `## Wave N` headers.** Agent prompts must be organized under `## Wave 1`, `## Wave 2`, etc. — not grouped under a flat `## Agent Prompts` section. The parser and web UI use these headers to determine wave grouping. (scout.md steps 7-8, output format template)
- ROADMAP.md: IMPL completion lifecycle marked as implemented (v0.9.4); remaining work noted (Go engine parser, API, web UI picker)

### Fixed

- **Documentation audit** (new user experience): install script created, dead `PROTOCOL.md` link in QUICKSTART.md fixed, Agent Skills badge explained, jargon defined on first use (IMPL doc, waves, scaffolds, I1-I6), "Ways to Use SAW" section bridging two repos added to README

---

## [0.9.3] - 2026-03-06

### Removed

- **`templates/` directory** (`templates/agent-prompt-template.md`, `templates/impl-doc-template.md`): Fillable templates created for the manual implementation are no longer needed — the Scout generates IMPL docs automatically and stamps agent prompts directly into them. Schemas are now covered by `protocol/message-formats.md`. Active references in `README.md` and `implementations/README.md` updated to point to `protocol/message-formats.md`.
- **`implementations/manual/`**: Human-executable orchestration guides removed — protocol is now Claude Code only. Choosing table and examples block removed from `implementations/README.md`.

### Changed

- **`IMPL-SCHEMA.md` merged into `protocol/message-formats.md`**: Standalone schema doc at repo root had no discoverable path from agent prompts. Unique content (size guidance, orchestrator parsing requirements) merged into `protocol/message-formats.md`. `IMPL-SCHEMA.md` deleted. Scout's output format section now references `protocol/message-formats.md`.

---

## [0.9.2] - 2026-03-06

### Fixed

- **`branch:` field missing from completion reports** (`agent-template.md`): Agents were not emitting `branch: wave{N}-agent-{letter}` in their YAML completion reports, despite it being specified in `protocol/message-formats.md`. Field added to agent-template.md schema.
- **Stale `PROTOCOL.md` reference** (`agent-template.md`): Line 16 referenced deleted `PROTOCOL.md` as the source for I{N}/E{N} notation. Updated to reference `protocol/invariants.md` and `protocol/execution-rules.md`.
- **IMPL doc heading level drift** (`scout.md`): Output format template used `###` (h3) for all top-level IMPL doc sections. Schema specifies `##` (h2). Corrected all 11 section headings in scout's output template.
- **`IMPL-SCHEMA.md` merged into `protocol/message-formats.md`**: Standalone schema doc at repo root had no discoverable path from agent prompts. Unique content (size guidance, orchestrator parsing requirements) merged into `protocol/message-formats.md`; `IMPL-SCHEMA.md` deleted. Scout's output format section now references `protocol/message-formats.md`.

---

## [0.9.1] - 2026-03-06

### Added

- **Agent Skills badge** (`README.md`, `assets/badge-agentskills.svg`): Visual indicator of open standard compliance; badge asset moved to `assets/` directory
- **Dual license** (`LICENSE`, `LICENSE-MIT`, `LICENSE-APACHE`): Project now licensed under MIT OR Apache-2.0 at user's choice; `license` field in `saw-skill.md` frontmatter updated to `MIT OR Apache-2.0`
- **Open standard positioning** (`README.md`): Added note identifying SAW as an Agent Skills open standard implementation compatible with Claude Code, Cursor, GitHub Copilot, and other tools; quickstart callout clarifies Claude Code syntax is implementation-specific

### Removed

- **`PROTOCOL.md`** (root-level consolidated spec): Removed — `protocol/` directory is the authoritative source; all internal cross-references updated to link directly to the relevant `protocol/*.md` files
- **Stale analysis and working docs** (`docs/`): Deleted `saw-skill-enhancement-analysis.md`, `saw-type-scaffold-proposal.md`, `scaffold-agent-rationale.md`, `NOTES-pattern-improvements.md`, `IMPL-FIXES-APPLIED.md`, `IMPL-FIXES-refactor-protocol-extraction.md`

### Changed

- **GitHub repository description**: Updated to reflect open standard positioning (removed "Reference implementation: /saw skill for Claude Code")
- **Protocol cross-references**: All `See PROTOCOL.md §...` references in `protocol/*.md` and `implementations/` updated to link to specific protocol files

---

## [0.9.0] - 2026-03-06

### Changed

- **Claude Code Implementation: Skills API Migration** (`implementations/claude-code/prompts/saw-skill.md`, v0.5.0):
  - **YAML frontmatter added:** Structured metadata including `name`, `description`, `argument-hint`, `allowed-tools`, `version`
  - **Portable path references:** Replaced hardcoded paths (`~/code/scout-and-wave/prompts/`) and `SAW_REPO` environment variable fallback with `${CLAUDE_SKILL_DIR}/filename.md` references
  - **Tool restrictions:** `allowed-tools` frontmatter field prevents orchestrator from performing agent duties (e.g., cannot use `Edit` on source files, enforcing I6 role separation)
  - **Supporting files documentation:** Added "Supporting Files" section listing all 7 files co-located in skill directory
  - **Invocation modes table:** Quick reference for all `/saw` commands with purpose column

- **Installation Method Updated** (`implementations/claude-code/README.md`):
  - **Target directory:** Changed from `~/.claude/commands/saw.md` to `~/.claude/skills/saw/SKILL.md`
  - **Supporting files:** All supporting files now symlinked into skill directory (7 files total: `saw-bootstrap.md`, `saw-merge.md`, `saw-worktree.md`, `agent-template.md`, `scout.md`, `scaffold-agent.md`, plus 3 agent types in `agents/` subdirectory)
  - **Symlink-based:** Maintains single source of truth in `implementations/claude-code/prompts/`, git pull updates skill automatically
  - **No environment variables:** Removed `SAW_REPO` requirement entirely

### Added

- **Enhanced autocomplete:** `argument-hint` field provides inline documentation: `[bootstrap <project-name> | scout <feature> | wave [--auto] | status]`
- **Skills API compliance:** Follows [Agent Skills](https://agentskills.io) open standard with Claude Code extensions
- **Documentation:** Three analysis documents in `docs/`:
  - `saw-skill-enhancement-analysis.md` - Comprehensive enhancement analysis with prioritized recommendations
  - `symlink-structure-analysis.md` - Current state, migration strategy, benefits comparison
  - `symlink-diagram-v2.md` - Visual diagrams of symlink structure before/after

### Benefits

- **Portability:** Works regardless of where scout-and-wave repository is cloned (no hardcoded paths)
- **Simplicity:** Single path resolution strategy (`${CLAUDE_SKILL_DIR}`) replaces 3-strategy fallback logic
- **Safety:** Tool restrictions prevent protocol violations (orchestrator cannot accidentally perform agent work)
- **Discoverability:** All supporting files visible in skill directory structure
- **Standards compliance:** Full Skills API features (frontmatter, tool restrictions, hooks support)

### Backward Compatibility

- **Source location unchanged:** All actual files remain in `implementations/claude-code/prompts/` (single source of truth preserved)
- **Symlink pattern preserved:** Same installation approach (symlinks), just to different target directory
- **Agent behavior unchanged:** Functional equivalence maintained; only installation and path resolution changed

### Migration

Users must migrate their installation to use the new skills directory:

```bash
# Remove old command
rm ~/.claude/commands/saw.md

# Create new skill directory structure
mkdir -p ~/.claude/skills/saw/agents

# Symlink all files (see README.md Step 3 for full commands)
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/skills/saw/SKILL.md
# ... (7 total files to symlink)
```

Restart Claude Code after migration. Test with `/saw status`.

**Net change:** +58 lines added to saw-skill.md (frontmatter + documentation), -3 lines removed (path logic simplified)

## [0.8.0] - 2026-03-06

### Changed

- **Protocol Extraction:** Refactored monolithic PROTOCOL.md (590 lines) into structured protocol/ directory with 8 implementation-agnostic specification files (1,755 lines total):
  - `protocol/README.md` - Navigation and adoption guide
  - `protocol/participants.md` - Orchestrator, Scout, Scaffold Agent, Wave Agent definitions
  - `protocol/preconditions.md` - P1-P5 suitability gate criteria
  - `protocol/invariants.md` - I1-I6 hard constraints
  - `protocol/execution-rules.md` - E1-E14 state transition rules
  - `protocol/state-machine.md` - Lifecycle states and transitions
  - `protocol/message-formats.md` - IMPL doc structure, completion reports
  - `protocol/procedures.md` - Scout, Wave, Merge operational procedures

- **PROTOCOL.md Refactored:** Reduced from 590 to 239 lines (59% reduction), now serves as navigation hub with quick reference tables for I1-I6 and E1-E14, linking to protocol/ for detailed specifications

- **Implementations Layer:** Reorganized Claude Code-specific files into `implementations/claude-code/` directory:
  - Moved `prompts/` → `implementations/claude-code/prompts/` (14 files)
  - Moved `examples/` → `implementations/claude-code/examples/`
  - Moved `hooks/` → `implementations/claude-code/hooks/`
  - Moved `docs/QUICKSTART.md` → `implementations/claude-code/QUICKSTART.md`
  - Created backward compatibility symlinks (`prompts`, `examples`, `hooks`) to maintain existing user workflows
  - Created `implementations/claude-code/README.md` with installation and usage instructions

- **README.md Restructured:** Root README transformed from Claude Code manual to protocol navigation hub:
  - Condensed Why/How sections while preserving key concepts
  - Added Protocol Documentation section linking to protocol/README.md
  - Added Implementations section linking to implementations/README.md
  - Moved installation instructions to implementations/claude-code/README.md
  - Updated Quick Start with new file paths (backward compatible via symlinks)

### Added

- **Manual Orchestration Guides** (`implementations/manual/`): Complete guide for humans orchestrating SAW without AI runtime (2,102 lines):
  - `README.md` - When to orchestrate manually, prerequisites, workflow overview
  - `scout-guide.md` - Manual codebase analysis, suitability assessment, IMPL doc creation (612 lines)
  - `wave-guide.md` - Team coordination using worktrees, parallel work management (472 lines)
  - `merge-guide.md` - Step-by-step merge procedure with conflict resolution (609 lines)
  - `checklist.md` - Printable checkbox format for Scout → Wave → Merge phases (239 lines)

- **IMPL-SCHEMA.md** (608 lines): Canonical IMPL doc structure specification documenting all 11 required sections with purpose, format, required fields, constraints, and examples

- **Generic Templates** (`templates/`): Implementation-agnostic starter templates (480 lines):
  - `agent-prompt-template.md` - 9-field agent prompt structure with placeholder variables
  - `impl-doc-template.md` - IMPL doc scaffold with frontmatter, scaffolds, wave structure

- **Implementations README** (`implementations/README.md`): Comparison table between Claude Code and manual orchestration with implementation chooser guidance

### Backward Compatibility

- All file moves preserve git history (100% rename similarity)
- Symlinks at old locations (`prompts/`, `examples/`, `hooks/`) maintain backward compatibility
- Existing installations work without modification
- `/saw scout` and `/saw wave` commands unchanged
- All agent prompts functionally equivalent (with documented improvements from v0.7.2)

### Validation

- Executed via Scout-and-Wave protocol (10 agents across 3 waves)
- Cross-repository orchestration pattern validated (0 isolation failures)
- All protocol content preserved and expanded
- No breaking changes to user workflows

**Dogfooding reference:** Full execution log in `docs/dogfooding-2026-03-06-protocol-extraction.md`

**Net change:** +11,390 lines added, -758 removed
## [0.7.2] - 2026-03-06

### Fixed

- **E4: Worktree isolation now mandatory for all Wave agents** (`PROTOCOL.md`, `prompts/agent-template.md`, `prompts/saw-skill.md`):
  Previously E4 allowed exceptions for "simple" work (documentation-only, refactors). The 2026-03-06 protocol extraction dogfooding session revealed this loophole caused Wave 1 execution failures when agents ran in wrong directories. E4 now states: "All Wave agents MUST use worktree isolation. There are no exceptions for work type. If work is too small to justify worktrees, it is too small for SAW; use sequential implementation instead."

  **Rationale added:** Worktrees enforce I1 (disjoint file ownership) mechanically, prevent concurrent write interference, enable independent verification before merge, and provide rollback capability. These benefits apply regardless of whether an agent modifies code or documentation.

  **Changes:**
  - PROTOCOL.md E4: Updated opening paragraph to remove exceptions, added rationale section
  - agent-template.md Field 0: Added "E4: Worktree isolation is MANDATORY" statement in rationale
  - saw-skill.md: No change needed (already enforces worktree creation before agent launch)

- **Cross-repository orchestration limitation documented** (`PROTOCOL.md`, `prompts/agent-template.md`, `prompts/saw-skill.md`):
  When Orchestrator runs from repo A but needs to coordinate work in repo B, the `isolation: "worktree"` parameter creates worktrees in A's context (wrong). Discovered during 2026-03-06 dogfooding when orchestrating scout-and-wave work from agentic-cold-start-audit directory.

  **Architectural constraint:** This is not a fixable bug. The task tool's isolation parameter operates relative to the orchestrator's working directory. To orchestrate work in repo B, the orchestrator must run from B's directory.

  **Workaround for cross-repo scenarios:**
  - Orchestrator: Manually create worktrees in target repo (Layer 1), omit `isolation: "worktree"` parameter
  - Agent: Field 0 cd command MUST succeed (not use `|| true`), or use explicit paths for all operations
  - Defense layers: Layer 1 (manual worktree creation) + Layer 3 (Field 0 verification) still provide isolation

  **Changes:**
  - PROTOCOL.md: Added "Cross-repository orchestration limitation" section to Orchestrator definition; updated E4 Layer 2 and Layer 3 with cross-repo guidance
  - agent-template.md Field 0: Added "Cross-repository scenarios" paragraph explaining workaround
  - saw-skill.md step 3: Added "Cross-repository orchestration" conditional logic for omitting isolation parameter

- **Field 0 cd strict in all scenarios** (`prompts/agent-template.md`, `PROTOCOL.md`):
  Removed `|| true` from Field 0 Step 1 cd command. Previously allowed silent failure with the assumption that Step 2 verification would catch problems. This weakened isolation enforcement and required complex conditional logic in documentation (alternative strategies for cross-repo scenarios).

  The strict cd works uniformly in both scenarios without conditional behavior:
  - Same-repo: Layer 2 (isolation parameter) positions agent correctly, cd is a no-op that succeeds
  - Cross-repo: Layer 2 omitted, cd performs actual navigation or fails fast if worktree doesn't exist

  This simplifies the protocol (one implementation instead of multiple strategies) and strengthens defense-in-depth (both Step 1 and Step 2 enforce, rather than Step 1 falling back to Step 2).

**Dogfooding reference:** These fixes address gaps #1 and #6 from `docs/dogfooding-2026-03-06-protocol-extraction.md`, which blocked Wave 1 execution during protocol extraction work.

## [0.7.1] - 2026-03-06

### Changed

- **Documentation: New-user onboarding improvements** (`README.md`):
  Comprehensive documentation audit revealed critical gaps that blocked new user comprehension.
  Addressed 10 high-priority issues identified through simulated new-user journey:

  1. **IMPL doc definition** - Added inline explanation on first mention: "structured coordination
     document that defines which files each agent will modify, what interfaces they'll implement"

  2. **Disjoint file ownership** - Added concrete example: "Agent A owns cache.go, Agent B owns
     client.go. Neither can touch the other's files. This guarantees conflict-free merges."

  3. **Worktree concept** - Explained on first use: "separate working directories that share git
     history but have independent files"

  4. **Scaffold Agent rationale** - Clarified why shared types need pre-commitment: "parallel
     agents work in isolated worktrees and can't see each other's code"

  5. **Two-directory structure** - Moved explanation to installation section: "prompts/agents/
     contains custom types (optional). prompts/ contains fallback prompts"

  6. **Temporal workflow sequence** - Added numbered 5-step overview at start of "How" section

  7. **I1-I6 invariant legend** - Added explanation: "I1-I6 are protocol invariants defined in
     PROTOCOL.md"

  8. **Installation step clarity** - Marked Steps 2-3 as "(Required)", Step 4 as "(Optional -
     Adds tool enforcement and observability)"

  9. **Real example reference** - Added pointer to brewprune IMPL doc for concrete example

  10. **Command flow diagram** - Added visual flow showing scout → review → wave sequence

  **Additional improvements:**
  - Emphasized "NOT SUITABLE" as a feature, not a failure
  - Defined "verification gate" as "build + tests + lint"
  - Explained "cascade failures" with cross-package example
  - Clarified bootstrap is for "new empty projects only"
  - Promoted QUICKSTART.md reference to top of Quick Start section
  - Removed JSON comment that breaks copy-paste

  **Impact:** Audit estimated these fixes reduce new-user time-to-first-successful-run from
  30-45 minutes to 10-15 minutes by surfacing key concepts at point of need rather than
  requiring deep-dive into specification documents.

## [0.7.0] - 2026-03-06

### Fixed

- **Bootstrap handoff to Scaffold Agent + Wave 1** (`prompts/saw-skill.md` v0.4.2):
  The bootstrap flow previously ended at "report and ask user to review" with no
  defined next step. After user approval the Orchestrator had no instruction to
  launch the Scaffold Agent or proceed to Wave 1 — the user had to know to invoke
  `/saw wave` separately, and the Scaffold Agent step could be silently skipped.

  Added steps 5 and 6 to the bootstrap branch:
  - Step 5: launch Scaffold Agent if Scaffolds section has pending files (identical
    logic to the scout flow's step 4)
  - Step 6: proceed to Wave 1 worktree setup and agent launch using the standard
    IMPL-exists wave loop

  Bootstrap is now fully continuous: requirements → Scout → review → Scaffold →
  Wave 1 → standard wave loop. No separate `/saw wave` invocation needed.

## [0.6.9] - 2026-03-06

### Changed

- **Bootstrap: structured requirements intake** (`prompts/saw-skill.md`, `prompts/saw-bootstrap.md`):
  The bootstrap flow now has a distinct pre-Scout step where the Orchestrator
  writes `docs/REQUIREMENTS.md` in the target project before launching the Scout
  agent. This file captures language, deployment target, external integrations,
  source codebase path, and architectural decisions already made. The Scout reads
  this file instead of receiving ad-hoc context in a massive prompt.

  **Why:** In practice, bootstrap requirements emerge organically over long
  conversations. By the time the Scout launches, context has been lost to
  compaction or scattered across chat history. A persistent requirements file
  survives session boundaries, gives the Scout structured input, and makes
  architectural constraints explicit rather than buried in prose.

  Files changed:
  - `prompts/saw-skill.md` v0.4.1: Bootstrap argument writes `docs/REQUIREMENTS.md`
    with structured template, asks user to confirm, then launches Scout referencing it
  - `prompts/saw-bootstrap.md` v0.3.4: Phase 0 changed from interactive question
    gathering to reading `docs/REQUIREMENTS.md`; fails fast if file missing

## [0.6.7] - 2026-03-05

### Changed

- **Wave Agent worktree isolation protocol** (`prompts/agents/wave-agent.md` v0.2.0): Added explicit instructions for using `git -C /full/worktree/path` flag for all git operations instead of relying on `cd`. Root cause: Bash tool in Claude Code does not persist working directory between command invocations, so `cd worktree && git commit` fails — the commit runs from the original CWD (main repo). New protocol section added at top of prompt with CORRECT/INCORRECT examples, branch verification command, and updated rules throughout. Fixes agents committing to main instead of worktree branches.

## [0.6.6] - 2026-03-04

### Added

- **Custom agent subtypes** (`prompts/agents/`): Three Claude Code agent type
  definitions — `scout.md`, `scaffold-agent.md`, `wave-agent.md` — with YAML
  frontmatter specifying `name`, `description`, `tools`, `model`, and `color`.
  When installed to `~/.claude/agents/` (or symlinked), these provide structural
  tool restrictions: scout cannot Edit source files, scaffold-agent can only
  Read/Write/Bash, wave-agent cannot spawn sub-agents. **This is optional.**
  The `/saw` skill falls back to `subagent_type: general-purpose` with the full
  prompt file if custom types are not installed. Users who prefer the existing
  workflow (general-purpose agents with full prompts) need not change anything.

- **`prompts/saw-skill.md` (v0.3.9 → v0.4.0):** Skill now specifies
  `subagent_type` when launching each agent — `scout`, `scaffold-agent`, or
  `wave-agent` — with automatic fallback to `general-purpose` if the custom
  type is not available. Added agent type preference paragraph explaining the
  two-tier design: type definition carries behavioral instructions and tool
  restrictions, prompt parameter carries task-specific context.

### Fixed

- **`prompts/scout.md` and `prompts/agents/scout.md`:** Suitability gate text
  said "Answer these three questions" but listed five numbered items. Changed
  to "Answer these five questions" in both files. The five questions have been
  present since v0.4.0; only the count text was wrong.

### Changed

- **`prompts/agents/scout.md`:** Synced from stale 160-line condensed version
  to full v0.4.0 content (475 lines). Previously missing: IMPL doc size
  guidance, type rename cascade checks, test performance guidance, linter
  auto-fix guidance, detailed pre-implementation check format, and
  time-to-value estimate format.

### Context

Custom agent subtypes are a layered enhancement. The tool restrictions they
provide (e.g., scout cannot `Edit`) are structural — enforced by the Claude Code
runtime, not by prompt instructions. A scout that tries to edit a source file
will be blocked at the tool level, not just told not to. This closes a class of
I6 violations where agents ignore role separation instructions. However, the
full-prompt approach remains the default and continues to work identically.
Installation is a symlink from the SAW repo to `~/.claude/agents/`:

```bash
ln -sf ~/code/scout-and-wave/prompts/agents/scout.md ~/.claude/agents/scout.md
ln -sf ~/code/scout-and-wave/prompts/agents/scaffold-agent.md ~/.claude/agents/scaffold-agent.md
ln -sf ~/code/scout-and-wave/prompts/agents/wave-agent.md ~/.claude/agents/wave-agent.md
```

---

## [0.6.2] - 2026-03-04

### Changed

- **`prompts/scout.md` (v0.4.0 → v0.4.1):** Scout step 5 now automatically
  detects shared types that cross agent boundaries and adds them to the
  Scaffolds section. Previously, the Scout could populate scaffolds but relied
  on manual detection during interface contract design. Now the Scout scans
  interface contracts after step 4 and counts how many agents will reference
  each type, struct, enum, or interface. If ≥2 agents will reference it (one
  defines, another consumes; or both consume), it is automatically added to
  scaffolds. Detection heuristics: explicit "define type X" + "consume type X"
  language in contracts, function return types crossing agent boundaries,
  duplicate struct/interface names in different agent sections. **Prevents
  merge conflicts:** Without this, Agent A might define `MetricSnapshot` in
  `fileA.go` while Agent B independently defines it in `fileB.go`, causing a
  duplicate declaration error at merge time. The Scaffold Agent materializes
  these shared types before Wave 1, so all agents import from the canonical
  location rather than redefining.

### Context

This improvement emerged from real-world SAW execution of claudewatch's metrics
export feature (Wave 1: Agent A + Agent B). Both agents independently created a
`MetricSnapshot` struct in separate files, causing a merge conflict. Root cause:
shared types should be in scaffold files committed to HEAD before Wave 1, not
independently declared by multiple agents. The Scaffolds section already existed
but was manually populated. This change makes detection automatic and systematic,
closing the gap between interface contract design and scaffold file generation.

---

## [0.6.1] - 2026-03-03

### Changed

- **`prompts/scout.md` (v0.3.9 → v0.4.0):** Status table in IMPL doc template
  now includes scaffold rows. Previously the status section only listed wave
  agent rows; scaffold steps were only visible by digging into the Scaffolds
  section. Now every IMPL doc produced by the Scout includes `— | Scaffold`
  rows in the status table at their correct position in the execution sequence,
  with commit SHA populated once done. Orchestrator row (`— | Orch`) for
  post-merge integration also added. Scaffold rows are omitted when no
  scaffolds are needed for a given wave boundary.

---

## [0.6.0] - 2026-03-03

### Added

- **`prompts/scaffold-agent.md` (v0.1.0):** New participant prompt for the Scaffold
  Agent. A lightweight participant that runs after Scout and human review: reads
  the approved IMPL doc Scaffolds section, creates the specified type scaffold
  source files, verifies they compile, commits to HEAD, and updates scaffold
  status. Embeds I2 and I5 at enforcement points. The Scaffold Agent is not a
  Wave Agent; it has no 9-field template, no worktree, and no completion report.
- **Scaffold Agent participant** added to `PROTOCOL.md`. Sits between Scout and
  Wave Agent in the participant model. Defined in the Participants section with
  narrow scope: materializes approved interface contracts as source files.
- **I2 invariant updated** in `PROTOCOL.md`: "The Scout defines all interfaces
  that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them
  as type scaffold files committed to HEAD after human review, before any Wave
  Agent launches." Previously credited Scout with both defining and implementing.
- **Scaffold Agent conditional spawn** added to `prompts/saw-skill.md` (v0.3.7):
  after Scout completes and user reviews the IMPL doc, if the Scaffolds section
  is non-empty and any scaffold file has `Status: pending`, launch Scaffold Agent
  before creating worktrees. Scaffold Agent is NOT a wave agent; runs via Agent
  tool with `run_in_background: true`.
- Same Scaffold Agent spawn step added to `saw-teams/saw-teams-skill.md` (v0.1.4).
  Scaffold Agent runs before any team is created; it is not a teammate.
- **`prompts/saw-bootstrap.md` (v0.3.3):** Scout Types Phase rewritten — Scout
  specifies scaffold file contents in IMPL doc; Scaffold Agent creates them after
  human review. Added "Why Scaffold Agent, not Scout" rationale. Output format,
  verification gates, and status checklist now show "Scaffold Agent:" instead of
  "Scout:". Rules clarified: Scout may create one artifact only (the IMPL doc).
- **Scaffold commit verification** added to skill files' worktree pre-creation
  steps: verify all IMPL doc Scaffolds section files show `Status: committed`
  before creating worktrees or spawning teammates.
- **Wave numbering note** added to `prompts/agent-template.md` (v0.3.8): waves
  are 1-indexed; there is no Wave 0; the Scout produces any required type scaffold
  files (via Scaffold Agent) before Wave 1 launches.

### Changed

- **`prompts/scout.md` (v0.3.9):** Scout no longer creates scaffold source files.
  Step 5 ("Produce type scaffolds if needed") reverted to "Define scaffold
  contents if needed" — Scout lists files in the IMPL doc Scaffolds section with
  exact contents specified, but does not write source files. Rules: "You may
  create one artifact: the IMPL doc. Do not create, modify, or delete any source
  files." IMPL doc Scaffolds section template updated: Status column added
  (`pending` initially, Scaffold Agent sets to `committed`).
- **`prompts/agent-template.md` (v0.3.8) Field 3:** "Scout-produced scaffold
  files committed to HEAD" → "Scaffold Agent-produced scaffold files committed to
  HEAD". Import from scaffold files rather than redefining types.
- **`saw-teams/teammate-template.md` (v0.1.3) Field 3:** same wording update.
- **`prompts/README.md`:** added `scaffold-agent.md` row (v0.1.0) to Participant
  Prompts table. Updated scout.md description: "Never modifies source files" →
  "Never modifies existing source files" (clarification: it is the Scaffold Agent
  that creates new ones). Version numbers updated: scout v0.3.9, agent-template
  v0.3.8, saw-skill v0.3.9.
- **`PROTOCOL.md` version:** 0.5.2 → 0.6.0.
- **`README.md` version badge:** 0.5.2 → 0.6.0.
- **`saw-teams/DESIGN.md`:** I2 row updated to reflect Scaffold Agent role; File
  Plan updated (saw-teams-skill v0.1.4, teammate-template v0.1.3); status line
  updated to v0.1.4 synced to protocol v0.6.0.

### Rationale

Introducing the Scaffold Agent restores the human review gate that the v0.5.0
"Scout creates scaffolds" design eliminated. Previously (v0.5.x), Scout committed
scaffold files before the user saw the IMPL doc — meaning interface contracts were
locked in code before human review. With v0.6.0, the flow is: Scout writes IMPL
doc → human reviews interface contracts → Scaffold Agent materializes them →
Wave Agents implement against them. The review gate is structural again.

The alternative (spawning Scout twice — once to analyze, once to create scaffolds)
was rejected: async agents run to completion with no pause/resume, so a "Scout
continues" design would require two separate Scout invocations with context
re-establishment overhead. The Scaffold Agent avoids this.

### Solo wave and cross-wave coordination semantics

- **Solo waves do not require scaffolding.** Scaffold files exist so that multiple
  agents in the same wave can compile against shared types; one agent cannot
  conflict with itself. Scout leaves the Scaffolds section empty for solo waves.
- **Cross-wave coordination uses committed code.** Waves execute sequentially.
  Wave N commits its work to HEAD; Wave N+1 imports from the committed codebase
  directly. Scaffolds solve the intra-wave problem only.
- **Scaffolding runs once, before the first wave.** E2 (interface freeze)
  guarantees all cross-agent types are known at REVIEWED. The state machine's
  loop-back from "more waves?" to WAVE_PENDING bypasses the scaffold gate by
  design — there is nothing new to scaffold between waves.

### Worktree isolation hardening

During a live SAW test (brewprune cold-start-r13, 6 parallel agents), all agents
committed to main instead of their worktree branches. The `isolation: "worktree"`
parameter on the Agent tool failed silently, Field 0 self-verification did not
catch it, and the Orchestrator saw "Already up to date" on all 6 branches during
merge — but proceeded anyway, committing uncommitted changes found on main.

The protocol had three defense layers but no merge-time enforcement. All three
cooperative layers (Task tool isolation, Field 0 verification, prompt
instructions) depend on agent behavior being correct. When the execution
environment fails silently, cooperative layers cannot detect it. The missing
piece was a deterministic check at merge time — before any `git merge` runs —
that verifies each agent branch actually has commits.

Correctness guarantees belong in infrastructure, not cooperation. Asking agents
to maintain worktree isolation through prompt instructions is fragile,
unenforceable at runtime, and invisible until merge time. Layer 4 transforms
an invisible failure mode into a loud, explicit error that forces investigation
before any damage occurs.

- **Layer 4 trip wire** added to merge procedure (`prompts/saw-merge.md` v0.4.5,
  `saw-teams/saw-teams-merge.md` v0.1.3): before any merge, verify each agent
  branch has commits beyond the base. Empty branch triggers hard stop. Catches
  all isolation failures regardless of cause — Task tool, Field 0, or prompt
  instructions.
- **Defense-in-depth rationale** added to worktree docs (`prompts/saw-worktree.md`
  v0.4.4, `saw-teams/saw-teams-worktree.md` v0.1.3): manual pre-creation stays
  alongside `isolation: "worktree"` as belt + suspenders. Neither mechanism is
  sufficient alone.
- **E4 rewritten** in `PROTOCOL.md`: documents 4-layer defense model (manual
  pre-creation → Task tool isolation → Field 0 verification → merge-time trip
  wire).

### Pre-commit hook as fail-fast guard (Layer 0)

Layer 4 detects isolation failures at merge time but cannot prevent them. The
natural follow-up: can we block the bad commit before it happens? A git
pre-commit hook can. But SAW has no runtime, no binary, no installed tooling.
The protocol is entirely prompt-driven. There is no hook file to commit to the
repo and no framework to manage it.

The solution is an ephemeral hook shipped as `hooks/pre-commit-guard.sh` in
the SAW repository. The Orchestrator copies it to `.git/hooks/pre-commit`
during worktree setup and removes it during cleanup after merge. Between
waves, the hook doesn't exist. The project's normal git workflow is
unaffected. If the project already has a pre-commit hook, SAW backs it up
and restores it afterward.

The hook blocks agent commits to main with an instructive error listing
available worktrees so the agent can self-correct (cd to its worktree and
retry). The Orchestrator bypasses the hook via `SAW_ALLOW_MAIN_COMMIT=1` for
its own legitimate main commits (scaffold, post-merge, lint fix). Agents never
have this variable set.

This closes the gap between prevention and detection. Layer 0 prevents the most
common failure mode (agent commits to main). Layer 4 catches everything Layer 0
can't prevent (agent works on main without committing, agent on wrong worktree
branch). Both are deterministic. Neither depends on agent cooperation.

- **Layer 0 pre-commit hook** added to worktree setup (`prompts/saw-worktree.md`
  v0.4.5, `saw-teams/saw-teams-worktree.md` v0.1.4): blocks agent commits to
  main during active waves with instructive error output.
- **`SAW_ALLOW_MAIN_COMMIT` bypass** added to merge procedures
  (`prompts/saw-merge.md` v0.4.6, `saw-teams/saw-teams-merge.md` v0.1.4) and
  `prompts/scaffold-agent.md` (v0.1.1) for legitimate Orchestrator commits.
- **E4 updated** in `PROTOCOL.md`: documents 5-layer defense model (Layer 0
  through Layer 4).

---

## [0.5.3] - 2026-03-03

### Fixed

- **`PROTOCOL.md` version header:** was `0.4.0`, updated to `0.5.2`.
- **`PROTOCOL.md` conformance criteria:** added scaffold file support bullet —
  conforming implementations must support Scout-produced scaffold files and
  post-merge scaffold integrity verification.
- **`PROTOCOL.md` audit grep instruction:** updated to include `E{N}` alongside
  `I{N}` so both invariants and execution rules are covered in consistency audits.
- **`prompts/README.md`:** updated all stale version numbers (saw-skill v0.3.3→v0.3.6,
  scout v0.3.5→v0.3.7, agent-template v0.3.4→v0.3.7, saw-worktree v0.4.1→v0.4.3,
  saw-merge v0.4.2→v0.4.4, saw-bootstrap v0.3.2→v0.3.1); removed "solo-agent check"
  from saw-worktree description; updated Scout description to reflect scaffold file
  production and "never modifies existing source files".
- **`README.md` version badge:** was `0.4.1`, updated to `0.5.2`.
- **`saw-teams/DESIGN.md`:** updated status line (v0.1.2→v0.1.3, protocol v0.4.1→v0.5.2);
  updated File Plan versions (saw-teams-skill v0.1.3, teammate-template v0.1.2,
  saw-teams-merge v0.1.2, saw-teams-worktree v0.1.2) and adapted-from references;
  added "committed to HEAD" to I2 row in both SAW and SAW-Teams columns.
- **`saw-teams/saw-teams-merge.md`:** "adapted from saw-merge (v0.4.3)" → v0.4.4.
- **`prompts/saw-bootstrap.md` (v0.3.2):** Rules section "Do not write any source code"
  contradicted the Scout Types Phase section which requires scaffold files. Fixed to
  allow scaffold files as a second artifact type. Removed stale `saw-quick mode`
  reference (saw-quick was removed in v0.4.0); NOT SUITABLE is now the verdict for
  fewer than 3 concerns.
- **`prompts/scout.md` (v0.3.8):** "All three questions" → "All five questions" in
  SUITABLE verdict (suitability gate has had 5 questions since v0.2.0). Removed stale
  `saw-quick mode` reference from low-parallelization guidance.
- **`docs/saw-type-scaffold-proposal.md`:** marked completed status items (v0.5.0
  Wave 1, v0.5.1 Wave 2, CHANGELOG updated); integration test item remains open.
- **`prompts/saw-worktree.md` (v0.4.3):** removed `store_embedding`-specific example
  from interface freeze checklist (implementation artifact that leaked into the generic
  protocol prompt); replaced with generic "multi-parameter function signatures" wording.
- **`saw-teams/saw-teams-worktree.md` (v0.1.2):** same `store_embedding` fix.
- **`prompts/agent-template.md` (v0.3.7):** Field 3 now names Scout-produced scaffold
  files as a source of interfaces alongside prior waves and existing code; adds note
  to check IMPL doc Scaffolds section.
- **`saw-teams/teammate-template.md` (v0.1.2):** same Field 3 scaffold note.

---

## [0.5.2] - 2026-03-03

### Changed

- **I2 invariant redefined:** renamed from "Interface contracts precede
  implementation" to "Interface contracts precede parallel implementation".
  Body updated to reflect the Scout's dual role: defines contracts in the IMPL
  doc AND implements them as type scaffold files committed to HEAD, before any
  Wave Agent launches. Updated in `PROTOCOL.md` (canonical definition),
  `prompts/saw-skill.md`, and `saw-teams/saw-teams-skill.md` (embeddings).

### Fixed

- **`saw-teams/DESIGN.md`:** I2 row was mislabeled "Verification gates"
  (that is I5). Corrected to "Interface contracts precede parallel
  implementation" with accurate SAW vs SAW-Teams comparison.
- **`saw-teams/README.md`:** I2 reference updated to name scaffold files
  explicitly.

---

## [0.5.0] - 2026-03-03

### Changed

- **Wave 0 collapsed into Scout phase.** The Scout now produces a types scaffold file directly — a source file containing all shared interfaces, structs, and error types — rather than writing a Wave 0 agent prompt. The work is identical; the mechanism changes from a sequential solo wave to a Scout output committed before any worktrees are created. Wave 1 is now always the first parallel wave.
- **Solo-agent short-circuit removed** from `prompts/saw-worktree.md`, `saw-teams/saw-teams-worktree.md`, and `saw-teams/saw-teams-skill.md`. Every wave runs through full wave machinery. A wave that decomposes to one agent signals a decomposition problem or NOT SUITABLE, not a short-circuit path.
- **Investigation-first items** are now NOT SUITABLE unconditionally. The SUITABLE WITH CAVEATS → Wave 0 workaround path is removed from the suitability gate in `scout.md`.
- **`saw-bootstrap.md`** reframed: "Wave 0 Pattern (Always Required)" → "Scout Types Phase (Always Required)". Output format, verification gates, status checklist, and rules updated to match.
- **`PROTOCOL.md`** solo wave definition removed; bootstrap Variants section updated.
- **`prompts/saw-skill.md`** and **`saw-teams/saw-teams-skill.md`** bootstrap descriptions updated.

### Rationale

Wave 0 was a structural smell: wave machinery applied to a single agent produces pure overhead with no parallelism benefit. The Scout already knows what Wave 0 needs to do — it wrote the Wave 0 agent prompt — so moving that work into the Scout phase requires only a permission change and a format change, not a new decision framework. See `docs/saw-type-scaffold-proposal.md` for the full design discussion.

---

## [0.5.1] - 2026-03-03

### Fixed

- **E-rule count mismatch:** `PROTOCOL.md`, `prompts/saw-skill.md`, and
  `saw-teams/saw-teams-skill.md` all claimed "E1–E13" despite E14 being defined
  in PROTOCOL.md since v0.4.0. All three updated to "E1–E14".
- **Scout definition stale in `PROTOCOL.md` and `README.md`:** both still said
  "Never modifies source files" after the Wave 0 collapse in v0.5.0. Updated to
  reflect that the Scout may produce type scaffold files as coordination
  artifacts; "Never modifies **existing** source files" is preserved.
- **Scaffold handling not visible in skill files:** the interface freeze
  checkpoint in `prompts/saw-skill.md` and `saw-teams/saw-teams-skill.md` did
  not mention scaffold commit verification. Added explicit note: Scout-produced
  scaffold files must be committed to HEAD before worktrees are created.
- **Post-merge verification missing scaffold check:** `prompts/saw-merge.md`
  (v0.4.4) and `saw-teams/saw-teams-merge.md` (v0.1.2) Step 6 now include a
  scaffold integrity check — verify scaffold files are present and unmodified
  after merge; any agent-modified scaffold is a protocol deviation.
- **Wave numbering not documented in `agent-template.md`:** added explicit note
  that waves are 1-indexed and Wave 0 no longer exists.

### Version bumps

`saw-skill.md` v0.3.6, `saw-merge.md` v0.4.4, `agent-template.md` v0.3.6,
`saw-teams-skill.md` v0.1.3, `saw-teams-merge.md` v0.1.2.

---

## [0.4.4] - 2026-03-03

### Added

- **`saw-teams/example-settings.json`:** all required `.claude/settings.json`
  fields for saw-teams in a single copyable block. Fields: `env` (enable Agent
  Teams), `teammateMode` (tmux recommended for wave work), `permissions.allow`
  (Agent + Bash + Read/Write/Edit + Glob/Grep), and `hooks` (TeammateIdle +
  TaskCompleted). README updated with a field-reference table explaining the
  purpose of each entry and calling out `"Agent"` as the critical allow-list
  entry.

---

## [0.4.3] - 2026-03-03

### Added

- **`saw-teams/hooks.md` (v0.1.0):** documentation for `TeammateIdle` and
  `TaskCompleted` protocol enforcement hooks. `TeammateIdle` fires when a
  teammate tries to idle; the SAW hook checks for a completion report in the
  IMPL doc and sends the teammate back if missing. `TaskCompleted` fires when
  a task is being closed; the hook enforces the I4 write-before-close ordering
  (IMPL doc write must precede task status update). Includes combined
  settings.json configuration and relationship to standard SAW.

- **`saw-teams/hooks/teammate-idle-saw.sh`:** executable `TeammateIdle`
  enforcement script. Exits 2 with structured feedback if no completion report
  or `status:` line found in the IMPL doc.

- **`saw-teams/hooks/task-completed-saw.sh`:** executable `TaskCompleted`
  enforcement script. Exits 2 if IMPL doc completion report is absent or
  missing `status:` line before a task is marked complete.

- **`saw-teams/README.md`:** setup guide covering: enable env var, display
  mode selection (in-process vs split-pane; split-pane recommended for SAW
  wave work), hook installation, `"Agent"` allow-list requirement, command
  reference, what SAW adds to Agent Teams, and known limitations.

### Changed

- **`saw-teams/saw-teams-skill.md` (v0.1.1 → v0.1.2):** spawn step (step 3c)
  fully specified. Three changes:
  1. **Spawn context construction**: explicit that spawn context must combine
     (a) teammate-template preamble, (b) IMPL doc agent section, (c) absolute
     worktree path. Without the preamble, the no-self-claim constraint and
     messaging protocol are absent and teammates default to Agent Teams
     self-claiming behavior.
  2. **CLAUDE.md note**: teammates automatically load the project's CLAUDE.md
     from their worktree working directory; project-level instructions are
     inherited without explicit inclusion in spawn context.
  3. **Display mode note**: split-pane mode recommended for SAW wave work;
     pointer to README.md for setup.
  4. **Task self-claiming note**: Agent Teams default is to self-claim; SAW
     explicitly prohibits it; the constraint lives in the spawn context.

- **`saw-teams/DESIGN.md`:** added "Protocol enforcement hooks" to "What's
  New" section. Updated File Plan to include README.md, hooks.md, and
  hooks/. Updated status to v0.1.2.

---

## [0.4.2] - 2026-03-03

### Changed

- **`saw-teams/saw-teams-skill.md` (v0.1.0 → v0.1.1):** synced to saw-skill
  v0.3.5 ([0.4.0]). Added E{N} notation to preamble. Embedded I2 (interface
  freeze at worktree creation, not teammate spawn) at step 3a. Embedded I4, I5,
  E7, E8 at step 5 (completion report reading). Embedded I3 (wave sequencing)
  at step 7.

- **`saw-teams/teammate-template.md` (v0.1.0 → v0.1.1):** synced to
  agent-template v0.3.5 ([0.4.0]). Added E{N} notation to preamble. Embedded
  E14 (IMPL doc write discipline) in Field 8: explicit append-only mandate,
  prohibition on editing earlier sections, rationale for why concurrent appends
  are safe.

- **`saw-teams/saw-teams-merge.md` (v0.1.0 → v0.1.1):** synced to saw-merge
  v0.4.3 ([0.4.1]). Step 6 now references `test_command` from the IMPL doc's
  Suitability Assessment rather than using ad-hoc language. The Scout derives
  this command; the lead consumes it at every post-merge gate.

- **`saw-teams/saw-teams-worktree.md` (v0.1.0 → v0.1.1):** synced to
  saw-worktree v0.4.2. Added Preflight Working Tree Check section (runs
  `git status --porcelain` before solo agent check, ownership verification, or
  worktree creation; two resolution paths: commit preferred, stash for WIP).
  Diagnose section 2 updated to use `git status --porcelain` and reference the
  preflight.

- **`saw-teams/DESIGN.md`:** corrected three stale table entries:
  - Field 0: "Agent Teams manages worktree natively" → actual behavior (lead
    pre-creates worktrees manually, same defense-in-depth as standard SAW)
  - I3 row: "via task dependencies" → "via control flow; future-wave tasks not
    created"
  - "Dynamic task reassignment" section relabeled as rejected; explained that
    self-claiming at runtime violates I1
  - File Plan version numbers updated to v0.1.1 throughout

---

## [0.4.1] - 2026-03-03

### Added

- **`test_command` field in IMPL doc** — Scout derives the project's full test
  suite command from the build system manifest (go.mod → `go test ./...`,
  Cargo.toml → `cargo test --workspace`, package.json → `npx jest`, etc.) and
  records it as `test_command` in the Suitability Assessment section. This is
  language-agnostic: the field is populated once by the Scout and consumed by
  the Orchestrator at every post-merge gate, with no per-language branching in
  the protocol itself.

### Changed

- **`saw-merge.md` Step 6** (`saw-merge v0.4.2 → v0.4.3`) — Post-merge
  verification now explicitly references `test_command` from the IMPL doc
  rather than describing the rule in generic terms. The "run tests unscoped"
  principle is unchanged; the change makes the IMPL doc the single source of
  the actual command.

- **`scout.md` Process step 1** (`scout v0.3.6 → v0.3.7`) — Step 1 now
  explicitly instructs the Scout to derive and record `test_command` as part of
  reading the build system. Previously this was implicit in "verification gates
  must match the project's actual toolchain."

---

## [0.4.0] - 2026-03-02

### Removed

- **`prompts/saw-quick.md` (Quick mode):** removed. Quick mode only enforced I1
  and explicitly unenforced I2–I5. A tool that strips SAW's guarantee set is not
  a SAW variant; it is a different thing wearing SAW's name. Keeping it in the
  repo implied SAW has a mode for every parallelization case, which dilutes the
  protocol's contract and invites using it as a catch-all. Work that doesn't fit
  SAW should not use SAW. The "Low parallelization value" guidance in the README
  covers the 2–3 agent case without prescribing a named protocol for it.

- **`/saw check` command:** removed. The command's only value was filtering NOT SUITABLE
  cases before a scout run, but the Scout already runs a built-in suitability gate and stops
  with a NOT SUITABLE verdict when the work doesn't qualify. Running `/saw check` before
  `/saw scout` added latency on SUITABLE outcomes (the common case) with no benefit, and
  the NOT SUITABLE path was already handled by the Scout's early exit. The "When to Use It"
  section now describes the Scout's suitability gate directly. The CHECKING state has been
  removed from the PROTOCOL.md state machine.

### Changed

- **`PROTOCOL.md` (v0.3.5):** added invariant reference convention. Invariants are
  identified by I-number (I1–I6). When referenced in prompt files, the I-number anchors
  cross-referencing and audit; the canonical definition is embedded verbatim for
  self-containment. Audit pattern: grep prompt files for `I{N}` and verify definition
  matches PROTOCOL.md.

- **`prompts/saw-skill.md` (v0.3.3 → v0.3.4):** role enforcement block replaced with
  I6 canonical definition verbatim. Wave execution step replaced "Disjoint file ownership
  is the primary safety mechanism" with I1 canonical definition. I-notation explanation
  added after I6 block.

- **`prompts/agent-template.md` (v0.3.3 → v0.3.4):** three additions:
  1. Opening paragraph names agents as Wave Agents operating under the SAW protocol,
     giving them formal identity and context for their role without requiring the full spec.
  2. I-notation explanation added so agents know I-numbers refer to `PROTOCOL.md` invariants.
  3. I1 canonical definition embedded in Section 1 (File Ownership).
  4. I5 canonical definition embedded in Section 8 (Report) before the commit instructions.

- **Terminology sweep:** eliminated all remaining "foreground/background" language
  in favour of "synchronous/asynchronous" per the canonical participant model:
  - `docs/saw-pipeline-proposal.md` lines 17, 119: "foreground" → "synchronous agent",
    "background scout" → "asynchronous scout"
  - `README.md` line 114: "goes to background" → "launches asynchronously"

- **9-field correction:** "8-field" references corrected to "9-field" across all files
  that had not yet been updated following the addition of Field 0 (Isolation Verification):
  - `prompts/agent-template.md` line 4: description updated to name Field 0 explicitly
  - `prompts/scout.md` line 335: IMPL doc output format reference
  - `prompts/saw-bootstrap.md` line 203: Agent Prompts section template
  - `README.md` line 44: Prompts table description, now names Field 0 and Fields 1–8

- **README version badge:** corrected from 0.3.7 to 0.3.5 to match PROTOCOL.md.
  The badge reflects the protocol specification version, not the latest individual
  prompt file version.

- **`PROTOCOL.md` (v0.3.4 → v0.3.5):** added **I6: Role Separation** invariant.
  The Orchestrator must not perform Scout or Wave Agent duties. Codebase analysis,
  IMPL doc production, and source code implementation must be delegated to the
  appropriate asynchronous agent. I6 violation added to the Protocol Violations table
  with its effects: context pollution, broken observability, async execution bypassed.
  This invariant was implicit in the participant role definitions but not enforced;
  the absence allowed rationalizing Scout work as Orchestrator convenience.

- **`prompts/saw-skill.md` (v0.3.2 → v0.3.3):** added strict role enforcement rule.
  The Orchestrator now has an explicit invariant: if it finds itself analyzing a codebase,
  writing an IMPL doc, or implementing code, it must stop and delegate to the appropriate
  agent. If asked to perform Scout or Wave agent duties directly, it must refuse and launch
  the correct agent instead. Stated at the top of the skill before all other instructions
  so it cannot be rationalized away by downstream context.

### Added

- **`docs/diagrams/saw-state-machine.drawio`:** new draw.io state machine diagram
  covering all named protocol states (IDLE, SCOUTING, REVIEWED, WAVE_PENDING,
  WAVE_EXECUTING, WAVE_MERGING, WAVE_VERIFIED, BLOCKED, COMPLETE) with solo/multi
  fork, BLOCKED recovery arc, and wave loop. Light/dark SVG exports in
  `docs/diagrams/`. Replaces the ASCII state machine in PROTOCOL.md.

- **`docs/saw-pipeline-proposal.md`:** new document capturing cross-feature scout
  pipelining: the observation that the orchestrator's wave-execution wait window is
  dead time that can be filled by launching the next feature's scout as an async agent.
  Covers the safety constraint (disjoint read domain check), timing model, a real
  example from a claudewatch session, and proposed protocol changes. Also captures
  the session-level DAG extension: applying SAW's file-level dependency graph reasoning
  at the feature level, with a proposed `/saw session` entry point for upfront
  full-landscape pipeline planning.

### Changed

- **`PROTOCOL.md` — execution rules numbered E1–E13:** all execution rules are now
  identified by E-number (E1–E13), matching the I-number convention for invariants.
  The E-number is the cross-referencing anchor for embedding in prompts and audit.
  Audit pattern: grep prompt files for `E{N}` and verify definition matches PROTOCOL.md.

- **`PROTOCOL.md` — state machine:** ASCII art replaced with draw.io SVG
  (`saw-state-machine-light.svg` / `saw-state-machine-dark.svg`). The `<picture>`
  element switches themes automatically. Source preserved in
  `docs/diagrams/saw-state-machine.drawio`.

- **`PROTOCOL.md` — pipelining references removed:** pipeline scheduling is an
  experimental design proposal (`docs/saw-pipeline-proposal.md`), not a finalized
  protocol feature. All references to it removed from the normative spec.

- **`PROTOCOL.md` — decoupled from Claude-specific language:** normative requirements
  are now implementation-agnostic. Claude Code primitives (e.g. `run_in_background:
  true`, `isolation: "worktree"`) re-added as parenthetical examples, not normative
  text. Protocol is portable; the mechanism is swappable.

- **`PROTOCOL.md` — Orchestrator role clarified:** synchronous execution is what makes
  checkpoints enforceable; the human is present through the Orchestrator, not as a
  separate participant. Mandatory vs optional checkpoints distinguished explicitly:
  suitability gate and REVIEWED are always mandatory; inter-wave confirmation is
  optional via `--auto`; BLOCKED always surfaces.

- **`docs/ECOSYSTEM.md`:** added explicit statement of prompt-native design intent
  and the down-the-stack tradeoff. The intellectual claim SAW makes — that coordination
  protocols can live in natural language and still provide structural safety guarantees
  — is now named directly. The tradeoff (code enforcement vs prompt portability) is
  stated with the condition under which it would be worth revisiting.

- **`README.md`:** added "How it works under the hood" section covering IMPL doc as
  coordination surface (not just documentation) and background execution as the
  mechanism that makes waves actually parallel. Updated permissions block to include
  WebFetch, WebSearch, and TodoWrite. Trimmed Workflow and "When to Use It" sections.
  Orchestrator described as running in the user's own session; no separate human role.

- **`prompts/saw-skill.md` (v0.3.4 → v0.3.5):**
  - Embedded I2, I3, I4, I5 at their enforcement points (I1 and I6 were already
    present). All six invariants now embedded verbatim in the skill.
  - Tightened I2: interface freeze occurs at worktree creation (step 2), not at agent
    launch (step 3). Added explicit freeze checkpoint callout to step 2.
  - Embedded E7 (agent failure handling) and E8 (same-wave interface failure) at step 4
    (completion report reading), the Orchestrator decision point for both.
  - Updated `I{N}` notation comment to cover `E{N}` execution rules (E1–E14).

- **`PROTOCOL.md` — spec hole patches (six gaps closed):**

  - **E14: IMPL doc write discipline (new rule).** Agents write to the IMPL doc
    exactly once: by appending their named completion report section at the end of
    the file. Must not edit any earlier section (interface contracts, ownership
    table, suitability verdict, wave structure). Those sections are frozen at
    worktree creation (E2). Any required update to an earlier section is an
    interface deviation — report it, do not edit in place. Cross-referenced from I4.
    This constraint is what makes IMPL doc git conflicts predictably resolvable (E12).

  - **E2: Interface freeze exception workflow.** Added two named recovery paths for
    interface changes after worktrees exist and some agents have completed work:
    (a) recreate and cherry-pick — preserve unaffected commits, recreate worktrees,
    cherry-pick safe commits, re-run only affected agents; use when most agents have
    completed and the change is narrow; (b) descope and defer — leave the current
    wave to complete against existing contracts, move the interface revision to the
    next wave boundary via E8; use when the change is broad or cherry-pick safety
    cannot be confirmed. Added E2/E8 relationship note: same problem from opposite
    discovery directions, both resolve at the wave boundary.

  - **E10: Scoped verification — exact commands mandate.** The scout must specify
    exact verification commands in Field 6 of each agent prompt. Agents run those
    exact commands; substitutions are not permitted. `go test ./...` is unscoped in
    Go regardless of speed; the correct scoped command targets owned packages only.
    An agent substituting a broader command is non-conforming even if it passes.

  - **Solo wave I6 safety clause.** The solo wave agent must operate in the Wave
    Agent role — launched by the Orchestrator as an asynchronous agent, not executed
    inline. Executing solo wave work directly violates I6 regardless of wave size.
    The absence of worktrees changes the isolation mechanism; it does not change
    participant roles.

  - **Precondition 1: append-only precisely defined.** A change qualifies as
    append-only if and only if: the diff is purely additive (no deletions, no
    modifications to existing entries, no reformatting, no reordering) and the new
    entries are self-contained. Any change that touches an existing line — even
    whitespace — disqualifies the file from orchestrator-owned treatment and makes
    it a decomposition blocker. Verification: diff must contain only `+` lines, no
    `-` lines.

  - **Protocol Guarantees: softened interface drift claim.** "Interface drift is
    structurally impossible" replaced with "direct coordination drift is prevented;
    deviations must be declared in completion reports and surfaced at wave
    boundaries." The original claim was falsifiable by semantic drift (wrong
    implementation of correct signature, differing contract interpretation). The
    revised claim matches what the protocol actually enforces via `interface_deviations`
    in the completion report schema.

- **`prompts/agent-template.md` (v0.3.4 → v0.3.5):**
  - Embedded E14 in Field 8 (Report): explicit append-only mandate with rationale.
    Agents must not edit earlier IMPL doc sections; report interface deviations
    instead of editing contracts in place.
  - Updated notation comment to cover `E{N}` execution rules (E1–E14).

- **Style:** removed em dashes from 20 markdown files across the repository.

- **`PROTOCOL.md` (v0.3.4):** three clarifications developed from practice:

  - **Opening description:** repositioned from "coordination protocol for parallel
    AI agent execution" to "a protocol for safely parallelizing human-guided agentic
    workflows." Human review checkpoints are now named as structural (not optional
    guardrails); cross-feature pipelining is named as optional.

  - **Participants section:** synchronous/asynchronous framing replaces
    foreground/background. Orchestrator is the synchronous agent that serializes all
    state transitions and is the sole human-facing reporting channel. Scouts and wave
    agents are asynchronous agents launched by the orchestrator. Async agents are
    invisible to the human except through the orchestrator's completion handling.

  - **Pipeline framing:** PROTOCOL.md now references `saw-pipeline-proposal.md`
    in the Scout participant description, noting that pipelining is a scheduling
    optimization on the orchestrator, not a structural change to the protocol. The
    orchestrator stays synchronous and foreground; it simply launches a scout instead
    of idling during wave execution.

- **`README.md`:** added **Permissions** subsection under Usage. Documents all
  required `~/.claude/settings.json` allow entries for hands-free execution.
  Calls out `"Agent"` as the critical entry: without it, every wave agent launch
  and pipelined scout launch blocks on a keyboard approval prompt.

## [0.3.7] - 2026-03-01

### Changed

- **`prompts/saw-merge.md` (v0.4.1 → v0.4.2):** post-merge verification now
  includes an explicit linter auto-fix pass before build and tests. The orchestrator
  runs the project's auto-fix command (`golangci-lint run --fix`, `ruff --fix`,
  `eslint --fix`, `cargo fmt`, etc.) on the merged codebase, commits any style
  changes, then runs the full suite. Centralizing auto-fix in the orchestrator
  is cleaner than requiring every agent to know and run the exact command; one
  pass on the merged result catches formatter divergence across all agents at once.

- **`prompts/agent-template.md` (v0.3.2 → v0.3.3):** agent verification gate
  now explicitly states agents do not run linter auto-fix. A note explains that
  the orchestrator owns the single auto-fix pass on the merged result, so agents
  run the linter in check mode only. Removes the failure mode where agents pass
  locally but CI fails because CI runs auto-fix and agents don't.

- **`prompts/scout.md` (v0.3.4 → v0.3.5):** step 8 now instructs the scout to
  document the project's auto-fix command in the IMPL doc's Wave Execution Loop
  (for the orchestrator) rather than emitting it in individual agent gates.

## [0.3.6] - 2026-03-01

### Changed

- **`prompts/saw-skill.md` (v0.3.0 → v0.3.1):** wave execution step 3 now requires a
  structured `[SAW:wave{N}:agent-{X}]` prefix on the Task tool's `description` parameter
  when launching agents. Format: `[SAW:wave1:agent-A] short description`. Enables
  claudewatch to automatically parse wave timing, agent count, and per-agent status from
  session transcripts with no additional instrumentation.

## [0.3.5] - 2026-03-01

### Changed

- **`prompts/scout.md` (v0.2.1 → v0.3.4):** suitability gate Q1 updated:
  append-only additions to shared files (config registries, module manifests,
  index files) are not a decomposition blocker; orchestrator-owned post-merge.
  "8-field format" reference corrected to "9-field format".

- **`prompts/saw-quick.md` (v0.2.0 → v0.3.4):** file ownership declaration
  is now a hard requirement before agents launch, not a checklist suggestion.
  Explicit warning added: Quick mode enforces I1 only; I2–I5 are unenforced.

- **`prompts/saw-merge.md` (v0.4.0 → v0.4.1):** four additions:
  - `status: partial` or `status: blocked` on any agent halts the wave; no
    partial merges permitted
  - Prompt propagation formalized: updating an agent prompt means editing its
    section in the IMPL doc in-place; no separate prompt files
  - Same-wave interface failure procedure: wave halts, contracts revised,
    affected agents re-prompted, unaffected agents do not re-run
  - Crash recovery section: use `git log --merges` to identify already-merged
    worktrees before resuming a mid-merge crash; WAVE_MERGING is not idempotent

- **`prompts/saw-worktree.md` (v0.4.0 → v0.4.1):** two additions:
  - Pre-launch ownership verification step: scan wave ownership table for
    overlaps before creating worktrees; block launch if any file appears twice
  - WAVE_PENDING re-entrancy note: check for existing worktrees before creating;
    do not duplicate

## [0.3.4] - 2026-03-01

### Changed

- **PROTOCOL.md updated to v0.3.4:** eight protocol gaps closed following formal review:
  - Precondition 1: append-only additions to shared files (config registries, module
    manifests) are not a decomposition blocker; scout makes such files orchestrator-owned
  - Execution Rules: pre-launch ownership verification added; orchestrator scans
    wave ownership table for overlaps before creating worktrees or launching agents
  - Execution Rules: agent prompt propagation formalized; prompts are sections within
    the IMPL doc; updates are edits in-place, no separate prompt files
  - Execution Rules: agent failure handling; any `status: partial` or `status: blocked`
    halts the wave; no partial merges permitted
  - Execution Rules: same-wave interface failure; wave goes to BLOCKED, contracts
    revised, affected agents re-prompted; unaffected agents do not re-run
  - Execution Rules: idempotency; WAVE_PENDING is re-entrant; WAVE_MERGING is not;
    recovery procedure defined for mid-merge orchestrator crash
  - Conflict prediction: explicit statement that within a valid wave merge order is
    arbitrary; same-wave agents are independent by construction
  - Variants: Quick mode now requires file ownership declaration (preserves I1);
    explicit statement that I2–I5 are unenforced in Quick mode

## [0.3.3] - 2026-03-01

### Changed

- **PROTOCOL.md updated to v0.3.3:** aligned with actual implementation:
  - Agent prompt is 9-field (Field 0: Isolation Verification), not 8-field
  - State machine extended: solo wave path bypasses WAVE_MERGING; Wave 0 formalized
  - New Execution Rules section: interface freeze, worktree pre-creation, scoped vs
    unscoped verification, conflict prediction before merge
  - I1 invariant clarified: single-agent out-of-scope changes are distinct from
    two-agent conflicts and not an I1 violation when justified and documented
  - Completion report `interface_deviations` extended with `downstream_action_required`
    and `affects` fields
  - New Variants section documenting Quick mode and Bootstrap mode
  - Protocol Violations table: removed language-specific Rust example (special case
    of I1, not a distinct protocol violation)
  - Reference Implementation table: corrected "8-field" to "9-field"

## [0.3.2] - 2026-02-28

### Added

- **Flow diagrams:** four draw.io source files and light/dark SVG exports covering
  each `/saw` subcommand: `saw-scout-wave`, `saw-bootstrap`, `saw-check`,
  `saw-status`. All files live in `docs/diagrams/`. Light/dark SVGs exported via
  `--svg-theme light/dark`; the `<picture>` element in README switches automatically.

- **`docs/diagrams/saw-scout-wave.drawio`:** full protocol flow from suitability
  gate through scout phase, IMPL doc, human review, wave loop (worktree setup,
  agent execution, completion reports, orchestrator, merge, fix/re-verify).

- **`docs/diagrams/saw-bootstrap.drawio`:** `/saw bootstrap` flow: git pre-flight,
  requirements gathering, package structure design, concerns gate (≥3 required),
  IMPL-bootstrap.md output, handoff to `/saw wave`.

- **`docs/diagrams/saw-check.drawio`:** `/saw check` flow: lightweight scan,
  3-question evaluation, 3-way verdict (SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS).
  Read-only pre-flight; no files written.

- **`docs/diagrams/saw-status.drawio`:** `/saw status` flow: IMPL doc existence
  check, wave structure and checkbox reading, progress report output.

- **README diagram**: replaced mermaid flowchart with `<picture>` element linking
  `saw-scout-wave-light.svg` / `saw-scout-wave-dark.svg` for native dark mode support.

## [0.3.1] - 2026-02-28

### Changed

- **Structured completion reports:** Agent template Section 8 now produces a
  machine-readable YAML block instead of free-form prose: `status`, `worktree`,
  `commit` (sha or "uncommitted"), `files_changed`, `files_created`,
  `interface_deviations`, `out_of_scope_deps`, `tests_added`, `verification`.
  Free-form notes follow the block for anything that doesn't fit. Enables
  orchestrator automation of conflict detection, merge sequencing, and IMPL doc
  updates without reading prose.

- **Conflict prediction before merge:** `saw-merge.md` now cross-references
  all agents' `files_changed` and `files_created` lists before touching the
  working tree. Disjoint ownership violations surface before `git merge` is
  attempted, not mid-merge. `out_of_scope_deps` lists are also cross-referenced
  for agents that flagged the same file with different required changes.

- **Structured merge procedure:** `saw-merge.md` rewritten as 7 explicit
  steps: parse reports, conflict prediction, review deviations, merge,
  cleanup, post-merge verification, IMPL doc updates. Each step uses
  structured report fields rather than requiring the orchestrator to interpret
  prose.

- **`saw-merge.md` version bump:** v0.2.0 → v0.3.0
- **`agent-template.md` version bump:** v0.2.0 → v0.3.1

## [0.3.0] - 2026-02-28

### Added

- **`/saw bootstrap` subcommand:** Design-first architecture for new projects
  with no existing codebase. The bootstrap scout acts as architect rather than
  analyst: it gathers requirements (language, project type, key concerns), designs
  package structure and interface contracts before any code is written, and
  produces `docs/IMPL-bootstrap.md` with a mandatory Wave 0 (types/interfaces)
  followed by parallel implementation waves. Solves the cold-start problem where
  regular scout has no existing code to analyze.

- **`saw-bootstrap.md`:** Dedicated module implementing the bootstrap procedure:
  requirements gathering, architecture design principles (one concern = one
  package, types-as-foundation, no god files), Wave 0 pattern, output format,
  and rules. Follows the module decomposition pattern established in v0.2.0.

- **Wave 0 pattern formalized:** Bootstrap projects always require a solo types
  wave before any parallel implementation. All shared interfaces and structs are
  defined in a `types` package first; downstream agents implement against these
  contracts without seeing each other's code. Post-Wave-0 gate is build-only
  (no tests yet), unblocking all Wave 1 agents simultaneously.

## [0.2.0] - 2026-02-28

### Changed

- **Decomposed skill prompt into focused modules:** `saw-skill.md` is now a thin router that delegates worktree management to `saw-worktree.md` and merge/verify logic to `saw-merge.md`. Each module is independently testable and debuggable. Previously all orchestration logic (routing, worktree creation, merge handling, conflict detection, diagnostics, progress tracking) was interleaved in a single prompt that assumed deterministic execution of non-deterministic steps.

- **Replaced agent count threshold with complexity-based heuristic:** The suitability gate no longer uses raw agent count (≤2 NOT SUITABLE, ≥5 SUITABLE) as the primary decision criterion. Instead evaluates parallelization value based on: build/test cycle length (>30s favors SAW), files per agent (≥3 favors SAW), agent independence (single wave = max benefit), and task complexity (logic > documentation). The previous threshold was based on a single dogfooding data point (4 documentation-only agents, 88% slower than sequential) that didn't generalize; code-heavy tasks with 2 agents benefited from SAW despite being under the threshold.

- **Added version headers to all prompt files:** Each prompt file now includes a `<!-- filename v0.2.0 -->` comment at the top. Users who copy prompts to `~/.claude/commands/` can compare their copy's version against the repo to detect staleness.

### Added

- **`saw-worktree.md`:** Dedicated module for worktree lifecycle: pre-creation, verification, diagnosis of creation failures (3-tier fallback), agent self-healing explanation, and cleanup. Extracted from saw-skill.md.

- **`saw-merge.md`:** Dedicated module for merge procedure: pre-merge conflict detection, handling committed vs uncommitted agent changes, worktree cleanup, post-merge verification, and IMPL doc updates. Extracted from saw-skill.md.

- **Worktree isolation verification:** SAW orchestrator now checks `git worktree list` after launching agents to verify worktrees were actually created. If count doesn't match (expected N+1 for N agents + main), stops immediately with error. Prevents silent data loss when `isolation: "worktree"` parameter fails to create worktrees. Emerged from brewprune Round 5 Wave 1 where 5 agents were launched but 0 worktrees created - all agents modified main directly. Zero conflicts occurred only due to perfect file disjointness (luck, not safety).

- **Agent self-healing isolation verification:** Agent template now includes mandatory Section 0: pre-flight worktree isolation check with self-healing. Agents first attempt `cd` to expected worktree location (self-correction), then verify pwd, git branch, and worktree existence BEFORE any file modifications. If verification fails after cd attempt, agent writes error to completion report and exits immediately without touching files. Orchestrator detects failures within 10s. This is Layer 1.5 (self-healing) + Layer 2 (strict verification) of defense in depth. Philosophy shift from "detect-only" to "attempt-fix-then-detect" provides redundant protection against Task tool working directory issues while maintaining strict fail-fast behavior. Validated in brewprune Round 5 Wave 2 where agents successfully self-corrected working directory.

- **Out-of-scope conflict detection:** SAW orchestrator now scans all agent completion reports for out-of-scope file changes (section 8) before merging. If multiple agents modified the same out-of-scope file, the orchestrator flags the conflict and prompts the user for resolution. Prevents silent data loss when agents touch files outside their ownership.

- **Performance guidance for test commands:** Scout now provides guidance on focused vs full test runs. For packages with >50 tests, agents use focused tests during waves (`go test ./pkg -run TestSpecific`) while post-merge verification runs the full suite (`go test ./...`). Includes reasonable timeouts (2-5min per package). Keeps agent verification fast while preserving full coverage at merge.

- **Pre-implementation status check:** Scout suitability gate now includes step 4: check each audit finding/requirement against the current codebase to determine implementation status (TO-DO, DONE, PARTIAL). For DONE items, scout adjusts agent prompts to "verify existing implementation and add test coverage" rather than "implement." Prevents wasted compute on already-implemented work.

- **Known Issues section in IMPL template:** Scout now includes a "Known Issues" section in the IMPL doc template where pre-existing test failures, build warnings, or known bugs can be documented. Helps agents distinguish expected failures from regressions. Includes workarounds and tracking links.

- **Justified API-wide changes guidance:** Agent template now explicitly permits out-of-scope modifications when fixing design flaws that require atomic changes. Agents must document all affected files, justify why changes must be atomic (not incremental), and update all call sites consistently. Example: fixing race conditions in shared APIs.

- **Integration test reminder:** Agent template now prompts agents to search for tests expecting OLD behavior when modifying command behavior, exit codes, or error handling. Update related tests BEFORE running verification to prevent post-merge test failures.

### Fixed

- **Scout agent file-writing clarification:** Removed ambiguous "read-only reconnaissance agent" language that caused Plan agents to refuse writing IMPL docs. Now explicitly states: "you do NOT write implementation code, but you MUST write the coordination artifact (IMPL doc) using the Write tool." Prevents agents from returning IMPL content as text instead of writing the file.

## [0.1.0] - 2026-02-27

Initial release of the Scout-and-Wave protocol based on lessons learned from brewprune UX audit experiments.

### Added
- Scout agent prompt for dependency mapping and coordination artifact generation
- 8-field agent prompt template
- `/saw` skill for Claude Code with `check`, `scout`, `wave`, and `status` commands
- Suitability gate with 3-question assessment (file decomposition, investigation items, interface discoverability)
- Wave execution loop with post-merge verification
- Living coordination artifact (agents append completion reports)

### Protocol Evolution Timeline

The improvements in this release emerged through iterative testing on brewprune (a Homebrew package cleanup tool):

**Round 3 Cold-Start Audit (2026-02-27):**
- 19 findings → 11 parallel agents in single wave
- **Discovered gaps:**
  - 5/11 agents found work already implemented (wasted compute)
  - Agents E & C both modified `quickstart.go` out-of-scope (conflict)
  - Test suite (131 tests) timed out during agent verification (slow iteration)
  - Agent F's test had incorrect expectations (quality issue)
- **Result:** Wave completed, but inefficiencies identified

**Post-Round 3 Fixes (2026-02-27-28):**
- Implemented 3 protocol improvements: conflict detection, performance guidance, pre-implementation check
- Updated scout prompt and SAW skill

**Round 4 Cold-Start Audit (2026-02-28):**
- 38 findings (7 P0 critical manually fixed, 31 P1/P2 for SAW)
- Scout agent attempted to produce IMPL doc but refused to write file
- **Discovered gap:** "Read-only reconnaissance agent" prompt caused agent to misinterpret as technical constraint
- **Result:** Fixed scout prompt clarification

**Current state:** Protocol now includes all 4 improvements. Round 4 P1/P2 fixes (31 findings, 10 agents, 3 waves) ready for execution using the improved protocol.

### Lessons Learned

**Audit-fix-audit cycle validates the protocol:**
- Cold-start audits identify UX issues (source of truth for quality)
- SAW accelerates parallel fixing (11 agents → single wave in Round 3)
- Each audit reveals protocol gaps → improvements → better next iteration

**Key insights:**
- Post-merge verification caught integration issues individual agents missed
- Out-of-scope dependencies are real and need proactive conflict detection
- Test performance matters for iteration speed (focused tests during waves, full suite at merge)
- Pre-implementation checks prevent wasted agent compute
- Prompt clarity is critical - agents will self-limit if language is ambiguous

## Protocol Design

Scout-and-wave is optimized for:
1. **Parallelization without conflicts:** Disjoint file ownership is a hard constraint
2. **Interface contracts before implementation:** Agents code against specs, not each other
3. **Living coordination artifacts:** Agents append completion reports; downstream agents read updated reality
4. **Post-merge verification as the real gate:** Individual agent success doesn't guarantee integration success
5. **Fail-fast suitability assessment:** Better to identify poor fits early than force decomposition

The protocol evolves through real-world usage. Each experiment surfaces gaps that become improvements.
