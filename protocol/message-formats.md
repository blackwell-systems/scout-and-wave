# Scout-and-Wave Message Formats

**Version:** 0.26.0

This document defines the structured data formats exchanged between participants: suitability verdicts, agent prompts, completion reports, and scaffold specifications.

---

## Overview

SAW uses the IMPL doc (Implementation Document) as the single source of truth (I4). All structured messages are written to the IMPL doc, not chat output. The IMPL doc evolves through the protocol lifecycle:

1. **Scout phase:** Scout writes suitability verdict and agent prompts
2. **Scaffold phase:** Scaffold Agent updates Scaffolds section with commit status
3. **Wave execution:** Each agent appends a completion report section

---

## YAML Manifest Structure

**Root-level YAML structure:**

```yaml
title: "Feature Name"           # required
feature_slug: "url-safe-slug"   # required — used in branch names and file paths
feature: "One-line description" # optional — informational
repository: "/absolute/path/to/repo"  # single-repo waves
repositories:  # multi-repo waves (omit if single-repo)
  - "/absolute/path/to/repo1"
  - "/absolute/path/to/repo2"
plan_reference: "path/to/original/plan.md"  # optional

test_command: "go test ./..."  # required
lint_command: "go vet ./..."   # required

state: "SCOUT_PENDING"  # SCOUT_PENDING | SCOUT_VALIDATING | REVIEWED | SCAFFOLD_PENDING
                        # WAVE_PENDING | WAVE_EXECUTING | WAVE_MERGING | WAVE_VERIFIED
                        # BLOCKED | COMPLETE | NOT_SUITABLE

verdict: "SUITABLE"  # required: "SUITABLE" | "NOT_SUITABLE" | "SUITABLE_WITH_CAVEATS"
suitability_assessment: "..."  # optional — prose rationale written by Scout (see Suitability Verdict Format)
suitability_reasoning: "..."   # optional — additional reasoning detail

quality_gates:  # optional - omit if no build toolchain
  level: "quick" | "standard" | "full"
  gates:
    - type: "build"
      command: "go build ./..."
      required: true
      fix: false                     # optional — fix mode for format gates
      timing: "pre-merge"            # optional — "pre-merge" (default) or "post-merge"
    # See Quality Gates section for full schema

scaffolds:  # optional - omit if no scaffold files needed
  - file: "path/to/file"
    contents: "..."
    import_path: "..."
    status: "pending" | "committed" | "FAILED"
    # See Scaffolds section for full schema

wiring:  # optional - E35 wiring obligation declarations
  - symbol: "RegisterHandler"
    defined_in: "pkg/handler/register.go"
    must_be_called_from: "cmd/main.go"
    agent: "A"
    wave: 1
    integration_pattern: "register"  # append | register | inject | call

reactions:  # optional - E19.1 per-IMPL failure reaction overrides
  transient:
    action: retry
    max_attempts: 3
  # See E19.1 in execution-rules.md for full schema

integration_connectors:  # optional - files the integration agent (E26) may modify
  - file: "cmd/main.go"
    reason: "Wire new service into startup"

integration_gap_severity_threshold: "warning"  # optional - minimum severity for E25 gaps

critic_report:  # optional - E37 critic-agent review output (written by critic, not Scout)
  verdict: "PASS" | "ISSUES" | "SKIPPED"
  agent_reviews:
    A:  # Per-agent review keyed by agent ID
      agent_id: "A"
      verdict: "PASS" | "ISSUES"
      issues:  # Present only if verdict is ISSUES
        - check: "file_existence" | "symbol_accuracy" | "interface_validity" | "import_availability" | "pattern_match" | "complexity_balance"
          severity: "error" | "warning"
          description: "Human-readable issue description"
          file: "path/to/file"  # optional - relevant file
          symbol: "functionName"  # optional - relevant symbol
    B:
      agent_id: "B"
      verdict: "PASS"
  summary: "Overall assessment of all agent briefs"
  reviewed_at: "2026-03-28T12:47:30Z"  # ISO8601 timestamp
  issue_count: 2  # Total issues across all agents

waves:  # optional - omit if not using per-agent model overrides or launch ordering
  - number: 1
    type: "standard"                 # optional — "standard" (default) or "integration" (E27)
    agent_launch_order: ["A", "B"]   # optional — explicit ordering within wave
    base_commit: "abc1234"           # recorded when worktrees are created; used for post-merge verification
    agents:
      - id: "A"
        model: "claude-opus-4-5"   # optional — overrides default model for this specific agent
```

---


### Completion Marker

When all waves are merged and post-merge verification passes, the orchestrator writes:

```html
<!-- SAW:COMPLETE YYYY-MM-DD -->
```

**Placement:** At the top of the IMPL doc, immediately after the title.

**E15:** Only the orchestrator writes this marker. Agents never add or modify it. Omit entirely for active IMPL docs.
## Typed Metadata Blocks

Certain sections of the IMPL doc are machine-parsed by the orchestrator and the IMPL doc validator (E16). These sections use fenced code blocks with a `type=impl-*` annotation on the opening fence, whitespace-separated from the language tag. This annotation serves as a precise parser anchor and enables validation errors to reference specific block types rather than line numbers.

**Why typed blocks exist:**
- Parser anchors: orchestrator locates sections by `type=` annotation, not by heading text or line number
- Precise validation: validator errors reference the block type (e.g., "`impl-file-ownership` block: missing Agent column") instead of "line 47"
- Stability: sections can be reordered or have prose added around them without breaking parsers

**Prose sections remain free-form.** The following sections do NOT use typed blocks and are excluded from validator scope: Suitability Assessment, Pre-Mortem, Scaffolds, Interface Contracts, Wave Execution Loop, Stub Report, Status table, and all agent prompt sections.

### Block Types

**`impl-file-ownership` — File Ownership table:**

Single-repo format:
```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/message-formats.md | A | 1 | — |
| protocol/execution-rules.md | B | 1 | — |
| implementations/claude-code/prompts/agents/scout.md | C | 2 | A, B |
```

Cross-repo format (add `Repo` column when agents work in different repositories):
```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On | Repo |
|------|-------|------|------------|------|
| pkg/engine/runner.go | A | 1 | — | saw-engine |
| pkg/engine/types.go | A | 1 | — | saw-engine |
| pkg/api/adapter.go | B | 1 | — | saw-web |
| cmd/saw/main.go | B | 1 | — | saw-web |
```

The `Repo` column value is the short repo name (matches the directory name). E3 ownership verification is performed per-repo: the same file path in different repos is not a conflict.

**`impl-dep-graph` — Dependency Graph:**

```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — foundation spec):
    [A] protocol/message-formats.md
         Defines canonical typed-block syntax and pre-mortem schema.
         ✓ root (no dependencies on other agents)

    [B] protocol/execution-rules.md
         Adds E16: validation + correction loop rule.
         ✓ root (no dependencies on other agents)

Wave 2 (2 parallel agents — consumer files):
    [C] implementations/claude-code/prompts/agents/scout.md
         Updates Scout prompt to use typed blocks. Depends on [A] for syntax spec.
         depends on: [A] [B]
```

**`impl-wave-structure` — Wave Structure diagram:**

```yaml type=impl-wave-structure
Wave 1: [A] [B]                    <- 2 parallel agents (spec foundation)
              | (A+B complete)
Wave 2: [C] [D]                    <- 2 parallel agents (consumer files)
              | (C+D complete)
Wave 3: {E}                        <- type: integration (wiring only, E27)
```

**Notation:** `[brackets]` for standard wave agents, `{braces}` for integration agents (E27).

**Wave `type` field (optional, default: `standard`):**
- `standard` — normal wave agents with worktree isolation (default when omitted)
- `integration` — wiring-only agents dispatched as Integration Agents (E27). No worktree creation, no isolation verification. Agents run on main branch and are constrained to their listed files via `AllowedPathPrefixes`.

**Wave additional fields:**
- `agent_launch_order` — Optional list of agent IDs specifying explicit launch ordering within the wave (e.g. `["A", "B", "C"]`). When omitted, agents are launched in parallel. Use when an agent requires another agent's output before starting, but they are in the same wave.
- `base_commit` — Git commit SHA recorded when worktrees are created. Used by the Orchestrator for post-merge verification to confirm no upstream commits were missed. Set automatically by `sawtools prepare-wave`; do not set manually.

**Agent additional fields:**
- `model` — Optional model override for this specific agent (e.g. `"claude-opus-4-5"`). Overrides the default model configured in the Orchestrator. Use when an agent's task requires a different model capability level than the wave default.

**`impl-completion-report` — Completion Report (written by Wave agents):**

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate | timeout  # required when status is partial or blocked; omit when status is complete
repo: /absolute/path/to/repo  # omit for single-repo waves
worktree: .claude/worktrees/saw/{slug}/wave{N}-agent-{ID}
branch: saw/{slug}/wave{N}-agent-{ID}
commit: {sha}
files_changed:
  - path/to/file
files_created:
  - path/to/file
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL ({command})
```

**`impl-quality-gates` — Quality Gates:**

```yaml type=impl-quality-gates
level: quick | standard | full
gates:
  - type: build | test | lint | custom
    command: {exact shell command}
    required: true | false
    description: {optional human-readable description}
    repo: {optional repo short name}  # if set, gate only runs in the specified repo (multi-repo waves)
    fix: true | false                  # if true, run in fix mode (e.g. gofmt -w); default false
    timing: pre-merge | post-merge    # optional: default is "pre-merge"
```

Gates with `timing: post-merge` execute after MergeAgents completes (step 5 of finalize-wave). This enables content and integration gates that require the merged state. When timing is empty or absent, `pre-merge` is assumed for backward compatibility.

Written by Scout between Suitability Assessment and Scaffolds. Defines verification commands that run after wave completion (E21).

**`impl-post-merge-checklist` — Post-Merge Checklist:**

```yaml type=impl-post-merge-checklist
groups:
  - title: {group name}
    items:
      - description: {verification step}
        command: {optional shell command}
```

Written by Scout between Known Issues and Dependency Graph. Optional orchestrator-facing verification steps that run after all agents merge.

**`impl-known-issues` — Known Issues:**

```yaml type=impl-known-issues
- title: {short title}
  description: {detailed description}
  status: {pre-existing | unrelated | blocking | etc.}
  workaround: {optional workaround or skip instruction}
```

Written by Scout between Pre-Mortem and Dependency Graph. Lists pre-existing issues discovered during suitability assessment. Use `[]` for empty list or omit section entirely.

---

## Suitability Verdict Format

Emitted by the Scout at the end of the suitability gate. Written to the IMPL doc before any agent prompts.

**YAML field vs prose display:** The `verdict:` YAML field uses underscores: `"SUITABLE"`, `"NOT_SUITABLE"`, `"SUITABLE_WITH_CAVEATS"`. The section templates below show the prose content Scout writes into the `suitability_assessment:` field (free-form markdown text) — that prose may use spaces for readability, but the YAML `verdict:` field value must use underscores exactly as shown above.

### SUITABLE Verdict

```markdown
**Verdict:** SUITABLE

{One paragraph rationale explaining why work is suitable for SAW}

**Estimated times:**
- Scout phase: ~X min
- Wave 1 execution: ~Y min (N agents in parallel)
- Wave 2 execution: ~Z min (M agents in parallel)
- Merge & verify: ~W min
- Total (SAW): ~T min
- Sequential baseline: ~B min
- Time savings: ~D min (P% faster | slower)

**Recommendation:** Proceed
```

### SUITABLE WITH CAVEATS Verdict

```markdown
**Verdict:** SUITABLE WITH CAVEATS

{One paragraph rationale}

**Caveats:**
- {Caveat 1: description}
- {Caveat 2: description}

**Estimated times:**
{Same structure as SUITABLE}

**Recommendation:** Proceed with caveats acknowledged
```

### NOT SUITABLE Verdict

```markdown
**Verdict:** NOT SUITABLE

{One paragraph rationale explaining why work is not suitable}

**Failed preconditions:**
- Precondition {N} ({name}): {evidence from codebase}
- Precondition {M} ({name}): {evidence from codebase}

**Suggested alternative:** {sequential execution | investigate-first then re-scout | other: describe}

**Estimated times:**
{Same structure, but highlights that SAW would be slower or riskier than alternative}

**Recommendation:** Do not proceed
```

**Required fields for NOT SUITABLE:**
- `Failed preconditions`: Names each precondition that blocked the verdict by number and name, with specific evidence
- `Suggested alternative`: Makes the verdict actionable rather than a stop sign

**Precondition reference (from [preconditions.md](preconditions.md)):**
1. File decomposition
2. No investigation-first blockers
3. Interface discoverability
4. Pre-implementation scan
5. Positive parallelization value

---

## Agent Prompt Format

9-field structure embedded in the IMPL doc. Field 0 is mandatory pre-flight isolation verification. Fields 1–8 are the implementation specification.

**Full field definitions:** See `prompts/agent-template.md` for the complete template with embedded invariant definitions (I1, I2, I4, I5) and execution rule references (E4, E14).

**Brief field summary:**

| Field | Content | Purpose |
|-------|---------|---------|
| **0. Isolation Verification** | Bash commands to verify worktree, branch, working directory | Defense-in-depth: ensure agent operates in correct worktree before modifying files |
| **1. File Ownership** | Exact files the agent owns | Hard constraint (I1: disjoint ownership) |
| **2. Interfaces to Implement** | Exact signatures the agent must deliver | Contract the agent implements |
| **3. Interfaces to Call** | Exact signatures from prior waves or existing code | Dependencies the agent may import |
| **4. What to Implement** | Functional description (what, not how) | Task definition |
| **5. Tests to Write** | Named tests with one-line descriptions | Verification requirements |
| **6. Verification Gate** | Exact commands (build, lint, test), scoped to owned files/packages | Pre-report checklist |
| **7. Constraints** | Hard rules (error handling, compatibility, things to avoid) | Implementation guardrails |
| **8. Report** | Instructions for writing completion report | Structured output format |

**Field 0 structure (isolation verification):**

```markdown
## 0. CRITICAL: Isolation Verification (RUN FIRST)

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd {absolute-repo-path}/.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="{absolute-repo-path}/.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="saw/{slug}/wave{N}-agent-{ID}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files).
```

**Cross-reference:** Field 0–8 full definitions are in `prompts/agent-template.md` with embedded invariant and execution rule text for self-contained prompts.

---

## Agent ID Format

Agent identifiers follow the `[Letter][Generation]` scheme:

- **Format:** An uppercase letter (A–Z) optionally followed by a single digit 2–9. Regex: `[A-Z][2-9]?`
- **Generation 1:** The bare letter, e.g., `A`, `B`, `C`. The digit is omitted for generation 1. `A` and `A1` are NOT both valid — only `A` represents generation 1.
- **Multi-generation:** `A2`, `B3`, `C4`, etc. Used when >26 agents are needed, or when the Scout wants to express that agents share a logical sub-domain (e.g., `A`, `A2`, `A3` for closely related work).
- **Appears in:** file ownership tables (`Agent` column), dep graph blocks (`[A2]`), wave structure blocks, SAW tags, worktree branch names, and completion report sections.
- **Worktree naming:** `saw/{slug}/wave{N}-agent-{ID}` — e.g., `saw/my-feature/wave1-agent-A2`, `saw/my-feature/wave2-agent-B3`. Branches created before v0.39.0 use the legacy format `wave{N}-agent-{ID}` without slug prefix; tools accept both formats.
- **SAW tag format:** `[SAW:wave{N}:agent-{ID}]` — e.g., `[SAW:wave1:agent-A2]`.

Generation-1 IDs (`A`, `B`, `C`, …) are valid wherever an agent ID appears. Multi-generation IDs are assigned by the Scout when needed; agents receive their full ID (e.g., `A2`) in Field 0 of their prompt.

---

## Completion Report Format

Structured data written by each agent to the IMPL doc. Machine-readable. Orchestrator parses these before merging.

**E14: Write discipline:** Agents append completion reports to the IMPL doc's `completion_reports:` map at root level with agent ID as key. Agents never edit earlier sections (interface contracts, ownership table, suitability verdict). Those sections are frozen at worktree creation (E2).

**Format:**

```yaml
completion_reports:
  A:
    status: complete
    commit: def5678
    files_changed: [pkg/cache.go]
    verification: PASS
  B:
    status: complete
    commit: ghi9012
    files_changed: [pkg/handler.go]
    verification: PASS
```

**Field definitions:**

```yaml type=impl-completion-report
status: complete | partial | blocked
failure_type: transient | fixable | needs_replan | escalate | timeout
  # Required when status is partial or blocked.
  # Omit (or set to null) when status is complete.
worktree: .claude/worktrees/saw/{slug}/wave{N}-agent-{ID}
branch: saw/{slug}/wave{N}-agent-{ID}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
  - path/to/modified/file_test
files_created:
  - path/to/new/file
  - path/to/new/file_test
interface_deviations:
  - description: "Exact description of deviation from specified contract"
    downstream_action_required: true | false
    affects: [agent-letter, ...]  # agents in later waves that depend on this interface
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why it's needed"
  # or []
tests_added:
  - test_function_name
  - test_function_name_edge_case
verification: PASS | FAIL ({command} - N/N tests)
```

**Field definitions:**

- **status:**
  - `complete`: All work done, verification passed, committed
  - `partial`: Some work done, but incomplete or verification failed. Explain what remains in notes.
  - `blocked`: Cannot proceed without changes outside agent's scope (interface contract unimplementable, missing dependency, etc.). Explain blocker in notes.

- **failure_type:**
  - `transient` — intermittent failure (network, git lock, flaky test). Orchestrator may retry automatically (see E19).
  - `fixable` — agent hit a concrete blocker but knows the fix (e.g., missing dependency, wrong import path). Orchestrator applies fix and relaunches.
  - `needs_replan` — agent discovered the IMPL doc decomposition is wrong (ownership conflict, undiscoverable interface, scope larger than estimated). Orchestrator re-engages Scout with agent's findings as additional context.
  - `escalate` — agent cannot continue and has no recovery path. Human intervention required.
  - `timeout` — agent exhausted its turn limit before completing. Orchestrator retries once with an explicit instruction to commit partial work and prioritize essential work only. If retry also times out, escalate — scope reduction in the IMPL doc may be required.
  - Required when `status` is `partial` or `blocked`. Omit when `status` is `complete`.
  - **Validation:** The `CompletionReportBuilder` validates that `failure_type` is one of the five allowed values. Invalid enum values are rejected before the report is written to the IMPL doc.

- **repo:** Absolute path to the repository this agent worked in. Required for cross-repo waves so the Orchestrator knows which repo to merge in. Omit for single-repo waves.

- **worktree:** Canonical worktree path. Must match E5 naming convention: `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}`

- **branch:** Branch name. Must match worktree naming: `saw/{slug}/wave{N}-agent-{ID}`. Branches created before v0.39.0 use the legacy format `wave{N}-agent-{ID}` without slug prefix; tools accept both formats.

- **commit:** Git commit SHA if changes were committed. `"uncommitted"` if no changes or commit failed. I5 requires agents commit before reporting.

- **files_changed:** List of files modified (not created). Relative paths from repository root.

- **files_created:** List of files created. Relative paths from repository root.

- **interface_deviations:** List of deviations from Field 2 (Interfaces to Implement). Empty list `[]` if all contracts implemented exactly as specified.
  - `downstream_action_required: true`: Orchestrator must update affected downstream agent prompts before next wave launches.
  - `affects`: List of agent letters in later waves that depend on this interface.

- **out_of_scope_deps:** List of files outside agent's ownership that require changes for correct implementation. Empty list `[]` if no out-of-scope dependencies discovered.

- **tests_added:** List of test function names added. Should correspond to Field 5 (Tests to Write).

- **verification:** `PASS` if all Field 6 commands passed. `FAIL` with details if any command failed.

- **notes:** Free-form text for context that doesn't fit structured fields: key decisions, surprises, warnings, recommendations for downstream agents.

- **dedup_stats:** (written by engine, not by agents) File-read dedup metrics for the agent's session. Contains `hits` (cache hits), `misses` (cache misses), and `tokens_saved_estimate` (estimated tokens saved by dedup). This field is populated automatically by the SDK when file-read dedup is active.

**Free-form notes section:** After the structured YAML block, agents may add free-form notes for context that doesn't fit structured fields: key decisions, surprises, warnings, recommendations for downstream agents.

**Typed-block annotation:** The opening fence must be `` ```yaml type=impl-completion-report `` (not plain `` ```yaml ``). The orchestrator locates completion reports by finding `type=impl-completion-report` blocks, not by heading text or YAML heuristics. Plain YAML blocks are not machine-parsed.

---

## Journal Entry Format

The tool journal is a sequence of JSONL entries written to `.saw-state/wave{N}/agent-{ID}/index.jsonl` during agent execution. Each line is a JSON object representing a single tool invocation or tool result. The journal is append-only and never modified after writing.

**Purpose:** The journal captures execution history for agent recovery (E23A). When an agent is relaunched (after failure, timeout, or context compaction), the Orchestrator loads the journal, generates a summary, and prepends it to the agent's prompt. This gives the agent working memory of what it has already attempted.

**Entry schema:** Each JSONL line conforms to the `ToolEntry` struct:

```go
type ToolEntry struct {
    Timestamp   time.Time              `json:"ts"`
    Kind        string                 `json:"kind"` // "tool_use" or "tool_result"
    ToolName    string                 `json:"tool_name,omitempty"`
    ToolUseID   string                 `json:"tool_use_id"`
    Input       map[string]interface{} `json:"input,omitempty"`
    ContentFile string                 `json:"content_file,omitempty"` // Path to full output
    Preview     string                 `json:"preview,omitempty"`      // First 800 chars
    Truncated   bool                   `json:"truncated,omitempty"`
}
```

**Field definitions:**

- **ts:** ISO 8601 timestamp when the tool was invoked or result received.
- **kind:** Either `"tool_use"` (agent invoked a tool) or `"tool_result"` (tool returned output).
- **tool_name:** Name of the tool invoked (e.g., `"Read"`, `"Write"`, `"Edit"`, `"Bash"`). Present only for `tool_use` entries.
- **tool_use_id:** Unique identifier correlating a `tool_use` with its corresponding `tool_result`.
- **input:** Tool parameters as a JSON object. Keys match tool parameter names. Present only for `tool_use` entries.
- **content_file:** Relative path to a file containing the full tool result (used when output exceeds preview size). Present only for `tool_result` entries.
- **preview:** First 800 characters of the tool result. Present only for `tool_result` entries. If output is ≤800 chars, `preview` contains the full output and `truncated` is false.
- **truncated:** Boolean indicating whether the full output was written to `content_file`. Present only for `tool_result` entries.

**Example JSONL entries:**

```jsonl
{"ts":"2025-01-15T14:32:10Z","kind":"tool_use","tool_name":"Read","tool_use_id":"toolu_01A2B3","input":{"file_path":"/repo/pkg/types.go"}}
{"ts":"2025-01-15T14:32:10Z","kind":"tool_result","tool_use_id":"toolu_01A2B3","preview":"package types\n\ntype Config struct {\n\tName string\n}\n","truncated":false}
{"ts":"2025-01-15T14:33:45Z","kind":"tool_use","tool_name":"Bash","tool_use_id":"toolu_02C4D5","input":{"command":"go build ./...","description":"Build all packages"}}
{"ts":"2025-01-15T14:33:47Z","kind":"tool_result","tool_use_id":"toolu_02C4D5","content_file":"results/toolu_02C4D5.txt","preview":"# github.com/example/pkg/api\npkg/api/handler.go:42:2: undefined: middleware\n","truncated":true}
{"ts":"2025-01-15T14:35:20Z","kind":"tool_use","tool_name":"Edit","tool_use_id":"toolu_03E6F7","input":{"file_path":"/repo/pkg/api/handler.go","old_string":"func HandleRequest(w http.ResponseWriter, r *http.Request) {","new_string":"func HandleRequest(w http.ResponseWriter, r *http.Request) {\n\tmiddleware.Authenticate(r)"}}
{"ts":"2025-01-15T14:35:20Z","kind":"tool_result","tool_use_id":"toolu_03E6F7","preview":"The file /repo/pkg/api/handler.go has been updated successfully.","truncated":false}
```

**Journal persistence across retries:** If an agent fails with `failure_type: transient` or `failure_type: fixable` (E19), the Orchestrator relaunches it. The journal is preserved — entries from the failed attempt remain in `index.jsonl`. On relaunch, the agent sees what it tried before via the recovered context (E23A). This prevents retry loops where the agent repeats the same failing operation without learning from it.

**Journal cleanup:** Journals are archived after wave merge (per agent completion). Archived journals are compressed and moved to `.saw-state/archives/wave{N}-agent-{ID}.tar.gz` for post-mortem debugging but are not loaded during normal execution. Only active agent journals (for in-progress waves) are read by E23A recovery. Note: archive paths remain at `.saw-state/archives/wave{N}-agent-{ID}.tar.gz` (no slug needed -- `.saw-state/` is already project-scoped).

**Related Rules:** See E23A (tool journal recovery), E19 (failure type decision tree), I4 (IMPL doc and journal duality).

---

## Scaffolds Section Format

Written by the Scout into the IMPL doc to specify type scaffold files. Read and materialized by the Scaffold Agent after human review.

**Canonical four-column format:**

```markdown
### Scaffolds

[Omit this section if no scaffold files are needed.]

| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| `path/to/types.go` | [exact types, interfaces, structs with signatures] | `module/internal/types` | pending |
| `path/to/shared.go` | [exact interfaces] | `module/pkg/shared` | pending |
```

**Column definitions:**

- **File:** Relative path from repository root. Scaffold Agent creates this file.
- **Contents:** Exact type definitions, interface signatures, struct declarations (no behavior, no function bodies). Inline in table cell or reference to earlier section.
- **Import path:** Module-qualified import path. Agents in the wave import from this path.
- **Status:** Lifecycle indicator.

**Status lifecycle:**

- `pending`: Scout wrote spec, Scaffold Agent not yet run
- `committed`: Scaffold Agent created, compiled, and committed the file. The `commit:` field contains the commit SHA.
- `FAILED: {reason}`: Scaffold Agent could not compile. No file committed. Orchestrator surfaces failure to human.

**YAML format:**
```yaml
scaffolds:
  - file: "pkg/types/shared.go"
    contents: "type Foo struct { ... }"
    import_path: "module/pkg/types"
    status: "committed"
    commit: "abc1234"
```

**Orchestrator verification:** Before creating worktrees, Orchestrator verifies all scaffold files show `committed (sha)` status. A `FAILED` status is a protocol stop: surface the failure to the human, do not proceed to worktree creation.

**When to omit Scaffolds section:**
- Solo waves (one agent): no shared types across agents
- No cross-agent interfaces: each agent owns fully independent subsystems
- Existing codebase has all needed types: agents import from existing code, no new shared types

**Interface freeze (E2):** Scaffold files are committed to HEAD before worktrees are created. Once worktrees branch from HEAD, interface contracts become immutable. Revising a scaffold file requires recreating all worktrees or descoping the wave.

---

## Stub Report Section Format

Written by the Orchestrator after wave agent completion reports (E20). Human-facing prose — NOT a typed block.

Placement: After the last `### Agent {ID} - Completion Report` section for a wave, before the next wave section or end of document.

Template — no stubs found:

```
## Stub Report — Wave {N}

_Generated by scan-stubs.sh after wave {N} completion. Informational only — does not block merge._

No stub patterns detected.
```

Template — stubs found:

```
## Stub Report — Wave {N}

_Generated by scan-stubs.sh after wave {N} completion. Informational only — does not block merge._

| File | Line | Pattern | Context |
|------|------|---------|---------|
| path/to/file.py | 42 | `pass` | `def process_items(self): pass` |
```

Stubs found at the review checkpoint are surfaced to the human reviewer. They do not automatically block merge — the reviewer decides.

**Storage:** Stub reports are written to the IMPL manifest's `stub_reports:` map as structured data:

```yaml
stub_reports:
  wave1:
    hits:
      - file: path/to/file.py
        line: 42
        pattern: pass
        context: "def process_items(self): pass"
```

The prose table format above is generated when displaying the report to users. The structured format in `stub_reports:` is the canonical storage.

---

## Post-Merge Checklist Section Format

Written by the Scout into the IMPL doc between Known Issues and Dependency Graph. Optional — omit if no post-merge verification steps are needed beyond quality gates.

Schema:

```yaml type=impl-post-merge-checklist
groups:
  - title: {group name}
    items:
      - description: {verification step}
        command: {optional shell command}
```

Example:

```yaml type=impl-post-merge-checklist
groups:
  - title: "Build Verification"
    items:
      - description: "Full workspace build passes"
        command: "go build ./..."
      - description: "No new compiler warnings"
        command: "go vet ./..."
  - title: "Integration Tests"
    items:
      - description: "End-to-end test suite passes"
        command: "npm run test:e2e"
```

The section is human-editable at review time. Checklist items are orchestrator-facing post-merge verification steps that run after all agents complete and are merged.

---

## Quality Gates Section Format

Written by the Scout into the IMPL doc between Suitability Assessment and Scaffolds (E21). Optional — omit if no build toolchain is known or gates are not configured.

Schema:

```yaml type=impl-quality-gates
level: quick | standard | full
gates:
  - type: build | test | lint | custom
    command: {exact shell command}
    required: true | false
    description: {optional human-readable description}
    repo: {optional repo short name}  # if set, gate only runs in the specified repo (multi-repo waves)
    fix: true | false                  # if true, run in fix mode (e.g. gofmt -w); default false
    timing: pre-merge | post-merge    # optional: default is "pre-merge"
```

Example:

```yaml type=impl-quality-gates
level: standard
gates:
  - type: build
    command: go build ./...
    required: true
  - type: test
    command: go test ./...
    required: true
  - type: lint
    command: go vet ./...
    required: false
    description: "Check for common Go mistakes"
  - type: test
    command: go test ./...
    required: true
    timing: post-merge
    description: "Integration test requiring merged state"
```

Auto-detection from project marker files:
- `go.mod` → `go build ./...` (build), `go test ./...` (test), `go vet ./...` (lint)
- `package.json` → `tsc --noEmit` (build), `npm test` (test), `eslint .` (lint)
- `Cargo.toml` → `cargo build` (build), `cargo test` (test), `cargo clippy` (lint)
- `pyproject.toml` → `mypy .` (build), `pytest` (test), `ruff check .` (lint)

The section is human-editable at review time. Gate commands should use the same toolchain already identified for the IMPL doc `test_command` field — no new tool discovery needed.

---

## docs/CONTEXT.md — Project Memory

A persistent project-level document at `docs/CONTEXT.md` in the target project. Created by the Orchestrator after the first completed feature (E18). Read by the Scout before every suitability assessment (E17).

**Canonical schema:**

```yaml
# docs/CONTEXT.md — Project memory for Scout-and-Wave
created: YYYY-MM-DD
protocol_version: "x.y.z"

architecture:
  language: string           # programming language (e.g. "go", "python")
  stack: [string]            # key frameworks/libraries (optional)
  summary: string            # backward compatibility alias for description
  description: string        # protocol-canonical human-readable summary
  modules:
    - name: string
      path: string
      responsibility: string

decisions:
  - decision: string
    rationale: string
    date: YYYY-MM-DD
    feature: string  # IMPL doc slug

conventions:
  naming: string
  error_handling: string
  testing: string

established_interfaces:
  - name: string
    path: string
    signature: string
    introduced_in: string  # IMPL doc slug

features_completed:
  - slug: string
    impl_doc: string
    waves: number
    agents: number
    date: YYYY-MM-DD
```

**Field definitions:**

- **created:** ISO date when this file was first created by the Orchestrator.
- **protocol_version:** SAW protocol version in use when the file was created or last updated.
- **architecture:** High-level description of the project's structure and its constituent modules. The `language` and `stack` fields identify the project toolchain. `description` is the protocol-canonical field name; `summary` is a backward-compatibility alias — both may appear in older CONTEXT.md files and are treated as equivalent. `modules` lists named subsystems with their filesystem paths and responsibilities.
- **decisions:** Log of architectural decisions made during SAW feature work, linked to the IMPL doc that introduced them.
- **conventions:** Project-wide conventions established through SAW waves (naming, error handling, testing patterns).
- **established_interfaces:** Interfaces introduced by prior waves that downstream agents may depend on.
- **features_completed:** Ordered record of all features delivered via SAW, for Scout context and project health tracking.

**Usage note:** The file is optional. Projects that have not completed a SAW feature will not have one. Scout handles absence gracefully (E17). Orchestrator creates it on first completion (E18).

---

## Pre-Mortem Section Format

Written by the Scout into the IMPL doc before the human review checkpoint. Placement: immediately after the Scaffolds section (or after Quality Gates if Scaffolds is omitted, or after Suitability Assessment if both Quality Gates and Scaffolds are omitted), before Known Issues and agent prompts.

The Pre-Mortem section uses a markdown table in free-form prose. It is human-facing and is NOT a typed block — it is excluded from validator scope.

**Schema:**

```markdown
## Pre-Mortem

**Overall risk:** low | medium | high

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| {description of what could go wrong} | low | medium | {concrete action to prevent or recover} |
| {description of what could go wrong} | medium | high | {concrete action to prevent or recover} |
```

**Example with realistic SAW failure modes:**

```markdown
## Pre-Mortem

**Overall risk:** medium

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Agent C writes typed-block examples that don't match the syntax Agent A defined in message-formats.md | medium | high | Agent C must read message-formats.md in full before editing; interface contract specifies exact fence annotation |
| Two agents claim ownership of the same file due to ambiguous decomposition | low | high | Scout verifies disjoint ownership before writing prompts; orchestrator checks ownership table for duplicates pre-launch |
| Scaffold file fails to compile, blocking all wave agents | low | high | Scaffold Agent must compile and commit before worktrees are created; FAILED status is a protocol stop |
| Wave 2 agent uses a state name that conflicts with Wave 1 agent's definition | low | medium | Interface contracts lock all shared names verbatim; agents must use these exactly |
```

**Field definitions:**

- **Overall risk:** Single token: `low`, `medium`, or `high`. Reflects aggregate risk across all failure modes.
- **Scenario:** Plain-language description of a specific failure mode. One row per scenario.
- **Likelihood:** `low`, `medium`, or `high`. How probable is this failure?
- **Impact:** `low`, `medium`, or `high`. How bad is the outcome if it occurs?
- **Mitigation:** Concrete action that prevents the failure or reduces its impact. Not "be careful" — a specific protocol step, check, or constraint.

---

## Known Issues Section Format

Written by the Scout into the IMPL doc between Pre-Mortem and Dependency Graph. Contains pre-existing issues discovered during suitability assessment.

Schema:

```yaml type=impl-known-issues
- title: {short title}
  description: {detailed description}
  status: {pre-existing | unrelated | blocking | etc.}
  workaround: {optional workaround or skip instruction}
```

Example:

```yaml type=impl-known-issues
- title: "Flaky test in auth module"
  description: "TestAuthHandler_SessionTimeout fails intermittently on CI"
  status: "Pre-existing, unrelated to this work"
  workaround: "Skip with -skip TestAuthHandler_SessionTimeout"
- title: "Missing error handling in legacy parser"
  description: "pkg/legacy/parser.go line 42 missing error check"
  status: "Blocking — must fix before wave launch"
  workaround: "None"
```

If no known issues exist, omit the section entirely or write:

```yaml type=impl-known-issues
[]
```

---

## Message Flow Sequence

1. **Scout → IMPL doc:** Writes suitability verdict, Scaffolds section (if needed), agent prompts
1a. **Orchestrator → Scout (E16):** Orchestrator runs validator on typed-block sections of the IMPL doc. If errors are found, feeds a correction prompt back to Scout specifying the exact failing blocks. Scout rewrites only the failing sections. This loop repeats until the doc passes validation or the retry limit (default: 3) is reached. On retry limit exhausted, Orchestrator enters BLOCKED state and surfaces errors to human. On pass, proceeds normally.
2. **Human → Orchestrator:** Approves or rejects IMPL doc
3. **Scaffold Agent → IMPL doc:** Updates Scaffolds section Status column with commit SHAs or FAILED
4. **Orchestrator → Agents:** Launches agents with absolute IMPL doc path (agents read their prompts from IMPL doc)
5. **Agents → IMPL doc:** Append completion reports
5a. **Orchestrator → IMPL doc:** Runs E20 stub scan (collects `files_changed` + `files_created` from all agent reports, runs `scan-stubs.sh`, writes `## Stub Report — Wave {N}` to IMPL doc).
5b. **Orchestrator → (build system):** Runs E21 post-wave verification gates (if `## Quality Gates` section is present in IMPL doc). Required gate failures block merge; optional gate failures warn only.
6. **Orchestrator → Human:** Surfaces completion reports, merge results, verification status

**Anti-pattern:** Completion reports written to chat only (I4 violation). IMPL doc is the single source of truth. Chat output is ephemeral; downstream agents and merge procedures rely on IMPL doc contents.

---

## IMPL Doc Conflict Resolution

**E12: Merge conflict taxonomy:**

1. **Git conflict on agent-owned files:** I1 violation (impossible if invariants hold). Do not merge. Correct ownership table and re-run wave.

2. **Git conflict on orchestrator-owned shared files (IMPL doc completion reports, append-only configs):** Expected. Resolve by accepting all appended sections. E14 ensures each agent owns a distinct named section; no semantic conflict, only git line adjacency conflict.

3. **Semantic conflict (incompatible interface implementations without git conflict):** Surfaces in `interface_deviations` and `out_of_scope_deps`. Resolved by Orchestrator before next wave via interface revision and prompt updates.

**E14 makes IMPL doc conflicts predictable:** Agents only append their named completion report section at the end. They never edit earlier sections (ownership table, interface contracts, wave structure). Two agents appending distinct sections always produce adjacent-section git conflicts with no semantic overlap.

---

---

## IMPL Doc Size

**Threshold:** If the IMPL doc exceeds ~20KB (roughly 500 lines), consider splitting.

**Split strategy:**
- Keep suitability verdict, scaffolds, dependency graph, interface contracts, file ownership, wave structure, and status in the main IMPL doc
- Move agent prompts to separate files: `docs/IMPL/IMPL-<feature>-wave{N}-agent-{ID}.md` (per-agent prompt files use `.md` extension — agent task content, not IMPL schema)
- Main IMPL doc links to per-agent files: `See [Agent A prompt](IMPL-<feature>-wave1-agent-A.md)`
- Note: per-agent filenames use the flat `wave{N}-agent-{ID}` format (no slug prefix needed since the feature name is already in the filename).

**When NOT to split:**
- Documentation-only refactors (agent prompts are small)
- Simple features with <5 agents total
- When unified audit trail is more valuable than file size

---

## Per-Agent Context Payload

Before launching Wave agents, `sawtools prepare-wave` writes a `.saw-agent-brief.md` file to each agent's worktree root. The Agent tool receives a short stub prompt (~60 tokens) referencing the IMPL doc path, wave number, and agent ID; the agent reads its full brief from `.saw-agent-brief.md`.

**Brief contents (written by `engine/prepare.go`):**

| Section | Source | Purpose |
|---------|--------|---------|
| IMPL doc path header | `opts.IMPLPath` | Agent writes completion report here (I4, I5) |
| Files owned | `file_ownership` filtered to this agent | Hard constraint (I1) |
| Task | `waves[N].agents[ID].task` | Implementation specification |
| Interface contracts | `interface_contracts` | Cross-agent boundary definitions |
| Wiring obligations | `wiring` filtered to this agent (E35 Layer 3C) | Mandatory call-sites to wire |
| Quality gates | `quality_gates.gates` | Verification commands required before completion report |
| Merge target | `opts.MergeTarget` (program-mode only) | Which branch to merge to (P5) |

**Agent stub prompt format (passed to Agent tool):**

```markdown
<!-- IMPL doc: /absolute/path/to/docs/IMPL/IMPL-feature.yaml | Wave N | Agent X -->
<!-- Worktree: /absolute/path/to/worktree | Branch: saw/{slug}/wave{N}-agent-{X} -->

MANDATORY FIRST STEP - Verify isolation before any work:
1. cd /absolute/path/to/worktree
2. sawtools verify-isolation --branch saw/{slug}/wave{N}-agent-{X}
3. If verification fails (exit code 1), STOP immediately and report status: blocked

After verification passes, read your pre-extracted brief:
Read .saw-agent-brief.md

Follow the brief exactly.
```

**Stability:** Brief format is identical across waves. Wave 2 agents receive the same structure as Wave 1 agents — their own task and files extracted, same shared sections included.

---

## Wiring Validation Output (E35)

When `validate-integration --wiring` runs, it writes validation results to the IMPL manifest's `wiring_validation_reports:` map:

```yaml
wiring_validation_reports:
  wave1:
    wave: 1
    valid: true | false
    gaps: []  # or list of WiringGap objects
    checked_at: "2026-03-28T14:32:15Z"
```

**WiringGap structure:**

```yaml
- symbol: "RegisterHandler"
  defined_in: "pkg/handler/register.go"
  must_be_called_from: "cmd/main.go"
  agent: "A"
  wave: 1
  integration_pattern: "register"
  found: false  # true if wiring is present, false if missing
  reason: "Symbol RegisterHandler not found in cmd/main.go (grep scan)"  # or AST analysis result
```

**Storage:** Wiring validation reports are keyed by wave (e.g., `wave1`, `wave2`) in the `wiring_validation_reports:` map. Each report shows whether all E35 wiring obligations were satisfied.

---

## Integration Messages (E25/E26)

The following message formats are emitted by the Orchestrator during integration validation (E25) and Integration Agent execution (E26). These messages are written to the IMPL doc and emitted as SSE events for web UI consumption.

### `integration_gaps_detected`

Emitted when `ValidateIntegration()` finds unconnected exports after a wave completes.

```yaml
type: integration_gaps_detected
payload:
  wave: int           # wave number that was just completed
  gaps_count: int     # number of integration gaps detected
  report:             # full IntegrationReport
    wave: int
    gaps:             # list of IntegrationGap
      - export_name: string
        file_path: string
        agent_id: string
        category: string       # function_call, type_usage, field_init
        severity: string       # high, medium, low
        reason: string
        suggested_fix: string
        search_results: [string]
    valid: bool       # always false when this message is emitted
    summary: string
```

### `integration_agent_started`

Emitted when the Orchestrator launches the Integration Agent to wire detected gaps.

```yaml
type: integration_agent_started
payload:
  wave: int                    # wave number
  connectors:                  # list of IntegrationConnector — files the agent may modify
    - file: string
      reason: string
```

### `integration_agent_complete`

Emitted when the Integration Agent finishes successfully.

```yaml
type: integration_agent_complete
payload:
  wave: int                    # wave number
  files_changed: [string]      # files the Integration Agent modified
```

### `integration_agent_failed`

Emitted when the Integration Agent fails to wire integration gaps.

```yaml
type: integration_agent_failed
payload:
  wave: int                    # wave number
  error: string                # error description
```

### `integration_agent_output`

Streaming output from the Integration Agent, emitted as the agent produces output chunks. Used by SSE consumers for real-time progress display.

```yaml
type: integration_agent_output
payload:
  wave: int                    # wave number
  chunk: string                # output text chunk
```

---

## Orchestrator Parsing Requirements

Orchestrators must parse these fields from each completion report:

1. **Status values:** `status: complete | partial | blocked` — gates merge decision
2. **Interface deviations:** `interface_deviations` array — identifies blocked downstream agents; items with `downstream_action_required: true` must be propagated before next wave
3. **Out-of-scope dependencies:** `out_of_scope_deps` array — generates post-merge fix list
4. **Verification results:** `verification: PASS | FAIL` — gates merge per agent
5. **File lists:** `files_changed` and `files_created` — used for conflict prediction before touching the working tree
6. **Failure type:** `failure_type: transient | fixable | needs_replan | escalate | timeout` — drives automatic remediation decision tree (E19). Present only when `status` is `partial` or `blocked`.

**Location:** The orchestrator locates completion reports by finding `` ```yaml type=impl-completion-report `` blocks in the IMPL doc — not by heading text, line number, or free-form YAML heuristics. Each such block is associated with the nearest preceding `### Agent {ID} - Completion Report` heading. Plain `` ```yaml `` blocks without the `type=` annotation are not parsed as completion reports.

**Format assumption:** All structured data is in `type=impl-completion-report` typed blocks with consistent field names. Orchestrators should reject malformed YAML or missing required fields.

---

**Reference:** See `state-machine.md` for protocol states and transitions. See `procedures.md` for orchestrator actions when reading and processing these messages.

---

## SSE Event Catalog

The Scout-and-Wave engine emits Server-Sent Events (SSE) to provide real-time progress updates during orchestration. All events are JSON payloads sent via HTTP SSE with an `event:` field for the event type and `data:` field for the payload.

### Wave Execution Events

#### `agent_output`

Streaming text chunks during agent execution. Emitted as the agent produces output for real-time progress display.

```json
{
  "agent": "A",
  "wave": 1,
  "chunk": "string"
}
```

#### `agent_tool_call`

Tool invocation and result events. Emitted when an agent calls a tool and when the result is received.

```json
{
  "agent": "A",
  "wave": 1,
  "tool_id": "toolu_123",
  "tool_name": "Read",
  "input": "{\"file_path\":\"src/main.go\"}",
  "is_result": false,
  "is_error": false,
  "duration_ms": 1250
}
```

**Fields:**
- `is_result`: `true` when this is a tool result event, `false` for tool invocation
- `is_error`: `true` if the tool returned an error
- `duration_ms`: Tool execution time (present only in result events)

#### `agent_prioritized`

Emitted when agents are reordered based on dependency graph analysis before wave execution.

```json
{
  "wave": 1,
  "original_order": ["A", "B", "C"],
  "prioritized_order": ["B", "A", "C"],
  "reordered": true,
  "reason": "Agent B provides types consumed by Agent A"
}
```

#### `auto_retry_started`

Emitted when E19 automatic retry is initiated for a failed agent.

```json
{
  "agent": "A",
  "wave": 1,
  "failure_type": "transient",
  "attempt": 2,
  "max_attempts": 3
}
```

#### `auto_retry_exhausted`

Emitted when E19 retry limit is reached without success.

```json
{
  "agent": "A",
  "wave": 1,
  "failure_type": "transient",
  "attempts": 3
}
```

### Program Execution Events (E40)

These events are emitted during PROGRAM-level orchestration (multi-IMPL coordination).

#### `program_tier_started`

Emitted when a program tier begins execution.

```json
{
  "tier": 1,
  "impl_count": 3,
  "concurrency_cap": 2
}
```

#### `program_scout_launched`

Emitted when a Scout is launched for an IMPL within a program tier.

```json
{
  "tier": 1,
  "impl_slug": "api-auth",
  "scout_agent_id": "scout-1234"
}
```

#### `program_scout_complete`

Emitted when a Scout completes successfully.

```json
{
  "tier": 1,
  "impl_slug": "api-auth",
  "verdict": "SUITABLE",
  "wave_count": 2
}
```

#### `program_impl_complete`

Emitted when an IMPL finishes all waves successfully.

```json
{
  "tier": 1,
  "impl_slug": "api-auth",
  "waves_completed": 2
}
```

#### `program_tier_gate_started`

Emitted when tier-level quality gates begin running.

```json
{
  "tier": 1,
  "gate_count": 3
}
```

#### `program_tier_gate_result`

Emitted with the result of each tier gate.

```json
{
  "tier": 1,
  "gate_type": "integration-test",
  "passed": true,
  "duration_ms": 45000
}
```

#### `program_contracts_frozen`

Emitted when interface contracts are frozen at tier boundaries (P2 enforcement).

```json
{
  "tier": 1,
  "frozen_at": "2026-03-28T15:30:00Z",
  "contract_count": 5
}
```

#### `program_tier_advanced`

Emitted when a tier completes and the program advances to the next tier.

```json
{
  "from_tier": 1,
  "to_tier": 2,
  "impl_completed": 3
}
```

#### `program_replan_triggered`

Emitted when E34 program replan is triggered.

```json
{
  "tier": 2,
  "reason": "Dependency conflict discovered in IMPL-user-auth",
  "replan_agent_id": "planner-5678"
}
```

#### `program_complete`

Emitted when all program tiers complete successfully.

```json
{
  "tier_count": 3,
  "impl_count": 8,
  "total_duration_ms": 1800000
}
```

---

## Event Consumption

**Web UI:** All SSE events are consumed by the web application's event stream endpoint (`GET /api/sse/{execution_id}`) for real-time progress display. See `docs/reference/sse-events.md` in scout-and-wave-go for full API documentation.

**CLI:** The CLI does not consume SSE events (agents run synchronously in `sawtools run-wave`). Event emission is disabled in CLI mode.

**Observability:** All events except `agent_output` chunks are also logged to the observability store (SQLite) for post-execution analysis and metrics.


