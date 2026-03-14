# Slice Planner Tool

## Overview

A local React + Vite web app backed by SQLite for mapping every file/package in an existing mobile app codebase to named slices. Used once per project to ensure 100% code coverage before triggering bead creation for the migration pipeline.

## Context

- The real target is an iOS app migration, but this tooling is built and exercised on Android/Windows first
- An agent generates the initial file-to-slice mapping externally; this tool is for reviewing, adjusting, and confirming those assignments
- The tool has no code-understanding capability — it operates strictly at the file and package level
- Once all files are assigned and confirmed, the tool exports YAML that feeds into a separate bead creation process

## Data Model

### Slice
- `id` (auto-generated)
- `name` (unique, human-readable)
- `type` (vertical | horizontal)
- `description` (short summary)

### Package
- `id` (auto-generated)
- `path` (relative path to package root)
- `name` (display name, derived from path)

### File
- `id` (auto-generated)
- `path` (relative path from project root)
- `package_id` (FK to package)

### FileSliceAssignment
- `file_id` (FK to file)
- `slice_id` (FK to slice)
- `confidence` (0.0–1.0, from agent's initial pass)
- `status` (unreviewed | confirmed | rejected)

Many-to-many: a file can belong to multiple slices, a slice contains files from multiple packages.

## Views

### Package View
- Tree/list of packages, expandable to show files
- Each file shows its slice assignment(s) with confidence badges
- Unassigned files highlighted
- Ability to assign/reassign files to slices from this view

### Slice View
- List of slices (filterable by type: vertical/horizontal)
- Expand a slice to see all contained files, grouped by package
- Ability to remove files from a slice or add new ones

### Coverage Dashboard
- Total files, assigned files, unassigned files, percentage covered
- Filter to show only unassigned files
- Filter to show low-confidence assignments (agent unsure)
- Sort by confidence ascending to review uncertain ones first

## Import / Export

### Import (agent-generated initial pass)
- JSON or YAML format containing:
  - List of slices with name, type, description
  - List of file-to-slice assignments with confidence scores
  - Full file listing from project scan
- Import command indexes all files and packages, creates slices, populates assignments

### Export (confirmed slice definitions)
- YAML output containing:
  - Each slice with name, type, description
  - List of assigned files per slice
  - Coverage summary (any remaining unassigned files flagged)
- This YAML is the input to the bead creation phase

## Tech Stack

- **Frontend**: React + Vite, runs locally
- **Backend**: Local API server (Express or similar lightweight)
- **Database**: SQLite (single file, portable)
- **No deployment**: `localhost` only

## Agent Skills for Initial Mapping

Three sequential skills, each producing inspectable output before proceeding to the next. All skills have full codebase and PRD access at runtime. The skill defines the methodology and expected output format; the agent does the actual analysis.

### Skill 1: `slice-inventory` — Identify packages and modules
- Walks the project file tree and identifies all packages/modules
- Produces a structured inventory: package name, path, file count, brief purpose summary
- Output: YAML file listing every package with its files and a one-line description of what it contains
- **Checkpoint**: User reviews the inventory to confirm package boundaries are correct and nothing is missing before proceeding

### Skill 2: `slice-propose` — Propose slices from PRD
- Takes the PRD as input along with the package inventory from Skill 1
- Analyzes the PRD to identify all features, cross-cutting concerns, and utilities
- Proposes a set of named slices, each with type (vertical/horizontal) and description
- Maps PRD sections/requirements to proposed slices
- Does NOT assign files yet — just defines the slice catalog
- Output: YAML file with slice definitions and PRD traceability
- **Checkpoint**: User reviews proposed slices — adjusts names, merges/splits slices, confirms the catalog is complete before proceeding

### Skill 3: `slice-map` — Map files to slices with confidence
- Takes the confirmed slice catalog (from Skill 2) and the package inventory (from Skill 1)
- Reads file contents to understand purpose and assigns each file to one or more slices
- Assigns a confidence score (0.0–1.0) per assignment based on how clearly the file fits
- Flags files that don't clearly belong to any slice
- Output: YAML file in the import format expected by the Slice Planner UI (slices + file assignments + confidence scores)
- **Checkpoint**: Output is imported into the Slice Planner UI for visual review, low-confidence and unassigned files get human attention

### Skill design principles
- Each skill is a Claude Code skill (`.claude/skills/`) with clear instructions, not code
- Skills define: what to analyze, how to classify, and the exact YAML output schema
- Skills are codebase-agnostic — they work with whatever project they're run in
- Each skill's output is a standalone artifact that can be re-run independently
- The three-step pipeline allows course-correction at each stage rather than one big pass

## Implementation Checklist

### Phase 0: Agent skills for initial mapping
- [ ] Define YAML output schema shared across all three skills (package inventory, slice catalog, file-to-slice mapping)
- [ ] Create `slice-inventory` skill — instructions for identifying all packages/modules and producing the inventory YAML
- [ ] Verify: run `slice-inventory` against this repo's `app/` dir, confirm output is valid YAML with correct file listings
- [ ] Create `slice-propose` skill — instructions for analyzing PRD + inventory to propose slice catalog
- [ ] Verify: run `slice-propose` with a sample PRD and inventory, confirm output contains typed/described slices with PRD references
- [ ] Create `slice-map` skill — instructions for reading files and assigning them to slices with confidence scores
- [ ] Verify: run `slice-map` with sample slice catalog + inventory, confirm output matches the import schema for the Slice Planner UI

### Phase 1: Project scaffold and database
- [ ] Initialize Vite + React + TypeScript project in `tools/slice-planner/`
- [ ] Add Express backend with SQLite (better-sqlite3)
- [ ] Create database schema (slices, packages, files, file_slice_assignments tables)
- [ ] Seed script that scans a project directory and populates packages + files tables
- [ ] Verify: run seed against this repo's `app/` dir, confirm files indexed in SQLite

### Phase 2: Import pipeline
- [ ] Define JSON/YAML import schema for agent-generated mappings
- [ ] Build import endpoint that creates slices and file assignments from import file
- [ ] Handle partial imports (add new assignments without wiping existing confirmed ones)
- [ ] Verify: create a sample import file, run import, query DB to confirm data

### Phase 3: Package View
- [ ] API endpoints: list packages, list files per package, get assignments per file
- [ ] Package tree component with expandable file lists
- [ ] Show slice assignment badges with confidence indicator per file
- [ ] Highlight unassigned files visually (red/yellow)
- [ ] Assign/reassign file to slice via dropdown or search
- [ ] Verify: navigate package view, assign a file to a slice, confirm DB updated

### Phase 4: Slice View
- [ ] API endpoints: list slices (filter by type), list files per slice grouped by package
- [ ] Slice list component with type filter (vertical/horizontal/all)
- [ ] Expand slice to see files grouped by source package
- [ ] Add/remove file from slice
- [ ] Verify: create a slice, add files, view them grouped correctly

### Phase 5: Coverage Dashboard
- [ ] API endpoint: coverage stats (total, assigned, unassigned, percentage)
- [ ] Dashboard component showing coverage bar and stats
- [ ] Unassigned files list with ability to assign from dashboard
- [ ] Low-confidence filter (show assignments below threshold, e.g. < 0.7)
- [ ] Sort by confidence ascending
- [ ] Verify: import partial data, confirm dashboard shows correct uncovered count

### Phase 6: Export
- [ ] Export endpoint that generates YAML from confirmed assignments
- [ ] Include coverage summary and flag any remaining unassigned files
- [ ] Download button in UI
- [ ] Verify: confirm exported YAML round-trips (re-import produces same state)

### Phase 7: Polish and portability
- [ ] Single `npm run dev` starts both frontend and backend
- [ ] README with usage instructions (scan, import, review, export)
- [ ] Confirm the tool is codebase-agnostic (works with any project dir passed as arg)
- [ ] Test portability: point at a different directory structure, verify it indexes correctly

## Out of Scope (for now)
- Code analysis or AST parsing — strictly file/package level
- Bead creation from YAML — separate tool/process
- Multi-user or deployment — local only
- Slice dependency tracking — that comes later in bead phase
