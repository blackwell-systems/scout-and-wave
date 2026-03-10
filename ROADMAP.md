# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Protocol Enhancements

### Contract Builder Phase

**Insight:** Forge separates *detecting* cross-agent boundaries from *specifying* the contracts at those boundaries. The planner emits **integration hints** — lightweight annotations flagging where tasks interact ("task-1 produces this API, task-2 consumes it"). A dedicated **Contract Builder** phase reads those hints and generates precise binding contracts before any agent launches.

**Current SAW state:** The Scout generates interface contracts in a single pass. It detects seams AND specifies contracts simultaneously. This works for type-level contracts (where the Scaffold Agent materializes them) but leaves API-level contracts implicit — agents infer request/response shapes from prose descriptions, not machine-readable specs.

**Proposed:** Add integration hints as a structured field in the IMPL doc. Scout emits hints during analysis; a Contract Builder phase (analogous to Scaffold Agent but for API contracts) generates precise specs:
- API contracts: method, path, request/response field types, auth requirements, producer/consumer task mapping
- Type contracts: shared data structures used across agent boundaries (already handled by Scaffold Agent)
- Event/message contracts: for event-driven interfaces

Contracts are injected into agent prompts as binding requirements. The reviewer verifies contract compliance as a distinct check.

**Protocol changes required:**
- `message-formats.md` — integration hint schema, API contract format
- `agents/scout.md` — emit integration hints alongside interface contracts
- New `contract-builder.md` agent type (or extend Scaffold Agent scope)
- `agent-template.md` — API contracts section in per-agent payload

---

### Tier 2 Merge Conflict Resolution Agent

**Insight:** Forge uses a tiered merge conflict strategy: Tier 1 auto-retries the merge (in case main advanced and the conflict resolves on retry); Tier 2 spawns a dedicated resolver agent that reads conflict markers and edits them to produce a clean merge.

**Current SAW state:** `saw-merge.md` Step 4 detects conflicts and surfaces them to the user but has no automated resolution path. The human must resolve manually.

**Proposed:** Add tiered resolution to the merge procedure:
- **Tier 1 (automatic):** Retry the merge after a brief delay — handles the common case where another agent merged concurrently and the working branch advanced
- **Tier 2 (resolver agent):** If Tier 1 fails, spawn a Wave Agent variant with: the conflicting files (with conflict markers), both agents' completion reports, and instructions to resolve by choosing or synthesizing the correct version
- Tier 2 resolver agent commits the resolved files and reports its decision rationale
- If Tier 2 also fails: escalate to human (current behavior)

**Protocol changes required:**
- `saw-merge.md` Step 4 — tiered resolution procedure
- New `resolver-agent.md` agent type (slim variant of wave-agent, owned-file scope is the conflicting files only)
- `execution-rules.md` — new E-rule for conflict resolution tiers

---

### Full Research Output on NOT SUITABLE Verdicts

> **UI implemented — 2026-03-08 (v0.17.0):** `NotSuitableResearchPanel` renders the full research output (verdict banner, rationale, blockers callout, serial implementation notes, Archive button). Protocol changes (scout.md, message-formats.md) to require scouts to always write full research sections regardless of verdict are still pending.

**Current state:** When Scout returns NOT SUITABLE, it writes a short verdict with a brief rationale and stops. The IMPL doc is minimal — just the verdict and a sentence or two explaining why.

**Problem:** The Scout has already done the work — it analyzed the codebase, mapped the files, identified the dependency structure, assessed the risks. All of that research is discarded. The user gets a dead end with no actionable information.

**Proposed:** Decouple the **verdict** from the **research**. The verdict gates whether the protocol proceeds to waves; the research is always written in full regardless of verdict.

A NOT SUITABLE IMPL doc should contain everything a SUITABLE one does, except agent prompts:

- Full file survey — what exists, what would need to change, what the blast radius is
- Dependency map — what depends on what, which files are entangled
- Risk assessment — what makes it unsuitable (scope too large, ownership conflicts, missing interfaces, architectural mismatch)
- **Why not suitable** — specific, actionable: "this requires touching 23 files across 6 packages with no clean seam for disjoint ownership" is more useful than "NOT SUITABLE"
- **What would make it suitable** — conditions under which a future Scout run could return SUITABLE. E.g., "extract `pkg/agent/runner.go` first as a prerequisite, then re-scout"
- **Serial implementation notes** — if the work isn't suitable for parallel wave execution, what's the recommended serial order? This surfaces value for users who want to implement manually or in a single agent rather than in waves.

The verdict badge on the review screen changes color (red/amber/green) but the research panels all populate. NOT SUITABLE is not a dead end — it's a detailed map of why the work is hard and what to do about it.

**Protocol changes required:**
- `protocol/message-formats.md` — NOT SUITABLE IMPL docs required to contain full research sections; only `## Agent Prompts` and `## Wave Execution Loop` are omitted
- `agents/scout.md` and `prompts/scout.md` — suitability gate updated: verdict is written early, but research sections are always completed regardless of verdict
- Web UI review screen — NOT SUITABLE verdict shown prominently but research panels still render; "What would make it suitable" section displayed as a callout

---

## ✅ Structured Output Parsing — SHIPPED (v0.17.0 engine / v0.32.0 web)

Schema-validated Scout output via `output_config.format`. Scout runs through API backend produce JSON matching `IMPLManifest` schema → unmarshalled directly → saved as YAML IMPL docs. CLI backend fallback to markdown parser preserved. `GenerateScoutSchema()` in `pkg/protocol/schema.go`, `UseStructuredOutput: true` in web Scout launcher, YAML rendering in `handleGetImpl`.

---

## Framework Skills Content

### Framework-Specific Guidance Documents

**Proposal:** The protocol repo should provide framework-specific best practice documents that implementations MAY inject into agent prompts. These documents capture common patterns, anti-patterns, and conventions for popular frameworks.

**Skill directory structure:**
```
scout-and-wave/skills/
  react-best-practices.md        # Hooks, component composition, prop types
  vue-best-practices.md          # Composition API, reactivity, lifecycle
  rust-ownership.md              # Borrowing, lifetimes, ownership patterns
  rust-error-handling.md         # Result, Option, ? operator
  go-idioms.md                   # Interfaces, error handling, goroutines
  go-error-handling.md           # Error wrapping, sentinel errors
  python-type-hints.md           # Type annotations, generics, protocols
  fastapi-patterns.md            # Dependency injection, async, validation
```

**Skill file format:**
- Markdown documents (500-1000 words each)
- Common patterns (with code examples)
- Anti-patterns to avoid (with explanations)
- Framework-specific best practices

**Detection trigger examples:**
- `package.json` with `react` dependency → load `react-best-practices.md`
- `Cargo.toml` exists → load `rust-ownership.md`, `rust-error-handling.md`
- `go.mod` exists → load `go-idioms.md`
- `pyproject.toml` with `fastapi` → load `fastapi-patterns.md`

**Protocol stance:** Implementations MAY auto-detect frameworks and inject skills, or require manual configuration. The protocol provides the content but does not mandate detection logic. This keeps framework knowledge centralized while allowing implementation flexibility.

**Implementation note:** Detection and injection logic belongs in orchestrator implementations (e.g., `scout-and-wave-go`), not in the protocol repo.

---

## Orchestration UX

*`scout-and-wave-web` implementation work. Full designs in `scout-and-wave-web/docs/ROADMAP.md`.*

### Claude Orchestrator Chat Panel

Add a Claude chat panel to `saw serve`. Read-only diagnostic mode first (why did agent B fail?), then write tools (retry, skip), then proactive SSE monitoring. No protocol changes required.

---

## Multi-Generation Agent IDs

### Extended Agent Identifier Format (A2, B3, ...)

**Current state:** Agent identifiers are single uppercase letters A–Z, giving a maximum of 26 agents per wave. The IMPL doc format, parser, and all agent prompts assume single-character IDs.

**Problem:** 26 agents per wave is a practical ceiling. Large features with many parallel work streams, or a future meta-orchestrator running multiple concurrent IMPLs, could exceed this. There is also no systematic color/identity scheme for agents — single letters were sufficient when the number was small.

**Proposed identifier format:** `[Letter][Generation]` where Generation is omitted for generation 1:

| ID | Letter | Generation | Meaning |
|----|--------|------------|---------|
| `A` | A | 1 | First agent of A-family |
| `B` | B | 1 | First agent of B-family |
| `A2` | A | 2 | Second agent of A-family (same hue, different shade) |
| `B3` | B | 3 | Third agent of B-family |

Letter families provide color identity continuity (see web UI roadmap). Generation distinguishes agents within a family while keeping the visual grouping clear — A and A2 are related; A and B are not.

**When to use multi-generation IDs:** The Scout assigns them when a feature requires more agents than available letters (>26), or when agents within a letter family share a logical sub-domain (e.g., A handles API layer; A2 handles API tests for the same subsystem). The Scout decides — the orchestrator does not assign IDs manually.

**Protocol changes required:**

- `protocol/message-formats.md` — Agent ID field definition updated: `[A-Z][2-9]?` (letter + optional digit 2–9; generation 1 is the bare letter). Examples in file ownership table and wave structure sections updated.
- `protocol/execution-rules.md` — E-rules referencing "agent letter" updated to "agent ID". SAW tag format updated: `[SAW:wave1:agent-A2]` is valid.
- `implementations/claude-code/prompts/agents/scout.md` — Scout briefing updated to explain multi-generation IDs and when to assign them.
- `implementations/claude-code/prompts/agents/wave-agent.md` — Wave agent briefing updated to accept multi-char `letter` field in Field 0.
- Parser (`pkg/protocol/parser.go` in scout-and-wave-web) — regex for agent letter updated from `[A-Z]` to `[A-Z][2-9]?`.
- Web UI (`lib/agentColors.ts`) — color derivation updated to decompose multi-char IDs into `(letter, generation)` and apply tonal variation. See web UI roadmap.

**Non-change:** Worktree branch names already use the full agent ID as a string (`wave1-agent-A2`), so no branch naming changes are needed.

---

## Protocol Hardening (Cross-Repo Lessons)

Items identified during the engine extraction (Wave 2, 2026-03-08) that should be added to the protocol.

### Cross-Repo Field 8 Completion Report Path

**Current state:** The agent template Field 8 (completion report) instructs agents to write the report to the IMPL doc. In cross-repo waves, the IMPL doc is in repo A (the spec repo) while the agent works in repo B. Agents that don't receive an absolute IMPL doc path write their report to the wrong location — or not at all.

**Proposed:** In cross-repo mode, the agent prompt must always include an absolute path to the IMPL doc (not relative). Add an explicit callout to `saw-worktree.md` cross-repo section:

> "When constructing wave agent prompts for cross-repo waves, Field 8 must include the **absolute path** to the IMPL doc in the orchestrating repo. Example: `/Users/dev/code/spec-repo/docs/IMPL/IMPL-feature.md`. A relative path will resolve to the wrong directory in the agent's worktree."

**Protocol changes required:** `saw-worktree.md` cross-repo mode section, `agents/wave-agent.md` Field 8 description.

---

### BUILD STUB Test Discipline

**Current state:** When agents write functions that compile but intentionally leave out implementation (e.g., stubs that will be filled by a later wave), tests that exercise those functions will fail. Agents sometimes mark these as `status: complete` anyway.

**Problem:** Stub functions with passing test suites are misleading. A BUILD STUB is not a COMPLETE stub — it is a deliberate placeholder. Treating it as complete conflates "code compiles" with "feature works."

**Proposed:** Distinguish two stub states in agent prompts:
- **BUILD STUB** — function is declared, compiles, body panics/returns zero values. Tests are expected to fail. Mark `status: partial` with `failure_type: fixable`.
- **COMPLETE** — function is fully implemented and tests pass.

Agents MUST NOT report `status: complete` if their functions are BUILD STUBs. The completion report should list each BUILD STUB explicitly.

**Protocol changes required:** `agents/wave-agent.md`, `agent-template.md` Field 9 (status values).

---

### ✅ Short IMPL-Referencing Prompts for Wave Agent Launches — SHIPPED (saw-skill v0.7.2)

**Current state:** The orchestrator copy-pastes the full agent brief (file ownership table, interface contracts, verification gate, completion report format) into each `Agent` tool call's `prompt` parameter. Each prompt is 800–1200 tokens, generated token-by-token before any tool calls fire.

**Problem:** Prompt generation is the bottleneck when launching parallel wave agents, not API latency. All 5 agents in a wave are launched in a single message, but each long prompt must be fully generated in sequence before the tool calls fire. A 1000-token prompt takes 5–10 seconds to generate; 5 agents × 1000 tokens = 5000 tokens of generation before anything executes.

**Proposed:** Use short IMPL-referencing prompts instead of copy-pasting the brief:

```
Read the agent prompt for Wave 2 Agent F from the IMPL doc at:
  /path/to/docs/IMPL/IMPL-feature.md

Find the section "### Agent F — ..." and follow it exactly.
The worktree branch wave2-agent-F is already checked out at
.claude/worktrees/wave2-agent-F. Begin immediately.
```

~60 tokens per agent vs ~1000. For 5 parallel agents: 300 tokens total vs 5000, firing ~10–15× faster. The agent reads the full brief from the IMPL doc on its first tool call — no information is lost.

**Protocol changes required:** `saw-skill.md` orchestration section — note that wave agent `prompt` parameters should be short IMPL-referencing stubs, not copy-pasted briefs. The IMPL doc is already the single source of truth (I4); the prompt should reference it, not duplicate it.

---

### `go.work` Recommendation for Cross-Repo Worktree LSP

**Current state:** When the orchestrating repo and target repo are different Go modules, wave agents working in worktrees of the target repo get LSP errors for cross-repo imports because the `replace` directive in `go.mod` points to a path that doesn't match the worktree layout.

**Proposed:** Add a note to `saw-worktree.md`:

> "For Go cross-repo waves: if the target repo uses a `replace` directive to point at the engine repo, consider creating a `go.work` file at the workspace root that includes both modules. This eliminates LSP 'module not found' noise in agent worktrees and improves IDE diagnostics without affecting production builds."

**Protocol changes required:** `saw-worktree.md` cross-repo mode section.

---

## IMPL Doc Length Management

As IMPL docs accumulate completion reports across many waves, they can grow large enough to create context pressure for agents reading them. Three complementary mitigations:

### History Sidecar (Completion Report Archiving)

**Problem:** Completion reports are verbose (file lists, gate outputs, deviation notes). After a wave merges, these reports are historical record — no future agent needs them. Yet they stay in the main IMPL doc, growing it with each wave.

**Proposed:** Once a wave merges successfully, the Orchestrator appends that wave's completion reports to a sidecar file (`docs/IMPL/IMPL-slug-history.md`) and replaces the verbose sections in the main doc with a one-line summary:

```markdown
### Agent A - Completion Report
<!-- compressed: status=complete, files=3, gate=pass, 2026-03-08 -->
```

The main doc stays bounded at roughly `(base_size) + (N_waves × ~50 bytes)` regardless of wave count. The history file holds the full record for auditing and is never passed as agent context.

**Protocol changes required:** `saw-teams-merge.md` post-merge procedure — add "compact completed wave reports" step after verification passes.

---

### Structured Doc Splitting

**Problem:** All IMPL doc concerns live in one file. Scaffold contents in particular can be large and are never re-read after Wave 1.

**Proposed:** Split by concern at creation time:
- `IMPL-slug.md` — live state: wave structure, file ownership, interface contracts, quality gates, current wave
- `IMPL-slug-scaffolds.md` — scaffold file contents (extracted by Scaffold Agent, referenced from main doc)
- `IMPL-slug-log.md` — append-only completion reports and deviation records

Agents receive only the slices relevant to them (E23 extraction becomes trivial — the right content is already in a separate file).

**Protocol changes required:** `protocol/message-formats.md` — IMPL doc format note on optional split layout; `agents/scaffold-agent.md` — write scaffold contents to sidecar.

---

### IMPL Doc Size Gate

**Problem:** Doc growth is currently invisible. There is no enforcement point that catches a bloated IMPL doc before agents consume it.

**Proposed:** Add a `validate-impl.sh` check: if the doc exceeds a configurable byte threshold (default 50 KB), emit a warning recommending history compaction. Not a hard failure — informational only, surfaced at the E16 validation step and in the web UI reviewer.

**Protocol changes required:** `scripts/validate-impl.sh` — size check with configurable threshold; `saw-teams-skill.md` — surface size warning in E16 validation output.

---

## IMPL-Level Parallelism (Concurrent Feature Execution)

**Current state:** SAW enforces disjoint file ownership within a wave (I1), but IMPL docs are always executed serially. One feature completes and merges before the next begins.

**Problem:** The serial constraint is too conservative. Two features that touch completely different files could execute in parallel — their wave agents would never conflict. But today SAW has no way to express or enforce this, so everything queues.

**The insight:** SAW already solves this problem one level down. I1 enforces disjoint ownership across agents within a wave. The same invariant, lifted one level up, gives you disjoint ownership across concurrent IMPL docs. The constraint is identical — the scope is wider.

**Proposed architecture:**

```
Current:  agents → waves → IMPL docs (always serial)
Next:     agents → waves → IMPL docs (parallel where disjoint, sequenced where overlapping)
```

**Cross-IMPL ownership registry:** Before any IMPL's Wave 1 launches, register its complete file ownership set. A file locked by IMPL-A cannot enter any wave of IMPL-B until A merges that file. The lock is file-granular, not IMPL-granular — IMPL-A and IMPL-B can run concurrently if their file sets are disjoint; they sequence only on the files they share.

**IMPL dependency graph (computed, not declared):** The meta-orchestrator computes which IMPLs block which others from their file ownership intersection. No manual dependency declarations needed — if IMPL-A owns `execution-rules.md` and IMPL-B also needs it, IMPL-B's waves that touch that file wait until IMPL-A releases it. IMPL-B's waves on unrelated files proceed immediately.

**Meta-orchestrator:** A new protocol layer above the current orchestrator. Manages IMPL lifecycle the same way the orchestrator manages wave lifecycle:
- Tracks active IMPLs and their file lock sets
- Computes unblocked IMPLs (no file conflicts with any running IMPL)
- Launches unblocked IMPLs in parallel
- Releases file locks as IMPLs merge; re-evaluates what's unblocked

**Partial-overlap case:** The common case. IMPL-A and IMPL-B both need `execution-rules.md`. Resolution: whichever IMPL starts first locks the file. The other IMPL's wave that needs it is WAVE_PENDING until the lock releases. Waves in IMPL-B that don't need the locked file are unblocked and run in parallel.

**Concrete example (what triggered this):**
- `IMPL-context-and-failure-taxonomy` — edits `execution-rules.md`, `message-formats.md`, `wave-agent.md`, `scout.md`, `agent-template.md`, `saw-skill.md`
- `IMPL-quality-gates` — edits `execution-rules.md`, `message-formats.md`, `scaffold-agent.md`, `scout.md`, `saw-skill.md`

With file-granular locking: IMPL-A runs first, locks those six files. IMPL-B waits on shared files but could immediately run any wave that only touches `scaffold-agent.md` (which IMPL-A doesn't own). After IMPL-A merges, IMPL-B's blocked waves resume. Net result: faster than serial, safe by construction.

**Protocol changes required:**
- New protocol layer: `protocol/meta-orchestrator.md` — IMPL registry, file lock semantics, dependency graph computation, unblocked IMPL selection
- `protocol/invariants.md` — new I7: no two concurrently active IMPLs may have overlapping file ownership for any currently-running wave
- `protocol/message-formats.md` — IMPL status field: `active | waiting_on_lock | complete`
- `protocol/execution-rules.md` — E-rules for lock acquisition, release, and partial-overlap sequencing
- `implementations/claude-code/prompts/saw-skill.md` — meta-orchestrator invocation mode (`/saw multi` or automatic when multiple IMPLs are active)

**Relationship to existing invariants:** I1–I6 are unchanged. They govern agent behavior within a wave. I7 governs IMPL behavior across features. The two levels compose: I1 ensures agents within a wave don't conflict; I7 ensures waves across features don't conflict.

---

## Tool System Refactoring *(shipped v0.19.0)*

**Shipped.** Unified `pkg/tools` package with Workshop registry, ToolExecutor interface, Middleware type, ToolAdapter (Anthropic/OpenAI/Bedrock), and namespaced tools. 7 standard tools (`read_file`, `write_file`, `list_directory`, `bash`, `edit_file`, `glob`, `grep`). Both Anthropic and OpenAI backends wired to Workshop — 3 old duplicated tool files deleted. Middleware and permission filtering available but not yet wired (future: Observatory timing, Scout read-only mode).

**Original problem and design** (retained for reference):

**Current state:** ~~`pkg/agent/tools.go` in `scout-and-wave-go` implements tools as a `[]Tool` slice...~~ Superseded by `pkg/tools/`.

**~~Problem:~~** ~~The current implementation is functional but not extensible...~~ Solved.

**Implemented approaches** (all 5 combined):

### 1. Tool Registry Pattern

Replace the hardcoded `StandardTools()` slice with a `ToolRegistry` that supports dynamic registration:

```go
type ToolRegistry struct {
    tools map[string]Tool
}

func (r *ToolRegistry) Register(tool Tool) error
func (r *ToolRegistry) Get(name string) (Tool, bool)
func (r *ToolRegistry) All() []Tool
func (r *ToolRegistry) Namespace(prefix string) []Tool
```

**Benefits:**
- Plugins can register custom tools at runtime via `init()` or explicit calls
- Test suites can register mock tools without editing production code
- Agent-specific tool sets can be composed from the registry (e.g., Scout gets read-only tools; Wave agents get read+write+bash)

**Example usage:**
```go
registry := tools.NewRegistry()
registry.Register(tools.Read(workDir))
registry.Register(tools.Write(workDir))
registry.Register(tools.Bash(workDir))

// Custom tool
registry.Register(tools.Tool{
    Name: "query_vector_db",
    Execute: func(input map[string]interface{}, workDir string) (string, error) { ... },
})

agentTools := registry.Namespace("file:") // Only file:read, file:write, etc.
```

### 2. Interface-Based Tool Executor

Replace raw `Execute` function fields with an interface:

```go
type ToolExecutor interface {
    Execute(ctx context.Context, input map[string]interface{}) (string, error)
}

type Tool struct {
    Name        string
    Description string
    InputSchema map[string]interface{}
    Executor    ToolExecutor
}
```

**Benefits:**
- Executors can carry state (DB connections, API clients, workspace handles)
- Easier to test (mock implementations of `ToolExecutor`)
- Supports tool versioning (same tool name, different executor based on agent type)

**Example:**
```go
type FileReadExecutor struct {
    workDir string
    fs      afero.Fs // Abstract filesystem for testing
}

func (e *FileReadExecutor) Execute(ctx context.Context, input map[string]interface{}) (string, error) {
    path := input["path"].(string)
    return e.fs.ReadFile(filepath.Join(e.workDir, path))
}
```

### 3. Tool Middleware / Hook System

Wrap tool execution in a middleware stack for cross-cutting concerns:

```go
type ToolMiddleware func(next ToolExecutor) ToolExecutor

// Logging middleware
func LoggingMiddleware(logger *log.Logger) ToolMiddleware {
    return func(next ToolExecutor) ToolExecutor {
        return ToolExecutorFunc(func(ctx context.Context, input map[string]interface{}) (string, error) {
            start := time.Now()
            logger.Printf("Tool call started: %v", input)
            result, err := next.Execute(ctx, input)
            logger.Printf("Tool call finished in %v: err=%v", time.Since(start), err)
            return result, err
        })
    }
}

// Timing middleware (for Observatory SSE events)
func TimingMiddleware(onDuration func(toolName string, dur time.Duration)) ToolMiddleware { ... }

// Validation middleware (schema check before execution)
func ValidationMiddleware(schema map[string]interface{}) ToolMiddleware { ... }

// Permission middleware (enforce read-only mode for Scout agents)
func PermissionMiddleware(allowedTools []string) ToolMiddleware { ... }
```

**Benefits:**
- Agent Observatory timing events can be collected without editing each tool's `Execute` function
- Unified logging for all tool calls (currently scattered or missing)
- Input validation enforced before execution
- Permission enforcement (e.g., Scout agents denied write access) without tool-specific checks

### 4. Backend Adapter Pattern

Extract tool serialization into backend-specific adapters:

```go
type ToolAdapter interface {
    Serialize(tools []Tool) interface{}
    Deserialize(response interface{}) (name string, input map[string]interface{}, error)
}

// Anthropic Messages API adapter
type AnthropicToolAdapter struct{}

func (a *AnthropicToolAdapter) Serialize(tools []Tool) interface{} {
    anthropicTools := make([]map[string]interface{}, len(tools))
    for i, t := range tools {
        anthropicTools[i] = map[string]interface{}{
            "name":         t.Name,
            "description":  t.Description,
            "input_schema": t.InputSchema,
        }
    }
    return anthropicTools
}

// OpenAI-compatible adapter
type OpenAIToolAdapter struct{}

func (a *OpenAIToolAdapter) Serialize(tools []Tool) interface{} {
    openaiTools := make([]map[string]interface{}, len(tools))
    for i, t := range tools {
        openaiTools[i] = map[string]interface{}{
            "type": "function",
            "function": map[string]interface{}{
                "name":        t.Name,
                "description": t.Description,
                "parameters":  t.InputSchema,
            },
        }
    }
    return openaiTools
}
```

**Benefits:**
- Backend packages no longer contain serialization logic — cleaner separation of concerns
- Adding a new backend (e.g., Groq, Cohere) requires only implementing a `ToolAdapter`
- Tool schema changes (e.g., adding a `strict` field for OpenAI) affect only the adapter, not the core `Tool` struct

### 5. Tool Namespaces / Categories

Support namespaced tool names for better organization and filtering:

```go
// Tool names
"file:read"
"file:write"
"file:list"
"git:commit"
"git:diff"
"web:fetch"
"claude:agent"  // Agent tool for spawning sub-agents
```

**Registry namespace filtering:**
```go
registry.Register(tools.Read(workDir).WithName("file:read"))
registry.Register(tools.GitCommit(workDir).WithName("git:commit"))

fileTools := registry.Namespace("file:")   // file:read, file:write, file:list
gitTools := registry.Namespace("git:")     // git:commit, git:diff
allTools := registry.All()                 // Everything
```

**Benefits:**
- Scout agents can receive only `file:read`, `file:list` (read-only)
- Wave agents receive `file:*`, `git:*`, `bash`, etc. (read-write)
- Clearer tool documentation (category is embedded in the name)
- Observatory SSE events can group tool calls by category

---

**Implementation scope:** Engine only (`scout-and-wave-go`). No protocol changes required.

**What shipped (v0.19.0):**
1. ~~Delete `StandardTools()`~~ Done — old `pkg/agent/tools.go`, `pkg/agent/backend/api/tools.go`, `pkg/agent/backend/openai/tools.go` deleted
2. ~~Implement `ToolRegistry`~~ Done — `pkg/tools/workshop.go` (`DefaultWorkshop` with thread-safe registration, namespace filtering)
3. ~~Replace `Execute func(...)` with `ToolExecutor` interface~~ Done — `ExecutionContext` carries `workDir` at call time
4. ~~Middleware wired~~ Done (v0.20.0) — `TimingMiddleware` feeds Observatory via `backend.Config.OnToolCall`; `PermissionMiddleware` + `ReadOnlyTools()` enforce Scout read-only mode via `backend.Config.ReadOnly`
5. ~~Backend adapters~~ Done — `AnthropicAdapter`, `OpenAIAdapter`, `BedrockAdapter` in `pkg/tools/adapters.go`; backends use Workshop directly for serialization
6. ~~Namespaced tools~~ Partial — `Namespace` field on `Tool` struct, `Workshop.Namespace()` method works; tool names use underscores (`read_file`) for OpenAI compatibility instead of colons

**Remaining (future):**
- Custom tool registration at runtime (plugin support)
- Validation middleware (JSON Schema input checks before execution)

---

## Formally Executable IMPL Docs (Coordination as a Program)

**Insight:** Every E-rule and invariant in the protocol is a retroactive constraint — built after an agent produced something malformed and we caught it post-hoc. Structured output parsing is the first time we push a constraint *before* generation. The next phase extends this: the IMPL doc stops being a document that *describes* coordination and becomes a program that *is* coordination.

**Phase 1 — Constraint-solving validator (immediate next step after structured outputs):**

Right now `sawtools validate` checks rules one at a time. Replace it with a constraint solver: model the manifest as a CSP — agents, files, and dependencies as variables and constraints — and *prove* the execution plan is correct rather than checking it's not-wrong. Topological sort over the dep graph catches I2 violations today; extending it to prove optimal wave grouping is a small step. The validator stops being a linter and becomes a proof system.

This also means Scout stops making scheduling decisions. Scout declares *what* agents need (file dependencies, interface dependencies). The solver derives *when* they run — which wave, which agents are parallel. The `wave:` numbers in `file_ownership` are computed, not guessed. I2_WAVE_ORDER errors become impossible because wave assignment is never hand-written.

**Phase 2 — Interface contracts as compiled types:**

The Scaffold Agent already proto-implements this — it materializes contracts as stub Go files. The missing piece: after scaffolds are written, compile a verification program that proves the stubs implement the contracts. A mismatched interface contract is caught before any Wave agent sees it, not after merge when tests fail.

**Phase 3 — Pre-execution simulation:**

Model each agent as a transaction over its owned files. Before worktrees are created, simulate the execution: prove that no two transactions conflict, that all interface consumers have exactly one producer, that every agent's dependencies are satisfied before it runs. This is database isolation theory (serializable transaction isolation) applied to agent coordination.

The full vision: Scout is a dependency mapper, not a scheduler. The scheduler is a deterministic program derived from the dependency graph. The validator is a proof system. Agents execute transactions. The IMPL doc is a formal specification that can be run, simulated, and verified before any real work happens.

**Protocol changes required:**
- `sawtools validate` → constraint solver (replaces rule-by-rule checking with CSP proof)
- `message-formats.md` — `wave:` numbers in file_ownership become optional (solver derives them)
- `agents/scout.md` — Scout emits dependency graph only; does not assign wave numbers
- New `protocol/solver.md` — documents the wave-derivation algorithm and constraint model

---

## SDK Branch as Generated Build Artifact

**Current state:** The `scout-and-wave` repo has two long-lived branches:
- `main` — natural language only. Refers to the `saw` CLI throughout (e.g., `saw validate`, `saw create-worktrees`).
- `sdk` — SDK-coupled. All `saw` references replaced with `sawtools` (the Go toolkit binary). This branch is hand-maintained: every commit to `main` that touches an NL reference must be ported to `sdk` manually.

**Problem:** The `main` → `sdk` substitutions are entirely mechanical. Every `saw ` becomes `sawtools `, every "run `saw`" becomes "run `sawtools`", with occasional CLI flag and path adjustments. There is no semantic difference — it is a textual transformation. Hand-maintaining two branches for a mechanical transformation means:
- Every PR requires a parallel `sdk` version
- Merge discipline must be enforced by convention, not tooling
- Contributors must know about the split and remember to port changes

**Proposed:** Treat the `sdk` branch as a **generated build artifact**, not a hand-edited branch. Define a substitution manifest (e.g., `sdk-substitutions.yaml`) that specifies:

```yaml
substitutions:
  - pattern: "run `saw "
    replace: "run `sawtools "
  - pattern: "exec saw "
    replace: "exec sawtools "
  - pattern: "`saw "
    replace: "`sawtools "
  # ... other mechanical substitutions

file_includes:
  - "implementations/claude-code/**/*.md"
  - "implementations/claude-code/**/*.sh"

# Optionally: files that need non-mechanical edits (override substitution for specific files)
overrides:
  - file: "implementations/claude-code/scripts/install.sh"
    manual: true   # This file is maintained manually in both branches
```

A CI step (GitHub Actions) generates the `sdk` branch on every push to `main`:
1. Checkout `main`
2. Apply all substitutions to all included files
3. Apply any manual overrides
4. Force-push the result to `sdk`

The `sdk` branch becomes a read-only generated artifact — never committed to directly. PRs target `main` only. The substitution manifest is the diff between `main` and `sdk`.

**Benefits:**
- `main` is the only branch contributors touch
- `sdk` is always up-to-date (generated on every push, not manually ported)
- Substitution rules are explicit and auditable (the manifest makes the transformation inspectable)
- Adding new binary-split variants in the future (e.g., a different package manager name) requires only a new manifest entry, not a new hand-maintained branch

**Long-term extension:** If the binary split ever deepens (e.g., different config file paths, different env vars), the manifest grows but the workflow is unchanged. Multiple "flavor" branches (sdk, sdk-docker, sdk-ci) could each have their own manifest.

**Implementation scope:** CI/CD only (`scout-and-wave` repo). No protocol changes required — the protocol content is unchanged; only the tooling that generates the SDK-coupled distribution changes.

**Protocol changes required:** None for the protocol itself. New files:
- `scripts/generate-sdk-branch.sh` — applies the substitution manifest and commits to `sdk`
- `.github/workflows/generate-sdk.yml` — triggers on push to `main`
- `sdk-substitutions.yaml` — the substitution manifest

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

**Engine extraction complete (2026-03-08).** `scout-and-wave-go` is the standalone engine module (agent runner, protocol parser, orchestrator, git, worktree management, types). `scout-and-wave-web` is the web UI + `saw` CLI server, importing the engine via Go module. The `/saw` Claude Code skill and the web UI are both clients on top of it.
