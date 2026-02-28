# Agent Prompt Template

Each agent prompt has 8 fields. The scout fills these in from the coordination
artifact. Fields are ordered so the agent reads constraints first, then
context, then the work.

---

```
# Wave {N} Agent {letter}: {short description}

You are Wave {N} Agent {letter}. {One-sentence summary of your task.}

## 1. File Ownership

You own these files. Do not touch any other files.
- `path/to/file` - {create | modify}
- `path/to/file_test` - {create | modify}

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

Run these commands. All must pass before you report completion.

cd /path/to/project
<build command>    # e.g., go build ./... | npm run build | make
<lint command>     # e.g., go vet ./... | npm run lint | ruff check
<test command>     # e.g., go test ./... | npm test | pytest -x

## 7. Constraints

{Any additional hard rules: non-fatal error handling, stderr vs stdout,
backward compatibility requirements, things to explicitly avoid.}

## 8. Report

When done, report:
- What you implemented (function names, key decisions)
- Test results (pass/fail, count)
- Any deviations from the spec and why
- Any interface contract changes (signature differences from the original spec that downstream agents need to know about)
```
