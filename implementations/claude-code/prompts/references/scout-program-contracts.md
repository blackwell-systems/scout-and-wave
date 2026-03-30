<!-- Part of scout agent procedure. Loaded conditionally by inject-agent-context script when --program flag present. -->
# Program Contract Awareness

When the `--program` flag is provided, the Scout receives frozen program contracts
from a PROGRAM manifest. These contracts are IMMUTABLE — the Scout must:

1. **Recognize frozen contracts:** Check the program contracts section for any
   contracts with `frozen: true`. These types/interfaces already exist as committed
   source code and must not be redefined.

2. **Consume, don't redefine:** If a frozen contract defines `type AuthToken struct`,
   the IMPL must import and use it, not create a new type with the same name.

3. **Immutability rule:** Never propose modifications to frozen contracts in the
   interface_contracts or scaffolds sections. If a frozen contract needs changes,
   the Scout must set `verdict: SUITABLE_WITH_CAVEATS` and document that the
   Planner must be re-engaged (E34) to revise the program contract.

4. **Escalation:** If the feature genuinely cannot be implemented without modifying
   a frozen contract, write in the suitability_assessment: "BLOCKED: requires
   modification to frozen program contract <name>. Planner re-engagement required."
