# Progressive Disclosure Hook Injection Audit

**Date:** 2026-03-28 (updated 2026-03-29)
**Status:** RESOLVED -- Inline always-needed content, collapse injection to script, remove agent-references frontmatter
**Context:** Analysis of hook-based reference injection vs progressive disclosure principles

**Outcome:** Three changes: (1) Inline always-needed content directly in agent definitions -- hook injection adds complexity without benefit for content that's always loaded. (2) Remove `agent-references:` YAML block from saw-skill.md frontmatter -- declarative config is over-engineered for 3 conditional entries + future dynamic injection that requires script logic anyway. (3) Move all injection logic into `inject-agent-context` script -- one mechanism handles both conditional static files and dynamic context generation. The hook stays (it's the interception point), but the YAML abstraction layer goes.

---

## Abstract: The Hook Injection Pattern Problem

**General problem:** Systems with orchestrators launching subprocesses often face a choice: how do subprocesses receive their instructions?

**Three approaches:**
1. **Inline** -- Instructions embedded in subprocess definition
2. **Hook injection** -- Orchestrator/system injects instructions before subprocess launches
3. **Breadcrumb** -- Subprocess reads instructions on-demand

**Key question:** When is hook injection justified vs inline?

**Common mistake:** Building hook infrastructure for organizational benefits (file splitting), then discovering the content is subprocess-specific (not shared) and always-needed (not conditional). Hook adds complexity without providing DRY or context economy benefits.

**This audit:** Started as "are we overusing hooks?" Initial analysis assumed 4 of 14 references were shared across agent types. Closer inspection revealed that no references are actually shared -- each completion-report and isolation file is agent-type-specific with distinct content. This strengthens the case for inlining: all always-needed references should be inlined, with hooks reserved for the 3 genuinely conditional references and repurposed for dynamic context injection that doesn't exist yet.

**Pattern-level lesson:** Hook injection is justified when content is:
1. **Shared across subprocess types** (DRY benefit)
2. **Conditionally needed** (context economy)
3. **Dynamically generated** (runtime state)

For subprocess-specific, always-needed content: **just inline it**. Same performance, simpler architecture.

**The serendipity:** We built hook injection as the wrong solution for a real problem (breadcrumb non-determinism for always-needed content). The right answer was inline. But the hook interception mechanism is exactly what's needed for a harder problem we hadn't yet addressed: delivering dynamic, situational context that varies per launch (retry errors, prior wave results, cross-repo boundaries). The pattern found its true use case through misapplication.

**The final simplification:** The declarative YAML config (`agent-references:` frontmatter) that drove injection was itself over-engineered. With only 3 conditional static entries remaining (after inlining 11), plus future dynamic injection that requires script logic anyway, the YAML abstraction adds parsing complexity without benefit. The injection logic belongs directly in the script. Declarative config earns its keep with many uniform entries edited by non-technical users -- not 3 entries maintained by the same engineers who write the scripts.

---

## Executive Summary

**Initial concern:** Scout-and-Wave's hook injection system injects most references unconditionally. Are we paying complexity cost for organizational benefit only?

**Key finding after analysis:** All always-needed content should be inlined. Hook injection should be reserved for conditional and dynamic content -- and repurposed for high-value dynamic context injection we aren't doing today (retry context, prior wave summaries, cross-repo coordination).

**The Context Boundary Insight:**
- Orchestrator (saw-skill.md) and subagents (agents/scout.md) are separate processes
- Subagents only see: their agent definition + prompt parameter + hook-injected content
- Without hook injection, the alternatives are: inline in agent prompt OR agent reads via breadcrumb
- For always-needed content, breadcrumbs are strictly worse (latency + risk agent skips)
- For always-needed content, inline vs injection has **same token cost** (both pre-loaded)

**The Sharing Ratio Discovery:**
- Analyzed all 14 agent-reference entries in saw-skill.md frontmatter
- Initially assumed 4 references were "shared" (completion-report format, worktree-isolation)
- Actual finding: **0 references are shared**. Each agent type has its own distinct completion-report file with different commands and formats (wave uses `set-completion`, critic uses `set-critic-review`, integration uses `set-completion` with different conventions). These are separate files bound to specific agent types, not a single shared resource.
- All 11 unconditional references are agent-specific and always-needed
- Only 3 references have legitimate conditional triggers (2 already implemented in frontmatter)

**Recommendation: Inline + Script + Remove Frontmatter**

1. **Inline all always-needed content** (11 references into agent definitions)
   - Scout: suitability-gate, implementation-process
   - Planner: suitability-gate, implementation-process, example-manifest
   - Wave: worktree-isolation, completion-report
   - Critic: verification-checks, completion-format
   - Integration: connectors-reference, completion-report

2. **Remove `agent-references:` block from saw-skill.md frontmatter**
   - Declarative YAML is over-engineered for 3 conditional entries
   - Dynamic injection (the highest-value use case) requires script logic anyway
   - One mechanism (script) instead of two (YAML + script)

3. **Move all injection logic into `inject-agent-context` script**
   - 3 conditional static injections: simple if/cat in bash
   - Future dynamic injections: sawtools commands in same script
   - Hook (`validate_agent_launch`) still fires, but calls the script directly instead of parsing YAML

4. **Build dynamic context injection** (future work, uses same script)
   - Retry context: inject prior attempt errors when relaunching failed agents
   - Prior wave summaries: inject Wave N-1 results for Wave N agents
   - Cross-repo coordination: inject repo boundaries for multi-repo IMPLs
   - Integration gap details: inject specific wiring targets for integration agents

**Result:** Hook stays (interception mechanism). YAML goes (unnecessary abstraction). Script becomes the single source of injection logic for both conditional static files and dynamic content. **Immediate: 4-6 hours (inline + script refactor + frontmatter cleanup). Future: dynamic injection features added to same script.**

---

## Current State: What Gets Injected

Source of truth (current): `agent-references` block in saw-skill.md frontmatter. The `validate_agent_launch` hook (or vendor-neutral `inject-agent-context` script) reads this block and prepends matching references to the agent's input. **This frontmatter block is slated for removal** -- see Recommendation.

### Scout Agent (3 references)

| Reference | When | Size (est) | Conditional? |
|-----------|------|------------|--------------|
| scout-suitability-gate.md | Always | ~2KB | No |
| scout-implementation-process.md | Always | ~3KB | No |
| scout-program-contracts.md | `when: "--program"` | ~2KB | Yes (already conditional in frontmatter) |

**Note:** The frontmatter already has `when: "--program"` on scout-program-contracts.md, making it conditional. The hook only injects it when the agent prompt matches `--program`.

### Wave Agent (4 references)

| Reference | When | Size (est) | Conditional? |
|-----------|------|------------|--------------|
| wave-agent-worktree-isolation.md | Always | ~2KB | No |
| wave-agent-completion-report.md | Always | ~1.5KB | No |
| wave-agent-build-diagnosis.md | Always | ~2KB | No (should be conditional on baseline failure) |
| wave-agent-program-contracts.md | `when: "frozen_contracts_hash\|frozen: true"` | ~2KB | Yes (already conditional in frontmatter) |

**Note:** wave-agent-program-contracts.md was missing from earlier analysis. The frontmatter lists 4 wave-agent references, not 3.

### Critic Agent (2 references)

| Reference | When | Size (est) | Conditional? |
|-----------|------|------------|--------------|
| critic-agent-verification-checks.md | Always | ~2KB | No |
| critic-agent-completion-format.md | Always | ~1KB | No |

### Planner Agent (3 references)

| Reference | When | Size (est) | Conditional? |
|-----------|------|------------|--------------|
| planner-suitability-gate.md | Always | ~2KB | No |
| planner-implementation-process.md | Always | ~3KB | No |
| planner-example-manifest.md | Always | ~4KB | No |

### Integration Agent (2 references)

| Reference | When | Size (est) | Conditional? |
|-----------|------|------------|--------------|
| integration-connectors-reference.md | Always | ~2KB | No |
| integration-agent-completion-report.md | Always | ~1KB | No |

**Totals:** 14 agent-reference entries. 2 already conditional. 1 should become conditional. 11 always-injected.

---

## The Problem

**Design intent:** Progressive disclosure = load content only when needed (context economy).

**Actual behavior:** 11 of 14 references are always-injected. The hook system is doing file concatenation, not progressive disclosure.

**Complexity cost:**
- Hook implementation (`validate_agent_launch` logic)
- Vendor-neutral fallback script (`inject-agent-context`)
- Injection method tracking (E16 validation)
- Debugging opacity (can't see what was injected without logging)

**Benefit received for always-injected content:**
- File organization (split long agent prompts into smaller files)
- Separation of concerns (agent definition vs procedures)
- Future extensibility (hook infrastructure exists)

**Net assessment:** For the 11 always-injected references, the hook provides organizational benefit at the cost of indirection -- but organizational benefit doesn't justify hook complexity when inlining achieves the same result with less indirection. For the 3 conditional references, the hook provides genuine context economy and should be retained. More importantly, the hook infrastructure should be repurposed for dynamic context injection (retry errors, prior wave summaries, cross-repo boundaries) -- content that can't be inlined because it doesn't exist until launch time. This is the hook pattern's natural use case.

---

## Analysis: When is Hook Injection Justified?

### Justified Use Cases

**1. Conditional Loading (Context Economy)**
- Content only needed in specific scenarios
- Saves tokens when not applicable
- Examples:
  - `scout-program-contracts.md` (only for --program mode)
  - `wave-agent-build-diagnosis.md` (only on baseline failure)
  - `wave-agent-program-contracts.md` (only if frozen contracts)

**2. Shared Across Subprocess Types (DRY)**
- Same content used by multiple agent types
- Injection avoids duplication in agent definitions
- **Note:** SAW currently has no truly shared references. Each agent type has its own files, even for similar-sounding concepts (completion reports). This use case is valid in theory but does not apply today.

**3. Dynamic Content (Runtime State) -- THE PRIMARY FUTURE VALUE**
- Generated based on current execution state
- Can't be inlined because it doesn't exist until launch time
- This is where hooks earn their complexity cost
- Examples:
  - Prior attempt error context for retries (attempt > 1)
  - Prior wave completion summaries (wave > 1)
  - Cross-repo coordination context (multi-repo IMPL)
  - Integration gap details from merge analysis (post E25/E26 scan)

### Not Justified

**1. Always-Needed, Agent-Specific Content**
- Every invocation of this agent type requires this content
- No other agent type uses this file
- Inlining has identical token cost, zero hook overhead, and full transparency
- Examples: scout-suitability-gate.md, planner-implementation-process.md, critic-agent-verification-checks.md

**2. File Organization**
- Splitting for readability is a valid goal but doesn't require hook infrastructure
- If the only benefit is "smaller files," consider whether the indirection cost is worth it
- Alternative: use clearly labeled sections within the agent definition file

---

## Context Boundary Insight

The key insight that resolved this audit is understanding how information flows across process boundaries in orchestrator/subprocess architectures.

### How Information Flows

```
Orchestrator Session (Claude running saw-skill.md)
|- Has access to: saw-skill.md, CLAUDE.md, project files
|- Does NOT pass saw-skill.md to subagents
'- Launches subagent via Agent tool
    |
Subagent Process (separate Claude instance)
|- Gets: agents/scout.md (as system prompt)
|- Gets: prompt parameter from orchestrator
|- Does NOT see: saw-skill.md
'- Hook injects: references/*.md files (via updatedInput)
```

**Subagents are separate processes.** They only see:
1. Their agent definition (agents/scout.md, agents/wave-agent.md, etc.)
2. The prompt parameter passed by orchestrator
3. Content injected via hooks

### The Three Delivery Mechanisms

**Hook Injection (current for 11 unconditional + 3 conditional references):**
- Hook prepends references/*.md to agent's input
- Content is pre-loaded in agent's context
- Agent sees it immediately, no Read tool needed
- Token cost: always paid upfront

**Inline in Agent Definition (proposed for 11 unconditional references):**
- Content lives in agents/scout.md directly
- Pre-loaded in agent's context (agents/X.md is the system prompt)
- Agent sees it immediately, no Read tool needed
- Token cost: always paid upfront (same as hook injection)

**Breadcrumb (agent reads on-demand):**
- agents/scout.md says: "Read references/scout-suitability-gate.md"
- Agent must use Read tool to load content
- Agent could skip reading it
- Token cost: paid when agent reads, plus latency of Read tool call
- Risk: agent might not follow breadcrumb

### Why Breadcrumbs Fail for Always-Needed Content

| Approach | Pre-loaded? | Agent choice? | Latency | Risk |
|----------|-------------|---------------|---------|------|
| Hook inject | Yes | No | None | None |
| Inline | Yes | No | None | None |
| Breadcrumb | No | Yes | +1 Read call | Agent might skip |

For always-needed content, breadcrumbs add latency and risk with no benefit. This rules out breadcrumbs for any content that agents must have, leaving the choice between hook injection and inlining.

### Why Inline Wins for Always-Needed, Agent-Specific Content

Since hook injection and inlining have identical token costs for always-needed content, the tiebreaker is simplicity and transparency:

- **Inline:** One file to read, one place to edit, visible in agent definition
- **Hook injection:** Two files to read, indirection through hook logic, requires logging to verify

Hook injection only wins when it provides a functional benefit (DRY for shared content, conditional logic for context economy). For agent-specific, always-needed content, those benefits don't apply.

---

## General Decision Framework: Inline vs Inject vs Breadcrumb

This framework applies to any system with orchestrators launching subprocesses.

### Step 1: Is the content always needed by this subprocess type?

- **YES** -- Continue to Step 2
- **NO** -- Either conditional injection OR breadcrumb (see Step 3)

### Step 2: Is the content shared across multiple subprocess types?

- **YES, same file used by multiple types** -- **Hook inject** (DRY benefit)
- **YES, similar but distinct content per type** -- **Inline** (not actually shared; DRY doesn't apply)
- **NO** -- **Inline** (simplicity benefit)

Step 2 deserves emphasis: "similar" is not "shared." If each subprocess type has its own version of a concept (e.g., each agent type has its own completion-report format), that's agent-specific content that happens to follow a pattern. Inlining is correct. Only inject when the exact same file is loaded by multiple subprocess types.

### Step 3: Conditional content decision

- **Dynamic data** (e.g., "error from prior attempt") -- **Hook inject** (runtime generation)
- **Static data, specific trigger** (e.g., "program mode guidance") -- **Hook inject conditionally** (context economy)
- **Optional guidance** (e.g., "advanced patterns guide") -- **Breadcrumb** (subprocess discretion)

### Step 4: Measure sharing ratio

Calculate: `truly_shared_refs / total_refs`

- **>50% shared** -- Hook infrastructure justified broadly
- **25-50% shared** -- Hybrid approach (inline specific, inject shared)
- **<25% shared** -- Inline almost everything, hooks only for conditional/dynamic

**This audit:** 0 shared / 14 total = 0%. All always-needed content should be inlined. Hooks justified for the 3 conditional references and for future dynamic context injection (see Future Work in Recommendation).

### Decision Matrix

| Content Type | Shared? | Always Needed? | Approach | Justification |
|--------------|---------|----------------|----------|---------------|
| Subprocess-specific procedure | No | Yes | Inline | Simplicity, transparency |
| Shared protocol compliance | Yes (same file) | Yes | Hook inject | DRY |
| Similar-but-distinct formats | No (separate files) | Yes | Inline | Not actually shared |
| Conditional (dynamic) | N/A | No | Hook inject | Runtime generation |
| Conditional (static) | N/A | No | Hook inject | Context economy |
| Optional guidance | No | No | Breadcrumb | Subprocess discretion |

### Anti-Patterns

**Inject Everything:** Hook complexity for subprocess-specific content that doesn't need it. Fix: only inject shared or conditional content.

**Breadcrumb Always-Needed Content:** Adds latency, risk of subprocess skipping. Fix: inline or inject (pre-load) always-needed content.

**Inline Shared Content:** Duplication across subprocess definitions. Fix: inject truly shared content (same file, multiple subprocess types).

**Confuse "Similar" with "Shared":** Building injection infrastructure for files that look alike but are actually separate per subprocess type. Fix: check whether the same file path is referenced by multiple subprocess types. If not, it's not shared.

**Build Hook Infrastructure for <25% Sharing:** Hook complexity not justified by DRY benefit. Fix: inline nearly everything, use hooks only for conditional loading.

---

## Recommendation: Inline + Script + Remove Frontmatter (Option A)

### How We Got Here

We built hook injection as the wrong solution for a real problem. The problem was real: breadcrumbs are non-deterministic (agents can ignore "read references/X.md"). For protocol-critical content like suitability gates and completion report formats, that's unacceptable. Content must be guaranteed in the agent's context.

We jumped from "must guarantee delivery" to "must use hooks." But there was a simpler path to guaranteed delivery: **inline the content in the agent definition.** The agent definition IS the agent's system prompt -- content there is always loaded, always present, zero infrastructure needed.

So we built a sophisticated injection system to solve a problem that inlining solves trivially. That's the wrong solution.

But in building it, we created infrastructure for a harder problem we hadn't yet addressed: **delivering dynamic, situational context that varies per launch.** Retry errors from prior attempts, prior wave results, cross-repo boundaries, integration gap details -- these can't be inlined because they don't exist until runtime. Hook injection is exactly the right delivery mechanism for this content.

**The pattern found its true use case through misapplication.**

One final realization: the declarative YAML (`agent-references:` in saw-skill.md frontmatter) that drove injection was itself an unnecessary abstraction. It provided a declarative interface over what amounts to 3 conditional `if/cat` statements after inlining. And the highest-value future use case -- dynamic context injection -- requires script logic that YAML can't express. The `inject-agent-context` script already exists as the vendor-neutral fallback. It should become the primary mechanism: the hook calls the script, the script contains the logic, the YAML goes away.

### Classification

**Inline (agent-specific, always-needed) -- 11 references:**
- scout-suitability-gate.md --> agents/scout.md
- scout-implementation-process.md --> agents/scout.md
- planner-suitability-gate.md --> agents/planner.md
- planner-implementation-process.md --> agents/planner.md
- planner-example-manifest.md --> agents/planner.md
- wave-agent-worktree-isolation.md --> agents/wave-agent.md
- wave-agent-completion-report.md --> agents/wave-agent.md
- critic-agent-verification-checks.md --> agents/critic-agent.md
- critic-agent-completion-format.md --> agents/critic-agent.md
- integration-connectors-reference.md --> agents/integration-agent.md
- integration-agent-completion-report.md --> agents/integration-agent.md

(Note: scout-architectural-discovery.md was listed in earlier drafts but does not exist. Omitted.)

**Inject conditionally -- 3 references:**
- scout-program-contracts.md (only if --program; already conditional in frontmatter)
- wave-agent-build-diagnosis.md (only if baseline failed; needs `when` clause added)
- wave-agent-program-contracts.md (only if frozen contracts; already conditional in frontmatter)

**Result:**
- Hook handles 3 references (down from 14), all conditional
- Agent definitions grow from ~1-2KB to ~5-9KB each (agent-specific content inlined)
- Hook logic becomes trivial: only conditional injection, no unconditional paths
- Token cost: identical to current (content moved, not removed)

### Implementation Plan

**Step 1: Inline Always-Needed Content (2-3 hours)**
1. For each of the 11 always-needed references:
   a. Append content to the corresponding agents/*.md file as a clearly labeled section
   b. Test: launch each agent type, verify prompts contain the inlined content
2. Keep reference files temporarily (delete after full verification)

**Step 2: Refactor inject-agent-context Script (1-2 hours)**
1. Replace YAML parsing (~30 lines of awk) with direct logic:
   ```bash
   case "$AGENT_TYPE" in
     scout)
       [[ "$PROMPT" =~ --program ]] && cat "$SKILL_DIR/references/scout-program-contracts.md"
       ;;
     wave-agent)
       [[ "$PROMPT" =~ baseline_verification_failed ]] && cat "$SKILL_DIR/references/wave-agent-build-diagnosis.md"
       [[ "$PROMPT" =~ frozen_contracts ]] && cat "$SKILL_DIR/references/wave-agent-program-contracts.md"
       ;;
   esac
   ```
2. Update `validate_agent_launch` hook to call script without reading frontmatter
3. Test: verify conditional injection still works with and without triggers

**Step 3: Remove agent-references Frontmatter (30 minutes)**
1. Delete `agent-references:` block from saw-skill.md (lines 26-59)
2. Update comments in saw-skill.md body that reference the frontmatter block
3. Update scripts/README.md to document the new script-driven approach
4. Test: verify hook + script still work without frontmatter

**Step 4: Add Logging (1 hour)**
1. Script emits JSON line per injection to `.saw-state/hook-logs/agent-launches.jsonl`
2. Include: timestamp, agent_type, agent_id, injected files, total_bytes
3. Add optional `SAW_HOOK_DEBUG=1` for stdout emission

**Total: 4-6 hours**

**Note:** The `triggers:` frontmatter block (lines 17-21) is unaffected. It serves a different purpose (orchestrator-level context injection for `/saw program` and `/saw amend` subcommands) and its declarative approach is appropriate for that use case.

### Future Work: Dynamic Context Injection

The hook infrastructure, freed from static file delivery, should be repurposed for dynamic context that varies per launch. These are high-value injection opportunities we are not exploiting today.

**1. Retry Context (HIGH VALUE)**

When an agent is relaunched after failure (attempt > 1), the hook can inject structured context about the prior failure.

Condition: `.saw-state/journals/wave{N}/agent-{ID}/attempt-{N-1}.json` exists
Content: Prior attempt's error classification, what files were committed before failure, suggested fix approach from `sawtools build-retry-context`

Currently, retry context is either manually assembled by the orchestrator or missing entirely. Hook injection standardizes it: every retried agent automatically receives structured failure context without orchestrator prompt engineering.

**2. Prior Wave Summaries (HIGH VALUE)**

Wave 2+ agents launch blind -- they know their brief but not what the prior wave actually produced. The hook can bridge this gap.

Condition: Wave number > 1 (parsed from SAW tag in agent description)
Content: Prior wave completion summaries (which agents committed, which files changed, post-merge build status, any interface deviations from contracts)

Source: `.saw-state/wave-{N-1}-summary.json` written by `finalize-wave`

This directly addresses a real friction point: Wave 2 agents sometimes make assumptions about Wave 1's output that don't match reality (e.g., assuming a type was added to a specific file when Wave 1 put it elsewhere).

**3. Cross-Repo Coordination Context (HIGH VALUE)**

When an IMPL spans multiple repos, agents need explicit awareness of repo boundaries.

Condition: IMPL `file_ownership` contains 2+ distinct `repo:` values
Content: Repo map (which files are in which repo), per-repo build commands, dependency ordering between repos, agent's working repo clearly identified

Currently the orchestrator handles this manually in the prompt. Hook injection standardizes it and prevents the common failure where cross-repo agents try to build in the wrong repo.

**4. Integration Gap Details (MEDIUM VALUE)**

Integration agents receive generic instructions but not the specific gaps they need to wire.

Condition: Agent type is `integration-agent`
Content: Unconnected exports from E25/E26 scan, call-site locations, wiring patterns

Source: `.saw-state/integration-report.json` written by `finalize-wave`

This is truly dynamic content -- different every time, generated by post-merge analysis.

**5. Complexity-Adaptive Guidance (LOWER VALUE)**

Simple features (1 agent, 1 file) don't need the same coordination guidance as complex ones (5+ agents, cross-repo). The hook could inject additional coordination warnings for complex IMPLs.

Condition: IMPL has 5+ agents or 3+ waves or spans 2+ repos
Content: Additional coordination warnings, pre-mortem risk patterns, interface contract emphasis

Lower priority because this optimizes for a less common case and the value is harder to measure.

### Why Not Status Quo (Option B: Keep YAML + Inject Everything)

**Approach:** Keep `agent-references:` frontmatter, keep injecting all 14 references, add logging.

**In its favor:**
- Works today, no migration risk
- Declarative config is self-documenting

**Against:**
- 11 of 14 entries provide no functional benefit over inlining
- Two places to look (agents/scout.md + references/) when one would suffice
- YAML parsing adds ~30 lines of awk for 3 effective entries
- Dynamic injection (the highest-value use case) can't be expressed in YAML, requiring a second mechanism
- "Progressive disclosure" label is misleading when 80% of content is always loaded

**Verdict:** Functional but over-engineered. Maintaining a declarative abstraction for 3 conditional entries while also needing script logic for dynamic injection means two mechanisms where one suffices.

### Why Not Inline Everything + Remove Hooks (Option C)

**Approach:** Move all 14 references into agent prompts, remove hook and script entirely.

**Against:**
- Loses conditional loading for the 3 references that benefit from it
- Wastes ~2KB per agent launch when conditional content isn't needed
- Removes the hook interception mechanism entirely, making future dynamic context injection impossible without rebuilding it
- The hook's highest-value use case (dynamic injection of retry context, prior wave summaries, cross-repo coordination) hasn't been built yet -- removing the mechanism now forecloses the most valuable path

**Verdict:** Overshoots. The hook interception point has value for conditional and dynamic content. Keep the hook and script; remove the YAML abstraction layer.

---

## Agent-Type-Specific Considerations

### Analysis Agents (Scout, Planner)

**Characteristics:**
- Long-lived (60-120 seconds execution)
- Complex procedural guidance (suitability assessment, tier construction, dependency analysis)
- Agent-specific procedures (Scout suitability assessment differs from Planner suitability assessment)
- Large prompts after inlining (5-9KB)

**Recommendation: Inline all always-needed content.**
- Procedures are always needed and agent-specific
- Long execution time means prompt size isn't the critical path
- One place to look for all Scout/Planner behavior

**What to inline:**
- Scout: suitability-gate, implementation-process
- Planner: suitability-gate, implementation-process, example-manifest

**What stays in hook (conditional):**
- Scout: program-contracts (only if --program)

### Implementation Agents (Wave, Integration)

**Characteristics:**
- Short-lived (30-90 seconds execution)
- Protocol compliance requirements (worktree isolation, completion report format)
- Smaller prompts after inlining (3-5KB)

**Recommendation: Inline all always-needed content.**

Earlier analysis classified wave-agent-completion-report and wave-agent-worktree-isolation as "shared" and recommended keeping them in hooks. This was incorrect: each agent type has its own distinct completion-report file (wave uses `sawtools set-completion`, integration uses `sawtools set-completion` with different conventions, critic uses `sawtools set-critic-review`). These are agent-specific files, not shared resources. Inline them.

**What to inline:**
- Wave: worktree-isolation, completion-report
- Integration: connectors-reference, completion-report

**What stays in hook (conditional):**
- Wave: build-diagnosis (only if baseline failed), program-contracts (only if frozen contracts)

### Verification Agents (Critic)

**Characteristics:**
- Medium-lived (45-75 seconds execution)
- Verification checks are agent-specific (E37 criteria)
- Completion format is agent-specific (uses `set-critic-review`, distinct from wave/integration)

**Recommendation: Inline everything.**
- Both references are agent-specific and always-needed
- No conditional content for critic agents currently

**What to inline:**
- verification-checks, completion-format

---

## Pattern Summary by Agent Type

| Agent Type | Inline | Inject (conditional) | Inject (dynamic, future) |
|------------|--------|---------------------|--------------------------|
| Scout | suitability-gate, implementation-process | program-contracts | (none currently) |
| Planner | suitability-gate, implementation-process, example-manifest | (none) | (none currently) |
| Wave | worktree-isolation, completion-report | build-diagnosis, program-contracts | retry context, prior wave summaries, cross-repo context |
| Integration | connectors-reference, completion-report | (none) | integration gap details |
| Critic | verification-checks, completion-format | (none) | (none currently) |
| Scaffold | (no references currently) | (none) | (none currently) |

---

## Conditional Injection Logic

After removing the `agent-references:` frontmatter, all conditional logic lives in the `inject-agent-context` script.

### Conditional References (3 total)

**Scout:**
- `scout-program-contracts.md`: Inject when prompt matches `--program`. Script checks: `[[ "$PROMPT" =~ --program ]]`

**Wave Agent:**
- `wave-agent-program-contracts.md`: Inject when prompt matches `frozen_contracts`. Script checks: `[[ "$PROMPT" =~ frozen_contracts ]]`
- `wave-agent-build-diagnosis.md`: Inject when baseline verification failed. Script checks: `[[ "$PROMPT" =~ baseline_verification_failed ]]`

### Signal Design

All three conditionals use **prompt-based signals**: the orchestrator includes a keyword in the agent's prompt when the condition applies. The script matches against it with a regex. This is simple, requires no file I/O, and keeps the injection script stateless.

For the future dynamic injection features, the script will use **state file signals** instead:
- Retry context: check if `.saw-state/journals/wave{N}/agent-{ID}/attempt-*.json` exists
- Prior wave summaries: check if `.saw-state/wave-{N-1}-summary.json` exists
- Cross-repo context: parse IMPL doc for multiple `repo:` values in file_ownership
- Integration gaps: read `.saw-state/integration-report.json`

These require file I/O but the script is the natural place for that logic -- it has access to the state directory and can call sawtools commands for structured output.

---

## Risks & Mitigations

### Risk 1: Agent Definitions Become Unwieldy

**Risk:** Inlining 11 references makes agent definition files large (5-9KB). Harder to navigate, edit, review.

**Mitigation:**
- Use clear section headers (## Suitability Assessment, ## Completion Report, etc.)
- Agent definitions are still smaller than many system prompts in production
- The tradeoff is transparency vs file size -- transparency wins for debugging

### Risk 2: Conditional Logic Misses Edge Cases

**Risk:** Conditional injection fails to trigger, agent lacks needed context.

**Mitigation:**
- Logging: record injection decisions in `.saw-state/hook-logs/`
- Agent self-reporting: completion reports can flag missing context
- Gradual rollout: start with build-diagnosis (lowest risk), measure, then evaluate
- Fallback: if conditional logic is unreliable, revert to always-inject for that reference

### Risk 3: Future Shared Content Needs Re-Architecture

**Risk:** A future reference genuinely needs to be shared across agent types, but hook infrastructure has been simplified.

**Mitigation:**
- Hook infrastructure still exists (for the 3 conditional references)
- Adding a new shared unconditional reference to the hook is trivial
- The framework in this document provides clear criteria for when to inject vs inline
- If sharing ratio exceeds 25%, revisit the hybrid approach

---

## Pattern-Level Lessons (Generalizable)

### Lesson 1: Verify Sharing Before Building Shared Infrastructure

Building injection infrastructure assumes content will be shared. Measure first. In this audit, what appeared to be 4 shared references turned out to be 0 -- similar-sounding files with distinct, agent-specific content.

**Red flag:** References named `<type>-completion-report.md` across multiple agent types look shared but aren't if they contain different commands, formats, or semantics.

**Practice:** Before building shared delivery infrastructure, verify that the same file (not just the same concept) is consumed by multiple subprocess types.

### Lesson 2: Context Boundaries Differ from Code Boundaries

Orchestrator and subprocesses are separate runtime contexts. Files visible to the orchestrator (saw-skill.md, CLAUDE.md) are invisible to subprocesses unless explicitly passed.

**Implication:** When deciding where content lives, think about which process needs it. Content that lives in the orchestrator's context can't be "seen" by subprocesses via code proximity alone -- it must be delivered (inline, injected, or breadcrumbed).

**Practice:** Document information flow across process boundaries. Make it explicit which process has access to which content.

### Lesson 3: "Progressive Disclosure" Requires Actual Conditionality

Progressive disclosure means loading content only when needed. If content is always loaded, it's not progressive disclosure -- it's file splitting. Both are valid, but they solve different problems and have different costs.

**Practice:** When labeling a system "progressive disclosure," verify that content loading is actually conditional. If >75% of content is always loaded, the system is primarily doing file organization, and simpler approaches (inline with sections) may be appropriate.

### Lesson 4: Simplicity as Default, Complexity When Justified

Hook injection is more complex than inlining. Complexity is justified when it provides functional benefits (DRY, conditional loading, runtime generation). When complexity provides only organizational benefits, the bar should be higher -- organizational benefits can often be achieved with simpler means (section headers, comments, code structure).

**Practice:** Start with the simplest delivery mechanism (inline). Add complexity (hooks) only when a functional requirement demands it. If the only argument for hooks is "cleaner file organization," consider whether the indirection cost is worth it.

### Lesson 5: Observability From the Start

Hook injection makes content flow opaque. You can't tell what a subprocess received without logging.

**Practice:** When building infrastructure that hides behavior (hooks, middleware, interceptors), add observability mechanisms at build time, not as an afterthought. Structured logs (JSONL), debug modes, and queryable audit trails make invisible systems debuggable.

### Lesson 6: Wrong Solutions Can Reveal Right Problems

We built hook injection to solve breadcrumb non-determinism for always-needed content. Inlining would have solved it more simply. But the hook infrastructure we built is exactly what's needed for a harder problem: dynamic context injection.

Static files don't need hooks -- they can be inlined. Dynamic context (retry errors from prior attempts, prior wave completion summaries, cross-repo coordination maps, integration gap details) can't be inlined because it doesn't exist until runtime. This is where hooks earn their complexity cost.

**Practice:** When you discover that infrastructure was built for the wrong reason, don't just dismantle it. Ask: "Is there a harder problem this infrastructure is actually well-suited for?" The investment may not be wasted -- it may just be misallocated. Repurposing existing infrastructure for its natural use case is often cheaper than building new infrastructure from scratch.

**Corollary:** This is why audits are valuable even when the initial concern turns out to be overstated. The process of analyzing "why did we build this?" often reveals "what should we build next?" We found the hook pattern's true purpose by questioning its current use.

### Lesson 7: Declarative Config Earns Its Keep at Scale

Declarative configuration (YAML, JSON schemas, DSLs) provides value when: many entries follow a uniform structure, non-technical users need to edit them, or tooling can validate/lint the config. With 3 entries maintained by the same engineers who write the scripts, declarative adds parsing complexity without benefit.

In this audit, the `agent-references:` YAML block required ~30 lines of awk to parse, plus a separate abstraction layer between the hook and the actual injection logic. The equivalent script logic is ~10 lines of bash. And the highest-value future use case (dynamic injection) requires imperative logic that YAML can't express, meaning we'd need both mechanisms.

**Practice:** Before building declarative config, ask: (1) How many entries? If <10, consider hardcoding. (2) Who edits them? If the same engineers who maintain the system, declarative adds indirection without accessibility benefit. (3) Will future requirements need imperative logic? If yes, you'll end up maintaining two mechanisms. Start with the script; add declarative config when the entry count or user base justifies it.

---

## Appendix: Reference File Inventory

| Reference | Agent | Current | Proposed | Rationale |
|-----------|-------|---------|----------|-----------|
| scout-suitability-gate.md | Scout | Always inject | **Inline** | Agent-specific, always needed |
| scout-implementation-process.md | Scout | Always inject | **Inline** | Agent-specific, always needed |
| scout-program-contracts.md | Scout | Conditional (`when: "--program"`) | **Keep conditional** | Already correct |
| wave-agent-worktree-isolation.md | Wave | Always inject | **Inline** | Agent-specific, always needed |
| wave-agent-completion-report.md | Wave | Always inject | **Inline** | Agent-specific (distinct format from critic/integration) |
| wave-agent-build-diagnosis.md | Wave | Always inject | **Make conditional** | Only needed on baseline failure |
| wave-agent-program-contracts.md | Wave | Conditional (`when: "frozen_contracts_hash\|frozen: true"`) | **Keep conditional** | Already correct |
| critic-agent-verification-checks.md | Critic | Always inject | **Inline** | Agent-specific (E37 criteria), always needed |
| critic-agent-completion-format.md | Critic | Always inject | **Inline** | Agent-specific (uses set-critic-review, not shared) |
| planner-suitability-gate.md | Planner | Always inject | **Inline** | Agent-specific, always needed |
| planner-implementation-process.md | Planner | Always inject | **Inline** | Agent-specific, always needed |
| planner-example-manifest.md | Planner | Always inject | **Inline** | Agent-specific reference, always needed |
| integration-connectors-reference.md | Integration | Always inject | **Inline** | Agent-specific (E26 data), always needed |
| integration-agent-completion-report.md | Integration | Always inject | **Inline** | Agent-specific (distinct format from wave/critic) |

**Distribution:**
- **Inline (agent-specific, always-needed):** 11 references
- **Keep conditional (already correct):** 2 references
- **Make conditional (currently always-injected):** 1 reference

**Token impact:**
- Current: 14 references injected via hook (~28KB across all agent types)
- After: 3 references injected via hook (~6KB conditional), 11 inlined in agent definitions
- Net token cost for always-needed content: identical (content moves from injection to inline, not removed)
- Net token savings from conditional logic: ~2KB per wave agent when baseline passes, ~2KB per scout without --program

**Operational benefit:**
- `agent-references:` YAML block removed from frontmatter (20 lines of config + 30 lines of awk parsing eliminated)
- Injection logic consolidated into `inject-agent-context` script (~10 lines of bash for 3 conditionals)
- Agent definitions become self-contained for always-needed behavior
- Debugging simplified: if an agent lacks context, check its definition file first
- Hook interception mechanism preserved; script handles both conditional static and future dynamic injection
- One mechanism instead of two (no YAML-for-static + script-for-dynamic split)

---

## Implementation Impact Analysis

*Generated 2026-03-29. Exhaustive file-by-file assessment of every change required to implement the three audit recommendations.*

### Category 1: Agent Definitions (files that GROW via inlining)

These files receive inlined content from reference files. The "Reference Files" breadcrumb section in each agent definition gets replaced with the actual content.

#### 1. `implementations/claude-code/prompts/agents/scout.md`
- **Current size:** 208 lines
- **Inlined content:** `scout-suitability-gate.md` (123 lines) + `scout-implementation-process.md` (464 lines)
- **Estimated new size:** ~780 lines
- **What changes:** Replace the "Reference Files" section (lines 139-158, the breadcrumb instructions that say "read these files yourself") with the actual content of both reference files. Remove the `<!-- injected: references/scout-X.md -->` dedup check instructions. Keep the mention of `scout-program-contracts.md` as a conditional reference ("Only required when `--program` flag is present") but change the delivery description from "injected by hook" to "injected by `inject-agent-context` script".
- **Why:** Audit recommendation 1 (inline always-needed content)
- **Effort:** medium (large content merge, must verify section ordering)
- **Dependencies:** None (can be done first)

#### 2. `implementations/claude-code/prompts/agents/wave-agent.md`
- **Current size:** 151 lines
- **Inlined content:** `wave-agent-worktree-isolation.md` (93 lines) + `wave-agent-completion-report.md` (94 lines)
- **Estimated new size:** ~320 lines
- **What changes:** Replace the "Reference Files" section (lines 18-39, breadcrumb instructions) with actual content of both reference files. Keep mentions of `wave-agent-build-diagnosis.md` and `wave-agent-program-contracts.md` as conditional references with updated delivery description.
- **Why:** Audit recommendation 1
- **Effort:** medium
- **Dependencies:** None

#### 3. `implementations/claude-code/prompts/agents/critic-agent.md`
- **Current size:** 90 lines
- **Inlined content:** `critic-agent-verification-checks.md` (84 lines) + `critic-agent-completion-format.md` (54 lines)
- **Estimated new size:** ~210 lines
- **What changes:** Replace the "Reference Files" section (lines 53-69, breadcrumb instructions) with actual content of both files.
- **Why:** Audit recommendation 1
- **Effort:** small
- **Dependencies:** None

#### 4. `implementations/claude-code/prompts/agents/planner.md`
- **Current size:** 143 lines
- **Inlined content:** `planner-suitability-gate.md` (50 lines) + `planner-implementation-process.md` (223 lines) + `planner-example-manifest.md` (159 lines)
- **Estimated new size:** ~555 lines
- **What changes:** Replace the "Reference Files" section (lines 39-58, breadcrumb instructions) with actual content of all three files.
- **Why:** Audit recommendation 1
- **Effort:** medium (largest inlining by line count)
- **Dependencies:** None

#### 5. `implementations/claude-code/prompts/agents/integration-agent.md`
- **Current size:** 133 lines
- **Inlined content:** `integration-connectors-reference.md` (88 lines) + `integration-agent-completion-report.md` (30 lines)
- **Estimated new size:** ~233 lines
- **What changes:** Replace the "Reference Files" section (lines 25-43, breadcrumb instructions) with actual content of both files.
- **Why:** Audit recommendation 1
- **Effort:** small
- **Dependencies:** None

### Category 2: Reference Files (files that get DELETED or STAY)

#### Files to DELETE after inlining (11 files):

These files become dead code once their content is inlined into agent definitions. Delete after verifying the inlined agent definitions work correctly.

6. `implementations/claude-code/prompts/references/scout-suitability-gate.md` (123 lines) -- DELETE
7. `implementations/claude-code/prompts/references/scout-implementation-process.md` (464 lines) -- DELETE
8. `implementations/claude-code/prompts/references/planner-suitability-gate.md` (50 lines) -- DELETE
9. `implementations/claude-code/prompts/references/planner-implementation-process.md` (223 lines) -- DELETE
10. `implementations/claude-code/prompts/references/planner-example-manifest.md` (159 lines) -- DELETE
11. `implementations/claude-code/prompts/references/wave-agent-worktree-isolation.md` (93 lines) -- DELETE
12. `implementations/claude-code/prompts/references/wave-agent-completion-report.md` (94 lines) -- DELETE
13. `implementations/claude-code/prompts/references/critic-agent-verification-checks.md` (84 lines) -- DELETE
14. `implementations/claude-code/prompts/references/critic-agent-completion-format.md` (54 lines) -- DELETE
15. `implementations/claude-code/prompts/references/integration-connectors-reference.md` (88 lines) -- DELETE
16. `implementations/claude-code/prompts/references/integration-agent-completion-report.md` (30 lines) -- DELETE

- **Why:** Audit recommendation 1 (content moved into agent definitions)
- **Effort:** trivial (git rm)
- **Dependencies:** Must complete agent definition inlining first. Must update install.sh symlink logic and README reference tables first.

#### Files that STAY (conditional injection, 3 files):

17. `implementations/claude-code/prompts/references/scout-program-contracts.md` (21 lines) -- NO CHANGE
18. `implementations/claude-code/prompts/references/wave-agent-build-diagnosis.md` (36 lines) -- MODIFY (update line 1 comment from "Loaded by validate_agent_launch hook" to "Loaded conditionally by inject-agent-context script")
19. `implementations/claude-code/prompts/references/wave-agent-program-contracts.md` (16 lines) -- MODIFY (update line 1 comment similarly)

- **Why:** These remain as conditional injection targets per audit recommendation
- **Effort:** trivial
- **Dependencies:** None

#### Files that STAY (orchestrator references, unaffected, 7 files):

20. `implementations/claude-code/prompts/references/program-flow.md` -- NO CHANGE
21. `implementations/claude-code/prompts/references/amend-flow.md` -- NO CHANGE
22. `implementations/claude-code/prompts/references/failure-routing.md` -- NO CHANGE
23. `implementations/claude-code/prompts/references/impl-targeting.md` -- NO CHANGE
24. `implementations/claude-code/prompts/references/model-selection.md` -- NO CHANGE
25. `implementations/claude-code/prompts/references/pre-wave-validation.md` -- NO CHANGE
26. `implementations/claude-code/prompts/references/wave-agent-contracts.md` -- NO CHANGE

### Category 3: Skill Frontmatter (saw-skill.md)

#### 27. `implementations/claude-code/prompts/saw-skill.md`
- **Current size:** 185 lines
- **What changes:**
  - **DELETE lines 26-59:** The entire `agent-references:` YAML block from frontmatter (34 lines). This is audit recommendation 2.
  - **UPDATE line 79** (body text, "Supporting Files & References" section): Remove the sentence "Agent references auto-injected by `validate_agent_launch` hook (see frontmatter)." Replace with: "Agent references: always-needed content inlined in agent definitions; conditional references injected by `scripts/inject-agent-context`." Also update the vendor-neutral fallback description to match: "Vendor-neutral fallback: orchestrator triggers use `scripts/inject-context "$prompt"`, conditional agent references use `scripts/inject-agent-context --type <agent-type>`."
  - **UPDATE line 128** (scout flow, step 2): The `set-injection-method` call. Content here references hook injection method. Consider whether `injection_method` field semantics need updating now that most content is inlined. The `--method hook` value should still work for the 3 conditional references, but the field's purpose shrinks. No blocking change needed but worth a comment update.
  - The `triggers:` block (lines 17-25) is UNAFFECTED.
- **Why:** Audit recommendation 2 (remove agent-references frontmatter)
- **Effort:** small
- **Dependencies:** Should be done after agent definitions are updated and the inject-agent-context script is refactored.

### Category 4: Scripts (files that get REFACTORED)

#### 28. `implementations/claude-code/prompts/scripts/inject-agent-context`
- **Current size:** 116 lines
- **What changes:** Complete rewrite per audit recommendation 3. Replace the awk-based YAML frontmatter parser (lines 56-83) and the generic entry-matching loop (lines 88-114) with direct conditional logic:
  ```bash
  case "$agent_type" in
    scout)
      if [[ "$prompt" =~ --program ]]; then
        inject_file "references/scout-program-contracts.md"
      fi
      ;;
    wave-agent)
      if [[ "$prompt" =~ baseline_verification_failed ]]; then
        inject_file "references/wave-agent-build-diagnosis.md"
      fi
      if [[ "$prompt" =~ frozen_contracts ]]; then
        inject_file "references/wave-agent-program-contracts.md"
      fi
      ;;
  esac
  ```
  The script no longer reads `saw-skill.md` frontmatter. It no longer references `SKILL.md` or `SKILL_FILE`. The `--type` and `--prompt` arguments remain. The dedup marker logic stays. The script becomes ~40-50 lines.
- **Why:** Audit recommendation 3 (script contains conditional logic directly)
- **Effort:** medium (functional rewrite, must test all 3 conditional paths)
- **Dependencies:** Must happen after agent-references block is removed from saw-skill.md (otherwise the old script and new script would conflict).

#### 29. `implementations/claude-code/prompts/scripts/inject-context`
- **NO CHANGE.** This script handles orchestrator-level `triggers:` injection, which is unaffected by the audit. It still reads `triggers:` from frontmatter (which remains).

#### 30. `implementations/claude-code/prompts/scripts/README.md`
- **Current size:** 408 lines
- **What changes:** Major update needed.
  - **Section "inject-agent-context"** (lines 67-138): Rewrite to document new script-driven approach. Remove all references to `agent-references:` frontmatter parsing. Remove the "Configuration (saw-skill.md frontmatter)" block showing agent-references YAML. Replace with documentation of the case/if logic. Update usage examples.
  - **Section "Architecture Overview"** (lines 140-163): Update to reflect that hooks no longer read agent-references from frontmatter. The hook calls the script; the script contains conditional logic directly.
  - **Section "Maintenance > Adding new reference files"** (lines 310-320): Rewrite. Currently says "Add entry to saw-skill.md frontmatter... No script changes needed." After the change, it should say: "For always-needed references, inline in agent definition. For conditional references, add a case branch in inject-agent-context."
  - **Section "Debugging frontmatter parsing"** (lines 348-388): Remove the awk debugging block for agent-references. Keep the triggers awk debugging block (triggers still use frontmatter).
  - **Section "Cross-References"** (lines 392-408): Update references that mention frontmatter agent-references.
- **Why:** Documentation must match implementation
- **Effort:** medium (substantial rewrite of one section)
- **Dependencies:** Do after script refactor.

### Category 5: Hooks (files that get SIMPLIFIED)

#### 31. `implementations/claude-code/hooks/validate_agent_launch`
- **Current size:** 471 lines
- **What changes:** Major simplification. Remove all unconditional injection blocks:
  - **DELETE Scout injection block** (lines 55-134): The always-inject logic for `scout-suitability-gate.md` and `scout-implementation-process.md`. Replace with a call to `inject-agent-context` script for the conditional `scout-program-contracts.md` only.
  - **DELETE Critic injection block** (lines 136-173, "Check 11"): Both critic references are always-needed and now inlined. Entire block removed.
  - **DELETE Planner injection block** (lines 175-218, "Check 12"): All three planner references are always-needed and now inlined. Entire block removed.
  - **DELETE Integration injection block** (lines 220-257, "Check 13"): Both integration references are always-needed and now inlined. Entire block removed.
  - **SIMPLIFY Wave agent injection block** (lines 407-467, "Check 10"): Remove always-inject logic for `wave-agent-worktree-isolation.md`, `wave-agent-completion-report.md`, `wave-agent-build-diagnosis.md`. Keep only the conditional `wave-agent-program-contracts.md` injection.
  - **ALTERNATIVE:** Instead of keeping per-agent-type conditional logic in the hook, the hook could delegate ALL injection to the `inject-agent-context` script. The hook would call `inject-agent-context --type "$subagent_type" --prompt "$prompt"` and use its output as the `updatedInput` injection content. This is cleaner (one place for injection logic) but adds a subprocess call.
  - **Keep** the scout description auto-fix logic (lines 68-83) -- this is enforcement, not injection.
  - **Keep** Checks 1-8 (lines 259-405) -- these are enforcement checks, unrelated to injection.
  - **Estimated new size:** ~250 lines (enforcement checks + thin injection delegation)
- **Why:** Audit recommendations 1 and 3 (inlined content no longer needs injection; remaining injection delegated to script)
- **Effort:** medium-large (largest single file change, must not break enforcement checks)
- **Dependencies:** Must be done AFTER agent definitions are inlined AND inject-agent-context is refactored.

#### 32. `implementations/claude-code/hooks/inject_skill_context`
- **NO CHANGE.** Handles orchestrator `triggers:` injection, which is unaffected.

### Category 6: Hook Documentation

#### 33. `implementations/claude-code/hooks/README.md`
- **Current size:** ~916 lines
- **What changes:**
  - **"Injection hooks" table** (lines 25-31): Update description for `validate_agent_launch` from "Injects agent type reference files into subagent prompt" to "Injects conditional agent references into subagent prompt (3 conditional files; always-needed content inlined in agent definitions)"
  - **"Injection Patterns" section** (lines 38-72): Update "Layer 2: Subagent injection" description. Remove mention of reading agent-references from frontmatter. Describe the new flow: hook detects agent type, calls inject-agent-context script for conditional injection, script contains case/if logic.
  - **"The two-layer picture"** (lines 74-90): Update the diagram text. Remove "Matches: subagent_type in {wave-agent, critic-agent, scout, planner, integration-agent}" for unconditional injection. Show only conditional injection for scout (--program) and wave-agent (frozen contracts, baseline failure).
  - **"Hook 9" section** (lines 534-567): Major rewrite. Update Checks 9-13 descriptions:
    - Check 9 (Scout): Remove "Always injects suitability-gate and implementation-process". Keep "Conditionally injects program-contracts when --program present."
    - Check 10 (Wave): Remove "Always injects worktree-isolation, completion-report, build-diagnosis". Keep "Conditionally injects program-contracts when frozen contracts present." Add "Conditionally injects build-diagnosis when baseline failed."
    - Check 11 (Critic): Remove entirely or note "No injection -- all content inlined in critic-agent.md."
    - Check 12 (Planner): Remove entirely or note "No injection -- all content inlined in planner.md."
    - Check 13 (Integration): Remove entirely or note "No injection -- all content inlined in integration-agent.md."
  - **"Checks 9+: Agent Type Injection" table** (lines 557-564): Update to show only conditional references.
- **Why:** Documentation must match implementation
- **Effort:** medium
- **Dependencies:** Do after hook refactor.

### Category 7: Prompts README

#### 34. `implementations/claude-code/prompts/README.md`
- **Current size:** 116 lines
- **What changes:**
  - **Directory structure** (lines 8-37): Update `references/` listing. Remove "(hook-injected)" annotations from the 11 deleted references. Keep them for the 3 remaining conditional references. Add "(inlined in agent definition)" annotations or remove the deleted files from the listing entirely.
  - **Agent Type Definitions table** (lines 53-59): Update descriptions. Currently says "Slim identity core (~166 lines)" for scout, "Slim identity core (~133 lines)" for wave-agent, etc. These descriptions are now wrong -- agent files grow significantly. Update line counts and remove "Slim identity core" language. Replace with accurate sizes: "Self-contained agent definition (~780 lines)" etc.
  - **"Agent References (hook-injected)" table** (lines 88-105): Remove the 11 entries for deleted reference files. Keep only the 3 conditional entries. Rename section header from "Agent References (hook-injected)" to "Agent References (conditionally injected)".
- **Why:** Documentation must match implementation
- **Effort:** small
- **Dependencies:** Do after reference files deleted.

### Category 8: Installation Scripts

#### 35. `install.sh` (root)
- **Current size:** 511 lines
- **What changes:**
  - The `install_skill_files` function (lines 57-100) uses a wildcard `for src in "${PROMPTS_DIR}"/references/*.md; do` to symlink all reference files. After deleting 11 reference files, this loop automatically handles fewer files. No code change needed -- the wildcard adapts.
  - The verification function (lines 126-171) counts reference symlinks. The count will decrease from 21 to 10 (7 orchestrator + 3 conditional agent). The `REF_COUNT` variable is computed dynamically. No code change needed.
  - The summary output at line 89 says "Reference files: ${REF_COUNT} files" and at line 152 "Install on-demand reference files (progressive disclosure)" -- both are fine as-is.
  - **Verdict: NO CODE CHANGE NEEDED.** The wildcard-based symlink approach is already correct. The file count changes automatically when files are deleted.
- **Why:** N/A
- **Effort:** none
- **Dependencies:** N/A

#### 36. `implementations/claude-code/hooks/install.sh`
- **NO CHANGE.** This is a 6-line delegation script that calls the root `install.sh`.

### Category 9: Architecture and Design Documentation

#### 37. `docs/skills-progressive-disclosure.md`
- **Current size:** 801 lines
- **What changes:** This is the most documentation-heavy change. The entire document is organized around the `agent-references:` frontmatter pattern.
  - **Executive Summary** (lines 1-18): Update item 1 from "`agent-references:` (subagents) in YAML frontmatter declare when X, inject Y rules" to describe the new script-driven approach. Update item 3 accordingly.
  - **Example flow** (lines 20-51): Update the agent-references portion. Currently shows `validate_agent_launch reads saw-skill.md frontmatter agent-references:`. Replace with: "validate_agent_launch calls inject-agent-context script for conditional references only; always-needed content already inlined in agent definitions."
  - **The Four Tiers > Tier 1** (lines 130-195): Remove the `agent-references:` YAML example block (lines 158-189). Update description of what Tier 1 frontmatter contains: only `triggers:` dispatch table, not `agent-references:`.
  - **"The Advanced Pattern" section** (lines 228-278): Rewrite the "Agent References" subsection (lines 253-278). Remove the `agent-references:` YAML example. Describe the new pattern: always-needed content inlined, conditional injection via script.
  - **"Three-Layer Injection"** section (around lines 130-148 based on grep): Update Layer 1 description. The hook no longer reads agent-references from frontmatter for most agents. Only conditional injection remains.
  - **Throughout:** Replace references to "frontmatter-driven" agent injection with "script-driven conditional injection." Keep "frontmatter-driven" for orchestrator triggers (those are unchanged).
  - **Add a note** explaining the simplification: "As of v0.X.0, always-needed agent references are inlined directly in agent definitions. The `agent-references:` frontmatter block has been removed. Conditional injection (3 references) is handled by the `inject-agent-context` script."
- **Why:** This is the primary architecture document for the injection system
- **Effort:** large (the document's central thesis changes)
- **Dependencies:** Do last, after all implementation changes are complete.

#### 38. `POSITION.md`
- **Current size:** ~500+ lines
- **What changes:**
  - **Line 84:** Currently reads "Tier 1 (frontmatter metadata, ~60 lines) -- parsed by the Skills API before context construction; includes `triggers:` and `agent-references:` declarations." Remove `and agent-references:` -- only `triggers:` remains in frontmatter.
  - **Lines 105-129:** The `agent-references:` YAML block example and surrounding description. Remove or replace with description of the new approach.
  - **Line 127:** "validate_agent_launch hook (Check 10) reads the agent-references: block" -- update to describe script-based conditional injection.
  - **Line 138:** "scripts/inject-agent-context" reference -- update description of what it does.
  - **Line 147:** "All three layers read from the same triggers: and agent-references: frontmatter source" -- remove agent-references part.
  - **Line 204:** "install.sh script... Adding a new reference requires: (2) add an entry to triggers: or agent-references: frontmatter" -- update to remove agent-references.
  - **Line 333:** Description of validate_agent_launch mentions "agent type reference injection" and "reads agent-references" -- update.
- **Why:** POSITION.md describes the architecture to external audiences
- **Effort:** medium (scattered changes throughout a large file)
- **Dependencies:** Do after implementation changes.

### Category 10: Configuration Files

#### 39. `saw.config.json`
- **NO CHANGE.** Does not reference agent-references or injection.

#### 40. `config/saw.config.json`
- **NO CHANGE.** Model selection config, unrelated.

### Category 11: Other Documentation

#### 41. `implementations/claude-code/README.md`
- **Current size:** ~417 lines
- **What changes:**
  - **Line 54:** scout.md description says "Slim identity core (~166 lines). Suitability gate, IMPL production steps, and program contract rules extracted to references/scout-*.md and injected by validate_agent_launch hook." Update to reflect inlining: "Self-contained agent definition (~780 lines). Suitability gate and implementation process inlined. Program contracts conditionally injected."
  - **Lines 55, 57-59:** Similar updates for wave-agent.md, critic-agent.md, planner.md descriptions.
  - **Lines 140-154 ("Install on-demand reference files"):** Update the description and file counts. Currently says "This symlinks all 21 reference files" with two bullet lists. Update to reflect: 10 reference files remain (7 orchestrator + 3 conditional agent). Remove the 11 deleted files from the "Agent references" bullet.
- **Why:** Installation documentation must match reality
- **Effort:** small
- **Dependencies:** Do after reference files deleted.

#### 42. `implementations/claude-code/QUICKSTART.md`
- **NO CHANGE expected** (grep shows no matches for agent-references or inject-agent-context). Verify manually.

#### 43. `docs/INSTALLATION.md`
- **NO CHANGE.** Grep confirmed no references to agent-references or inject-agent-context.

#### 44. `docs/CONTEXT.md`
- **NO CHANGE.** Grep confirmed no references.

#### 45. `ROADMAP.md`
- **NO CHANGE.** Grep confirmed no references.

#### 46. `CHANGELOG.md`
- **NO CHANGE to existing content.** Add a new entry when the changes are committed, documenting the simplification.

#### 47. `docs/PROGRAM/PROGRAM-agent-type-progressive-disclosure.yaml`
- **REVIEW.** This PROGRAM manifest may reference the injection architecture. If it contains references to `agent-references:` frontmatter, update. Grep showed it matches "progressive disclosure" but not "agent-references" specifically. Likely NO CHANGE needed.

#### 48. `docs/IMPL/IMPL-agentskills-progressive-disclosure.yaml`
- **REVIEW.** This is an active IMPL doc that may describe the injection architecture as it was being built. Since it is documentation of past work (not active configuration), likely NO CHANGE needed. However, if it has agents that reference the `agent-references:` frontmatter pattern, add a note that the pattern was simplified.

### Category 12: Protocol Documentation

#### 49. `protocol/execution-rules.md`
- **Grep showed matches for `updatedInput` and `injection_method`.** The execution rules reference injection_method (E44) and the hook mechanism. Review whether E44's description of injection_method needs updating. The `injection_method` field in IMPL docs still makes sense (hook vs manual-fallback) but its scope narrows from 14 references to 3 conditional ones. **Likely NO CHANGE** to the protocol rules themselves -- the protocol describes the mechanism generically, not the specific reference file list.

#### 50. `protocol/procedures.md`
- **Grep showed match for "frontmatter".** Review the specific mention. Likely describes the general frontmatter extension mechanism, not the specific `agent-references:` block. **Likely NO CHANGE.**

### Category 13: Files Confirmed NO CHANGE

The following files were examined and confirmed to need no changes:

- `implementations/claude-code/prompts/agents/scaffold-agent.md` -- No references currently, unaffected
- `implementations/claude-code/prompts/agent-template.md` -- Wave agent brief template, unaffected
- `implementations/claude-code/prompts/saw-bootstrap.md` -- Bootstrap procedure, unaffected
- `implementations/claude-code/hooks/inject_skill_context` -- Orchestrator triggers, unaffected
- `implementations/claude-code/hooks/inject_worktree_env` -- E43 env vars, unaffected
- `implementations/claude-code/hooks/inject_bash_cd` -- E43 cd injection, unaffected
- `implementations/claude-code/hooks/validate_write_paths` -- E43 write validation, unaffected
- `implementations/claude-code/hooks/check_scout_boundaries` -- I6 enforcement, unaffected
- `implementations/claude-code/hooks/check_wave_ownership` -- I1 enforcement, unaffected
- `implementations/claude-code/hooks/check_git_ownership` -- I1 enforcement, unaffected
- `implementations/claude-code/hooks/validate_impl_on_write` -- E16 enforcement, unaffected
- `implementations/claude-code/hooks/validate_agent_completion` -- E42 enforcement, unaffected
- `implementations/claude-code/hooks/verify_worktree_compliance` -- E42/I5, unaffected
- `implementations/claude-code/hooks/emit_agent_completion` -- E40 observability, unaffected
- `implementations/claude-code/hooks/warn_stubs` -- H3 stub detection, unaffected
- `implementations/claude-code/hooks/check_branch_drift` -- H4 drift detection, unaffected
- `implementations/claude-code/hooks/block_claire_paths` -- .claire blocker, unaffected
- `implementations/claude-code/prompts/scripts/inject-context` -- Orchestrator triggers, unaffected
- `saw.config.json` -- Config, unaffected
- `config/saw.config.json` -- Config, unaffected
- `docs/INSTALLATION.md` -- No references found
- `docs/CONTEXT.md` -- No references found
- `ROADMAP.md` -- No references found
- `protocol/invariants.md` -- No references found
- `protocol/execution-rules.md` -- Generic mechanism descriptions, no specific agent-references mentions
- All 7 orchestrator reference files in `references/` -- Unaffected
- All files in `docs/proposals/` -- Historical design docs, no changes needed
- All files in `docs/IMPL/complete/` -- Completed IMPL docs, historical records

---

### Execution Order (Dependency-Aware)

**Phase 1: Inline content (can be done in parallel across agents)**
1. Inline into `agents/scout.md` (from scout-suitability-gate.md + scout-implementation-process.md)
2. Inline into `agents/wave-agent.md` (from wave-agent-worktree-isolation.md + wave-agent-completion-report.md)
3. Inline into `agents/critic-agent.md` (from critic-agent-verification-checks.md + critic-agent-completion-format.md)
4. Inline into `agents/planner.md` (from planner-suitability-gate.md + planner-implementation-process.md + planner-example-manifest.md)
5. Inline into `agents/integration-agent.md` (from integration-connectors-reference.md + integration-agent-completion-report.md)

**Phase 2: Remove frontmatter + refactor script (sequential)**
6. Remove `agent-references:` block from `saw-skill.md`
7. Refactor `inject-agent-context` script to use direct conditional logic
8. Update comment headers in remaining conditional reference files

**Phase 3: Simplify hook (depends on phases 1-2)**
9. Refactor `validate_agent_launch` to remove all unconditional injection blocks
10. Test all agent types launch correctly with inlined content

**Phase 4: Delete inlined reference files (depends on phase 3 verification)**
11. Delete 11 reference files that were inlined

**Phase 5: Update documentation (depends on all above)**
12. Update `implementations/claude-code/prompts/README.md`
13. Update `implementations/claude-code/README.md`
14. Update `implementations/claude-code/hooks/README.md`
15. Update `implementations/claude-code/prompts/scripts/README.md`
16. Update `docs/skills-progressive-disclosure.md`
17. Update `POSITION.md`
18. Update `saw-skill.md` body text (Supporting Files section)

---

### Complete File Manifest

| # | File | Change Type | Effort | Phase |
|---|------|-------------|--------|-------|
| 1 | `implementations/claude-code/prompts/agents/scout.md` | MODIFY (grow +587 lines) | medium | 1 |
| 2 | `implementations/claude-code/prompts/agents/wave-agent.md` | MODIFY (grow +169 lines) | medium | 1 |
| 3 | `implementations/claude-code/prompts/agents/critic-agent.md` | MODIFY (grow +120 lines) | small | 1 |
| 4 | `implementations/claude-code/prompts/agents/planner.md` | MODIFY (grow +412 lines) | medium | 1 |
| 5 | `implementations/claude-code/prompts/agents/integration-agent.md` | MODIFY (grow +100 lines) | small | 1 |
| 6-16 | `references/` (11 always-needed files) | DELETE | trivial | 4 |
| 17 | `references/scout-program-contracts.md` | NO CHANGE | - | - |
| 18 | `references/wave-agent-build-diagnosis.md` | MODIFY (comment) | trivial | 2 |
| 19 | `references/wave-agent-program-contracts.md` | MODIFY (comment) | trivial | 2 |
| 20-26 | `references/` (7 orchestrator files) | NO CHANGE | - | - |
| 27 | `implementations/claude-code/prompts/saw-skill.md` | MODIFY (delete 34 lines + update body) | small | 2 |
| 28 | `implementations/claude-code/prompts/scripts/inject-agent-context` | REWRITE (~116 -> ~50 lines) | medium | 2 |
| 29 | `implementations/claude-code/prompts/scripts/inject-context` | NO CHANGE | - | - |
| 30 | `implementations/claude-code/prompts/scripts/README.md` | MODIFY (major section rewrite) | medium | 5 |
| 31 | `implementations/claude-code/hooks/validate_agent_launch` | MODIFY (delete ~220 lines) | medium-large | 3 |
| 32 | `implementations/claude-code/hooks/inject_skill_context` | NO CHANGE | - | - |
| 33 | `implementations/claude-code/hooks/README.md` | MODIFY (update injection docs) | medium | 5 |
| 34 | `implementations/claude-code/prompts/README.md` | MODIFY (update tables) | small | 5 |
| 35 | `install.sh` | NO CHANGE (wildcards adapt) | - | - |
| 36 | `implementations/claude-code/hooks/install.sh` | NO CHANGE | - | - |
| 37 | `docs/skills-progressive-disclosure.md` | MODIFY (major rewrite) | large | 5 |
| 38 | `POSITION.md` | MODIFY (scattered updates) | medium | 5 |
| 39-40 | Config files | NO CHANGE | - | - |
| 41 | `implementations/claude-code/README.md` | MODIFY (update descriptions) | small | 5 |

**Totals:**
- Files modified: 16
- Files deleted: 11
- Files unchanged: 30+
- Estimated total effort: 6-8 hours (accounts for testing between phases)
