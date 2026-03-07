# Scout-and-Wave

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
![Version](https://img.shields.io/badge/version-0.9.3-blue)
[![Agent Skills](assets/badge-agentskills.svg)](https://agentskills.io)

**Parallel AI agents that don't break each other's code.**

Other multi-agent frameworks run fast and merge chaos. SAW gives every agent its own worktree, assigns every file to exactly one agent, and shows you the full plan before any agent touches your code. Conflicts are resolved at planning time - not at merge time, after two agents have already built divergent solutions.

> Follows the [Agent Skills](https://agentskills.io) open standard - compatible with Claude Code, Cursor, GitHub Copilot, and other Agent Skills-compatible tools. See [`implementations/`](implementations/) for reference implementations.

> **New to Scout-and-Wave?** Follow this path:
> 1. Read this README (15 min) - understand "why" and "how" at a high level
> 2. Read [implementations/claude-code/QUICKSTART.md](implementations/claude-code/QUICKSTART.md) (20 min) - see a real example with output
> 3. Try it yourself: `/saw scout "feature"` on a test project
> 4. Deep dive: [protocol/](protocol/) specification when building a new implementation

## Why

You've run parallel agents before. You know what happens: two agents edit the same file, the merge produces garbage, and you spend longer fixing it than if you'd done the work sequentially. Or worse - the merge succeeds silently because both agents touched different functions in the same file, but they made contradictory assumptions about shared state. You find out at runtime.

Most frameworks try to solve this with better prompts. SAW solves it with structure:

- **Disjoint file ownership.** The Scout assigns every file to exactly one agent before any code is written. Two agents in the same wave cannot produce edits to the same file. Merge conflicts become structurally impossible.
- **Per-agent worktree isolation.** Each agent works in its own git worktree - a separate directory with an independent file tree. Concurrent builds, tests, and tool-cache writes don't race on shared state.
- **Human review before execution.** You see the full plan - file assignments, interface contracts, wave structure - and approve it before any agent launches. This is the last point where changing the architecture is cheap.
- **Suitability gate.** SAW says "no" when the work doesn't decompose cleanly. A poor-fit assessment prevents bad decompositions from producing expensive failures.

Four participants coordinate within a single session: the **Orchestrator** (your Claude Code session), **Scout** (analyzes codebase, assigns files to agents), **Scaffold Agent** (creates shared types before parallel work begins), and **Wave Agents** (implement their assigned files in parallel worktrees, one wave at a time). The scout enforces disjoint ownership at planning time, the scaffold agent creates interface contracts before parallelization, and wave agents work in isolated worktrees. Everything is coordinated by a single orchestrator that holds full state.

## How

**What happens when you run SAW:**

1. You run `/saw scout "feature"` → Scout analyzes codebase, assigns files to agents
2. Scout writes IMPL doc (implementation plan with file ownership and interface contracts) → You review wave structure
3. You run `/saw wave` → Scaffold Agent creates shared types (if needed)
4. Wave Agents launch in parallel → Each works in isolated worktree on disjoint files
5. Orchestrator merges → Runs tests → Cleans up worktrees

**Key mechanisms:**

- **Orchestrator:** Synchronous coordination agent in your session. Launches Scout and Wave Agents, enforces file ownership, executes merge procedure, runs verification gates. Human reviews and approves through it directly.

- **Scout:** Asynchronous agent. Analyzes codebase, produces IMPL doc with dependency graph, interface contracts, file ownership table, and wave structure. Every file assigned to exactly one agent. Resolves ownership conflicts at planning time or declares work NOT SUITABLE.

- **Scaffold Agent:** Asynchronous agent. Runs once before Wave 1 if the IMPL doc specifies shared types that multiple agents need (e.g., interface definitions). Creates shared type files (called "scaffolds") from IMPL doc contracts, verifies compilation, commits to HEAD. Runs once before any Wave Agent launches. If compilation fails, wave stops before worktrees are created.

- **Wave Agents:** Asynchronous agents running in parallel. Each owns disjoint files, implements against frozen interface contracts, runs verification gate, commits work, writes completion report.

The protocol has a built-in **suitability gate** that answers five questions before producing any agent prompts. If preconditions don't hold, the scout emits NOT SUITABLE and stops. **SAW isn't for everything.** A poor-fit assessment prevents bad decompositions.

The five questions assess whether the work:
1. Decomposes into independent files
2. Avoids investigation-first blockers
3. Has discoverable interfaces
4. Doesn't require pre-implementation scanning
5. Provides value from parallelization

See [protocol/preconditions.md](protocol/preconditions.md) for details.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/saw-scout-wave-dark.svg">
  <img src="docs/diagrams/saw-scout-wave-light.svg" alt="SAW scout + wave execution flow">
</picture>

## Quick Start

> **⚠️ BEFORE YOU START:** Add `"Agent"` to your allow list in `~/.claude/settings.json` or you'll need to manually approve each agent launch. See [implementations/claude-code/README.md](implementations/claude-code/README.md#step-1-configure-permissions-required) for details.

> **ℹ️ Claude Code implementation shown below.** The `/saw` commands use Claude Code's Agent Skills syntax. Other Agent Skills-compatible tools (Cursor, GitHub Copilot, etc.) use their own invocation syntax - see [`implementations/`](implementations/) for the appropriate guide.

```bash
# 1. Clone and install
git clone https://github.com/blackwell-systems/scout-and-wave.git ~/code/scout-and-wave

# Create skill directory and symlink files (see implementations/claude-code/README.md for full install)
mkdir -p ~/.claude/skills/saw/agents
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/skills/saw/SKILL.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-bootstrap.md ~/.claude/skills/saw/saw-bootstrap.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-merge.md ~/.claude/skills/saw/saw-merge.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-worktree.md ~/.claude/skills/saw/saw-worktree.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md ~/.claude/skills/saw/agent-template.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/scout.md ~/.claude/skills/saw/scout.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/scaffold-agent.md ~/.claude/skills/saw/scaffold-agent.md

# 2. Restart Claude Code, then in any session on any project:
/saw scout "add a caching layer to the API client"
# → Scout analyzes the codebase, assigns files to agents, writes docs/IMPL/IMPL-caching-layer.md
# → Orchestrator shows you the wave structure and interface contracts for review
# → You review the IMPL doc. This is the last chance to change interfaces.

/saw wave
# → If shared types are needed, Scaffold Agent creates them automatically
# → Parallel agents implement their assigned files concurrently
# → Orchestrator merges, runs tests, reports result
```

The scout produces an **Implementation Document (IMPL doc)** (`docs/IMPL/IMPL-<feature>.md`): a structured coordination document that defines which files each agent will modify, what interfaces they'll implement, and how they'll work in parallel. You review it before any agent writes code. This is the human checkpoint that makes parallel execution safe.

**First time using SAW?** See [implementations/claude-code/QUICKSTART.md](implementations/claude-code/QUICKSTART.md) for step-by-step guidance with example output.

## Documentation

### Protocol Specification

The protocol is defined independent of any implementation. Read these to understand how SAW works:

- **[protocol/README.md](protocol/README.md)** - Protocol overview and navigation guide
- **[protocol/participants.md](protocol/participants.md)** - Four participant roles and their responsibilities
- **[protocol/preconditions.md](protocol/preconditions.md)** - Five preconditions for suitability gate
- **[protocol/invariants.md](protocol/invariants.md)** - Six invariants that ensure correctness (I1-I6)
- **[protocol/execution-rules.md](protocol/execution-rules.md)** - Ten rules governing state transitions and merges
- **[protocol/state-machine.md](protocol/state-machine.md)** - Protocol states and transitions
- **[protocol/message-formats.md](protocol/message-formats.md)** - IMPL doc and completion report schemas
- **[protocol/procedures.md](protocol/procedures.md)** - Step-by-step merge and verification procedures

### Implementations

SAW can be executed in different ways:

- **[implementations/claude-code/](implementations/claude-code/)** - Fully automated implementation using Claude Code

See **[implementations/README.md](implementations/README.md)** for details.

## When to Use It

SAW pays for itself when the work has clear file seams, interfaces can be defined before implementation starts, and each agent owns enough work to justify running in parallel. The build/test cycle being >30 seconds amplifies the savings further.

If the work doesn't decompose cleanly, the Scout says so. It runs a suitability gate first and emits NOT SUITABLE rather than forcing a bad decomposition.

## How Parallel Safety Works

SAW enforces two independent constraints that together make parallel execution correct:

**Disjoint file ownership** prevents merge conflicts. Every file that will change is assigned to exactly one agent in the IMPL doc. No two agents in the same wave can produce edits to the same file, so the merge step is always conflict-free regardless of what agents do during execution.

**Worktree isolation** prevents execution-time interference. Each agent works in its own git worktree - a separate directory that shares the same git history but has an independent file tree. This means concurrent `go build`, `go test`, and tool-cache writes don't race on shared build caches, lock files, or intermediate object files.

Neither constraint substitutes for the other. Disjoint ownership without worktrees: merge is safe, but concurrent builds are flaky. Worktrees without disjoint ownership: execution is clean, but merge produces unresolvable conflicts. Both must hold for a wave to be correct and reproducible.

**Cascade failures:** These happen when Agent A changes a function signature and Agent B's code breaks at integration time, even though both passed isolated tests. The post-merge verification gate catches these cross-package issues that individual agents can't see in their isolated worktrees.

### Worktree Isolation Defense (5 layers)

Agents don't always respect isolation instructions. v0.6.0 adds a layered defense model that treats worktree isolation as an infrastructure problem, not a cooperation problem:

(Layers numbered 0-4. Layer 0 is the foundational prevention layer; higher layers add defense-in-depth.)

| Layer | Mechanism | Type |
|-------|-----------|------|
| 0 | **Pre-commit hook** (`hooks/pre-commit-guard.sh`) - copied to `.git/hooks/pre-commit` during worktree setup, removed during cleanup. Blocks commits to main during active waves. Agents receive an instructive error with their worktree path. Orchestrator bypasses via `SAW_ALLOW_MAIN_COMMIT=1`. | Prevention |
| 1 | **Manual worktree pre-creation** - Orchestrator creates all worktrees before any agent launches | Deterministic |
| 2 | **`isolation: "worktree"` parameter** - each agent launch specifies worktree isolation at the tool level | Tool-level |
| 3 | **Field 0 self-verification** - agents verify their own branch and working directory on startup | Cooperative |
| 4 | **Merge-time trip wire** - Orchestrator counts commits per worktree branch before merging. Zero commits = isolation failure. Stops with recovery options. | Deterministic |

Layers 0 and 4 are the structural guarantees: Layer 0 prevents agents from committing to main, Layer 4 detects if isolation failed by any mechanism. Layers 1-3 are defense-in-depth.

## Building a New Implementation

To implement SAW in a different runtime (Python, Rust, TypeScript, etc.):

1. Read protocol docs in order: [participants](protocol/participants.md) → [preconditions](protocol/preconditions.md) → [invariants](protocol/invariants.md) → [execution-rules](protocol/execution-rules.md) → [state-machine](protocol/state-machine.md) → [message-formats](protocol/message-formats.md) → [procedures](protocol/procedures.md)
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (worktree isolation): git worktrees, filesystem snapshots, containers, etc.
4. Use the [protocol/](protocol/) specification as reference for orchestrator logic
5. Use [protocol/message-formats.md](protocol/message-formats.md) as reference for IMPL doc structure and message schemas
6. Verify your implementation satisfies all six invariants (I1-I6)

See [protocol/README.md](protocol/README.md) for the full adoption guide.

## SAW-Teams (Experimental)

[`saw-teams/`](saw-teams/) is an alternate execution layer using Claude Code Agent Teams. Same protocol, same IMPL doc, same Scout. Different wave plumbing: teammates replace background Agent tool calls, providing inter-agent messaging and real-time deviation alerts. Trade-off: better visibility during execution, worse crash recovery. See [`saw-teams/README.md`](saw-teams/README.md) for setup and usage.

## Blog Post

Four-part series on the pattern, the lessons learned from dogfooding it, and how the protocol evolved:

1. [Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/). The pattern: failure modes of naive parallelism, the scout deliverable, wave execution, and a worked example from brewprune.
2. [Scout-and-Wave, Part 2: What Dogfooding Taught Us](https://blog.blackwell-systems.com/posts/scout-and-wave-part2/). The audit-fix-audit loop, overhead measurement (88% slower when ignored), Quick mode, and the bootstrap problem for new projects.
3. [Scout-and-Wave, Part 3: Five Failures, Five Fixes](https://blog.blackwell-systems.com/posts/scout-and-wave-part3/). How the skill file decomposed from a 400-line monolith, why version headers matter, and five scout prompt fixes driven by real failures.
4. [Scout-and-Wave, Part 4: Trust Is Structural](https://blog.blackwell-systems.com/posts/scout-and-wave-part4/). The Scaffold Agent, the 5-layer worktree isolation defense, and why correctness belongs in infrastructure rather than cooperation.

## License

[MIT OR Apache-2.0](LICENSE)
