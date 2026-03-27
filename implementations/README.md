# Scout-and-Wave Implementations

Scout-and-Wave is an open protocol for safely parallelizing human-guided agentic workflows. It follows the [Agent Skills](https://agentskills.io) open standard, making it compatible with Claude Code, Cursor, GitHub Copilot, and other Agent Skills-compatible tools. This directory contains implementations of the protocol for different runtimes.

## Available Implementations

### Claude Code (Fully Automated)

**Path:** [`claude-code/`](claude-code/)

Fully automated implementation using Claude Code's agent runtime and git worktree isolation. Includes 15 enforcement hooks (SubagentStart, PreToolUse, PostToolUse, SubagentStop) for mechanical worktree isolation and protocol compliance. The protocol runs within a single Claude Code session with background agents executing in parallel git worktrees.

**Best for:**
- Automated parallel execution of complex features
- Teams already using Claude Code
- Projects where build/test cycles are >30 seconds
- Features with clear file decomposition

**Requires:**
- Claude Code desktop app
- Git 2.20+ (for worktree support)
- 5-10 minutes setup time (one-time)

**Usage:**
```
/saw scout "add caching layer"
/saw wave
```

See [`claude-code/README.md`](claude-code/README.md) for installation and detailed usage.


## Protocol Specification

All implementations must conform to the protocol specification in [`../protocol/`](../protocol/). Key documents:

- [`participants.md`](../protocol/participants.md) - Participant roles and responsibilities
- [`invariants.md`](../protocol/invariants.md) - Correctness guarantees (I1-I6)
- [`execution-rules.md`](../protocol/execution-rules.md) - State transitions and verification gates
- [`message-formats.md`](../protocol/message-formats.md) - IMPL doc and completion report formats

## Building a New Implementation

To implement Scout-and-Wave in a different runtime (Python, Rust, TypeScript, etc.):

1. Read protocol docs in order: `participants` → `preconditions` → `invariants` → `execution-rules` → `state-machine` → `message-formats` → `procedures`
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (disjoint file ownership): git worktrees, filesystem snapshots, containers, etc.
4. Use [`../protocol/`](../protocol/) as reference for participant roles and orchestrator logic
5. Use [`protocol/message-formats.md`](../protocol/message-formats.md) as reference for IMPL doc structure and message schemas
6. Verify your implementation satisfies all six invariants (I1-I6)

See [`../protocol/README.md`](../protocol/README.md) for the full adoption guide.

## License

[MIT OR Apache-2.0](../LICENSE)
