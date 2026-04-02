# Claude Code Reference Implementation

**Protocol Version:** 0.26.0

Scout-and-Wave implemented as a Claude Code skill for fully automated parallel agent execution.

## Prerequisites

- Claude Code desktop app
- Git 2.20+ (for worktree support)
- `sawtools` CLI (see Step 2 below)
- Project with existing codebase OR empty repo for bootstrap mode

## Installation

### Step 1: Configure Permissions (Required)

SAW requires `"Agent"` in your Claude Code permissions allow list. **Without this, every agent launch will pause for manual approval.**

**If `~/.claude/settings.json` doesn't exist yet**, create it:

```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json <<'EOF'
{
  "permissions": {
    "allow": [
      "Agent",
      "Bash",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebFetch",
      "WebSearch",
      "TodoWrite"
    ]
  }
}
EOF
```

**If `~/.claude/settings.json` already exists**, add `"Agent"` to the `allow` array if it's not there:

```json
{
  "permissions": {
    "allow": [
      "Agent"
    ]
  }
}
```

**Why these permissions:**
- **`"Agent"`** (critical): Launches Scout and Wave agents without blocking
- `"Bash"`, `"Read"`, `"Write"`, `"Edit"`, `"Glob"`, `"Grep"`: Git commands, worktree management, IMPL doc writes, codebase reads
- `"TodoWrite"`: Wave progress tracking
- `"WebFetch"`, `"WebSearch"`: Doc/API lookups during scout analysis

For project-scoped settings, add the same block to `.claude/settings.json` in the project root.

### Step 2: Install sawtools (Required)

`sawtools` is the CLI engine for all wave operations — worktree creation, merge, IMPL validation, stub scanning. **Without it, `/saw wave` cannot function.**

```bash
# Homebrew (macOS/Linux)
brew install blackwell-systems/tap/sawtools

# Or via Go install (requires Go 1.21+)
go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest

# Verify
sawtools version
```

### Step 3: Clone the Repository (Required)

The skill reads prompt files from the repository at runtime, so keep it on disk:

```bash
# Clone to a location of your choice (~/code is just a suggestion)
git clone https://github.com/blackwell-systems/scout-and-wave.git ~/code/scout-and-wave

# Or anywhere else:
# git clone https://github.com/blackwell-systems/scout-and-wave.git /path/you/prefer
```

### Step 4: Install the Skill (Required)

Create the skill directory and symlink all required files:

```bash
# Create skill directory structure
mkdir -p ~/.claude/skills/saw/agents

# Symlink main skill file
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md \
       ~/.claude/skills/saw/SKILL.md

# Symlink supporting files
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/saw-bootstrap.md \
       ~/.claude/skills/saw/saw-bootstrap.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agent-template.md \
       ~/.claude/skills/saw/agent-template.md

# If you cloned elsewhere, adjust all paths:
# mkdir -p ~/.claude/skills/saw/agents
# ln -sf /your/path/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/skills/saw/SKILL.md
# ... (repeat for all supporting files)
```

**Why symlinks?** The SAW repo is the single source of truth. Symlinks mean `git pull` on the repo automatically updates the skill — no reinstall step needed.

**What changed in v0.5.0:** The skill now uses the Claude Code Skills API instead of the legacy commands API. Supporting files are co-located in the skill directory and referenced via `${CLAUDE_SKILL_DIR}`, eliminating hardcoded paths and environment variables.

### Step 5: Install Custom Agent Types (Required)

SAW uses custom Claude Code agent types that provide structural tool restrictions (e.g., scout cannot edit source files, wave agents cannot spawn sub-agents) and behavioral instructions. These must be installed for the skill to function.

**Install agent types into the skill directory:**

```bash
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scout.md \
       ~/.claude/skills/saw/agents/scout.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md \
       ~/.claude/skills/saw/agents/wave-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md \
       ~/.claude/skills/saw/agents/scaffold-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/integration-agent.md \
       ~/.claude/skills/saw/agents/integration-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/critic-agent.md \
       ~/.claude/skills/saw/agents/critic-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/planner.md \
       ~/.claude/skills/saw/agents/planner.md
```

**Install on-demand reference files (progressive disclosure):**

```bash
mkdir -p ~/.claude/skills/saw/references
cd ~/code/scout-and-wave/implementations/claude-code/prompts/references
for file in *.md; do
  ln -sf "$(pwd)/$file" ~/.claude/skills/saw/references/"$file"
done
```

This symlinks the 11 remaining reference files (down from 22):
- **Orchestrator references** (8 files, loaded by skill on matching subcommands): `program-flow.md`, `amend-flow.md`, `failure-routing.md`, `impl-targeting.md`, `model-selection.md`, `pre-wave-validation.md`, `wave-agent-contracts.md`, `integration-gap-detection.md`
- **Conditional agent references** (3 files, injected by hooks only when specific conditions match): `scout-program-contracts.md`, `wave-agent-build-diagnosis.md`, `wave-agent-program-contracts.md`

Most agent reference content is now inlined directly in agent type definitions (`agents/*.md`), eliminating hook-based injection for the common case. Only 3 conditional references remain for context that applies in specific scenarios (program contracts, build diagnosis).

These files are loaded on-demand only when the matching subcommand is invoked or condition is met at agent launch. See `docs/skills-progressive-disclosure.md` for the design.

**What you get:** Custom agent types provide runtime-enforced tool restrictions (scout cannot Edit source files, wave agents cannot spawn sub-agents) and better observability. Each agent type has YAML frontmatter that Claude Code uses to enforce behavioral constraints.

### Step 6: Install Hooks (Required)

Hooks enforce the protocol's correctness guarantees at the Claude Code level — preventing Scout from writing source files (I6), blocking wave agents from touching files they don't own (I1), validating IMPL docs on write (E16), checking agent launch/completion protocol (E42/H5), enforcing worktree isolation (E43), detecting stub patterns (E20/H3), preventing branch drift (H4), blocking git stash in wave-agent worktrees, and emitting observability events (E40). **Without hooks, many invariants are advisory only.**

```bash
cd ~/code/scout-and-wave/implementations/claude-code/hooks
./install.sh
```

The installer symlinks all 18 hook scripts to `~/.local/bin/`, registers them in `~/.claude/settings.json`, and verifies each hook is executable. It will print a summary of what was installed.

**If `~/.local/bin` is not on your `$PATH`**, add it:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc
```

See `implementations/claude-code/hooks/README.md` for the full list of hooks and what each enforces.

### Step 7: Verify Installation

Restart Claude Code (if it was already running), then in any session:

```
/saw status
```

**Expected output:** `"No IMPL doc found in this project"` or similar. This confirms the skill loaded successfully.

**If you see an error about `/saw` not being recognized:**
- Check that `SKILL.md` exists in `~/.claude/skills/saw/`
- Verify all supporting files are symlinked correctly: `ls -la ~/.claude/skills/saw/`
- Restart Claude Code

**To check symlinks:**
```bash
ls -la ~/.claude/skills/saw/
# Should show symlinks pointing to implementations/claude-code/prompts/
```

## Usage

### Quick Start

Navigate to a project with existing code and run:

```
/saw scout "add a cache to the API"   # Scout analyzes (30-90s)
/saw wave                              # Agents execute in parallel (2-5min)
```

**New to SAW?** See **[QUICKSTART.md](QUICKSTART.md)** for a detailed step-by-step guide with example output, error handling, and tips for success.

### Commands

**Command flow:**
```
/saw scout <feature>   → Analyzes, writes IMPL doc
[You review IMPL doc]
/saw wave              → Runs next pending wave
/saw wave              → Runs next wave (repeat for multi-wave)
/saw wave --auto       → Runs ALL remaining waves hands-free
/saw status            → Shows current wave and progress
```

**Which command to use:**
- **Empty repo or no architecture yet?** → `/saw bootstrap <project-name>` (designs structure from scratch)
- **Existing codebase, adding a feature?** → `/saw scout <feature-description>` (analyzes and parallelizes work)

### Workflow

0. **Bootstrap (new projects only):** `/saw bootstrap "description"` designs package structure, interface contracts, and wave layout for a new repo before any code is written.

1. **Scout:** `/saw scout "feature description"` analyzes the codebase, runs the suitability gate, and produces `docs/IMPL/IMPL-<feature>.md`. This file, the IMPL doc, is the coordination artifact: it contains file ownership (which agent owns which files), interface contracts (exact function signatures crossing agent boundaries), and a per-agent prompt for each wave agent. The orchestrator will show you a summary before any agent starts.

2. **Review:** Read the IMPL doc. Verify ownership is clean, interfaces are correct, and wave order makes sense. Adjust before proceeding. This is the last moment to change interface signatures.

3. **Scaffold Agent (conditional):** If the IMPL doc has a non-empty Scaffolds section, the Orchestrator launches the Scaffold Agent automatically. It creates the shared type files, verifies compilation, and commits to HEAD. If any scaffold fails to compile, the run stops here — fix the contracts in the IMPL doc before proceeding. When all scaffolds show `Status: committed`, the interface contracts are frozen.

4. **Wave:** `/saw wave` launches parallel agents for the current wave, merges on completion, and runs the **verification gate** (build + tests + lint).

5. **Repeat:** `/saw wave` for each subsequent wave, or `/saw wave --auto` to run all remaining waves unattended. Auto mode still pauses if verification fails.

### What Happens

**When you run `/saw scout "feature"` + `/saw wave`:**

1. **Scout** analyzes your codebase and writes `docs/IMPL/IMPL-<feature>.md`
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
- **TodoWrite:** Wave progress tracking

## Skill Architecture

The `/saw` skill consists of several specialized prompts, all installed to `~/.claude/skills/saw/`:

- **`SKILL.md`** (from `implementations/claude-code/prompts/saw-skill.md`) - Main orchestrator with YAML frontmatter
- **`saw-bootstrap.md`** - Bootstrap mode for new projects
- **`agent-template.md`** - Wave Agent template (Scout fills this to generate per-agent prompts)
- **`agents/`** - Custom agent type definitions (scout, wave-agent, scaffold-agent, integration-agent, critic-agent, planner)

All orchestration operations (worktree management, merge procedures, validation, stub scanning) are handled by the `sawtools` CLI from the scout-and-wave-go SDK.

All files are symlinked from `implementations/claude-code/prompts/` (the single source of truth). The skill references them via `${CLAUDE_SKILL_DIR}` for portability.

## Configuration

### Agent Model Selection

Agent definitions do not hardcode a model — they inherit the parent session's model by default. This keeps agent definitions platform-agnostic and conformant with the agent-skills standard (the agent describes *what it does*, not *what powers it*).

Model can be overridden at three levels (highest precedence first):

| Level | Scope | How |
|-------|-------|-----|
| **Skill argument** | Per-invocation | `/saw scout --model sonnet "feature"` |
| **Config file** | Per-project or global | `saw.config.json` (see lookup order below) |
| **Parent model** | Session default | Inherited automatically (no config needed) |

### `saw.config.json`

The skill looks for this file in two locations (first match wins):

1. **`<project-root>/saw.config.json`** — per-project config (same file the web app uses)
2. **`~/.claude/saw.config.json`** — global default for all projects

Per-project config overrides global. Use global for your default model preferences, per-project to override for specific repos.

**Install the global config (optional):**

```bash
ln -sf ~/code/scout-and-wave/config/saw.config.json ~/.claude/saw.config.json
```

Edit `config/saw.config.json` in the repo to set your preferred models. Empty string fields inherit the parent session's model. Changes are version-controlled and propagate via `git pull`.

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
| `scout_model` | `/saw scout`, `/saw bootstrap` | Parent session model |
| `wave_model` | `/saw wave` (all wave agents) | Parent session model |
| `chat_model` | Web app chat panel | Parent session model |
| `integration_model` | Integration Agent (E26) | Parent session model |

**`quality` fields:**

| Field | Effect |
|-------|--------|
| `require_tests` | Wave agents must write tests |
| `require_lint` | Lint gate is enforced |
| `block_on_failure` | Block merge on quality gate failure |

If the file doesn't exist, all values fall back to defaults. The CLI skill reads `scout_model` for `/saw scout` and `wave_model` for `/saw wave`.

### Agent Architecture

SAW uses custom Claude Code agent types for all Scout, Scaffold Agent, Wave Agent, and Integration Agent launches:

**Directory structure:**
```
prompts/
├── agent-template.md     # Scout's reference doc for writing agent briefs into IMPL doc
├── saw-bootstrap.md      # Bootstrap Scout procedure
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

## Examples

Real IMPL docs from dogfooding sessions:
- [`examples/brewprune-IMPL-brew-native.md`](examples/brewprune-IMPL-brew-native.md) - Multi-wave refactor of a Go CLI tool

These demonstrate how the protocol handles complex features in practice.

## When to Use It

SAW pays for itself when the work has clear file seams, interfaces can be defined before implementation starts, and each agent owns enough work to justify running in parallel. The build/test cycle being >30 seconds amplifies the savings further.

If the work doesn't decompose cleanly, the Scout says so. It runs a suitability gate first and emits NOT SUITABLE rather than forcing a bad decomposition.

## How it Works Under the Hood

**IMPL doc as coordination surface.** The IMPL doc is not just documentation; it is the live state of the wave. Agents write structured YAML completion reports directly into it, and the orchestrator parses those reports to detect ownership violations, interface deviations, and blocked agents before touching the working tree. The format has to be strict enough to be machine-readable. Loose or summarized reports break the orchestrator's ability to do conflict prediction and downstream prompt propagation.

**Background execution.** Every agent launch uses `run_in_background: true`. Without it, the orchestrator blocks waiting for each agent to finish before launching the next; sequential execution with extra steps. Background execution is what makes the wave actually parallel. The same applies to CI polling and `gh run watch` calls; anything that blocks the foreground session defeats the hands-free design.

## Troubleshooting

**Agent launches pause for approval:**
- Check that `"Agent"` is in your `~/.claude/settings.json` allow list
- Restart Claude Code after modifying settings

**Skill not found (`/saw` not recognized):**
- Verify `SKILL.md` is in `~/.claude/skills/saw/`
- Check all supporting files are symlinked: `ls -la ~/.claude/skills/saw/`
- Restart Claude Code

**Worktree isolation failures:**
- See [worktree defense layers](../../protocol/invariants.md#i1-disjoint-file-ownership) in protocol docs
- Pre-commit hook is installed automatically by `sawtools create-worktrees`

**For more help:**
- Read the [protocol specification](../../protocol/README.md)
- Check [execution rules](../../protocol/execution-rules.md)
- Review [invariants](../../protocol/invariants.md)

## License

[MIT OR Apache-2.0](../../LICENSE)
