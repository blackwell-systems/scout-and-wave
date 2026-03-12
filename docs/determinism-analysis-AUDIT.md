# Determinism Analysis — Meta-Audit

**Auditor:** Claire (Meta-Reviewer)
**Date:** 2026-03-11
**Source:** determinism-analysis.md

---

## Executive Summary

The determinism analysis identifies real gaps but suffers from three critical weaknesses: (1) **Phase ordering is inverted** — H1 (suitability scoring) depends on H2+H3 outputs but is scheduled before them; (2) **ROI projections are overly optimistic** — the 80% time reduction (25→5 min) assumes perfect automation with zero error handling overhead; (3) **Missing high-impact opportunities** — Wave agent ad-hoc behaviors (dependency installation, build troubleshooting, test flake workarounds) and Scaffold agent error recovery are entirely absent despite being frequent failure modes. The analysis correctly identifies H2 (command extraction) and H3 (dep graphs) as foundation work, but underestimates the complexity of H1 (which is really 3-4 separate tools masquerading as one). **Recommendation:** Proceed with Phase 1 (H2+H3 only), defer H1 to Phase 2 after dependency on H2/H3 outputs is resolved, and add Wave/Scaffold agent automation as new HIGH-impact opportunities.

---

## Priority Disputes

### H1: Suitability Gate Scoring — Mis-Ranked as Single HIGH Item

**Problem:** H1 is presented as one tool (`sawtools analyze-suitability`) but is actually 4-5 distinct capabilities with vastly different complexity:

1. **Pre-implementation status checking** — file scanning + classification (DONE/PARTIAL/TODO)
2. **Parallelization value estimation** — build cycle detection + agent independence scoring
3. **Time estimation** — requires historical data or heuristics
4. **Suitability verdict synthesis** — combines all above outputs

**Dependency Issue:** H1's proposed JSON schema includes:
- `lint_command` / `test_command` → requires H2 (command extraction) output
- `agent_independence` / `build_cycle_seconds` → requires H3 (dep graph) output
- Pre-implementation item status → requires reading every file mentioned, which is slow without H3's file mapping

**Impact:** H1 cannot be implemented before H2+H3 complete. The analysis ranks it HIGH and places it in Phase 1, but makes it dependent on H2+H3 *within* Phase 1. This creates a false impression that all three can run in parallel.

**Re-Ranking Recommendation:**
- **H1a (Pre-implementation scanning):** HIGH, but Phase 2 (needs H3 for file location mapping)
- **H1b (Lint/test command synthesis):** Subsumed by H2
- **H1c (Time estimation):** MEDIUM (valuable but requires historical data collection infrastructure)
- **H1d (Parallelization value scoring):** MEDIUM (needs H3 output + build system profiling)

### H4: Scaffold Detection — Correctly Ranked HIGH but Wrong Phase

**Dependency:** H4 explicitly depends on H3 (dep graph) for cross-boundary type detection. The analysis places H4 in Phase 2, H3 in Phase 1 — this is correct sequencing but undermines the claim that H4 is HIGH impact. If it were truly HIGH, it should be in Phase 1 alongside H3.

**Actual Priority:** HIGH impact *when needed*, but frequency is lower than H2/H3 (only runs when ≥2 agents exist and share types). Should remain Phase 2.

### H5: Pre-Implementation Reporting — Should Be LOW, Not MEDIUM

**Rationale:** H5 is pure formatting — it takes H1's output and renders it as text. The analysis admits this: "~2 minutes per Scout run (formatting time)". If H1 doesn't exist yet, H5 is a no-op. This is polish, not functionality.

**Re-Ranking:** LOW (cosmetic, no functional value without H1)

### Missing HIGH-Priority Opportunity: Wave Agent Dependency Installation

**Gap:** The analysis ignores Wave agent ad-hoc behaviors entirely. From `wave-agent.md`:
- Agents run `go get`, `npm install`, `cargo fetch`, `pip install` when missing dependencies
- No guidance on when to install vs. report as blocker
- Failure mode: agents waste 5-10 minutes trying to auto-resolve dependency issues that require orchestrator intervention

**Proposed Opportunity: H6 (NEW):**

**Name:** Automated Dependency Conflict Detection

**Current behavior:** Wave agents discover missing dependencies at build time and attempt to install them ad-hoc. If installation fails (version conflicts, platform incompatibility), agents retry multiple times before reporting `status: blocked`.

**Determinism gap:**
- No pre-flight dependency check before launching agents
- Agents guess whether to install locally or report to orchestrator
- Dependency installation is not recorded in completion reports consistently

**Proposed solution:** `sawtools check-deps <impl-doc> --wave <N>`

Run before creating worktrees. Scans agent file ownership lists, extracts import statements, cross-references with project lock files (`go.sum`, `package-lock.json`, `Cargo.lock`). Returns:
```json
{
  "missing_deps": [
    {"agent": "A", "package": "github.com/foo/bar", "required_by": "pkg/auth.go"}
  ],
  "version_conflicts": [
    {"agents": ["A", "B"], "package": "lodash", "versions": ["4.17.0", "5.0.0"]}
  ],
  "recommendations": [
    "Install github.com/foo/bar before Wave 1 launch",
    "Resolve lodash version conflict (A requires 4.x, B requires 5.x)"
  ]
}
```

**Impact:** HIGH
- **Frequency:** ~40% of waves (agents adding new packages or upgrading versions)
- **Error risk:** Agents waste 5-10 min each on dependency thrashing
- **Time savings:** ~8-15 minutes per affected wave (pre-flight install vs. per-agent retry)
- **Reliability:** Catches version conflicts that cause flaky builds

---

## Missing Opportunities

### 1. Wave Agent Build Troubleshooting (HIGH Impact)

**Observed Behavior (from `wave-agent.md` Field 6):**
- Agents run verification gates (build + lint + test)
- Build failures trigger ad-hoc debugging: reading error logs, checking imports, adjusting flags
- No structured guidance on which build errors are fixable vs. should escalate

**Determinism Gap:**
- Agents retry builds with slight variations (adding flags, changing paths) hoping for success
- No catalog of "known build patterns" (e.g., Go: `cannot find package` → run `go mod tidy`)

**Proposed Tool:** `sawtools diagnose-build-failure <error-log> --language <lang>`

Ingests build error output, pattern-matches against known failure types, emits:
```yaml
diagnosis: "missing_import"
confidence: 0.95
fix: "go mod tidy && go build ./..."
rationale: "Error 'cannot find package X' indicates go.sum is stale"
auto_fixable: true
```

**Impact:** HIGH (applies to every agent with build failures, ~30% of agents)

### 2. Test Flake Detection (MEDIUM Impact)

**Observed Behavior:**
- Wave agents run focused tests (Field 6 verification gate)
- Flaky tests cause agents to report `status: partial` when work is actually complete
- No mechanism to distinguish flaky tests from real failures

**Proposed Tool:** `sawtools detect-flakes <test-output> --history <N-runs>`

Runs test suite N times, identifies tests that pass <100% of the time, emits:
```yaml
flaky_tests:
  - name: "TestAuthHandler_SessionTimeout"
    pass_rate: 0.6
    recommendation: "Skip with -skip flag or fix race condition"
```

**Impact:** MEDIUM (frequency ~15%, but high cost when it occurs — agent blocks unnecessarily)

### 3. Scaffold Agent Error Recovery (HIGH Impact)

**Observed Behavior (from `scaffold-agent.md`):**
- Scaffold Agent creates type files, runs build verification (E22)
- Build failures mark scaffold as `Status: FAILED`, blocking entire wave
- No guidance on how to fix scaffold build failures (wrong import path, syntax error, missing type field)

**Determinism Gap:**
- Scaffold Agent must manually debug build errors
- No structured catalog of "common scaffold errors" (e.g., Go: `undeclared name` → add missing import)

**Proposed Tool:** `sawtools validate-scaffold <scaffold-file> --impl-doc <path>`

Runs syntax check + import resolution + partial build before committing:
```yaml
validation:
  syntax: PASS
  imports: FAIL
    - missing: "context"
    - unused: "fmt"
  type_references: PASS
  build: FAIL
    - error: "undeclared name: Context"
    - fix: "Add 'import \"context\"' to scaffold file"
```

**Impact:** HIGH
- **Frequency:** ~50% of Scaffold Agent runs (type definitions often have import errors on first attempt)
- **Error risk:** Blocks entire wave if scaffold fails
- **Time savings:** ~10-15 minutes (Scaffold Agent rebuild iterations)

### 4. Orchestrator Pause-for-Review Decision Logic (MEDIUM Impact)

**Observed Behavior (from `saw-skill.md`):**
- Orchestrator asks user to review after Scout completes, after each wave completes
- No guidance on when to auto-proceed vs. pause
- `--auto` flag exists but is binary (all or nothing)

**Determinism Gap:**
- No risk-based review gating (e.g., "if 1 agent changed 1 file, auto-merge; if 5 agents changed 20 files, pause")
- No confidence scoring on wave success (e.g., "all agents PASS + no interface deviations = high confidence")

**Proposed Tool:** `sawtools assess-wave-risk <impl-doc> --wave <N>`

Analyzes completion reports, emits risk score:
```yaml
risk_level: "low"  # low | medium | high
factors:
  - all_agents_complete: true
  - interface_deviations: 0
  - out_of_scope_deps: 0
  - files_changed_count: 3
  - verification_failures: 0
recommendation: "Auto-merge (low risk)"
```

**Impact:** MEDIUM (workflow optimization, not correctness)

### 5. Cross-Repo Dependency Coordination (HIGH Impact — Recent Multi-Repo Work)

**Context (from MEMORY.md):**
- Recent work added `repo:` fields to file ownership table
- Cross-repo waves now supported
- No tooling for cross-repo dependency analysis

**Observed Behavior:**
- Scout manually traces dependencies across repo boundaries
- No automated way to detect "Agent A in repo X depends on type defined in repo Y"

**Proposed Tool:** `sawtools analyze-cross-repo-deps <impl-doc>`

Scans file ownership table for `repo:` fields, cross-references imports:
```yaml
cross_repo_deps:
  - source_agent: "A"
    source_repo: "scout-and-wave-web"
    target_repo: "scout-and-wave-go"
    dependency: "pkg/engine.Runner"
    wave_constraint: "Agent A must be in Wave ≥2 if Runner changes in Wave 1"
```

**Impact:** HIGH (applies to all cross-repo waves, new protocol feature with no tooling support yet)

---

## Implementation Risks

### H1: Suitability Gate Scoring

**Feasibility Concerns:**
1. **Pre-implementation scanning requires file content parsing** — not just path matching. For a 50-file codebase, reading every mentioned file to classify as DONE/PARTIAL/TODO takes ~30-60 seconds. The analysis claims "~5-10 minutes saved" but the tool itself might take 2-3 minutes to run.

2. **Parallelization value scoring needs build system profiling** — the schema includes `build_cycle_seconds: 45`. How is this measured? Run `cargo build` and time it? That's another 30-60 seconds. Total suitability analysis could take 3-5 minutes, not the instantaneous operation the ROI math assumes.

3. **Agent independence scoring (0.85)** — this is a graph theory problem (transitive closure on dep graph). Computationally cheap once H3 exists, but H3 doesn't exist yet.

**Maintenance Burden:**
- Every new CI system requires updating command extraction patterns
- Every language ecosystem requires separate import parsing logic
- Historical data for time estimation requires persistent storage + query layer

**Edge Cases:**
- **Dynamic imports (Python):** `importlib.import_module(variable)` — static analysis cannot detect these
- **Conditional compilation (Rust):** `#[cfg(feature = "foo")]` — file decomposition depends on feature flags
- **Generated code (Protocol Buffers):** Scout scans `.proto` files but agents modify generated `.pb.go` files — ownership table doesn't match actual file changes

### H2: Lint/Test Command Extraction

**Feasibility:** HIGH — this is pattern matching on known config formats.

**Edge Cases:**
1. **Makefile target chaining:** `test: build lint test-unit test-integration` — which target is "the test command"?
2. **CI matrix builds:** Different commands for different OS/architecture combos
3. **Monorepo workspace commands:** `npm test --workspace=packages/foo` vs. `npm test` (full repo)

**Maintenance Burden:** LOW to MEDIUM
- GitHub Actions YAML schema is stable
- Makefile patterns are ad-hoc but finite (20-30 common patterns cover 90% of projects)

### H3: Dependency Graph Generation

**Feasibility Concerns:**
1. **Language-specific parsers required** — Go: `go/parser`, Rust: `syn` crate, JavaScript: Babel/TypeScript parser, Python: `ast` module. Each has different AST format and import semantics.

2. **Transitive dependency explosion** — a 10-file change might have 50+ transitive dependencies. The analysis shows 3 nodes in the example output, but real-world graphs have 20-50 nodes for medium features.

3. **Cross-package type references** — Go: `pkg/auth.User` vs. TypeScript: `import {User} from '../auth'` — same semantic dependency, different syntactic patterns.

**Edge Cases:**
- **Circular dependencies:** A imports B imports C imports A — how to assign wave structure?
- **Conditional imports:** `if DEBUG: import foo` — should `foo` be in dep graph?
- **Runtime-only dependencies:** File A calls `exec()` to run binary from File B — static analysis misses this

**Maintenance Burden:** HIGH
- Must stay current with language syntax evolution (Go generics, Rust async, TypeScript decorators)
- Each language needs separate implementation + test suite

### H4: Scaffold Detection

**Feasibility:** MEDIUM — depends on H3's accuracy.

**Edge Cases:**
1. **Same type name, different semantics** — Agent A defines `AuthToken` (OAuth), Agent B defines `AuthToken` (JWT) — naming collision, not shared type
2. **Type refinement across waves** — Wave 1 defines `UserBasic`, Wave 2 adds `UserExtended` — should scaffold include both?
3. **Generic type parameters** — Go: `Response[T any]` used by 3 agents with different `T` — one scaffold or three?

**Maintenance Burden:** MEDIUM (logic complexity, but no external dependencies)

### H5: Pre-Implementation Reporting

**Risk:** None (pure formatting). If H1 doesn't exist, this is trivial.

---

## Metrics Critique

### 80% Time Reduction Projection (25 min → 5 min) — Overly Optimistic

**Claimed Breakdown:**
- Before: Scout time 15-25 min
- After Phase 1: Scout time 5-10 min (60% reduction)
- After Full Implementation: Scout time 3-5 min (80% reduction)

**Challenge 1: Tool Execution Overhead Not Accounted For**

The "after" numbers assume instantaneous tool execution. Reality:
- `sawtools analyze-deps` on a 50-file codebase: 30-60 seconds (must parse every file)
- `sawtools extract-commands` on complex CI config: 5-10 seconds
- `sawtools analyze-suitability` (runs both above + pre-impl scan): 2-3 minutes

**Revised Estimate:**
- Tool execution time: 3-4 minutes
- Scout reasoning time (synthesizing tool outputs): 3-5 minutes
- Total: **6-9 minutes** (not 3-5 minutes)

**Actual Reduction:** 25 min → 6-9 min = **64-76% reduction**, not 80%

**Challenge 2: Error Handling Overhead Ignored**

Tools fail. When they do, Scout must:
1. Interpret error message
2. Decide whether to retry with adjusted params or fall back to manual analysis
3. Re-run the tool

Conservatively, tool failures add 2-3 minutes per Scout run (10-20% of runs encounter tool errors).

**Adjusted Reduction:** 64-76% → **50-65% realistic reduction**

**Challenge 3: Pre-Implementation Scanning Slowdown**

The analysis claims pre-impl scanning saves 25 minutes by detecting DONE items. But the scanning itself requires:
- Reading 50+ files mentioned in audit report
- Parsing each file to classify as DONE/PARTIAL/TODO
- This takes 3-5 minutes

**Net Savings:** 25 minutes saved - 4 minutes spent scanning = **21 minutes net** (not 25)

**Challenge 4: Assumes Tools Never Wrong**

If `sawtools analyze-deps` produces an incorrect dep graph (missed import, wrong direction), Scout must manually verify and correct. This adds 5-10 minutes of "spot-check" time to every Scout run.

**Conservative Estimate:** Spot-checking adds 2-3 minutes average (accounting for 20-30% of runs needing corrections).

**Final Realistic Projection:**

| Metric | Before | After Phase 1 | After Full |
|--------|--------|---------------|------------|
| Scout time (min) | 15-25 | 10-14 | 8-12 |
| Reduction (%) | — | 40-56% | 52-68% |

**Conclusion:** 50-65% reduction is achievable. 80% is fantasy.

### Suitability Gate Variance: 30% → <5% — Plausible but Unverified

**Claim:** "Suitability gate variance: ~30% between runs (subjective scoring)"

**Question:** Where does 30% come from? No data is cited. Is this:
- 30% of runs flip SUITABLE ↔ NOT_SUITABLE?
- 30% variance in parallelization value score (e.g., score 7 vs. score 10)?
- 30% variance in time estimates?

**If "flip rate":** 30% flip rate would mean 1 in 3 identical features get opposite verdicts — this seems implausibly high. If Scout flips verdicts this often, the suitability gate itself is broken, not just non-deterministic.

**If "score variance":** 30% variance in a 1-10 score (±3 points) is plausible for subjective judgment, but automated scoring won't reduce this to <5% — it will reduce it to measurement error (sensor precision), which is ~10-15% for graph metrics.

**Revised Target:** <10-15% variance is realistic. <5% requires perfect static analysis (unachievable).

---

## Phase Ordering Recommendation

**Original Roadmap:**

**Phase 1:** H3 (deps) → H2 (commands) → H1 (suitability)
**Phase 2:** H4 (scaffolds) + H5 (reporting) + M2 (cascades)

**Problem:** H1 depends on H2+H3, but is in same phase. This serializes Phase 1 unnecessarily.

**Revised Roadmap:**

### Phase 1: Foundation (Parallel Work)
1. **H2: Command Extraction** (10-15 hours) — no dependencies
2. **H3: Dep Graph Generation** (20-25 hours) — no dependencies

**Rationale:** H2 and H3 can be built in parallel. Both are self-contained. Combined effort: 30-40 hours.

### Phase 2: Scout Automation (Sequential Work)
3. **H1a: Pre-Implementation Scanning** (15-20 hours) — depends on H3 for file mapping
4. **H4: Scaffold Detection** (12-15 hours) — depends on H3 for cross-boundary detection
5. **M2: Cascade Detection** (8-10 hours) — depends on H3 for type reference search

**Rationale:** All three tools consume H3's output. Can be built in parallel after H3 completes.

### Phase 3: Wave Agent Automation (New)
6. **H6 (NEW): Dependency Conflict Detection** (10-12 hours)
7. **H7 (NEW): Build Failure Diagnosis** (12-15 hours)
8. **H8 (NEW): Scaffold Validation** (8-10 hours)

**Rationale:** These are independent of Scout tools. High ROI (apply to every wave, not just Scout phase).

### Phase 4: Polish
9. **M1: Agent ID Assignment** (3-5 hours)
10. **M3: Repo Context Derivation** (3-5 hours)
11. **M4: Verification Gate Templates** (5-8 hours) — depends on H2
12. **H5: Pre-Implementation Reporting** (3-5 hours) — depends on H1a
13. **M5: Manifest Size Estimation** (3-5 hours)
14. **L3: Commit Message Templates** (2-3 hours)

**Total Effort:**
- Phase 1: 30-40 hours
- Phase 2: 35-45 hours
- Phase 3: 30-37 hours (NEW)
- Phase 4: 19-31 hours

**Grand Total:** 114-153 hours (vs. original estimate of 40-60 hours)

**Why the Discrepancy?**
- Original estimate omitted Wave/Scaffold agent tools entirely
- H1 is actually 3-4 tools, not 1
- Cross-language support for H3 requires 4x the effort (Go + Rust + JS + Python parsers)

---

## Command Interdependencies

**Original Dependencies Identified:**
- H2 → H1 (command extraction feeds suitability scoring)
- H3 → H4 (dep graph feeds scaffold detection)

**Additional Dependencies:**

### H3 → H1a (Pre-Implementation Scanning)
- H1a must locate files mentioned in audit reports
- H3's file ownership mapping accelerates this (otherwise Scout greps the entire repo)

### H3 → M2 (Cascade Detection)
- M2 searches for type references across codebase
- H3's import graph identifies candidate files to search (otherwise M2 scans every file)

### H2 → M4 (Verification Gate Templates)
- M4 formats commands extracted by H2
- Cannot exist without H2

### H1a → H5 (Pre-Implementation Reporting)
- H5 formats H1a's output
- Pure dependency (H5 is a no-op without H1a)

### H6 (Dependency Conflict Detection) → Standalone
- Reads file ownership table, parses imports, cross-references lock files
- No dependencies on other tools

### H7 (Build Failure Diagnosis) → Standalone
- Pattern-matches build error logs
- No dependencies

### H8 (Scaffold Validation) → Depends on H2 (Command Extraction)
- Must run build commands to verify scaffolds
- Uses H2's extracted `build_command`

**Revised Dependency Graph:**

```
Phase 1 (Parallel):
  H2 (commands)
  H3 (deps)

Phase 2 (After H3):
  H1a (pre-impl scan) ← H3
  H4 (scaffolds) ← H3
  M2 (cascades) ← H3

Phase 3 (Parallel):
  H6 (dep conflicts) — standalone
  H7 (build diagnosis) — standalone
  H8 (scaffold validation) ← H2

Phase 4 (Polish):
  M4 (verification templates) ← H2
  H5 (pre-impl report) ← H1a
  M1, M3, M5, L3 — standalone
```

**Critical Path:** H3 → {H1a, H4, M2} (Phase 2 bottlenecked on H3 completion)

---

## Net Assessment

### Should the project proceed with Phase 1?

**YES**, with modifications:

**Proceed Immediately:**
- H2 (Command Extraction) — clear scope, high ROI, no dependencies
- H3 (Dep Graph Generation) — largest time sink in Scout phase, foundational for 4 downstream tools

**Defer to Phase 2:**
- H1 (Suitability Scoring) — split into H1a/H1b/H1c, only build H1a (pre-impl scanning) after H3 completes

**Add to Roadmap (Phase 3):**
- H6: Dependency Conflict Detection (Wave agent failure mode, not addressed in original analysis)
- H7: Build Failure Diagnosis (applies to every agent with build errors, ~30% of agents)
- H8: Scaffold Validation (Scaffold Agent failure mode, blocks entire wave when it occurs)

**De-Prioritize:**
- H5 (Pre-Implementation Reporting) — cosmetic, no functional value
- M5 (Manifest Size Estimation) — edge case, low frequency

### What needs to change first?

**Before starting Phase 1 implementation:**

1. **Revise H1 scope** — split into 4 separate tools (pre-impl scanning, time estimation, parallelization scoring, verdict synthesis). Only commit to building pre-impl scanning in Phase 2.

2. **Add Wave/Scaffold agent opportunities** — the original analysis is Scout-centric. Wave agents and Scaffold Agent have determinism gaps too. Add H6/H7/H8 to roadmap.

3. **Revise ROI projections** — 80% time reduction is unrealistic. Target 50-65% reduction after accounting for tool execution overhead and error handling.

4. **Add cross-language scope to H3** — the analysis assumes one language. Real projects are polyglot (Go backend + TypeScript frontend). H3 must support 3-4 languages to be useful, which triples implementation time.

5. **Add error handling effort estimates** — tools fail. Scout must interpret errors and decide whether to retry or fall back to manual analysis. Add 20-30% overhead to all tool execution time estimates.

**Confidence Assessment:**

- **H2 (Command Extraction):** HIGH confidence — pattern matching on known formats, finite scope
- **H3 (Dep Graph Generation):** MEDIUM confidence — language-specific parsers are complex, edge cases abound
- **H1a (Pre-Implementation Scanning):** MEDIUM confidence — file classification heuristics are fuzzy
- **H6 (Dependency Conflicts):** HIGH confidence — lock file parsing is deterministic
- **H7 (Build Diagnosis):** LOW confidence — error message patterns are language-specific and evolve over time
- **H8 (Scaffold Validation):** HIGH confidence — wrapper around existing build commands

**Go / No-Go for Phase 1:**

**GO** — Build H2 + H3. These are foundational, have clear ROI, and unlock 4 downstream tools. Accept 50-65% Scout time reduction as realistic target (not 80%). Plan for 30-40 hours of implementation effort (not 25 hours).

**DEFER** — H1 (suitability scoring) until Phase 2. It's too large, too dependent on H2/H3, and ROI is overstated (time estimation requires historical data collection, which doesn't exist yet).

**ADD** — H6/H7/H8 (Wave/Scaffold agent tools) to roadmap. These have equal or higher ROI than Scout tools because they apply to every wave, not just the Scout phase.
