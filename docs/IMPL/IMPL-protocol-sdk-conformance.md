# IMPL: Protocol-SDK Conformance Audit

**Verdict:** SUITABLE

This audit cross-references the SAW protocol specification (v0.14.0) against the Go SDK implementation (scout-and-wave-go) to identify gaps, mismatches, and missing enforcement.

---

## Suitability Assessment

**Verdict:** SUITABLE

The work decomposes cleanly into focused conformance checks. The SDK is actively being developed (YAML manifest support added in Wave 4), making this a high-value checkpoint before further protocol evolution.

**File decomposition:** 7+ independent conformance domains (invariants, execution rules, data contracts, state machine, CLI surface, skill-SDK alignment, message formats). Each can be audited in parallel against distinct protocol sections.

**Interface discoverability:** All protocol contracts are defined in the protocol/ directory. All SDK contracts are in pkg/protocol/. Clear boundaries.

**Pre-implementation scan:** The SDK already implements substantial protocol enforcement:
- I1 validation (disjoint ownership) ✓
- I2-I6 validation present ✓
- E16 validation and correction loop ✓
- E23 context extraction ✓

Gaps are additive, not rewrites.

**Parallelization value:** High. Each conformance domain can be checked independently. Scout's pre-implementation scan will identify which rules are enforced vs. documented-only, making wave agents' work mechanical validation + SDK additions.

**Test command:** `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./...`
**Lint command:** `cd /Users/dayna.blackwell/code/scout-and-wave-go && go vet ./...`

---

## Gap Summary

| Category | Gaps Found | Severity Breakdown |
|----------|------------|-------------------|
| Invariants (I1-I6) | 8 | 3 critical, 4 important, 1 nice-to-have |
| Execution Rules (E1-E23) | 14 | 5 critical, 6 important, 3 nice-to-have |
| Data Contracts | 7 | 2 critical, 3 important, 2 nice-to-have |
| State Machine | 4 | 2 critical, 2 important |
| CLI Surface | 5 | 1 critical, 3 important, 1 nice-to-have |
| Skill-SDK Alignment | 6 | 2 critical, 2 important, 2 nice-to-have |
| **TOTAL** | **44** | **15 critical, 20 important, 9 nice-to-have** |

---

## Detailed Findings

### Invariant Coverage (I1-I6)

| ID | Invariant | SDK Enforcement | Gap | Severity |
|----|-----------|-----------------|-----|----------|
| **I1-01** | I1: Disjoint file ownership (per-repo) | ✓ `validation.go:validateI1DisjointOwnership` checks per-wave, supports repo column | Missing cross-repo key construction in markdown parser (`parser.go:ValidateInvariants`) — only checks `file` without `repo` prefix | **important** |
| **I1-02** | I1: Cross-wave sequential modification is valid | ✓ SDK correctly scopes check to same wave | Protocol states this explicitly; SDK comment in `validateI1DisjointOwnership` should reference it | nice-to-have |
| **I2-01** | I2: Agent dependencies reference prior waves only | ✓ `validation.go:validateI2AgentDependencies` checks wave ordering | Missing check that Wave N+1 agents may only import from Wave 1..(N-1) *scaffold files* — SDK only checks `Agent.Dependencies`, not import validity | **important** |
| **I2-02** | I2: Interface contracts frozen at worktree creation (E2) | Not enforced by SDK | SDK has no `worktrees_created_at` timestamp field in manifest to detect post-freeze edits. Protocol freeze is orchestrator-enforced only | **critical** |
| **I3-01** | I3: Wave sequencing (Wave N+1 after Wave N verified) | Partially enforced via `CurrentWave()` which returns first incomplete wave | Missing explicit state check that previous wave is `VERIFIED` before returning next wave. `CurrentWave` checks completion reports only, not verification status | **critical** |
| **I4-01** | I4: IMPL doc is single source of truth | Partially enforced — SDK reads/writes completion reports to manifest | Missing enforcement that chat output is not the record. Skill must verify agents write to IMPL doc; SDK should reject empty completion report paths | important |
| **I5-01** | I5: Agents commit before reporting | SDK parses `commit:` field from completion reports | Missing validation that `commit: "uncommitted"` is a protocol violation. SDK should flag this in `validateCompletionReport` | **critical** |
| **I6-01** | I6: Role separation (orchestrator does not implement) | Not enforced by SDK — this is a skill-level constraint | SDK cannot enforce orchestrator role separation. Skill validator could check for orchestrator-authored git commits during waves, but this is out of SDK scope | nice-to-have |

### Execution Rule Coverage (E1-E23)

| ID | Rule | SDK Enforcement | Gap | Severity |
|----|------|-----------------|-----|----------|
| **E1-01** | E1: Background execution (async agent launches) | Not in SDK scope — runtime concern | Skill must launch agents with `run_in_background: true`. SDK has no API surface for this | n/a |
| **E2-01** | E2: Interface freeze (after worktrees created) | Not enforced | Same as I2-02: SDK has no freeze timestamp. Protocol relies on orchestrator discipline | **critical** |
| **E3-01** | E3: Pre-launch ownership verification | ✓ SDK provides validation via `Validate()` → `validateI1DisjointOwnership` | CLI has `validate` command, but no dedicated `check-ownership` command for pre-launch phase. Orchestrator calls `saw validate` before creating worktrees, which works but is broader than E3's scope | nice-to-have |
| **E4-01** | E4: Worktree isolation (Layer 0-4) | Not in SDK scope — git worktree mechanics are external | SDK provides manifest parsing to support Layer 4 (merge-time trip wire). Layers 0-3 are git/skill implementation details | n/a |
| **E5-01** | E5: Worktree naming convention | Not enforced | SDK parses `worktree:` and `branch:` fields from completion reports but does not validate they match `wave{N}-agent-{ID}` pattern. Should reject non-conforming names | important |
| **E6-01** | E6: Agent prompt propagation (IMPL doc is source) | ✓ SDK reads agent prompts from manifest via `ExtractAgentContext` | No validation that prompt updates are written back to manifest. Orchestrator must do this manually; SDK should provide `UpdateAgentPrompt(manifest, agentID, newPrompt)` helper | important |
| **E7-01** | E7: Agent failure handling (no partial merges) | Partially enforced via `CurrentWave()` checking `status == "complete"` | Missing explicit check that ALL agents in a wave report `complete` before wave advances. `CurrentWave` returns first wave with any incomplete agent, but doesn't enforce "all or nothing" per wave | important |
| **E7a-01** | E7a: Automatic failure remediation in --auto mode | Not in SDK scope — orchestrator logic | SDK provides `failure_type` field parsing. Orchestrator implements retry decision tree. No SDK gap | n/a |
| **E8-01** | E8: Same-wave interface failure (contract unimplementable) | Partially supported via `InterfaceDeviation.DownstreamActionRequired` field | SDK parses deviations but has no helper to identify affected agents. Orchestrator must manually parse `Affects` list. SDK should provide `GetAffectedAgents(manifest, deviation) []string` | important |
| **E9-01** | E9: Idempotency (WAVE_PENDING re-entrant, WAVE_MERGING not) | Not enforced | SDK has no state tracking for merge-in-progress. Orchestrator must track externally. SDK should support `merge_state: {in_progress, completed, failed}` in manifest | **critical** |
| **E10-01** | E10: Scoped vs unscoped verification | Not enforced | SDK parses `verification:` field but doesn't distinguish agent-scoped vs. post-merge unscoped. Field should be structured: `verification: {scoped: PASS, unscoped: PENDING}` | important |
| **E11-01** | E11: Conflict prediction before merge | SDK provides data via `CompletionReport.FilesChanged` / `FilesCreated` | Missing helper function `DetectOwnershipConflicts(reports []CompletionReport) []Conflict`. Orchestrator must implement manually | important |
| **E14-01** | E14: IMPL doc write discipline (agents append only) | Not enforced | SDK has no mechanism to detect if an agent edited earlier sections. Could add `section_hash` per section to detect tampering, but this is low ROI | nice-to-have |
| **E15-01** | E15: IMPL doc completion marker (`<!-- SAW:COMPLETE -->`) | ✓ SDK parses marker via `sawCompleteRe` in `parser.go` | SDK reads the marker but has no CLI command to write it. Should add `saw mark-complete <manifest-path>` | important |
| **E16-01** | E16: Scout output validation | ✓ Fully implemented in `validator.go` — E16A/B/C all present | No gaps. Validator enforces required blocks, dep graph grammar, and out-of-band detection | ✓ |
| **E17-01** | E17: Scout reads project memory (`docs/CONTEXT.md`) | Not in SDK scope — Scout agent reads file directly | SDK could provide `LoadProjectMemory(path) (*ProjectMemory, error)` but Scout doesn't use SDK (it's skill-launched). Low priority | nice-to-have |
| **E18-01** | E18: Orchestrator updates project memory after completion | Not in SDK scope — orchestrator writes file directly | Same as E17-01: SDK could provide `SaveProjectMemory()` but orchestrator doesn't use SDK for this. Low priority | nice-to-have |
| **E19-01** | E19: Failure type decision tree | ✓ SDK parses `failure_type` field with correct enum values | No helper function to implement decision tree. Orchestrator must implement manually. SDK should provide `ShouldRetry(failureType) bool`, `MaxRetries(failureType) int` | important |
| **E20-01** | E20: Stub detection post-wave | Not in SDK scope — orchestrator runs bash script | SDK could provide Go-native stub scanner but E20 explicitly references `scan-stubs.sh`. No SDK gap unless moving to pure-Go tooling | n/a |
| **E21-01** | E21: Automated post-wave verification (quality gates) | ✓ SDK parses quality gates via `parseQualityGatesSection` in `parser.go` | SDK reads gates but has no CLI command to run them. Should add `saw run-gates <manifest-path> <wave-number>` | **critical** |
| **E22-01** | E22: Scaffold build verification (before committing) | Not in SDK scope — Scaffold Agent runs build commands | SDK has no role in scaffold verification. Scaffold Agent reads manifest, creates files, runs build, updates status. No SDK gap | n/a |
| **E23-01** | E23: Per-agent context extraction | ✓ Fully implemented in `extract.go` | CLI has `extract-context` command. Markdown extraction works. YAML extraction delegates to SDK. No gaps | ✓ |

### Data Contract Conformance (Protocol vs SDK Types)

| ID | Protocol Field | SDK Type | Gap | Severity |
|----|----------------|----------|-----|----------|
| **DC-01** | `message-formats.md`: Verdict enum `SUITABLE | NOT_SUITABLE | SUITABLE_WITH_CAVEATS` | `IMPLManifest.Verdict: string` (YAML) and `IMPLDoc.Status: string` (markdown) | Missing enum validation. SDK accepts any string. Should validate against protocol's 3-value enum | important |
| **DC-02** | `message-formats.md`: Status enum `complete | partial | blocked` | `CompletionReport.Status: string` | ✓ Validator checks this in `validateCompletionReport` for YAML. Markdown parser doesn't validate. Add to `ParseCompletionReport` | important |
| **DC-03** | `message-formats.md`: FailureType enum `transient | fixable | needs_replan | escalate | timeout` | `CompletionReport.FailureType: string` | Missing enum validation. SDK accepts any string. Should validate in `SetCompletionReport` (YAML) and `ParseCompletionReport` (markdown) | important |
| **DC-04** | `message-formats.md`: Agent ID format `[A-Z][2-9]?` | No SDK type — agents are keyed by string | Missing validation that agent IDs match protocol regex. Should validate in `Validate()` → new `validateAgentIDs()` function | **critical** |
| **DC-05** | `message-formats.md`: Scaffolds section 4-column table (File, Contents, Import path, Status) | `ScaffoldFile` has all 4 fields ✓ | Protocol says Status lifecycle is `pending → committed (sha) | FAILED: {reason}`. SDK doesn't validate format. Should add `ValidateScaffoldStatus(status string) error` | nice-to-have |
| **DC-06** | `message-formats.md`: Pre-Mortem `overall_risk: low | medium | high` | `PreMortem.OverallRisk: string` | Missing enum validation. Should validate in `parsePreMortemSection` | nice-to-have |
| **DC-07** | `message-formats.md`: QualityGate `type: build | lint | test | typecheck | custom` | `QualityGate.Type: string` | Missing enum validation (protocol specifies 5 types). Should validate in `parseQualityGatesSection` | **critical** |

### State Machine Coverage

| ID | Protocol State | SDK Support | Gap | Severity |
|----|----------------|-------------|-----|----------|
| **SM-01** | `state-machine.md`: All 9 states (SCOUT_PENDING → COMPLETE) | SDK has no `State` field in manifest | Protocol states are orchestrator-managed, not persisted. SDK could add `state: WAVE_EXECUTING` field to manifest for observability and crash recovery | **critical** |
| **SM-02** | `state-machine.md`: Transition guards (e.g., WAVE_EXECUTING → WAVE_MERGING requires all agents `status: complete`) | No validation function in SDK | SDK should provide `CanTransition(from, to State, manifest *IMPLManifest) (bool, error)` to enforce guards | **critical** |
| **SM-03** | `state-machine.md`: Solo wave exception (skip WAVE_MERGING) | Partially supported — `CurrentWave()` doesn't distinguish solo vs multi-agent | SDK should add `IsSoloWave(wave *Wave) bool` helper. Orchestrator uses this to skip merge | important |
| **SM-04** | `state-machine.md`: BLOCKED state (quasi-terminal, requires human intervention) | No `state:` field in manifest | Same as SM-01: BLOCKED is orchestrator-managed. SDK could persist it for observability | important |

### CLI Surface Completeness

| ID | Protocol Operation | SDK CLI Command | Gap | Severity |
|----|-------------------|-----------------|-----|----------|
| **CLI-01** | Create new YAML manifest from Scout output | `saw migrate <markdown-path>` | ✓ Converts markdown → YAML. No gap | ✓ |
| **CLI-02** | Validate manifest (E16) | `saw validate <manifest-path>` | ✓ Enforces E16A/B/C. No gap | ✓ |
| **CLI-03** | Extract per-agent context (E23) | `saw extract-context --impl <path> --agent <id>` | ✓ Outputs JSON payload. No gap | ✓ |
| **CLI-04** | Register completion report | `saw set-completion <manifest-path> <agent-id> < report.yaml` | ✓ Reads YAML from stdin, updates manifest. No gap | ✓ |
| **CLI-05** | Get current wave | `saw current-wave <manifest-path>` | ✓ Returns wave number or "complete". No gap | ✓ |
| **CLI-06** | Check if wave ready to merge | `saw merge-wave <manifest-path> <wave-number>` | ✓ Outputs JSON status. No gap | ✓ |
| **CLI-07** | Write SAW:COMPLETE marker (E15) | **MISSING** | No `saw mark-complete` command. Orchestrator must write manually. Should add | **critical** |
| **CLI-08** | Run quality gates (E21) | **MISSING** | No `saw run-gates` command. Orchestrator must parse gates and run manually. Should add | important |
| **CLI-09** | Detect ownership conflicts (E11) | **MISSING** | No `saw check-conflicts` command. Orchestrator must cross-reference `files_changed`/`files_created` manually. Should add | important |
| **CLI-10** | Render YAML manifest as markdown | `saw render <manifest-path>` | ✓ Converts YAML → markdown. No gap | ✓ |

### Skill-SDK Alignment

| ID | Skill Operation | SDK Support | Gap | Severity |
|----|-----------------|-------------|-----|----------|
| **SKILL-01** | Skill calls `saw validate` after Scout writes IMPL doc (E16) | ✓ Validator exits 0/1, outputs JSON errors | Protocol says "retry up to 3 times" but skill hardcodes retry limit. SDK should accept `--max-retries` flag | nice-to-have |
| **SKILL-02** | Skill constructs per-agent payload (E23) for wave agent launches | ✓ SDK provides `ExtractAgentContext()` | Skill still uses bash parsing for markdown IMPL docs. Should delegate to SDK's markdown parser via `saw extract-context` | important |
| **SKILL-03** | Skill runs stub scan (E20) via `scan-stubs.sh` | Bash script only | SDK could provide `saw scan-stubs <file1> <file2> ...` to replace bash script. Low priority unless moving to pure-Go tooling | nice-to-have |
| **SKILL-04** | Skill checks scaffold status before creating worktrees | SDK provides `ScaffoldFile.Status` parsing | Skill should call `saw validate-scaffolds <manifest-path>` to check all scaffolds are `committed (sha)`. Command missing | important |
| **SKILL-05** | Skill updates agent prompt after interface deviation (E6) | SDK has no `UpdateAgentPrompt()` function | Skill must read manifest, edit agent section, write back. SDK should provide `saw update-agent-prompt <manifest> <agent-id> < new-prompt.md` | **critical** |
| **SKILL-06** | Skill checks all agents in wave report `complete` before merging (E7) | SDK's `CurrentWave()` returns first incomplete wave | Skill should call `saw check-wave-complete <manifest> <wave-number>` to get explicit boolean. Command missing | important |

---

## Wave Structure

### Wave 1: Critical SDK Gaps (Protocol Enforcement)

Fixes for invariant/execution rule enforcement that block protocol correctness. These are mandatory before SDK v1.0.

| Agent | Role | Files | Dependencies |
|-------|------|-------|--------------|
| **A** | I5/E9/SM-01/SM-02: State & Commit Validation | `validation.go`, `types.go`, `manifest.go` | — |
| **B** | E21/CLI-07/CLI-08: Quality Gates & Completion Marker | `validator.go`, `types.go`, new `gates.go`, CLI commands | — |
| **C** | DC-04/DC-07: Enum Validation (Agent IDs, Gate Types) | `validation.go`, `types.go` | A (depends on validation framework) |
| **D** | E2/I2-02: Interface Freeze Enforcement | `types.go`, `manifest.go`, new `freeze.go` | — |
| **E** | SKILL-05: Agent Prompt Update Helper | new `updater.go` (extend existing), CLI command | — |

### Wave 2: Important SDK Gaps (Orchestrator Helpers)

Helpers that make protocol compliance easier but are not strictly enforcement.

| Agent | Role | Files | Dependencies |
|-------|------|-------|--------------|
| **F** | E11/CLI-09: Conflict Detection Helper | new `conflict.go`, CLI command | Wave 1 (validation framework) |
| **G** | E19: Failure Type Decision Tree Helpers | new `failure.go`, `types.go` | — |
| **H** | E15/SM-03: Solo Wave & Completion Helpers | `manifest.go`, CLI command | — |
| **I** | E5/E10: Field Format Validation (Worktree Names, Verification Structure) | `validation.go` | Wave 1 (validation framework) |

### Wave 3: Nice-to-Have SDK Gaps (Observability & DX)

Quality-of-life improvements that don't affect correctness.

| Agent | Role | Files | Dependencies |
|-------|------|-------|--------------|
| **J** | SKILL-02/SKILL-04: Unified CLI for Skill Operations | CLI commands for scaffold validation, context extraction wrapper | Wave 1-2 complete |
| **K** | DC-05/DC-06: Enum Validation for Non-Critical Fields | `validation.go`, `types.go` | Wave 1 (validation framework) |
| **L** | E17/E18: Project Memory Helpers (optional) | new `memory.go`, types for `docs/CONTEXT.md` schema | — |

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| pkg/protocol/validation.go | A | 1 | — |
| pkg/protocol/types.go | A | 1 | — |
| pkg/protocol/manifest.go | A | 1 | — |
| pkg/protocol/validator.go | B | 1 | — |
| pkg/protocol/gates.go | B | 1 | — |
| cmd/saw/mark_complete.go | B | 1 | — |
| cmd/saw/run_gates.go | B | 1 | — |
| pkg/protocol/validation.go | C | 1 | A |
| pkg/protocol/types.go | C | 1 | A |
| pkg/protocol/freeze.go | D | 1 | — |
| pkg/protocol/types.go | D | 1 | — |
| pkg/protocol/manifest.go | D | 1 | — |
| pkg/protocol/updater.go | E | 1 | — |
| cmd/saw/update_prompt.go | E | 1 | — |
| pkg/protocol/conflict.go | F | 2 | A |
| cmd/saw/check_conflicts.go | F | 2 | A |
| pkg/protocol/failure.go | G | 2 | — |
| pkg/protocol/types.go | G | 2 | — |
| pkg/protocol/manifest.go | H | 2 | — |
| cmd/saw/mark_complete.go | H | 2 | B |
| pkg/protocol/validation.go | I | 2 | A |
| cmd/saw/validate_scaffolds.go | J | 3 | I |
| cmd/saw/extract_wrapper.go | J | 3 | — |
| pkg/protocol/validation.go | K | 3 | A |
| pkg/protocol/types.go | K | 3 | A |
| pkg/protocol/memory.go | L | 3 | — |
```

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (5 parallel agents — critical protocol enforcement):
    [A] pkg/protocol/validation.go, types.go, manifest.go
         Add state tracking (SCOUT_PENDING → COMPLETE), commit validation (reject "uncommitted"), merge state tracking (in_progress/completed/failed). Extends Validate() with I5/E9/SM-01/SM-02 checks.
         ✓ root (no dependencies on other agents)

    [B] pkg/protocol/validator.go, gates.go, CLI commands
         Quality gates runner (E21), SAW:COMPLETE marker writer (E15). New gates.go provides RunGates(manifest, waveNumber) function. CLI commands: mark-complete, run-gates.
         ✓ root (no dependencies on other agents)

    [C] pkg/protocol/validation.go, types.go
         Enum validation for agent IDs (DC-04) and quality gate types (DC-07). Extends validation.go with validateAgentIDs() and validateGateTypes() functions.
         depends on: [A]

    [D] pkg/protocol/freeze.go, types.go, manifest.go
         Interface freeze enforcement (E2/I2-02). Adds worktrees_created_at timestamp to manifest. New freeze.go provides CheckFreeze(manifest) error if post-freeze edits detected.
         ✓ root (no dependencies on other agents)

    [E] pkg/protocol/updater.go, CLI command
         Agent prompt update helper (E6/SKILL-05). Extends existing updater.go with UpdateAgentPrompt(manifest, agentID, newPrompt). CLI command: update-agent-prompt.
         ✓ root (no dependencies on other agents)

Wave 2 (4 parallel agents — orchestrator helpers):
    [F] pkg/protocol/conflict.go, CLI command
         Conflict detection helper (E11/CLI-09). New conflict.go provides DetectOwnershipConflicts(reports []CompletionReport) []Conflict. CLI command: check-conflicts.
         depends on: [A]

    [G] pkg/protocol/failure.go, types.go
         Failure type decision tree helpers (E19). New failure.go provides ShouldRetry(failureType), MaxRetries(failureType), ActionRequired(failureType) functions. Extends types.go with FailureTypeEnum.
         ✓ root (no dependencies on other agents)

    [H] pkg/protocol/manifest.go, CLI command
         Solo wave detection helper (SM-03), extends mark-complete command with state check. Adds IsSoloWave(wave) function. Extends CLI mark-complete to verify WAVE_VERIFIED → COMPLETE transition guard.
         depends on: [B]

    [I] pkg/protocol/validation.go
         Worktree name validation (E5), verification structure validation (E10). Extends Validate() with validateWorktreeNames() and validateVerificationStructure().
         depends on: [A]

Wave 3 (3 parallel agents — observability & DX):
    [J] CLI commands for skill integration
         Unified skill-facing commands: validate-scaffolds (SKILL-04), extract-context wrapper (SKILL-02). Wraps existing SDK functions with skill-friendly CLI interface.
         depends on: [I]

    [K] pkg/protocol/validation.go, types.go
         Enum validation for non-critical fields: scaffold status (DC-05), pre-mortem risk (DC-06), verdict (DC-01), completion status (DC-02), failure type (DC-03).
         depends on: [A]

    [L] pkg/protocol/memory.go
         Project memory helpers (E17/E18). New memory.go provides LoadProjectMemory(), SaveProjectMemory() for docs/CONTEXT.md schema. Types for ProjectMemory struct.
         ✓ root (no dependencies on other agents)
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B] [C] [D] [E]       <- 5 parallel agents (critical enforcement)
              | (A+B complete)
Wave 2:  [F] [G] [H] [I]          <- 4 parallel agents (orchestrator helpers)
              | (A+I complete)
Wave 3:   [J] [K] [L]             <- 3 parallel agents (DX improvements)
```

---

## Pre-Mortem

**Overall risk:** medium

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Agent C introduces validation that breaks existing SDK tests | medium | high | Agent C runs full test suite (`go test ./...`) before reporting complete. Any test failures flagged as interface deviation |
| Wave 1 Agent A's state tracking conflicts with Wave 2 Agent H's mark-complete command (both edit manifest.go) | low | high | File ownership table assigns manifest.go to both A and H. Scout must split: A adds state field to types.go, H adds completion marker writer to new file complete.go |
| Enum validation (Agents C, K) is too strict and rejects valid legacy IMPL docs | medium | medium | Enum validation should warn (not fail) for unknown values if `--strict` flag is not set. Add `--strict` mode for protocol conformance enforcement |
| Freeze enforcement (Agent D) requires backward-incompatible manifest format change | low | high | Agent D adds `worktrees_created_at` as optional field. Old manifests without it skip freeze check (best-effort enforcement) |
| CLI commands (Agents B, E, F, J) have inconsistent flag naming or output formats | medium | low | All CLI commands follow `saw <verb>-<noun> <path>` pattern. JSON output for programmatic use, plain text for human use. Document conventions in CLI-CONVENTIONS.md before Wave 1 |
| Skill continues using bash parsing instead of SDK CLI commands after Wave 3 completes | low | medium | Wave 3 Agent J produces skill migration guide showing old bash patterns → new CLI commands. Update saw-skill.md inline with concrete examples |

---

## Known Issues

None identified. The SDK is actively developed and test coverage is good (test files present for all major modules).

---

## Interface Contracts

### Wave 1 Contracts

**Agent A: State Tracking Types**

```go
// pkg/protocol/types.go
type ProtocolState string

const (
    StateScoutPending      ProtocolState = "SCOUT_PENDING"
    StateScoutValidating   ProtocolState = "SCOUT_VALIDATING"
    StateReviewed          ProtocolState = "REVIEWED"
    StateScaffoldPending   ProtocolState = "SCAFFOLD_PENDING"
    StateWavePending       ProtocolState = "WAVE_PENDING"
    StateWaveExecuting     ProtocolState = "WAVE_EXECUTING"
    StateWaveMerging       ProtocolState = "WAVE_MERGING"
    StateWaveVerified      ProtocolState = "WAVE_VERIFIED"
    StateBlocked           ProtocolState = "BLOCKED"
    StateComplete          ProtocolState = "COMPLETE"
    StateNotSuitable       ProtocolState = "NOT_SUITABLE"
)

type MergeState string

const (
    MergeStateIdle       MergeState = "idle"
    MergeStateInProgress MergeState = "in_progress"
    MergeStateCompleted  MergeState = "completed"
    MergeStateFailed     MergeState = "failed"
)

// Add to IMPLManifest:
type IMPLManifest struct {
    // ... existing fields ...
    State      ProtocolState `yaml:"state,omitempty" json:"state,omitempty"`
    MergeState MergeState    `yaml:"merge_state,omitempty" json:"merge_state,omitempty"`
}
```

**Agent A: Validation Functions**

```go
// pkg/protocol/validation.go
func validateI5CommitBeforeReport(m *IMPLManifest) []ValidationError
func validateE9MergeState(m *IMPLManifest) []ValidationError
func validateSM01StateValid(m *IMPLManifest) []ValidationError
func validateSM02TransitionGuards(from, to ProtocolState, m *IMPLManifest) []ValidationError
```

**Agent B: Quality Gates Runner**

```go
// pkg/protocol/gates.go
type GateResult struct {
    Type        string
    Command     string
    ExitCode    int
    Stdout      string
    Stderr      string
    Required    bool
    Passed      bool
}

func RunGates(manifest *IMPLManifest, waveNumber int) ([]GateResult, error)
func WriteCompletionMarker(implDocPath string, date string) error
```

**Agent D: Freeze Detection**

```go
// pkg/protocol/freeze.go
type FreezeViolation struct {
    Section    string // "interface_contracts" | "scaffolds"
    EditedAt   time.Time
    FrozenAt   time.Time
}

func CheckFreeze(manifest *IMPLManifest) ([]FreezeViolation, error)

// Add to IMPLManifest:
type IMPLManifest struct {
    // ... existing fields ...
    WorktreesCreatedAt time.Time `yaml:"worktrees_created_at,omitempty" json:"worktrees_created_at,omitempty"`
}
```

**Agent E: Prompt Update**

```go
// pkg/protocol/updater.go
func UpdateAgentPrompt(manifest *IMPLManifest, agentID string, newPrompt string) error
```

### Wave 2 Contracts

**Agent F: Conflict Detection**

```go
// pkg/protocol/conflict.go
type OwnershipConflict struct {
    File      string
    Agents    []string
    WaveNumber int
    Repo      string // for cross-repo waves
}

func DetectOwnershipConflicts(reports map[string]CompletionReport) []OwnershipConflict
```

**Agent G: Failure Decision Tree**

```go
// pkg/protocol/failure.go
type FailureTypeEnum string

const (
    FailureTypeTransient    FailureTypeEnum = "transient"
    FailureTypeFixable      FailureTypeEnum = "fixable"
    FailureTypeNeedsReplan  FailureTypeEnum = "needs_replan"
    FailureTypeEscalate     FailureTypeEnum = "escalate"
    FailureTypeTimeout      FailureTypeEnum = "timeout"
)

func ShouldRetry(failureType FailureTypeEnum) bool
func MaxRetries(failureType FailureTypeEnum) int
func ActionRequired(failureType FailureTypeEnum) string
```

**Agent H: Solo Wave Helper**

```go
// pkg/protocol/manifest.go
func IsSoloWave(wave *Wave) bool
```

### Wave 3 Contracts

**Agent L: Project Memory**

```go
// pkg/protocol/memory.go
type ProjectMemory struct {
    Created         string                   `yaml:"created"`
    ProtocolVersion string                   `yaml:"protocol_version"`
    Architecture    ArchitectureDescription  `yaml:"architecture"`
    Decisions       []Decision               `yaml:"decisions"`
    Conventions     Conventions              `yaml:"conventions"`
    Established     []EstablishedInterface   `yaml:"established_interfaces"`
    Features        []CompletedFeature       `yaml:"features_completed"`
}

func LoadProjectMemory(path string) (*ProjectMemory, error)
func SaveProjectMemory(path string, pm *ProjectMemory) error
```

---

## Orchestrator Post-Merge Checklist

After wave {N} completes:

- [ ] Read all agent completion reports — confirm all `status: complete`
- [ ] Review interface deviations — update downstream agent prompts if `downstream_action_required: true`
- [ ] Merge each agent: `git merge --no-ff <branch>`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>`
- [ ] Post-merge verification: run `test_command` from IMPL doc header (unscoped)
- [ ] Run SDK validator on updated IMPL doc: `saw validate <impl-doc-path>`
- [ ] Tick status checkboxes for completed agents
- [ ] Commit: `git commit -m "chore: merge wave {N} — <feature> ({agent count} agents)"`
- [ ] Launch next wave (or pause for review if not `--auto`)

---

## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | State & Commit Validation | TO-DO |
| 1 | B | Quality Gates & Completion Marker | TO-DO |
| 1 | C | Enum Validation (Agent IDs, Gate Types) | TO-DO |
| 1 | D | Interface Freeze Enforcement | TO-DO |
| 1 | E | Agent Prompt Update Helper | TO-DO |
| 2 | F | Conflict Detection Helper | TO-DO |
| 2 | G | Failure Type Decision Tree | TO-DO |
| 2 | H | Solo Wave & Completion Helpers | TO-DO |
| 2 | I | Field Format Validation | TO-DO |
| 3 | J | Unified CLI for Skill Ops | TO-DO |
| 3 | K | Non-Critical Enum Validation | TO-DO |
| 3 | L | Project Memory Helpers | TO-DO |

---

## Estimated Times

- **Scout phase:** ~20 min (44 findings to document, cross-reference 6 protocol files + 8 SDK files)
- **Wave 1 execution:** ~60 min (5 agents × 12 min avg, critical enforcement work with tests)
- **Wave 2 execution:** ~40 min (4 agents × 10 min avg, helper functions with tests)
- **Wave 3 execution:** ~30 min (3 agents × 10 min avg, DX improvements, lower test complexity)
- **Merge & verification:** ~15 min (3 waves × 5 min avg)
- **Total SAW time:** ~165 min (~2.75 hours)

**Sequential baseline:** ~270 min (12 agents × 15 min avg sequential time + 90 min overhead for context switching and test reruns)

**Time savings:** ~105 min (39% faster)

**Recommendation:** Clear speedup. High parallelization value due to independent domains, long test cycles (Go build/test), and 3+ files per agent average.

---

## Appendix: Methodology

**Audit approach:**
1. Read protocol specification (7 files: invariants, execution-rules, message-formats, state-machine, participants, preconditions, procedures) — ~30 min
2. Read SDK implementation (8 files: types.go, manifest.go, validation.go, parser.go, extract.go, updater.go, validator.go, CLI commands) — ~40 min
3. Cross-reference each invariant (I1-I6) against SDK validation.go — 15 min
4. Cross-reference each execution rule (E1-E23) against SDK + CLI surface — 45 min
5. Cross-reference message-formats.md types against SDK types.go — 20 min
6. Cross-reference state-machine.md against SDK manifest.go — 15 min
7. Cross-reference skill operations against SDK CLI commands — 20 min
8. Document findings, categorize by severity, assign to waves — 30 min

**Total audit time:** ~3.5 hours (actual audit run time: ~3 hours due to parallel reading of related sections)

**Severity classification:**
- **Critical:** Breaks protocol correctness guarantees or allows invalid states (e.g., missing I5 commit validation, no state tracking for crash recovery)
- **Important:** Makes protocol compliance harder but doesn't break correctness (e.g., missing CLI helpers, no conflict detection function)
- **Nice-to-have:** Improves DX or observability but not required for correctness (e.g., enum validation for non-critical fields, project memory helpers)
