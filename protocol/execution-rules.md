# Scout-and-Wave Protocol Execution Rules

**Version:** 0.14.0

This document defines the execution rules that govern orchestrator behavior during Scout-and-Wave protocol execution. These rules are not captured by the state machine alone.

---

## Overview

Rules are numbered E1–E23 for cross-referencing and audit; the same convention as invariants (I1–I6). When referenced in implementation files, the E-number serves as an anchor; implementations should embed the canonical definition verbatim alongside the reference.

To audit consistency, search implementation files for `E{N}` and verify the embedded definitions match this document.

---

## E1: Background Execution

**Trigger:** Launching any agent, polling CI, or running long-running watch commands

**Required Action:** All such operations must execute asynchronously without blocking the orchestrator's main execution thread.

**Why This Is Not a Performance Preference:** A blocking agent launch serializes the wave; the orchestrator waits for one agent before launching the next, eliminating parallelism. This is a protocol violation. Any implementation that blocks the orchestrator on agent execution or polling is non-conforming.

**Failure Handling:** If the runtime does not support asynchronous execution, the implementation is non-conforming.

---

## E2: Interface Freeze

**Trigger:** Worktrees are created

**Required Action:** Interface contracts become immutable. The review window between REVIEWED and WAVE_PENDING is the checkpoint for revising type signatures, adding fields, or restructuring APIs.

**Rationale:** After worktrees branch from HEAD, any interface change requires removing and recreating all worktrees for the wave.

### Recovery Paths When Interface Change Required After Worktrees Exist

When an interface change is required after worktrees exist and some agents have already committed work, two recovery paths are available:

**(a) Recreate and cherry-pick:**
- Record the commit SHAs of agents whose completed work does not implement or call the changed interface
- Remove and recreate all worktrees
- Cherry-pick the unaffected commits onto their new worktrees
- Verify each cherry-picked commit still builds against the new interface
- Re-run only the agents whose work is affected by the change
- Use this path when most agents have completed and the change is narrow (affects 1–2 agents)

**(b) Descope and defer:**
- Leave the current wave to complete against the existing contracts
- Move the interface revision to the next wave boundary, where it becomes the contract for a new wave
- Agents that cannot complete against the current contract report `status: blocked` (E8)
- The orchestrator resolves the contract change at the wave boundary
- Use this path when the change is broad, when few agents have completed, or when cherry-pick safety cannot be confirmed

**Simplified Case:** If no agents have committed work yet, recreate worktrees without cherry-pick.

**Scope:** E2 governs orchestrator-initiated interface changes. E8 governs the same problem from the other direction: agent-discovered contract failures.

**Related Invariants:** See I2 (interface contracts precede parallel implementation)

---

## E3: Pre-Launch Ownership Verification

**Trigger:** Before creating worktrees or launching any agent in a wave

**Required Action:** The orchestrator scans the wave's file ownership table in the IMPL doc and verifies no file appears in more than one agent's ownership list.

**Cross-repo waves:** The file ownership table must include a `Repo` column. Disjointness is checked per-repo — the same filename in different repositories is not a conflict. Files in different repos are inherently disjoint (no shared filesystem). E3 verification runs per-repo: within each repo, no two agents may own the same file.

**Failure Handling:** If an overlap is found within the same repo, the wave does not launch; the IMPL doc must be corrected first.

**Distinction:** This is distinct from post-execution conflict prediction (E11). Pre-launch catches scout planning errors; post-execution catches runtime deviations where an agent touched files outside its declared scope.

**Related Invariants:** See I1 (disjoint file ownership)

---

## E4: Worktree Isolation

**Trigger:** All Wave agents

**Required Action:** All Wave agents MUST use worktree isolation. There are no exceptions for work type (documentation-only, simple refactors, file moves, etc.).

**Failure Handling:** If work is too small to justify worktrees, it is too small for SAW; use sequential implementation instead.

### Rationale for Mandatory Isolation

- Worktrees enforce I1 (disjoint file ownership) mechanically, preventing concurrent writes to the same files on the main branch
- Enable independent verification of each agent's work before merge
- Provide rollback capability via worktree removal without affecting main
- Prevent execution-time interference from concurrent operations (builds, tests, file system operations)

### Five Layers Protecting Against Isolation Failures

**Layer 0 — Pre-commit hook:**
- A git pre-commit hook installed during worktree setup blocks commits to main during active waves
- Agents that attempt to commit to main receive an instructive error with their assigned worktree path
- The orchestrator bypasses the hook for legitimate main commits
- This is infrastructure enforcement: it prevents the violation rather than detecting it
- The hook is shipped as a file and installed ephemerally: copied during worktree creation, removed during cleanup

**Layer 1 — Manual pre-creation:**
- The orchestrator creates all worktrees before launching any agent
- This is the primary mechanism
- It is deterministic and does not depend on agent cooperation

**Layer 2 — Task tool isolation:**
- Runtime isolation parameters provide isolation when the orchestrator and target repository are the same
- This is the secondary mechanism
- **Cross-repository waves: omit Layer 2 intentionally.** When agents work in a different repo from the Orchestrator, `isolation: "worktree"` creates worktrees in the Orchestrator's repo (wrong repo). Omit the parameter entirely for cross-repo agents. Layer 1 (manual worktree creation in each target repo) and Layer 3 (Field 0 absolute path navigation) provide the isolation instead. Omitting Layer 2 in a cross-repo wave is correct protocol, not a degraded fallback.
- Layer 2 may also fail silently in same-repo scenarios — do not rely on it alone.

**Layer 3 — Field 0 self-verification:**
- Each agent verifies its working directory at startup (change directory, verify path, verify branch)
- The change directory command is strict (no silent failure suppression) — if navigation to the worktree fails, the agent exits immediately with status 1
- This works correctly in both same-repo and cross-repo scenarios: when Layer 2 positioned the agent correctly (same-repo), the change directory is a no-op that succeeds; when Layer 2 is omitted (cross-repo), change directory performs actual navigation
- All subsequent agent operations inherit this working directory
- If verification fails after successful directory change, the agent exits without modifying files
- This is agent-cooperative defense-in-depth

**Layer 4 — Merge-time trip wire:**
- Before any merge, the orchestrator verifies each agent branch has commits beyond the base
- Empty branch = hard stop
- This catches all isolation failures regardless of cause

**Summary:** Layer 0 prevents the most common failure mode (agent commits to main). Layers 1 and 2 may both fire; this is harmless. If all prevention layers fail, Layer 4 catches it before any incorrect merge.

### Relationship to Disjoint File Ownership

Disjoint file ownership and worktree isolation are complementary layers that protect against different failure modes. Neither substitutes for the other.

- **Disjoint file ownership (I1)** prevents merge conflicts: no two agents produce edits to the same file, so the merge step is always conflict-free.
- **Worktree isolation** prevents execution-time interference: each agent's build, test, and tool-cache writes operate on an independent working tree, so concurrent builds do not race on shared build caches, test caches, lock files, or intermediate object files. Without worktrees, two agents running builds simultaneously on the same directory produce flaky failures that look like code bugs but are actually filesystem races.

**Result:** Disjoint ownership without worktrees: merge is safe, but concurrent execution is flaky. Worktrees without disjoint ownership: execution is clean, but merge produces unresolvable conflicts. Both constraints must hold simultaneously for parallel waves to be correct and reproducible.

**Related Invariants:** See I1 (disjoint file ownership)

---

## E5: Worktree Naming Convention

**Trigger:** Creating worktrees

**Required Action:** Worktrees must be named `.claude/worktrees/wave{N}-agent-{ID}` where `{N}` is the 1-based wave number and `{ID}` is the agent identifier. Agent identifiers follow the `[A-Z][2-9]?` pattern: a single uppercase letter (generation 1, e.g., `A`, `B`, `C`) or a letter followed by a digit 2–9 (multi-generation, e.g., `A2`, `B3`). Examples: `wave1-agent-A`, `wave1-agent-A2`, `wave2-agent-B3`.

**Why This Is Not a Style Choice:** This is a canonical requirement. The naming scheme is the mechanism by which external tooling identifies SAW sessions and correlates agents to waves. Deviating from it breaks observability silently. Any tooling that consumes SAW session data must treat this naming scheme as the stable interface.

**Failure Handling:** Non-conforming worktree names prevent monitoring tools from detecting SAW sessions.

---

## E6: Agent Prompt Propagation

**Trigger:** Interface deviation propagation, contract revision, or same-wave interface failure

**Required Action:** When the orchestrator updates an agent prompt, it edits the prompt section in the IMPL doc directly. The agent reads its prompt from the IMPL doc at launch time, so the corrected version is always what runs.

**Rationale:** There is no separate prompt file to keep in sync. The IMPL doc is the single source of truth.

**Related Invariants:** See I4 (IMPL doc is single source of truth)

---

## E7: Agent Failure Handling

**Trigger:** Any agent in a wave reports `status: partial` or `status: blocked`

**Required Action:** The wave does not merge. The wave goes to BLOCKED. The orchestrator must resolve the failing agent (re-run it, manually fix the issue, or descope it from the wave) before the merge step proceeds.

**Constraint:** Agents that completed successfully are not re-run, but their worktrees are not merged until the full wave is resolved. Partial merges are not permitted.

**Failure Handling:** See E7a for automatic remediation in `--auto` mode

---

## E7a: Automatic Failure Remediation in --auto Mode

**Trigger:** `--auto` mode is active AND an agent fails with a correctable issue

**Required Action:** The orchestrator should automatically re-launch the agent with corrections rather than surfacing the failure to the user.

### Correctable Failures

Failures where the fix is deterministic and requires no human decision:

- **Isolation failures:** Re-launch with explicit repository context (absolute IMPL doc path) so the agent can derive the correct repository root
- **Missing dependencies:** Install the dependency and re-launch
- **Transient build errors:** Re-run after a brief delay (network hiccups, race conditions in parallel builds)

### Non-Correctable Failures

Always surface to the user regardless of `--auto` mode:
- Logic errors
- Test failures
- Interface contract violations

**Distinction:** correctable = environmental/setup issue, non-correctable = code or design issue requiring human judgment.

**Retry Limit:** In `--auto` mode, the orchestrator may retry a correctable failure up to 2 times before escalating to the user. Each retry should include an explanatory note in logs but should not block wave execution. If an agent succeeds after retry, the wave proceeds normally; no user intervention is required.

---

## E8: Same-Wave Interface Failure

**Trigger:** Any agent reports `status: blocked` due to an interface contract being unimplementable as specified

**Required Action:**
- The wave does not merge
- The orchestrator marks the wave BLOCKED
- Revises the affected contracts in the IMPL doc
- Re-issues prompts to all agents whose work depends on the changed contract
- Agents that completed cleanly against unaffected contracts do not re-run
- The wave restarts from WAVE_PENDING with the corrected contracts

**Relationship to E2:** E2 governs orchestrator-initiated interface changes. E8 governs the same problem from the other direction: agent-discovered contract failures.

**Related Invariants:** See I2 (interface contracts precede parallel implementation)

---

## E9: Idempotency

**WAVE_PENDING Re-Entry:** WAVE_PENDING is re-entrant; re-running the wave command checks for existing worktrees before creating new ones and does not duplicate them.

**WAVE_MERGING Non-Idempotency:** WAVE_MERGING is not idempotent. If the orchestrator crashes mid-merge, inspect the state before continuing: check which worktree branches are already present in main's history (search merge commits) and skip those. Do not re-merge a worktree that has already been merged.

**Failure Handling:** Before continuing a crashed merge, the orchestrator must verify merge state to prevent duplicate merges.

---

## E10: Scoped vs Unscoped Verification

**During Waves (Agent Verification):** Agents run focused verification scoped to the files and packages they own to keep iteration fast.

**Post-Merge (Orchestrator Verification):** The orchestrator's post-merge gate runs unscoped across the full project to catch cross-package cascade failures that no individual agent could see.

### Scout Responsibility

The scout must specify exact verification commands in Field 6 of each agent prompt. Agents run those exact commands; they may not substitute broader ones.

"Scoped" is not self-evident from agent context: a command that tests all packages is unscoped regardless of how fast it runs; the correct scoped command targets only owned packages. The scout knows the project structure and can determine the right target; agents must not guess.

**Non-Conformance:** An agent that substitutes a broader command than specified is non-conforming, even if the command passes.

---

## E11: Conflict Prediction Before Merge

**Trigger:** Before merging any wave

**Required Action:** The orchestrator cross-references all agents' `files_changed` and `files_created` lists before touching the working tree. A file appearing in more than one agent's list is a disjoint ownership violation. It must be resolved before any merge proceeds.

**Merge Order:** Within a valid wave, merge order is arbitrary. Same-wave agents are independent by construction: any agent whose work depends on a file created by another agent belongs in a later wave. If merge order appears to matter, the wave structure is wrong, not the merge sequence.

**Related Invariants:** See I1 (disjoint file ownership)

---

## E12: Merge Conflict Taxonomy

Three distinct conflict types can arise; each has a different resolution path:

### 1. Git Conflict on Agent-Owned Files

**Cause:** an I1 violation. This is impossible if invariants hold.

**Resolution:** If it occurs, the scout produced an incorrect ownership table. Do not merge. Correct the IMPL doc and re-run the wave.

### 2. Git Conflict on Orchestrator-Owned Shared Files

**Cause:** Expected. Multiple agents append to IMPL doc completion report sections or append-only config registries.

**Resolution:** Resolve by accepting all appended sections. Each agent owns a distinct named section; there is no semantic conflict, only a git conflict on adjacent lines.

### 3. Semantic Conflict

**Cause:** Two agents implement incompatible interfaces without a git conflict.

**Detection:** Surfaces in `interface_deviations` and `out_of_scope_deps` in completion reports.

**Resolution:** Resolved by the orchestrator before the next wave launches, via interface contract revision and downstream prompt updates.

---

## E13: Verification Minimum

**Minimum Acceptable Verification Gate:** Build (compile) passing and lint passing.

**Test Requirement:** Tests are required if the project has a test suite. A wave reporting PASS on compile-only when tests exist is a protocol violation.

**Scoping:**
- Agents scope their verification to owned files and packages
- The orchestrator's post-merge gate runs unscoped to catch cross-package cascade failures

**Related Rules:** See E10 (scoped vs unscoped verification)

---

## E14: IMPL Doc Write Discipline

**Trigger:** Agent writes completion report

**Required Action:** Agents write to the IMPL doc exactly once: by appending their named completion report section at the end of the file under `### Agent {ID} - Completion Report`.

**Prohibition:** Agents must not edit any earlier section of the IMPL doc (interface contracts, file ownership table, suitability verdict, wave structure). Those sections are frozen at worktree creation (E2).

**Interface Deviations:** Any apparent need to update an earlier section is an interface deviation; it must be reported in the completion report and resolved by the Orchestrator, not edited in-place by the agent.

**Why This Matters:** This constraint is what makes IMPL doc git conflicts predictably resolvable: two agents appending distinct named sections always produce adjacent-section conflicts with no semantic overlap (E12).

**Related Invariants:** See I4 (IMPL doc is single source of truth) and I5 (agents commit before reporting)

**Related Rules:** See E12 (merge conflict taxonomy)

---

## E15: IMPL Doc Completion Marker

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE transition)

**Required Action:** The orchestrator writes `<!-- SAW:COMPLETE YYYY-MM-DD -->` (with the current ISO date) on the line immediately after the IMPL doc title, then commits the update. This is the formal close of the IMPL lifecycle. The marker must be written before the orchestrator reports completion to the user.

**Format:** HTML comment tag. Invisible in rendered markdown. Parseable with a single regex: `<!-- SAW:COMPLETE (\d{4}-\d{2}-\d{2}) -->`. Tooling can grep a directory of IMPL docs without parsing each file.

**Constraint:** Only the orchestrator writes this marker. Agents never add or modify it (E14 already prohibits agents from editing earlier sections). If the marker is already present, do not overwrite.

**Backward Compatibility:** IMPL docs without the `<!-- SAW:COMPLETE -->` tag are treated as active. No migration is required.

**Related Rules:** See E14 (IMPL doc write discipline). See state-machine.md for the WAVE_VERIFIED → COMPLETE transition guard.

---

## E16: Scout Output Validation

**Trigger:** Scout writes IMPL doc to disk

**Required Action:** Orchestrator runs the IMPL doc validator before entering REVIEWED state.
If validation fails, the specific errors are fed back to Scout as a correction prompt.
Scout rewrites only the failing sections. This loops until the doc passes or a retry limit
(default: 3) is reached.

**Validator scope:** Typed-block sections (`type=impl-*` blocks) plus document-level presence checks. Prose sections are excluded from content validation.

**E16A — Required block presence:** An IMPL doc that contains any typed blocks must include all three of the following, or validation fails:
- `type=impl-file-ownership`
- `type=impl-dep-graph`
- `type=impl-wave-structure`

Error format: `missing required block: impl-dep-graph`

Trigger condition: E16A fires only when `block_count > 0`. Docs with no typed blocks (pre-v0.10.0 format) skip this check and receive the existing "no typed blocks found" warning instead.

**E16B — Dep graph grammar:** When an `impl-dep-graph` block is present, its contents must conform to the canonical grammar. This check already exists in both the bash and Go validators; this rule documents it authoritatively.

Canonical dep graph grammar:
```
Wave N (label):          # one or more Wave sections; N is a digit
    [X] path/to/file     # one or more agent entries per wave; X is an agent ID matching [A-Z][2-9]?
        ✓ root           # root agents declare ✓ root
    [Y] path/to/file
        depends on: X    # dependent agents declare depends on: <agent IDs>
```

Rules:
- At least one `Wave N` line (where N is one or more digits) must appear.
- At least one `[X]` agent entry must appear. `X` is an agent ID matching `[A-Z][2-9]?` (e.g., `A`, `B2`, `C3`).
- Each agent entry must be followed (before the next agent entry) by either `✓ root` or `depends on:` on an indented line.

**E16C — Out-of-band dep graph detection (warn only):** If a plain fenced block (no `type=` annotation) contains both a `[A-Z][2-9]?` agent reference pattern and the word `Wave`, the validator emits a warning to stdout but does not fail. This catches dep graphs written as ASCII art outside typed blocks.

Warning format: `WARNING: possible dep-graph content found outside typed block at line N — use \`\`\`yaml type=impl-dep-graph\`\`\``

E16C warnings appear in the correction prompt fed back to Scout but do not trigger a retry on their own. They are informational — the Scout should move the content into a typed block.

**Correction prompt format:** The orchestrator's correction prompt to Scout must list each error with the section name, the specific failure (e.g., "impl-dep-graph block: Wave 2 missing `depends on:` line for agent [C]"), and the line number or block identifier where the error occurred. This gives Scout precise targets for correction without requiring it to re-read the whole doc.

**Retry limit:** Default 3 attempts. After the 3rd failed validation, enter BLOCKED. Implementations may override this default, but the default is 3.

**On retry limit exhausted:** Enter BLOCKED state. Orchestrator surfaces validation errors
to human. Do not enter REVIEWED.

**On validation pass:** Proceed to REVIEWED normally.

**Relationship to structured outputs:** For API-backend runs using structured output enforcement, the validator always passes on first attempt (the output was already schema-validated). E16's correction loop is effectively a no-op in that path but must still be present in the protocol for CLI-backend and hand-edited docs.

---

## E17: Scout Reads Project Memory

**Trigger:** Scout begins a new suitability assessment

**Required Action:** Before running the suitability gate, the Scout checks for
`docs/CONTEXT.md` in the target project. If the file exists, Scout reads it in
full and uses its contents to inform the suitability assessment:
- `established_interfaces` — avoids proposing types that already exist
- `decisions` — respects prior architectural decisions; does not contradict them
- `conventions` — follows project naming, error handling, and testing conventions
- `features_completed` — understands project history and prior wave structure

**If absent:** Scout proceeds normally without it. `docs/CONTEXT.md` is optional;
projects that have never completed a SAW feature will not have one.

**Rationale:** Without project memory, each Scout run starts cold. After several
features, the project accumulates naming conventions, module boundaries, and
interface decisions that the Scout would otherwise rediscover (expensively) or
miss entirely.

**Related Rules:** See E18 (Orchestrator creates/updates docs/CONTEXT.md after
each completed feature).

---

## E18: Orchestrator Updates Project Memory

**Trigger:** Final wave's post-merge verification passes (WAVE_VERIFIED → COMPLETE
transition — same trigger as E15)

**Required Action:** The Orchestrator creates or updates `docs/CONTEXT.md` in the
target project:

1. If `docs/CONTEXT.md` does not exist, create it with the schema defined in
   `message-formats.md` (## docs/CONTEXT.md — Project Memory section).

2. Append to `features_completed`:
   ```yaml
   - slug: {feature-slug}
     impl_doc: docs/IMPL/IMPL-{feature-slug}.md
     waves: {N}
     agents: {total agent count}
     date: {YYYY-MM-DD}
   ```

3. Append any architectural decisions made during this feature to `decisions`.
   Decisions are identified from interface contracts and any `out_of_scope_deps`
   resolutions that reveal project conventions.

4. Append any new scaffold-file interfaces to `established_interfaces`. An
   interface is "established" if it was committed as a scaffold file and is now
   part of the project's public module boundary.

5. Commit: `git commit -m "chore: update docs/CONTEXT.md for {feature-slug}"`

**Constraint:** E18 runs after E15 (IMPL doc completion marker). The commit order
is: E15 writes `<!-- SAW:COMPLETE -->` to the IMPL doc, then E18 updates
`docs/CONTEXT.md`, then a single commit captures both.

**When to omit:** If no new decisions, interfaces, or conventions were established
during the feature, E18 still appends to `features_completed` but may omit the
other fields.

**Related Rules:** See E15 (IMPL doc completion marker), E17 (Scout reads project
memory).

---

## E19: Failure Type Decision Tree

**Trigger:** Any agent reports `status: partial` or `status: blocked` with a
`failure_type` field

**Required Action:** The Orchestrator reads `failure_type` and applies the
corresponding action:

| failure_type   | Orchestrator action |
|----------------|---------------------|
| `transient`    | Retry automatically, up to 2 times. If all retries fail, escalate to human. Log each retry attempt. |
| `fixable`      | Read agent's free-form notes for the specific fix. Apply the fix (install dependency, correct path, update config). Relaunch the agent. One retry only; if it fails again, escalate. |
| `needs_replan` | Do not retry. Re-engage Scout with the agent's completion report as additional context. Scout produces a revised IMPL doc. Human reviews before wave re-executes. |
| `escalate`     | Surface immediately to human with agent's full completion report. No automatic action. |
| `timeout`      | Retry once with an explicit note in the retry prompt: "Your previous run exhausted its turn limit. Commit any partial work immediately, then complete only what is essential. Defer non-critical work." If the retry also times out, escalate to human — scope may need to be reduced in the IMPL doc. |

**Backward compatibility:** If `failure_type` is absent from a completion report
that has `status: partial` or `status: blocked`, treat as `escalate` (most
conservative fallback). This preserves compatibility with agents that predate E19.

**Relationship to E7:** E7 defines the general failure handling rule (wave does
not merge, enters BLOCKED state). E19 is the decision tree within that BLOCKED
state — it specifies what the Orchestrator does next based on failure classification.
E7 and E19 are complementary; E19 does not supersede E7.

**Relationship to E7a:** E7a defines automatic remediation for correctable failures
in `--auto` mode. E19 extends this to non-`--auto` mode for `transient` and
`fixable` failures. In `--auto` mode, E7a and E19 apply together; E7a's retry
limit (2 retries) applies.

**Related Rules:** See E7 (agent failure handling), E7a (automatic failure
remediation), message-formats.md (failure_type field definition).

---

## E20: Stub Detection Post-Wave

**Trigger:** After all wave agents in a wave write their completion reports and before the review checkpoint.

**Required Action:** The Orchestrator:
1. Collects the union of all `files_changed` and `files_created` from wave agent completion reports.
2. Runs `bash ${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh {file1} {file2} ...` with that file list.
3. Appends the scan output to the IMPL doc under `## Stub Report — Wave {N}` (after the last completion report section for this wave).

Exit code of `scan-stubs.sh` is always 0 — stub detection is informational only. Stubs found are surfaced at the review checkpoint but do not block merge automatically.

**Note:** The script carries the comment `# scan-stubs.sh — SAW stub detection scanner (E20)` — E20 was reserved in the script header before this rule was written.

**Rationale:** An agent can write a syntactically correct function shell with a stub body (`pass`, `...`, `raise NotImplementedError`) and mark `[COMPLETE]`. The human reviewer approving the plan (not the diff) may not catch it. Stub detection surfaces hollow implementations before they ship.

**Related Rules:** See E21 (post-wave verification gates), `message-formats.md` (## Stub Report Section Format).

---

## E21: Automated Post-Wave Verification

**Trigger:** After all wave agents in a wave report complete and after E20 stub scan, before merge.

**Required Action:** If the IMPL doc contains a `## Quality Gates` section, the Orchestrator reads the configured gates and runs each command:

| Gate type   | Example command              |
|-------------|------------------------------|
| `typecheck` | `tsc --noEmit`, `mypy .`     |
| `test`      | `go test ./...`, `npm test`  |
| `lint`      | `go vet ./...`, `ruff check` |
| `custom`    | Any command in the IMPL doc  |

For each gate:
- `required: true` — non-zero exit code **blocks merge**. Report failure to user.
- `required: false` — non-zero exit code is a **warning only**. Log and continue.

**Flow levels** (set in `## Quality Gates` section):
- `quick` — skip all gates
- `standard` — run all gates; failures warn
- `full` — run all gates; required failures block merge

**Out of scope:** AI Verification Gate (an agent that reviews implementation correctness). Subprocess-based gates only.

**Rationale:** Individual agents run gates in isolation (their own package scope). The orchestrator's post-wave gate runs unscoped — catching cross-package cascade failures that agent-scoped gates miss.

**Related Rules:** See E20 (stub detection), E22 (scaffold build verification), `message-formats.md` (## Quality Gates Section Format).

---

## E22: Scaffold Build Verification

**Trigger:** Scaffold Agent completes file creation, before committing.

**Required Action:** The Scaffold Agent must run, in order:

1. **Dependency resolution** — ensure declared dependencies resolve:
   - Go: `go get ./...`
   - Python: `pip install -e .` or `uv sync`
   - Node: `npm install`
   - Rust: `cargo fetch`

2. **Dependency cleanup** (where applicable):
   - Go: `go mod tidy`

3. **Build verification** — confirm the project compiles with scaffold files present:
   - Go: `go build ./...`
   - Rust: `cargo build`
   - Node: `tsc --noEmit` or `npm run build`
   - Python: `python -m mypy .` or `python -m py_compile`

**Failure behavior:** If any step fails, the Scaffold Agent:
- Does NOT commit the scaffold files
- Marks each failing scaffold file's status as `FAILED: {error output}` in the IMPL doc Scaffolds section
- Reports `status: FAILED` in its completion report

The Orchestrator reads this and halts before creating any worktrees. The user must revise the interface contracts and re-run the Scaffold Agent.

**Rationale:** Scaffold files define types and interfaces that Wave agents import. A scaffold file with a syntax error, wrong import path, or missing dependency causes every Wave agent in the next wave to fail immediately — wasting the full wave execution.

**Related Rules:** See `procedures.md` (Procedure 2: Scaffold Agent), `message-formats.md` (Scaffolds Section Format), `agents/scaffold-agent.md`.

---

## E23: Per-Agent Context Extraction

**Trigger:** Orchestrator is about to launch a Wave agent.

**Required Action:** The orchestrator constructs a per-agent context payload for each Wave agent instead of passing the full IMPL doc. The payload contains exactly:

1. The agent's 9-field prompt section (extracted from IMPL doc by heading: `### Agent {letter} - {Role}`)
2. The full `## Interface Contracts` section
3. The full `## File Ownership` table
4. The full `## Scaffolds` section (agent needs to know what is pre-built)
5. The full `## Quality Gates` section (agent needs its verification commands)
6. The absolute path to the IMPL doc (agent writes completion report here per I5)

This assembled payload is passed as the `prompt` parameter when launching the agent. The agent does not receive or read the full IMPL doc.

**Excluded sections:** Other agents' 9-field prompt sections, `## Suitability Assessment`, `## Dependency Graph`, `## Pre-Mortem`, `## Known Issues`, `## Wave Structure` prose, completion reports from prior waves.

**Rationale:** Without extraction, N agents each receive N−1 other agents' full prompts — O(N²) token consumption that grows with wave size. With extraction, every agent receives the same payload size regardless of wave count. A 14-agent wave eliminates 182 unnecessary prompt reads (14 × 13). Context quality also improves: agents reason about their own task without unrelated implementation plans in working context.

**E6 interaction:** E6 (Agent Prompt Propagation) is unchanged. When the orchestrator updates an agent's section in the IMPL doc (interface deviation propagation), it re-extracts the updated payload before re-launching. The IMPL doc remains source of truth (I4); E23 describes how agents consume it at launch time.

**I4 interaction:** I4 (IMPL doc is source of truth) is unchanged. Agents write completion reports to the full IMPL doc via the absolute path included in the payload.

**Related:** See Per-Agent Context Payload in `message-formats.md`.

---

## Cross-References

- See `preconditions.md` for conditions that must hold before execution begins
- See `invariants.md` for runtime constraints that must hold during execution
- See `state-machine.md` and `message-formats.md` for state machine and message format specifications
- See `state-machine.md` for the SCOUT_VALIDATING state triggered by E16
- E17: Scout reads `docs/CONTEXT.md` before suitability assessment — see also `message-formats.md` (docs/CONTEXT.md schema)
- E18: Orchestrator creates/updates `docs/CONTEXT.md` after WAVE_VERIFIED → COMPLETE — see also E15, `message-formats.md`
- E19: Orchestrator applies `failure_type` decision tree on partial/blocked agents — see also E7, E7a, `message-formats.md`
- E20: Orchestrator runs stub detection after each wave — see also E21, `message-formats.md` (## Stub Report Section Format)
- E21: Orchestrator runs post-wave verification gates before merge — see also E20, E22, `message-formats.md` (## Quality Gates Section Format)
- E22: Scaffold Agent runs build verification before committing scaffold files — see also E5, `message-formats.md` (Scaffolds Section Format), `agents/scaffold-agent.md`
