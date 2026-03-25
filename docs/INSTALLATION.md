# Installation Guide

## Zero to First Scout

Six commands from nothing to your first `/saw scout`. Copy-paste in order:

```bash
# 0. Prerequisites: Git 2.20+, Go 1.25+, jq 1.6+
git --version && go version && jq --version

# 1. Install skill files + enforcement hooks
git clone https://github.com/blackwell-systems/scout-and-wave.git
cd scout-and-wave && ./install.sh

# 2. Install the CLI
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest

# 3. Initialize your project
cd /path/to/your-project
sawtools init

# 4. Verify everything works
sawtools verify-install

# 5. Run your first scout
#    (in Claude Code, type this as a prompt)
/saw scout "describe your feature here"
```

**Important:** Add `Agent` to your Claude Code permissions or you'll be prompted to approve every agent launch:

```bash
# Add to ~/.claude/settings.json under "permissions.allow":
jq '.permissions.allow += ["Agent"] | .permissions.allow |= unique' \
  ~/.claude/settings.json > /tmp/cs.json && mv /tmp/cs.json ~/.claude/settings.json
```

That's it for most users. The Web UI is optional -- see [Step 3](#step-3-web-ui-optional) below if you want the browser interface.

---

## Prerequisites

| Tool | Minimum Version | Check With | Required For |
|---|---|---|---|
| Git | 2.20+ | `git --version` | All (worktree support) |
| Go | 1.25+ | `go version` | `sawtools` binary |
| jq | 1.6+ | `jq --version` | Installer + hooks at runtime |
| yq | 4.x | `yq --version` | Pre-launch validation (H5); grep fallback exists |
| Node.js | 18+ | `node --version` | Web UI only |

## What you need

Most users need **two repos**: this one (protocol + skill files + hooks) and `sawtools` (a single binary from scout-and-wave-go). The web UI is a third repo, optional.

| What | Install method | Required? |
|---|---|---|
| Protocol + skill + hooks | `git clone` + `./install.sh` | Yes |
| `sawtools` CLI | `brew install` or `go install` | Yes |
| Web UI | `git clone` + `npm build` + `go build` | No -- only if you want the browser dashboard |

## Installation Steps

Install in this order. Each step builds on the previous one.

### Step 1: Protocol, Skill Files, and Hooks

Clone this repository and run the installer:

```bash
git clone https://github.com/blackwell-systems/scout-and-wave.git
cd scout-and-wave
./install.sh
```

The installer does three things:

1. **Symlinks skill files** to `~/.claude/skills/saw/` (SKILL.md, agent definitions, references, scripts).
2. **Symlinks hook scripts** to `~/.local/bin/` (11 enforcement hooks, see [Hooks](#hooks-10-total) below).
3. **Registers hooks** in `~/.claude/settings.json` under `PreToolUse`, `PostToolUse`, `SubagentStop`, and `UserPromptSubmit` lifecycle events.

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

Install the `sawtools` binary using one of these methods:

**Homebrew (macOS/Linux):**
```bash
brew install blackwell-systems/tap/sawtools
```

**Go install (any platform with Go 1.21+):**
```bash
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest
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

Verify the installation:

```bash
sawtools version
```

### Step 2b: Initialize Your Project

After installing `sawtools`, run `sawtools init` in your project directory to auto-generate a `saw.config.json` configuration file:

```bash
cd your-project
sawtools init
```

`sawtools init` auto-detects your project's language (Go, Rust, Node, Python, Ruby, or Makefile-based), build command, and test command, then writes a `saw.config.json` with sensible defaults. No manual configuration needed for most projects.

**Flags:**
- `--repo <path>` — Initialize a project at a different path (default: current directory)
- `--force` — Overwrite an existing `saw.config.json`

If you already have a `saw.config.json` or prefer to configure manually, this step is optional — see [Configuration](#configuration) below.

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

## Configuration: `saw.config.json`

### What it is

`saw.config.json` is a per-project configuration file that lives in your project root. It tells SAW how to build, test, and manage your project -- which repos are involved, which models to use for each agent role, and what quality gates to run.

### What happens without it

SAW works without `saw.config.json`, but with reduced capabilities:

| Feature | With config | Without config |
|---------|-------------|----------------|
| Agent model selection | Per-role models (Scout=Sonnet, Wave=Opus, etc.) | All agents inherit parent session model |
| Build/test commands | Auto-detected or configured | Must be specified in IMPL doc quality gates |
| Multi-repo awareness | Repos listed, cross-repo IMPL docs work | Single-repo only |
| Web UI project binding | `saw serve` auto-finds project | Must pass `--repo` flag every time |
| Webhook notifications | Adapters configured under `webhooks:` key | No webhook delivery |

**Bottom line:** A single-repo project with default models works fine without it. Multi-repo projects or custom model selection need it.

### Creating it

The recommended approach is auto-detection:

```bash
cd your-project
sawtools init
```

This scans for language markers (go.mod, Cargo.toml, package.json, pyproject.toml, Gemfile, Makefile) and generates a config with sensible defaults. Use `--force` to overwrite an existing file.

### Full reference

```json
{
  "repos": [
    {"name": "my-project", "path": "/absolute/path/to/my-project"},
    {"name": "my-shared-lib", "path": "/absolute/path/to/shared-lib"}
  ],
  "agent": {
    "scout_model": "claude-sonnet-4-6",
    "wave_model": "claude-sonnet-4-6",
    "scaffold_model": "",
    "integration_model": "",
    "planner_model": "",
    "critic_model": "",
    "chat_model": ""
  },
  "build": {
    "command": "go build ./...",
    "detected": true
  },
  "test": {
    "command": "go test ./...",
    "detected": true
  },
  "webhooks": {
    "enabled": false,
    "adapters": []
  }
}
```

### Field reference

**`repos`** (array of `{name, path}`) -- Repositories this project spans. For single-repo projects, `sawtools init` creates one entry pointing to the current directory. For multi-repo projects, add additional entries. Cross-repo IMPL docs use `repo:` tags on file_ownership and quality_gates that must match a `name` here.

**`agent`** (object) -- Model override per agent role. Empty string or missing field means "inherit the parent session's model." The `/saw` skill reads these at agent launch time. Available roles: `scout_model`, `wave_model`, `scaffold_model`, `integration_model`, `planner_model`, `critic_model`, `chat_model`.

**`build`** / **`test`** (object with `command` and `detected`) -- Build and test commands for the project. `sawtools init` auto-detects these and sets `detected: true`. Override `command` if auto-detection chose wrong. These are used by `sawtools finalize-wave` for post-merge verification.

**`webhooks`** (object) -- Webhook notification configuration. `enabled: true` activates delivery. `adapters` is an array of adapter configs (Slack, Discord, Telegram). Configure via the web UI Settings page or edit directly.

### Config file lookup

SAW checks two locations (first match wins):

1. `<project-root>/saw.config.json` -- per-project config
2. `~/.claude/saw.config.json` -- global default for all projects

The project-local file takes full precedence. There is no merging between levels.

## Troubleshooting

### "sawtools: command not found"

Install or reinstall:
```bash
brew install blackwell-systems/tap/sawtools
# or
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest
```

If installed via `go install`, ensure `$GOPATH/bin` (typically `~/go/bin`) is on your PATH:
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
   ./install.sh
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
