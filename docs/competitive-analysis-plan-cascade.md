# Competitive Analysis: Scout-and-Wave vs Plan-Cascade

**Version**: 1.0
**Date**: 2026-03-28
**Compared Versions**: Scout-and-Wave v0.73.0, Plan-Cascade v4.4.0

---

## Executive Summary

Both Scout-and-Wave (SAW) and Plan-Cascade solve parallel agent coordination in software development, but with fundamentally different philosophies and architectural choices:

**Scout-and-Wave** is a protocol-first system with strict invariants enforced at the tool boundary. It treats parallel agent work as a distributed systems problem requiring structural guarantees: disjoint file ownership (I1), interface contracts before implementation (I2), and wave sequencing (I3). The protocol is language-agnostic with a production-grade Go SDK, hook-based enforcement in Claude Code, and a real-time web dashboard. SAW optimizes for **correctness and determinism** — conflicts are impossible by construction, not probabilistically avoided.

**Plan-Cascade** is a pragmatic orchestration framework focused on developer experience and rapid iteration. It decomposes features into PRDs with dependency-resolved story batches, supports multi-agent collaboration with fallback chains, and emphasizes quality gates (typecheck, test, lint) with automatic project detection. Built in Python with a Rust desktop app in development, Plan-Cascade excels at **flexibility and rapid prototyping** — easy to extend, quick to experiment with.

**Use Case Fit:**
- **Choose SAW** when correctness guarantees are critical (production codebases, complex refactors, team workflows requiring reproducible outcomes)
- **Choose Plan-Cascade** when rapid iteration and experimentation matter more (prototyping, solo developers, exploratory development)

**Key Insight:** These systems are complementary, not competing. SAW prioritizes correctness through structural enforcement; Plan-Cascade prioritizes flexibility through intelligent orchestration. The best features of each inform improvements to the other.

---

## 1. Architecture Comparison

### 1.1 Core Philosophy

| Aspect | Scout-and-Wave | Plan-Cascade |
|--------|----------------|--------------|
| **Design Philosophy** | Protocol-first, distributed systems approach | Framework-first, orchestration approach |
| **Correctness Model** | Structural guarantees (invariants I1-I6) | Best-effort coordination + quality gates |
| **Conflict Prevention** | Impossible by construction (disjoint ownership) | Detected at merge time |
| **Planning Artifact** | IMPL manifest (YAML, execution artifact) | PRD (JSON, planning artifact) |
| **State Authority** | IMPL doc is source of truth (I4) | Multiple state files (prd.json, .agent-status.json, progress.txt) |
| **Execution Model** | Wave-based with sequencing (I3) | Batch-based with dependencies |

### 1.2 Repository Structure

**Scout-and-Wave** (3 repos, ~135K LOC Go + protocol docs):
```
scout-and-wave/          # Protocol specification (language-agnostic)
├── protocol/            # Invariants I1-I6, execution rules E1-E45
├── implementations/     # Claude Code skill + hooks
└── docs/                # Architecture, proposals, onboarding

scout-and-wave-go/       # Go SDK + CLI engine (~135K LOC)
├── pkg/engine/          # Core orchestration engine
├── pkg/protocol/        # IMPL validation, serialization
├── pkg/agent/           # 4 LLM backends (Anthropic, Bedrock, OpenAI, CLI)
├── pkg/worktree/        # Git worktree management
├── pkg/journal/         # Tool execution journaling (E23A)
├── pkg/collision/       # Type collision detection (E41)
└── cmd/sawtools/        # 71+ CLI commands

scout-and-wave-web/      # Web application (Go + React)
├── pkg/api/             # HTTP/SSE API server
├── web/                 # React dashboard (70+ components)
└── cmd/saw/             # Embedded binary
```

**Plan-Cascade** (1 repo, ~50K LOC Python + Rust desktop):
```
plan-cascade/
├── src/plan_cascade/    # Python core (~50K LOC)
│   ├── core/            # Orchestration (PRD gen, iteration loop, quality gates)
│   ├── backends/        # Agent abstraction (ClaudeCode, Builtin)
│   ├── llm/             # 7 LLM providers
│   ├── state/           # State management, path resolution
│   └── tools/           # ReAct tools (file, search, shell)
├── commands/            # Claude Code plugin commands
├── skills/              # Plugin skills (hybrid-ralph, mega-plan)
├── external-skills/     # Framework skills (React, Vue, Rust)
├── desktop/             # Tauri desktop app (Rust + React, 115 commands)
└── mcp_server/          # MCP server implementation
```

**Key Difference:** SAW separates protocol (language-agnostic spec) from implementation (Go SDK). Plan-Cascade is implementation-first with the protocol embedded in the code.

### 1.3 Implementation Languages

| Component | Scout-and-Wave | Plan-Cascade |
|-----------|----------------|--------------|
| **Core Engine** | Go (compiled, 34 packages) | Python 3.10+ (interpreted) |
| **CLI Binary** | `sawtools` (Go, statically linked) | `plan-cascade` (Python entry point) |
| **Web Application** | Go backend + React frontend | Rust (Tauri 2.0) + React frontend |
| **Distribution** | Pre-built binaries (macOS/Linux/Windows) | pip package + desktop installer |
| **Performance** | Native Go (fast, low memory) | Python (slower, higher memory) |
| **Extensibility** | Importable Go module | Python package with plugin system |

**Insight:** SAW's Go implementation prioritizes production stability and performance. Plan-Cascade's Python core prioritizes rapid iteration and accessibility for contributors.

---

## 2. Plan-Cascade Strengths (What SAW Can Learn)

### 2.1 Three-Tier Cascading Architecture

**What it is:** Plan-Cascade decomposes work at three levels:
- **Mega Plan** (project-level): Manages multiple features in parallel batches
- **Hybrid Ralph** (feature-level): Auto-generates PRD with user stories
- **Story Execution** (task-level): Parallel story execution with multi-agent support

**Why it's better than SAW:**
- SAW's two-layer model (IMPL + PROGRAM) is less granular
- Plan-Cascade's intermediate "feature" layer provides natural decomposition
- Mega Plan's batch execution allows partial completion (Batch 1 merges, Batch 2 continues)

**Borrowable for SAW:**
```
Current SAW: Feature → Waves (agents in parallel)
Proposed:    Feature → Waves → Tasks (sub-agent decomposition within wave)

Example:
Wave 1 Agent A (implement auth module)
  ├── Task 1: Database schema (sub-agent or same agent, sequential)
  ├── Task 2: API routes (depends on Task 1)
  └── Task 3: Unit tests (depends on Task 2)
```

**Implementation guidance:**
1. Add `tasks:` section to agent briefs in IMPL manifest
2. Scout can decompose large agent responsibilities into sequential sub-tasks
3. Each task gets its own tool journal entry for granular context recovery
4. E23A (tool journaling) naturally extends to task-level checkpoints

**Status:** Not planned. SAW prioritizes horizontal parallelism (multiple agents, same wave) over vertical decomposition (sub-tasks within agent). Could be explored post-v1.0 if users request finer-grained checkpointing.

### 2.2 Spec Interview Mode (Shift-Left Planning)

**What it is:** Optional planning-time interview that runs BEFORE final PRD generation. Produces `spec.json` (structured requirements) and `spec.md` (rendered spec) via 6-phase structured requirements gathering.

**Why it's better than SAW:**
- SAW's Scout directly produces IMPL docs with no intermediate requirements gathering
- Plan-Cascade's interview mode explicitly captures user intent before decomposition
- Resumable interview state (`.state/spec-interview.json`) allows iterative refinement
- Compiled PRD inherits `flow_config`, `tdd_config`, `execution_config` from spec

**Borrowable for SAW:**
```
Current SAW workflow:
User feature request → Scout → IMPL doc → Review → Execute

Proposed workflow:
User feature request → Interview Agent → Requirements Doc → Scout → IMPL doc → Review → Execute

Interview phases:
1. Feature understanding
2. Scope definition
3. Acceptance criteria
4. Dependencies
5. Risks
6. Verification strategy
```

**Implementation guidance:**
1. New `sawtools interview` command (already exists! E39)
2. Output: `REQUIREMENTS.md` in project root
3. Scout prompt updated to consume REQUIREMENTS.md when present
4. Interview state stored in `.saw-state/interview.json` for resumability
5. `/saw interview` subcommand in Claude Code skill

**Status:** E39 (Interview Mode) is already implemented in v0.58.0+. But it's underutilized — no integration with web app, no progressive disclosure of interview phases. Plan-Cascade's execution here (6 explicit phases, resumable state, clear progression) is superior and worth mirroring.

### 2.3 Quality Gate Architecture (Three-Phase Execution)

**What it is:** Quality gates execute in three phases with different parallelization strategies:
- **PRE_VALIDATION** (sequential): FORMAT gate auto-formats code
- **VALIDATION** (parallel): TYPECHECK, TEST, LINT run simultaneously
- **POST_VALIDATION** (parallel): CODE_REVIEW, IMPLEMENTATION_VERIFY

**Why it's better than SAW:**
- SAW's gates run sequentially (E21: run-gates executes gates in order)
- Plan-Cascade parallelizes independent gates (typecheck + test + lint in parallel)
- Format gate runs FIRST and auto-fixes issues before validation
- Code review runs AFTER validation (no point reviewing broken code)

**Borrowable for SAW:**
```yaml
# IMPL manifest enhancement
quality_gates:
  - name: format
    phase: PRE_VALIDATION
    command: ["gofmt", "-w", "."]
    auto_fix: true
  - name: typecheck
    phase: VALIDATION
    command: ["go", "vet", "./..."]
    parallel_group: "validation"
  - name: test
    phase: VALIDATION
    command: ["go", "test", "./..."]
    parallel_group: "validation"
  - name: code_review
    phase: POST_VALIDATION
    model: "claude-haiku-3-5"
    parallel_group: "post"
```

**Implementation guidance:**
1. Add `phase` and `parallel_group` fields to gate schema in `pkg/protocol/gates.go`
2. Update `pkg/engine/gates.go` to group gates by phase
3. Execute phases sequentially, gates within phase in parallel (goroutines)
4. Add `auto_fix: true` option for gates that can self-correct (format, lint --fix)
5. Exit early if PRE_VALIDATION fails (no point running tests on unformatted code)

**Status:** Not planned. E21 execution order is currently fixed. Parallelization would improve speed but adds complexity to error reporting (which gate failed first?). Worth considering for v0.80+.

### 2.4 External Framework Skills (Auto-Detection + Injection)

**What it is:** Plan-Cascade auto-detects project framework (React, Vue, Rust) and injects best practices from Git submodules:
- React/Next.js: detected via `package.json` → injects `react-best-practices`, `web-design-guidelines`
- Vue/Nuxt: detected via `package.json` → injects `vue-best-practices`, `vue-router-best-practices`
- Rust: detected via `Cargo.toml` → injects `rust-coding-guidelines`, `rust-ownership`

**Why it's better than SAW:**
- SAW's skills are static (bundled in `implementations/claude-code/prompts/`)
- Plan-Cascade's skills are modular (Git submodules, three-tier priority system)
- Skills load on-demand based on project context (React skills don't load in Rust projects)

**Three-tier priority system:**
| Tier | Priority Range | Source | Description |
|------|----------------|--------|-------------|
| Builtin | 1-50 | `builtin-skills/` | Python, Go, Java, TypeScript best practices |
| External | 51-100 | `external-skills/` | Framework skills from Git submodules |
| User | 101-200 | `.plan-cascade/skills.json` | Custom skills from local paths or URLs |

**Borrowable for SAW:**
```bash
# New directory structure
scout-and-wave/
└── implementations/
    └── claude-code/
        └── prompts/
            ├── scout.md              # Core prompt (unchanged)
            ├── wave-agent.md         # Core prompt (unchanged)
            └── skills/               # NEW: Skill library
                ├── builtin/          # Tier 1: Language skills
                │   ├── go.md
                │   ├── rust.md
                │   └── typescript.md
                ├── external/         # Tier 2: Framework skills (Git submodules)
                │   ├── react/        # From vercel-labs/agent-skills
                │   ├── vue/          # From vuejs-ai/skills
                │   └── rust/         # From actionbook/rust-skills
                └── user/             # Tier 3: User skills
                    └── .saw-skills.json  # User config

# Auto-detection logic (in Orchestrator)
if package.json contains "react":
    inject skills/external/react/react-best-practices.md
```

**Implementation guidance:**
1. New `pkg/skills` package with auto-detection logic
2. Scout/Wave agent prompts call `LoadApplicableSkills()` before launch
3. Skills injected via prompt prepending (similar to reference injection)
4. Skill priority resolves conflicts (User > External > Builtin)
5. Orchestrator caches detection results (avoid re-scanning on every agent launch)

**Status:** Not planned. SAW's progressive disclosure system (v0.73.0) already handles on-demand reference injection. Skill modularity could be added post-v1.0 as a progressive disclosure enhancement.

### 2.5 Resumability and Dashboard

**What it is:**
- **Resume Detection:** `/plan-cascade:resume` auto-detects incomplete execution (stage-state.json, .iteration-state.json, .mega-status.json) and suggests recovery actions
- **Dashboard:** `/plan-cascade:dashboard` aggregates status from multiple state files into unified view

**Why it's better than SAW:**
- SAW's `sawtools resume-detect` only reports progress percentage — no actionable suggestions
- Plan-Cascade's resume command provides specific actions ("Run /plan-cascade:approve", "Run /plan-cascade:mega-resume")
- Dashboard view shows execution status, story status, batch status, and suggested actions in one call

**Borrowable for SAW:**
```bash
# Enhanced sawtools resume-detect output
$ sawtools resume-detect
Incomplete IMPL detected: IMPL-user-auth.yaml
Progress: 60% (Wave 1 complete, Wave 2 in progress)
Status: Wave 2 Agent B failed with build errors

Suggested actions:
  1. Review build errors: sawtools diagnose-build-failure --impl IMPL-user-auth.yaml --wave 2
  2. Retry failed agent: sawtools retry --impl IMPL-user-auth.yaml --wave 2 --agent B
  3. Continue execution: /saw wave --impl IMPL-user-auth.yaml

Files to review:
  - .saw-state/wave2/agent-B/journal/context.md (agent prior work)
  - .saw-state/wave2/agent-B/completion-report.md (if exists)
```

**Implementation guidance:**
1. Enhance `pkg/resume/detector.go` to analyze failure types (build, merge conflict, incomplete)
2. Add `SuggestedActions []string` field to `IncompleteStateInfo` struct
3. Resume detector reads journal + completion reports to diagnose failure cause
4. Web app calls `resume-detect` and displays suggested actions in UI

**Status:** Partially implemented. `sawtools resume-detect` exists but is minimal. Dashboard view could be added to web app (`/api/dashboard` endpoint aggregating IMPL state, wave progress, agent status). Worth prioritizing for v0.80+.

### 2.6 Mega Plan Batch Execution Model

**What it is:** Plan-Cascade's Mega Plan executes features in sequential batches:
- Batch 1 features create worktrees from `main`, execute stories, merge back to `main`
- Batch 2 features create worktrees from UPDATED `main`, execute stories, merge back
- Each batch can contain multiple independent features executing in parallel

**Why it's better than SAW:**
- SAW's PROGRAM layer executes all tier 1 IMPLs, then all tier 2 IMPLs (tier-level parallelism)
- Plan-Cascade's batching allows partial completion — Batch 1 merges even if Batch 2 fails
- Batch execution is resumable mid-program (`.mega-status.json` tracks batch progress)

**Key insight:** SAW's tier-based model is more rigid. Plan-Cascade's batch model is more forgiving — if Feature B depends on Feature A, A completes and merges before B starts, even if they're in different batches.

**Borrowable for SAW:**
```yaml
# PROGRAM manifest enhancement
program:
  execution_strategy: batch  # NEW: "tier" (current) or "batch" (new)
  batches:
    - id: batch-1
      features:
        - user-auth
        - product-catalog
      status: complete
    - id: batch-2
      features:
        - shopping-cart
        - order-processing
      status: in_progress

# Execution logic
for batch in program.batches:
    if batch.status == "complete":
        continue

    # Create worktrees from current main
    for feature in batch.features:
        create_worktree(feature, base_branch="main")

    # Execute features in parallel
    execute_features_parallel(batch.features)

    # Merge all features in batch before advancing
    for feature in batch.features:
        merge_to_main(feature)

    batch.status = "complete"
```

**Implementation guidance:**
1. Add `execution_strategy` field to PROGRAM manifest schema
2. Tier-based execution remains default (backward compatible)
3. Batch-based execution available via `--execution-strategy=batch` flag
4. Batch status tracked in `.saw-state/program/{program-id}/batch-status.json`
5. Web app shows batch progress in Program Board

**Status:** Not planned. SAW's tier model enforces stricter dependency resolution (DAG-based coloring). Batch model is more forgiving but less predictable. Could be explored as an alternative execution mode post-v1.0.

---

## 3. Scout-and-Wave Strengths (What Plan-Cascade Should Learn)

### 3.1 Protocol-First Architecture

**What it is:** SAW separates protocol specification from implementation:
- Protocol: Language-agnostic docs defining invariants, execution rules, agent contracts
- Implementation: Go SDK, Claude Code hooks, web app — all implement the same protocol

**Why it's better than Plan-Cascade:**
- Plan-Cascade's protocol is implicit in the Python code (no standalone spec)
- SAW's protocol is portable — any language/tool can implement it
- Clear separation between "what must happen" (protocol) and "how it happens" (implementation)

**Key difference:** Protocol as documentation (Plan-Cascade) vs protocol as enforcement (SAW).

**What Plan-Cascade should adopt:**
1. Extract protocol rules into standalone markdown docs (separate from code)
2. Define invariants explicitly (e.g., "No two stories in the same batch own the same file")
3. Number execution rules (E1-E45 style) for cross-reference in code/docs

**Implementation sketch for Plan-Cascade:**
```
plan-cascade/
└── protocol/
    ├── invariants.md        # Core correctness properties
    ├── execution-rules.md   # Sequenced operations (E1-E50)
    ├── story-lifecycle.md   # State transitions
    └── quality-gates.md     # Gate specification
```

**Benefit:** Makes Plan-Cascade easier to audit, extend, and implement in other languages. A Rust rewrite (currently in progress for desktop app) would reference the protocol docs rather than reverse-engineering Python code.

### 3.2 Disjoint File Ownership (I1) with Tool-Level Enforcement

**What it is:** SAW's I1 invariant: No two agents in the same wave own the same file. Enforced at three layers:
1. **Claude Code hooks** (PreToolUse): Block Write/Edit to files agent doesn't own
2. **Git pre-commit hooks**: Catch violations at commit time
3. **SDK constraints**: Enforce ownership programmatically in CLI/daemon

**Why it's better than Plan-Cascade:**
- Plan-Cascade uses dependency resolution but allows concurrent writes to shared files
- Conflicts detected at merge time (reactive) vs blocked before write (proactive)
- No structural guarantee that stories in same batch have disjoint file ownership

**What Plan-Cascade should adopt:**
```python
# In src/plan_cascade/core/orchestrator.py

def validate_batch_ownership(batch: list[Story]) -> list[str]:
    """Validate that stories in batch have disjoint file ownership."""
    file_owners = {}
    conflicts = []

    for story in batch:
        for file_path in story.affected_files:
            if file_path in file_owners:
                conflicts.append(
                    f"File {file_path} owned by both {file_owners[file_path]} and {story.id}"
                )
            file_owners[file_path] = story.id

    return conflicts

# Call before batch execution
conflicts = validate_batch_ownership(current_batch)
if conflicts:
    raise ValueError(f"Ownership conflicts detected:\n" + "\n".join(conflicts))
```

**Enforcement options:**
1. **Planning-time validation** (easiest): Scout detects file ownership conflicts during PRD generation
2. **Execution-time validation** (safer): Orchestrator validates before launching batch
3. **Tool-level enforcement** (strongest): Hook Write/Edit tools to check ownership (requires Claude Code plugin hooks)

**Status recommendation:** Start with planning-time validation (add to PRD generation logic). Tool-level enforcement requires significant Claude Code plugin work but provides strongest guarantees.

### 3.3 Interface Contracts Before Implementation (I2)

**What it is:** SAW's I2 invariant: Interface contracts precede parallel implementation. Scaffold Agent materializes shared types as committed source files before Wave 1 launches. Interfaces freeze when worktrees are created.

**Why it's better than Plan-Cascade:**
- Plan-Cascade's stories can reference shared types but doesn't enforce pre-implementation
- Stories might hallucinate APIs (Agent A expects function signature X, Agent B implements signature Y)
- No mechanism to detect "integration gaps" until merge time

**What Plan-Cascade should adopt:**
```python
# New: Scaffold phase before story execution

class ScaffoldPhase:
    """Create shared types/interfaces before parallel execution."""

    def detect_shared_types(self, prd: PRD) -> list[SharedType]:
        """Scan stories for types referenced by 2+ stories."""
        type_refs = defaultdict(set)
        for story in prd.stories:
            for symbol in extract_symbols(story.description):
                type_refs[symbol].add(story.id)

        return [
            SharedType(name=name, referenced_by=list(stories))
            for name, stories in type_refs.items()
            if len(stories) >= 2
        ]

    def generate_scaffolds(self, shared_types: list[SharedType]) -> dict[str, str]:
        """Generate type definitions (no implementation)."""
        # AI agent generates type definitions
        # Returns {file_path: content}

    def commit_scaffolds(self, scaffolds: dict[str, str]):
        """Commit scaffolds to main branch before story execution."""
        for path, content in scaffolds.items():
            write_file(path, content)
        git_commit("Add scaffolds for shared types")
```

**Integration into Hybrid flow:**
```
Current:  PRD generation → Story execution
Proposed: PRD generation → Scaffold phase → Story execution
                          ↑
                          Detect shared types
                          Generate skeletons
                          Commit to main
```

**Status recommendation:** High value. Prevents entire class of integration failures (mismatched APIs). Scaffold agent could be a separate Task tool invocation or built into PRD generation phase.

### 3.4 Tool Journaling for Context Recovery (E23A)

**What it is:** External observer that preserves agent execution context across Claude Code's context window compaction:
- Tails Claude Code session logs (`.claude/sessions/*.jsonl`)
- Extracts tool executions (Read, Write, Edit, Bash) into structured journal
- Generates markdown context summary injected into agent prompt on resume

**Why it's better than Plan-Cascade:**
- Plan-Cascade has "Compaction-Safe Session Journal" but it's manual (requires explicit `.state/claude-session/` writes)
- SAW's journaling is automatic (external observer, no agent cooperation needed)
- Journal archives after merge with 30-day retention policy

**What Plan-Cascade should adopt:**
```python
# New: src/plan_cascade/core/tool_journal.py

class ToolJournal:
    """External observer for tool execution history."""

    def __init__(self, session_log: Path, journal_dir: Path):
        self.session_log = session_log
        self.journal_dir = journal_dir
        self.cursor_file = journal_dir / "cursor.json"

    def sync(self):
        """Tail session log and update journal."""
        last_pos = self._load_cursor()
        with open(self.session_log) as f:
            f.seek(last_pos)
            for line in f:
                entry = json.loads(line)
                if self._is_tool_call(entry):
                    self._record_tool(entry)
            self._save_cursor(f.tell())

    def generate_context(self) -> str:
        """Generate markdown summary of recent work."""
        # Read last 30 tool executions
        # Format as markdown: "You have already modified: ..."
```

**Integration:**
- Orchestrator calls `journal.sync()` every 30 seconds during story execution
- Before agent launch, call `journal.generate_context()` and prepend to prompt
- Archive journal after story completion

**Status recommendation:** High value for long-running agents (45+ min sessions). Requires access to Claude Code session logs but provides automatic context recovery. Worth implementing as optional feature (enabled via config flag).

### 3.5 Worktree Isolation for Parallel Execution

**What it is:** Each Wave agent operates in an isolated git worktree with its own branch. No shared state, no conflicts during implementation.

**Why it's better than Plan-Cascade:**
- Plan-Cascade executes stories on the same branch (potential conflicts if agents overlap)
- Merge happens after batch completes — conflicts detected late
- No clean rollback mechanism if one agent fails

**What Plan-Cascade should adopt:**
```python
# New: src/plan_cascade/backends/worktree_backend.py

class WorktreeBackend(AgentBackend):
    """Execute stories in isolated git worktrees."""

    def execute_story(self, story: Story, context: ExecutionContext):
        # Create worktree
        worktree_path = create_worktree(
            name=f"story-{story.id}",
            base_branch="main"
        )

        # Launch agent in worktree
        agent = self.create_agent(
            working_dir=worktree_path,
            constraints={"allowed_files": story.affected_files}
        )

        result = agent.run(story.task_prompt)

        # Agent commits to worktree branch
        # Orchestrator merges after all stories complete
```

**Integration with existing Hybrid Worktree:**
- Plan-Cascade already has worktree support for feature-level isolation
- Extend to story-level: each story in a batch gets its own worktree
- Merge all story worktrees after batch completes (similar to SAW's wave merge)

**Status recommendation:** Medium value. Adds complexity (worktree management overhead) but eliminates entire class of conflicts. Could be opt-in via `--use-worktrees` flag.

### 3.6 Critic Agent for Pre-Execution Review (E37)

**What it is:** Before Wave agents launch, a Critic Agent reviews each agent brief for:
- Symbol accuracy (are referenced types/functions correct?)
- Import conflicts (do planned imports collide?)
- Ownership gaps (does brief reference files agent doesn't own?)

**Why it's better than Plan-Cascade:**
- Plan-Cascade's quality gates run AFTER story execution (reactive)
- SAW's critic gate runs BEFORE execution (proactive)
- Catches planning errors before compute is wasted

**What Plan-Cascade should adopt:**
```python
# New: src/plan_cascade/core/critic_gate.py

class CriticGate:
    """Pre-execution validation of story briefs."""

    def review_story(self, story: Story, prd: PRD) -> CriticReport:
        """
        Review story brief for issues.

        Returns:
            CriticReport with pass/issues/fail verdict
        """
        prompt = f"""
        Review this story brief for issues:

        Story: {story.description}
        Affected files: {story.affected_files}
        Dependencies: {story.dependencies}

        Check for:
        1. Symbol accuracy (are referenced functions/types correct?)
        2. Import conflicts (do planned imports collide?)
        3. Ownership gaps (does brief reference files not in affected_files?)

        Output JSON: {{"verdict": "pass|issues|fail", "findings": [...]}}
        """
        # LLM call
        return CriticReport.from_json(response)

# In orchestrator before batch execution
for story in batch:
    report = critic.review_story(story, prd)
    if report.verdict == "fail":
        raise ValueError(f"Story {story.id} failed critic review: {report.findings}")
```

**Status recommendation:** High value. Prevents wasted compute on broken plans. Critic can be fast model (Haiku) since it's reviewing text, not generating code. Add as optional gate before story execution.

---

## 4. Plan-Cascade Weaknesses (Limitations)

### 4.1 No Structural Conflict Prevention

**Issue:** Plan-Cascade allows concurrent story execution on same branch with no file ownership enforcement. Conflicts detected at merge time (reactive) rather than blocked before write (proactive).

**Impact:**
- Silent failures: Story A and Story B both modify `api/routes.ts`, conflicts surface after batch completes
- Wasted compute: Both agents complete work, then merge conflicts require manual resolution or re-execution

**Example failure scenario:**
```
Batch 1:
  Story A: "Add user authentication" → modifies src/auth.ts
  Story B: "Add password reset" → modifies src/auth.ts (no conflict detected!)

Both agents complete successfully.
Merge Batch 1 → Conflict in src/auth.ts → Manual resolution required
```

**SAW's solution:** I1 (disjoint file ownership) makes this impossible — Scout assigns files to agents, hooks enforce ownership at tool boundary.

**Recommendation:** Implement planning-time ownership validation (cheapest fix). Tool-level enforcement requires hooks but provides strongest guarantee.

### 4.2 Implicit Protocol (No Language-Agnostic Spec)

**Issue:** Plan-Cascade's protocol is embedded in Python code. No standalone specification means:
- Reimplementing in another language requires reverse-engineering Python
- Protocol invariants not explicitly documented
- Hard to audit correctness (is this a bug or intended behavior?)

**Impact:**
- Desktop Rust rewrite (v5.0) had to reconstruct protocol from Python code
- Protocol drift: Rust and Python implementations may diverge over time
- No cross-language compatibility testing

**SAW's solution:** Protocol-first architecture — invariants, execution rules documented separately from implementation. Any language can implement the protocol.

**Recommendation:** Extract protocol into standalone docs (see Section 3.1). Rust and Python implementations both reference the same spec.

### 4.3 No Interface Contract Enforcement

**Issue:** Plan-Cascade doesn't enforce shared types/interfaces before story execution. Stories can reference functions/types that don't exist or have wrong signatures.

**Impact:**
- Integration failures at merge time (Agent A calls function X, Agent B never implemented it)
- Wasted compute: Stories complete successfully but don't integrate
- Manual resolution required

**Example failure scenario:**
```
Story A: "Implement OAuth login"
  → Calls authenticate_user(username, password, provider)

Story B: "Create user authentication service"
  → Implements authenticate_user(email, password)

Both stories complete. Merge fails: authenticate_user signature mismatch.
```

**SAW's solution:** I2 (interface contracts precede implementation) — Scaffold Agent materializes shared types before Wave 1, interfaces freeze at worktree creation.

**Recommendation:** Add scaffold phase before story execution (see Section 3.3). Generate type definitions for shared symbols, commit to main, freeze before batch execution.

### 4.4 Limited Resumability Context

**Issue:** Plan-Cascade's resume detection is basic — reports progress percentage and incomplete state, but doesn't analyze failure cause or suggest actions.

**Impact:**
- User must manually inspect logs to understand why execution failed
- No guidance on recovery steps
- Context loss on long-running agents (compaction erases history)

**SAW's solution:**
- Tool journaling (E23A) preserves execution history across compaction
- Resume detector analyzes failure type (build error, merge conflict, incomplete)
- Suggests specific recovery commands (`sawtools retry`, `sawtools diagnose-build-failure`)

**Recommendation:**
1. Implement tool journaling for automatic context recovery (see Section 3.4)
2. Enhance resume detector to analyze failure types and suggest actions (see Section 2.5)

### 4.5 Single Backend Limitation

**Issue:** Plan-Cascade's Python core supports 7 LLM providers (Claude, OpenAI, DeepSeek, Ollama, etc.) but story execution is single-agent — one agent executes each story from start to finish.

**Impact:**
- Can't mix models within batch (all stories use same model)
- No retry with different agent on failure
- No fallback chains (if preferred agent fails, execution stops)

**SAW's solution:**
- Multi-backend support: 4 LLM backends (Anthropic API, Bedrock, OpenAI-compatible, CLI)
- Per-role model selection (Scout, Wave, Critic can use different models)
- Fallback chains: if Agent A fails, retry with Agent B

**Recommendation:** Plan-Cascade already has multi-agent support (codex, aider, amp-code) with fallback chains in `phase_config.py`. But it's not well-integrated with the Python core. Better integration between backend abstraction and phase-based agent selection would improve reliability.

---

## 5. Scout-and-Wave Weaknesses (Limitations)

### 5.1 Heavyweight Setup (Worktree Overhead)

**Issue:** SAW's worktree-per-agent model has overhead:
- Disk space: Each worktree is a full copy of repo
- Setup time: Creating worktrees takes 1-5 seconds per agent
- Cleanup required: Worktrees must be manually removed after merge

**Impact:**
- Small features (1-2 file changes) don't benefit from worktree isolation
- Overhead dominates for quick tasks
- Worktree leakage if cleanup fails (`.git/worktrees/` grows over time)

**Plan-Cascade's advantage:** Executes stories directly on main branch (no worktree overhead). Fast for small changes.

**Recommendation:**
- Solo wave optimization (already implemented in v0.65.0): Skip worktree creation for waves with single agent
- Add `--no-worktrees` flag for small features (executes directly on branch, loses conflict protection)
- Better cleanup: `sawtools cleanup-stale` removes abandoned worktrees automatically

### 5.2 Limited Desktop Experience

**Issue:** SAW's web app (`scout-and-wave-web`) is production-grade but not a standalone desktop app:
- Requires server running (`saw serve`)
- No offline mode (needs LLM API access)
- No project management UI (must manually track projects)

**Plan-Cascade's advantage:**
- Standalone desktop app (Tauri 2.0, single executable)
- Project browser (`~/.claude/projects/`)
- Session management with visual timeline
- MCP server management built-in

**Recommendation:**
- Explore Tauri 2.0 for desktop packaging of `scout-and-wave-web`
- Add project management to web app (currently just IMPL-centric)
- Implement session tracking (currently no concept of "session" vs "IMPL")

### 5.3 No Spec Interview Mode

**Issue:** SAW's Scout directly produces IMPL docs without intermediate requirements gathering. If user doesn't know what they want, Scout's decomposition may miss requirements.

**Plan-Cascade's advantage:**
- Spec Interview mode (6-phase structured requirements gathering)
- Produces `spec.json` (structured) and `spec.md` (rendered)
- Resumable interview state (`.state/spec-interview.json`)

**Recommendation:**
- SAW's E39 (Interview Mode) exists but is underutilized
- Add interview phases (currently freeform conversation)
- Generate REQUIREMENTS.md from interview, Scout consumes it
- Web app UI for interview mode (currently CLI-only)

### 5.4 Steep Learning Curve

**Issue:** SAW's protocol-first architecture has a steep learning curve:
- 6 invariants (I1-I6) to understand
- 45+ execution rules (E1-E45) to internalize
- 71+ CLI commands to learn
- IMPL manifest format (YAML with fenced blocks)

**Plan-Cascade's advantage:**
- Simpler conceptual model (PRD → Stories → Execution)
- Fewer commands (`/plan-cascade:auto` covers 90% of use cases)
- JSON format (more familiar to developers)

**Recommendation:**
- Better onboarding: `/saw quickstart` wizard that walks through first feature
- Simplified commands: `/saw run <feature>` that bundles scout + wave + finalize
- Video tutorials showing common workflows
- IMPL doc templates (pre-filled examples)

### 5.5 No Built-In Code Review

**Issue:** SAW has code review capabilities (`pkg/codereview`) but it's not integrated into standard workflow:
- No pre-merge code review by default
- Review model not configurable per-role
- No dimensional scoring UI in web app

**Plan-Cascade's advantage:**
- Code review is standard POST_VALIDATION gate
- 5-dimension scoring (code_quality, naming_clarity, complexity, pattern_adherence, security)
- Configurable thresholds and block-on-critical
- Review results shown in dashboard

**Recommendation:**
- Add code review to E21 (quality gates) as optional gate
- Web app shows review scores in agent cards
- Configure review model in `saw.config.json` (currently hardcoded to default model)

---

## 6. Borrowable Ideas (Concrete Features SAW Should Adopt)

### 6.1 Quality Gate Parallelization (Plan-Cascade → SAW)

**Current SAW behavior:** E21 runs gates sequentially (typecheck → test → lint → custom).

**Plan-Cascade improvement:** Three-phase execution with parallelization:
- PRE_VALIDATION (sequential): FORMAT auto-fixes code
- VALIDATION (parallel): TYPECHECK + TEST + LINT run simultaneously
- POST_VALIDATION (parallel): CODE_REVIEW + IMPLEMENTATION_VERIFY

**Implementation for SAW:**
```yaml
# pkg/protocol/gates.go - Add phase and parallel_group
type GateConfig struct {
    Name          string
    Phase         GatePhase  // PRE_VALIDATION | VALIDATION | POST_VALIDATION
    ParallelGroup string     // Empty = sequential, same string = parallel
    Command       []string
    ...
}

# pkg/engine/gates.go - Execute gates in phases
func RunGates(gates []GateConfig) error {
    phases := groupByPhase(gates)

    for _, phase := range []GatePhase{PRE_VALIDATION, VALIDATION, POST_VALIDATION} {
        phaseGates := phases[phase]
        groups := groupByParallelGroup(phaseGates)

        for _, group := range groups {
            if group.sequential {
                runSequential(group.gates)
            } else {
                runParallel(group.gates)  // goroutines
            }
        }
    }
}
```

**Benefit:** Faster gate execution (typecheck + test in parallel saves time). No downside (gates are independent).

**Priority:** Medium (v0.80). Improves speed but doesn't fix correctness issues.

### 6.2 External Framework Skills (Plan-Cascade → SAW)

**Current SAW behavior:** Skills are static (bundled in `implementations/claude-code/prompts/`).

**Plan-Cascade improvement:** Auto-detected framework skills from Git submodules with three-tier priority system.

**Implementation for SAW:**
```bash
# New directory structure
scout-and-wave/implementations/claude-code/prompts/skills/
├── builtin/       # Tier 1: Language skills
│   ├── go.md
│   ├── rust.md
│   └── typescript.md
├── external/      # Tier 2: Framework skills (Git submodules)
│   ├── react/     # From vercel-labs/agent-skills
│   ├── vue/       # From vuejs-ai/skills
│   └── rust/      # From actionbook/rust-skills
└── user/          # Tier 3: User skills
    └── .saw-skills.json

# Orchestrator auto-detection (pkg/skills/)
func LoadApplicableSkills(repoPath string) []Skill {
    skills := []Skill{}

    if fileExists(path.Join(repoPath, "package.json")) {
        data := readJSON(path.Join(repoPath, "package.json"))
        if data["dependencies"]["react"] {
            skills = append(skills, LoadSkill("external/react/react-best-practices.md"))
        }
    }

    if fileExists(path.Join(repoPath, "Cargo.toml")) {
        skills = append(skills, LoadSkill("builtin/rust.md"))
    }

    return skills
}
```

**Benefit:** Context-specific best practices without bloating base prompts.

**Priority:** Low (v0.85+). Nice-to-have but not critical. Progressive disclosure system already handles on-demand reference injection.

### 6.3 Enhanced Resume Detection (Plan-Cascade → SAW)

**Current SAW behavior:** `sawtools resume-detect` reports progress percentage. No actionable guidance.

**Plan-Cascade improvement:** Resume detector analyzes failure type and suggests specific recovery actions.

**Implementation for SAW:**
```go
// pkg/resume/detector.go
type IncompleteStateInfo struct {
    IMPLPath        string
    ProgressPercent int
    Status          string
    FailureType     FailureType  // NEW: build_error | merge_conflict | incomplete | timeout
    SuggestedActions []string     // NEW: Recovery steps
    FilesToReview    []string     // NEW: Relevant files for debugging
}

func AnalyzeFailure(implPath string) FailureType {
    // Read completion reports, journal context, build logs
    if buildLogContainsErrors() {
        return FailureTypeBuildError
    }
    if gitStatusShowsConflicts() {
        return FailureTypeMergeConflict
    }
    return FailureTypeIncomplete
}

func SuggestActions(info IncompleteStateInfo) []string {
    switch info.FailureType {
    case FailureTypeBuildError:
        return []string{
            "sawtools diagnose-build-failure --impl " + info.IMPLPath,
            "sawtools retry --impl " + info.IMPLPath + " --wave " + currentWave,
        }
    case FailureTypeMergeConflict:
        return []string{
            "git status",
            "Resolve conflicts manually, then: sawtools merge-agents --impl " + info.IMPLPath,
        }
    default:
        return []string{"/saw wave --impl " + info.IMPLPath}
    }
}
```

**Benefit:** Faster recovery from failures. User knows exactly what to do next.

**Priority:** High (v0.75). Low-hanging fruit that significantly improves UX.

### 6.4 Scaffold Detection Automation (Plan-Cascade → SAW)

**Current SAW behavior:** Scout manually identifies scaffolds (human writes scaffold entries in IMPL manifest).

**Plan-Cascade improvement:** Auto-detect shared types by scanning agent briefs for symbols referenced by 2+ agents.

**Implementation for SAW:**
```go
// pkg/analyzer/scaffold_detection.go
func DetectSharedTypes(impl *protocol.IMPL) []protocol.Scaffold {
    symbolRefs := make(map[string][]string)  // symbol -> agentIDs

    for _, agent := range impl.Agents {
        symbols := extractSymbols(agent.Brief)  // Parse brief for type/function names
        for _, symbol := range symbols {
            symbolRefs[symbol] = append(symbolRefs[symbol], agent.ID)
        }
    }

    scaffolds := []protocol.Scaffold{}
    for symbol, refs := range symbolRefs {
        if len(refs) >= 2 {  // Referenced by 2+ agents
            scaffolds = append(scaffolds, protocol.Scaffold{
                Name:         symbol,
                ReferencedBy: refs,
                Status:       protocol.ScaffoldStatusPending,
            })
        }
    }

    return scaffolds
}

// Called in sawtools finalize-impl
impl.Scaffolds = append(impl.Scaffolds, DetectSharedTypes(impl)...)
```

**Benefit:** Prevents integration failures from mismatched APIs. Automates tedious manual work.

**Priority:** High (v0.75). E45 already exists but detection is manual. Automation is low-cost, high-value.

### 6.5 Dashboard Aggregator (Plan-Cascade → SAW)

**Current SAW behavior:** Web app shows IMPL-level status. No cross-IMPL aggregation.

**Plan-Cascade improvement:** Dashboard aggregates status from multiple IMPLs into unified view.

**Implementation for SAW:**
```go
// pkg/api/dashboard.go
type DashboardSummary struct {
    ActiveIMPLs      []IMPLStatus
    CompletedIMPLs   int
    TotalAgents      int
    RunningAgents    int
    FailedAgents     int
    SuggestedActions []Action
}

func GetDashboard(repoPath string) DashboardSummary {
    impls := listIMPLs(repoPath)
    summary := DashboardSummary{}

    for _, impl := range impls {
        state := readIMPLState(impl)
        summary.ActiveIMPLs = append(summary.ActiveIMPLs, IMPLStatus{
            Path:     impl,
            Progress: calculateProgress(state),
            Status:   state.Status,
        })

        summary.TotalAgents += len(state.Agents)
        for _, agent := range state.Agents {
            if agent.Status == "running" {
                summary.RunningAgents++
            } else if agent.Status == "failed" {
                summary.FailedAgents++
            }
        }
    }

    summary.SuggestedActions = generateActions(summary)
    return summary
}
```

**Web app route:** `/api/dashboard` returns JSON consumed by React dashboard component.

**Benefit:** Single-pane-of-glass view for multi-IMPL projects. Currently must navigate to each IMPL individually.

**Priority:** Medium (v0.80). Improves UX for complex projects (PROGRAM layer users).

---

## 7. Architecture Comparison Table

| Aspect | Scout-and-Wave | Plan-Cascade |
|--------|----------------|--------------|
| **Protocol Spec** | Explicit (invariants I1-I6, rules E1-E45) | Implicit (embedded in Python code) |
| **Conflict Prevention** | Structural (I1: disjoint ownership) | Best-effort (dependency resolution) |
| **Isolation** | Worktree-per-agent | Single branch (or feature-level worktree) |
| **Interface Contracts** | Enforced (I2: scaffolds before waves) | Not enforced (stories can hallucinate APIs) |
| **Quality Gates** | Sequential (E21) | Three-phase (PRE/VALIDATION/POST), parallel |
| **Code Review** | Optional, not standard workflow | Standard POST_VALIDATION gate |
| **Resumability** | Progress % + suggested actions | Progress % only |
| **Tool Journaling** | Automatic (external observer, E23A) | Manual (requires explicit writes) |
| **Multi-Agent** | Per-role model selection + fallback | Phase-based agent selection + fallback |
| **Desktop App** | Web app (requires server) | Standalone app (Tauri 2.0) |
| **Skill System** | Static prompts | Auto-detected framework skills |
| **Spec Interview** | E39 (underutilized) | 6-phase structured interview |
| **Codebase Size** | ~135K LOC Go + protocol docs | ~50K LOC Python + Rust desktop |
| **Distribution** | Pre-built binaries (Go) | pip package + desktop installer |

---

## 8. Summary: Which System to Choose?

### Choose Scout-and-Wave if you need:
- **Correctness guarantees** (conflicts impossible by construction)
- **Production-grade reliability** (self-hosting protocol for 30+ features)
- **Protocol portability** (language-agnostic spec)
- **Strict isolation** (worktree-per-agent, tool-level enforcement)
- **Resume intelligence** (tool journaling, context recovery)
- **Real-time monitoring** (SSE-based web dashboard)

**Best for:** Production codebases, team workflows, complex refactors, reproducible outcomes.

### Choose Plan-Cascade if you need:
- **Rapid iteration** (Python core, easy to extend)
- **Flexible orchestration** (PRD-based decomposition, multi-agent fallback)
- **Desktop experience** (standalone Tauri app, project management)
- **Quality gates** (three-phase parallel execution, format auto-fix)
- **Framework skills** (auto-detected React/Vue/Rust best practices)
- **Lower barrier to entry** (simpler conceptual model, fewer commands)

**Best for:** Solo developers, exploratory development, prototyping, experimentation.

---

## 9. Actionable Recommendations for SAW

### Immediate (v0.75, 2-4 weeks):
1. **Enhanced resume detection** (Section 6.3) — Analyze failure types, suggest recovery actions
2. **Scaffold detection automation** (Section 6.4) — Auto-detect shared types from agent briefs (E45 enhancement)
3. **Code review integration** (Section 5.5) — Add to E21 as optional gate, show scores in web app

### Near-term (v0.80, 1-2 months):
4. **Quality gate parallelization** (Section 6.1) — Three-phase execution with parallel gates
5. **Dashboard aggregator** (Section 6.5) — `/api/dashboard` endpoint for cross-IMPL summary
6. **Spec interview enhancement** (Section 5.3) — Add 6-phase structure to E39, web app UI

### Medium-term (v0.85+, 3-6 months):
7. **External framework skills** (Section 6.2) — Auto-detected React/Vue/Rust best practices
8. **Desktop app** (Section 5.2) — Tauri 2.0 packaging of `scout-and-wave-web`
9. **Solo wave optimization improvements** (Section 5.1) — Better detection of worktree-unnecessary scenarios

### Long-term (v1.0+, 6-12 months):
10. **Protocol extraction** (Section 3.1) — Extract protocol into standalone spec docs
11. **Story-level worktrees** (Section 3.5) — Extend worktree isolation to sub-wave granularity
12. **Batch execution model** (Section 2.6) — Alternative to tier-based PROGRAM execution

---

## 10. Conclusion

Scout-and-Wave and Plan-Cascade represent two valid approaches to parallel agent coordination:

- **SAW** prioritizes **correctness** through structural guarantees (disjoint ownership, interface contracts, worktree isolation). It treats parallelism as a distributed systems problem requiring mechanical enforcement.

- **Plan-Cascade** prioritizes **flexibility** through intelligent orchestration (dependency resolution, multi-agent fallback, quality gates). It treats parallelism as a workflow problem requiring adaptive coordination.

Both systems have significant strengths worth borrowing:
- SAW should adopt Plan-Cascade's quality gate parallelization, enhanced resumability, and framework skill system
- Plan-Cascade should adopt SAW's disjoint file ownership, interface contract enforcement, and tool journaling

The best path forward for SAW is to **maintain protocol-first correctness while improving developer experience** through:
1. Better resumability (actionable guidance, not just progress %)
2. Faster gates (parallel execution, format auto-fix)
3. Easier onboarding (enhanced interview mode, dashboard aggregation)

These improvements make SAW more approachable without sacrificing the correctness guarantees that make it production-grade.

---

**Document Status:** Complete
**Next Steps:** Review recommendations with SAW team, prioritize v0.75 roadmap items
