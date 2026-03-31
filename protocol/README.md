# Scout-and-Wave Protocol Documentation

This directory contains the implementation-agnostic specification of the Scout-and-Wave (SAW) protocol. These documents define the coordination rules, correctness guarantees, and behavioral contracts that any SAW implementation must satisfy, independent of the runtime or tooling used.

**Intended audience:** Developers implementing SAW in new runtimes (Python, Rust, TypeScript, etc.), humans orchestrating SAW workflows manually, and maintainers of existing implementations verifying protocol compliance.

## Navigation

Read these documents in order to understand the complete protocol:

| Document | Description |
|----------|-------------|
| [participants.md](participants.md) | Defines the seven participant roles (Orchestrator, Scout, Scaffold Agent, Wave Agent, Integration Agent, Critic Agent, Planner), their execution modes, responsibilities, and forbidden actions |
| [preconditions.md](preconditions.md) | Lists the five preconditions that must hold before the protocol may run (file decomposition, investigation-first blockers, interface discoverability, pre-implementation scan, parallelization value) |
| [invariants.md](invariants.md) | Specifies the six invariants that must hold throughout protocol execution (disjoint file ownership, interface contracts precede parallel implementation, wave sequencing, etc.) |
| [execution-rules.md](execution-rules.md) | Defines forty-nine execution rules (E1–E45, including sub-rules) governing state transitions, agent launches, completion handling, automatic failure remediation in --auto mode (E7a), manual merge escape hatch (E11a), merge procedures, verification gates, IMPL doc lifecycle, Scout output validation, project memory lifecycle (E17/E18), failure taxonomy (E19), stub detection (E20), post-wave quality gates (E21/E21A/E21B), scaffold build verification (E22), per-agent context extraction (E23/E23A), integration validation (E25), integration agent (E26), planned integration waves (E27), program execution tiers and invariants (E28/E28A/E28B–E34), wiring obligation (E35), IMPL amendment (E36), critic gate (E37), gate caching (E38), interview mode (E39), observability events (E40), type collision detection (E41), SubagentStop validation (E42), hook-based isolation enforcement (E43), context injection observability (E44), and shared data structure scaffold detection (E45) |
| [state-machine.md](state-machine.md) | Documents the protocol state machine: states, transitions, triggers, and termination conditions |
| [message-formats.md](message-formats.md) | Specifies structured message formats for IMPL docs, agent prompts, completion reports, and merge summaries |
| [procedures.md](procedures.md) | Step-by-step procedures for all protocol phases: Scout, Scaffold Agent, wave execution, merge, inter-wave checkpoint, and protocol completion |
| [interview-mode.md](interview-mode.md) | E39: Structured interview mode for deterministic requirements gathering as an alternative to Scout |
| [observability-events.md](observability-events.md) | E40: Observability event emission schema (cost, agent performance, orchestrator activity) |
| [program-invariants.md](program-invariants.md) | P1–P5: Program-level invariants for multi-IMPL coordination across tiered execution |
| [program-manifest.md](program-manifest.md) | PROGRAM manifest schema specification for coordinating multiple IMPLs into tiered execution |
| [impl-manifest.schema.json](impl-manifest.schema.json) | JSON Schema for IMPL manifest validation (waves, agents, file ownership, completion reports) |

## Adoption Guide

**To implement SAW in a new runtime:**

1. Read the protocol docs in the order listed in the Navigation table above
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (disjoint file ownership): git worktrees, filesystem snapshots, containers, etc.
4. Implement the state machine transitions (see [state-machine.md](state-machine.md))
5. Implement structured message parsing (see [message-formats.md](message-formats.md))
6. Verify your implementation satisfies all six invariants (see [invariants.md](invariants.md))
7. Test with a multi-agent feature that meets all five preconditions (see [preconditions.md](preconditions.md))

**Beyond single-feature execution:**

- **Program-level execution:** For coordinating multiple features, implement PROGRAM manifests with the Planner agent and tier-gated progression (E28–E34). See [program-manifest.md](program-manifest.md) and [program-invariants.md](program-invariants.md).
- **Interview mode (E39):** An alternative entry point where the orchestrator conducts structured requirements gathering before producing an IMPL doc. See [interview-mode.md](interview-mode.md).
- **Integration validation (E25/E26):** After wave merges, the Integration Agent verifies cross-agent wiring correctness. Implement integration waves (E27) for planned integration steps.
- **Critic gate (E37):** Before launching a wave, the Critic Agent reviews agent briefs and can request revisions. This catches file ownership conflicts and missing context before agents start work.
- **Observability (E40):** Emit structured events for cost tracking, agent performance, and orchestrator activity. See [observability-events.md](observability-events.md).
- **SubagentStop validation (E42):** Enforce that agents use the designated stop mechanism on completion rather than silently exiting, ensuring completion reports are always captured.


## Protocol Guarantees

When all preconditions are met and all invariants hold throughout execution, the protocol guarantees:

- **No merge conflicts** between agents working in the same wave
- **Reproducible verification** via agent-specific gates before merge
- **Human checkpoint enforcement** at suitability gate and REVIEWED state
- **Structured failure recovery** via completion reports, `failure_type` taxonomy (E19), and orchestrator escalation
- **Project memory accumulation** via `docs/CONTEXT.md` — Scout reads accumulated context (E17), Orchestrator updates it after each feature (E18)
- **Post-wave quality enforcement** via stub detection (E20) and automated quality gates (E21)
- **Interface build safety** via Scaffold Agent build verification before wave launch (E22)
- **Mechanical isolation enforcement** via lifecycle hooks (E43) — isolation violations prevented at tool boundary rather than detected after-the-fact

See [execution-rules.md](execution-rules.md) for the formal correctness argument.

## Versioning

This protocol specification follows semantic versioning. Breaking changes to invariants, preconditions, or message formats increment the major version. New optional fields or clarifications increment the minor version.

Current version: **0.76.0**

**Changelog:**
- **0.58.0** — E43 hook-based isolation enforcement: lifecycle hooks (SubagentStart, PreToolUse:Bash, PreToolUse:Write/Edit, SubagentStop) mechanically prevent isolation violations at tool boundary; procedures.md updated with E43 enforcement note; README.md isolation defense updated to 6 layers with E43 as primary prevention mechanism; protocol guarantees updated with mechanical isolation enforcement
- **0.57.0** — Comprehensive protocol-to-engine audit: state-machine.md aligned with Go allowedTransitions (8 gaps fixed: REVIEWED->WAVE_EXECUTING, SCAFFOLD_PENDING->WAVE_EXECUTING, WAVE_EXECUTING->COMPLETE, WAVE_VERIFIED->WAVE_EXECUTING, WAVE_VERIFIED->BLOCKED, BLOCKED->REVIEWED, SCOUT_PENDING->REVIEWED direct); impl-manifest.schema.json aligned with Go types (added wiring, wiring_validation_reports, integration_reports, integration_connectors, integration_gap_severity_threshold, reactions, critic_report, dedup_stats, feature, repository, repositories, plan_reference, suitability_reasoning; QualityGate gains fix/timing/format; Wave gains type field); procedures.md worktree paths updated to slug-based E5 naming; message-formats.md adds missing root-level manifest fields; program-manifest.md REPLANNING state marked as not-yet-implemented in SDK
- **0.56.0** — E11a manual merge escape hatch, E37 enforcement in prepare-wave, critic action:new awareness
- **0.55.0** — Previous release

## Reference Implementations

- **Claude Code:** `implementations/claude-code/` — Fully automated implementation using Claude Code's agent runtime and git worktree isolation

Each implementation documents its deviations (if any) from this specification.
