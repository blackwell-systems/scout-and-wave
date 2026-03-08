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

### ~~Pre-Mortem in Scout Output~~ — Implemented (v0.10.0)

Implemented as a required Scout output section (`## Pre-Mortem`) written before the human review checkpoint. Contains an overall risk rating (low/medium/high) and a failure modes table (Scenario / Likelihood / Impact / Mitigation). Schema defined in `protocol/message-formats.md`; output template added to both scout prompt files (`prompts/scout.md` and `prompts/agents/scout.md`).

Remaining work: Web UI review screen — Pre-Mortem section displayed as a callout before the wave structure approval buttons.

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

### ~~IMPL Doc Completion Lifecycle~~ — Implemented (v0.9.4)

Implemented as E15 in `protocol/execution-rules.md`. The orchestrator writes `<!-- SAW:COMPLETE YYYY-MM-DD -->` on the line immediately after the IMPL doc title after final wave verification. IMPL doc schema updated in `protocol/message-formats.md`, state machine updated in `protocol/state-machine.md`, orchestrator skill updated with step 6.

Remaining work: Go engine parser support (`pkg/protocol/parser.go`), API response field (`doc_status`), web UI picker filtering (active vs completed).

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

### ~~Validation + Correction Loop~~ — Implemented (v0.10.0)

**The deeper problem:** Structured outputs solve format enforcement at generation time — but only for the API backend, and only for new runs. Existing docs, CLI-backend users, and hand-edited files all bypass it. The root issue is there is no feedback loop: the AI writes something, the parser tries to read it, and if it fails the error is silent.

**Proposed:** After Scout writes the IMPL doc, the orchestrator runs a deterministic validator before the human review checkpoint. If validation fails, the specific errors are fed back to Scout as a correction prompt. Scout rewrites only the failing sections. This loops until the doc passes or a retry limit is hit.

```
Scout writes → validator runs → pass: proceed to review
                              → fail: "dep graph missing Wave N headers (line 47),
                                       file ownership table missing Wave column" →
                                Scout corrects → validator runs again → ...
```

This is how compilers work — the LLM doesn't need to be perfect on the first try, it needs to respond correctly to deterministic feedback. Works on any backend, works on existing docs when re-validated.

**Validator scope:** Only machine-parsed sections need validation — dep graph, file ownership table, wave/agent structure, completion reports. Prose sections (suitability rationale, interface contracts narrative) are intentionally free-form and excluded.

**Protocol changes required:**
- `protocol/execution-rules.md` — new E-rule (E16): after Scout writes the IMPL doc, orchestrator runs the validator; on failure, re-engages Scout with the error list; proceeds to human review only when validation passes or retry limit is reached
- `protocol/state-machine.md` — new SCOUT_VALIDATING state between SCOUT_COMPLETE and PENDING_REVIEW; transitions: pass → PENDING_REVIEW, fail + retries remain → SCOUT_VALIDATING, fail + retries exhausted → BLOCKED
- `protocol/participants.md` — orchestrator responsibilities updated to include validation step

---

### ~~Structured Metadata Blocks~~ — Implemented (v0.10.0)

**Complementary to the correction loop.** Instead of Scout writing a blank page, the machine-parsed sections are required to be fenced code blocks with declared types:

````
```yaml type=impl-file-ownership
| File | Agent | Wave | Action |
...
```

```yaml type=impl-dep-graph
Wave 1 (2 parallel agents):
    [A] pkg/...
...
```
````

The validator only needs to check typed blocks — it ignores prose entirely. The declared type tells the parser exactly which schema to apply. A block that fails to parse produces a precise error message ("impl-dep-graph block: Wave 2 agent [C] missing depends-on line") that Scout can act on.

This separates human-readable prose from machine-parsed data without requiring the whole doc to be JSON. The IMPL doc stays readable; the structured sections are unambiguous.

**Structured outputs as the strong form of this:** For API-backend runs, `output_config` schema enforcement means the validator always passes — the correction loop becomes a no-op. For CLI backend, the loop provides the same guarantee through iteration rather than constraint.

**Protocol changes required:**
- `protocol/message-formats.md` — IMPL doc schema updated: machine-parsed sections (file ownership, dep graph, wave structure, completion reports) required to use typed fenced blocks (`type=impl-*`); prose sections remain free-form
- `agents/scout.md` and `prompts/scout.md` — output format template updated to use typed blocks for all structured sections
- `agents/wave-agent.md` — completion report format updated to typed block
- `protocol/participants.md` — validator described as a protocol-level tool, not an implementation detail

---

### ~~E16 Validator as Bundled Skill Script~~ — Implemented (v0.10.1–0.10.2)

Implemented as `implementations/claude-code/scripts/validate-impl.sh`, symlinked into `~/.claude/skills/saw/scripts/`. Validates all `type=impl-*` typed blocks (file-ownership, dep-graph, wave-structure, completion-report) with structural regex checks. Exits 0 on pass, 1 on failure with plain-text errors the orchestrator passes directly to Scout. `saw-skill.md` step 3 calls it by relative path: `bash scripts/validate-impl.sh "<impl-doc>"`. Script outputs go to stderr (progress) and stdout (errors), following the Agent Skills cross-platform spec for deterministic skill logic.

v0.10.2 added:
- **E16A:** Required block presence enforcement — docs with any typed blocks must include all three of `impl-file-ownership`, `impl-dep-graph`, and `impl-wave-structure`, or validation fails with a distinct error per missing type. Pre-v0.10.0 docs (no typed blocks) are unaffected.
- **E16C:** Out-of-band dep graph detection — a second scan pass checks all plain fenced blocks for `[A-Z]` agent refs + the word `Wave`; emits a WARNING to stdout but does not cause exit 1. Orchestrator includes E16C warnings in the Scout correction prompt.

---



### Local-First Web UI (`saw serve`)

**Current state:** SAW runs entirely in the terminal. The IMPL doc review checkpoint is opening a markdown file. Wave execution is opaque background processes.

**Proposed:** `saw serve` starts a local web server (default `localhost:7432`). No hosted infrastructure, no auth, no data leaves the machine.

**Core surfaces:**

**Review screen** — shown after `/saw scout`, before `/saw wave`. Displays:
- Suitability verdict with rationale
- Pre-mortem failure modes with likelihood/impact
- Wave structure (visual, not text)
- File ownership table — each agent's files, color-coded by agent
- Interface contracts — exact signatures, frozen at this point
- Approve / Request Changes / Reject buttons

**Wave execution board** — shown during `/saw wave`. Live updates:
- Agent cards showing status (pending / running / complete / failed)
- Completion reports streaming in as agents write to IMPL doc
- Failure type badge on failed agents with appropriate action button
- Merge progress after wave completes

**Project memory** — `docs/SAW.md` viewer/editor. Shows established decisions, conventions, completed features timeline.

**Engine:** `scout-and-wave-go` exposes HTTP + SSE API. Web frontend connects to it. IMPL doc is the source of truth — UI reads from and writes to it, never to a separate database.

**Transport decisions:**
- Live wave events (agent status, output streaming) → SSE. One-way server→client, works through proxies without config, browser auto-reconnects.
- Plan edits (user submits changes to dep graph, wave structure, interface contracts) → HTTP POST. Simple, sufficient for single-user local tool.
- WebSocket deferred — only needed if real-time collaborative editing becomes a requirement. SSE stream is unaffected either way; only the edit path would change.

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

`scout-and-wave-go` is the engine. The `/saw` Claude Code skill and the web UI are both clients on top of it.
