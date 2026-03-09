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

## Per-Agent Context Slicing for Large IMPL Docs

> **Implemented — 2026-03-08:** E23 (`ExtractAgentContext` / `FormatAgentContextPayload`) shipped in `scout-and-wave-go` v0.2.0, wired into `launchAgent` before `ExecuteStreaming`. UI: `AgentContextToggle` + `AgentContextPanel` in `scout-and-wave-web` v0.18.0 expose the per-agent payload for inspection in ReviewScreen.

**Current state:** When an IMPL doc contains many agents (10+), every Wave agent receives the full IMPL doc as context. Agent A reads all 13 other agents' full prompts, dep graph prose, pre-mortem, and known issues — sections it has no use for.

**Problem:** Context waste scales with team size. A 14-agent IMPL doc is ~3× larger than a 5-agent one. Each extra agent prompt consumed by every other agent compounds: N agents × N prompts = O(N²) token waste for context that belongs to no one agent. This isn't just cost — it erodes the signal-to-noise ratio in the agent's working context for the duration of its run.

**Proposed: Per-agent context extraction.** The orchestrator constructs a trimmed payload for each agent before launch, containing only:
1. That agent's 9-field prompt section
2. Interface contracts (every agent needs these)
3. File ownership table (needed for I1 invariant verification)
4. Scaffolds section (needed to know what's pre-built)
5. Quality gates (needed for verification gate)

Other agents' prompts, the full dep graph prose, pre-mortem, and known issues are omitted. The full IMPL doc stays on disk as source of truth (I4 unchanged) — agents still write completion reports to it. The per-agent payload is a read-only extract for consumption at launch time only.

**Protocol changes required:**
- `saw-skill.md` — orchestrator constructs per-agent payload before launching each Wave agent rather than passing the raw full doc
- `agent-template.md` — Field 0 updated: agents receive a trimmed context object, not necessarily the full IMPL doc
- `message-formats.md` — define Per-Agent Context Payload schema: sections always included vs. elided

---

## Structured Output Parsing

### Schema-Validated Scout Output (API Backend)

**Current state:** The Scout writes a free-form markdown IMPL doc to disk. The Go engine parses it with a line-by-line state machine that is brittle — format deviations (wrong header levels, missing sections, non-standard dep graph notation) cause silent parse failures or fallback to raw text in the UI.

**Problem:** The app's correctness depends entirely on the AI producing output that conforms to an implicit format. When it doesn't, the UI degrades unpredictably. Parser fixes are a treadmill — each new Scout-written doc can introduce new formatting variations.

**Proposed:** When running Scout via the API backend, use Claude's structured outputs (`output_config.format`) to constrain the Scout's response to a JSON schema matching `types.IMPLDoc`. The orchestrator receives validated JSON, writes the IMPL doc markdown from it (keeping human-readable files on disk), and serves the parsed struct directly — bypassing the markdown parser entirely for this path.

**Flow:**

```
API backend:   Scout prompt → output_config schema → validated JSON → write markdown + serve struct
CLI backend:   Scout prompt → free-form markdown → disk → markdown parser (fallback, as today)
```

**Schema:** Based on the existing `types.IMPLDoc` Go struct — suitability verdict, file ownership table, wave/agent assignments, dependency graph (structured, not prose), interface contracts, scaffolds, known issues. The JSON schema is generated from the Go struct and passed as `output_config.format.json_schema`.

**Benefits:**
- Eliminates parse failures for API-backend users
- Dep graph rendering, wave structure panel, file ownership table all guaranteed to populate
- Completion reports (currently YAML blocks) can use the same approach — `types.CompletionReport` schema passed when running wave agents
- Parser kept as fallback for CLI backend and hand-written/legacy docs

**Implementation path:**
1. Define JSON schema from `types.IMPLDoc` and `types.CompletionReport`
2. Pass schema via `output_config` when invoking Scout and Wave agents via API backend
3. On response, unmarshal directly to struct — skip `protocol.ParseIMPLDoc`
4. Write markdown IMPL doc from struct (so files remain human-readable/editable)
5. Keep `protocol.ParseIMPLDoc` as fallback for CLI backend and existing docs

**Implementation scope:** Engine only (`scout-and-wave-go`). No protocol changes — the protocol defines what the IMPL doc contains, not how it is generated.

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

### Short IMPL-Referencing Prompts for Wave Agent Launches

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

## Tool System Refactoring

**Current state:** `pkg/agent/tools.go` in `scout-and-wave-go` implements tools as a `[]Tool` slice where each `Tool` struct contains `Name`, `Description`, `InputSchema`, and an `Execute` function. Tools are constructed via factory functions (`readFileTool()`, `writeFileTool()`, etc.) that close over `workDir`. The `StandardTools(workDir)` function returns the hardcoded set of available tools. Backends serialize this slice into their native tool-call format (Anthropic Messages API `tools` array, OpenAI-compatible `tools` array, etc.) inline before each request.

**Problem:** The current implementation is functional but not extensible. Adding a new tool requires editing `StandardTools()`. Backend-specific serialization is scattered across each backend package (`api/client.go`, `openai/client.go`, `bedrock/client.go`). There's no hook system for logging, timing, or validation. Tool namespacing (e.g., `file:read` vs `git:commit`) is not supported. Custom tools for specific agent types require passing different tool sets through the entire call chain.

**Proposed refactoring approaches** (can be combined):

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

**Implementation scope:** Engine only (`scout-and-wave-go`). No protocol changes required — the protocol defines what tools agents receive (Field 4 in `agent-template.md`), not how implementations structure their tool systems.

**Implementation approach:** Clean-slate refactoring. All five patterns should be implemented together as a cohesive architecture rather than staged incrementally:

1. Delete `StandardTools()` and the current `[]Tool` slice approach entirely
2. Implement `ToolRegistry` as the foundation with namespace support from day one
3. Replace `Execute func(...)` fields with the `ToolExecutor` interface
4. Wrap all executors in the middleware stack (logging, timing, validation, permissions)
5. Create backend-specific adapters and remove all inline serialization from backend packages
6. Use namespaced tool names (`file:read`, `git:commit`, etc.) as the primary addressing scheme

This gives a cleaner final architecture without technical debt from compatibility shims. Breaking change acceptable for v0.x engine versions.

**Benefits of unified refactoring:**
- No half-migrated state where some tools use Registry and others use the old slice
- Middleware applied uniformly to all tools from the start (Observatory timing works everywhere)
- Backend adapters eliminate serialization duplication immediately
- Agent permission models (Scout read-only, Wave read-write) work via namespace filtering from launch

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

**Engine extraction complete (2026-03-08).** `scout-and-wave-go` is the standalone engine module (agent runner, protocol parser, orchestrator, git, worktree management, types). `scout-and-wave-web` is the web UI + `saw` CLI server, importing the engine via Go module. The `/saw` Claude Code skill and the web UI are both clients on top of it.
