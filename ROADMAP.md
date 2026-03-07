# Scout-and-Wave Roadmap

Items are grouped by theme, not priority. Nothing here is committed or scheduled.

---

## Protocol Enhancements

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

### Pre-Mortem in Scout Output

**Current state:** Scout runs the suitability gate (P1-P5) and produces a binary SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS verdict.

**Problem:** The verdict tells you whether to proceed, but not what could go wrong if you do. Agents discover failure modes at execution time rather than surfacing them at the review checkpoint.

**Proposed:** Add a `## Pre-Mortem` section to the IMPL doc, written by the Scout before the human review checkpoint:

```yaml
pre_mortem:
  overall_risk: low | medium | high
  failure_modes:
    - scenario: "Agent B cannot compile without Agent A's type definitions"
      likelihood: medium
      impact: high
      mitigation: "Scaffold Agent creates shared types before Wave 1"
    - scenario: "Interface contract between waves is underspecified"
      likelihood: low
      impact: high
      mitigation: "Scout specifies exact function signatures, not prose descriptions"
```

The pre-mortem appears on the IMPL doc review screen in the web UI — it's the first thing the human reads before approving the wave structure. Forces the scout to think adversarially about its own plan.

**Protocol changes required:** New section in `protocol/message-formats.md`, scout output format in `scout.md`.

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

### IMPL Doc Completion Lifecycle

**Current state:** The Status table in IMPL docs tracks individual agents (TO-DO → COMPLETE), but there is no final "this IMPL is done" marker. Completed IMPL docs remain in `docs/IMPL/` indefinitely and continue appearing in the `saw serve` picker alongside active work.

**Problem:** No protocol step closes the loop. The orchestrator stops after the last wave's post-merge verification, leaving the IMPL doc in a liminal state — all agents complete, but the document itself is unmarked. This creates clutter in the picker and ambiguity about whether follow-up work is expected.

**Proposed:** Add a completion lifecycle with three steps:

1. **Orchestrator marks completion.** After the final wave's post-merge verification passes, the orchestrator writes `## Status: COMPLETE` at the top of the IMPL doc (below the title). This is a protocol-level state transition, not a human action.

2. **Web UI distinguishes complete IMPLs.** The picker shows completed docs with a muted style or under a "Completed" accordion. Active docs appear first. Completed docs are still accessible for reference.

3. **Optional archival.** Users may move completed docs to `docs/IMPL/done/` or delete them. This is a user choice, not a protocol requirement — the `COMPLETE` marker is sufficient for the orchestrator and web UI to behave correctly.

**New E-rule:** After the final wave merges and post-merge verification passes, the orchestrator MUST write `## Status: COMPLETE` to the IMPL doc before any commit or push. This is the formal close of the IMPL lifecycle.

**Protocol changes required:** New E-rule in `protocol/execution-rules.md`, IMPL doc schema update in `protocol/message-formats.md` (add `## Status` as a recognized top-level section), `saw serve` picker logic to read and filter by status, orchestrator skill update to write the marker.

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

## Web Product

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

**Engine:** `scout-and-wave-go` exposes HTTP + WebSocket API. Web frontend connects to it. IMPL doc is the source of truth — UI reads from and writes to it, never to a separate database.

---

## Implementation Notes

Items above are not independent — the failure taxonomy feeds the web UI action buttons, the pre-mortem feeds the review screen, `docs/SAW.md` feeds both the scout and the project memory view. They are designed to ship together as a coherent v1.0 rather than as separate incremental additions.

`scout-and-wave-go` is the engine. The `/saw` Claude Code skill and the web UI are both clients on top of it.
