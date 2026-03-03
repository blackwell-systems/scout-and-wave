# Prompts

Reference implementations of the [SAW protocol](../PROTOCOL.md). Each file
maps to a specific participant role or procedure defined in the spec.

## Entry Point

| File | Version | Purpose |
|------|---------|---------|
| [`saw-skill.md`](saw-skill.md) | v0.3.9 | The `/saw` skill router. Install to `~/.claude/commands/saw.md`. Routes `bootstrap`, `scout`, `wave`, `wave --auto`, and `status` commands. Drives all protocol state transitions as the Orchestrator. |

## Participant Prompts

These files are passed as agent content; the Orchestrator reads them and
uses their text as the prompt when launching an asynchronous agent.

| File | Version | Participant | Purpose |
|------|---------|-------------|---------|
| [`scout.md`](scout.md) | v0.3.9 | Scout | Suitability gate (5 questions) + IMPL doc production. Analyzes the codebase, assigns file ownership, defines interface contracts, specifies scaffold file contents in the IMPL doc Scaffolds section, structures waves, and stamps per-agent prompts. Never modifies source files. |
| [`scaffold-agent.md`](scaffold-agent.md) | v0.1.1 | Scaffold Agent | Materializes approved interface contracts as type scaffold source files after human review of the IMPL doc. Runs between Scout and Wave 1. Creates only the files listed in the IMPL doc Scaffolds section, verifies they compile, commits, and updates scaffold status. |
| [`agent-template.md`](agent-template.md) | v0.3.8 | Wave Agent | 9-field prompt template stamped per-agent by the Scout into the IMPL doc. Field 0: isolation verification (mandatory pre-flight). Fields 1–8: file ownership, interfaces, implementation spec, tests, verification gate, constraints, completion report. |

## Procedure Prompts

These files are read by the Orchestrator at runtime to drive its own
behavior. They are not passed to agents; the Orchestrator follows the
instructions in them directly.

| File | Version | When read | Purpose |
|------|---------|-----------|---------|
| [`saw-worktree.md`](saw-worktree.md) | v0.4.3 | Before wave launch | Worktree lifecycle: preflight working tree check, pre-launch ownership verification, interface freeze (including scaffold commit verification), pre-creation, creation verification, failure diagnosis, and post-wave cleanup. |
| [`saw-merge.md`](saw-merge.md) | v0.4.4 | After wave completes | Merge procedure: parse completion reports, conflict prediction, interface deviation review, per-agent merge, worktree cleanup, post-merge verification (linter auto-fix pass + scaffold integrity check), IMPL doc updates, and crash recovery. |

## Variant Prompts

| File | Version | Skill command | Purpose |
|------|---------|---------------|---------|
| [`saw-bootstrap.md`](saw-bootstrap.md) | v0.3.3 | `/saw bootstrap` | Design-first execution for new projects with no existing codebase. Orchestrator reads this and acts as architect: gathers requirements, designs package structure, defines interface contracts, specifies types scaffold in IMPL doc Scaffolds section, and writes `docs/IMPL-bootstrap.md` with parallel implementation waves starting from Wave 1. |

## Protocol Invariants Referenced

Invariants I1–I6 are defined in [`PROTOCOL.md`](../PROTOCOL.md). Where
invariants appear in these prompts, they are embedded verbatim alongside
their I-number so each prompt is self-contained. To audit consistency:

```bash
grep -n "I[1-6]:" prompts/*.md
```
