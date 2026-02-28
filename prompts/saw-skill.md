Scout-and-Wave: Parallel Agent Coordination

Read the scout prompt at `prompts/scout.md` and the agent template at `prompts/agent-template.md` from the scout-and-wave repository. If these files are not in the current project, look for them at the path configured in the SAW_REPO environment variable, or fall back to `~/code/scout-and-wave/prompts/`.

If no `docs/IMPL-*.md` file exists for the current feature:
1. Run the scout phase: analyze the codebase and produce a coordination artifact following the scout prompt. Write it to `docs/IMPL-<feature-slug>.md`.
2. Report the wave structure, file ownership table, and interface contracts. Ask the user to review before proceeding.

If a `docs/IMPL-*.md` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items).
2. For each agent in the current wave, launch a parallel Task agent using the agent prompt from the IMPL doc. Use `isolation: "worktree"` for each agent. Note: worktree isolation does not guarantee true filesystem isolation — disjoint file ownership (enforced by the IMPL doc) is what prevents conflicts, not the worktree mechanism.
3. After all agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {letter} — Completion Report`). Check for interface contract deviations and out-of-scope dependencies.
4. Merge all agent worktrees back into the main branch.
5. Run the verification gate commands listed in the IMPL doc against the merged result. Individual agents pass their gates in isolation, but the merged codebase can surface issues none of them saw individually. This post-merge verification is the real gate. Pay attention to cascade candidates listed in the IMPL doc.
6. If verification passes, update the IMPL doc: tick status checkboxes, correct any interface contracts that changed, apply any out-of-scope fixes flagged by agents, and commit the wave's changes. If `--auto` was passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
7. If verification fails, report the failures and ask the user how to proceed.

Arguments:
- `scout <feature-description>`: Run only the scout phase to produce the IMPL doc
- `wave`: Execute the next pending wave, pause for review after each wave
- `wave --auto`: Execute all remaining waves automatically; only pause if verification fails
- `status`: Show current progress from the IMPL doc

Always read the full IMPL doc before taking any action. The IMPL doc is the single source of truth.
