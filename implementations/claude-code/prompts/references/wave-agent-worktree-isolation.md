<!-- Part of wave-agent procedure. Loaded by validate_agent_launch hook. -->
# Worktree Isolation Protocol

You are working in a git worktree. Four lifecycle hooks enforce isolation automatically:

1. **SubagentStart** → `inject_worktree_env` sets `SAW_AGENT_WORKTREE`, `SAW_AGENT_ID`, `SAW_WAVE_NUMBER`, `SAW_IMPL_PATH`, `SAW_BRANCH`
2. **PreToolUse:Bash** → `inject_bash_cd` prepends `cd $SAW_AGENT_WORKTREE &&` to every bash command
3. **PreToolUse:Write|Edit** → `validate_write_paths` blocks relative paths and out-of-worktree writes
4. **SubagentStop** → `verify_worktree_compliance` checks completion report exists

**Why automatic enforcement?** The Bash tool starts each command in the orchestrator's directory (not your worktree). The `inject_bash_cd` hook solves this by prepending `cd $SAW_AGENT_WORKTREE &&` automatically.

## Step 1: Read Your Pre-Extracted Brief (MANDATORY)

Your brief is pre-extracted before launch to eliminate startup latency:

```bash
Read .saw-agent-brief.md
```

Contains:
- Your agent ID and wave number
- Files you own (Field 1)
- Task instructions (Field 2)
- Interface contracts you must implement or call
- Quality gates you must pass

## Step 2: File Operations

### Read/Write/Edit - Use Absolute Paths
The `$SAW_AGENT_WORKTREE` environment variable is set automatically by hooks:

```bash
Read $SAW_AGENT_WORKTREE/pkg/module/file.go
Write $SAW_AGENT_WORKTREE/pkg/module/newfile.go
Edit $SAW_AGENT_WORKTREE/pkg/module/file.go
```

**Note:** Relative paths are blocked by the `validate_write_paths` hook.

### Bash Commands - Work Naturally
The `inject_bash_cd` hook makes relative paths work in bash:

```bash
go test ./pkg/module
# Hook transforms to: cd $SAW_AGENT_WORKTREE && go test ./pkg/module
```

### Git Operations - Use -C Flag
Hooks don't modify git commands, so use explicit worktree targeting:

```bash
git -C $SAW_AGENT_WORKTREE status
git -C $SAW_AGENT_WORKTREE add pkg/module/
git -C $SAW_AGENT_WORKTREE commit -m "message"
```

**For tests requiring repo root:**
```bash
cd $SAW_AGENT_WORKTREE && go test ./pkg/module
```

## Special Cases

### go.mod replace directives (Go projects)
**Do NOT modify `replace` directives.** Relative paths (e.g. `../sibling-module`) are correct relative to the repo root, not your worktree. Your worktree is nested inside `.claude/worktrees/saw/{slug}/wave{N}-agent-{ID}/`, so paths look wrong from your perspective — but they resolve correctly after merge. If you rewrite them to match your worktree depth (e.g. `../../../../sibling-module`), they will break after merge.

## Troubleshooting

### Verify hooks are active
```bash
jq '.hooks.SubagentStart, .hooks.PreToolUse[] | select(.hooks[].command | contains("inject_"))' ~/.claude/settings.json
```

**Expected:** Should show `inject_worktree_env`, `inject_bash_cd`, `validate_write_paths`

### If hooks aren't registered
Run `./install.sh --claude-code` from scout-and-wave repo.

### If you encounter isolation violations
Report in your completion report with:
```bash
sawtools set-completion --status blocked --failure-type escalate --notes "Isolation violation: [describe issue]"
```

## Environment Variables Available

The `inject_worktree_env` hook sets these automatically:
- `$SAW_AGENT_WORKTREE` - Your worktree path
- `$SAW_AGENT_ID` - Your agent ID (A, B, C, etc.)
- `$SAW_WAVE_NUMBER` - Current wave number
- `$SAW_IMPL_PATH` - Path to IMPL doc
- `$SAW_BRANCH` - Your worktree branch name
