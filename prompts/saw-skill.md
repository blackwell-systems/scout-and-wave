<!-- saw-skill v0.3.0 -->
Scout-and-Wave: Parallel Agent Coordination

Read the scout prompt at `prompts/scout.md` and the agent template at `prompts/agent-template.md` from the scout-and-wave repository. If these files are not in the current project, look for them at the path configured in the SAW_REPO environment variable, or fall back to `~/code/scout-and-wave/prompts/`.

If the argument is `bootstrap <project-description>`:
1. Read `prompts/saw-bootstrap.md` from the scout-and-wave repository and follow the bootstrap procedure.
2. Gather requirements (language, project type, key concerns) before designing anything.
3. Design the package structure and interface contracts, then write `docs/IMPL-bootstrap.md`.
4. Report the architecture design and wave structure. Ask the user to review before proceeding.

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
2. **Worktree setup:** Read `prompts/saw-worktree.md` from the scout-and-wave repository and follow the pre-creation procedure. Create a worktree for each agent before launching any agents.
3. For each agent in the current wave, launch a parallel Task agent using the agent prompt from the IMPL doc. Use `isolation: "worktree"` for each agent. Disjoint file ownership (enforced by the IMPL doc) is the primary safety mechanism.
4. After all agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {letter} — Completion Report`).
5. **Merge and verify:** Read `prompts/saw-merge.md` from the scout-and-wave repository and follow the merge procedure (conflict detection → merge each agent → cleanup → post-merge verification → update IMPL doc).
6. If `--auto` was passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
7. If verification fails, report the failures and ask the user how to proceed.

Arguments:
- `bootstrap <project-description>`: Design-first architecture for new projects
  with no existing codebase. Acts as architect rather than analyst — designs
  disjoint file ownership before any code is written. Gathers requirements
  (language, project type, key concerns), designs package structure and interface
  contracts, and produces `docs/IMPL-bootstrap.md` with a Wave 0 (types) pattern
  followed by parallel implementation waves. Use when starting from scratch.
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
