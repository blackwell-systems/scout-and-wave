# Failure Routing & Integration — On-Demand Reference

Load this file when an agent reports non-complete status (E7a/E19) or after wave finalization succeeds (E25/E26/E35 integration gap detection).

## E7a: Automatic Failure Remediation

When an agent fails with a correctable issue, build structured retry context before re-launching:
```bash
sawtools build-retry-context "<manifest-path>" --agent "<ID>"
```
This classifies the error (import/type/test/build/lint), provides targeted fix suggestions, formats a retry prompt, and surfaces the `failure_type` field from the agent's completion report. Read the `failure_type` from the JSON output to determine the retry path before relaunching. Prepend the `prompt_text` field to the agent's prompt on relaunch.

## E19: Failure Type Routing

The `failure_type` field on any non-complete completion report drives the orchestrator response automatically (applies in all modes, not just --auto):

- `transient` → retry automatically, no human gate, up to 2 retries; after 2 exhausted retries, escalate to user
- `fixable` → read agent notes, apply the fix described in the notes, relaunch once (1 retry max); if retry fails, escalate to user
- `needs_replan` → re-engage Scout with the agent's completion report as additional context; the resulting revised IMPL doc requires human review before re-launching
- `escalate` → surface to human immediately (no automatic retry)
- `timeout` → retry once with a scope-reduction note prepended to the agent prompt; if retry fails, escalate to user
- absent → treat as `escalate` (backward compatibility)

## E19.1: Per-IMPL Reactions Override

If the IMPL doc contains a `reactions:` block, use it to override the E19 defaults above. Each entry maps a failure type to an action and optional max_attempts. Absent entries fall back to E19 defaults. Valid actions: `retry`, `send-fix-prompt`, `pause`, `auto-scout` (treat as `pause` if not implemented). See E19.1 in `protocol/execution-rules.md` for the full schema.

**reactions block (optional):** Write a `reactions:` block based on the pre-mortem risk assessment and codebase context.

Write reactions when:
- `pre_mortem.overall_risk` is `high` → set transient max_attempts: 3
- CI is known to be flaky → increase timeout retries
- Codebase has strict review/merge policies → prefer `pause` over auto-retry
- needs_replan and escalate: always set action: pause

## Correctable vs Non-Correctable Failures

Correctable failures (transient/fixable): (a) isolation failures (wrong directory/branch) - re-launch with explicit repository context including absolute IMPL doc path; (b) missing dependencies - install and re-launch; (c) transient build errors - retry automatically. Non-correctable failures (`needs_replan`, `escalate`) always surface to the user. Track retries per agent; after retry limits are exhausted, escalate to user.

## E8: Same-Wave Interface Failure

If any agent reports `status: blocked` due to an interface contract being unimplementable as specified, the wave does not merge. Mark the wave BLOCKED, revise the affected contracts in the IMPL doc, and re-issue prompts to all agents whose work depends on the changed contract. Use `sawtools update-agent-prompt "<manifest-path>" --agent "<id>" < new-prompt.txt` to update affected agent prompts and `sawtools check-conflicts "<manifest-path>"` to verify no ownership conflicts before re-launching. Agents that completed cleanly against unaffected contracts do not re-run. The wave restarts from WAVE_PENDING with the corrected contracts.

## E20: Stub Scan

Collect the union of all `files_changed` and `files_created` from agent completion reports. Run:
```bash
sawtools scan-stubs <file1> <file2> ...
```
Append the output to the IMPL doc under `## Stub Report — Wave {N}` (after the last agent completion report for this wave). Exit code is always 0 — stub detection is informational. Surface stubs at the review checkpoint.

**E21: Quality gate verification.** Quality gates are run automatically by `finalize-wave` in the next step.

## E25/E26/E35: Integration Gap Detection and Wiring (Post-Merge)

After wave finalization succeeds, run integration validation to detect unconnected exports:
```bash
sawtools validate-integration "<manifest-path>" --wave <N>
```
This scans the merged codebase for exported symbols flagged as `integration_required` or detected via heuristics (e.g., `New*`, `Build*`, `Register*` functions with no callers), and also checks all `wiring:` declarations from the IMPL doc (E35). **Integration completeness audit:** For each declared `wiring:` entry, validate-integration verifies that `symbol` appears as a call expression in `must_be_called_from`. Missing calls are reported as severity: error.

If gaps are found, launch an **Integration Agent** to wire them:

1. Read `agent.integration_model` from `saw.config.json` (same two-level lookup as other models). If empty or missing, inherit the parent model.
2. Launch the integration agent via the Agent tool with `subagent_type: integration-agent` and `run_in_background: true`. Pass the IMPL doc path, wave number, and the integration report JSON as the prompt. Use `[SAW:wave{N}:integrator] wire integration gaps` as the description.
3. After the integration agent completes, verify the build: `go build ./...`. If it fails, surface the error to the user.
4. Read the integration agent's completion report from the IMPL doc (agent ID: `integrator`).

In the web app, this runs automatically after `finalize-wave`. CLI users can also run `sawtools validate-integration` manually and review the integration report before proceeding to the next wave.
