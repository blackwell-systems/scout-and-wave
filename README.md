# Scout-and-Wave

![Version](https://img.shields.io/badge/version-0.2.0-blue)

A methodology for reducing conflict and improving efficiency with parallel AI agents.

## Why

Parallel AI agents working on the same codebase produce merge conflicts, contradictory implementations, and expensive rework. Agents make local decisions without global context, and those decisions collide.

## How

Scout-and-wave addresses this in two phases:

1. **Scout:** A read-only agent analyzes the codebase and produces a coordination artifact: a dependency graph, interface contracts, a file ownership table, and a wave structure.
2. **Wave:** Groups of agents execute in parallel, each owning disjoint files, across successive waves verified by build and test gates.

Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.

The coordination artifact is living. After each wave, agents append their completion reports directly to the artifact — interface contract deviations, out-of-scope discoveries, and implementation decisions. The orchestrator reads the artifact to run the post-merge verification gate, then downstream agents in the next wave read it for updated context. The plan converges toward reality with each wave instead of drifting from it.

## How It Differs From Spec-Driven Development

[Spec-driven development](https://developer.microsoft.com/blog/spec-driven-development-spec-kit) says write the spec before the code. That's table stakes. Scout-and-wave starts where those specs end: when multiple agents need to execute in parallel against a shared codebase. Who owns which files? What are the exact interface contracts across agent boundaries? How do you propagate the actual state of completed work to the next wave? The scout produces that coordination artifact autonomously by reading the codebase. You don't write it by hand.

## Prompts

- [`prompts/scout.md`](prompts/scout.md) — The scout prompt that produces the coordination artifact
- [`prompts/agent-template.md`](prompts/agent-template.md) — The 8-field agent prompt template stamped per-agent
- [`prompts/saw-skill.md`](prompts/saw-skill.md) — Claude Code `/saw` skill router (copy to `~/.claude/commands/saw.md`)
- [`prompts/saw-merge.md`](prompts/saw-merge.md) — Merge procedure: conflict detection, agent merging, post-merge verification
- [`prompts/saw-worktree.md`](prompts/saw-worktree.md) — Worktree lifecycle: creation, verification, diagnosis, cleanup
- [`prompts/saw-quick.md`](prompts/saw-quick.md) — Lightweight mode for 2-3 agents with no IMPL doc

## When to Use It

**High parallelization value** (SAW pays for itself):
- Build/test cycle >30 seconds — each parallel agent runs independently, amplifying time savings
- Agents own 3+ files each — more implementation time per agent means more to parallelize
- Tasks involve non-trivial logic, tests, and edge cases — not simple find-and-replace
- Agents are independent (single wave) — maximum parallelization benefit

**Low parallelization value** (consider alternatives):
- Simple edits, documentation-only, or trivially fast sequential work — SAW overhead dominates
- 2-3 agents with disjoint files and no dependencies — use SAW Quick mode instead
- The IMPL doc has coordination value even when speed gains are marginal (audit trail, interface spec, progress tracking)

**Good fit:**
- Clear seams exist between pieces
- Interfaces can be defined before implementation starts
- Work can be chunked so each agent owns 1-3 files
- Cross-agent dependencies require coordination artifacts

**Poor fit:**
- Tightly coupled code with no clean file boundaries
- Interface cannot be known until you start implementing
- Simple work better done sequentially
- Root cause is unknown (crash, race condition) — investigate first, then use SAW for the fix

Use `/saw check` when you're unsure. The scout runs a built-in suitability gate with time-to-value estimates (scout + agents + merge vs sequential baseline) and will emit a NOT SUITABLE verdict (and stop) rather than producing a broken IMPL doc with forced decomposition. Either way, a poor-fit assessment is useful output — it tells you SAW isn't the right tool before any agents spend time on it.

## Usage with Claude Code

Scout-and-wave ships as a `/saw` skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

### Install

Copy the skill to your global commands directory:

```bash
cp prompts/saw-skill.md ~/.claude/commands/saw.md
```

### Commands

```
/saw check <feature-description>   # Lightweight suitability pre-flight (no files written)
/saw scout <feature-description>   # Run the scout phase, produce docs/IMPL-<feature>.md
/saw wave                          # Execute the next pending wave, pause for review
/saw wave --auto                   # Execute all waves; only pause if verification fails
/saw status                        # Show current progress
```

### Workflow

1. **Check (optional):** `/saw check "add OAuth2 login flow"` runs a lightweight pre-flight. It answers whether the work can be decomposed into disjoint file groups, whether there are investigation-first items, and whether cross-agent interfaces can be defined upfront. Emits SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS. No files are written. Skip this step if you already know SAW is a good fit.

2. **Scout:** `/saw scout "add OAuth2 login flow"` analyzes the codebase and writes `docs/IMPL-oauth2-login.md`. The scout always runs the suitability gate first — if the work is not suitable it writes only the verdict and stops without generating agent prompts. If suitable, it produces the full coordination artifact: suitability assessment with time-to-value estimates (scout + agents + merge vs sequential baseline), dependency graph, file ownership, interface contracts, wave structure, and per-agent prompts.

3. **Review:** Read the IMPL doc. Verify the suitability verdict makes sense, file ownership is clean, interface contracts are correct, and wave ordering is right. Adjust before proceeding.

4. **Wave:** `/saw wave` launches parallel agents for the current wave. Each agent owns disjoint files and codes against the interface contracts. Build and test gates verify the wave before proceeding. Note: git worktree isolation is not guaranteed to prevent concurrent writes — disjoint file ownership is what makes parallel execution safe, not the worktree mechanism.

5. **Repeat:** Run `/saw wave` for each subsequent wave, or `/saw wave --auto` to execute all remaining waves without per-wave confirmation prompts. Auto mode still pauses if verification fails.

## Blog Post

[Scout-and-Wave: A Coordination Pattern for Parallel AI Agents](https://blog.blackwell-systems.com/posts/scout-and-wave/)

## License

[MIT](LICENSE)
