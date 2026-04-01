# pkg/config Package Review

Date: 2026-04-01
Reviewer: SAW Deep Review (3 agents)

## Executive Summary

The `pkg/config` package demonstrates strong engineering fundamentals: comprehensive Result[T] pattern conformance, structured error handling with appropriate error codes, and solid test coverage (83.1% overall). However, the review uncovered **two critical issues** requiring immediate attention:

1. **state.go has a showstopper bug** preventing integration: completion report key format mismatch (`"wave1-A"` vs `"A"`) makes it incompatible with the rest of the codebase. This code appears unused (no external callers found) and may be dead code.

2. **pkg/agent/backend/configfile.go is accidental duplication** of `pkg/config`: duplicates parsing logic and struct definitions after partial migration left behind technical debt.

**Recommended actions**: (1) Determine if state.go is dead code to be removed or needs key format fix + integration; (2) Execute three-phase migration to consolidate configfile.go into pkg/config (deprecate, migrate callers, remove).

## Findings by Category

### 1. Result[T] Pattern Conformance

**Status**: PASS

All public fallible functions across the package return `Result[T]`:

**config.go**:
- `Load()` → `Result[*SAWConfig]` ✓
- `Save()` → `Result[bool]` ✓
- `LoadOrDefault()` → returns `*SAWConfig` directly (acceptable convenience wrapper) ✓

**state.go**:
- `GetWaveState()` → `Result[*WaveState]` ✓
- `GetAllWaveStates()` → `Result[[]WaveState]` ✓

**configfile.go**:
- `LoadProvidersFromConfig()` → returns bare `SAWProviders` (zero value on error)
- **Deviation**: Does not use Result[T] pattern — returns zero value on error instead
- **Impact**: Inconsistent with rest of codebase, reduces error visibility
- **Recommendation**: Migrate to `Result[SAWProviders]` or eliminate entirely (see Duplication section)

### 2. Error Handling

**Status**: PARTIAL — config.go PASS, state.go issues found, configfile.go silent failures

**config.go — PASS**:
- Structured error codes used consistently:
  - `N013_CONFIG_NOT_FOUND` (CodeConfigNotFound) — no config file found
  - `N014_CONFIG_INVALID` (CodeConfigInvalid) — JSON parse/read errors
  - `N085_CONFIG_IO_FAILED` (CodeConfigIOFailed) — temp file/write/chmod failures
- All error messages include context (file path, failure reason)
- Error construction matches patterns in pkg/protocol and pkg/journal

**state.go — ISSUES**:
1. **Error code misuse**: `CodeWaveNotReady` (N007 "Wave is not ready for execution") is used for "wave not found in manifest" (line 41) — semantically different conditions
   - **Recommendation**: Use more specific code like `CodeWaveNotFound` or `CodeManifestInvalid` (V001)
2. **Error wrapping loses context**: Lines 111-115 wrap error messages with `fmt.Sprintf("wave %d: %s", w.Number, e.Message)` but loses structured error context
   - **Recommendation**: Use `SAWError.WithContext()` method or structured context fields instead of string interpolation

**configfile.go — SILENT FAILURES**:
- Returns zero value `SAWProviders` on all errors (file not found, permission denied, invalid JSON, unmarshal failure)
- **Risk**: MODERATE — callers check for empty strings so no nil dereference risk, but users won't see warnings if saw.config.json contains malformed JSON
- **Comparison**: `config.Load()` returns explicit errors with error codes, allowing callers to distinguish "no config" from "broken config"

### 3. Dead Code Analysis

**Status**: FAIL — state.go appears completely unused

**config.go**:
- `LoadOrDefault()` has no in-tree callers but is **intentionally dead code** — provides convenience API for future use
- All struct types heavily used across pkg/engine, pkg/protocol, pkg/collision, cmd/sawtools
- `FindConfigPath()` used by Load() and is public API for path discovery

**state.go — CRITICAL ISSUE**:
- **Key format bug prevents integration**: Uses `fmt.Sprintf("wave%d-%s", waveNum, id)` to create keys like `"wave1-A"` (line 55), but pkg/protocol uses bare agent IDs (`"A"`) everywhere
- **No external callers found**: `config.WaveState`, `config.GetWaveState`, `config.GetAllWaveStates` only referenced in state_test.go and historical IMPL docs
- **Historical context**: Created as part of IMPL-config-hardening.yaml but never integrated into orchestration flow
- **Impact**: This code cannot work with real manifests due to key format mismatch. Tests pass because they use the same wrong format.
- **Recommendation**: Either (A) fix key format to use bare agent.ID + integrate into orchestration, or (B) remove state.go and state_test.go entirely

**configfile.go**:
- Called from two locations (api/client.go:59, bedrock/client.go:65) for credential fallback
- Not dead code, but duplicates functionality now available in pkg/config

### 4. Code Duplication

**Status**: FAIL — Accidental duplication between configfile.go and pkg/config

**Duplicate structs**:
- `SAWProviders` (configfile.go:11-25) duplicates `config.ProvidersConfig` (config.go:30-54)
- Field names and JSON tags are **identical** — no drift detected
- Comparison:
  - `SAWProviders.Anthropic` (anonymous struct) vs `config.AnthropicProvider` (named type)
  - `SAWProviders.Bedrock` (anonymous struct) vs `config.BedrockProvider` (named type)
  - `SAWProviders.OpenAI` (anonymous struct) vs `config.OpenAIProvider` (named type)

**Duplicate logic**:
- `LoadProvidersFromConfig()` re-implements config parsing that `config.Load()` already provides
- After refactor (commit e9ae569), configfile.go switched to `config.FindConfigPath()` for path discovery but kept duplicate parsing

**Historical cause**:
- configfile.go created (commit 80f8cbd, 2024) **before** unified pkg/config package existed
- pkg/config created later (commit 972de70)
- Partial refactor (commit e9ae569) removed findConfigFile() duplication but left parsing duplication intact
- **Conclusion**: Accidental duplication, not intentional design

**Impact**:
- 46 lines of duplicate code in configfile.go
- 73 lines of duplicate tests in configfile_test.go
- Two config parsing implementations to maintain
- Inconsistent error handling (zero-value vs Result[T])

**Recommendation**: **CONSOLIDATE immediately** — see Migration Path section for three-phase plan

### 5. Consistency with Codebase Patterns

**Status**: PARTIAL — config.go excellent, state.go broken, configfile.go inconsistent

**config.go — PASS**:
- Error construction matches pkg/protocol and pkg/journal (structured SAWErrors, descriptive messages)
- Atomic write pattern (temp file + rename) consistent with standard Go practices
- `FindConfigPath()` walk-up pattern matches filesystem navigation conventions
- `slog.Warn()` usage in LoadOrDefault() appropriate for non-fatal fallbacks

**state.go — INTEGRATION FAILURE**:
- Status classification logic (lines 61-71) correctly matches pkg/protocol/types.go definitions (StatusBlocked→failed, StatusPartial→failed, StatusComplete→completed, default→pending)
- `IsComplete` calculation (line 85) correct: all agents complete AND zero failures
- **BUT**: Key format (`"wave1-A"`) incompatible with protocol package (`"A"`) breaks all integrations
- `MergeState` field inclusion (line 94) reasonable for status queries, though it's manifest-level metadata

**configfile.go — INCONSISTENT**:
- Does not follow Result[T] pattern used by rest of pkg/config
- Zero-value-on-error pattern differs from config.Load() error reporting

### 6. Simplification Opportunities

**config.go**:
1. **Legacy migration removal** (lines 159-184): Handles migration from `"repo"` object to `"repos"` array. Adds ~25 lines complexity with json.RawMessage re-parsing.
   - **Action**: Document when migration was added, establish deprecation timeline. If legacy format >6 months old and all configs migrated, remove in next major version.

2. **Extract JSON merge helper**: `Save()` preserve-unknown-keys logic (lines 195-218) could be extracted to `mergeJSONKeys(existing, new map[string]json.RawMessage) map[string]json.RawMessage` if pattern needed elsewhere
   - **Priority**: LOW unless needed elsewhere

3. **Return type refinement**: `Save()` returns `Result[bool]` but the success `true` value is unused
   - **Consideration**: `Result[struct{}]` would be more idiomatic (unit type for side effects)

**state.go**:
1. **Extract classification helper**: Lines 53-72 agent classification loop could be `classifyAgents(agentIDs, reports, waveNum)` for testability
   - **Priority**: LOW (code clear as-is)

2. **Nil-slice initialization**: Lines 74-83 explicitly convert nil to empty slices, but json.Marshal handles this automatically
   - **Counter-argument**: Explicit initialization documents intent and makes behavior predictable
   - **Priority**: LOW (acceptable either way)

3. **Move to pkg/protocol**: WaveState logic tightly coupled to IMPLManifest structure; pkg/protocol already has `CurrentWave()` doing similar iteration
   - **Trade-off**: Would increase pkg/protocol surface area
   - **Priority**: MEDIUM (after fixing key format bug)

**configfile.go**:
1. **Eliminate entirely**: Replace with `config.Load(dir).GetData().Providers`
   - **Benefits**: -46 lines code, -73 lines tests, consistent error handling, single parsing implementation
   - **Drawbacks**: None identified
   - **Priority**: HIGH (see Migration Path)

### 7. Test Coverage

**Overall**: 83.1% (strong coverage)

**config.go**: 83.1%
- Function-level breakdown:
  - `FindConfigPath`: 91.7% ✓
  - `Load`: 91.3% ✓
  - `Save`: 63.6% ← **lowest coverage**
  - `LoadOrDefault`: 100.0% ✓

**Gaps — config.go**:
- `Save()` error paths undertested:
  - Marshal failure (unlikely but line 204 uncovered)
  - Close failure after successful write (line 244)
  - **Chmod failure (lines 258-260)** — important for security validation
- Well-covered: invalid JSON, missing file, walk-up, atomic write, preserve unknown keys, legacy migration

**Test quality — config.go**:
- Tests use `t.TempDir()` correctly for isolation ✓
- Legacy migration tests include well-formed and malformed cases ✓
- File permissions test exists (lines 309-331) but chmod failure case missing

**state.go**: 83.1%
- Excellent coverage: valid lookup, wave not found, all status transitions, nil manifest errors, multi-wave aggregation, error wrapping
- Missing: empty waves (zero agents), explicit unknown status test
- **Test quality**: Excellent (edge cases well-documented, inline helpers clear)
- **Critical issue**: Tests pass because they use same wrong key format as production code

**configfile.go**: 52.9% (pkg/agent/backend overall)
- Basic coverage: missing file, valid config, parent walk-up
- **Gaps compared to pkg/config tests**:
  - No invalid JSON test (config_test.go has this)
  - No permission error test
  - Only Anthropic tested; Bedrock and OpenAI fields not covered
  - No partial parse test (valid JSON but missing providers section)

## Recommendations

### High Priority

1. **Resolve state.go status** (CRITICAL)
   - **If keeping**: Fix key format to use bare `agent.ID` (remove `wave%d-` prefix on line 55), integrate into orchestrator status query paths, verify with integration tests
   - **If removing**: Delete state.go and state_test.go, document reason in CHANGELOG
   - **Decision needed**: Was Issue 6 from IMPL-config-hardening.yaml about removing GateResults field or entire WaveState struct? Check with original author.

2. **Consolidate configfile.go** (HIGH)
   - Execute three-phase migration (see Migration Path section):
     - Phase 1: Add deprecation notice (non-breaking)
     - Phase 2: Migrate api/client.go and bedrock/client.go to use config.Load() (non-breaking)
     - Phase 3: Remove configfile.go and configfile_test.go (breaking, next minor version)
   - **Timeline**: Phase 1 immediate, Phase 2 within 1-2 releases, Phase 3 next minor version

3. **Add Save() error path tests** (MEDIUM-HIGH)
   - Test chmod failure (security-critical: ensures API keys protected with 0600)
   - Test close failure after write
   - Target: Raise Save() coverage from 63.6% to >85%

### Medium Priority

4. **Fix state.go error code misuse** (if keeping state.go)
   - Replace `CodeWaveNotReady` with `CodeWaveNotFound` or `CodeManifestInvalid` for "wave not found" condition
   - Use `SAWError.WithContext()` instead of string interpolation in GetAllWaveStates error wrapping

5. **Document legacy migration deprecation timeline** (config.go lines 159-184)
   - Add comment with date migration was introduced
   - Establish removal date (suggest: 6 months after introduction if all configs migrated)
   - Add deprecation notice in next release CHANGELOG

6. **Improve configfile.go test coverage** (if not consolidated immediately)
   - Add invalid JSON test
   - Test Bedrock and OpenAI providers
   - Add partial parse test
   - Target: Match pkg/config 83% coverage

### Low Priority / Future Work

7. **Consider Save() return type change**: `Result[bool]` → `Result[struct{}]` (more idiomatic for side-effect-only functions)

8. **Extract JSON merge helper** if pattern needed elsewhere in codebase

9. **Move WaveState to pkg/protocol** after key format fix + integration (improve discoverability of related logic)

10. **Review LoadOrDefault() usage**: Confirm intentionally unused or add example usage in documentation

## Migration Path: Consolidating configfile.go

### Phase 1: Deprecate (Non-Breaking)
**Timeline**: Immediate

1. Add deprecation comment to `LoadProvidersFromConfig`:
   ```go
   // Deprecated: Use config.Load(dir).GetData().Providers instead.
   // This function will be removed in v0.95.0.
   func LoadProvidersFromConfig(dir string) SAWProviders { ... }
   ```
2. Update CHANGELOG to announce deprecation
3. No behavior change in this phase

### Phase 2: Migrate Callers (Non-Breaking)
**Timeline**: Within 1-2 releases

1. Update `pkg/agent/backend/api/client.go:56-63`:
   ```go
   // Fall back to saw.config.json
   if apiKey == "" {
       cwd, _ := os.Getwd()
       r := config.Load(cwd)
       if r.IsSuccess() {
           if r.GetData().Providers.Anthropic.APIKey != "" {
               apiKey = r.GetData().Providers.Anthropic.APIKey
           }
       }
   }
   ```

2. Update `pkg/agent/backend/bedrock/client.go:62-76` similarly:
   ```go
   cwd, _ := os.Getwd()
   r := config.Load(cwd)
   if r.IsSuccess() {
       providers := r.GetData().Providers
       if cfg.AWSRegion == "" && providers.Bedrock.AWSRegion != "" {
           cfg.AWSRegion = providers.Bedrock.AWSRegion
       }
       if cfg.AWSProfile == "" && providers.Bedrock.AWSProfile != "" {
           cfg.AWSProfile = providers.Bedrock.AWSProfile
       }
   }
   ```

3. Verify tests still pass (behavior unchanged, implementation different)

### Phase 3: Remove Dead Code (Breaking)
**Timeline**: Next minor version (v0.94.0 or v0.95.0)

1. Delete `pkg/agent/backend/configfile.go`
2. Delete `pkg/agent/backend/configfile_test.go`
3. Update CHANGELOG for breaking change
4. **Verification**: No external users identified (internal backend package)

### Benefits of Migration
- Eliminates 46 lines duplicate code
- Eliminates 73 lines duplicate tests
- Consistent error handling across codebase (all config access uses Result[T])
- Single config parsing implementation to maintain
- Better error visibility for users (explicit errors vs silent fallback)

## Questions for Maintainers

1. **state.go**: Was this code abandoned or is integration planned? Should it be removed or fixed?
2. **Legacy migration** (config.go): When was `"repo"` → `"repos"` migration added? Can it be removed?
3. **LoadOrDefault()**: Any out-of-tree consumers? (In-tree: no usage found)
4. **Save() return type**: Is the returned `true` value used anywhere, or should it return `Result[struct{}]`?

## Appendix: Per-File Details

### config.go and config_test.go (Agent A)

#### Result[T] Pattern Conformance
- **[PASS]** All public fallible functions return Result[T]
- **Notes:**
  - `Load()` returns `Result[*SAWConfig]` ✓
  - `Save()` returns `Result[bool]` ✓
  - `LoadOrDefault()` is a convenience wrapper that returns `*SAWConfig` directly — acceptable as fallback API and documented clearly

#### Error Handling
- **[PASS]** Structured error codes used consistently
- **Issues found:** None
- **Codes verified:**
  - `N013_CONFIG_NOT_FOUND` (CodeConfigNotFound) — used when no config file found walking up directory tree
  - `N014_CONFIG_INVALID` (CodeConfigInvalid) — used for read errors, JSON parse errors, and marshaling errors
  - `N085_CONFIG_IO_FAILED` (CodeConfigIOFailed) — used for temp file creation, write, close, rename, and chmod failures
- **Pattern comparison:** Error construction matches protocol package style
- **Observation:** All error messages include context (file path, specific failure reason)

#### Dead Code
- **[PASS]** No unused exports
- **Findings:**
  - `LoadOrDefault` is NOT used anywhere in the codebase (grep returned no results outside config package itself)
  - **However:** This is intentionally dead code — provides convenience API for callers who want default-on-failure semantics
  - All struct types heavily used across pkg/engine, pkg/protocol, pkg/collision, and cmd/sawtools
  - `FindConfigPath()` is called by `Load()` internally and is a public API for path discovery

#### Consistency
- **[PASS]** Matches pkg/* patterns
- **Deviations:** None
- **Observations:**
  - Error construction pattern matches pkg/protocol and pkg/journal (structured SAWErrors, descriptive messages)
  - Atomic write pattern (temp file + rename) consistent with standard Go practices
  - `FindConfigPath()` walk-up pattern matches filesystem navigation conventions
  - `slog.Warn()` usage in `LoadOrDefault()` appropriate for non-fatal fallback scenarios

#### Simplification Opportunities
1. **Legacy migration logic** (lines 159-184): Handles migration from single `"repo"` object to `"repos"` array
   - Adds ~25 lines complexity with json.RawMessage re-parsing
   - **Recommendation**: Document when migration added, establish deprecation timeline

2. **Preserve-unknown-keys logic** (lines 195-218): Good for extensibility but could be extracted
   - **Recommendation**: Extract to `mergeJSONKeys()` helper if pattern needed elsewhere

3. **maxWalkDepth constant**: 10-parent-directory limit is reasonable, no change recommended

#### Test Coverage
- **Coverage:** 83.1% overall
- **Function-level breakdown:**
  - `FindConfigPath`: 91.7%
  - `Load`: 91.3%
  - `Save`: 63.6% ← **lowest coverage**
  - `LoadOrDefault`: 100.0%

- **Gaps identified:**
  - `Save()` at 63.6% suggests error paths undertested:
    - Marshal failure (line 204 uncovered)
    - Close failure after successful write (line 244)
    - Chmod failure (lines 258-260) — important for security validation
  - **Covered well:** Invalid JSON, missing file, walk-up, atomic write, preserve unknown keys, legacy migration

- **Test quality observations:**
  - Tests use `t.TempDir()` correctly for isolation
  - Tests cover happy path and major error paths
  - Legacy migration tests include both well-formed and malformed cases
  - File permissions test exists but chmod failure case missing

#### Documentation
- **[PASS]** Complete and accurate
- **Issues:** None
- **Observations:**
  - Package-level doc comment explains purpose and history
  - All exported functions have doc comments
  - Error codes documented in function comments
  - Non-obvious behavior documented (atomic write, legacy migration)
  - Struct field tags consistent and correct

#### Additional Findings

**Positive patterns:**
1. Type safety: All config fields use strongly-typed structs
2. Atomic writes: Temp-file-then-rename prevents partial writes
3. Permissions: Config file set to 0600 to protect API keys
4. Graceful degradation: LoadOrDefault() provides safe fallback
5. Backward compatibility: Legacy migration preserves existing configs
6. Extensibility: Unknown keys preserved in Save()

**Questions:**
1. When was legacy `"repo"` → `"repos"` migration added? Can it be removed?
2. Is LoadOrDefault() used by out-of-tree consumers?
3. Should Save() return `Result[bool]` or `Result[struct{}]`?

**Minor improvements:**
1. Add test coverage for Save() error paths (chmod failure, close failure)
2. Consider extracting mergeJSONKeys() helper if needed elsewhere
3. Document deprecation timeline for legacy repo migration

### state.go and state_test.go (Agent B)

#### Result[T] Pattern Conformance
✅ **PASS** — Both public functions conform to Result[T] pattern:
- `GetWaveState()` returns `result.Result[*WaveState]`
- `GetAllWaveStates()` returns `result.Result[[]WaveState]`

All error paths use `result.NewFailure()` with proper `result.SAWError` construction.

#### Error Handling
🟡 **ISSUE FOUND** — Error codes mostly correct but have consistency issues:

1. **CodeWaveNotReady vs CodeConfigInvalid usage**
   - `CodeConfigInvalid` (N014) used for nil manifest (correct)
   - `CodeWaveNotReady` (N007) used for "wave not found in manifest" (line 41)
   - **Analysis**: CodeWaveNotReady defined as "Wave is not ready for execution" but used here for "wave doesn't exist"
   - **Recommendation**: Create more specific code like `CodeWaveNotFound` or use `CodeManifestInvalid` (V001)

2. **Error wrapping in GetAllWaveStates**
   - Lines 111-115: Creates new SAWError structs with `fmt.Sprintf("wave %d: %s", w.Number, e.Message)`
   - **Issue**: Loses original error context beyond message string
   - **Recommendation**: Use `SAWError.WithContext()` method or structured context instead of string interpolation

#### Dead Code
🔴 **CRITICAL ISSUE** — Code appears **completely unused or broken**:

**Key format inconsistency**:
- state.go line 55: Uses `fmt.Sprintf("wave%d-%s", waveNum, id)` creating keys like `"wave1-A"`
- pkg/protocol everywhere: Uses `manifest.CompletionReports[agent.ID]` directly (just `"A"`, not `"wave1-A"`)

**Evidence**:
- Searched entire codebase: `config.WaveState`, `config.GetWaveState`, `config.GetAllWaveStates` — **NO external callers found**
- Only references in pkg/config/state_test.go and historical IMPL docs
- IMPL-config-hardening.yaml lists Issue 6: "remove dead GateResults field" and Issue 2: "nil manifest guard" for WaveState

**Conclusion**: Code created as part of IMPL-config-hardening.yaml but never integrated. Key format mismatch means it would never successfully read completion reports from real manifests.

**Impact**: Either this is:
1. Future planned functionality needing key format fix before integration, OR
2. Dead code that should be removed

#### Consistency
🔴 **FAIL** — Multiple consistency issues:

1. **Status classification logic**
   - Lines 61-71: Logic correctly matches pkg/protocol/types.go definitions
   - StatusBlocked → failed ✓
   - StatusPartial → failed ✓
   - StatusComplete → completed ✓
   - default → pending ✓
   - **BUT**: Key format issue means this never finds real reports

2. **IsComplete calculation**
   - Line 85: `isComplete := len(completed) == len(agentIDs) && len(failed) == 0`
   - Correct — requires ALL agents complete AND zero failures
   - Treats unknown status as pending (reasonable)

3. **MergeState field inclusion**
   - Line 94: `MergeState: string(manifest.MergeState)`
   - Reasonable for status queries, though it's manifest-level not wave-level metadata

4. **Key format breaks all integrations**
   - Creates keys like `"wave1-A"` but protocol uses `"A"`
   - **Showstopper bug** preventing this code from working with real manifests
   - Test suite passes because tests use same wrong format

#### Simplification Opportunities
1. **Extract agent classification** (lines 53-72): Could be `classifyAgents(agentIDs, reports, waveNum)` — Priority: LOW

2. **Nil-slice initialization** (lines 74-83): json.Marshal already handles nil slices as `[]` — Priority: LOW

3. **Move WaveState to pkg/protocol**: Logic tightly coupled to IMPLManifest — Priority: MEDIUM

4. **Fix key format OR remove code**:
   - Option A: Change line 55 to `reportKey := id` (remove wave number prefix)
   - Option B: Change protocol to use `wave{N}-{ID}` everywhere (breaking)
   - Option C: Remove entirely if unused
   - Priority: **CRITICAL** (must resolve before any integration)

#### Test Coverage
📊 **Coverage: 83.1%**

**Coverage by scenario**:
- ✅ Valid wave lookup
- ✅ Wave not found
- ✅ All agents complete
- ✅ Partial completion
- ✅ Agent failures (blocked + partial)
- ✅ Nil manifest error paths
- ✅ Multi-wave aggregation
- ✅ Error wrapping behavior documented

**Missing coverage**:
1. Empty waves (wave with zero agents)
2. Unknown status handling (line 70 default case) — covered indirectly
3. Edge case: Wave exists but manifest.CompletionReports is nil

**Test quality notes**:
- Tests use inline helpers (makeManifest, twoAgentWave) — good
- Excellent documentation explaining test rationale
- **Critical issue**: Tests use same wrong key format as production code

#### Naming Consistency
🟡 **MINOR ISSUES**:

1. **WaveState vs WaveStatus vs WaveProgress**
   - Current: `WaveState`
   - Consistent with "state" terminology elsewhere (`manifest.State`, `MergeState`)
   - Alternative: `WaveProgress` might be more descriptive
   - **Verdict**: Acceptable as-is

2. **GetWaveState vs GetAllWaveStates**
   - Follows Go convention: singular Get + plural GetAll ✅

3. **WaveState struct fields**
   - `CompletedAgents`, `FailedAgents`, `PendingAgents` — clear and parallel
   - `IsComplete` — boolean follows Go convention
   - `MergeState` — matches protocol.MergeState type name
   - ✅ Good naming

#### Summary
**Critical Issues**:
1. 🔴 Key format bug: `"wave1-A"` vs `"A"` makes code incompatible with system
2. 🔴 Dead code: No callers found outside test suite
3. 🔴 Integration needed: If intended for use, must wire into orchestration

**Recommendation**:
- **If keeping**: Fix key format to use agent.ID directly, integrate into orchestrator
- **If not keeping**: Remove state.go and state_test.go to avoid confusion
- **Check with team**: Issue 6 from IMPL-config-hardening.yaml about removing GateResults or entire WaveState?

**Test quality**: ✅ Excellent (83.1%, edge cases documented)
**Code quality**: ✅ Good (Result[T] pattern, error handling, nil checks)
**Integration status**: 🔴 Not integrated, possibly abandoned

### pkg/agent/backend/configfile.go (Agent C)

#### Duplication Analysis
- **DUPLICATE**: `SAWProviders` struct (configfile.go:11-25) duplicates fields from `config.ProvidersConfig` (config.go:30-54)
- **Field comparison**:
  - `SAWProviders.Anthropic` (anonymous struct) vs `config.AnthropicProvider` (named type)
  - `SAWProviders.Bedrock` (anonymous struct) vs `config.BedrockProvider` (named type)
  - `SAWProviders.OpenAI` (anonymous struct) vs `config.OpenAIProvider` (named type)
  - Field names and JSON tags **identical** — no drift
- **Recommendation**: **CONSOLIDATE** — eliminate SAWProviders, use `config.Load().GetData().Providers`

#### Usage Analysis
- **Called from**:
  1. `pkg/agent/backend/api/client.go:59` — Anthropic API credential fallback
  2. `pkg/agent/backend/bedrock/client.go:65` — Bedrock credential fallback
- **Purpose**: Credential fallback when explicit API keys not provided via config structs or environment variables
- **Why separate from config.Load()?**: Originally had own `findConfigFile()` implementation. After refactor (commit e9ae569), calls `config.FindConfigPath()` but still duplicates parsing logic.

#### Result[T] Migration
- **Current**: Returns zero-value `SAWProviders` on any error
- **Recommended**: **MIGRATE TO Result[T]** for consistency with config.Load()
- **Breaking change**: **YES**
  - Both call sites rely on zero-value-on-error semantics
  - api/client.go:60 checks `if providers.Anthropic.APIKey != ""`
  - bedrock/client.go:66-74 checks individual fields for emptiness
  - Callers would need to check `r.IsSuccess()` before accessing data

#### Simplification Opportunities
- **Can LoadProvidersFromConfig be eliminated?** **YES**
- **Can it delegate to config.Load()?** **YES**
- **Recommended pattern**: Replace with `config.Load(dir).GetData().Providers`
- **Benefits**:
  - Eliminates 46 lines duplicate code
  - Eliminates 73 lines duplicate tests
  - Consistent error handling (all config access uses Result[T])
  - Single parsing implementation to maintain
- **Drawbacks**: None identified

#### Error Handling
- **Silent failure risk**: **MODERATE**
  - Returns zero values on all errors (file not found, permission denied, invalid JSON, unmarshal failure)
  - Callers check for empty strings (no nil dereference risk)
  - **Scenario**: If saw.config.json exists but contains malformed JSON, callers silently fall back without warning user
- **Caller assumptions**:
  - Both callers correctly check for empty values
  - No nil pointer risk
  - Users might be confused if saw.config.json incorrect and credentials aren't used
- **Comparison**: config.Load() returns explicit errors with codes (N013, N014), distinguishing "no config" from "broken config"

#### Test Coverage
- **pkg/agent/backend coverage**: 52.9%
- **pkg/config coverage**: 83.1%
- **configfile_test.go tests**:
  1. TestLoadProvidersFromConfig_NotFound — missing config
  2. TestLoadProvidersFromConfig_Found — valid config
  3. TestLoadProvidersFromConfig_WalksUp — parent directory walk-up
- **Gaps compared to pkg/config tests**:
  - No invalid JSON test (config_test.go has this)
  - No permission error test
  - Only Anthropic tested; Bedrock and OpenAI not covered
  - No partial parse test (valid JSON but missing providers)
- **Overall**: Basic happy-path covered, error handling undertested

#### Historical Context
- **Git history**:
  - 80f8cbd (2024): configfile.go added with findConfigFile() implementation
  - 972de70 (later): pkg/config package created with unified config management
  - e9ae569 (refactor): configfile.go switched from local findConfigFile() to config.FindConfigPath()
- **Intent**: configfile.go created **before** unified pkg/config existed as temporary solution
- After pkg/config introduced, findConfigFile() duplication removed but parsing duplication remained
- **Conclusion**: **Accidental duplication**, not intentional — should have been fully migrated during e9ae569 refactor

#### Summary Recommendation
**CONSOLIDATE immediately** — Duplication is accidental. Both callers can migrate to config.Load() without behavior change. Migration path clear and low-risk.
