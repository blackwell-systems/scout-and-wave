# Dogfooding Report: `sawtools pre-commit-check` Missing from Binary

**Date:** 2026-03-25
**Discovered during:** `scout-prompt-extraction` wave (all 4 agents used `--no-verify`)
**Severity:** High — quality gate silently absent on every commit in every wave

---

## What the hook calls and what it is supposed to do

The pre-commit hook installed at `.git/hooks/pre-commit` (and per-worktree at
`.git/worktrees/<name>/hooks/pre-commit`) contains:

```sh
#!/bin/sh
set -e
# SAW pre-commit quality gate (M4)
sawtools pre-commit-check --repo-dir "$(git rev-parse --show-toplevel)"
```

`pre-commit-check` is the M4 quality gate. It calls `protocol.DiscoverLintGate`
to find the project's configured lint/build command from the active IMPL doc,
then runs that command. If no gate is configured it exits silently (pass). If
the command fails it blocks the commit. The intent is to enforce quality gates
inline during agent commits, not just at finalize-wave time.

---

## Root cause: commands exist in source but are never registered

`newPreCommitCheckCmd()` is implemented in:
- `/Users/dayna.blackwell/code/scout-and-wave-go/cmd/sawtools/pre_commit_cmd.go`

`newInstallHooksCmd()` is implemented in:
- `/Users/dayna.blackwell/code/scout-and-wave-go/cmd/sawtools/install_hooks_cmd.go`

Neither function appears in the `rootCmd.AddCommand(...)` list in:
- `/Users/dayna.blackwell/code/scout-and-wave-go/cmd/sawtools/main.go`

The binary was rebuilt after the source files were added (binary timestamp
20:04, source commit 23:03 the prior day), so the binary is current — it simply
never wired the commands. When `sawtools pre-commit-check` is invoked, cobra
returns `unknown command "pre-commit-check"` and exits 1, causing `set -e` to
abort the commit. Agents worked around this with `--no-verify`.

The wiring audit at `docs/planning/wiring-audit.md` (last reviewed 2026-03-25)
does not list these two commands among its gaps — it missed them.

---

## How the hook gets installed

The hook is written by `runInstallHooks()` (called from `newInstallHooksCmd()`),
which is also called directly from `prepare_wave.go` line 65:

```go
// Auto-install M4 pre-commit lint gate hook if missing
if err := runInstallHooks(projectRoot); err != nil {
    fmt.Fprintf(os.Stderr, "prepare-wave: could not auto-install M4 hook: %v\n", err)
}
```

Because `runInstallHooks` is a package-level function (not gated behind command
registration), `prepare-wave` successfully installs the hook file — the hook
content is correct. The failure is purely that the installed hook calls a
subcommand that cobra does not recognize at runtime.

The hook installer was also separately added as `sawtools install-hooks` (for
explicit/manual use), but that subcommand is also unregistered.

---

## Protocol reference

`protocol/procedures.md` §Wave Setup step 2 documents this explicitly:

> Quality gate hook (M4): Installed to the project root by `prepare-wave`
> (via `sawtools install-hooks`). Runs `sawtools pre-commit-check` on every
> commit to enforce quality gates inline.

The protocol is correct; the implementation has the registration gap.

---

## Suggested fix

**Option A (preferred): Register the missing commands in `main.go`.**

Add two lines to the `rootCmd.AddCommand(...)` block:

```go
newPreCommitCheckCmd(),
newInstallHooksCmd(),
```

Then rebuild the binary. No source changes needed — the implementations are
complete and tested.

**Option B (fallback only): Remove or no-op the hook body.**

Change the hook to `exit 0` so it does not call a nonexistent command. This
eliminates the error but also eliminates the gate entirely. Not recommended.

Option A is the correct fix — the source is fully implemented, tests exist
(`pre_commit_cmd_test.go`, `install_hooks_cmd_test.go`), and the IMPL doc
(`IMPL-m4-pre-commit-gate.yaml`) is marked complete. The only missing step
is the registration line in `main.go`.

---

## Impact on normal workflows

**Every wave, every commit.** `prepare-wave` installs the broken hook into the
project root and all worktrees. Any agent that does not use `--no-verify` will
have their commit blocked immediately with `unknown command "pre-commit-check"`.
Agents that discover this (as happened in `scout-prompt-extraction`) are forced
to use `--no-verify`, which bypasses the isolation hook (Layer 0) as well,
not just the M4 gate. This means file-ownership enforcement at commit time is
also silently disabled for the entire wave.

There is no partial degradation — the gate is either enforced or completely
bypassed. The current state is complete bypass.
