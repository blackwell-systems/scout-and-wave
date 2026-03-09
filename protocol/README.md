# Scout-and-Wave Protocol Documentation

This directory contains the implementation-agnostic specification of the Scout-and-Wave (SAW) protocol. These documents define the coordination rules, correctness guarantees, and behavioral contracts that any SAW implementation must satisfy, independent of the runtime or tooling used.

**Intended audience:** Developers implementing SAW in new runtimes (Python, Rust, TypeScript, etc.), humans orchestrating SAW workflows manually, and maintainers of existing implementations verifying protocol compliance.

## Navigation

Read these documents in order to understand the complete protocol:

| Document | Description |
|----------|-------------|
| [participants.md](participants.md) | Defines the four participant roles (Orchestrator, Scout, Scaffold Agent, Wave Agent), their execution modes, responsibilities, and forbidden actions |
| [preconditions.md](preconditions.md) | Lists the five preconditions that must hold before the protocol may run (file decomposition, investigation-first blockers, interface discoverability, pre-implementation scan, parallelization value) |
| [invariants.md](invariants.md) | Specifies the six invariants that must hold throughout protocol execution (disjoint file ownership, interface contracts precede parallel implementation, wave sequencing, etc.) |
| [execution-rules.md](execution-rules.md) | Defines twenty-three execution rules (E1–E23) governing state transitions, agent launches, completion handling, automatic failure remediation in --auto mode (E7a), merge procedures, verification gates, IMPL doc lifecycle, Scout output validation, project memory lifecycle (E17/E18), failure taxonomy (E19), stub detection (E20), post-wave quality gates (E21), scaffold build verification (E22), and per-agent context extraction (E23) |
| [state-machine.md](state-machine.md) | Documents the protocol state machine: states, transitions, triggers, and termination conditions |
| [message-formats.md](message-formats.md) | Specifies structured message formats for IMPL docs, agent prompts, completion reports, and merge summaries |
| [procedures.md](procedures.md) | Step-by-step procedures for all protocol phases: Scout, Scaffold Agent, wave execution, merge, inter-wave checkpoint, and protocol completion |

## Adoption Guide

**To implement SAW in a new runtime:**

1. Read the protocol docs in the order listed in the Navigation table above
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (disjoint file ownership): git worktrees, filesystem snapshots, containers, etc.
4. Implement the state machine transitions (see [state-machine.md](state-machine.md))
5. Implement structured message parsing (see [message-formats.md](message-formats.md))
6. Verify your implementation satisfies all six invariants (see [invariants.md](invariants.md))
7. Test with a multi-agent feature that meets all five preconditions (see [preconditions.md](preconditions.md))


## Protocol Guarantees

When all preconditions are met and all invariants hold throughout execution, the protocol guarantees:

- **No merge conflicts** between agents working in the same wave
- **Reproducible verification** via agent-specific gates before merge
- **Human checkpoint enforcement** at suitability gate and REVIEWED state
- **Structured failure recovery** via completion reports, `failure_type` taxonomy (E19), and orchestrator escalation
- **Project memory accumulation** via `docs/CONTEXT.md` — Scout reads accumulated context (E17), Orchestrator updates it after each feature (E18)
- **Post-wave quality enforcement** via stub detection (E20) and automated quality gates (E21)
- **Interface build safety** via Scaffold Agent build verification before wave launch (E22)

See [execution-rules.md](execution-rules.md) for the formal correctness argument.

## Versioning

This protocol specification follows semantic versioning. Breaking changes to invariants, preconditions, or message formats increment the major version. New optional fields or clarifications increment the minor version.

Current version: **0.14.8**

## Reference Implementations

- **Claude Code:** `implementations/claude-code/` — Fully automated implementation using Claude Code's agent runtime and git worktree isolation

Each implementation documents its deviations (if any) from this specification.
