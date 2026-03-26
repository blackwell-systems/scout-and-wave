<!-- Part of wave-agent procedure. Loaded by validate_agent_launch hook. -->
# Worktree Isolation Protocol

**CRITICAL:** You are working in a git worktree. All git operations MUST use absolute paths to ensure commands execute in your worktree, not the main repository.

### Step 0: Verify Isolation and Capture Worktree Path (MANDATORY FIRST STEP)

Your worktree path and branch name are provided in your agent prompt (Field 1). **Before any other work**, run this verification and capture the absolute worktree path:

```bash
# Verify isolation (this also validates you're in a worktree, not main repo)
cd /full/path/to/your/worktree && sawtools verify-isolation --branch saw/{slug}/wave{N}-agent-{ID}
```

**Expected output:**
```json
{
  "ok": true,
  "branch": "saw/my-feature/wave1-agent-A"
}
```

**If verification fails** (exit code 1, `"ok": false`): STOP immediately. Do not create any files. The JSON output will contain an `"errors"` array explaining the failure. Report the isolation failure in your completion report with `status: blocked` and `failure_type: escalate`.

**After verification passes, save your worktree path as an environment variable for all subsequent operations:**

```bash
WORKTREE=/full/path/to/your/worktree
```

**Why this matters:**
- `verify-isolation` now checks that your current directory path contains `.claude/worktrees/` — if you accidentally run it in the main repo, it will fail
- The Bash tool **does not preserve working directory** between calls — `cd` in one command doesn't affect the next
- You **must use absolute paths** (via `$WORKTREE` variable or explicit paths) for ALL file operations
- This prevents the Agent B leak scenario where files are created in the main repo instead of the worktree

### Step 0.5: Read Your Pre-Extracted Brief (MANDATORY SECOND STEP)

After verification passes, read your agent brief from the pre-extracted file:

**For worktree agents:**
```bash
Read $WORKTREE/.saw-agent-brief.md
```

**For solo agents (no worktree):**
```bash
Read .saw-state/wave{N}/agent-{ID}/brief.md
```

The orchestrator runs `sawtools prepare-agent` before launching you, which extracts your task, file ownership, interface contracts, and quality gates from the IMPL doc into this file. This eliminates the ~10s latency of calling `extract-context` at startup.

The brief contains:
- Your agent ID and wave number
- Files you own (Field 1)
- Task instructions (Field 2)
- Interface contracts you must implement or call
- Quality gates you must pass

### All File Operations: Use Absolute Paths

**CRITICAL:** The Bash tool does **NOT** preserve working directory between calls. You must use absolute paths for ALL operations (file reads, writes, git commands, test execution).

**Pattern: Use $WORKTREE variable**

After Step 0 verification, reference your worktree path via the `$WORKTREE` variable:

```bash
# File operations with Read/Write/Edit tools
Read: $WORKTREE/pkg/module/file.go
Write: $WORKTREE/pkg/module/newfile.go
Edit: $WORKTREE/pkg/module/file.go

# Git operations (use -C flag)
git -C $WORKTREE status
git -C $WORKTREE add pkg/module/
git -C $WORKTREE commit -m "message"

# Test execution (use -C flag to change directory before running)
cd $WORKTREE && go test ./pkg/module
# OR for one-liners:
git -C $WORKTREE rev-parse --show-toplevel | xargs -I {} sh -c 'cd {} && go test ./pkg/module'
```

**NEVER do this:**
```bash
# WRONG: cd doesn't persist to next Bash call
cd $WORKTREE
go test ./pkg/module  # This runs in a DIFFERENT directory!

# WRONG: Relative paths assume current directory
Write: pkg/module/file.go  # Where is "pkg"? Might be main repo!
```

**Why this matters:** Every Bash tool invocation starts fresh in the orchestrator's working directory (usually the main repo). If you use relative paths or rely on `cd`, file operations will execute in the main repo, causing the Agent B leak scenario.

### go.mod replace directives (Go projects)

**Do NOT modify `replace` directives in `go.mod`.** Relative paths in replace blocks (e.g. `../sibling-module`) are correct relative to the **repo root**, not your worktree. Your worktree is nested deep inside `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}/`, so the relative paths look wrong from your perspective — but they resolve correctly when the branch is merged back to main. If you rewrite them to match your worktree depth (e.g. `../../../../sibling-module`), they will break after merge.
