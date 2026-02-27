# Scout-and-Wave

A methodology for reducing conflict and improving efficiency with parallel AI agents.

## Why

Parallel AI agents working on the same codebase produce merge conflicts, contradictory implementations, and expensive rework. Agents make local decisions without global context, and those decisions collide.

## How

Scout-and-wave addresses this in two phases:

1. **Scout:** A read-only agent analyzes the codebase and produces a coordination artifact: a dependency graph, interface contracts, a file ownership table, and a wave structure.
2. **Wave:** Groups of agents execute in parallel, each owning disjoint files, across successive waves verified by build and test gates.

Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.

## How It Differs From Spec-Driven Development

[Spec-driven development](https://developer.microsoft.com/blog/spec-driven-development-spec-kit) says write the spec before the code. That's table stakes. Scout-and-wave starts where those specs end: when multiple agents need to execute in parallel against a shared codebase. Who owns which files? What are the exact interface contracts across agent boundaries? How do you propagate the actual state of completed work to the next wave? The scout produces that coordination artifact autonomously by reading the codebase. You don't write it by hand.

## Prompts

- [`prompts/scout.md`](prompts/scout.md) — The scout prompt that produces the coordination artifact
- [`prompts/agent-template.md`](prompts/agent-template.md) — The 8-field agent prompt template stamped per-agent
- [`prompts/saw-skill.md`](prompts/saw-skill.md) — Claude Code `/saw` skill (copy to `~/.claude/commands/saw.md`)

## When to Use It

**Good fit:**
- Feature touches 5+ files
- Clear seams exist between pieces
- Interfaces can be defined before implementation
- Work can be chunked so each agent owns 1-3 files

**Poor fit:**
- Tightly coupled code with no clean seams
- Interface unknown until you start implementing
- Single piece of logic with nothing to parallelize

The scout itself will surface a poor fit: if file ownership cannot be cleanly assigned, that's a signal the work isn't parallelizable, which is still useful information before you start.

## Usage with Claude Code

Scout-and-wave ships as a `/saw` skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

### Install

Copy the skill to your global commands directory:

```bash
cp prompts/saw-skill.md ~/.claude/commands/saw.md
```

### Commands

```
/saw scout <feature-description>   # Run the scout phase, produce docs/IMPL-<feature>.md
/saw wave                          # Execute the next pending wave from the IMPL doc
/saw status                        # Show current progress
```

### Workflow

1. **Scout:** `/saw scout "add OAuth2 login flow"` analyzes the codebase and writes `docs/IMPL-oauth2-login.md` with the full coordination artifact: dependency graph, file ownership, interface contracts, wave structure, and per-agent prompts.

2. **Review:** Read the IMPL doc. Verify file ownership is clean, interface contracts are correct, and wave ordering makes sense. Adjust before proceeding.

3. **Wave:** `/saw wave` launches parallel agents for the current wave. Each agent runs in an isolated git worktree, owns disjoint files, and codes against the interface contracts. Build and test gates verify the wave before proceeding.

4. **Repeat:** Run `/saw wave` for each subsequent wave until all waves complete.

## Blog Post

[Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/)

## License

[MIT](LICENSE)
