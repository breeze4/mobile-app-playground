# Model Assignment Results

Template for recording experiment results and final model assignments.

## Experiment Results

### Run A: Claude (test) / Codex (code)

#### hello-ui

| Step | Metric | Value | Notes |
|------|--------|-------|-------|
| 3 - Test Design | Coverage completeness | | |
| 3 - Test Design | Missed scenarios | | |
| 4 - Test Implement | Syntax correct | | |
| 4 - Test Implement | Flows runnable | | |
| 5 - Test Verify | First-run pass rate | | |
| 5 - Test Verify | Debug iterations | | |
| 5 - Test Verify | Human interventions | | |
| 6 - Implement | Plan adherence | | |
| 6 - Implement | First-run test pass rate | | |
| 7 - Verify | Fix iterations | | |
| 7 - Verify | Final pass rate | | |

#### build-config

| Step | Metric | Value | Notes |
|------|--------|-------|-------|
| 3 - Test Design | Coverage completeness | | |
| 3 - Test Design | Missed scenarios | | |
| 4 - Test Implement | Syntax correct | | |
| 4 - Test Implement | Flows runnable | | |
| 5 - Test Verify | First-run pass rate | | |
| 5 - Test Verify | Debug iterations | | |
| 5 - Test Verify | Human interventions | | |
| 6 - Implement | Plan adherence | | |
| 6 - Implement | First-run test pass rate | | |
| 7 - Verify | Fix iterations | | |
| 7 - Verify | Final pass rate | | |

### Run B: Codex (test) / Claude (code)

#### hello-ui

| Step | Metric | Value | Notes |
|------|--------|-------|-------|
| 3 - Test Design | Coverage completeness | | |
| 3 - Test Design | Missed scenarios | | |
| 4 - Test Implement | Syntax correct | | |
| 4 - Test Implement | Flows runnable | | |
| 5 - Test Verify | First-run pass rate | | |
| 5 - Test Verify | Debug iterations | | |
| 5 - Test Verify | Human interventions | | |
| 6 - Implement | Plan adherence | | |
| 6 - Implement | First-run test pass rate | | |
| 7 - Verify | Fix iterations | | |
| 7 - Verify | Final pass rate | | |

#### build-config

| Step | Metric | Value | Notes |
|------|--------|-------|-------|
| 3 - Test Design | Coverage completeness | | |
| 3 - Test Design | Missed scenarios | | |
| 4 - Test Implement | Syntax correct | | |
| 4 - Test Implement | Flows runnable | | |
| 5 - Test Verify | First-run pass rate | | |
| 5 - Test Verify | Debug iterations | | |
| 5 - Test Verify | Human interventions | | |
| 6 - Implement | Plan adherence | | |
| 6 - Implement | First-run test pass rate | | |
| 7 - Verify | Fix iterations | | |
| 7 - Verify | Final pass rate | | |

## Aggregate Comparison

| Metric | Run A (Claude test / Codex code) | Run B (Codex test / Claude code) |
|--------|----------------------------------|----------------------------------|
| Total human interventions | | |
| Average first-run pass rate | | |
| Average debug iterations | | |
| Slices achieving full parity | | |

## Final Assignment Decision

**Test-author pool (steps 3-5):** _TBD_

**Code-author pool (steps 6-7):** _TBD_

**Rationale:** _TBD_

## Scaffolder Integration

Once assignments are decided, update the bead scaffolder formula to set the `agent_pool` tags:

```bash
# In mol-slice-pipeline.formula.json, set:
#   steps 3-5: agent_pool = "<winning-test-model>"
#   steps 6-7: agent_pool = "<winning-code-model>"
#
# The scaffolder reads these tags when pouring molecules.
# See: tools/bead-scaffolder/ and docs/plans/bead-scaffolding.md
```
