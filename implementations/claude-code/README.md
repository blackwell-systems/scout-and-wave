# Claude Code Reference Implementation

**Protocol Version:** 0.11.0

Polywave implemented as a Claude Code skill for fully automated parallel agent execution.

## Prerequisites

- Claude Code desktop app
- Git 2.20+
- jq 1.6+
- `polywave-tools` CLI (installed in step 2 below)

## Installation

The fastest path is the root installer, which handles permissions, skill symlinks, hooks, and agent types in one command:

```bash
git clone https://github.com/blackwell-systems/polywave.git ~/code/polywave
~/code/polywave/install.sh
```

Then install the CLI and initialize your project:

```bash
brew install blackwell-systems/tap/polywave-tools     # or: go install github.com/blackwell-systems/polywave-go/cmd/polywave-tools@latest
cd your-project && polywave-tools init
polywave-tools verify-install
```

Restart Claude Code, then run `/polywave scout "feature"`.

See [docs/INSTALLATION.md](../../docs/INSTALLATION.md) for the full guide with manual steps, troubleshooting, and platform-specific options.

### What install.sh does

1. Configures `"Agent"` permission in `~/.claude/settings.json`
2. Symlinks skill files to `~/.claude/skills/polywave/`
3. Symlinks agent type definitions (scout, wave-agent, scaffold-agent, integration-agent, critic-agent, planner)
4. Symlinks on-demand reference files for progressive disclosure
5. Installs 22 protocol enforcement hooks to `~/.claude/agents/hooks/`

All installed files are symlinks back to the cloned repo, so `git pull` updates everything automatically.

### Verify

```bash
polywave-tools verify-install  # checks skill files, CLI, hooks, permissions
```

**If `/polywave` is not recognized after restart:**
- Check that `SKILL.md` exists: `ls ~/.claude/skills/polywave/SKILL.md`
- Check symlinks: `ls -la ~/.claude/skills/polywave/`
- Restart Claude Code again (skills are loaded at session start)

## Usage

### Quick Start

Navigate to a project with existing code and run:

```
/polywave scout "add a cache to the API"   # Scout analyzes (30-90s)
/polywave wave                              # Agents execute in parallel (2-5min)
```

**New to Polywave?** See **[QUICKSTART.md](QUICKSTART.md)** for a detailed step-by-step guide with example output, error handling, and tips for success.

### Commands

**Command flow:**
```
/polywave scout <feature>   → Analyzes, writes IMPL doc
[You review IMPL doc]
/polywave wave              → Runs next pending wave
/polywave wave              → Runs next wave (repeat for multi-wave)
/polywave wave --auto       → Runs ALL remaining waves hands-free
/polywave status            → Shows current wave and progress
```

**Which command to use:**
- **Empty repo or no architecture yet?** → `/polywave bootstrap <project-name>` (designs structure from scratch)
- **Existing codebase, adding a feature?** → `/polywave scout <feature-description>` (analyzes and parallelizes work)

### Workflow

0. **Bootstrap (new projects only):** `/polywave bootstrap "description"` designs package structure, interface contracts, and wave layout for a new repo before any code is written.

1. **Scout:** `/polywave scout "feature description"` analyzes the codebase, runs the suitability gate, and produces `docs/IMPL/IMPL-<feature>.yaml`. This file, the IMPL doc, is the coordination artifact: it contains file ownership (which agent owns which files), interface contracts (exact function signatures crossing agent boundaries), and a per-agent prompt for each wave agent. The orchestrator will show you a summary before any agent starts.

2. **Review:** Read the IMPL doc. Verify ownership is clean, interfaces are correct, and wave order makes sense. Adjust before proceeding. This is the last moment to change interface signatures.

3. **Scaffold Agent (conditional):** If the IMPL doc has a non-empty Scaffolds section, the Orchestrator launches the Scaffold Agent automatically. It creates the shared type files, verifies compilation, and commits to HEAD. If any scaffold fails to compile, the run stops here — fix the contracts in the IMPL doc before proceeding. When all scaffolds show `Status: committed`, the interface contracts are frozen.

4. **Wave:** `/polywave wave` launches parallel agents for the current wave, merges on completion, and runs the **verification gate** (build + tests + lint).

5. **Repeat:** `/polywave wave` for each subsequent wave, or `/polywave wave --auto` to run all remaining waves unattended. Auto mode still pauses if verification fails.

### What Happens

**When you run `/polywave scout "feature"` + `/polywave wave`:**

1. **Scout** analyzes your codebase and writes `docs/IMPL/IMPL-<feature>.yaml`
2. **You review** the wave structure and interface contracts (last chance to change them)
3. **Scaffold Agent** creates shared type files if needed (10-30s)
4. **Wave Agents** (multiple agents per wave) implement their assigned files in parallel (2-5min per wave)
5. **Orchestrator** merges, runs tests, reports success

Scout will show you the wave structure and ask for approval before any agent starts.

**Expected timing:** ~5-7 minutes total for Wave 1 (2 agents running in parallel)

## Tool Requirements

This implementation uses Claude Code's tool suite:
- **Agent:** Launch Scout, Scaffold Agent, Wave Agents, Integration Agent
- **Read/Write/Edit:** IMPL doc and source file operations
- **Bash:** Git commands, build/test execution
- **Glob/Grep:** Codebase analysis during scout phase
- **TaskCreate:** Wave progress tracking

## Skill Architecture

The `/polywave` skill consists of several specialized prompts, all installed to `~/.claude/skills/polywave/`:

- **`SKILL.md`** (from `implementations/claude-code/prompts/polywave-skill.md`) - Main orchestrator with YAML frontmatter
- **`polywave-bootstrap.md`** - Bootstrap mode for new projects
- **`agent-template.md`** - Wave Agent template (Scout fills this to generate per-agent prompts)
- **`agents/`** - Custom agent type definitions (scout, wave-agent, scaffold-agent, integration-agent, critic-agent, planner)

All orchestration operations (worktree management, merge procedures, validation, stub scanning) are handled by the `polywave-tools` CLI from the polywave-go SDK.

All files are symlinked from `implementations/claude-code/prompts/` (the single source of truth). The skill references them via `${CLAUDE_SKILL_DIR}` for portability.

## Configuration

### Agent Model Selection

Agent definitions do not hardcode a model — they inherit the parent session's model by default. This keeps agent definitions platform-agnostic and conformant with the agent-skills standard (the agent describes *what it does*, not *what powers it*).

Model can be overridden at three levels (highest precedence first):

| Level | Scope | How |
|-------|-------|-----|
| **Skill argument** | Per-invocation | `/polywave scout --model sonnet "feature"` |
| **Config file** | Per-project or global | `polywave.config.json` (see lookup order below) |
| **Parent model** | Session default | Inherited automatically (no config needed) |

### `polywave.config.json`

The skill looks for this file in two locations (first match wins):

1. **`<project-root>/polywave.config.json`** — per-project config (same file the web app uses)
2. **`~/.claude/polywave.config.json`** — global default for all projects

Per-project config overrides global. Use global for your default model preferences, per-project to override for specific repos.

**Install the global config (optional):**

```bash
ln -sf ~/code/polywave/config/polywave.config.json ~/.claude/polywave.config.json
```

Edit `config/polywave.config.json` in the repo to set your preferred models. Empty string fields inherit the parent session's model. Changes are version-controlled and propagate via `git pull`.

```json
{
  "agent": {
    "scout_model": "claude-sonnet-4-5",
    "wave_model": "claude-sonnet-4-5",
    "chat_model": "claude-sonnet-4-5",
    "integration_model": "claude-sonnet-4-5"
  },
  "quality": {
    "require_tests": false,
    "require_lint": false,
    "block_on_failure": false
  }
}
```

**`agent` fields:**

| Field | Used by | Default |
|-------|---------|---------|
| `scout_model` | `/polywave scout`, `/polywave bootstrap` | Parent session model |
| `wave_model` | `/polywave wave` (all wave agents) | Parent session model |
| `chat_model` | Web app chat panel | Parent session model |
| `integration_model` | Integration Agent (E26) | Parent session model |

**`quality` fields:**

| Field | Effect |
|-------|--------|
| `require_tests` | Wave agents must write tests |
| `require_lint` | Lint gate is enforced |
| `block_on_failure` | Block merge on quality gate failure |

If the file doesn't exist, all values fall back to defaults. The CLI skill reads `scout_model` for `/polywave scout` and `wave_model` for `/polywave wave`.

### Agent Architecture

Polywave uses custom Claude Code agent types for all Scout, Scaffold Agent, Wave Agent, and Integration Agent launches:

**Directory structure:**
```
prompts/
├── agent-template.md     # Scout's reference doc for writing agent briefs into IMPL doc
├── polywave-bootstrap.md # Bootstrap Scout procedure
└── agents/
    ├── scout.md              # Custom agent type (with YAML frontmatter)
    ├── wave-agent.md         # Custom agent type (with YAML frontmatter)
    ├── scaffold-agent.md     # Custom agent type (with YAML frontmatter)
    ├── integration-agent.md  # Custom agent type (with YAML frontmatter)
    ├── critic-agent.md       # Custom agent type (with YAML frontmatter)
    └── planner.md            # Custom agent type (with YAML frontmatter)
```

**Wave agents use a two-layer architecture:**

- **Type layer** (`prompts/agents/wave-agent.md`): Shared behavior across all wave agents — worktree isolation protocol, workflow checklist, session recovery, completion report format, invariants (I1, I2, I5)
- **Instance layer** (`prompts/agent-template.md`): Comprehensive reference documentation Scout uses when writing per-agent briefs into the IMPL doc. Defines the 9-field structure (Field 0-8), isolation verification protocol, YAML completion schema, and protocol constraints.

**Workflow:**
1. Scout reads `agent-template.md` as reference documentation
2. Scout writes filled agent briefs into the IMPL doc (one section per agent)
3. Orchestrator extracts agent briefs from the IMPL doc
4. Orchestrator launches wave agents with `subagent_type: wave-agent` + extracted brief as `prompt`
5. Agents execute with both layers: type layer (wave-agent.md) provides shared behavior, instance brief provides task-specific details

Wave agents never read `agent-template.md` directly — they receive the Scout-generated brief from the IMPL doc. The template exists to ensure Scout writes consistent, protocol-compliant agent briefs.

## When to Use It

Polywave pays for itself when the work has clear file seams, interfaces can be defined before implementation starts, and each agent owns enough work to justify running in parallel. The build/test cycle being >30 seconds amplifies the savings further.

If the work doesn't decompose cleanly, the Scout says so. It runs a suitability gate first and emits NOT SUITABLE rather than forcing a bad decomposition.

## How it Works Under the Hood

**IMPL doc as coordination surface.** The IMPL doc is not just documentation; it is the live state of the wave. Agents write structured YAML completion reports directly into it, and the orchestrator parses those reports to detect ownership violations, interface deviations, and blocked agents before touching the working tree. The format has to be strict enough to be machine-readable. Loose or summarized reports break the orchestrator's ability to do conflict prediction and downstream prompt propagation.

**Background execution.** Every agent launch uses `run_in_background: true`. Without it, the orchestrator blocks waiting for each agent to finish before launching the next; sequential execution with extra steps. Background execution is what makes the wave actually parallel. The same applies to CI polling and `gh run watch` calls; anything that blocks the foreground session defeats the hands-free design.

## Troubleshooting

**Agent launches pause for approval:**
- Check that `"Agent"` is in your `~/.claude/settings.json` allow list
- Restart Claude Code after modifying settings

**Skill not found (`/polywave` not recognized):**
- Verify `SKILL.md` is in `~/.claude/skills/polywave/`
- Check all supporting files are symlinked: `ls -la ~/.claude/skills/polywave/`
- Restart Claude Code

**Worktree isolation failures:**
- See [worktree defense layers](https://github.com/blackwell-systems/polywave-protocol/blob/main/invariants.md#i1-disjoint-file-ownership) in protocol docs
- Pre-commit hook is installed automatically by `polywave-tools create-worktrees`

**For more help:**
- Read the [protocol specification](https://github.com/blackwell-systems/polywave-protocol)
- Check [execution rules](https://github.com/blackwell-systems/polywave-protocol/blob/main/execution-rules.md)
- Review [invariants](../../protocol/invariants.md)

## License

[MIT OR Apache-2.0](../../LICENSE)
