# Changelog

All notable changes to the Scout-and-Wave pattern will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Out-of-scope conflict detection** (2026-02-28): SAW orchestrator now scans all agent completion reports for out-of-scope file changes (section 8) before merging. If multiple agents modified the same out-of-scope file, the orchestrator flags the conflict and prompts the user for resolution. Prevents silent data loss when agents touch files outside their ownership. ([commit cb003ce](https://github.com/anthropics/scout-and-wave/commit/cb003ce))

- **Performance guidance for test commands** (2026-02-28): Scout now provides guidance on focused vs full test runs. For packages with >50 tests, agents use focused tests during waves (`go test ./pkg -run TestSpecific`) while post-merge verification runs the full suite (`go test ./...`). Includes reasonable timeouts (2-5min per package). Keeps agent verification fast while preserving full coverage at merge. ([commit cb003ce](https://github.com/anthropics/scout-and-wave/commit/cb003ce))

- **Pre-implementation status check** (2026-02-28): Scout suitability gate now includes step 4: check each audit finding/requirement against the current codebase to determine implementation status (TO-DO, DONE, PARTIAL). For DONE items, scout adjusts agent prompts to "verify existing implementation and add test coverage" rather than "implement." Prevents wasted compute on already-implemented work. ([commit cb003ce](https://github.com/anthropics/scout-and-wave/commit/cb003ce))

### Fixed
- **Scout agent file-writing clarification** (2026-02-28): Removed ambiguous "read-only reconnaissance agent" language that caused Plan agents to refuse writing IMPL docs. Now explicitly states: "you do NOT write implementation code, but you MUST write the coordination artifact (IMPL doc) using the Write tool." Prevents agents from returning IMPL content as text instead of writing the file. ([commit 5d8c980](https://github.com/anthropics/scout-and-wave/commit/5d8c980))

## [0.1.0] - 2026-02-27

Initial release of Scout-and-Wave pattern based on lessons learned from brewprune UX audit experiments.

### Added
- Scout agent prompt for dependency mapping and coordination artifact generation
- 8-field agent prompt template
- `/saw` skill for Claude Code with `check`, `scout`, `wave`, and `status` commands
- Suitability gate with 3-question assessment (file decomposition, investigation items, interface discoverability)
- Wave execution loop with post-merge verification
- Living coordination artifact pattern (agents append completion reports)

### Pattern Improvements from Brewprune Experiments

**Lessons from Round 3 (19 findings, 11 parallel agents):**
- 5 of 11 agents found work pre-implemented → Added pre-implementation check (step 4)
- Agent E/C had out-of-scope conflict in quickstart.go → Added conflict detection (step 4)
- Test suite timeouts during agent verification → Added performance guidance for focused tests
- Agent F's test had incorrect expectations → Identified need for test quality validation (future work)

**Observed:** The audit-fix-audit cycle works well. Scout-and-wave accelerates the "fix" phase by enabling parallel agent execution. Cold-start audits remain the source of truth for UX quality validation.

## Pattern Philosophy

Scout-and-wave is optimized for:
1. **Parallelization without conflicts** — Disjoint file ownership is a hard constraint
2. **Interface contracts before implementation** — Agents code against specs, not each other
3. **Living coordination artifacts** — Agents append completion reports; downstream agents read updated reality
4. **Post-merge verification as the real gate** — Individual agent success doesn't guarantee integration success
5. **Fail-fast suitability assessment** — Better to identify poor fits early than force decomposition

The pattern evolves through real-world usage. Each experiment surfaces gaps that become improvements.
