# Batch Orchestrator Buildout — Parallel Execution Plan

## Context

99 open beads across 4 plans (BS:24, E2E:19, RPT:32, LB:24) need to be implemented. The beads form a single sequential dependency chain (BS → E2E → RPT → LB), but the **code** for each plan touches non-overlapping file areas, making worktree parallelism viable. Workers implement all code for their scope, commit, and create PRs. Bead closing happens separately after merge.

## Research Summary

- **Bead state**: Only 1 bead is ready (BS P1 first task). All others blocked by the sequential chain.
- **File separation**: Each plan writes to distinct directories with minimal overlap.
- **Tech stack**: Slice Planner is React 19 + Vite + Express 5 + SQLite (ports 3051/5199). Skills are markdown instruction files. Scripts are bash.
- **Cross-plan file deps**: E2E P4-P5 modify the scaffolder (BS files). LB P4 modifies the formula (BS files). These create merge ordering constraints but not worktree conflicts if each worker creates the full content independently.

## Work Units (6 units)

### Unit 1: BS — Bead Scaffolding (24 tasks)
**Files**: `.beads/formulas/mol-slice-pipeline.formula.json`, `tools/bead-scaffolder/scaffold.sh` (or `.py`), `tools/bead-scaffolder/id-map.yaml`
**Description**: Create the 8-step slice pipeline formula with variables and agent_pool labels. Build scaffolding script that parses slice YAML, pours molecules, adds cross-slice deps, handles idempotency, creates swarm, prints summary. Include dry-run mode.
**Phases**: P1 (formula), P2 (script), P3 (idempotency), P4 (swarm), P5 (summary/validation)

### Unit 2: E2E-Setup — Maestro + Test Skills (8 tasks, E2E P1+P2)
**Files**: `e2e/flows/`, `e2e/config/`, `e2e/output/`, `.claude/skills/test-design/SKILL.md`, `.claude/skills/test-implement/SKILL.md`, `.claude/skills/test-verify/SKILL.md`
**Description**: Install Maestro CLI (note: no emulator available, create structure but mark verification as needing emulator). Create e2e/ directory with flows/config/output structure. Write one sample flow. Create 3 test skills following existing skill patterns (see .claude/skills/slice-inventory/ for format).
**Phases**: P1 (Maestro setup), P2 (test skills)

### Unit 3: E2E-Advanced — Comparison, Experiment, Integration (11 tasks, E2E P3+P4+P5)
**Files**: `scripts/compare-builds.sh`, `docs/plans/e2e-test-harness.md` (review section), E2E experiment docs
**Description**: Build parity comparison script that runs Maestro flows against two APP_IDs and generates diff report. Create model experiment framework (pick 2 slices, document experiment matrix, document plan for Claude vs Codex comparison). Update scaffolder integration notes. Store test artifacts in standard locations.
**Phases**: P3 (comparison), P4 (experiment framework), P5 (pipeline integration)
**Note**: E2E P4 "Run experiment matrix" — just create the framework and document the plan, don't actually run models. E2E P4+P5 reference the scaffolder from BS — create any scaffolder modifications independently (will merge after BS).

### Unit 4: RPT — Reporting UI (32 tasks, RPT P1-P6)
**Files**: `tools/slice-planner/server/routes/reports.ts`, `tools/slice-planner/server/mock-reports.ts`, `tools/slice-planner/src/components/ReportsView.tsx`, `tools/slice-planner/src/components/ReportPage.tsx`, `tools/slice-planner/src/components/VideoPlayer.tsx`, `tools/slice-planner/src/components/ScreenshotsGallery.tsx`, `tools/slice-planner/src/App.tsx` (add Reports tab), `.claude/skills/slice-report/SKILL.md`
**Description**: Add full Reports view to Slice Planner. P1: Define report.json schema, add API endpoints (list reports, get report, serve artifacts). P2: Reports list view with status filters. P3: Slice report page (header, files, test cases GWT, results table). P4: HTML5 video player with interactive trace (clickable step list, timestamp seeking, offset calibration, step highlighting). P5: Screenshots gallery (grid, expand, old vs new comparison). P6: Create slice-report skill. Create sample/mock report data for development.
**Phases**: P1-P6 (all reporting)

### Unit 5: LB-Core — Ralph Loop Scripts (15 tasks, LB P1+P2+P3)
**Files**: `scripts/ralph-once.sh`, `scripts/ralph.sh`, `.ralph/models.yaml`, `.ralph/logs/` (gitkeep)
**Description**: Build inner loop (ralph-once.sh): query bd ready with filters, pick bead, mark in_progress, read description, construct prompt, invoke claude, close on success/add notes on failure, exit RALPH_DONE if empty. Build outer loop (ralph.sh): accepts --slices/--pool/--iterations, runs inner loop in for-loop with early exit, logs to .ralph/logs/. Add multi-model support: --model flag, pool-to-model mapping in .ralph/models.yaml.
**Phases**: P1 (inner loop), P2 (outer loop), P3 (multi-model)

### Unit 6: LB-Advanced — Rich Descriptions + Safety (9 tasks, LB P4+P5)
**Files**: Updates to formula (`.beads/formulas/mol-slice-pipeline.formula.json`), updates to scaffolder, updates to `scripts/ralph-once.sh` and `scripts/ralph.sh`
**Description**: Update formula to include detailed description templates per step referencing slice variables. Update pour script to populate descriptions from skill outputs. Add safety guardrails: max consecutive failures, bead-level time limit, summary output, bd ready count check before starting.
**Phases**: P4 (rich descriptions), P5 (safety)
**Note**: This unit modifies files created by Units 1 and 5. Merge after those land. Worker should create the files with full content (formula + scripts) as if starting fresh, since it runs in an isolated worktree.

## E2E Test Recipe

### For script-heavy units (BS, E2E-Setup, E2E-Advanced, LB-Core, LB-Advanced):
1. Run `bash -n <script>` to verify no syntax errors
2. If the script has a `--help` flag, run it to verify arg parsing
3. If dry-run mode exists, run `<script> --dry-run` with sample input
4. For skill files: verify they follow the markdown structure of existing skills in `.claude/skills/slice-inventory/SKILL.md`

### For the RPT unit (Slice Planner UI):
1. `cd tools/slice-planner && npm install`
2. `npm run build` — must compile cleanly
3. `npm run lint` — must pass
4. Start dev server: `npm run dev` (background)
5. Use the `agent-browser` skill to open http://localhost:5199
6. Navigate to Reports tab, screenshot the reports list view → save to `docs/screenshots/rpt-reports-list.png`
7. Click into a report (using mock data), screenshot → save to `docs/screenshots/rpt-report-page.png`
8. Verify video player and screenshots gallery render (even if no real video data)

## Worker Instructions Template

Each worker receives:
1. Overall goal (implement orchestrator tooling for the mobile-app-playground project)
2. Their unit's specific task (title, files, description from above)
3. Convention notes:
   - Skills are markdown instruction files (see `.claude/skills/slice-inventory/SKILL.md` for format)
   - Slice Planner: React 19 + Vite + Express 5 + better-sqlite3, ports 3051/5199
   - Scripts go in `scripts/`, tools in `tools/`, skills in `.claude/skills/`
   - Do NOT add AI co-author lines or mention AI/Claude in commit messages
   - For RPT: create mock/sample report data for development (the app needs data to render)
   - For Maestro tasks: no emulator available, create all structure but note verification needs emulator
4. The e2e test recipe from above
5. Standard worker completion instructions (simplify, test, commit, PR)

## Merge Order

Due to cross-unit file dependencies, PRs should merge in this order:
1. Units 1 (BS) and 2 (E2E-Setup) — no dependencies, merge first
2. Units 3 (E2E-Advanced) and 4 (RPT) — E2E-Advanced may touch scaffolder files
3. Unit 5 (LB-Core) — creates ralph scripts
4. Unit 6 (LB-Advanced) — modifies formula and scripts from Units 1 and 5

Units with no file conflicts can merge in parallel. Conflicts (if any) will be in `.beads/formulas/` and `tools/bead-scaffolder/` between Units 1, 3, and 6.

## Post-Merge

After all PRs are merged, close all 99 beads on main using bd close with the relevant bead IDs.
