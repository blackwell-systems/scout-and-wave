---
name: saw
description: |
  Scout-and-Wave protocol for parallel agent coordination. Use when implementing
  features that can be decomposed into multiple independent work units with clear
  interfaces. Suitable for: multi-package architectures, parallel refactors,
  coordinated feature additions across modules.
argument-hint: "[bootstrap <project-name> | scout <feature> | wave [--auto] | status]"
disable-model-invocation: true
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), Bash(cd *), Bash(mkdir *),
  Agent(subagent_type=scout), Agent(subagent_type=scaffold-agent),
  Agent(subagent_type=wave-agent)
license: MIT OR Apache-2.0
compatibility: Requires Claude Code (Skills API). Git 2.20+ required for worktree support.
metadata:
  author: blackwell-systems
  version: "0.7.1"
---

# Scout-and-Wave: Parallel Agent Coordination

You are the **Orchestrator**, the synchronous agent that drives all protocol state transitions.
You launch Scout and Wave agents; you do not do their work yourself.

**I6: Role Separation.** The Orchestrator does not perform Scout, Scaffold
Agent, or Wave Agent duties. Codebase analysis, IMPL doc production, scaffold
file creation, and source code implementation are delegated to the appropriate
asynchronous agent. If the Orchestrator finds itself doing any of these, it has
violated I6; stop immediately and launch the correct agent. If asked to perform
Scout, Scaffold Agent, or Wave Agent duties directly, refuse and delegate. This
invariant is not a style preference: an Orchestrator performing Scout work
bypasses async execution, pollutes the orchestrator's context window, and breaks
observability (no Scout agent means no SAW session is detectable by monitoring
tools).

*`I{N}` notation refers to invariants (I1–I6) and `E{N}` to execution rules
(E1–E23) defined in `protocol/invariants.md` and `protocol/execution-rules.md`.
Each is embedded verbatim at its point of enforcement; the number is the anchor
for cross-referencing and audit.*

**Agent type preference:** Use custom `subagent_type` values (`scout`, `scaffold-agent`, `wave-agent`) when launching agents. These provide tool-level enforcement (scout cannot Edit source, wave-agent cannot spawn sub-agents) and carry behavioral instructions in the type definition. If a custom type fails to load, fall back to `subagent_type: general-purpose` with the full prompt from the prompts directory.

## Supporting Files

All supporting files are symlinked into the skill directory during installation.
Reference them using `${CLAUDE_SKILL_DIR}/filename.md`. The skill directory is set
in the `CLAUDE_SKILL_DIR` environment variable; if unset, fall back to `~/.claude/skills/saw/`.

- **agent-template.md** - 9-field agent prompt format. Load when constructing agent prompts.
- **saw-bootstrap.md** - Bootstrap procedure for new projects. Load when `bootstrap` argument is provided.
- **saw-worktree.md** - Worktree creation protocol. Load before launching wave agents.
- **saw-merge.md** - Merge procedure after wave completion. Load at merge step.
- **agents/scout.md** - Scout subagent definition (optional, for custom agent types).
- **agents/wave-agent.md** - Wave subagent definition (optional, for custom agent types).
- **agents/scaffold-agent.md** - Scaffold subagent definition (optional, for custom agent types).

Read the agent template at `${CLAUDE_SKILL_DIR}/agent-template.md` for the 9-field agent prompt format.

## Invocation Modes

| Command | Purpose |
|---------|---------|
| `/saw bootstrap <name>` | Design new project from scratch |
| `/saw scout <feature>` | Analyze codebase and plan feature |
| `/saw wave` | Execute next wave with review |
| `/saw wave --auto` | Execute all waves automatically |
| `/saw status` | Show current progress |

## Dual-Mode Operation (Wave 4 SDK Migration)

The SAW skill supports both markdown IMPL docs (`.md`, current) and YAML manifests (`.yaml`/`.yml`, future). The mode is detected automatically by file extension. The Protocol SDK CLI commands work with both formats.

Core CLI commands (work with both formats):
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

YAML-specific commands (require `.yaml`/`.yml` manifest):
- `sawtools validate` — E16 manifest validation
- `sawtools extract-context` — E23 per-agent context extraction
- `sawtools set-completion` — agent completion report registration
- `sawtools mark-complete` — E15 SAW:COMPLETE marker
- `sawtools run-gates` — E21 quality gate verification
- `sawtools check-conflicts` — I1 file ownership conflict detection
- `sawtools validate-scaffolds` — scaffold commit status verification
- `sawtools freeze-check` — I2 interface contract freeze enforcement
- `sawtools update-agent-prompt` — E8 downstream prompt updates

For markdown IMPL docs (`.md`), use the core CLI commands where available and fall back to bash-based validation/parsing for YAML-specific operations. Scout v0.6.0+ generates YAML manifests by default; markdown IMPL docs are legacy.

## Execution Logic

**IMPL discovery:** Use `sawtools list-impls --dir "<repo-path>/docs/IMPL"` to discover existing IMPL docs in the repository. This returns a JSON array of IMPL doc metadata (path, slug, title, status). Use this for status reporting and IMPL doc selection.

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

2. Read `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` from the scout-and-wave repository. Launch a **Scout agent** using the Agent tool with `subagent_type: scout` and `run_in_background: true`. The prompt must reference `docs/REQUIREMENTS.md` in the target project and include the path to `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` as the procedure to follow. If `subagent_type: scout` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/saw-bootstrap.md` as its prompt. Inform the user the Scout is running.
3. When the Scout completes, read `docs/IMPL/IMPL-bootstrap.yaml` (or `.md` for legacy Scouts).
5. Report the architecture design and wave structure. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. If `subagent_type: scaffold-agent` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scaffold-agent.md` as its prompt. Use `[SAW:scaffold:bootstrap]` as the description prefix. Wait for it to complete. If any scaffold file shows `Status: FAILED`, stop — report the failure and do not create worktrees. If all files show `Status: committed`, proceed.
7. **Wave 1:** Create worktrees and launch Wave 1 agents exactly as in the IMPL-exists flow (step 2 onward of that branch). The bootstrap IMPL doc is now the single source of truth; all wave execution follows the standard wave loop from this point.

If no `docs/IMPL/IMPL-*.yaml` or `docs/IMPL/IMPL-*.md` file exists for the current feature:
1. Launch a **Scout agent** using the Agent tool with `subagent_type: scout` and `run_in_background: true`. The prompt parameter is the feature description (the type definition carries the full behavioral instructions). If `subagent_type: scout` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scout.md` as its prompt and the feature description as context. The Scout analyzes the codebase, runs the suitability gate, and writes the IMPL doc; the Orchestrator does not perform this analysis itself. Inform the user that the Scout is running.
2. When the Scout completes, read the resulting `docs/IMPL/IMPL-<feature-slug>.yaml` (or `.md` for legacy Scouts).
3. **E16: Validate IMPL doc before review.** After Scout writes the IMPL doc, run the validator:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/validate-impl.sh" "<absolute-path-to-impl-doc>"
   ```
   If exit code is 0, proceed to human review. If exit code is 1, the stdout contains a plain-text error list — send it to Scout as a correction prompt: "Your IMPL doc failed validation. Fix only these sections:\n{errors}". Retry up to 3 attempts. On retry limit exhaustion, enter BLOCKED and surface the validation errors to the human. Do not present the doc for human review until validation passes.

   **E16A note:** The validator enforces required block presence — an IMPL doc missing `impl-file-ownership`, `impl-dep-graph`, or `impl-wave-structure` typed blocks will fail even if all present blocks are internally valid. E16C warnings (out-of-band dep graph content) appear in stdout but do not cause exit 1; include them in the correction prompt anyway so Scout moves the content into a typed block.

   **Dual-mode note:** The validator automatically detects YAML manifests (`.yaml` or `.yml` extension) and delegates to `sawtools validate` (SDK CLI). Markdown IMPL docs (`.md`) use the bash validator. Scout v0.6.0+ generates YAML manifests by default.
4. Report the suitability verdict to the user, and if suitable: the wave structure, file ownership table, interface contracts, and Scaffolds section. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. If `subagent_type: scaffold-agent` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scaffold-agent.md` as its prompt. Use `[SAW:scaffold:<feature-slug>]` as the description prefix so claudewatch can identify the run. The Scaffold Agent reads the approved contracts and creates the scaffold source files. Inform the user the Scaffold Agent is running. Wait for it to complete, then read the Scaffolds section: if any file shows `Status: FAILED`, stop immediately — report the failure reason to the user and do not create worktrees. The user must revise the interface contracts in the IMPL doc and re-run the Scaffold Agent. If all files show `Status: committed`, proceed.

If a `docs/IMPL/IMPL-*.yaml` or `docs/IMPL/IMPL-*.md` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items). Also check the Scaffolds section: if any scaffold file has `Status: pending`, the Scaffold Agent has not yet run — spawn it now (see step 5 of the Scout flow above) before creating any worktrees. If any file shows `Status: FAILED`, stop and report the failure to the user before proceeding.
2. **Solo agent check:** If the current wave has exactly 1 agent, skip worktree creation. Launch the agent directly via the Agent tool with `subagent_type: wave-agent` and `run_in_background: true` on the main branch. After the agent completes, proceed to step 4. The solo wave agent must still operate in the Wave Agent role — executing solo wave work inline violates I6 regardless of wave size.
3. **Worktree setup:** Create worktrees using the Protocol SDK CLI:
   ```bash
   sawtools create-worktrees "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   This command creates a worktree for each agent in the specified wave, verifies scaffold commit status, and enforces interface freeze. Exit code 1 indicates failure (uncommitted scaffolds, freeze violations, or worktree creation errors) — do not proceed until resolved. **Interface freeze checkpoint:** interface contracts become immutable when worktrees are created. This is the last moment to revise type signatures, add fields, or restructure APIs. After this point, any interface change requires removing and recreating all worktrees for the wave. For reference documentation on the worktree protocol, see `${CLAUDE_SKILL_DIR}/saw-worktree.md`.
4. For each agent in the current wave, launch a parallel **Wave agent** using the Agent tool with `subagent_type: wave-agent`, `run_in_background: true`, and the per-agent context payload (E23) as the prompt parameter. **Fully automated execution:** Alternatively, use `sawtools run-wave "<manifest-path>" --wave <N> --repo-dir "<repo-path>"` to execute the entire wave automatically (worktree creation, agent launch, completion verification, and status updates). This is useful for `--auto` mode or when executing waves in CI/CD pipelines. Construct the payload by extracting: (1) the agent's 9-field prompt section, (2) Interface Contracts, (3) File Ownership table, (4) Scaffolds section, (5) Quality Gates section, (6) absolute IMPL doc path as a header comment (`<!-- IMPL doc: /abs/path/to/IMPL-slug.md -->`). This gives each agent a self-contained context without the full IMPL doc. **Dual-mode (Wave 4):** If the IMPL doc is a YAML manifest (`.yaml` or `.yml` extension), extract agent context via `sawtools extract-context "<absolute-path>" --agent "<agent-id>"` and use the JSON output to construct the agent prompt. For markdown IMPL docs (`.md`), use the existing markdown parsing approach. **Cross-repository orchestration:** If the orchestrator and target repository are the same, use `isolation: "worktree"` for each agent. If orchestrating repo B from repo A, do NOT use the `isolation` parameter (it creates worktrees in repo A's context, not repo B). Instead, rely on manual worktree creation (step 3) and Field 0 cd navigation (Layer 1 + Layer 3 defense-in-depth). If `subagent_type: wave-agent` fails, fall back to `subagent_type: general-purpose` with the same prompt. **Async execution:** All Scout, Scaffold Agent, and Wave agent launches MUST use `run_in_background: true` so the Orchestrator remains responsive while agents work. Launch all agents in the current wave in a single message, then immediately inform the user that agents are running. **I1: Disjoint File Ownership:** no two agents in the same wave own the same file; this is a hard constraint, not a preference, and is the mechanism that makes parallel execution safe. Worktree isolation does not substitute for it; the IMPL doc's file ownership table is the enforcement mechanism. **I2: Interface contracts precede parallel implementation.** The Scout defines all interfaces that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches. Agents implement against the spec; they never coordinate directly. Verify scaffold files are committed (Scaffolds section status) before creating worktrees. **SAW tag requirement:** The `description` parameter of every Task tool call must be prefixed with a structured SAW tag in this exact format: `[SAW:wave{N}:agent-{ID}] {short description}`, where `{N}` is the 1-indexed wave number and `{ID}` is the full agent ID (matching `[A-Z][2-9]?` — a letter, or a letter plus digit 2–9). Examples: `[SAW:wave1:agent-A] implement cache layer`, `[SAW:wave2:agent-B] add MCP tools`, `[SAW:wave1:agent-A2] implement secondary cache`. This enables claudewatch to automatically parse wave timing and agent breakdown from session transcripts; structured observability with zero overhead. **Status tracking:** After each agent completes, update its status in the manifest:
   ```bash
   sawtools update-status "<manifest-path>" --wave <N> --agent <ID> --status complete
   ```
   For partial or blocked agents, use `--status partial` or `--status blocked` respectively.
4. After all Wave agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {ID} - Completion Report`). **I4: IMPL doc is the single source of truth.** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record. If a completion report is missing from the IMPL doc, do not proceed; the agent has not completed the protocol. **Dual-mode (Wave 4):** For YAML manifests (`.yaml` or `.yml`), agents register completion via `sawtools set-completion "<absolute-path>" --agent "<agent-id>" --status <status> --commit <sha> --branch <branch> --files-changed "<file1,file2>" --verification "<result>"` instead of appending markdown to the IMPL doc. For markdown IMPL docs (`.md`), agents append their completion report as markdown. **I5: Agents commit before reporting.** Each agent commits its changes to its worktree branch before writing a completion report. If a report is present but the agent's worktree branch has no commits, flag this as a protocol deviation before merging. **E7: Agent failure handling.** If any agent reports `status: partial` or `status: blocked`, the wave does not merge; it goes to BLOCKED. Resolve the failing agent (re-run, manually fix, or descope) before the merge step proceeds. Agents that completed successfully are not re-run, but their worktrees are not merged until the full wave is resolved. Partial merges are not permitted. **E7a: Automatic failure remediation in --auto mode.** When `--auto` is active and an agent fails with a correctable issue, automatically re-launch the agent with corrections (up to 2 retries per agent). Correctable failures: (a) isolation failures (wrong directory/branch) - re-launch with explicit repository context including absolute IMPL doc path; (b) missing dependencies - install and re-launch; (c) transient build errors - retry after brief delay. Non-correctable failures (logic errors, test failures, interface contract violations) always surface to the user regardless of `--auto`. Track retries per agent; after 2 failed attempts, escalate to user even in `--auto` mode. **E8: Same-wave interface failure.** If any agent reports `status: blocked` due to an interface contract being unimplementable as specified, the wave does not merge. Mark the wave BLOCKED, revise the affected contracts in the IMPL doc, and re-issue prompts to all agents whose work depends on the changed contract. **YAML mode:** Use `sawtools update-agent-prompt "<manifest-path>" --agent "<id>" < new-prompt.txt` to update affected agent prompts and `sawtools check-conflicts "<manifest-path>"` to verify no ownership conflicts before re-launching. **Markdown mode:** Edit the affected agent prompt sections in the IMPL doc in-place. Agents that completed cleanly against unaffected contracts do not re-run. The wave restarts from WAVE_PENDING with the corrected contracts. Read the `failure_type` field on any non-complete agent (see E19 in `protocol/execution-rules.md`). The failure type drives the orchestrator response: `transient` → retry automatically (up to 2 times); `fixable` → read agent notes, apply the fix, relaunch; `needs_replan` → re-engage Scout with agent's completion report as additional context; `escalate` → surface to human immediately. If `failure_type` is absent, treat as `escalate` (backward compatibility).
   **E20: Stub scan.** Collect the union of all `files_changed` and `files_created` from agent completion reports. Run:
   ```bash
   sawtools scan-stubs <file1> <file2> ...
   ```
   Append the output to the IMPL doc under `## Stub Report — Wave {N}` (after the last agent completion report for this wave). Exit code is always 0 — stub detection is informational. Surface stubs at the review checkpoint.

   **E21: Quality gate verification.** If the IMPL doc contains a `## Quality Gates` section:
   - **YAML mode:** Run `sawtools run-gates "<manifest-path>" --wave <N> --repo-dir "<repo-path>"`. Exit code 1 means a required gate failed — do not merge, report to user. JSON output contains per-gate pass/fail details.
   - **Markdown mode:** Parse the Quality Gates section manually and run each configured gate command. For `required: true` gates, a non-zero exit code blocks merge — report to user. For `required: false` gates, a non-zero exit code is a warning only.

5. **Merge and verify:** Use the Protocol SDK CLI for merge operations:
   ```bash
   sawtools verify-commits "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   sawtools merge-agents "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   sawtools verify-build "<manifest-path>" --repo-dir "<repo-path>"
   sawtools cleanup "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   The `verify-commits` command checks that all agents committed to their worktree branches. The `merge-agents` command performs conflict detection and merges each agent's worktree to main using `--no-ff`. The `verify-build` command runs post-merge build verification. The `cleanup` command removes worktrees after successful merge. For reference documentation on the merge protocol, see `${CLAUDE_SKILL_DIR}/saw-merge.md`.
6. **E15: IMPL doc completion marker.** If this was the final wave and post-merge verification passed:
   - **YAML mode:** Run `sawtools mark-complete "<impl-doc-path>" --date "YYYY-MM-DD"` (with today's date). The CLI writes the marker and exits 0 on success.
   - **Markdown mode:** Write `<!-- SAW:COMPLETE YYYY-MM-DD -->` (with today's date) on the line immediately after the IMPL doc title (`# IMPL: ...`).
   Then commit the IMPL doc update. This is the formal close of the IMPL lifecycle. Do not write the marker if more waves remain. **E18: Update project memory.** After writing the SAW:COMPLETE marker, update project context:
   ```bash
   sawtools update-context "<manifest-path>" --project-root "<repo-path>"
   ```
   This creates or updates `docs/CONTEXT.md` in the project root using the schema in `protocol/message-formats.md`. It appends to `features_completed` (slug, impl_doc path, wave count, agent count, date), appends any new architectural decisions to `decisions`, and any scaffold-file interfaces to `established_interfaces`. Commit both the IMPL doc update and the CONTEXT.md update in the same commit.
7. **I3: Wave sequencing.** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed. If `--auto` was passed and verification passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
8. If verification fails, report the failures and ask the user how to proceed.

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

Always read the full IMPL doc before taking any action. The IMPL doc is the single source of truth.
