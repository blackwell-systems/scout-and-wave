# Polywave: Three-Repo Architecture

## Dependency Graph

```
┌─────────────────────────────────────────────┐
│  polywave  (Protocol)                 │
│  github.com/blackwell-systems/polywave│
│                                             │
│  +-- Invariants (I1-I6)                     │
│  +-- Execution rules (E1-E38)               │
│  +-- Skill files (saw-skill.md, etc.)       │
│  +-- Agent prompts (scout.md, wave-agent.md)│
│  +-- Install script (install.sh)            │
└──────────────────┬──────────────────────────┘
                   │
                   │  protocol spec defines behavior
                   v
┌─────────────────────────────────────────────┐
│  polywave-go  (Engine / SDK)          │
│  github.com/blackwell-systems/polywave-go
│                                             │
│  +-- polywave-tools CLI binary                    │
│  +-- Engine package (pkg/engine/)           │
│  +-- Protocol types (pkg/protocol/)         │
│  +-- Git worktree management (internal/git/)│
│  +-- IMPL doc parser + validator            │
└──────────────────┬──────────────────────────┘
                   │
                   │  Go module import
                   v
┌─────────────────────────────────────────────┐
│  polywave-web  (Web Application)      │
│  github.com/blackwell-systems/polywave-web
│                                             │
│  +-- saw binary (HTTP server)               │
│  +-- React web UI (embedded via go:embed)   │
│  +-- HTTP API endpoints                     │
│  +-- SSE live streaming                     │
└─────────────────────────────────────────────┘
```

## Data Flow

IMPL docs live in the **target project** (not in any SAW repo). Here is how
data moves between repos at runtime:

```
Target Project (your codebase)
  docs/IMPL/*.yaml  <───────  polywave-tools reads/writes IMPL docs
       ^                            |
       |                      ┌─────┴─────┐
       |                      │  polywave-tools  │  (built from polywave-go)
       |                      └─────┬─────┘
       |                            |
       |                      ┌─────┴──────────────────┐
       └──────────────────────│  saw web server         │
                              │  (imports scout-and-    │
                              │   wave-go as Go module) │
                              └────────────────────────┘

~/.claude/skills/saw/
  saw-skill.md  ──symlink──>  polywave/implementations/
                              claude-code/prompts/saw-skill.md
```

- **polywave-tools** reads and writes IMPL docs directly in your project
- **saw web server** imports `polywave-go` as a Go module for engine logic
- **Skill files** are symlinked from the protocol repo into `~/.claude/skills/saw/`

See also: [symlink-diagram.md](../symlink-diagram.md),
[ECOSYSTEM.md](../ECOSYSTEM.md)

## Which Repo Do I Change?

| I want to change...                | Repo                   |
|------------------------------------|------------------------|
| Protocol behavior or rules         | `polywave`       |
| Agent prompts or skill files       | `polywave`       |
| CLI commands or engine logic       | `polywave-go`    |
| IMPL doc parsing or validation     | `polywave-go`    |
| Web UI or React components         | `polywave-web`   |
| HTTP API or SSE streaming          | `polywave-web`   |
| All three (new protocol feature)   | Protocol -> SDK -> Web |

**Rule of thumb:** Start with protocol (source of truth), then SDK (types must
match), then web (consumes both). Skip repos that aren't affected.
