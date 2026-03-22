# Scout-and-Wave: Three-Repo Architecture

## Dependency Graph

```
┌─────────────────────────────────────────────┐
│  scout-and-wave  (Protocol)                 │
│  github.com/blackwell-systems/scout-and-wave│
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
│  scout-and-wave-go  (Engine / SDK)          │
│  github.com/blackwell-systems/scout-and-wave-go
│                                             │
│  +-- sawtools CLI binary                    │
│  +-- Engine package (pkg/engine/)           │
│  +-- Protocol types (pkg/protocol/)         │
│  +-- Git worktree management (internal/git/)│
│  +-- IMPL doc parser + validator            │
└──────────────────┬──────────────────────────┘
                   │
                   │  Go module import
                   v
┌─────────────────────────────────────────────┐
│  scout-and-wave-web  (Web Application)      │
│  github.com/blackwell-systems/scout-and-wave-web
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
  docs/IMPL/*.yaml  <───────  sawtools reads/writes IMPL docs
       ^                            |
       |                      ┌─────┴─────┐
       |                      │  sawtools  │  (built from scout-and-wave-go)
       |                      └─────┬─────┘
       |                            |
       |                      ┌─────┴──────────────────┐
       └──────────────────────│  saw web server         │
                              │  (imports scout-and-    │
                              │   wave-go as Go module) │
                              └────────────────────────┘

~/.claude/skills/saw/
  saw-skill.md  ──symlink──>  scout-and-wave/implementations/
                              claude-code/prompts/saw-skill.md
```

- **sawtools** reads and writes IMPL docs directly in your project
- **saw web server** imports `scout-and-wave-go` as a Go module for engine logic
- **Skill files** are symlinked from the protocol repo into `~/.claude/skills/saw/`

See also: [symlink-diagram.md](../symlink-diagram.md),
[ECOSYSTEM.md](../ECOSYSTEM.md)

## Which Repo Do I Change?

| I want to change...                | Repo                   |
|------------------------------------|------------------------|
| Protocol behavior or rules         | `scout-and-wave`       |
| Agent prompts or skill files       | `scout-and-wave`       |
| CLI commands or engine logic       | `scout-and-wave-go`    |
| IMPL doc parsing or validation     | `scout-and-wave-go`    |
| Web UI or React components         | `scout-and-wave-web`   |
| HTTP API or SSE streaming          | `scout-and-wave-web`   |
| All three (new protocol feature)   | Protocol -> SDK -> Web |

**Rule of thumb:** Start with protocol (source of truth), then SDK (types must
match), then web (consumes both). Skip repos that aren't affected.
