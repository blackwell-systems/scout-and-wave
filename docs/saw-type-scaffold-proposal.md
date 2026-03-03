# SAW Type Scaffold Proposal: Removing Wave 0 via Scout-Produced Coordination Artifacts

**Status:** Proposal

**Date:** 2026-03-03

---

## Discussion: How We Got Here

This proposal emerged from a `/saw-teams` test run on the claudewatch
`get_drift_signal` feature (2026-03-03). The wave worked cleanly — 2 parallel
agents, no merge conflicts, all tests green — but it surfaced a question about
the protocol's design: *when does it make sense to use SAW for a 1-agent wave?*

**The 1-agent wave question.** After the wave completed, we asked: should a
1-agent wave exist in SAW at all? The solo-agent short-circuit in both skill
files silently degrades to the standard Agent tool when a wave has exactly one
agent. That's the worst of both worlds: the user invoked SAW and gets standard
behavior with no indication anything changed. The short-circuit is an invisible
fallback, not a deliberate design choice.

**The Wave 0 smell.** Digging further: Wave 0 is the most common source of
solo-agent waves. It exists because some work is a prerequisite for everything
else — shared types, interface stubs, scaffolding that downstream agents depend
on. The protocol accommodates this by defining Wave 0 as "a single solo agent
that gates all downstream waves." But this encoding is wrong. A wave of one is
not a wave. The parallel execution machinery, worktree isolation, disjoint
ownership, merge verification — all of that overhead exists to coordinate
multiple agents. Applied to a single agent it is pure ceremony.

**Wave 0 as structural smell.** Deeper still: Wave 0 often signals that the
suitability gate was soft-passed. Investigation-first work that cannot be
specified upfront should fail the gate (NOT SUITABLE). Wave 0 as a "SUITABLE
WITH CAVEATS" workaround hides this — it encodes "not ready for SAW" as a wave
number instead of forcing the work to be resolved before the Scout runs.

**The existing Scout judgment.** The key observation: the Scout already knows
what Wave 0 needs to do. It reasons about what must exist before Wave 1 agents
can start. It has the dependency graph, the interface contracts, the full
codebase in context. It already makes the right call — it just currently
delegates the execution to a Wave 0 agent rather than doing the setup itself.
This means no new decision framework is needed. The Scout's judgment is already
correct. Only the mechanism changes: instead of writing a Wave 0 agent prompt,
the Scout produces the prerequisite output directly.

**The type scaffold insight.** This leads to the type scaffold concept: the
Scout can produce source files whose sole purpose is to define cross-agent
interfaces as compilable code. These are coordination artifacts, not product
code. The Scout already produces the IMPL doc (a coordination artifact in
markdown). Producing a `types.go` stub alongside it is the same thing expressed
in a different format — one that agents can import and compile against rather
than just read.

**Existing behavior preserved.** Crucially, this keeps the existing behavior
while fixing the protocol purity. The actual execution order is unchanged:
Scout runs → prerequisite output exists → Wave 1 agents start. The only
difference is attribution: that prerequisite output comes from the Scout phase
rather than Wave 0. Users who were relying on Wave 0 for setup work get the
same outcome. There are no new commands, no new workflow steps, no visible
change from the outside.

**The Scout does not need to be told.** The Scout already knew what Wave 0
needed to do because it wrote the Wave 0 agent prompt. Moving the work from
Wave 0 to the Scout phase means the Scout does not need a new decision tree —
it just needs permission (constraint relaxation) and a format spec (what a
scaffold file looks like and how to reference it in the IMPL doc).

---

## Problem

SAW protocol has a structural smell: the **solo Wave 0**. Wave 0 exists to handle
prerequisite work — creating shared types, stubs, or interfaces that downstream
agents depend on before they can start. A Wave 0 agent is a single agent running
sequentially before the parallel wave machinery begins.

The smell: a wave of one defeats the entire point of wave machinery. Disjoint
ownership, parallel execution, merge verification — all of that overhead exists
to coordinate multiple agents. Applied to a single agent it is pure ceremony with
no benefit. The protocol currently justifies this as "Wave 0 in bootstrap projects
is always a solo wave" and handles investigation-first items as "Wave 0 (a single
solo agent, not parallel), which gates all downstream waves."

The deeper issue: Wave 0 encodes "not ready for parallel execution" into the
protocol as a first-class state, rather than resolving it before the protocol
begins. Investigation-first work that cannot be resolved before the Scout runs
should fail the suitability gate (NOT SUITABLE), not be given a wave number.

---

## Observation

The Scout already knows what Wave 0 needs to do. It reasons:
*what must exist before Wave 1 agents can start?* It then writes a Wave 0 agent
prompt describing that work. The Scout has the dependency graph, the interface
contracts, and the full codebase in context. It already makes the right judgment
call. It just currently delegates the execution to a Wave 0 agent rather than
doing the setup itself.

This means the Scout does not need a new decision framework to replace Wave 0.
The judgment is already there. What changes is only the *mechanism*: instead of
writing a Wave 0 agent prompt, the Scout produces the prerequisite output directly
as coordination artifacts.

---

## Proposed Change

### 1. Scout produces type scaffold files

Expand the Scout's output from one coordination artifact (the IMPL doc) to
optionally include **type scaffold files** — source files whose sole purpose is to
define cross-agent interfaces so Wave 1 agents can compile against them.

Type scaffolds are coordination artifacts, not product code. The distinction:

| Type scaffold | Product code |
|---|---|
| Defines types, constants, interfaces | Implements behavior |
| Exists to express the interface contract as compilable code | Exists to ship |
| Written by the Scout before any wave runs | Written by Wave agents |
| Content is fully determined by the interface contracts the Scout already produces | Content requires implementation decisions |
| Would be identical if the Scout ran twice | Depends on agent choices |

Type scaffolds belong in the source tree (e.g. `internal/types/feature.go`), not
in `docs/`. They are real source files that agents import. The Scout owns them
during the Scout phase; they are committed as part of the Scout's output before
any worktrees are created.

**Permission change required:** The Scout's current constraint is:

> "You are read-only. Do not create, modify, or delete any source files other
> than the coordination artifact at `docs/IMPL-<feature-slug>.md`."

This becomes:

> "You may create type scaffold files in addition to the IMPL doc. Type scaffold
> files contain only type definitions, constants, and interface declarations — no
> function bodies, no behavior. They are coordination artifacts expressed as
> compilable code. Do not create, modify, or delete any other source files."

### 2. IMPL doc references scaffolds explicitly

When the Scout produces type scaffold files, the IMPL doc gains a new
**Scaffolds** section listing:

- File paths created
- What each file contains
- How agents should reference them (import path, etc.)
- That agents must not redefine types already declared in scaffolds

Example:

```markdown
## Scaffolds

The Scout has created the following type scaffold files. Wave agents must import
these rather than defining their own versions of these types.

| File | Contents | Import path |
|---|---|---|
| `internal/types/drift.go` | `DriftSignalResult`, `LiveDriftStats` | `github.com/org/repo/internal/types` |
```

### 3. Suitability gate: investigation-first items become NOT SUITABLE

Remove Wave 0 as the resolution for investigation-first blockers. The suitability
gate question 2 becomes:

> **Investigation-first items.** Does any part of the work require root cause
> analysis before implementation: a crash whose source is unknown, a race
> condition that must be reproduced before it can be fixed, behavior that must be
> observed to be understood? If so, the work is NOT SUITABLE for SAW. Recommend
> resolving the investigation sequentially first, then running `/saw scout` once
> the work is fully specifiable.

The current "SUITABLE WITH CAVEATS → Wave 0" path is removed. Investigation-first
work is either resolved before the Scout runs (and then SAW proceeds normally), or
it fails the gate.

### 4. Solo-agent wave short-circuit removed

The solo-agent short-circuit logic is removed from all skill and worktree files.
Every wave must have ≥2 agents with disjoint file ownership. If a wave decomposes
to one agent, the Scout should either:

- Expand scope to find a second disjoint file to assign to a second agent, or
- Declare the wave NOT SUITABLE (not enough parallelism to justify the overhead)

The short-circuit in current files:

| File | Location |
|---|---|
| `prompts/saw-worktree.md` | Solo Agent Check section (lines 50–63) |
| `saw-teams/saw-teams-worktree.md` | Solo Agent Check section (lines 56–74) |
| `saw-teams/saw-teams-skill.md` | Step 2 solo check (line 47) |

### 5. Wave 0 removed from the spec

Remove all first-class Wave 0 references:

| File | Change |
|---|---|
| `PROTOCOL.md` | Remove solo wave definition (lines 167–176); remove mandatory Wave 0 from bootstrap description (lines 451–453) |
| `prompts/scout.md` | Remove Wave 0 from suitability gate (lines 44, 134–135); remove from output format (lines 215–219, 327–335) |
| `prompts/saw-skill.md` | Update bootstrap description (line 48) |
| `saw-teams/saw-teams-skill.md` | Update bootstrap description (line 129) |
| `prompts/saw-bootstrap.md` | Reframe: Wave 0 pattern becomes "Scout produces shared types scaffold; Wave 1 is the first parallel wave" |

---

## What Does Not Change

- The Scout's analysis and judgment — same reasoning, different output mechanism
- The IMPL doc format — gains a Scaffolds section, all other sections unchanged
- Wave sequencing — Wave 1 still cannot start until Scout output (now including
  scaffolds) is committed and reviewed
- Human review checkpoint — still happens after Scout output, before any wave runs
- Invariants I1–I5 — unchanged; scaffolds are committed by the Scout, not a wave
  agent, so no ownership conflict arises
- The suitability gate's other four questions — unchanged

---

## Correctness Guarantee

The protocol's existing guarantee: *if the suitability gate passes and
verification gates pass, the work was safe to parallelize.*

With this change: *if the suitability gate passes, prerequisites were resolved in
the Scout phase. Wave 1 agents have everything they need before they start.*

The guarantee strengthens slightly: there is no longer a sequential wave that
could fail partway and leave Wave 1 agents with incomplete prerequisites. The
Scout either produces complete scaffolds (and the review checkpoint catches
incompleteness) or it does not produce them at all.

---

## Implementation Plan

Two waves. Wave 1 is a prerequisite for Wave 2.

### Wave 1: Remove Wave 0 and solo-agent short-circuit

Pure deletion and reframing. No new behavior, no judgment rules. All changes are
to existing files — removing sections that document Wave 0 and the solo-agent
short-circuit.

**Files:**

| File | Agent | Change |
|---|---|---|
| `PROTOCOL.md` | A | Remove solo wave section (lines 167–176); remove Wave 0 from bootstrap section (lines 451–453) |
| `prompts/scout.md` | A | Remove Wave 0 from suitability gate and output format (lines 44, 134–135, 215–219, 294, 327–335) |
| `prompts/saw-worktree.md` | B | Delete Solo Agent Check section (lines 50–63) |
| `saw-teams/saw-teams-worktree.md` | B | Delete Solo Agent Check section (lines 56–74) |
| `saw-teams/saw-teams-skill.md` | B | Delete solo agent check step (line 47) |
| `prompts/saw-skill.md` | B | Update bootstrap description (line 48) |
| `saw-teams/saw-teams-skill.md` | B | Update bootstrap description (line 129) — same file as above |
| `prompts/saw-bootstrap.md` | A | Reframe Wave 0 as Scout scaffold phase |

Agent A: PROTOCOL.md + scout.md + saw-bootstrap.md
Agent B: saw-worktree.md + saw-teams-worktree.md + saw-teams-skill.md + saw-skill.md

**Verification:** `grep -r "Wave 0\|solo wave\|solo agent" prompts/ saw-teams/` returns
only backward-compatibility notes (if any) and the pipeline proposal doc.

### Wave 2: Add type scaffold mechanics

Adds new capability: the Scout's permission change, scaffold file format spec,
IMPL doc Scaffolds section format, and agent-template reference field.

**Files:**

| File | Agent | Change |
|---|---|---|
| `prompts/scout.md` | C | Relax read-only constraint; add scaffold creation guidance and output format |
| `PROTOCOL.md` | C | Add type scaffold definition; update Scout mandate section |
| `prompts/agent-template.md` | D | Add Field referencing scaffolds (between Fields 3 and 4, or as new Field 3b) |
| `saw-teams/teammate-template.md` | D | Same scaffold reference field |

Agent C: scout.md + PROTOCOL.md
Agent D: agent-template.md + saw-teams/teammate-template.md

**Interface contract (Wave 2 agents need this from Wave 1 output):**
Wave 1 must complete and Wave 2 agents must read the updated PROTOCOL.md and
scout.md before writing. Wave 2 is gated on Wave 1.

**Verification:** Run `/saw scout "add a caching layer"` on a test project and
confirm the Scout (a) does not produce a Wave 0 agent prompt, (b) produces a type
scaffold file when cross-agent types are needed, (c) produces an IMPL doc with a
Scaffolds section when scaffolds were created.

---

## Open Questions

1. **Scaffold location:** Should scaffold files go in the actual source tree
   (e.g. `internal/types/`) or in a staging area (e.g. `docs/scaffolds/`) that
   agents copy from? Source tree is simpler and immediately importable; staging
   area makes the coordination-artifact status more explicit but adds a copy step.
   Current lean: source tree, same as where Wave 0 agents would have put them.

2. **Scaffold compilation gate:** Should the Scout verify that scaffold files
   compile before writing the IMPL doc? Current lean: yes — a scaffold that does
   not compile is a broken coordination artifact and should be caught before
   agents start, not discovered by Wave 1 agents mid-execution.

3. **Mixed waves:** What if a wave has some agents that need scaffold output and
   some that don't? Current lean: scaffolds are committed before any worktrees are
   created, so all agents in all waves see them equally. No special handling needed.

4. **Backward compatibility:** IMPL docs produced before this change may reference
   Wave 0 in their status checklists. The Orchestrator should handle these
   gracefully — treat Wave 0 as a legacy pattern, execute it as a single-agent
   wave on main (same behavior as today's short-circuit), and note the deprecation.

---

## Status

- [ ] Wave 1 IMPL doc written
- [ ] Wave 1 complete
- [ ] Wave 2 IMPL doc written
- [ ] Wave 2 complete
- [ ] Integration test: Scout produces scaffold on real project
- [ ] CHANGELOG updated
