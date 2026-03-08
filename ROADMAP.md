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

## Protocol Hardening (Cross-Repo Lessons)

Items identified during the engine extraction (Wave 2, 2026-03-08) that should be added to the protocol.

### Scaffold Agent Must Verify Build After Creating Stubs

**Current state:** The Scaffold Agent creates stub files and commits them, but does not verify the project builds.

**Problem:** Scaffold files define types and interfaces that Wave agents import. If the scaffold file has a syntax error, wrong import path, or references a missing dependency, every Wave agent in the next wave will fail immediately with a build error — wasting the full wave execution.

**Proposed:** Scaffold Agent required to run after creating stubs:
1. `go get ./...` (or language-equivalent) — ensure declared dependencies resolve
2. `go mod tidy` — clean up go.sum
3. `go build ./...` — confirm the project compiles with the new stubs

If any step fails, Scaffold Agent reports `status: FAILED` with the error output and does not commit. The orchestrator halts before creating worktrees.

**Protocol changes required:** Add to `agents/scaffold-agent.md` and `protocol/execution-rules.md`.

---

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

### `go.work` Recommendation for Cross-Repo Worktree LSP

**Current state:** When the orchestrating repo and target repo are different Go modules, wave agents working in worktrees of the target repo get LSP errors for cross-repo imports because the `replace` directive in `go.mod` points to a path that doesn't match the worktree layout.

**Proposed:** Add a note to `saw-worktree.md`:

> "For Go cross-repo waves: if the target repo uses a `replace` directive to point at the engine repo, consider creating a `go.work` file at the workspace root that includes both modules. This eliminates LSP 'module not found' noise in agent worktrees and improves IDE diagnostics without affecting production builds."

**Protocol changes required:** `saw-worktree.md` cross-repo mode section.

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

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

**Engine extraction complete (2026-03-08).** `scout-and-wave-go` is the standalone engine module (agent runner, protocol parser, orchestrator, git, worktree management, types). `scout-and-wave-web` is the web UI + `saw` CLI server, importing the engine via Go module. The `/saw` Claude Code skill and the web UI are both clients on top of it.
