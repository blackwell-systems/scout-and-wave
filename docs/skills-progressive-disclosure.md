# Progressive Disclosure in SAW Skills

The SAW `/saw` skill implements the [Agent Skills progressive disclosure model](https://agentskills.io/specification#progressive-disclosure) with a four-tier structure to minimize context window usage. This document explains how SAW applies the spec, where it extends it, and how to add new tiers.

## The Agent Skills Spec

The [Agent Skills specification](https://agentskills.io/specification) defines a three-tier progressive disclosure model for agentic skills:

1. **Metadata** (~100 tokens) — `name` and `description` frontmatter, loaded at startup for all skills
2. **Instructions** (<5000 tokens recommended) — the full `SKILL.md` body, loaded on skill activation
3. **Resources** (as needed) — files in `scripts/`, `references/`, `assets/`, loaded only when required

SAW extends this with a Tier 0 discovery layer (`CLAUDE.md`) that sits outside the skill itself, providing project-level routing before any skill is activated.

The `triggers:` frontmatter extension proposed in `docs/proposals/agentskills-subcommand-dispatch.md` is SAW's contribution back to the ecosystem — deterministic enforcement of Tier 3 loading via the `UserPromptSubmit` hook, rather than convention-based routing.

## Why Progressive Disclosure

Every token loaded into the Orchestrator's context window is a token that cannot be used for reasoning, agent prompts, and coordination work. The `/saw` skill has grown to cover several distinct subcommand families:

- **Core flow** — `/saw scout`, `/saw wave`, `/saw status`, `/saw bootstrap`, `/saw interview` (invoked on nearly every session)
- **Program commands** — `/saw program plan/execute/status/replan` (~324 lines of flow logic)
- **Amend commands** — `/saw amend --add-wave/--redirect-agent/--extend-scope` (~39 lines)
- **Failure routing** — E7a/E19 failure type routing, E25/E26/E35 integration gap detection (~69 lines)

Loading all of this unconditionally would consume ~715 lines on every `/saw` invocation. A `/saw wave` call has no need for the program execution tier graph or the amend flow. Loading them wastes roughly 40% of the skill's effective context budget on content that will never be referenced.

Progressive disclosure defers these on-demand references until the matching subcommand is actually invoked.

## The Four Tiers

> **Spec alignment:** The Agent Skills spec defines three tiers (Metadata, Instructions, Resources). SAW adds Tier 0 as a discovery layer that sits outside the spec's scope — it is not part of the skill itself, but part of the project environment.

### Tier 0 — CLAUDE.md Index (always in context, zero invocation cost)

*Not part of the Agent Skills spec — SAW extension for project-level discovery.*

`CLAUDE.md` files — global (`~/.claude/CLAUDE.md`) or project-level (`.claude/CLAUDE.md`) — are loaded into every Claude Code session before any user message is processed. They are not loaded *by* a skill; they are always present. This makes them the ideal entry point for the entire progressive disclosure system.

**Role in progressive disclosure:** CLAUDE.md acts as the discovery layer — the thing that tells Claude what tools and skills are available in this environment, without loading any of them. It is the outermost ring of the system:

```markdown
## Available Skills

- `/saw` — Scout-and-Wave parallel agent coordination.
  Use for any feature work that can be decomposed across files.
  Subcommands: scout, wave, status, bootstrap, interview, program, amend.
```

A user who types "add caching to the API" in a project with this CLAUDE.md gets the routing suggestion immediately — the skill's 300-line body hasn't loaded yet. Only when they invoke `/saw scout` does Tier 1 and Tier 2 come into play.

**What belongs in the Tier 0 entry:**
- Skill name and one-sentence purpose
- Top-level subcommand list (breadth-first, no depth)
- The trigger condition ("use for X")
- No implementation detail, no flags, no flow logic

**What does not belong:**
- Anything duplicating content from the skill frontmatter or SKILL.md
- Subcommand option lists (those belong in Tier 2 or Tier 3)
- Protocol invariants, error codes, or agent types

**CLAUDE.md as a multi-skill index:** In a project that uses multiple skills, CLAUDE.md can serve as the index for all of them. Each entry is a few lines; together they give Claude (and the user) a map of the full capability surface without loading any of it:

```markdown
## Available Skills

- `/saw` — Parallel agent coordination for feature work.
- `/deploy` — Deploy to staging or production.
- `/review` — AI code review on open PRs.
```

This is the progressive disclosure model applied at the project level: the index is always loaded; the skill bodies load only when invoked.

**Known limitation:** CLAUDE.md entries are advisory — Claude reads them but there is no enforcement mechanism that prevents the model from ignoring them. The entries should be written to make the correct routing the obvious choice, not to mandate it. The `UserPromptSubmit` hook proposal (`docs/proposals/agentskills-subcommand-dispatch.md`) addresses the same gap the Agent Skills spec leaves open: the spec defines the Resources tier but leaves loading to convention. The `triggers:` frontmatter extension provides deterministic dispatch for subcommand-anchored references (e.g. `/saw program` → `program-flow.md`). Mid-execution references (failure routing, error states) remain convention-based — see the proposal for scope and known limitations.

### Tier 1 — Metadata (always loaded, ~17 lines)

*Maps to Agent Skills spec: **Metadata** tier (~100 tokens).*

The skill frontmatter is parsed by the Claude Code Skills API before the Orchestrator's context is constructed. It is always present and carries zero variable cost at invocation time:

```yaml
---
name: saw
description: "Parallel agent coordination: Scout analyzes your code..."
argument-hint: "[bootstrap <project-name> | interview <description> | ...]"
disable-model-invocation: true
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *), ...
---
```

**Target:** ~17 lines. Nothing in the frontmatter should grow beyond what the Skills API needs to route and present the skill.

### Tier 2 — Core SKILL.md (loaded on invocation, ~283 lines)

*Maps to Agent Skills spec: **Instructions** tier (<5000 tokens recommended).*

The main body of `saw-skill.md` is loaded on every `/saw` invocation. It contains everything the Orchestrator needs for the most common subcommands:

- Role separation invariants (I6)
- Agent model selection (config lookup, `--model` override, fallback rule)
- Supporting files table (`agent-template.md`, `saw-bootstrap.md`, `agents/`)
- The on-demand routing table (lines 76–88)
- Invocation mode table
- Pre-flight validation checklist
- Execution logic for scout, wave, status, bootstrap, interview
- The full wave loop (prepare-wave, agent launching, finalize-wave, close-impl)

**Target:** Under 350 lines. The heuristic for what stays in core is: any logic invoked on more than 50% of `/saw` calls belongs here. If it is only needed for a minority subcommand family, it is a candidate for extraction.

### Tier 3 — On-Demand Reference Files (loaded only when matched)

*Maps to Agent Skills spec: **Resources** tier (loaded as needed). The spec recommends keeping reference files focused and one level deep from SKILL.md.*

Three on-demand references live in `implementations/claude-code/prompts/references/`. The Orchestrator reads them only when the routing table matches the invoked subcommand.

| File | Subcommand trigger | Lines |
|------|--------------------|-------|
| `references/program-flow.md` | `/saw program *` | ~324 |
| `references/amend-flow.md` | `/saw amend *` | ~39 |
| `references/failure-routing.md` | Agent failure or post-merge integration | ~69 |

**Target per file:** No hard limit, but each file should cover exactly one logical domain. A on-demand reference that grows past ~400 lines is a signal it has taken on too many concerns.

## The Routing Table Pattern

The routing table lives in the "On-Demand References" section of `saw-skill.md` (lines 76–88). It has two parts: a display table and imperative dispatch logic.

**Display table** (documentation, not execution):

```
| Subcommand | Reference file |
|------------|----------------|
| `/saw program *` | Read `${CLAUDE_SKILL_DIR}/references/program-flow.md` |
| `/saw amend *` | Read `${CLAUDE_SKILL_DIR}/references/amend-flow.md` |
| Agent failure or post-merge integration | Read `${CLAUDE_SKILL_DIR}/references/failure-routing.md` |
```

**Dispatch logic** (the Orchestrator actually follows this):

```
If the argument starts with `program `:
- Read `${CLAUDE_SKILL_DIR}/references/program-flow.md`
- Follow instructions for the specific subcommand
- Do not continue to bootstrap/scout/wave logic below

If the argument starts with `amend `:
- Read `${CLAUDE_SKILL_DIR}/references/amend-flow.md`
- Follow the instructions for the specific subcommand
- Do not continue to bootstrap/scout/wave logic below

If no routing match, continue with the execution flows below
```

The failure-routing reference is triggered mid-execution rather than at dispatch time. Two trigger points in the wave loop emit explicit read instructions:

1. After all agents complete, if any report non-complete status: "read `${CLAUDE_SKILL_DIR}/references/failure-routing.md` for E7a retry context, E19 failure type routing..."
2. After wave finalization succeeds, for integration gap detection: "read `${CLAUDE_SKILL_DIR}/references/failure-routing.md` § E25/E26/E35..."

This means failure routing is never loaded for successful waves, which is the common case.

**Key convention:** All on-demand reference paths use `${CLAUDE_SKILL_DIR}/references/<name>.md`. The `CLAUDE_SKILL_DIR` environment variable is set by the Skills API; if unset, the Orchestrator falls back to `~/.claude/skills/saw/`.

## The Reference File Format

Reference files follow a consistent internal structure:

1. **Header comment** — A single line indicating when to load the file:
   ```
   # Program Commands — On-Demand Reference
   ```

2. **Back-link for shared logic** — If the reference needs behavior already defined in core SKILL.md, it references it rather than duplicating it. Example from `program-flow.md`:
   ```
   **Wave execution:** Program tiers execute IMPLs using the standard wave loop from
   the core SKILL.md (steps 3-11 of Execution Logic). Do not duplicate that logic
   here — when Step 3b says "use existing `/saw wave --auto` flow", follow the
   wave loop in the core file.
   ```
   This back-link convention is important: it keeps on-demand references focused on their additive content and prevents the core wave loop from being duplicated and drifting.

3. **Lifecycle analogy tables** (optional) — Program-flow uses a table mapping IMPL lifecycle commands to their Program equivalents. This gives the Orchestrator structural context without repeating the underlying logic.

4. **Subcommand sections** — Each subcommand variant gets its own `##` header with numbered Orchestrator steps.

## The Symlink Setup

The `agents/` subdirectory already uses the symlink pattern: agent type definition files live in `implementations/claude-code/prompts/agents/` and are symlinked into `~/.claude/skills/saw/agents/` during installation. The Orchestrator references them as `${CLAUDE_SKILL_DIR}/agents/<type>.md`.

The `references/` directory uses the same pattern. The consolidated `install.sh` at the repo root handles all symlinks: core skill files, agent definitions, references, and scripts. It dynamically discovers files in each subdirectory, so adding a new reference or agent definition requires no installer changes.

**Gap: resolved.** The root `install.sh` now handles skill files, hooks, settings.json registration, and Agent permission in a single command. The old `hooks/install.sh` delegates to it.

Like the `agents/` symlinks, these should be one-time setup steps. A `git pull` on the protocol repo will then update all on-demand references automatically.

## How to Extend — Adding a New Reference File

Use this checklist when extracting a new subcommand family into an on-demand reference:

### Step 1: Determine whether extraction is warranted

Apply the threshold heuristic:
- Logic invoked on **more than 50%** of `/saw` calls → keep in core SKILL.md
- Logic invoked on **less than 25%** of `/saw` calls → extract to an on-demand reference
- 25–50% → judgment call based on line count and conceptual distance from the wave loop

A new subcommand family that adds 50+ lines of flow logic and is not needed for scout/wave/status is almost always a candidate for extraction.

### Step 2: Write the on-demand reference

Create `implementations/claude-code/prompts/references/<name>-flow.md`.

**One-level-deep rule:** Reference files must link directly from `saw-skill.md` — never from another on-demand reference. Claude may preview long files with partial reads (`head -100`); a reference that itself points to sub-references risks the leaf content being read incompletely or not at all. If an on-demand reference needs to point to additional content, either inline it or add a separate top-level entry to the routing table.

**Table of contents (required if file > 100 lines):** Place a contents list immediately after the header comment, before any prose. List all `##` sections. This ensures Claude sees the full scope of available information even when previewing. Files under 100 lines do not need one.

Structure:
```markdown
# <Subcommand Family> — On-Demand Reference

**<Any shared logic>:** Use the <X> from core SKILL.md. Do not duplicate.

## /saw <subcommand> --<flag>

**Orchestrator steps:**
1. ...
2. ...
```

Include back-links to core SKILL.md for any logic that is already defined there (wave loop, IMPL discovery, agent launching). Do not copy-paste.

### Step 3: Add the routing stub to core SKILL.md

In the "On-Demand References" section of `saw-skill.md`, add a row to the display table and a corresponding dispatch block:

**Table row:**
```
| `/saw <subcommand> *` | Read `${CLAUDE_SKILL_DIR}/references/<name>-flow.md` |
```

**Dispatch block** (add after the existing `amend` block):
```
If the argument starts with `<subcommand> `:
- Read `${CLAUDE_SKILL_DIR}/references/<name>-flow.md`
- Follow the instructions for the specific subcommand
- Do not continue to bootstrap/scout/wave logic below
```

If the trigger is mid-execution rather than at dispatch time (like failure-routing), add the read instruction at the relevant point in the wave loop instead of the dispatch block.

### Step 4: Update install instructions

In `implementations/claude-code/README.md`, add symlink commands for the new on-demand reference to the "Step 3: Install the Skill" section, following the same pattern as the existing `agents/` symlinks.

### Step 5: Test the routing

Verify:
- A `/saw <new-subcommand>` invocation reads the on-demand reference before executing any logic
- A `/saw wave` invocation does not read the on-demand reference
- The on-demand reference's back-links correctly defer to core SKILL.md for shared logic

## What Stays in Core

The decision heuristic (for content already past the CLAUDE.md entry stage):

| Condition | Decision |
|-----------|----------|
| Skill discovery / routing hint | Tier 0: CLAUDE.md |
| Invoked on >50% of `/saw` calls | Tier 2: core SKILL.md |
| Invoked on <25% of `/saw` calls | Tier 3: on-demand reference |
| 25–50% and adds >80 lines | Tier 3: on-demand reference |
| 25–50% and <30 lines | Tier 2: core SKILL.md |
| Directly referenced by the wave loop | Tier 2: core SKILL.md |
| Adds a new subcommand family with no overlap with wave loop | Tier 3: on-demand reference |

**Always in Tier 0 (CLAUDE.md):**
- Skill name and one-sentence purpose
- Top-level subcommand list (breadth-first)
- The trigger condition that helps Claude route the user to `/saw`
- Nothing else — no flags, no flow, no protocol terms

**Always in Tier 2 (core SKILL.md):**
- Role separation invariants (I6) and agent type preference — checked on every invocation
- The on-demand routing table itself — the dispatch mechanism must always be present
- Pre-flight validation — checked once per session on the first `/saw` call
- IMPL discovery and targeting — used by wave, status, and amend
- The full wave loop (steps 1–11) — the core value of the skill; invoked by every `/saw wave` call
- E37 Critic Gate logic — triggered during scout and wave flows, both common paths

**Always in Tier 3 (on-demand references):**
- Subcommand families that represent a distinct execution tier (program, amend)
- Failure routing logic beyond the basic "read failure-routing.md" trigger point — agents succeed on the majority of runs, so detailed remediation logic is pay-per-use

---

## Agent Type Progressive Disclosure

The skill's four-tier model covers one surface: the **orchestrator's** context window. There is a parallel surface: **agent type prompts** (`wave-agent.md`, `critic-agent.md`, `scout.md`, `planner.md`). These are loaded in full on every agent launch, regardless of whether the agent will use the content.

The same principle applies: content needed on <25% of launches belongs in a reference file, not the core type prompt.

### The second progressive disclosure surface

| Surface | Loaded when | Injection mechanism |
|---------|-------------|---------------------|
| SKILL.md (Tier 2) | User invokes `/saw *` | Always loaded |
| Skill references (Tier 3) | Matching subcommand triggered | `UserPromptSubmit` → `additionalContext` into orchestrator |
| Agent type prompt core | Any agent of that type launches | Always loaded |
| Agent type references | Agent of that type launches | `PreToolUse/Agent` → `updatedInput` into subagent |

The bottom two rows are the agent type layer. The injection mechanism is different from the skill layer — and the difference matters.

### Why `updatedInput`, not `additionalContext`

`UserPromptSubmit` fires when the user submits a prompt. `PreToolUse/Agent` fires when the orchestrator calls the `Agent` tool to launch a subagent. By the time the orchestrator is launching agents, `UserPromptSubmit` is long past and cannot inject into a subagent's context.

`additionalContext` in a `PreToolUse` hook adds content to the *calling model's* (orchestrator's) context — wrong target. `updatedInput.prompt` modifies the Agent tool's `prompt` parameter before execution — the content becomes part of the subagent's initial message.

```
PreToolUse/Agent hook fires
  → hook reads subagent_type
  → hook loads matching reference files
  → hook returns updatedInput.prompt = "[reference content]\n\n[original prompt]"
  → Claude Code launches subagent with modified prompt
  → subagent has reference content before its first step
```

See `docs/proposals/agentskills-agent-type-injection.md` for the full decision record (including why this was a non-obvious discovery — `additionalContext` was tried first and blocked by critic review).

### What to extract from agent type prompts

The same heuristics apply as for skill references, scoped to the agent type:

| Condition | Decision |
|-----------|----------|
| Needed on every launch of this agent type | Keep in core type prompt |
| Needed only for specific scenarios (errors, edge cases) | Extract to reference file |
| Procedural steps for a specific sub-flow | Extract to reference file |
| Long examples, sample outputs, example manifests | Extract to reference file |
| Identity, role definition, invariants | Always in core type prompt |
| Completion report format | Extract — only needed at end of work |

### Current extraction state

| Agent type | Core prompt | Reference files |
|-----------|-------------|-----------------|
| `scout` | ~166 lines | `scout-suitability-gate.md`, `scout-implementation-process.md`, `scout-program-contracts.md` |
| `wave-agent` | ~133 lines | `worktree-isolation.md`, `build-diagnosis.md`, `completion-report.md` |
| `critic-agent` | ~75 lines | `critic-agent-verification-checks.md`, `critic-agent-completion-format.md` |
| `planner` | ~148 lines | `planner-suitability-gate.md`, `planner-implementation-process.md`, `planner-example-manifest.md` |

Injection is implemented in `validate_agent_launch` checks 9+ (see `implementations/claude-code/hooks/README.md` § Hook 9).

### Wave-agent as the first progressive disclosure surface

The wave agent is the first subagent type to fully apply the progressive disclosure pattern at the subagent level. The wave agent's worktree isolation protocol (Steps 0/0.5, absolute path patterns, go.mod warning), completion report reference (`sawtools set-completion` with examples for all status/failure types), and H7 build failure diagnosis have been extracted from the core `agents/wave-agent.md` prompt into three always-injected reference files. A fourth file (`wave-agent-program-contracts.md`) is injected conditionally only when the IMPL has frozen interface contracts.

The extraction reduces the wave-agent type prompt from a large self-contained document to a slim identity core (~133 lines), with heavy procedural content deferred to `references/wave-agent-*.md`. This means every wave agent launch saves the context cost of the full procedure — paying it only via the hook, which prepends the references before the agent's first step.

The injection mechanism is `updatedInput.prompt` via the `validate_agent_launch` PreToolUse/Agent hook. Detection fires on `subagent_type: wave-agent` in tool input or `[SAW:wave` in the description. Dedup markers (`<!-- injected: references/wave-agent-X.md -->`) ensure idempotency.

### Scout as the second progressive disclosure surface

The scout agent is the second subagent type to fully apply the progressive disclosure pattern at the subagent level. The scout's suitability gate, IMPL production steps (1–17), and program contract handling rules have been extracted from the core `agents/scout.md` prompt into three reference files in `references/scout-*.md`.

This creates a nested application of the pattern: the skill (`saw-skill.md`) is itself a Tier 2 file that defers to Tier 3 on-demand references; the scout agent type prompt is a Tier 2 subagent prompt that defers to its own Tier 3 references. The scout is a Tier 3 reference *from the orchestrator's perspective*, but a Tier 2 document *from the subagent perspective* — with its own progressive disclosure layer beneath it.

The injection mechanism differs between the two layers:

- **Orchestrator references** (`inject_skill_context`, UserPromptSubmit): `additionalContext` into the orchestrator's context
- **Scout references** (`validate_agent_launch`, PreToolUse/Agent): `updatedInput.prompt` into the scout subagent's initial prompt

`validate_agent_launch` provides deterministic injection for subagents, paralleling `inject_skill_context` for the orchestrator skill. The dedup mechanism (`<!-- injected: references/scout-X.md -->` markers) ensures idempotency — if the orchestrator manually prepends a reference, the hook skips that file. This makes the injection transparent and composable.

### Critic-agent as the third progressive disclosure surface

The critic agent is the third core SAW agent type to fully apply the progressive disclosure pattern at the subagent level. The critic's verification checks procedure and completion format reference have been extracted from the core `agents/critic-agent.md` prompt into two always-injected reference files: `references/critic-agent-verification-checks.md` and `references/critic-agent-completion-format.md`.

Unlike wave-agent (conditional injection for program contracts) and scout (conditional injection for `--program` flag), critic-agent has no conditional references — both files are always injected. This reflects the critic's role: every critic launch performs the full verification procedure and writes a completion report, with no scenario-specific paths.

Detection in `validate_agent_launch` fires on `subagent_type: critic-agent` in tool input or `[SAW:critic` in the description. Dedup markers (`<!-- injected: references/critic-agent-X.md -->`) prevent double-injection. The slim `critic-agent.md` core (~75 lines) carries identity, role invariants, and a reference loading block instructing the agent to skip re-reading files whose markers are already in context.

With scout, wave-agent, and critic-agent all using hook-based progressive disclosure, the pattern is now applied to all three core SAW agent types that perform the primary SAW workflow: analysis (scout), implementation (wave-agent), and review (critic-agent).

### Planner as the fourth progressive disclosure surface

The planner agent is the fourth SAW agent type to fully apply the progressive disclosure pattern at the subagent level. The planner's suitability gate (4-question program assessment with verdicts and time estimates), implementation process (Steps 1–10 for analyzing the project and producing a PROGRAM manifest), and example manifest (a complete annotated example PROGRAM manifest for a fictional project) have been extracted from the core `agents/planner.md` prompt into three always-injected reference files: `references/planner-suitability-gate.md`, `references/planner-implementation-process.md`, and `references/planner-example-manifest.md`.

Like critic-agent, planner has no conditional references — all three files are always injected. Every planner launch evaluates program suitability, runs the full implementation process, and can benefit from an example manifest as a structural guide.

Detection in `validate_agent_launch` fires on `subagent_type: planner` in tool input or `[SAW:planner` in the description. Dedup markers (`<!-- injected: references/planner-X.md -->`) prevent double-injection. The slim `planner.md` core (~148 lines) carries identity, role definition, and a reference loading block instructing the agent to skip re-reading files whose markers are already in context.

With scout, wave-agent, critic-agent, and planner all using hook-based progressive disclosure, the pattern now covers all four major SAW agent types: analysis (scout), implementation (wave-agent), review (critic-agent), and program planning (planner).

### The generalized pattern

With scout, wave-agent, critic-agent, and planner all using hook-based progressive disclosure, the pattern is fully generalized. Any SAW agent type can apply it:

1. Extract heavy procedural content from the core type prompt into `references/<type>-<name>.md` files
2. Add a detection block in `validate_agent_launch` for the new `subagent_type`
3. Inject using `updatedInput.prompt` with dedup markers `<!-- injected: references/<type>-<name>.md -->`
4. The core type prompt stays as a slim identity core; references carry the procedure

The dedup marker protocol (`<!-- injected: references/X.md -->`) is shared across all agent types. It prevents double-injection regardless of whether the orchestrator or the hook is the injection source, making the system composable and order-independent.

### How to extend — adding a new agent type reference

1. Write `implementations/claude-code/prompts/agents/<type>/references/<name>.md` with the extracted content
2. Add a back-link in the reference file pointing to the core type prompt for shared logic it defers to
3. Add a stub in the core type prompt: "For X, see `${CLAUDE_SKILL_DIR}/agents/<type>/references/<name>.md`"
4. Add a case branch to `validate_agent_launch` checks 9+:
   ```bash
   new-agent-type) refs=("name.md") ;;
   ```
5. Add symlink in `install.sh` for the new reference file
6. Verify: launch a `new-agent-type` agent and confirm the reference marker appears in its initial context
