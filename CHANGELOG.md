# Changelog

All notable changes to the Scout-and-Wave protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [0.3.3] - 2026-03-01

### Changed

- **PROTOCOL.md updated to v0.3.3** — aligned with actual implementation:
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

- **Flow diagrams** — four draw.io source files and light/dark SVG exports covering
  each `/saw` subcommand: `saw-scout-wave`, `saw-bootstrap`, `saw-check`,
  `saw-status`. All files live in `docs/diagrams/`. Light/dark SVGs exported via
  `--svg-theme light/dark`; the `<picture>` element in README switches automatically.

- **`docs/diagrams/saw-scout-wave.drawio`**: full protocol flow from suitability
  gate through scout phase, IMPL doc, human review, wave loop (worktree setup,
  agent execution, completion reports, orchestrator, merge, fix/re-verify).

- **`docs/diagrams/saw-bootstrap.drawio`**: `/saw bootstrap` flow — git pre-flight,
  requirements gathering, package structure design, concerns gate (≥3 required),
  IMPL-bootstrap.md output, handoff to `/saw wave`.

- **`docs/diagrams/saw-check.drawio`**: `/saw check` flow — lightweight scan,
  3-question evaluation, 3-way verdict (SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS).
  Read-only pre-flight; no files written.

- **`docs/diagrams/saw-status.drawio`**: `/saw status` flow — IMPL doc existence
  check, wave structure and checkbox reading, progress report output.

- **README diagram**: replaced mermaid flowchart with `<picture>` element linking
  `saw-scout-wave-light.svg` / `saw-scout-wave-dark.svg` for native dark mode support.

## [0.3.1] - 2026-02-28

### Changed

- **Structured completion reports** — Agent template Section 8 now produces a
  machine-readable YAML block instead of free-form prose: `status`, `worktree`,
  `commit` (sha or "uncommitted"), `files_changed`, `files_created`,
  `interface_deviations`, `out_of_scope_deps`, `tests_added`, `verification`.
  Free-form notes follow the block for anything that doesn't fit. Enables
  orchestrator automation of conflict detection, merge sequencing, and IMPL doc
  updates without reading prose.

- **Conflict prediction before merge** — `saw-merge.md` now cross-references
  all agents' `files_changed` and `files_created` lists before touching the
  working tree. Disjoint ownership violations surface before `git merge` is
  attempted, not mid-merge. `out_of_scope_deps` lists are also cross-referenced
  for agents that flagged the same file with different required changes.

- **Structured merge procedure** — `saw-merge.md` rewritten as 7 explicit
  steps: parse reports → conflict prediction → review deviations → merge →
  cleanup → post-merge verification → IMPL doc updates. Each step uses
  structured report fields rather than requiring the orchestrator to interpret
  prose.

- **`saw-merge.md` version bump** — v0.2.0 → v0.3.0
- **`agent-template.md` version bump** — v0.2.0 → v0.3.1

## [0.3.0] - 2026-02-28

### Added

- **`/saw bootstrap` subcommand** — Design-first architecture for new projects
  with no existing codebase. The bootstrap scout acts as architect rather than
  analyst: it gathers requirements (language, project type, key concerns), designs
  package structure and interface contracts before any code is written, and
  produces `docs/IMPL-bootstrap.md` with a mandatory Wave 0 (types/interfaces)
  followed by parallel implementation waves. Solves the cold-start problem where
  regular scout has no existing code to analyze.

- **`saw-bootstrap.md`** — Dedicated module implementing the bootstrap procedure:
  requirements gathering, architecture design principles (one concern = one
  package, types-as-foundation, no god files), Wave 0 pattern, output format,
  and rules. Follows the module decomposition pattern established in v0.2.0.

- **Wave 0 pattern formalized** — Bootstrap projects always require a solo types
  wave before any parallel implementation. All shared interfaces and structs are
  defined in a `types` package first; downstream agents implement against these
  contracts without seeing each other's code. Post-Wave-0 gate is build-only
  (no tests yet), unblocking all Wave 1 agents simultaneously.

## [0.2.0] - 2026-02-28

### Changed

- **Decomposed skill prompt into focused modules** — `saw-skill.md` is now a thin router that delegates worktree management to `saw-worktree.md` and merge/verify logic to `saw-merge.md`. Each module is independently testable and debuggable. Previously all orchestration logic (routing, worktree creation, merge handling, conflict detection, diagnostics, progress tracking) was interleaved in a single prompt that assumed deterministic execution of non-deterministic steps.

- **Replaced agent count threshold with complexity-based heuristic** — The suitability gate no longer uses raw agent count (≤2 NOT SUITABLE, ≥5 SUITABLE) as the primary decision criterion. Instead evaluates parallelization value based on: build/test cycle length (>30s favors SAW), files per agent (≥3 favors SAW), agent independence (single wave = max benefit), and task complexity (logic > documentation). The previous threshold was based on a single dogfooding data point (4 documentation-only agents, 88% slower than sequential) that didn't generalize — code-heavy tasks with 2 agents benefited from SAW despite being under the threshold.

- **Added version headers to all prompt files** — Each prompt file now includes a `<!-- filename v0.2.0 -->` comment at the top. Users who copy prompts to `~/.claude/commands/` can compare their copy's version against the repo to detect staleness.

### Added

- **`saw-worktree.md`** — Dedicated module for worktree lifecycle: pre-creation, verification, diagnosis of creation failures (3-tier fallback), agent self-healing explanation, and cleanup. Extracted from saw-skill.md.

- **`saw-merge.md`** — Dedicated module for merge procedure: pre-merge conflict detection, handling committed vs uncommitted agent changes, worktree cleanup, post-merge verification, and IMPL doc updates. Extracted from saw-skill.md.

- **Worktree isolation verification**: SAW orchestrator now checks `git worktree list` after launching agents to verify worktrees were actually created. If count doesn't match (expected N+1 for N agents + main), stops immediately with error. Prevents silent data loss when `isolation: "worktree"` parameter fails to create worktrees. Emerged from brewprune Round 5 Wave 1 where 5 agents were launched but 0 worktrees created - all agents modified main directly. Zero conflicts occurred only due to perfect file disjointness (luck, not safety).

- **Agent self-healing isolation verification**: Agent template now includes mandatory Section 0: pre-flight worktree isolation check with self-healing. Agents first attempt `cd` to expected worktree location (self-correction), then verify pwd, git branch, and worktree existence BEFORE any file modifications. If verification fails after cd attempt, agent writes error to completion report and exits immediately without touching files. Orchestrator detects failures within 10s. This is Layer 1.5 (self-healing) + Layer 2 (strict verification) of defense in depth. Philosophy shift from "detect-only" to "attempt-fix-then-detect" provides redundant protection against Task tool working directory issues while maintaining strict fail-fast behavior. Validated in brewprune Round 5 Wave 2 where agents successfully self-corrected working directory.

- **Out-of-scope conflict detection**: SAW orchestrator now scans all agent completion reports for out-of-scope file changes (section 8) before merging. If multiple agents modified the same out-of-scope file, the orchestrator flags the conflict and prompts the user for resolution. Prevents silent data loss when agents touch files outside their ownership.

- **Performance guidance for test commands**: Scout now provides guidance on focused vs full test runs. For packages with >50 tests, agents use focused tests during waves (`go test ./pkg -run TestSpecific`) while post-merge verification runs the full suite (`go test ./...`). Includes reasonable timeouts (2-5min per package). Keeps agent verification fast while preserving full coverage at merge.

- **Pre-implementation status check**: Scout suitability gate now includes step 4: check each audit finding/requirement against the current codebase to determine implementation status (TO-DO, DONE, PARTIAL). For DONE items, scout adjusts agent prompts to "verify existing implementation and add test coverage" rather than "implement." Prevents wasted compute on already-implemented work.

- **Known Issues section in IMPL template**: Scout now includes a "Known Issues" section in the IMPL doc template where pre-existing test failures, build warnings, or known bugs can be documented. Helps agents distinguish expected failures from regressions. Includes workarounds and tracking links.

- **Justified API-wide changes guidance**: Agent template now explicitly permits out-of-scope modifications when fixing design flaws that require atomic changes. Agents must document all affected files, justify why changes must be atomic (not incremental), and update all call sites consistently. Example: fixing race conditions in shared APIs.

- **Integration test reminder**: Agent template now prompts agents to search for tests expecting OLD behavior when modifying command behavior, exit codes, or error handling. Update related tests BEFORE running verification to prevent post-merge test failures.

### Fixed

- **Scout agent file-writing clarification**: Removed ambiguous "read-only reconnaissance agent" language that caused Plan agents to refuse writing IMPL docs. Now explicitly states: "you do NOT write implementation code, but you MUST write the coordination artifact (IMPL doc) using the Write tool." Prevents agents from returning IMPL content as text instead of writing the file.

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
1. **Parallelization without conflicts** — Disjoint file ownership is a hard constraint
2. **Interface contracts before implementation** — Agents code against specs, not each other
3. **Living coordination artifacts** — Agents append completion reports; downstream agents read updated reality
4. **Post-merge verification as the real gate** — Individual agent success doesn't guarantee integration success
5. **Fail-fast suitability assessment** — Better to identify poor fits early than force decomposition

The protocol evolves through real-world usage. Each experiment surfaces gaps that become improvements.
