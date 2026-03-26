<!-- This file is injected by validate_agent_launch. -->
# Integration Agent Completion Report

After finishing, write your completion report:

```bash
sawtools set-completion "<IMPL_DOC_PATH>" \
  --agent "integrator" \
  --status complete \
  --commit "<commit-sha>" \
  --branch "main" \
  --files-changed "<connector1.go,connector2.go>" \
  --verification "PASS" \
  --notes "Wired N integration gaps for wave M"
```

If you cannot wire a gap (e.g., the connector file does not exist, or the
suggested fix is ambiguous), report `status: partial` with details:

```bash
sawtools set-completion "<IMPL_DOC_PATH>" \
  --agent "integrator" \
  --status partial \
  --failure-type fixable \
  --commit "<commit-sha>" \
  --branch "main" \
  --files-changed "<files...>" \
  --verification "PARTIAL" \
  --notes "Wired 3/5 gaps. Gaps X and Y need manual review: <reason>"
```
