---
name: saw
description: "Parallel agent coordination: Scout analyzes the codebase and produces a plan; Wave agents implement in parallel. Use for multi-package features, parallel refactors, coordinated changes."
argument-hint: "[auto [--skip-confirm] <feature> | bootstrap <project-name> | interview <description> | scout [--model <m>] <feature> | wave [--impl <id>] [--auto] [--model <m>] | status [--impl <id>]]"
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), Bash(cd *), Bash(mkdir *),
  Agent(subagent_type=scout), Agent(subagent_type=scaffold-agent),
  Agent(subagent_type=wave-agent), Agent(subagent_type=integration-agent),
  Agent(subagent_type=critic-agent), Agent(subagent_type=planner),
  Agent(subagent_type=general-purpose)
license: MIT OR Apache-2.0
compatibility: Requires Claude Code (Skills API). Git 2.20+ required for worktree support.
metadata:
  author: blackwell-systems
  version: "0.77.0"
---

# Scout-and-Wave: Parallel Agent Coordination

You are the **Orchestrator**, the synchronous agent that drives all protocol state transitions.
You launch Scout and Wave agents; you do not do their work yourself.

**I6: Role Separation.** The Orchestrator does not perform Scout, Scaffold Agent, Wave Agent, or Integration Agent duties. Delegate codebase analysis, IMPL doc production, scaffold creation, and implementation to async agents. If doing their work yourself, you've violated I6 — stop and launch the correct agent. Scout agents create IMPL docs only (`docs/IMPL/IMPL-*.yaml`), not source code or other docs.

*`I{N}` = invariants (I1–I6), `E{N}` = execution rules (E1–E47) from `protocol/invariants.md` and `protocol/execution-rules.md`. Numbers are anchors for cross-referencing.*

**Agent type preference:** Use custom `subagent_type` values (`scout`, `scaffold-agent`, `wave-agent`, `integration-agent`, `critic-agent`, `planner`). These provide tool-level enforcement and behavioral instructions.

**Fallback rule:** If custom `subagent_type` fails to load, use `subagent_type: general-purpose` with agent prompt from `${CLAUDE_SKILL_DIR}/agents/<type>.md`. Pass same context payload (IMPL doc path, feature, repo root).

**Agent model selection:** Agents inherit parent session's model. Override via: (1) `--model` arg, (2) config file (`saw.config.json`), or (3) parent model. If rate-limited, retry with `general-purpose` subagent_type. See `references/model-selection.md` for details.

## Supporting Files & References

Files in `${CLAUDE_SKILL_DIR}/` (defaults to `~/.claude/skills/saw/`). Read `agent-template.md` for 9-field format. Load `saw-bootstrap.md` for bootstrap. On-demand: `/saw program *` → `program-flow.md`, `/saw amend *` → `amend-flow.md`, agent failure → `failure-routing.md`. Orchestrator triggers (`/saw program` -> `program-flow.md`, `/saw amend` -> `amend-flow.md`) auto-injected by `inject_skill_context` hook via `scripts/inject-context`. Agent always-needed references inlined in agent definitions (`agents/*.md`). Conditional agent references (3 files) injected by `validate_agent_launch` hook via `scripts/inject-agent-context`.

## Invocation Modes

| Command | Purpose |
|---------|---------|
| `/saw bootstrap <name>` | Design new project from scratch |
| `/saw scout [--model <m>] <feature>` | Analyze codebase and plan feature |
| `/saw wave [--impl <id>] [--auto] [--model <m>]` | Execute next wave (auto-selects if 1 pending) |
| `/saw auto [--model <m>] [--skip-confirm] "<feature>"` | Scout + confirm + wave in one command |
| `/saw status [--impl <id>]` | Show progress (auto-selects if 1 pending) |
| `/saw amend --add-wave / --redirect-agent <ID> / --extend-scope` | Modify active IMPL |
| `/saw program --impl <slug> ...` | Bundle existing IMPLs into a parallel program (tier-assigned by file ownership) |
| `/saw program plan/execute/status/replan` | Top-down multi-feature planning and tier-gated execution |
| `/saw interview [--resume <path>] "<description>"` | Requirements gathering |


**Auto flow** (`auto <feature-description>`):
Collapses scout -> review -> wave into a single command. Human confirmation is
preserved -- /saw auto eliminates command overhead, not the review step.

1. Launch Scout agent (same as Scout flow step 1). Inform user.
2. When Scout completes, read `docs/IMPL/IMPL-<feature-slug>.yaml`.
3. **If NOT_SUITABLE:** Report verdict, reason, and suggested alternative. Stop.
4. **E16+E35: Validate IMPL doc.** Same as Scout flow step 3.
5. **Critic Gate (E37).** Same as Scout flow step 4.
6. Report: verdict (SUITABLE or SUITABLE_WITH_CAVEATS), wave structure summary,
   file ownership count, interface contract count. If SUITABLE_WITH_CAVEATS, show
   caveats explicitly before asking for confirmation.
7. **Scaffold Agent (conditional).** Same as Scout flow step 6.
8. Ask: "Proceed with wave execution? [y/N]"
   - N (or no input): "Auto flow cancelled. Review the IMPL doc and run `/saw wave` when ready." Stop.
   - Y: continue.
9. Execute waves with `--auto` behavior (I3: each wave waits for the prior wave to
   merge and verify before proceeding). Equivalent to `/saw wave --auto` starting
   at Wave 1.
10. On any wave failure: stop and report. Do not proceed.
11. On completion: report result (same as standard wave completion).

**`--skip-confirm` flag (expert/CI only):** Omits step 8. Removes the human
checkpoint entirely. NOT recommended for regular use.

## Pre-flight Validation

Run once per session on first `/saw` invocation. Skip on subsequent.

1. **sawtools on PATH**: `command -v sawtools` — blocker
2. **Skill files**: Check `${CLAUDE_SKILL_DIR}/agent-template.md` exists — blocker
3. **Git 2.20+**: `git --version` — blocker if < 2.20
4. **saw.config.json** (optional): If missing, suggest `sawtools init`. Not a blocker.

If 1-3 fail, print what's missing (see `docs/INSTALLATION.md`) and stop.

## Execution Models

**CLI orchestration (you):** Use Agent tool to launch agents. Manual flow: `create-worktrees` → launch → `merge-agents`. Only way to access Max plan/Bedrock/MCP. **Programmatic:** `sawtools run-wave` for automation (not available in CLI sessions).

## Execution Logic

**IMPL targeting:** Parse `--impl <value>` from arguments (slug / filename / path). When omitted, auto-select if exactly 1 pending IMPL exists. Parse `--impl` before other flags.

**Resume detection:** Run `sawtools resume-detect` before `wave` or `status` execution. For `status`, include resume state in report. For `wave`, report interrupted session and use `sawtools build-retry-context` for failed agents.

**Session stop detection:** The `saw_orchestrator_stop` Stop hook warns automatically when the session ends with an active IMPL in WAVE_PENDING or WAVE_EXECUTING state, or with active worktrees. No action needed — the hook fires passively at session end.

See `references/impl-targeting.md` for discovery commands, resolution logic, auto-selection rules, and cross-repo handling.

**On-demand reference routing:** If args start with `program `, read `references/program-flow.md` and stop. If args start with `amend `, read `references/amend-flow.md` and stop. Otherwise, continue below.

**Bootstrap flow** (`bootstrap <project-description>`):
1. **Requirements intake (Orchestrator duty).** Gather requirements, write `docs/REQUIREMENTS.md`. Cover: language, project type, deployment, key concerns, storage, integrations, source codebase. Confirm with user. Template in `saw-bootstrap.md`.
2. Launch Scout agent (`subagent_type: scout`, `run_in_background: true`) with `docs/REQUIREMENTS.md` and `saw-bootstrap.md` path. Inform user.
3. When Scout completes, read `docs/IMPL/IMPL-bootstrap.yaml`. Report architecture and wave structure. Ask user to review.
4. **Scaffold Agent (conditional):** If Scaffolds section has `Status: pending`, launch Scaffold Agent (`[SAW:scaffold:bootstrap]`). If any `Status: FAILED`, stop. If all `committed`, proceed.
5. **Wave 1:** Execute standard wave flow (step 2+ of IMPL-exists flow below).

**Scout flow** (no IMPL doc exists):
1. Launch Scout agent (`subagent_type: scout`, `run_in_background: true`, prompt = feature description). Inform user.
2. When Scout completes, read `docs/IMPL/IMPL-<feature-slug>.yaml`. Record injection method: `sawtools set-injection-method "<path>" --method hook`.
3. **E16+E35+TestCascade: Validate IMPL doc.** `sawtools pre-wave-validate "<path>" --wave 1 --fix`.
   Exit 0 = proceed. Exit 1 = send errors to Scout (resume), retry once. Failure = BLOCKED.
   Now includes Step 3: test cascade check — verifies that *_test.go files calling changed
   symbols are assigned to agents. See `references/pre-wave-validation.md`.
4. **Critic Gate (E37).** Check trigger conditions (3+ agents OR 2+ repos). If triggered:
   ```bash
   sawtools run-critic "<impl-path>"
   ```
   - **PASS** → proceed.
   - **ISSUES (error)** → fix errors in the IMPL doc, then **re-run `sawtools run-critic`**. The pre-wave gate reads `critic_report.verdict` — this field stays ISSUES until the critic is re-run and writes a new verdict. Do NOT manually edit the YAML verdict field.
   - See `references/pre-wave-validation.md` § E37.
5. Report suitability verdict, wave structure, file ownership, interface contracts, Scaffolds. Ask user to review.
6. **Scaffold Agent (conditional):** If Scaffolds has `Status: pending`, launch Scaffold Agent (`[SAW:scaffold:<slug>]`). If `FAILED`, stop. If `committed`, proceed.

If a `docs/IMPL/IMPL-*.yaml` file already exists:
1. Read it and identify the current wave. Check Scaffolds section: if any file has `Status: pending` or `Status: FAILED`, spawn/fix Scaffold Agent before creating worktrees.
2. **Critic gate (E37):** Check for non-empty `critic_report` field. If missing and E37 triggered (see `references/pre-wave-validation.md`), run E37. Otherwise skip.

3. **Integration wave (E27):** If `type: integration`, skip worktrees. For each agent: `sawtools prepare-agent --no-worktree`, launch `integration-agent` on main branch with `[SAW:wave{N}:agent-{ID}] wire integration`. Read `agent.integration_model` from config. Agent's `files` list constrains modifications. After all complete, proceed to step 7.
4. **Solo agent:** If exactly 1 agent (not integration type), skip worktrees. Run `sawtools prepare-agent --no-worktree`, launch `wave-agent` on main branch. After completes, proceed to step 7. Solo agents still operate in Wave Agent role (I6).
5. **Wave preparation (multi-agent):** For waves with 2+ agents:
   ```bash
   sawtools prepare-wave "<manifest-path>" --wave <N> --repo-dir "<repo-path>" [--commit-baseline]
   ```
   Combines worktree creation + agent preparation (brief extraction, journal init). Exit 1 = failure (E21A baseline gate, scaffolds, or worktree errors) — do not proceed.

   **--commit-baseline flag:** Auto-commits baseline fixes when working directory is dirty. **Always use with `--auto` flag** for autonomous execution. Without it, dirty working dir causes failure.

   **E43:** Hook-based isolation enforces worktree boundaries automatically. Agents don't need manual `cd` commands. See `protocol/execution-rules.md` E43.

   **E21A baseline failure:** Codebase already broken. Fix and re-run. See `references/pre-wave-validation.md` § E21A.

   Returns JSON with worktree paths and agent metadata. Result also written to `.saw-state/wave{N}/prepare-result.json` for automation-friendly access.

6. **Agent launching.** For each agent, launch with `subagent_type: wave-agent` and `run_in_background: true`. Use short IMPL-referencing prompts (~60 tokens). Agent reads full brief from `.saw-agent-brief.md`.

   **Journal context recovery (resumed agents):** The `prepare-wave` and `prepare-agent` JSON output includes `"journal_context_available"` per agent. If `true`, read the file at `"journal_context_file"` and prepend its contents to the agent's launch prompt (before the IMPL doc comment block). This restores working memory for agents resuming after context compaction or interruption. If `journal_context_available` is `false` (first launch or no prior history), omit this step.

**E44: Agent naming from brief metadata.** Read `.saw-agent-brief.md` frontmatter and extract `saw_name` field. Use this as the `name` parameter for the Agent tool call. The brief metadata contains the SAW-formatted name `[SAW:wave{N}:agent-{ID}] {task_summary}`. If frontmatter is missing or `saw_name` field is absent (old briefs), the `auto_format_saw_agent_names` PreToolUse hook provides fallback formatting.

**YAML manifest prompt template:**
```
<!-- IMPL doc: /abs/path/to/IMPL-feature.yaml | Wave N | Agent X -->
<!-- Worktree: /abs/path/to/.claude/worktrees/saw/{slug}/wave{N}-agent-{X} -->

Read .saw-agent-brief.md and follow exactly.
```

**Protocol contracts:** See `references/wave-agent-contracts.md` for I1 (disjoint ownership), I2 (interface-first), I5 (commit before report), E35 (own the caller), E42 (SubagentStop validation), SAW tag format, and async execution requirements.

**Status tracking:** After agent completes, run `sawtools update-status` with `--status complete/partial/blocked`.
7. **After all agents complete:** Read completion reports from IMPL doc (`### Agent {ID} - Completion Report`). **I4:** IMPL doc is single source of truth, not chat output. **I5:** Agents commit before reporting (see `references/wave-agent-contracts.md`). **E7:** If any agent reports `partial` or `blocked`, wave goes to BLOCKED. Resolve failing agent before merge. No partial merges. If non-complete status, read `references/failure-routing.md` for E7a retry, E19 routing, E8 interface failures, E20 stub scanning.

8. **Wave finalization:** Batch command verifies, merges, and cleans up:
   ```bash
   sawtools finalize-wave "<absolute-manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   **Always use absolute path for `<manifest-path>`.** Cross-repo IMPLs fail with relative paths. For cross-repo IMPLs, add `--cross-repo-verify` to run baseline gates on all repos after primary merge (catches cross-repo breakage early). Combines 6 steps: (1) verify-commits (E7), (2) scan-stubs (E20), (3) run-gates (E21), (4) merge-agents, (5) verify-build, (6) cleanup. Exit 1 = failure. For solo agents, run `verify-build` manually. For integration waves, skip merge-agents (no worktree branches).
8a. **E25/E26/E35: Integration gap detection.** After finalization succeeds, read `references/integration-gap-detection.md` for the 7-step integration gap detection workflow.
8b. **E47: Caller cascade hotfix.** `finalize-wave` automatically runs
   `apply-cascade-hotfix` (step 6a) when `CallerCascadeOnly=true`.
   When hotfix succeeds, `finalize-wave` exits 0 — proceed normally to
   step 9. To debug classification without running the agent:
   ```bash
   sawtools finalize-wave "<absolute-manifest-path>" --wave <N> --dry-run
   ```
   If hotfix fails (`finalize-wave` exits 1 with `"build still fails
   after hotfix"`), treat as a genuine build failure and route through E7/E8.
9. **E15: IMPL completion.** If final wave and verification passed:
   ```bash
   sawtools close-impl "<impl-doc-path>" --date "YYYY-MM-DD"
   ```
   Atomically: writes SAW:COMPLETE, archives to `docs/IMPL/complete/`, updates `docs/CONTEXT.md` (E18), cleans worktrees. Commit in single commit. Don't run if more waves remain.
10. **I3: Wave sequencing.** Wave N+1 launches only after Wave N merges and post-merge verification passes. If `--auto` and verification passed, proceed to next wave. Otherwise, report result and ask user.
11. If verification fails, report failures and ask user how to proceed.
