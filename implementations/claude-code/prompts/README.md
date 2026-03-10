# Prompts

Reference implementations of the SAW protocol. Each file maps to a specific
participant role or procedure defined in the [protocol/](../protocol/) specification.

## Entry Point

| File | Version | Purpose |
|------|---------|---------|
| [`saw-skill.md`](saw-skill.md) | v0.6.0 | The `/saw` skill router. Install to `~/.claude/skills/saw/SKILL.md`. Routes `bootstrap`, `scout`, `wave`, `wave --auto`, and `status` commands. Drives all protocol state transitions as the Orchestrator. YAML mode uses SDK CLI commands (`saw run-gates`, `saw mark-complete`, `saw check-conflicts`, `saw validate-scaffolds`, `saw freeze-check`, `saw update-agent-prompt`). |

## Participant Prompts

These files are passed as agent content; the Orchestrator reads them and
uses their text as the prompt when launching an asynchronous agent.

| File | Version | Participant | Purpose |
|------|---------|-------------|---------|
| [`scout.md`](scout.md) | v0.4.0 | Scout | Suitability gate (5 questions) + IMPL doc production. Analyzes the codebase, assigns file ownership, defines interface contracts, specifies scaffold file contents in the IMPL doc Scaffolds section, structures waves, and stamps per-agent prompts. Never modifies source files. |
| [`scaffold-agent.md`](scaffold-agent.md) | v0.1.2 | Scaffold Agent | Materializes approved interface contracts as type scaffold source files after human review of the IMPL doc. Runs between Scout and Wave 1. Creates only the files listed in the IMPL doc Scaffolds section, verifies they compile, commits, and updates scaffold status. |
| [`agent-template.md`](agent-template.md) | v0.3.8 | Wave Agent | 9-field prompt template stamped per-agent by the Scout into the IMPL doc. Field 0: isolation verification (mandatory pre-flight). Fields 1–8: file ownership, interfaces, implementation spec, tests, verification gate, constraints, completion report. |

## Procedure Prompts

These files are read by the Orchestrator at runtime to drive its own
behavior. They are not passed to agents; the Orchestrator follows the
instructions in them directly.

| File | Version | When read | Purpose |
|------|---------|-----------|---------|
| [`saw-worktree.md`](saw-worktree.md) | v0.5.1 | Before wave launch | Worktree lifecycle: preflight working tree check, pre-launch ownership verification, interface freeze (including scaffold commit verification via `saw validate-scaffolds` and `saw freeze-check`), pre-creation, creation verification, failure diagnosis, and post-wave cleanup. |
| [`saw-merge.md`](saw-merge.md) | v0.5.0 | After wave completes | Merge procedure: parse completion reports, conflict prediction (via `saw check-conflicts`), interface deviation review, quality gates (via `saw run-gates`), per-agent merge, worktree cleanup, post-merge verification (linter auto-fix pass + scaffold integrity check via `saw validate-scaffolds`), IMPL doc updates, and crash recovery. |

## Variant Prompts

| File | Version | Skill command | Purpose |
|------|---------|---------------|---------|
| [`saw-bootstrap.md`](saw-bootstrap.md) | v0.3.4 | `/saw bootstrap` | Design-first execution for new projects with no existing codebase. Orchestrator reads this and acts as architect: gathers requirements, designs package structure, defines interface contracts, specifies types scaffold in IMPL doc Scaffolds section, and writes `docs/IMPL/IMPL-bootstrap.md` with parallel implementation waves starting from Wave 1. |

## Protocol Invariants Referenced

Invariants I1–I6 are defined in [`protocol/invariants.md`](../protocol/invariants.md). Where
invariants appear in these prompts, they are embedded verbatim alongside
their I-number so each prompt is self-contained. To audit consistency:

```bash
grep -n "I[1-6]:" prompts/*.md
```
