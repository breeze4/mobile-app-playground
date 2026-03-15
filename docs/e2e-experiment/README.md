# E2E Experiment Framework

Framework for evaluating model performance across the 8-step slice pipeline.

## Purpose

The slice pipeline separates test authoring (steps 3-5) from code implementation (steps 6-7) and requires different models for each. This experiment determines which model performs best at each role by running controlled A/B tests on representative slices.

## Contents

- **experiment-matrix.md** — Experiment design: selected slices, evaluation criteria, and decision process
- **model-assignments.md** — Template for recording results and final model assignments
- **pipeline-flow.md** — Full pipeline flow documentation with artifact storage and bead integration

## How to Run the Experiment

1. Select slices (already done: `hello-ui` and `build-config`)
2. For each run configuration (A and B), execute the 8-step pipeline on both slices
3. Record metrics in `model-assignments.md` as each step completes
4. After all runs, compare aggregate results and fill in the final assignment decision
5. Update the bead scaffolder formula with the winning assignments

## Related Files

- `scripts/compare-builds.sh` — Parity comparison script for running Maestro flows against two apps
- `docs/plans/e2e-test-harness.md` — Full E2E test harness plan
- `docs/plans/bead-scaffolding.md` — Bead scaffolder plan (formula and molecule structure)
