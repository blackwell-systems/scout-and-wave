# Quickstart: Scout-and-Wave Web UI

Get from zero to your first parallel wave in under 10 minutes using the browser-based interface.

## Prerequisites

| Tool | Minimum Version | Check With |
|---|---|---|
| Go | 1.25+ | `go version` |
| Node.js | 18+ | `node --version` |
| Git | 2.20+ | `git --version` |

You also need the [scout-and-wave-web](https://github.com/blackwell-systems/scout-and-wave-web) repo cloned locally.

## Step 1: Build and Start the Server

```bash
cd scout-and-wave-web
make build
./saw serve
```

**What happens:** The `make build` command compiles the React frontend and embeds it into the Go binary. The server starts on port 7432 by default.

**Expected output:**

```
SAW server listening on http://localhost:7432
```

## Step 2: Open the Web UI

Navigate to [http://localhost:7432](http://localhost:7432) in your browser.

[Screenshot: SAW Web UI landing page with navigation sidebar]

You should see the main dashboard with a sidebar for navigation.

## Step 3: Your First IMPL Review

### Browse Existing IMPLs

Click **IMPL Picker** in the sidebar to see all IMPL docs in your configured repositories.

[Screenshot: IMPL Picker showing list of IMPLs with status badges]

Each IMPL shows its current status (draft, in-progress, complete) and a summary of the planned work.

### Review an IMPL Doc

Click any IMPL to open the **Review Screen**. Key sections to check:

- **Suitability Verdict** -- Did Scout determine this work is parallelizable?
- **Wave Structure** -- How many waves, how many agents per wave?
- **File Ownership Table** -- Which agent owns which files? Verify no overlaps.
- **Interface Contracts** -- The function signatures agents will implement against. These freeze at wave launch.

[Screenshot: Review Screen showing suitability verdict, wave structure, and file ownership]

### Approve or Revise

If the plan looks correct, you are ready to launch. If something needs changing, edit the IMPL doc directly (it is a YAML file in `docs/IMPL/`) and refresh the page.

## Step 4: Launching a Wave

Click the **Launch Wave** button on the IMPL review page.

**Isolation enforcement:** When using Claude Code as the agent backend, worktree isolation is enforced automatically via hooks. When using API-based execution, isolation relies on manual worktree pre-creation and merge-time verification.

[Screenshot: Launch Wave button on IMPL review page]

The view switches to the **Wave Dashboard**, which shows live progress for each agent:

[Screenshot: Wave Dashboard with agent status cards showing "running", file counts, and elapsed time]

Each agent card displays:
- Agent ID and task summary
- Current status (running, complete, partial, blocked)
- Files owned and modified
- Elapsed time

Agents work in parallel in isolated git worktrees. When all agents report complete, the dashboard shows merge and verification results.

## Step 5: Using Chat

Click **Chat** in the sidebar to open the conversational interface. You can ask questions about the current IMPL doc, wave progress, or general SAW concepts.

Example prompts:
- "What files does Agent A own?"
- "Show me the interface contracts for this IMPL"
- "What is the status of wave 1?"

[Screenshot: Chat interface with a question about agent file ownership]

## Troubleshooting

### Port 7432 already in use

Another process is using the default port. Either stop that process or specify a different address:

```bash
./saw serve --addr localhost:8080
```

### Build fails during `make build`

**Missing Node.js dependencies:** Run `cd web && npm install` before `make build`.

**Go build errors:** Ensure Go 1.25+ is installed. Run `go version` to check. If you have the right version but builds still fail, try `go clean -cache` and rebuild.

### Page loads but shows no IMPLs

The server needs a `saw.config.json` file that points to your repositories. Verify the file exists and contains valid repo paths:

```bash
cat saw.config.json
```

Each repo entry should have an absolute path to a directory containing `docs/IMPL/`.

### Changes not appearing after editing IMPL doc

The web UI reads IMPL docs from disk. Refresh the browser page after saving changes to the YAML file.

## What Next?

- [Getting Started Guide](GETTING_STARTED.md) -- Overview of all three SAW interfaces
- [Installation Guide](INSTALLATION.md) -- Full installation walkthrough for all components
- [Claude Code Quickstart](../implementations/claude-code/QUICKSTART.md) -- Using SAW via the `/saw` skill in Claude Code

---

Last reviewed: 2026-03-24
