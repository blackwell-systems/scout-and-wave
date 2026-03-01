<!-- saw-quick v0.3.4 -->
# SAW Quick Mode: Lightweight Parallel Execution

Use this mode for small work (≤3 agents) with no coordination complexity.

**When to use:**
- Total agents: 2-3
- No cross-agent dependencies (truly parallel work)
- No interface contracts needed
- No audit trail required
- Files are obviously disjoint

**When NOT to use:**
- ≥4 agents (use full SAW with IMPL doc)
- Cross-agent dependencies (need interface contracts)
- Complex coordination (need dependency mapping)
- Audit-fix-audit cycle (need completion reports)

## Protocol Guarantees

**Quick mode enforces I1 (disjoint file ownership) only.** The following
invariants are unenforced:

- **I2** — No interface contracts. Agents may implement incompatible signatures.
- **I3** — No wave sequencing. All agents run in a single flat batch.
- **I4** — No IMPL doc. Results are reported to chat; there is no persistent record.
- **I5** — No commit requirement. Agents may report complete with uncommitted changes.

If any of these gaps would cause a problem for the work at hand, use full SAW.

## Quick Mode Process

1. **Declare file ownership** — write down every file each agent owns and verify
   there is no overlap. This is a hard requirement, not a checklist item. Do not
   launch agents until ownership is confirmed disjoint.
2. **Generate inline prompts** — use simplified 3-field template
3. **Launch agents** — no IMPL doc, just task descriptions
4. **Merge results** — simple file copy or git merge
5. **Run verification** — build + test on merged result

## Simplified Agent Prompt Template

```
# Quick Agent {letter}: {description}

## Files You Own
- path/to/file1 (modify)
- path/to/file2 (create)

## Task
{2-3 sentence description of what to do. No 8-field structure, just the work.}

## Verification
```bash
cd /path/to/repo
{build command}
{test command}
```

Report: Write results directly to chat (no IMPL doc completion report).
```

## Usage Example

```
/saw quick "Add logging to error handlers in api.go and fix validation in auth.go"

This launches 2 agents:
- Agent A: api.go (add logging)
- Agent B: auth.go (fix validation)

No IMPL doc created. Results reported directly.
```

## Merge Logic

```bash
# Simple merge for quick mode
for agent in A B; do
  branch="quick-agent-${agent}"
  git merge --no-ff "$branch" || {
    echo "Merge conflict in quick mode - use full SAW instead"
    exit 1
  }
done
```

If merge conflicts occur, this is a signal the work needs full SAW coordination.

## Decision Tree: Quick vs Full SAW

```
Is work < 4 agents? ──NO──> Use full SAW
    │
   YES
    │
    ▼
Are files disjoint? ──NO──> Use full SAW
    │
   YES
    │
    ▼
Cross-agent deps? ──YES──> Use full SAW
    │
   NO
    │
    ▼
Need audit trail? ──YES──> Use full SAW
    │
   NO
    │
    ▼
Use Quick Mode ✓
```

## Quick Mode Template Fields

Quick mode uses 3 fields (Files, Task, Verification) vs full SAW's 8 fields.
Omits: interfaces, dependencies, constraints, IMPL report.

## When to Graduate to Full SAW

If during quick mode you encounter:
- Merge conflicts
- Missing interface definitions
- Circular dependencies
- Need to track completion per-agent

Stop, rollback, and restart with full SAW coordination.

## Example: Full SAW vs Quick Mode

**Full SAW**: 5 agents, shared interfaces, IMPL doc with contracts/dependencies
**Quick Mode**: 2 agents, disjoint files, direct reporting, no IMPL doc

## Quick Mode Checklist

Before using quick mode, verify:
- [ ] ≤3 agents total
- [ ] File ownership declared and confirmed disjoint (hard requirement)
- [ ] No shared interfaces needed
- [ ] No cross-agent dependencies
- [ ] Merge conflicts unlikely
- [ ] No audit trail needed

If all checked, proceed with quick mode. Otherwise use full SAW.
