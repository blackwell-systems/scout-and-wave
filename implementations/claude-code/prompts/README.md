# Prompts

Reference implementations of the SAW protocol. Each file maps to a specific
participant role or procedure defined in the [protocol/](../protocol/) specification.

## Directory Structure

```
prompts/
├── saw-skill.md          ← Orchestrator skill (entry point)
├── saw-bootstrap.md      ← Bootstrap Scout procedure
├── agent-template.md     ← Wave agent brief specification (Scout reference)
├── agents/               ← Agent type definitions (tool restrictions + behavior)
│   ├── scout.md
│   ├── wave-agent.md
│   ├── scaffold-agent.md
│   ├── integration-agent.md
│   ├── critic-agent.md
│   └── planner.md
└── references/           ← On-demand references (11 files, progressive disclosure)
    ├── amend-flow.md
    ├── failure-routing.md
    ├── impl-targeting.md
    ├── integration-gap-detection.md
    ├── model-selection.md
    ├── pre-wave-validation.md
    ├── program-flow.md
    ├── scout-program-contracts.md       ← Scout agent reference (conditionally injected)
    ├── wave-agent-build-diagnosis.md     ← Wave agent reference (conditionally injected)
    ├── wave-agent-contracts.md
    └── wave-agent-program-contracts.md   ← Wave agent reference (conditionally injected)
```

## Entry Point

| File | Purpose |
|------|---------|
| [`saw-skill.md`](saw-skill.md) | The `/saw` skill body. Loaded on every `/saw` invocation. Drives all protocol state transitions as the Orchestrator. Uses `sawtools prepare-wave`, `sawtools finalize-wave`, `sawtools close-impl` for orchestration operations. Routes: `scout`, `wave`, `wave --auto`, `status`, `bootstrap`, `interview`. On-demand routing to `references/` for `program`, `amend`, and failure handling. |

## Agent Type Definitions (`agents/`)

Custom Claude Code agent types. Each file carries YAML frontmatter that Claude Code
uses to enforce tool restrictions and behavioral invariants. Launched via
`subagent_type:` — the Orchestrator does not pass the file content directly.

| File | Agent | Purpose |
|------|-------|---------|
| [`agents/scout.md`](agents/scout.md) | Scout | Self-contained agent definition (~780 lines). Includes suitability gate, IMPL production steps. Program contract rules conditionally injected from `references/scout-program-contracts.md`. Cannot edit source files (I6 enforcement). |
| [`agents/wave-agent.md`](agents/wave-agent.md) | Wave Agent | Self-contained agent definition (~320 lines). Includes worktree isolation protocol, completion report reference. Build diagnosis and program contract rules conditionally injected from `references/wave-agent-*.md`. Cannot spawn sub-agents. |
| [`agents/scaffold-agent.md`](agents/scaffold-agent.md) | Scaffold Agent | Materializes approved interface contracts as type scaffold source files. Runs between Scout and Wave 1. Creates only files listed in IMPL doc Scaffolds section. |
| [`agents/integration-agent.md`](agents/integration-agent.md) | Integration Agent | Self-contained agent definition (~233 lines). Post-merge wiring agent (E26/E27). Wires unconnected exports into connector files. Runs on main branch after wave merge. |
| [`agents/critic-agent.md`](agents/critic-agent.md) | Critic Agent | Self-contained agent definition (~210 lines). Includes verification checks (7 checks) and completion format. Never modifies source files. |
| [`agents/planner.md`](agents/planner.md) | Planner | Self-contained agent definition (~555 lines). Includes suitability gate, implementation process, and example manifest. Produces PROGRAM manifests only. |

## Scout Payload Files (root)

These files are **passed by path** to the Scout agent at launch. The Orchestrator
does not read them directly; it includes the path in the Scout's prompt.

| File | When used | Purpose |
|------|-----------|---------|
| [`agent-template.md`](agent-template.md) | Every Scout launch | INSTANCE LAYER reference. Defines the 9-field agent brief structure, isolation verification protocol, YAML completion schema, and protocol constraints. Scout reads this → writes filled briefs into the IMPL doc. Wave agents never read this file directly. |
| [`saw-bootstrap.md`](saw-bootstrap.md) | `/saw bootstrap` only | Bootstrap Scout procedure. Architecture design principles, disjoint ownership patterns, Rust workspace rules, types scaffold specification, and IMPL-bootstrap.yaml output format. |

## On-Demand References (`references/`)

Loaded by the Orchestrator only when the matching subcommand is invoked, or conditionally injected by the `inject-agent-context` script at agent launch time.
See `docs/skills-progressive-disclosure.md` for the design.

### Orchestrator References (skill-loaded)

| File | Trigger | Purpose |
|------|---------|---------|
| [`references/program-flow.md`](references/program-flow.md) | `/saw program *` | Program plan/execute/status/replan flow. ~324 lines. Includes lifecycle analogy table and per-subcommand Orchestrator steps. |
| [`references/amend-flow.md`](references/amend-flow.md) | `/saw amend *` | Amend subcommands: `--add-wave`, `--redirect-agent`, `--extend-scope`. |
| [`references/failure-routing.md`](references/failure-routing.md) | Agent failure or post-merge integration gaps | E7a retry context, E19 failure type routing, E19.1 reactions override, E8 interface failures, E20 stub scanning, E25/E26/E35 integration gap detection. |
| [`references/impl-targeting.md`](references/impl-targeting.md) | `/saw wave --impl`, `/saw status --impl` | IMPL doc targeting and resume logic. Supports slug, filename, or path resolution. |
| [`references/model-selection.md`](references/model-selection.md) | All agent launches | Model selection hierarchy (skill argument → config file → parent session). Config file lookup order and saw.config.json schema. |
| [`references/pre-wave-validation.md`](references/pre-wave-validation.md) | `/saw wave` | E16 IMPL validation, E37 critic gate, E21A baseline verification. Pre-flight validation sequence before worktree creation. |
| [`references/wave-agent-contracts.md`](references/wave-agent-contracts.md) | `/saw wave` | I1/I2/I5/E35/E42 protocol rules. Disjoint ownership enforcement, interface freeze contracts, commit requirements, wiring obligations. |

### Agent References (conditionally injected)

| File | Trigger | Purpose |
|------|---------|---------|
| [`references/scout-program-contracts.md`](references/scout-program-contracts.md) | Scout agent launch with `--program` in prompt | Program contract handling rules. Injected by `validate_agent_launch` only when `--program` flag present in prompt. |
| [`references/wave-agent-build-diagnosis.md`](references/wave-agent-build-diagnosis.md) | Wave agent launch with `baseline_verification_failed` in prompt | H7 build failure diagnosis tool usage (all languages). Injected by `validate_agent_launch` only when baseline verification has failed. |
| [`references/wave-agent-program-contracts.md`](references/wave-agent-program-contracts.md) | Wave agent launch with `frozen_contracts` in prompt | Program contract handling rules. Injected by `validate_agent_launch` only when `frozen_contracts_hash` or `frozen: true` present in prompt. |

## Protocol Invariants Referenced

Invariants I1–I6 are defined in [`protocol/invariants.md`](../protocol/invariants.md). Where
invariants appear in these prompts, they are embedded verbatim alongside
their I-number so each prompt is self-contained. To audit consistency:

```bash
grep -rn "I[1-6]:" prompts/
```
