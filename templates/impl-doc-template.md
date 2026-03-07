<!-- impl-doc-template v1.0.0 -->
# IMPL: {Feature Name}

**Feature:** {One-sentence feature description}

**Repository:** {repo-root}

**Plan Reference:** {path/to/plan.md} ({word-count} words, {line-count} lines)

---

## Suitability Assessment

**Verdict:** SUITABLE | UNSUITABLE | DEFERRED

**test_command:** {test-command} | none (no executable code)

**lint_command:** {lint-command} | none (no linting applicable)

**Estimated times:**
- Scout phase: ~{N} min ({what scout does})
- Wave 1 execution: ~{N} min ({M} agents in parallel - {what they do})
- Wave 2 execution: ~{N} min ({M} agents in parallel - {what they do})
- Wave N execution: ~{N} min ({M} agents in parallel - {what they do})
- Merge & verification: ~{N} min ({what gets verified})
- Total (SAW): ~{N} min
- Sequential baseline: ~{N} min ({M} agents × {N} min avg sequential time)
- Time savings: ~{N} min ({P}% faster)

**Recommendation:** {Proceed | Defer | Reject} - {Justification for verdict. Mention any protocol compliance fixes applied, suitability factors, or blocking concerns.}

---

## Scaffolds

{This section lists type scaffolds, interface definitions, or shared types that the Scout creates before Wave 1 launches. If no scaffolds are needed, write "None required."}

**Scout produces before Wave 1:**

- `{path/to/scaffold-file}` - {description of what scaffold defines}
  ```{language}
  {code snippet showing scaffold structure}
  ```

---

## Wave {N}: {Wave Description}

**Status:** [planning] [ready] [in-progress] [complete] [blocked]

**Agents:** {M} agents in parallel

**Dependencies:** {Prior wave numbers, or "None (foundation wave)"}

**Goal:** {One-sentence summary of what this wave delivers}

### File Ownership Table

| Agent | Files Owned | Purpose |
|-------|-------------|---------|
| A | `{file-path-1}`, `{file-path-2}` | {what agent A implements} |
| B | `{file-path-3}`, `{file-path-4}` | {what agent B implements} |
| C | `{file-path-5}` | {what agent C implements} |

### Interface Contracts

**Produced by this wave (agents must implement):**

```{language}
{function/type/interface signature}
```
{Description of expected behavior.}

**Consumed by this wave (available from prior waves or scaffolds):**

```{language}
{function/type/interface signature}
```
{Description of behavior agents can rely on.}

### Verification Gate

```bash
cd {repo-root}
{build-command}
{lint-command}
{test-command}
```

All commands must pass (exit code 0) before wave is marked complete.

---

{Insert Agent A prompt here using templates/agent-prompt-template.md}

---

{Insert Agent B prompt here using templates/agent-prompt-template.md}

---

{Insert Agent C prompt here using templates/agent-prompt-template.md}

---

## Wave {N+1}: {Next Wave Description}

{Repeat wave structure for subsequent waves...}

---

## Post-Merge Verification

**After all waves merge to main:**

```bash
cd {repo-root}
{build-command}
{lint-command}
{test-command}
{integration-test-command}  # if applicable
```

**Additional checks:**
- {Check 1}: {description}
- {Check 2}: {description}

---

## Completion Criteria

**Definition of Done:**

- [ ] All waves marked `[complete]`
- [ ] All agent completion reports show `status: complete` and `verification: PASS`
- [ ] Post-merge verification gate passes
- [ ] {Additional feature-specific criteria}

**Out of Scope (explicitly deferred):**

- {Feature X} - {reason for deferring}
- {Optimization Y} - {reason for deferring}

---

## Agent Completion Reports

{Agents append their completion reports here using the YAML format from Field 8 of agent-prompt-template.md. Do not edit this section manually; agents write to it.}

### Agent A - Completion Report

{Agent A writes here}

### Agent B - Completion Report

{Agent B writes here}

### Agent C - Completion Report

{Agent C writes here}

---

## Template Variables Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{Feature Name}` | Title of the feature being implemented | `Protocol Extraction Refactor` |
| `{repo-root}` | Absolute path to repository | `/home/user/project` |
| `{path/to/plan.md}` | Reference to planning document | `docs/PLAN-feature.md` |
| `{word-count}` | Approximate word count of plan | `16,000+` |
| `{line-count}` | Line count of plan | `1886` |
| `{test-command}` | How to run tests | `cargo test`, `npm test`, `go test ./...` |
| `{lint-command}` | How to lint | `cargo clippy`, `eslint`, `golangci-lint run` |
| `{build-command}` | How to build | `cargo build`, `npm run build`, `go build ./...` |
| `{language}` | Programming language | `rust`, `typescript`, `go` |
| `{Wave Description}` | Summary of wave's goal | `Foundation Types`, `Core Implementation` |
| `{M}` | Number of agents | `4`, `3`, `1` |
| `{N}` | Time estimate or wave number | `15`, `2`, `Wave 1` |
| `{P}` | Percentage | `52` |

---

## Notes for IMPL Doc Authors

### When to Create Scaffolds

If multiple agents need to reference a shared type/interface that doesn't exist yet, the Scout should create a scaffold file before Wave 1. This prevents each agent from defining it independently (violates disjoint ownership) or blocking on another agent's work.

**Example:** If Agents A, B, and C all need to work with a `Task` struct, Scout creates `types/task.go` with the struct definition, then Agents A/B/C import and use it.

### Wave Sequencing

Waves must be ordered by dependency:
- **Wave 1** is always foundation work (no dependencies on other parallel agents)
- **Wave 2** can depend on Wave 1's outputs
- **Wave N** can depend on Wave N-1's outputs

Within a wave, agents work in parallel and cannot depend on each other. If Agent B needs Agent A's output, they belong in different waves.

### File Ownership Rules

1. **Disjoint within a wave:** No two agents in the same wave can own the same file
2. **Creation vs. modification:** Specify whether agent creates new file or modifies existing
3. **Test files:** If agent owns `foo.{ext}`, they usually also own `foo_test.{ext}`

### Interface Contract Precision

Be explicit about:
- Function signatures (parameter types, return types, error handling)
- Struct/type definitions (field names, types, visibility)
- Expected behavior (what the function does, not how)
- Error conditions (when to return errors vs. panic)

Vague contracts lead to integration failures at merge time.

### Verification Gate Design

Choose commands that:
- Run quickly (< 2 minutes per agent)
- Cover the agent's changes (not the entire codebase if avoidable)
- Fail fast on integration issues

**Example:** If agent only touches `internal/parser`, run `go test ./internal/parser` instead of `go test ./...` to save time.

### Status Workflow

Wave status progression:
1. `[planning]` — Scout is writing agent prompts
2. `[ready]` — All prompts written, agents can launch
3. `[in-progress]` — At least one agent working
4. `[complete]` — All agents reported complete, verification passed
5. `[blocked]` — Critical issue preventing progress

Update status as wave progresses.
