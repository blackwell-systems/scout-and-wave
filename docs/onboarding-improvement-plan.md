# Onboarding Improvement Plan for Scout-and-Wave

**Date:** 2026-03-22
**Author:** Claire (research agent)
**Status:** Proposal — ready for review and prioritization

---

## 1. Current State Analysis

### 1.1 CLI Path: What a New User Does Today

A new user who discovers SAW and wants to try it goes through these steps:

1. **Read the README** (206 lines). Encounters seven participant roles, six invariants, five preconditions, 41 execution rules, worktree isolation layers, scaffold agents, interface contracts, and wave sequencing — before seeing `Quick Start`.
2. **Follow Quick Start** — must clone one repo, run `install.sh`, clone a second repo (`scout-and-wave-go`), build a Go binary (`go build -o ~/.local/bin/sawtools ./cmd/sawtools`), ensure `~/.local/bin` is on PATH, edit `~/.claude/settings.json` to add Agent permissions, optionally create `saw.config.json`.
3. **Run `sawtools verify-install`** to check the setup.
4. **Navigate to GETTING_STARTED.md** to understand the three interfaces (skill, web, CLI).
5. **Navigate to `implementations/claude-code/QUICKSTART.md`** for a step-by-step walkthrough.
6. **Finally run `/saw scout "feature"`** — and wait 30-90 seconds for a result they need protocol knowledge to evaluate.

**Minimum steps before first productive use: 9** (clone, install, clone, build, PATH, permissions, verify, read quickstart, run scout). Compare with AO's 1 step: `ao start <url>`.

**Minimum concepts required before first use:**
- What a "Scout" is and why it runs first
- What an "IMPL doc" is (the YAML coordination artifact)
- What "waves" are and why they're sequential
- What "file ownership" means and why it matters
- What "interface contracts" are and why they freeze
- What "scaffold files" are and when they're needed
- What "suitability" means and when the scout says no

That is seven protocol-specific concepts, all required upfront. A user who skips any of them will be confused by the Scout's output.

### 1.2 Web App Path: What a New User Does Today

1. Clone three repos, build the web app (`make build`), run `./saw serve`.
2. Open `http://localhost:7432`.
3. See the **WelcomeCard** component: "Scout-and-Wave uses AI agents to plan and implement features in parallel." Then: "First, add a repository in Settings so Scout knows which codebase to analyze."
4. Click "Open Settings," navigate to the repo configuration form, add a repo path, validate it.
5. Return to the main view — see "No plan selected" with an empty document icon.
6. Must figure out that "New Plan" in the header triggers a Scout.
7. The header shows seven model selectors (`SCOUT`, `CRITIC`, `WAVE`, `CHAT`, `PLANNER`, `SCAFFOLD`, `INTEGRATION`) with no explanation of what any role is.

**Friction points:**
- The WelcomeCard mentions "IMPL" in passing ("implementation plan (IMPL)") but does not explain what to do after adding a repo.
- "No plan selected" is a dead end — no call-to-action.
- Seven model selectors visible on first load overwhelm without context.
- "New Plan" button text does not say "Scout" or explain what happens.
- "New Program" is visible but meaningless without understanding single-feature flow first.

### 1.3 Friction Classification

| Friction Point | Must Learn Before Using | Can Learn By Doing |
|---|---|---|
| What a Scout does | Must learn | - |
| IMPL doc structure (YAML format, sections) | - | Can learn by doing (read after Scout produces one) |
| Wave concept (parallel groups) | - | Can learn by doing (see it happen) |
| File ownership (I1) | - | Can learn by doing (see the table) |
| Interface contracts (I2) | - | Can learn by doing (see scaffold section) |
| Scaffold Agent role | - | Can learn by doing (it runs automatically) |
| Suitability gate (5 questions) | - | Can learn by doing (see SUITABLE/NOT SUITABLE verdict) |
| Wave sequencing (I3) | - | Can learn by doing (system handles it) |
| Worktree isolation | - | Can learn by doing (invisible to user) |
| Seven participant roles | - | Can learn later (most are invisible) |
| `sawtools` binary and its 20+ commands | Must learn (to install) | Can defer (skill handles orchestration) |
| `saw.config.json` format | Must learn (for web app) | Can defer (CLI auto-detects) |
| Agent permissions in Claude Code | Must learn | - |
| Three-repo architecture | Must learn (to install) | Can defer understanding why |

**Key insight:** Only 3 things genuinely must be learned before first use: (1) a Scout analyzes your code and produces a plan, (2) you review the plan, (3) you approve and agents implement in parallel. Everything else can be deferred.

---

## 2. Competitor Onboarding Teardown

### 2.1 Agent Orchestrator: Zero-Config Flow

**What makes it work:**

```bash
ao start https://github.com/your-org/your-repo
```

One command. AO:
- Clones the repo (or uses existing clone)
- Auto-generates config via hash-based namespacing (no user input)
- Detects project structure (language, build system)
- Launches the web dashboard
- Shows a ready-to-use interface

**What they hide from users:**
- Session lifecycle state machine (15+ states) — user sees "running" or "done"
- Plugin architecture — auto-detected, user never chooses
- Runtime isolation (tmux/Docker/K8s) — auto-selected
- Branch naming conventions — auto-generated from issue IDs
- Agent adapter selection — auto-detected from environment

**What they front-load:**
- Nothing. The only input is a repo URL.

**Trade-off they accept:** No correctness guarantees. Two agents can silently edit the same file. Merge conflicts surface at PR time. This is the price of zero-config: no planning phase means no ownership verification.

**What SAW can borrow without sacrificing correctness:** The single-command entry point. SAW's Scout phase is the value prop — it should not be hidden. But everything *before* the Scout (install, config, permissions, verify) can be collapsed into one command.

### 2.2 Paperclip: Corporate Metaphor as Onboarding

**Their onboarding:**

```bash
npx paperclipai onboard --yes
```

One command that:
- Installs dependencies
- Sets up the database (PGlite for dev)
- Creates a default company
- Starts the server
- Opens the dashboard

**What they front-load:**
- The "company" metaphor: you hire agents, set budgets, define goals
- This is immediately intuitive even if the user does not understand the internals

**What they defer:**
- Budget policies (can add later)
- Agent adapters (defaults to Claude Code)
- Governance rules (defaults to "board approves everything")
- Cost tracking details (visible but not required)

**Key lesson:** A strong metaphor reduces cognitive load. "Company with employees" is immediately graspable. "Protocol with invariants" is not — even though SAW's invariants are what make it correct.

### 2.3 What Competitors Defer vs Front-Load

| Concept | AO | Paperclip | SAW (current) |
|---|---|---|---|
| Project setup | Auto-detect | One command | 9 steps |
| Planning phase | None (skip to execution) | CEO delegates tasks | Scout (required, must understand) |
| Correctness model | None | None | 6 invariants (front-loaded in docs) |
| Agent roles | Hidden (one agent per issue) | Corporate metaphor (CEO, CTO, engineer) | 7 roles (front-loaded in README) |
| Configuration | Zero-config | `--yes` defaults | Manual `saw.config.json` + 3 repos |
| First productive use | 30 seconds | 2 minutes | 15-30 minutes |

---

## 3. Progressive Disclosure Design

### Level 0: Zero Protocol Knowledge (30 seconds)

**What the user can do:**
- Run `saw init` in any project directory
- System auto-detects language, build commands, test commands
- System generates config with sensible defaults
- User sees: "Ready. Run `saw plan 'your feature'` to get started."

**What they need to understand:**
- SAW plans features before building them
- You review the plan before agents start

**What the system hides:**
- Protocol invariants (I1-I6)
- Execution rules (E1-E41)
- Participant roles (all seven)
- IMPL doc format (YAML structure)
- Worktree isolation mechanics
- Scaffold agent existence
- Wave sequencing rules
- Three-repo architecture

**What the UI/CLI should look like:**

```
$ saw init
Detected: Go project (go.mod found)
  Build: go build ./...
  Test:  go test ./...

SAW is ready. Next steps:
  saw plan "describe your feature"     Plan a feature (Scout analyzes your code)
  saw serve                            Open the web dashboard
```

### Level 1: First Feature (5 minutes)

**What the user can do:**
- Run `saw plan "add caching to the API client"`
- See the plan summary in plain English (not raw YAML)
- Approve or reject
- Watch agents work in parallel
- See the merged result

**What they need to understand:**
- The plan shows which files each agent will change (file ownership)
- They should review the plan before approving
- Agents work in parallel and merge automatically

**What the system hides:**
- IMPL doc YAML internals (show a rendered summary instead)
- Interface contract details (show only if scaffolds are needed)
- Wave numbering (show as "Wave 1", "Wave 2")
- Suitability gate mechanics (show verdict, not the 5 questions)
- Verification gate details (show pass/fail, not individual checks)

**What the UI/CLI should look like:**

```
$ saw plan "add caching to the API client"

Analyzing your codebase...

Plan: Add caching to the API client
  Status: Suitable for parallel implementation

  Wave 1 (2 agents working in parallel):
    Agent A: Cache interface and in-memory implementation
      Creates: src/cache/cache.go, src/cache/memory.go, src/cache/cache_test.go
    Agent B: HTTP client integration
      Modifies: src/client/client.go, src/client/options.go, src/client/client_test.go

  Shared types (created before agents start):
    src/cache/types.go — CacheInterface definition

  Approve this plan? [Y/n]
```

### Level 2: Power User (30 minutes)

**What the user can do:**
- Understand and edit IMPL docs directly
- Use `--model` overrides for different agents
- Run `/saw amend --add-wave` to extend plans
- Use the interview system for requirements gathering
- Configure quality gates
- Run programs (multi-feature orchestration)

**What they need to understand:**
- IMPL doc structure (YAML sections, what each means)
- Wave sequencing and why Wave 2 waits for Wave 1
- Interface contracts and scaffold files
- Model selection per role
- Quality gate configuration

**What the system reveals:**
- Full IMPL doc YAML access
- Per-role model configuration
- Gate configuration
- Amendment commands
- Program-level orchestration

### Level 3: Protocol Mastery (ongoing)

**What the user can do:**
- Build custom implementations in other languages
- Understand invariant enforcement mechanics
- Write custom verification gates
- Contribute to the protocol specification
- Run cross-repo waves

**What they need to understand:**
- All six invariants and why each matters
- Execution rules and state machine
- Worktree isolation layers (0-4)
- Cross-repo orchestration
- Program invariants (P5)

---

## 4. Concrete Proposals

### 4.1 Zero-Config CLI Entry Point

**Command:** `saw init`

**Behavior:**

```
saw init [--repo <path>] [--force]
```

1. **Auto-detect project:**
   - Scan for `go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `Makefile`, `Gemfile`
   - Determine language, build command, test command
   - Determine if project uses monorepo structure (multiple go.mod, workspaces)

2. **Generate `saw.config.json`:**
   ```json
   {
     "repos": [{ "path": "/current/directory", "name": "my-project" }],
     "build": { "command": "go build ./...", "detected": true },
     "test": { "command": "go test ./...", "detected": true },
     "agent": {
       "scout_model": "claude-sonnet-4-6",
       "wave_model": "claude-sonnet-4-6"
     }
   }
   ```

3. **Run verify-install** (check for sawtools, git version, etc.)

4. **If sawtools is missing**, print install instructions:
   ```
   sawtools not found. Install it:
     go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest

   Or build from source:
     git clone https://github.com/blackwell-systems/scout-and-wave-go.git
     cd scout-and-wave-go && go build -o ~/.local/bin/sawtools ./cmd/sawtools
   ```

5. **Print next steps:**
   ```
   SAW initialized for my-project (Go).

   Quick start:
     saw plan "describe your feature"     Create an implementation plan
     saw serve                            Open the web dashboard

   Learn more:
     saw help                             All commands
     https://saw.dev/quickstart           Step-by-step guide
   ```

**Implementation:**
- **Repo:** scout-and-wave-go (`cmd/sawtools/init_cmd.go`)
- **Effort:** Medium (new command, project detection heuristics, config generation)
- **Dependencies:** None

**Design decisions:**
- `saw init` (not `sawtools init`) — use the simpler binary name for the entry point. The web app binary is already called `saw`; unify the CLI name.
- Do not require cloning the protocol repo for basic usage. The protocol repo is for skill files (Claude Code) and protocol specification. If the user is using the web app or standalone CLI, they do not need it.
- `--force` overwrites existing config.

### 4.2 Guided First Run

**Design:** A first-run experience built into the existing interfaces, not a separate tutorial.

#### CLI First Run (`/saw` skill in Claude Code)

**Current behavior:** Pre-flight validation checks sawtools, skill files, git version, config. If anything fails, prints what is missing and stops.

**Proposed behavior:** If pre-flight detects this is the first run (no `saw.config.json`, no `docs/IMPL/` directory), switch to guided mode:

```
This looks like your first time using SAW in this project.

SAW works in two steps:
  1. Plan — A Scout agent analyzes your codebase and creates an implementation plan
  2. Build — Parallel agents implement the plan in isolated git branches

Let's try it. Describe a feature you want to add:
> add a health check endpoint to the API

Launching Scout to analyze your codebase...
```

The orchestrator then runs the normal Scout flow but with enhanced output that explains what is happening at each step:

```
Scout is reading your codebase to understand the architecture...
Scout is checking if this feature can be split into parallel work...
  Result: Suitable — the work splits into 2 independent agents

Scout is assigning files to agents...
  Agent A will create: pkg/health/handler.go, pkg/health/handler_test.go
  Agent B will modify: cmd/server/routes.go, cmd/server/routes_test.go

Scout is defining the interface between agents...
  Both agents need: type HealthChecker interface { Check(ctx) HealthResult }
  This will be created as a shared file before agents start.

Plan saved to docs/IMPL/IMPL-health-check.yaml

Review the plan above. If it looks right:
  /saw wave          Launch the agents
  /saw status        Check progress anytime
```

**Key differences from current behavior:**
- Explains "why" at each step, not just "what"
- Uses plain language ("files," "agents," "plan") not protocol terms ("IMPL doc," "I1," "E16")
- Shows the plan inline instead of pointing to a YAML file
- Gives explicit next-step commands

**Implementation:**
- **Repo:** scout-and-wave (skill prompt modifications in `implementations/claude-code/prompts/saw-skill.md`)
- **Effort:** Small (conditional prompt section for first-run detection)
- **Dependencies:** None

#### Web App First Run

**Current behavior:** WelcomeCard says "add a repository in Settings" then stops.

**Proposed behavior:** Replace WelcomeCard with a 3-step guided flow:

**Step 1: "Where's your code?"**
- Show a directory picker (already have `DirPicker` component)
- Auto-validate the path (already have `validateRepoPath`)
- Auto-detect language and build/test commands
- Save to config automatically

**Step 2: "What do you want to build?"**
- Show a text input: "Describe a feature to add to your project"
- Example suggestions based on detected project type:
  - Go: "Add a health check endpoint", "Add structured logging"
  - React: "Add a dark mode toggle", "Add search to the sidebar"
  - Python: "Add input validation to the API", "Add caching with Redis"
- "Plan this feature" button that triggers the Scout

**Step 3: "Review the plan"**
- Auto-navigate to the ReviewScreen when Scout completes
- Highlight the key sections with inline explanations:
  - "These are the files each agent will change" (file ownership table)
  - "This is the shared interface they'll both use" (scaffold section)
  - "Approve to start building" (approve button)

**Implementation:**
- **Repo:** scout-and-wave-web (`web/src/components/Onboarding.tsx` — new component replacing WelcomeCard)
- **Effort:** Medium (new component, 3-step wizard, project detection API endpoint)
- **Dependencies:** Project detection logic from 4.1 (shared with `saw init`)

### 4.3 Web App Empty State

**Current state:** When repos are configured but no IMPL is selected, the user sees "No plan selected — Select a plan from the sidebar or create a new one with New Plan."

**Problems:**
- "Plan" is SAW-specific jargon (it means IMPL doc, but that is also jargon)
- The call-to-action ("New Plan") does not explain what will happen
- The sidebar may be empty if no IMPL docs exist yet
- The header shows "New Program" which is a Level 2+ concept

**Proposed empty state (repos configured, no IMPLs exist):**

```
No implementation plans yet.

A plan describes how SAW will split a feature into parallel work units.
Each agent gets its own files and works independently.

Create your first plan:
  [Text input: "Describe a feature to add..."]
  [Create Plan button]

Or try one of these examples:
  "Add structured logging"
  "Add a health check endpoint"
  "Refactor auth to use middleware"
```

**Proposed empty state (repos configured, IMPLs exist but none selected):**

```
[Keep current "No plan selected" but add:]

Recent activity:
  IMPL-health-check    Complete (2 agents, 1 wave)     2 hours ago
  IMPL-auth-refactor   Wave 1 in progress              Running now

[Click any plan to review it]
```

**Implementation:**
- **Repo:** scout-and-wave-web (modify `App.tsx` empty state block and WelcomeCard)
- **Effort:** Small (replace static text with dynamic content)
- **Dependencies:** None

### 4.4 Concept Renaming Audit

| Current Term | Problem | Proposed Change | Rationale |
|---|---|---|---|
| **Scout** | Unclear to newcomers. "Scout" suggests reconnaissance, which is roughly correct, but provides no hint about output. | Keep "Scout" but always pair with explanation: "Scout (analyzes your code and creates a plan)". In UI, use "Plan" as the verb: "New Plan" not "New Scout". | The Scout metaphor works once explained. It is the first-run explanation that is missing, not the name. |
| **IMPL doc** | Terrible. "IMPL" is an internal abbreviation. "Implementation Document" is better but still opaque. | Rename to **"plan"** in all user-facing contexts. Keep "IMPL doc" in protocol docs and developer-facing code. File path stays `docs/IMPL/IMPL-*.yaml`. | Users understand "plan." The file format is an implementation detail. |
| **Wave** | Acceptable but needs context. Users may think "wave" is a metaphor for something else. | **Keep "wave."** It's distinctive, memorable, and actually describes parallel execution. "Phase" is too generic and has waterfall connotations. Add contextual explanation on first encounter: "Wave 1 — a group of agents working in parallel." | "Wave" becomes intuitive after one use. Renaming to "phase" loses the distinctive SAW identity for no clarity gain. |
| **File ownership** | Good. Self-explanatory. | Keep as-is. | No change needed. |
| **Interface contracts** | Good for developers. Slightly formal. | Keep as-is but add a one-line explanation on first encounter: "Interface contracts — the function signatures agents agree to implement." | Developers understand interfaces. The word "contract" adds precision. |
| **Scaffold files** | Opaque. "Scaffold" is overloaded (Rails scaffolding, construction scaffolding). | **Keep "scaffold"** — developers understand the metaphor. Add contextual tooltip: "Scaffold: shared code files created before agents start, so they agree on interfaces." "Shared types" is too narrow (scaffolds can be interfaces, stubs, configs). | The word is fine; the missing explanation is the problem. |
| **Orchestrator** | Fine for power users. Overwhelming for newcomers (it is one of seven roles). | Do not expose to Level 0/1 users. The orchestrator is invisible — it is just "SAW." | Users do not need to know that their Claude Code session is technically an "Orchestrator." |
| **Suitability gate** | Good concept, jargon name. | Rename to **"compatibility check"** in user-facing contexts. | "SAW checked if this feature can be parallelized" vs "the suitability gate evaluated five preconditions." |
| **Invariant** | Protocol jargon. Users should never see this word. | Never use in user-facing text. Use "rule" or "guarantee" instead. | "SAW guarantees no two agents edit the same file" vs "Invariant I1: disjoint file ownership." |
| **Critic Agent** | Clear enough. | Keep but do not surface until Level 2. | Users do not need to know about the critic on first use. |
| **Integration Agent** | Clear enough. | Keep but do not surface until Level 2. Label in UI as "post-merge wiring." | |
| **Planner** | Clear. | Keep. Surface only in program context. | |
| **Program** | Overloaded word but acceptable in context. | Keep. Surface only at Level 2+. | |

**Specific UI changes in the web app:**

1. **AppHeader:** Hide `CRITIC`, `SCAFFOLD`, `INTEGRATION`, `PLANNER` model selectors behind an "Advanced" toggle. Show only `SCOUT` (labeled "Plan") and `WAVE` (labeled "Build") by default.
2. **AppHeader:** Rename "New Plan" to "New Plan" (keep) but add tooltip: "Scout analyzes your code and creates an implementation plan."
3. **AppHeader:** Hide "New Program" behind the "Advanced" toggle or move to Settings.
4. **SidebarNav:** Label IMPL entries as "Plans" not "IMPLs."
5. **ReviewScreen:** Add section headers with one-line explanations:
   - "File Assignment — Which files each agent will create or modify"
   - "Scaffolds — Shared code files created before agents start so they agree on interfaces"
   - "Waves — Groups of agents that work in parallel"

**Implementation:**
- **Repo:** scout-and-wave-web (UI label changes across multiple components)
- **Repo:** scout-and-wave (skill prompt — use "plan" in user-facing output, keep "wave" and "scaffold" with explanations)
- **Effort:** Medium (many small changes across both repos)
- **Dependencies:** None

### 4.5 Error Messages as Teaching Moments

#### Error: sawtools not installed

**Current message (from pre-flight in saw-skill.md):**
> "sawtools on PATH: blocker if missing"

The skill prompt tells the orchestrator to "print what's missing and how to install it (see `docs/INSTALLATION.md`)" but the actual error is LLM-generated and varies.

**Proposed standard error:**
```
SAW needs the 'sawtools' command-line tool, but it's not installed.

Install it (choose one):
  go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest

  Or build from source:
    git clone https://github.com/blackwell-systems/scout-and-wave-go.git
    cd scout-and-wave-go && go build -o ~/.local/bin/sawtools ./cmd/sawtools

Then add to your PATH if needed:
  export PATH="$HOME/.local/bin:$PATH"

After installing, try your command again.
```

**Implementation:** Add this as a verbatim string in the skill prompt's pre-flight section, not as a "see docs" reference. The LLM should emit this exact text, not paraphrase it.

#### Error: Running waves without a Scout

**Current behavior:** If a user runs `/saw wave` with no IMPL docs, the orchestrator runs `sawtools list-impls`, gets an empty list, and produces an LLM-generated error.

**Proposed standard error:**
```
No implementation plans found in this project.

Before running agents, you need a plan. A plan tells SAW which files each
agent should work on so they don't conflict.

Create a plan:
  /saw scout "describe the feature you want to build"

The Scout will analyze your codebase and produce a plan for you to review.
```

#### Error: IMPL doc validation failure (E16)

**Current behavior:** The orchestrator runs `sawtools validate`, gets structured JSON errors, and presents them. The errors are technical (missing fields, invalid YAML, schema violations).

**Proposed enhancement:** Wrap each validation error with a "what this means" explanation:

```
Plan validation found 2 issues:

1. Missing file_ownership for agent B
   What this means: Agent B has a task description but no files assigned.
   Every agent needs at least one file to work on.
   Fix: Add files to agent B's ownership list, or remove agent B if
   its work is covered by another agent.

2. Duplicate file: src/api/handler.go assigned to both Agent A and Agent B
   What this means: Two agents would try to edit the same file, which
   causes merge conflicts. Each file must belong to exactly one agent.
   Fix: Move src/api/handler.go to one agent and remove it from the other.
```

**Implementation:**
- **Repo:** scout-and-wave-go (add `UserMessage string` field to validation errors in `pkg/protocol/validate.go`)
- **Repo:** scout-and-wave (update skill prompt to use UserMessage when available)
- **Effort:** Medium (add human-readable messages to ~15 validation error types)
- **Dependencies:** None

#### Error: Agent tool not allowed

**Current behavior:** Claude Code says the Agent tool is not permitted.

**Proposed standard error (in skill prompt pre-flight):**
```
SAW needs permission to launch background agents, but it's not allowed yet.

Add this to ~/.claude/settings.json:
  {
    "permissions": {
      "allow": ["Agent"]
    }
  }

Then restart Claude Code and try again.

Why: SAW runs Scout and Wave agents in the background. Without this
permission, it cannot launch any agents and cannot function.
```

#### Error: Git version too old

**Proposed standard error:**
```
SAW needs Git 2.20 or newer, but you have Git <version>.

Why: SAW creates isolated git worktrees for each agent. Worktree support
was added in Git 2.20.

Update Git:
  macOS:  brew install git
  Ubuntu: sudo apt-get install git
  Other:  https://git-scm.com/downloads
```

#### Error: Wave agent fails in worktree

**Current behavior:** Agent completion report shows status "blocked" or "partial." The orchestrator presents the raw completion report.

**Proposed enhancement:**
```
Agent B encountered a problem during Wave 1.

Status: Partial completion
  Files completed: 2 of 3
  Build: Passing
  Tests: 1 failure in src/client/client_test.go

What happened: Agent B could not resolve a test failure in client_test.go.
The build passes but one test assertion fails.

Options:
  /saw wave                     Retry the failed agent
  /saw amend --redirect-agent B Re-assign agent B with updated instructions
  (edit the plan manually)      Fix the IMPL doc and re-run
```

**Implementation across all errors:**
- **Repo:** scout-and-wave (skill prompt — add verbatim error templates for the 6 most common errors)
- **Repo:** scout-and-wave-go (add `UserMessage` to validation errors and build diagnostics)
- **Repo:** scout-and-wave-web (add error explanation panels to ReviewScreen and WaveBoard)
- **Effort:** Medium (error template catalog + UI work)

### 4.6 ~~Unified Binary Name~~ REJECTED

**Decision:** Keep two separate binaries. The CLI (`sawtools`) doesn't need the web app, and the web app (`saw`) doesn't need the CLI. Merging them conflates installation friction with architectural coupling.

- **`sawtools`** — protocol engine CLI for the `/saw` skill, CI pipelines, SDK consumers. No web dependency.
- **`saw`** — web app binary. Imports Go engine as a library. Embeds React. Serves HTTP/SSE.

They share the engine (`pkg/`), not each other. That's correct architecture.

**The real fix for installation friction is `go install`** (make both binaries easy to install), not merging them. See Tier 2 priority.

**Note:** The fact that this proposal was generated at all is itself an onboarding signal — the two-binary architecture and its rationale need to be documented clearly in INSTALLATION.md and the README. If a researcher reading the codebase can't tell why they're separate, new users can't either.

### 4.7 `saw plan` as Alias for Scout

**Current state:** `/saw scout "feature"` is the command. "Scout" is protocol jargon.

**Proposal:** Add `saw plan "feature"` as an alias. Both work; `plan` is recommended for new users, `scout` for power users and documentation.

In the web app, the "New Plan" button already uses "Plan" language. This makes CLI and web consistent.

**Implementation:**
- **Repo:** scout-and-wave-go (alias in command routing)
- **Repo:** scout-and-wave (update skill prompt to accept `/saw plan` as equivalent to `/saw scout`)
- **Effort:** Small
- **Dependencies:** None

### 4.8 Wave Execution Alias (Rejected: `saw build`)

**Current state:** `/saw wave` launches the next wave. "Wave" is protocol jargon.

**Original proposal:** Add `saw build` as an alias. This was **rejected** — "build" conflicts with the compile/build step that SAW already runs as part of verification gates, creating ambiguity ("build the plan" vs "build the code").

**If an alias is needed:** `saw run` is the preferred alternative ("run the next wave"). However, `saw wave` is acceptable as-is — per the concept renaming audit (Section 4.4), "wave" is distinctive, memorable, and becomes intuitive after one use. Adding an alias is lower priority than the `saw plan` alias (Section 4.7) since users encounter `plan`/`scout` first.

**Implementation (if pursued):**
- **Repo:** scout-and-wave-go (alias in command routing)
- **Repo:** scout-and-wave (update skill prompt)
- **Effort:** Small
- **Dependencies:** None

---

## 5. Implementation Priority

### Tier 1: Highest Impact, Lowest Effort (do first)

| # | Proposal | Impact | Effort | Repos | Dependencies |
|---|---|---|---|---|---|
| 1 | **4.5 Error messages as teaching moments** (skill prompt templates) | High — every new user hits at least one error | Small | scout-and-wave | None |
| 2 | **4.7 `saw plan` alias** | High — removes first jargon barrier | Small | scout-and-wave-go, scout-and-wave | None |
| 3 | **4.8 `saw run` alias** (if needed; `saw wave` is acceptable) | Low — "wave" is distinctive and learnable | Small | scout-and-wave-go, scout-and-wave | None |
| 4 | **4.4 Concept renaming** (UI labels only) | High — reduces cognitive load on every page | Small-Medium | scout-and-wave-web | None |

### Tier 2: High Impact, Medium Effort (do second)

| # | Proposal | Impact | Effort | Repos | Dependencies |
|---|---|---|---|---|---|
| 5 | **4.2 Guided first run** (CLI skill prompt changes) | High — transforms first experience | Medium | scout-and-wave | None |
| 6 | **4.3 Web app empty state** redesign | High — eliminates dead-end first impression | Medium | scout-and-wave-web | None |
| 7 | **4.1 `saw init`** command | High — replaces 9-step install with 1 command | Medium | scout-and-wave-go | None |
| 8 | **`go install` distribution** for sawtools | High — without this, `saw init` still requires building from source | Small | scout-and-wave-go | None |
| 9 | **4.5 Error messages** (Go-side UserMessage fields) | Medium — better diagnostics compound over time | Medium | scout-and-wave-go | None |

### Tier 3: High Impact, Large Effort (do third)

| # | Proposal | Impact | Effort | Repos | Dependencies |
|---|---|---|---|---|---|
| 10 | **4.2 Guided first run** (web app onboarding wizard) | High — transforms web app first experience | Large | scout-and-wave-web, scout-and-wave-go | 4.1 (project detection logic) |
| 11 | **4.4 Concept renaming** (protocol doc updates, blog references) | Low-Medium — docs are secondary to the product experience | Large | scout-and-wave | After UI changes settle |

### Tier 4: Nice to Have

| # | Proposal | Impact | Effort | Repos |
|---|---|---|---|---|
| 12 | Homebrew formula for `saw` | Medium — macOS users expect this | Medium | New repo (homebrew-tap) |
| 13 | Interactive web tutorial (guided overlay) | Medium — web-specific onboarding | Large | scout-and-wave-web |

---

## 6. Review Findings (integrated 2026-03-22)

Independent review verdict: **APPROVE WITH CHANGES**. Status of each condition:

### Resolved
- **4.6 Unified binary** — REJECTED. Two binaries stay separate (sawtools = CLI, saw = web app). Rationale documented in 4.6 section.
- **Phase vs Wave inconsistency** — FIXED. All mocks now use "Wave", not "Phase".
- **FTUE deferral** — RESOLVED. FTUE analysis reviewed item-by-item; most items already implemented. Remaining 3 minor items tracked separately.
- **FTUE 1.4 Approve confirmation** — REJECTED. Tooltip already explains action; double-click friction unacceptable.
- **`go install` priority** — MOVED to Tier 1 (see revised priority below).

### Open (still to address)
- **First-run detection reconciliation:** `saw init` checks `saw.config.json`; skill guided mode checks `docs/IMPL/`. Need single signal. Recommendation: `saw.config.json` existence is the canonical "initialized" flag.
- **CHAT model visibility in header:** Plan proposes hiding advanced model selectors but doesn't mention CHAT. Recommendation: show SCOUT, WAVE, CHAT by default; hide CRITIC, SCAFFOLD, INTEGRATION, PLANNER behind Advanced toggle.
- **Web onboarding wizard split:** Decouple generic wizard (no project detection dependency) from language-specific examples. Generic version can ship in Tier 2 without `saw init`.
- **Team lead / evaluator persona:** README needs "What does it look like?" with screenshot/recording in first 20 lines. Not addressed by current plan.
- **"Just try it" persona:** Can `saw plan "feature"` work without `saw init`? Auto-detect everything on the fly for the zero-commitment trial.
- **Onboarding metrics:** No way to measure if improvements work. Suggest: time from init to first merge, abandonment rate per step, error frequency by type.

### Second review (2026-03-24)

**Pushbacks:**

1. **4.7 `saw plan` alias — DEFERRED.** The CLI is invoked via `/saw scout` inside Claude Code — there is no standalone `saw` binary for CLI users. The alias would need to live in the skill prompt as routing logic, not in sawtools. Additionally, "plan" is already overloaded: it is a noun (the IMPL doc), a verb in `/saw program plan`, and would become a second verb meaning "run the scout." This creates ambiguity. Revisit only if a standalone CLI entry point is built.

2. **4.1 `saw init` — DESCOPED.** The web app has its own setup flow. CLI users install via `install.sh` which handles clone + build + symlink + permissions in one invocation. The stated "9 steps" inflates the problem — `install.sh` is already a single command. The real installation friction is building sawtools from source, which `go install` (Tier 2, item 8) solves directly. `saw init` adds surface area without addressing the actual bottleneck. Keep the project-detection logic in the backlog for the web onboarding wizard, but do not build a separate CLI command for it.

3. **4.2 Guided first-run — RESTRUCTURE.** Adding ~50 lines to the skill prompt for a path that fires once per project is expensive context for every subsequent invocation. Move the guided first-run content into a reference file (e.g., `references/first-run.md`) loaded on first-run detection, same pattern as `program-flow.md` and `amend-flow.md`. The routing table in the core skill adds one line; the content loads on demand.

4. **Section 6 "Open" items underweighted.** The screenshot/recording for evaluators ("What does it look like?" in README first 20 lines) and the zero-commitment trial (`/saw scout` auto-detects everything without init) would have more impact than error message templates. A 10-second GIF showing Scout → review → wave → merge would convert more evaluators than any amount of better error messages.

**Revised priority order:**

### Tier 1: Highest Impact (do first)

| # | Proposal | Impact | Effort | Rationale |
|---|---|---|---|---|
| 1 | **`go install` for sawtools** | High | Small | Eliminates the real installation friction (building Go from source). Single command: `go install github.com/blackwell-systems/scout-and-wave-go/cmd/sawtools@latest` |
| 2 | **Web app empty state redesign (4.3)** | High | Small | Immediate payoff. Replaces dead-end "No plan selected" with call-to-action. No dependencies. |
| 3 | **Error message templates in skill prompt (4.5, prompt-side only)** | High | Small | Verbatim error strings for the 6 most common failures. No Go changes needed. |
| 4 | **Hide advanced model selectors (4.4, UI labels)** | High | Small | Show SCOUT, WAVE, CHAT; hide CRITIC, SCAFFOLD, INTEGRATION, PLANNER behind Advanced toggle. |
| 5 | **README screenshot/recording** | High | Small | 10-second GIF of Scout → review → wave → merge in first 20 lines. Converts evaluators. |

### Tier 2: Medium Impact (do second)

| # | Proposal | Impact | Effort | Rationale |
|---|---|---|---|---|
| 6 | **Guided first-run as reference file (4.2 restructured)** | High | Medium | On-demand reference loaded on first-run detection. No prompt bloat. |
| 7 | **Error messages Go-side (4.5, UserMessage fields)** | Medium | Medium | Better diagnostics compound over time. |
| 8 | **Web onboarding wizard (4.2 web, generic version)** | High | Medium | 3-step wizard without project-detection dependency. |
| 9 | **Concept renaming in UI (4.4 full)** | Medium | Medium | "Plans" not "IMPLs" in sidebar, section explanations in ReviewScreen. |

### Tier 3: Lower Priority

| # | Proposal | Impact | Effort | Rationale |
|---|---|---|---|---|
| 10 | **`saw plan` alias (4.7)** | Low | Small | Deferred — overloads "plan" and no standalone CLI exists. Revisit if CLI entry point is built. |
| 11 | **`saw init` command (4.1)** | Low | Medium | Descoped — `install.sh` and `go install` cover the real friction. |
| 12 | **Protocol doc renaming (4.4 docs)** | Low | Large | Docs are secondary to the product experience. |
| 13 | **Homebrew formula** | Medium | Medium | macOS convenience. Depends on `go install` working first. |
| 14 | **Interactive web tutorial** | Medium | Large | Guided overlay in web app. Nice to have. |

## 7. Anti-Patterns to Avoid

### 6.1 Do Not Hide the Protocol Entirely

The protocol is the value proposition. AO has zero correctness guarantees and users hit merge conflicts constantly. SAW's planning phase is why it works. The goal is not "make SAW as simple as AO" — it is "make users productive before they understand the protocol, then teach the protocol as they need it."

**Concrete rule:** Every feature that hides protocol complexity must have a natural path to revealing it. The "plan" alias leads to discovering "scout." The "build" alias leads to discovering "wave." The simplified ReviewScreen leads to the full YAML.

### 6.2 Do Not Create a "Beginner Mode" Dead End

Do not build a separate simplified interface that diverges from the real one. Every simplification should be a layer on top of the real system:
- `saw plan` calls the same code as `saw scout`
- The guided first run uses the same IMPL doc format
- The web onboarding wizard writes the same `saw.config.json`

Users who outgrow Level 0 should find themselves already in Level 1, not needing to migrate.

### 6.3 Do Not Add Tutorials That Go Stale

The current QUICKSTART.md files show example output that will drift from reality as the product evolves. Instead:
- **CLI guided mode** generates explanations dynamically from actual Scout output
- **Web onboarding** uses the user's actual codebase, not a tutorial repo
- **Error messages** are embedded in the code path that produces the error, so they stay synchronized

### 6.4 Do Not Sacrifice Power-User Workflows

Every onboarding simplification must be additive, not reductive:
- `saw plan` is an alias, not a replacement — `saw scout` still works
- "Build" is a command alias, not a schema change — YAML still says `wave`
- The advanced model selectors are hidden behind a toggle, not removed
- The `--auto` flag, `--model` overrides, amendment commands, and program orchestration remain unchanged

### 6.5 Do Not Optimize Onboarding for the Wrong Persona

SAW's target users are developers who have already experienced the pain of parallel agent conflicts. They do not need to be sold on the problem — they need to see that SAW solves it. Onboarding should demonstrate the solution (file ownership, plan review, clean merge) not explain the problem (merge conflicts, race conditions, divergent assumptions).

**Wrong:** "Have you ever had two AI agents edit the same file? SAW prevents that."
**Right:** "SAW assigns every file to one agent. Here's the plan — review it before agents start."

---

## Appendix: File References

Key files that would be modified by these proposals:

**scout-and-wave (protocol repo):**
- `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md` — skill prompt (guided first run, error templates, plan/build aliases)
- `/Users/dayna.blackwell/code/scout-and-wave/docs/INSTALLATION.md` — simplify to reference `saw init`
- `/Users/dayna.blackwell/code/scout-and-wave/docs/GETTING_STARTED.md` — rewrite around progressive disclosure levels
- `/Users/dayna.blackwell/code/scout-and-wave/README.md` — simplify Quick Start to `saw init` + `saw plan`

**scout-and-wave-go (Go engine):**
- `/Users/dayna.blackwell/code/scout-and-wave-go/cmd/sawtools/` — new `init_cmd.go`, aliases for `plan`/`build`
- `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/protocol/validate.go` — add `UserMessage` to validation errors
- `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/engine/runner.go` — enhanced error context in `RunScout`, `RunSingleWave`

**scout-and-wave-web (web app):**
- `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/App.tsx` — replace WelcomeCard, improve empty states
- `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/layout/AppHeader.tsx` — hide advanced model selectors, rename labels
- `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/SettingsScreen.tsx` — integrate into onboarding flow
- `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/ReviewScreen.tsx` — add section explanations
