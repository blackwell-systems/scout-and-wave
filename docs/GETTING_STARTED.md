# Getting Started with Polywave

## What is SAW?

Polywave (SAW) runs parallel AI coding agents that don't break each other's code. A Scout analyzes your codebase and assigns every file to exactly one agent, making merge conflicts structurally impossible. You review the full plan before any agent touches your code.

## Three Ways to Use SAW

Choose the path that fits your workflow:

### Claude Code Skill (`/saw`)

The most common way to use SAW. Install the skill, then run `/polywave scout "feature"` directly in Claude Code. The orchestrator handles everything: launching agents, creating worktrees, merging results, running tests.

**Best for:** Day-to-day feature development, teams already using Claude Code.

**Isolation enforcement:** Worktree isolation is enforced automatically via hooks (environment injection, cd auto-injection, path validation, compliance verification). No manual `cd` commands required.

### Web UI (`polywave serve`)

A browser-based interface for reviewing IMPL docs, monitoring wave progress, and chatting with the orchestrator. Gives you visual feedback on agent status and file ownership.

**Best for:** Visual review of plans before execution, monitoring long-running waves, teams that prefer a GUI.

### CLI (`polywave-tools`)

Direct command-line access to every SAW operation. Build automation pipelines, script wave execution, integrate with CI/CD.

**Best for:** CI/CD pipelines, scripting, power users who want fine-grained control.

### Scout Automation Commands

These four commands replace manual grep and guessing during Scout planning:

| Command | Purpose |
|---------|---------|
| `polywave-tools check-callers "<symbol>" --repo-dir <path>` | Find all call sites of a function/method across the repo (including test files) |
| `polywave-tools list-error-ranges --repo-dir <path>` | List all allocated error code ranges from `pkg/result/codes.go` |
| `polywave-tools suggest-wave-structure <manifest> --repo-dir <path>` | Validate that callers of changed interfaces are in correct downstream waves |
| `polywave-tools check-test-cascade <manifest> --repo-dir <path>` | Pre-flight gate: verify test files calling changed symbols are assigned to agents |
| `polywave-tools validate-briefs <manifest>` | Symbol existence and line reference validation of agent briefs (runs as part of `finalize-scout`) |

`check-test-cascade` runs automatically as Step 3 of `polywave-tools pre-wave-validate`.

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
2. Install polywave-tools: `brew install blackwell-systems/tap/polywave-tools` (or `go install github.com/blackwell-systems/polywave-go/cmd/polywave-tools@latest`)
3. (Optional) Clone [polywave-web](https://github.com/blackwell-systems/polywave-web) for the Web UI

## Three Repos, One System

SAW is split across three repositories, each with a distinct role:

| Repository | What It Contains | When You Need It |
|---|---|---|
| [polywave](https://github.com/blackwell-systems/polywave) | Protocol spec, skill files, agent prompts | Always (this repo) |
| [polywave-go](https://github.com/blackwell-systems/polywave-go) | Go engine, `polywave-tools` CLI binary | Always (provides the CLI tools) |
| [polywave-web](https://github.com/blackwell-systems/polywave-web) | Web UI, `polywave serve` binary | Only if you want the browser interface |

**polywave** (this repo) defines the protocol and contains the Claude Code skill files. It has no runtime dependencies beyond Git.

**polywave-go** implements the protocol engine in Go and produces the `polywave-tools` binary. This is what creates worktrees, validates IMPL docs, and runs verification gates.

**polywave-web** adds an HTTP server and React frontend on top of the Go engine. It produces the `polywave` binary that serves the Web UI.

## Next Steps

- **First time?** Follow the [First Run Walkthrough](../implementations/claude-code/QUICKSTART.md) for a step-by-step example with real output
- **Need to install?** See the [Installation Guide](INSTALLATION.md)
- **Want to understand the protocol?** Read the [protocol specification](../protocol/)
- **Curious about the architecture?** See [architecture.md](architecture.md)
