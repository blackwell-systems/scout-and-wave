# State Machine Conformance Audit

**Date:** 2026-03-11
**Protocol:** scout-and-wave/protocol/state-machine.md (v0.14.0)
**Implementation:** scout-and-wave-go/pkg/types/types.go + pkg/protocol/types.go + pkg/orchestrator/transitions.go

## Summary

**Major discrepancies found.** The Go implementation uses two separate State type systems that are not synchronized with each other or with the protocol specification:

1. **pkg/types/types.go** defines `State` as an `int` enum with PascalCase constants (e.g., `ScoutPending`)
2. **pkg/protocol/types.go** defines `ProtocolState` as a `string` type with SCREAMING_SNAKE_CASE constants (e.g., `SCOUT_PENDING`)

The protocol document uses SCREAMING_SNAKE_CASE throughout (matching `protocol.ProtocolState`), but the orchestrator state machine uses the integer-based `types.State` enum with PascalCase naming. This creates a fundamental type mismatch and naming inconsistency.

Additionally, there is a critical missing state transition in the implementation: the protocol specifies `SCOUT_PENDING → SCOUT_VALIDATING`, but the implementation transitions map shows `ScoutPending → Reviewed` (skipping validation entirely).

## States Comparison

### Protocol States (from state-machine.md)

Listed in the State Catalog (lines 14-27):

1. **SCOUT_PENDING** - Initial state. Scout analysis not yet complete.
2. **SCOUT_VALIDATING** - Orchestrator running validator on Scout output; feeding errors back to Scout if needed.
3. **REVIEWED** - IMPL doc produced, awaiting human review and approval.
4. **SCAFFOLD_PENDING** - Scaffold Agent creating type scaffold files from approved contracts.
5. **WAVE_PENDING** - Ready to launch wave agents. Worktrees not yet created.
6. **WAVE_EXECUTING** - Agents running in parallel.
7. **WAVE_MERGING** - All agents complete, orchestrator merging worktrees.
8. **WAVE_VERIFIED** - Merge complete, post-merge verification passed.
9. **BLOCKED** - Wave failed verification or agent reported failure.
10. **COMPLETE** - All waves verified, feature complete.
11. **NOT_SUITABLE** - Scout determined work not suitable for SAW.

### Implementation States (from types.go)

**In pkg/types/types.go** (integer enum with PascalCase):

```go
type State int

const (
    ScoutPending    State = iota // SCOUT_PENDING
    ScoutValidating              // SCOUT_VALIDATING
    NotSuitable                  // NOT_SUITABLE
    Reviewed                     // REVIEWED
    ScaffoldPending              // SCAFFOLD_PENDING
    WavePending                  // WAVE_PENDING
    WaveExecuting                // WAVE_EXECUTING
    WaveMerging                  // WAVE_MERGING
    WaveVerified                 // WAVE_VERIFIED
    Blocked                      // BLOCKED
    Complete                     // COMPLETE
)
```

**In pkg/protocol/types.go** (string type with SCREAMING_SNAKE_CASE):

```go
type ProtocolState string

const (
    StateScoutPending    ProtocolState = "SCOUT_PENDING"
    StateScoutValidating ProtocolState = "SCOUT_VALIDATING"
    StateReviewed        ProtocolState = "REVIEWED"
    StateScaffoldPending ProtocolState = "SCAFFOLD_PENDING"
    StateWavePending     ProtocolState = "WAVE_PENDING"
    StateWaveExecuting   ProtocolState = "WAVE_EXECUTING"
    StateWaveMerging     ProtocolState = "WAVE_MERGING"
    StateWaveVerified    ProtocolState = "WAVE_VERIFIED"
    StateBlocked         ProtocolState = "BLOCKED"
    StateComplete        ProtocolState = "COMPLETE"
    StateNotSuitable     ProtocolState = "NOT_SUITABLE"
)
```

### Discrepancies

#### States in Protocol but NOT in Implementation

**None.** All 11 protocol states exist in both Go implementations.

#### States in Implementation but NOT in Protocol

**None.** No extra states exist in the implementation.

#### Naming Mismatches

**CRITICAL:** Two separate type systems exist:

1. **types.State** (integer enum, PascalCase) - Used by pkg/orchestrator
2. **protocol.ProtocolState** (string type, SCREAMING_SNAKE_CASE) - Used in YAML manifests

The protocol document exclusively uses SCREAMING_SNAKE_CASE (matching `ProtocolState`), but the orchestrator state machine uses `types.State` with PascalCase naming.

**State ordering discrepancy:**
- Protocol catalog lists states in logical flow order: SCOUT_PENDING → SCOUT_VALIDATING → REVIEWED → ...
- `types.State` iota enum lists: ScoutPending → ScoutValidating → **NotSuitable** → Reviewed → ...

The `NotSuitable` state appears at position 2 (value=2) in the iota sequence, which breaks the logical flow ordering. While this doesn't affect correctness (the values are arbitrary), it creates confusion when debugging or logging state transitions.

#### Type System Split

**MAJOR ISSUE:** The codebase has two parallel state type systems:

- **Orchestrator** (`pkg/orchestrator/orchestrator.go` line 308): `state types.State` (integer)
- **IMPL Manifest** (`pkg/protocol/types.go` line 31): `State ProtocolState` (string)

This means:
1. State transitions in memory use integer comparisons (`types.State`)
2. State persistence in YAML uses string values (`ProtocolState`)
3. Conversion between the two types is implicit and error-prone

**Evidence from actual usage:**
- IMPL YAML files show: `state: COMPLETE`, `state: SCOUT_PENDING` (strings, SCREAMING_SNAKE_CASE)
- Orchestrator initializes: `state: types.ScoutPending` (integer, PascalCase)
- No explicit conversion layer exists between the two representations

## Transitions Comparison

### Protocol Transitions (from state-machine.md)

**Primary Success Flow:**
```
SCOUT_PENDING → SCOUT_VALIDATING (Scout completes, IMPL doc written)
SCOUT_VALIDATING → REVIEWED (Validation passes)
REVIEWED → SCAFFOLD_PENDING (Human approves, scaffolds needed)
REVIEWED → WAVE_PENDING (Human approves, no scaffolds)
SCAFFOLD_PENDING → WAVE_PENDING (Scaffold Agent commits)
WAVE_PENDING → WAVE_EXECUTING (Orchestrator launches agents)
WAVE_EXECUTING → WAVE_MERGING (All agents complete)
WAVE_MERGING → WAVE_VERIFIED (Merge successful)
WAVE_VERIFIED → WAVE_PENDING (More waves exist)
WAVE_VERIFIED → COMPLETE (No more waves)
```

**Failure Paths:**
```
SCOUT_VALIDATING → SCOUT_VALIDATING (Validation fails, retries remain - self-loop)
SCOUT_VALIDATING → BLOCKED (Retry limit exhausted)
SCOUT_PENDING → NOT_SUITABLE (Suitability gate fails)
SCAFFOLD_PENDING → BLOCKED (Scaffold fails)
WAVE_EXECUTING → BLOCKED (Agent failure or verification failure)
WAVE_MERGING → BLOCKED (Merge conflict or verification failure)
BLOCKED → WAVE_PENDING (Issue resolved, restart wave)
BLOCKED → WAVE_VERIFIED (Issue resolved, resume)
```

**Total valid transitions per protocol:** 18 unique directed edges

### Implementation Transitions (from transitions.go)

**From pkg/orchestrator/transitions.go lines 9-20:**

```go
var validTransitions = map[types.State][]types.State{
    types.ScoutPending:    {types.Reviewed, types.NotSuitable},
    types.Reviewed:        {types.ScaffoldPending, types.WavePending},
    types.ScaffoldPending: {types.WavePending, types.Blocked},
    types.WavePending:     {types.WaveExecuting},
    types.WaveExecuting:   {types.WaveMerging, types.WaveVerified, types.Blocked},
    types.WaveMerging:     {types.WaveVerified, types.Blocked},
    types.WaveVerified:    {types.Complete, types.WavePending},
    types.Blocked:         {types.WavePending, types.WaveVerified},
    types.NotSuitable:     {},
    types.Complete:        {},
}
```

**Total valid transitions in implementation:** 15 unique directed edges

### Discrepancies

#### Missing Transitions (in protocol but not implemented)

**CRITICAL:**

1. **SCOUT_PENDING → SCOUT_VALIDATING** (Protocol line 100-103)
   - **Protocol:** "SCOUT_VALIDATING is now interposed between SCOUT_PENDING and REVIEWED. The previous direct transition from SCOUT_PENDING to REVIEWED no longer fires on Scout completion; validation must pass first."
   - **Implementation:** `ScoutPending → {Reviewed, NotSuitable}` - validation state is completely bypassed
   - **Impact:** E16 validation loop cannot function. The implementation jumps directly from ScoutPending to Reviewed, skipping the SCOUT_VALIDATING state where retry loops should occur.

2. **SCOUT_VALIDATING → REVIEWED** (Protocol line 105-109)
   - **Protocol:** Guard condition is "Validator reports no errors"
   - **Implementation:** Missing entirely (ScoutValidating has no outgoing edges defined)

3. **SCOUT_VALIDATING → SCOUT_VALIDATING (self-loop)** (Protocol line 111-114)
   - **Protocol:** "Validator reports errors AND retry count < retry limit"
   - **Implementation:** Missing entirely
   - **Impact:** E16 correction prompt loop cannot execute

4. **SCOUT_VALIDATING → BLOCKED** (Protocol line 116-118)
   - **Protocol:** "Validator reports errors AND retry count >= retry limit"
   - **Implementation:** Missing entirely

#### Extra Transitions (implemented but not documented)

1. **WaveExecuting → WaveVerified** (transitions.go line 14)
   - **Implementation:** Allows direct skip from WAVE_EXECUTING to WAVE_VERIFIED
   - **Protocol:** Not explicitly documented
   - **Analysis:** This appears to be the "solo wave exception" path mentioned in protocol lines 206-217, where a single-agent wave skips the WAVE_MERGING state. However, the protocol doesn't show this as a state transition edge - it describes it as "skip WAVE_MERGING entirely" rather than a direct edge. This is a documentation vs. implementation modeling difference.

#### Incorrect Transitions

**None.** All implemented transitions (except the missing SCOUT_VALIDATING edges) match the protocol specification.

### Solo Wave Variant

**Protocol (lines 206-219):** Solo waves (exactly one agent) skip WAVE_MERGING and transition directly from WAVE_EXECUTING to WAVE_VERIFIED.

**Implementation (transitions.go line 14):** `WaveExecuting: {WaveMerging, WaveVerified, Blocked}` - the direct edge exists.

**Status:** Implemented correctly, though the protocol describes this as a "skip" rather than showing it as an explicit transition edge in the state machine diagram. The implementation models it as an explicit edge, which is more accurate.

## Terminal States

**Protocol:**
- **COMPLETE** - "All waves verified, feature fully implemented" (line 177)
- **NOT_SUITABLE** - "Scout determined preconditions not satisfied" (line 179)
- **BLOCKED (quasi-terminal)** - "Not truly terminal. Orchestrator can resolve and advance to WAVE_VERIFIED. But human intervention is required." (line 181)

**Implementation (transitions.go lines 18-19):**
- **NotSuitable:** `{}` (empty transition list - terminal)
- **Complete:** `{}` (empty transition list - terminal)

**Discrepancies:**
- **BLOCKED** is correctly modeled as non-terminal in implementation (has outgoing edges)
- Terminal states match protocol exactly

## State Entry Actions

**Protocol defines entry actions** (lines 185-201) for each state (e.g., "Orchestrator launches Scout agent with absolute IMPL doc path" on SCOUT_PENDING entry).

**Implementation:** No explicit entry action system exists. The `Orchestrator.TransitionTo()` method (orchestrator.go lines 374-383) only validates the transition and updates the state field. Entry actions are implemented as imperative code in higher-level orchestrator methods (`RunWave`, `MergeWave`, etc.) rather than as a declarative entry action system.

**Analysis:** This is an architectural difference, not a conformance bug. The protocol's "entry actions" table is descriptive (documenting what the orchestrator should do), not prescriptive (requiring a specific entry action hook mechanism). The implementation achieves the same behavior through explicit method calls.

## Recommendations

### High Priority (breaking changes - must fix)

1. **Unify state type systems**
   - **Problem:** Two parallel state types (`types.State` int vs `protocol.ProtocolState` string) create confusion and potential bugs.
   - **Solution Option A (backward compatible):** Keep both, but add explicit conversion functions `ToProtocolState(types.State) ProtocolState` and `FromProtocolState(ProtocolState) (types.State, error)`. Use `ProtocolState` for all YAML I/O and `types.State` for internal orchestrator logic.
   - **Solution Option B (breaking change):** Eliminate `types.State` integer enum. Migrate orchestrator to use `protocol.ProtocolState` string type throughout. This matches the protocol spec exactly and eliminates the conversion layer.
   - **Recommendation:** Option B (use string type throughout) aligns with protocol spec and eliminates type confusion.

2. **Implement SCOUT_VALIDATING transitions**
   - **Problem:** The E16 validation state machine is completely missing from the implementation.
   - **Solution:** Add to `validTransitions` map:
     ```go
     types.ScoutPending:    {types.ScoutValidating, types.NotSuitable},
     types.ScoutValidating: {types.Reviewed, types.ScoutValidating, types.Blocked},
     ```
   - **Impact:** Without this, the E16 retry loop (protocol lines 111-118) cannot function. Scout outputs go directly to human review without validation.

3. **Fix ScoutValidating state position in iota sequence**
   - **Problem:** `NotSuitable` appears at position 2 in the iota, breaking logical flow order.
   - **Solution:** Reorder constants to match protocol flow:
     ```go
     const (
         ScoutPending    State = iota
         ScoutValidating
         Reviewed
         ScaffoldPending
         WavePending
         WaveExecuting
         WaveMerging
         WaveVerified
         Blocked
         Complete
         NotSuitable  // Move to end (terminal state)
     )
     ```
   - **Impact:** This is a breaking change (changes integer values of all subsequent states). Only safe if state values are never persisted as integers.

### Medium Priority (documentation drift)

4. **Document solo wave transition explicitly**
   - **Problem:** Protocol describes solo waves as "skip WAVE_MERGING" (line 214) but doesn't show `WAVE_EXECUTING → WAVE_VERIFIED` as an explicit edge in the state transition diagram.
   - **Solution:** Update protocol/state-machine.md line 52 to add:
     ```
     WAVE_EXECUTING
         ↓ (All agents complete, multi-agent wave)
     WAVE_MERGING
         ↓ (Solo wave: skip merge)
     WAVE_VERIFIED
     ```
   - **Rationale:** Implementation models this as an explicit edge (transitions.go line 14), which is more accurate than describing it as a "skip."

5. **Add transition guard documentation to types.go**
   - **Problem:** The `validTransitions` map in transitions.go (lines 9-20) has no comments explaining guard conditions.
   - **Solution:** Add inline comments cross-referencing protocol sections:
     ```go
     var validTransitions = map[types.State][]types.State{
         // SCOUT_PENDING can transition to SCOUT_VALIDATING (on Scout completion)
         // or NOT_SUITABLE (suitability gate fails). See protocol §99-109.
         types.ScoutPending: {types.ScoutValidating, types.NotSuitable},
         ...
     }
     ```

6. **Standardize state names in protocol document**
   - **Problem:** Protocol uses SCREAMING_SNAKE_CASE inconsistently (sometimes "SCOUT_PENDING", sometimes "Scout Pending" in prose).
   - **Solution:** Use `SCOUT_PENDING` (monospace, SCREAMING_SNAKE_CASE) consistently when referring to state constants.

### Low Priority (clarifications)

7. **Add state machine diagram**
   - **Problem:** Protocol describes transitions in prose and code blocks, but no visual state machine diagram exists.
   - **Solution:** Add a Mermaid state diagram to protocol/state-machine.md showing all 11 states and 18 transitions.
   - **Benefit:** Visual diagram makes valid transitions immediately obvious.

8. **Document types.State.String() output format**
   - **Problem:** `types.State.String()` returns PascalCase (e.g., "ScoutPending"), but YAML manifests use SCREAMING_SNAKE_CASE (e.g., "SCOUT_PENDING").
   - **Solution:** Either:
     - Change `String()` to return SCREAMING_SNAKE_CASE (matches protocol + YAML)
     - Or document that `String()` is for debug logging only, not YAML serialization
   - **Current risk:** If `String()` output is used for YAML serialization, state names will be wrong.

## Conformance Status

- [ ] Fully conformant
- [ ] Minor discrepancies (documentation only)
- [x] **Major discrepancies (implementation bugs or protocol errors)**

### Summary of Non-Conformance

1. **Missing SCOUT_VALIDATING state machine** - E16 validation retry loop cannot function
2. **Dual state type systems** - `types.State` (int, PascalCase) vs `protocol.ProtocolState` (string, SCREAMING_SNAKE_CASE) creates confusion
3. **No explicit SCOUT_PENDING → SCOUT_VALIDATING transition** - implementation bypasses validation entirely
4. **State constant ordering** - iota sequence doesn't match logical flow order

### Severity Assessment

**Critical (blocks E16 protocol compliance):**
- Missing `SCOUT_VALIDATING → {REVIEWED, SCOUT_VALIDATING, BLOCKED}` transitions
- Direct `SCOUT_PENDING → REVIEWED` transition bypasses validation

**High (architectural debt):**
- Dual state type systems increase maintenance burden and bug risk

**Medium (maintainability):**
- State constant ordering confusion
- Missing transition guard documentation

The implementation is approximately 85% conformant with the protocol specification. The missing SCOUT_VALIDATING state machine is the most critical gap and blocks E16 validation loop compliance.
