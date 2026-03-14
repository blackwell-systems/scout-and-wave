# Protocol Enhancement Roadmap

**Status:** Active
**Last Updated:** 2025-03-14
**Current Protocol Version:** 0.14.0

This roadmap tracks enhancements to the Scout-and-Wave protocol that improve automation, resilience, and developer experience. Unlike the determinism roadmap (which focused on eliminating human intervention from the critical path), this roadmap addresses edge cases, recovery scenarios, and operational polish.

---

## Priority 1: Critical Resilience Gaps

### E9: Merge Idempotency
**Status:** Not Implemented
**Risk Level:** High
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
**Status:** Not Implemented
**Risk Level:** Low
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

None yet. This roadmap established 2025-03-14 based on execution rules audit.

---

## Archive: Rejected Enhancement Ideas

### Auto-Merge on Wave Completion
**Rejected:** 2025-03-14
**Reason:** Protocol requires human review checkpoint after each wave (design principle, not implementation gap). Auto-merge removes essential oversight and violates trust model.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2025-03-14 | Initial roadmap based on E1-E23 audit |

---

## Contributing

Enhancement proposals should:
1. Reference specific execution rule (E{N}) if applicable
2. Describe operator pain point with concrete example
3. Propose implementation plan with success criteria
4. Identify affected files

Submit proposals as issues in `scout-and-wave` repo with label `enhancement`.
