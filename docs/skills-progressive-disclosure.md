# Progressive Disclosure in SAW Skills

The SAW `/saw` skill implements an **advanced progressive disclosure architecture** that extends the [Agent Skills specification](https://agentskills.io/specification#progressive-disclosure) with hook-based deterministic injection. This document explains the four-tier structure, the three-layer injection architecture, and the frontmatter-driven dispatch mechanism that makes context loading automatic rather than convention-based.

## Executive Summary: The Advanced Pattern

SAW's progressive disclosure goes beyond the Agent Skills spec's convention-based model (where references are loaded "as needed" based on model decisions) to implement **deterministic hook-based injection**:

**What makes it advanced:**

1. **Always-needed agent references inlined in agent definitions** — Content that every launch of an agent type needs is now part of the agent definition itself. Conditional references (3 total) are injected by the `inject-agent-context` script when specific scenarios are detected.
2. **Hook-based enforcement** — Claude Code lifecycle hooks (`inject_skill_context`, `validate_agent_launch`) inject references automatically before the model runs
3. **Conditional injection** — Direct conditional logic in scripts enables scenario-specific loading (e.g., only inject program contracts when `--program` flag present)
4. **Two-surface architecture** — Orchestrator references use `UserPromptSubmit` + `additionalContext`; subagent references use `PreToolUse/Agent` + `updatedInput.prompt`
5. **Three-layer fallback** — Hooks (Layer 1, deterministic) → Scripts (Layer 2, model-initiated) → Routing table (Layer 3, convention-based)
6. **Vendor-neutral scripts** — Bash scripts (`inject-context`, `inject-agent-context`) use direct conditional logic for platforms without hooks
7. **Dedup markers** — HTML comments prevent double-injection regardless of which layer loaded the content

**The result:** A `/saw wave` invocation never loads program coordination logic. A scout launch never loads wave agent worktree isolation procedures. Conditional references (program contracts, frozen interfaces) only load when the scenario requires them. The model receives exactly the context it needs, automatically, with zero routing decisions.

**Example flow:**

```
User: /saw program execute "add caching"
  ↓
UserPromptSubmit hook fires
  ↓
inject_skill_context calls inject-context script with direct conditional matching:
  prompt matches "^/saw program" → inject references/program-flow.md
  ↓
Hook returns additionalContext with program-flow.md content
  ↓
Model receives: [saw-skill.md core] + [program-flow.md] before first step
  ↓
Model launches Scout with --program flag (subagent_type: scout)
  ↓
PreToolUse/Agent hook fires
  ↓
validate_agent_launch calls inject-agent-context script:
  scout + "--program" in prompt → inject scout-program-contracts.md
  (suitability gate and implementation process already inlined in scout.md)
  ↓
Hook returns updatedInput.prompt with conditional reference prepended
  ↓
Scout subagent receives: [scout-program-contracts.md] + [scout.md with inlined content] + [orchestrator's prompt]
```

No routing tables. No "read this file if you need it" instructions. Always-needed content is inlined in agent definitions; conditional content is injected deterministically before the model starts.

## The Agent Skills Spec and SAW Extensions

The [Agent Skills specification](https://agentskills.io/specification) defines a three-tier progressive disclosure model for agentic skills:

1. **Metadata** (~100 tokens) — `name` and `description` frontmatter, loaded at startup for all skills
2. **Instructions** (<5000 tokens recommended) — the full `SKILL.md` body, loaded on skill activation
3. **Resources** (as needed) — files in `scripts/`, `references/`, `assets/`, loaded only when required

**SAW's extensions to the spec:**

1. **Tier 0 discovery layer** — `CLAUDE.md` sits outside the skill, providing project-level routing before any skill is activated
2. **Hook-based injection architecture** — Deterministic loading via `UserPromptSubmit` and `PreToolUse/Agent` hooks (Claude Code) + vendor-neutral script fallbacks
3. **Script-based conditional dispatch** — `inject-context` script for orchestrator references, `inject-agent-context` script for conditional subagent references, both using direct conditional logic
4. **Conditional injection** — Script-based pattern matching enables scenario-specific reference loading

The injection architecture is documented in `docs/proposals/agentskills-subcommand-dispatch.md` and `docs/proposals/subagent-prompt-injection.md`.

## Why Progressive Disclosure

Every token loaded into the Orchestrator's context window is a token that cannot be used for reasoning, agent prompts, and coordination work. The `/saw` skill has grown to cover several distinct subcommand families:

- **Core flow** — `/saw scout`, `/saw wave`, `/saw status`, `/saw bootstrap`, `/saw interview` (invoked on nearly every session)
- **Program commands** — `/saw program plan/execute/status/replan` (~324 lines of flow logic)
- **Amend commands** — `/saw amend --add-wave/--redirect-agent/--extend-scope` (~39 lines)
- **Failure routing** — E7a/E19 failure type routing, E25/E26/E35 integration gap detection (~69 lines)

Loading all of this unconditionally would consume ~765 lines on every `/saw` invocation. A `/saw wave` call has no need for the program execution tier graph or the amend flow. Loading them wastes roughly 40% of the skill's effective context budget on content that will never be referenced.

**The advanced pattern:** Rather than relying on the model to read references on-demand (convention-based), SAW uses **hook-based deterministic injection**. Scripts with direct conditional logic determine "when prompt matches X, inject file Y" -- the `UserPromptSubmit` hook enforces this before the model runs. The model receives the context it needs automatically, with zero routing decisions required.

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

**Known limitation:** CLAUDE.md entries are advisory — Claude reads them but there is no enforcement mechanism that prevents the model from ignoring them. The entries should be written to make the correct routing the obvious choice, not to mandate it. The `UserPromptSubmit` hook and `inject-context` script address the same gap the Agent Skills spec leaves open: the spec defines the Resources tier but leaves loading to convention. The script-based conditional dispatch provides deterministic injection for subcommand-anchored references (e.g. `/saw program` → `program-flow.md`). Mid-execution references (failure routing, error states) remain convention-based — see `docs/proposals/agentskills-subcommand-dispatch.md` for scope and known limitations.

### Tier 1 — Metadata (always loaded, ~20 lines)

*Maps to Agent Skills spec: **Metadata** tier (~100 tokens).*

The skill frontmatter is parsed by the Claude Code Skills API before the Orchestrator's context is constructed. It is always present and carries zero variable cost at invocation time. As of v0.56.0, the frontmatter contains only standard Skills API fields -- no custom frontmatter (`triggers:` or `agent-references:`) remains:

```yaml
---
name: saw
description: "Parallel agent coordination: Scout analyzes your code..."
argument-hint: "[bootstrap <project-name> | interview <description> | ...]"
user-invocable: true
allowed-tools: |
  Read, Write, Glob, Grep, Bash(git *),
  Agent(subagent_type=scout), Agent(subagent_type=wave-agent), ...
license: MIT OR Apache-2.0
compatibility: Requires Claude Code (Skills API). Git 2.20+ required.
metadata:
  author: blackwell-systems
  version: "0.56.0"
---
```

**As of v0.56.0, always-needed agent references are inlined directly in agent definitions. The `triggers:` and `agent-references:` custom frontmatter blocks have been removed. Conditional injection (3 references) and orchestrator trigger injection (2 references) are handled by scripts with direct conditional logic. Zero custom frontmatter fields remain.**

Orchestrator trigger injection (`inject-context` script) and conditional agent injection (`inject-agent-context` script) use direct conditional matching in bash rather than YAML frontmatter parsing. Adding a new conditional reference requires updating the script logic.

**Target:** ~20 lines. The frontmatter is now minimal standard Skills API metadata only.

### Tier 2 — Core SKILL.md (loaded on invocation, ~323 lines)

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
| `references/program-flow.md` | `/saw program *` | ~334 |
| `references/amend-flow.md` | `/saw amend *` | ~39 |
| `references/failure-routing.md` | Agent failure or post-merge integration | ~69 |

**Target per file:** No hard limit, but each file should cover exactly one logical domain. A on-demand reference that grows past ~400 lines is a signal it has taken on too many concerns.

## The Advanced Pattern: Hook-Based Deterministic Injection

SAW's implementation goes beyond the Agent Skills spec's convention-based loading model. Instead of relying on the model to follow routing instructions, SAW uses **frontmatter-driven hook injection** to load references deterministically.

### Script-Based Conditional Dispatch

As of v0.56.0, the former YAML frontmatter dispatch tables (`triggers:` and `agent-references:`) have been replaced by direct conditional logic in scripts.

#### Orchestrator Triggers (`inject-context` script)

The `inject-context` script matches prompt patterns with direct conditional logic:

- `^/saw program` in prompt → inject `references/program-flow.md`
- `^/saw amend` in prompt → inject `references/amend-flow.md`

Multiple matches result in all matching references injected (concatenated). No match results in no injection, zero overhead.

The `inject_skill_context` hook (UserPromptSubmit) calls this script, which matches against the prompt and returns `additionalContext` containing the reference file content. The orchestrator receives the context before it runs -- no routing decision required.

#### Agent Conditional References (`inject-agent-context` script)

The `inject-agent-context` script handles 3 conditional references with direct conditional logic:

- `scout` + `--program` in prompt → inject `scout-program-contracts.md`
- `wave-agent` + `baseline_verification_failed` in prompt → inject `wave-agent-build-diagnosis.md`
- `wave-agent` + `frozen_contracts` in prompt → inject `wave-agent-program-contracts.md`

All other agent types receive no injection -- their always-needed content is inlined directly in their agent definitions.

The `validate_agent_launch` hook (PreToolUse/Agent) calls this script, checks conditions against the prompt, and returns `updatedInput.prompt` with reference content prepended when conditions match.

**Conditional injection** enables scenario-specific loading. Scout's program contracts only inject when `--program` appears in the prompt. Wave agent's program contracts only inject when the IMPL has frozen interfaces. This prevents context pollution for scenarios where the content is irrelevant.

### Three-Layer Injection Architecture

The injection system has three layers, each targeting a different deployment context:

| Layer | Mechanism | Platform | Enforcement |
|-------|-----------|----------|-------------|
| **Hook** | `inject_skill_context` + `validate_agent_launch` | Claude Code | Deterministic (always fires) |
| **Script** | `scripts/inject-context` + `scripts/inject-agent-context` | Any platform with Bash | Model-initiated |
| **Fallback** | Routing table in SKILL.md | Any platform | Convention-based |

#### Layer 1: Hook-Based Injection (Claude Code)

Claude Code's lifecycle hooks provide deterministic injection:

- **`inject_skill_context` (UserPromptSubmit)**: Fires before the orchestrator runs. Calls the `inject-context` script which uses direct conditional matching against the prompt, returns `additionalContext` containing reference content.
- **`validate_agent_launch` (PreToolUse/Agent)**: Fires before subagent launch. Calls the `inject-agent-context` script which uses direct conditional logic to determine which references to inject, returns `updatedInput.prompt` with reference content prepended. Only 3 conditional references remain; all always-needed content is inlined in agent definitions.

Both hooks delegate to scripts with direct conditional logic (no YAML frontmatter parsing). The hooks are installed once during setup and fire automatically on every invocation.

**Key distinction: `updatedInput` vs `additionalContext`**

- `additionalContext` (UserPromptSubmit) → adds content to the **orchestrator's** context
- `updatedInput.prompt` (PreToolUse/Agent) → modifies the **subagent's** initial prompt

This distinction is non-obvious. Early implementations tried `additionalContext` in PreToolUse -- this augmented the orchestrator's context, not the subagent's. The correct mechanism is `updatedInput`, which modifies the Agent tool's `prompt` parameter before Claude Code launches the subagent. See `docs/proposals/subagent-prompt-injection.md` for the full decision record.

#### Layer 2: Vendor-Neutral Script Injection

Bash scripts bundled in `scripts/` provide portable injection for any platform with Bash:

- **`scripts/inject-context`**: Uses direct conditional matching against provided prompt (`^/saw program` → program-flow.md, `^/saw amend` → amend-flow.md), outputs concatenated reference content
- **`scripts/inject-agent-context --type <agent-type> --prompt "$prompt"`**: Uses direct conditional logic to match agent type + prompt patterns, outputs reference content for the 3 conditional references

The skill's instructions include: "Before executing, run `scripts/inject-context` with the user's prompt." The model calls Bash, the script matches conditions and outputs reference content, the model has context. Model-initiated, but simpler than following a multi-entry routing table.

Both scripts use direct conditional logic (no YAML frontmatter parsing). Adding a new conditional reference requires updating the script.

#### Layer 3: Routing Table Fallback

The traditional routing table in SKILL.md: "If the argument starts with `program `, read `references/program-flow.md`". Convention-based -- the model must follow routing instructions. This is the always-available fallback for platforms without hooks or script execution.

### Dedup Markers

All three layers use HTML comment markers to prevent double-injection:

```markdown
<!-- injected: references/wave-agent-worktree-isolation.md -->
[reference file content]
```

Before injecting, each layer checks if the marker is already present in the prompt. If found, that reference is skipped. This makes injection idempotent -- whether the orchestrator manually prepended a reference, the hook injected it, or the script loaded it, the subagent never receives duplicate content.

## The Routing Table Pattern (Layer 3 Fallback)

The routing table lives in the "On-Demand References" section of `saw-skill.md`. It has two parts: a display table and imperative dispatch logic.

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

### Step 3: Add conditional dispatch logic

**For orchestrator references** (loaded via `UserPromptSubmit`), add a conditional block to the `inject-context` script:

```bash
# In inject-context script:
if [[ "$prompt" =~ ^/saw\ <subcommand> ]]; then
  inject references/<name>-flow.md
fi
```

**For agent type conditional references** (loaded via `PreToolUse/Agent`), add a conditional block to the `inject-agent-context` script:

```bash
# In inject-agent-context script:
if [[ "$agent_type" == "<type>" ]] && [[ "$prompt" =~ pattern-to-match ]]; then
  inject references/<type>-<name>.md
fi
```

Note: Always-needed references should be inlined in the agent definition rather than injected conditionally. Only scenario-specific content (program contracts, build diagnosis) should use conditional injection.

### Step 4: Add routing table fallback (Layer 3)

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

This fallback ensures the reference loads even on platforms without hooks or script support.

If the trigger is mid-execution rather than at dispatch time (like failure-routing), add the read instruction at the relevant point in the wave loop instead of the dispatch block.

### Step 5: No installer changes required

The `install.sh` script uses wildcard patterns (`prompts/references/*.md`) to automatically symlink all files in `references/`. Adding a new file requires no installer changes -- just re-run `install.sh` after updating the repo.

### Step 6: Test the injection

Verify all three layers:

**Layer 1 (Hooks):**
- A `/saw <new-subcommand>` invocation on Claude Code receives the reference content before the model runs (check via hook logs or model behavior)
- A `/saw wave` invocation does not receive the reference

**Layer 2 (Scripts):**
- `bash scripts/inject-context "/saw <new-subcommand>"` outputs the reference content
- `bash scripts/inject-context "/saw wave"` outputs empty string (no match)

**Layer 3 (Routing table):**
- The model correctly reads the reference when hooks/scripts are disabled

**Back-links:**
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

The skill's four-tier model covers one surface: the **orchestrator's** context window. There is a parallel surface: **agent type prompts** (`wave-agent.md`, `critic-agent.md`, `scout.md`, `planner.md`). Without progressive disclosure, these would be loaded in full on every agent launch, regardless of whether the agent will use the content.

The same principle applies: content needed on <25% of launches belongs in a reference file, not the core type prompt.

### The second progressive disclosure surface

| Surface | Loaded when | Injection mechanism |
|---------|-------------|---------------------|
| SKILL.md (Tier 2) | User invokes `/saw *` | Always loaded |
| Skill references (Tier 3) | Matching subcommand triggered | `UserPromptSubmit` → `additionalContext` into orchestrator |
| Agent type prompt core | Any agent of that type launches | Always loaded |
| Agent type references | Agent of that type launches | `PreToolUse/Agent` → `updatedInput` into subagent |

The bottom two rows are the agent type layer. The injection mechanism is different from the skill layer — and the difference matters.

### Hook Implementation: validate_agent_launch

The `validate_agent_launch` hook serves dual roles: **enforcement** (H5 pre-launch gate with 8 checks) and **injection** (agent type reference loading). It runs on every `Agent` tool call via PreToolUse.

**Execution order:**

1. **Scout path** (before Check 1): Detects `subagent_type: scout` or `[SAW:scout:*]` description. Injects scout references (suitability-gate, implementation-process, conditionally program-contracts). Returns `updatedInput`. Exits 0.
2. **Check 11** (before Check 1): Detects `subagent_type: critic-agent`. Injects critic references (verification-checks, completion-format). Returns `updatedInput`. Exits 0.
3. **Check 12** (before Check 1): Detects `subagent_type: planner`. Injects planner references (suitability-gate, implementation-process, example-manifest). Returns `updatedInput`. Exits 0.
4. **Check 13** (before Check 1): Detects `subagent_type: integration-agent`. Injects integration references (connectors-reference, completion-report). Returns `updatedInput`. Exits 0.
5. **Check 1**: Extracts `[SAW:wave{N}:agent-{ID}]` tag from description. Non-wave-agent calls exit here (pass through).
6. **Checks 2-8**: IMPL existence, IMPL validation, agent in wave, ownership file match, worktree branch, scaffolds committed. Exit 2 if any fail (blocks launch).
7. **Check 10**: Wave agent reference injection. Injects wave-agent references (worktree-isolation, completion-report, build-diagnosis, conditionally program-contracts). Returns `updatedInput`. Exits 0.

Non-wave-agent types must exit **before Check 1** because Check 1 is the wave-agent-only structural validation gate. Checks 2-8 assume wave agent context and would fail on scout/critic/planner/integration launches.

**Detection strategy:**

The hook checks both `subagent_type` field (reliable when present) and description tag (fallback for compatibility):

```bash
is_scout=false
if [[ "$subagent_type" == "scout" ]] || [[ "$description" =~ \[SAW:scout ]]; then
  is_scout=true
fi
```

Description tags (`[SAW:scout:slug]`, `[SAW:critic:impl-slug]`) are the SAW session fingerprint used by monitoring (E40) and SubagentStop validation (E42). The hook auto-fixes missing tags when `subagent_type` is present but description lacks the tag.

**updatedInput preservation:**

The hook preserves all original `tool_input` fields (`run_in_background`, `model`, `name`, `isolation`) when returning `updatedInput`:

```bash
jq -n --arg inject "$inject_content" --arg orig "$prompt" --argjson orig_input "$tool_input" \
  '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow",
    "updatedInput": ($orig_input | .prompt = ($inject + "\n\n" + $orig))}}'
```

The `$orig_input | .prompt = (...)` pattern modifies `prompt` in place on the original object, preserving all other fields. This ensures background execution, model selection, and isolation settings survive the hook.

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

See `docs/proposals/subagent-prompt-injection.md` for the full decision record (including why this was a non-obvious discovery — `additionalContext` was tried first and blocked by critic review).

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
| `scout` | ~208 lines | `scout-suitability-gate.md`, `scout-implementation-process.md`, `scout-program-contracts.md` |
| `wave-agent` | ~151 lines | `wave-agent-worktree-isolation.md`, `wave-agent-build-diagnosis.md`, `wave-agent-completion-report.md` |
| `critic-agent` | ~90 lines | `critic-agent-verification-checks.md`, `critic-agent-completion-format.md` |
| `planner` | ~143 lines | `planner-suitability-gate.md`, `planner-implementation-process.md`, `planner-example-manifest.md` |
| `integration-agent` | ~133 lines | `integration-connectors-reference.md`, `integration-agent-completion-report.md` |
| `scaffold-agent` | ~159 lines | (no extracted references — all content kept in core prompt) |

Injection is implemented in `validate_agent_launch` as named check blocks. The execution order in the hook is:

1. **Scout path** — fires before Check 1; injects scout references, emits `updatedInput`, exits 0
2. **Check 11 (critic-agent)** — fires before Check 1; injects critic references, emits `updatedInput`, exits 0
3. **Check 12 (planner)** — fires before Check 1; injects planner references, emits `updatedInput`, exits 0
4. **Check 13 (integration-agent)** — fires before Check 1; injects integration references, emits `updatedInput`, exits 0
5. **Check 1** — extracts `[SAW:wave{N}:agent-{ID}]` tag from description; non-wave-agent calls exit here
6. **Checks 2–8** — IMPL existence, IMPL validation, agent-in-wave, ownership file, worktree branch, scaffold committed
7. **Check 10 (wave-agent)** — runs after Checks 1–8 pass; injects wave-agent references into `updatedInput`

Checks 11–13 and the Scout path are positioned before Check 1 (the wave-agent gate) because they must exit early on non-wave-agent launches. Check 10 is positioned after Checks 2–8 because wave-agent injection only runs when those structural checks have passed.

### Wave-agent as the first progressive disclosure surface

The wave agent is the first subagent type to fully apply the progressive disclosure pattern at the subagent level. The wave agent's worktree isolation protocol (Steps 0/0.5, absolute path patterns, go.mod warning), completion report reference (`sawtools set-completion` with examples for all status/failure types), and H7 build failure diagnosis have been extracted from the core `agents/wave-agent.md` prompt into three always-injected reference files. A fourth file (`wave-agent-program-contracts.md`) is injected conditionally only when the IMPL has frozen interface contracts.

The extraction reduces the wave-agent type prompt from a large self-contained document to a slim identity core (~151 lines), with heavy procedural content deferred to `references/wave-agent-*.md`. This means every wave agent launch saves the context cost of the full procedure — paying it only via the hook, which prepends the references before the agent's first step.

The injection mechanism is `updatedInput.prompt` via the `validate_agent_launch` PreToolUse/Agent hook (Check 10). Detection fires on `subagent_type: wave-agent` in tool input or `[SAW:wave` in the description. Dedup markers (`<!-- injected: references/wave-agent-worktree-isolation.md -->`, `<!-- injected: references/wave-agent-completion-report.md -->`, etc.) ensure idempotency.

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

Detection in `validate_agent_launch` (Check 11) fires on `subagent_type: critic-agent` in tool input or `[SAW:critic` in the description. Dedup markers (`<!-- injected: references/critic-agent-verification-checks.md -->` and `<!-- injected: references/critic-agent-completion-format.md -->`) prevent double-injection. The slim `critic-agent.md` core (~90 lines) carries identity, role invariants, and a reference loading block instructing the agent to skip re-reading files whose markers are already in context.

With scout, wave-agent, and critic-agent all using hook-based progressive disclosure, the pattern is now applied to all three primary SAW workflow agent types: analysis (scout), implementation (wave-agent), and review (critic-agent).

### Planner as the fourth progressive disclosure surface

The planner agent is the fourth SAW agent type to fully apply the progressive disclosure pattern at the subagent level. The planner's suitability gate (4-question program assessment with verdicts and time estimates), implementation process (Steps 1–10 for analyzing the project and producing a PROGRAM manifest), and example manifest (a complete annotated example PROGRAM manifest for a fictional project) have been extracted from the core `agents/planner.md` prompt into three always-injected reference files: `references/planner-suitability-gate.md`, `references/planner-implementation-process.md`, and `references/planner-example-manifest.md`.

Like critic-agent, planner has no conditional references — all three files are always injected. Every planner launch evaluates program suitability, runs the full implementation process, and can benefit from an example manifest as a structural guide.

Detection in `validate_agent_launch` (Check 12) fires on `subagent_type: planner` in tool input or `[SAW:planner` in the description. Dedup markers (`<!-- injected: references/planner-suitability-gate.md -->`, `<!-- injected: references/planner-implementation-process.md -->`, `<!-- injected: references/planner-example-manifest.md -->`) prevent double-injection. The slim `planner.md` core (~143 lines) carries identity, role definition, and a reference loading block instructing the agent to skip re-reading files whose markers are already in context.

With scout, wave-agent, critic-agent, and planner all using hook-based progressive disclosure, the pattern now covers four of the five progressive-disclosure-enabled agent types: analysis (scout), implementation (wave-agent), review (critic-agent), and program planning (planner). Integration-agent (Check 13) is the fifth.

### Integration-agent as the fifth progressive disclosure surface

The integration agent is the fifth SAW agent type to use hook-based progressive disclosure. Two reference files have been extracted from the core `agents/integration-agent.md` prompt: `references/integration-connectors-reference.md` (connector and gap-detection reference) and `references/integration-agent-completion-report.md` (completion report format). Both are always injected — like critic-agent, the integration agent has no conditional references.

Detection in `validate_agent_launch` (Check 13) fires on `subagent_type: integration-agent` in tool input or `[SAW:integration` in the description. Dedup markers (`<!-- injected: references/integration-connectors-reference.md -->` and `<!-- injected: references/integration-agent-completion-report.md -->`) prevent double-injection.

### The generalized pattern

With scout, wave-agent, critic-agent, planner, and integration-agent all using hook-based progressive disclosure, the pattern is fully generalized. Any SAW agent type can apply it:

1. Extract heavy procedural content from the core type prompt into `references/<type>-<name>.md` files
2. Add a detection block in `validate_agent_launch` for the new `subagent_type`
3. Inject using `updatedInput.prompt` with dedup markers `<!-- injected: references/<type>-<name>.md -->`
4. The core type prompt stays as a slim identity core; references carry the procedure

The dedup marker protocol (`<!-- injected: references/X.md -->`) is shared across all agent types. It prevents double-injection regardless of whether the orchestrator or the hook is the injection source, making the system composable and order-independent.

### Three-layer injection architecture

The injection system has three layers, each targeting a different deployment context:

| Layer | Mechanism | Platform | Enforcement |
|-------|-----------|----------|-------------|
| Hook | `validate_agent_launch` PreToolUse/Agent | Claude Code | Deterministic (always fires) |
| Script | `scripts/inject-agent-context` | Any platform with Bash | Model-initiated |
| Fallback | Routing table in SKILL.md | Any platform | Convention-based |

`inject-agent-context` is the authoritative source for conditional reference mapping and dedup markers, called by the hook for Layer 1. Output from either layer is idempotent when combined. Platforms that register the hook get Layer 1 automatically. Platforms without Claude Code hooks but with Bash can call the script directly as Layer 2. The routing table in `saw-skill.md` remains the always-available Layer 3 fallback.

See `docs/proposals/subagent-prompt-injection.md` for the full decision record on why `updatedInput` (not `additionalContext`) is required for subagent injection.

### How to extend — adding a new agent type reference

1. Write `implementations/claude-code/prompts/references/<type>-<name>.md` with the extracted content (all reference files live in the top-level `references/` directory, not in a per-agent subdirectory)
2. Add a back-link in the reference file pointing to the core type prompt for shared logic it defers to
3. Add a stub in the core type prompt: "For X, see `${CLAUDE_SKILL_DIR}/references/<type>-<name>.md`"
4. For always-needed content, inline it directly in the agent definition file (`agents/<type>.md`). For conditional content only, add conditional logic to the `inject-agent-context` script:
   ```bash
   # In inject-agent-context:
   if [[ "$agent_type" == "<new-type>" ]] && [[ "$prompt" =~ condition ]]; then
     inject references/<type>-<name>.md
   fi
   ```
5. If conditional injection is needed, add a detection block to `validate_agent_launch` **before Check 1** (the wave-agent tag gate), following the pattern of the existing Scout path. New non-wave-agent types must exit before Check 1, which is the wave-agent-only structural validation gate.
6. No installer changes required — `install.sh` dynamically discovers all `*.md` files in `references/` and symlinks them automatically
7. Verify: launch a `new-agent-type` agent and confirm the reference marker appears in its initial context

---

## Summary: The Complete Advanced Pattern

SAW's progressive disclosure architecture combines **four tiers**, **three layers**, and **two surfaces** to deliver deterministic context loading:

### Four Tiers

1. **Tier 0** (CLAUDE.md): Discovery index. Always present. Zero invocation cost.
2. **Tier 1** (Frontmatter): Standard Skills API metadata only. No custom frontmatter fields. Parsed at skill load time.
3. **Tier 2** (Core SKILL.md): ~183 lines covering core flows (scout, wave, status, bootstrap, interview). Loaded on every `/saw` invocation.
4. **Tier 3** (References): Conditional reference files loaded only when scenario requires them. Always-needed content inlined in agent definitions.

### Three Layers

1. **Hook Layer** (Claude Code): `inject_skill_context` (UserPromptSubmit) + `validate_agent_launch` (PreToolUse/Agent). Deterministic injection before model runs.
2. **Script Layer** (Vendor-neutral): `scripts/inject-context` + `scripts/inject-agent-context`. Model-initiated via Bash calls.
3. **Fallback Layer** (Universal): Routing table in SKILL.md. Convention-based, always available.

### Two Surfaces

1. **Orchestrator surface**: Skill references loaded via `inject-context` script + `UserPromptSubmit` + `additionalContext`
2. **Subagent surface**: Conditional agent references loaded via `inject-agent-context` script + `PreToolUse/Agent` + `updatedInput.prompt`; always-needed content inlined in agent definitions

### Key Mechanisms

- **Script-based dispatch**: Direct conditional logic in scripts handles "when X, inject Y" rules
- **Conditional injection**: Pattern matching in scripts enables scenario-specific loading
- **Dedup markers**: HTML comments prevent double-injection across layers
- **updatedInput preservation**: Hook preserves all `tool_input` fields when modifying prompt
- **Early exit pattern**: Non-wave-agent types exit before wave-agent validation checks

### The Result

- A `/saw wave` invocation never loads program coordination logic (saves ~324 lines)
- A `/saw scout` launch never loads wave agent worktree isolation (saves ~93 lines)
- Conditional references (program contracts, frozen interfaces) only load when scenario requires them
- Scout reference injection saves ~200+ lines per launch via hook prepending
- The model receives exactly the context it needs, automatically, with zero routing decisions

### Why This Matters

**Before (convention-based):**
```
Model: I should read references/program-flow.md
Model: [calls Read tool]
Model: [reads 324 lines]
Model: [processes content]
Model: [continues execution]
```

**After (hook-based):**
```
UserPromptSubmit hook fires
Hook: prompt matches "^/saw program", injecting references/program-flow.md
Model receives: [core] + [program-flow.md] in initial context
Model: [begins execution with all context present]
```

The difference is **determinism**. The model cannot skip routing, misread the table, or forget to load a reference. The context is constructed correctly before the model starts, every time, automatically.

This is the advanced pattern: not just deferred loading, but **deterministic hook-enforced injection with script-based conditional dispatch, inlined always-needed content, and three-layer platform compatibility**.
