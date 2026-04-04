# Installation Guide

## Zero to First Scout

Five commands from nothing to your first `/saw scout`. Copy-paste in order:

```bash
# 0. Prerequisites: Git 2.20+, Go 1.25+, jq 1.6+
git --version && go version && jq --version

# 1. Install skill files, hooks, and Agent permission
git clone https://github.com/blackwell-systems/scout-and-wave.git
cd scout-and-wave && ./install.sh

# 2. Install the CLI
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest

# 3. Initialize your project
cd /path/to/your-project
sawtools init

# 4. Verify everything works
sawtools verify-install

# 5. Run your first scout (in Claude Code, type this as a prompt)
/saw scout "describe your feature here"
```

The installer auto-detects Claude Code and handles everything: skill files, enforcement hooks, settings.json registration, and Agent permission. No manual configuration needed.

For non-Claude-Code platforms, use `./install.sh --generic` to install to `~/.agents/skills/saw/` instead (see [Platform Support](#platform-support) below).

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

The installer auto-detects Claude Code (checks for `~/.claude`) and does four things:

1. **Symlinks skill files** to `~/.claude/skills/saw/` (SKILL.md, agent definitions, references, scripts).
2. **Symlinks hook scripts** to `~/.local/bin/` (18 enforcement hooks, see [Hooks](#hooks-18-total) below).
3. **Registers hooks** in `~/.claude/settings.json` under `PreToolUse`, `PostToolUse`, `SubagentStart`, `SubagentStop`, and `UserPromptSubmit` lifecycle events.
4. **Adds `Agent` permission** to `~/.claude/settings.json` so SAW can launch agents without manual approval.

The installer is idempotent — safe to run multiple times. It backs up `settings.json` before modifying it. Run `./install.sh --generic` to install to `~/.agents/skills/saw/` without Claude Code-specific configuration.

#### Skill Files

After installation, the skill directory structure looks like this:

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
│   ├── impl-targeting.md -> prompts/references/impl-targeting.md
│   ├── integration-gap-detection.md -> prompts/references/integration-gap-detection.md
│   ├── model-selection.md -> prompts/references/model-selection.md
│   ├── pre-wave-validation.md -> prompts/references/pre-wave-validation.md
│   ├── program-flow.md   -> prompts/references/program-flow.md
│   ├── scout-program-contracts.md -> prompts/references/scout-program-contracts.md
│   ├── wave-agent-build-diagnosis.md -> prompts/references/wave-agent-build-diagnosis.md
│   ├── wave-agent-contracts.md -> prompts/references/wave-agent-contracts.md
│   └── wave-agent-program-contracts.md -> prompts/references/wave-agent-program-contracts.md
└── hooks/
    └── pre-commit-guard.sh
```

All symlink targets point into `implementations/claude-code/prompts/` in the protocol repo, so pulling the latest revision updates skill behavior without re-symlinking.

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

## Hooks (18 total)

The hook installer registers 18 hooks across five lifecycle events. All hook scripts live in `implementations/claude-code/hooks/` and are symlinked to `~/.local/bin/`.

### SubagentStart (2 hooks — fire when an agent session starts)

| Hook | Matcher | Purpose |
|---|---|---|
| `inject_worktree_env` | *(all)* | Sets 5 environment variables (worktree path, agent ID, wave number, IMPL path, branch name) |
| `validate_agent_isolation` | *(all)* | Verifies wave agent is running in the correct worktree (exit 2 blocks start) |

### PreToolUse (8 hooks — fire before tool execution)

| Hook | Matcher | Purpose |
|---|---|---|
| `check_scout_boundaries` | `Write\|Edit` | Blocks Scout agents from writing outside `docs/IMPL/IMPL-*.yaml` |
| `block_claire_paths` | `Write\|Edit\|Bash` | Blocks operations targeting `.claire` paths (common typo for `.claude`) |
| `check_wave_ownership` | `Write\|Edit\|NotebookEdit` | Blocks Wave agents from writing files outside their ownership manifest |
| `auto_format_saw_agent_names` | `Agent` | Validates/formats SAW agent names from brief metadata (fallback for E44) |
| `validate_agent_launch` | `Agent` | Full pre-launch validation gate: checks IMPL doc, agent existence, scaffolds, branch |
| `inject_bash_cd` | `Bash` | Auto-prepends `cd $SAW_AGENT_WORKTREE &&` to every bash command when agent is in worktree |
| `validate_write_paths` | `Write\|Edit` | Blocks relative paths and paths outside worktree boundaries |
| `block_git_stash` | `Bash` | Blocks `git stash` in wave-agent worktrees (stash hides uncommitted work from merge verification) |

### PostToolUse (4 hooks — fire after tool execution)

| Hook | Matcher | Purpose |
|---|---|---|
| `validate_impl_on_write` | `Write` | Validates IMPL docs against schema immediately after writing |
| `check_git_ownership` | `Bash` (async) | Warns when git operations modify files outside ownership list |
| `warn_stubs` | `Write\|Edit` | Warns on stub patterns (TODO, FIXME, panic) in written files |
| `check_branch_drift` | `Bash` | Blocks commits directly to `main` or `master` |

### SubagentStop (3 hooks — fire when an agent session ends)

| Hook | Matcher | Purpose |
|---|---|---|
| `validate_agent_completion` | *(all)* | Blocks completion if protocol obligations are unfulfilled (timeout: 10s) |
| `emit_agent_completion` | *(all, async)* | Emits observability events for monitoring and the web dashboard |
| `verify_worktree_compliance` | *(all)* | Verifies completion report and commits exist (warn-only, creates audit trail) |

### UserPromptSubmit (1 hook — fires when user submits a prompt)

| Hook | Matcher | Purpose |
|---|---|---|
| `inject_skill_context` | *(all)* | Injects skill subcommand references (program-flow, amend-flow) into orchestrator context |

#### Hook-Based Enforcement (E43)

As of v0.65.0, worktree isolation is enforced automatically via lifecycle hooks. Wave agents no longer need manual `cd` commands or `$WORKTREE` variable usage — hooks inject working directory changes and validate paths before tool execution.

This prevents the Agent B leak scenario where files are accidentally created in the main repository instead of the agent's assigned worktree. Four hooks work together to provide defense-in-depth isolation:

1. Environment injection (SubagentStart)
2. Bash command rewriting (PreToolUse:Bash)
3. Write/Edit path validation (PreToolUse:Write/Edit)
4. Protocol compliance verification (SubagentStop)

See `implementations/claude-code/hooks/README.md` for full hook documentation.

For detailed hook documentation, see [hooks/README.md](../implementations/claude-code/hooks/README.md).

### Symlinks Created

The installer creates these symlinks in `~/.local/bin/`:

```
~/.local/bin/inject_worktree_env
~/.local/bin/validate_agent_isolation
~/.local/bin/check_scout_boundaries
~/.local/bin/block_claire_paths
~/.local/bin/check_wave_ownership
~/.local/bin/auto_format_saw_agent_names
~/.local/bin/validate_agent_launch
~/.local/bin/inject_bash_cd
~/.local/bin/validate_write_paths
~/.local/bin/block_git_stash
~/.local/bin/validate_impl_on_write
~/.local/bin/check_git_ownership
~/.local/bin/warn_stubs
~/.local/bin/check_branch_drift
~/.local/bin/validate_agent_completion
~/.local/bin/emit_agent_completion
~/.local/bin/verify_worktree_compliance
~/.local/bin/inject_skill_context
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

If any are missing, re-run the installer: `./install.sh`

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

See [hooks/README.md](../implementations/claude-code/hooks/README.md) for detailed troubleshooting of individual hooks.

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

## Platform Support

The installer supports multiple platforms via flags:

| Flag | Skill directory | Hooks | Settings |
|------|----------------|-------|----------|
| `./install.sh` (auto-detect) | `~/.claude/skills/saw/` if Claude Code detected, else `~/.agents/skills/saw/` | `~/.local/bin/` | `settings.json` if Claude Code |
| `./install.sh --claude-code` | `~/.claude/skills/saw/` | `~/.local/bin/` | Registers in `settings.json` + Agent permission |
| `./install.sh --generic` | `~/.agents/skills/saw/` | `~/.local/bin/` | None (manual registration) |

**`sawtools` works on any platform** -- it's a standalone Go binary that manages git worktrees, validates IMPL docs, merges branches, and runs quality gates. No LLM API calls. Key capabilities include:

- Worktree management: `prepare-wave`, `finalize-wave`, `create-worktree`
- Validation: `pre-wave-validate`, `verify-install`, `validate-impl`, `validate-briefs`
- Configuration: `init`, `set-completion`, `set-impl-state`
- Scout automation: `check-callers`, `list-error-ranges`, `suggest-wave-structure`,
  and `check-test-cascade` replace manual grep during planning

**The orchestrator prompt and hooks are platform-specific.** The `/saw` skill prompt is written for Claude Code's skill system. The hook scripts use a JSON stdin/stdout protocol that can be adapted to other platforms' hook systems (Gemini CLI's `BeforeAgent`, Cursor's `beforeSubmitPrompt`, etc.). Use `--generic` to install the scripts, then register them in your platform's configuration.

## Uninstalling

```bash
./install.sh --uninstall
```

This removes skill file symlinks and hook script symlinks. Hook registrations in `settings.json` are not removed automatically -- edit that file manually if needed.

## Next Steps

- [Getting Started](GETTING_STARTED.md) -- decide which interface to use
- [First Run Walkthrough](../implementations/claude-code/QUICKSTART.md) -- step-by-step example
- [Protocol Specification](../protocol/) -- deep dive into how SAW works
- [Hook System](../implementations/claude-code/hooks/README.md) -- detailed documentation for all enforcement hooks

---

Last reviewed: 2026-04-03
