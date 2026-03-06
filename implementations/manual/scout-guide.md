# Manual Scout Guide

**Role:** Analyze codebase to determine SAW suitability and produce agent prompts.

**Time estimate:** 30-90 minutes depending on codebase complexity.

**Output:** IMPL document at `docs/IMPL/IMPL-{feature-name}.md` with suitability verdict and agent prompts.

---

## Overview

The Scout phase answers one question: **Can this work be parallelized safely?**

If the answer is yes, the Scout produces an IMPL doc with everything agents need:
- File ownership assignments (who touches what)
- Interface contracts (how agents' code connects)
- Verification commands (how to validate work)

If the answer is no, the Scout explains why and suggests alternatives.

---

## Step 1: Suitability Assessment (15-30 minutes)

Answer these five questions by reading the codebase:

### P1: File Decomposition

**Question:** Does the work split into ≥2 disjoint file groups?

**How to check:**
1. List all files that need changes for this feature
2. Group files by logical component (e.g., "API handler files", "database migration files", "UI component files")
3. Check if groups share files - if yes, can you restructure to eliminate overlap?

**Example (SUITABLE):**
```
Feature: Add user authentication

Agent A files:
- internal/auth/handler.go (new)
- internal/auth/middleware.go (new)

Agent B files:
- internal/database/migrations/003_users.sql (new)
- internal/database/user_repo.go (modified)

Agent C files:
- cmd/api/routes.go (modified, adds auth routes)
- internal/config/config.go (modified, adds auth config)
```

**Example (NOT SUITABLE):**
```
Feature: Refactor error handling

All agents need to modify:
- internal/errors/errors.go (shared enum)

→ NOT SUITABLE: Shared file blocks parallelization
```

**Verdict:**
- ✓ SUITABLE if you can assign disjoint file lists to ≥2 agents
- ✗ NOT SUITABLE if critical files appear in multiple agents' lists

**Append-only exception:** Shared config registries (e.g., `internal/registry/handlers.go` where each agent appends one line) can be orchestrator-owned and applied post-merge. See [protocol/preconditions.md](../../protocol/preconditions.md) §P1 for append-only definition.

---

### P2: No Investigation-First Blockers

**Question:** Can you fully specify each agent's work before starting?

**How to check:**
1. For each agent, list what they need to implement
2. Ask: "Do I know exactly what interfaces they'll call?"
3. Ask: "Do I know exactly what behavior they'll add?"
4. If answer is "need to investigate first", mark as blocker

**Example (SUITABLE):**
```
Agent A: Implement HTTP handler calling existing UserService.CreateUser()
  → Known interface: UserService.CreateUser(ctx, email, password) error
  → Known behavior: Parse JSON body, validate, call service, return 201

Agent B: Add UserService.CreateUser() method
  → Known interface: func (s *Service) CreateUser(ctx, email, password) error
  → Known behavior: Hash password, call repository, emit event
```

**Example (NOT SUITABLE):**
```
Agent A: Fix database query performance issue
  → Unknown: What's the root cause? Slow query? Missing index? Bad schema?
  → Need to investigate before specifying work

→ NOT SUITABLE: Investigation required first
```

**Verdict:**
- ✓ SUITABLE if each agent's task is fully specified
- ✗ NOT SUITABLE if root cause analysis needed before specification

---

### P3: Interface Discoverability

**Question:** Can you define all cross-agent interfaces before agents start?

**How to check:**
1. Draw dependency arrows: which agents call which agents' code?
2. For each arrow, write the function signature: `func Name(params) returns`
3. If you can't write the signature without seeing the implementation, mark as blocker

**Example (SUITABLE):**
```
Agent A (API) → calls → Agent B (Service)
Interface contract:
  func (s *UserService) CreateUser(ctx context.Context, email, password string) error

Agent B (Service) → calls → Agent C (Repository)
Interface contract:
  func (r *UserRepository) Insert(ctx context.Context, user User) error
```

**Example (NOT SUITABLE):**
```
Agent A: Implement data processor
Agent B: Implement data consumer

What interface does A expose for B to call?
→ Unknown: Need to see A's implementation to know what methods B can call

→ NOT SUITABLE: Interface signatures cannot be known upfront
```

**Verdict:**
- ✓ SUITABLE if all function signatures can be written now
- ✗ NOT SUITABLE if signatures depend on seeing implementation

---

### P4: Pre-Implementation Scan

**Question:** If working from an audit/findings list, are all items classified?

**How to check:**
1. If starting from bug list, audit report, or TODO list, read each item
2. Mark each as: TO-DO (needs implementation), DONE (already fixed), PARTIAL (started but incomplete)
3. Only assign TO-DO items to agents

**Example (SUITABLE):**
```
Audit findings:
1. Missing input validation on /users endpoint → TO-DO (assign to Agent A)
2. Exposed debug endpoints in production → DONE (removed in commit abc123)
3. SQL injection risk in search query → TO-DO (assign to Agent B)
4. Rate limiting partially implemented → PARTIAL (assign remaining work to Agent C)
```

**Example (NOT SUITABLE if skipped):**
```
Assign all 15 audit items to agents without checking status
→ Agents waste time implementing already-fixed issues
→ Duplicate implementations cause merge conflicts
```

**Verdict:**
- ✓ SUITABLE if all items classified before assignment (or not working from list)
- ✗ NOT SUITABLE if items not pre-scanned

---

### P5: Positive Parallelization Value

**Question:** Does parallelization save time vs sequential work?

**How to calculate:**
```
Sequential time:    Agent A (3h) + Agent B (3h) + Agent C (2h) = 8 hours
Parallel time:      max(3h, 3h, 2h) = 3 hours
Scout + merge:      1h + 0.5h = 1.5 hours

Time saved:         8h - (3h + 1.5h) = 3.5 hours

→ SUITABLE: Parallelization saves 3.5 hours
```

**When parallelization loses:**
```
Sequential time:    Agent A (1h) + Agent B (1h) = 2 hours
Parallel time:      max(1h, 1h) = 1 hour
Scout + merge:      1h + 0.5h = 1.5 hours

Time saved:         2h - (1h + 1.5h) = -0.5 hours

→ NOT SUITABLE: Parallelization is slower than sequential work
```

**Verdict:**
- ✓ SUITABLE if `(sequential_time - max_agent_time) > (scout_time + merge_time)`
- ✗ NOT SUITABLE if overhead exceeds time saved

---

## Step 2: Suitability Verdict (5 minutes)

Based on P1-P5 answers, write verdict in IMPL doc:

### Format: SUITABLE

```markdown
## Suitability Verdict

**Verdict:** SUITABLE

**Precondition assessment:**
- P1 (File decomposition): ✓ Work splits into 3 disjoint file groups (auth, database, config)
- P2 (No investigation-first blockers): ✓ All work fully specified
- P3 (Interface discoverability): ✓ All interfaces defined (see Interface Contracts section)
- P4 (Pre-implementation scan): ✓ All 8 audit items classified (5 TO-DO, 2 DONE, 1 PARTIAL)
- P5 (Positive parallelization value): ✓ Saves 4 hours (8h sequential vs 3h + 1h overhead)

**Estimated time:** 3 hours (parallel) + 1 hour (scout + merge) = 4 hours total
```

### Format: NOT SUITABLE

```markdown
## Suitability Verdict

**Verdict:** NOT SUITABLE

**Failed preconditions:**
- P1 (File decomposition): ✗ All agents must modify shared enum in internal/errors/errors.go
- P3 (Interface discoverability): ✗ Agent B's interface depends on Agent A's implementation details

**Suggested alternative:** Sequential implementation. Agent A implements error types first, then Agent B uses them.
```

**See:** [protocol/preconditions.md](../../protocol/preconditions.md) for detailed precondition definitions.

---

## Step 3: Dependency Mapping (10-20 minutes)

If SUITABLE, draw the dependency graph:

### Simple Example (No Dependencies)

```
Wave 1:
  Agent A: API handlers     (no dependencies)
  Agent B: Database layer   (no dependencies)
  Agent C: Config parser    (no dependencies)

→ All agents run in parallel (one wave)
```

### Complex Example (Multi-Wave)

```
Wave 1:
  Agent A: Define User type           (no dependencies)
  Agent B: Implement UserRepository   (depends on User type from A)

→ Wave 1 completes, commits to main

Wave 2:
  Agent C: Implement UserService      (depends on A + B from Wave 1)
  Agent D: Implement HTTP handlers    (depends on A from Wave 1)

→ Wave 2 completes
```

**Rule:** If Agent X calls code from Agent Y, they must be in different waves (Y before X).

**Scaffold files:** If multiple agents in the same wave need the same type definition, create a scaffold file (type-only stub) that all agents import. See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E2 for scaffold materialization.

---

## Step 4: Interface Contracts (15-30 minutes)

For each cross-agent interface, write exact signature:

### Go Example

```markdown
## Interface Contracts

### Agent B → Agent C (Repository Interface)

**File:** `internal/database/user_repo.go`

**Interface:**
```go
type UserRepository interface {
    Insert(ctx context.Context, user *User) error
    FindByEmail(ctx context.Context, email string) (*User, error)
}
```

**Import path:** `import "github.com/example/app/internal/database"`

**Status:** pending (becomes `committed (sha)` after scaffold agent runs)
```

### TypeScript Example

```markdown
## Interface Contracts

### Agent A → Agent B (API Types)

**File:** `src/types/api.ts`

**Interface:**
```typescript
export interface CreateUserRequest {
  email: string;
  password: string;
}

export interface CreateUserResponse {
  id: string;
  email: string;
  createdAt: string;
}
```

**Import path:** `import { CreateUserRequest, CreateUserResponse } from '@/types/api'`

**Status:** pending
```

**See:** [protocol/invariants.md](../../protocol/invariants.md) §I2 for interface contract requirements.

---

## Step 5: File Ownership Table (10-15 minutes)

Assign exact file lists to each agent:

```markdown
## File Ownership

| Agent | Files Owned |
|-------|-------------|
| A | internal/auth/handler.go (new) |
| A | internal/auth/middleware.go (new) |
| B | internal/database/migrations/003_users.sql (new) |
| B | internal/database/user_repo.go (modified) |
| C | cmd/api/routes.go (modified) |
| C | internal/config/config.go (modified) |
```

**Critical:** No file appears in >1 agent's list (I1: disjoint file ownership).

**Note:** Mark files as `(new)` or `(modified)` for clarity.

---

## Step 6: Agent Prompts (30-60 minutes)

For each agent, write a 9-field prompt:

### Field 0: Isolation Verification

Copy from [templates/agent-prompt-template.md](../../templates/agent-prompt-template.md) and fill in:
- `{worktree-path}` → `.claude/worktrees/wave1-agent-A`
- `{branch-name}` → `wave1-agent-A`

### Field 1: File Ownership

Copy the agent's row from File Ownership table.

### Field 2: Interfaces to Implement

List interfaces this agent creates (that other agents will call):

```markdown
Implement these interfaces exactly as specified in Interface Contracts:

- `UserRepository` interface in `internal/database/user_repo.go`
- Must include methods: `Insert()`, `FindByEmail()`
```

### Field 3: Interfaces to Call

List interfaces this agent uses (from other agents or scaffolds):

```markdown
Import and call these interfaces:

- `UserService.CreateUser()` from `internal/service/user_service.go` (Agent B)
- Use `User` type from `internal/types/user.go` (scaffold file)
```

### Field 4: What to Implement

Describe the feature work in plain language:

```markdown
Implement HTTP handlers for user authentication:

1. POST /auth/register endpoint
   - Parse JSON body (email, password)
   - Validate email format
   - Call UserService.CreateUser()
   - Return 201 Created on success

2. POST /auth/login endpoint
   - Parse JSON body (email, password)
   - Call UserService.Authenticate()
   - Return JWT token on success
```

### Field 5: Tests to Write

Specify test requirements:

```markdown
Write tests in `internal/auth/handler_test.go`:

- TestRegisterHandler_Success (valid input)
- TestRegisterHandler_InvalidEmail (validation error)
- TestRegisterHandler_DuplicateUser (409 Conflict)
```

### Field 6: Verification Gate

Specify exact commands to run:

```markdown
Run these commands before reporting complete:

```bash
# Build
go build ./internal/auth

# Lint
go vet ./internal/auth

# Tests
go test ./internal/auth -v
```

All commands must pass (exit code 0).
```

**Critical:** Use scoped commands (only test owned packages). See [protocol/execution-rules.md](../../protocol/execution-rules.md) §E10 for scoping rationale.

### Field 7: Constraints

List any restrictions:

```markdown
- Hard constraint: Do not modify `internal/database/schema.go` (owned by Agent B)
- Error handling: Return errors, do not panic
- Logging: Use structured logging (zerolog)
```

### Field 8: Report Instructions

```markdown
After completing work and verification:

1. Commit changes:
   ```bash
   git add .
   git commit -m "wave1-agent-A: implement auth handlers"
   ```

2. Report completion by updating this IMPL doc with your status:
   - Add completion report under "### Agent A - Completion Report"
   - Include commit SHA, files changed, verification results
```

**Full template:** See [templates/agent-prompt-template.md](../../templates/agent-prompt-template.md) for complete structure.

---

## Step 7: Write IMPL Doc (10 minutes)

Combine all sections into `docs/IMPL/IMPL-{feature-name}.md`:

```markdown
# IMPL: User Authentication Feature

**Repository:** /Users/you/code/yourapp
**Feature:** Add user registration and login endpoints
**Scout:** Your Name
**Date:** 2026-03-06

---

## Suitability Verdict

[Paste from Step 2]

---

## Dependency Graph

[Paste from Step 3]

---

## Interface Contracts

[Paste from Step 4]

---

## File Ownership

[Paste from Step 5]

---

## Wave Structure

### Wave 1

#### Agent A - Auth Handlers

[Paste Field 0-8 from Step 6]

#### Agent B - Database Layer

[Paste Field 0-8 from Step 6]

#### Agent C - Config Updates

[Paste Field 0-8 from Step 6]

---

## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Auth handlers | TO-DO |
| 1 | B | Database layer | TO-DO |
| 1 | C | Config updates | TO-DO |
```

**Template:** See [templates/IMPL-doc-template.md](../../templates/IMPL-doc-template.md) for complete structure.

---

## Step 8: Review and Approve (5 minutes)

Before handing off to team:

1. ✓ Verify no file appears in multiple agents' ownership lists
2. ✓ Verify all interface contracts have exact signatures
3. ✓ Verify verification commands are scoped (not project-wide)
4. ✓ Verify time estimates are realistic
5. ✓ Verify each agent's Field 0-8 is complete

If all checks pass, the IMPL doc is ready for Wave phase.

---

## Common Scout Mistakes

1. **Forgetting to check file overlap** → Causes merge conflicts in Wave
2. **Vague interface contracts** ("Agent A will define some types") → Agents implement incompatible interfaces
3. **Project-wide verification commands** (`go test ./...`) → Slows iteration, violates E10
4. **Missing time estimates** → Can't evaluate P5 (positive parallelization value)
5. **No scaffold files for shared types within wave** → Agents can't import each other's uncommitted code

---

## When Scout Fails

If you answer "NOT SUITABLE" to any P1-P5 question:

**Option 1: Restructure work**
- Can you split shared files into smaller modules?
- Can you defer investigation to a pre-scout phase?
- Can you define interfaces more precisely?

**Option 2: Use sequential implementation**
- If restructure isn't viable, SAW isn't the right tool
- Standard sequential PR workflow is better

**Option 3: Hybrid approach**
- Parallelize what you can, defer blockers to later wave
- Example: Wave 1 does investigation, Wave 2 parallelizes fixes

---

## Next Steps

After Scout completes and IMPL doc is approved:

1. Share IMPL doc with team
2. Assign each agent section to a team member
3. Proceed to [wave-guide.md](./wave-guide.md) for parallel execution

---

**References:**
- [protocol/preconditions.md](../../protocol/preconditions.md) - P1-P5 detailed definitions
- [protocol/invariants.md](../../protocol/invariants.md) - I1-I6 constraints
- [protocol/execution-rules.md](../../protocol/execution-rules.md) - E1-E14 procedures
- [templates/agent-prompt-template.md](../../templates/agent-prompt-template.md) - Field 0-8 structure
- [templates/IMPL-doc-template.md](../../templates/IMPL-doc-template.md) - IMPL doc structure
