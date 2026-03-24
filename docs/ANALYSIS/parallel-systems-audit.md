# Parallel Systems Audit: Scout-and-Wave Codebase

**Date:** 2026-03-23
**Scope:** All 3 repositories (protocol, SDK, web)
**Context:** Discovered during error-code-taxonomy investigation that IMPL proposed `WrapCommandResult()` pattern would create parallel error handling alongside existing nested-result pattern.

---

## Executive Summary

**Total Parallel Systems Found:** 8 major categories
**High Priority Unifications:** 4 (2 completed, 2 remaining)
**Medium Priority:** 3
**Low Priority:** 1
**Estimated Breaking Changes:** 3 high-priority items require breaking changes (2 completed)

### Key Finding

The codebase exhibits significant **architectural duplication** across result types, error handling, configuration management, and validation logic. Most divergence is **accidental** rather than intentional design for separation of concerns. The most critical issue is the **proliferation of 60+ Result types** with inconsistent error signaling patterns.

---

## Findings by Category

### 1. Result/Response Types ✅ **COMPLETED**

#### Current State

**SDK (scout-and-wave-go):** 60+ distinct `*Result` struct types
- Examples: `PrepareWaveResult`, `FinalizeWaveResult`, `ValidateResult`, `FinalizeIMPLResult`, `VerifyCommitsResult`, `ScanStubsResult`, etc.
- Each has custom fields, inconsistent error signaling
- Some use `Success bool`, others check nested field validity

**Web API (scout-and-wave-web):** 25+ distinct `*Response` struct types
- Examples: `ScoutRunResponse`, `PipelineResponse`, `IMPLDocResponse`, `ProgramStatusResponse`
- JSON-focused, often wrap SDK result types

**Pattern Variance:**
```go
// Pattern A: Success flag (used in ~15% of cases)
type FinalizeWaveResult struct {
    Success bool `json:"success"`
    // ... other fields
}

// Pattern B: Check nested result validity (used in ~40% of cases)
type PrepareWaveResult struct {
    Wave        int
    Worktrees   []WorktreeInfo
    // No success field; caller must check len(Worktrees) or nested errors
}

// Pattern C: Return error separately (used in ~30% of cases)
func SomeOperation() (*SomeResult, error)

// Pattern D: Nested validation results (used in ~15% of cases)
type ValidationResult struct {
    Syntax  ValidationStep
    Imports ValidationStep
    // Overall status via OverallStatus() method
}
```

#### Divergence Assessment

**Severity:** High
**Impact:** Every CLI command, SDK function, and API handler must implement custom error checking logic. No consistent pattern for "did this succeed?"

**Example of Inconsistency:**
```go
// finalize-wave: has Success field
if !result.Success {
    return fmt.Errorf("finalize failed")
}

// prepare-wave: no Success field, check nested data
if len(result.Worktrees) == 0 {
    return fmt.Errorf("prepare failed")
}

// validate: custom OverallStatus() method
if result.OverallStatus() == "FAIL" {
    return fmt.Errorf("validation failed")
}
```

#### Unification Opportunity

**HIGH** - Consolidate into a **single nested result pattern**:

```go
// Unified result wrapper (inspired by error-code-taxonomy discovery)
type Result[T any] struct {
    Data   *T              `json:"data,omitempty"`
    Errors []StructuredError `json:"errors,omitempty"`
    Code   string          `json:"code"` // "SUCCESS" | "PARTIAL" | "FATAL"
}

func (r Result[T]) IsSuccess() bool {
    return r.Code == "SUCCESS" && len(r.Errors) == 0
}

func (r Result[T]) IsFatal() bool {
    return r.Code == "FATAL"
}
```

**Benefits:**
- Single pattern for all operations
- Eliminates `if !result.Success`, `if result.OverallStatus() == "FAIL"`, etc.
- Structured errors enable better error UX
- Type-safe data payload

**Breaking Changes:** Yes - requires migration of all 60+ Result types

**Migration Effort:** High (2-3 weeks)
- Update all SDK functions to return `Result[T]`
- Update CLI commands to use `.IsSuccess()` pattern
- Update web API handlers to serialize `Result[T]`
- Update frontend TypeScript types

#### Completion

**Date:** 2026-03-23
**IMPLs:** IMPL-result-types-unification (Phase 1), IMPL-result-types-phase2 (Phase 2)

**Key Outcomes:**
- `result.Result[T]` is now the universal result type across both SDK and web repos
- All 60+ `*Result` structs renamed to `*Data` (payload types), wrapped by `Result[T]`
- `APIResponse[T]` and `APIError` web-specific aliases deleted — web uses `result.Result[T]` directly
- Zero type aliases remain; single consistent pattern for all operations

---

### 2. Error Handling ✅ **COMPLETED**

#### Current State

**Three parallel error systems:**

**A. ValidationError (structured, protocol-level)**
```go
type ValidationError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Field   string `json:"field,omitempty"`
    Line    int    `json:"line,omitempty"`
    // ... context fields
}
```
- Used by: IMPL manifest validation
- Location: `pkg/protocol/types.go`

**B. StructuredError (tool output parsing)**
```go
type StructuredError struct {
    File       string `json:"file"`
    Line       int    `json:"line,omitempty"`
    Severity   string `json:"severity"` // "error" | "warning" | "info"
    Message    string `json:"message"`
    Tool       string `json:"tool"`
}
```
- Used by: `pkg/errparse` for compiler/linter errors
- Location: `pkg/errparse/types.go`

**C. Free-form error strings (everywhere else)**
```go
fmt.Errorf("verify-commits found agents with no commits")
errors.New("H2 data unavailable - run extract-commands first")
```
- Used by: 180+ instances of `fmt.Errorf`, 25+ instances of `errors.New`
- No structure, hard to parse, no error codes

#### Divergence Assessment

**Severity:** High
**Impact:**
- Cannot build unified error taxonomy without consolidation
- CLI users see inconsistent error messages (some structured, most free-form)
- Web UI cannot provide actionable error UX (no error codes to trigger help text)
- Proposed `WrapCommandResult()` would add 4th parallel system

#### Unification Opportunity

**HIGH** - Consolidate all three into **single error taxonomy**:

```go
// Unified structured error (extends StructuredError with validation context)
type SAWError struct {
    Code       string `json:"code"`        // "E001_MANIFEST_INVALID", "E002_BUILD_FAILED", etc.
    Message    string `json:"message"`     // Human-readable
    Severity   string `json:"severity"`    // "fatal" | "error" | "warning" | "info"
    File       string `json:"file,omitempty"`
    Line       int    `json:"line,omitempty"`
    Field      string `json:"field,omitempty"` // for validation errors
    Tool       string `json:"tool,omitempty"`  // for tool errors
    Suggestion string `json:"suggestion,omitempty"` // auto-fix or remediation
    Context    map[string]string `json:"context,omitempty"` // wave, agent, slug, etc.
}
```

**Benefits:**
- Single error type across entire codebase
- Error codes enable documentation links ("See docs for E001")
- Structured data enables smart error UX (auto-suggest fixes)
- Replaces 200+ instances of `fmt.Errorf` with structured errors

**Breaking Changes:** Yes - requires replacing `error` returns with `[]SAWError` in many functions

**Migration Effort:** High (3-4 weeks)
- Define error code taxonomy (E001-E999)
- Update SDK functions to return structured errors
- Update CLI to render structured errors
- Update web API to serialize structured errors

#### Completion

**Date:** 2026-03-23
**IMPL:** IMPL-error-code-taxonomy-v2

**Key Outcomes:**
- `result.SAWError` is now the single error type across the codebase
- `ValidationError` deleted from `pkg/protocol/types.go`
- `errparse.StructuredError` deleted from `pkg/errparse/types.go`
- 78 error code constants defined in `pkg/result/codes.go` across 7 domains (V/B/G/A/N/P/T)
- CLI renderer: `PrintSAWErrors`/`FormatSAWError` in `cmd/saw/render_errors.go`
- TypeScript `SAWError` + `GateResult` interfaces in `web/src/types.ts`
- All three parallel error systems consolidated into one

---

### 3. Configuration Management 🟡 **MEDIUM PRIORITY**

#### Current State

**Three overlapping config systems:**

**A. saw.config.json (primary config file)**
- Read by: `pkg/agent/backend/configfile.go`, `pkg/autonomy/config.go`
- Contains: providers (API keys), autonomy settings, repos array
- Location: Project root, walked up from working directory

**B. .saw-state/ directory (runtime state)**
- Contains: `gate-cache.json`, session files, journal archives
- Location: Project root
- Purpose: Transient state, not configuration

**C. RepoEntry array (passed at runtime)**
- Type: `[]protocol.RepoEntry`
- Passed to: CLI commands, engine functions
- Contents: Repo name/path mappings, per-repo build/test commands

#### Divergence Assessment

**Severity:** Medium
**Impact:**
- Config loading logic duplicated in 2 packages (`backend/configfile.go`, `autonomy/config.go`)
- Both walk filesystem looking for `saw.config.json`
- `RepoEntry` data is redundant with `saw.config.json` repos array
- No single "load config" function

**Example Duplication:**
```go
// pkg/agent/backend/configfile.go
func findConfigFile(dir string) string {
    for i := 0; i < 10; i++ {
        candidate := filepath.Join(dir, "saw.config.json")
        // ...
    }
}

// pkg/autonomy/config.go
func LoadConfig(repoPath string) (Config, error) {
    path := filepath.Join(repoPath, configFileName)
    // No walking, assumes repoPath is correct
}
```

#### Unification Opportunity

**MEDIUM** - Create **single config package**:

```go
// pkg/config/config.go
type SAWConfig struct {
    Providers SAWProviders     `json:"providers"`
    Autonomy  AutonomyConfig   `json:"autonomy"`
    Repos     []RepoEntry      `json:"repos"`
}

func Load(startDir string) (*SAWConfig, error) {
    // Single walker, single parse, single validation
}

func Save(repoPath string, cfg *SAWConfig) error {
    // Single save logic
}
```

**Benefits:**
- Single config loading path
- Remove duplication between backend/configfile and autonomy/config
- `RepoEntry` array sourced directly from config file
- Easy to extend with new config sections

**Breaking Changes:** Moderate - existing callers need to use new package

**Migration Effort:** Low (2-3 days)
- Create `pkg/config` package
- Migrate `LoadProvidersFromConfig` and `LoadConfig` to new package
- Update callers (20-30 files)

---

### 4. State Tracking 🟡 **MEDIUM PRIORITY**

#### Current State

**Three overlapping state systems:**

**A. IMPL Manifest (authoritative state)**
- Fields: `State ProtocolState`, `MergeState`, `CompletionReports map[string]CompletionReport`
- Location: `docs/IMPL/*.yaml`
- Purpose: Protocol state machine, wave completion status

**B. .saw-state/ directory**
- Files: `gate-cache.json` (gate execution results), session files, journal archives
- Purpose: Caching, observability, resume capability

**C. In-memory state (web app)**
- Examples: `agentSnapshots sync.Map` (SSE event cache), run status tracking
- Purpose: SSE replay for late-connecting clients

#### Divergence Assessment

**Severity:** Medium
**Impact:**
- State scattered across 3 locations
- IMPL manifest is "source of truth" but `.saw-state/` also tracks state
- No single query for "what's the current state of wave N?"
- Web app has to reconstruct state from IMPL + .saw-state + in-memory

**Example Inconsistency:**
- IMPL manifest: `state: WAVE_EXECUTING`
- `.saw-state/sessions/`: Active session JSON files
- Web app memory: `agentSnapshots` with agent lifecycle events
- Query "is wave 2 complete?" requires checking all 3 sources

#### Unification Opportunity

**MEDIUM** - Make **IMPL manifest the single source of truth**:

**Principle:** `.saw-state/` should be cache-only (can be deleted), IMPL manifest should contain all recoverable state.

**Changes:**
1. Move session state to IMPL manifest (new `sessions` field)
2. Keep `.saw-state/gate-cache.json` as cache (rebuilt from IMPL if deleted)
3. Web app SSE snapshots remain in-memory (ephemeral UI state)

**Benefits:**
- Single query for all state: `protocol.Load(implPath)`
- `.saw-state/` becomes optional (improves git hygiene)
- Easier resume after crash (all state in IMPL doc)

**Breaking Changes:** Low - `.saw-state/` format changes, backward compatible

**Migration Effort:** Medium (1 week)
- Add session tracking to IMPL manifest schema
- Update engine to write session state to IMPL
- Update resume logic to read from IMPL first

---

### 5. Validation Logic 🟡 **MEDIUM PRIORITY**

#### Current State

**Validation scattered across 3 layers:**

**A. Protocol-level validation (SDK)**
- Function: `protocol.Validate(manifest)` in `pkg/protocol/validator.go`
- Returns: `[]ValidationError`
- Checks: Manifest structure, agent IDs, file ownership, dependencies

**B. CLI command validation**
- Examples: `validate_cmd.go`, `validate_program_cmd.go`, `validate_scaffold_cmd.go`
- Each wraps protocol validation + adds CLI-specific checks
- Inconsistent error formatting

**C. Web API validation**
- Handlers: `validation_handlers.go`, `bootstrap_handler.go`
- Duplicates some protocol validation logic
- Returns JSON responses, not structured errors

#### Divergence Assessment

**Severity:** Medium
**Impact:**
- Same validation logic duplicated in CLI and API handlers
- No guarantee CLI and API enforce same rules
- Adding new validation requires updating 3 places

**Example Duplication:**
```go
// CLI: cmd/saw/validate_cmd.go
manifest, err := protocol.Load(manifestPath)
if err != nil {
    return fmt.Errorf("load manifest: %w", err)
}
errs := protocol.Validate(manifest)
if len(errs) > 0 {
    // CLI-specific error formatting
}

// Web API: pkg/api/validation_handlers.go
manifest, err := protocol.Load(manifestPath)
if err != nil {
    respondError(w, err.Error(), http.StatusBadRequest)
    return
}
errs := protocol.Validate(manifest)
// JSON response formatting
```

#### Unification Opportunity

**MEDIUM** - **Centralize all validation in SDK**, thin wrappers in CLI/API:

**Pattern:**
```go
// SDK: pkg/protocol/validator.go
func ValidateManifest(m *IMPLManifest) ValidationResult {
    // All validation logic here
    return ValidationResult{
        Valid:  true/false,
        Errors: []SAWError{},
    }
}

// CLI: just calls SDK and formats output
result := protocol.ValidateManifest(manifest)
if !result.Valid {
    printErrors(result.Errors)
    os.Exit(1)
}

// API: just calls SDK and serializes result
result := protocol.ValidateManifest(manifest)
respondJSON(w, http.StatusOK, result)
```

**Benefits:**
- Single validation implementation
- CLI and API guaranteed to enforce same rules
- Validation logic testable in SDK without CLI/API dependencies

**Breaking Changes:** None - refactor only

**Migration Effort:** Low (3-4 days)
- Extract CLI-specific validation into protocol package
- Remove duplication from API handlers
- Update tests

---

### 6. File Ownership / Path Resolution 🔵 **LOW PRIORITY**

#### Current State

**Centralized in SDK:**
- Primary: `pkg/protocol/repo_resolve.go` (`ResolveTargetRepos`, `ValidateRepoMatch`)
- Secondary: `internal/git` package (git operations, not path resolution)
- Web/CLI: Both use SDK functions, no duplication

**Pattern:**
```go
repos, err := protocol.ResolveTargetRepos(manifest, fallbackPath, configRepos)
// Returns map[repoName]string (absolute paths)
```

#### Divergence Assessment

**Severity:** Low
**Impact:** Minimal divergence. Path resolution is **already centralized** in SDK.

**Minor issue:** `internal/git` package exists but is rarely used (9 references). Most git operations use `os/exec` directly.

#### Unification Opportunity

**LOW** - Consider consolidating `internal/git` into `pkg/git` or eliminating:

**Current state:**
- `internal/git` exists but is underutilized
- Most git commands use raw `exec.Command("git", ...)`

**Options:**
1. Promote `internal/git` to `pkg/git` and use consistently
2. Remove `internal/git` and use raw `exec.Command` everywhere

**Benefits:** Minimal - path resolution already centralized

**Breaking Changes:** None

**Migration Effort:** Very Low (1 day)

---

### 7. Logging / Observability ✅ **ALREADY UNIFIED**

#### Current State

**Centralized observability system:**
- Package: `pkg/observability`
- Pattern: `*Emitter` (nil-safe, non-blocking wrapper)
- Storage: `pkg/observability/sqlite` (SQLite-backed event store)
- Events: Structured `ActivityEvent`, `ErrorEvent`, etc.

**Logging pattern:**
```go
emitter := observability.NewEmitter(store)
emitter.Emit(ctx, observability.NewWaveStartEvent(slug, wave))
```

**Minor issue:** Some code still uses `fmt.Fprintf(os.Stderr, ...)` for errors instead of observability system.

#### Divergence Assessment

**Severity:** Low
**Impact:** Observability is **already unified**. Minor cleanup needed.

#### Unification Opportunity

**LOW** - Migrate remaining `fmt.Fprintf(os.Stderr, ...)` to observability emitter:

**Benefit:** All errors/warnings flow through observability system (queryable, analyzable)

**Breaking Changes:** None

**Migration Effort:** Very Low (1-2 days)

---

### 8. Command/API Interface Duplication ⚠️ **HIGH PRIORITY**

#### Current State

**Parallel implementations in CLI and web:**

**Example 1: Scout execution**
- CLI: `cmd/saw/run_scout_cmd.go` (calls `engine.RunScout`)
- Web: `pkg/api/scout.go` + `pkg/service/scout_service.go` (calls `engine.RunScout`)
- Duplication: Request parsing, validation, error formatting

**Example 2: Wave execution**
- CLI: `cmd/saw/prepare_wave.go` (calls `engine.PrepareWave`)
- Web: `pkg/api/wave_runner.go` (calls `engine.PrepareWave`)
- Duplication: SSE event emission, error handling

**Pattern:**
```
User Request
    ↓
CLI Command (cobra)          Web Handler (http)
    ↓                              ↓
[request parsing]           [request parsing]
[validation]                [validation]
    ↓                              ↓
Engine Function (SHARED)
    ↓
SDK (SHARED)
```

#### Divergence Assessment

**Severity:** High
**Impact:**
- Business logic duplicated in CLI and web layers
- Adding new feature requires updating 2 places
- CLI and web may diverge in behavior

**Example Duplication:**
```go
// CLI: cmd/saw/prepare_wave.go
func runE(cmd *cobra.Command, args []string) error {
    manifestPath := args[0]
    manifest, err := protocol.Load(manifestPath)
    if err != nil {
        return fmt.Errorf("load manifest: %w", err)
    }
    // ... validation, checks, engine call
}

// Web: pkg/api/wave_runner.go
func (s *Server) handlePrepareWave(w http.ResponseWriter, r *http.Request) {
    var req PrepareWaveRequest
    json.NewDecoder(r.Body).Decode(&req)
    manifest, err := protocol.Load(req.ManifestPath)
    if err != nil {
        respondError(w, err.Error(), 500)
        return
    }
    // ... validation, checks, engine call (DUPLICATED)
}
```

#### Unification Opportunity

**HIGH** - Extract **business logic into SDK**, make CLI/API thin wrappers:

**Current:**
```
CLI (business logic) → Engine → SDK
Web (business logic) → Engine → SDK
```

**Proposed:**
```
CLI (thin wrapper) → SDK Business Logic → Engine → SDK Core
Web (thin wrapper) → SDK Business Logic → Engine → SDK Core
```

**Example:**
```go
// SDK: pkg/operations/scout.go
type RunScoutParams struct {
    Feature string
    RepoPath string
    IMPLDir string
}

func RunScout(ctx context.Context, params RunScoutParams) (*RunScoutResult, error) {
    // All validation, business logic, engine orchestration here
}

// CLI: cmd/saw/run_scout_cmd.go
func runE(cmd *cobra.Command, args []string) error {
    result, err := operations.RunScout(ctx, operations.RunScoutParams{
        Feature: args[0],
        RepoPath: repoPath,
        IMPLDir: implDir,
    })
    if err != nil {
        return err
    }
    printResult(result) // CLI-specific formatting
    return nil
}

// Web: pkg/api/scout.go
func (s *Server) handleScoutRun(w http.ResponseWriter, r *http.Request) {
    var req ScoutRunRequest
    json.NewDecoder(r.Body).Decode(&req)
    result, err := operations.RunScout(r.Context(), operations.RunScoutParams{
        Feature: req.Feature,
        RepoPath: s.cfg.RepoPath,
        IMPLDir: s.cfg.IMPLDir,
    })
    if err != nil {
        respondError(w, err.Error(), 500)
        return
    }
    respondJSON(w, http.StatusOK, result) // JSON serialization
}
```

**Benefits:**
- Single source of truth for business logic
- CLI and web guaranteed to behave identically
- Easier to test (test SDK, not CLI/web layers)
- Easier to add new interfaces (gRPC, GraphQL, etc.)

**Breaking Changes:** None - refactor only (internal change)

**Migration Effort:** Medium (1-2 weeks)
- Create `pkg/operations` package
- Extract business logic from 15-20 CLI commands
- Update CLI commands to call `pkg/operations`
- Update web handlers to call `pkg/operations`

**Status Update (2026-03-23):** IMPL-integration-completeness-gate was closed as superseded — its scope was too broad. A focused wiring IMPL targeting the CLI/API business logic extraction is being scouted.

---

## Priority Ranking

### High Priority (Critical Unifications)

1. ~~**Result/Response Types** - 60+ types with inconsistent error signaling~~ ✅ **COMPLETED** (2026-03-23)

2. ~~**Error Handling** - 3 parallel error systems, 200+ unstructured errors~~ ✅ **COMPLETED** (2026-03-23)

3. **Command/API Duplication** - Business logic duplicated in CLI and web
   - Impact: Feature velocity, consistency
   - Effort: Medium (1-2 weeks)
   - Breaking: No

### Medium Priority (Quality of Life)

4. **Configuration Management** - Duplicated config loading logic
   - Impact: Maintainability
   - Effort: Low (2-3 days)
   - Breaking: Moderate

5. **State Tracking** - State scattered across IMPL + .saw-state + memory
   - Impact: Resume capability, query complexity
   - Effort: Medium (1 week)
   - Breaking: Low

6. **Validation Logic** - Validation duplicated in CLI/API
   - Impact: Consistency, maintainability
   - Effort: Low (3-4 days)
   - Breaking: None

### Low Priority (Minor Cleanup)

7. **Logging/Observability** - Already unified, minor cleanup needed
   - Impact: Minimal
   - Effort: Very Low (1-2 days)
   - Breaking: None

8. **File Ownership/Path Resolution** - Already centralized
   - Impact: Minimal
   - Effort: Very Low (1 day)
   - Breaking: None

---

## Recommendations

### Immediate Actions (Sprint 1)

1. ~~**Create unified Result[T] type**~~ ✅ **COMPLETED** (2026-03-23) — `result.Result[T]` universal across SDK and web

2. ~~**Design error code taxonomy**~~ ✅ **COMPLETED** (2026-03-23) — `result.SAWError` with 78 error codes across 7 domains

3. **Extract business logic to SDK** (High Priority #3)
   - Create `pkg/operations` package
   - Migrate `run-scout` and `prepare-wave` as pilots
   - Verify CLI and web behave identically

### Follow-up Actions (Sprint 2)

4. **Unified config package** (Medium Priority #4)
5. **State consolidation** (Medium Priority #5)
6. **Validation centralization** (Medium Priority #6)

### Future Cleanup (Sprint 3+)

7. **Observability cleanup** (Low Priority #7)
8. **Git package consolidation** (Low Priority #8)

---

## Conclusion

The Scout-and-Wave codebase exhibits **significant architectural duplication**, primarily in result types, error handling, and business logic across CLI/web interfaces. Most divergence is **accidental** (not intentional separation of concerns), making unification both feasible and beneficial.

**Key Insight:** The discovery of the `WrapCommandResult()` parallel system was a **symptom of a larger pattern** - the codebase lacks unified abstractions for results, errors, and operations, leading developers to create new patterns rather than extend existing ones.

**Recommended Approach:** Tackle high-priority unifications first (Result types, error handling, business logic extraction), as these have multiplicative impact on code quality, maintainability, and feature velocity. Medium/low priority items can be addressed opportunistically during related work.

**Estimated Total Effort:** 8-10 weeks for all high/medium priority unifications (can be parallelized across 2-3 developers).
