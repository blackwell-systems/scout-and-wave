# Protocol Enhancement Roadmap

**Status:** Active
**Last Updated:** 2025-03-14
**Current Protocol Version:** 0.14.0
**Source:** Execution rules audit (E1-E23) + Protocol audit (I1-I6, P1-P5, message formats, participants, procedures)

This roadmap tracks enhancements to the Scout-and-Wave protocol that improve automation, resilience, and developer experience. Unlike the determinism roadmap (which focused on eliminating human intervention from the critical path), this roadmap addresses edge cases, recovery scenarios, and operational polish.

**Audit Findings (2025-03-14):**
- **Execution Rules (E1-E23):** 19 fully implemented, 3 partial, 1 gap
- **Protocol Specs (I1-I6, etc.):** 78% compliance, strong architectural foundation
- **Critical Gaps:** E23A (journal recovery), E17 (CONTEXT.md validation), E9 (merge idempotency)
- **Full Reports:** See `/code/scout-and-wave/PROTOCOL_AUDIT_REPORT.md`

---

## Priority 1: Critical Resilience Gaps

### E23A: Tool Journal Recovery
**Status:** ✅ Completed 2025-03-14
**Risk Level:** High (resolved)
**Execution Rule:** E23A in `protocol/execution-rules.md`
**Audit Finding:** Protocol audit 2025-03-14

**Problem:**
Agent execution history is lost on failure, retry, or context compaction. Without tool journal recovery, agents lack the context needed for automatic failure remediation (E7a, E19). Journal schema is documented in `protocol/message-formats.md` but not implemented in SDK.

**Current State:**
- Schema defined in message-formats.md (lines 567-615)
- `ToolEntry` struct specifies format for `index.jsonl` files
- No SDK implementation found in `pkg/protocol/` or `pkg/orchestrator/`
- Agent prompts mention journal context prepending, but no SDK function generates the context

**Implementation Plan:**
1. Create `pkg/protocol/journal.go` with journal writing/reading functions:
   ```go
   type ToolEntry struct {
       Timestamp   time.Time
       Kind        string // "tool_use" or "tool_result"
       ToolName    string
       ToolUseID   string
       Input       map[string]interface{}
       ContentFile string
       Preview     string
       Truncated   bool
   }

   func WriteJournalEntry(journalDir string, entry ToolEntry) error
   func ReadJournal(journalDir string, limit int) ([]ToolEntry, error)
   func GenerateContextMD(journalDir string, lastN int) (string, error)
   ```
2. Integrate journal writing in agent launch hooks:
   - Capture tool use events from agent sessions
   - Write entries to `.saw-state/journals/wave{N}/agent-{ID}/index.jsonl`
3. Implement recovery logic:
   - On agent retry/relaunch, read last 50 journal entries
   - Generate `context.md` summary
   - Prepend to agent prompt as "Prior Work" section
4. Add `sawtools journal-context` command for manual inspection

**Success Criteria:**
- Agents retain execution history across retries
- Journal entries written for every tool use
- Context recovery works after process kill/restart
- Automatic remediation (E7a) becomes robust

**Files to Update:**
- `scout-and-wave-go/pkg/protocol/journal.go` - New file
- `scout-and-wave-go/pkg/orchestrator/orchestrator.go` - Add journal hooks
- `scout-and-wave-go/cmd/saw/journal_context.go` - New command
- `implementations/claude-code/prompts/saw-skill.md` - Document journal recovery flow
- `protocol/message-formats.md` - Add implementation notes

---

### E17: Project Memory Reading Validation
**Status:** Not Implemented
**Risk Level:** Medium
**Execution Rule:** E17 in `protocol/execution-rules.md`
**Audit Finding:** Protocol audit 2025-03-14

**Problem:**
Scout agent prompt instructs reading `docs/CONTEXT.md` before suitability gate, but no SDK validation that Scout actually reads the file. Project memory may be ignored silently, leading to redundant discovery of known patterns or conflicts with established conventions.

**Current State:**
- Agent prompt (agents/scout.md line 103) instructs reading CONTEXT.md
- No enforcement mechanism in SDK
- Relies entirely on agent prompt compliance

**Implementation Plan:**

**Option A: Add Validation (Strict Enforcement)**
1. Implement `pkg/protocol/context_validation.go`:
   ```go
   func ValidateScoutReadContext(implDocPath string, agentToolUses []ToolUse) error {
       contextPath := filepath.Join(filepath.Dir(implDocPath), "CONTEXT.md")
       if !fileExists(contextPath) {
           return nil // No CONTEXT.md present, validation passes
       }

       for _, use := range agentToolUses {
           if use.ToolName == "Read" && use.Input["file_path"] == contextPath {
               return nil // Scout read CONTEXT.md
           }
       }
       return fmt.Errorf("E17 violation: Scout did not read docs/CONTEXT.md")
   }
   ```
2. Call validation after Scout completes, before presenting IMPL doc for review
3. On failure: re-launch Scout with explicit instruction to read CONTEXT.md

**Option B: Document as Best Practice (Soft Enforcement)**
1. Update E17 in execution-rules.md to mark as "recommended, not enforced"
2. Add rationale: validation is brittle (read may occur via different path, or Scout may legitimately have no project memory to consult)
3. Accept that agent prompt instructions are sufficient

**Decision Required:** Choose Option A or Option B based on protocol philosophy (strict enforcement vs agent autonomy)

**Success Criteria (if Option A):**
- Scout compliance with E17 reaches 100%
- CONTEXT.md reading is verifiable in SDK
- False positives are rare (<5% of cases)

**Files to Update (if Option A):**
- `scout-and-wave-go/pkg/protocol/context_validation.go` - New file
- `scout-and-wave-go/pkg/orchestrator/orchestrator.go` - Add E17 check after Scout
- `protocol/execution-rules.md` - Document validation behavior

**Files to Update (if Option B):**
- `protocol/execution-rules.md` - Mark E17 as "best practice, not enforced"

---

### Markdown IMPL Format Deprecation Timeline
**Status:** Timeline Undefined
**Risk Level:** Medium
**Audit Finding:** Protocol audit 2025-03-14

**Problem:**
Message-formats.md states "Markdown format deprecated... Scout v0.7.1+ generates YAML manifests exclusively," but parser still supports markdown format with `# IMPL:` headers. No removal timeline documented, no migration tool provided. Legacy support creates maintenance burden and potential for format confusion.

**Current State:**
- Parser (`pkg/protocol/parser.go`) reads both YAML and markdown
- Scout only generates YAML (since v0.7.1)
- Existing markdown IMPL docs in the wild (unknown quantity)
- No automated migration path

**Implementation Plan:**
1. **Decision Point:** Set deprecation timeline
   - **Recommendation:** Remove markdown support in v1.0.0 (breaking change appropriate for major version)
   - **Rationale:** Scout v0.7.1+ only generates YAML; legacy markdown docs are historical artifacts that can remain readable until removal
2. Add deprecation warnings in current version:
   - Parser emits warning when reading markdown format
   - Warning includes: "Markdown format deprecated, will be removed in v1.0.0. No action required - Scout generates YAML exclusively."
3. Update documentation:
   - message-formats.md: Add removal version (v1.0.0) and rationale
   - CHANGELOG.md: Add deprecation notice in next release

**Success Criteria:**
- Users have clear timeline (e.g., "markdown removed in v1.0.0, released Q2 2026")
- Deprecation warnings appear in CLI output for markdown users
- v1.0.0 parser rejects markdown format with actionable error message
- No migration burden—Scout already generates YAML exclusively

**Files to Update:**
- `scout-and-wave-go/pkg/protocol/parser.go` - Add deprecation warning
- `protocol/message-formats.md` - Document removal timeline
- `CHANGELOG.md` - Add deprecation notice

---

### E9: Merge Idempotency
**Status:** ✅ Completed 2025-03-14
**Risk Level:** High (resolved)
**Execution Rule:** E9 in `protocol/execution-rules.md`

**Problem:**
`finalize-wave` is not idempotent in the WAVE_MERGING phase. If merge crashes mid-operation (network failure, process kill, etc.) and the operator re-runs the command, already-merged worktrees may be merged again, creating duplicate commits.

**Current State:**
- WAVE_PENDING is idempotent (worktree existence checks present)
- WAVE_MERGING has no crash recovery guards
- No merge commit SHA tracking to skip already-merged worktrees

**Implementation Plan:**
1. Add `.saw-state/wave{N}/merge-log.json` to track per-agent merge SHAs
2. Implement `sawtools check-merge-state` command:
   ```bash
   sawtools check-merge-state "<manifest-path>" --wave <N>
   ```
   - Searches git history for merge commits matching pattern `Merge wave{N}-agent-{ID}`
   - Returns JSON: `{"agent": "A", "merged": true, "merge_sha": "abc123"}`
3. Update `finalize-wave` to:
   - Check merge-log.json before each agent merge
   - Skip agents already in merge log
   - Append to merge log after successful merge
4. Add `--force-remerge` flag for operators to override idempotency (rare cases)

**Success Criteria:**
- Running `finalize-wave` twice produces identical git history
- Crashed merges can resume without manual intervention
- Test: Kill process mid-merge, verify clean restart

**Files to Update:**
- `scout-and-wave-go/pkg/protocol/merge.go` - Add merge-log tracking
- `scout-and-wave-go/cmd/saw/finalize_wave.go` - Add idempotency checks
- `scout-and-wave-go/cmd/saw/check_merge_state.go` - New command
- `protocol/execution-rules.md` - Document merge-log format

---

## Priority 2: Interface Change Recovery Automation

### E2: Interface Freeze Recovery Paths
**Status:** Partially Implemented
**Risk Level:** Medium
**Execution Rule:** E2 in `protocol/execution-rules.md`

**Problem:**
Interface contracts freeze when worktrees are created (E2 checkpoint). If agents discover interface is unimplementable, no automated recovery paths exist. Operator must manually cherry-pick or descope work, then re-issue prompts.

**Current State:**
- Checkpoint documented in orchestrator skill (line 293)
- No `sawtools` command for recovery
- Manual git operations required

**Implementation Plan:**
1. Implement `sawtools recover-interface-change` command:
   ```bash
   sawtools recover-interface-change "<manifest-path>" --wave <N> \
     --mode [cherry-pick|descope] \
     --affected-agents <comma-separated>
   ```
2. **Cherry-pick mode:**
   - Lists completed agents whose work doesn't depend on changed contract
   - Cherry-picks their commits to main
   - Marks them as "salvaged" in IMPL doc
   - Re-runs `create-worktrees` for affected agents only
3. **Descope mode:**
   - Marks affected agents as "descoped" in IMPL doc
   - Proceeds with merge for unaffected agents
   - Creates follow-up IMPL doc for descoped work

**Success Criteria:**
- Interface change doesn't require full wave restart
- Completed work can be salvaged automatically
- Clear operator guidance on which mode to use

**Files to Update:**
- `scout-and-wave-go/cmd/saw/recover_interface_change.go` - New command
- `protocol/execution-rules.md` - Document recovery modes
- `implementations/claude-code/prompts/saw-skill.md` - Add recovery instructions

---

### E6: Agent Prompt Propagation (Interface Deviation)
**Status:** Partially Implemented
**Risk Level:** Medium
**Execution Rule:** E6 in `protocol/execution-rules.md`

**Problem:**
When agent reports `interface_deviations` in completion report (indicating interface contract needs revision), orchestrator doesn't automatically update prompts for downstream agents. Operator must manually call `update-agent-prompt` and re-launch affected agents.

**Current State:**
- `update-agent-prompt` CLI command exists
- No orchestrator auto-detection of deviations
- Manual coordination required

**Implementation Plan:**
1. Orchestrator detects `interface_deviations` in completion reports
2. Automatically invokes `update-agent-prompt` for affected agents
3. Provides operator with:
   - Diff of prompt changes
   - List of agents requiring re-run
   - Approval prompt before re-launching
4. Tracks prompt version in `.saw-state/wave{N}/prompt-log.json`

**Success Criteria:**
- Interface deviation triggers automatic prompt update
- Operator gets clear diff and impact assessment
- Re-launch is one-command operation

**Files to Update:**
- `scout-and-wave-go/pkg/orchestrator/orchestrator.go` - Add deviation detection
- `scout-and-wave-go/pkg/orchestrator/prompt_propagation.go` - New module
- `implementations/claude-code/prompts/saw-skill.md` - Document auto-update flow

---

### E8: Same-Wave Interface Failure (Contract Unimplementable)
**Status:** Partially Implemented
**Risk Level:** Medium
**Execution Rule:** E8 in `protocol/execution-rules.md`

**Problem:**
When agent reports `status: blocked` with `failure_type: needs_replan`, orchestrator doesn't automatically re-engage Scout to revise contracts. Operator must manually update IMPL doc and re-issue prompts.

**Current State:**
- `update-agent-prompt` CLI command exists
- No orchestrator auto-replan logic
- Manual Scout re-engagement required

**Implementation Plan:**
1. Orchestrator detects `failure_type: needs_replan` in completion reports
2. Automatically launches Scout with context:
   - Original IMPL doc
   - Failing agent's completion report (describes why contract failed)
   - Instruction to revise affected contracts only
3. Scout updates Interface Contracts section in IMPL doc
4. Orchestrator runs `check-conflicts` to verify no new ownership issues
5. Calls `update-agent-prompt` for affected agents
6. Provides operator with:
   - Contract diff (old vs new)
   - List of agents requiring re-run
   - Approval prompt before re-launching

**Success Criteria:**
- Contract failure triggers Scout re-engagement automatically
- Contract revision is surgical (only affected interfaces)
- Wave restarts from WAVE_PENDING with corrected contracts

**Files to Update:**
- `scout-and-wave-go/pkg/orchestrator/orchestrator.go` - Add replan detection
- `scout-and-wave-go/pkg/orchestrator/replan.go` - New module
- `implementations/claude-code/prompts/agents/scout.md` - Add contract revision mode
- `implementations/claude-code/prompts/saw-skill.md` - Document replan flow

---

## Priority 3: Operational Polish

### E12: Conflict Resolution Hints
**Status:** Taxonomy Documented
**Risk Level:** Low
**Enhancement Opportunity**

**Problem:**
When `check-conflicts` detects ownership conflicts, it returns raw conflict data. Operator must manually diagnose conflict type (cross-agent, cross-wave, cross-repo) and determine resolution strategy.

**Current State:**
- Conflict taxonomy documented in E12
- No diagnostic tool to suggest resolution

**Implementation Plan:**
1. Implement `sawtools diagnose-conflict` command:
   ```bash
   sawtools diagnose-conflict "<manifest-path>"
   ```
2. Analyzes conflict report and outputs:
   - Conflict type (cross-agent, cross-wave, cross-repo)
   - Root cause (overlapping file ownership, incorrect repo assignment)
   - Suggested resolution (split file, reassign ownership, move to later wave)
   - Example IMPL doc fix

**Success Criteria:**
- Operator gets actionable guidance from conflict report
- Resolution suggestions are accurate 90%+ of time

**Files to Update:**
- `scout-and-wave-go/cmd/saw/diagnose_conflict.go` - New command
- `protocol/execution-rules.md` - Document diagnostic output format

---

### H10: Pre-Commit Hook Verification
**Status:** ✅ Completed 2025-03-14
**Risk Level:** Low (resolved)
**Related:** E4 (Worktree Isolation Layer 0)

**Problem:**
Worktree isolation Layer 0 (pre-commit hook) is installed during `create-worktrees`, but no verification that hook is still present/functional before wave execution. If operator removes `.git/hooks/pre-commit` or hook fails silently, Layer 0 protection is lost.

**Implementation Plan:**
1. Implement `sawtools verify-hook-installed` command:
   ```bash
   sawtools verify-hook-installed "<worktree-path>" --wave <N>
   ```
2. Checks:
   - Hook file exists in `.git/hooks/pre-commit`
   - Hook contains isolation check logic
   - Hook is executable
3. Add to `prepare-wave` as Step 0.5 (after worktree creation, before agent launch)
4. Exit code 1 if any hook missing/broken

**Success Criteria:**
- Silent hook removal is detected before agents launch
- Operator gets clear error message with fix instructions

**Files to Update:**
- `scout-and-wave-go/cmd/saw/verify_hook_installed.go` - New command
- `scout-and-wave-go/cmd/saw/prepare_wave.go` - Add hook verification step

---

### H11: IMPL Doc Validation Caching
**Status:** Not Implemented
**Risk Level:** Low
**Performance Optimization**

**Problem:**
`sawtools validate` re-parses IMPL doc on every invocation. In correction loops (E16), Scout may retry 3 times, re-parsing the same 2KB+ document each time. Wastes ~100-200ms per validation.

**Implementation Plan:**
1. Add validation result caching in `.saw-state/cache/validation-{hash}.json`
2. Hash IMPL doc content (SHA256)
3. On validation request:
   - Check cache for hash match
   - If hit: return cached result (0ms)
   - If miss: validate, cache result
4. Cache expires after 5 minutes
5. Add `--no-cache` flag to bypass

**Success Criteria:**
- Validation on unchanged IMPL doc is <10ms (vs ~150ms uncached)
- Correction loop validation overhead reduced by 70%+

**Files to Update:**
- `scout-and-wave-go/pkg/protocol/validator.go` - Add caching layer
- `scout-and-wave-go/cmd/saw/validate.go` - Add --no-cache flag

---

## Completed Enhancements

### E23A: Tool Journal Recovery + E9: Merge Idempotency
**Completed:** 2025-03-14
**Implementation:** Combined in single IMPL (IMPL-journal-recovery-merge-idempotency)
**Wave Structure:** Single wave, 4 agents (fully parallel)

**E23A Deliverables:**
- `pkg/orchestrator/journal_integration.go` - PrepareAgentContext(), WriteJournalEntry()
- `pkg/journal/observer.go` - LoadJournal(), GenerateContext() implementation
- Enables agents to recover execution history across retries and context compaction
- Supports automatic failure remediation (E7a, E19)

**E9 Deliverables:**
- `pkg/protocol/merge_log.go` - MergeLog type, LoadMergeLog(), SaveMergeLog()
- Idempotency checks integrated into finalize-wave, merge_agents, orchestrator/merge
- .saw-state/wave{N}/merge-log.json tracks completed merges
- Crashed merges can resume without duplicate commits

**Verification:**
- All tests passing (28 new tests total)
- Build verification passed post-merge
- Deployed to scout-and-wave-go develop branch

**Time to Complete:** ~4 hours (Scout 15min + Wave agents 3h20min + Merge/fix 25min)
**Time Estimate:** 33 minutes (actual was longer due to test fix iteration)

---

### H10: Pre-Commit Hook Verification
**Completed:** 2025-03-14
**Implementation:** Direct implementation (no SAW wave execution)

**Deliverables:**
- `cmd/saw/verify_hook_installed.go` - New CLI command (156 lines)
  - Verifies hook file exists in worktree git directory
  - Handles both regular repos and worktrees (.git file vs directory)
  - Checks hook is executable (mode & 0111)
  - Validates hook contains SAW isolation logic markers
  - Returns JSON with verification status
- `cmd/saw/prepare_wave.go` - Integrated as Step 1.5
  - Verifies all hooks after worktree creation, before agent launch
  - Blocks wave execution if any hook missing/invalid
  - Clear error messages for operators
- Layer 0 enforcement of E4 worktree isolation

**Verification:**
- Command builds and runs successfully
- Transparent to agents and orchestrator (no prompt updates needed)
- Zero test overhead (verification runs once per wave in prepare-wave)

**Time to Complete:** ~15 minutes (direct implementation)

---

## Archive: Rejected Enhancement Ideas

### Auto-Merge on Wave Completion
**Rejected:** 2025-03-14
**Reason:** Protocol requires human review checkpoint after each wave (design principle, not implementation gap). Auto-merge removes essential oversight and violates trust model.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.2.0 | 2025-03-14 | Added E23A, E17, markdown deprecation from protocol audit |
| 0.1.0 | 2025-03-14 | Initial roadmap based on E1-E23 audit |

---

## Contributing

Enhancement proposals should:
1. Reference specific execution rule (E{N}) if applicable
2. Describe operator pain point with concrete example
3. Propose implementation plan with success criteria
4. Identify affected files

Submit proposals as issues in `scout-and-wave` repo with label `enhancement`.
