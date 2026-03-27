# Quickstart: Scout-and-Wave CLI (sawtools)

Get from zero to your first parallel wave using the command-line interface.

## Prerequisites

| Tool | Minimum Version | Check With |
|---|---|---|
| Go | 1.25+ | `go version` |
| Git | 2.20+ | `git --version` |

You also need `sawtools` built and on your PATH. See the [Installation Guide](INSTALLATION.md) for build instructions.

## Step 1: Verify Installation

```bash
sawtools verify-install
```

**What happens:** Checks that all SAW prerequisites are met -- sawtools on PATH, skill files symlinked, Git version sufficient, configured repos exist on disk.

**Expected output:**

```json
{
  "checks": [
    {"name": "sawtools_on_path", "status": "pass"},
    {"name": "skill_symlinks", "status": "pass"},
    {"name": "git_version", "status": "pass", "detail": "2.43.0"},
    {"name": "config_file", "status": "pass"},
    {"name": "repo_paths", "status": "pass"}
  ],
  "verdict": "PASS"
}
```

If any check fails, the output includes a plain-English explanation and remediation steps. For a human-readable version instead of JSON, pass `--human`.

## Step 2: Scout a Feature

Navigate to your project directory and run:

```bash
sawtools run-scout "add caching to the API client"
```

**What happens:** Launches a Scout agent that analyzes your codebase, checks suitability for parallel decomposition, designs the wave structure, and writes an IMPL doc.

**Expected output:**

```
Launching Scout agent...
Scout analyzing codebase...
Suitability: SUITABLE
Writing IMPL doc...

IMPL doc created: docs/IMPL/IMPL-add-caching.yaml
  Waves: 1
  Agents: 2 (A, B)
  Files: 6 (3 new, 3 modified)

Review the IMPL doc before proceeding.
```

## Step 3: Review the IMPL Doc

Open the generated IMPL doc and check these sections:

**Suitability verdict** -- Confirms the work can be parallelized. If Scout says NOT SUITABLE, it explains why (investigation-first work, tightly coupled changes, etc.).

**File ownership table** -- Every file assigned to exactly one agent. Verify no file appears twice and no needed file is missing.

```yaml
file_ownership:
  - file: "src/cache/cache.go"
    agent: "A"
    wave: 1
    action: "new"
  - file: "src/client/client.go"
    agent: "B"
    wave: 1
    action: "modify"
```

**Wave structure** -- Agents in the same wave run in parallel. Later waves depend on earlier ones completing first.

**Interface contracts** -- The function signatures agents implement against. These freeze when worktrees are created, so review them carefully now.

## Step 4: Prepare a Wave

```bash
sawtools prepare-wave docs/IMPL/IMPL-add-caching.yaml --wave 1
```

**What happens:** Creates isolated git worktrees for each agent, extracts agent briefs, installs pre-commit hooks, and runs pre-flight checks (dependency validation, scaffold verification).

**Expected output:**

```json
{
  "wave": 1,
  "worktrees": [
    {
      "agent": "A",
      "path": ".claude/worktrees/saw/add-caching/wave1-agent-A",
      "branch": "saw/add-caching/wave1-agent-A"
    },
    {
      "agent": "B",
      "path": ".claude/worktrees/saw/add-caching/wave1-agent-B",
      "branch": "saw/add-caching/wave1-agent-B"
    }
  ],
  "status": "ready"
}
```

## Step 5: Launch Agents

Agent execution requires Claude Code or the Claude API. Each agent receives a brief extracted from the IMPL doc and works in its own worktree.

**Hook-based enforcement (Claude Code only):** If using the `/saw` skill in Claude Code, worktree isolation is enforced automatically via 4 hooks (environment injection, bash cd injection, path validation, compliance verification). API-based execution uses Layer 1 (manual pre-creation) and Layer 4 (merge-time trip wire) for isolation.

If you are using the `/saw` skill in Claude Code, run `/saw wave` to launch agents automatically. For API-based execution, pass each agent's brief file (`.saw-agent-brief.md` in the worktree root) to your Claude API client.

Agents run in parallel, implement their assigned files, run tests, and write completion reports back to the IMPL doc.

## Step 6: Finalize the Wave

After all agents report complete:

```bash
sawtools finalize-wave docs/IMPL/IMPL-add-caching.yaml --wave 1
```

**What happens:** Verifies all agents committed, scans for stub functions, runs quality gates, merges branches to main, runs unscoped build and test verification, and cleans up worktrees.

**Expected output:**

```json
{
  "wave": 1,
  "merge": "success",
  "verification": {
    "build": "pass",
    "tests": "pass (13/13)",
    "stubs": "none detected"
  },
  "cleanup": "complete"
}
```

If any step fails, the output includes diagnostics and the merge is not finalized.

## Common Commands Reference

| Command | Purpose |
|---|---|
| `sawtools verify-install` | Check all prerequisites are met |
| `sawtools run-scout "feature"` | Analyze codebase and create IMPL doc |
| `sawtools validate <impl-doc>` | Validate an IMPL doc against protocol rules |
| `sawtools prepare-wave <impl-doc> --wave N` | Create worktrees and extract agent briefs |
| `sawtools finalize-wave <impl-doc> --wave N` | Merge agent work, verify, and clean up |
| `sawtools list-impls` | Show all IMPL docs and their status |
| `sawtools set-completion <impl-doc>` | Write agent completion report (used by agents) |

## Troubleshooting

### "sawtools: command not found"

Install: `brew install blackwell-systems/tap/sawtools` or `go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest`. Ensure the binary is on your PATH.

### "verify-install: skill_symlinks: FAIL"

Run the skill installer from the protocol repo root: `./install.sh`. This creates `~/.claude/skills/saw/` and symlinks all required prompt files. See the [Installation Guide](INSTALLATION.md) for the full skill directory structure.

### "prepare-wave: config_file: not found"

Create `saw.config.json` in your project root with repository paths. See the [Installation Guide](INSTALLATION.md) for format.

### "finalize-wave: stub detected"

An agent left placeholder functions instead of real implementations. Re-run the agent or implement the missing code manually.

### "finalize-wave: merge conflict"

Should not happen with disjoint ownership. If it does, check the IMPL doc's file ownership table -- an agent likely modified a file outside its scope.

### Protocol error codes (E16, I1, E21A, etc.)

Each code maps to a protocol rule. See the [protocol documentation](../protocol/) for the full reference.

## What Next?

- [Getting Started Guide](GETTING_STARTED.md) -- Overview of all three SAW interfaces
- [Installation Guide](INSTALLATION.md) -- Full installation walkthrough for all components
- [Claude Code Quickstart](../implementations/claude-code/QUICKSTART.md) -- Using SAW via the `/saw` skill

---

Last reviewed: 2026-03-24
