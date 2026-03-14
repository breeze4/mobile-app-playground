# Batch: Complete Orchestrator Buildout

Work through ALL remaining orchestrator beads (99 tasks across 4 plans: Bead Scaffolding, E2E Test Harness, Reporting, Loop Builder). Work 100% autonomously until every task is closed. Do NOT wait for user input at any point, including Explore gates — handle those yourself with agent-browser screenshots.

## How to work

1. Run `bd ready --type task -n 1` to find the next unblocked task
2. `bd update <id> --status=in_progress`
3. Do the work described in the bead title
4. `git add <files> && git commit -m "descriptive message"` (no AI co-author, no AI mentions)
5. `bd close <id> --reason="what was done"`
6. Repeat from step 1 until `bd ready --type task` returns no orchestrator tasks (ignore beads that don't start with BS/E2E/RPT/LB)

## Explore gates

When you hit an "Explore" bead, use the `agent-browser` skill to open http://localhost:5199, screenshot the relevant view, save to docs/screenshots/, then close the gate. Do NOT wait for the user.

## Reference files

- docs/plans/bead-scaffolding.md — Plan 2
- docs/plans/e2e-test-harness.md — Plan 3
- docs/plans/reporting.md — Plan 4
- docs/plans/loop-builder.md — Plan 5
- docs/plans/slice-planner-tool.md — Slice Planner context (already built at tools/slice-planner/)
- docs/schemas/slice-schemas.md — YAML schemas
- docs/slices/*.yaml — Sample data

## Plan-specific context

### Bead Scaffolding (BS, 24 tasks)

Build a formula (mol-slice-pipeline.formula.json) for the 8-step slice pipeline, a scaffolding script that reads slice YAML and pours molecules, with idempotency, swarm setup, and validation. Uses native beads constructs: `bd cook`, `bd mol pour`, `bd dep add`, `bd swarm create`. The formula goes in `.beads/formulas/`.

### E2E Test Harness (E2E, 19 tasks)

Set up Maestro for e2e testing. Install Maestro CLI, create e2e/ directory structure, write sample flows, create 3 test skills (test-design, test-implement, test-verify), build parity comparison script, run model experiment (document findings, don't actually run Claude vs Codex — just create the framework and document the plan), integrate with bead pipeline.

NOTE: Maestro requires an Android emulator. If Maestro can't run (no emulator available), create all the scripts/skills/structure but mark verification tasks with a note that they need an emulator. Don't block on this.

### Reporting (RPT, 32 tasks)

Add Reports view to the Slice Planner app (tools/slice-planner/). Uses ports 3051 (backend) and 5199 (frontend). Add report data model, API endpoints, Reports list view, individual report pages, video player with interactive trace, screenshots gallery, and report generation skill. Create sample/mock report data for development.

### Loop Builder (LB, 24 tasks)

Build beads-native Ralph loops: scripts/ralph-once.sh (inner loop using bd ready), scripts/ralph.sh (outer loop), multi-model support (.ralph/models.yaml), rich bead descriptions in the formula, safety guardrails (max failures, time limits, summary output).

## Important conventions

- Do NOT add AI co-author lines or mention AI/Claude in commit messages
- Each task = one git commit
- Use `bd close <id> --reason="..."` after each commit
- Scripts go in scripts/, tools in tools/, skills in .claude/skills/
- For Slice Planner UI changes: the app is at tools/slice-planner/, backend port 3051, frontend port 5199
- Run `npm run demo` in tools/slice-planner/ to reset demo data if needed
