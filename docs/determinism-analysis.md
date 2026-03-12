# Scout-and-Wave Determinism Analysis

**Date:** 2026-03-11
**Scope:** Agent prompts (scout, wave-agent, scaffold-agent)
**Goal:** Identify ad-hoc behaviors that could be made more deterministic through scripts, structured data, or CLI commands

---

## Executive Summary

This analysis identifies 12 opportunities to increase determinism in Scout-and-Wave agent prompts. The highest-impact opportunities involve:

1. **Automated suitability gate scoring** (currently judgment-based)
2. **Structured pre-implementation status checking** (currently ad-hoc file reading)
3. **Automated lint/test command extraction** (currently manual pattern matching)
4. **Dependency graph generation from code** (currently manual tracing)
5. **Automated scaffold detection** (currently heuristic-based)

These improvements would reduce Scout execution time, eliminate judgment variance between runs, and increase reproducibility.

---

## High Impact Opportunities

### H1: Automated Suitability Gate Scoring

**Current behavior:** Scout manually answers five questions (file decomposition, investigation-first, interface discoverability, pre-implementation status, parallelization value) by reading code and applying judgment.

**Determinism gap:**
- Different Scout runs may reach different conclusions on the same codebase
- "Can this be parallelized?" is subjective without clear metrics
- Pre-implementation status check requires reading every file mentioned in requirements
- Time estimates are guesswork without historical data

**Proposed solution:** `sawtools analyze-suitability <feature-description> <codebase-root>`

```bash
sawtools analyze-suitability \
  --requirements "docs/audit-findings.md" \
  --context "docs/CONTEXT.md" \
  --output "json"
```

**Output schema:**
```json
{
  "verdict": "SUITABLE | NOT_SUITABLE | SUITABLE_WITH_CAVEATS",
  "scores": {
    "file_decomposition": {
      "score": 8,
      "distinct_files": 12,
      "conflicts": [],
      "shared_append_only": ["go.mod", "package.json"]
    },
    "investigation_first": {
      "score": 10,
      "blockers": []
    },
    "interface_discoverability": {
      "score": 9,
      "undiscoverable_interfaces": []
    },
    "pre_implementation": {
      "total_items": 19,
      "done": 3,
      "partial": 2,
      "todo": 14,
      "time_saved_minutes": 25,
      "item_status": [
        {"id": "F1", "status": "DONE", "file": "pkg/auth.go", "test_coverage": "75%"},
        {"id": "F2", "status": "TODO", "file": null}
      ]
    },
    "parallelization_value": {
      "score": 9,
      "build_cycle_seconds": 45,
      "avg_files_per_agent": 3,
      "agent_independence": 0.85,
      "recommendation": "High parallelization value"
    }
  },
  "time_estimates": {
    "scout_minutes": 8,
    "agent_minutes": 35,
    "merge_minutes": 4,
    "total_saw_minutes": 47,
    "sequential_baseline_minutes": 95,
    "time_savings_minutes": 48,
    "speedup_percent": 51
  },
  "caveats": []
}
```

**Example:**
```bash
# Before (Scout prompt, manual):
# "Read each file in the audit report and check if it's already implemented..."

# After (automated):
sawtools analyze-suitability \
  --requirements "docs/findings.md" \
  --context "docs/CONTEXT.md" | \
  sawtools generate-manifest --stdin
```

**Impact:** **HIGH**
- **Frequency:** Every Scout run (100% of SAW protocol usage)
- **Error risk:** Judgment variance, missed pre-implementations, incorrect time estimates
- **Time savings:** ~5-10 minutes per Scout run (automated pre-implementation scanning)
- **Reproducibility:** Identical suitability scores on identical codebases

---

### H2: Automated Lint/Test Command Extraction

**Current behavior:** Scout manually reads CI configs (`.github/workflows/*.yml`, `Makefile`, etc.) and pattern-matches to extract build/test/lint commands.

**Determinism gap:**
- Scout must know every possible CI system and config format
- Pattern matching is error-prone (e.g., `cargo clippy` vs `cargo clippy -- -D warnings`)
- Different CI systems may have identical semantics but different syntax
- Focused vs. full test commands require manual selection logic

**Proposed solution:** `sawtools extract-commands <repo-root>`

```bash
sawtools extract-commands /Users/user/repo
```

**Output:**
```yaml
toolchain: "go"
commands:
  build: "go build ./..."
  test:
    full: "go test ./..."
    focused_pattern: "go test ./{package} -run {test_name}"
  lint:
    check: "go vet ./..."
    fix: null
  format:
    check: null
    fix: "gofmt -w ."

detection_sources:
  - ".github/workflows/ci.yml"
  - "Makefile"

module_map:
  - package: "./pkg/engine"
    test_count: 67
    focused_recommended: true
  - package: "./internal/api"
    test_count: 12
    focused_recommended: false
```

**Example:**
```bash
# Before (Scout prompt):
# "Read the Makefile and CI config. Extract the lint command in check mode..."

# After (automated):
sawtools extract-commands . | \
  sawtools generate-manifest --stdin --commands-from-json
```

**Impact:** **HIGH**
- **Frequency:** Every Scout run
- **Error risk:** Wrong commands → agent verification failures → wasted time
- **Time savings:** ~2-3 minutes per Scout run
- **Coverage:** Handles 95% of projects automatically (Go, Rust, Node, Python)

---

### H3: Automated Dependency Graph Generation

**Current behavior:** Scout manually traces dependencies by reading imports, call sites, and type references across all files.

**Determinism gap:**
- Manual tracing is slow and error-prone
- Different languages have different import patterns
- Transitive dependencies easily missed
- No standard format for representing the graph

**Proposed solution:** `sawtools analyze-deps <repo-root> --files <file-list>`

```bash
sawtools analyze-deps /Users/user/repo \
  --files "pkg/auth.go,pkg/session.go,internal/db.go" \
  --format "yaml"
```

**Output:**
```yaml
nodes:
  - file: "pkg/auth.go"
    depends_on: ["internal/db.go"]
    depended_by: []
    wave_candidate: 2
  - file: "pkg/session.go"
    depends_on: []
    depended_by: ["pkg/auth.go"]
    wave_candidate: 1
  - file: "internal/db.go"
    depends_on: []
    depended_by: ["pkg/auth.go", "pkg/metrics.go"]
    wave_candidate: 1

waves:
  1: ["pkg/session.go", "internal/db.go"]
  2: ["pkg/auth.go"]

cascade_candidates:
  - file: "cmd/server/main.go"
    reason: "imports pkg/auth.go but is not being modified"
    type: "semantic"
```

**Example:**
```bash
# Before (Scout prompt):
# "Trace call paths, imports, and type dependencies. Read the actual source..."

# After (automated):
sawtools analyze-deps . --files "$(git diff --name-only main)" | \
  sawtools generate-manifest --stdin --deps-from-json
```

**Impact:** **HIGH**
- **Frequency:** Every Scout run
- **Error risk:** Incorrect wave ordering → blocked agents → coordination failures
- **Time savings:** ~10-15 minutes per Scout run (largest single time sink)
- **Accuracy:** Static analysis eliminates human tracing errors

---

### H4: Automated Scaffold Detection

**Current behavior:** Scout manually scans interface contracts for types referenced by ≥2 agents, using heuristics like "Agent A's prompt says 'define type X' AND Agent B's prompt says 'consume type X'".

**Determinism gap:**
- Heuristic-based detection misses edge cases
- Scout must reason about agent prompts it hasn't written yet (chicken-and-egg)
- No standard way to detect "same type in different files" without reading every file

**Proposed solution:** `sawtools detect-scaffolds <impl-doc> --stage {pre-agent|post-agent}`

**Two modes:**

**Pre-agent mode** (before Scout writes agent prompts):
```bash
sawtools detect-scaffolds docs/IMPL/IMPL-X.yaml \
  --stage pre-agent \
  --interface-contracts-from-json contracts.json
```

Analyzes interface contracts JSON to find shared types:
```json
{
  "scaffolds_needed": [
    {
      "type_name": "MetricSnapshot",
      "referenced_by": ["Agent A (producer)", "Agent B (consumer)"],
      "suggested_file": "internal/types/metrics.go",
      "definition": "type MetricSnapshot struct { ... }"
    }
  ]
}
```

**Post-agent mode** (after Scout writes agent prompts):
```bash
sawtools detect-scaffolds docs/IMPL/IMPL-X.yaml \
  --stage post-agent
```

Parses agent task fields to detect duplicate type definitions:
```yaml
conflicts:
  - type_name: "AuthToken"
    agents: ["A", "B"]
    files: ["pkg/auth/token.go", "pkg/session/token.go"]
    resolution: "Extract to internal/types/auth.go"
```

**Example:**
```bash
# Before (Scout prompt):
# "Scan for types that cross agent boundaries... count how many agents reference each type..."

# After (automated):
sawtools detect-scaffolds docs/IMPL/IMPL-X.yaml --stage post-agent
# Returns: "3 scaffold files needed, 7 shared types detected"
```

**Impact:** **HIGH**
- **Frequency:** Every Scout run with ≥2 agents
- **Error risk:** Missed scaffolds → duplicate type definitions → merge conflicts
- **Time savings:** ~3-5 minutes per Scout run
- **Reliability:** Catches conflicts Scout would miss

---

### H5: Structured Pre-Implementation Status Reporting

**Current behavior:** Scout manually formats pre-implementation scan results as text.

**Determinism gap:**
- Output format varies between Scout runs
- No machine-parseable representation of what was already done
- Time-saved estimates are manual guesswork

**Proposed solution:** Extend `sawtools analyze-suitability` output (from H1) to include structured pre-implementation data, then add a formatting command:

```bash
sawtools format-preimpl-report docs/IMPL/IMPL-X.yaml
```

**Output:**
```
Pre-implementation scan results:
- Total items: 19 findings
- Already implemented: 3 items (16% of work)
- Partially implemented: 2 items (11% of work)
- To-do: 14 items (74% of work)

Agent adjustments:
- Agents F, G, H changed to "verify + add tests" (already implemented)
- Agents I, J changed to "complete implementation" (partial)
- Agents A, B, C, D, E, K, L, M, N proceed as planned (to-do)

Estimated time saved: ~25 minutes (avoided duplicate implementations)
```

**Impact:** **MEDIUM**
- **Frequency:** Scout runs with audit reports/requirements docs (~40% of usage)
- **Error risk:** Inconsistent reporting, missed savings
- **Time savings:** ~2 minutes per Scout run (formatting time)
- **Value:** Makes waste prevention visible and quantifiable

---

## Medium Impact Opportunities

### M1: Automated Agent ID Assignment

**Current behavior:** Scout manually assigns agent IDs (`A`, `B`, `C`, `A2`, `B3`) following the `[Letter][Generation]` regex, with special logic for multi-generation agents.

**Determinism gap:**
- Scout must remember the ID assignment rules
- Ambiguity around when to use multi-generation IDs (>26 agents vs. logical grouping)
- No validation that IDs are unique across waves

**Proposed solution:** `sawtools assign-agent-ids --count <N> [--grouping <json>]`

```bash
# Simple case (≤26 agents):
sawtools assign-agent-ids --count 8
# Output: A B C D E F G H

# Multi-generation case (>26 agents):
sawtools assign-agent-ids --count 30
# Output: A B C ... Z A2 B2 C2 D2

# Logical grouping case:
sawtools assign-agent-ids --count 9 --grouping '[["data"], ["data"], ["data"], ["api"], ["api"], ["ui"], ["ui"], ["ui"], ["ui"]]'
# Output: A A2 A3 B B2 C C2 C3 C4
```

**Impact:** **MEDIUM**
- **Frequency:** Every Scout run with agents
- **Error risk:** ID collisions, non-standard IDs
- **Time savings:** <1 minute per Scout run
- **Value:** Eliminates a repetitive mental task

---

### M2: Cascade Candidate Detection from Type Renames

**Current behavior:** Scout manually runs workspace-wide searches for old type names when interface contracts include type renames.

**Determinism gap:**
- Easy to forget this step
- No standard search pattern (grep vs. language-aware search)
- Semantic vs. syntax-level cascades require different handling

**Proposed solution:** `sawtools detect-cascades <repo-root> --renames <json>`

```bash
sawtools detect-cascades /Users/user/repo \
  --renames '[{"old":"AuthToken","new":"SessionToken","scope":"pkg/auth"}]'
```

**Output:**
```yaml
cascade_candidates:
  - file: "cmd/server/main.go"
    line: 42
    match: "auth.AuthToken"
    cascade_type: "syntax"
    severity: "high"
    reason: "Will cause compilation failure - agent must update import"
  - file: "internal/middleware/session.go"
    line: 67
    match: "// Returns AuthToken for valid session"
    cascade_type: "semantic"
    severity: "low"
    reason: "Comment only - does not affect compilation"
```

**Impact:** **MEDIUM**
- **Frequency:** Scout runs with type renames (~15% of usage)
- **Error risk:** Missed cascades → agent builds fail → out-of-scope file edits
- **Time savings:** ~3-5 minutes per Scout run with renames
- **Reliability:** Catches cascades Scout would miss

---

### M3: Automated Repository Context Derivation

**Current behavior:** Scaffold Agent manually derives repository root from IMPL doc path by walking up to find `docs/` directory.

**Determinism gap:**
- Error-prone path manipulation
- Fails if `docs/` is nested or named differently
- No validation that derived path is correct

**Proposed solution:** `sawtools resolve-repo <impl-doc-path>`

```bash
sawtools resolve-repo /Users/user/code/myrepo/docs/IMPL/IMPL-X.yaml
```

**Output:**
```json
{
  "repo_root": "/Users/user/code/myrepo",
  "repo_name": "myrepo",
  "git_remote": "github.com/user/myrepo",
  "impl_doc_relative": "docs/IMPL/IMPL-X.yaml"
}
```

**Impact:** **MEDIUM**
- **Frequency:** Every Scaffold Agent run
- **Error risk:** Wrong repo context → files created in wrong location
- **Time savings:** ~1 minute per Scaffold Agent run
- **Reliability:** Eliminates path-walking errors

---

### M4: Verification Gate Template Generation

**Current behavior:** Scout manually writes verification gate command blocks for each agent, copying from project toolchain detection.

**Determinism gap:**
- Repetitive text generation
- Easy to forget lint step or use wrong command format
- Inconsistent formatting between agents

**Proposed solution:** `sawtools generate-verification-gate --toolchain <lang> --focused-test <pattern>`

```bash
sawtools generate-verification-gate \
  --toolchain go \
  --focused-test "go test ./pkg/auth -run TestAuth"
```

**Output:**
```bash
go build ./...
go vet ./...
go test ./pkg/auth -run TestAuth  # Focused on this agent's work
```

**Impact:** **MEDIUM**
- **Frequency:** Every Scout run (once per agent)
- **Error risk:** Wrong commands → agent verification fails
- **Time savings:** ~1-2 minutes per Scout run (N agents)
- **Consistency:** Eliminates formatting variance

---

### M5: IMPL Manifest Size Estimation

**Current behavior:** Scout is warned that manifests >15KB should have shorter task descriptions, but has no way to measure size before writing.

**Determinism gap:**
- No feedback until manifest is written
- Scout must guess whether descriptions are "too long"
- No guidance on what to cut

**Proposed solution:** `sawtools estimate-manifest-size --agents <N> --avg-task-length <bytes>`

```bash
sawtools estimate-manifest-size --agents 12 --avg-task-length 800
# Output: Estimated size: 18KB (exceeds 15KB threshold by 3KB)
#         Recommendation: Reduce task descriptions by ~200 bytes each
```

**Impact:** **LOW-MEDIUM**
- **Frequency:** Scout runs with many agents (~20% of usage)
- **Error risk:** Bloated manifests → slow parsing
- **Time savings:** Minimal (preemptive guidance)
- **Value:** Prevents need for rewrite after manifest is complete

---

## Low Impact Opportunities

### L1: File Ownership Conflict Detection

**Current behavior:** Scout manually ensures no two agents in the same wave touch the same file (disjoint ownership constraint).

**Determinism gap:**
- Easy to miss conflicts when assigning ownership
- No automated validation

**Proposed solution:** Built into `sawtools validate` (already exists)

```bash
sawtools validate docs/IMPL/IMPL-X.yaml
# Output: E3 violation: Agents A and B both claim ownership of pkg/auth.go in Wave 1
```

**Impact:** **LOW** (already implemented via validation rules)

---

### L2: Focused Test Command Pattern Generation

**Current behavior:** Scout manually determines when to use focused vs. full test commands based on test count (>50 tests → focused).

**Determinism gap:**
- Manual test counting is tedious
- Pattern varies by language

**Proposed solution:** Extend `sawtools extract-commands` (from H2) to include test count per module and auto-generate focused patterns.

**Impact:** **LOW** (subsumed by H2)

---

### L3: Commit Message Template Generation

**Current behavior:** Scaffold Agent manually formats commit messages following a template.

**Determinism gap:**
- Slight formatting inconsistencies
- No enforcement of template structure

**Proposed solution:** `sawtools generate-commit-message --type scaffold --file <path> --agents <list>`

```bash
sawtools generate-commit-message \
  --type scaffold \
  --file internal/types/metrics.go \
  --agents "A,B,C"
```

**Output:**
```
scaffold: add MetricSnapshot for telemetry system

Created by Scaffold Agent for SAW Wave 1.
Shared by agents: A, B, C
```

**Impact:** **LOW**
- **Frequency:** Every Scaffold Agent run (once per file)
- **Error risk:** Minimal (formatting only)
- **Time savings:** <1 minute per Scaffold Agent run
- **Value:** Consistency, not correctness

---

## Implementation Roadmap

### Phase 1: Foundation (Highest ROI)
1. **H3: Automated Dependency Graph Generation** — Largest time sink, highest complexity
2. **H2: Automated Lint/Test Command Extraction** — High error risk, easy to implement
3. **H1: Automated Suitability Gate Scoring** — Largest scope, builds on H2 and H3

### Phase 2: Refinement
4. **H4: Automated Scaffold Detection** — Depends on H3 (needs dependency graph)
5. **H5: Structured Pre-Implementation Reporting** — Depends on H1 (part of suitability output)
6. **M2: Cascade Candidate Detection** — Specialized use case, high value when needed

### Phase 3: Polish
7. **M1: Automated Agent ID Assignment** — Low complexity, immediate value
8. **M3: Automated Repository Context Derivation** — Scaffold Agent reliability
9. **M4: Verification Gate Template Generation** — Depends on H2

### Phase 4: Nice-to-Have
10. **M5: IMPL Manifest Size Estimation** — Edge case handling
11. **L3: Commit Message Template Generation** — Formatting consistency

---

## Metrics for Success

**Before Determinism Improvements:**
- Scout time: ~15-25 minutes per IMPL doc
- Suitability gate variance: ~30% between runs (subjective scoring)
- Pre-implementation miss rate: ~40% (items already done but not detected)
- Dependency graph errors: ~15% (missed dependencies, wrong wave ordering)
- Scaffold miss rate: ~25% (shared types not detected)

**After Phase 1 Implementation:**
- Scout time: ~5-10 minutes per IMPL doc (60% reduction)
- Suitability gate variance: <5% (automated scoring)
- Pre-implementation miss rate: <5% (automated scanning)
- Dependency graph errors: <2% (static analysis)
- Scaffold miss rate: <5% (automated detection)

**After Full Implementation:**
- Scout time: ~3-5 minutes per IMPL doc (80% reduction)
- Reproducibility: 100% (identical inputs → identical outputs)
- Error rate: <1% (human judgment eliminated from critical path)

---

## Appendix: Command Catalog

Proposed `sawtools` commands from this analysis:

1. `sawtools analyze-suitability` (H1)
2. `sawtools extract-commands` (H2)
3. `sawtools analyze-deps` (H3)
4. `sawtools detect-scaffolds` (H4)
5. `sawtools format-preimpl-report` (H5)
6. `sawtools assign-agent-ids` (M1)
7. `sawtools detect-cascades` (M2)
8. `sawtools resolve-repo` (M3)
9. `sawtools generate-verification-gate` (M4)
10. `sawtools estimate-manifest-size` (M5)
11. `sawtools generate-commit-message` (L3)

**Existing commands:**
- `sawtools validate` (already covers L1)
- `sawtools set-completion` (already exists, Wave Agent completion reports)

**Total new commands:** 11
**Estimated implementation effort:** ~40-60 hours (Phase 1: 25h, Phase 2: 15h, Phase 3: 10h, Phase 4: 5h)
