# Changelog

All notable changes to the Scout-and-Wave protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Version History

| Version | Date | Headline |
|---------|------|----------|
| [0.7.0] | 2026-03-06 | Bootstrap: Scaffold Agent + Wave 1 handoff steps added; bootstrap now fully continuous |
| [0.6.9] | 2026-03-06 | Bootstrap: structured requirements intake via docs/REQUIREMENTS.md |
| [0.6.8] | 2026-03-05 | IMPL docs moved to docs/IMPL/ subdirectory to reduce clutter |
| [0.6.7] | 2026-03-05 | Wave Agent: explicit worktree isolation protocol using git -C flag |
| [0.6.6] | 2026-03-04 | Custom agent subtypes (optional); scout agent definition synced to v0.4.0; suitability gate question count fix |
| [0.6.5] | 2026-03-04 | SAW skill implements E7a: automatic retry logic for correctable agent failures |
| [0.6.4] | 2026-03-04 | E7a protocol rule: automatic failure remediation in --auto mode (spec) |
| [0.6.3] | 2026-03-04 | Scaffold Agent: repository context derivation from IMPL doc location |
| [0.6.2] | 2026-03-04 | Scout automatically detects shared types for scaffold files |
| [0.6.1] | 2026-03-03 | Scout status table includes scaffold rows with commit SHAs |
| [0.6.0] | 2026-03-03 | Scaffold Agent: new participant; Scout defines contracts, Scaffold Agent materializes them after review |
| [0.5.3] | 2026-03-03 | Deep consistency pass: 15 issues across 12 files |
| [0.5.2] | 2026-03-03 | I2 invariant updated: Scout defines and implements interface contracts |
| [0.5.1] | 2026-03-03 | Consistency pass: E-rule count, scaffold handling, Scout definition |
| [0.5.0] | 2026-03-03 | Wave 0 collapsed into Scout phase; solo-agent short-circuit removed |
| [0.4.4] | 2026-03-03 | saw-teams/example-settings.json; all required config fields in one copyable block |
| [0.4.3] | 2026-03-03 | saw-teams hooks, README, and spawn step; complete Agent Teams integration |
| [0.4.2] | 2026-03-03 | saw-teams prompt set synced to protocol v0.4.1; all invariants/E-rules propagated |
| [0.4.1] | 2026-03-03 | `test_command` field in IMPL doc; post-merge gate explicitly runs it unscoped |
| [0.4.0] | 2026-03-02 | Spec completeness pass: E1–E14 numbered, six spec holes patched, state machine diagram, all invariants embedded in skill, conformance criteria |
| [0.3.7] | 2026-03-01 | Orchestrator owns linter auto-fix post-merge; agents run check-only |
| [0.3.6] | 2026-03-01 | SAW tag format for claudewatch wave/agent observability |
| [0.3.5] | 2026-03-01 | I-number anchors for cross-referencing; I6 role separation invariant added |
| [0.3.4] | 2026-03-01 | Eight protocol gaps closed; Execution Rules section added |
| [0.3.3] | 2026-03-01 | Solo wave path formalized; 9-field agent template; conflict taxonomy |
| [0.3.2] | 2026-02-28 | Draw.io flow diagrams with light/dark SVG exports |
| [0.3.1] | 2026-02-28 | Structured YAML completion reports; automated conflict prediction |
| [0.3.0] | 2026-02-28 | Bootstrap mode for new projects; Wave 0 pattern |
| [0.2.0] | 2026-02-28 | Decomposed skill prompt; complexity-based suitability heuristic |
| [0.1.0] | 2026-02-27 | Initial release |

---

## [0.7.0] - 2026-03-06

### Fixed

- **Bootstrap handoff to Scaffold Agent + Wave 1** (`prompts/saw-skill.md` v0.4.2):
  The bootstrap flow previously ended at "report and ask user to review" with no
  defined next step. After user approval the Orchestrator had no instruction to
  launch the Scaffold Agent or proceed to Wave 1 — the user had to know to invoke
  `/saw wave` separately, and the Scaffold Agent step could be silently skipped.

  Added steps 5 and 6 to the bootstrap branch:
  - Step 5: launch Scaffold Agent if Scaffolds section has pending files (identical
    logic to the scout flow's step 4)
  - Step 6: proceed to Wave 1 worktree setup and agent launch using the standard
    IMPL-exists wave loop

  Bootstrap is now fully continuous: requirements → Scout → review → Scaffold →
  Wave 1 → standard wave loop. No separate `/saw wave` invocation needed.

## [0.6.9] - 2026-03-06

### Changed

- **Bootstrap: structured requirements intake** (`prompts/saw-skill.md`, `prompts/saw-bootstrap.md`):
  The bootstrap flow now has a distinct pre-Scout step where the Orchestrator
  writes `docs/REQUIREMENTS.md` in the target project before launching the Scout
  agent. This file captures language, deployment target, external integrations,
  source codebase path, and architectural decisions already made. The Scout reads
  this file instead of receiving ad-hoc context in a massive prompt.

  **Why:** In practice, bootstrap requirements emerge organically over long
  conversations. By the time the Scout launches, context has been lost to
  compaction or scattered across chat history. A persistent requirements file
  survives session boundaries, gives the Scout structured input, and makes
  architectural constraints explicit rather than buried in prose.

  Files changed:
  - `prompts/saw-skill.md` v0.4.1: Bootstrap argument writes `docs/REQUIREMENTS.md`
    with structured template, asks user to confirm, then launches Scout referencing it
  - `prompts/saw-bootstrap.md` v0.3.4: Phase 0 changed from interactive question
    gathering to reading `docs/REQUIREMENTS.md`; fails fast if file missing

## [0.6.7] - 2026-03-05

### Changed

- **Wave Agent worktree isolation protocol** (`prompts/agents/wave-agent.md` v0.2.0): Added explicit instructions for using `git -C /full/worktree/path` flag for all git operations instead of relying on `cd`. Root cause: Bash tool in Claude Code does not persist working directory between command invocations, so `cd worktree && git commit` fails — the commit runs from the original CWD (main repo). New protocol section added at top of prompt with CORRECT/INCORRECT examples, branch verification command, and updated rules throughout. Fixes agents committing to main instead of worktree branches.

## [0.6.6] - 2026-03-04

### Added

- **Custom agent subtypes** (`prompts/agents/`): Three Claude Code agent type
  definitions — `scout.md`, `scaffold-agent.md`, `wave-agent.md` — with YAML
  frontmatter specifying `name`, `description`, `tools`, `model`, and `color`.
  When installed to `~/.claude/agents/` (or symlinked), these provide structural
  tool restrictions: scout cannot Edit source files, scaffold-agent can only
  Read/Write/Bash, wave-agent cannot spawn sub-agents. **This is optional.**
  The `/saw` skill falls back to `subagent_type: general-purpose` with the full
  prompt file if custom types are not installed. Users who prefer the existing
  workflow (general-purpose agents with full prompts) need not change anything.

- **`prompts/saw-skill.md` (v0.3.9 → v0.4.0):** Skill now specifies
  `subagent_type` when launching each agent — `scout`, `scaffold-agent`, or
  `wave-agent` — with automatic fallback to `general-purpose` if the custom
  type is not available. Added agent type preference paragraph explaining the
  two-tier design: type definition carries behavioral instructions and tool
  restrictions, prompt parameter carries task-specific context.

### Fixed

- **`prompts/scout.md` and `prompts/agents/scout.md`:** Suitability gate text
  said "Answer these three questions" but listed five numbered items. Changed
  to "Answer these five questions" in both files. The five questions have been
  present since v0.4.0; only the count text was wrong.

### Changed

- **`prompts/agents/scout.md`:** Synced from stale 160-line condensed version
  to full v0.4.0 content (475 lines). Previously missing: IMPL doc size
  guidance, type rename cascade checks, test performance guidance, linter
  auto-fix guidance, detailed pre-implementation check format, and
  time-to-value estimate format.

### Context

Custom agent subtypes are a layered enhancement. The tool restrictions they
provide (e.g., scout cannot `Edit`) are structural — enforced by the Claude Code
runtime, not by prompt instructions. A scout that tries to edit a source file
will be blocked at the tool level, not just told not to. This closes a class of
I6 violations where agents ignore role separation instructions. However, the
full-prompt approach remains the default and continues to work identically.
Installation is a symlink from the SAW repo to `~/.claude/agents/`:

```bash
ln -sf ~/code/scout-and-wave/prompts/agents/scout.md ~/.claude/agents/scout.md
ln -sf ~/code/scout-and-wave/prompts/agents/scaffold-agent.md ~/.claude/agents/scaffold-agent.md
ln -sf ~/code/scout-and-wave/prompts/agents/wave-agent.md ~/.claude/agents/wave-agent.md
```

---

## [0.6.2] - 2026-03-04

### Changed

- **`prompts/scout.md` (v0.4.0 → v0.4.1):** Scout step 5 now automatically
  detects shared types that cross agent boundaries and adds them to the
  Scaffolds section. Previously, the Scout could populate scaffolds but relied
  on manual detection during interface contract design. Now the Scout scans
  interface contracts after step 4 and counts how many agents will reference
  each type, struct, enum, or interface. If ≥2 agents will reference it (one
  defines, another consumes; or both consume), it is automatically added to
  scaffolds. Detection heuristics: explicit "define type X" + "consume type X"
  language in contracts, function return types crossing agent boundaries,
  duplicate struct/interface names in different agent sections. **Prevents
  merge conflicts:** Without this, Agent A might define `MetricSnapshot` in
  `fileA.go` while Agent B independently defines it in `fileB.go`, causing a
  duplicate declaration error at merge time. The Scaffold Agent materializes
  these shared types before Wave 1, so all agents import from the canonical
  location rather than redefining.

### Context

This improvement emerged from real-world SAW execution of claudewatch's metrics
export feature (Wave 1: Agent A + Agent B). Both agents independently created a
`MetricSnapshot` struct in separate files, causing a merge conflict. Root cause:
shared types should be in scaffold files committed to HEAD before Wave 1, not
independently declared by multiple agents. The Scaffolds section already existed
but was manually populated. This change makes detection automatic and systematic,
closing the gap between interface contract design and scaffold file generation.

---

## [0.6.1] - 2026-03-03

### Changed

- **`prompts/scout.md` (v0.3.9 → v0.4.0):** Status table in IMPL doc template
  now includes scaffold rows. Previously the status section only listed wave
  agent rows; scaffold steps were only visible by digging into the Scaffolds
  section. Now every IMPL doc produced by the Scout includes `— | Scaffold`
  rows in the status table at their correct position in the execution sequence,
  with commit SHA populated once done. Orchestrator row (`— | Orch`) for
  post-merge integration also added. Scaffold rows are omitted when no
  scaffolds are needed for a given wave boundary.

---

## [0.6.0] - 2026-03-03

### Added

- **`prompts/scaffold-agent.md` (v0.1.0):** New participant prompt for the Scaffold
  Agent. A lightweight participant that runs after Scout and human review: reads
  the approved IMPL doc Scaffolds section, creates the specified type scaffold
  source files, verifies they compile, commits to HEAD, and updates scaffold
  status. Embeds I2 and I5 at enforcement points. The Scaffold Agent is not a
  Wave Agent; it has no 9-field template, no worktree, and no completion report.
- **Scaffold Agent participant** added to `PROTOCOL.md`. Sits between Scout and
  Wave Agent in the participant model. Defined in the Participants section with
  narrow scope: materializes approved interface contracts as source files.
- **I2 invariant updated** in `PROTOCOL.md`: "The Scout defines all interfaces
  that cross agent boundaries in the IMPL doc. The Scaffold Agent implements them
  as type scaffold files committed to HEAD after human review, before any Wave
  Agent launches." Previously credited Scout with both defining and implementing.
- **Scaffold Agent conditional spawn** added to `prompts/saw-skill.md` (v0.3.7):
  after Scout completes and user reviews the IMPL doc, if the Scaffolds section
  is non-empty and any scaffold file has `Status: pending`, launch Scaffold Agent
  before creating worktrees. Scaffold Agent is NOT a wave agent; runs via Agent
  tool with `run_in_background: true`.
- Same Scaffold Agent spawn step added to `saw-teams/saw-teams-skill.md` (v0.1.4).
  Scaffold Agent runs before any team is created; it is not a teammate.
- **`prompts/saw-bootstrap.md` (v0.3.3):** Scout Types Phase rewritten — Scout
  specifies scaffold file contents in IMPL doc; Scaffold Agent creates them after
  human review. Added "Why Scaffold Agent, not Scout" rationale. Output format,
  verification gates, and status checklist now show "Scaffold Agent:" instead of
  "Scout:". Rules clarified: Scout may create one artifact only (the IMPL doc).
- **Scaffold commit verification** added to skill files' worktree pre-creation
  steps: verify all IMPL doc Scaffolds section files show `Status: committed`
  before creating worktrees or spawning teammates.
- **Wave numbering note** added to `prompts/agent-template.md` (v0.3.8): waves
  are 1-indexed; there is no Wave 0; the Scout produces any required type scaffold
  files (via Scaffold Agent) before Wave 1 launches.

### Changed

- **`prompts/scout.md` (v0.3.9):** Scout no longer creates scaffold source files.
  Step 5 ("Produce type scaffolds if needed") reverted to "Define scaffold
  contents if needed" — Scout lists files in the IMPL doc Scaffolds section with
  exact contents specified, but does not write source files. Rules: "You may
  create one artifact: the IMPL doc. Do not create, modify, or delete any source
  files." IMPL doc Scaffolds section template updated: Status column added
  (`pending` initially, Scaffold Agent sets to `committed`).
- **`prompts/agent-template.md` (v0.3.8) Field 3:** "Scout-produced scaffold
  files committed to HEAD" → "Scaffold Agent-produced scaffold files committed to
  HEAD". Import from scaffold files rather than redefining types.
- **`saw-teams/teammate-template.md` (v0.1.3) Field 3:** same wording update.
- **`prompts/README.md`:** added `scaffold-agent.md` row (v0.1.0) to Participant
  Prompts table. Updated scout.md description: "Never modifies source files" →
  "Never modifies existing source files" (clarification: it is the Scaffold Agent
  that creates new ones). Version numbers updated: scout v0.3.9, agent-template
  v0.3.8, saw-skill v0.3.9.
- **`PROTOCOL.md` version:** 0.5.2 → 0.6.0.
- **`README.md` version badge:** 0.5.2 → 0.6.0.
- **`saw-teams/DESIGN.md`:** I2 row updated to reflect Scaffold Agent role; File
  Plan updated (saw-teams-skill v0.1.4, teammate-template v0.1.3); status line
  updated to v0.1.4 synced to protocol v0.6.0.

### Rationale

Introducing the Scaffold Agent restores the human review gate that the v0.5.0
"Scout creates scaffolds" design eliminated. Previously (v0.5.x), Scout committed
scaffold files before the user saw the IMPL doc — meaning interface contracts were
locked in code before human review. With v0.6.0, the flow is: Scout writes IMPL
doc → human reviews interface contracts → Scaffold Agent materializes them →
Wave Agents implement against them. The review gate is structural again.

The alternative (spawning Scout twice — once to analyze, once to create scaffolds)
was rejected: async agents run to completion with no pause/resume, so a "Scout
continues" design would require two separate Scout invocations with context
re-establishment overhead. The Scaffold Agent avoids this.

### Solo wave and cross-wave coordination semantics

- **Solo waves do not require scaffolding.** Scaffold files exist so that multiple
  agents in the same wave can compile against shared types; one agent cannot
  conflict with itself. Scout leaves the Scaffolds section empty for solo waves.
- **Cross-wave coordination uses committed code.** Waves execute sequentially.
  Wave N commits its work to HEAD; Wave N+1 imports from the committed codebase
  directly. Scaffolds solve the intra-wave problem only.
- **Scaffolding runs once, before the first wave.** E2 (interface freeze)
  guarantees all cross-agent types are known at REVIEWED. The state machine's
  loop-back from "more waves?" to WAVE_PENDING bypasses the scaffold gate by
  design — there is nothing new to scaffold between waves.

### Worktree isolation hardening

During a live SAW test (brewprune cold-start-r13, 6 parallel agents), all agents
committed to main instead of their worktree branches. The `isolation: "worktree"`
parameter on the Agent tool failed silently, Field 0 self-verification did not
catch it, and the Orchestrator saw "Already up to date" on all 6 branches during
merge — but proceeded anyway, committing uncommitted changes found on main.

The protocol had three defense layers but no merge-time enforcement. All three
cooperative layers (Task tool isolation, Field 0 verification, prompt
instructions) depend on agent behavior being correct. When the execution
environment fails silently, cooperative layers cannot detect it. The missing
piece was a deterministic check at merge time — before any `git merge` runs —
that verifies each agent branch actually has commits.

Correctness guarantees belong in infrastructure, not cooperation. Asking agents
to maintain worktree isolation through prompt instructions is fragile,
unenforceable at runtime, and invisible until merge time. Layer 4 transforms
an invisible failure mode into a loud, explicit error that forces investigation
before any damage occurs.

- **Layer 4 trip wire** added to merge procedure (`prompts/saw-merge.md` v0.4.5,
  `saw-teams/saw-teams-merge.md` v0.1.3): before any merge, verify each agent
  branch has commits beyond the base. Empty branch triggers hard stop. Catches
  all isolation failures regardless of cause — Task tool, Field 0, or prompt
  instructions.
- **Defense-in-depth rationale** added to worktree docs (`prompts/saw-worktree.md`
  v0.4.4, `saw-teams/saw-teams-worktree.md` v0.1.3): manual pre-creation stays
  alongside `isolation: "worktree"` as belt + suspenders. Neither mechanism is
  sufficient alone.
- **E4 rewritten** in `PROTOCOL.md`: documents 4-layer defense model (manual
  pre-creation → Task tool isolation → Field 0 verification → merge-time trip
  wire).

### Pre-commit hook as fail-fast guard (Layer 0)

Layer 4 detects isolation failures at merge time but cannot prevent them. The
natural follow-up: can we block the bad commit before it happens? A git
pre-commit hook can. But SAW has no runtime, no binary, no installed tooling.
The protocol is entirely prompt-driven. There is no hook file to commit to the
repo and no framework to manage it.

The solution is an ephemeral hook shipped as `hooks/pre-commit-guard.sh` in
the SAW repository. The Orchestrator copies it to `.git/hooks/pre-commit`
during worktree setup and removes it during cleanup after merge. Between
waves, the hook doesn't exist. The project's normal git workflow is
unaffected. If the project already has a pre-commit hook, SAW backs it up
and restores it afterward.

The hook blocks agent commits to main with an instructive error listing
available worktrees so the agent can self-correct (cd to its worktree and
retry). The Orchestrator bypasses the hook via `SAW_ALLOW_MAIN_COMMIT=1` for
its own legitimate main commits (scaffold, post-merge, lint fix). Agents never
have this variable set.

This closes the gap between prevention and detection. Layer 0 prevents the most
common failure mode (agent commits to main). Layer 4 catches everything Layer 0
can't prevent (agent works on main without committing, agent on wrong worktree
branch). Both are deterministic. Neither depends on agent cooperation.

- **Layer 0 pre-commit hook** added to worktree setup (`prompts/saw-worktree.md`
  v0.4.5, `saw-teams/saw-teams-worktree.md` v0.1.4): blocks agent commits to
  main during active waves with instructive error output.
- **`SAW_ALLOW_MAIN_COMMIT` bypass** added to merge procedures
  (`prompts/saw-merge.md` v0.4.6, `saw-teams/saw-teams-merge.md` v0.1.4) and
  `prompts/scaffold-agent.md` (v0.1.1) for legitimate Orchestrator commits.
- **E4 updated** in `PROTOCOL.md`: documents 5-layer defense model (Layer 0
  through Layer 4).

---

## [0.5.3] - 2026-03-03

### Fixed

- **`PROTOCOL.md` version header:** was `0.4.0`, updated to `0.5.2`.
- **`PROTOCOL.md` conformance criteria:** added scaffold file support bullet —
  conforming implementations must support Scout-produced scaffold files and
  post-merge scaffold integrity verification.
- **`PROTOCOL.md` audit grep instruction:** updated to include `E{N}` alongside
  `I{N}` so both invariants and execution rules are covered in consistency audits.
- **`prompts/README.md`:** updated all stale version numbers (saw-skill v0.3.3→v0.3.6,
  scout v0.3.5→v0.3.7, agent-template v0.3.4→v0.3.7, saw-worktree v0.4.1→v0.4.3,
  saw-merge v0.4.2→v0.4.4, saw-bootstrap v0.3.2→v0.3.1); removed "solo-agent check"
  from saw-worktree description; updated Scout description to reflect scaffold file
  production and "never modifies existing source files".
- **`README.md` version badge:** was `0.4.1`, updated to `0.5.2`.
- **`saw-teams/DESIGN.md`:** updated status line (v0.1.2→v0.1.3, protocol v0.4.1→v0.5.2);
  updated File Plan versions (saw-teams-skill v0.1.3, teammate-template v0.1.2,
  saw-teams-merge v0.1.2, saw-teams-worktree v0.1.2) and adapted-from references;
  added "committed to HEAD" to I2 row in both SAW and SAW-Teams columns.
- **`saw-teams/saw-teams-merge.md`:** "adapted from saw-merge (v0.4.3)" → v0.4.4.
- **`prompts/saw-bootstrap.md` (v0.3.2):** Rules section "Do not write any source code"
  contradicted the Scout Types Phase section which requires scaffold files. Fixed to
  allow scaffold files as a second artifact type. Removed stale `saw-quick mode`
  reference (saw-quick was removed in v0.4.0); NOT SUITABLE is now the verdict for
  fewer than 3 concerns.
- **`prompts/scout.md` (v0.3.8):** "All three questions" → "All five questions" in
  SUITABLE verdict (suitability gate has had 5 questions since v0.2.0). Removed stale
  `saw-quick mode` reference from low-parallelization guidance.
- **`docs/saw-type-scaffold-proposal.md`:** marked completed status items (v0.5.0
  Wave 1, v0.5.1 Wave 2, CHANGELOG updated); integration test item remains open.
- **`prompts/saw-worktree.md` (v0.4.3):** removed `store_embedding`-specific example
  from interface freeze checklist (implementation artifact that leaked into the generic
  protocol prompt); replaced with generic "multi-parameter function signatures" wording.
- **`saw-teams/saw-teams-worktree.md` (v0.1.2):** same `store_embedding` fix.
- **`prompts/agent-template.md` (v0.3.7):** Field 3 now names Scout-produced scaffold
  files as a source of interfaces alongside prior waves and existing code; adds note
  to check IMPL doc Scaffolds section.
- **`saw-teams/teammate-template.md` (v0.1.2):** same Field 3 scaffold note.

---

## [0.5.2] - 2026-03-03

### Changed

- **I2 invariant redefined:** renamed from "Interface contracts precede
  implementation" to "Interface contracts precede parallel implementation".
  Body updated to reflect the Scout's dual role: defines contracts in the IMPL
  doc AND implements them as type scaffold files committed to HEAD, before any
  Wave Agent launches. Updated in `PROTOCOL.md` (canonical definition),
  `prompts/saw-skill.md`, and `saw-teams/saw-teams-skill.md` (embeddings).

### Fixed

- **`saw-teams/DESIGN.md`:** I2 row was mislabeled "Verification gates"
  (that is I5). Corrected to "Interface contracts precede parallel
  implementation" with accurate SAW vs SAW-Teams comparison.
- **`saw-teams/README.md`:** I2 reference updated to name scaffold files
  explicitly.

---

## [0.5.0] - 2026-03-03

### Changed

- **Wave 0 collapsed into Scout phase.** The Scout now produces a types scaffold file directly — a source file containing all shared interfaces, structs, and error types — rather than writing a Wave 0 agent prompt. The work is identical; the mechanism changes from a sequential solo wave to a Scout output committed before any worktrees are created. Wave 1 is now always the first parallel wave.
- **Solo-agent short-circuit removed** from `prompts/saw-worktree.md`, `saw-teams/saw-teams-worktree.md`, and `saw-teams/saw-teams-skill.md`. Every wave runs through full wave machinery. A wave that decomposes to one agent signals a decomposition problem or NOT SUITABLE, not a short-circuit path.
- **Investigation-first items** are now NOT SUITABLE unconditionally. The SUITABLE WITH CAVEATS → Wave 0 workaround path is removed from the suitability gate in `scout.md`.
- **`saw-bootstrap.md`** reframed: "Wave 0 Pattern (Always Required)" → "Scout Types Phase (Always Required)". Output format, verification gates, status checklist, and rules updated to match.
- **`PROTOCOL.md`** solo wave definition removed; bootstrap Variants section updated.
- **`prompts/saw-skill.md`** and **`saw-teams/saw-teams-skill.md`** bootstrap descriptions updated.

### Rationale

Wave 0 was a structural smell: wave machinery applied to a single agent produces pure overhead with no parallelism benefit. The Scout already knows what Wave 0 needs to do — it wrote the Wave 0 agent prompt — so moving that work into the Scout phase requires only a permission change and a format change, not a new decision framework. See `docs/saw-type-scaffold-proposal.md` for the full design discussion.

---

## [0.5.1] - 2026-03-03

### Fixed

- **E-rule count mismatch:** `PROTOCOL.md`, `prompts/saw-skill.md`, and
  `saw-teams/saw-teams-skill.md` all claimed "E1–E13" despite E14 being defined
  in PROTOCOL.md since v0.4.0. All three updated to "E1–E14".
- **Scout definition stale in `PROTOCOL.md` and `README.md`:** both still said
  "Never modifies source files" after the Wave 0 collapse in v0.5.0. Updated to
  reflect that the Scout may produce type scaffold files as coordination
  artifacts; "Never modifies **existing** source files" is preserved.
- **Scaffold handling not visible in skill files:** the interface freeze
  checkpoint in `prompts/saw-skill.md` and `saw-teams/saw-teams-skill.md` did
  not mention scaffold commit verification. Added explicit note: Scout-produced
  scaffold files must be committed to HEAD before worktrees are created.
- **Post-merge verification missing scaffold check:** `prompts/saw-merge.md`
  (v0.4.4) and `saw-teams/saw-teams-merge.md` (v0.1.2) Step 6 now include a
  scaffold integrity check — verify scaffold files are present and unmodified
  after merge; any agent-modified scaffold is a protocol deviation.
- **Wave numbering not documented in `agent-template.md`:** added explicit note
  that waves are 1-indexed and Wave 0 no longer exists.

### Version bumps

`saw-skill.md` v0.3.6, `saw-merge.md` v0.4.4, `agent-template.md` v0.3.6,
`saw-teams-skill.md` v0.1.3, `saw-teams-merge.md` v0.1.2.

---

## [0.4.4] - 2026-03-03

### Added

- **`saw-teams/example-settings.json`:** all required `.claude/settings.json`
  fields for saw-teams in a single copyable block. Fields: `env` (enable Agent
  Teams), `teammateMode` (tmux recommended for wave work), `permissions.allow`
  (Agent + Bash + Read/Write/Edit + Glob/Grep), and `hooks` (TeammateIdle +
  TaskCompleted). README updated with a field-reference table explaining the
  purpose of each entry and calling out `"Agent"` as the critical allow-list
  entry.

---

## [0.4.3] - 2026-03-03

### Added

- **`saw-teams/hooks.md` (v0.1.0):** documentation for `TeammateIdle` and
  `TaskCompleted` protocol enforcement hooks. `TeammateIdle` fires when a
  teammate tries to idle; the SAW hook checks for a completion report in the
  IMPL doc and sends the teammate back if missing. `TaskCompleted` fires when
  a task is being closed; the hook enforces the I4 write-before-close ordering
  (IMPL doc write must precede task status update). Includes combined
  settings.json configuration and relationship to standard SAW.

- **`saw-teams/hooks/teammate-idle-saw.sh`:** executable `TeammateIdle`
  enforcement script. Exits 2 with structured feedback if no completion report
  or `status:` line found in the IMPL doc.

- **`saw-teams/hooks/task-completed-saw.sh`:** executable `TaskCompleted`
  enforcement script. Exits 2 if IMPL doc completion report is absent or
  missing `status:` line before a task is marked complete.

- **`saw-teams/README.md`:** setup guide covering: enable env var, display
  mode selection (in-process vs split-pane; split-pane recommended for SAW
  wave work), hook installation, `"Agent"` allow-list requirement, command
  reference, what SAW adds to Agent Teams, and known limitations.

### Changed

- **`saw-teams/saw-teams-skill.md` (v0.1.1 → v0.1.2):** spawn step (step 3c)
  fully specified. Three changes:
  1. **Spawn context construction**: explicit that spawn context must combine
     (a) teammate-template preamble, (b) IMPL doc agent section, (c) absolute
     worktree path. Without the preamble, the no-self-claim constraint and
     messaging protocol are absent and teammates default to Agent Teams
     self-claiming behavior.
  2. **CLAUDE.md note**: teammates automatically load the project's CLAUDE.md
     from their worktree working directory; project-level instructions are
     inherited without explicit inclusion in spawn context.
  3. **Display mode note**: split-pane mode recommended for SAW wave work;
     pointer to README.md for setup.
  4. **Task self-claiming note**: Agent Teams default is to self-claim; SAW
     explicitly prohibits it; the constraint lives in the spawn context.

- **`saw-teams/DESIGN.md`:** added "Protocol enforcement hooks" to "What's
  New" section. Updated File Plan to include README.md, hooks.md, and
  hooks/. Updated status to v0.1.2.

---

## [0.4.2] - 2026-03-03

### Changed

- **`saw-teams/saw-teams-skill.md` (v0.1.0 → v0.1.1):** synced to saw-skill
  v0.3.5 ([0.4.0]). Added E{N} notation to preamble. Embedded I2 (interface
  freeze at worktree creation, not teammate spawn) at step 3a. Embedded I4, I5,
  E7, E8 at step 5 (completion report reading). Embedded I3 (wave sequencing)
  at step 7.

- **`saw-teams/teammate-template.md` (v0.1.0 → v0.1.1):** synced to
  agent-template v0.3.5 ([0.4.0]). Added E{N} notation to preamble. Embedded
  E14 (IMPL doc write discipline) in Field 8: explicit append-only mandate,
  prohibition on editing earlier sections, rationale for why concurrent appends
  are safe.

- **`saw-teams/saw-teams-merge.md` (v0.1.0 → v0.1.1):** synced to saw-merge
  v0.4.3 ([0.4.1]). Step 6 now references `test_command` from the IMPL doc's
  Suitability Assessment rather than using ad-hoc language. The Scout derives
  this command; the lead consumes it at every post-merge gate.

- **`saw-teams/saw-teams-worktree.md` (v0.1.0 → v0.1.1):** synced to
  saw-worktree v0.4.2. Added Preflight Working Tree Check section (runs
  `git status --porcelain` before solo agent check, ownership verification, or
  worktree creation; two resolution paths: commit preferred, stash for WIP).
  Diagnose section 2 updated to use `git status --porcelain` and reference the
  preflight.

- **`saw-teams/DESIGN.md`:** corrected three stale table entries:
  - Field 0: "Agent Teams manages worktree natively" → actual behavior (lead
    pre-creates worktrees manually, same defense-in-depth as standard SAW)
  - I3 row: "via task dependencies" → "via control flow; future-wave tasks not
    created"
  - "Dynamic task reassignment" section relabeled as rejected; explained that
    self-claiming at runtime violates I1
  - File Plan version numbers updated to v0.1.1 throughout

---

## [0.4.1] - 2026-03-03

### Added

- **`test_command` field in IMPL doc** — Scout derives the project's full test
  suite command from the build system manifest (go.mod → `go test ./...`,
  Cargo.toml → `cargo test --workspace`, package.json → `npx jest`, etc.) and
  records it as `test_command` in the Suitability Assessment section. This is
  language-agnostic: the field is populated once by the Scout and consumed by
  the Orchestrator at every post-merge gate, with no per-language branching in
  the protocol itself.

### Changed

- **`saw-merge.md` Step 6** (`saw-merge v0.4.2 → v0.4.3`) — Post-merge
  verification now explicitly references `test_command` from the IMPL doc
  rather than describing the rule in generic terms. The "run tests unscoped"
  principle is unchanged; the change makes the IMPL doc the single source of
  the actual command.

- **`scout.md` Process step 1** (`scout v0.3.6 → v0.3.7`) — Step 1 now
  explicitly instructs the Scout to derive and record `test_command` as part of
  reading the build system. Previously this was implicit in "verification gates
  must match the project's actual toolchain."

---

## [0.4.0] - 2026-03-02

### Removed

- **`prompts/saw-quick.md` (Quick mode):** removed. Quick mode only enforced I1
  and explicitly unenforced I2–I5. A tool that strips SAW's guarantee set is not
  a SAW variant; it is a different thing wearing SAW's name. Keeping it in the
  repo implied SAW has a mode for every parallelization case, which dilutes the
  protocol's contract and invites using it as a catch-all. Work that doesn't fit
  SAW should not use SAW. The "Low parallelization value" guidance in the README
  covers the 2–3 agent case without prescribing a named protocol for it.

- **`/saw check` command:** removed. The command's only value was filtering NOT SUITABLE
  cases before a scout run, but the Scout already runs a built-in suitability gate and stops
  with a NOT SUITABLE verdict when the work doesn't qualify. Running `/saw check` before
  `/saw scout` added latency on SUITABLE outcomes (the common case) with no benefit, and
  the NOT SUITABLE path was already handled by the Scout's early exit. The "When to Use It"
  section now describes the Scout's suitability gate directly. The CHECKING state has been
  removed from the PROTOCOL.md state machine.

### Changed

- **`PROTOCOL.md` (v0.3.5):** added invariant reference convention. Invariants are
  identified by I-number (I1–I6). When referenced in prompt files, the I-number anchors
  cross-referencing and audit; the canonical definition is embedded verbatim for
  self-containment. Audit pattern: grep prompt files for `I{N}` and verify definition
  matches PROTOCOL.md.

- **`prompts/saw-skill.md` (v0.3.3 → v0.3.4):** role enforcement block replaced with
  I6 canonical definition verbatim. Wave execution step replaced "Disjoint file ownership
  is the primary safety mechanism" with I1 canonical definition. I-notation explanation
  added after I6 block.

- **`prompts/agent-template.md` (v0.3.3 → v0.3.4):** three additions:
  1. Opening paragraph names agents as Wave Agents operating under the SAW protocol,
     giving them formal identity and context for their role without requiring the full spec.
  2. I-notation explanation added so agents know I-numbers refer to `PROTOCOL.md` invariants.
  3. I1 canonical definition embedded in Section 1 (File Ownership).
  4. I5 canonical definition embedded in Section 8 (Report) before the commit instructions.

- **Terminology sweep:** eliminated all remaining "foreground/background" language
  in favour of "synchronous/asynchronous" per the canonical participant model:
  - `docs/saw-pipeline-proposal.md` lines 17, 119: "foreground" → "synchronous agent",
    "background scout" → "asynchronous scout"
  - `README.md` line 114: "goes to background" → "launches asynchronously"

- **9-field correction:** "8-field" references corrected to "9-field" across all files
  that had not yet been updated following the addition of Field 0 (Isolation Verification):
  - `prompts/agent-template.md` line 4: description updated to name Field 0 explicitly
  - `prompts/scout.md` line 335: IMPL doc output format reference
  - `prompts/saw-bootstrap.md` line 203: Agent Prompts section template
  - `README.md` line 44: Prompts table description, now names Field 0 and Fields 1–8

- **README version badge:** corrected from 0.3.7 to 0.3.5 to match PROTOCOL.md.
  The badge reflects the protocol specification version, not the latest individual
  prompt file version.

- **`PROTOCOL.md` (v0.3.4 → v0.3.5):** added **I6: Role Separation** invariant.
  The Orchestrator must not perform Scout or Wave Agent duties. Codebase analysis,
  IMPL doc production, and source code implementation must be delegated to the
  appropriate asynchronous agent. I6 violation added to the Protocol Violations table
  with its effects: context pollution, broken observability, async execution bypassed.
  This invariant was implicit in the participant role definitions but not enforced;
  the absence allowed rationalizing Scout work as Orchestrator convenience.

- **`prompts/saw-skill.md` (v0.3.2 → v0.3.3):** added strict role enforcement rule.
  The Orchestrator now has an explicit invariant: if it finds itself analyzing a codebase,
  writing an IMPL doc, or implementing code, it must stop and delegate to the appropriate
  agent. If asked to perform Scout or Wave agent duties directly, it must refuse and launch
  the correct agent instead. Stated at the top of the skill before all other instructions
  so it cannot be rationalized away by downstream context.

### Added

- **`docs/diagrams/saw-state-machine.drawio`:** new draw.io state machine diagram
  covering all named protocol states (IDLE, SCOUTING, REVIEWED, WAVE_PENDING,
  WAVE_EXECUTING, WAVE_MERGING, WAVE_VERIFIED, BLOCKED, COMPLETE) with solo/multi
  fork, BLOCKED recovery arc, and wave loop. Light/dark SVG exports in
  `docs/diagrams/`. Replaces the ASCII state machine in PROTOCOL.md.

- **`docs/saw-pipeline-proposal.md`:** new document capturing cross-feature scout
  pipelining: the observation that the orchestrator's wave-execution wait window is
  dead time that can be filled by launching the next feature's scout as an async agent.
  Covers the safety constraint (disjoint read domain check), timing model, a real
  example from a claudewatch session, and proposed protocol changes. Also captures
  the session-level DAG extension: applying SAW's file-level dependency graph reasoning
  at the feature level, with a proposed `/saw session` entry point for upfront
  full-landscape pipeline planning.

### Changed

- **`PROTOCOL.md` — execution rules numbered E1–E13:** all execution rules are now
  identified by E-number (E1–E13), matching the I-number convention for invariants.
  The E-number is the cross-referencing anchor for embedding in prompts and audit.
  Audit pattern: grep prompt files for `E{N}` and verify definition matches PROTOCOL.md.

- **`PROTOCOL.md` — state machine:** ASCII art replaced with draw.io SVG
  (`saw-state-machine-light.svg` / `saw-state-machine-dark.svg`). The `<picture>`
  element switches themes automatically. Source preserved in
  `docs/diagrams/saw-state-machine.drawio`.

- **`PROTOCOL.md` — pipelining references removed:** pipeline scheduling is an
  experimental design proposal (`docs/saw-pipeline-proposal.md`), not a finalized
  protocol feature. All references to it removed from the normative spec.

- **`PROTOCOL.md` — decoupled from Claude-specific language:** normative requirements
  are now implementation-agnostic. Claude Code primitives (e.g. `run_in_background:
  true`, `isolation: "worktree"`) re-added as parenthetical examples, not normative
  text. Protocol is portable; the mechanism is swappable.

- **`PROTOCOL.md` — Orchestrator role clarified:** synchronous execution is what makes
  checkpoints enforceable; the human is present through the Orchestrator, not as a
  separate participant. Mandatory vs optional checkpoints distinguished explicitly:
  suitability gate and REVIEWED are always mandatory; inter-wave confirmation is
  optional via `--auto`; BLOCKED always surfaces.

- **`docs/ECOSYSTEM.md`:** added explicit statement of prompt-native design intent
  and the down-the-stack tradeoff. The intellectual claim SAW makes — that coordination
  protocols can live in natural language and still provide structural safety guarantees
  — is now named directly. The tradeoff (code enforcement vs prompt portability) is
  stated with the condition under which it would be worth revisiting.

- **`README.md`:** added "How it works under the hood" section covering IMPL doc as
  coordination surface (not just documentation) and background execution as the
  mechanism that makes waves actually parallel. Updated permissions block to include
  WebFetch, WebSearch, and TodoWrite. Trimmed Workflow and "When to Use It" sections.
  Orchestrator described as running in the user's own session; no separate human role.

- **`prompts/saw-skill.md` (v0.3.4 → v0.3.5):**
  - Embedded I2, I3, I4, I5 at their enforcement points (I1 and I6 were already
    present). All six invariants now embedded verbatim in the skill.
  - Tightened I2: interface freeze occurs at worktree creation (step 2), not at agent
    launch (step 3). Added explicit freeze checkpoint callout to step 2.
  - Embedded E7 (agent failure handling) and E8 (same-wave interface failure) at step 4
    (completion report reading), the Orchestrator decision point for both.
  - Updated `I{N}` notation comment to cover `E{N}` execution rules (E1–E14).

- **`PROTOCOL.md` — spec hole patches (six gaps closed):**

  - **E14: IMPL doc write discipline (new rule).** Agents write to the IMPL doc
    exactly once: by appending their named completion report section at the end of
    the file. Must not edit any earlier section (interface contracts, ownership
    table, suitability verdict, wave structure). Those sections are frozen at
    worktree creation (E2). Any required update to an earlier section is an
    interface deviation — report it, do not edit in place. Cross-referenced from I4.
    This constraint is what makes IMPL doc git conflicts predictably resolvable (E12).

  - **E2: Interface freeze exception workflow.** Added two named recovery paths for
    interface changes after worktrees exist and some agents have completed work:
    (a) recreate and cherry-pick — preserve unaffected commits, recreate worktrees,
    cherry-pick safe commits, re-run only affected agents; use when most agents have
    completed and the change is narrow; (b) descope and defer — leave the current
    wave to complete against existing contracts, move the interface revision to the
    next wave boundary via E8; use when the change is broad or cherry-pick safety
    cannot be confirmed. Added E2/E8 relationship note: same problem from opposite
    discovery directions, both resolve at the wave boundary.

  - **E10: Scoped verification — exact commands mandate.** The scout must specify
    exact verification commands in Field 6 of each agent prompt. Agents run those
    exact commands; substitutions are not permitted. `go test ./...` is unscoped in
    Go regardless of speed; the correct scoped command targets owned packages only.
    An agent substituting a broader command is non-conforming even if it passes.

  - **Solo wave I6 safety clause.** The solo wave agent must operate in the Wave
    Agent role — launched by the Orchestrator as an asynchronous agent, not executed
    inline. Executing solo wave work directly violates I6 regardless of wave size.
    The absence of worktrees changes the isolation mechanism; it does not change
    participant roles.

  - **Precondition 1: append-only precisely defined.** A change qualifies as
    append-only if and only if: the diff is purely additive (no deletions, no
    modifications to existing entries, no reformatting, no reordering) and the new
    entries are self-contained. Any change that touches an existing line — even
    whitespace — disqualifies the file from orchestrator-owned treatment and makes
    it a decomposition blocker. Verification: diff must contain only `+` lines, no
    `-` lines.

  - **Protocol Guarantees: softened interface drift claim.** "Interface drift is
    structurally impossible" replaced with "direct coordination drift is prevented;
    deviations must be declared in completion reports and surfaced at wave
    boundaries." The original claim was falsifiable by semantic drift (wrong
    implementation of correct signature, differing contract interpretation). The
    revised claim matches what the protocol actually enforces via `interface_deviations`
    in the completion report schema.

- **`prompts/agent-template.md` (v0.3.4 → v0.3.5):**
  - Embedded E14 in Field 8 (Report): explicit append-only mandate with rationale.
    Agents must not edit earlier IMPL doc sections; report interface deviations
    instead of editing contracts in place.
  - Updated notation comment to cover `E{N}` execution rules (E1–E14).

- **Style:** removed em dashes from 20 markdown files across the repository.

- **`PROTOCOL.md` (v0.3.4):** three clarifications developed from practice:

  - **Opening description:** repositioned from "coordination protocol for parallel
    AI agent execution" to "a protocol for safely parallelizing human-guided agentic
    workflows." Human review checkpoints are now named as structural (not optional
    guardrails); cross-feature pipelining is named as optional.

  - **Participants section:** synchronous/asynchronous framing replaces
    foreground/background. Orchestrator is the synchronous agent that serializes all
    state transitions and is the sole human-facing reporting channel. Scouts and wave
    agents are asynchronous agents launched by the orchestrator. Async agents are
    invisible to the human except through the orchestrator's completion handling.

  - **Pipeline framing:** PROTOCOL.md now references `saw-pipeline-proposal.md`
    in the Scout participant description, noting that pipelining is a scheduling
    optimization on the orchestrator, not a structural change to the protocol. The
    orchestrator stays synchronous and foreground; it simply launches a scout instead
    of idling during wave execution.

- **`README.md`:** added **Permissions** subsection under Usage. Documents all
  required `~/.claude/settings.json` allow entries for hands-free execution.
  Calls out `"Agent"` as the critical entry: without it, every wave agent launch
  and pipelined scout launch blocks on a keyboard approval prompt.

## [0.3.7] - 2026-03-01

### Changed

- **`prompts/saw-merge.md` (v0.4.1 → v0.4.2):** post-merge verification now
  includes an explicit linter auto-fix pass before build and tests. The orchestrator
  runs the project's auto-fix command (`golangci-lint run --fix`, `ruff --fix`,
  `eslint --fix`, `cargo fmt`, etc.) on the merged codebase, commits any style
  changes, then runs the full suite. Centralizing auto-fix in the orchestrator
  is cleaner than requiring every agent to know and run the exact command; one
  pass on the merged result catches formatter divergence across all agents at once.

- **`prompts/agent-template.md` (v0.3.2 → v0.3.3):** agent verification gate
  now explicitly states agents do not run linter auto-fix. A note explains that
  the orchestrator owns the single auto-fix pass on the merged result, so agents
  run the linter in check mode only. Removes the failure mode where agents pass
  locally but CI fails because CI runs auto-fix and agents don't.

- **`prompts/scout.md` (v0.3.4 → v0.3.5):** step 8 now instructs the scout to
  document the project's auto-fix command in the IMPL doc's Wave Execution Loop
  (for the orchestrator) rather than emitting it in individual agent gates.

## [0.3.6] - 2026-03-01

### Changed

- **`prompts/saw-skill.md` (v0.3.0 → v0.3.1):** wave execution step 3 now requires a
  structured `[SAW:wave{N}:agent-{X}]` prefix on the Task tool's `description` parameter
  when launching agents. Format: `[SAW:wave1:agent-A] short description`. Enables
  claudewatch to automatically parse wave timing, agent count, and per-agent status from
  session transcripts with no additional instrumentation.

## [0.3.5] - 2026-03-01

### Changed

- **`prompts/scout.md` (v0.2.1 → v0.3.4):** suitability gate Q1 updated:
  append-only additions to shared files (config registries, module manifests,
  index files) are not a decomposition blocker; orchestrator-owned post-merge.
  "8-field format" reference corrected to "9-field format".

- **`prompts/saw-quick.md` (v0.2.0 → v0.3.4):** file ownership declaration
  is now a hard requirement before agents launch, not a checklist suggestion.
  Explicit warning added: Quick mode enforces I1 only; I2–I5 are unenforced.

- **`prompts/saw-merge.md` (v0.4.0 → v0.4.1):** four additions:
  - `status: partial` or `status: blocked` on any agent halts the wave; no
    partial merges permitted
  - Prompt propagation formalized: updating an agent prompt means editing its
    section in the IMPL doc in-place; no separate prompt files
  - Same-wave interface failure procedure: wave halts, contracts revised,
    affected agents re-prompted, unaffected agents do not re-run
  - Crash recovery section: use `git log --merges` to identify already-merged
    worktrees before resuming a mid-merge crash; WAVE_MERGING is not idempotent

- **`prompts/saw-worktree.md` (v0.4.0 → v0.4.1):** two additions:
  - Pre-launch ownership verification step: scan wave ownership table for
    overlaps before creating worktrees; block launch if any file appears twice
  - WAVE_PENDING re-entrancy note: check for existing worktrees before creating;
    do not duplicate

## [0.3.4] - 2026-03-01

### Changed

- **PROTOCOL.md updated to v0.3.4:** eight protocol gaps closed following formal review:
  - Precondition 1: append-only additions to shared files (config registries, module
    manifests) are not a decomposition blocker; scout makes such files orchestrator-owned
  - Execution Rules: pre-launch ownership verification added; orchestrator scans
    wave ownership table for overlaps before creating worktrees or launching agents
  - Execution Rules: agent prompt propagation formalized; prompts are sections within
    the IMPL doc; updates are edits in-place, no separate prompt files
  - Execution Rules: agent failure handling; any `status: partial` or `status: blocked`
    halts the wave; no partial merges permitted
  - Execution Rules: same-wave interface failure; wave goes to BLOCKED, contracts
    revised, affected agents re-prompted; unaffected agents do not re-run
  - Execution Rules: idempotency; WAVE_PENDING is re-entrant; WAVE_MERGING is not;
    recovery procedure defined for mid-merge orchestrator crash
  - Conflict prediction: explicit statement that within a valid wave merge order is
    arbitrary; same-wave agents are independent by construction
  - Variants: Quick mode now requires file ownership declaration (preserves I1);
    explicit statement that I2–I5 are unenforced in Quick mode

## [0.3.3] - 2026-03-01

### Changed

- **PROTOCOL.md updated to v0.3.3:** aligned with actual implementation:
  - Agent prompt is 9-field (Field 0: Isolation Verification), not 8-field
  - State machine extended: solo wave path bypasses WAVE_MERGING; Wave 0 formalized
  - New Execution Rules section: interface freeze, worktree pre-creation, scoped vs
    unscoped verification, conflict prediction before merge
  - I1 invariant clarified: single-agent out-of-scope changes are distinct from
    two-agent conflicts and not an I1 violation when justified and documented
  - Completion report `interface_deviations` extended with `downstream_action_required`
    and `affects` fields
  - New Variants section documenting Quick mode and Bootstrap mode
  - Protocol Violations table: removed language-specific Rust example (special case
    of I1, not a distinct protocol violation)
  - Reference Implementation table: corrected "8-field" to "9-field"

## [0.3.2] - 2026-02-28

### Added

- **Flow diagrams:** four draw.io source files and light/dark SVG exports covering
  each `/saw` subcommand: `saw-scout-wave`, `saw-bootstrap`, `saw-check`,
  `saw-status`. All files live in `docs/diagrams/`. Light/dark SVGs exported via
  `--svg-theme light/dark`; the `<picture>` element in README switches automatically.

- **`docs/diagrams/saw-scout-wave.drawio`:** full protocol flow from suitability
  gate through scout phase, IMPL doc, human review, wave loop (worktree setup,
  agent execution, completion reports, orchestrator, merge, fix/re-verify).

- **`docs/diagrams/saw-bootstrap.drawio`:** `/saw bootstrap` flow: git pre-flight,
  requirements gathering, package structure design, concerns gate (≥3 required),
  IMPL-bootstrap.md output, handoff to `/saw wave`.

- **`docs/diagrams/saw-check.drawio`:** `/saw check` flow: lightweight scan,
  3-question evaluation, 3-way verdict (SUITABLE / NOT SUITABLE / SUITABLE WITH CAVEATS).
  Read-only pre-flight; no files written.

- **`docs/diagrams/saw-status.drawio`:** `/saw status` flow: IMPL doc existence
  check, wave structure and checkbox reading, progress report output.

- **README diagram**: replaced mermaid flowchart with `<picture>` element linking
  `saw-scout-wave-light.svg` / `saw-scout-wave-dark.svg` for native dark mode support.

## [0.3.1] - 2026-02-28

### Changed

- **Structured completion reports:** Agent template Section 8 now produces a
  machine-readable YAML block instead of free-form prose: `status`, `worktree`,
  `commit` (sha or "uncommitted"), `files_changed`, `files_created`,
  `interface_deviations`, `out_of_scope_deps`, `tests_added`, `verification`.
  Free-form notes follow the block for anything that doesn't fit. Enables
  orchestrator automation of conflict detection, merge sequencing, and IMPL doc
  updates without reading prose.

- **Conflict prediction before merge:** `saw-merge.md` now cross-references
  all agents' `files_changed` and `files_created` lists before touching the
  working tree. Disjoint ownership violations surface before `git merge` is
  attempted, not mid-merge. `out_of_scope_deps` lists are also cross-referenced
  for agents that flagged the same file with different required changes.

- **Structured merge procedure:** `saw-merge.md` rewritten as 7 explicit
  steps: parse reports, conflict prediction, review deviations, merge,
  cleanup, post-merge verification, IMPL doc updates. Each step uses
  structured report fields rather than requiring the orchestrator to interpret
  prose.

- **`saw-merge.md` version bump:** v0.2.0 → v0.3.0
- **`agent-template.md` version bump:** v0.2.0 → v0.3.1

## [0.3.0] - 2026-02-28

### Added

- **`/saw bootstrap` subcommand:** Design-first architecture for new projects
  with no existing codebase. The bootstrap scout acts as architect rather than
  analyst: it gathers requirements (language, project type, key concerns), designs
  package structure and interface contracts before any code is written, and
  produces `docs/IMPL-bootstrap.md` with a mandatory Wave 0 (types/interfaces)
  followed by parallel implementation waves. Solves the cold-start problem where
  regular scout has no existing code to analyze.

- **`saw-bootstrap.md`:** Dedicated module implementing the bootstrap procedure:
  requirements gathering, architecture design principles (one concern = one
  package, types-as-foundation, no god files), Wave 0 pattern, output format,
  and rules. Follows the module decomposition pattern established in v0.2.0.

- **Wave 0 pattern formalized:** Bootstrap projects always require a solo types
  wave before any parallel implementation. All shared interfaces and structs are
  defined in a `types` package first; downstream agents implement against these
  contracts without seeing each other's code. Post-Wave-0 gate is build-only
  (no tests yet), unblocking all Wave 1 agents simultaneously.

## [0.2.0] - 2026-02-28

### Changed

- **Decomposed skill prompt into focused modules:** `saw-skill.md` is now a thin router that delegates worktree management to `saw-worktree.md` and merge/verify logic to `saw-merge.md`. Each module is independently testable and debuggable. Previously all orchestration logic (routing, worktree creation, merge handling, conflict detection, diagnostics, progress tracking) was interleaved in a single prompt that assumed deterministic execution of non-deterministic steps.

- **Replaced agent count threshold with complexity-based heuristic:** The suitability gate no longer uses raw agent count (≤2 NOT SUITABLE, ≥5 SUITABLE) as the primary decision criterion. Instead evaluates parallelization value based on: build/test cycle length (>30s favors SAW), files per agent (≥3 favors SAW), agent independence (single wave = max benefit), and task complexity (logic > documentation). The previous threshold was based on a single dogfooding data point (4 documentation-only agents, 88% slower than sequential) that didn't generalize; code-heavy tasks with 2 agents benefited from SAW despite being under the threshold.

- **Added version headers to all prompt files:** Each prompt file now includes a `<!-- filename v0.2.0 -->` comment at the top. Users who copy prompts to `~/.claude/commands/` can compare their copy's version against the repo to detect staleness.

### Added

- **`saw-worktree.md`:** Dedicated module for worktree lifecycle: pre-creation, verification, diagnosis of creation failures (3-tier fallback), agent self-healing explanation, and cleanup. Extracted from saw-skill.md.

- **`saw-merge.md`:** Dedicated module for merge procedure: pre-merge conflict detection, handling committed vs uncommitted agent changes, worktree cleanup, post-merge verification, and IMPL doc updates. Extracted from saw-skill.md.

- **Worktree isolation verification:** SAW orchestrator now checks `git worktree list` after launching agents to verify worktrees were actually created. If count doesn't match (expected N+1 for N agents + main), stops immediately with error. Prevents silent data loss when `isolation: "worktree"` parameter fails to create worktrees. Emerged from brewprune Round 5 Wave 1 where 5 agents were launched but 0 worktrees created - all agents modified main directly. Zero conflicts occurred only due to perfect file disjointness (luck, not safety).

- **Agent self-healing isolation verification:** Agent template now includes mandatory Section 0: pre-flight worktree isolation check with self-healing. Agents first attempt `cd` to expected worktree location (self-correction), then verify pwd, git branch, and worktree existence BEFORE any file modifications. If verification fails after cd attempt, agent writes error to completion report and exits immediately without touching files. Orchestrator detects failures within 10s. This is Layer 1.5 (self-healing) + Layer 2 (strict verification) of defense in depth. Philosophy shift from "detect-only" to "attempt-fix-then-detect" provides redundant protection against Task tool working directory issues while maintaining strict fail-fast behavior. Validated in brewprune Round 5 Wave 2 where agents successfully self-corrected working directory.

- **Out-of-scope conflict detection:** SAW orchestrator now scans all agent completion reports for out-of-scope file changes (section 8) before merging. If multiple agents modified the same out-of-scope file, the orchestrator flags the conflict and prompts the user for resolution. Prevents silent data loss when agents touch files outside their ownership.

- **Performance guidance for test commands:** Scout now provides guidance on focused vs full test runs. For packages with >50 tests, agents use focused tests during waves (`go test ./pkg -run TestSpecific`) while post-merge verification runs the full suite (`go test ./...`). Includes reasonable timeouts (2-5min per package). Keeps agent verification fast while preserving full coverage at merge.

- **Pre-implementation status check:** Scout suitability gate now includes step 4: check each audit finding/requirement against the current codebase to determine implementation status (TO-DO, DONE, PARTIAL). For DONE items, scout adjusts agent prompts to "verify existing implementation and add test coverage" rather than "implement." Prevents wasted compute on already-implemented work.

- **Known Issues section in IMPL template:** Scout now includes a "Known Issues" section in the IMPL doc template where pre-existing test failures, build warnings, or known bugs can be documented. Helps agents distinguish expected failures from regressions. Includes workarounds and tracking links.

- **Justified API-wide changes guidance:** Agent template now explicitly permits out-of-scope modifications when fixing design flaws that require atomic changes. Agents must document all affected files, justify why changes must be atomic (not incremental), and update all call sites consistently. Example: fixing race conditions in shared APIs.

- **Integration test reminder:** Agent template now prompts agents to search for tests expecting OLD behavior when modifying command behavior, exit codes, or error handling. Update related tests BEFORE running verification to prevent post-merge test failures.

### Fixed

- **Scout agent file-writing clarification:** Removed ambiguous "read-only reconnaissance agent" language that caused Plan agents to refuse writing IMPL docs. Now explicitly states: "you do NOT write implementation code, but you MUST write the coordination artifact (IMPL doc) using the Write tool." Prevents agents from returning IMPL content as text instead of writing the file.

## [0.1.0] - 2026-02-27

Initial release of the Scout-and-Wave protocol based on lessons learned from brewprune UX audit experiments.

### Added
- Scout agent prompt for dependency mapping and coordination artifact generation
- 8-field agent prompt template
- `/saw` skill for Claude Code with `check`, `scout`, `wave`, and `status` commands
- Suitability gate with 3-question assessment (file decomposition, investigation items, interface discoverability)
- Wave execution loop with post-merge verification
- Living coordination artifact (agents append completion reports)

### Protocol Evolution Timeline

The improvements in this release emerged through iterative testing on brewprune (a Homebrew package cleanup tool):

**Round 3 Cold-Start Audit (2026-02-27):**
- 19 findings → 11 parallel agents in single wave
- **Discovered gaps:**
  - 5/11 agents found work already implemented (wasted compute)
  - Agents E & C both modified `quickstart.go` out-of-scope (conflict)
  - Test suite (131 tests) timed out during agent verification (slow iteration)
  - Agent F's test had incorrect expectations (quality issue)
- **Result:** Wave completed, but inefficiencies identified

**Post-Round 3 Fixes (2026-02-27-28):**
- Implemented 3 protocol improvements: conflict detection, performance guidance, pre-implementation check
- Updated scout prompt and SAW skill

**Round 4 Cold-Start Audit (2026-02-28):**
- 38 findings (7 P0 critical manually fixed, 31 P1/P2 for SAW)
- Scout agent attempted to produce IMPL doc but refused to write file
- **Discovered gap:** "Read-only reconnaissance agent" prompt caused agent to misinterpret as technical constraint
- **Result:** Fixed scout prompt clarification

**Current state:** Protocol now includes all 4 improvements. Round 4 P1/P2 fixes (31 findings, 10 agents, 3 waves) ready for execution using the improved protocol.

### Lessons Learned

**Audit-fix-audit cycle validates the protocol:**
- Cold-start audits identify UX issues (source of truth for quality)
- SAW accelerates parallel fixing (11 agents → single wave in Round 3)
- Each audit reveals protocol gaps → improvements → better next iteration

**Key insights:**
- Post-merge verification caught integration issues individual agents missed
- Out-of-scope dependencies are real and need proactive conflict detection
- Test performance matters for iteration speed (focused tests during waves, full suite at merge)
- Pre-implementation checks prevent wasted agent compute
- Prompt clarity is critical - agents will self-limit if language is ambiguous

## Protocol Design

Scout-and-wave is optimized for:
1. **Parallelization without conflicts:** Disjoint file ownership is a hard constraint
2. **Interface contracts before implementation:** Agents code against specs, not each other
3. **Living coordination artifacts:** Agents append completion reports; downstream agents read updated reality
4. **Post-merge verification as the real gate:** Individual agent success doesn't guarantee integration success
5. **Fail-fast suitability assessment:** Better to identify poor fits early than force decomposition

The protocol evolves through real-world usage. Each experiment surfaces gaps that become improvements.
