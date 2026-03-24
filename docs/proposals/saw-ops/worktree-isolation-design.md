# Why SAW Uses Explicit Worktree Orchestration

Claude Code supports an `isolation: worktree` key in `.claude/agents/`
definition files that automatically creates a worktree whenever that agent
type is invoked. SAW does not use this as a replacement for explicit
worktree orchestration via `saw create-worktrees`. Four reasons:

**1. Branch naming is load-bearing.**
`saw create-worktrees` produces `wave{N}-agent-{ID}` branch names derived
from the IMPL manifest. Both `saw verify-commits` (I5 trip wire) and
`saw merge-agents` find branches by these exact names. Agent-definition
isolation generates its own branch names — unknown to the merge step,
breaking the pipeline.

**2. Pre-validation before parallel work begins.**
`saw create-worktrees` reads the entire manifest and confirms all worktrees
are clean before any agent starts. Agent-definition isolation fails lazily —
per-agent, mid-execution — meaning 10 agents may have done significant work
before the 11th reveals a setup problem.

**3. I1 enforcement at creation time.**
Disjoint file ownership is validated against the IMPL manifest before
worktrees branch. Agent-definition isolation has no awareness of IMPL
manifests or file ownership assignments; it cannot enforce I1.

**4. The protocol is a chain.**
SAW's value is the invariant chain:
scout → create → verify → merge → build → cleanup.
Agent-definition isolation covers one link in a way that is incompatible
with the links on either side. It is optimized for single ad-hoc agents,
not coordinated N-agent waves.

## When agent-definition isolation IS useful

`isolation: worktree` in agent frontmatter is the right tool for ad-hoc
agents that run outside any orchestration framework — a `refactor-agent`
or `experiment-agent` invoked manually where you want automatic isolation
without any protocol overhead. The two approaches are not competing; they
serve different problem shapes.
