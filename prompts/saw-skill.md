Scout-and-Wave: Parallel Agent Coordination

Read the scout prompt at `prompts/scout.md` and the agent template at `prompts/agent-template.md` from the scout-and-wave repository. If these files are not in the current project, look for them at the path configured in the SAW_REPO environment variable, or fall back to `~/code/scout-and-wave/prompts/`.

If the argument is `check <feature-description>`:
1. Read the feature description and do a lightweight codebase scan (directory structure, key files likely to change — no deep analysis).
2. Answer the three suitability questions:
   - Can the work decompose into ≥2 disjoint file groups?
   - Are there investigation-first items (unknown root causes, crashes to reproduce)?
   - Can cross-agent interfaces be defined before implementation starts?
3. Emit a verdict (SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS) with a one-paragraph rationale and a recommended next step. Do not write any files.

If no `docs/IMPL-*.md` file exists for the current feature:
1. Run the scout phase: analyze the codebase and produce a coordination artifact following the scout prompt. The scout runs the suitability gate first; if NOT SUITABLE it writes only the verdict section and stops. Write the result to `docs/IMPL-<feature-slug>.md`.
2. Report the suitability verdict, and if suitable: the wave structure, file ownership table, and interface contracts. Ask the user to review before proceeding.

If a `docs/IMPL-*.md` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items).
2. For each agent in the current wave, launch a parallel Task agent using the agent prompt from the IMPL doc. Use `isolation: "worktree"` for each agent. Note: worktree isolation does not guarantee true filesystem isolation — disjoint file ownership (enforced by the IMPL doc) is what prevents conflicts, not the worktree mechanism.
3. After all agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {letter} — Completion Report`). Check for interface contract deviations and out-of-scope dependencies.
4. **Detect out-of-scope conflicts before merging**: Scan all completion reports for out-of-scope file changes (reported in section 8). If multiple agents modified the same out-of-scope file, flag the conflict and show both changes to the user. Ask which version to keep or if manual merge is needed. Do not proceed to merge until conflicts are resolved.
5. Merge all agent worktrees back into the main branch.
6. Run the verification gate commands listed in the IMPL doc against the merged result. Individual agents pass their gates in isolation, but the merged codebase can surface issues none of them saw individually. This post-merge verification is the real gate. Pay attention to cascade candidates listed in the IMPL doc.
7. If verification passes, update the IMPL doc: tick status checkboxes, correct any interface contracts that changed, apply any out-of-scope fixes flagged by agents, and commit the wave's changes. If `--auto` was passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
8. If verification fails, report the failures and ask the user how to proceed.

Arguments:
- `check <feature-description>`: Lightweight suitability pre-flight. Does not
  analyze the full codebase and does not write any files. Answers three
  questions: (1) Can the work decompose into ≥2 disjoint file groups?
  (2) Are there investigation-first items (crashes, unknown root causes)?
  (3) Can cross-agent interfaces be defined before implementation starts?
  Emits a verdict: SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS, plus a
  recommended next step. Run this when you are unsure whether SAW is the
  right approach before committing to a full scout.
- `scout <feature-description>`: Run the scout phase to produce the IMPL doc.
  The scout always runs the suitability gate first; if the work is not
  suitable, it writes a short verdict to `docs/IMPL-<slug>.md` and stops
  without producing agent prompts.
- `wave`: Execute the next pending wave, pause for review after each wave
- `wave --auto`: Execute all remaining waves automatically; only pause if verification fails
- `status`: Show current progress from the IMPL doc

Always read the full IMPL doc before taking any action. The IMPL doc is the single source of truth.
