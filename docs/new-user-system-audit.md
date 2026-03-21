# Scout-and-Wave: New User System Audit

**Date:** 2026-03-19
**Scope:** Full system across all 3 repos — installation, CLI, /saw skill, agent prompts, docs, cross-repo friction, error recovery, competitive positioning.

---

## Critical Gaps

1. **Prerequisites assumed, not validated** — No pre-flight check when `/saw` is invoked. Missing sawtools → cryptic "command not found".
2. **No unified entry point** — Three tools (skill, web UI, CLI) with no decision tree. User doesn't know which to install first.
3. **sawtools binary build/install instructions missing** — Protocol repo never mentions building sawtools. Users clone scout-and-wave, try `/saw scout`, fail.
4. **Cross-repo dependency is silent** — No explicit "Repo X depends on Repo Y" matrix. Users clone incomplete set.
5. **Install script doesn't verify completeness** — Says "Installation complete!" without checking sawtools is on PATH or skill loads.
6. **No getting-started for web app or CLI** — QUICKSTART.md is 100% Claude Code skill focused.
7. **Error messages are technical jargon** — E16, I1, E21A codes with no plain-language explanation.
8. **No cross-repo troubleshooting guide** — When something fails, users don't know which repo has the bug.

## High-Impact Improvements

| # | Improvement | Effort | Impact |
|---|-------------|--------|--------|
| 1 | Decision tree entry point (GETTING_STARTED.md) | 2h | Eliminates "which tool?" confusion |
| 2 | Cross-repo installation guide (INSTALLATION.md) | 3-4h | First install: 30 min → 5 min |
| 3 | Pre-flight diagnostics in saw-skill.md | 2-3h | Self-diagnose 80% of setup issues |
| 4 | Web app walkthrough (QUICKSTART-WEB.md) | 3-4h | Web users get guided experience |
| 5 | CLI walkthrough (QUICKSTART-CLI.md) | 3-4h | CLI users get guided experience |
| 6 | Error message translation layer | 4-5h | Users understand errors |
| 7 | Hook system documentation | 1-2h | Users understand safety guardrails |
| 8 | "Which tool failed?" diagnostic command | 3-4h | Self-service debugging |

## Polish Items

- `/saw verify` or `sawtools verify-install` command
- Fix install.sh "Next steps" to include exact JSON snippet for permissions
- Quick links / "Stuck?" section in all READMEs
- Visual diagram of three-repo dependency graph
- Document symlink model
- Add inline examples to CLI help texts

## What's Already Good

- QUICKSTART.md for Claude Code skill is excellent (step-by-step, expected output, troubleshooting)
- Protocol spec is thorough and language-agnostic
- /saw skill prompt is comprehensive with edge case coverage
- Agent type separation (scout, wave-agent, scaffold-agent) provides structural enforcement
- Error recovery in QUICKSTART.md is honest and helpful
- Cross-repo pattern documented in project memory

## Competitive Analysis

**Strong vs Cursor/Windsurf/Copilot Workspace:**
- Formal protocol with invariants (rigorous, not ad-hoc)
- Disjoint file ownership (no merge conflicts by construction — unique)
- Interface contracts as first-class (scaffold/freeze model)

**Weak vs competitors:**
- Setup complexity (20+ min vs one-click)
- Documentation fragmentation (3 repos, 3 READMEs)
- No in-app help or first-run wizard
- Three different CLIs (saw vs sawtools vs /saw)
- Error messages reference protocol codes not plain English

## Priority Order

**Tier 1 (block 80% of setup failures):** INSTALLATION.md, GETTING_STARTED.md, pre-flight diagnostics
**Tier 2 (improve all paths):** Web walkthrough, CLI walkthrough, error translation
**Tier 3 (perception polish):** Verify command, visual diagrams, help examples
**Tier 4 (documentation debt):** ARCHITECTURE.md, hook system README

**Total estimated effort for full fix:** 25-30 hours
