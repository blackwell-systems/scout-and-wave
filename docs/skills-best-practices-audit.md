# SAW Skills Best Practices Audit

**Date:** 2026-03-11
**Auditor:** Claire (Claude Sonnet 4.5)
**Scope:** Scout, Wave Agent, Scaffold Agent, and main SAW orchestrator skill

## Executive Summary

Scout-and-Wave skills are **well-structured and comprehensive** but have significant opportunities to improve conciseness, progressive disclosure, and model-appropriate guidance. The skills contain ~1500 lines of dense procedural content that loads into context on every invocation, creating token waste and cognitive load. Key findings: (1) excessive verbosity in sections Claude already understands, (2) flat structure missing progressive disclosure patterns, (3) minimal model-specific guidance despite cross-model usage, (4) strong adherence to interface contracts and workflow patterns but room for template improvements.

**Priority:** Medium-high. Current skills work effectively, but optimization would reduce token costs 30-40% and improve agent success rates across model tiers.

---

## Best Practices Review

Claude's agent skills documentation emphasizes:

### Core Principles
1. **Concise is key** - Challenge every explanation with "Does Claude really need this?" The context window is a shared resource.
2. **Set appropriate degrees of freedom** - Match specificity to task fragility (high freedom for analysis, low for error-prone operations)
3. **Test with all models** - Haiku needs more guidance, Opus tolerates less, Sonnet is balanced
4. **Progressive disclosure** - Keep SKILL.md under 500 lines; link to detailed files that load on-demand

### Structure Patterns
1. **Third-person descriptions** - Never "I can help" or "You can use"
2. **Specific, discoverable descriptions** - Include both what and when to use
3. **One level deep references** - Avoid nested file references; all links from SKILL.md
4. **Table of contents in long files** - For 100+ line reference files

### Content Guidance
1. **Workflow patterns with checklists** - For multi-step tasks, provide copy-paste progress trackers
2. **Template patterns** - Provide exact formats for structured outputs
3. **Conditional workflows** - Guide through decision points clearly
4. **Avoid time-sensitive info** - Use "old patterns" sections instead
5. **Consistent terminology** - Pick one term and use it everywhere

### Advanced Patterns (for executable code)
1. **Solve, don't punt** - Handle errors explicitly in scripts; don't leave it to Claude
2. **Utility scripts over generation** - Pre-made scripts are more reliable
3. **Verifiable intermediate outputs** - Plan-validate-execute pattern for complex tasks
4. **Visual analysis** - Use Claude's vision when applicable
5. **MCP tool references** - Always use fully qualified `ServerName:tool_name` format

---

## Current SAW Implementation

### What We're Doing Well

**Strong workflow structure:**
- Clear step-by-step procedures (Scout's 0-14 steps, Wave's 9-field format)
- Explicit state transitions (suitability gate, verification gates, completion reports)
- Comprehensive error handling branches (E7, E7a, E8 failure modes)

**Interface contract discipline:**
- Strong I1/I2 invariants enforcement (disjoint ownership, binding contracts)
- Pre-flight validation (E16, E20, E21, E22)
- Clear separation of concerns (I6: role separation)

**Good use of executable tooling:**
- `sawtools` CLI handles all deterministic operations
- Scripts don't punt to agents (validation, merge, conflict detection)
- Clear command documentation with exact syntax

**Effective cross-referencing:**
- Invariant/execution rule numbering (I1-I6, E1-E23) for audit trail
- Typed-block syntax for structured sections
- Links to protocol documentation files

### What We're Missing

**Progressive disclosure:**
- All skills are monolithic (scout.md: 706 lines, wave-agent.md: 182 lines, SKILL.md: 285 lines)
- No separate reference files for: suitability gate criteria, verification gate patterns, failure remediation procedures
- Context loaded all at once instead of on-demand

**Model-specific guidance:**
- No Haiku/Sonnet/Opus differentiation despite `--model` flag support
- Same prompts for 3.5 Haiku (needs more detail) and Opus (tolerates less)
- Missing "test with all models" validation

**Conciseness issues:**
- Verbose explanations of concepts Claude already knows (git worktrees, dependency graphs, YAML syntax)
- Repeated procedural instructions across multiple skills
- Over-explanation of "why" in sections meant for "what"

---

## Gaps and Recommendations

### High Priority

#### 1. Progressive Disclosure Refactor (scout.md)

**Gap:** Scout skill is 706 lines, all loaded into context on every invocation. Step 4 (pre-implementation status check) alone is ~60 lines of guidance Claude may not need if the feature is greenfield.

**Recommendation:**
- Keep scout.md under 300 lines as the main procedure
- Extract to separate files:
  - `scout-suitability-gate.md` - Full 5-question breakdown with examples (load when verdict is NOT_SUITABLE)
  - `scout-dep-analysis.md` - Manual dependency tracing procedures (load when `analyze-deps` tool fails)
  - `scout-verification-gates.md` - Language-specific test command patterns (load when writing agent prompts)
  - `scout-pre-implementation-check.md` - DONE/PARTIAL/TODO classification logic (load when processing audit reports)

**Link pattern in scout.md:**
```markdown
## Suitability Gate

Answer these five questions (see [scout-suitability-gate.md](scout-suitability-gate.md) for full criteria):
1. File decomposition - can work split to ≥2 agents with disjoint ownership?
2. Investigation-first items - any unknown root causes?
3. Interface discoverability - can contracts be defined upfront?
4. Pre-implementation status - what's already done?
5. Parallelization value - does SAW save time?

Emit verdict: SUITABLE | NOT_SUITABLE | SUITABLE_WITH_CAVEATS
```

**Impact:** ~400 line reduction in main scout.md, 30-40% token savings per Scout invocation.

---

#### 2. Model-Specific Guidance Layers

**Gap:** Skills use identical prompts for Haiku (fast, needs guidance) vs Opus (powerful, over-explaining wastes tokens). The `--model` flag exists but doesn't adjust prompt detail level.

**Recommendation:**
Add model detection logic to orchestrator and conditional prompt sections:

**In SKILL.md (orchestrator):**
```markdown
## Agent Model Selection

When launching agents, detect the model tier and adjust prompt detail:
- **Haiku**: Include full verification gate commands, explicit error handling steps
- **Sonnet**: Balanced - include key commands, assume standard knowledge
- **Opus**: Minimal - assume Claude knows git, YAML, testing patterns

Read model from: (1) --model flag, (2) saw.config.json, (3) parent session
```

**In scout.md:**
```markdown
## Suitability Gate

<model-tier=haiku>
Answer each question explicitly. For question 1, count the files that will change by reading each one. For question 2, check if any task description includes words like "investigate", "debug", "find root cause"...
</model-tier>

<model-tier=sonnet>
Answer these five questions. Use your judgment on edge cases.
</model-tier>

<model-tier=opus>
Run the suitability gate. You know the drill.
</model-tier>
```

**Implementation:** Use frontmatter or inline tags that orchestrator can strip based on detected model before passing to Agent tool.

**Impact:** 20-30% token reduction for Opus agents, improved Haiku success rates (fewer ambiguity-related failures).

---

#### 3. Template Pattern for YAML Output

**Gap:** Scout prompt includes a 150-line YAML schema example with extensive comments. This is reference material, not procedural instructions. It's loaded on every Scout invocation even though the schema rarely changes.

**Recommendation:**
Extract YAML schema to `scout-yaml-schema.md` and provide minimal template in main prompt:

**In scout.md:**
```markdown
## Output Format

Write to `docs/IMPL/IMPL-<slug>.yaml`. Use this structure (see [scout-yaml-schema.md](scout-yaml-schema.md) for full schema):

```yaml
title: "Feature Name"
feature_slug: "feature-slug"
verdict: "SUITABLE"
state: "SCOUT_PENDING"

# Suitability Assessment (comment format)
quality_gates: { level, gates[] }
scaffolds: []
interface_contracts: []
file_ownership: []
waves: []
pre_mortem: { overall_risk, rows[] }
```

All fields expecting arrays use `[]` or `- item` syntax. All structs use nested key-value pairs.
```

**Impact:** 100+ line reduction, clearer separation between "what to write" (main prompt) and "exact format reference" (schema doc).

---

#### 4. Workflow Checklist Pattern (Wave Agent)

**Gap:** Wave agent prompt lists 9 fields (0-8) but doesn't provide a progress tracker. Agents working through complex implementations can lose track of what's complete, especially after context compaction.

**Recommendation:**
Add copy-paste checklist at the top of wave-agent.md:

```markdown
## Your Task

Copy this checklist and track your progress:

```
Wave Agent Progress:
- [ ] Field 0: Verify isolation (git branch --show-current)
- [ ] Field 1: Confirm file ownership (only modify owned files)
- [ ] Field 2: Implement required interfaces
- [ ] Field 3: Call scaffold/upstream interfaces correctly
- [ ] Field 4: Complete implementation (tests + logic)
- [ ] Field 5: Write all required tests
- [ ] Field 6: Run verification gate (build/test/lint)
- [ ] Field 7: Respect constraints (no out-of-scope work)
- [ ] Field 8: Write completion report (sawtools set-completion)
```

**Per best practices:** "For particularly complex workflows, provide a checklist that Claude can copy into its response and check off as it progresses."

**Impact:** Reduced field omissions, clearer recovery after session context compaction (journal helps but checklist is immediate visual reference).

---

### Medium Priority

#### 5. Conditional Workflow Pattern for Failure Handling

**Gap:** E7/E7a/E8 failure handling is described procedurally in long paragraphs. The orchestrator must parse "if any agent reports status: partial or status: blocked, the wave does not merge..." from dense text.

**Recommendation:**
Use decision-tree format:

**In SKILL.md:**
```markdown
## After Wave Agents Complete

1. Read completion reports from IMPL doc (not chat output - I4)

2. Check agent statuses:

   **All agents `status: complete`?** → Proceed to merge (step 6)

   **Any agent `status: partial` or `status: blocked`?** → Branch by failure_type:

   - `failure_type: transient` → Retry agent (up to 2 attempts), then escalate
   - `failure_type: fixable` → Read notes, apply fix, relaunch agent
   - `failure_type: needs_replan` → Re-engage Scout with agent's report
   - `failure_type: escalate` → Surface to human immediately
   - `failure_type: timeout` → Agent committed partial work; human decision required

3. Wave remains BLOCKED until all agents reach `status: complete`
```

**Impact:** Clearer orchestrator decision-making, easier to audit failure handling, reduced ambiguity in --auto mode.

---

#### 6. Reference File for Verification Gate Patterns

**Gap:** Steps 10-11 in scout.md contain 50+ lines of language-specific build/test/lint command tables. This is reference material that should be in a separate file.

**Recommendation:**
Extract to `scout-verification-gates.md`:

```markdown
# Verification Gate Reference

## Build Commands by Language

| Language | Build | Test | Lint (check mode) |
|----------|-------|------|-------------------|
| Go       | `go build ./...` | `go test ./...` | `go vet ./...` |
| Rust     | `cargo build` | `cargo test` | `cargo clippy -- -D warnings` |
| Node     | `tsc --noEmit` | `npm test` | `npx eslint .` |
| Python   | `python -m mypy .` | `pytest` | `ruff check .` |

## Focused Test Commands (for agent gates)

Use focused tests during waves, full suite at post-merge:

| Language | Focused (agent) | Full (post-merge) |
|----------|----------------|-------------------|
| Go       | `go test ./pkg -run TestFoo` | `go test ./...` |
| Rust     | `cargo test test_foo` | `cargo test` |
...
```

**In scout.md main prompt:**
```markdown
## Step 10: Verification Gates

Read build system (Makefile, CI config). Extract exact commands from project.

For language-specific patterns, see [scout-verification-gates.md](scout-verification-gates.md).

Record `test_command` and `lint_command` in IMPL doc header.
```

**Impact:** 50-line reduction in main prompt, easier to maintain language support matrix.

---

#### 7. Consistent Terminology Audit

**Gap:** Mixed usage of terms across skills creates ambiguity:
- "IMPL doc" vs "manifest" vs "coordination artifact" (all mean the same thing)
- "Wave agent" vs "implementation agent" vs "agent"
- "Scaffolds section" vs "Scaffolds table" vs "scaffold file list"

**Recommendation:**
Pick canonical terms and use consistently:

| Concept | Canonical Term | Avoid |
|---------|---------------|-------|
| YAML file in docs/IMPL/ | IMPL doc | manifest, coordination artifact |
| Agent executing in Wave 1/2/3 | Wave agent | implementation agent |
| Scaffolds section of IMPL doc | Scaffolds section | scaffolds table, scaffold list |
| sawtools CLI | sawtools | Protocol SDK CLI, SDK commands |
| Main orchestrator (this skill) | Orchestrator | main agent, parent agent |

**Impact:** Reduced cognitive load, clearer when agents reference the same concept, easier onboarding.

---

#### 8. Avoid Nested References (Scaffold Agent)

**Gap:** scaffold-agent.md references "E22 in protocol/execution-rules.md" which then references build verification procedures. This is two levels deep from the agent's main prompt.

**Recommendation:**
Inline critical E22 content directly in scaffold-agent.md, link to protocol doc only for full specification:

```markdown
## Step 3: Build Verification (E22)

After creating scaffold files, run three passes:

**Pass 1 - Dependency resolution:**
- Go: `go get ./... && go mod tidy`
- Python: `pip install -e .` or `uv sync`
...

**Pass 2 - Scaffold package only:**
- Go: `go build ./internal/types/`
...

**Pass 3 - Full project build:**
- Go: `go build ./...`
...

If any pass fails, mark scaffold Status: FAILED in IMPL doc and stop.

For full protocol specification, see [protocol/execution-rules.md#E22](../../protocol/execution-rules.md).
```

**Best practice:** "Keep references one level deep from SKILL.md. All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed."

**Impact:** Ensures scaffold agent sees full build verification procedure without nested file reads.

---

### Low Priority

#### 9. Old Patterns Section for Deprecated Features

**Gap:** Skills reference "YAML manifests" as the current format but don't document that Markdown IMPL docs existed previously. Future maintainers may be confused by references to `.md` IMPL files in git history.

**Recommendation:**
Add collapsed section in scout.md:

```markdown
<details>
<summary>Old patterns - Markdown IMPL docs (deprecated 2026-03-09)</summary>

Before v0.6.0, IMPL docs used Markdown format with typed fence blocks. YAML format is now standard. If you encounter `IMPL-*.md` files in git history, they used this structure:

```markdown
# IMPL: feature-slug

## Suitability Assessment
...
```

All new IMPL docs use `.yaml` format.
</details>
```

**Best practice:** "Don't include information that will become outdated... use 'old patterns' section."

**Impact:** Minimal, but improves long-term maintainability and reduces confusion.

---

#### 10. Visual Overview Diagrams

**Gap:** Skills are text-heavy with no visual aids. The wave execution flow, file ownership table, and dependency graph concepts would benefit from diagrams.

**Recommendation:**
Add ASCII art or mermaid diagrams to key sections. Example for wave execution in SKILL.md:

```markdown
## Wave Execution Flow

```
Scout → Scaffolds → Wave 1 (agents A,B,C in parallel) → Merge → Verify
                        ↓
                   Wave 2 (agents D,E depend on A,B) → Merge → Verify
                        ↓
                   Wave 3 (agent F depends on D) → Merge → Complete
```

Each wave merges atomically after all agents complete.
```

Or for dependency graph in scout.md:

```markdown
## Dependency Graph Structure

```
fileA.go (Wave 1) ──depends on──> scaffolds/types.go (pre-wave)
    ↓
    provides interface to
    ↓
fileB.go (Wave 2) ──depends on──> fileA.go
```

**Impact:** Faster comprehension for complex protocol concepts, especially helpful for Haiku.

---

## Implementation Roadmap

### Phase 1: Quick Wins (Week 1)
1. **Consistent terminology audit** (#7) - Search/replace across all skills
2. **Add wave agent checklist** (#4) - 10-line addition to wave-agent.md
3. **Conditional workflow for failures** (#5) - Restructure existing E7/E8 content

**Estimated effort:** 2-3 hours
**Impact:** Immediate clarity improvements, easier debugging

### Phase 2: Progressive Disclosure (Week 2)
4. **Extract scout reference files** (#1) - Create 4 new .md files, slim scout.md to 300 lines
5. **Extract verification gates reference** (#6) - Create scout-verification-gates.md
6. **Extract YAML schema reference** (#3) - Create scout-yaml-schema.md

**Estimated effort:** 4-6 hours
**Impact:** 30-40% token reduction per scout invocation, faster agent launches

### Phase 3: Model-Specific Optimization (Week 3)
7. **Model-specific guidance layers** (#2) - Add tier detection + conditional prompts
8. **Test with Haiku/Sonnet/Opus** - Run 5-10 sample features on each model, measure success rates

**Estimated effort:** 6-8 hours
**Impact:** Improved Haiku success rate, reduced Opus token waste

### Phase 4: Polish (Week 4)
9. **Inline E22 in scaffold-agent** (#8) - Flatten nested references
10. **Old patterns sections** (#9) - Document Markdown IMPL deprecation
11. **Visual diagrams** (#10) - Add ASCII art to key workflow sections

**Estimated effort:** 2-3 hours
**Impact:** Long-term maintainability, faster onboarding

---

## Success Metrics

Track these after implementing recommendations:

1. **Token efficiency:**
   - Before: Scout invocation = ~5000 tokens (706-line prompt + context)
   - Target: Scout invocation = ~3000 tokens (300-line prompt + on-demand refs)

2. **Agent success rates by model:**
   - Haiku: Track % of agents reaching `status: complete` without retries
   - Target: 80%+ first-attempt success rate

3. **Time to first tool use:**
   - Measure lag between agent launch and first Read/Write/Bash call
   - Target: <10 seconds (faster prompt parsing)

4. **Human review velocity:**
   - Track time from "Scout complete" notification to "approved, proceed to Wave 1"
   - Target: <5 minutes (clearer, more scannable IMPL docs)

---

## Conclusion

SAW skills are **architecturally sound** with strong workflow discipline and comprehensive error handling. The primary optimization opportunity is **progressive disclosure** - the current monolithic structure loads 1500+ lines of guidance into context on every invocation, much of which Claude already knows or won't need for a given task.

**Top 3 recommendations:**
1. **Progressive disclosure refactor** (scout.md: 706 → 300 lines via reference files)
2. **Model-specific guidance layers** (Haiku gets more detail, Opus gets less)
3. **Workflow checklist pattern** (visual progress tracker for wave agents)

These changes would reduce token consumption 30-40%, improve cross-model success rates, and make the skills easier to maintain as the protocol evolves.
