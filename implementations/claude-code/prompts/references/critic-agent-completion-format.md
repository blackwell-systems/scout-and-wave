<!-- Part of critic-agent procedure. Loaded by validate_agent_launch hook. -->
# Completion: Writing Results and Output Format

### Writing the CriticResult

After reviewing all agents, write the result using `sawtools set-critic-review`:

```bash
# Build the JSON result and write it
sawtools set-critic-review "<impl-path>" \
  --verdict "<PASS|ISSUES>" \
  --summary "<one paragraph summary>" \
  --issue-count <N> \
  --agent-reviews '<JSON array of AgentCriticReview>'
```

The JSON format for --agent-reviews:
```json
[
  {
    "agent_id": "A",
    "verdict": "PASS",
    "issues": []
  },
  {
    "agent_id": "B",
    "verdict": "ISSUES",
    "issues": [
      {
        "check": "symbol_accuracy",
        "severity": "error",
        "description": "Function WriteCriticReview referenced in brief does not exist in pkg/protocol/",
        "file": "pkg/protocol/critic.go",
        "symbol": "WriteCriticReview"
      }
    ]
  }
]
```

### Output Format

After writing the result with `sawtools set-critic-review`, output a brief human-
readable summary to the orchestrator:

```
Critic Review Complete: <PASS|ISSUES>

Agents reviewed: N
Issues found: N errors, N warnings

<If ISSUES: list each agent with errors and the specific problems>
<If PASS: "All briefs verified against codebase. Wave execution may proceed.">
```
