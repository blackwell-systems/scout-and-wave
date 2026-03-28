# Issue: pre-commit-check runs wrong repo's lint gates

**Status:** ✅ RESOLVED (2026-03-28)
**Date:** 2026-03-28
**Severity:** Medium (forces `--no-verify` bypass, breaks hook trust)
**Component:** `sawtools pre-commit-check` (M4 pre-commit hook)
**Fix:** scout-and-wave-go@1fc6e21

## Problem

`sawtools pre-commit-check` finds the first active IMPL in `docs/IMPL/` and runs its lint gates **without validating that the IMPL targets the current repository**. This causes commits to fail with toolchain errors when an IMPL stored in repo A targets files in repo B.

## Symptom

```bash
$ git commit -m "docs: update protocol"
[pre-commit] running lint gate: cargo clippy -- -D warnings
error: could not find `Cargo.toml` in `/Users/dayna.blackwell/code/scout-and-wave` or any parent directory
Error: lint gate failed: exit 101
```

## Root Cause

`cmd/sawtools/pre_commit_check.go` logic:
1. Scans `docs/IMPL/*.yaml` for active IMPLs (state ≠ COMPLETE)
2. Picks the first one found
3. Runs `manifest.LintCommand` in the current repo
4. **Missing:** No validation that `file_ownership[].repo` matches current repo

## Concrete Example

- **Repo A (scout-and-wave):** Protocol documentation repo (no Cargo.toml)
- **IMPL:** `docs/IMPL/IMPL-agentskills-progressive-disclosure.yaml` stored in repo A
- **Target:** Files in agentskills-cli (Rust project) with `lint_command: cargo clippy`
- **Failure:** Committing protocol docs triggers Rust lint in non-Rust repo

## Impact

- Forced 3 commits to use `--no-verify` during integration-agent-cli-workflow wave
- Breaks the "hooks are trustworthy" assumption — users learn to bypass them
- Agents in worktrees also hit this (Agent D used `--no-verify` for markdown commit)

## Proposed Fix

### Option 1: Repo Matching (Strict)

```go
// In pre_commit_check.go
func findApplicableIMPL(repoDir string) (*protocol.IMPLManifest, error) {
    impls := scanActiveIMPLs("docs/IMPL")
    for _, impl := range impls {
        // Check if any file_ownership entry targets current repo
        if impl.TargetsRepo(repoDir) {
            return impl, nil
        }
    }
    return nil, nil // No applicable IMPL for this repo
}
```

If no IMPL targets the current repo, skip lint gates entirely (exit 0).

### Option 2: Toolchain Detection (Permissive)

```go
// Before running lint_command, verify toolchain exists
func hasToolchain(lintCmd string, repoDir string) bool {
    if strings.Contains(lintCmd, "cargo") {
        return fileExists(filepath.Join(repoDir, "Cargo.toml"))
    }
    if strings.Contains(lintCmd, "go vet") || strings.Contains(lintCmd, "golangci-lint") {
        return fileExists(filepath.Join(repoDir, "go.mod"))
    }
    // Add more toolchain checks as needed
    return true // Unknown command, allow it
}
```

If toolchain missing, skip that gate with warning (not failure).

### Option 3: Hybrid (Recommended)

1. First try Option 1 (repo matching) — only run gates if IMPL targets current repo
2. If an IMPL does target the repo but toolchain is missing, **fail hard** (this is a real problem, not a cross-repo mismatch)
3. If no IMPL targets the repo, skip gates silently (exit 0)

## Related Issues

- Cross-repo IMPL storage strategy: Should IMPLs always live in the target repo, or is storing them in the protocol repo acceptable?
- Hook configuration for multi-repo projects: Should `saw.config.json` specify which repos have pre-commit hooks enabled?

## Workaround (Current)

1. Use `--no-verify` when committing to repos that don't match active IMPLs
2. Or move cross-repo IMPLs to their target repos
3. Or archive stale IMPLs to `docs/IMPL/complete/`

## Acceptance Criteria

- [ ] `pre-commit-check` validates IMPL→repo mapping before running gates
- [ ] Cross-repo commits succeed without `--no-verify`
- [ ] Missing toolchain is caught as a configuration error (not silently skipped)
- [ ] Test case: IMPL-X in repo A targeting repo B does not block commits to repo A

## Resolution

**Fixed in:** scout-and-wave-go@1fc6e21 (2026-03-28)

Implemented Option 3 (Hybrid approach) with 3-tier validation logic:

### Implementation

Added `IMPLManifest.TargetsRepo(repoDir string) bool` method that checks:

1. **Explicit repository fields** (highest priority):
   - If `Repository` field exists, compare absolute paths
   - If `Repositories` list exists, check if repoDir matches any entry
   
2. **FileOwnership.Repo field** (medium priority):
   - Extract repo name from repoDir
   - Check if any `FileOwnership.Repo` matches repo name
   
3. **File existence fallback** (lowest priority):
   - For old IMPLs with no `Repository` field and empty `Repo` fields
   - Check if any `FileOwnership.File` path exists in current repo
   - If no files exist, IMPL targets different repo

Modified `DiscoverLintGate()` to skip IMPLs where `TargetsRepo()` returns false.

### Result

- ✅ Commits to scout-and-wave repo succeed without `--no-verify`
- ✅ agentskills IMPL (targets Rust project) is correctly skipped
- ✅ Cross-repo IMPLs with explicit `repo:` fields work correctly
- ✅ Old IMPLs without `Repository` field handled via file existence check

### Testing

Verified fix by committing to scout-and-wave repo with agentskills IMPL present in `docs/IMPL/`. Pre-commit hook silently skipped the IMPL (no lint gate run), commit succeeded.
