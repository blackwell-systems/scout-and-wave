# Scout-and-Wave Determinism Roadmap

**Date:** 2026-03-11
**Status:** Phase 1 + Phase 2 COMPLETE | Phase 3 Ready
**Updated:** 2026-03-14
**Sources:** determinism-analysis.md + determinism-analysis-AUDIT.md (merged)

---

## Phase 1 + 2 Completion (2026-03-14)

**All foundational Scout automation tools are now COMPLETE and integrated:**

- ✅ **H2** (extract-commands) — CI config scanner with 8 parsers (GitHub Actions, CircleCI, Travis, Jenkins, GitLab, Makefile, package.json, justfile)
- ✅ **H3** (analyze-deps) — Multi-language dependency analyzer (Go/Rust/JS/Python) with wave candidate suggestions
- ✅ **H1a** (analyze-suitability) — Pre-implementation status scanner with DONE/PARTIAL/TODO classification
- ✅ **H4** (detect-scaffolds) — Interface scaffold detection from type contracts
- ✅ **M2** (detect-cascades) — AST-based rename cascade analyzer

**Integration (v0.36.0):**
- SDK: `pkg/engine/runner.go` calls H2→H1a→H3 before Scout launch
- CLI: `/saw` skill runs `sawtools` automation commands via Bash
- Results injected into Scout prompts as "Automation Analysis Results" section

**Measured impact:**
- Build/test commands auto-detected (eliminates manual guessing)
- Requirements status classified automatically (DONE/PARTIAL/TODO)
- Dependency-aware wave structures (H3 wave_candidate field)
- Zero Scout runtime overhead (runs in orchestrator layer)


## Executive Summary

This roadmap identifies opportunities to eliminate judgment variance from Scout-and-Wave agent prompts through automation. The highest-impact work involves:

1. ✅ **Automated dependency graph generation** (H3) — largest Scout time sink, foundational for 4 downstream tools
2. ✅ **Automated lint/test command extraction** (H2) — highest error risk (wrong commands break verification gates)
3. **Wave/Scaffold agent automation** (H6, H7, H8) — applies to every wave execution, not just planning phase

**Realistic ROI:** 50-65% Scout time reduction (25 min → 8-12 min) after Phase 1+2 completion, accounting for tool execution overhead and error handling. The original 80% projection was overly optimistic.

**Total Effort:** 114-153 hours across 4 phases (not 40-60 hours as originally estimated). The discrepancy comes from:
- Multi-language support requirements (Go/Rust/JS/Python parsers for H3)
- Wave/Scaffold agent tools (30-37h) entirely missing from original analysis
- H1 split into 4 separate tools (pre-impl scanning, time estimation, parallelization scoring, verdict synthesis)

**Recommendation:** Proceed with Phase 1 (H2 + H3, 30-40 hours) immediately. These are foundational, have clear ROI, and can be built in parallel.

---

## Revised Roadmap

### Phase 3b: Wave Failure Diagnosis (8-12 hours, NEW) — PROPOSED

**H9: Wave Failure Diagnosis** (8-12 hours) — PROPOSED
- Extends H7 pattern-matching to SAW's own wave failures
- Diagnoses post-merge test failures, missing dependencies, interface mismatches, commit violations
- Auto-runs on `verify-build` failure
- Estimated to catch 80% of common wave failure patterns

**Deliverables:**
- `sawtools diagnose-wave-failure <impl-doc> --wave <N>`

**Rationale:** H7 test isolation bug (catalog state mutation) required manual diagnosis. The protocol caught the failure (post-merge verification), but root cause analysis was manual. Automated failure diagnosis with pattern matching would have immediately identified the global state mutation and suggested the defer-based fix.

---

### Phase 4: Polish (19-31 hours)

**M3: Repository Context Derivation** (3-5 hours)
**M4: Verification Gate Template Generation** (5-8 hours) — depends on H2
**H5: Pre-Implementation Reporting** (3-5 hours) — depends on H1a (formatting only)
**M5: Manifest Size Estimation** (3-5 hours)
**L3: Commit Message Template Generation** (2-3 hours)

**Deliverables:**
- `sawtools resolve-repo <impl-doc-path>`
- `sawtools generate-verification-gate --toolchain <lang> --focused-test <pattern>`
- `sawtools format-preimpl-report <impl-doc>`
- `sawtools estimate-manifest-size --agents <N> --avg-task-length <bytes>`
- `sawtools generate-commit-message --type scaffold --file <path> --agents <list>`

---

## Opportunities Catalog

### H1: Automated Suitability Gate Scoring

**SPLIT INTO 4 COMPONENTS** (original analysis treated as single tool):

#### H1b: Lint/Test Command Synthesis (Subsumed by H2)

**Status:** No separate tool needed — H2 (command extraction) provides this functionality.

---

#### H1c: Time Estimation (MEDIUM, Phase 4 or later)

**Current behavior:** Scout guesses time estimates without historical data.

**Proposed solution:** Requires persistent storage layer + query API for historical SAW session data. Out of scope for initial phases.

**Defer until:** Project has 20+ completed IMPL docs to train on.

---

#### H1d: Parallelization Value Scoring (MEDIUM, Phase 4 or later)

**Current behavior:** Scout manually assesses "is parallelization valuable?" using subjective judgment.

**Proposed solution:** Extend H3 (dep graph) with:
```json
{
  "parallelization_value": {
    "score": 9,
    "build_cycle_seconds": 45,
    "avg_files_per_agent": 3,
    "agent_independence": 0.85,
    "recommendation": "High parallelization value"
  }
}
```

**Implementation notes:**
- Requires build system profiling (run `cargo build` and time it)
- Agent independence = graph theory problem (transitive closure on H3's dep graph)
- Adds 30-60 seconds to tool execution time

---

### H5: Structured Pre-Implementation Reporting (LOW, Phase 4)

**Current behavior:** Scout manually formats pre-implementation scan results as text.

**Determinism gap:**
- Output format varies between Scout runs
- No machine-parseable representation of what was already done
- Time-saved estimates are manual guesswork

**Proposed solution:** `sawtools format-preimpl-report <impl-doc>`

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

Estimated time saved: ~21 minutes (avoided duplicate implementations)
```

**Impact:**
- **Frequency:** Scout runs with audit reports/requirements docs (~40% of usage)
- **Error risk:** Minimal (formatting only, no functional value)
- **Time savings:** ~2 minutes per Scout run (formatting time)
- **Value:** Makes waste prevention visible and quantifiable

**Dependencies:** Requires H1a (pre-implementation scanning) — this is pure formatting of H1a's output.

---

### H6: Dependency Conflict Detection (HIGH, Phase 3 — NEW)

**Current behavior:** Wave agents discover missing dependencies at build time and attempt to install them ad-hoc. If installation fails (version conflicts, platform incompatibility), agents retry multiple times before reporting `status: blocked`.

**Determinism gap:**
- No pre-flight dependency check before launching agents
- Agents guess whether to install locally or report to orchestrator
- Dependency installation is not recorded in completion reports consistently

**Observed failure mode (from `wave-agent.md`):**
- Agents run `go get`, `npm install`, `cargo fetch`, `pip install` when missing dependencies
- No guidance on when to install vs. report as blocker
- Agents waste 5-10 minutes trying to auto-resolve dependency issues that require orchestrator intervention

**Proposed solution:** `sawtools check-deps <impl-doc> --wave <N>`

Run before creating worktrees. Scans agent file ownership lists, extracts import statements, cross-references with project lock files (`go.sum`, `package-lock.json`, `Cargo.lock`).

**Usage:**
```bash
sawtools check-deps docs/IMPL/IMPL-feature.yaml --wave 1
```

**Output:**
```json
{
  "missing_deps": [
    {
      "agent": "A",
      "package": "github.com/foo/bar",
      "required_by": "pkg/auth.go",
      "available_version": null
    }
  ],
  "version_conflicts": [
    {
      "agents": ["A", "B"],
      "package": "lodash",
      "versions": ["4.17.0", "5.0.0"],
      "resolution_needed": true
    }
  ],
  "recommendations": [
    "Install github.com/foo/bar before Wave 1 launch",
    "Resolve lodash version conflict (A requires 4.x, B requires 5.x)"
  ]
}
```

**Example integration:**
```bash
# Before worktree creation:
sawtools check-deps docs/IMPL/IMPL-X.yaml --wave 1

# If conflicts detected:
# - Install missing deps in main branch
# - Resolve version conflicts
# - Re-run check-deps
# - Proceed to worktree creation when clean
```

**Impact:**
- **Frequency:** ~40% of waves (agents adding new packages or upgrading versions)
- **Error risk:** HIGH — agents waste 5-10 min each on dependency thrashing
- **Time savings:** ~8-15 minutes per affected wave (pre-flight install vs. per-agent retry)
- **Reliability:** Catches version conflicts that cause flaky builds

**Implementation notes:**
- Standalone (no tool dependencies)
- Reads lock files deterministically
- HIGH confidence (lock file parsing is straightforward)

**Multi-repo support:** Scans lock files in all repos referenced in file ownership table (`repo:` fields). Reports cross-repo version conflicts (Agent A in repo X requires lodash@4.x, Agent B in repo Y requires lodash@5.x).

---

### H7: Build Failure Diagnosis — ✅ COMPLETE (v0.38.0 + v0.39.0 integration)

**Current behavior (from `wave-agent.md` Field 6):**
- Agents run verification gates (build + lint + test)
- Build failures trigger ad-hoc debugging: reading error logs, checking imports, adjusting flags
- No structured guidance on which build errors are fixable vs. should escalate

**Determinism gap:**
- Agents retry builds with slight variations (adding flags, changing paths) hoping for success
- No catalog of "known build patterns" (e.g., Go: `cannot find package` → run `go mod tidy`)

**Proposed solution:** `sawtools diagnose-build-failure <error-log> --language <lang>`

**Usage:**
```bash
# Agent hits build failure:
go build ./... 2>&1 | tee build-error.log

# Diagnose:
sawtools diagnose-build-failure build-error.log --language go
```

**Output:**
```yaml
diagnosis: "missing_import"
confidence: 0.95
fix: "go mod tidy && go build ./..."
rationale: "Error 'cannot find package X' indicates go.sum is stale"
auto_fixable: true
```

**Pattern catalog (examples):**

**Go:**
- `cannot find package` → `go mod tidy`
- `undefined: X` → check imports, add missing import
- `cannot use X (type Y) as type Z` → type mismatch, check interface contract

**Rust:**
- `error[E0425]: cannot find value` → check module imports, add `use` statement
- `error[E0277]: the trait bound ... is not satisfied` → missing trait implementation

**JavaScript/TypeScript:**
- `Cannot find module 'X'` → `npm install X`
- `Property 'X' does not exist on type 'Y'` → type definition mismatch, check interface contract

**Python:**
- `ModuleNotFoundError: No module named 'X'` → `pip install X`
- `NameError: name 'X' is not defined` → check imports

**Status: COMPLETE (2026-03-14)**
- v0.38.0: CLI command + pattern engine (27 patterns across 4 languages)
- v0.39.0: Wave agent integration (wave-agent.md + agent-template.md)
- Integration: Agents auto-call diagnose-build-failure on verification gate failures
- Confidence threshold: ≥0.85 for auto-fix, <0.85 for manual review

**Impact:**
- **Frequency:** ~30% of agents (agents with build failures)
- **Error risk:** Agents waste 3-5 min per retry on ad-hoc debugging
- **Time savings:** ~5-10 minutes per affected agent (structured diagnosis vs. trial-and-error)
- **Reliability:** Pattern matching catches 60-70% of common build errors

**Implementation notes:**
- Standalone (no tool dependencies)
- Pattern catalog evolves over time (add new patterns as observed)
- LOW-MEDIUM confidence (error message patterns change with compiler versions)

**Maintenance burden:** MEDIUM
- Must stay current with compiler error message formats
- Each language needs separate pattern catalog

---

### H9: Wave Failure Diagnosis (HIGH, Phase 3b — NEW) — PROPOSED

**Current behavior:**
- Post-merge `verify-build` fails with cryptic error messages
- Root cause analysis is manual (e.g., H7 test isolation bug required human diagnosis)
- No structured catalog of "common wave failure patterns"

**Determinism gap:**
- Wave failures caught by protocol (verify-build) but diagnosis is manual
- Same failure modes repeat across different features (test isolation, missing deps, interface mismatches)
- No guidance on how to fix common wave failures

**Proposed solution:** `sawtools diagnose-wave-failure <impl-doc> --wave <N>`

Extends H7 pattern-matching to SAW's own wave failures. Auto-runs on `verify-build` failure.

**Common Failure Patterns:**

1. **Test Isolation Failure** (what we hit with H7):
   - Individual agent tests passed, post-merge suite fails
   - Root cause: Global state mutation without cleanup
   - Fix: Add defer-based cleanup pattern

2. **Missing Cross-Package Dependencies**:
   - Wave agents built locally, post-merge fails with "undefined: Type"
   - Root cause: Missing `go mod tidy` or uncommitted agent work
   - Fix: Verify all agents committed (I5), run `go mod tidy`

3. **Interface Contract Mismatch**:
   - Wave agents passed, post-merge fails with type errors
   - Root cause: Agent worked from stale IMPL doc or misread contract
   - Fix: Re-extract interface contracts, update agent implementation

4. **No Commits (I5 violation)**:
   - Agent completion report present, worktree branch has 0 commits
   - Root cause: Agent wrote report without committing work
   - Fix: Check working directory for uncommitted changes

**Usage:**
```bash
# Manual invocation:
sawtools diagnose-wave-failure docs/IMPL/IMPL-feature.yaml --wave 2

# Auto-runs on verify-build failure:
sawtools verify-build docs/IMPL/IMPL-feature.yaml --repo-dir .
# If exit code 1, automatically runs:
# sawtools diagnose-wave-failure docs/IMPL/IMPL-feature.yaml --wave 2
```

**Output schema:**
```yaml
pattern: TEST_ISOLATION_FAILURE
confidence: 0.95
evidence:
  - Wave agents passed local tests
  - Post-merge suite failed with 21 errors
  - All failures in test files from multiple agents
root_cause: |
  Global state mutation without cleanup. Test functions modify
  shared variables (e.g., `catalogs` map) without restoring
  original state after test completes.
fix: |
  Add defer-based cleanup pattern to test functions:

  originalState := globalVar
  defer func() { globalVar = originalState }()
  globalVar = make(...)
auto_fixable: false
suggested_files:
  - pkg/builddiag/diagnose_test.go:10
  - pkg/builddiag/diagnose_test.go:41
  - pkg/builddiag/diagnose_test.go:82
```

**Impact:**
- **Frequency:** ~20% of waves (post-merge verification failures)
- **Error risk:** HIGH — blocks wave merge, requires manual debugging
- **Time savings:** ~15-30 minutes per failure (root cause identification)
- **Reliability:** Estimated to catch 80% of common wave failure patterns

**Implementation notes:**
- Reuses H7 infrastructure (pattern matching, confidence scoring, fix suggestions)
- Covers test isolation, missing deps, interface mismatches, commit violations
- Progressive disclosure: high-confidence patterns suggest fixes, low-confidence reports evidence
- Integration: `verify-build` auto-runs diagnostics on failure

**Effort estimate:** 8-12 hours (similar to H7, reuses catalog pattern)

**Rationale:** Would have immediately caught H7 test isolation bug and suggested the defer fix. Makes wave failure recovery smoother by automating the most common debugging patterns.

---

### M3: Repository Context Derivation (MEDIUM, Phase 4)

**Current behavior:** Scaffold Agent manually derives repository root from IMPL doc path by walking up to find `docs/` directory.

**Determinism gap:**
- Error-prone path manipulation
- Fails if `docs/` is nested or named differently
- No validation that derived path is correct

**Proposed solution:** `sawtools resolve-repo <impl-doc-path>`

**Usage:**
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

**Impact:**
- **Frequency:** Every Scaffold Agent run
- **Error risk:** Wrong repo context → files created in wrong location
- **Time savings:** ~1 minute per Scaffold Agent run
- **Reliability:** Eliminates path-walking errors

---

### M4: Verification Gate Template Generation (MEDIUM, Phase 4)

**Current behavior:** Scout manually writes verification gate command blocks for each agent, copying from project toolchain detection.

**Determinism gap:**
- Repetitive text generation
- Easy to forget lint step or use wrong command format
- Inconsistent formatting between agents

**Proposed solution:** `sawtools generate-verification-gate --toolchain <lang> --focused-test <pattern>`

**Usage:**
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

**Impact:**
- **Frequency:** Every Scout run (once per agent)
- **Error risk:** Wrong commands → agent verification fails
- **Time savings:** ~1-2 minutes per Scout run (N agents)
- **Consistency:** Eliminates formatting variance

**Implementation notes:**
- Depends on H2 (formats commands extracted by H2)
- Cannot exist without H2

---

### M5: IMPL Manifest Size Estimation (LOW, Phase 4)

**Current behavior:** Scout is warned that manifests >15KB should have shorter task descriptions, but has no way to measure size before writing.

**Determinism gap:**
- No feedback until manifest is written
- Scout must guess whether descriptions are "too long"
- No guidance on what to cut

**Proposed solution:** `sawtools estimate-manifest-size --agents <N> --avg-task-length <bytes>`

**Usage:**
```bash
sawtools estimate-manifest-size --agents 12 --avg-task-length 800
# Output: Estimated size: 18KB (exceeds 15KB threshold by 3KB)
#         Recommendation: Reduce task descriptions by ~200 bytes each
```

**Impact:**
- **Frequency:** Scout runs with many agents (~20% of usage)
- **Error risk:** Minimal (bloated manifests → slow parsing)
- **Time savings:** Minimal (preemptive guidance)
- **Value:** Prevents need for rewrite after manifest is complete

---

### L1: File Ownership Conflict Detection (LOW — Already Implemented)

**Current behavior:** Scout manually ensures no two agents in the same wave touch the same file (disjoint ownership constraint).

**Status:** Built into `sawtools validate` (already exists).

```bash
sawtools validate docs/IMPL/IMPL-X.yaml
# Output: E3 violation: Agents A and B both claim ownership of pkg/auth.go in Wave 1
```

**Impact:** LOW (already implemented via validation rules)

---

### L2: Focused Test Command Pattern (LOW — Subsumed by H2)

**Current behavior:** Scout manually determines when to use focused vs. full test commands based on test count (>50 tests → focused).

**Status:** Subsumed by H2 (command extraction includes test count per module and auto-generates focused patterns).

---

### L3: Commit Message Template Generation (LOW, Phase 4)

**Current behavior:** Scaffold Agent manually formats commit messages following a template.

**Determinism gap:**
- Slight formatting inconsistencies
- No enforcement of template structure

**Proposed solution:** `sawtools generate-commit-message --type scaffold --file <path> --agents <list>`

**Usage:**
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

**Impact:**
- **Frequency:** Every Scaffold Agent run (once per file)
- **Error risk:** Minimal (formatting only)
- **Time savings:** <1 minute per Scaffold Agent run
- **Value:** Consistency, not correctness

---

## Implementation Risks and Edge Cases

### Multi-Language Support (H3)

**Risk:** H3 (dependency graph generation) requires separate parsers for each language. Cross-language support multiplies implementation effort by 3-4x.

**Mitigation:** Phase 1 implements Go only. Add Rust/JS/Python in Phase 2 after validating approach.

**Edge cases:**
- **Dynamic imports (Python):** `importlib.import_module(variable)` — static analysis cannot detect
- **Conditional compilation (Rust):** `#[cfg(feature = "foo")]` — dep graph depends on feature flags
- **Generated code (Protocol Buffers):** Ownership table must include both `.proto` source and `.pb.go` generated files

### Tool Execution Overhead

**Risk:** Tools are not instantaneous. H3 (dep graph) takes 30-60 seconds for 50-file codebase. H1a (pre-impl scanning) takes 3-5 minutes. This overhead erodes the projected time savings.

**Mitigation:** ROI calculations now include tool execution time. Realistic reduction: 50-65% (not 80%).

### Error Handling Complexity

**Risk:** Tools fail. When they do, Scout must interpret error messages, decide whether to retry, and potentially fall back to manual analysis. This adds 2-3 minutes per Scout run (10-20% of runs encounter tool errors).

**Mitigation:** Phase 1 tools (H2, H3) focus on high-confidence patterns. Defer lower-confidence tools (H7: build diagnosis) to Phase 3.

### Circular Dependency Detection (H3)

**Edge case:** File A imports B imports C imports A. Cannot assign wave structure.

**Resolution:** Detect cycles, report as error. Scout must manually break cycle (refactor code or mark as same-wave constraint).

### Version Conflicts (H6)

**Edge case:** Agent A requires `lodash@4.17.0`, Agent B requires `lodash@5.0.0`. Both agents are in Wave 1 (parallel execution).

**Resolution:** `sawtools check-deps` detects conflict before worktree creation. Orchestrator pauses, reports conflict, waits for human resolution (upgrade A, downgrade B, or split into sequential waves).

---

## Metrics and Success Criteria

### Realistic ROI Projections

**Before Automation:**
- Scout time: 15-25 minutes per IMPL doc
- Suitability gate variance: ~30% (subjective scoring — NOTE: baseline unclear, may be overstated)
- Pre-implementation miss rate: ~40% (items already done but not detected)
- Dependency graph errors: ~15% (missed dependencies, wrong wave ordering)
- Scaffold miss rate: ~25% (shared types not detected)

**After Phase 1 (H2 + H3):**
- Scout time: 10-14 minutes per IMPL doc (40-56% reduction)
- Dependency graph errors: <5% (static analysis)
- Tool execution overhead: 2-3 minutes (H2: 5-10 sec, H3: 30-60 sec)

**After Phase 2 (H1a + H4 + M2):**
- Scout time: 8-12 minutes per IMPL doc (52-68% reduction)
- Pre-implementation miss rate: <10% (automated scanning)
- Scaffold miss rate: <10% (automated detection)
- Suitability gate variance: <10-15% (measurement error floor)
- Tool execution overhead: 4-6 minutes total

**After Phase 3 (H6 + H7 + H8):**
- Wave agent dependency thrashing: <5% of waves (pre-flight check catches 90%)
- Wave agent build failures: 30% → 20% (diagnosis patterns catch common errors)
- Scaffold Agent failure rate: 50% → 20% (validation catches import/syntax errors)

**After Phase 4 (Polish):**
- Scout time: 8-12 minutes (no further reduction — Phase 4 is formatting/convenience)
- Reproducibility: ~95% (identical inputs → identical outputs, modulo measurement noise)

### What's Realistic vs. Optimistic

**Realistic:**
- 50-65% Scout time reduction (25 min → 8-12 min) after Phase 1+2
- <5% dependency graph errors (static analysis is reliable for import tracing)
- <10% pre-implementation miss rate (file scanning is straightforward)

**Optimistic (from original analysis):**
- 80% Scout time reduction (25 min → 5 min) — doesn't account for tool execution overhead
- <5% suitability gate variance — measurement error floor is ~10-15% for graph metrics
- 100% reproducibility — edge cases (dynamic imports, conditional compilation) always require human judgment

---

## Command Dependencies

### Dependency Graph

```
Phase 1 (Parallel):
  H2 (command extraction) ────────┐
  H3 (dependency graph) ──────┐   │
                              │   │
Phase 2 (After H3):           │   │
  H1a (pre-impl scan) ←───────┘   │
  H4 (scaffold detection) ←───┘   │
  M2 (cascade detection) ←────┘   │
                                  │
Phase 3 (Parallel):               │
  H6 (dependency conflicts) — standalone
  H7 (build diagnosis) — standalone
  H8 (scaffold validation) ←──────┘
                                  │
Phase 4 (Polish):                 │
  M4 (verification templates) ←───┘
  H5 (pre-impl reporting) ←─── H1a
  M1, M3, M5, L3 — standalone
```

### Critical Path

**Longest dependency chain:** H3 → {H1a, H4, M2} (Phase 2 bottlenecked on H3 completion)

**Parallelization opportunities:**
- Phase 1: H2 and H3 can be built simultaneously (30-40 hours total, not sequential)
- Phase 2: H1a, H4, M2 can be built simultaneously after H3 completes (35-45 hours, but all depend on H3)
- Phase 3: H6, H7, H8 can be built simultaneously (30-37 hours total, H8 depends on H2 but H2 is done in Phase 1)

---

## Command Catalog

### New Commands (11 total)

1. `sawtools analyze-suitability` (H1a — partial implementation, pre-impl scanning only)
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
12. `sawtools check-deps` (H6 — NEW)
13. `sawtools diagnose-build-failure` (H7 — NEW)
14. `sawtools validate-scaffold` (H8 — NEW)

### Existing Commands (Already Implemented)

- `sawtools validate` (covers L1 — file ownership conflict detection)
- `sawtools set-completion` (Wave Agent completion reports)
- `sawtools create-worktrees` (worktree setup)
- `sawtools merge-agents` (merge protocol)
- `sawtools verify-commits` (pre-merge verification)
- `sawtools scan-stubs` (stub detection)
- `sawtools cleanup` (worktree cleanup)
- `sawtools verify-build` (post-merge build verification)
- `sawtools update-status` (wave/agent status tracking)
- `sawtools update-context` (project memory)
- `sawtools list-impls` (IMPL discovery)
- `sawtools run-wave` (automated wave execution)
- `sawtools extract-context` (per-agent context)
- `sawtools mark-complete` (completion marker)
- `sawtools run-gates` (quality gates)
- `sawtools check-conflicts` (file ownership conflicts)
- `sawtools validate-scaffolds` (scaffold commit status)
- `sawtools freeze-check` (interface freeze enforcement)
- `sawtools update-agent-prompt` (downstream prompt updates)

**Total sawtools commands after full implementation:** 20 existing + 14 new = 34 commands

---

## Next Steps

