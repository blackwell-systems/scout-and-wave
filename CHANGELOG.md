# Changelog

All notable changes to the Scout-and-Wave protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Version History

| Version | Date | Headline |
|---------|------|----------|
| Unreleased | -- | Spec completeness pass: E1–E14 numbered, six spec holes patched, state machine diagram, all invariants embedded in skill |
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

## [Unreleased]

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
