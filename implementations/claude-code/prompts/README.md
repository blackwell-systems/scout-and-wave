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
└── references/           ← Orchestrator on-demand references (progressive disclosure)
    ├── program-flow.md
    ├── amend-flow.md
    ├── failure-routing.md
    ├── scout-suitability-gate.md       ← Scout agent reference (hook-injected)
    ├── scout-implementation-process.md  ← Scout agent reference (hook-injected)
    └── scout-program-contracts.md       ← Scout agent reference (hook-injected)
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
| [`agents/scout.md`](agents/scout.md) | Scout | Slim identity core (~166 lines). Suitability gate, IMPL production steps, and program contract rules extracted to `references/scout-*.md` and injected by `validate_agent_launch` hook. Cannot edit source files (I6 enforcement). |
| [`agents/wave-agent.md`](agents/wave-agent.md) | Wave Agent | TYPE LAYER shared by all wave agents. Worktree isolation protocol, workflow checklist, session recovery, completion report format. Cannot spawn sub-agents. |
| [`agents/scaffold-agent.md`](agents/scaffold-agent.md) | Scaffold Agent | Materializes approved interface contracts as type scaffold source files. Runs between Scout and Wave 1. Creates only files listed in IMPL doc Scaffolds section. |
| [`agents/integration-agent.md`](agents/integration-agent.md) | Integration Agent | Post-merge wiring agent (E26/E27). Wires unconnected exports into connector files. Runs on main branch after wave merge. |
| [`agents/critic-agent.md`](agents/critic-agent.md) | Critic Agent | Pre-wave brief review (E37). Reads every agent brief, reads every owned file, verifies accuracy across 6 checks. Writes verdict to IMPL doc. Never modifies source files. |
| [`agents/planner.md`](agents/planner.md) | Planner | Program-level planning agent. Produces PROGRAM manifest with tiered IMPL execution plan for `/saw program plan/execute`. |

## Scout Payload Files (root)

These files are **passed by path** to the Scout agent at launch. The Orchestrator
does not read them directly; it includes the path in the Scout's prompt.

| File | When used | Purpose |
|------|-----------|---------|
| [`agent-template.md`](agent-template.md) | Every Scout launch | INSTANCE LAYER reference. Defines the 9-field agent brief structure, isolation verification protocol, YAML completion schema, and protocol constraints. Scout reads this → writes filled briefs into the IMPL doc. Wave agents never read this file directly. |
| [`saw-bootstrap.md`](saw-bootstrap.md) | `/saw bootstrap` only | Bootstrap Scout procedure. Architecture design principles, disjoint ownership patterns, Rust workspace rules, types scaffold specification, and IMPL-bootstrap.yaml output format. |

## On-Demand References (`references/`)

Loaded by the Orchestrator only when the matching subcommand is invoked.
See `docs/skills-progressive-disclosure.md` for the design.

| File | Trigger | Purpose |
|------|---------|---------|
| [`references/program-flow.md`](references/program-flow.md) | `/saw program *` | Program plan/execute/status/replan flow. ~324 lines. Includes lifecycle analogy table and per-subcommand Orchestrator steps. |
| [`references/amend-flow.md`](references/amend-flow.md) | `/saw amend *` | Amend subcommands: `--add-wave`, `--redirect-agent`, `--extend-scope`. |
| [`references/failure-routing.md`](references/failure-routing.md) | Agent failure or post-merge integration gaps | E7a retry context, E19 failure type routing, E19.1 reactions override, E8 interface failures, E20 stub scanning, E25/E26/E35 integration gap detection. |
| [`references/scout-suitability-gate.md`](references/scout-suitability-gate.md) | Scout agent launch (hook-injected) | 5-question suitability checklist. Injected by `validate_agent_launch` into every scout agent prompt. |
| [`references/scout-implementation-process.md`](references/scout-implementation-process.md) | Scout agent launch (hook-injected) | Steps 1-17 for IMPL doc production. Injected by `validate_agent_launch` into every scout agent prompt. |
| [`references/scout-program-contracts.md`](references/scout-program-contracts.md) | Scout agent launch with --program (hook-injected) | Program contract handling rules. Injected by `validate_agent_launch` only when `--program` flag present in prompt. |

## Protocol Invariants Referenced

Invariants I1–I6 are defined in [`protocol/invariants.md`](../protocol/invariants.md). Where
invariants appear in these prompts, they are embedded verbatim alongside
their I-number so each prompt is self-contained. To audit consistency:

```bash
grep -rn "I[1-6]:" prompts/
```
