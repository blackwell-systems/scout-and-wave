# Scaffold Agent: Design Rationale

## The Problem

Before any Wave Agents can run in parallel, shared interface contracts need to
exist as compiled source files — type definitions, traits, interfaces — that
all agents can import. Without them, agents can't build against each other's
types, and parallel execution breaks down at the first cross-package reference.

This creates a sequencing problem: *something* has to produce those files before
the wave launches.

## What We Tried First (v0.5.x)

The simplest answer was to let the Scout do it. Scout already analyzes the
codebase and writes the IMPL doc — why not also write the scaffold files?

This worked functionally. Wave Agents got their type contracts. Builds passed.

But it had a structural problem: **Scout committed scaffold source files before
the user ever saw the IMPL doc.** By the time the user reviewed the interface
contracts, they were already locked in code. The review gate was cosmetic.

It also blurred Scout's role. Scout's defining rule is: *you may create one
artifact — the IMPL doc.* Adding scaffold file production as a carve-out made
the rule read: *you may create one artifact… except also source files when
needed.* That kind of exception is a signal that a new participant is hiding
inside the existing one.

## Why the Other Options Didn't Work

**Option A: Spawn Scout twice.**
Scout could analyze + write the IMPL doc in one pass, then be spawned again to
create scaffold files after the user approves. But async agents run to
completion — there's no pause/resume. Spawning Scout twice means re-establishing
context from scratch. It also means Scout re-reads the codebase and re-runs its
analysis, which is redundant and expensive.

**Option B: Orchestrator creates the scaffold files.**
The Orchestrator is the synchronous agent that drives protocol state transitions.
Having it write source code violates I6 (role separation): the Orchestrator does
not perform Scout or Wave Agent duties. If the Orchestrator is writing type
definitions, it has become an implementer — which breaks observability, pollutes
the orchestrator's context window, and makes the role boundaries meaningless.

**Option C: Keep v0.5.x (Scout creates scaffolds).**
Functional, but the review gate stays cosmetic and Scout's role definition
stays muddled.

## The Scaffold Agent (v0.6.0)

A narrow, new participant with a single responsibility: read the approved IMPL
doc Scaffolds section, create the specified source files, verify they compile,
commit to HEAD, and update the status field. That's it.

The flow with Scaffold Agent:

```
Scout          → writes IMPL doc (analysis + interface specs + Scaffolds section)
                 ↓
Human review   → approves interface contracts before any code is written
                 ↓
Scaffold Agent → materializes approved contracts as compiled source files
                 ↓
Wave Agents    → implement in parallel against the scaffold files
```

The review gate is structural again. Scout's role is pure analysis. The
Orchestrator/lead doesn't do implementation work. I6 is clean.

## Why This Is the Cleanest Design

The Scaffold Agent is small by design. It has no 9-field template, no worktree,
no completion report, no merge step. It's an implementation step, not a
coordination step. It runs once, produces files that are committed to the
shared HEAD, and exits. Wave Agents treat those files as existing code —
they import from them, they don't own them.

The key insight is that the protocol already had the right shape: Scout
(planning), review gate (human checkpoint), parallel execution (wave agents).
The scaffold file problem was just a missing step at the checkpoint — something
had to happen between human approval and wave launch. The Scaffold Agent names
that step without changing anything else.

## What Changed

On the prompt side:
- `prompts/scaffold-agent.md` — the new participant prompt
- `prompts/scout.md` — Step 5 reverted: Scout specifies scaffold file contents
  in the IMPL doc (exact types, signatures, import paths) but does not create
  them. Rules restored: one artifact only.
- Skill files — conditional Scaffold Agent spawn added after user review, before
  worktrees are created
- Agent/teammate templates — Field 3 updated to credit Scaffold Agent as the
  source of scaffold files

On the invariant side:
- I2 updated to name both roles explicitly: "The Scout defines all interfaces
  that cross agent boundaries in the IMPL doc. The Scaffold Agent implements
  them as type scaffold files committed to HEAD after human review, before any
  Wave Agent launches."

Nothing else changed. The protocol structure, wave execution, merge procedure,
and all other invariants are identical to v0.5.x.
