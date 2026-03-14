#!/usr/bin/env bash
set -euo pipefail

# Bootstrap beads for building the orchestrator tooling itself.
# Creates 145 beads: 136 checklist items + 8 UI exploration gates + 1 project bootstrap
#
# Usage:
#   ./tools/bootstrap-beads.sh [--dry-run]
#
# Requires: bd (beads CLI)

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN MODE ==="
fi

# Helper: create a bead and capture its ID
create_bead() {
  local title="$1"
  local description="$2"
  local type="${3:-task}"
  local priority="${4:-2}"

  if $DRY_RUN; then
    echo "[CREATE] $title"
    echo "  bd-dry-run-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
    return
  fi

  local output
  output=$(bd create --title="$title" --description="$description" --type="$type" --priority="$priority" --json 2>/dev/null)
  echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || {
    # Fallback: extract ID with grep
    echo "$output" | grep -oP '"id":\s*"\K[^"]+'
  }
}

# Helper: add dependency
add_dep() {
  local issue="$1"
  local depends_on="$2"

  if $DRY_RUN; then
    echo "[DEP] $issue depends on $depends_on"
    return
  fi

  bd dep add "$issue" "$depends_on" 2>/dev/null || true
}

echo "=== Creating orchestrator build beads ==="
echo ""

# ============================================================
# TOP-LEVEL EPIC
# ============================================================
echo "--- Top-level epic ---"
TOP_EPIC=$(create_bead \
  "Build Orchestrator Tooling" \
  "Top-level epic for building the mobile app migration orchestrator. Contains 5 sub-plans: Slice Planner, Bead Scaffolding, E2E Test Harness, Reporting, Loop Builder." \
  "epic" "1")
echo "Top epic: $TOP_EPIC"

# ============================================================
# BOOTSTRAP BEAD
# ============================================================
echo ""
echo "--- Bootstrap ---"
BOOTSTRAP=$(create_bead \
  "Bootstrap: Name project and initialize beads" \
  "Choose the beads project name for the orchestrator build. Initialize the beads database. Set up the project structure. This is the first step before any other work begins." \
  "task" "1")
add_dep "$BOOTSTRAP" "$TOP_EPIC" 2>/dev/null || true
echo "Bootstrap: $BOOTSTRAP"

# Track the last bead in the previous plan for cross-plan deps
PREV_PLAN_LAST=""

# ============================================================
# PLAN 1: SLICE PLANNER TOOL
# ============================================================
echo ""
echo "=== Plan 1: Slice Planner Tool ==="

SP_EPIC=$(create_bead \
  "Slice Planner Tool" \
  "React + Vite web app backed by SQLite for mapping every file/package in an existing codebase to named slices. Includes agent skills for initial mapping, package/slice views, coverage dashboard, and export." \
  "epic" "1")
add_dep "$SP_EPIC" "$BOOTSTRAP"

# --- Phase 0: Agent skills for initial mapping ---
echo "  Phase 0: Agent skills"
SP_P0_EPIC=$(create_bead "SP: Phase 0 - Agent Skills for Initial Mapping" "Create the three sequential agent skills that generate the initial file-to-slice mappings." "epic" "2")
add_dep "$SP_P0_EPIC" "$SP_EPIC"

PREV=""
for item in \
  "Define YAML output schema shared across all three skills (package inventory, slice catalog, file-to-slice mapping)" \
  "Create slice-inventory skill - instructions for identifying all packages/modules and producing the inventory YAML" \
  "Verify: run slice-inventory against app/ dir, confirm output is valid YAML with correct file listings" \
  "Create slice-propose skill - instructions for analyzing PRD + inventory to propose slice catalog" \
  "Verify: run slice-propose with a sample PRD and inventory, confirm output contains typed/described slices with PRD references" \
  "Create slice-map skill - instructions for reading files and assigning them to slices with confidence scores" \
  "Verify: run slice-map with sample slice catalog + inventory, confirm output matches the import schema for the Slice Planner UI"; do
  ID=$(create_bead "SP P0: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P0_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P0_LAST="$PREV"

# --- Phase 1: Project scaffold and database ---
echo "  Phase 1: Project scaffold"
SP_P1_EPIC=$(create_bead "SP: Phase 1 - Project Scaffold and Database" "Initialize Vite + React + TypeScript project with Express backend and SQLite." "epic" "2")
add_dep "$SP_P1_EPIC" "$SP_P0_LAST"

PREV=""
for item in \
  "Initialize Vite + React + TypeScript project in tools/slice-planner/" \
  "Add Express backend with SQLite (better-sqlite3)" \
  "Create database schema (slices, packages, files, file_slice_assignments tables)" \
  "Seed script that scans a project directory and populates packages + files tables" \
  "Verify: run seed against app/ dir, confirm files indexed in SQLite"; do
  ID=$(create_bead "SP P1: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P1_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P1_LAST="$PREV"

# --- Phase 2: Import pipeline ---
echo "  Phase 2: Import pipeline"
SP_P2_EPIC=$(create_bead "SP: Phase 2 - Import Pipeline" "Build the import system for agent-generated slice mappings." "epic" "2")
add_dep "$SP_P2_EPIC" "$SP_P1_LAST"

PREV=""
for item in \
  "Define JSON/YAML import schema for agent-generated mappings" \
  "Build import endpoint that creates slices and file assignments from import file" \
  "Handle partial imports (add new assignments without wiping existing confirmed ones)" \
  "Verify: create a sample import file, run import, query DB to confirm data"; do
  ID=$(create_bead "SP P2: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P2_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P2_LAST="$PREV"

# --- Phase 3: Package View ---
echo "  Phase 3: Package View"
SP_P3_EPIC=$(create_bead "SP: Phase 3 - Package View" "Build the package-centric view showing files and their slice assignments." "epic" "2")
add_dep "$SP_P3_EPIC" "$SP_P2_LAST"

PREV=""
for item in \
  "API endpoints: list packages, list files per package, get assignments per file" \
  "Package tree component with expandable file lists" \
  "Show slice assignment badges with confidence indicator per file" \
  "Highlight unassigned files visually (red/yellow)" \
  "Assign/reassign file to slice via dropdown or search" \
  "Verify: navigate package view, assign a file to a slice, confirm DB updated"; do
  ID=$(create_bead "SP P3: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P3_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P3_LAST="$PREV"

# Exploration gate after Package View
SP_P3_GATE=$(create_bead "SP P3: Explore - Review Package View UI" "Manual exploration gate: interact with the Package View, verify file tree rendering, slice assignment UX, and unassigned file highlighting. Check that assignments persist in SQLite." "task" "1")
add_dep "$SP_P3_GATE" "$SP_P3_LAST"
echo "    + Exploration gate"

# --- Phase 4: Slice View ---
echo "  Phase 4: Slice View"
SP_P4_EPIC=$(create_bead "SP: Phase 4 - Slice View" "Build the slice-centric view showing files grouped by package." "epic" "2")
add_dep "$SP_P4_EPIC" "$SP_P3_GATE"

PREV=""
for item in \
  "API endpoints: list slices (filter by type), list files per slice grouped by package" \
  "Slice list component with type filter (vertical/horizontal/all)" \
  "Expand slice to see files grouped by source package" \
  "Add/remove file from slice" \
  "Verify: create a slice, add files, view them grouped correctly"; do
  ID=$(create_bead "SP P4: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P4_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P4_LAST="$PREV"

# Exploration gate after Slice View
SP_P4_GATE=$(create_bead "SP P4: Explore - Review Slice View UI" "Manual exploration gate: interact with the Slice View, verify slice filtering, file grouping by package, and add/remove operations." "task" "1")
add_dep "$SP_P4_GATE" "$SP_P4_LAST"
echo "    + Exploration gate"

# --- Phase 5: Coverage Dashboard ---
echo "  Phase 5: Coverage Dashboard"
SP_P5_EPIC=$(create_bead "SP: Phase 5 - Coverage Dashboard" "Build the coverage tracking dashboard." "epic" "2")
add_dep "$SP_P5_EPIC" "$SP_P4_GATE"

PREV=""
for item in \
  "API endpoint: coverage stats (total, assigned, unassigned, percentage)" \
  "Dashboard component showing coverage bar and stats" \
  "Unassigned files list with ability to assign from dashboard" \
  "Low-confidence filter (show assignments below threshold, e.g. < 0.7)" \
  "Sort by confidence ascending" \
  "Verify: import partial data, confirm dashboard shows correct uncovered count"; do
  ID=$(create_bead "SP P5: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P5_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P5_LAST="$PREV"

# Exploration gate after Coverage Dashboard
SP_P5_GATE=$(create_bead "SP P5: Explore - Review Coverage Dashboard UI" "Manual exploration gate: verify coverage stats accuracy, test low-confidence filtering, confirm unassigned file assignment flow works from dashboard." "task" "1")
add_dep "$SP_P5_GATE" "$SP_P5_LAST"
echo "    + Exploration gate"

# --- Phase 6: Export ---
echo "  Phase 6: Export"
SP_P6_EPIC=$(create_bead "SP: Phase 6 - Export" "Build YAML export of confirmed slice definitions." "epic" "2")
add_dep "$SP_P6_EPIC" "$SP_P5_GATE"

PREV=""
for item in \
  "Export endpoint that generates YAML from confirmed assignments" \
  "Include coverage summary and flag any remaining unassigned files" \
  "Download button in UI" \
  "Verify: confirm exported YAML round-trips (re-import produces same state)"; do
  ID=$(create_bead "SP P6: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P6_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P6_LAST="$PREV"

# Exploration gate after Export
SP_P6_GATE=$(create_bead "SP P6: Explore - Review Export UI and YAML output" "Manual exploration gate: test the download button, review exported YAML format, verify round-trip import produces same state." "task" "1")
add_dep "$SP_P6_GATE" "$SP_P6_LAST"
echo "    + Exploration gate"

# --- Phase 7: Polish and portability ---
echo "  Phase 7: Polish and portability"
SP_P7_EPIC=$(create_bead "SP: Phase 7 - Polish and Portability" "Final polish: single dev command, README, codebase-agnostic verification." "epic" "2")
add_dep "$SP_P7_EPIC" "$SP_P6_GATE"

PREV=""
for item in \
  "Single npm run dev starts both frontend and backend" \
  "README with usage instructions (scan, import, review, export)" \
  "Confirm the tool is codebase-agnostic (works with any project dir passed as arg)" \
  "Test portability: point at a different directory structure, verify it indexes correctly"; do
  ID=$(create_bead "SP P7: $item" "$item" "task" "2")
  add_dep "$ID" "$SP_P7_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
SP_P7_LAST="$PREV"
PREV_PLAN_LAST="$SP_P7_LAST"

# ============================================================
# PLAN 2: BEAD SCAFFOLDING
# ============================================================
echo ""
echo "=== Plan 2: Bead Scaffolding ==="

BS_EPIC=$(create_bead \
  "Bead Scaffolding" \
  "Formula-based scaffolding that creates the full bead hierarchy from confirmed slice YAML. Uses native beads constructs: formulas, molecules, epics, swarms." \
  "epic" "1")
add_dep "$BS_EPIC" "$PREV_PLAN_LAST"

# --- Phase 1: Formula creation ---
echo "  Phase 1: Formula creation"
BS_P1_EPIC=$(create_bead "BS: Phase 1 - Formula Creation" "Create the mol-slice-pipeline formula with 8 steps and variables." "epic" "2")
add_dep "$BS_P1_EPIC" "$BS_EPIC"

PREV=""
for item in \
  "Create .beads/formulas/ directory" \
  "Write mol-slice-pipeline.formula.json with 8 steps, variables, and sequential deps" \
  "Tag steps with agent_pool labels (test-author, code-author, general)" \
  "bd cook mol-slice-pipeline --dry-run - verify template structure" \
  "bd mol pour mol-slice-pipeline --dry-run --var slice_name=test-slice - verify instantiation" \
  "Verify: pour one real molecule, confirm 8 child beads with correct sequential deps"; do
  ID=$(create_bead "BS P1: $item" "$item" "task" "2")
  add_dep "$ID" "$BS_P1_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
BS_P1_LAST="$PREV"

# --- Phase 2: Scaffolding script ---
echo "  Phase 2: Scaffolding script"
BS_P2_EPIC=$(create_bead "BS: Phase 2 - Scaffolding Script" "Script that parses slice YAML and pours molecules with cross-slice deps." "epic" "2")
add_dep "$BS_P2_EPIC" "$BS_P1_LAST"

PREV=""
for item in \
  "Script that parses slice YAML and pours one molecule per slice" \
  "Capture and store bead ID mapping (slice/step to bead ID)" \
  "Topological sort with cycle detection on the slice DAG" \
  "Add cross-slice deps after all molecules are poured" \
  "Dry-run mode" \
  "Verify: run against sample YAML with 3-4 slices and a simple DAG, confirm structure via bd graph"; do
  ID=$(create_bead "BS P2: $item" "$item" "task" "2")
  add_dep "$ID" "$BS_P2_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
BS_P2_LAST="$PREV"

# --- Phase 3: Idempotency ---
echo "  Phase 3: Idempotency"
BS_P3_EPIC=$(create_bead "BS: Phase 3 - Idempotency" "Handle re-runs without creating duplicates." "epic" "2")
add_dep "$BS_P3_EPIC" "$BS_P2_LAST"

PREV=""
for item in \
  "Detect already-poured slices (check for existing molecules by name/label)" \
  "Skip already-created molecules, only pour missing ones" \
  "Option to tear down a single slice molecule for re-scaffolding" \
  "Verify: run twice, confirm no duplicates"; do
  ID=$(create_bead "BS P3: $item" "$item" "task" "2")
  add_dep "$ID" "$BS_P3_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
BS_P3_LAST="$PREV"

# --- Phase 4: Swarm setup ---
echo "  Phase 4: Swarm setup"
BS_P4_EPIC=$(create_bead "BS: Phase 4 - Swarm Setup" "Create top-level epic and swarm for coordinated execution." "epic" "2")
add_dep "$BS_P4_EPIC" "$BS_P3_LAST"

PREV=""
for item in \
  "Create top-level epic that parents all slice molecules" \
  "Create swarm from that epic for coordinated execution" \
  "Verify: bd swarm status shows correct structure"; do
  ID=$(create_bead "BS P4: $item" "$item" "task" "2")
  add_dep "$ID" "$BS_P4_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
BS_P4_LAST="$PREV"

# --- Phase 5: Summary and validation ---
echo "  Phase 5: Summary and validation"
BS_P5_EPIC=$(create_bead "BS: Phase 5 - Summary and Validation" "Summary output and validation of the scaffolded bead structure." "epic" "2")
add_dep "$BS_P5_EPIC" "$BS_P4_LAST"

PREV=""
for item in \
  "Print creation summary: slices poured, beads total, deps added" \
  "Print critical path through the DAG" \
  "Validate all cross-slice deps are correct via bd dep tree" \
  "Export ID mapping file for use by other tools" \
  "Verify: summary matches bd stats"; do
  ID=$(create_bead "BS P5: $item" "$item" "task" "2")
  add_dep "$ID" "$BS_P5_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
BS_P5_LAST="$PREV"
PREV_PLAN_LAST="$BS_P5_LAST"

# ============================================================
# PLAN 3: E2E TEST HARNESS
# ============================================================
echo ""
echo "=== Plan 3: E2E Test Harness ==="

E2E_EPIC=$(create_bead \
  "E2E Test Harness" \
  "Maestro-based e2e testing pipeline. Tests written against existing app, then run against new app for parity verification. Test authoring and code implementation use different models." \
  "epic" "1")
add_dep "$E2E_EPIC" "$PREV_PLAN_LAST"

# --- Phase 1: Maestro setup ---
echo "  Phase 1: Maestro setup"
E2E_P1_EPIC=$(create_bead "E2E: Phase 1 - Maestro Setup" "Install and validate Maestro CLI on the playground app." "epic" "2")
add_dep "$E2E_P1_EPIC" "$E2E_EPIC"

PREV=""
for item in \
  "Install Maestro CLI, verify it runs on the playground Android app via emulator" \
  "Create e2e/ directory structure (flows, config, output)" \
  "Write one manual sample flow against the playground app to validate the setup" \
  "Verify: maestro test and maestro record both work, artifacts land in output dir"; do
  ID=$(create_bead "E2E P1: $item" "$item" "task" "2")
  add_dep "$ID" "$E2E_P1_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
E2E_P1_LAST="$PREV"

# --- Phase 2: Test skills ---
echo "  Phase 2: Test skills"
E2E_P2_EPIC=$(create_bead "E2E: Phase 2 - Test Skills" "Create the three test-related agent skills." "epic" "2")
add_dep "$E2E_P2_EPIC" "$E2E_P1_LAST"

PREV=""
for item in \
  "Create test-design skill with instructions for producing GWT YAML from slice context" \
  "Create test-implement skill with Maestro YAML generation instructions and conventions" \
  "Create test-verify skill with run/debug/retry loop instructions" \
  "Verify: run all three skills manually on one slice of the playground app"; do
  ID=$(create_bead "E2E P2: $item" "$item" "task" "2")
  add_dep "$ID" "$E2E_P2_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
E2E_P2_LAST="$PREV"

# --- Phase 3: Parity comparison ---
echo "  Phase 3: Parity comparison"
E2E_P3_EPIC=$(create_bead "E2E: Phase 3 - Parity Comparison Workflow" "Script that runs same Maestro flows against two app builds and diffs results." "epic" "2")
add_dep "$E2E_P3_EPIC" "$E2E_P2_LAST"

PREV=""
for item in \
  "Script that runs the same Maestro flow suite against two different APP_IDs" \
  "Diff report: which flows pass on old app vs new app, side-by-side" \
  "Verify: intentionally break a feature in the new app, confirm diff report catches it"; do
  ID=$(create_bead "E2E P3: $item" "$item" "task" "2")
  add_dep "$ID" "$E2E_P3_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
E2E_P3_LAST="$PREV"

# --- Phase 4: Model experiment ---
echo "  Phase 4: Model experiment"
E2E_P4_EPIC=$(create_bead "E2E: Phase 4 - Model Experiment" "Run controlled experiment to determine which model handles which pipeline steps." "epic" "2")
add_dep "$E2E_P4_EPIC" "$E2E_P3_LAST"

PREV=""
for item in \
  "Pick 2 slices (1 vertical, 1 horizontal) from the playground app" \
  "Run experiment matrix (Claude vs Codex swapped across test/code steps)" \
  "Document results and assign models to step types" \
  "Update bead scaffolder to tag beads with assigned model/agent type"; do
  ID=$(create_bead "E2E P4: $item" "$item" "task" "2")
  add_dep "$ID" "$E2E_P4_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
E2E_P4_LAST="$PREV"

# --- Phase 5: Integration with bead pipeline ---
echo "  Phase 5: Integration with bead pipeline"
E2E_P5_EPIC=$(create_bead "E2E: Phase 5 - Integration with Bead Pipeline" "Connect e2e test harness to the bead scaffolding pipeline." "epic" "2")
add_dep "$E2E_P5_EPIC" "$E2E_P4_LAST"

PREV=""
for item in \
  "Update bead scaffolder to create 8 steps instead of 6" \
  "Test artifacts (videos, screenshots, results) stored in standard location per slice" \
  "Bead notes updated with test results summary on completion of test-verify and verify steps" \
  "Verify: full pipeline run on one playground slice, all 8 beads created and closeable"; do
  ID=$(create_bead "E2E P5: $item" "$item" "task" "2")
  add_dep "$ID" "$E2E_P5_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
E2E_P5_LAST="$PREV"
PREV_PLAN_LAST="$E2E_P5_LAST"

# ============================================================
# PLAN 4: REPORTING
# ============================================================
echo ""
echo "=== Plan 4: Reporting ==="

RPT_EPIC=$(create_bead \
  "Reporting" \
  "Adds Reports screen to the Slice Planner app. Per-slice reports with test results, video recordings with interactive trace navigation, and screenshots." \
  "epic" "1")
add_dep "$RPT_EPIC" "$PREV_PLAN_LAST"

# --- Phase 1: Report data model and API ---
echo "  Phase 1: Report data model and API"
RPT_P1_EPIC=$(create_bead "RPT: Phase 1 - Report Data Model and API" "Define report schema and add API endpoints to Slice Planner backend." "epic" "2")
add_dep "$RPT_P1_EPIC" "$RPT_EPIC"

PREV=""
for item in \
  "Define report.json schema (slice metadata, test cases, results, artifact paths, step timings)" \
  "Add API endpoints to Slice Planner backend: list reports, get report for slice" \
  "Serve artifact files (videos, screenshots) from the reports directory" \
  "Verify: create a sample report.json manually, confirm API returns it"; do
  ID=$(create_bead "RPT P1: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P1_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P1_LAST="$PREV"

# --- Phase 2: Reports list view ---
echo "  Phase 2: Reports list view"
RPT_P2_EPIC=$(create_bead "RPT: Phase 2 - Reports List View" "Build the reports navigation and slice list with status." "epic" "2")
add_dep "$RPT_P2_EPIC" "$RPT_P1_LAST"

PREV=""
for item in \
  "Add Reports nav item to Slice Planner app" \
  "Slice list with report status (complete, pending, no report)" \
  "Filter by status, slice type" \
  "Verify: navigate to reports view, see slice list with correct statuses"; do
  ID=$(create_bead "RPT P2: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P2_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P2_LAST="$PREV"

# Exploration gate
RPT_P2_GATE=$(create_bead "RPT P2: Explore - Review Reports List View" "Manual exploration gate: verify reports navigation, slice list rendering, status indicators, and filtering." "task" "1")
add_dep "$RPT_P2_GATE" "$RPT_P2_LAST"
echo "    + Exploration gate"

# --- Phase 3: Slice report page ---
echo "  Phase 3: Slice report page"
RPT_P3_EPIC=$(create_bead "RPT: Phase 3 - Slice Report Page" "Build the individual slice report page with all sections." "epic" "2")
add_dep "$RPT_P3_EPIC" "$RPT_P2_GATE"

PREV=""
for item in \
  "Header with slice metadata" \
  "File list section" \
  "Test cases section (GWT formatted)" \
  "Test results table (flow name, old app pass/fail, new app pass/fail)" \
  "Verify: render a complete report page from sample data"; do
  ID=$(create_bead "RPT P3: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P3_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P3_LAST="$PREV"

# Exploration gate
RPT_P3_GATE=$(create_bead "RPT P3: Explore - Review Slice Report Page" "Manual exploration gate: verify report page layout, test cases formatting, results table accuracy." "task" "1")
add_dep "$RPT_P3_GATE" "$RPT_P3_LAST"
echo "    + Exploration gate"

# --- Phase 4: Video player with interactive trace ---
echo "  Phase 4: Video player with trace"
RPT_P4_EPIC=$(create_bead "RPT: Phase 4 - Video Player with Interactive Trace" "Build embedded video player with clickable step-level trace navigation." "epic" "2")
add_dep "$RPT_P4_EPIC" "$RPT_P3_GATE"

PREV=""
for item in \
  "Embedded HTML5 video player component" \
  "Parse Maestro results JSON for step names and timestamps" \
  "Render clickable step list alongside video" \
  "Click step -> seek video to timestamp (with offset calibration)" \
  "Highlight currently playing step based on video playback position" \
  "Verify: play a recorded Maestro test, click through steps, confirm seeking works"; do
  ID=$(create_bead "RPT P4: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P4_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P4_LAST="$PREV"

# Exploration gate
RPT_P4_GATE=$(create_bead "RPT P4: Explore - Review Video Player and Trace" "Manual exploration gate: play test recording, verify step clicking seeks correctly, check offset calibration, test highlight tracking." "task" "1")
add_dep "$RPT_P4_GATE" "$RPT_P4_LAST"
echo "    + Exploration gate"

# --- Phase 5: Screenshots gallery ---
echo "  Phase 5: Screenshots gallery"
RPT_P5_EPIC=$(create_bead "RPT: Phase 5 - Screenshots Gallery" "Build screenshot viewing with side-by-side old/new app comparison." "epic" "2")
add_dep "$RPT_P5_EPIC" "$RPT_P4_GATE"

PREV=""
for item in \
  "Grid/list of screenshots per flow, labeled by step" \
  "Click to expand full-size" \
  "Side-by-side old app vs new app screenshot comparison (same step)" \
  "Verify: view screenshots from a test run, compare old vs new"; do
  ID=$(create_bead "RPT P5: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P5_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P5_LAST="$PREV"

# Exploration gate
RPT_P5_GATE=$(create_bead "RPT P5: Explore - Review Screenshots Gallery" "Manual exploration gate: verify screenshot grid, expand functionality, side-by-side comparison rendering." "task" "1")
add_dep "$RPT_P5_GATE" "$RPT_P5_LAST"
echo "    + Exploration gate"

# --- Phase 6: Report generation skill ---
echo "  Phase 6: Report generation skill"
RPT_P6_EPIC=$(create_bead "RPT: Phase 6 - Report Generation Skill" "Create the slice-report skill that auto-generates reports from test artifacts." "epic" "2")
add_dep "$RPT_P6_EPIC" "$RPT_P5_GATE"

PREV=""
for item in \
  "Create slice-report skill for the report bead step" \
  "Skill collects artifacts from test-verify and verify output dirs" \
  "Generates report.json with all required fields" \
  "Copies/links artifacts into reports/{slice-name}/ structure" \
  "Verify: run skill on a completed slice, confirm report renders in the app"; do
  ID=$(create_bead "RPT P6: $item" "$item" "task" "2")
  add_dep "$ID" "$RPT_P6_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
RPT_P6_LAST="$PREV"
PREV_PLAN_LAST="$RPT_P6_LAST"

# ============================================================
# PLAN 5: LOOP BUILDER
# ============================================================
echo ""
echo "=== Plan 5: Loop Builder ==="

LB_EPIC=$(create_bead \
  "Loop Builder (Ralph for Beads)" \
  "Beads-native Ralph loop. Inner loop queries bd ready, reads bead description as instructions, does the work, closes the bead. Outer loop runs N iterations with slice and agent pool filters." \
  "epic" "1")
add_dep "$LB_EPIC" "$PREV_PLAN_LAST"

# --- Phase 1: Inner loop script ---
echo "  Phase 1: Inner loop script"
LB_P1_EPIC=$(create_bead "LB: Phase 1 - Inner Loop Script" "Build ralph-once.sh that works off bd ready." "epic" "2")
add_dep "$LB_P1_EPIC" "$LB_EPIC"

PREV=""
for item in \
  "ralph-once.sh - queries bd ready, filters by slices and pool" \
  "Picks first matching bead, marks in_progress" \
  "Reads bead description and constructs prompt from template" \
  "Invokes claude with appropriate permission mode and allowed tools" \
  "On exit: closes bead on success, adds failure notes on failure" \
  "Exits with RALPH_DONE if no ready beads in scope" \
  "Verify: run once against a test molecule with a trivial bead, confirm it picks up, works, and closes"; do
  ID=$(create_bead "LB P1: $item" "$item" "task" "2")
  add_dep "$ID" "$LB_P1_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
LB_P1_LAST="$PREV"

# --- Phase 2: Outer loop script ---
echo "  Phase 2: Outer loop script"
LB_P2_EPIC=$(create_bead "LB: Phase 2 - Outer Loop Script" "Build ralph.sh with iteration control and logging." "epic" "2")
add_dep "$LB_P2_EPIC" "$LB_P1_LAST"

PREV=""
for item in \
  "ralph.sh - accepts --slices, --pool, --iterations args" \
  "Runs inner loop in a for loop with early exit on RALPH_DONE" \
  "Logs to .ralph/logs/ralph-<timestamp>.log" \
  "Verify: run with 3 iterations against a molecule with 2 ready beads, confirm it does 2 and exits"; do
  ID=$(create_bead "LB P2: $item" "$item" "task" "2")
  add_dep "$ID" "$LB_P2_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
LB_P2_LAST="$PREV"

# --- Phase 3: Multi-model support ---
echo "  Phase 3: Multi-model support"
LB_P3_EPIC=$(create_bead "LB: Phase 3 - Multi-Model Support" "Pool-to-model mapping so different step types use different AI models." "epic" "2")
add_dep "$LB_P3_EPIC" "$LB_P2_LAST"

PREV=""
for item in \
  "--model flag to select claude vs gemini (or specific model)" \
  "Pool-to-model mapping config file (.ralph/models.yaml)" \
  "Inner loop reads model from config based on bead pool label" \
  "Verify: run with different pools, confirm correct model is invoked"; do
  ID=$(create_bead "LB P3: $item" "$item" "task" "2")
  add_dep "$ID" "$LB_P3_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
LB_P3_LAST="$PREV"

# --- Phase 4: Rich bead descriptions ---
echo "  Phase 4: Rich bead descriptions"
LB_P4_EPIC=$(create_bead "LB: Phase 4 - Rich Bead Descriptions" "Ensure formula populates actionable descriptions for each step type." "epic" "2")
add_dep "$LB_P4_EPIC" "$LB_P3_LAST"

PREV=""
for item in \
  "Update mol-slice-pipeline formula to include detailed description templates per step" \
  "Description templates reference slice variables (name, files, type)" \
  "Pour script populates descriptions from slice planning skill outputs" \
  "Verify: pour a molecule, read bead descriptions, confirm they contain actionable instructions"; do
  ID=$(create_bead "LB P4: $item" "$item" "task" "2")
  add_dep "$ID" "$LB_P4_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
LB_P4_LAST="$PREV"

# --- Phase 5: Safety and observability ---
echo "  Phase 5: Safety and observability"
LB_P5_EPIC=$(create_bead "LB: Phase 5 - Safety and Observability" "Guardrails and summary output for autonomous operation." "epic" "2")
add_dep "$LB_P5_EPIC" "$LB_P4_LAST"

PREV=""
for item in \
  "Max consecutive failures before stopping (avoid burning tokens on a stuck bead)" \
  "Bead-level time limit (kill inner loop if it runs too long on one bead)" \
  "Summary at end of outer loop: beads completed, beads failed, beads remaining in scope" \
  "bd ready count check before starting (warn if scope has 0 ready beads)" \
  "Verify: simulate a failure, confirm loop handles it and continues to next bead"; do
  ID=$(create_bead "LB P5: $item" "$item" "task" "2")
  add_dep "$ID" "$LB_P5_EPIC"
  [[ -n "$PREV" ]] && add_dep "$ID" "$PREV"
  PREV="$ID"
done
LB_P5_LAST="$PREV"

echo ""
echo "=== Done ==="
echo "Top-level epic: $TOP_EPIC"
echo ""
echo "Run 'bd stats' to see totals."
echo "Run 'bd ready' to see what's available to work on."
echo "Run 'bd graph $TOP_EPIC' to visualize the dependency graph."
