# QUICKSTART.md Modernization Changes

**Date:** 2026-03-11

## Changes Made

### Section: Prerequisites
- **Issue:** Did not mention `sawtools` binary requirement
- **Fix:** Added `sawtools` binary installation checkpoint (`~/.local/bin/sawtools` from scout-and-wave-go)
- **Impact:** Users now know they need the Go SDK binary installed, not just the protocol repo

### Section: Scout Output (Step 2)
- **Issue:** Referenced `.md` file extension for IMPL doc
- **Fix:** Changed `docs/IMPL/IMPL-simple-cache.md` → `docs/IMPL/IMPL-simple-cache.yaml`
- **Impact:** Reflects protocol v0.7.0+ YAML-only mandate

### Section: Review the IMPL doc (Step 3)
- **Issue:** Showed markdown table format for file ownership, markdown table for scaffolds, markdown for interface contracts
- **Fix:**
  - Replaced markdown tables with YAML array syntax for `file_ownership`
  - Replaced markdown table with YAML array syntax for `scaffolds`
  - Replaced markdown code block with YAML array syntax for `interface_contracts`
- **Impact:** Users see the actual YAML structure they will encounter in scout v0.7.1+ output

### Section: Review the IMPL doc - Duplicate File Ownership Tables
- **Issue:** File ownership table was duplicated 5 times (lines 88-113), likely a copy-paste error
- **Fix:** Removed duplicates, kept single YAML example
- **Impact:** Cleaner document, no confusion

### Section: Agent Prompts (Step 3)
- **Issue:** Described "agent prompts" as if they were standalone sections in the IMPL doc
- **Fix:** Clarified that agents have task specifications in the `waves` array, and the orchestrator wraps these with the 9-field template at launch time
- **Impact:** More accurate description of how E23 per-agent context extraction works

### Section: Agent execution (Step 4c)
- **Issue:** Did not mention completion report writing mechanism
- **Fix:** Added "Writing completion reports (via `sawtools set-completion`)" to agent execution list and periodic updates
- **Impact:** Users understand completion reports are written via sawtools CLI, not free-form

### Section: Agents complete and report (Step 4d)
- **Issue:** Showed prose-style completion report format
- **Fix:** Replaced with actual YAML structure showing `completion_reports` map with agent IDs as keys
- **Impact:** Users see the exact YAML schema agents write to (wave-agent v0.4.1 uses `sawtools set-completion`)

### Section: Orchestrator merges (Step 5)
- **Issue:** Showed raw git commands without sawtools wrapper
- **Fix:** Added `sawtools verify-commits` and `sawtools merge-agents` commands
- **Impact:** Reflects actual orchestrator behavior using SDK CLI (saw-skill.md v0.9.0)

### Section: Post-merge verification (Step 6)
- **Issue:** Showed verification steps without sawtools command
- **Fix:** Added `sawtools verify-build` command wrapping the verification steps
- **Impact:** Consistent with SDK-based orchestration model

### Section: Cleanup and completion (Step 7)
- **Issue:** Did not show E15 completion marker or E18 project memory update
- **Fix:** Added `sawtools cleanup` and `sawtools mark-complete` commands (always archives to `complete/`)
- **Impact:** Users see the full lifecycle including IMPL doc archival to `docs/IMPL/complete/`

### Section: Troubleshooting - Scaffold Agent
- **Issue:** Referenced "Scaffolds section" generically
- **Fix:** Specified `scaffolds` YAML section with `status: FAILED: <reason>` format
- **Impact:** Users know where to look for scaffold build errors in YAML structure

## Conformity Check

- [x] Protocol conformance (YAML format, E1-E23)
  - YAML manifest format throughout (message-formats.md v0.14.0)
  - References to sawtools CLI commands (execution-rules.md E15, E18, E20, E21)
  - Completion report schema matches protocol (wave-agent v0.4.1)
- [x] Go engine references (sawtools commands)
  - All orchestrator operations use sawtools CLI
  - Command syntax matches scout-and-wave-go v0.18.0+
- [x] Web app accuracy (if mentioned)
  - Not mentioned in QUICKSTART (CLI-focused)
- [x] Agent versions current
  - scout.md v0.7.1 (YAML output)
  - wave-agent.md v0.4.1 (sawtools set-completion)
  - References match current implementations
- [x] File paths verified
  - `~/.local/bin/sawtools` correct
  - `docs/IMPL/IMPL-*.yaml` correct
  - `.claude/worktrees/wave{N}-agent-{ID}` correct
- [x] Command syntax matches saw-skill.md
  - `/saw scout`, `/saw wave`, `/saw status` syntax preserved
  - sawtools command syntax matches SDK
- [x] Examples tested conceptually
  - YAML examples conform to pkg/protocol/types.go schema
  - File ownership, scaffolds, completion reports all valid

## Breaking Changes for Users

None. The changes are corrections to match current implementation, not changes to user-facing commands or workflows. Users who followed the old guide would have encountered mismatches (markdown vs YAML); this update eliminates that friction.

## Recommendations

### Additional Modernization (Not Implemented - Out of Scope for This Update)

1. **Add Web UI section:** Now that scout-and-wave-web is ~95% complete, a "Visual Alternative" section showing the web UI could be added. Would show:
   - Starting the server (`cd ~/code/scout-and-wave-web && ./saw serve`)
   - Opening `http://localhost:7432`
   - Running scout/wave/review cycle visually
   - Dependency graph panel
   - Manifest validation panel

2. **Add tool journaling context:** E23A tool journal recovery is now live. A brief note on "what happens if an agent times out" could explain that agents recover execution history from the journal, not just from conversation context.

3. **Add --impl flag examples:** saw-skill v0.9.0 added explicit IMPL targeting. Could add examples:
   ```
   /saw wave --impl tool-journaling
   /saw status --impl IMPL-cache.yaml
   ```

4. **Add version numbers to headings:** Could add agent version numbers in section headings so readers know which version the guide reflects.

5. **Cross-reference protocol docs:** Could add "See protocol/execution-rules.md E{N}" citations in key sections for readers who want deeper detail.

### Why These Were Not Done

The task was to "update for modern conformity," not to expand the guide. The above are enhancements, not corrections. They would increase cognitive load for first-time users. QUICKSTART should remain minimal.

## Testing Notes

All YAML examples were validated against:
- `pkg/protocol/types.go` in scout-and-wave-go (IMPLManifest schema)
- `protocol/message-formats.md` v0.14.0 (YAML manifest structure)
- `implementations/claude-code/prompts/agents/scout.md` v0.7.1 (scout output format)

No syntax errors in YAML examples. All field names match SDK schema.
