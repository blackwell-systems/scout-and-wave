# Getting Started with Scout-and-Wave

## What is SAW?

Scout-and-Wave (SAW) runs parallel AI coding agents that don't break each other's code. A Scout analyzes your codebase and assigns every file to exactly one agent, making merge conflicts structurally impossible. You review the full plan before any agent touches your code.

## Three Ways to Use SAW

Choose the path that fits your workflow:

### Claude Code Skill (`/saw`)

The most common way to use SAW. Install the skill, then run `/saw scout "feature"` directly in Claude Code. The orchestrator handles everything: launching agents, creating worktrees, merging results, running tests.

**Best for:** Day-to-day feature development, teams already using Claude Code.

**Isolation enforcement:** Worktree isolation is enforced automatically via hooks (environment injection, cd auto-injection, path validation, compliance verification). No manual `cd` commands required.

### Web UI (`saw serve`)

A browser-based interface for reviewing IMPL docs, monitoring wave progress, and chatting with the orchestrator. Gives you visual feedback on agent status and file ownership.

**Best for:** Visual review of plans before execution, monitoring long-running waves, teams that prefer a GUI.

### CLI (`sawtools`)

Direct command-line access to every SAW operation. Build automation pipelines, script wave execution, integrate with CI/CD.

**Best for:** CI/CD pipelines, scripting, power users who want fine-grained control.

## Quick Decision

```
Do you use Claude Code?
  |
  +-- Yes --> Install the skill, follow the quickstart
  |           See: implementations/claude-code/QUICKSTART.md
  |
  +-- No
       |
       Do you prefer a web UI?
         |
         +-- Yes --> Set up the web server
         |           See: [QUICKSTART-WEB.md](QUICKSTART-WEB.md)
         |
         +-- No --> Use the CLI directly
                    See: [QUICKSTART-CLI.md](QUICKSTART-CLI.md)
```

Most users start with the Claude Code skill. You can always add the Web UI or CLI later.

## Installation

See [INSTALLATION.md](INSTALLATION.md) for the full installation guide, including prerequisites, the dependency matrix, and troubleshooting.

**Quick version:**

1. Clone this repo and run `./install.sh` (installs the Claude Code skill)
2. Install sawtools: `brew install blackwell-systems/tap/sawtools` (or `go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest`)
3. (Optional) Clone [scout-and-wave-web](https://github.com/blackwell-systems/scout-and-wave-web) for the Web UI

## Three Repos, One System

SAW is split across three repositories, each with a distinct role:

| Repository | What It Contains | When You Need It |
|---|---|---|
| [scout-and-wave](https://github.com/blackwell-systems/scout-and-wave) | Protocol spec, skill files, agent prompts | Always (this repo) |
| [scout-and-wave-go](https://github.com/blackwell-systems/scout-and-wave-go) | Go engine, `sawtools` CLI binary | Always (provides the CLI tools) |
| [scout-and-wave-web](https://github.com/blackwell-systems/scout-and-wave-web) | Web UI, `saw serve` binary | Only if you want the browser interface |

**scout-and-wave** (this repo) defines the protocol and contains the Claude Code skill files. It has no runtime dependencies beyond Git.

**scout-and-wave-go** implements the protocol engine in Go and produces the `sawtools` binary. This is what creates worktrees, validates IMPL docs, and runs verification gates.

**scout-and-wave-web** adds an HTTP server and React frontend on top of the Go engine. It produces the `saw` binary that serves the Web UI.

## Next Steps

- **First time?** Follow the [First Run Walkthrough](../implementations/claude-code/QUICKSTART.md) for a step-by-step example with real output
- **Need to install?** See the [Installation Guide](INSTALLATION.md)
- **Want to understand the protocol?** Read the [protocol specification](../protocol/)
- **Curious about the architecture?** See [architecture.md](architecture.md)
