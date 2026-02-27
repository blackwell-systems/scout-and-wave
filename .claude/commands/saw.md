Scout-and-Wave: Parallel Agent Coordination

Read the scout prompt at `prompts/scout.md` and the agent template at `prompts/agent-template.md`.

If no `docs/IMPL-*.md` file exists for the current feature:
1. Run the scout phase: analyze the codebase and produce a coordination artifact following the scout prompt. Write it to `docs/IMPL-<feature-slug>.md`.
2. Report the wave structure, file ownership table, and interface contracts. Ask the user to review before proceeding.

If a `docs/IMPL-*.md` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items).
2. For each agent in the current wave, launch a parallel Task agent using the agent prompt from the IMPL doc. Use `isolation: "worktree"` for each agent so they work on isolated copies.
3. After all agents in the wave complete, report their results.
4. Run the verification gate commands listed in the IMPL doc.
5. If verification passes, update the status checklist in the IMPL doc, commit the wave's changes, and ask the user if they want to proceed to the next wave.
6. If verification fails, report the failures and ask the user how to proceed.

Arguments:
- `scout <feature-description>`: Run only the scout phase to produce the IMPL doc
- `wave`: Execute the next pending wave from the existing IMPL doc
- `status`: Show current progress from the IMPL doc

Always read the full IMPL doc before taking any action. The IMPL doc is the single source of truth.
