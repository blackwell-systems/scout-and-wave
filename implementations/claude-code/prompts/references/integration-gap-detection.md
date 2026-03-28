# Integration Gap Detection (E25/E26/E35)

**Trigger:** After `sawtools finalize-wave` succeeds.

## 7-Step Workflow

1. Check `finalize-wave` JSON output for `integration_report.valid` field
2. If `valid == false`, integration gaps were detected
3. Read stderr output for gap summary and next-step guidance
4. Run the command shown in stderr (typically: `sawtools run-integration-agent "<manifest-path>" --wave <N>`)
5. Read integration agent's completion report from IMPL doc (agent ID: `integrator`)
6. If completion report shows `status: complete`, proceed to next wave or IMPL completion
7. If `status: blocked` or `status: partial`, apply E19 failure routing (see `references/failure-routing.md`)

## Integration Agent Model Config

Integration agent model is read from `saw.config.json` under `agent.integration_model`. If empty, inherits parent session's model.

## E27 Planned Integration Waves

If the IMPL doc includes a wave with `type: integration`, use `sawtools run-integration-wave` instead of reactive gap detection. Planned integration waves run before gap detection (between steps 3 and 8a).
