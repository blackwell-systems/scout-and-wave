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

## Overview Table

| Hook | Layer | Invariant | Trigger | What it blocks |
|------|-------|-----------|---------|----------------|
| `check_scout_boundaries` | 1 (PreToolUse) | I6 | Scout calls Write or Edit | Scout writing outside `docs/IMPL/IMPL-*.yaml` |
| `check_wave_ownership` | 1 (PreToolUse) | I1 | Wave agent calls Write, Edit, or NotebookEdit | Wave agent writing files not in its `.saw-ownership.json` |
| `block_claire_paths` | 1 (PreToolUse) | -- | Any agent calls Write, Edit, or Bash | Operations targeting `.claire` paths (model hallucination guard) |
| `validate_impl_on_write` | 1 (PostToolUse) | E16 | Any agent calls Write on an IMPL doc | Saving an IMPL doc that fails `sawtools validate` |
| SAW pre-commit guard | 2 (Git hook) | I4 | `git commit` in a worktree | Commits to `main`/`master` from agent worktrees |
| SAW go.mod guard | 2 (Git hook) | -- | `git commit` touching `go.mod` | `replace` directives with deep relative paths (`../../..`) |
| Ownership middleware | 3 (SDK) | I1 | Engine Write/Edit tool execution | Agent writing files outside `OwnedFiles` map |
| Freeze middleware | 3 (SDK) | I2 | Engine Write/Edit tool execution | Agent writing to frozen interface paths after freeze time |
| Role path middleware | 3 (SDK) | I6 | Engine Write/Edit tool execution | Agent writing outside `AllowedPathPrefixes` |

---

## Layer 1: Claude Code Hooks

Claude Code hooks are bash scripts registered in `~/.claude/settings.json`.
They receive JSON on stdin describing the tool call and exit 0 (allow) or 1
(block, with error message on stderr).

### Installation

The installer script lives at:

```
implementations/claude-code/hooks/install.sh
```

It performs these steps:

1. **Creates symlinks** in `~/.local/bin/` pointing to the hook scripts in the
   repo:
   - `~/.local/bin/check_scout_boundaries` -> `implementations/claude-code/hooks/check_scout_boundaries`
   - `~/.local/bin/block_claire_paths` -> `implementations/claude-code/hooks/block_claire_paths`
   - `~/.local/bin/validate_impl_on_write` -> `implementations/claude-code/hooks/validate_impl_on_write`

2. **Merges hook configuration** into `~/.claude/settings.json` using `jq`:
   - Adds a `PreToolUse` entry for `check_scout_boundaries` with matcher `Write|Edit`
   - Adds a `PreToolUse` entry for `block_claire_paths` with matcher `Write|Edit|Bash`
   - Adds a `PostToolUse` entry for `validate_impl_on_write` with matcher `Write`

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
**Invariant:** I6 (role-based path boundaries)

Restricts Scout agents to writing only IMPL planning documents. Reads JSON
from stdin and extracts `tool_name`, `agent_type`, and `tool_input.file_path`.

**Logic:**
- Exits 0 (allow) if `agent_type` is not `"scout"` -- only Scouts are constrained.
- Exits 0 if `tool_name` is not `Write` or `Edit`.
- Normalizes the file path and checks: directory must be exactly `docs/IMPL`
  and filename must match `IMPL-*.yaml`. Subdirectories (e.g., `docs/IMPL/complete/`)
  are rejected.
- Exits 1 with an `I6 VIOLATION` message on stderr for anything else.

**Example block output:**
```
I6 VIOLATION: Scout agents create IMPL planning documents only.

Attempted: src/main.go
Allowed: docs/IMPL/IMPL-<feature-slug>.yaml
```

### check_wave_ownership (I1)

**File:** `implementations/claude-code/hooks/check_wave_ownership`
**Type:** PreToolUse
**Matcher:** Not currently registered in `settings.json` or the installer (see Known Gaps)
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
- Exits 1 with an `I1 VIOLATION` message on stderr if the file is not owned.

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
**Invariant:** None (model hallucination guard)

Blocks tool calls that reference `.claire` in file paths. This is a guardrail
against a known, widespread model hallucination where the model writes `.claire`
instead of `.claude` for directory paths (e.g., `~/.claire/settings.json`
instead of `~/.claude/settings.json`). This has been reported across multiple
models and is documented on Reddit.

**Logic:**
- Inspects the tool input for any file path or command string containing `.claire`.
- Exits 1 with a corrective message on stderr if `.claire` is found.
- Exits 0 (allow) otherwise.

**Example block output:**
```
BLOCKED: You wrote .claire — the correct directory is .claude. Fix the path and retry.
```

### validate_impl_on_write (E16)

**File:** `implementations/claude-code/hooks/validate_impl_on_write`
**Type:** PostToolUse
**Matcher:** `Write`
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
- If validation fails, exits 1 with the error count and messages on stderr.

**Example block output:**
```
BLOCKED: IMPL validation failed (3 errors). Fix these before continuing:
missing required field: feature_slug
wave 1 agent A has no owned_files
gates[0] missing agent_id
```

---

## Layer 2: Git Pre-Commit Hook

A bash pre-commit hook installed into each Wave agent worktree. This is the
last line of defense before code is committed -- it cannot be bypassed by
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
but worktree creation is not aborted -- the `prepare-wave` verification step
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

- **`constraints.go`** -- Defines the `Constraints` struct that configures
  enforcement per-agent.
- **`constraint_enforcer.go`** -- Implements the three middleware functions
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
worktree creation -- shared interface files cannot be modified by agents once
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

- **`ValidateScoutWrites(repoPath, expectedIMPLPath, startTime)`** -- Walks
  `docs/` looking for files modified after `startTime` that are not the
  expected IMPL doc or a valid `docs/IMPL/IMPL-*.yaml` path. Returns an
  `I6 VIOLATION` error listing unauthorized writes.
- **`IsValidScoutPath(filePath)`** -- Pure predicate: returns true only for
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
   ```
   Both should be symlinks (`l` prefix) pointing into the repo's
   `implementations/claude-code/hooks/` directory.

2. **Check settings.json registration:**
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```
   Verify `PreToolUse` contains `check_scout_boundaries` and
   `block_claire_paths`, and `PostToolUse` contains `validate_impl_on_write`.

3. **Check jq is installed** (required by all hook scripts):
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

3. **Re-install by running `prepare-wave`** -- it calls `InstallHooks`
   automatically during worktree creation.

### Layer 3: SDK middleware not enforcing

SDK middleware is compiled into the Go binary. If constraints are not being
enforced:

1. Verify the `Constraints` struct is being populated from the IMPL manifest
   (check `OwnedFiles`, `FrozenPaths`, `AllowedPathPrefixes` are non-empty).
2. A zero-value `Constraints` disables all enforcement by design.

---

## Known Gaps

### check_wave_ownership not registered in installer or settings.json

The `check_wave_ownership` script exists at
`implementations/claude-code/hooks/check_wave_ownership` and is fully
implemented, but:

- **`install.sh` does not create a symlink** for it in `~/.local/bin/`.
- **`install.sh` does not add a `PreToolUse` entry** for it in `settings.json`.
- It is **not present** in the current `~/.claude/settings.json` hooks
  configuration.

This means I1 enforcement for Wave agents in the CLI (Claude Code) environment
relies entirely on Layer 3 (SDK middleware) or agent-prompt compliance. To
activate this hook, `install.sh` would need to be updated to symlink the script
and register it as a PreToolUse hook with an appropriate matcher.

### validate_impl_on_write depends on sawtools availability

The PostToolUse validation hook silently exits 0 if `sawtools` is not on
`$PATH`. This is intentional graceful degradation, but means IMPL validation
is silently skipped if the binary is not built or not in the path.

### Pre-commit hook installation is non-fatal

If `InstallHooks` fails during worktree creation, only a warning is printed.
The worktree is still created without the hook. The `sawtools verify-hook-installed`
command exists to catch this, but it must be called explicitly or as part of
a `prepare-wave` verification step.
