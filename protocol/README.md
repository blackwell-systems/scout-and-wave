# Scout-and-Wave Protocol Documentation

This directory contains the implementation-agnostic specification of the Scout-and-Wave (SAW) protocol. These documents define the coordination rules, correctness guarantees, and behavioral contracts that any SAW implementation must satisfy, independent of the runtime or tooling used.

**Intended audience:** Developers implementing SAW in new runtimes (Python, Rust, TypeScript, etc.), humans orchestrating SAW workflows manually, and maintainers of existing implementations verifying protocol compliance.

## Navigation

Read these documents in order to understand the complete protocol:

| Document | Description |
|----------|-------------|
| [participants.md](participants.md) | Defines the four participant roles (Orchestrator, Scout, Scaffold Agent, Wave Agent), their execution modes, responsibilities, and forbidden actions |
| [preconditions.md](preconditions.md) | Lists the five preconditions that must hold before the protocol may run (file decomposition, investigation-first blockers, interface discoverability, pre-implementation scan, parallelization value) |
| [invariants.md](invariants.md) | Specifies the six invariants that must hold throughout protocol execution (worktree isolation, disjoint file ownership, interface freeze, etc.) |
| [execution-rules.md](execution-rules.md) | Defines sixteen execution rules (E1–E16) governing state transitions, agent launches, completion handling, merge procedures, verification gates, IMPL doc lifecycle, and Scout output validation |
| [state-machine.md](state-machine.md) | Documents the protocol state machine: states, transitions, triggers, and termination conditions |
| [message-formats.md](message-formats.md) | Specifies structured message formats for IMPL docs, agent prompts, completion reports, and merge summaries |
| [procedures.md](procedures.md) | Detailed step-by-step procedures for merge operations, conflict resolution, and verification gates |

## Adoption Guide

**To implement SAW in a new runtime:**

1. Read the protocol docs in the order listed in the Navigation table above
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (worktree isolation): git worktrees, filesystem snapshots, containers, etc.
4. Implement the state machine transitions (see [state-machine.md](state-machine.md))
5. Implement structured message parsing (see [message-formats.md](message-formats.md))
6. Verify your implementation satisfies all six invariants (see [invariants.md](invariants.md))
7. Test with a multi-agent feature that meets all five preconditions (see [preconditions.md](preconditions.md))


## Protocol Guarantees

When all preconditions are met and all invariants hold throughout execution, the protocol guarantees:

- **No merge conflicts** between agents working in the same wave
- **Reproducible verification** via agent-specific gates before merge
- **Human checkpoint enforcement** at suitability gate and REVIEWED state
- **Structured failure recovery** via completion reports and orchestrator escalation

See [execution-rules.md](execution-rules.md) for the formal correctness argument.

## Versioning

This protocol specification follows semantic versioning. Breaking changes to invariants, preconditions, or message formats increment the major version. New optional fields or clarifications increment the minor version.

Current version: **0.8.0**

## Reference Implementations

- **Claude Code:** `implementations/claude-code/` — Fully automated implementation using Claude Code's agent runtime and git worktree isolation

Each implementation documents its deviations (if any) from this specification.
