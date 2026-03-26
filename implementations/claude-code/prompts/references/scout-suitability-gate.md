<!-- Part of scout agent procedure. Loaded by validate_agent_launch hook. -->
# Suitability Gate

Run this gate before any file analysis. If the work is not suitable, stop
early; do not produce a full IMPL doc with agents.

Answer these five questions:

1. **File decomposition.** Can the work be assigned to ≥2 agents with
   disjoint file ownership? Count the distinct files that will change and
   check whether any two tasks require *conflicting modifications* to the
   same file. If every change funnels through a single file, there is
   nothing to parallelize.

   Append-only additions to a shared file (config registries, module
   manifests such as `go.mod` or root `Cargo.toml`, index files) are not
   a decomposition blocker; make those files orchestrator-owned and apply
   the additions post-merge after all agents complete.

2. **Investigation-first items.** Does any part of the work require root
   cause analysis before implementation: a crash whose source is unknown,
   a race condition that must be reproduced before it can be fixed, behavior
   that must be observed to be understood? If so, agents cannot be written
   for those items yet; they must be resolved before SAW begins.

3. **Interface discoverability.** Can the cross-agent interfaces be defined
   before implementation starts? If a downstream agent's inputs cannot be
   specified until an upstream agent has already started implementing, the
   contract cannot be written and agents will contradict each other.

4. **Pre-implementation status check.** If the work is based on an audit report,
   bug list, or requirements document, check each item against the current
   codebase to determine implementation status:

   > **CONTEXT.md cross-check:** Also check `established_interfaces` for any
   > interfaces that overlap with the feature. Reference existing interfaces
   > rather than redefining them.

   ```bash
   sawtools analyze-suitability <requirements-file> --repo-root <repo-path>
   ```

   Returns per-requirement status: DONE, PARTIAL, or TODO. Use this to adjust
   agent prompts:
   - **DONE** with good tests → skip agent or change to "verify + add coverage"
   - **PARTIAL** → agent prompt says "complete the implementation"
   - **TODO** → proceed as planned

   Document the results in the Suitability Assessment (e.g., "3 of 19 findings
   already implemented; agents F, G, H adjusted to add test coverage only").

5. **Parallelization value check.** Estimate whether SAW saves time over
   sequential implementation. Raw agent count is not a reliable indicator;
   2 agents with complex build/test cycles benefit more from parallelization
   than 4 agents doing simple documentation edits. Evaluate these factors:

   - **Build/test cycle length:** If the full build + test cycle takes >30
     seconds (e.g., `cargo test`, `go build && go test`, `npm test`), each
     parallel agent runs that independently. Longer cycles amplify
     parallelization benefit.
   - **Files per agent:** More files per agent means more implementation time,
     which means more to parallelize. Agents touching 3+ files each are
     good candidates.
   - **Agent independence:** Fully independent agents (single wave) get maximum
     parallelization. Multi-wave chains reduce the benefit since waves run
     sequentially.
   - **Task complexity:** Code changes with logic, tests, and edge cases
     benefit from parallelization. Simple find-and-replace or documentation
     edits have low per-agent time, so SAW overhead dominates.

   Apply this guidance:

   - **High parallelization value:** Agents are independent AND (build/test
     cycle >30s OR avg files per agent ≥3 OR tasks involve non-trivial logic).
     Proceed as SUITABLE.
   - **Low parallelization value:** Tasks are simple edits, documentation-only,
     or trivially fast to implement sequentially. Recommend sequential
     implementation (SAW overhead exceeds parallelization benefit for this work).
   - **Coordination value independent of speed:** Even when parallelization
     savings are marginal, the IMPL doc provides value as an audit trail,
     interface spec, or progress tracker. Flag as SUITABLE WITH CAVEATS and
     note that the value is coordination, not speed.

**Emit a verdict before proceeding:**

- **SUITABLE:** All five questions resolve cleanly. Proceed with full
  analysis and produce the IMPL doc.
- **NOT SUITABLE:** One or more questions is a hard blocker (e.g., only
  one file changes, or root cause of a crash is completely unknown). Write
  a minimal YAML manifest to `docs/IMPL/IMPL-<slug>.yaml` with `verdict: "NOT_SUITABLE"`
  and a brief explanation. Do not include agent definitions.
  Recommend sequential implementation or an investigation-first step.
- **SUITABLE WITH CAVEATS:** The work is parallelizable but has known
  constraints. Proceed, but document the caveats explicitly:
  - Interfaces that cannot yet be fully defined are flagged as blockers in
    the interface contracts section, with a note on how to resolve them.

**Time-to-value estimate format:**

When emitting the verdict, include estimated times:

```
Estimated times:
- Scout phase: ~X min (dependency mapping, interface contracts, IMPL doc)
- Agent execution: ~Y min (N agents × M min avg, accounting for parallelism)
- Merge & verification: ~Z min
Total SAW time: ~T min

Sequential baseline: ~B min (N agents × S min avg sequential time)
Time savings: ~D min (P% faster/slower)

Recommendation: [Marginal gains | Clear speedup | Overhead dominates].
[Guidance on whether to proceed]
```

Fill in X, Y, Z, T based on:
- Scout: 5-10 min for most projects (more for large dependency graphs)
- Agent: 2-5 min per agent for simple changes, 10-20 min for complex
- Merge: 2-5 min depending on agent count
- Sequential time: agent count × (agent time + overhead)

Record the verdict and its rationale in the IMPL doc under a
**Suitability Assessment** section that appears before the dependency graph.
