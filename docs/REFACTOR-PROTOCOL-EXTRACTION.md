# Scout-and-Wave Protocol Extraction Refactor Plan

**Version:** 1.0.0
**Status:** Draft
**Created:** 2026-03-06
**Estimated Effort:** 16-24 hours across 4 phases

## Executive Summary

Scout-and-Wave was designed as a general-purpose protocol for safely parallelizing human-guided agentic workflows, with Claude Code as the reference implementation. However, the current codebase intermixes protocol-level specifications with Claude Code-specific implementation details, making it difficult for other AI systems or manual orchestration to adopt the protocol.

This refactor extracts the pure protocol into a clean, implementation-agnostic specification layer while preserving full backward compatibility for existing Claude Code users. The goal is to enable alternative implementations (Python orchestrators, manual workflows, other AI runtimes) without disrupting current workflows.

**Key Benefits:**
- Other AI systems can implement SAW from protocol docs alone
- Manual orchestration becomes feasible for human-driven workflows
- Protocol improvements don't break implementations
- Clear separation enables independent evolution of protocol vs. implementation

**Key Risks:**
- Documentation drift between protocol and implementations
- Over-engineering if no alternative implementations emerge
- Breaking changes for users who depend on current file locations

## 1. Current State Analysis

### 1.1 What's Mixed (Protocol + Implementation)

**PROTOCOL.md** - Currently contains:
- ✅ Pure protocol: Invariants I1-I6, Execution Rules E1-E14, state machine, message formats
- ⚠️ Mixed: References to Claude Code tools (Agent tool, Task tool, `run_in_background: true`)
- ⚠️ Mixed: "Reference Implementation" section points to Claude Code prompts specifically
- ⚠️ Mixed: Version headers section mandates markdown comment syntax (`<!-- -->`)

**README.md** - Currently contains:
- ❌ Claude Code-specific: Entire "Usage with Claude Code" section (50% of content)
- ❌ Claude Code-specific: Install instructions for `~/.claude/` directory structure
- ❌ Claude Code-specific: Permission model (`allow` list in `~/.claude/settings.json`)
- ✅ Pure protocol: "Why", "How", "Quick Start" concepts (but examples are Claude-specific)
- ⚠️ Mixed: Invariants described in prose but with Claude Code tool names

**prompts/scout.md** - Currently contains:
- ❌ Claude Code-specific: "You may create one artifact... using the Write tool"
- ❌ Claude Code-specific: Tool name references (Read, Write, Edit, Bash)
- ✅ Pure protocol: Suitability gate questions, IMPL doc schema, output format
- ✅ Pure protocol: File ownership rules, interface contract requirements

**prompts/scaffold-agent.md** - Currently contains:
- ❌ Claude Code-specific: "Your launch parameters should include..."
- ❌ Claude Code-specific: Tool references (Read, Edit, Bash)
- ✅ Pure protocol: Scaffold Agent responsibilities, compilation verification, commit rules

**prompts/agent-template.md** - Currently contains:
- ❌ Claude Code-specific: 9-field structure assumes markdown-formatted prompts
- ❌ Claude Code-specific: Bash code blocks for isolation verification
- ✅ Pure protocol: Field 0 isolation concept, ownership rules, completion report schema
- ⚠️ Mixed: YAML completion report format (good) with Claude-specific field examples

**prompts/saw-skill.md** - Entirely Claude Code-specific:
- ❌ Skill file format with markdown comments for versioning
- ❌ References to `subagent_type`, `run_in_background`, `isolation: "worktree"`
- ❌ Agent tool launch syntax throughout

**prompts/saw-merge.md** - Currently contains:
- ✅ Pure protocol: Merge procedure steps, conflict taxonomy, verification gates
- ⚠️ Mixed: Git commands (universal) with orchestrator instructions (Claude-specific prose)
- ✅ Pure protocol: Trip wire logic, ownership verification, cascade candidate handling

### 1.2 Where Claude Code Assumptions Leak

**Permission Model:**
- `allow` list in `~/.claude/settings.json` is Claude Code-specific
- "Agent" tool permission requirements scattered throughout docs
- No generic description of what capabilities an orchestrator needs

**Agent Launch Mechanism:**
- `run_in_background: true` appears in PROTOCOL.md E1 as if it's universal
- `subagent_type` is Claude Code's agent type system
- `isolation: "worktree"` is a Claude Code parameter, not a protocol requirement

**Tool Names:**
- Read, Write, Edit, Bash, Glob, Grep are Claude Code tools
- Protocol docs reference these as if they're universal primitives
- No abstraction layer for file operations vs. git operations vs. shell commands

**Prompt Delivery:**
- Assumes prompts are markdown files with YAML frontmatter
- Assumes agent launch accepts a `prompt` parameter
- No specification of how prompts could be delivered in non-file systems

**Version Headers:**
- Mandates `<!-- name v0.0.0 -->` syntax (HTML comments in markdown)
- Not applicable to JSON-based systems or Python scripts

### 1.3 What's Already Well-Separated

**Invariants I1-I6:**
- Cleanly defined, implementation-agnostic
- No tool references in definitions
- Could be implemented in any runtime

**Message Formats:**
- YAML completion report schema is universal
- Suitability verdict format has no Claude-specific dependencies
- IMPL doc structure is markdown but could map to other formats

**State Machine:**
- Transitions are pure logic, no implementation coupling
- BLOCKED, REVIEWED, WAVE_PENDING states are universal concepts

**Git Operations:**
- Worktree management is git-native, works across all environments
- Merge procedure is standard git, no Claude Code coupling

**Suitability Gate:**
- Five questions are implementation-agnostic
- Could be answered manually or by any AI system

## 2. Target Architecture

### 2.1 Proposed Directory Structure

```
scout-and-wave/
├── PROTOCOL.md              # Pure protocol spec (invariants, state machine, guarantees)
├── IMPL-SCHEMA.md           # IMPL doc format reference (sections, fields, examples)
├── README.md                # Overview + navigation to protocol & implementations
├── LICENSE
├── CHANGELOG.md
│
├── protocol/                # Protocol-level documentation (implementation-agnostic)
│   ├── README.md            # Protocol overview, intended audience, adoption guide
│   ├── participants.md      # Orchestrator, Scout, Scaffold Agent, Wave Agent roles
│   ├── preconditions.md     # Five suitability gate questions with examples
│   ├── invariants.md        # I1-I6 definitions with violation taxonomy
│   ├── execution-rules.md   # E1-E14 definitions with rationale
│   ├── state-machine.md     # State transitions, wave lifecycle, checkpoints
│   ├── message-formats.md   # YAML schemas, suitability verdict, completion reports
│   ├── merge-procedure.md   # Conflict taxonomy, merge steps, verification gates
│   ├── worktree-isolation.md # 5-layer defense model, ownership vs. isolation
│   ├── compliance.md        # How to verify protocol compliance (checklist)
│   └── FAQ.md               # Common questions about protocol interpretation
│
├── implementations/
│   ├── README.md            # Implementation comparison table, choosing guide
│   │
│   ├── claude-code/         # Reference implementation
│   │   ├── README.md        # Installation, usage, configuration
│   │   ├── QUICKSTART.md    # First run walkthrough (moved from docs/)
│   │   ├── prompts/
│   │   │   ├── saw-skill.md
│   │   │   ├── saw-merge.md
│   │   │   ├── saw-worktree.md
│   │   │   ├── saw-bootstrap.md
│   │   │   ├── scout.md              # Fallback prompt
│   │   │   ├── scaffold-agent.md     # Fallback prompt
│   │   │   ├── agent-template.md     # Fillable template
│   │   │   └── agents/
│   │   │       ├── scout.md          # Custom agent type
│   │   │       ├── scaffold-agent.md # Custom agent type
│   │   │       └── wave-agent.md     # Custom agent type
│   │   ├── hooks/
│   │   │   └── pre-commit-guard.sh
│   │   ├── examples/
│   │   │   └── brewprune-IMPL-brew-native.md
│   │   └── docs/
│   │       ├── agent-architecture.md
│   │       ├── permissions.md
│   │       └── troubleshooting.md
│   │
│   └── manual/              # Manual orchestration guide
│       ├── README.md        # When to orchestrate manually, prerequisites
│       ├── scout-guide.md   # How to perform scout analysis by hand
│       ├── wave-guide.md    # How to coordinate parallel work manually
│       ├── merge-guide.md   # Step-by-step merge procedure for humans
│       └── checklist.md     # Printable checklist for manual runs
│
├── templates/               # Generic, fillable templates
│   ├── IMPL-doc-template.md        # Generic IMPL doc with [PLACEHOLDER] markers
│   ├── agent-prompt-template.md    # Generic 9-field agent prompt
│   ├── completion-report.yaml      # Completion report schema with examples
│   └── suitability-verdict.md      # Verdict format template
│
└── docs/                    # Project-level docs (not moved)
    ├── diagrams/
    │   ├── saw-state-machine-light.svg
    │   ├── saw-state-machine-dark.svg
    │   ├── saw-scout-wave-light.svg
    │   └── saw-scout-wave-dark.svg
    └── IMPL/                # Generated IMPL docs land here during use
```

### 2.2 File Mapping (Old → New)

| Current Location | New Location | Notes |
|------------------|--------------|-------|
| `PROTOCOL.md` | `PROTOCOL.md` (updated) | Extract Claude-specific refs to `implementations/claude-code/` |
| `README.md` | `README.md` (rewritten) | High-level overview, points to protocol/ and implementations/ |
| `prompts/scout.md` | `implementations/claude-code/prompts/scout.md` | Keep Claude version here |
| `prompts/scaffold-agent.md` | `implementations/claude-code/prompts/scaffold-agent.md` | Keep Claude version here |
| `prompts/agent-template.md` | `implementations/claude-code/prompts/agent-template.md` | Keep Claude version here |
| `prompts/saw-skill.md` | `implementations/claude-code/prompts/saw-skill.md` | Claude Code skill file |
| `prompts/saw-merge.md` | `implementations/claude-code/prompts/saw-merge.md` | Claude orchestrator merge logic |
| `prompts/saw-worktree.md` | `implementations/claude-code/prompts/saw-worktree.md` | Claude orchestrator worktree logic |
| `prompts/saw-bootstrap.md` | `implementations/claude-code/prompts/saw-bootstrap.md` | Bootstrap mode |
| `prompts/agents/*.md` | `implementations/claude-code/prompts/agents/*.md` | Custom agent types |
| `docs/QUICKSTART.md` | `implementations/claude-code/QUICKSTART.md` | Claude Code walkthrough |
| `examples/*.md` | `implementations/claude-code/examples/*.md` | Claude Code examples |
| N/A (new) | `protocol/*.md` | Pure protocol extraction |
| N/A (new) | `templates/*.md` | Generic templates |
| N/A (new) | `implementations/manual/*.md` | Manual orchestration guide |
| N/A (new) | `IMPL-SCHEMA.md` | IMPL doc format reference |

## 3. Separation Strategy

### 3.1 Protocol Layer (Implementation-Agnostic)

**PROTOCOL.md** - Cleaned Version
- Remove all Claude Code tool references
- Abstract "agent launch" to "agent execution begins"
- Change "run_in_background: true" to "asynchronous execution required"
- Keep invariants I1-I6 verbatim (already clean)
- Keep execution rules E1-E14 but with generic language
- Keep state machine (already clean)
- Remove "Reference Implementation" section (move to implementations/README.md)
- Add "Conformance" section: what an implementation MUST preserve

**protocol/participants.md**
```markdown
# Participant Roles

Four participants in the Scout-and-Wave protocol:

## Orchestrator
- **Execution mode:** Synchronous (interactive session)
- **Responsibilities:**
  - Launch Scout, Scaffold Agent, Wave Agents
  - Serialize all state transitions
  - Execute merge procedure
  - Run verification gates
  - Present human checkpoints
- **Required capabilities:**
  - Read/write files
  - Execute git commands
  - Launch asynchronous agents
  - Parse YAML completion reports
- **Forbidden actions:**
  - Performing Scout analysis duties (I6)
  - Performing Wave Agent implementation duties (I6)

## Scout
- **Execution mode:** Asynchronous (background)
- **Responsibilities:**
  - Analyze codebase
  - Run suitability gate
  - Produce IMPL doc
  - Define interface contracts
  - Specify scaffold files
- **Required capabilities:**
  - Read source files
  - Understand project structure
  - Write IMPL doc
- **Forbidden actions:**
  - Modifying source files
  - Creating scaffold files (specify only)
  - Participating in wave execution

## Scaffold Agent
- **Execution mode:** Asynchronous (background)
- **Responsibilities:**
  - Read approved interface contracts
  - Create type scaffold source files
  - Verify compilation
  - Commit to HEAD
- **Required capabilities:**
  - Read IMPL doc
  - Write source files
  - Execute build commands
  - Execute git commands
- **Forbidden actions:**
  - Modifying existing source files
  - Implementing behavior (types only)

## Wave Agent
- **Execution mode:** Asynchronous (background, parallel)
- **Responsibilities:**
  - Implement assigned files
  - Run verification gate
  - Commit to worktree branch
  - Write completion report
- **Required capabilities:**
  - Read/write files (owned files only)
  - Execute build, lint, test commands
  - Execute git commands
  - Parse IMPL doc (own prompt section)
- **Forbidden actions:**
  - Modifying files outside ownership scope (except justified)
  - Coordinating directly with other Wave Agents
```

**protocol/invariants.md**
```markdown
# Protocol Invariants

Invariants I1-I6 MUST hold throughout execution. Violations invalidate correctness guarantees.

## I1: Disjoint File Ownership

**Definition:** No two agents in the same wave own the same file.

**Enforcement point:** Orchestrator pre-launch ownership verification (E3)

**Why this matters:** This is the mechanism that makes parallel execution safe. Worktree isolation prevents execution-time interference; disjoint ownership prevents merge conflicts.

**Violation detection:**
- Pre-launch: Orchestrator scans IMPL doc ownership table
- Post-execution: Orchestrator cross-references completion report `files_changed` lists
- Merge-time: Conflict prediction step (merge procedure Step 2)

**Exception:** Orchestrator-owned append-only files (IMPL doc, config registries)

**Example violation:**
```yaml
# IMPL doc ownership table shows:
# Agent A owns: src/cache.go
# Agent B owns: src/cache.go, src/client.go
# ⚠️ I1 VIOLATION: cache.go appears in both lists
```

**Recovery:** Correct IMPL doc ownership table before launching wave.

## I2: Interface Contracts Precede Parallel Implementation

**Definition:** The Scout defines all cross-agent interfaces in the IMPL doc. The Scaffold Agent implements them as type scaffold files committed to HEAD after human review, before any Wave Agent launches.

**Enforcement point:** Orchestrator verifies scaffold files exist and compile (Scaffolds section status checks) before creating worktrees

**Why this matters:** Agents work in isolated worktrees and cannot see each other's code. Shared types must exist on HEAD before worktrees branch.

**Violation detection:**
- Pre-wave: Scaffolds section shows `Status: pending` or `Status: FAILED`
- Post-wave: Scaffold files missing or modified in merged result

**Example:**
```markdown
### Scaffolds
| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| internal/types/cache.go | CacheEntry struct | pkg/types | committed (abc123) |
```

## I3: Wave Sequencing

**Definition:** Wave N+1 does not launch until Wave N has been merged and post-merge verification has passed.

**Enforcement point:** Orchestrator checks previous wave status before launching next wave

**Why this matters:** Later waves depend on earlier waves' committed work. Launching Wave 2 before Wave 1 verification passes can propagate broken code.

**Violation detection:** Manual audit of orchestrator launch sequence

**Example compliant sequence:**
1. Launch Wave 1 agents
2. Wait for all Wave 1 completion reports
3. Merge Wave 1
4. Run post-merge verification
5. If PASS: launch Wave 2
6. If FAIL: fix, re-verify, then launch Wave 2

## I4: IMPL Doc is Single Source of Truth

**Definition:** Completion reports, interface contract updates, and status are written to the IMPL doc. Chat output is not the record.

**Enforcement point:** Orchestrator reads IMPL doc for state, not agent chat logs

**Why this matters:** Enables crash recovery, provides audit trail, allows orchestrator to parse structured data

**Violation detection:** Completion report present in chat but not in IMPL doc

**Example:**
```yaml
### Agent A - Completion Report
status: complete
worktree: .claude/worktrees/wave1-agent-A
commit: abc123
# ... rest of report
```

## I5: Agents Commit Before Reporting

**Definition:** Each agent commits its changes to its worktree branch before writing a completion report.

**Enforcement point:** Merge procedure Step 1.5 (trip wire - counts commits per branch)

**Why this matters:** Enables git merge instead of manual file copying. Provides atomic change sets.

**Violation detection:** Branch has 0 commits but completion report shows `status: complete`

**Recovery options:**
1. Re-run wave (discard changes, safest)
2. Investigate (attribute changes manually)
3. Accept as-is (bypass merge guarantees)

## I6: Role Separation

**Definition:** The Orchestrator does not perform Scout, Scaffold Agent, or Wave Agent duties.

**Enforcement point:** Manual audit, observability tooling

**Why this matters:**
- Maintains async execution parallelism
- Prevents context pollution
- Enables observability (agent sessions are detectable)

**Violation examples:**
- Orchestrator reads codebase files to write IMPL doc (Scout duty)
- Orchestrator creates scaffold files directly (Scaffold Agent duty)
- Orchestrator implements source changes inline (Wave Agent duty)

**Correct pattern:** Orchestrator launches appropriate agent type for each phase
```

**protocol/execution-rules.md** - Similar treatment for E1-E14 with generic language

**protocol/message-formats.md**
```yaml
# Completion Report Schema

version: 1.0.0

# Required fields (must be present in all implementations)
required:
  - status          # complete | partial | blocked
  - worktree        # relative path from repo root
  - commit          # git SHA or "uncommitted"
  - files_changed   # array of relative paths
  - files_created   # array of relative paths
  - verification    # PASS | FAIL with command and test count

# Optional fields (recommended for protocol compliance)
optional:
  - interface_deviations:
      type: array
      items:
        - description: string
        - downstream_action_required: boolean
        - affects: array of agent identifiers
  - out_of_scope_deps:
      type: array
      items:
        - file: string
        - change: string
        - reason: string
  - tests_added:
      type: array
      items: string (test name)

# Implementation-specific extensions
# Implementations MAY add custom fields with namespaced keys
# Example: claude_code_session_id, python_orchestrator_pid

# Example compliant report
example: |
  ### Agent A - Completion Report
  status: complete
  worktree: .claude/worktrees/wave1-agent-A
  commit: abc123def456
  files_changed:
    - src/cache.go
    - src/cache_test.go
  files_created:
    - docs/cache-design.md
  interface_deviations: []
  out_of_scope_deps: []
  tests_added:
    - TestCacheGet
    - TestCacheSet
    - TestCacheExpiry
  verification: PASS (go test ./src/cache_test.go - 3/3 tests)
```

**IMPL-SCHEMA.md** - New File
```markdown
# IMPL Document Schema

Version: 1.0.0

The IMPL doc is the coordination artifact that enables parallel agent execution. This document defines its structure.

## File Naming Convention

- Pattern: `docs/IMPL/IMPL-<feature-slug>.md`
- Example: `docs/IMPL/IMPL-add-caching-layer.md`
- Location: Always in `docs/IMPL/` directory at repository root
- Format: Markdown with YAML code blocks for structured data

## Required Sections

### 1. Suitability Assessment

**Purpose:** Record scout's verdict before any agent launches

**Required fields:**
- `Verdict:` SUITABLE | NOT SUITABLE | SUITABLE WITH CAVEATS
- `test_command:` Full test suite command for post-merge verification
- `lint_command:` Check-mode lint command or "none"
- Rationale paragraph

**If NOT SUITABLE:**
- List failed preconditions with evidence
- Suggest alternative approach
- STOP - do not include sections 2-8

### 2. Scaffolds (Conditional)

**Purpose:** Specify type scaffold files for Scaffold Agent to create

**When to include:** If any types cross agent boundaries

**When to omit:** If agents have independent type ownership

**Format:**
| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| path | Type definitions | import/path | pending |

**Status lifecycle:**
- `pending` → Scout wrote spec, Scaffold Agent not yet run
- `committed (sha)` → Scaffold Agent created and committed file
- `FAILED: {reason}` → Compilation failed, blockers wave launch

### 3. Known Issues (Optional but Recommended)

**Purpose:** Document pre-existing failures to distinguish from regressions

**Example:**
```markdown
- TestFoo - Hangs (tries to execute binary as CLI)
  - Status: Pre-existing, unrelated to this work
  - Workaround: Skip with `-skip 'TestFoo'`
```

### 4. Dependency Graph

**Purpose:** Explain which files/modules block which others

**Contents:**
- DAG description (roots, leaves, dependencies)
- Files split or extracted to resolve ownership conflicts
- Cascade candidates (files not changing but referencing changed interfaces)

### 5. Interface Contracts

**Purpose:** Binding contracts for cross-agent function signatures

**Requirements:**
- Language-specific, fully typed
- No pseudocode
- Exact signatures agents will implement/call

### 6. File Ownership

**Purpose:** Disjoint file assignment (I1 enforcement)

**Format:**
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| ... | ... | ... | ... |

**Constraints:**
- No file appears in multiple agent rows (same wave)
- Every file that will change is listed
- Generated files (build artifacts) excluded

### 7. Wave Structure

**Purpose:** Visual representation of parallel execution plan

**Format:**
```
Wave 1: [A] [B] [C]          <- 3 parallel agents (foundation)
           | (A+B complete)
Wave 2:   [D] [E]            <- 2 parallel agents
           | (D+E complete)
Wave 3:    [F]               <- 1 agent
```

### 8. Agent Prompts

**Purpose:** Complete, self-contained instructions per agent

**Format:** 9-field structure (see templates/agent-prompt-template.md)

**Contents per agent:**
- Field 0: Isolation verification
- Field 1: File ownership list
- Field 2: Interfaces to implement
- Field 3: Interfaces to call
- Field 4: What to implement (functional description)
- Field 5: Tests to write
- Field 6: Verification gate (exact commands)
- Field 7: Constraints
- Field 8: Report (completion report instructions)

### 9. Wave Execution Loop

**Purpose:** Rationale for orchestrator post-merge checklist

**Contents:**
- Merge procedure summary
- Interface deviation handling
- Verification gate explanation

### 10. Orchestrator Post-Merge Checklist

**Purpose:** Executable checklist for orchestrator after each wave

**Format:** Markdown checklist with feature-specific steps

**Standard items:**
- [ ] Read all completion reports
- [ ] Conflict prediction
- [ ] Review interface deviations
- [ ] Merge each agent
- [ ] Worktree cleanup
- [ ] Post-merge verification
- [ ] Cascade failure fixes
- [ ] Status updates
- [ ] Commit
- [ ] Launch next wave

### 11. Status

**Purpose:** Live tracking of agent completion

**Format:**
| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| — | Scaffold | ... | TO-DO |
| 1 | A | ... | TO-DO → IN PROGRESS → DONE |
| 1 | B | ... | TO-DO |

**Status values:** TO-DO | IN PROGRESS | DONE | BLOCKED

## Completion Reports (Appended by Agents)

**Location:** End of IMPL doc, one section per agent

**Format:** See protocol/message-formats.md for YAML schema

**Section header:** `### Agent {letter} - Completion Report`

## Implementation Notes

- **Size limit:** If IMPL doc exceeds ~20KB, split into index + per-agent files
- **Concurrent writes:** Agents append distinct sections (E14), orchestrator resolves conflicts
- **Parsing:** Orchestrator must parse YAML blocks, not just read freeform text
```

### 3.2 Implementation Layer (Claude Code-Specific)

**implementations/claude-code/README.md**
```markdown
# Claude Code Reference Implementation

Scout-and-Wave implemented as a Claude Code skill.

## Prerequisites

- Claude Code desktop app
- Git 2.20+ (for worktree support)
- Project with existing codebase OR empty repo for bootstrap mode

## Installation

See detailed installation instructions including:
- Permission configuration (`~/.claude/settings.json`)
- Repository cloning
- Skill file installation
- Custom agent types (optional)

## Usage

```
/saw scout "feature description"
/saw wave
/saw wave --auto
/saw status
```

## Tool Requirements

This implementation uses Claude Code's tool suite:
- **Agent:** Launch Scout, Scaffold Agent, Wave Agents
- **Read/Write/Edit:** IMPL doc and source file operations
- **Bash:** Git commands, build/test execution
- **Glob/Grep:** Codebase analysis during scout phase

## Skill Architecture

- **saw-skill.md:** Command router (Orchestrator role)
- **saw-merge.md:** Merge procedure implementation
- **saw-worktree.md:** Worktree lifecycle management
- **saw-bootstrap.md:** Bootstrap mode for new projects

## Agent Types

Custom agent types provide:
- Tool-level enforcement (scout cannot Edit source files)
- Observability (claudewatch tracks agent types separately)
- Graceful fallback to general-purpose agents

Install to `~/.claude/agents/` for enhanced experience.

## Examples

See `examples/` for real IMPL docs from dogfooding sessions.
```

**implementations/claude-code/prompts/scout.md** - Keep current version with Claude tool names

**implementations/claude-code/prompts/agent-template.md** - Keep current 9-field version

### 3.3 Manual Implementation (New)

**implementations/manual/README.md**
```markdown
# Manual Orchestration Guide

How to run Scout-and-Wave by hand without AI orchestration.

## When to Orchestrate Manually

- Learning the protocol deeply
- Small waves (1-2 agents) where automation overhead exceeds benefit
- Debugging protocol compliance issues
- Building a new implementation (use this as a reference)

## Prerequisites

- Understanding of protocol invariants (I1-I6)
- Git worktree experience
- Ability to read and write IMPL docs
- Discipline to follow checklist strictly

## Overview

You play all four participant roles:

1. **Scout role:** Analyze codebase, write IMPL doc by hand
2. **Scaffold Agent role:** Create scaffold files from IMPL doc contracts
3. **Wave Agent role:** Implement in worktrees, write completion reports
4. **Orchestrator role:** Merge, verify, advance state

## Process

See individual guides for detailed steps:
- `scout-guide.md` - Suitability gate + IMPL doc creation
- `wave-guide.md` - Worktree setup + parallel implementation
- `merge-guide.md` - Conflict detection + merge procedure

## Checklist

See `checklist.md` for printable process checklist.
```

**implementations/manual/scout-guide.md**
```markdown
# Manual Scout Phase

## Step 1: Run Suitability Gate

Answer these five questions (see protocol/preconditions.md for details):

1. [ ] Can the work decompose into ≥2 agents with disjoint file ownership?
   - List files that will change: _______________
   - Assign to agents: Agent A: ___, Agent B: ___
   - Any overlaps? (If yes, NOT SUITABLE)

2. [ ] Are there investigation-first blockers?
   - Any unknown root causes? _______________
   - Any behavior that must be observed first? _______________

3. [ ] Can interfaces be defined upfront?
   - List cross-agent function calls: _______________
   - Can you write exact signatures now? _______________

4. [ ] Pre-implementation scan (if from audit/bug list):
   - Read source files for each item
   - Classify: TO-DO | DONE | PARTIAL
   - Adjust agent prompts for DONE items (verify + test coverage)

5. [ ] Does parallelization gain exceed overhead?
   - Build/test cycle length: ___ seconds
   - Files per agent: ___
   - Agent independence: Single wave? Multi-wave?

**Verdict:** SUITABLE | NOT SUITABLE | SUITABLE WITH CAVEATS

If NOT SUITABLE, stop. Document reasoning in brief IMPL doc.

## Step 2: Analyze Codebase

For each file that will change:
1. Read the source
2. Trace call paths and imports
3. Identify dependencies (what it needs, what needs it)
4. Note cascade candidates (files referencing changed interfaces but not changing)

Build a dependency graph on paper or in a diagramming tool.

## Step 3: Define Interface Contracts

For every function crossing agent boundaries:
- Write exact signature (language-specific, fully typed)
- Document parameters and return types
- Note any required imports

These are binding contracts. Agents implement without seeing each other's code.

## Step 4: Detect Shared Types

Scan interface contracts for types referenced by ≥2 agents:
- Structs, enums, interfaces, type aliases
- If Agent A defines and Agent B consumes, add to Scaffolds section

Scaffolds section format:
| File | Contents | Import path | Status |
|------|----------|-------------|--------|
| path/to/types.go | TypeName struct (fields) | import/path | pending |

## Step 5: Assign File Ownership

Create ownership table:
| File | Agent | Wave | Depends On |
|------|-------|------|------------|

Rules:
- No file in multiple agent rows (same wave)
- Every changing file listed
- Exclude generated files

## Step 6: Structure Waves

From dependency graph:
- Wave 1: Agents whose files have no dependencies on new work
- Wave N+1: Agents whose files depend on Wave N interfaces

Annotate each wave transition with which agent(s) unblock it.

## Step 7: Write Agent Prompts

For each agent, use 9-field template (see templates/agent-prompt-template.md):
- Fill in file ownership, interfaces, tests, verification commands
- Make prompt self-contained (agent needs only prompt + codebase)

## Step 8: Determine Verification Gates

From build system (Makefile, CI config):
- Extract build command
- Extract lint command (check mode)
- Extract test command (scoped for agents, unscoped for orchestrator)

Record as `test_command` and `lint_command` in IMPL doc header.

## Step 9: Write IMPL Doc

Use IMPL-SCHEMA.md as template. Include all sections:
1. Suitability Assessment
2. Scaffolds (if needed)
3. Known Issues
4. Dependency Graph
5. Interface Contracts
6. File Ownership
7. Wave Structure
8. Agent Prompts
9. Wave Execution Loop
10. Orchestrator Post-Merge Checklist
11. Status

Save to `docs/IMPL/IMPL-<feature-slug>.md`.

## Step 10: Human Review

Review your IMPL doc:
- [ ] Ownership is disjoint (no overlaps)
- [ ] Interface contracts are complete and exact
- [ ] Scaffold files cover all shared types
- [ ] Wave structure respects dependencies
- [ ] Verification commands match project's toolchain

This is the last checkpoint to change interfaces before worktrees are created.
```

## 4. Migration Steps

### Phase 1: Setup & Extraction (4-6 hours)

**1.1 Create Directory Structure**
```bash
mkdir -p protocol
mkdir -p implementations/claude-code/prompts/agents
mkdir -p implementations/manual
mkdir -p templates
```

**1.2 Extract Pure Protocol Content**
- Create `protocol/*.md` files from PROTOCOL.md sections
- Write `protocol/invariants.md` (clean I1-I6 definitions)
- Write `protocol/execution-rules.md` (clean E1-E14 definitions)
- Write `protocol/participants.md` (generic role descriptions)
- Write `protocol/preconditions.md` (suitability gate questions)
- Write `protocol/message-formats.md` (YAML schemas)
- Write `protocol/state-machine.md` (state transitions)
- Write `protocol/merge-procedure.md` (conflict taxonomy)
- Write `protocol/compliance.md` (verification checklist)

**1.3 Create Generic Templates**
- Write `templates/IMPL-doc-template.md` with [PLACEHOLDER] markers
- Write `templates/agent-prompt-template.md` (generic 9-field)
- Write `templates/completion-report.yaml` (schema + examples)
- Write `templates/suitability-verdict.md`

**1.4 Write IMPL-SCHEMA.md**
- Document all required sections
- Provide examples for each section
- Explain status lifecycles (scaffold files, agent status)

### Phase 2: Claude Code Implementation Move (4-6 hours)

**2.1 Create Implementation Directory**
```bash
mkdir -p implementations/claude-code/{prompts/agents,hooks,examples,docs}
```

**2.2 Move Files (with git mv for history)**
```bash
# Prompts
git mv prompts/saw-skill.md implementations/claude-code/prompts/
git mv prompts/saw-merge.md implementations/claude-code/prompts/
git mv prompts/saw-worktree.md implementations/claude-code/prompts/
git mv prompts/saw-bootstrap.md implementations/claude-code/prompts/
git mv prompts/scout.md implementations/claude-code/prompts/
git mv prompts/scaffold-agent.md implementations/claude-code/prompts/
git mv prompts/agent-template.md implementations/claude-code/prompts/
git mv prompts/agents/*.md implementations/claude-code/prompts/agents/

# Hooks
git mv hooks/pre-commit-guard.sh implementations/claude-code/hooks/

# Examples
git mv examples/*.md implementations/claude-code/examples/

# Docs (move some, not all)
git mv docs/QUICKSTART.md implementations/claude-code/QUICKSTART.md
```

**2.3 Update Internal References**
- Update `saw-skill.md` to reference new prompt paths
- Update `saw-merge.md` to reference new hook path
- Update `agent-template.md` cross-references

**2.4 Create Claude Code Documentation**
- Write `implementations/claude-code/README.md` (installation, usage)
- Write `implementations/claude-code/docs/permissions.md` (allow list details)
- Write `implementations/claude-code/docs/agent-architecture.md` (custom types)
- Write `implementations/claude-code/docs/troubleshooting.md`

### Phase 3: Manual Implementation Guide (3-4 hours)

**3.1 Write Manual Guides**
- Write `implementations/manual/README.md` (overview)
- Write `implementations/manual/scout-guide.md` (step-by-step)
- Write `implementations/manual/wave-guide.md` (worktree setup)
- Write `implementations/manual/merge-guide.md` (merge procedure)
- Write `implementations/manual/checklist.md` (printable)

**3.2 Test Manual Process**
- Walk through manual scout guide on a test feature
- Verify IMPL doc produced matches schema
- Validate checklist completeness

### Phase 4: Root Documentation Rewrite (4-6 hours)

**4.1 Rewrite README.md**

Current structure:
- Why, How, Quick Start, Usage with Claude Code, When to Use, Protocol Spec, Prompts, License

New structure:
```markdown
# Scout-and-Wave

A protocol for safely parallelizing human-guided agentic workflows.

## What is Scout-and-Wave?

Scout-and-Wave (SAW) is a coordination protocol that enables parallel AI agents
to work on the same codebase without conflicts. It defines:
- Participant roles (Orchestrator, Scout, Scaffold Agent, Wave Agents)
- Preconditions (suitability gate)
- Invariants (I1-I6: correctness guarantees)
- State machine (wave lifecycle)
- Message formats (IMPL doc, completion reports)

SAW is **implementation-agnostic**. This repository contains:
- The protocol specification (`protocol/`)
- A reference implementation for Claude Code (`implementations/claude-code/`)
- A guide for manual orchestration (`implementations/manual/`)

## Quick Start

### Using Claude Code (AI-Orchestrated)

Install the skill:
```bash
git clone https://github.com/blackwell-systems/scout-and-wave.git ~/code/scout-and-wave
cp ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/commands/saw.md
```

Run on any project:
```
/saw scout "add caching layer"
/saw wave
```

See [Claude Code implementation guide](implementations/claude-code/README.md) for details.

### Manual Orchestration (Human-Driven)

Use SAW without AI orchestration:
1. Run scout phase by hand (analyze codebase, write IMPL doc)
2. Create worktrees manually
3. Implement in parallel branches
4. Follow merge procedure checklist

See [manual orchestration guide](implementations/manual/README.md) for step-by-step.

## Why Use SAW?

Parallel AI agents produce merge conflicts and contradictory implementations.
SAW prevents this through:
- **Disjoint file ownership (I1):** No two agents touch the same file
- **Interface contracts (I2):** Shared types defined before parallel work
- **Worktree isolation:** Each agent works in separate git worktree
- **Verification gates:** Build+test after each wave catches integration issues

## Documentation

- **[Protocol Specification](protocol/README.md)** - Implementation-agnostic rules
- **[IMPL Doc Schema](IMPL-SCHEMA.md)** - Coordination artifact format
- **[Claude Code Implementation](implementations/claude-code/README.md)** - Reference
- **[Manual Orchestration](implementations/manual/README.md)** - Human-driven guide
- **[Generic Templates](templates/)** - Fillable templates for any implementation

## Implementations

| Implementation | Orchestration | Status | Use When |
|---------------|---------------|--------|----------|
| [Claude Code](implementations/claude-code/) | AI (Claude Code skill) | Stable (v0.6.x) | You have Claude Code and want hands-free execution |
| [Manual](implementations/manual/) | Human (checklist-driven) | Stable | Learning protocol or debugging, small waves |
| Python orchestrator | AI (custom script) | Planned | Building non-Claude automation |
| GitHub Actions | CI/CD | Planned | Automated wave execution in CI pipeline |

Want to build an implementation? See [protocol/compliance.md](protocol/compliance.md).

## Blog Posts

[Links to 4-part series]

## License

MIT
```

**4.2 Update PROTOCOL.md**
- Remove Claude Code tool references
- Replace with generic language ("file read capability", "async execution")
- Update "Conformance" section
- Point to `implementations/` for concrete examples

**4.3 Create protocol/README.md**
```markdown
# Scout-and-Wave Protocol Specification

## Intended Audience

- AI system developers building SAW implementations
- Manual orchestrators running SAW by hand
- Protocol researchers analyzing coordination patterns
- Tool developers integrating SAW into IDEs or CI systems

## Protocol Guarantees

When all preconditions hold and all invariants are maintained:
- No two agents produce conflicting changes (I1)
- Interface drift is prevented (I2)
- Integration failures surface at wave boundaries, not at the end (I3)
- The orchestrator can detect violations before merging (I4, I5)

## Core Documents

1. **[participants.md](participants.md)** - Four participant roles and capabilities
2. **[preconditions.md](preconditions.md)** - Five suitability gate questions
3. **[invariants.md](invariants.md)** - I1-I6 correctness guarantees
4. **[execution-rules.md](execution-rules.md)** - E1-E14 orchestrator behavior
5. **[state-machine.md](state-machine.md)** - Wave lifecycle transitions
6. **[message-formats.md](message-formats.md)** - IMPL doc and completion report schemas
7. **[compliance.md](compliance.md)** - How to verify conformance

## Implementation Requirements

A conforming SAW implementation MUST preserve:
- All six invariants (I1-I6) semantically
- All fourteen execution rules (E1-E14) at enforcement points
- State machine transitions (including human checkpoints)
- Message format schemas (IMPL doc structure, completion report YAML)
- Suitability gate (five questions, NOT SUITABLE as first-class outcome)

What MAY vary:
- Agent runtime primitives (tool names, launch mechanisms)
- Programming language of target projects
- UI for human checkpoints
- Storage format (markdown vs. JSON vs. database)

See [compliance.md](compliance.md) for verification checklist.
```

### Phase 5: Backward Compatibility & Testing (2-3 hours)

**5.1 Create Symlinks for Backward Compatibility**

Users who installed before refactor may have scripts referencing old paths:

```bash
# In repository root, create symlinks
ln -s implementations/claude-code/prompts/saw-skill.md prompts/saw-skill.md
ln -s implementations/claude-code/prompts/scout.md prompts/scout.md
ln -s implementations/claude-code/prompts/scaffold-agent.md prompts/scaffold-agent.md
ln -s implementations/claude-code/prompts/agent-template.md prompts/agent-template.md
ln -s implementations/claude-code/prompts/saw-merge.md prompts/saw-merge.md
ln -s implementations/claude-code/prompts/saw-worktree.md prompts/saw-worktree.md
ln -s implementations/claude-code/prompts/saw-bootstrap.md prompts/saw-bootstrap.md

# For agents directory
ln -s implementations/claude-code/prompts/agents prompts/agents
```

Add to README:
```markdown
## Upgrading from v0.6.x

If you installed before v0.7.0, prompts moved to `implementations/claude-code/prompts/`.
Symlinks provide backward compatibility, but update your install:

```bash
# Old (still works via symlinks):
cp ~/code/scout-and-wave/prompts/saw-skill.md ~/.claude/commands/saw.md

# New (recommended):
cp ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/commands/saw.md
```

**5.2 Update saw-skill.md Path Resolution**

Current skill looks for prompts at:
1. `$SAW_REPO/prompts/`
2. `~/code/scout-and-wave/prompts/`

Update to:
1. `$SAW_REPO/implementations/claude-code/prompts/`
2. `~/code/scout-and-wave/implementations/claude-code/prompts/`
3. Fallback: `$SAW_REPO/prompts/` (via symlink)

**5.3 Test on Existing Project**

Validate refactor doesn't break existing workflows:
1. Clone refactored repo to fresh location
2. Install skill using new path
3. Run `/saw scout "test feature"` on brewprune or similar
4. Verify IMPL doc generated correctly
5. Run `/saw wave` and confirm agents launch
6. Verify completion reports parse correctly
7. Test merge procedure

**5.4 Test Manual Orchestration Guide**

Walk through manual guide on a small test case:
1. Follow scout-guide.md to produce IMPL doc by hand
2. Create worktrees manually following wave-guide.md
3. Implement simple changes in parallel branches
4. Follow merge-guide.md checklist
5. Verify result matches protocol guarantees

## 5. Backward Compatibility

### 5.1 File Location Strategy

**Approach: Symlinks + Deprecation Warnings**

- Keep symlinks at old locations (`prompts/*.md` → `implementations/claude-code/prompts/*.md`)
- Add deprecation notice to README for old paths
- Update installation instructions to use new paths
- Keep symlinks for 2-3 releases (6-9 months), then remove

**Deprecation timeline:**
- v0.7.0: Introduce new structure, add symlinks, update docs
- v0.8.0: Add deprecation warnings to symlinked files
- v0.9.0: Remove symlinks, break old paths

### 5.2 Version Strategy

This is a major refactor that changes public API (file locations, import paths):

- **Current:** v0.6.2
- **Refactor:** v0.7.0 (minor bump, backward compatible via symlinks)
- **Breaking:** v1.0.0 (when symlinks removed)

Semantic versioning justification:
- v0.7.0: New features (manual guide, protocol extraction) + backward compat
- v1.0.0: Breaking changes (remove symlinks, require new paths)

### 5.3 Installation Script Updates

Provide migration script for existing users:

**scripts/migrate-to-v0.7.sh**
```bash
#!/bin/bash
# Migrate SAW installation from v0.6.x to v0.7.0

set -e

echo "Scout-and-Wave v0.7.0 Migration"
echo "================================"
echo ""

# Check if SAW is installed
if [ ! -f ~/.claude/commands/saw.md ]; then
  echo "⚠️  No existing SAW installation found at ~/.claude/commands/saw.md"
  echo "Run the standard installation instead."
  exit 1
fi

# Detect SAW_REPO location
if [ -n "$SAW_REPO" ]; then
  SAW_PATH="$SAW_REPO"
elif [ -d ~/code/scout-and-wave ]; then
  SAW_PATH=~/code/scout-and-wave
else
  echo "❌ Cannot locate SAW repository."
  echo "Set SAW_REPO environment variable or install to ~/code/scout-and-wave"
  exit 1
fi

echo "Found SAW repository at: $SAW_PATH"
echo ""

# Pull latest
echo "Pulling latest changes..."
cd "$SAW_PATH"
git pull origin main

# Update skill file
echo "Updating skill file..."
cp "$SAW_PATH/implementations/claude-code/prompts/saw-skill.md" ~/.claude/commands/saw.md
echo "✓ Skill updated"

# Update custom agent types if installed
if [ -L ~/.claude/agents/scout.md ] || [ -f ~/.claude/agents/scout.md ]; then
  echo ""
  echo "Updating custom agent types..."
  ln -sf "$SAW_PATH/implementations/claude-code/prompts/agents/scout.md" ~/.claude/agents/scout.md
  ln -sf "$SAW_PATH/implementations/claude-code/prompts/agents/scaffold-agent.md" ~/.claude/agents/scaffold-agent.md
  ln -sf "$SAW_PATH/implementations/claude-code/prompts/agents/wave-agent.md" ~/.claude/agents/wave-agent.md
  echo "✓ Agent types updated"
fi

echo ""
echo "✅ Migration complete!"
echo ""
echo "Changes in v0.7.0:"
echo "  - Prompts moved to implementations/claude-code/prompts/"
echo "  - New protocol/ directory with implementation-agnostic specs"
echo "  - New manual orchestration guide in implementations/manual/"
echo ""
echo "Your existing workflows will continue to work (symlinks provide compatibility)."
echo "See README.md for new documentation structure."
```

### 5.4 Update References in Existing Projects

Users may have project-specific `.claude/settings.json` with scoped Bash permissions:

**Old format:**
```json
{
  "permissions": {
    "allow": ["Bash(docker exec brewprune-r*)"]
  }
}
```

**Still works** - no change needed. Scoped permissions reference container names, not file paths.

## 6. Benefits & Risks

### 6.1 Benefits

**Protocol Adoption:**
- **Other AI systems can implement SAW** - Python orchestrators, OpenAI Agents, LangChain, etc.
- **Manual orchestration becomes feasible** - Humans can run SAW with checklist alone
- **Protocol improvements are implementation-agnostic** - Fixing I1 violation handling doesn't require updating every tool reference

**Maintainability:**
- **Clear separation** - Protocol changes don't touch Claude Code implementation
- **Independent evolution** - Protocol can stabilize (v1.0) while implementation adds features
- **Easier testing** - Protocol compliance checklist works for any implementation

**Documentation Quality:**
- **Better onboarding** - New users can understand protocol without Claude Code knowledge
- **Reference manual** - Protocol docs serve as formal specification
- **Implementation guides** - Each implementation has focused documentation

**Community Growth:**
- **Academic use** - Researchers can cite protocol without implementation coupling
- **Tool integration** - IDEs, CI systems can implement SAW natively
- **Polyglot support** - Python SAW, JavaScript SAW, etc. all conform to same protocol

### 6.2 Risks

**Documentation Drift:**
- **Risk:** Protocol docs and implementation docs diverge over time
- **Mitigation:** Automated compliance tests (check Claude Code impl against protocol/compliance.md)
- **Mitigation:** Quarterly audit of protocol vs. implementation alignment
- **Severity:** Medium (fixable with process)

**Increased Maintenance Burden:**
- **Risk:** Two documentation sets to maintain (protocol + Claude Code)
- **Mitigation:** Protocol stabilizes faster than implementation (target v1.0 in 3-6 months)
- **Mitigation:** Once protocol is v1.0, changes are rare and require RFC process
- **Severity:** Medium (manageable with discipline)

**Over-Engineering:**
- **Risk:** No one builds alternative implementations, effort wasted
- **Mitigation:** Manual orchestration guide provides immediate value (learning, debugging)
- **Mitigation:** Protocol extraction itself improves Claude Code docs (clearer invariants)
- **Severity:** Low (even without alternative impls, refactor has value)

**Breaking Changes for Existing Users:**
- **Risk:** File moves break user scripts, symlinks don't cover all cases
- **Mitigation:** Symlinks at old locations provide 6-9 month compatibility window
- **Mitigation:** Migration script automates update for common cases
- **Mitigation:** Deprecation warnings in v0.8.0 before breaking in v1.0.0
- **Severity:** Medium (mitigated with versioning strategy)

**Confusion About Which Docs to Read:**
- **Risk:** Users don't know whether to read protocol/ or implementations/claude-code/
- **Mitigation:** Clear signposting in README ("If using Claude Code, start here...")
- **Mitigation:** Each directory has README.md explaining its audience
- **Severity:** Low (good navigation fixes this)

### 6.3 Risk Mitigation Summary

| Risk | Likelihood | Impact | Mitigation Strategy | Residual Risk |
|------|------------|--------|---------------------|---------------|
| Documentation drift | Medium | High | Automated compliance tests, quarterly audits | Low |
| Maintenance burden | High | Medium | Protocol stabilization (v1.0), RFC process | Medium |
| Over-engineering | Low | Low | Manual guide provides immediate value | Low |
| Breaking changes | Medium | Medium | Symlinks, migration script, versioning | Low |
| Confusion | Medium | Low | Clear navigation, per-directory READMEs | Low |

## 7. Success Criteria

### 7.1 Protocol Layer Success

**Someone could build a Python orchestrator from protocol docs alone:**

Test by asking a developer unfamiliar with Claude Code to:
1. Read `protocol/README.md`
2. Implement orchestrator that:
   - Parses IMPL doc
   - Launches Python subprocesses as "agents"
   - Executes merge procedure
   - Validates compliance checklist

**Success:** Orchestrator passes compliance tests without reading Claude Code implementation.

### 7.2 Implementation Layer Success

**Claude Code implementation remains fully functional:**

Test by:
1. Fresh clone of refactored repo
2. Follow `implementations/claude-code/README.md` install instructions
3. Run scout + wave on existing test project (e.g., brewprune)
4. Verify all agent launches succeed
5. Verify merge procedure completes
6. Verify post-merge verification passes

**Success:** All existing workflows work without modification (except install path).

### 7.3 Manual Orchestration Success

**A human could run SAW with checklist alone:**

Test by:
1. Give `implementations/manual/` guide to developer unfamiliar with SAW
2. Ask them to run scout phase on small test feature
3. Verify IMPL doc produced matches schema
4. Ask them to run wave execution following checklist
5. Verify merge completes correctly

**Success:** Human completes scout + wave + merge without AI assistance, produces valid result.

### 7.4 Documentation Quality Success

**All examples work in both contexts:**

Test by:
1. Verify `examples/` IMPL docs reference protocol concepts (not Claude tools)
2. Check all links in protocol/ resolve correctly
3. Run markdown linter on all docs
4. Verify no broken internal references

**Success:** Zero broken links, all examples parseable by generic tooling.

### 7.5 Compliance Checklist Success

**Compliance checklist passes for Claude Code impl:**

Test by:
1. Walk through `protocol/compliance.md` with Claude Code implementation
2. Verify each invariant (I1-I6) is enforced
3. Verify each execution rule (E1-E14) fires at correct point
4. Verify message formats match schemas

**Success:** All checklist items pass, no protocol violations detected.

### 7.6 Backward Compatibility Success

**Existing users can upgrade without breaking:**

Test by:
1. Simulate v0.6.2 installation (old paths)
2. Pull v0.7.0 with symlinks
3. Run existing workflow without changes
4. Verify symlinks resolve correctly
5. Run migration script
6. Verify new paths work

**Success:** Both old and new paths work, migration is smooth.

## 8. Timeline Estimate

### Phase 1: Setup & Extraction (4-6 hours)
- Create directory structure: 30 min
- Extract protocol docs: 2-3 hours
- Create generic templates: 1-1.5 hours
- Write IMPL-SCHEMA.md: 1 hour

### Phase 2: Claude Code Move (4-6 hours)
- Move files with git history: 1 hour
- Update internal references: 1-2 hours
- Create Claude Code docs: 2-3 hours

### Phase 3: Manual Guide (3-4 hours)
- Write scout guide: 1-1.5 hours
- Write wave guide: 1 hour
- Write merge guide: 1 hour
- Create checklist: 30 min

### Phase 4: Root Docs Rewrite (4-6 hours)
- Rewrite README.md: 2 hours
- Update PROTOCOL.md: 1-2 hours
- Create protocol/README.md: 1 hour
- Update cross-references: 1 hour

### Phase 5: Compatibility & Testing (2-3 hours)
- Create symlinks: 15 min
- Update path resolution in skill: 30 min
- Test Claude Code workflow: 1 hour
- Test manual guide: 1 hour

**Total: 17-25 hours**

**Suggested schedule:**
- **Day 1 (8h):** Phase 1 + Phase 2
- **Day 2 (8h):** Phase 3 + Phase 4
- **Day 3 (4h):** Phase 5 + buffer for issues

## 9. Open Questions & Decisions Needed

### 9.1 Repository Structure

**Q1: Should protocol/ be a separate repository?**

**Option A:** Keep monorepo (current plan)
- ✅ Simpler for users (one clone)
- ✅ Easier to keep protocol and reference impl in sync
- ❌ Protocol changes coupled to implementation releases

**Option B:** Split into scout-and-wave-protocol + scout-and-wave-claude
- ✅ Protocol can stabilize independently
- ✅ Clearer separation
- ❌ Two repos to maintain
- ❌ Users must clone both for Claude Code usage

**Recommendation:** Keep monorepo (Option A) until protocol reaches v1.0, then consider split.

### 9.2 IMPL Doc Storage Format

**Q2: Should we define a JSON schema for IMPL docs?**

Current: IMPL docs are markdown with YAML blocks

**Option A:** Markdown only (current)
- ✅ Human-readable
- ✅ Diffable in git
- ❌ Harder to parse programmatically

**Option B:** JSON schema + markdown renderer
- ✅ Easier for alternative implementations to parse
- ✅ Validation possible
- ❌ Breaks existing IMPL docs
- ❌ Less human-readable in raw form

**Option C:** Dual format (markdown + JSON export)
- ✅ Best of both worlds
- ❌ Two formats to maintain in sync

**Recommendation:** Option A (markdown) for v0.7.0, add JSON schema as optional in v0.8.0.

### 9.3 Compliance Testing

**Q3: Should we build automated compliance tests?**

**Option A:** Manual checklist only (protocol/compliance.md)
- ✅ Simple, no tooling needed
- ❌ Relies on human discipline

**Option B:** Automated test harness
- ✅ Catches protocol violations automatically
- ✅ Enables CI checks
- ❌ Requires building test tooling

**Recommendation:** Manual checklist for v0.7.0, explore automated testing in v0.8.0 once protocol stabilizes.

### 9.4 Version Header Format

**Q4: Should protocol mandate version header format?**

Current PROTOCOL.md says:
> "Each prompt file must carry a machine-readable version identifier on line 1 in the format `<name> v<major>.<minor>.<patch>`, using whatever comment syntax the implementation supports"

**Option A:** Keep flexible (current)
- ✅ Allows `<!-- -->` for markdown, `#` for Python, `//` for JavaScript
- ❌ Harder to parse across implementations

**Option B:** Mandate specific format
- ✅ Universal parsing
- ❌ Requires preprocessor for non-markdown implementations

**Recommendation:** Keep flexible (Option A) with examples for each language in protocol/message-formats.md.

### 9.5 Orchestrator Interface

**Q5: Should we define a standard orchestrator API?**

Currently: Each implementation chooses its own interface (Claude Code uses `/saw` skill commands)

**Option A:** No standard API (current)
- ✅ Flexibility for each implementation
- ❌ Harder to switch between implementations

**Option B:** Define standard CLI interface
- ✅ Portability (users learn once)
- ✅ Tooling can target standard interface
- ❌ May not fit all runtimes (web UIs, IDEs)

**Recommendation:** Option A for now, revisit when 2+ implementations exist.

### 9.6 Example Projects

**Q6: Should we create a "SAW-compatible" example project?**

**Option A:** Use existing examples (brewprune)
- ✅ Real-world complexity
- ❌ Assumes Go knowledge

**Option B:** Create minimal "hello-saw" project
- ✅ Easier to understand protocol
- ✅ Translatable to any language
- ❌ Not realistic

**Recommendation:** Both. Add `examples/hello-saw/` (minimal) and keep brewprune (realistic).

## 10. Next Steps

### 10.1 Immediate Actions (Before Starting Refactor)

1. **Create tracking issue in scout-and-wave repo:**
   - Title: "Refactor: Extract protocol from Claude Code implementation"
   - Link to this document
   - Create sub-tasks for each phase

2. **Announce intent in CHANGELOG.md:**
   - Add v0.7.0 (unreleased) section
   - Note: "Breaking: File locations moving (symlinks provided)"
   - Note: "Added: Protocol extraction, manual orchestration guide"

3. **Create feature branch:**
   ```bash
   git checkout -b refactor/protocol-extraction
   ```

4. **Decision on open questions:**
   - Review section 9 and make calls on Q1-Q6
   - Document decisions in tracking issue

### 10.2 During Refactor

1. **Commit granularly:**
   - Phase 1 in separate commits per protocol doc
   - Phase 2 as single commit (file moves preserve history)
   - Phase 3 as single commit per guide
   - Phase 4 as separate commits per root doc

2. **Test continuously:**
   - After Phase 2, test Claude Code workflow
   - After Phase 3, test manual guide
   - After Phase 5, run full compatibility tests

3. **Update CHANGELOG.md as you go:**
   - Add entries for each major change
   - Note breaking changes explicitly
   - Link to migration guide

### 10.3 After Refactor (PR Review)

1. **Self-review checklist:**
   - [ ] All symlinks created and tested
   - [ ] All internal links resolve
   - [ ] Claude Code workflow tested end-to-end
   - [ ] Manual guide walkthrough completed
   - [ ] Migration script tested
   - [ ] CHANGELOG.md updated
   - [ ] README.md rewritten

2. **Request review:**
   - Tag maintainers
   - Provide testing instructions
   - Link to this plan document

3. **After merge:**
   - Tag release v0.7.0
   - Announce in blog post or social media
   - Update installation instructions in docs

### 10.4 Post-Release Monitoring (v0.7.0 → v0.8.0)

1. **Track adoption:**
   - Monitor issues related to new structure
   - Watch for confusion about which docs to read
   - Collect feedback on manual guide usability

2. **Plan for v0.8.0:**
   - Add deprecation warnings to symlinked files
   - Consider JSON schema for IMPL docs (Q2)
   - Explore automated compliance testing (Q3)

3. **Plan for v1.0.0 (breaking):**
   - Remove symlinks (breaking change)
   - Finalize protocol (stable spec)
   - Consider repository split (Q1)

## Appendix A: Example Protocol Document Excerpt

**protocol/invariants.md** (excerpt showing target style):

```markdown
# I1: Disjoint File Ownership

## Definition

No two agents in the same wave own the same file.

## Why This Matters

This is the mechanism that makes parallel execution safe. Worktree isolation prevents execution-time interference (race conditions on build caches); disjoint ownership prevents merge conflicts.

## Enforcement Points

1. **Pre-launch:** Orchestrator scans IMPL doc ownership table (E3)
2. **Post-execution:** Orchestrator cross-references completion report `files_changed` lists
3. **Merge-time:** Conflict prediction step (merge procedure Step 2)

## Violation Examples

### Example 1: Overlapping Ownership

```markdown
# IMPL doc ownership table:
| File | Agent | Wave |
|------|-------|------|
| src/cache.go | A | 1 |
| src/cache.go | B | 1 |
```

**Violation:** cache.go appears in both Agent A and Agent B ownership lists.

**Detection:** Orchestrator pre-launch scan flags overlap.

**Resolution:** Correct IMPL doc before launching wave. Options:
- Split cache.go into cache_types.go (Agent A) and cache_impl.go (Agent B)
- Assign cache.go to single agent, have other agent call its interface
- Make cache.go orchestrator-owned if changes are append-only

### Example 2: Undeclared Modification

```yaml
# Agent A completion report:
files_changed:
  - src/cache.go
  - src/client.go  # ⚠️ Not in Agent A ownership table

# IMPL doc ownership table:
| File | Agent | Wave |
|------|-------|------|
| src/cache.go | A | 1 |
| src/client.go | B | 1 |
```

**Violation:** Agent A modified src/client.go, which belongs to Agent B.

**Detection:** Merge procedure Step 1.75 (file ownership verification) flags mismatch.

**Resolution:**
- If change is justified (API-wide atomic change), accept and document
- If not justified, re-run Agent A with stricter ownership enforcement

## Non-Violations

### Orchestrator-Owned Append-Only Files

```markdown
# IMPL doc:
| File | Agent | Wave | Notes |
|------|-------|------|-------|
| src/registry.go | Orchestrator | (post-merge) | Append-only, agents specify additions in completion reports |
```

**Not a violation:** Multiple agents can specify additions to orchestrator-owned files.

**Mechanism:** Agents do not modify the file directly. They list additions in completion reports. Orchestrator applies all additions post-merge in a single commit.

## Implementation Requirements

All conforming implementations MUST:
1. Check ownership table for overlaps before launching wave
2. Cross-reference completion reports before merging
3. Halt on violation (no partial merges)
4. Provide clear error message identifying which agents and files are in conflict
```

## Appendix B: Example Generic Template

**templates/agent-prompt-template.md** (excerpt showing generic version):

```markdown
# Wave {N} Agent {LETTER}: {DESCRIPTION}

You are Wave {N} Agent {LETTER}. {ONE_SENTENCE_SUMMARY}

## 0. Isolation Verification (RUN FIRST)

⚠️ **MANDATORY PRE-FLIGHT CHECK**

Before modifying any files, verify you are working in the correct isolated environment.

**For git worktree implementations:**

```bash
# Check working directory
pwd
# Expected: {REPO_ROOT}/.claude/worktrees/wave{N}-agent-{LETTER}

# Check git branch
git branch --show-current
# Expected: wave{N}-agent-{LETTER}
```

**For container implementations:**

```bash
# Check container name
hostname
# Expected: wave{N}-agent-{LETTER}

# Check volume mount
ls -la /workspace
# Expected: isolated workspace for this agent
```

**For other implementations:**

[Define appropriate isolation verification for your runtime]

**If verification fails:**
- Write error to completion report
- Exit immediately
- Do NOT modify files

## 1. File Ownership

**I1: Disjoint File Ownership** - No two agents in the same wave own the same file.

You own these files:
{LIST_OF_FILES}

Do not modify files outside this list except as justified under "Exception: Justified API-wide changes".

## 2. Interfaces You Must Implement

Exact signatures you are responsible for delivering:

{INTERFACE_SIGNATURES}

## 3. Interfaces You May Call

Signatures from prior waves or existing code:

{CALLABLE_SIGNATURES}

## 4. What to Implement

{FUNCTIONAL_DESCRIPTION}

## 5. Tests to Write

{NUMBERED_TEST_LIST}

## 6. Verification Gate

Run these commands. All must pass before reporting completion.

{BUILD_COMMAND}
{LINT_COMMAND}
{TEST_COMMAND}

## 7. Constraints

{CONSTRAINT_LIST}

## 8. Report

Before reporting, commit your changes:

```bash
git add {YOUR_FILES}
git commit -m "wave{N}-agent-{LETTER}: {short description}"
```

Then write structured completion report to IMPL doc:

```yaml
### Agent {LETTER} - Completion Report
status: complete | partial | blocked
worktree: {WORKTREE_PATH}
commit: {SHA_OR_UNCOMMITTED}
files_changed: {LIST}
files_created: {LIST}
interface_deviations: {LIST_OR_EMPTY}
out_of_scope_deps: {LIST_OR_EMPTY}
tests_added: {LIST}
verification: PASS | FAIL ({command} - {count})
```

Free-form notes follow structured block.
```

---

**End of Refactor Plan**

This document provides a complete roadmap for extracting the Scout-and-Wave protocol into an implementation-agnostic specification layer while preserving the Claude Code reference implementation and maintaining backward compatibility. Estimated total effort: 17-25 hours across 5 phases.
