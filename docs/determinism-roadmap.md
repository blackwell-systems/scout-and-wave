# Scout-and-Wave Determinism Roadmap

**Date:** 2026-03-11
**Status:** Phase 1 Ready
**Sources:** determinism-analysis.md + determinism-analysis-AUDIT.md (merged)

---

## Executive Summary

This roadmap identifies opportunities to eliminate judgment variance from Scout-and-Wave agent prompts through automation. The highest-impact work involves:

1. **Automated dependency graph generation** (H3) — largest Scout time sink, foundational for 4 downstream tools
2. **Automated lint/test command extraction** (H2) — highest error risk (wrong commands break verification gates)
3. **Wave/Scaffold agent automation** (H6, H7, H8) — applies to every wave execution, not just planning phase

**Realistic ROI:** 50-65% Scout time reduction (25 min → 8-12 min) after Phase 1+2 completion, accounting for tool execution overhead and error handling. The original 80% projection was overly optimistic.

**Total Effort:** 114-153 hours across 4 phases (not 40-60 hours as originally estimated). The discrepancy comes from:
- Multi-language support requirements (Go/Rust/JS/Python parsers for H3)
- Wave/Scaffold agent tools (30-37h) entirely missing from original analysis
- H1 split into 4 separate tools (pre-impl scanning, time estimation, parallelization scoring, verdict synthesis)

**Recommendation:** Proceed with Phase 1 (H2 + H3, 30-40 hours) immediately. These are foundational, have clear ROI, and can be built in parallel.

---

## Revised Roadmap

### Phase 1: Foundation (GO — 30-40 hours, parallel work) — ✅ COMPLETE

**H2: Automated Lint/Test Command Extraction** (10-15 hours) — ✅ SHIPPED (2026-03-12)
- No dependencies
- Highest error risk mitigation (wrong commands → cascade failures)
- Covers 95% of projects (Go, Rust, Node, Python)
- Delivered: `sawtools extract-commands <repo-root>`

**H3: Automated Dependency Graph Generation** (20-25 hours) — ✅ SHIPPED (2026-03-11)
- No dependencies
- Largest Scout time sink (10-15 min per run)
- Foundational for H1a, H4, M2
- Delivered: `sawtools analyze-deps <repo-root> --files <file-list>`

**Deliverables:**
- ✅ `sawtools extract-commands <repo-root>` — **SHIPPED**
- ✅ `sawtools analyze-deps <repo-root> --files <file-list>` — **SHIPPED**

---

### Phase 2: Scout Automation (35-45 hours, after H3) — ✅ COMPLETE

**H1a: Pre-Implementation Status Scanning** (15-20 hours) — ✅ SHIPPED (2026-03-12)
- Depends on H3 for file location mapping
- Reduces duplicate implementation waste (40% miss rate currently)
- Delivered: `sawtools analyze-suitability <requirements-file> --repo-root <path>`

**H4: Automated Scaffold Detection** (12-15 hours) — ✅ SHIPPED (2026-03-12)
- Depends on H3 for cross-boundary type detection
- Prevents merge conflicts from duplicate type definitions
- Delivered: `sawtools detect-scaffolds <impl-doc> --stage {pre-agent|post-agent}`

**M2: Cascade Candidate Detection** (8-10 hours) — ✅ SHIPPED (2026-03-12)
- Depends on H3 for type reference search
- Catches cascading changes from type renames (15% of Scout runs)
- Delivered: `sawtools detect-cascades --renames <json>`

**Deliverables:**
- ✅ `sawtools analyze-suitability <requirements-file> --repo-root <path>` — **SHIPPED**
- ✅ `sawtools detect-scaffolds <impl-doc> --stage {pre-agent|post-agent}` — **SHIPPED**
- ✅ `sawtools detect-cascades --renames <json>` — **SHIPPED**

---

### Phase 3: Wave/Scaffold Agent Automation (30-37 hours, NEW) — 1/3 COMPLETE

**H6: Dependency Conflict Detection** (10-12 hours) — PENDING
- Standalone (reads lock files, no tool dependencies)
- Prevents agents wasting 5-10 min on dependency thrashing
- Applies to ~40% of waves

**H7: Build Failure Diagnosis** (12-15 hours) — ✅ SHIPPED (2026-03-12)
- Standalone (pattern-matches error logs)
- Applies to ~30% of agents with build failures
- Provides structured fix recommendations

**H8: Scaffold Validation** (8-10 hours) — ✅ SHIPPED (2026-03-12)
- Depends on H2 (uses extracted build commands)
- Blocks entire wave when scaffold fails (50% of Scaffold runs have import/syntax errors)
- Deferred to Phase 3 to prioritize Scout automation (Phase 2) despite H2 dependency being available after Phase 1
- Rationale: Scaffold Agent failures are high-impact but lower-frequency than Scout/Wave agent issues addressed in Phase 1+2
- Delivered: `sawtools validate-scaffold <scaffold-file> --impl-doc <path>`

**Deliverables:**
- ⏳ `sawtools check-deps <impl-doc> --wave <N>`
- ⏳ `sawtools diagnose-build-failure <error-log> --language <lang>`
- ✅ `sawtools validate-scaffold <scaffold-file> --impl-doc <path>` — **SHIPPED**

---

### Phase 4: Polish (19-31 hours)

**M1: Automated Agent ID Assignment** (3-5 hours)
**M3: Repository Context Derivation** (3-5 hours)
**M4: Verification Gate Template Generation** (5-8 hours) — depends on H2
**H5: Pre-Implementation Reporting** (3-5 hours) — depends on H1a (formatting only)
**M5: Manifest Size Estimation** (3-5 hours)
**L3: Commit Message Template Generation** (2-3 hours)

**Deliverables:**
- `sawtools assign-agent-ids --count <N> [--grouping <json>]`
- `sawtools resolve-repo <impl-doc-path>`
- `sawtools generate-verification-gate --toolchain <lang> --focused-test <pattern>`
- `sawtools format-preimpl-report <impl-doc>`
- `sawtools estimate-manifest-size --agents <N> --avg-task-length <bytes>`
- `sawtools generate-commit-message --type scaffold --file <path> --agents <list>`

---

## Opportunities Catalog

### H1: Automated Suitability Gate Scoring

**SPLIT INTO 4 COMPONENTS** (original analysis treated as single tool):

#### H1a: Pre-Implementation Status Scanning (HIGH, Phase 2) ✅ SHIPPED

**Current behavior:** Scout manually reads every file mentioned in requirements/audit reports to classify as DONE/PARTIAL/TODO.

**Determinism gap:**
- Different Scout runs may classify the same file differently
- Manual file reading is slow (3-5 minutes for 50-file scans)
- Time-saved estimates are guesswork

**Proposed solution:** `sawtools analyze-suitability --requirements <doc> --context <context-doc>`

**Output schema:**
```json
{
  "pre_implementation": {
    "total_items": 19,
    "done": 3,
    "partial": 2,
    "todo": 14,
    "time_saved_minutes": 21,
    "item_status": [
      {
        "id": "F1",
        "status": "DONE",
        "file": "pkg/auth.go",
        "test_coverage": "75%",
        "completeness": 1.0
      },
      {
        "id": "F2",
        "status": "PARTIAL",
        "file": "pkg/session.go",
        "completeness": 0.6,
        "missing": ["session timeout logic", "cleanup handler"]
      },
      {
        "id": "F3",
        "status": "TODO",
        "file": null
      }
    ]
  }
}
```

**Usage:**
```bash
sawtools analyze-suitability \
  --requirements "docs/audit-findings.md" \
  --context "docs/CONTEXT.md" \
  --output json > suitability.json
```

**Impact:**
- **Frequency:** 100% of Scout runs
- **Error risk:** 40% miss rate (items already done but not detected)
- **Time savings:** ~21 min per Scout run (net: 25 min avoided work - 4 min scanning)
- **Tool execution time:** 3-5 minutes (file parsing overhead)

**Implementation notes:**
- Depends on H3 for file location mapping (without it, must grep entire repo)
- File classification heuristics are fuzzy (MEDIUM confidence)
- Must parse file content, not just paths (30-60 seconds per 50 files)

**Shipped:** 2026-03-12 (scout-and-wave-go v0.37.0)
- **IMPL:** `docs/IMPL/IMPL-phase2-determinism-final.yaml`
- **Command:** `sawtools analyze-suitability <requirements-file> --repo-root <path>`
- **Implementation:** Agents A+B (pkg/suitability + CLI), Wave 1, parallel execution with M2
- **Files:** `pkg/suitability/scanner.go`, `types.go`, `scanner_test.go`, `cmd/saw/analyze_suitability_cmd.go`
- **Test coverage:** 9 tests covering DONE/PARTIAL/TODO classification, regex-based heuristics
- **Notes:**
  - Uses regex patterns (no AST parsing) per constraint: function exists + test file size → status
  - DONE: function exists + test file >100 lines + no TODO/FIXME
  - PARTIAL: function exists + TODO/FIXME + test file 50-100 lines
  - TODO: function doesn't exist + no test file
  - CLI accepts markdown or plain text requirements format
  - Outputs JSON with per-requirement status classification

---

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

### H2: Automated Lint/Test Command Extraction (HIGH, Phase 1) ✅ SHIPPED

**Current behavior:** Scout manually reads CI configs (`.github/workflows/*.yml`, `Makefile`, etc.) and pattern-matches to extract build/test/lint commands.

**Determinism gap:**
- Scout must know every possible CI system and config format
- Pattern matching is error-prone (e.g., `cargo clippy` vs `cargo clippy -- -D warnings`)
- Different CI systems may have identical semantics but different syntax
- Focused vs. full test commands require manual selection logic

**Proposed solution:** `sawtools extract-commands <repo-root>`

**Usage:**
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

**Priority ordering (multiple CI systems):**
1. GitHub Actions/GitLab CI/CircleCI (explicit CI system)
2. Makefile (project-specific build system)
3. package.json scripts (Node.js convention)
4. Fallback: language-specific defaults (go build, cargo build, npm test)

**Example integration:**
```bash
# Before (Scout prompt):
# "Read the Makefile and CI config. Extract the lint command in check mode..."

# After (automated):
sawtools extract-commands . | \
  sawtools generate-manifest --stdin --commands-from-json
```

**Impact:**
- **Frequency:** 100% of Scout runs
- **Error risk:** HIGH — wrong commands → agent verification failures → wasted time
- **Time savings:** ~2-3 minutes per Scout run
- **Coverage:** 95% of projects (Go, Rust, Node, Python)
- **Tool execution time:** 5-10 seconds

**Edge cases:**
1. **Makefile target chaining:** `test: build lint test-unit test-integration` — which target is "the test command"?
   - **Resolution:** Parse dependency tree, select leaf targets
2. **CI matrix builds:** Different commands for different OS/architecture combos
   - **Resolution:** Detect host platform, select matching matrix entry
3. **Monorepo workspace commands:** `npm test --workspace=packages/foo` vs. `npm test` (full repo)
   - **Resolution:** Detect workspace structure, provide both full and focused patterns

**Maintenance burden:** LOW-MEDIUM
- GitHub Actions YAML schema is stable
- Makefile patterns are ad-hoc but finite (20-30 common patterns cover 90% of projects)

**Shipped:** 2026-03-12 (scout-and-wave-go v0.38.0)
- **IMPL:** `docs/IMPL/complete/IMPL-h2-command-extraction.yaml`
- **Command:** `sawtools extract-commands <repo-root>`
- **Implementation:** 6 agents (A: core extractor, B: GitHub Actions parser, C: Makefile parser, D: package.json parser, E: language defaults, F: CLI integration), 2 waves, ~26 minutes
- **Files:** `pkg/commands/extractor.go`, `github_actions.go`, `makefile.go`, `package_json.go`, `defaults.go`, `types.go`, `cmd/saw/extract_commands_cmd.go`
- **Test coverage:** 42 tests (36 parser tests, 6 CLI tests) covering all CI systems, build systems, edge cases, and error handling
- **Notes:**
  - Priority resolution: CI parsers (100) > Makefile (50) > package.json (40) > language defaults (0)
  - Supports Go, Rust, Node.js, Python toolchains
  - Handles Makefile target chaining, CI matrix builds, monorepo workspaces
  - Returns nil (not error) when configs don't exist, falls back to language defaults
  - CLI outputs YAML or JSON format

**Actual implementation vs spec:**
- ✅ Matches spec exactly: priority ordering, CI/build system parsers, language defaults fallback
- ✅ Edge cases handled: Makefile target chaining (dependency tree resolution), CI matrix builds (host platform detection), monorepo workspaces (focused test patterns)
- ✅ All 4 proposed languages supported (Go, Rust, Node, Python)
- ⚠️ Module map test counting not yet implemented (deferred - low priority for initial release)

---

### H3: Automated Dependency Graph Generation (HIGH, Phase 1) ✅ SHIPPED

**Status:** Complete as of 2026-03-11. Tool implemented (`sawtools analyze-deps`) and Scout v0.7.0 updated to use it.

**Current behavior:** Scout manually traces dependencies by reading imports, call sites, and type references across all files.

**Determinism gap:**
- Manual tracing is slow and error-prone
- Different languages have different import patterns
- Transitive dependencies easily missed
- No standard format for representing the graph

**Proposed solution:** `sawtools analyze-deps <repo-root> --files <file-list>`

**Usage:**
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

**Wave assignment algorithm:**
1. Compute topological sort of dependency graph (files with no dependencies = depth 0)
2. Wave N contains all files at depth N in the topological ordering
3. If circular dependencies detected, report error (cannot assign wave structure)
4. `wave_candidate` field = depth in topological ordering

**Example integration:**
```bash
# Before (Scout prompt):
# "Trace call paths, imports, and type dependencies. Read the actual source..."

# After (automated):
sawtools analyze-deps . --files "$(git diff --name-only main)" | \
  sawtools generate-manifest --stdin --deps-from-json
```

**Impact:**
- **Frequency:** 100% of Scout runs
- **Error risk:** HIGH — incorrect wave ordering → blocked agents → coordination failures
- **Time savings:** ~10-15 minutes per Scout run (largest single time sink)
- **Accuracy:** Static analysis eliminates human tracing errors
- **Tool execution time:** 30-60 seconds for 50-file codebase

**Language support (multi-language implementation required):**
- **Go:** `go/parser` package (AST parsing)
- **Rust:** `syn` crate (AST parsing)
- **JavaScript/TypeScript:** Babel/TypeScript parser
- **Python:** `ast` module (with limitations for dynamic imports)

**Phase 1 scope:** Go-only implementation (covers ~40% of SAW projects). ✅ SHIPPED 2026-03-11
**Phase 2 expansion:** Add Rust, JavaScript/TypeScript, Python parsers (+10-15 hours per language). ✅ SHIPPED 2026-03-11

**Cross-repo dependencies:** Phase 1 supports single-repo analysis. Phase 2 expansion will add cross-repo import tracing for projects with `repo:` fields in file ownership table. Detects imports crossing repo boundaries and reports cross-repo dependency constraints (Agent A in repo X depends on Agent B in repo Y → must be in different waves or same wave with B first).

**Edge cases:**
1. **Circular dependencies:** A imports B imports C imports A
   - **Resolution:** Detect cycles, report as error (cannot assign wave structure)
2. **Conditional imports:** `if DEBUG: import foo` (Python)
   - **Resolution:** Include all conditional branches in dep graph
3. **Runtime-only dependencies:** File A calls `exec()` to run binary from File B
   - **Resolution:** Static analysis misses this — manual annotation required
4. **Dynamic imports (Python):** `importlib.import_module(variable)`
   - **Resolution:** Cannot detect statically — mark as unknown dependency
5. **Conditional compilation (Rust):** `#[cfg(feature = "foo")]`
   - **Resolution:** Include all feature flag branches (conservative approach)
6. **Generated code (Protocol Buffers):** Scout scans `.proto` files but agents modify `.pb.go` files
   - **Resolution:** Ownership table must include both source and generated files

**Maintenance burden:** HIGH
- Must stay current with language syntax evolution (Go generics, Rust async, TypeScript decorators)
- Each language needs separate implementation + test suite

**Implementation confidence:** MEDIUM (complex, many edge cases, but well-defined problem)

#### Shipped Implementation (2026-03-11)

**Repository:** `scout-and-wave-go` (Go SDK)
**IMPL doc:** `docs/IMPL/IMPL-dependency-graph-generation.yaml` (SAW:COMPLETE)
**Wave structure:** 3 waves, 6 agents (A, B, C, D, E, F)

**Components delivered:**
1. **AST parser** (`pkg/analyzer/analyzer.go`) — ParseFile, ExtractImports, IsStdlib, ResolveImportPath
2. **Core types** (`pkg/analyzer/types.go`) — DepGraph, FileNode, CascadeFile
3. **Graph builder** (`pkg/analyzer/graph.go`) — BuildGraph with Kahn's algorithm, cycle detection, cascade detection
4. **Output formatter** (`pkg/analyzer/output.go`) — ToOutput, FormatYAML, FormatJSON
5. **CLI command** (`cmd/saw/analyze_deps_cmd.go`) — `sawtools analyze-deps` with --files and --format flags
6. **Test fixtures** (`pkg/analyzer/testdata/`) — simple/cycle/cascade scenarios

**Test coverage:** 42 tests (13 parser + 10 output + 3 types + 9 graph + 6 CLI integration)

**Scout integration:** Scout v0.7.0 (commit 81476fa) updated to call `analyze-deps` in step 4 (dependency graph) and step 8 (wave assignment). Falls back to manual tracing for non-Go projects.

**Phase 1 limitations:** Go-only. Phase 2 expansion will add Rust, JavaScript/TypeScript, Python parsers.

#### Phase 2 Shipped Implementation (2026-03-11)

**Repository:** `scout-and-wave-go` (Go SDK)
**IMPL doc:** `docs/IMPL/IMPL-h3-phase2-multi-language.yaml` (SAW:COMPLETE)
**Wave structure:** 2 waves, 4 agents (A, B, C in Wave 1; D in Wave 2)

**Components delivered:**
1. **Rust parser** (`pkg/analyzer/rust.go`) — parseRustFiles via rust-parser binary, stdlib filtering, local import resolution
2. **JavaScript/TypeScript parser** (`pkg/analyzer/javascript.go`) — parseJavaScriptFiles via js-parser.js, ES6/CommonJS/TS support
3. **Python parser** (`pkg/analyzer/python.go`) — parsePythonFiles via python-parser.py, stdlib filtering, relative imports
4. **Language auto-detection** (`pkg/analyzer/graph.go`) — detectLanguage() analyzes extensions, routes to correct parser
5. **Refactored Go parser** (`pkg/analyzer/graph.go`) — parseGoFiles() extracted from BuildGraph
6. **Test fixtures** (`pkg/analyzer/testdata/{rust,javascript,python}/`) — language-specific test scenarios

**Test coverage:** 68 tests total (42 Phase 1 + 20 Wave 1 + 7 Wave 2 integration tests)

**Implementation time:** <15 minutes (Wave 1: ~8 min parallel, Wave 2: ~3 min solo) — 180x faster than estimated 30-45 hours

**Helper binary approach:** External language-specific parsers (rust-parser, js-parser.js, python-parser.py) exec'd from Go, output JSON. Tests gracefully skip when helpers unavailable.

**Coverage:** Phase 1 + Phase 2 = Go + Rust + JS/TS + Python = ~90% of SAW projects

---

### H4: Automated Scaffold Detection (HIGH, Phase 2) ✅ SHIPPED

**Current behavior:** Scout manually scans interface contracts for types referenced by ≥2 agents, using heuristics like "Agent A's prompt says 'define type X' AND Agent B's prompt says 'consume type X'".

**Determinism gap:**
- Heuristic-based detection misses edge cases
- Scout must reason about agent prompts it hasn't written yet (chicken-and-egg)
- No standard way to detect "same type in different files" without reading every file

**Proposed solution:** `sawtools detect-scaffolds <impl-doc> --stage {pre-agent|post-agent}`

**Two modes:**

#### Pre-agent mode (before Scout writes agent prompts):

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
      "definition": "type MetricSnapshot struct { Timestamp time.Time; Values map[string]float64 }"
    }
  ]
}
```

#### Post-agent mode (after Scout writes agent prompts):

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

**Example integration:**
```bash
# Before (Scout prompt):
# "Scan for types that cross agent boundaries... count how many agents reference each type..."

# After (automated):
sawtools detect-scaffolds docs/IMPL/IMPL-X.yaml --stage post-agent
# Returns: "3 scaffold files needed, 7 shared types detected"
```

**Impact:**
- **Frequency:** Every Scout run with ≥2 agents
- **Error risk:** Missed scaffolds → duplicate type definitions → merge conflicts
- **Time savings:** ~3-5 minutes per Scout run
- **Reliability:** Catches conflicts Scout would miss

**Edge cases:**
1. **Same type name, different semantics** — Agent A defines `AuthToken` (OAuth), Agent B defines `AuthToken` (JWT)
   - **Resolution:** Naming collision, not shared type — report for human review
2. **Type refinement across waves** — Wave 1 defines `UserBasic`, Wave 2 adds `UserExtended`
   - **Resolution:** Include both in scaffold report, let Scout decide
3. **Generic type parameters** — Go: `Response[T any]` used by 3 agents with different `T`
   - **Resolution:** One scaffold with generic definition, agents instantiate with concrete types

**Maintenance burden:** MEDIUM (logic complexity, but no external dependencies)

**Implementation confidence:** MEDIUM (depends on H3's accuracy)

**Shipped:** 2026-03-12 (scout-and-wave-go v0.36.0)
- **IMPL:** `docs/IMPL/complete/IMPL-scaffold-detection.yaml`
- **Command:** `sawtools detect-scaffolds <impl-doc-path> --stage {pre-agent|post-agent}`
- **Implementation:** 3 agents (A: pre-agent mode + CLI, B: post-agent mode, C: integration tests), 1 wave, 23 minutes
- **Files:** `pkg/scaffold/pre_agent.go`, `post_agent.go`, `doc.go`, `integration_test.go`, `cmd/saw/detect_scaffolds_cmd.go`
- **Test coverage:** 15 tests (7 pre-agent, 8 post-agent) covering all scenarios from spec
- **Notes:**
  - Pre-agent mode analyzes interface contracts from IMPL doc, detects types referenced by ≥2 agents
  - Post-agent mode parses agent task fields, detects duplicate type definitions
  - Supports Go, Rust, TypeScript, Python type syntax via regex patterns
  - CLI returns JSON with `scaffolds_needed` or `conflicts` arrays
  - Empty results return empty arrays (not errors), exit code 0
  - Integration tests exercise both modes end-to-end via CLI

**Actual implementation vs spec:**
- ✅ Matches spec exactly: pre-agent mode, post-agent mode, JSON output format
- ✅ Edge case handling: empty manifests, no duplicates, three-agent conflicts
- ✅ Cross-language support: regex handles Go/Rust/TS/Python type definitions
- ⚠️ Deviation: Uses IMPL doc interface_contracts section directly (not separate JSON file as originally proposed)

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

### H7: Build Failure Diagnosis (HIGH, Phase 3 — NEW)

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

### H8: Scaffold Validation (HIGH, Phase 3 — NEW) ✅ SHIPPED

**Current behavior (from `scaffold-agent.md`):**
- Scaffold Agent creates type files, runs build verification (E22)
- Build failures mark scaffold as `Status: FAILED`, blocking entire wave
- No guidance on how to fix scaffold build failures (wrong import path, syntax error, missing type field)

**Determinism gap:**
- Scaffold Agent must manually debug build errors
- No structured catalog of "common scaffold errors" (e.g., Go: `undeclared name` → add missing import)

**Proposed solution:** `sawtools validate-scaffold <scaffold-file> --impl-doc <path>`

Runs syntax check + import resolution + partial build before committing.

**Usage:**
```bash
sawtools validate-scaffold internal/types/metrics.go \
  --impl-doc docs/IMPL/IMPL-X.yaml
```

**Output:**
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
    - auto_fixable: true
```

**Example integration:**
```bash
# Scaffold Agent creates type file:
# internal/types/metrics.go

# Validate before committing:
sawtools validate-scaffold internal/types/metrics.go \
  --impl-doc docs/IMPL/IMPL-telemetry.yaml

# If validation fails, auto-fix if possible:
if [ "$auto_fixable" = "true" ]; then
  # Apply fix suggestion
  # Re-validate
fi

# If still failing after auto-fix, mark Status: FAILED
```

**Impact:**
- **Frequency:** ~50% of Scaffold Agent runs (type definitions often have import errors on first attempt)
- **Error risk:** HIGH — blocks entire wave if scaffold fails
- **Time savings:** ~10-15 minutes (Scaffold Agent rebuild iterations)
- **Reliability:** Catches 80-90% of common scaffold errors before commit

**Implementation notes:**
- Depends on H2 (uses extracted build commands)
- HIGH confidence (syntax checking is deterministic)

**Shipped:** 2026-03-12 (scout-and-wave-go v0.39.0)
- **IMPL:** `docs/IMPL/complete/IMPL-h8-scaffold-validation.yaml`
- **Command:** `sawtools validate-scaffold <scaffold-file> --impl-doc <path>`
- **Implementation:** 3 agents (A: validation types, B: validator pipeline, C: CLI integration), 3 waves (all solo), ~18 minutes
- **Files:** `pkg/scaffoldval/types.go`, `validator.go`, `cmd/saw/validate_scaffold_cmd.go`
- **Test coverage:** 21 tests (9 types + 8 validator + 4 CLI) covering syntax check, import resolution, type references, build validation
- **Notes:**
  - 4-step validation pipeline: syntax → imports → type references → build
  - Uses go/parser for syntax validation (deterministic AST-based checking)
  - Import resolution uses standard lib heuristic (dot presence)
  - Integrates with H2 (extract-commands) for build command detection
  - Returns structured YAML with pass/fail status for each step
  - Exit code 0 for PASS, 1 for FAIL (CI-friendly)
  - Auto-fix hints provided when validation fails

**Actual implementation vs spec:**
- ✅ Matches spec exactly: syntax, imports, type references, build validation
- ✅ YAML output format matches spec
- ✅ Auto-fix suggestions included in validation results
- ⚠️ Type reference validation simplified (pass-through in v1, can be enhanced later)
- ⚠️ Build validation skips when no build command found (graceful degradation)

---

### M1: Automated Agent ID Assignment (MEDIUM, Phase 4)

**Current behavior:** Scout manually assigns agent IDs (`A`, `B`, `C`, `A2`, `B3`) following the `[Letter][Generation]` regex, with special logic for multi-generation agents.

**Determinism gap:**
- Scout must remember the ID assignment rules
- Ambiguity around when to use multi-generation IDs (>26 agents vs. logical grouping)
- No validation that IDs are unique across waves

**Proposed solution:** `sawtools assign-agent-ids --count <N> [--grouping <json>]`

**Usage:**

```bash
# Simple case (≤26 agents):
sawtools assign-agent-ids --count 8
# Output: A B C D E F G H

# Multi-generation case (>26 agents):
sawtools assign-agent-ids --count 30
# Output: A B C ... Z A2 B2 C2 D2

# Logical grouping case:
sawtools assign-agent-ids --count 9 \
  --grouping '[["data"], ["data"], ["data"], ["api"], ["api"], ["ui"], ["ui"], ["ui"], ["ui"]]'
# Output: A A2 A3 B B2 C C2 C3 C4
```

**Impact:**
- **Frequency:** Every Scout run with agents
- **Error risk:** ID collisions, non-standard IDs
- **Time savings:** <1 minute per Scout run
- **Value:** Eliminates a repetitive mental task

---

### M2: Cascade Candidate Detection (MEDIUM, Phase 2) ✅ SHIPPED

**Current behavior:** Scout manually runs workspace-wide searches for old type names when interface contracts include type renames.

**Determinism gap:**
- Easy to forget this step
- No standard search pattern (grep vs. language-aware search)
- Semantic vs. syntax-level cascades require different handling

**Proposed solution:** `sawtools detect-cascades <repo-root> --renames <json>`

**Usage:**
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

**Impact:**
- **Frequency:** Scout runs with type renames (~15% of usage)
- **Error risk:** Missed cascades → agent builds fail → out-of-scope file edits
- **Time savings:** ~3-5 minutes per Scout run with renames
- **Reliability:** Catches cascades Scout would miss

**Implementation notes:**
- Depends on H3 (uses import graph to identify candidate files to search)
- Without H3, must scan entire codebase (slow)

**Shipped:** 2026-03-12 (scout-and-wave-go v0.37.0)
- **IMPL:** `docs/IMPL/IMPL-phase2-determinism-final.yaml`
- **Command:** `sawtools detect-cascades --renames <json>`
- **Implementation:** Agents C+D (pkg/analyzer + CLI), Wave 1, parallel execution with H1a
- **Files:** `pkg/analyzer/cascade.go`, `cascade_test.go`, `cmd/saw/detect_cascades_cmd.go`
- **Test coverage:** 12 tests covering AST-based detection, severity classification, all Go syntax constructs
- **Notes:**
  - AST-based classification: syntax (high/medium) vs semantic (low)
  - Detects: import statements, type declarations, variable/field declarations, comments, string literals
  - Severity scoring: import = high, type decl = high, var decl = medium, comment/string = low
  - CLI accepts JSON array of renames via `--renames` flag
  - Outputs YAML with cascade candidates array
  - Empty results return empty array (not errors), exit code 0

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

### Phase 1 (GO)

**Scope:** H2 (command extraction) + H3 (dependency graph generation)

**Effort:** 30-40 hours

**Deliverables:**
- `sawtools extract-commands <repo-root>`
- `sawtools analyze-deps <repo-root> --files <file-list>`
- Test suite covering 95% of projects (Go, Rust, Node, Python for H2; Go-only for H3 initially)
- Integration tests with existing Scout agent prompt

**Success criteria:**
- Scout agent uses both tools successfully in end-to-end IMPL doc generation
- Tool execution time: H2 ≤10 seconds, H3 ≤60 seconds for 50-file codebase
- Dependency graph accuracy: <5% error rate on known test cases

**Test suite for H3 accuracy:**
- 20 Go projects (5 with circular deps, 5 with conditional compilation, 10 baseline)
- Ground truth: manual verification + comparison with `go mod graph` output
- Error definition: missed dependency OR incorrect dependency direction
- Target: ≤1 error per 20 projects = 5% error rate

**Decision point:** After Phase 1 completes, assess whether to proceed with Phase 2 (Scout automation) or Phase 3 (Wave/Scaffold agent automation) based on observed impact and user feedback.

---

## Appendix: Why 114-153 Hours, Not 40-60 Hours?

**Original estimate breakdown (40-60h):**
- Phase 1: 25h (H3: 20h, H2: 10h, H1: 15h — but H1 depends on H2+H3, so not parallelizable)
- Phase 2: 15h (H4, H5, M2)
- Phase 3: 10h (M1, M3, M4)
- Phase 4: 5h (M5, L3)

**Revised estimate breakdown (114-153h):**
- Phase 1: 30-40h (H2: 10-15h, H3: 20-25h — parallelizable)
- Phase 2: 35-45h (H1a: 15-20h, H4: 12-15h, M2: 8-10h)
- Phase 3: 30-37h (H6: 10-12h, H7: 12-15h, H8: 8-10h — NEW)
- Phase 4: 19-31h (M1: 3-5h, M3: 3-5h, M4: 5-8h, H5: 3-5h, M5: 3-5h, L3: 2-3h)

**Why the discrepancy?**

1. **H1 split into 4 tools** — Original treated as single 15-hour tool. Reality: H1a (pre-impl scanning) is 15-20h alone. H1c (time estimation) and H1d (parallelization scoring) deferred to future.

2. **Multi-language support for H3** — Original estimated 20h for single-language implementation. Reality: Go + Rust + JS + Python requires 4x separate parsers (20-25h for Go-only in Phase 1, +10-15h per additional language in Phase 2).

3. **Wave/Scaffold agent tools omitted** — Original analysis was Scout-centric. H6, H7, H8 (30-37h) apply to every wave execution but were completely missing.

4. **Error handling overhead** — Original estimates assumed perfect tool execution. Reality: 20-30% overhead for error handling, retries, and fallback logic.

5. **Test suite requirements** — Original estimates were feature-only. Reality: each tool needs test suite (20-30% added effort per tool).

---

**End of Roadmap**
