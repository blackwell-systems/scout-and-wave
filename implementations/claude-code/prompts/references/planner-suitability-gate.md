<!-- Part of planner agent procedure. Loaded by validate_agent_launch hook. -->
# Program Suitability Gate

Before beginning project analysis, run this gate to determine whether the project benefits from multi-IMPL orchestration. Answer these four questions:

**1. Feature Independence**
Can the project be decomposed into 3+ features with bounded cross-feature dependencies?

If every feature depends on every other feature in complex ways, a single IMPL doc is better. Look for natural architectural boundaries: packages, services, layers, subsystems, or distinct functional areas.

**2. Tier Depth**
Are there at least 2 tiers of features (where Tier 2 depends on Tier 1 outputs)?

If all features are completely independent with no dependencies, just run separate Scouts — no Program Layer needed. The value of the Program Layer is coordinating dependencies across features.

**3. Shared Types**
Are there cross-feature types or APIs that need formal contracts?

If features are truly independent with no shared types, program contracts add overhead without value. Look for: core domain types (User, Session, Account), protocol definitions (API response schemas), or shared infrastructure types (Database connection, Config).

**4. Scale Justification**
Is the total estimated work >8 agents?

Below this threshold, a single IMPL doc handles the work fine. Program Layer overhead is only justified for projects that would produce 10+ agents across multiple features.

**Verdicts:**

- **PROGRAM_SUITABLE** — All four questions resolve clearly. Proceed with full analysis and produce the PROGRAM manifest.

- **SINGLE_IMPL_SUFFICIENT** — Project is small enough or cohesive enough for a single IMPL doc. Write a minimal YAML manifest to `docs/PROGRAM-<slug>.yaml` with `state: "NOT_SUITABLE"` and a brief explanation. Recommend `/saw bootstrap` or `/saw scout` instead.

- **NOT_DECOMPOSABLE** — Features are too entangled for safe parallel execution at any level. Write a minimal YAML manifest with `state: "NOT_SUITABLE"` and explain why. Recommend sequential implementation or architectural refactoring before SAW execution.

**Time-to-value estimate format:**

When emitting the verdict, include estimated times for PROGRAM_SUITABLE projects:

```
Estimated times:
- Planner phase: ~X min (project analysis, program manifest)
- Scout phase: ~Y min (N features × M min avg)
- Total agent execution: ~Z min (estimated agents across all features)
- Merge & verification: ~W min
Total SAW time: ~T min

Sequential baseline: ~B min
Time savings: ~D min (P% faster)

Recommendation: [Clear speedup | Marginal gains | Overhead dominates].
```
