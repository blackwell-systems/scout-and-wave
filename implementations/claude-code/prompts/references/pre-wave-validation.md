# Pre-Wave Validation (E16, E35, E37, E21A)

**Purpose:** This reference documents the validation gates that run after Scout produces an IMPL doc and before Wave agents launch.

## Batch Command (Recommended)

**When:** Immediately after Scout writes the IMPL doc, before human review.

**Command:**
```bash
sawtools pre-wave-validate "<absolute-path-to-impl-doc>" --wave <N> --fix
```

**What it does:**
- Runs E16 (IMPL doc structure validation)
- Runs E35 (same-package caller detection)
- Returns combined JSON output
- Exit 0 = all passed, Exit 1 = any failed

**Use this instead of separate `validate` calls** — batches synchronous checks for efficiency.

## E16: IMPL Doc Validation

**When:** Part of `pre-wave-validate` batch (or standalone via `sawtools validate --fix`).

**Standalone command:**
```bash
sawtools validate --fix "<absolute-path-to-impl-doc>"
```

### The `--fix` Flag

Auto-corrects mechanically fixable issues before validation runs:
- **Invalid gate types** → `custom` (valid types: `build`, `lint`, `test`, `typecheck`, `format`, `custom`)
- **Malformed YAML structure** → Normalized formatting
- **Missing required fields** → Populated with defaults where safe

**Logging fixes:** Check the `"fixed"` field in JSON output. If non-zero, log the corrections for the user.

### Exit Codes & Retry Logic

**Exit 0:** Validation passed → proceed to human review (or E37 if triggered).

**Exit 1:** Validation failed → Scout must correct errors.

**Retry procedure:**
1. Scout has already self-validated (up to 3 internal retries per Scout agent prompt)
2. Send remaining errors to Scout via **resume with the Scout's agent ID** (preserves codebase analysis context):
   - `resume: <scout-agent-id>`
   - `prompt: "Your IMPL doc failed orchestrator validation. Fix only these sections:\n{errors}"`
3. Retry **once** (Scout already exhausted its retries; >1 orchestrator retry unlikely to help)
4. On failure: Enter BLOCKED, surface validation errors to human

**Do not present the IMPL doc for human review until validation passes.**

### E16A: Required Block Enforcement

The validator enforces presence of typed blocks. An IMPL doc missing any of these will fail validation even if all present blocks are internally valid:
- `impl-file-ownership`
- `impl-dep-graph`
- `impl-wave-structure`

### E16C: Out-of-Band Content Warnings

Warnings about content that should be in typed blocks (e.g., dependency graph info in prose comments) appear in stdout but do **not** cause exit 1.

**Handling:** Include E16C warnings in the correction prompt anyway, so Scout moves the content into proper typed blocks.

## E35: Same-Package Caller Detection

**When:** Part of `pre-wave-validate` batch, runs after E16 passes.

**Purpose:** Detect E35 violations where an agent owns a function definition but not the call sites in the same package. Prevents post-merge build failures from signature mismatches.

### How It Works

1. Parse IMPL doc to get file ownership for target wave
2. For each agent's owned files:
   - Extract function/method declarations via Go AST
   - Determine package via `go/build`
3. For each function:
   - Find all files in same package
   - Search for call sites in files NOT owned by defining agent
   - Report gaps with file:line references

### Detection Scope

**Detected:**
- Exported functions (e.g., `CreateProgramWorktrees`)
- Unexported functions (e.g., `helperFunc`)
- Methods on types (e.g., `(r *Receiver) Method()`)
- Same-package calls only

**Not detected:**
- Cross-package calls (different concern — E2 dependency analysis)
- Test files (`*_test.go`) excluded from call site search

### Exit Codes & Gap Handling

**Exit 0:** No E35 gaps found → proceed to E37 (if triggered) or human review.

**Exit 1:** E35 gaps detected → Scout must resolve before wave execution.

**Resolution strategies:**
1. **Reassign ownership:** Extend agent's `files` list to include caller files
2. **Create wiring entry:** Add `wiring` block for cross-agent integration (if caller must stay with different agent)
3. **Defer to integration wave:** Document in pre_mortem, handle post-merge

### Output Format

```json
{
  "validation": {"valid": true, "errors": []},
  "e35_gaps": {
    "passed": false,
    "gaps": [
      {
        "agent": "C",
        "function_name": "CreateProgramWorktrees",
        "defined_in": "pkg/protocol/worktree.go",
        "called_from": [
          "pkg/protocol/program_tier_prepare.go:45",
          "pkg/protocol/program_tier_prepare.go:82"
        ],
        "package": "github.com/.../pkg/protocol"
      }
    ]
  }
}
```

### Real-World Example

**Problem:** Wave 1 of logging-injection-remaining IMPL:
- Agent C owned `pkg/protocol/worktree.go` (defines `CreateProgramWorktrees`)
- Agent B owned `pkg/protocol/program_tier_prepare.go` (calls `CreateProgramWorktrees`)
- Agent C added `logger` parameter → build failed post-merge (unowned call sites had old signature)

**E35 would catch:** `Agent C owns CreateProgramWorktrees but not its 2 callers in program_tier_prepare.go`

**Resolution:** Extend Agent C's ownership to include `program_tier_prepare.go`, or create integration wave.

## E37: Critic Gate (Pre-Wave Brief Review)

**When:** After `sawtools validate` passes (E16), before human review and wave execution.

**Purpose:** Automated review of agent briefs for 3+ agent waves or multi-repo coordination. Catches task ambiguity, missing dependencies, ownership conflicts.

### Trigger Conditions

Auto-trigger if **either**:
1. Wave 1 has **3+ agents**, OR
2. `file_ownership` spans **2+ repos**

**Skip condition:** `--no-critic` flag passed to `sawtools run-scout`.

### Execution Steps

1. **Model selection:** Read `agent.critic_model` from `saw.config.json` (fall back to parent model).

2. **Launch critic agent:**
   ```
   Agent(
     subagent_type=critic-agent,
     run_in_background=true,
     description="[SAW:critic:<slug>] pre-wave brief review — <IMPL doc absolute path>",
     prompt="<IMPL doc path>\n<repo root path>"
   )
   ```

   **CRITICAL:** The IMPL doc path MUST be in the `description` (not just the `prompt`) so the SubagentStop hook can locate it for E42 validation.

   **CLI restriction:** Do NOT use `sawtools run-critic` in CLI mode (spawns subprocess that fails in Claude Code session).

3. **Wait for completion:** Critic writes `critic_report` section to IMPL doc with structured findings.

4. **Read verdict:** `critic_report.verdict` field in IMPL doc.

### Verdict Handling

**PASS:** Proceed to human REVIEWED checkpoint.

**ISSUES (severity: error):**
- **BLOCKS execution** — must resolve before wave launch
- Correct briefs using `sawtools amend-impl --redirect-agent <ID>`
- Re-validate (E16)
- Re-run critic

**ISSUES (warnings only):**
- Advisory — inform user, ask if they want to proceed
- Non-blocking

### Critic Report Structure

The critic writes findings to the IMPL doc in this format:

```yaml
critic_report:
  verdict: PASS | ISSUES
  findings:
    - agent: A
      severity: error | warning
      category: ambiguity | missing_dependency | ownership_conflict | scope_mismatch
      description: "Brief says 'update cache logic' but cache.go not in ownership"
      suggestion: "Add cache.go to agent A's ownership or move task to agent owning cache.go"
```

## E21A: Baseline Gate Failure

**When:** During `sawtools prepare-wave` (step 5 of wave execution).

**Purpose:** Verify the codebase builds/tests **before** creating worktrees. Prevents agents from working on a broken baseline.

### Trigger

Before creating worktrees for Wave N, run the quality gates (build/test) defined in the IMPL doc against the current HEAD.

### Failure Handling

If `baseline_verification_failed` is returned:
1. **The codebase was already broken** — not an agent failure
2. Report to user: "Baseline verification failed. Fix the build/tests before launching Wave N."
3. **Do not create worktrees**
4. After user fixes, re-run `sawtools prepare-wave`

### Success Behavior

If baseline passes, proceed with worktree creation and agent launches.

## Integration with Orchestrator Flow

**Scout flow (new IMPL):**
1. Scout completes → Read IMPL doc
2. Run `sawtools pre-wave-validate` (combines E16 + E35)
3. If validation failed → send errors to Scout for correction, retry once
4. If E37 triggered → Run E37 (this file § E37)
5. Present for human review

**Existing IMPL flow (wave execution):**
1. Check if critic already ran (non-empty `critic_report` field)
2. If not and E37 triggered → Run E37
3. Run `sawtools prepare-wave` → E21A executes automatically
4. Launch wave agents

**Retry procedure for E35 gaps:**
1. Parse JSON output from `pre-wave-validate`
2. If `e35_gaps.passed == false`, extract gaps list
3. Send to Scout via resume: "E35 gaps detected. Resolve ownership:\n{gaps}"
4. Scout updates IMPL doc (extends file_ownership or adds wiring entries)
5. Re-run `pre-wave-validate` (retry once)
6. On second failure: Enter BLOCKED, surface to human
