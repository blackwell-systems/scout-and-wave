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
