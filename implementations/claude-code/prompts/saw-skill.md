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
  Agent(subagent_type=wave-agent), Agent(subagent_type=general-purpose)
license: MIT OR Apache-2.0
compatibility: Requires Claude Code (Skills API). Git 2.20+ required for worktree support.
metadata:
  author: blackwell-systems
  version: "0.9.0"
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
       "chat_model": "claude-sonnet-4-5"
     }
   }
   ```
   For `/saw scout`, read `agent.scout_model`. For `/saw wave`, read `agent.wave_model`. Empty string or missing field means "inherit parent model." If neither config file exists, fall through to level 3.
3. **Parent model** — If neither arg nor config specifies a model, agents inherit the parent session's model (no `model:` in frontmatter = inherit).

**Implementation:** The Agent tool does not expose a model parameter, so model override works indirectly. Custom `subagent_type` values (`scout`, `wave-agent`, `scaffold-agent`) inherit the parent session's model. When `--model` is specified explicitly and the custom subagent_type's inherited model doesn't match (e.g., parent is Opus but `--model sonnet` requested), fall back to `subagent_type: general-purpose` with the full agent prompt from the prompts directory.

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

## Protocol SDK CLI Commands

All operations use the `sawtools` CLI. IMPL docs are YAML manifests (`.yaml`).

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
- `sawtools run-gates` — E21 quality gate verification
- `sawtools check-conflicts` — I1 file ownership conflict detection
- `sawtools validate-scaffolds` — scaffold commit status verification
- `sawtools freeze-check` — I2 interface contract freeze enforcement
- `sawtools update-agent-prompt` — E8 downstream prompt updates

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
3. When the Scout completes, read `docs/IMPL/IMPL-bootstrap.yaml`.
5. Report the architecture design and wave structure. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. If `subagent_type: scaffold-agent` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scaffold-agent.md` as its prompt. Use `[SAW:scaffold:bootstrap]` as the description prefix. Wait for it to complete. If any scaffold file shows `Status: FAILED`, stop — report the failure and do not create worktrees. If all files show `Status: committed`, proceed.
7. **Wave 1:** Create worktrees and launch Wave 1 agents exactly as in the IMPL-exists flow (step 2 onward of that branch). The bootstrap IMPL doc is now the single source of truth; all wave execution follows the standard wave loop from this point.

If no `docs/IMPL/IMPL-*.yaml` file exists for the current feature:
1. **Run automation tools (best-effort).** Before launching Scout, gather automated analysis to prepend to Scout's context. Run these commands in sequence, capturing output but not blocking on failures:

   ```bash
   # Determine repo path (current working directory)
   REPO_PATH=$(pwd)

   # H2: Extract build/test/lint commands
   H2_OUTPUT=$(sawtools extract-commands "$REPO_PATH" 2>&1)
   H2_EXIT=$?

   # H1a: Analyze suitability (only if feature is a file path)
   H1A_OUTPUT=""
   H1A_EXIT=0
   if [[ "$FEATURE_DESC" == *.md ]] || [[ "$FEATURE_DESC" == *.txt ]]; then
     H1A_OUTPUT=$(sawtools analyze-suitability "$FEATURE_DESC" --repo-root "$REPO_PATH" 2>&1)
     H1A_EXIT=$?
   fi

   # H3: Analyze dependencies
   H3_OUTPUT=""
   H3_EXIT=0
   if [ $H1A_EXIT -eq 0 ] && [ -n "$H1A_OUTPUT" ]; then
     # Extract files from H1a output if present
     FILES=$(echo "$H1A_OUTPUT" | grep -oE 'file: [^ ]+' | cut -d' ' -f2 | tr '\n' ',' | sed 's/,$//')
     if [ -n "$FILES" ]; then
       H3_OUTPUT=$(sawtools analyze-deps "$REPO_PATH" --files "$FILES" 2>&1)
     else
       H3_OUTPUT=$(sawtools analyze-deps "$REPO_PATH" 2>&1)
     fi
     H3_EXIT=$?
   else
     H3_OUTPUT=$(sawtools analyze-deps "$REPO_PATH" 2>&1)
     H3_EXIT=$?
   fi

   # Create automation results file
   cat > /tmp/scout-automation-$$.md << 'EOF'
## Automation Analysis Results

### Build/Test Commands (H2)
EOF

   if [ $H2_EXIT -eq 0 ]; then
     echo "$H2_OUTPUT" >> /tmp/scout-automation-$$.md
   else
     echo "Not detected" >> /tmp/scout-automation-$$.md
   fi

   cat >> /tmp/scout-automation-$$.md << 'EOF'

### Pre-Implementation Status (H1a)
EOF

   if [ -n "$H1A_OUTPUT" ] && [ $H1A_EXIT -eq 0 ]; then
     echo "$H1A_OUTPUT" >> /tmp/scout-automation-$$.md
   elif [[ "$FEATURE_DESC" == *.md ]] || [[ "$FEATURE_DESC" == *.txt ]]; then
     echo "Analysis failed: $H1A_OUTPUT" >> /tmp/scout-automation-$$.md
   else
     echo "Skipped - no requirements file" >> /tmp/scout-automation-$$.md
   fi

   cat >> /tmp/scout-automation-$$.md << 'EOF'

### Dependency Analysis (H3)
EOF

   if [ $H3_EXIT -eq 0 ]; then
     echo "$H3_OUTPUT" >> /tmp/scout-automation-$$.md
   else
     echo "Analysis failed: $H3_OUTPUT" >> /tmp/scout-automation-$$.md
   fi

   cat >> /tmp/scout-automation-$$.md << 'EOF'

Use these results to:
- Populate quality_gates and test_command from H2 output
- Adjust agent prompts based on H1a DONE/PARTIAL/TODO status
- Use H3 wave_candidate field to assign wave numbers
- Document pre-implementation findings in suitability assessment
EOF
   ```

   After creating `/tmp/scout-automation-$$.md`, prepend it to the Scout agent prompt (AFTER any existing CONTEXT.md prepending if present, BEFORE scout.md contents). All failures are logged but do not block Scout launch.

2. Launch a **Scout agent** using the Agent tool with `subagent_type: scout` and `run_in_background: true`. The prompt parameter is the feature description (the type definition carries the full behavioral instructions). If `subagent_type: scout` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scout.md` as its prompt and the feature description as context. The Scout analyzes the codebase, runs the suitability gate, and writes the IMPL doc; the Orchestrator does not perform this analysis itself. Inform the user that the Scout is running.
3. When the Scout completes, read the resulting `docs/IMPL/IMPL-<feature-slug>.yaml`.
4. **E16: Validate IMPL doc before review.** After Scout writes the IMPL doc, run:
   ```bash
   sawtools validate "<absolute-path-to-impl-doc>"
   ```
   If exit code is 0, proceed to human review. If exit code is 1, the stdout contains a plain-text error list — send it to Scout as a correction prompt: "Your IMPL doc failed validation. Fix only these sections:\n{errors}". Retry up to 3 attempts. On retry limit exhaustion, enter BLOCKED and surface the validation errors to the human. Do not present the doc for human review until validation passes.

   **E16A note:** The validator enforces required block presence — an IMPL doc missing `impl-file-ownership`, `impl-dep-graph`, or `impl-wave-structure` typed blocks will fail even if all present blocks are internally valid. E16C warnings (out-of-band dep graph content) appear in stdout but do not cause exit 1; include them in the correction prompt anyway so Scout moves the content into a typed block.
4a. **M4: Auto-populate verification gates.** After validation passes, automatically generate verification gate blocks for all agents:
   ```bash
   sawtools populate-verification-gates "<absolute-path-to-impl-doc>"
   ```
   This orchestrator post-processor reads the IMPL doc's file ownership table and H2's toolchain data, then writes properly formatted verification blocks to each agent section. Exit code 0 means success; exit code 1 means failure (missing H2 data or malformed IMPL doc). If it fails, log the error but continue — verification gates can be manually written during human review. After M4 completes, run validation again to confirm gates are valid:
   ```bash
   sawtools validate "<absolute-path-to-impl-doc>"
   ```
   If this second validation fails, surface the errors to the human during review (M4 bug or edge case).
5. Report the suitability verdict to the user, and if suitable: the wave structure, file ownership table, interface contracts, and Scaffolds section. Ask the user to review before proceeding.
6. **Scaffold Agent (conditional):** If the IMPL doc Scaffolds section is non-empty and any scaffold file has `Status: pending`, launch a **Scaffold Agent** using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`. The prompt parameter is the path to the IMPL doc and the feature slug. If `subagent_type: scaffold-agent` fails, fall back to `subagent_type: general-purpose` with the contents of `${CLAUDE_SKILL_DIR}/agents/scaffold-agent.md` as its prompt. Use `[SAW:scaffold:<feature-slug>]` as the description prefix so claudewatch can identify the run. The Scaffold Agent reads the approved contracts and creates the scaffold source files. Inform the user the Scaffold Agent is running. Wait for it to complete, then read the Scaffolds section: if any file shows `Status: FAILED`, stop immediately — report the failure reason to the user and do not create worktrees. The user must revise the interface contracts in the IMPL doc and re-run the Scaffold Agent. If all files show `Status: committed`, proceed.

If a `docs/IMPL/IMPL-*.yaml` file already exists:
1. Read it and identify the current wave (the first wave with unchecked status items). Also check the Scaffolds section: if any scaffold file has `Status: pending`, the Scaffold Agent has not yet run — spawn it now (see step 5 of the Scout flow above) before creating any worktrees. If any file shows `Status: FAILED`, stop and report the failure to the user before proceeding.
2. **Solo agent check:** If the current wave has exactly 1 agent, skip worktree creation. Run `sawtools prepare-agent "<manifest-path>" --wave <N> --agent <ID> --repo-dir "<repo-path>" --no-worktree` to extract brief and init journal, then launch the agent directly via the Agent tool with `subagent_type: wave-agent` and `run_in_background: true` on the main branch. After the agent completes, proceed to step 6. The solo wave agent must still operate in the Wave Agent role — executing solo wave work inline violates I6 regardless of wave size.
3. **Wave preparation (multi-agent):** For waves with 2+ agents, use the batch preparation command:
   ```bash
   sawtools prepare-wave "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   This atomic operation combines dependency conflict detection, worktree creation, and per-agent preparation (brief extraction + journal initialization) into a single command. Step 0 checks for missing packages and version conflicts; if detected, the command exits with code 1 and prints a JSON conflict report. Resolve conflicts in main branch and re-run. Exit code 1 also indicates other failures (uncommitted scaffolds, freeze violations, or worktree creation errors) — do not proceed until resolved. **Interface freeze checkpoint:** interface contracts become immutable when worktrees are created. This is the last moment to revise type signatures, add fields, or restructure APIs. Returns JSON with all worktree paths and agent brief metadata.
4. For each agent in the current wave, launch a parallel **Wave agent** using the Agent tool with `subagent_type: wave-agent`, `run_in_background: true`, and the per-agent context payload (E23) as the prompt parameter. **Journal context prepending:** Before passing the prompt to the Agent tool, prepend the content of `.saw-state/journals/wave<N>/agent-<ID>/context.md` (if it exists and is non-empty) to the agent's prompt as a `## Prior Work` section. This ensures the agent has visibility into its own execution history even after context compaction. **Use short IMPL-referencing prompts — do not copy-paste agent briefs.** Pass a ~60-token stub containing the IMPL doc path, wave number, and agent ID. The agent reads its own full brief on its first tool call via its Read tool or `sawtools extract-context`. This is 10–15× faster to generate than copy-pasting the full context, and no information is lost — the IMPL doc is already the single source of truth (I4).

For **YAML manifests** (`.yaml`/`.yml`):
```
<!-- IMPL doc: /abs/path/to/IMPL-feature.yaml | Wave N | Agent X -->
<!-- Worktree: /abs/path/to/.claude/worktrees/wave{N}-agent-{X} | Branch: wave{N}-agent-{X} -->

MANDATORY FIRST STEP - Verify isolation before any work:
1. cd /abs/path/to/.claude/worktrees/wave{N}-agent-{X}
2. sawtools verify-isolation --branch wave{N}-agent-{X}
3. If verification fails (exit code 1), STOP immediately and report status: blocked

After verification passes, read your pre-extracted brief:
Read .saw-agent-brief.md

Follow the brief exactly.Follow the extracted brief exactly.
```

**Fallback (full context):** If the IMPL doc path is not accessible from the agent's working directory (e.g., cross-repo orchestration where the doc is in a different repo the agent cannot reach), construct the full payload by extracting: (1) the agent's 9-field prompt section, (2) Interface Contracts, (3) File Ownership table, (4) Scaffolds section, (5) Quality Gates section, (6) absolute IMPL doc path as a header comment. Use the full-context fallback only when the short stub approach is not viable. **Cross-repository orchestration:** If the orchestrator and target repository are the same, use `isolation: "worktree"` for each agent. If orchestrating repo B from repo A, do NOT use the `isolation` parameter (it creates worktrees in repo A's context, not repo B). Instead, rely on manual worktree creation (step 3) and Field 0 cd navigation (Layer 1 + Layer 3 defense-in-depth). If `subagent_type: wave-agent` fails, fall back to `subagent_type: general-purpose` with the same prompt. **Async execution:** All Scout, Scaffold Agent, and Wave agent launches MUST use `run_in_background: true` so the Orchestrator remains responsive while agents work. Launch all agents in the current wave in a single message, then immediately inform the user that agents are running. **I1: Disjoint File Ownership:** no two agents in the same wave own the same file; this is a hard constraint, not a preference, and is the mechanism that makes parallel execution safe. Worktree isolation does not substitute for it; the IMPL doc's file ownership table is the enforcement mechanism. **I2: Interface contracts precede parallel implementation.** The Scout defines all interfaces that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches. Agents implement against the spec; they never coordinate directly. Verify scaffold files are committed (Scaffolds section status) before creating worktrees. **SAW tag requirement:** The `description` parameter of every Task tool call must be prefixed with a structured SAW tag in this exact format: `[SAW:wave{N}:agent-{ID}] {short description}`, where `{N}` is the 1-indexed wave number and `{ID}` is the full agent ID (matching `[A-Z][2-9]?` — a letter, or a letter plus digit 2–9). Examples: `[SAW:wave1:agent-A] implement cache layer`, `[SAW:wave2:agent-B] add MCP tools`, `[SAW:wave1:agent-A2] implement secondary cache`. This enables claudewatch to automatically parse wave timing and agent breakdown from session transcripts; structured observability with zero overhead. **Status tracking:** After each agent completes, update its status in the manifest:
   ```bash
   sawtools update-status "<manifest-path>" --wave <N> --agent <ID> --status complete
   ```
   For partial or blocked agents, use `--status partial` or `--status blocked` respectively.
6. After all Wave agents in the wave complete, read each agent's completion report from their named section in the IMPL doc (`### Agent {ID} - Completion Report`). **I4: IMPL doc is the single source of truth.** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record. If a completion report is missing from the IMPL doc, do not proceed; the agent has not completed the protocol. Agents register completion via `sawtools set-completion "<absolute-path>" --agent "<agent-id>" --status <status> --commit <sha> --branch <branch> --files-changed "<file1,file2>" --verification "<result>"`. **I5: Agents commit before reporting.** Each agent commits its changes to its worktree branch before writing a completion report. If a report is present but the agent's worktree branch has no commits, flag this as a protocol deviation before merging. **E7: Agent failure handling.** If any agent reports `status: partial` or `status: blocked`, the wave does not merge; it goes to BLOCKED. Resolve the failing agent (re-run, manually fix, or descope) before the merge step proceeds. Agents that completed successfully are not re-run, but their worktrees are not merged until the full wave is resolved. Partial merges are not permitted. **E7a: Automatic failure remediation in --auto mode.** When `--auto` is active and an agent fails with a correctable issue, automatically re-launch the agent with corrections (up to 2 retries per agent). Correctable failures: (a) isolation failures (wrong directory/branch) - re-launch with explicit repository context including absolute IMPL doc path; (b) missing dependencies - install and re-launch; (c) transient build errors - retry after brief delay. Non-correctable failures (logic errors, test failures, interface contract violations) always surface to the user regardless of `--auto`. Track retries per agent; after 2 failed attempts, escalate to user even in `--auto` mode. **E8: Same-wave interface failure.** If any agent reports `status: blocked` due to an interface contract being unimplementable as specified, the wave does not merge. Mark the wave BLOCKED, revise the affected contracts in the IMPL doc, and re-issue prompts to all agents whose work depends on the changed contract. Use `sawtools update-agent-prompt "<manifest-path>" --agent "<id>" < new-prompt.txt` to update affected agent prompts and `sawtools check-conflicts "<manifest-path>"` to verify no ownership conflicts before re-launching. Agents that completed cleanly against unaffected contracts do not re-run. The wave restarts from WAVE_PENDING with the corrected contracts. Read the `failure_type` field on any non-complete agent (see E19 in `protocol/execution-rules.md`). The failure type drives the orchestrator response: `transient` → retry automatically (up to 2 times); `fixable` → read agent notes, apply the fix, relaunch; `needs_replan` → re-engage Scout with agent's completion report as additional context; `escalate` → surface to human immediately. If `failure_type` is absent, treat as `escalate` (backward compatibility).
   **E20: Stub scan.** Collect the union of all `files_changed` and `files_created` from agent completion reports. Run:
   ```bash
   sawtools scan-stubs <file1> <file2> ...
   ```
   Append the output to the IMPL doc under `## Stub Report — Wave {N}` (after the last agent completion report for this wave). Exit code is always 0 — stub detection is informational. Surface stubs at the review checkpoint.

   **E21: Quality gate verification.** Quality gates are run automatically by `finalize-wave` in the next step.

7. **Wave finalization:** Use the batch finalization command to verify, merge, and cleanup:
   ```bash
   sawtools finalize-wave "<manifest-path>" --wave <N> --repo-dir "<repo-path>"
   ```
   This atomic operation combines the 6-step post-wave pipeline: (1) verify-commits (E7 check), (2) scan-stubs (E20), (3) run-gates (E21), (4) merge-agents, (5) verify-build, (6) cleanup. The command stops on first failure and returns comprehensive JSON with all verification results. Exit code 1 indicates failure at any step. Returns `Success: true` only if all steps pass. For solo agents (no worktrees), run the individual commands manually: `verify-build` to run tests, then proceed to step 8.
8. **E15: IMPL doc completion marker.** If this was the final wave and post-merge verification passed, run:
   ```bash
   sawtools mark-complete "<impl-doc-path>" --date "YYYY-MM-DD"
   ```
   This writes the SAW:COMPLETE marker and moves the IMPL doc from `docs/IMPL/` to `docs/IMPL/complete/`, keeping the active directory focused on in-progress work. Then commit the archived IMPL doc. This is the formal close of the IMPL lifecycle. Do not write the marker if more waves remain. **E18: Update project memory.** After writing the SAW:COMPLETE marker, update project context:
   ```bash
   sawtools update-context "<manifest-path>" --project-root "<repo-path>"
   ```
   This creates or updates `docs/CONTEXT.md` in the project root using the schema in `protocol/message-formats.md`. It appends to `features_completed` (slug, impl_doc path, wave count, agent count, date), appends any new architectural decisions to `decisions`, and any scaffold-file interfaces to `established_interfaces`. Commit both the IMPL doc update and the CONTEXT.md update in the same commit.
9. **I3: Wave sequencing.** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed. If `--auto` was passed and verification passed, immediately proceed to the next wave. Otherwise, report the wave result and ask the user if they want to continue.
10. If verification fails, report the failures and ask the user how to proceed.

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
