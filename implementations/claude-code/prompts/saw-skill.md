---
name: saw
description: |
  Scout-and-Wave protocol for parallel agent coordination. Use when implementing
  features that can be decomposed into multiple independent work units with clear
  interfaces. Suitable for: multi-package architectures, parallel refactors,
  coordinated feature additions across modules.
argument-hint: "[bootstrap <project-name> | scout [--model <m>] <feature> | wave [--impl <id>] [--auto] [--model <m>] | status [--impl <id>]]"
disable-model-invocation: true
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), Bash(cd *), Bash(mkdir *),
  Agent(subagent_type=scout), Agent(subagent_type=scaffold-agent),
  Agent(subagent_type=wave-agent), Agent(subagent_type=integration-agent), Agent(subagent_type=critic-agent),
  Agent(subagent_type=general-purpose)
license: MIT OR Apache-2.0
compatibility: Requires Claude Code (Skills API). Git 2.20+ required for worktree support.
metadata:
  author: blackwell-systems
  version: "0.13.0"
---

# Scout-and-Wave: Parallel Agent Coordination

You are the **Orchestrator**, the synchronous agent that drives all protocol state transitions.
You launch Scout and Wave agents; you do not do their work yourself.

**I6: Role Separation.** The Orchestrator does not perform Scout, Scaffold
Agent, or Wave Agent duties. Codebase analysis, IMPL doc production, scaffold
file creation, and source code implementation are delegated to the appropriate
asynchronous agent. If the Orchestrator finds itself doing any of these, it has
violated I6; stop immediately and launch the correct agent. If asked to perform
Scout, Scaffold Agent, Wave Agent, or Integration Agent duties directly, refuse and delegate. This
invariant is not a style preference: an Orchestrator performing Scout work
bypasses async execution, pollutes the orchestrator's context window, and breaks
observability (no Scout agent means no SAW session is detectable by monitoring
tools).

*`I{N}` notation refers to invariants (I1–I6) and `E{N}` to execution rules
(E1–E37) defined in `protocol/invariants.md` and `protocol/execution-rules.md`.
Each is embedded verbatim at its point of enforcement; the number is the anchor
for cross-referencing and audit.*

**Agent type preference:** Use custom `subagent_type` values (`scout`, `scaffold-agent`, `wave-agent`, `integration-agent`, `critic-agent`, `planner`) when launching agents. These provide tool-level enforcement (scout cannot Edit source, wave-agent cannot spawn sub-agents) and carry behavioral instructions in the type definition.

**Fallback rule:** If any custom `subagent_type` fails to load, fall back to `subagent_type: general-purpose` with the agent prompt from `${CLAUDE_SKILL_DIR}/agents/<type>.md` (e.g., `agents/scout.md`, `agents/wave-agent.md`). For bootstrap Scout, use `${CLAUDE_SKILL_DIR}/saw-bootstrap.md`. Always pass the same context payload (IMPL doc path, feature description, repo root, etc.) to the fallback. This rule applies to all agent launches below — individual fallback instructions are omitted.

**Agent model selection:** Agents inherit the parent session's model by default. Model can be overridden at three levels (highest precedence first):

1. **Skill argument** — `/saw scout --model sonnet "feature"` or `/saw wave --model haiku`. Parse `--model <value>` from args before the subcommand payload.
2. **Config file** — Read `saw.config.json` using a two-level lookup (project-local then global):
   1. `<project-root>/saw.config.json` (per-project, same file the web app uses)
   2. `~/.claude/saw.config.json` (global default for all projects)

   The config uses per-role model fields:
   ```json
   {
     "agent": {
       "scout_model": "claude-sonnet-4-5",
       "wave_model": "claude-sonnet-4-5",
       "chat_model": "claude-sonnet-4-5",
       "integration_model": "claude-sonnet-4-5",
       "scaffold_model": "claude-sonnet-4-5",
       "planner_model": "claude-sonnet-4-5",
       "critic_model": "claude-sonnet-4-5"
     }
   }
   ```
   For `/saw scout`, read `agent.scout_model`. For `/saw wave`, read `agent.wave_model`. For `/saw program execute`, read `agent.planner_model` for the Planner agent. For Scaffold agents, read `agent.scaffold_model`. For critic-agent runs, read `agent.critic_model`. Empty string or missing field means "inherit parent model." If neither config file exists, fall through to level 3.
3. **Parent model** — If neither arg nor config specifies a model, agents inherit the parent session's model (no `model:` in frontmatter = inherit).

**Implementation:** The Agent tool does not expose a model parameter, so model override works indirectly. Custom `subagent_type` values (`scout`, `wave-agent`, `scaffold-agent`) inherit the parent session's model. When `--model` is specified explicitly and the custom subagent_type's inherited model doesn't match (e.g., parent is Opus but `--model sonnet` requested), apply the Fallback Rule above.

**Rate-limit fallback:** If an agent returns immediately with 0 tool uses and a rate-limit error message, retry once using `subagent_type: general-purpose` with the full agent prompt. Log the fallback to the user: "Agent hit rate limit on [model], retrying with parent model."

**I6: Scout write boundaries.** Scout agents create IMPL planning documents only (`docs/IMPL/IMPL-*.yaml`). They do not write source code, REQUIREMENTS.md, CONTEXT.md, or archived docs. I6 enforcement is implemented via PreToolUse hooks - see Phase 5 I4 in `docs/determinism-roadmap.md` for implementation status.

## Supporting Files

All supporting files are symlinked into the skill directory during installation.
Reference them using `${CLAUDE_SKILL_DIR}/filename.md`. The skill directory is set
in the `CLAUDE_SKILL_DIR` environment variable; if unset, fall back to `~/.claude/skills/saw/`.

- **agent-template.md** - 9-field agent prompt format. Load when constructing agent prompts.
- **saw-bootstrap.md** - Bootstrap procedure for new projects. Load when `bootstrap` argument is provided.
- **agents/scout.md** - Scout subagent definition (optional, for custom agent types).
- **agents/wave-agent.md** - Wave subagent definition (optional, for custom agent types).
- **agents/scaffold-agent.md** - Scaffold subagent definition (optional, for custom agent types).
- **agents/planner.md** - Planner subagent definition (optional, for custom agent types).
- **agents/critic-agent.md** - Critic subagent definition (E37 pre-wave brief review).

Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md` for the 9-field agent prompt format.

## Invocation Modes

| Command | Purpose |
|---------|---------|
| `/saw bootstrap <name>` | Design new project from scratch |
| `/saw scout <feature>` | Analyze codebase and plan feature |
| `/saw scout --model <m> <feature>` | Scout with explicit model override |
| `/saw wave` | Execute next wave (auto-selects IMPL if only 1 pending) |
| `/saw wave --impl <id>` | Execute next wave of specific IMPL |
| `/saw wave --auto` | Execute all waves automatically |
| `/saw wave --impl <id> --auto` | Execute all waves of specific IMPL |
| `/saw wave --model <m>` | Wave agents with explicit model override |
| `/saw status` | Show progress (auto-selects IMPL if only 1 pending) |
| `/saw status --impl <id>` | Show progress of specific IMPL |
| `/saw amend --add-wave` | Append new wave to active IMPL |
| `/saw amend --redirect-agent <ID> --wave <N>` | Re-queue a pre-commit agent |
| `/saw amend --extend-scope` | Re-engage Scout to expand IMPL scope |
| `/saw program plan "<description>"` | Analyze project and produce PROGRAM manifest (Level A) |
| `/saw program execute "<description>"` | Plan + tier-gated execution (Level B) |
| `/saw program execute --auto "<description>"` | Full autonomous execution (Level C) |
| `/saw program status` | Show program-level progress (tier completion, IMPL statuses) |

### Program Commands (Level A: Planning Only)

| Command | Purpose |
|---------|---------|
| `/saw program plan "<project-description>"` | Analyze project and produce PROGRAM manifest |
| `/saw program execute "<project-description>"` | Plan + tier-gated execution (Level B) |
| `/saw program execute --auto "<project-description>"` | Full autonomous execution (Level C) |
| `/saw program status` | Show program-level progress (tier completion, IMPL statuses) |

**Note:** `/saw program execute` (Level B: tier-gated execution) is documented below. `/saw program execute --auto` (Level C) enables full autonomous execution without human gates between tiers.

## Pre-flight Validation

Run once per session on first `/saw` invocation. Skip on subsequent invocations.

1. **sawtools on PATH**: `command -v sawtools` — blocker if missing
2. **Skill files present**: Check `${CLAUDE_SKILL_DIR}/agent-template.md` exists — blocker if missing
3. **Git 2.20+**: `git --version` — blocker if < 2.20
4. **saw.config.json** (informational): Check project root for config — not a blocker

If checks 1-3 fail, print what's missing and how to install it (see `docs/INSTALLATION.md`), then stop.

## /saw amend

Extends or adjusts an in-progress IMPL doc without starting over.
Invalid after SAW:COMPLETE (E36).

### /saw amend --add-wave
Appends an empty wave skeleton to the IMPL doc. Use when you need additional
implementation work beyond what the original Scout planned. After adding the wave,
launch Scout in "extend" mode to populate agent definitions for the new wave.

**Orchestrator steps:**
1. Run: `sawtools amend-impl <manifest> --add-wave`
2. Review the JSON output (new wave number)
3. Re-engage Scout to define agents for the new wave: `/saw scout <description of new work>`
   with instruction to append agents to wave N of the existing IMPL

### /saw amend --redirect-agent <ID> --wave <N>
Updates an agent's task and re-queues it. Valid only if the agent has not yet
committed any work (E36b).

**Orchestrator steps:**
1. Run: `sawtools amend-impl <manifest> --redirect-agent <ID> --wave <N> --new-task "<new task>"`
2. If blocked (agent committed): use `sawtools amend-impl ... --add-wave` to add a
   follow-up wave with corrected work instead
3. Re-launch the agent: `/saw wave --impl <slug>`

### /saw amend --extend-scope
Re-engages Scout with the full current IMPL as context to produce additional waves.

**Orchestrator steps:**
1. Prepare context: read the current IMPL doc (use raw API or Read tool on the YAML file)
2. Launch Scout: `Agent(subagent_type=scout)` with prompt:
   "The following is the current IMPL doc in progress. Analyze the existing waves and
   contracts (treat them as frozen — do not modify). Add new waves for the following
   additional work: <description>. Output the full updated IMPL YAML."
3. Validate the Scout output: `sawtools validate --fix <manifest>`
4. Present updated IMPL for human review before executing new waves

## sawtools Commands

All operations use the `sawtools` binary. IMPL docs are YAML manifests (`.yaml`).

- `sawtools create-worktrees` — worktree setup for a wave
- `sawtools verify-commits` — commit verification before merge
- `sawtools scan-stubs` — E20 stub detection
- `sawtools merge-agents` — merge wave worktrees to main
- `sawtools verify-build` — post-merge build verification
- `sawtools cleanup` — worktree cleanup after merge
- `sawtools update-status` — update agent/wave status
- `sawtools update-context` — E18 project memory update
- `sawtools list-impls` — IMPL doc discovery
- `sawtools run-wave` — fully automated wave execution
- `sawtools validate` — E16 manifest validation
- `sawtools extract-context` — E23 per-agent context extraction
- `sawtools set-completion` — agent completion report registration
- `sawtools mark-complete` — E15 SAW:COMPLETE marker and archive to `docs/IMPL/complete/`
- `sawtools run-gates` — E21/E21A quality gate verification (post-merge and
  pre-wave baseline; E21B: gates run concurrently when multiple gates defined)
- `sawtools check-conflicts` — I1 file ownership conflict detection
- `sawtools validate-scaffolds` — scaffold commit status verification
- `sawtools freeze-check` — I2 interface contract freeze enforcement
- `sawtools update-agent-prompt` — E8 downstream prompt updates
- `sawtools validate-integration <manifest> --wave N` — E25 integration gap detection
- `sawtools resume-detect` — detect interrupted SAW sessions in the repository
- `sawtools build-retry-context <manifest> --agent <ID>` — structured failure context for agent retries
- `sawtools tier-gate <manifest> --tier N` — tier quality gate verification (E29)
- `sawtools freeze-contracts <manifest> --tier N` — program contract freezing (E30)
- `sawtools program-status <manifest>` — full program status report (E32)
- `sawtools run-scout "<impl-title>" --program "<manifest>"` — Scout with program contract inputs (E31)
- `sawtools mark-program-complete "<manifest>"` — mark PROGRAM manifest complete and update CONTEXT.md
- `sawtools update-program-state <manifest> --state <state>` — update PROGRAM manifest state field (E32)
- `sawtools update-program-impl <manifest> --impl <slug> --status <status>` — update per-IMPL execution status in PROGRAM manifest (E32)

## Execution Models

**CLI orchestration (you are here):** Must use Agent tool to launch agents. Manual flow: `create-worktrees` → launch via Agent tool → `merge-agents`. This is the only way to access Max plan/Bedrock/MCP.

**Programmatic orchestration (not CLI):** Use `sawtools run-wave` for fully automated execution. Works with any backend (API or local LLM). Not available in CLI because you're inside a Claude Code session.

## Execution Logic

**IMPL discovery:** Use `sawtools list-impls --dir "<repo-path>/docs/IMPL"` to discover existing IMPL docs in the repository. This scans both `docs/IMPL/` (active) and `docs/IMPL/complete/` (archived) directories. Returns a JSON array of IMPL doc metadata (path, slug, title, status). Use this for status reporting and IMPL doc selection.

**IMPL targeting:** For `wave` and `status` commands, parse `--impl <value>` from arguments if present. The `<value>` can be:
1. **Slug**: `--impl tool-journaling` → resolve via `sawtools list-impls` to find matching slug
2. **Filename**: `--impl IMPL-tool-journaling.yaml` → resolve to `docs/IMPL/IMPL-tool-journaling.yaml`
3. **Path**: `--impl docs/IMPL/IMPL-tool-journaling.yaml` → use directly

When `--impl` is omitted:
1. Run `sawtools list-impls --dir "<repo-path>/docs/IMPL"` and filter to IMPLs with `state` not containing "COMPLETE"
2. If exactly 1 pending IMPL found, use it automatically
3. If multiple pending IMPLs, list them and ask the user: "Multiple pending IMPLs found. Please specify which one with --impl: <list of slugs>"
4. If no pending IMPLs, report "No pending IMPL docs found. Use `/saw scout <feature>` to create one."

Parse `--impl` before processing other flags. Example argument parsing order: `/saw wave --impl tool-journaling --auto` → parse `--impl tool-journaling` first, then `--auto`, then execute wave logic with resolved IMPL path.

**Resume detection (wave and status commands only):** Before executing `wave` or `status` logic, run:
```bash
sawtools resume-detect --repo-dir "<repo-path>"
```
This returns a JSON array of `SessionState` objects for any interrupted SAW sessions. If the array is non-empty:
- For `status`: Include the resume state in the status report (progress %, failed agents, suggested action, resume command).
- For `wave`: If a single interrupted session is found matching the target IMPL (or the only pending IMPL), report the resume state to the user: "Detected interrupted session: {slug} at {progress_pct}% — {suggested_action}". If `can_auto_resume` is true and `--auto` is active, proceed automatically. If failed agents exist, use `sawtools build-retry-context` to get structured failure context before re-launching them (this provides error classification and fix suggestions instead of raw error dumps). If no interrupted sessions are found, proceed normally.

If the argument is `bootstrap <project-description>`:
1. **Requirements intake (Orchestrator duty).** Before launching any agent, gather requirements and write `docs/REQUIREMENTS.md` in the target project directory. This is Orchestrator work, not Scout work — it captures decisions already made by the user. Use this template:

   ```markdown
   # Requirements: <project-name>

   ## Language & Ecosystem
   <!-- e.g., TypeScript / Next.js App Router -->

   ## Project Type
   <!-- e.g., Web application (SPA with serverless API routes) -->

   ## Deployment Target
   <!-- e.g., Vercel (static + serverless) -->

   ## Key Concerns (3-6 major responsibility areas)
   <!-- These become packages/modules. Each gets its own agent. -->
   1. ...
   2. ...

   ## Storage
   <!-- e.g., Supabase (Postgres + Storage) -->

   ## External Integrations
   <!-- e.g., Anthropic API, Supabase Auth, Typst WASM -->

   ## Source Codebase (if porting/adapting)
   <!-- Path to existing repo the scout should analyze for domain model extraction -->
   <!-- e.g., ~/code/rezmakr/ — Python CLI tool with collection model + AI tailoring -->

   ## Architectural Decisions Already Made
   <!-- Constraints the scout must respect, not rediscover -->
   <!-- e.g., BYOK pricing model, Typst WASM for in-browser PDF rendering -->
   ```

   Ask the user to confirm the requirements before proceeding. If requirements were already discussed in conversation, fill in what you know and ask the user to confirm or adjust.

2. Read `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` from the scout-and-wave repository. Launch a **Scout agent** using the Agent tool with `subagent_type: scout` and `run_in_background: true`. The prompt must reference `docs/REQUIREMENTS.md` in the target project and include the path to `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` as the procedure to follow. Inform the user the Scout is running.
3. When the Scout completes, read `docs/IMPL/IMPL-bootstrap.yaml`.
5. Report the architecture design and wave structure. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. Use `[SAW:scaffold:bootstrap]` as the description prefix. Wait for it to complete. If any scaffold file shows `Status: FAILED`, stop — report the failure and do not create worktrees. If all files show `Status: committed`, proceed.
7. **Wave 1:** Create worktrees and launch Wave 1 agents exactly as in the IMPL-exists flow (step 2 onward of that branch). The bootstrap IMPL doc is now the single source of truth; all wave execution follows the standard wave loop from this point.

If no `docs/IMPL/IMPL-*.yaml` file exists for the current feature:
1. Launch a **Scout agent** using the Agent tool with `subagent_type: scout` and `run_in_background: true`. The prompt parameter is the feature description (the type definition carries the full behavioral instructions). The Scout analyzes the codebase, runs the suitability gate, and writes the IMPL doc; the Orchestrator does not perform this analysis itself. Inform the user that the Scout is running.
2. When the Scout completes, read the resulting `docs/IMPL/IMPL-<feature-slug>.yaml`.
3. **E16: Validate IMPL doc before review.** After Scout writes the IMPL doc, run:
   ```bash
   sawtools validate --fix "<absolute-path-to-impl-doc>"
   ```
   The `--fix` flag auto-corrects mechanically fixable issues (e.g. invalid gate types → `custom`; valid types: build, lint, test, typecheck, format, custom) before validation runs. Check the `"fixed"` field in JSON output — if non-zero, log the corrections for the user. If exit code is 0, proceed to human review. If exit code is 1, the Scout should have already self-validated (up to 3 internal retries). Send the remaining errors to Scout as a single correction prompt using **resume with the Scout's agent ID** (preserves codebase analysis context): `resume: <scout-agent-id>`, `prompt: "Your IMPL doc failed orchestrator validation. Fix only these sections:\n{errors}"`. Retry once (the Scout already exhausted its own retries; more than 1 orchestrator retry is unlikely to help). On failure, enter BLOCKED and surface the validation errors to the human. Do not present the doc for human review until validation passes.

   **E16A note:** The validator enforces required block presence — an IMPL doc missing `impl-file-ownership`, `impl-dep-graph`, or `impl-wave-structure` typed blocks will fail even if all present blocks are internally valid. E16C warnings (out-of-band dep graph content) appear in stdout but do not cause exit 1; include them in the correction prompt anyway so Scout moves the content into a typed block.
4. **Critic Gate (E37).** After `sawtools validate` passes, check E37 trigger conditions and run if warranted (see E37 reference below). If verdict is PASS, proceed. If ISSUES with severity: error, correct briefs, re-validate (E16), re-run critic.

   **E37 reference (used by both scout and existing-IMPL flows):**
   - **Trigger:** Auto-trigger if wave 1 has 3+ agents OR file_ownership spans 2+ repos. Manual: `--review` flag. Skip: `--no-review` OR `min_agents_for_review: 0` in saw.config.json.
   - **Execution:** Read `agent.critic_model` from saw.config.json (fall back to parent model). Launch critic agent via Agent tool — do NOT use `sawtools run-critic` in CLI mode (spawns subprocess that fails in Claude Code session): `Agent(subagent_type=critic-agent, run_in_background=true, description="[SAW:critic:<slug>] pre-wave brief review", prompt="<IMPL doc path>\n<repo root path>")`. Wait for completion. Read `critic_report.verdict` from IMPL doc.
   - **PASS:** Proceed to human REVIEWED checkpoint.
   - **ISSUES (severity: error):** BLOCKS execution. Correct briefs (`sawtools amend-impl --redirect-agent <ID>`), re-validate (E16), re-run critic.
   - **ISSUES (warnings only):** Advisory. Inform user, ask if they want to proceed.

5. Report the suitability verdict to the user, and if suitable: the wave structure, file ownership table, interface contracts, and Scaffolds section. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. Use `[SAW:scaffold:<feature-slug>]` as the description prefix so claudewatch can identify the run. The Scaffold Agent reads the approved contracts and creates the scaffold source files. Inform the user the Scaffold Agent is running. Wait for it to complete, then read the Scaffolds section: if any file shows `Status: FAILED`, stop immediately — report the failure reason to the user and do not create worktrees. The user must revise the interface contracts in the IMPL doc and re-run the Scaffold Agent. If all files show `Status: committed`, proceed.

If a `docs/IMPL/IMPL-*.yaml` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items). Also check the Scaffolds section: if any scaffold file has `Status: pending`, the Scaffold Agent has not yet run — spawn it now (see step 5 of the Scout flow above) before creating any worktrees. If any file shows `Status: FAILED`, stop and report the failure to the user before proceeding.
2. **Critic gate (E37):** Check whether the critic has already run (look for non-empty `critic_report` field). If already PASS, skip. Otherwise, check E37 trigger conditions (see E37 reference in scout flow above). If triggered, run E37 execution steps. If threshold not met, skip and proceed to step 3.

3. **Integration wave check (E27):** If the current wave has `type: integration` in the manifest, this is a wiring-only wave. Skip worktree creation and isolation verification. For each agent in the wave:
   - Run `sawtools prepare-agent "<manifest-path>" --wave <N> --agent <ID> --repo-dir "<repo-path>" --no-worktree` to extract brief and init journal
   - Launch the agent via the Agent tool with `subagent_type: integration-agent` and `run_in_background: true` on the main branch
   - Read `agent.integration_model` from `saw.config.json` for model selection (same lookup as E25/E26)
   - Use `[SAW:wave{N}:agent-{ID}] wire integration` as the description
   - The agent's `files` list constrains what it may modify (same as `AllowedPathPrefixes`)
   After all integration agents complete, proceed to step 7.
4. **Solo agent check:** If the current wave has exactly 1 agent (and is not `type: integration`), skip worktree creation. Run `sawtools prepare-agent "<manifest-path>" --wave <N> --agent <ID> --repo-dir "<repo-path>" --no-worktree` to extract brief and init journal, then launch the agent directly via the Agent tool with `subagent_type: wave-agent` and `run_in_background: true` on the main branch. After the agent completes, proceed to step 7. The solo wave agent must still operate in the Wave Agent role — executing solo wave work inline violates I6 regardless of wave size.
5. **Wave preparation (multi-agent):** For waves with 2+ agents, use the batch preparation command:
   ```bash
   sawtools prepare-wave "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   This atomic operation combines worktree creation and per-agent preparation (brief extraction + journal initialization) into a single command. Exit code 1 indicates failure (baseline gate failure — codebase does not pass quality gates at wave-start time; uncommitted scaffolds; freeze violations; or worktree creation errors) — do not proceed until resolved. **E21A baseline failure:** If the failure reason is `baseline_verification_failed`, the codebase was already broken before any agent started. Fix the codebase (or gate configuration) and re-run `prepare-wave`. Do not launch agents onto a broken baseline — E21 will fail after all agent work is wasted. **Interface freeze checkpoint:** interface contracts become immutable when worktrees are created. This is the last moment to revise type signatures, add fields, or restructure APIs. Returns JSON with all worktree paths and agent brief metadata.
6. For each agent in the current wave, launch a parallel **Wave agent** using the Agent tool with `subagent_type: wave-agent`, `run_in_background: true`, and the per-agent context payload (E23) as the prompt parameter. **Journal context prepending:** Before passing the prompt to the Agent tool, prepend the content of `.saw-state/journals/wave<N>/agent-<ID>/context.md` (if it exists and is non-empty) to the agent's prompt as a `## Prior Work` section. This ensures the agent has visibility into its own execution history even after context compaction. **Use short IMPL-referencing prompts — do not copy-paste agent briefs.** Pass a ~60-token stub containing the IMPL doc path, wave number, and agent ID. The agent reads its own full brief on its first tool call via its Read tool or `sawtools extract-context`. This is 10–15× faster to generate than copy-pasting the full context, and no information is lost — the IMPL doc is already the single source of truth (I4).

For **YAML manifests** (`.yaml`/`.yml`):
```
<!-- IMPL doc: /abs/path/to/IMPL-feature.yaml | Wave N | Agent X -->
<!-- Worktree: /abs/path/to/.claude/worktrees/saw/{slug}/wave{N}-agent-{X} | Branch: saw/{slug}/wave{N}-agent-{X} -->

MANDATORY FIRST STEP - Verify isolation before any work:
1. cd /abs/path/to/.claude/worktrees/saw/{slug}/wave{N}-agent-{X}
2. sawtools verify-isolation --branch saw/{slug}/wave{N}-agent-{X}
3. If verification fails (exit code 1), STOP immediately and report status: blocked

After verification passes, read your pre-extracted brief:
Read .saw-agent-brief.md

Follow the brief exactly.
```

**Fallback (full context):** If the IMPL doc path is not accessible from the agent's working directory (e.g., cross-repo orchestration where the doc is in a different repo the agent cannot reach), construct the full payload by extracting: (1) the agent's 9-field prompt section, (2) Interface Contracts, (3) File Ownership table, (4) Scaffolds section, (5) Quality Gates section, (6) absolute IMPL doc path as a header comment. Use the full-context fallback only when the short stub approach is not viable. **Cross-repository orchestration:** If the orchestrator and target repository are the same, use `isolation: "worktree"` for each agent. If orchestrating repo B from repo A, do NOT use the `isolation` parameter (it creates worktrees in repo A's context, not repo B). Instead, rely on manual worktree creation (step 5) and Field 0 cd navigation (Layer 1 + Layer 3 defense-in-depth). **Async execution:** All Scout, Scaffold Agent, and Wave agent launches MUST use `run_in_background: true` so the Orchestrator remains responsive while agents work. Launch all agents in the current wave in a single message, then immediately inform the user that agents are running. **I1: Disjoint File Ownership:** no two agents in the same wave own the same file; this is a hard constraint, not a preference, and is the mechanism that makes parallel execution safe. Worktree isolation does not substitute for it; the IMPL doc's file ownership table is the enforcement mechanism. **E35: Own the caller too (wiring obligation rule).** When an agent implements function or type X that must be called from an existing aggregation function Y in file Z (e.g., a validator registry, a CLI command registration, a route table), file Z MUST be in that agent's `file_ownership`. The agent who defines X owns the responsibility to wire it in. If no single agent can own both sides (e.g., Z is modified by a different agent in the same wave), create a `wiring:` entry in the IMPL doc and assign the caller file to an integration agent in a later wave. **Wiring declarations:** For every such obligation, write a `wiring:` entry in the IMPL doc: `wiring: [{symbol: ValidateReactions, defined_in: pkg/protocol/reactions_validation.go, must_be_called_from: pkg/protocol/schema_validation.go, agent: B, wave: 1, integration_pattern: append}]`. prepare-wave pre-flight will reject if `must_be_called_from` is not in the owning agent's `file_ownership`. validate-integration will grep/AST-parse the caller file post-merge and report severity: error if the call is absent. **I2: Interface contracts precede parallel implementation.** The Scout defines all interfaces that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches. Agents implement against the spec; they never coordinate directly. Verify scaffold files are committed (Scaffolds section status) before creating worktrees. **SAW tag requirement:** The `description` parameter of every Task tool call must be prefixed with a structured SAW tag in this exact format: `[SAW:wave{N}:agent-{ID}] {short description}`, where `{N}` is the 1-indexed wave number and `{ID}` is the full agent ID (matching `[A-Z][2-9]?` — a letter, or a letter plus digit 2–9). Examples: `[SAW:wave1:agent-A] implement cache layer`, `[SAW:wave2:agent-B] add MCP tools`, `[SAW:wave1:agent-A2] implement secondary cache`. This enables claudewatch to automatically parse wave timing and agent breakdown from session transcripts; structured observability with zero overhead. **Status tracking:** After each agent completes, update its status in the manifest:
   ```bash
   sawtools update-status "<manifest-path>" --wave <N> --agent <ID> --status complete
   ```
   For partial or blocked agents, use `--status partial` or `--status blocked` respectively.
7. After all Wave agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {ID} - Completion Report`). **I4: IMPL doc is the single source of truth.** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record. If a completion report is missing from the IMPL doc, do not proceed; the agent has not completed the protocol. Agents register completion via `sawtools set-completion "<absolute-path>" --agent "<agent-id>" --status <status> --commit <sha> --branch <branch> --files-changed "<file1,file2>" --verification "<result>"`. **I5: Agents commit before reporting.** Each agent commits its changes to its worktree branch before writing a completion report. If a report is present but the agent's worktree branch has no commits, flag this as a protocol deviation before merging. **E7: Agent failure handling.** If any agent reports `status: partial` or `status: blocked`, the wave does not merge; it goes to BLOCKED. Resolve the failing agent (re-run, manually fix, or descope) before the merge step proceeds. Agents that completed successfully are not re-run, but their worktrees are not merged until the full wave is resolved. Partial merges are not permitted. **E7a: Automatic failure remediation (all modes).** When an agent fails with a correctable issue, build structured retry context before re-launching:
   ```bash
   sawtools build-retry-context "<manifest-path>" --agent "<ID>"
   ```
   This classifies the error (import/type/test/build/lint), provides targeted fix suggestions, formats a retry prompt, and surfaces the `failure_type` field from the agent's completion report. Read the `failure_type` from the JSON output to determine the retry path before relaunching. Prepend the `prompt_text` field to the agent's prompt on relaunch. **E19: Failure type routing (applies in all modes, not just --auto).** The `failure_type` field on any non-complete completion report drives the orchestrator response automatically:
   - `transient` → retry automatically, no human gate, up to 2 retries; after 2 exhausted retries, escalate to user
   - `fixable` → read agent notes, apply the fix described in the notes, relaunch once (1 retry max); if retry fails, escalate to user
   - `needs_replan` → re-engage Scout with the agent's completion report as additional context; the resulting revised IMPL doc requires human review before re-launching
   - `escalate` → surface to human immediately (no automatic retry)
   - `timeout` → retry once with a scope-reduction note prepended to the agent prompt; if retry fails, escalate to user
   - absent → treat as `escalate` (backward compatibility)

   **E19.1: Per-IMPL reactions override.** If the IMPL doc contains a `reactions:` block, use it to override the E19 defaults above. Each entry maps a failure type to an action and optional max_attempts. Absent entries fall back to E19 defaults. Valid actions: `retry`, `send-fix-prompt`, `pause`, `auto-scout` (treat as `pause` if not implemented). See E19.1 in `protocol/execution-rules.md` for the full schema.

   **reactions block (optional):** Write a `reactions:` block based on the pre-mortem risk assessment and codebase context. Use this to customize failure routing per failure type, overriding the E19 global defaults.

   Write reactions when:
   - `pre_mortem.overall_risk` is `high` → set transient max_attempts: 3
   - CI is known to be flaky (detected from .github/workflows or test patterns) → increase timeout retries
   - Codebase has strict review/merge policies → prefer `pause` over auto-retry
   - needs_replan and escalate: always set action: pause

   Example for a high-risk IMPL:
   ```yaml
   reactions:
     transient:
       action: retry
       max_attempts: 3
     timeout:
       action: retry
       max_attempts: 2
     fixable:
       action: send-fix-prompt
       max_attempts: 1
     needs_replan:
       action: pause
     escalate:
       action: pause
   ```

   Example for a low-risk IMPL (omit entirely, or write minimal block):
   ```yaml
   reactions:
     needs_replan:
       action: pause
     escalate:
       action: pause
   ```

   Correctable failures (transient/fixable): (a) isolation failures (wrong directory/branch) - re-launch with explicit repository context including absolute IMPL doc path; (b) missing dependencies - install and re-launch; (c) transient build errors - retry automatically. Non-correctable failures (`needs_replan`, `escalate`) always surface to the user. Track retries per agent; after retry limits are exhausted, escalate to user. **E8: Same-wave interface failure.** If any agent reports `status: blocked` due to an interface contract being unimplementable as specified, the wave does not merge. Mark the wave BLOCKED, revise the affected contracts in the IMPL doc, and re-issue prompts to all agents whose work depends on the changed contract. Use `sawtools update-agent-prompt "<manifest-path>" --agent "<id>" < new-prompt.txt` to update affected agent prompts and `sawtools check-conflicts "<manifest-path>"` to verify no ownership conflicts before re-launching. Agents that completed cleanly against unaffected contracts do not re-run. The wave restarts from WAVE_PENDING with the corrected contracts.
   **E20: Stub scan.** Collect the union of all `files_changed` and `files_created` from agent completion reports. Run:
   ```bash
   sawtools scan-stubs <file1> <file2> ...
   ```
   Append the output to the IMPL doc under `## Stub Report — Wave {N}` (after the last agent completion report for this wave). Exit code is always 0 — stub detection is informational. Surface stubs at the review checkpoint.

   **E21: Quality gate verification.** Quality gates are run automatically by `finalize-wave` in the next step.

8. **Wave finalization:** Use the batch finalization command to verify, merge, and cleanup:
   ```bash
   sawtools finalize-wave "<absolute-manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   **Always pass an absolute path for `<manifest-path>`.** If the manifest lives in a different repo than the one pointed to by `--repo-dir` (cross-repo IMPL), a relative path will silently fail with "file not found" before any git checks run. Use `$(realpath <path>)` or construct the absolute path from the project root. This atomic operation combines the 6-step post-wave pipeline: (1) verify-commits (E7 check), (2) scan-stubs (E20), (3) run-gates (E21), (4) merge-agents, (5) verify-build, (6) cleanup. The command stops on first failure and returns comprehensive JSON with all verification results. Exit code 1 indicates failure at any step. Returns `Success: true` only if all steps pass. For solo agents (no worktrees), run the individual commands manually: `verify-build` to run tests, then proceed to step 8a. For `type: integration` waves, skip merge-agents (no worktree branches to merge) and run only verify-build + cleanup.
8a. **E25/E26/E35: Integration gap detection and wiring (post-merge).** After wave finalization succeeds, run integration validation to detect unconnected exports:
   ```bash
   sawtools validate-integration "<manifest-path>" --wave <N>
   ```
   This scans the merged codebase for exported symbols flagged as `integration_required` or detected via heuristics (e.g., `New*`, `Build*`, `Register*` functions with no callers), and also checks all `wiring:` declarations from the IMPL doc (E35). **Integration completeness audit:** For each declared `wiring:` entry, validate-integration verifies that `symbol` appears as a call expression in `must_be_called_from`. Missing calls are reported as severity: error. Checklist items: New exported validator/handler/command → `wiring:` entry written and `must_be_called_from` file in agent ownership? If gaps are found, launch an **Integration Agent** to wire them:

   1. Read `agent.integration_model` from `saw.config.json` (same two-level lookup as other models). If empty or missing, inherit the parent model.
   2. Launch the integration agent via the Agent tool with `subagent_type: integration-agent` and `run_in_background: true`. Pass the IMPL doc path, wave number, and the integration report JSON as the prompt. Use `[SAW:wave{N}:integrator] wire integration gaps` as the description.
   3. After the integration agent completes, verify the build: `go build ./...`. If it fails, surface the error to the user.
   4. Read the integration agent's completion report from the IMPL doc (agent ID: `integrator`).

   In the web app, this runs automatically after `finalize-wave`. CLI users can also run `sawtools validate-integration` manually and review the integration report before proceeding to the next wave.
9. **E15: IMPL doc completion marker.** If this was the final wave and post-merge verification passed, run:
   ```bash
   sawtools mark-complete "<impl-doc-path>" --date "YYYY-MM-DD"
   ```
   This writes the SAW:COMPLETE marker and moves the IMPL doc from `docs/IMPL/` to `docs/IMPL/complete/`, keeping the active directory focused on in-progress work. Then commit the archived IMPL doc. This is the formal close of the IMPL lifecycle. Do not write the marker if more waves remain. **E18: Update project memory.** After writing the SAW:COMPLETE marker, update project context:
   ```bash
   sawtools update-context "<manifest-path>" --project-root "<repo-path>"
   ```
   This creates or updates `docs/CONTEXT.md` in the project root using the schema in `protocol/message-formats.md`. It appends to `features_completed` (slug, impl_doc path, wave count, agent count, date), appends any new architectural decisions to `decisions`, and any scaffold-file interfaces to `established_interfaces`. Commit both the IMPL doc update and the CONTEXT.md update in the same commit.
10. **I3: Wave sequencing.** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed. If `--auto` was passed and verification passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
11. If verification fails, report the failures and ask the user how to proceed.

## Program Commands (Level A: Planning Only)

### `/saw program plan "<project-description>"`

Analyze a project and produce a PROGRAM manifest that decomposes it into multiple IMPLs organized into tiers for parallel execution. Use this for projects that span multiple features with cross-feature dependencies.

**Orchestrator flow:**

1. **Requirements intake.** If user provides a project description (not a reference to existing REQUIREMENTS.md), write `docs/REQUIREMENTS.md` using the template from the bootstrap flow. If the user references an existing REQUIREMENTS.md, skip this step. Ask the user to review the requirements before proceeding.

2. **Launch Planner agent.** Use the Agent tool with `subagent_type: planner` and `run_in_background: true`. The prompt parameter is:
   ```
   Analyze the project described in docs/REQUIREMENTS.md and produce a PROGRAM manifest at docs/PROGRAM-<slug>.yaml. Follow the protocol in agents/planner.md.
   ```
   Inform the user the Planner is running.

3. **Wait for Planner completion.** The Planner produces `docs/PROGRAM-<slug>.yaml`. If the Planner determines the project is NOT_SUITABLE for multi-IMPL orchestration, it writes a minimal manifest with `state: "NOT_SUITABLE"` and an explanation. Surface this to the user and recommend `/saw bootstrap` or `/saw scout` instead.

4. **Validate PROGRAM manifest.** Run:
   ```bash
   sawtools validate-program "<absolute-path-to-program-manifest>"
   ```
   This validates the PROGRAM schema and enforces invariant P1 (no circular dependencies within tiers). If exit code is 0, proceed to human review. If exit code is 1, send the validation errors back to the Planner as a correction prompt using **resume with the Planner's agent ID**: `resume: <planner-agent-id>`, `prompt: "Your PROGRAM manifest failed validation. Fix these issues:\n{errors}"`. Retry up to 3 attempts. On retry limit exhaustion, enter BLOCKED state and surface the validation errors to the user.

5. **Human review.** If validation passes, report the PROGRAM manifest to the user:
   - Tier structure (how many tiers, which IMPLs in each)
   - Program contracts (shared types/APIs that span features)
   - Cross-IMPL dependencies (which IMPLs depend on which)
   - Estimated complexity (total agents, total waves across all IMPLs)
   - Tier gates (quality checks between tiers)

   Surface the PROGRAM manifest and ask the user to review. The user may approve as-is, request changes, or reject the plan.

6. **State transition.** If the user approves, update the PROGRAM manifest state to `REVIEWED`:
   ```bash
   sawtools update-program-state "<manifest-path>" --state REVIEWED
   ```

**What happens next (not in your scope as Orchestrator):**

After human approval, the program enters the execution phase:
- **Scaffold phase:** Materialize program contracts as source code (committed to HEAD)
- **Tier 1 execution:** Launch Scout agents for all Tier 1 IMPLs in parallel
- **Tier boundary:** Run tier gates, freeze program contracts consumed by Tier 2
- **Tier 2 execution:** Launch Scout agents for all Tier 2 IMPLs in parallel
- Repeat until all tiers complete

This is the `/saw program execute` flow (Level B), which is documented in the next section.

### `/saw program execute "<project-description>"`

Orchestrator flow for `/saw program execute`: Plan and execute a multi-IMPL program with tier-gated progression. This extends the Level A planning flow with automated execution.

**Phase 1: Planning (reuses /saw program plan flow)**

Steps 1-6 from the existing `/saw program plan` section apply:
1. Requirements intake
2. Launch Planner agent
3. Wait for Planner completion
4. Validate PROGRAM manifest
5. Human review
6. State transition to REVIEWED

After human approves the PROGRAM manifest, continue to Phase 2.

**Phase 2: Program Scaffold (if program contracts exist)**

If the manifest has program_contracts with defined locations, launch a Scaffold Agent to materialize them as source code:
1. Launch Scaffold Agent using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`
2. The prompt parameter is the path to the PROGRAM manifest
3. The Scaffold Agent reads the program_contracts section and creates the scaffold source files
4. Wait for Scaffold Agent to complete
5. Verify all contract files show `Status: committed` in the manifest
6. If any file shows `Status: FAILED`, stop and surface the failure to the user
7. Commit scaffold files to HEAD
8. Transition manifest state to TIER_EXECUTING

**Phase 3: Tier Execution Loop (E28)**

For each tier N from 1 to manifest.tiers_total:

**Step 3a: Parallel Scout Launching (E31)**

Partition tier N IMPLs by status (E28A):
- **pending / scouting** — Scout as normal (existing flow below)
- **reviewed / complete** — Validate only (skip Scout, see pre-existing validation below)

*Scout new IMPLs:*
- For each IMPL in tier N with status "pending":
  - Launch Scout agent with: `subagent_type: scout`, `run_in_background: true`
  - Pass --program flag: `sawtools run-scout "<impl-title>" --program "<manifest-path>"`
  - Scout receives frozen program contracts as immutable inputs
- Wait for all Scouts to complete
- Validate each newly scouted IMPL doc (E16): run `sawtools validate --fix "<impl-doc-path>"` for each

*Validate pre-existing IMPLs (E28A):*
- For each IMPL in tier N with status "reviewed" or "complete":
  - Verify IMPL doc exists: `docs/IMPL/IMPL-<slug>.yaml`
  - Run: `sawtools validate --fix "<impl-doc-path>"`
  - Check P2 compliance: `sawtools freeze-check "<program-manifest>" --impl "<slug>"`
  - If validation fails, enter BLOCKED

> **Tip:** Use `sawtools import-impls` before program execution to bulk-import
> pre-existing IMPL docs into the PROGRAM manifest with correct tier assignments
> and status. This avoids manual manifest editing when adopting existing work.

- Present ALL IMPL docs (newly scouted + pre-existing) for unified human review (tier structure, file ownership, interface contracts)

**Step 3b: IMPL Execution**
- For each reviewed IMPL in tier N:
  - Execute the full IMPL lifecycle: scaffold, waves, merge
  - Use existing `/saw wave --auto` flow per IMPL
  - Update IMPL status in PROGRAM manifest as each completes (E32):
    ```bash
    sawtools update-program-impl "<manifest>" --impl "<slug>" --status "<status>"
    ```
- Wait for all IMPLs in the tier to reach "complete"

**Step 3c: Tier Gate (E29)**
- Run: `sawtools tier-gate "<manifest>" --tier N`
- This verifies all IMPLs are complete and runs tier_gates quality gate commands from the PROGRAM manifest
- If gate fails, enter BLOCKED. Surface failure to user.
- If gate passes, proceed to contract freezing.

**Step 3d: Contract Freezing (E30)**
- Run: `sawtools freeze-contracts "<manifest>" --tier N`
- This identifies program contracts whose freeze_at matches tier N
- Verifies contract source files exist and are committed to HEAD
- Marks contracts as frozen in the manifest
- If freezing fails (missing files, uncommitted changes), enter BLOCKED
- If freezing succeeds, all contracts consumed by next tier are locked

**Step 3e: Tier Boundary Review**
- Run: `sawtools program-status "<manifest>"`
- Surface tier completion status to user (tier N complete, contracts frozen)
- If `--auto` flag is active:
  - Call `AdvanceTierAutomatically(manifest, N, repoPath, autoMode=true)` to check gate, freeze contracts, and advance (E33)
  - If gate passed, automatically proceed to next tier (no human review)
  - If gate failed, enter PROGRAM_BLOCKED and surface failure to user (E34)
- If `--auto` flag is NOT active:
  - Pause for human review as normal
  - Human approves to advance to next tier

**Phase 4: Program Completion**

After final tier gate passes:
1. Run: `sawtools mark-program-complete "<manifest>"` (or update state to COMPLETE manually if command not yet available)
2. Update CONTEXT.md with program-level completion data:
   ```bash
   sawtools update-context "<manifest>" --project-root "<repo-path>"
   ```
3. Report final program status to user

**Error handling:**
- If any IMPL enters BLOCKED during tier execution, that IMPL's failure does not cascade to other IMPLs in the same tier (P1).
- If the tier cannot complete because one IMPL is blocked, enter BLOCKED and surface the specific IMPL failure.
- The user may fix the blocked IMPL and resume, or re-plan.

### `/saw program status`

Show program-level progress: tier completion, IMPL statuses, and program contract freeze status.

**Orchestrator flow:**

1. **Discover PROGRAM manifests.** Run:
   ```bash
   sawtools list-programs --dir "<repo-path>/docs"
   ```
   This returns a JSON array of PROGRAM manifest metadata (path, slug, state, title). If no PROGRAM manifests are found, report: "No PROGRAM manifests found. Use `/saw program plan` to create one."

2. **Select target PROGRAM.** If exactly 1 PROGRAM manifest is found, use it automatically. If multiple are found, list them and ask the user to specify which one.

3. **Read PROGRAM manifest.** Load the selected manifest from disk.

4. **Display program status:**

   **Tier Structure:**
   ```
   Tier 1 (2/2 IMPLs complete):
     - data-model: COMPLETE
     - auth: COMPLETE

   Tier 2 (1/2 IMPLs complete):
     - api-routes: EXECUTING (Wave 2/3)
     - frontend: COMPLETE

   Tier 3 (0/1 IMPLs complete):
     - integration-tests: PENDING
   ```

   **Program Contracts:**
   ```
   User (pkg/types/user.go)
     - Frozen: Yes (Tier 1)
     - Consumers: auth, api-routes, frontend

   Task (pkg/types/task.go)
     - Frozen: Yes (Tier 1)
     - Consumers: api-routes, frontend
   ```

   **Overall Progress:**
   ```
   Tiers: 1/3 complete
   IMPLs: 3/5 complete
   Total agents: 12/13 complete
   Total waves: 5/7 complete
   ```

   **Current State:** `TIER_EXECUTING` (or `REVIEWED`, `SCAFFOLD`, `COMPLETE`, `BLOCKED`)

5. **Blocked state handling.** If the program state is `BLOCKED`, read the IMPL docs for all IMPLs in the current tier and surface any failure reports or blocking issues to the user.

### `/saw program replan`

Re-engage the Planner agent to revise a PROGRAM manifest after a tier gate failure or when the user explicitly requests it.

**Orchestrator flow:**

1. Parse existing PROGRAM manifest.

2. Construct revision prompt with failure context:
   - Current PROGRAM manifest content
   - Reason for re-planning (tier gate failure, user request, etc.)
   - Failed tier number (if applicable)
   - Completion reports from IMPLs in failed tier

3. Launch Planner agent with revision prompt:
   - Use Agent tool with `subagent_type: planner` and `run_in_background: true`
   - Pass revision prompt as parameter

4. Wait for Planner completion. Planner produces revised PROGRAM manifest.

5. Validate revised manifest:
   ```bash
   sawtools validate-program "<revised-manifest-path>"
   ```
   If validation fails, send errors back to Planner as correction prompt
   using resume (up to 3 attempts).

6. Present revised PROGRAM manifest for human review:
   - Show what changed (tiers added/removed, contracts revised, IMPLs reordered)
   - Surface the changes summary
   - Ask user to approve revised plan

7. If approved, update manifest state to PROGRAM_REVIEWED and resume execution
   from the failed tier (or next pending tier).

**Non-destructive guarantee:** Re-planning does not discard completed work.
Completed tiers and their IMPLs remain in the manifest with status "complete".
Only pending and failed tiers may be revised.

**Error handling:**
- If Planner fails to produce valid revision after 3 attempts, enter BLOCKED
  and surface validation errors to user
- User may manually edit PROGRAM manifest or abandon re-planning

## Arguments

- `bootstrap <project-name>`: Design-first architecture for new projects with no
  existing codebase. The Orchestrator writes `docs/REQUIREMENTS.md` first
  (capturing language, deployment, integrations, and architectural decisions
  already made), then launches a Scout agent that reads that file and designs
  disjoint file ownership. Produces `docs/IMPL/IMPL-bootstrap.yaml` with interface
  contracts, scaffolds, and parallel implementation waves. Use when starting from
  scratch or from an empty repo.
- `scout <feature-description>`: The Orchestrator launches a Scout agent
  (asynchronous) to analyze the codebase and produce the IMPL doc. The Scout
  runs the suitability gate first; if the work is not suitable, it writes a
  short verdict to `docs/IMPL/IMPL-<slug>.yaml` and stops without producing agent
  prompts. The Orchestrator waits for the Scout to complete, then reports the
  verdict and asks the user to review.
- `wave`: Execute the next pending wave, pause for review after each wave
- `wave --auto`: Execute all remaining waves automatically; only pause if verification fails
- `status`: Show current progress from the IMPL doc
- `program plan "<project-description>"`: Analyze project and produce PROGRAM manifest coordinating multiple IMPLs (Level A: planning only)
- `program execute "<project-description>"`: Plan and execute multi-IMPL program with tier-gated progression. Extends Level A planning with automated Scout launching, IMPL execution, tier gates, and contract freezing. Pauses for human review at tier boundaries (Level B).
- `program status`: Show program-level progress (tier completion, IMPL statuses, contract freeze status)
- `program replan`: Re-engage Planner to revise PROGRAM manifest after tier gate failure or user request
