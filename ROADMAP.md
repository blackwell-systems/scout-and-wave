# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Protocol Enhancements

### Full Research Output on NOT SUITABLE Verdicts

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

### Failure Taxonomy

**Current state:** Agent completion reports use `status: complete | partial | blocked`. The orchestrator surfaces `partial` or `blocked` to the human and stops.

**Problem:** Not all failures are equal. A transient git error, a recoverable build failure, and a fundamentally unsound IMPL doc all look the same to the orchestrator.

**Proposed:** Add a `failure_type` field to completion reports:

```yaml
failure_type: transient | fixable | needs_replan | escalate
```

- `transient` — intermittent failure (network, git lock, flaky test). Orchestrator retries automatically up to N times before escalating.
- `fixable` — agent hit a concrete blocker but knows the fix (e.g., missing dependency, wrong import path). Orchestrator applies the fix and relaunches the agent.
- `needs_replan` — agent discovered that the IMPL doc decomposition is wrong (ownership conflict, undiscoverable interface, scope larger than estimated). Orchestrator re-engages Scout with the agent's findings as additional context.
- `escalate` — agent cannot continue and has no recovery path. Human intervention required.

This maps to an orchestrator decision tree instead of the current "halt and surface" model. The web UI would show the failure type and offer the appropriate action button for each — retry, fix, re-scout, or escalate.

**Protocol changes required:** `completion-report` schema in `protocol/message-formats.md`, orchestrator behavior in `protocol/execution-rules.md` (new E-rules for each failure_type), `agent-template.md`.

---

### `docs/SAW.md` — Project Memory

**Current state:** Each IMPL doc is per-feature and ephemeral. The Scout starts cold on every feature — no memory of architectural decisions made in previous features, no record of established conventions, no knowledge of interfaces that already exist from prior waves.

**Problem:** After several features, SAW users develop project-level knowledge (naming conventions, module boundaries, shared types) that the Scout has to rediscover every time. This is expensive and error-prone.

**Proposed:** A persistent project-level document at `docs/SAW.md`, created on first `/saw scout` and updated after each completed feature:

```yaml
# docs/SAW.md — Project memory for Scout-and-Wave
created: 2026-03-07
protocol_version: "0.9.3"

architecture:
  description: "Brief description of project structure"
  modules:
    - name: string
      path: string
      responsibility: string

decisions:
  - decision: "Use worktree isolation for all waves regardless of wave size"
    rationale: "Consistency > convenience; removes I1 violation edge cases"
    date: 2026-03-06
    feature: IMPL-add-caching-layer

conventions:
  naming: string
  error_handling: string
  testing: string

established_interfaces:
  - name: string
    path: string
    signature: string
    introduced_in: string  # IMPL doc slug

features_completed:
  - slug: string
    impl_doc: string
    waves: number
    agents: number
    date: string
```

Scout reads `docs/SAW.md` before the suitability gate. After a wave completes, orchestrator appends to `decisions`, `established_interfaces`, and `features_completed`. Prevents the scout from redefining types that already exist, proposing architecture that contradicts prior decisions, or missing conventions that the project has established.

**Protocol changes required:** New section in `protocol/message-formats.md` defining the schema, new E-rule requiring Scout to read `docs/SAW.md` if present, orchestrator update step after each completed feature.

---

## Quality Gates

### Automated Post-Wave Verification

**Current state:** SAW's only quality check is the human review checkpoint after the Scout produces the IMPL doc. Once waves execute, there is no automated verification — a wave agent that writes broken code, leaves stubs, or breaks tests is only caught when a human looks at the output.

**Problem:** The review checkpoint is pre-execution. There is no gate between wave agent completion and merge. Broken code silently merges into the integration branch.

**Proposed:** After each wave agent writes `[COMPLETE]` to its IMPL doc section, the orchestrator runs a quality gate before considering the story done. Gates are subprocess calls — not AI prompts — that check the exit code of real project tools.

**Gate types:**

```
typecheck  →  tsc --noEmit  /  mypy .  /  pyright
test       →  pytest -v  /  npm test  /  cargo test  /  go test ./...
lint       →  ruff check .  /  eslint .  /  cargo clippy
custom     →  any command defined in saw.config.json
```

Project type is auto-detected from marker files (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`). Each gate type has a fallback chain — if `mypy` is not installed, try `pyright`, then `python -m mypy`. Gates are configured as `required` (blocks merge) or `optional` (warns only).

**AI Verification Gate** — separate from subprocess gates. A Task agent reads the wave agent's acceptance criteria from the IMPL doc and the changed files, and answers: did the agent actually implement what was specified, or did it leave stubs? Skeleton code patterns that trigger failure: `pass`, `...`, `NotImplementedError`, `TODO`, `FIXME`, `implement later`.

**Failure handling:** A required gate failure feeds directly into the failure taxonomy — the orchestrator classifies it as `fixable` (test failure with known error) or `escalate` (compilation broken, no clear path). In automatic retry mode, the orchestrator re-runs the wave agent up to N times before escalating to the human.

**Flow levels** (maps to protocol suitability gate severity):

| Level | Gates | Behavior on failure |
|-------|-------|---------------------|
| `quick` | none | no gates run |
| `standard` | all gates | failure is a warning, merge proceeds |
| `full` | all gates | required gate failure blocks merge |

**Protocol changes required:** New E-rule in `protocol/execution-rules.md` requiring orchestrator to run configured gates before marking a wave agent complete, new `quality_gates` section in `protocol/message-formats.md` defining gate config schema, `scout.md` updated to optionally emit gate config in IMPL doc.

---

### Stub Detection at Review Checkpoint

**Current state:** The review checkpoint is a human reading the IMPL doc and approving the wave structure. There is no automated check on what the wave agents actually produced.

**Problem:** An agent can write a function shell — correct signature, correct file location, correct import — but with `pass`, `...`, or `raise NotImplementedError` as the body, then mark `[COMPLETE]`. The IMPL doc looks fine. The human reviewer looking at the plan (not the diff) would not catch it. The stub ships.

**Proposed:** After all wave agents complete and before the review checkpoint, the orchestrator scans every file touched by wave agents for stub patterns:

```
pass          # Python empty body
...           # Python ellipsis body
NotImplementedError
TODO
FIXME
raise NotImplementedError
// TODO
/* TODO */
throw new Error("not implemented")
unimplemented!()   # Rust
todo!()            # Rust
```

Stubs found in changed files → listed in the IMPL doc under a new `## Stub Report` section, flagged on the review screen. The human sees exactly which functions are hollow before approving.

This is distinct from quality gates (which run project tools). Stub detection is a static text scan — no build required, works on any language, zero false-negative risk on the patterns above.

**Protocol changes required:** New E-rule requiring orchestrator to run stub scan after wave completes, new `## Stub Report` section in IMPL doc schema (`protocol/message-formats.md`), review screen in web UI surfaces stub report prominently.

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

### Local-First Web UI (`saw serve`) — Partially implemented

**Implemented (`scout-and-wave-go`):** `saw serve` runs at `localhost:7432`. Review screen shows suitability verdict, pre-mortem, wave structure (SVG timeline + DAG), file ownership table, interface contracts, and Approve/Reject. Split-pane IMPL list with resizable/collapsible sidebar. SSE-based wave board with agent status cards.

**Outstanding:**
- **Wave execution board** — agent cards live-update as agents write completion reports; failure type badge with action button (retry / fix / re-scout / escalate) per failure taxonomy
- **Project memory view** — `docs/SAW.md` viewer/editor showing decisions, conventions, completed features timeline
- **Stub report panel** — surfaces stub scan results before approve buttons
- **NOT SUITABLE research panels** — verdict shown prominently but all research sections still render; "What would make it suitable" callout

---

## Orchestration UX

### Claude Orchestrator Chat Panel

**Current state:** The web UI workflow is button-driven. User clicks Approve → watches WaveBoard as agents execute → manually intervenes when failures occur. The orchestrator runs autonomously once triggered; the user is an observer until something breaks. When an agent fails, the user must:
1. Read the completion report to understand what went wrong
2. Inspect logs, diffs, or git state to diagnose
3. Decide whether to retry, skip, or abort
4. Execute the decision via `saw` CLI or by manually restarting the server

**Problem:** SAW orchestrates parallel agent execution, but the user orchestrates the orchestrator. When errors occur, the system halts and waits for human judgment. The user has state (IMPL doc, agent results, git history) but no reasoning partner. They must translate error messages, interpret completion reports, and decide on recovery paths without assistance.

**Proposed:** Add a **Claude chat panel** to the web UI. The user can converse with Claude about the workflow state and ask Claude to execute orchestration actions. Claude has direct access to orchestrator primitives as tools and can reason about IMPL doc structure, wave dependencies, agent status, and failure context.

---

#### Architecture

**Hybrid model:** Keep existing UI buttons for deterministic operations (Approve, Start Wave, Reject). Add Claude chat as a copilot for:
- Error diagnosis: "Why did agent B fail?" → Claude reads completion report, checks git state, explains in plain language
- Recovery guidance: "Should I retry agent B or skip it?" → Claude analyzes dependencies, suggests trade-offs
- Smart resumption: "Continue from where it failed" → Claude checks wave state, determines which agents need rerun
- Proactive orchestration: "Start wave 1, and if all agents succeed, start wave 2" → Claude monitors and chains operations

Claude is the **navigator who can grab the wheel**, not autopilot. Buttons remain the primary interface for users who want direct control. Chat is for when you want help reasoning about the next action.

**Backend: Claude agent with orchestrator tools**

New Go package `pkg/orchestrator/assistant` provides a Claude agent configured with tools for workflow control:

```go
type OrchestratorTool interface {
  Name() string
  Description() string
  Schema() map[string]interface{}
  Execute(ctx context.Context, params map[string]interface{}) (interface{}, error)
}

// Tools exposed to Claude:
- read_impl(slug string)           // Parse and return IMPL doc structure
- get_status(slug string)          // Current wave/agent state, completion status
- start_wave(slug string, wave int)
- retry_agent(slug string, wave int, agent string)
- skip_agent(slug string, wave int, agent string)
- view_logs(slug string, wave int, agent string)  // Read completion report + stderr
- read_file(path string)           // Read source file from repo
- git_status(slug string)          // Check working tree state, conflicts
- git_diff(slug string, ref string)
- list_branches(slug string)       // Show wave branches, merged status
- explain_dependency(slug string, agent string)  // Why agent X depends on Y
```

Tools have **direct access** to the orchestrator state machine and git operations. They do not shell out to `saw` CLI — they invoke the same internal functions that the REST API uses.

**System prompt:** Claude is briefed on the SAW protocol (wave structure, agent isolation, merge gates, completion reports). On each chat session start, the system injects:
- Full IMPL doc text (slug, suitability, waves, agents, dependencies, scaffolds)
- Current orchestrator state (which waves/agents have run, which are pending, which failed)
- Recent SSE events (last 10 events: agent_started, agent_complete, agent_failed, etc.)

Claude's role: "You are assisting a developer using the Scout-and-Wave protocol. The developer will ask you questions about the workflow or request you to perform orchestration actions. Use your tools to inspect state and execute commands. Always explain what you're doing and why. For destructive operations (start wave, retry agent), confirm your understanding before executing."

**API endpoint:**

```
POST /api/impl/{slug}/chat
WebSocket or SSE stream

Request:
{
  "message": "Why did agent B fail?",
  "conversation_id": "uuid"  // maintain chat history per session
}

Response (streamed):
{
  "type": "assistant_message",
  "content": "Let me check agent B's completion report..."
}
{
  "type": "tool_use",
  "tool": "view_logs",
  "input": {"slug": "demo-complex", "wave": 1, "agent": "B"}
}
{
  "type": "tool_result",
  "content": "..."
}
{
  "type": "assistant_message",
  "content": "Agent B failed because of a merge conflict in types.ts. The conflict is between..."
}
```

Conversation history is stored in memory per `conversation_id`. When user opens the chat panel, a new conversation starts with fresh context injection. History persists for the browser session but is not saved to disk (ephemeral — each feature's workflow is independent).

**Frontend: Chat panel component**

New React component `ChatPanel.tsx`:

```tsx
<ChatPanel slug={slug}>
  <MessageList>
    {messages.map(msg => (
      msg.role === 'user' ? <UserMessage>{msg.content}</UserMessage> :
      msg.role === 'assistant' ? <ClaudeMessage>{msg.content}</ClaudeMessage> :
      msg.role === 'tool_use' ? <ToolCallBadge tool={msg.tool} input={msg.input} /> :
      msg.role === 'tool_result' ? <ToolResultCollapsible>{msg.content}</ToolResultCollapsible> : null
    ))}
  </MessageList>
  <ChatInput
    onSubmit={handleSend}
    placeholder="Ask Claude about the workflow or request an action..."
    disabled={loading}
  />
</ChatPanel>
```

**Integration into ReviewScreen:**

Chat panel appears as a **docked sidebar** on the right side of ReviewScreen (or as a toggle panel like Pre-Mortem/Wave Structure). When docked:
- Always visible alongside other panels
- Resizable/collapsible (similar to left nav)
- Can be opened from WaveBoard too (so user can chat during wave execution)

Alternative: Chat panel as a **modal overlay** that can be opened from any screen via a floating action button. Modal dims the background, shows full chat interface, closes on ESC or explicit close button.

**UX flow examples:**

*Example 1: Error diagnosis*
```
User: "Why did agent B fail?"
Claude: [calls view_logs(wave=1, agent="B")]
Claude: "Agent B failed with status 'blocked'. The completion report shows:
        - Attempted to modify `src/types.ts`
        - Merge conflict detected during verification
        - Conflict markers found at lines 42-48

        The conflict is between Agent A's changes (added `PreMortem` type) and
        Agent B's changes (added `StubReport` type) in the same exports block.

        Would you like me to show you the diff?"

User: "Yes, show the diff"
Claude: [calls git_diff(ref="wave1-agent-b")]
Claude: [displays formatted diff with conflict markers highlighted]
Claude: "The fix is straightforward — both types need to be exported. You can:
        1. Let me retry Agent B with instructions to preserve both exports
        2. Manually resolve the conflict and mark Agent B complete
        3. Skip Agent B and continue (not recommended — breaks Wave 2 dependency)

        What would you like to do?"
```

*Example 2: Proactive orchestration*
```
User: "Start wave 1"
Claude: [calls start_wave(wave=1)]
Claude: "Starting Wave 1 with 4 agents: A, B, C, D. All agents are running in parallel..."
Claude: [monitors SSE events]
Claude: "Agent A completed successfully ✓"
Claude: "Agent C completed successfully ✓"
Claude: "Agent D completed successfully ✓"
Claude: "Agent B failed with a merge conflict ✗"
Claude: "Wave 1 is 75% complete (3/4 agents). Agent B's failure blocks the merge gate.
        Should I retry Agent B, or would you like to investigate the conflict first?"
```

*Example 3: Dependency explanation*
```
User: "Why does agent J depend on F and G?"
Claude: [calls read_impl(), calls explain_dependency(agent="J")]
Claude: "Agent J depends on F and G because:
        - Agent F creates `pkg/types/scaffold.go` with the `ScaffoldFile` type
        - Agent G creates `pkg/protocol/parser.go` with the `parseScaffoldsSection` function
        - Agent J implements `pkg/api/impl.go` which imports both types and uses them to
          build the API response

        The dependency graph shows:
        Wave 2: F, G (parallel)
        Wave 3: J (waits for F and G to merge)

        This is a classic 'shared type dependency' — J consumes what F and G produce."
```

*Example 4: Smart recovery*
```
User: "Wave 1 failed. Continue from where it left off."
Claude: [calls get_status()]
Claude: "Wave 1 status:
        - Agent A: complete ✓
        - Agent B: failed (merge conflict)
        - Agent C: complete ✓
        - Agent D: complete ✓

        Agent B is the only blocker. Let me check the failure..."
Claude: [calls view_logs(agent="B")]
Claude: "Agent B's merge conflict is in `types.ts` (exports block). I can retry Agent B
        with explicit instructions to preserve existing exports. Should I proceed?"

User: "Yes"
Claude: [calls retry_agent(wave=1, agent="B")]
Claude: "Retrying Agent B with merge conflict guidance..."
Claude: [monitors]
Claude: "Agent B completed successfully on retry ✓"
Claude: "Wave 1 is now 100% complete. Ready to merge. Should I start Wave 2?"
```

---

#### Implementation Phases

**Phase 1: Read-only assistant (Diagnostic mode)**
- Chat panel UI component (message list, input, loading states)
- API endpoint: `POST /api/impl/{slug}/chat` with conversation history
- Backend: Claude agent with **read-only tools** only:
  - `read_impl`, `get_status`, `view_logs`, `read_file`, `git_status`, `git_diff`, `explain_dependency`
- System prompt: Claude briefed on SAW protocol + current IMPL state
- Goal: User can ask "why did X fail?" and get answers, but Claude cannot execute actions yet

**Phase 2: Orchestration actions (Copilot mode)**
- Add **write tools**:
  - `start_wave`, `retry_agent`, `skip_agent`
- Tool execution requires **confirmation for destructive ops**:
  - Before calling `start_wave` or `retry_agent`, Claude asks "Should I proceed?" and waits for user reply
  - User can say "yes", "no", or "explain first"
- Goal: User can delegate recovery actions to Claude ("retry agent B")

**Phase 3: Proactive monitoring (Navigator mode)**
- Claude **subscribes to SSE events** and provides commentary:
  - "Agent A just completed ✓"
  - "Agent B failed — checking logs now..."
- Chat panel shows **live updates** as agents run (not just responses to user messages)
- User can ask "what's happening?" mid-execution and Claude summarizes current state
- Goal: Claude watches the workflow and surfaces issues proactively

**Phase 4: Autonomous chains (Autopilot mode - optional)**
- User can request **multi-step workflows**:
  - "Run wave 1, and if all agents succeed, start wave 2"
  - "Retry failed agents up to 3 times before escalating"
- Claude plans the sequence, confirms with user, then executes autonomously
- User can interrupt at any time ("stop", "pause")
- Goal: Claude handles routine workflows end-to-end with user oversight

**Phase 4 is speculative** — may not be needed if Phases 1-3 cover 90% of use cases. The goal is to make error recovery easier, not to replace the user's judgment.

---

#### Design Considerations

**Latency:**
- Button click = instant action (direct REST call)
- Chat message = 2-4s for Claude to reason + call tools
- **Tradeoff accepted:** Buttons remain for fast deterministic ops. Chat is for when you need reasoning, not speed.

**Cost:**
- Every chat message costs tokens (system prompt + conversation history + tool results)
- Worst case: ~10-20k tokens per error diagnosis (IMPL doc + logs + git diff)
- **Mitigation:** User is on Max Plan (unlimited); token cost is not a concern for this use case. If deploying for API-key users, add conversation limits or require opt-in.

**Reliability:**
- What if Claude misinterprets "skip agent B" as "skip wave 2"?
- **Mitigation:** Tool schemas are strict. `skip_agent` requires `wave: int, agent: string`. Claude cannot skip an entire wave with the skip_agent tool. For ambiguous requests, Claude asks clarifying questions.
- Destructive ops (start wave, retry, skip) require confirmation before execution.

**Trust:**
- Will users trust Claude to drive merges, branch creation, retries?
- **Mitigation:** Phase 1 (read-only) builds trust first. Users see Claude accurately diagnose errors before granting write access. Phase 2 adds confirmation prompts. By Phase 3, users have seen Claude's reasoning enough to trust autonomous monitoring.

**Multi-repo:**
- Chat is scoped to one IMPL doc (one repo). If user runs multiple `saw serve` instances, each has independent chat history.
- Claude does not have cross-repo context (consistent with single-repo-per-instance design).

**Conversation persistence:**
- Chat history is **ephemeral** (in-memory for the session).
- Rationale: Each IMPL doc is independent. Knowledge from one feature's troubleshooting does not carry over. If persistence is needed later, store conversations in `~/.saw/chat-history/{slug}.jsonl`.

**Alternative: Terminal emulator (rejected for v1)**
- Could embed xterm.js and spawn `claude` CLI with PTY for full terminal experience
- **Rejected because:**
  - Cannot inject IMPL doc context automatically (user would need to paste it)
  - Security risk (PTY gives shell access to host)
  - Harder to instrument (no structured tool call logs)
  - Chat UI is more accessible for non-terminal-fluent users

**Comparison to existing tools:**
- **GitHub Copilot Chat:** IDE-scoped, reads open files, suggests code edits. SAW chat is workflow-scoped, reads IMPL docs + git state, executes orchestrator actions.
- **Anthropic Console:** Generic Claude chat, no project context. SAW chat is pre-loaded with IMPL structure and can execute domain-specific tools.
- **Aider:** Terminal-based coding agent with git integration. SAW chat is GUI-based and orchestrates multi-agent workflows (not single-agent coding).

**Why this is high-value:**
- **Error recovery is the hardest part of SAW.** When an agent fails, the user must diagnose (read logs, check git, understand dependencies) and decide (retry? skip? abort?). This is exactly where Claude's reasoning shines.
- **Lowers the skill floor.** New SAW users don't need to memorize orchestrator states or understand wave dependencies — they can ask Claude.
- **Scales with complexity.** Simple workflows (1 wave, 2 agents) don't need chat. Complex workflows (3 waves, 11 agents, scaffold step, cross-wave dependencies) benefit immensely.

**Success criteria:**
- Phase 1: Users naturally ask Claude "why did this fail?" instead of reading raw completion reports
- Phase 2: >50% of retry/skip actions are delegated to Claude rather than manual CLI
- Phase 3: Users leave chat panel open during wave execution for live commentary
- Phase 4: Users request autonomous workflows ("run all waves") and trust Claude to handle transient failures

---

#### Protocol Changes Required

**None.** This is a UX enhancement to `scout-and-wave-go` (the engine). The protocol defines IMPL doc structure and execution rules, not how users interact with the orchestrator. Chat is a new interface on top of existing orchestrator primitives.

The only protocol-adjacent addition: if chat proves valuable, future protocol versions could define a **standard tool interface** for orchestrator actions, allowing any Claude-based UI (not just `saw serve`) to implement the same orchestration tools.

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

`scout-and-wave-go` is the engine. The `/saw` Claude Code skill and the web UI are both clients on top of it.
