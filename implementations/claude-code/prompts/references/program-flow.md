# Program Commands — On-Demand Reference

**Contents:**
- [Create PROGRAM from Existing IMPLs](#saw-program---impl)
- [Level A: Planning Only — program plan/execute/status/replan](#program-commands-level-a-planning-only)
  - [/saw program plan](#saw-program-plan-project-description)
  - [/saw program execute](#saw-program-execute-project-description)
  - [/saw program status](#saw-program-status)
  - [/saw program replan](#saw-program-replan---reason-reason)

**Wave execution:** Program tiers execute IMPLs using the standard wave loop from the core SKILL.md (steps 3-11 of Execution Logic). Do not duplicate that logic here — when Step 3b says "use existing `/saw wave --auto` flow", follow the wave loop in the core file.

**Lifecycle analogy — Program commands mirror IMPL commands:**

| IMPL Lifecycle | Program Lifecycle | Purpose |
|---------------|-------------------|---------|
| `/saw scout <feature>` | `/saw program --impl x y z` or `/saw program plan` | Create the plan artifact |
| `/saw wave` | `/saw program execute` | Execute next unit of work (wave / tier) |
| `/saw wave --auto` | `/saw program execute --auto` | Execute all remaining units automatically |
| `/saw status` | `/saw program status` | Show progress |
| `/saw amend --extend-scope` | `/saw program replan --reason` | Revise the plan after failure |

## /saw program --impl — Create PROGRAM from Existing IMPLs

Create a PROGRAM manifest from pre-existing IMPL docs with automatic tiering based on file ownership disjointness.

**Orchestrator flow:**

1. **Parse `--impl` flag values.** Extract all IMPL slugs from the argument string. Each value after `--impl` that is not a recognized flag (`--slug`, `--title`) is an IMPL slug. Also parse optional flags:
   - `--slug <name>` — override the auto-generated program slug
   - `--title <name>` — override the auto-generated program title

2. **Resolve slugs to IMPL doc paths.** Run:
   ```bash
   sawtools list-impls --dir "<repo-path>/docs/IMPL"
   ```
   Match each provided slug against the returned IMPL metadata. If any slug cannot be resolved, report the missing slug(s) to the user and stop.

3. **Create PROGRAM manifest.** Run:
   ```bash
   sawtools create-program --from-impls <slug1> --from-impls <slug2> ... --repo-dir "<repo-path>"
   ```
   If `--slug` was provided, append `--slug <name>`. If `--title` was provided, append `--title <name>`.

   This command internally:
   - Runs `check-impl-conflicts` to detect file ownership overlaps
   - Auto-assigns tiers based on file disjointness (P1+): IMPLs with disjoint file ownership are placed in the same tier; IMPLs with overlapping files are placed in sequential tiers
   - Generates a PROGRAM manifest at `docs/PROGRAM-<auto-slug>.yaml`

4. **Report results to the user:**
   - **Tier assignments** — which IMPLs were placed in which tier, and why
   - **File ownership conflicts** — any overlaps detected between IMPLs (these drive tier separation)
   - **Generated manifest path** — the absolute path to the new PROGRAM manifest
   - **Suggested next step** — `/saw program execute` to begin tier-gated execution, or `/saw program status` to review the manifest

5. **Does NOT auto-execute.** This is a planning-only command. The user must explicitly invoke `/saw program execute` or `/saw program status` to proceed.

---

## Program Commands (Level A: Planning Only)

### `/saw program plan "<project-description>"`

Analyze a project and produce a PROGRAM manifest that decomposes it into multiple IMPLs organized into tiers for parallel execution. Use this for projects that span multiple features with cross-feature dependencies.

**Orchestrator flow:**

1. **Requirements intake.** If user provides a project description (not a reference to existing REQUIREMENTS.md), write `docs/REQUIREMENTS.md` using the template from the bootstrap flow. If the user references an existing REQUIREMENTS.md, skip this step. Ask the user to review the requirements before proceeding.

2. **Launch Planner agent.** Use the Agent tool with `subagent_type: planner` and `run_in_background: true`. The prompt parameter is:
   ```
   Analyze the project described in docs/REQUIREMENTS.md and produce a PROGRAM manifest at docs/PROGRAM-<slug>.yaml. Follow the protocol in agents/planner.md.
   ```
   Inform the user the Planner is running.

3. **Wait for Planner completion.** The Planner produces `docs/PROGRAM-<slug>.yaml`. If the Planner determines the project is NOT_SUITABLE for multi-IMPL orchestration, it writes a minimal manifest with `state: "NOT_SUITABLE"` and an explanation. Surface this to the user and recommend `/saw bootstrap` or `/saw scout` instead.

4. **Validate PROGRAM manifest.** Run:
   ```bash
   sawtools validate-program "<absolute-path-to-program-manifest>"
   ```
   This validates the PROGRAM schema and enforces invariant P1 (no circular dependencies within tiers). If exit code is 0, proceed to human review. If exit code is 1, send the validation errors back to the Planner as a correction prompt using **resume with the Planner's agent ID**: `resume: <planner-agent-id>`, `prompt: "Your PROGRAM manifest failed validation. Fix these issues:\n{errors}"`. Retry up to 3 attempts. On retry limit exhaustion, enter BLOCKED state and surface the validation errors to the user.

5. **Human review.** If validation passes, report the PROGRAM manifest to the user:
   - Tier structure (how many tiers, which IMPLs in each)
   - Program contracts (shared types/APIs that span features)
   - Cross-IMPL dependencies (which IMPLs depend on which)
   - Estimated complexity (total agents, total waves across all IMPLs)
   - Tier gates (quality checks between tiers)

   Surface the PROGRAM manifest and ask the user to review. The user may approve as-is, request changes, or reject the plan.

6. **State transition.** If the user approves, update the PROGRAM manifest state to `REVIEWED`:
   ```bash
   sawtools update-program-state "<manifest-path>" --state REVIEWED
   ```

**What happens next (not in your scope as Orchestrator):**

After human approval, the program enters the execution phase:
- **Scaffold phase:** Materialize program contracts as source code (committed to HEAD)
- **Tier 1 execution:** Launch Scout agents for all Tier 1 IMPLs in parallel
- **Tier boundary:** Run tier gates, freeze program contracts consumed by Tier 2
- **Tier 2 execution:** Launch Scout agents for all Tier 2 IMPLs in parallel
- Repeat until all tiers complete

This is the `/saw program execute` flow (Level B), which is documented in the next section.

### `/saw program execute "<project-description>"`

Orchestrator flow for `/saw program execute`: Plan and execute a multi-IMPL program with tier-gated progression. This extends the Level A planning flow with automated execution.

**Resume detection:** Before starting the planning flow, check if a PROGRAM manifest already exists:
```bash
sawtools list-programs --dir "<repo-path>/docs"
```
If a PROGRAM manifest is found with state `REVIEWED`, `TIER_EXECUTING`, `TIER_VERIFIED`, or `BLOCKED`:
- Report the existing program to the user: "Found existing PROGRAM: {title} ({slug}) in state {state}"
- If state is `REVIEWED` or `TIER_VERIFIED`: skip Phase 1, proceed directly to Phase 2 (scaffold) or Phase 3 (tier execution) as appropriate
- If state is `TIER_EXECUTING`: resume the current tier (identify the first tier with incomplete IMPLs and continue execution)
- If state is `BLOCKED`: surface the blocking issue and ask the user whether to fix and resume, or replan
- This mirrors how `/saw wave` auto-selects an existing IMPL when one is pending

If no existing PROGRAM manifest is found, or the user provides a new description, proceed with Phase 1.

**Phase 1: Planning (reuses /saw program plan flow)**

Steps 1-6 from the existing `/saw program plan` section apply:
1. Requirements intake
2. Launch Planner agent
3. Wait for Planner completion
4. Validate PROGRAM manifest
5. Human review
6. State transition to REVIEWED

After human approves the PROGRAM manifest, continue to Phase 2.

**Phase 2: Program Scaffold (if program contracts exist)**

If the manifest has program_contracts with defined locations, launch a Scaffold Agent to materialize them as source code:
1. Launch Scaffold Agent using the Agent tool with `subagent_type: scaffold-agent` and `run_in_background: true`
2. The prompt parameter is the path to the PROGRAM manifest
3. The Scaffold Agent reads the program_contracts section and creates the scaffold source files
4. Wait for Scaffold Agent to complete
5. Verify all contract files show `Status: committed` in the manifest
6. If any file shows `Status: FAILED`, stop and surface the failure to the user
7. Commit scaffold files to HEAD
8. Transition manifest state to TIER_EXECUTING

**Phase 3: Tier Execution Loop (E28)**

For each tier N from 1 to manifest.tiers_total:

**Step 3a: Parallel Scout Launching (E31)**

Partition tier N IMPLs by status (E28A):
- **pending / scouting** — Scout as normal (existing flow below)
- **reviewed / complete** — Validate only (skip Scout, see pre-existing validation below)

*Scout new IMPLs:*
- For each IMPL in tier N with status "pending":
  - Launch Scout agent with: `subagent_type: scout`, `run_in_background: true`
  - Pass --program flag: `sawtools run-scout "<impl-title>" --program "<manifest-path>"`
  - Scout receives frozen program contracts as immutable inputs
- Wait for all Scouts to complete
- Validate each newly scouted IMPL doc (E16): run `sawtools validate --fix "<impl-doc-path>"` for each

*Validate pre-existing IMPLs (E28A):*
- For each IMPL in tier N with status "reviewed" or "complete":
  - Verify IMPL doc exists: `docs/IMPL/IMPL-<slug>.yaml`
  - Run: `sawtools validate --fix "<impl-doc-path>"`
  - Check P2 compliance: `sawtools freeze-check "<program-manifest>" --impl "<slug>"`
  - If validation fails, enter BLOCKED

> **Tip:** Use `sawtools import-impls` before program execution to bulk-import
> pre-existing IMPL docs into the PROGRAM manifest with correct tier assignments
> and status. This avoids manual manifest editing when adopting existing work.

- Present ALL IMPL docs (newly scouted + pre-existing) for unified human review (tier structure, file ownership, interface contracts)

**P1+ Pre-flight: File Ownership Conflict Check**

After human review approves the tier, run the conflict check before launching any IMPL agents:
```bash
sawtools check-program-conflicts "<manifest-path>" --tier N
```
This enforces P1+: no two IMPLs in the same tier may own the same file. If conflicts are found, enter BLOCKED — surface the conflicting IMPL/file pairs to the user and do not launch any agents until the IMPL docs are revised to resolve ownership.

**Step 3a.5: Create IMPL Branches**

Create long-lived IMPL branches for all IMPLs in the tier:
```bash
sawtools create-program-worktrees "<manifest-path>" --tier N --repo-dir "<repo-path>"
```
Each IMPL gets a branch: `saw/program/{slug}/tier{N}-impl-{implSlug}`.
These branches are the merge targets for all wave executions within
the IMPL — waves merge to the IMPL branch, NOT to main.

**Step 3b: IMPL Execution**
- For each reviewed IMPL in tier N:
  - Compute IMPL branch: `saw/program/{slug}/tier{N}-impl-{implSlug}`
  - Execute the full IMPL lifecycle with IMPL branch as merge target:
    - prepare-wave: `sawtools prepare-wave <impl-doc> --wave W --merge-target <impl-branch>`
    - finalize-wave: `sawtools finalize-wave <impl-doc> --wave W --merge-target <impl-branch>`
    - Waves merge to the IMPL branch, isolating each IMPL's work
  - Use existing `/saw wave --auto` flow per IMPL (with merge target threading)
  - Update IMPL status in PROGRAM manifest as each completes (E32):
    ```bash
    sawtools update-program-impl "<manifest>" --impl "<slug>" --status "<status>"
    ```
- Wait for all IMPLs in the tier to reach "complete"

**Step 3b.5: Tier Merge**

After all IMPLs in the tier complete, merge their IMPL branches to main:
```bash
sawtools finalize-tier "<manifest-path>" --tier N --repo-dir "<repo-path>"
```
This merges all IMPL branches (created in Step 3a.5) for the tier to main in order, runs `RunTierGate` as a post-merge verification, and is idempotent (already-merged branches are skipped). Each IMPL branch contains the accumulated work from all waves executed against it. If any merge fails, enter BLOCKED before running the quality gate.

**Backward compatibility:** When running outside a program context (standard `/saw wave` flow), MergeTarget is empty and waves merge to HEAD as before. The IMPL branch model only activates during `/saw program execute`.

**Step 3c: Tier Gate (E29)**
- Run: `sawtools tier-gate "<manifest>" --tier N`
- This verifies all IMPLs are complete and runs tier_gates quality gate commands from the PROGRAM manifest
- If gate fails, enter BLOCKED. Surface failure to user.
- If gate passes, proceed to contract freezing.

**Step 3d: Contract Freezing (E30)**
- Run: `sawtools freeze-contracts "<manifest>" --tier N`
- This identifies program contracts whose freeze_at matches tier N
- Verifies contract source files exist and are committed to HEAD
- Marks contracts as frozen in the manifest
- If freezing fails (missing files, uncommitted changes), enter BLOCKED
- If freezing succeeds, all contracts consumed by next tier are locked

**Step 3e: Tier Boundary Review**
- Run: `sawtools program-status "<manifest>"`
- Surface tier completion status to user (tier N complete, contracts frozen)
- If `--auto` flag is active:
  - Call `AdvanceTierAutomatically(manifest, N, repoPath, autoMode=true)` to check gate, freeze contracts, and advance (E33)
  - If gate passed, automatically proceed to next tier (no human review)
  - If gate failed, enter PROGRAM_BLOCKED and surface failure to user (E34)
- If `--auto` flag is NOT active:
  - Pause for human review as normal
  - Human approves to advance to next tier

**Phase 4: Program Completion**

After final tier gate passes:
1. Run: `sawtools mark-program-complete "<manifest>"` (or update state to COMPLETE manually if command not yet available)
2. Update CONTEXT.md with program-level completion data:
   ```bash
   sawtools update-context "<manifest>" --project-root "<repo-path>"
   ```
3. Report final program status to user

**Error handling:**
- If any IMPL enters BLOCKED during tier execution, that IMPL's failure does not cascade to other IMPLs in the same tier (P1).
- If the tier cannot complete because one IMPL is blocked, enter BLOCKED and surface the specific IMPL failure.
- The user may fix the blocked IMPL and resume, or re-plan.

### `/saw program status`

Show program-level progress: tier completion, IMPL statuses, and program contract freeze status.

**Orchestrator flow:**

1. **Discover PROGRAM manifests.** Run:
   ```bash
   sawtools list-programs --dir "<repo-path>/docs"
   ```
   This returns a JSON array of PROGRAM manifest metadata (path, slug, state, title). If no PROGRAM manifests are found, report: "No PROGRAM manifests found. Use `/saw program plan` to create one."

2. **Select target PROGRAM.** If exactly 1 PROGRAM manifest is found, use it automatically. If multiple are found, list them and ask the user to specify which one.

3. **Read PROGRAM manifest.** Load the selected manifest from disk.

4. **Display program status:** Show tier structure (which IMPLs per tier, their status), program contracts (frozen status, consumers), overall progress (tiers/IMPLs/agents/waves complete), and current state.

5. **Blocked state handling.** If the program state is `BLOCKED`, read the IMPL docs for all IMPLs in the current tier and surface any failure reports or blocking issues to the user.

### `/saw program replan --reason "<reason>"`

Re-engage the Planner agent to revise a PROGRAM manifest after a tier gate failure or when the user explicitly requests it. The `--reason` argument is required and provides context for the Planner about why re-planning is needed.

**Orchestrator flow:**

1. Parse existing PROGRAM manifest.

2. Record the replan trigger:
   ```bash
   sawtools program-replan "<manifest-path>" --reason "<reason>"
   ```
   This updates the manifest state to `REPLANNING` and records the reason for audit. If the reason originates from a tier gate failure, include the tier number and gate output in the reason string.

3. Construct revision prompt with failure context:
   - Current PROGRAM manifest content
   - Reason for re-planning (from `--reason` argument)
   - Failed tier number (if applicable)
   - Completion reports from IMPLs in failed tier
   - Any tier gate output that triggered the replan

4. Launch Planner agent with revision prompt:
   - Use Agent tool with `subagent_type: planner` and `run_in_background: true`
   - Pass revision prompt as parameter

5. Wait for Planner completion. Planner produces revised PROGRAM manifest.

6. Validate revised manifest:
   ```bash
   sawtools validate-program "<revised-manifest-path>"
   ```
   If validation fails, send errors back to Planner as correction prompt
   using resume (up to 3 attempts).

7. Present revised PROGRAM manifest for human review:
   - Show what changed (tiers added/removed, contracts revised, IMPLs reordered)
   - Surface the changes summary
   - Ask user to approve revised plan

8. If approved, update manifest state to PROGRAM_REVIEWED and resume execution
   from the failed tier (or next pending tier).

**Non-destructive guarantee:** Re-planning does not discard completed work.
Completed tiers and their IMPLs remain in the manifest with status "complete".
Only pending and failed tiers may be revised.

**Error handling:**
- If Planner fails to produce valid revision after 3 attempts, enter BLOCKED
  and surface validation errors to user
- User may manually edit PROGRAM manifest or abandon re-planning
