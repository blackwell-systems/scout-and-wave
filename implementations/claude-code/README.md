# Claude Code Reference Implementation

Scout-and-Wave implemented as a Claude Code skill for fully automated parallel agent execution.

## Prerequisites

- Claude Code desktop app
- Git 2.20+ (for worktree support)
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

### Step 2: Clone the Repository (Required)

The skill reads prompt files from the repository at runtime, so keep it on disk:

```bash
# Clone to a location of your choice (~/code is just a suggestion)
git clone https://github.com/blackwell-systems/scout-and-wave.git ~/code/scout-and-wave

# Or anywhere else:
# git clone https://github.com/blackwell-systems/scout-and-wave.git /path/you/prefer
```

**If you clone to a non-standard location**, set `SAW_REPO` in your shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc:
export SAW_REPO=/path/you/prefer/scout-and-wave
```

### Step 3: Install the Skill (Required)

Copy the skill file to Claude Code's commands directory:

```bash
cp ~/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md ~/.claude/commands/saw.md

# If you cloned elsewhere, adjust the path:
# cp $SAW_REPO/implementations/claude-code/prompts/saw-skill.md ~/.claude/commands/saw.md
```

### Step 4: Install Custom Agent Types (Optional)

SAW can use custom Claude Code agent types that provide structural tool restrictions (e.g., scout cannot edit source files, wave agents cannot spawn sub-agents). This is **optional** — the skill automatically falls back to `general-purpose` agents with full prompts if these are not installed.

```bash
# Symlink agent types from the SAW repo to Claude Code's agents directory
mkdir -p ~/.claude/agents
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scout.md ~/.claude/agents/scout.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/scaffold-agent.md ~/.claude/agents/scaffold-agent.md
ln -sf ~/code/scout-and-wave/implementations/claude-code/prompts/agents/wave-agent.md ~/.claude/agents/wave-agent.md

# If you cloned elsewhere, adjust the paths:
# ln -sf $SAW_REPO/implementations/claude-code/prompts/agents/scout.md ~/.claude/agents/scout.md
# ln -sf $SAW_REPO/implementations/claude-code/prompts/agents/scaffold-agent.md ~/.claude/agents/scaffold-agent.md
# ln -sf $SAW_REPO/implementations/claude-code/prompts/agents/wave-agent.md ~/.claude/agents/wave-agent.md
```

**Why symlinks?** The SAW repo is the single source of truth for agent definitions. Symlinks mean `git pull` on the repo automatically updates your agent types — no reinstall step needed.

**What you get:** When installed, the skill launches agents with their custom `subagent_type` (e.g., `subagent_type: scout`), which provides runtime-enforced tool restrictions and better observability. Without them, agents use `subagent_type: general-purpose` with the full prompt — functionally identical, but without structural tool enforcement.

**Why two prompt directories?** `prompts/agents/` contains custom agent types (optional). `prompts/` contains fallback prompts used when custom types aren't installed. You'll use one or the other automatically—the skill detects what's available and adapts.

### Step 5: Verify Installation

Restart Claude Code (if it was already running), then in any session:

```
/saw status
```

**Expected output:** `"No IMPL doc found in this project"` or similar. This confirms the skill loaded successfully.

If you see an error about `/saw` not being recognized, check that `saw.md` is in `~/.claude/commands/` and restart Claude Code.

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
- **Agent:** Launch Scout, Scaffold Agent, Wave Agents
- **Read/Write/Edit:** IMPL doc and source file operations
- **Bash:** Git commands, build/test execution
- **Glob/Grep:** Codebase analysis during scout phase
- **TodoWrite:** Wave progress tracking

## Skill Architecture

The `/saw` skill consists of several specialized prompts:

- **`prompts/saw-skill.md`** - Command router (Orchestrator role)
- **`prompts/saw-merge.md`** - Merge procedure implementation
- **`prompts/saw-worktree.md`** - Worktree lifecycle management
- **`prompts/saw-bootstrap.md`** - Bootstrap mode for new projects
- **`prompts/scout.md`** - Scout agent prompt (or `prompts/agents/scout.md` if custom types installed)
- **`prompts/scaffold-agent.md`** - Scaffold Agent prompt
- **`prompts/agent-template.md`** - Wave Agent template (Scout fills this to generate per-agent prompts)

## Agent Architecture: Dual-Structure Design

SAW uses a dual-structure architecture that supports both custom agent types and graceful fallback to general-purpose agents:

**Directory structure:**
```
prompts/
├── scout.md              # Fallback prompt (no YAML frontmatter)
├── scaffold-agent.md     # Fallback prompt (no YAML frontmatter)
├── agent-template.md     # Template Scout fills to generate wave agent prompts
└── agents/
    ├── scout.md          # Custom agent type (with YAML frontmatter)
    ├── scaffold-agent.md # Custom agent type (with YAML frontmatter)
    └── wave-agent.md     # Custom agent type (with YAML frontmatter)
```

**How fallback works:**

1. **Error-based, not config-based:** The Orchestrator always tries custom types first (`subagent_type: scout`). Only when Claude Code returns an error ("subagent type 'scout' not found") does it fall back to `subagent_type: general-purpose` with the full prompt from `prompts/scout.md`.

2. **Zero configuration required:** Users simply don't install custom agent types if they don't want them. The system automatically detects the absence and uses the fallback behavior.

3. **Behavioral equivalence:** With or without custom types, agents produce the same results. Custom types add runtime tool enforcement (scout cannot Edit source files) and observability (claudewatch can track agent types separately), but don't change the logic.

**Wave agents are special:**

Wave agents use a **two-layer architecture**:

- **Type layer** (`prompts/agents/wave-agent.md`): Shared behavior across all wave agents — worktree isolation protocol, completion report format, invariants (I1, I2, I5)
- **Instance layer** (`prompts/agent-template.md`): Scout fills this template to generate Agent A, Agent B, Agent C prompts with specific files, interfaces, and tests

When custom types are installed, both layers combine. In fallback mode, the filled template already contains all necessary instructions (it's self-contained), so wave agents work identically.

**Why root-level prompts exist:**

The files in `prompts/` (without YAML frontmatter) serve two purposes:

1. **Active fallback code paths:** When custom types aren't installed, these are the actual prompts passed to general-purpose agents
2. **Historical preservation:** They document what the prompts looked like before the custom agent types refactoring (commit c43bd41), preserving the evolution from "everything runs through general-purpose agents" to "specialized agent types with focused prompts"

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
- Verify `saw.md` is in `~/.claude/commands/`
- Check the file name is exactly `saw.md`
- Restart Claude Code

**Worktree isolation failures:**
- See [worktree defense layers](../../protocol/invariants.md#i1-worktree-isolation) in protocol docs
- Check pre-commit hook is active: `cat .git/hooks/pre-commit`

**For more help:**
- Read the [protocol specification](../../protocol/README.md)
- Check [execution rules](../../protocol/execution-rules.md)
- Review [invariants](../../protocol/invariants.md)

## License

[MIT](../../LICENSE)
