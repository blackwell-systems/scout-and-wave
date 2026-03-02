# SAW in the Ecosystem

Where scout-and-wave sits in the parallel AI coding landscape, and why
the protocol layer is the one that matters. Last updated March 2026.

## The Layer Nobody Else Occupies

Multiple AI agents working on the same codebase produce merge conflicts,
contradictory implementations, and expensive rework. Every tool in the
ecosystem has a response to this. But they all respond at the same two
layers: **mechanism** (how to run agents in parallel) and **infrastructure**
(how to manage the logistics). Nobody answers the prior question:

**Should you parallelize this at all? And if so, how do you guarantee the
agents won't conflict?**

That's the layer SAW operates at. It's the only tool in the ecosystem that
treats "don't parallelize this" as a first-class outcome, and the only one
that proves conflict-freedom at planning time rather than discovering
conflicts at merge time.

## The Ecosystem — and What's Missing from Each Layer

### Agent Runtimes (OpenClaw, OpenFang)

[OpenClaw](https://openclaw.ai/) and [OpenFang](https://openfang.app/) are
autonomous agent operating systems — connect an LLM to messaging, scheduling,
browsers, and file systems, then let it run 24/7. OpenFang adds fan-out
parallelism in its workflow engine.

These are general-purpose agent runtimes, not coding-specific. They solve
scheduling and persistence. OpenFang's parallelism is at the task pipeline
level (steps, loops, conditionals) — it has no concept of codebase file
ownership.

**What's missing:** No awareness of source code structure. Fan-out
parallelism without ownership guarantees is just concurrent mutation.

### IDE-Native Multi-Agent (Claude Code Agent Teams, Cursor, Codex)

The major coding tools now ship built-in multi-agent:

- **Claude Code Agent Teams** (Feb 2026) — team lead spawns teammates with
  a shared task list, inter-agent messaging, and git worktrees.
- **Cursor 2.0** (Oct 2025) — up to 8 concurrent agents in the editor.
- **Codex app** (Feb 2026) — "command center for agents," each with its own
  worktree, emphasis on long-running tasks.

These are the most capable execution mechanisms available. Agent Teams in
particular gives you worktree isolation, progress visibility, task
dependencies, and inter-agent messaging — real coordination primitives.

**What's missing:** The coordination is *emergent*. Agents share a task list
and self-organize. This works for loosely coupled tasks — but for tightly
interdependent code changes, self-organization produces exactly the
conflicts that worktrees were supposed to prevent. Two agents can claim
different tasks that modify the same file. The conflict is discovered at
merge time, after both have implemented divergent solutions. Worktrees
contain the blast radius; they don't prevent the collision.

There's no suitability gate. No formal file ownership verification before
launch. No frozen interface contracts. No persistent artifact that records
what was parallelized and why. The task list is ephemeral — when the session
ends, the coordination state is gone.

### Orchestration Layers (1code, code-conductor, ccswarm)

A wave of tools wrap Claude Code / Codex to manage the logistics:

- [**1code**](https://github.com/21st-dev/1code) (YC) — UI for up to 6
  agents in parallel with split view and worktree isolation.
- [**code-conductor**](https://github.com/ryanmac/code-conductor) —
  GitHub-native orchestration with automatic worktree management.
- [**ccswarm**](https://github.com/nwiizo/ccswarm) — multi-agent
  orchestration with specialized agent roles.
- [**parallel-code**](https://github.com/johannesjo/parallel-code) — run
  Claude Code, Codex, and Gemini side by side in worktrees.
- [**agent-orchestrator**](https://github.com/ComposioHQ/agent-orchestrator) —
  task planning, agent spawning, CI fix handling.

These solve the plumbing: worktree creation, process management, UI, merge.
They make it easy to *run* agents in parallel.

**What's missing:** Ease of execution doesn't mean safety of execution.
Making it trivial to spawn 6 agents doesn't answer whether those 6 agents
will step on each other. These tools manage the *how*. They don't address
the *what* (which files does each agent own?) or the *whether* (should this
work be parallelized at all?). When agents conflict, the orchestration layer
reports the merge failure — it doesn't prevent it.

### Spec-Driven Development (Kiro, GitHub Spec Kit, BMAD-METHOD)

[Kiro](https://kiro.dev/) (AWS) pioneered this: generate `requirements.md`,
`design.md`, and `tasks.md` before code. The spec is the source of truth;
the agent implements against it.

- **Kiro** — EARS-notation requirements, architecture decisions,
  dependency-ordered tasks, then code generation.
- **GitHub Spec Kit** — similar spec files driving agent behavior.
- **BMAD-METHOD** — broader spec-driven methodology.

This is the closest philosophical cousin to SAW. Both believe in planning
before execution. Both produce auditable artifacts. Both treat the plan as
a contract.

**What's missing:** Spec-driven development plans for *one agent*. It
makes a single agent's output predictable and auditable. It does not
address parallelization, file ownership, wave ordering, merge procedures,
or the question of whether work decomposes into parallel-safe chunks. Kiro
generates a task list; it does not verify that the tasks can be executed
concurrently without conflicts.

## Where SAW Sits

Every other tool in the ecosystem is either a **mechanism** (how to run
agents) or a **methodology** (how to plan for one agent). SAW is a
**coordination protocol**: a set of invariants that guarantee parallel
agents won't conflict, enforced at planning time.

```
┌─────────────────────────────────────────────────────────┐
│  Methodology: plan before code                          │
│  (Kiro, Spec Kit, BMAD-METHOD)                          │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Protocol: plan for safe parallelism        ← SAW │  │
│  │  (suitability gate, disjoint ownership,           │  │
│  │   interface contracts, wave ordering,             │  │
│  │   merge verification)                             │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Mechanism: run agents in parallel          │  │  │
│  │  │  (Agent Teams, Cursor, Codex, 1code,        │  │  │
│  │  │   code-conductor, ccswarm)                  │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

SAW is the middle layer. It sits between "have a plan" (methodology) and
"run the agents" (mechanism). It's the layer that answers: *given this
plan, can it be safely parallelized, and if so, how do we assign ownership
to guarantee conflict-freedom?*

No other tool in the ecosystem occupies this layer.

### What SAW provides that nothing else does

**Suitability gate.** The Scout runs a 5-question assessment and can emit
NOT SUITABLE. Every other tool assumes parallelization is desirable and
leaves conflict handling to merge time. SAW treats "don't parallelize this"
as a first-class outcome — a useful answer that prevents wasted agent time.

**Disjoint file ownership, verified before launch.** No two agents in the
same wave may touch the same file (I1). The Scout verifies this at planning
time. The Orchestrator re-verifies at merge time. Worktree isolation is
defense-in-depth, not the primary mechanism. This is the difference between
"conflicts are isolated to worktrees" and "conflicts cannot occur."

**Interface contracts frozen before execution.** Agents code against exact
type signatures defined in the IMPL doc. A Wave 2 agent knows exactly what
types Wave 1 will produce because the contracts are frozen before Wave 1
launches. Other tools let agents discover interfaces during implementation —
which works until two agents discover different answers.

**Human-in-the-loop as a structural guarantee.** The Orchestrator is the
user's session. The protocol requires human approval at the suitability
gate and between waves. `--auto` mode skips inter-wave confirmation but
still pauses on failures. This isn't a preference; it's an invariant.

**Persistent, auditable artifact.** The IMPL doc captures the suitability
assessment, dependency graph, file ownership table, interface contracts,
wave structure, agent prompts, and completion reports in a single markdown
file. It persists after the session ends. Six months later, you can read
an IMPL doc and reconstruct exactly what was parallelized, who owned what,
and what deviated. Task lists and chat histories don't survive.

**Protocol, not product.** SAW is a set of markdown files — prompt templates,
a skill router, and a formal spec (PROTOCOL.md with invariants I1–I6). No
binary, no server, no SDK, no vendor lock-in. It runs inside whatever agent
tool you already use. Today that's Claude Code; tomorrow it could be Codex,
Cursor, or a custom agent. The protocol is portable; the mechanism is
swappable.

## The Natural Pairing: Agent Teams + SAW

Claude Code Agent Teams is the strongest execution mechanism in the
ecosystem. SAW is the strongest safety protocol. They solve complementary
problems:

| Concern | Agent Teams | SAW |
|---------|------------|-----|
| Spawn agents in parallel | Yes | Delegates to Agent Teams |
| Worktree isolation | Built-in | Uses Agent Teams' worktrees |
| Inter-agent messaging | Yes | Not available standalone |
| Progress visibility | Yes | Not available standalone |
| Suitability gate | No | Yes — Scout decides if parallelization is safe |
| Disjoint file ownership | No — agents self-organize | Yes — verified before launch |
| Interface contracts | No — agents discover during implementation | Yes — frozen in IMPL doc |
| Persistent coordination artifact | No — task list is ephemeral | Yes — IMPL doc survives |
| "Don't parallelize this" | Not a concept | First-class outcome |

**Agent Teams without SAW:** Powerful but unplanned. Agents self-organize,
which works for loosely coupled tasks. On interdependent code changes, you
get merge-time surprises. No record of why work was decomposed the way it
was.

**SAW without Agent Teams:** Works today with the raw Agent tool and git
worktrees. All the safety guarantees hold. But you lose inter-agent
messaging, progress visibility, and native worktree management — the
Orchestrator does manual plumbing that Agent Teams handles natively.

**Agent Teams + SAW:** The Scout plans the decomposition with ownership
guarantees and frozen contracts. Agent Teams executes with messaging,
progress tracking, and worktree management. The IMPL doc persists as the
audit trail. Planned safety from SAW, emergent adaptation from Agent Teams.

## Decision Guide

| Situation | Use |
|-----------|-----|
| Quick parallel edits, loosely coupled | Agent Teams or orchestration layer — SAW overhead isn't worth it |
| Feature with 3+ agents, shared interfaces, file interdependencies | SAW — the Scout identifies safe decomposition before agents start |
| Need an audit trail of what was parallelized and why | SAW — the IMPL doc is the artifact |
| Uncertain whether parallelization is even appropriate | SAW — the suitability gate answers the question |
| Spec-driven team that also needs parallel execution | Kiro for the spec, SAW for the parallelization |
| Maximum throughput with maximum safety | Agent Teams + SAW |

## Further Reading

- [PROTOCOL.md](../PROTOCOL.md) — formal specification of invariants I1–I6
- [Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/) — the pattern, the failure modes of naive parallelism, and a worked example
- [Scout-and-Wave, Part 2: What Dogfooding Taught Us](https://blog.blackwell-systems.com/posts/scout-and-wave-part2/) — overhead measurement, the audit-fix-audit loop, and the bootstrap problem
- [Scout-and-Wave, Part 3: Five Failures, Five Fixes](https://blog.blackwell-systems.com/posts/scout-and-wave-part3/) — prompt engineering evolution driven by real failures
