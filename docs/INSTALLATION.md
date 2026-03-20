# Installation Guide

This guide walks you through installing all Scout-and-Wave components. Most users need the first two steps; the Web UI is optional.

## Prerequisites

| Tool | Minimum Version | Check With |
|---|---|---|
| Git | 2.20+ | `git --version` |
| Go | 1.25+ | `go version` |
| Node.js | 18+ | `node --version` |
| Claude Code | Latest | `claude --version` |

**Notes:**
- Git 2.20+ is required for worktree support (SAW creates isolated worktrees for each agent)
- Go is required to build the `sawtools` binary from scout-and-wave-go
- Node.js is only required if you want the Web UI (scout-and-wave-web)
- Claude Code is required for the `/saw` skill interface

## Dependency Matrix

Not every component needs every tool. Here is what each repo requires:

| Component | Requires | Purpose |
|---|---|---|
| Protocol (scout-and-wave) | Git | Skill files, protocol spec |
| CLI (scout-and-wave-go) | Git, Go 1.25+ | `sawtools` binary |
| Web UI (scout-and-wave-web) | Git, Go 1.25+, Node.js 18+ | `saw` web server |

## Installation Steps

Install in this order. Each step builds on the previous one.

### Step 1: Protocol and Skill Files

Clone this repository and run the installer:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave.git
cd scout-and-wave
./install.sh
```

The install script creates `~/.claude/skills/saw/` and symlinks the skill files (SKILL.md, agent templates, bootstrap prompts). It is safe to run multiple times.

### Step 2: CLI Tools (`sawtools`)

Clone the Go engine repo and build the binary:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave-go.git
cd scout-and-wave-go
go build -o ~/.local/bin/sawtools ./cmd/saw
```

Make sure `~/.local/bin` is on your PATH. Add this to your shell profile if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Verify the build:

```bash
sawtools --version
```

### Step 3: Web UI (Optional)

If you want the browser-based interface:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave-web.git
cd scout-and-wave-web
make build
```

This builds the React frontend and embeds it into the `saw` Go binary. Start the server with:

```bash
./saw serve
```

## Verify Installation

Run the installation verification command:

```bash
sawtools verify-install
```

This checks that all prerequisites are met: `sawtools` is on PATH, skill files are symlinked, Git version is sufficient, and configured repos exist on disk. Fix any reported issues before proceeding.

## Permissions

Claude Code needs permission to launch background agents. Add `"Agent"` to your settings:

**File:** `~/.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Agent"
    ]
  }
}
```

Without this permission, SAW cannot launch Scout or Wave agents.

## Configuration

SAW looks for a `saw.config.json` file in your project root. This tells `sawtools` where to find the other repos:

```json
{
  "repos": {
    "protocol": "/path/to/scout-and-wave",
    "engine": "/path/to/scout-and-wave-go",
    "web": "/path/to/scout-and-wave-web"
  }
}
```

If you cloned all three repos into the same parent directory, the default paths should work automatically.

## Troubleshooting

### "sawtools: command not found"

The `sawtools` binary is not on your PATH. Either:
- Move it to a directory on your PATH: `cp sawtools ~/.local/bin/`
- Or add its location to PATH: `export PATH="/path/to/dir:$PATH"`

Verify with: `which sawtools`

### "/saw not recognized" in Claude Code

The skill files are not installed. Run `./install.sh` from the scout-and-wave repo root, then restart Claude Code.

Verify with: `ls ~/.claude/skills/saw/SKILL.md`

### "Git worktree error" or worktree creation fails

Your Git version is too old. SAW requires Git 2.20+ for worktree support.

Check with: `git --version`

Upgrade Git:
- **macOS:** `brew install git`
- **Ubuntu/Debian:** `sudo apt-get install git`

### "Agent tool not allowed"

Claude Code does not have permission to launch agents. Add `"Agent"` to your `~/.claude/settings.json` allow list (see Permissions section above).

### Build fails for scout-and-wave-go

Ensure you have Go 1.25+ installed:

```bash
go version
```

If you have an older version, update Go from [go.dev/dl](https://go.dev/dl/).

### Web UI build fails (npm errors)

Ensure you have Node.js 18+:

```bash
node --version
```

If the React build fails, try clearing the cache:

```bash
cd scout-and-wave-web/web
rm -rf node_modules
npm install
npm run build
```

## Next Steps

- [Getting Started](GETTING_STARTED.md) -- decide which interface to use
- [First Run Walkthrough](../implementations/claude-code/QUICKSTART.md) -- step-by-step example
- [Protocol Specification](../protocol/) -- deep dive into how SAW works
