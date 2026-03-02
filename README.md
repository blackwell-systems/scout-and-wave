# Scout-and-Wave: A Protocol for Safely Parallelizing Human-Guided Agentic Workflows

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
![Version](https://img.shields.io/badge/version-0.3.5-blue)

A coordination protocol for safely parallelizing human-guided agentic workflows. Defines participant roles, preconditions, ownership invariants, and verification gates that guarantee agents can work concurrently without conflicts. Human review checkpoints are structural: the protocol does not advance past the suitability gate or between waves without human approval.

## Why

Parallel AI agents working on the same codebase produce merge conflicts, contradictory implementations, and expensive rework. Agents make local decisions without global context, and those decisions collide.

The root cause isn't that agents are careless; it's that nothing stops two agents from claiming the same file. Worktrees isolate working directories, not merge outcomes. Two agents can still produce incompatible edits to the same file; the conflict is discovered at merge time, after both have implemented divergent solutions. You get either a merge conflict or, worse, a silent overwrite.

## How

Scout-and-wave fixes this before any agent starts, through three participant roles:

- **Orchestrator:** the synchronous agent. Drives all protocol state transitions. Launches the Scout and Wave Agents, waits for completion, executes the merge procedure, verifies the result, and advances state. The only participant that interacts with the human directly. Does not perform Scout or Wave Agent duties (I6: Role Separation).

- **Scout:** an asynchronous agent launched by the Orchestrator. Analyzes the codebase and produces a coordination artifact: a dependency graph, exact interface contracts, a file ownership table, and a wave structure. Every file that will change is assigned to exactly one agent. No two agents in the same wave may touch the same file (I1: Disjoint File Ownership). The Scout resolves ownership conflicts at planning time or declares the work NOT SUITABLE for parallel execution. Never modifies source files.

- **Wave Agents:** asynchronous agents launched by the Orchestrator in parallel. Each owns a disjoint set of files, implements against the pre-defined interface contracts, runs the verification gate, commits its work, and writes a structured completion report (interface deviations, out-of-scope discoveries, verification result). Build and test gates verify each wave before the next begins.

The protocol has a built-in suitability gate. The scout answers five questions before producing any agent prompts:

1. Can the work decompose into disjoint file groups?
2. Are there investigation-first blockers?
3. Can interfaces be defined upfront?
4. Are any items already implemented?
5. Does parallelization gain exceed the overhead of scout + merge?

If any question is a hard blocker, the scout emits NOT SUITABLE and stops. A poor-fit assessment is useful output: it tells you SAW isn't the right tool before any agent spends time on it.

When all preconditions hold and all invariants are maintained, the protocol provides a concrete correctness guarantee: if the suitability gate passes and the verification gates pass, the work was safe to parallelize. That's the difference between parallel agents with coordination overhead and parallel agents with structural safety properties.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/diagrams/saw-scout-wave-dark.svg">
  <img src="docs/diagrams/saw-scout-wave-light.svg" alt="SAW scout + wave execution flow">
</picture>

## Protocol Specification

[`PROTOCOL.md`](PROTOCOL.md). Formal specification: participant roles, preconditions, invariants (I1–I6), state machine, execution rules, message formats, and correctness guarantees. Invariants are numbered I1–I6; prompt files embed them verbatim alongside their I-number for self-containment and auditability. The prompts in `prompts/` are reference implementations of this spec.

## Prompts

- [`prompts/scout.md`](prompts/scout.md): The scout prompt that produces the coordination artifact
- [`prompts/agent-template.md`](prompts/agent-template.md): The 9-field agent prompt template stamped per-agent (Field 0: isolation verification; Fields 1–8: implementation spec)
- [`prompts/saw-skill.md`](prompts/saw-skill.md): Claude Code `/saw` skill router (copy to `~/.claude/commands/saw.md`)
- [`prompts/saw-bootstrap.md`](prompts/saw-bootstrap.md): Design-first architecture for new projects with no existing codebase
- [`prompts/saw-merge.md`](prompts/saw-merge.md): Merge procedure: conflict detection, agent merging, post-merge verification
- [`prompts/saw-worktree.md`](prompts/saw-worktree.md): Worktree lifecycle: creation, verification, diagnosis, cleanup

## When to Use It

SAW pays for itself when the work has clear file seams, interfaces can be defined before implementation starts, and each agent owns enough work to justify running in parallel. The build/test cycle being >30 seconds amplifies the savings further.

If the work doesn't decompose cleanly, the Scout says so. It runs a suitability gate first and emits NOT SUITABLE rather than forcing a bad decomposition.

## Usage with Claude Code

Scout-and-wave ships as a `/saw` skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

### Install

Copy the skill to your global commands directory:

```bash
cp prompts/saw-skill.md ~/.claude/commands/saw.md
```

### Permissions

SAW requires the following entries in `~/.claude/settings.json` to run without
blocking on approval prompts at each tool call:

```json
{
  "permissions": {
    "allow": [
      "Agent",
      "Bash",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebFetch",
      "WebSearch",
      "TodoWrite"
    ]
  }
}
```

**`"Agent"` is the critical one.** Without it, every wave agent launch and
every pipelined scout launch blocks waiting for a keyboard approval. In a
multi-agent wave, you would need to approve each agent individually before it
launches asynchronously. Add `"Agent"` once to your user-level settings and all
future SAW runs are fully hands-free from the moment you invoke `/saw wave`.

The other entries cover git commands, worktree management, IMPL doc writes, and codebase reads (`Bash`, `Read`, `Write`, `Edit`, `Glob`, `Grep`), task list updates for wave progress tracking (`TodoWrite`), and doc/API lookups during scout analysis (`WebFetch`, `WebSearch`). If your existing settings already allow these, no change is needed.
For project-scoped settings, add the same block to
`.claude/settings.json` in the project root.

### How it works under the hood

**IMPL doc as coordination surface.** The IMPL doc is not just documentation; it is the live state of the wave. Agents write structured YAML completion reports directly into it, and the orchestrator parses those reports to detect ownership violations, interface deviations, and blocked agents before touching the working tree. The format has to be strict enough to be machine-readable. Loose or summarized reports break the orchestrator's ability to do conflict prediction and downstream prompt propagation.

**Background execution.** Every agent launch uses `run_in_background: true`. Without it, the orchestrator blocks waiting for each agent to finish before launching the next; sequential execution with extra steps. Background execution is what makes the wave actually parallel. The same applies to CI polling and `gh run watch` calls; anything that blocks the foreground session defeats the hands-free design.

### Commands

```
/saw bootstrap <project-description>   # Design-first architecture for new projects
/saw scout <feature-description>       # Run the scout phase, produce docs/IMPL-<feature>.md
/saw wave                              # Execute the next pending wave, pause for review
/saw wave --auto                       # Execute all waves; only pause if verification fails
/saw status                            # Show current progress
```

### Workflow

0. **Bootstrap (new projects only):** `/saw bootstrap "description"` designs package structure, interface contracts, and wave layout for a new repo before any code is written.

1. **Scout:** `/saw scout "feature description"` analyzes the codebase, runs the suitability gate, and produces `docs/IMPL-<feature>.md` with file ownership, interface contracts, and per-agent prompts.

2. **Review:** Read the IMPL doc. Verify ownership is clean, interfaces are correct, and wave order makes sense. Adjust before proceeding.

3. **Wave:** `/saw wave` launches parallel agents for the current wave, merges on completion, and runs the verification gate.

4. **Repeat:** `/saw wave` for each subsequent wave, or `/saw wave --auto` to run all remaining waves unattended. Auto mode still pauses if verification fails.

## Blog Post

Three-part series on the pattern, the lessons learned from dogfooding it, and how the skill file evolved:

1. [Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/). The pattern: failure modes of naive parallelism, the scout deliverable, wave execution, and a worked example from brewprune.
2. [Scout-and-Wave, Part 2: What Dogfooding Taught Us](https://blog.blackwell-systems.com/posts/scout-and-wave-part2/). The audit-fix-audit loop, overhead measurement (88% slower when ignored), Quick mode, and the bootstrap problem for new projects.
3. [Scout-and-Wave, Part 3: Five Failures, Five Fixes](https://blog.blackwell-systems.com/posts/scout-and-wave-part3/). How the skill file decomposed from a 400-line monolith, why version headers matter, and five scout prompt fixes driven by real failures.

## License

[MIT](LICENSE)
