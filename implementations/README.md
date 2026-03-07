# Scout-and-Wave Implementations

Scout-and-Wave is a coordination protocol for safely parallelizing human-guided agentic workflows. This directory contains different implementations of the protocol.

## Available Implementations

### Claude Code (Fully Automated)

**Path:** [`claude-code/`](claude-code/)

A complete automated implementation using Claude Code's agent runtime. The protocol runs within a single Claude Code session with background agents executing in parallel git worktrees.

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

### Manual Orchestration (Human-Driven)

**Path:** [`manual/`](manual/)

Step-by-step guides for running Scout-and-Wave workflows by hand without AI orchestration. You play all four participant roles yourself: Scout, Scaffold Agent, Wave Agent, and Orchestrator.

**Best for:**
- Learning the protocol deeply
- Small waves (1-2 agents) where automation overhead exceeds benefit
- Debugging protocol compliance issues
- Building a new implementation in another runtime

**Requires:**
- Understanding of protocol invariants (see [`../protocol/`](../protocol/))
- Git worktree experience
- Ability to read and write IMPL docs
- Discipline to follow checklists strictly

**Usage:**
Follow the guides in sequence:
1. `scout-guide.md` - Suitability gate + IMPL doc creation
2. `wave-guide.md` - Worktree setup + parallel implementation
3. `merge-guide.md` - Conflict detection + merge procedure

See [`manual/README.md`](manual/README.md) for detailed process.

## Choosing an Implementation

| Criteria | Claude Code | Manual |
|----------|-------------|--------|
| **Setup time** | 5-10 min (one-time) | None (just read guides) |
| **Execution speed** | Fast (parallel agents) | Slow (you do everything) |
| **Learning curve** | Gentle (skill handles details) | Steep (protocol internals) |
| **Best for** | Production use | Learning or debugging |
| **Overhead** | Low (background agents) | High (human coordination) |
| **Observability** | TodoWrite progress tracking | Manual notes |

**Recommendation:** Start with Claude Code unless you're building a new implementation or specifically want to learn the protocol's internals.

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
3. Choose an isolation mechanism that satisfies I1 (worktree isolation): git worktrees, filesystem snapshots, containers, etc.
4. Use `manual/` guides as a reference for orchestrator logic
5. Use `templates/` for fillable IMPL doc and agent prompt templates
6. Verify your implementation satisfies all six invariants (I1-I6)

See [`../protocol/README.md`](../protocol/README.md) for the full adoption guide.

## Examples

Real IMPL docs from dogfooding sessions are in [`claude-code/examples/`](claude-code/examples/):
- `brewprune-IMPL-brew-native.md` - Multi-wave refactor of a Go CLI tool
- Other examples showing different decomposition patterns

These demonstrate how the protocol handles complex features in practice.

## License

[MIT OR Apache-2.0](../LICENSE)
