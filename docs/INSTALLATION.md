# Installation Guide

This guide walks you through installing all Scout-and-Wave components. Most users need the first two steps; the Web UI is optional.

## Prerequisites

| Tool | Minimum Version | Check With | Required For |
|---|---|---|---|
| Git | 2.20+ | `git --version` | All components |
| Go | 1.25+ | `go version` | Building `sawtools` and `saw` binaries |
| jq | 1.6+ | `jq --version` | Hook installer, hook scripts at runtime |
| yq | 4.x | `yq --version` | Pre-launch validation (H5), IMPL parsing |
| Node.js | 18+ | `node --version` | Web UI only |

**Notes:**
- Git 2.20+ is required for worktree support (SAW creates isolated worktrees for parallel agents)
- Go is required to build the `sawtools` binary from scout-and-wave-go
- `jq` is required by the hook installer and by most hook scripts at runtime
- `yq` is used by the pre-launch validation hook; a `grep` fallback exists but is less precise
- Node.js is only required if you want the Web UI (scout-and-wave-web)

## Dependency Matrix

Not every component needs every tool. Here is what each repo requires:

| Component | Requires | Purpose |
|---|---|---|
| Protocol (scout-and-wave) | Git, jq | Skill files, protocol spec, hook installer |
| CLI (scout-and-wave-go) | Git, Go 1.25+ | `sawtools` binary |
| Web UI (scout-and-wave-web) | Git, Go 1.25+, Node.js 18+ | `saw` web server |

## Installation Steps

Install in this order. Each step builds on the previous one.

### Step 1: Protocol, Skill Files, and Hooks

Clone this repository and run the hook installer:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave.git
cd scout-and-wave
./implementations/claude-code/hooks/install.sh
```

The installer does two things:

1. **Creates symlinks** in `~/.local/bin/` pointing to the 11 hook scripts in the repo (see [Hooks](#hooks-10-total) below).
2. **Registers hooks** in `~/.claude/settings.json` under `PreToolUse`, `PostToolUse`, and `SubagentStop` lifecycle events.

The installer is idempotent — safe to run multiple times. It backs up `settings.json` before modifying it.

#### Skill Files

The skill files must also be symlinked into `~/.claude/skills/saw/`. After installation, the directory structure should look like this:

```
~/.claude/skills/saw/
├── SKILL.md              -> prompts/saw-skill.md
├── agent-template.md     -> prompts/agent-template.md
├── saw-bootstrap.md      -> prompts/saw-bootstrap.md
├── agents/
│   ├── critic-agent.md   -> prompts/agents/critic-agent.md
│   ├── integration-agent.md -> prompts/agents/integration-agent.md
│   ├── planner.md        -> prompts/agents/planner.md
│   ├── scaffold-agent.md -> prompts/agents/scaffold-agent.md
│   ├── scout.md          -> prompts/agents/scout.md
│   └── wave-agent.md     -> prompts/agents/wave-agent.md
├── references/
│   ├── amend-flow.md     -> prompts/references/amend-flow.md
│   ├── failure-routing.md -> prompts/references/failure-routing.md
│   └── program-flow.md   -> prompts/references/program-flow.md
└── hooks/
    └── pre-commit-guard.sh
```

All symlink targets point into `implementations/claude-code/prompts/` in the protocol repo, so pulling the latest revision updates skill behavior without re-symlinking.

If the skill symlinks are not set up by the hook installer, create them manually:

```bash
mkdir -p ~/.claude/skills/saw/agents ~/.claude/skills/saw/references ~/.claude/skills/saw/hooks

ln -sf "$(pwd)/implementations/claude-code/prompts/saw-skill.md" ~/.claude/skills/saw/SKILL.md
ln -sf "$(pwd)/implementations/claude-code/prompts/agent-template.md" ~/.claude/skills/saw/agent-template.md
ln -sf "$(pwd)/implementations/claude-code/prompts/saw-bootstrap.md" ~/.claude/skills/saw/saw-bootstrap.md

for f in implementations/claude-code/prompts/agents/*.md; do
  ln -sf "$(pwd)/$f" ~/.claude/skills/saw/agents/$(basename "$f")
done

for f in implementations/claude-code/prompts/references/*.md; do
  ln -sf "$(pwd)/$f" ~/.claude/skills/saw/references/$(basename "$f")
done
```

### Step 2: CLI Tools (`sawtools`)

Install the `sawtools` binary:

```bash
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest
```

This places the binary in `$GOPATH/bin` (typically `~/go/bin`), which Go adds to your PATH by default.

Verify the installation:

```bash
sawtools version
```

<details>
<summary>Alternative: build from source (for contributors)</summary>

```bash
git clone https://github.com/blackwell-systems/scout-and-wave-go.git
cd scout-and-wave-go
go build -o ~/.local/bin/sawtools ./cmd/sawtools
```

Make sure `~/.local/bin` is on your PATH: `export PATH="$HOME/.local/bin:$PATH"`
</details>

### Step 3: Web UI (Optional)

If you want the browser-based interface:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave-web.git
cd scout-and-wave-web
cd web && npm install && npm run build && cd ..
go build -o saw ./cmd/saw
```

The React frontend is embedded into the Go binary via `//go:embed`, so **both** the npm build and the Go build are required. Any change to the frontend requires re-running both steps.

Start the server with:

```bash
./saw serve
```

## Hooks (10 total)

The hook installer registers 10 hooks across three lifecycle events. All hook scripts live in `implementations/claude-code/hooks/` and are symlinked to `~/.local/bin/`.

### PreToolUse (4 hooks — fire before tool execution)

| Hook | Matcher | Purpose |
|---|---|---|
| `check_scout_boundaries` | `Write\|Edit` | Blocks Scout agents from writing outside `docs/IMPL/IMPL-*.yaml` |
| `block_claire_paths` | `Write\|Edit\|Bash` | Blocks operations targeting `.claire` paths (common typo for `.claude`) |
| `check_wave_ownership` | `Write\|Edit\|NotebookEdit` | Blocks Wave agents from writing files outside their ownership manifest |
| `validate_agent_launch` | `Agent` | Full pre-launch validation gate: checks IMPL doc, agent existence, scaffolds, branch |

### PostToolUse (4 hooks — fire after tool execution)

| Hook | Matcher | Purpose |
|---|---|---|
| `validate_impl_on_write` | `Write` | Validates IMPL docs against schema immediately after writing |
| `check_git_ownership` | `Bash` (async) | Warns when git operations modify files outside ownership list |
| `warn_stubs` | `Write\|Edit` | Warns on stub patterns (TODO, FIXME, panic) in written files |
| `check_branch_drift` | `Bash` | Blocks commits directly to `main` or `master` |

### SubagentStop (2 hooks — fire when an agent session ends)

| Hook | Matcher | Purpose |
|---|---|---|
| `validate_agent_completion` | *(all)* | Blocks completion if protocol obligations are unfulfilled (timeout: 10s) |
| `emit_agent_completion` | *(all, async)* | Emits observability events for monitoring and the web dashboard |

For detailed hook documentation, see [HOOKS.md](HOOKS.md).

### Symlinks Created

The installer creates these symlinks in `~/.local/bin/`:

```
~/.local/bin/check_scout_boundaries
~/.local/bin/block_claire_paths
~/.local/bin/check_wave_ownership
~/.local/bin/validate_agent_launch
~/.local/bin/validate_impl_on_write
~/.local/bin/check_git_ownership
~/.local/bin/warn_stubs
~/.local/bin/check_branch_drift
~/.local/bin/validate_agent_completion
~/.local/bin/emit_agent_completion
```

Note: The installer script also references `check_impl_path` in its uninstall instructions, but this hook has been superseded by `validate_agent_launch` and is no longer installed or registered.

## Verify Installation

Run the installation verification command:

```bash
sawtools verify-install
```

This checks that all prerequisites are met: `sawtools` is on PATH, skill files are symlinked, Git version is sufficient, and configured repos exist on disk. Fix any reported issues before proceeding.

For human-readable output instead of JSON:

```bash
sawtools verify-install --human
```

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

Install or reinstall: `go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest`

If already installed, ensure `$GOPATH/bin` (typically `~/go/bin`) is on your PATH:
```bash
export PATH="$(go env GOPATH)/bin:$PATH"
```

Verify with: `which sawtools`

### "/saw not recognized"

The skill files are not installed. Verify the symlinks exist:

```bash
ls -la ~/.claude/skills/saw/SKILL.md
ls ~/.claude/skills/saw/agents/
ls ~/.claude/skills/saw/references/
```

If any are missing, re-create the symlinks (see [Skill Files](#skill-files) above).

### Hooks not firing

1. Check that symlinks exist and are executable:
   ```bash
   ls -la ~/.local/bin/check_scout_boundaries
   ls -la ~/.local/bin/validate_agent_launch
   ```

2. Check that hooks are registered in settings:
   ```bash
   jq '.hooks' ~/.claude/settings.json
   ```

3. Re-run the installer:
   ```bash
   ./implementations/claude-code/hooks/install.sh
   ```

See [HOOKS.md](HOOKS.md) for detailed troubleshooting of individual hooks.

### "Git worktree error" or worktree creation fails

Your Git version is too old. SAW requires Git 2.20+ for worktree support.

Check with: `git --version`

Upgrade Git:
- **macOS:** `brew install git`
- **Ubuntu/Debian:** `sudo apt-get install git`

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

Then rebuild the Go binary (required because assets are embedded):

```bash
cd scout-and-wave-web
go build -o saw ./cmd/saw
```

## Uninstalling

To remove SAW hooks and symlinks:

1. Remove hook symlinks:
   ```bash
   rm ~/.local/bin/check_scout_boundaries \
      ~/.local/bin/block_claire_paths \
      ~/.local/bin/check_wave_ownership \
      ~/.local/bin/validate_agent_launch \
      ~/.local/bin/validate_impl_on_write \
      ~/.local/bin/check_git_ownership \
      ~/.local/bin/warn_stubs \
      ~/.local/bin/check_branch_drift \
      ~/.local/bin/validate_agent_completion \
      ~/.local/bin/emit_agent_completion
   ```

2. Edit `~/.claude/settings.json` and remove the `PreToolUse`, `PostToolUse`, and `SubagentStop` hook entries that reference SAW hooks.

3. Remove skill files:
   ```bash
   rm -rf ~/.claude/skills/saw
   ```

## Next Steps

- [Getting Started](GETTING_STARTED.md) -- decide which interface to use
- [First Run Walkthrough](../implementations/claude-code/QUICKSTART.md) -- step-by-step example
- [Protocol Specification](../protocol/) -- deep dive into how SAW works
- [Hook System](HOOKS.md) -- detailed documentation for all enforcement hooks

---

Last reviewed: 2026-03-24
