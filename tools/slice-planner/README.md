# Slice Planner

Local React + Vite web app backed by SQLite for mapping every file in a codebase to named slices. Used to review, adjust, and confirm file-to-slice assignments before exporting a YAML mapping for downstream tooling.

## Install

```bash
cd tools/slice-planner
npm install
```

## Scan a project

Index all files and packages from a project directory into SQLite:

```bash
npm run seed -- /path/to/project
```

This walks the directory tree, skipping common non-source files (node_modules, build artifacts, images, etc.), and populates the `packages` and `files` tables.

## Generate mock data

After seeding, optionally populate slices and assignments for testing:

```bash
npm run mock
```

## Import a slice mapping

If you have a YAML file matching the `slice-mapping` schema (from the `slice-map` skill or a previous export):

```bash
curl -X POST http://localhost:3001/api/import \
  -H 'Content-Type: application/x-yaml' \
  --data-binary @path/to/slice-mapping.yaml
```

Import is additive: existing confirmed assignments are preserved.

## Run the app

```bash
npm run dev
```

Starts both the Express backend (port 3001) and Vite dev server (port 5173). Open http://localhost:5173.

## Views

- **Packages** -- Browse files by package, view/edit slice assignments per file
- **Slices** -- Browse slices with type filter (vertical/horizontal), expand to see files grouped by package, add/remove files
- **Coverage** -- Dashboard with coverage percentage, stats cards, unassigned file list, low-confidence assignment list
- **Export** -- Preview coverage stats and download the YAML slice mapping

## Export

The Export view generates a YAML file matching the `slice-mapping` schema defined in `docs/schemas/slice-schemas.md`. When confirmed assignments exist, only those are included. Otherwise all assignments are exported. Unassigned files are flagged in the output.

The exported YAML can be re-imported to restore the same state.

## Tech stack

- React 19 + Vite 8 + TypeScript
- Express 5 backend
- SQLite via better-sqlite3
- No deployment -- localhost only
