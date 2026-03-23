# Amend Commands — On-Demand Reference

## /saw amend

Extends or adjusts an in-progress IMPL doc without starting over.
Invalid after SAW:COMPLETE (E36).

### /saw amend --add-wave
Appends an empty wave skeleton to the IMPL doc. Use when you need additional
implementation work beyond what the original Scout planned. After adding the wave,
launch Scout in "extend" mode to populate agent definitions for the new wave.

**Orchestrator steps:**
1. Run: `sawtools amend-impl <manifest> --add-wave`
2. Review the JSON output (new wave number)
3. Re-engage Scout to define agents for the new wave: `/saw scout <description of new work>`
   with instruction to append agents to wave N of the existing IMPL

### /saw amend --redirect-agent <ID> --wave <N>
Updates an agent's task and re-queues it. Valid only if the agent has not yet
committed any work (E36b).

**Orchestrator steps:**
1. Run: `sawtools amend-impl <manifest> --redirect-agent <ID> --wave <N> --new-task "<new task>"`
2. If blocked (agent committed): use `sawtools amend-impl ... --add-wave` to add a
   follow-up wave with corrected work instead
3. Re-launch the agent: `/saw wave --impl <slug>`

### /saw amend --extend-scope
Re-engages Scout with the full current IMPL as context to produce additional waves.

**Orchestrator steps:**
1. Prepare context: read the current IMPL doc (use raw API or Read tool on the YAML file)
2. Launch Scout: `Agent(subagent_type=scout)` with prompt:
   "The following is the current IMPL doc in progress. Analyze the existing waves and
   contracts (treat them as frozen — do not modify). Add new waves for the following
   additional work: <description>. Output the full updated IMPL YAML."
3. Validate the Scout output: `sawtools validate --fix <manifest>`
4. Present updated IMPL for human review before executing new waves
