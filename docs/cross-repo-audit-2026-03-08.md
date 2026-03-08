# Cross-Repo Consistency Audit — 2026-03-08

Audit of all protocol and implementation documents following the v0.11.0 cross-repo wave support release.

---

## Scope

Files audited:

- `README.md`
- `protocol/README.md`
- `protocol/preconditions.md`
- `protocol/state-machine.md`
- `protocol/participants.md`
- `protocol/invariants.md`
- `protocol/execution-rules.md`
- `protocol/procedures.md`
- `protocol/message-formats.md`
- `implementations/claude-code/prompts/saw-skill.md`
- `implementations/claude-code/prompts/saw-bootstrap.md`
- `implementations/claude-code/prompts/saw-merge.md`
- `implementations/claude-code/prompts/saw-worktree.md`
- `implementations/claude-code/prompts/agent-template.md`
- `implementations/claude-code/prompts/agents/scout.md`
- `implementations/claude-code/prompts/agents/wave-agent.md`
- `implementations/claude-code/prompts/agents/scaffold-agent.md`

Grep searches run across all `.md` files for: `cross-repo`, `cross-repository`, `architectural constraint`, `not a fixable bug`, `Layer 2`.

---

## Issues Fixed

### 1. `README.md` — Version badge stale

**Problem:** Version badge showed `0.10.3` while v0.11.0 was released.

**Fix:** Updated badge to `0.11.0`.

### 2. `protocol/README.md` — Version number stale

**Problem:** "Current version: **0.10.3**" — not updated to reflect v0.11.0.

**Fix:** Updated to `0.11.0`.

### 3. `README.md` — Layer 2 row omits cross-repo omission note

**Problem:** The "Worktree Isolation Defense (5 layers)" table described Layer 2 as `isolation: "worktree"` parameter for each agent, with no mention that this layer is intentionally omitted for cross-repo waves. A reader following this table for a cross-repo wave would incorrectly apply Layer 2 and create worktrees in the wrong repository.

**Fix:** Added note to Layer 2 row: "Omitted for cross-repo waves (would create worktrees in the wrong repo); Layer 1 and Layer 3 provide isolation instead. See `saw-worktree.md` Cross-Repo Mode."

---

## No Issues Found

### Protocol documents (already correct)

All core protocol documents were updated as part of v0.11.0 and are consistent:

- **`protocol/participants.md`** — "Cross-repository orchestration limitation" section correctly replaced with "Cross-repository orchestration" covering both single-repo and cross-repo modes.
- **`protocol/execution-rules.md`** — E3 disjointness check correctly documented as per-repo; E4 Layer 2 correctly describes cross-repo omission as intentional correct protocol.
- **`protocol/invariants.md`** — I1 cross-repo scope note present and correct.
- **`protocol/procedures.md`** — Phase 1 Step 2 correctly describes cross-repo mode; merge note present; recovery section describes accidental Layer 2 use, not cross-repo as an error.
- **`protocol/message-formats.md`** — `Repositories:` frontmatter, `Repo` column, and `repo` completion report field all documented.
- **`protocol/preconditions.md`** — No cross-repo references needed; preconditions are agnostic to single-repo vs. cross-repo mode.
- **`protocol/state-machine.md`** — No cross-repo references needed; state machine is agnostic to isolation mode.

### Implementation prompt files (already correct)

- **`saw-worktree.md`** — Cross-Repo Mode section present and comprehensive (preflight, worktree creation, hook installation, merge, cleanup, key constraint on multi-repo agent ownership).
- **`saw-skill.md`** — Step 3 of the wave execution branch already has correct conditional: "If the orchestrator and target repository are the same, use `isolation: 'worktree'`. If orchestrating repo B from repo A, do NOT use the `isolation` parameter."
- **`agent-template.md`** — Field 0 already has "Cross-repository scenarios" paragraph explaining that Layer 2 is omitted for cross-repo and that the strict cd handles both scenarios uniformly.
- **`scaffold-agent.md`** — Step 0 already derives repository context from IMPL doc location, covering multi-repo sessions.
- **`saw-merge.md`** — Merge procedure is repo-agnostic; no single-repo-only assumptions.
- **`saw-bootstrap.md`** — Bootstrap is inherently single-repo (new project from scratch); no cross-repo language issues. "Architectural constraints" in saw-bootstrap.md refers to project architectural decisions (language, deployment), not the protocol limitation.
- **`agents/scout.md`**, **`agents/wave-agent.md`** — No stale cross-repo language.

### Historical documents (correctly preserved)

- **`CHANGELOG.md` v0.7.2 entry** — Describes "cross-repository orchestration limitation documented" as a historical fact of what was added in that version. This is accurate historical record and must not be changed. Similarly, the "Architectural constraint: This is not a fixable bug" language in the v0.7.2 section accurately describes the framing at the time; v0.11.0 supersedes it as the current protocol.
- **`docs/dogfooding-2026-03-06-protocol-extraction.md`** — Retrospective document written at the time of the 2026-03-06 dogfooding session. References to "Not a bug - architectural constraint" and "Document cross-repository limitation explicitly" are accurate historical records of what was understood at that time. Retrospective documents should not be retroactively edited to match subsequent protocol evolution.

### `CHANGELOG.md` v0.7.2 version table entry

The version table (line 24) reads: `[0.7.2] | 2026-03-06 | Protocol: mandatory worktree isolation (E4) and cross-repository orchestration limitation documented`. This is historical and correct — the limitation WAS documented in v0.7.2. The limitation was lifted in v0.11.0, which is also in the table. No change needed.

---

## Summary

**3 fixes made:**

| File | Change |
|------|--------|
| `README.md` | Version badge: `0.10.3` → `0.11.0` |
| `protocol/README.md` | Current version: `0.10.3` → `0.11.0` |
| `README.md` | Layer 2 row: added cross-repo omission note |

**All other documents are consistent with v0.11.0.** The protocol documents, implementation prompts, and skill file were all correctly updated as part of the v0.11.0 release. No stale "cross-repo is not supported" or "architectural constraint, not a fixable bug" language remains in any normative document.
