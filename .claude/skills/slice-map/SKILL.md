# Skill: slice-map

Map every file in a project to one or more slices with confidence scores.

## When to use

Use this skill after `slice-propose` has produced a slice catalog. This skill reads file contents and assigns each file to slices, producing a self-contained mapping YAML that can be imported into the Slice Planner UI.

## Inputs

- **Catalog path**: Path to the slice catalog YAML (Schema 2, output of `slice-propose`)
- **Inventory path**: Path to the package inventory YAML (Schema 1, output of `slice-inventory`)

Default paths if not specified:
- Catalog: `docs/slices/catalog.yaml`
- Inventory: `docs/slices/inventory.yaml`

## Instructions

### 1. Load inputs

- Parse the slice catalog to get the list of slices (name, type, description)
- Parse the package inventory to get the list of packages and files
- Verify both files are valid YAML matching their respective schemas

### 2. Analyze each file

For each file in the inventory:
- Read the file contents (or for large files, the first 100 lines plus imports/declarations)
- Consider the file name, directory location, imports, and purpose
- Determine which slice(s) the file belongs to

Use these signals for assignment:
- **File name and path**: Often the strongest signal (e.g., `LoginScreen.kt` -> auth slice)
- **Package location**: Files in the same package often belong to the same slice
- **Imports and dependencies**: What a file imports reveals its purpose
- **File contents**: Class names, function signatures, comments indicating purpose
- **Build files**: Assign to the build/config horizontal slice

### 3. Assign confidence scores

Each assignment gets a confidence score from 0.0 to 1.0:

| Range | Meaning | When to use |
|-------|---------|-------------|
| 0.9 - 1.0 | Obvious | File name/path clearly indicates the slice |
| 0.7 - 0.89 | Reasonable | File primarily serves one slice but has some ambiguity |
| 0.5 - 0.69 | Uncertain | File could belong to multiple slices |
| 0.3 - 0.49 | Weak | Tangential relationship to the slice |

A file may have multiple assignments if it serves multiple slices (e.g., a shared utility used by two features). Each assignment has its own confidence score.

### 4. Handle unassignable files

Files where the best confidence for any slice is below 0.3 go in the `unassigned` list. Provide a `reason` explaining why:
- "Generic utility with no clear slice affinity"
- "Configuration file not specific to any feature"
- "Test infrastructure shared across all slices"

### 5. Produce output

Write the mapping to `docs/slices/mapping.yaml` in the following format. The output must be **self-contained** — it includes the full slice definitions and package list so the UI can import it without needing the other files.

```yaml
version: "1"
kind: slice-mapping
generated_at: "<ISO 8601 timestamp>"
slices:
  - name: "slice-name"
    type: vertical
    description: "Short description"
packages:
  - path: "relative/path"
    name: "package-name"
files:
  - path: "relative/path/to/file"
    package: "relative/path/to/package"
    assignments:
      - slice: "slice-name"
        confidence: 0.85
unassigned:
  - path: "relative/path/to/file"
    package: "relative/path/to/package"
    reason: "Why no slice fits"
summary:
  total_files: <count>
  assigned_files: <count>
  unassigned_files: <count>
  coverage_percent: <float>
  low_confidence_count: <count of assignments with confidence < 0.7>
```

See `docs/schemas/slice-schemas.md` for the full schema reference.

### 6. Validate

After generating the YAML:
- Confirm it parses as valid YAML
- Verify every file from the inventory appears in either `files` or `unassigned`
- Verify no file appears in both `files` and `unassigned`
- Verify all confidence scores are floats between 0.0 and 1.0
- Verify all slice names in assignments match names in the `slices` list
- Verify all package paths in files match paths in the `packages` list
- Verify `summary.total_files` equals `assigned_files + unassigned_files`
- Verify `summary.coverage_percent` equals `(assigned_files / total_files) * 100`
- Verify `summary.low_confidence_count` matches the actual count of assignments with confidence < 0.7

## What this skill does NOT do

- No slice creation — slices come from the catalog input
- No package discovery — packages come from the inventory input
- No status assignment — all imports enter the UI as `unreviewed`
