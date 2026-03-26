# Design Note: Top-Down Program Creation

**Status:** Gap identified — not yet designed
**Created:** 2026-03-25
**Relates to:** `docs/program-layer.md`, `/saw program plan/execute`

---

## Two Directions of Program Creation

### Bottom-Up (implemented)

Individual scouts run first → IMPLs exist independently → `/saw program --impl s1 s2 ...` assembles them into a PROGRAM manifest with auto-tiering.

The work happened before the program was defined. The Planner reverse-engineers a tier structure from existing IMPLs based on declared dependencies. Inter-IMPL constraints are inferred after the fact.

### Top-Down (gap)

Start with a high-level vision → `/saw program plan "description"` → Planner decomposes into features with tier structure and dependency constraints → Scouts run per-feature → IMPLs produced already slotted into the program.

The program structure precedes the implementation work. Scouts run with awareness of their tier context and inter-IMPL constraints.

---

## The Gap

`/saw program plan` and `/saw program execute` are meant to be the top-down path. The Planner produces a PROGRAM manifest with feature descriptions. But:

1. **Scouts run independently** — each Scout analyzes its feature in isolation, unaware of sibling features or program-level constraints. A Scout planning `engine-reference-injection` doesn't know it must depend on `*-prompt-extraction` IMPLs completing first.

2. **Dependencies are declared post-hoc** — the PROGRAM manifest is assembled after Scouts complete. Inter-IMPL dependency constraints (`tier: 2, depends_on: [scout-prompt-extraction, wave-agent-prompt-extraction]`) are either inferred by the Planner from IMPL content or specified manually. There is no mechanism for the Planner to pre-wire these into the Scout's context.

3. **No program context during Scout** — when a Scout runs under a program, it has no access to the program's tier structure, sibling IMPLs, or the Planner's decomposition rationale. If the Planner decides that `engine-reference-injection` is Tier 2, the Scout has no way to know it should design its IMPL to depend on Tier 1 outputs.

---

## What True Top-Down Requires

### 1. Planner produces a structured decomposition, not just a feature list

Current PROGRAM manifest describes features with text descriptions. A top-down Planner needs to produce:

- **Tier assignments** with explicit rationale
- **Inter-IMPL dependency declarations** (what must complete before what)
- **Interface constraints** across IMPLs — if IMPL A produces `references/scout-procedure.md` and IMPL B consumes it via the engine loader, the Planner should declare this as a cross-IMPL contract

### 2. Scouts run with program context

When a Scout is launched under a top-down program, it should receive:
- Its tier assignment and why
- Names and purposes of sibling IMPLs (not their full content — just enough to avoid overlap and align on shared artifacts)
- Any cross-IMPL interface constraints the Planner declared
- The Planner's rationale for the decomposition

This lets the Scout design its IMPL to fit into the larger program structure rather than optimizing for its feature in isolation.

### 3. Program manifest is the source of truth from the start

In bottom-up creation, the PROGRAM manifest is assembled after all Scouts complete. In top-down creation, the PROGRAM manifest exists before any Scout runs. Scouts update it rather than it being assembled from Scout output.

---

## Design Questions

1. **How much program context is too much for a Scout?** Giving a Scout full sibling IMPL content would bloat its context. The right granularity is probably: feature names, tier, shared artifacts, declared dependencies — not full IMPL docs.

2. **Who resolves conflicts between Planner intent and Scout findings?** The Planner may assign a feature to Tier 1, but the Scout's suitability gate may find a dependency on a Tier 2 feature. Resolution needs a defined protocol (E-rule or Orchestrator decision point).

3. **Should the Planner run incrementally or once?** In a large program, new Scout findings may require the Planner to revise the tier structure (`/saw program replan`). Top-down creation may need a tighter Planner-Scout feedback loop than current implementation supports.

4. **How does this interact with cross-repo programs?** When IMPLs span multiple repos (as in the progressive disclosure program), top-down planning requires the Planner to understand both repos' structure before assigning features to tiers.

---

## Relationship to Current Implementation

The bottom-up path (`/saw program --impl`) is working. Top-down (`/saw program plan/execute`) partially works — the Planner decomposes features and Scouts run, but the program context is not passed to Scouts and inter-IMPL contracts are not pre-wired.

The gap is most visible when:
- A program has cross-IMPL dependencies on shared artifacts (files one IMPL creates that another consumes)
- The tier structure is non-obvious and needs the Planner's rationale to make the Scout's IMPL design correct
- Multiple IMPLs in the same tier touch overlapping areas and need explicit non-overlap guidance from the Planner

---

## Proposed Next Step

Design a `program-context.yaml` sidecar that the Planner writes alongside the PROGRAM manifest. This carries per-IMPL Scout context: tier, dependencies, shared artifacts, sibling features. The Orchestrator injects this into each Scout's prompt when launching under a top-down program. The Scout writes its IMPL with this context rather than in isolation.

This is a protocol addition (new execution rule, new Planner output format) and an engine change (pass context to Scout launcher). Scope as a separate IMPL when ready to implement.
