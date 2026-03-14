# Orchestrator Build Plan — Meta

## Build Order

```
slice-planner-tool ──→ bead-scaffolding ──→ e2e-test-harness ──→ reporting ──→ loop-builder
```

## Plans

| # | Plan | Depends On | Status |
|---|------|-----------|--------|
| 1 | [Slice Planner Tool](slice-planner-tool.md) | — | drafted |
| 2 | [Bead Scaffolding](bead-scaffolding.md) | Slice Planner (exports YAML consumed by scaffolder) | drafted |
| 3 | [E2E Test Harness](e2e-test-harness.md) | Bead Scaffolding (test beads define what to test) | drafted |
| 4 | [Reporting](reporting.md) | E2E Test Harness (reports consume test run artifacts) + Slice Planner (adds screens to same app) | drafted |
| 5 | [Loop Builder](loop-builder.md) | All above (Ralph loops work off bead DAG) | drafted |

## Notes

- Each plan can be built and exercised independently on the Android playground project
- The real target (iOS) gets these tools dropped in once proven
- Slice Planner includes read-only DAG visualization (dependency flow between slices)
- Slice visualizer is incorporated into the Slice Planner, not a separate tool
