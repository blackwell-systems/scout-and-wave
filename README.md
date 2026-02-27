# Scout-and-Wave

A methodology for reducing conflict and improving efficiency with parallel AI agents.

## The Problem

Parallel AI agents working on the same codebase produce merge conflicts, contradictory implementations, and expensive rework. Agents make local decisions without global context, and those decisions collide.

## The Pattern

Scout-and-wave solves this in two phases:

1. **Scout:** A read-only agent analyzes the codebase and produces a coordination artifact: a dependency graph, interface contracts, a file ownership table, and a wave structure.
2. **Wave:** Groups of agents execute in parallel, each owning disjoint files, across successive waves verified by build and test gates.

Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.

## How It Differs From Spec-Driven Development

[Spec-driven development](https://developer.microsoft.com/blog/spec-driven-development-spec-kit) says write the spec before the code. That's table stakes. Scout-and-wave starts where those specs end: when multiple agents need to execute in parallel against a shared codebase. Who owns which files? What are the exact interface contracts across agent boundaries? How do you propagate the actual state of completed work to the next wave? The scout produces that coordination artifact autonomously by reading the codebase. You don't write it by hand.

## Prompts

- [`prompts/scout.md`](prompts/scout.md) — The scout prompt that produces the coordination artifact
- [`prompts/agent-template.md`](prompts/agent-template.md) — The 8-field agent prompt template stamped per-agent

## Worked Example

[`examples/brewprune-IMPL-brew-native.md`](examples/brewprune-IMPL-brew-native.md) — A real coordination artifact from a [brewprune](https://github.com/blackwell-systems/brewprune) session: 7 agents, 3 waves, 1,532 lines across 16 files.

```
Wave 1: [A] [B] [C] [D]     <- 4 parallel agents, 600 lines
           | (A completes)
Wave 2:   [E] [F]            <- 2 parallel agents, 530 lines
           | (E+F complete)
Wave 3:    [G]               <- 1 agent, 402 lines
```

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

## Blog Post

[Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/)

## License

[MIT](LICENSE)
