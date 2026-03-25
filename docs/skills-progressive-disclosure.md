# Progressive Disclosure in SAW Skills

The SAW `/saw` skill uses a three-tier progressive disclosure model to minimize context window usage. This document explains the design, implementation, and how to extend it.

## Why Progressive Disclosure

Every token loaded into the Orchestrator's context window is a token that cannot be used for reasoning, agent prompts, and coordination work. The `/saw` skill has grown to cover several distinct subcommand families:

- **Core flow** — `/saw scout`, `/saw wave`, `/saw status`, `/saw bootstrap`, `/saw interview` (invoked on nearly every session)
- **Program commands** — `/saw program plan/execute/status/replan` (~324 lines of flow logic)
- **Amend commands** — `/saw amend --add-wave/--redirect-agent/--extend-scope` (~39 lines)
- **Failure routing** — E7a/E19 failure type routing, E25/E26/E35 integration gap detection (~69 lines)

Loading all of this unconditionally would consume ~715 lines on every `/saw` invocation. A `/saw wave` call has no need for the program execution tier graph or the amend flow. Loading them wastes roughly 40% of the skill's effective context budget on content that will never be referenced.

Progressive disclosure defers these reference files until the matching subcommand is actually invoked.

## The Three Tiers

### Tier 1 — Metadata (always loaded, ~17 lines)

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

### Tier 2 — Core SKILL.md (always loaded, ~283 lines)

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

Three reference files live in `implementations/claude-code/prompts/references/`. The Orchestrator reads them only when the routing table matches the invoked subcommand.

| File | Subcommand trigger | Lines |
|------|--------------------|-------|
| `references/program-flow.md` | `/saw program *` | ~324 |
| `references/amend-flow.md` | `/saw amend *` | ~39 |
| `references/failure-routing.md` | Agent failure or post-merge integration | ~69 |

**Target per file:** No hard limit, but each file should cover exactly one logical domain. A reference file that grows past ~400 lines is a signal it has taken on too many concerns.

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

**Key convention:** All reference file paths use `${CLAUDE_SKILL_DIR}/references/<name>.md`. The `CLAUDE_SKILL_DIR` environment variable is set by the Skills API; if unset, the Orchestrator falls back to `~/.claude/skills/saw/`.

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
   This back-link convention is important: it keeps reference files focused on their additive content and prevents the core wave loop from being duplicated and drifting.

3. **Lifecycle analogy tables** (optional) — Program-flow uses a table mapping IMPL lifecycle commands to their Program equivalents. This gives the Orchestrator structural context without repeating the underlying logic.

4. **Subcommand sections** — Each subcommand variant gets its own `##` header with numbered Orchestrator steps.

## The Symlink Setup

The `agents/` subdirectory already uses the symlink pattern: agent type definition files live in `implementations/claude-code/prompts/agents/` and are symlinked into `~/.claude/skills/saw/agents/` during installation. The Orchestrator references them as `${CLAUDE_SKILL_DIR}/agents/<type>.md`.

The `references/` directory should use the same pattern. The current installation instructions in `implementations/claude-code/README.md` document agent symlinks but do not yet include the `references/` directory.

**Gap:** `implementations/claude-code/hooks/install.sh` is a hooks installer and does not handle skill file symlinks at all — skill symlinks are documented manually in the README's "Step 3" and "Step 4" sections. The `references/` symlinks need to be added to those manual instructions.

The commands to add to the README installation block:

```bash
# Symlink on-demand reference files
mkdir -p ~/.claude/skills/saw/references
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/references/program-flow.md \
       ~/.claude/skills/saw/references/program-flow.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/references/amend-flow.md \
       ~/.claude/skills/saw/references/amend-flow.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/references/failure-routing.md \
       ~/.claude/skills/saw/references/failure-routing.md
```

Like the `agents/` symlinks, these should be one-time setup steps. A `git pull` on the protocol repo will then update all reference files automatically.

## How to Extend — Adding a New Reference File

Use this checklist when extracting a new subcommand family into a reference file:

### Step 1: Determine whether extraction is warranted

Apply the threshold heuristic:
- Logic invoked on **more than 50%** of `/saw` calls → keep in core SKILL.md
- Logic invoked on **less than 25%** of `/saw` calls → extract to a reference file
- 25–50% → judgment call based on line count and conceptual distance from the wave loop

A new subcommand family that adds 50+ lines of flow logic and is not needed for scout/wave/status is almost always a candidate for extraction.

### Step 2: Write the reference file

Create `implementations/claude-code/prompts/references/<name>-flow.md`.

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

In `implementations/claude-code/README.md`, add symlink commands for the new reference file to the "Step 3: Install the Skill" section, following the same pattern as the existing `agents/` symlinks.

### Step 5: Test the routing

Verify:
- A `/saw <new-subcommand>` invocation reads the reference file before executing any logic
- A `/saw wave` invocation does not read the reference file
- The reference file's back-links correctly defer to core SKILL.md for shared logic

## What Stays in Core

The decision heuristic:

| Condition | Decision |
|-----------|----------|
| Invoked on >50% of `/saw` calls | Stays in core SKILL.md |
| Invoked on <25% of `/saw` calls | Extract to reference file |
| 25–50% and adds >80 lines | Extract to reference file |
| 25–50% and <30 lines | Stays in core SKILL.md |
| Directly referenced by the wave loop | Stays in core SKILL.md |
| Adds a new subcommand family with no overlap with wave loop | Extract to reference file |

**Always in core:**
- Role separation invariants (I6) and agent type preference — checked on every invocation
- The on-demand routing table itself — the dispatch mechanism must always be present
- Pre-flight validation — checked once per session on the first `/saw` call
- IMPL discovery and targeting — used by wave, status, and amend
- The full wave loop (steps 1–11) — the core value of the skill; invoked by every `/saw wave` call
- E37 Critic Gate logic — triggered during scout and wave flows, both common paths

**Always extracted:**
- Subcommand families that represent a distinct execution tier (program, amend)
- Failure routing logic beyond the basic "read failure-routing.md" trigger point — agents succeed on the majority of runs, so detailed remediation logic is pay-per-use
