# SAW Hook System

SAW enforces protocol invariants through three independent enforcement layers
that operate at different stages of the tool-execution pipeline. Each layer
catches violations that earlier layers might miss, providing defense in depth.

- **Layer 1** (Claude Code Hooks) intercepts tool calls before/after execution
  in the CLI environment.
- **Layer 2** (Git Pre-Commit Hook) blocks invalid commits inside Wave agent
  worktrees.
- **Layer 3** (SDK Constraint Middleware) enforces invariants in-process when
  the Go engine/web app drives tool execution.

## Exit Code Semantics (Layer 1)

Claude Code hooks use exit codes to signal disposition:

| Exit code | Meaning |
|-----------|---------|
| `0` | Allow — tool execution proceeds |
| `1` | Non-blocking error — logged, but execution continues |
| `2` | Block — tool execution is prevented; message on stderr shown to model |

Most SAW enforcement hooks use **exit 2** to block. `check_git_ownership` is an
intentional exception: it runs PostToolUse (the git command has already
executed), so it uses exit 0 with a warning message instead of blocking.

`block_claire_paths` uses a separate JSON-response protocol: it writes
`{"decision":"block","reason":"..."}` to stdout and exits 0. Claude Code reads
this JSON to determine whether to block.

## Overview Table

| Hook | Layer | Invariant | Trigger | Blocks / Warns |
|------|-------|-----------|---------|----------------|
| `check_scout_boundaries` | 1 (PreToolUse) | I6 | Scout calls Write or Edit | Blocks Scout writing outside `docs/IMPL/IMPL-*.yaml` |
| `check_wave_ownership` | 1 (PreToolUse) | I1 | Wave agent calls Write, Edit, or NotebookEdit | Blocks Wave agent writing files not in its `.saw-ownership.json` |
| `block_claire_paths` | 1 (PreToolUse) | -- | Any agent calls Write, Edit, or Bash | Blocks operations targeting `.claire` paths (model hallucination guard) |
| `validate_agent_launch` | 1 (PreToolUse) | H5 | Any Agent tool call with `[SAW:waveN:agent-ID]` tag | Blocks agent launch if IMPL doc is missing, invalid, agent not found, or scaffold not committed |
| `validate_impl_on_write` | 1 (PostToolUse) | E16 | Any agent calls Write on an IMPL doc | Blocks saving an IMPL doc that fails `sawtools validate` |
| `check_git_ownership` | 1 (PostToolUse) | I1 | Wave agent calls Bash with git checkout/merge/rebase/etc. | Warns (non-blocking) when git operations modify files outside ownership list |
| SAW pre-commit guard | 2 (Git hook) | I4 | `git commit` in a worktree | Blocks commits to `main`/`master` from agent worktrees |
| SAW go.mod guard | 2 (Git hook) | -- | `git commit` touching `go.mod` | Blocks `replace` directives with deep relative paths (`../../..`) |
| `validate_agent_completion` | 1 (SubagentStop) | E42/I1/I4/I5 | SAW agent session ends | Blocks completion if protocol obligations unfulfilled |
| Ownership middleware | 3 (SDK) | I1 | Engine Write/Edit tool execution | Blocks agent writing files outside `OwnedFiles` map |
| Freeze middleware | 3 (SDK) | I2 | Engine Write/Edit tool execution | Blocks agent writing to frozen interface paths after freeze time |
| Role path middleware | 3 (SDK) | I6 | Engine Write/Edit tool execution | Blocks agent writing outside `AllowedPathPrefixes` |

---

## Layer 1: Claude Code Hooks

Claude Code hooks are bash scripts registered in `~/.claude/settings.json`.
They receive JSON on stdin describing the tool call. PreToolUse hooks exit 2 to
block (with an error message on stderr) or exit 0 to allow. PostToolUse hooks
exit 2 to surface a blocking error to the model, exit 1 for a non-blocking log,
or exit 0 to pass silently.

### Installation

The installer script lives at:

```
implementations/claude-code/hooks/install.sh
```

It performs these steps:

1. **Creates symlinks** in `~/.local/bin/` pointing to the hook scripts in the
   repo:
   - `~/.local/bin/check_scout_boundaries`
   - `~/.local/bin/block_claire_paths`
   - `~/.local/bin/validate_impl_on_write`
   - `~/.local/bin/check_wave_ownership`
   - `~/.local/bin/check_git_ownership`
   - `~/.local/bin/validate_agent_launch`
   - `~/.local/bin/validate_agent_completion`
   - `~/.local/bin/emit_agent_completion`
   - (plus `check_impl_path`, `warn_stubs`, `check_branch_drift` — referenced
     in the installer but scripts not yet present in repo; these steps fail
     silently if scripts are missing)

2. **Merges hook configuration** into `~/.claude/settings.json` using `jq`:
   - `PreToolUse`: `check_scout_boundaries` (matcher `Write|Edit`)
   - `PreToolUse`: `block_claire_paths` (matcher `Write|Edit|Bash`)
   - `PreToolUse`: `check_wave_ownership` (matcher `Write|Edit|NotebookEdit`)
   - `PreToolUse`: `validate_agent_launch` (matcher `Agent`)
   - `PostToolUse`: `validate_impl_on_write` (matcher `Write`)
   - `PostToolUse`: `check_git_ownership` (matcher `Bash`)
   - `SubagentStop`: `validate_agent_completion` (blocking, timeout 10s) + `emit_agent_completion` (async)

3. **Verifies** the installation by checking symlinks are executable and
   settings.json contains the hook entries, then runs a smoke test (valid and
   invalid path).

The symlink model means pulling the latest repo revision updates hook behavior
without re-running the installer.

**Prerequisites:** `jq` must be installed (`brew install jq`).

### check_scout_boundaries (I6)

**File:** `implementations/claude-code/hooks/check_scout_boundaries`
**Type:** PreToolUse
**Matcher:** `Write|Edit`
**Exit to block:** 2
**Invariant:** I6 (role-based path boundaries)

Restricts Scout agents to writing only IMPL planning documents. Reads JSON
from stdin and extracts `tool_name`, `agent_type`, and `tool_input.file_path`.

**Logic:**
- Exits 0 (allow) if `agent_type` is not `"scout"` — only Scouts are constrained.
- Exits 0 if `tool_name` is not `Write` or `Edit`.
- Normalizes the file path and checks: directory must be exactly `docs/IMPL`
  and filename must match `IMPL-*.yaml`. Subdirectories (e.g., `docs/IMPL/complete/`)
  are rejected.
- Exits 2 with an `I6 VIOLATION` message on stderr for anything else.

**Example block output:**
```
I6 VIOLATION: Scout agents create IMPL planning documents only.

Attempted: src/main.go
Allowed: docs/IMPL/IMPL-<feature-slug>.yaml
```

### check_wave_ownership (I1)

**File:** `implementations/claude-code/hooks/check_wave_ownership`
**Type:** PreToolUse
**Matcher:** `Write|Edit|NotebookEdit`
**Exit to block:** 2
**Invariant:** I1 (disjoint file ownership)

Restricts Wave agents to writing only files listed in their ownership manifest.

**Logic:**
- Exits 0 if `agent_type` is not `"wave-agent"`.
- Exits 0 if `tool_name` is not `Write`, `Edit`, or `NotebookEdit`.
- Walks up from `$PWD` (up to 5 levels) looking for `.saw-ownership.json`.
  If not found, assumes this is not a SAW wave context and allows the operation.
- Reads the `owned_files` array and `agent` ID from the manifest.
- Normalizes the target path relative to the worktree root (handles both
  absolute and relative paths).
- Checks exact match against `owned_files`, then checks if any owned path is
  a directory prefix of the target.
- Exits 2 with an `I1 VIOLATION` message on stderr if the file is not owned.

**Example block output:**
```
I1 VIOLATION: Wave agent B (wave 1) attempted to write a file it does not own.

Attempted: pkg/api/routes.go
Normalized: pkg/api/routes.go

Owned files for this agent:
  - web/src/components/Dashboard.tsx
  - web/src/types.ts
```

### block_claire_paths

**File:** `implementations/claude-code/hooks/block_claire_paths`
**Type:** PreToolUse
**Matcher:** `Write|Edit|Bash`
**Exit to block:** JSON response (`{"decision":"block","reason":"..."}`) + exit 0
**Invariant:** None (model hallucination guard)

Blocks tool calls that reference `.claire` in file paths. This is a guardrail
against a known, widespread model hallucination where the model writes `.claire`
instead of `.claude` for directory paths (e.g., `~/.claire/settings.json`
instead of `~/.claude/settings.json`).

**Note on exit code:** Unlike other SAW hooks, this hook uses the JSON-response
protocol: it writes `{"decision":"block","reason":"..."}` to stdout and exits
0. Claude Code reads the JSON `decision` field to decide whether to block. The
exit code itself does not drive the block decision here.

**Logic:**
- Inspects `tool_input.file_path` or `tool_input.command` for any string
  containing `.claire`.
- Returns `{"decision":"block","reason":"BLOCKED: ..."}` if `.claire` is found.
- Returns `{"decision":"approve"}` otherwise.

**Example block output (stdout JSON):**
```json
{"decision":"block","reason":"BLOCKED: You wrote .claire — the correct directory is .claude. Fix the path and retry."}
```

### validate_agent_launch (H5)

**File:** `implementations/claude-code/hooks/validate_agent_launch`
**Type:** PreToolUse
**Matcher:** `Agent`
**Exit to block:** 2
**Invariant:** H5 (pre-launch validation gate)

Fires before every `Agent` tool call. Non-SAW agents (no `[SAW:waveN:agent-ID]`
tag in the description field) pass through immediately. For SAW agents, runs
up to 8 validation checks before allowing the agent to launch.

**Logic:**
1. Parses `[SAW:wave{N}:agent-{ID}]` from the Agent tool's `description` field.
   Exits 0 (pass) if the tag is absent.
2. Extracts the IMPL doc path from the prompt (`docs/IMPL/IMPL-*.yaml` pattern).
   Exits 2 if not found.
3. Verifies the IMPL file exists on disk. Exits 2 if not found.
4. Runs `sawtools validate <impl>` if `sawtools` is on `$PATH`. Exits 2 if
   validation fails. (Skips silently if `sawtools` is unavailable.)
5. Verifies the agent ID exists in the specified wave using `yq` (with grep
   fallback). Exits 2 if not found.
6. If `.saw-ownership.json` is found in the worktree: verifies `agent` and
   `wave` fields match the SAW tag. Exits 2 on mismatch.
7. Checks that the worktree's current git branch ends in
   `wave{N}-agent-{ID}`. Exits 2 on branch mismatch.
8. Verifies all scaffolds in the IMPL doc have `status: committed` (using `yq`
   with grep fallback). Exits 2 if any scaffold is uncommitted.

**Example block output:**
```
H5: No IMPL doc path found in agent prompt. Agent A (wave 1) cannot launch without an IMPL doc reference in the prompt.
```

### validate_impl_on_write (E16)

**File:** `implementations/claude-code/hooks/validate_impl_on_write`
**Type:** PostToolUse
**Matcher:** `Write`
**Exit to block:** 2
**Invariant:** E16 (IMPL document validation)

Automatically validates IMPL documents after they are written, catching schema
errors immediately rather than at wave-preparation time.

**Logic:**
- Exits 0 if `jq` is not available (graceful degradation).
- Extracts `tool_input.file_path` from stdin JSON.
- Matches only active IMPL docs: paths matching `*/docs/IMPL/IMPL-*.yaml` or
  `*/docs/IMPL/IMPL-*.yml`. Skips archived docs in `*/docs/IMPL/complete/*`.
- Exits 0 if the file does not exist or `sawtools` is not on `$PATH`.
- Runs `sawtools validate <file>` and parses the JSON output.
- If `valid` is `true`, exits 0.
- If validation fails, exits 2 with the error count and messages on stderr.

**Example block output:**
```
BLOCKED: IMPL validation failed (3 errors). Fix these before continuing:
missing required field: feature_slug
wave 1 agent A has no owned_files
gates[0] missing agent_id
```

### check_git_ownership (I1 layer 2)

**File:** `implementations/claude-code/hooks/check_git_ownership`
**Type:** PostToolUse
**Matcher:** `Bash`
**Exit to block:** N/A — non-blocking warning (always exits 0)
**Invariant:** I1 (disjoint file ownership)

A second layer of I1 enforcement that catches ownership violations that bypass
the Write/Edit hooks — specifically git operations like `git checkout --theirs`,
`git merge`, `git rebase`, and `git restore` that can modify files without going
through the Write or Edit tools.

Because the Bash command has already executed by the time this PostToolUse hook
fires, it cannot undo the file modification. Instead it warns the agent and
instructs it to revert the unowned changes before committing.

**Logic:**
- Only fires for `wave-agent` agents using the `Bash` tool.
- Skips commands that don't match `git (checkout|merge|rebase|cherry-pick|stash|reset|restore)`.
- Walks up from `$PWD` looking for `.saw-ownership.json`. Exits 0 if not found
  (not a SAW context).
- Runs `git diff --name-only HEAD` and `git diff --name-only --cached` to list
  all changed files.
- Checks each changed file against `owned_files` (exact match and directory
  prefix).
- If any unowned files are found, prints a `WARNING:` block to stdout listing
  the violations and instructing the agent to `git checkout HEAD -- <file>`
  for each.
- Always exits 0 (non-blocking).

**Example warning output:**
```
WARNING: Git operation modified files outside your ownership list.

Agent: B (wave 1)
Files outside ownership:
  - pkg/api/routes.go

These changes likely came from a merge conflict resolution. Do NOT commit them.
Instead:
1. Run: git checkout HEAD -- <file> for each file listed above
2. Only commit files in your ownership list
3. If a conflict blocks your work, report status: blocked
```

---

## Hook 10: Agent Completion Validation (E42)

**SubagentStop** — Validates protocol compliance when a SAW agent session ends.
Blocks agent completion if protocol obligations are unfulfilled. Fires two
hooks in sequence: a blocking validator and an async observability emitter.

### File

- `implementations/claude-code/hooks/validate_agent_completion` (blocking)
- `implementations/claude-code/hooks/emit_agent_completion` (async)

### Type

SubagentStop (fires when an agent subprocess completes)

### Exit Codes

| Exit code | Meaning |
|-----------|---------|
| `0` | Pass — agent fulfilled obligations or is not a SAW agent |
| `2` | Block — agent has unfulfilled protocol obligations |

Stderr contains human-readable error message explaining what is missing.
Stdout contains JSON observability event on success (from the async emitter).

### Validation Sequence

The blocking hook (`validate_agent_completion`) runs the following checks based
on agent type, parsed from the `agent_description` field's `[SAW:waveN:agent-ID]`
tag:

1. **SAW agent detection** — Parses `[SAW:wave{N}:agent-{ID}]` from
   `agent_description`. Non-SAW agents pass through immediately (exit 0).
2. **IMPL doc discovery** — Locates the IMPL doc from `.saw-agent-brief.md`
   or the worktree's `.saw-state/` directory.
3. **I5: Commit verification** — Checks that the agent's worktree branch has
   commits (agents must commit before reporting complete).
4. **I4: Completion report verification** — Uses `sawtools check-completion`
   to verify the agent wrote a completion report to the IMPL doc.
5. **I1: Ownership verification** — Cross-references committed files against
   the agent's `.saw-ownership.json` to confirm no out-of-scope writes.

If any check fails, the hook exits 2 with a descriptive error on stderr,
blocking the agent from completing until obligations are fulfilled.

The async hook (`emit_agent_completion`) runs after the blocking hook passes:

1. **Journal archival** — Archives the agent's tool journal for post-session
   analysis.
2. **Observability event** — Emits a structured JSON event to stdout for
   consumption by claudewatch and the web app SSE pipeline.

The async hook uses `"async": true` in the hook configuration so it never
slows down agent lifecycle. Failures in the async hook are logged but not
fatal.

### Observability Event Schema

```json
{
  "event": "agent_complete",
  "agent_id": "A",
  "wave": 1,
  "agent_type": "wave",
  "status": "complete",
  "files_changed": ["file1.go", "file2.go"],
  "validation_checks": {
    "i1_ownership": "pass",
    "i5_commit": "pass",
    "protocol_report": "pass",
    "journal_archived": true
  },
  "duration_ms": 45000,
  "timestamp": "2026-03-23T12:00:00Z"
}
```

### Manual Installation

1. Symlinks:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/validate_agent_completion ~/.local/bin/validate_agent_completion
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/emit_agent_completion ~/.local/bin/emit_agent_completion
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SubagentStop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/validate_agent_completion",
               "timeout": 10
             },
             {
               "type": "command",
               "command": "$HOME/.local/bin/emit_agent_completion",
               "async": true
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Non-SAW agent — should exit 0 (pass through)
echo '{"session_id":"abc","agent_name":"helper","agent_description":"general helper","exit_reason":"completed"}' | validate_agent_completion
echo $?  # 0

# SAW agent with fulfilled obligations — should exit 0
echo '{"session_id":"abc","agent_name":"wave-A","agent_description":"[SAW:wave1:agent-A] implement feature","exit_reason":"completed"}' | validate_agent_completion
echo $?  # 0 (if all obligations met)

# SAW agent with missing completion report — should exit 2
echo '{"session_id":"abc","agent_name":"wave-A","agent_description":"[SAW:wave1:agent-A] implement feature","exit_reason":"completed"}' | validate_agent_completion 2>&1
echo $?  # 2 (if completion report missing)
```

---

## Layer 2: Git Pre-Commit Hook

A bash pre-commit hook installed into each Wave agent worktree. This is the
last line of defense before code is committed — it cannot be bypassed by
agent prompt manipulation.

### Hook Content

The hook template is embedded as `preCommitHookTemplate` in:

```
scout-and-wave-go/internal/git/commands.go
```

It enforces two rules:

#### Main branch protection (I4)

Blocks `git commit` when the current branch is `main` or `master`. Wave agents
must commit only to their dedicated `wave{N}-agent-{ID}` branches.

**Bypass:** Set `SAW_ALLOW_MAIN_COMMIT=1` (used by the SAW orchestrator during
merge operations).

**Error output:**
```
SAW isolation violation: Cannot commit to main from Wave agent worktree
```

#### go.mod deep-path guard

Blocks commits that add `replace` directives in `go.mod` with deep relative
paths (three or more `../` segments). These paths are relative to the worktree
depth, not the repo root, and break after merge.

The check scans `git diff --cached -- go.mod` for lines matching
`^\+.*=>.*\.\./\.\./\.\.`.

**Error output:**
```
SAW go.mod guard: replace directive has deep relative path (../../../...)
```

### Installation

`InstallHooks(repoPath, worktreePath)` in `internal/git/commands.go`:

1. Reads the `.git` file in the worktree to find the gitdir pointer
   (e.g., `/path/to/repo/.git/worktrees/<name>`).
2. Creates the `hooks/` directory under that gitdir if it does not exist.
3. Writes the hook template to `hooks/pre-commit` with mode `0755`.

This function is called automatically during worktree creation in
`pkg/protocol/worktree.go` (standard waves) and `pkg/protocol/program_worktree.go`
(program-tier waves). If installation fails, a warning is printed to stderr
but worktree creation is not aborted — the `prepare-wave` verification step
catches missing hooks.

### Verification

```bash
sawtools verify-hook-installed <worktree-path> [--wave N]
```

Implemented in `cmd/saw/verify_hook_installed.go`. Returns JSON:

```json
{
  "valid": true,
  "hook_path": "/path/to/.git/worktrees/wave1-agent-A/hooks/pre-commit",
  "executable": true,
  "has_logic": true
}
```

Checks:
1. Hook file exists at the correct path (handles both regular repos and worktrees).
2. Hook file is executable (`mode & 0111 != 0`).
3. Hook content contains SAW isolation logic (looks for `SAW_ALLOW_MAIN_COMMIT`
   or `SAW pre-commit guard` strings).

There is also a Go function `VerifyHookInWorktree(worktreePath)` in
`internal/git/commands.go` that performs the same checks programmatically,
returning `(bool, error)`.

---

## Layer 3: SDK Constraint Middleware

In-process Go middleware that wraps tool execution in the engine and web app.
This layer enforces invariants without relying on external scripts or git hooks.

### Architecture

The middleware system is defined across two files in `pkg/tools/`:

- **`constraints.go`** — Defines the `Constraints` struct that configures
  enforcement per-agent.
- **`constraint_enforcer.go`** — Implements the three middleware functions
  and registers them via `init()`.

The `Constraints` struct carries all enforcement configuration:

```go
type Constraints struct {
    OwnedFiles          map[string]bool   // I1: files this agent may write
    FrozenPaths         map[string]bool   // I2: paths frozen after worktree creation
    FreezeTime          *time.Time        // I2: when freeze took effect (nil = disabled)
    TrackCommits        bool              // I5: track git commit invocations
    AllowedPathPrefixes []string          // I6: path prefixes for role restriction
    AgentRole           string            // "scout" | "wave" | "scaffold"
    AgentID             string            // e.g., "A", "B"
}
```

A zero-value `Constraints` applies no enforcement (backward compatible).

Middleware constructors are registered in `init()` and override passthrough
stubs from `workshop_constrained.go`. Each middleware wraps a `ToolExecutor`,
inspecting the `file_path` or `path` key in the tool input map before
delegating to the next executor in the chain.

### Ownership middleware (I1)

**Constructor:** `newOwnershipMiddleware`
**Error code:** `I1_VIOLATION`

Blocks Write/Edit to any path not present in `Constraints.OwnedFiles`. Used
for Wave agents where file ownership is extracted from the IMPL manifest.

If `OwnedFiles` is empty (nil map), no restriction is applied.

### Freeze middleware (I2)

**Constructor:** `newFreezeMiddleware`
**Error code:** `I2_VIOLATION`

Blocks Write/Edit to paths listed in `Constraints.FrozenPaths`, but only when
`Constraints.FreezeTime` is non-nil. This enforces interface stability after
worktree creation — shared interface files cannot be modified by agents once
the wave begins.

### Role path middleware (I6)

**Constructor:** `newRolePathMiddleware`
**Error code:** `I6_VIOLATION`

Blocks Write/Edit to paths that do not match any prefix in
`Constraints.AllowedPathPrefixes`. If the prefix list is empty, the middleware
is a passthrough (Wave agents rely on ownership middleware instead).

Typical configuration:
- Scout agents: `AllowedPathPrefixes: ["docs/IMPL/IMPL-"]`
- Wave agents: empty (uses OwnedFiles instead)

### Post-execution validation (pkg/hooks)

The `pkg/hooks/` package in `scout-and-wave-go` provides a Go-native
post-execution boundary check:

- **`ValidateScoutWrites(repoPath, expectedIMPLPath, startTime)`** — Walks
  `docs/` looking for files modified after `startTime` that are not the
  expected IMPL doc or a valid `docs/IMPL/IMPL-*.yaml` path. Returns an
  `I6 VIOLATION` error listing unauthorized writes.
- **`IsValidScoutPath(filePath)`** — Pure predicate: returns true only for
  paths matching `docs/IMPL/IMPL-*.yaml` (not subdirectories, not `.yml`).

These are used for after-the-fact auditing, not real-time blocking.

---

## Troubleshooting

### Layer 1: Claude Code hooks not firing

1. **Check symlinks exist and are executable:**
   ```bash
   ls -la ~/.local/bin/check_scout_boundaries
   ls -la ~/.local/bin/block_claire_paths
   ls -la ~/.local/bin/validate_impl_on_write
   ls -la ~/.local/bin/check_wave_ownership
   ls -la ~/.local/bin/check_git_ownership
   ls -la ~/.local/bin/validate_agent_launch
   ls -la ~/.local/bin/validate_agent_completion
   ls -la ~/.local/bin/emit_agent_completion
   ```
   All should be symlinks (`l` prefix) pointing into the repo's
   `implementations/claude-code/hooks/` directory.

2. **Check settings.json registration:**
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```
   Verify `PreToolUse` contains `check_scout_boundaries`, `block_claire_paths`,
   `check_wave_ownership`, and `validate_agent_launch`; `PostToolUse`
   contains `validate_impl_on_write` and `check_git_ownership`; and
   `SubagentStop` contains `validate_agent_completion` and `emit_agent_completion`.

3. **Check jq is installed** (required by most hook scripts):
   ```bash
   which jq
   ```

4. **Re-run the installer:**
   ```bash
   ./implementations/claude-code/hooks/install.sh
   ```

### Layer 2: Git pre-commit hook not firing

1. **Verify hook is installed in the worktree:**
   ```bash
   sawtools verify-hook-installed /path/to/worktree
   ```

2. **Check the hook file directly:**
   ```bash
   # For a worktree, find the gitdir first:
   cat /path/to/worktree/.git
   # Then check the hook:
   ls -la /path/to/repo/.git/worktrees/<name>/hooks/pre-commit
   ```

3. **Re-install by running `prepare-wave`** — it calls `InstallHooks`
   automatically during worktree creation.

### Layer 3: SDK middleware not enforcing

SDK middleware is compiled into the Go binary. If constraints are not being
enforced:

1. Verify the `Constraints` struct is being populated from the IMPL manifest
   (check `OwnedFiles`, `FrozenPaths`, `AllowedPathPrefixes` are non-empty).
2. A zero-value `Constraints` disables all enforcement by design.

---

## Known Gaps

### check_impl_path, warn_stubs, check_branch_drift not yet implemented

`install.sh` references three hooks that do not yet exist in the repository:
- `check_impl_path` — H2 PreToolUse on `Agent` for IMPL path validation
- `warn_stubs` — H3 PostToolUse on `Write|Edit` for stub pattern warnings
- `check_branch_drift` — H4 PostToolUse on `Bash` for branch drift detection

The installer will fail when attempting to `chmod +x` these missing scripts.
These are planned hooks; until implemented, the relevant checks are not
enforced at the Claude Code layer.

### validate_impl_on_write depends on sawtools availability

The PostToolUse validation hook silently exits 0 if `sawtools` is not on
`$PATH`. This is intentional graceful degradation, but means IMPL validation
is silently skipped if the binary is not built or not in the path.

### validate_agent_launch H5 checks 4–8 depend on external tools

- Check 4 (IMPL validation) requires `sawtools` — skipped if not on `$PATH`.
- Checks 5 and 8 (agent existence, scaffold status) use `yq` with a grep
  fallback — the grep fallback is less precise and may produce false negatives.

### Pre-commit hook installation is non-fatal

If `InstallHooks` fails during worktree creation, only a warning is printed.
The worktree is still created without the hook. The `sawtools verify-hook-installed`
command exists to catch this, but it must be called explicitly or as part of
a `prepare-wave` verification step.
