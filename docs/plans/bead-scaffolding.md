# Bead Scaffolding

## Overview

Uses native beads constructs (formulas, molecules, epics, swarms) to scaffold the full work hierarchy from confirmed slice definitions. A formula defines the 8-step slice pipeline as a reusable template. Each slice is poured as a molecule from that formula. Cross-slice dependencies are added from the DAG. A swarm coordinates parallel execution.

## Input

The exported YAML from the Slice Planner, which contains:
- Slice definitions (name, type, description)
- Inter-slice dependency DAG (slice A depends on slice B)
- File assignments per slice (for reference in bead descriptions)

## Formula: `mol-slice-pipeline`

A formula defining the 8-step sequential pipeline for one slice. Lives in `.beads/formulas/mol-slice-pipeline.formula.json`.

### Variables
- `{{slice_name}}` — slice identifier (e.g., `camera-list-page`)
- `{{slice_type}}` — vertical or horizontal
- `{{slice_description}}` — short description
- `{{slice_files}}` — comma-separated file references

### Steps (sequential)
1. **Research** — analyze existing code for this slice, understand behavior and edge cases
2. **Plan** — create implementation plan for porting/building this slice
3. **Test Design** — define behavioral test cases (given/when/then) in structured YAML
4. **Test Implement** — translate test cases into Maestro YAML flows
5. **Test Verify** — run flows against existing app, debug until green
6. **Implement** — write the feature code in the new app
7. **Verify** — run Maestro flows against new app, confirm parity
8. **Report** — generate the post-build report with screenshots/video

### Model separation
Steps 3-5 (test steps) and steps 6-7 (code steps) must be assigned to different models/agents. The formula should label these steps with an `agent_pool` tag:
- Steps 3-5: `agent_pool: test-author`
- Steps 6-7: `agent_pool: code-author`
- Steps 1-2, 8: `agent_pool: general` (either model can do these)

## Scaffolding Workflow

### Step 1: Cook the formula
```bash
bd cook mol-slice-pipeline --dry-run
```
Verify the template structure looks correct with placeholders intact.

### Step 2: Pour one molecule per slice
For each slice in the YAML:
```bash
bd mol pour mol-slice-pipeline \
  --var slice_name=camera-list-page \
  --var slice_type=vertical \
  --var slice_description="Camera list with thumbnails" \
  --var slice_files="src/camera/list.kt,src/camera/adapter.kt"
```
This creates an epic with 8 child beads, sequentially dependent.

### Step 3: Add cross-slice dependencies
From the DAG: if slice A depends on slice B, then slice A's **research** step depends on slice B's **report** step. This ensures slice B is fully complete before slice A begins.
```bash
bd dep add <slice-a-research-id> <slice-b-report-id>
```

### Step 4: Create swarm for parallel execution
Group independent slices (no DAG edges between them) for parallel work:
```bash
bd swarm create <parent-epic-id>
```

## Scaffolding Script

A script (`tools/bead-scaffolder/scaffold.py` or `.sh`) that automates steps 2-4:

1. Parse the slice YAML export
2. Topological sort of slices from the DAG (detect cycles, fail if found)
3. Pour a molecule for each slice with variable substitution
4. Capture bead IDs from pour output (molecule root + child step IDs)
5. Add cross-slice deps: for each DAG edge (A depends on B), link A/research → B/report
6. Optionally create swarm for the top-level epic
7. Print summary

### Dry-run mode
```bash
./scaffold.py --dry-run slices.yaml
```
Prints all `bd mol pour` and `bd dep add` commands without executing.

## Bead Naming

Molecules get IDs via `--ref` on pour if supported, otherwise the script maintains a mapping file (`.ralph/state/id-mapping.json`) from `slice-name/step` → bead ID for use by other tools.

## Implementation Checklist

### Phase 1: Formula creation
- [x] Create `.beads/formulas/` directory
- [x] Write `mol-slice-pipeline.formula.json` with 8 steps, variables, and sequential deps
- [x] Tag steps with `agent_pool` labels (test-author, code-author, general)
- [x] `bd cook mol-slice-pipeline --dry-run` — verify template structure
- [x] `bd mol pour mol-slice-pipeline --dry-run --var slice_name=test-slice` — verify instantiation
- [x] Verify: pour one real molecule, confirm 8 child beads with correct sequential deps

### Phase 2: Scaffolding script
- [x] Script that parses slice YAML and pours one molecule per slice
- [x] Capture and store bead ID mapping (slice/step → bead ID)
- [x] Topological sort with cycle detection on the slice DAG
- [x] Add cross-slice deps after all molecules are poured
- [x] Dry-run mode
- [x] Verify: run against sample YAML with 3-4 slices and a simple DAG, confirm structure via `bd graph`

### Phase 3: Idempotency
- [x] Detect already-poured slices (check for existing molecules by name/label)
- [x] Skip already-created molecules, only pour missing ones
- [x] Option to tear down a single slice's molecule for re-scaffolding
- [x] Verify: run twice, confirm no duplicates

### Phase 4: Swarm setup
- [x] Create top-level epic that parents all slice molecules
- [x] Create swarm from that epic for coordinated execution
- [x] Verify: `bd swarm status` shows correct structure

### Phase 5: Summary and validation
- [x] Print creation summary: slices poured, beads total, deps added
- [x] Print critical path through the DAG
- [x] Validate all cross-slice deps are correct via `bd dep tree`
- [x] Export ID mapping file for use by other tools (e2e harness, reporting, loop builder)
- [x] Verify: summary matches `bd stats`

## Out of Scope
- Modifying slice definitions — that's the Slice Planner's job
- Running any slice work — this just creates the tracking structure
- Model assignment decisions — determined by the experimentation plan in the e2e test harness
