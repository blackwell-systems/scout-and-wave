# First Run Walkthrough

This guide walks you through your first SAW session step-by-step, showing exactly what to expect at each stage.

## Prerequisites

Before starting, ensure you've completed the [installation steps](../README.md#install) in the main README:
- [x] Permissions configured (`"Agent"` in allow list)
- [x] Repository cloned
- [x] Skill installed (`~/.claude/commands/saw.md`)
- [x] Installation verified (`/saw status` works)

## Your First SAW Run

### Step 1: Navigate to a project with existing code

Open Claude Code in any project directory. SAW works best with existing codebases (not empty repos).

**Example:** A Go API client library, a Python web app, a TypeScript React project, etc.

### Step 2: Run your first scout

```
You: /saw scout "add a simple cache to the API client"
```

**What happens (30-90 seconds):**

The orchestrator launches a Scout agent in the background. You'll see progress updates:

```
Launching Scout agent to analyze "add a simple cache to the API client"...

Scout is analyzing your codebase:
-> Scanning files with Glob and Grep
-> Reading key architecture files (README, main entry points)
-> Understanding project structure and patterns
-> Running suitability gate (5 questions)
-> Designing wave structure
-> Defining interface contracts
-> Assigning files to agents
-> Writing docs/IMPL-simple-cache.md...
```

**Scout completes and reports:**

```
OK Suitability: SUITABLE for SAW parallelization

Wave Structure:
  Wave 1: 2 agents (parallel)
    Agent A: Cache interface + in-memory implementation
    Agent B: HTTP client integration

File Ownership:
  Agent A owns:
    - src/cache/cache.go (new)
    - src/cache/memory.go (new)
    - src/cache/cache_test.go (new)

  Agent B owns:
    - src/client/client.go (modify)
    - src/client/options.go (modify)
    - src/client/client_test.go (modify)

Scaffold Files:
  src/cache/types.go - CacheInterface definition
  Status: pending (Scaffold Agent will create this after you approve)

Interface Contracts:
  type CacheInterface interface {
      Get(key string) ([]byte, bool)
      Set(key string, value []byte)
      Delete(key string)
  }

IMPL doc written to: docs/IMPL-simple-cache.md

Review the IMPL doc. This is your last chance to change interface signatures.
Ready to proceed?
```

### Step 3: Review the IMPL doc

The IMPL doc is the coordination artifact. Key sections to check:

**File Ownership Table:**
```markdown
| File | Owner | Status |
|------|-------|--------|
| src/cache/cache.go | Agent A | new |
| src/cache/memory.go | Agent A | new |
| src/client/client.go | Agent B | modify |
```

Verify:
- [x] No file appears in multiple agents' ownership (disjoint ownership)
- [x] All files that need to change are assigned

**Interface Contracts:**
```go
// Package cache provides caching interfaces and implementations.
type CacheInterface interface {
    Get(key string) ([]byte, bool)
    Set(key string, value []byte)
    Delete(key string)
}
```

Verify:
- [x] Function signatures are correct
- [x] Types are complete (return values, parameters)
- [x] No missing methods

**Scaffolds Section:**
```markdown
## Scaffolds

| File | Status | Commit |
|------|--------|--------|
| src/cache/types.go | pending | - |

Contents:
```go
package cache

type CacheInterface interface {
    Get(key string) ([]byte, bool)
    Set(key string, value []byte)
    Delete(key string)
}
```
```

If scaffolds are listed, the Scaffold Agent will create them automatically in the next step.

**Agent Prompts:**

Each agent has a detailed prompt in the IMPL doc. You can read these to understand what each agent will do.

**If you want to make changes:**

You can edit the IMPL doc directly:
- Adjust interface signatures
- Reassign files between agents
- Change wave structure
- Modify agent prompts

```
You: Can you update the CacheInterface to include a Clear() method?
```

The orchestrator will update the IMPL doc. Once you're satisfied, proceed to the next step.

### Step 4: Launch the first wave

```
You: /saw wave
```

**What happens:**

#### 4a. Scaffold Agent runs (if needed)

If the IMPL doc has scaffolds with `Status: pending`:

```
Checking Scaffolds section...
  -> src/cache/types.go: Status: pending
  -> Launching Scaffold Agent...

Scaffold Agent running in background...

Scaffold Agent completed:
  OK Created src/cache/types.go (45 lines)
  OK Build successful: go build ./src/cache
  OK Committed to main (abc123def)
  -> IMPL doc updated: Status: committed

Interface contracts are now frozen. All Wave Agents will implement against this version.
```

**If scaffold compilation fails:**

```
Scaffold Agent completed:
  X Build failed: undefined: CachOptions
  -> IMPL doc updated: Status: FAILED

Fix the interface contracts in the IMPL doc and re-run /saw wave.
Wave 1 will not launch until all scaffolds show Status: committed.
```

You must fix the issue before proceeding. The orchestrator prevents Wave Agents from launching with broken scaffolds.

#### 4b. Worktrees created

```
Creating worktrees:
  OK .claude/worktrees/wave1-agent-A
    Branch: wave1-agent-A
    Base: main (abc123def)

  OK .claude/worktrees/wave1-agent-B
    Branch: wave1-agent-B
    Base: main (abc123def)

Pre-commit hook installed: guards against accidental commits to main
```

Each agent gets its own isolated working directory (git worktree). They share git history but have separate file trees.

#### 4c. Agents launch in parallel

```
Launching Wave 1 agents in parallel:
  -> [SAW:wave1:agent-A] implement cache layer
  -> [SAW:wave1:agent-B] integrate cache into client

Agents running in background...

You can continue working in Claude Code while they run.
Check /saw status anytime to see progress.
```

**Agent execution (2-5 minutes):**

Both agents work simultaneously in their worktrees:
- Reading files (via Read, Glob, Grep)
- Writing implementation (via Edit, Write)
- Running tests (via Bash: `go test ./...`)
- Committing to their worktree branches

You'll see periodic updates:

```
Agent A: Reading src/cache/types.go...
Agent B: Writing src/client/client.go...
Agent A: Running tests...
Agent B: Running tests...
```

#### 4d. Agents complete and report

```
Agent A completed:
  Status: complete
  Files changed:
    - src/cache/cache.go (127 lines)
    - src/cache/memory.go (84 lines)
    - src/cache/cache_test.go (156 lines)
  Verification:
    OK go build ./src/cache
    OK go test ./src/cache (8/8 tests passing)
    OK go vet ./src/cache
  Commits: 2 commits on wave1-agent-A
  Interface deviations: none
  Out-of-scope discoveries: none

Agent B completed:
  Status: complete
  Files changed:
    - src/client/client.go (+45 -3 lines)
    - src/client/options.go (+12 -0 lines)
    - src/client/client_test.go (+67 -2 lines)
  Verification:
    OK go build ./src/client
    OK go test ./src/client (5/5 tests passing)
    OK go vet ./src/client
  Commits: 1 commit on wave1-agent-B
  Interface deviations: none
  Out-of-scope discoveries: none
```

Both agents report `Status: complete`. If either reported `Status: partial` or `Status: blocked`, the wave would not proceed to merge.

### Step 5: Orchestrator merges

The orchestrator verifies both agents succeeded, then merges sequentially:

```
All agents completed successfully. Beginning merge...

Merging wave1-agent-A...
  -> git merge --no-ff wave1-agent-A
  OK Merged (no conflicts)

Merging wave1-agent-B...
  -> git merge --no-ff wave1-agent-B
  OK Merged (no conflicts)
```

**Why no conflicts?**

Disjoint file ownership guarantees conflict-free merges. Agent A and Agent B never touched the same file.

### Step 6: Post-merge verification

```
Running post-merge verification gate:

Linter auto-fix:
  -> go fmt ./...
  OK No formatting changes needed

Build:
  -> go build ./...
  OK Build successful

Tests (unscoped):
  -> go test ./...
  OK 13/13 tests passing
    - src/cache: 8 tests
    - src/client: 5 tests
```

**Why unscoped tests matter:**

Individual agents ran scoped tests (`go test ./src/cache`). The orchestrator runs **unscoped** tests (`go test ./...`) to catch cross-package issues.

Example: Agent B added a cache field to `Client` struct. If a test in a different package constructs `Client{}` directly, it will fail here (missing cache field).

### Step 7: Cleanup and completion

```
Cleaning up worktrees:
  -> Removed .claude/worktrees/wave1-agent-A
  -> Removed wave1-agent-A branch
  -> Removed .claude/worktrees/wave1-agent-B
  -> Removed wave1-agent-B branch

OK Wave 1 complete and merged to main

Summary:
  Agents: 2 (parallel)
  Files changed: 6 (3 new, 3 modified)
  Lines added: 491
  Lines removed: 5
  Tests: 13/13 passing
  Duration: 4m 23s
```

### Step 8: Review the changes

```
You: show me what was implemented
```

The orchestrator summarizes the changes:

```
Cache Layer (Agent A):
- Created src/cache/cache.go with CacheInterface
- Implemented MemoryCache with Get/Set/Delete
- Added 8 unit tests with 100% coverage

Client Integration (Agent B):
- Added WithCache() option to client.Options
- Modified Client.Do() to check cache before HTTP request
- Modified Client.Do() to store responses in cache
- Added 5 integration tests with cache enabled/disabled
```

You can also use git:

```bash
git log --oneline -5
git diff HEAD~2..HEAD
```

### What if something goes wrong?

**Scout says "NOT SUITABLE":**

```
X Suitability: NOT SUITABLE

Reason: Investigation-first blocker detected

The work requires prototyping the cache eviction strategy before
interface design is possible. Recommend implementing manually first,
then using SAW for the next feature once the approach is validated.
```

This is **expected and useful**. Not all work parallelizes well. The suitability gate prevents bad decompositions.

**Scaffold Agent fails:**

```
Scaffold Agent completed:
  X Build failed: src/cache/types.go:5:15: undefined: CachOptions
  -> Status: FAILED

Fix the interface contracts in the IMPL doc and re-run /saw wave.
```

Fix the typo in the IMPL doc (`CachOptions` -> `CacheOptions`), then run `/saw wave` again. The Scaffold Agent will re-run with the corrected interface.

**Agent reports Status: partial:**

```
Agent A completed:
  Status: partial
  Reason: Tests failing (2/8 passing)

Agent B completed:
  Status: complete
```

The wave does not merge. Options:
1. Re-run Agent A (orchestrator can restart just the failing agent)
2. Fix manually and mark as resolved
3. Descope Agent A's work and continue with Agent B only

The orchestrator will present recovery options.

**Post-merge tests fail:**

```
Tests (unscoped):
  -> go test ./...
  X FAIL: TestClientWithoutCache (client_integration_test.go:45)
```

The orchestrator stops before cleanup:

```
Post-merge verification failed. Fix the issue before proceeding.

Working tree state: merged but not finalized
Worktrees: still available for inspection
```

You can investigate, fix the issue, and re-run verification.

## Next Steps

**If you have more waves:**

```
/saw status
```

Shows:

```
Current wave: Wave 2 (pending)
  Agent C: Add cache metrics/observability

Run /saw wave to execute Wave 2.
```

**Run all remaining waves automatically:**

```
/saw wave --auto
```

Auto mode will:
- Execute each wave sequentially
- Only pause if verification fails
- Complete all waves hands-free if everything passes

**Start a new feature:**

```
/saw scout "add rate limiting to the API"
```

This creates a new IMPL doc and doesn't interfere with the cache feature.

## Tips for Success

**Good feature descriptions for Scout:**

[x] "add request retry logic with exponential backoff"
[x] "implement pagination for the list endpoints"
[x] "add Prometheus metrics export"

X "make the app better" (too vague)
X "investigate performance issues" (investigation-first)
X "fix all the bugs" (not a feature)

**When Scout says NOT SUITABLE, listen:**

If the suitability gate fails, it's usually right. Prototyping, investigation-heavy work, and tightly coupled changes don't parallelize well.

**Review the IMPL doc carefully:**

The 30 seconds you spend reviewing interface contracts saves hours of rework later. Interfaces freeze at worktree creation time.

**Let agents run in background:**

Don't watch them execute. Do other work in Claude Code or check back with `/saw status`. Agents report when done.

**Trust the merge:**

Disjoint file ownership means merges are deterministic. If both agents report `Status: complete` and their verification gates passed, the merge will succeed.

## Common Questions

**Q: Can I use SAW on a feature branch?**

Yes! SAW works on any branch. Just ensure your working tree is clean before starting.

**Q: What if I need to stop mid-wave?**

Claude Code background agents continue even if you close the session. If you restart, use `/saw status` to check progress.

**Q: Can I modify files while agents are running?**

Agents work in isolated worktrees, so you can edit files on main safely. Your changes won't interfere with theirs.

**Q: How do I see what agents are doing in real-time?**

Agent work happens in `.claude/worktrees/wave{N}-agent-{letter}/`. You can `cd` into those directories and inspect the changes, but don't commit manually.

**Q: What if two agents need to modify the same file?**

Scout will detect this and either:
1. Assign the whole file to one agent (the other reads but doesn't modify)
2. Split the work across waves (Wave 1 agent modifies, Wave 2 agent builds on it)
3. Declare the work NOT SUITABLE if splitting isn't feasible

Disjoint ownership is enforced before any agent starts.

**Q: Can I reuse an IMPL doc for similar work later?**

Not directly. Each IMPL doc is specific to one feature. But you can copy the file ownership patterns and interface contract style for future features.

## Troubleshooting

**Problem: `/saw` not recognized**

Solution: Check `~/.claude/commands/saw.md` exists and restart Claude Code.

**Problem: "Agent tool not allowed"**

Solution: Add `"Agent"` to `~/.claude/settings.json` permissions allow list (see [Install -> Step 1](../README.md#install)).

**Problem: Scaffold Agent says "Build failed"**

Solution: Check the IMPL doc Scaffolds section for the error message. Fix the interface contracts and re-run `/saw wave`.

**Problem: Merge conflicts**

Solution: This shouldn't happen with disjoint ownership. If it does, file an issue — this indicates a protocol violation.

**Problem: Tests passing individually but failing after merge**

Solution: This is the point of the unscoped test gate. Fix the cross-package issue (usually a missing field in a struct constructor or changed function signature).

## Further Reading

- [README](../README.md) - Main documentation
- [PROTOCOL.md](../PROTOCOL.md) - Formal specification
- [Blog series](https://blog.blackwell-systems.com/posts/scout-and-wave/) - Pattern evolution and lessons learned
