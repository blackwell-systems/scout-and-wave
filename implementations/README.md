# Polywave Implementations

Polywave is an open protocol for safely parallelizing human-guided agentic workflows. It follows the [Agent Skills](https://agentskills.io) open standard, making it compatible with Claude Code, Cursor, GitHub Copilot, and other Agent Skills-compatible tools. This directory contains implementations of the protocol for different runtimes.

## Available Implementations

### Claude Code (Fully Automated)

**Path:** [`claude-code/`](claude-code/)

Fully automated implementation using Claude Code's agent runtime and git worktree isolation. Includes 17 hooks (SubagentStart, PreToolUse, PostToolUse, SubagentStop, UserPromptSubmit) for mechanical worktree isolation, protocol compliance, progressive disclosure injection, and observability event emission. The protocol runs within a single Claude Code session with background agents executing in parallel git worktrees.

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
/polywave scout "add caching layer"
/polywave wave
```

See [`claude-code/README.md`](claude-code/README.md) for installation and detailed usage.


## Protocol Specification

All implementations must conform to the protocol specification: **[polywave-protocol](https://github.com/blackwell-systems/polywave-protocol)**

## Portability Layers

Polywave is designed as a layered system. Most of it is already platform-agnostic:

| Layer | Platform-specific? | Details |
|-------|-------------------|---------|
| **Protocol** (invariants, state machine, execution rules) | No | Fully platform-agnostic specification |
| **Go Engine** (`polywave-go/pkg/engine`, `pkg/protocol`) | No | Provider-agnostic orchestration, validation, and merging |
| **Agent backends** (`polywave-go/pkg/agent/backend/`) | No | 4 backends: Anthropic API, AWS Bedrock, OpenAI-compatible (Ollama, Groq, LM Studio), CLI |
| **Skill format** (SKILL.md + references/) | No | [Agent Skills](https://agentskills.io) standard format; any compatible tool can load the skill |
| **Skill content** (orchestration instructions) | Yes (`polywave-tools`) | The skill's instructions call `polywave-tools` CLI commands throughout the orchestration flow (prepare-wave, finalize-wave, validate, close-impl, etc.). `polywave-tools` on PATH is a pre-flight blocker. Any platform running this skill needs the Go CLI installed. |
| **Progressive disclosure** | Mostly no | 3-layer design: hooks (Claude Code), scripts (any platform with script execution), routing table in SKILL.md (universal fallback) |
| **Enforcement hooks** (22 hooks) | Yes (Claude Code) | Uses Claude Code lifecycle events (SubagentStart, PreToolUse, SubagentStop). Other platforms implement equivalent enforcement at their tool boundary. |
| **Agent prompts** | Partially | Prompt content is generic; delivery mechanism (`subagent_type`) is Claude Code-specific |

The skill's packaging follows the Agent Skills standard (portable format), but its orchestration logic requires `polywave-tools` (the Go CLI). This is by design: the CLI is the predictability boundary that makes agent behavior deterministic. Platforms that embed the Go engine directly (web app, native app) bypass the CLI entirely, but skill-based orchestration on any platform needs it installed.

The protocol requires that invariants (I1-I6) be enforced. It does not prescribe how. The Claude Code hooks are one implementation of enforcement; other platforms can enforce the same invariants through their own tool-boundary mechanisms.

## Building a New Implementation

The Polywave skill follows the [Agent Skills](https://agentskills.io) open standard. Any Agent Skills-compatible platform (Cursor, GitHub Copilot, etc.) can load the skill's SKILL.md and reference docs. To run the orchestration flow, `polywave-tools` must be installed (`go install github.com/blackwell-systems/polywave-go/cmd/polywave-tools@latest`). What else you need to provide:

1. **Agent spawning**: your platform's mechanism for launching parallel agents (the Go engine's 4-backend system handles this for programmatic orchestration)
2. **Invariant enforcement**: any mechanism that blocks writes outside an agent's assigned files and worktree (hooks are one approach; filesystem permissions, container boundaries, or tool-level filtering all satisfy the same requirement)
3. **Worktree isolation**: git worktrees (recommended) or equivalent filesystem isolation

### Steps

1. Read protocol docs in order: `participants` -> `preconditions` -> `invariants` -> `execution-rules` -> `state-machine` -> `message-formats` -> `procedures`
2. Identify which participant roles your runtime will support (minimum: Orchestrator + Wave Agent)
3. Choose an isolation mechanism that satisfies I1 (disjoint file ownership): git worktrees, filesystem snapshots, containers, etc.
4. Choose an enforcement mechanism for I1 at the tool boundary: pre-execution validation, filesystem permissions, or platform-specific hooks
5. Use the [protocol specification](https://github.com/blackwell-systems/polywave-protocol) as reference for participant roles and orchestrator logic
6. Verify your implementation satisfies all six invariants (I1-I6)

See the [polywave-protocol README](https://github.com/blackwell-systems/polywave-protocol#building-a-new-implementation) for the full adoption guide.

## License

[MIT OR Apache-2.0](../LICENSE)
