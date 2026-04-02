# Wave Agent Protocol Contracts

**Purpose:** This reference consolidates the invariants and execution rules that govern Wave agent behavior. These are the non-negotiable protocol constraints enforced during wave execution.

## I1: Disjoint File Ownership

**Rule:** No two agents in the same wave own the same file.

**Why:** Prevents merge conflicts, ensures parallel execution safety.

**Enforcement:** The IMPL doc's `file_ownership` table is the single source of truth. Scout must assign each file to exactly one agent per wave.

**Violation impact:** Hard constraint violation → protocol failure, not a style preference.

## I2: Interface Contracts Precede Implementation

**Rule:** Interfaces must be defined and committed to HEAD before Wave agents launch.

**Process:**
1. Scout defines interfaces in the IMPL doc's `interface_contracts` section
2. Scaffold Agent commits scaffold files to HEAD
3. **Freeze checkpoint:** When worktrees are created, contracts become immutable
4. Wave agents implement against the frozen interfaces

**Verification:** Check Scaffolds section before creating worktrees. If any scaffold file shows `Status: pending`, the Scaffold Agent has not run. If any shows `Status: FAILED`, stop immediately.

**Last moment for revision:** Before `sawtools prepare-wave` creates worktrees. After worktree creation, type signatures cannot change without aborting the wave.

## I5: Agents Commit Before Reporting

**Rule:** Each agent commits its changes to its worktree branch before writing a completion report.

**Verification:**
1. Read completion report from IMPL doc (`### Agent {ID} - Completion Report`)
2. Check the agent's worktree branch for commits
3. If report is present but branch has no commits → **flag as protocol deviation**

**Why:** Ensures completion reports reflect actual committed work, not just chat promises.

**Hook enforcement:** The E42 SubagentStop hook validates I5 automatically (see below).

## E35: Own the Caller

**Rule:** When agent X defines function F that must be called from aggregation file A (registry, route table, main.go), file A MUST be in agent X's `file_ownership`.

**Problem:** Agent X implements feature, but cannot wire it into the app because the wiring point (main.go, routes.go) is owned by another agent or not owned at all.

**Solution patterns:**

### Pattern 1: Assign Caller to Definer
If the wiring file can be safely modified by the same agent:
```yaml
file_ownership:
  - agent: X
    files:
      - src/feature/handler.go  # defines Handler
      - src/main.go              # registers Handler
```

### Pattern 2: Wiring Entry (Cross-Agent Integration)
If both sides cannot be in one agent:
```yaml
wiring:
  - symbol: CacheHandler
    defined_in: src/cache/handler.go
    must_be_called_from: src/routes.go
    agent: B
    wave: 1
    integration_pattern: append
```

This creates an integration wave where agent B wires agent A's work into the app.

**Detection:** The E25/E26/E35 post-merge integration gap detection scans for this pattern (see `references/failure-routing.md`).

## E42: SubagentStop Validation

**Rule:** Agent completion is automatically validated via the `validate_agent_completion` SubagentStop hook.

**Validated obligations:**
1. **I5:** Agent committed to worktree branch
2. **I4:** Completion report written to IMPL doc
3. **I1:** Agent only modified files in its ownership

**Enforcement:** The hook **blocks** agents that skip protocol obligations. Agent cannot report "complete" without satisfying all three.

**Orchestrator role:** The orchestrator does not need to manually verify these obligations (hook does it), but should still read completion reports per I4 for decision-making:
- Wave progression (when to merge)
- Failure routing (partial/blocked agents)
- Integration planning (E25/E26 gap detection)

## SAW Tag Format (E44)

**Rule:** Agent names must use the standardized tag format for observability.

**Format:**
```
[SAW:wave{N}:agent-{ID}] {short description}
```

**Examples:**
- `[SAW:wave1:agent-A] implement cache layer`
- `[SAW:wave2:agent-C] add HTTP endpoints`
- `[SAW:scaffold:user-auth] create interface files`
- `[SAW:critic:user-auth] pre-wave brief review`

**Implementation (automatic):**
1. `sawtools prepare-wave/prepare-agent` writes `saw_name` field to brief frontmatter
2. Orchestrator reads `saw_name` from `.saw-agent-brief.md` and uses as Agent tool name parameter
3. `auto_format_saw_agent_names` PreToolUse hook validates format and provides fallback

**Why:** Enables monitoring tools (claudewatch, SAW dashboard) to detect and track agent runs.

**Components:**
- `SAW:` — Protocol identifier
- `wave{N}:` or `scaffold:` or `critic:` — Phase identifier
- `agent-{ID}` or feature slug — Agent/task identifier
- Short description — Human-readable summary

**Orchestrators:** Read the `saw_name` field from brief frontmatter—do not manually construct names.

## Commit with --no-verify (Parallel Type Dependency Exception)

**Rule:** Wave agents may commit with `git commit --no-verify` when parallel agents have unmerged type dependencies.

**When this applies:** If an agent's worktree fails a pre-commit hook because it imports a type defined in another agent's (not yet merged) worktree, the hook fires on a dependency that doesn't exist in HEAD yet — a false positive caused by parallel execution. In this scenario, the agent may commit with `--no-verify` to bypass the hook.

**Conditions for use:**
1. The failing hook check is about a type or import that will be satisfied post-merge (another agent creates it)
2. The agent's own code is correct and complete
3. The worktree branch remains intact for merge

**Note:** `--no-verify` does NOT bypass the E42 SubagentStop validation hook — that runs at agent session close, not at commit time.

---

## Cross-Repository Orchestration

**Same repo:** Use `isolation: "worktree"` in Agent tool invocations.

**Different repo:**
- **Do NOT** use `isolation` field (creates worktrees in wrong repo)
- Use manual worktree creation via `sawtools prepare-wave` instead
- Pass absolute paths to worktree directories in agent prompts

## Async Execution Requirement

**Rule:** All agent launches MUST use `run_in_background: true`.

**Why:** Enables parallel execution of all agents in a wave within a single orchestrator message.

**Impact:** Orchestrator launches all wave agents, then waits for all to complete before proceeding to merge step.

## Protocol Reference Notation

`I{N}` = Invariants (I1-I6) defined in `protocol/invariants.md`
`E{N}` = Execution rules (E1-E45) defined in `protocol/execution-rules.md`

Each number is an anchor for cross-referencing and audit trail.
