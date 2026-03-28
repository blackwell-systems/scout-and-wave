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
    ├── scout-program-contracts.md       ← Scout agent reference (hook-injected)
    ├── wave-agent-worktree-isolation.md  ← Wave agent reference (hook-injected)
    ├── wave-agent-completion-report.md   ← Wave agent reference (hook-injected)
    ├── wave-agent-build-diagnosis.md     ← Wave agent reference (hook-injected)
    ├── wave-agent-program-contracts.md   ← Wave agent reference (hook-injected, frozen contracts only)
    ├── critic-agent-verification-checks.md  ← Critic agent reference (hook-injected)
    ├── critic-agent-completion-format.md    ← Critic agent reference (hook-injected)
    ├── planner-suitability-gate.md          ← Planner agent reference (hook-injected)
    ├── planner-implementation-process.md    ← Planner agent reference (hook-injected)
    ├── planner-example-manifest.md          ← Planner agent reference (hook-injected)
    ├── integration-connectors-reference.md  ← Integration agent reference (hook-injected)
    └── integration-agent-completion-report.md ← Integration agent reference (hook-injected)
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
| [`agents/wave-agent.md`](agents/wave-agent.md) | Wave Agent | Slim identity core (~133 lines). Worktree isolation protocol, completion report reference, build diagnosis, and program contract rules extracted to `references/wave-agent-*.md` and injected by `validate_agent_launch` hook. Cannot spawn sub-agents. |
| [`agents/scaffold-agent.md`](agents/scaffold-agent.md) | Scaffold Agent | Materializes approved interface contracts as type scaffold source files. Runs between Scout and Wave 1. Creates only files listed in IMPL doc Scaffolds section. |
| [`agents/integration-agent.md`](agents/integration-agent.md) | Integration Agent | Post-merge wiring agent (E26/E27). Wires unconnected exports into connector files. Runs on main branch after wave merge. |
| [`agents/critic-agent.md`](agents/critic-agent.md) | Critic Agent | Slim identity core (~75 lines). Verification checks (7 checks) and completion format extracted to `references/critic-agent-*.md` and injected by `validate_agent_launch` hook. Never modifies source files. |
| [`agents/planner.md`](agents/planner.md) | Planner | Slim identity core (~148 lines). Suitability gate, implementation process, and example manifest extracted to `references/planner-*.md` and injected by `validate_agent_launch` hook. Produces PROGRAM manifests only. |

## Scout Payload Files (root)

These files are **passed by path** to the Scout agent at launch. The Orchestrator
does not read them directly; it includes the path in the Scout's prompt.

| File | When used | Purpose |
|------|-----------|---------|
| [`agent-template.md`](agent-template.md) | Every Scout launch | INSTANCE LAYER reference. Defines the 9-field agent brief structure, isolation verification protocol, YAML completion schema, and protocol constraints. Scout reads this → writes filled briefs into the IMPL doc. Wave agents never read this file directly. |
| [`saw-bootstrap.md`](saw-bootstrap.md) | `/saw bootstrap` only | Bootstrap Scout procedure. Architecture design principles, disjoint ownership patterns, Rust workspace rules, types scaffold specification, and IMPL-bootstrap.yaml output format. |

## On-Demand References (`references/`)

Loaded by the Orchestrator only when the matching subcommand is invoked, or injected by hooks at agent launch time.
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

### Agent References (hook-injected)

| File | Trigger | Purpose |
|------|---------|---------|
| [`references/scout-suitability-gate.md`](references/scout-suitability-gate.md) | Scout agent launch (hook-injected) | 5-question suitability checklist. Injected by `validate_agent_launch` into every scout agent prompt. |
| [`references/scout-implementation-process.md`](references/scout-implementation-process.md) | Scout agent launch (hook-injected) | Steps 1-17 for IMPL doc production. Injected by `validate_agent_launch` into every scout agent prompt. |
| [`references/scout-program-contracts.md`](references/scout-program-contracts.md) | Scout agent launch with --program (hook-injected) | Program contract handling rules. Injected by `validate_agent_launch` only when `--program` flag present in prompt. |
| [`references/wave-agent-worktree-isolation.md`](references/wave-agent-worktree-isolation.md) | Wave agent launch (hook-injected) | Worktree isolation protocol (E43 hook-based enforcement, environment variables, absolute path patterns, go.mod warning). Injected by `validate_agent_launch` into every wave agent prompt. |
| [`references/wave-agent-completion-report.md`](references/wave-agent-completion-report.md) | Wave agent launch (hook-injected) | Full `sawtools set-completion` reference with examples for all status/failure types. Injected by `validate_agent_launch` into every wave agent prompt. |
| [`references/wave-agent-build-diagnosis.md`](references/wave-agent-build-diagnosis.md) | Wave agent launch (hook-injected) | H7 build failure diagnosis tool usage (all languages). Injected by `validate_agent_launch` into every wave agent prompt. |
| [`references/wave-agent-program-contracts.md`](references/wave-agent-program-contracts.md) | Wave agent launch with frozen contracts (hook-injected) | Program contract handling rules. Injected by `validate_agent_launch` only when `frozen_contracts_hash` or `frozen: true` present in prompt. |
| [`references/critic-agent-verification-checks.md`](references/critic-agent-verification-checks.md) | Critic agent launch (hook-injected) | Verification checks procedure for critic agents. Injected by `validate_agent_launch` into every critic agent prompt. |
| [`references/critic-agent-completion-format.md`](references/critic-agent-completion-format.md) | Critic agent launch (hook-injected) | `sawtools set-critic-review` command reference and output format. Injected by `validate_agent_launch` into every critic agent prompt. |
| [`references/planner-suitability-gate.md`](references/planner-suitability-gate.md) | Planner agent launch (hook-injected) | 4-question program suitability gate with verdicts and time estimate format. Injected by `validate_agent_launch` into every planner agent prompt. |
| [`references/planner-implementation-process.md`](references/planner-implementation-process.md) | Planner agent launch (hook-injected) | Steps 1-10 for analyzing the project and producing the PROGRAM manifest. Injected by `validate_agent_launch` into every planner agent prompt. |
| [`references/planner-example-manifest.md`](references/planner-example-manifest.md) | Planner agent launch (hook-injected) | Complete annotated example PROGRAM manifest for a fictional project. Injected by `validate_agent_launch` into every planner agent prompt. |
| [`references/integration-connectors-reference.md`](references/integration-connectors-reference.md) | Integration agent launch (hook-injected) | Background on integration_connectors, AllowedPathPrefixes, type: integration waves, and common wiring patterns. Injected by `validate_agent_launch` into every integration agent prompt. |
| [`references/integration-agent-completion-report.md`](references/integration-agent-completion-report.md) | Integration agent launch (hook-injected) | `sawtools set-completion` command examples for complete and partial status. Injected by `validate_agent_launch` into every integration agent prompt. |

## Protocol Invariants Referenced

Invariants I1–I6 are defined in [`protocol/invariants.md`](../protocol/invariants.md). Where
invariants appear in these prompts, they are embedded verbatim alongside
their I-number so each prompt is self-contained. To audit consistency:

```bash
grep -rn "I[1-6]:" prompts/
```
