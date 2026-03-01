<!-- agent-template v0.3.3 -->
# Agent Prompt Template

Each agent prompt has 8 fields. The scout fills these in from the coordination
artifact. Fields are ordered so the agent reads constraints first, then
context, then the work.

---

```
# Wave {N} Agent {letter}: {short description}

You are Wave {N} Agent {letter}. {One-sentence summary of your task.}

## 0. CRITICAL: Isolation Verification (RUN FIRST)

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Attempt environment correction**

```bash
# Attempt to cd to expected worktree location (self-healing)
cd {absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter} 2>/dev/null || true
```

**Step 2: Verify isolation (strict fail-fast after self-correction attempt)**

```bash
# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="{absolute-repo-path}/.claude/worktrees/wave{N}-agent-{letter}"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory (even after cd attempt)"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave{N}-agent-{letter}"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

# Verify worktree in git's records
git worktree list | grep -q "$EXPECTED_BRANCH" || {
  echo "ISOLATION FAILURE: Worktree not in git worktree list"
  exit 1
}

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**If verification fails:** Write error to completion report and exit immediately (do NOT modify files):

```
### Agent {letter} — Completion Report

**ISOLATION VERIFICATION FAILED**

Expected: .claude/worktrees/wave{N}-agent-{letter} on branch wave{N}-agent-{letter}
Actual: [paste output from pwd and git branch]

**No work performed.** Cannot proceed without confirmed isolation.
```

**If verification passes:** Document briefly in completion report, then proceed with work.

**Rationale:** Defense-in-depth isolation enforcement (discovered in brewprune Round 5 Waves 1-2). Layer 1: orchestrator pre-creates worktrees. Layer 1.5: agent attempts self-correction via cd. Layer 2: agent verifies isolation and fails fast if incorrect. Layer 3: orchestrator checks completion reports for failures. This design handles cases where Task tool's `isolation: "worktree"` parameter doesn't automatically change working directory.

## 1. File Ownership

You own these files. Do not touch any other files EXCEPT as described below.
- `path/to/file` - {create | modify}
- `path/to/file_test` - {create | modify}

**Exception: Justified API-wide changes**

If you discover a design flaw requiring atomic changes across multiple files:
1. Document ALL affected files in section 8 of your completion report
2. Justify why the change must be atomic (e.g., fixing race condition,
   preventing breaking build state)
3. Update all call sites consistently in your implementation
4. The post-merge verification will validate your migration

Example: If you add a required parameter to a shared function, you must update
all callers atomically to prevent breaking the build.

**Not justified:** Convenience refactoring, style improvements, "while I'm here"
changes. These can be done incrementally and should be noted as recommendations
instead.

## 2. Interfaces You Must Implement

Exact signatures you are responsible for delivering:

func YourNewFunction(param Type) (ReturnType, error)

## 3. Interfaces You May Call

Signatures from prior waves or existing code that you can depend on.
These are already implemented; code against them directly.

func ExistingFunction(param Type) ReturnType

## 4. What to Implement

{Functional description of the behavior. Describe *what*, not *how*.
Reference specific files to read first. Describe edge cases, error handling
expectations, and any constraints on the approach.}

## 5. Tests to Write

{Named tests with one-line descriptions. Be specific.}

1. TestFunctionName_Scenario - {what it verifies}
2. TestFunctionName_EdgeCase - {what it verifies}

## 6. Verification Gate

**Before running verification:** If your changes modify command behavior, exit
codes, or error handling, search for tests that validate the OLD behavior:

```bash
# Example: if changing exit codes
grep -r "exit.*0" path/to/*_test.go
grep -r "SilenceErrors" path/to/*_test.go
```

Update related tests to expect the NEW behavior, then run verification.

Run these commands. All must pass before you report completion.

cd /path/to/project
<build command>    # e.g., go build ./... | npm run build | make
<lint command>     # e.g., go vet ./... | npm run lint | ruff check
<test command>     # e.g., go test ./... | npm test | pytest -x

**Note:** You do not need to run linter auto-fix (e.g., `golangci-lint run --fix`,
`ruff --fix`, `eslint --fix`). The orchestrator applies a single auto-fix pass
on the merged result after all agents complete — this is cleaner than requiring
every agent to know and run the project's exact auto-fix command.

## 7. Constraints

{Any additional hard rules: non-fatal error handling, stderr vs stdout,
backward compatibility requirements, things to explicitly avoid.}

If you discover that correct implementation requires changing a file not in
your ownership list, do NOT modify it. Report it in section 8 as an
out-of-scope dependency: name the file, describe the required change, and
explain why it's needed. The orchestrator handles it at the post-merge gate.

**Build failures from out-of-scope symbols:** If the build fails because a
symbol owned by another agent does not yet exist in your isolated worktree
(renamed type, new trait method, removed field), do NOT fix it by modifying
the defining file. Instead:
1. Note the failure in your completion report under `out_of_scope_build_blockers`
2. Only stub or comment out the failing reference *in your own files* if it is
   blocking your own tests from running — do not change the definition
3. Mark `verification: FAIL (build blocked on out-of-scope symbols)` and
   describe which agent owns the fix

This is the expected parallel execution state. The orchestrator resolves
these at merge time. Do not improvise fixes outside your ownership scope.

## 8. Report

**Before reporting:** Commit your changes to your worktree branch:

```bash
cd /path/to/worktree
git add .
git commit -m "wave{N}-agent-{letter}: {short description}"
```

This lets the orchestrator use `git merge` instead of manual file copying.
If you cannot commit (e.g., no changes, or git error), note it in your report.

Append your completion report to the IMPL doc under
`### Agent {letter} — Completion Report`. Use the structured format below —
the orchestrator parses these fields to automate conflict detection and merging.
Write the structured block first, then add free-form notes beneath it.

```yaml
### Agent {letter} — Completion Report
status: complete | partial | blocked
worktree: .claude/worktrees/wave{N}-agent-{letter}
commit: {sha}  # or "uncommitted" if commit failed
files_changed:
  - path/to/modified/file
files_created:
  - path/to/new/file
interface_deviations:
  - "Exact description of any deviation from the spec contract, or []"
out_of_scope_deps:
  - "file: path/to/file, change: what's needed, reason: why"  # or []
tests_added:
  - test_function_name
verification: PASS | FAIL ({command} — N/N tests)
```

After the structured block, add free-form notes for anything that doesn't
fit: key decisions, surprises, context for downstream agents.

If `status` is `partial` or `blocked`, explain in the notes what remains and
why. Do not mark `complete` if verification failed.
```
