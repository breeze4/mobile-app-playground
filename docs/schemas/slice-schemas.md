# Slice YAML Schemas

Three schemas used by the slice planning pipeline. Each file starts with `version` and `kind` headers for validation.

Design principles:
- Natural keys only (path for files/packages, name for slices) — no synthetic IDs
- No `status` field in YAML — all imports start as `unreviewed` (UI-side default)
- Schema 3 is flat and self-contained, mapping directly to the relational model

---

## Schema 1: Package Inventory

Output of the `slice-inventory` skill. Lists every package and its files.

```yaml
version: "1"
kind: package-inventory
project_root: "."
generated_at: "2026-03-13T12:00:00Z"  # ISO 8601 timestamp
packages:
  - path: "relative/path/to/package"
    name: "package-name"
    description: "One-line description of what this package contains"
    files:
      - path: "relative/path/to/file"
summary:
  total_packages: 3
  total_files: 15
```

### Field definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | yes | Schema version, currently `"1"` |
| `kind` | string | yes | Must be `package-inventory` |
| `project_root` | string | yes | Relative path to project root (usually `"."`) |
| `generated_at` | string | yes | ISO 8601 timestamp of generation |
| `packages[].path` | string | yes | Relative path from project root to package directory |
| `packages[].name` | string | yes | Human-readable package name |
| `packages[].description` | string | yes | One-line summary of package purpose |
| `packages[].files[].path` | string | yes | Relative path from project root to file |
| `summary.total_packages` | integer | yes | Count of packages |
| `summary.total_files` | integer | yes | Count of all files across all packages |

---

## Schema 2: Slice Catalog

Output of the `slice-propose` skill. Defines slices without file assignments.

```yaml
version: "1"
kind: slice-catalog
generated_at: "2026-03-13T12:00:00Z"
slices:
  - name: "slice-name"
    type: vertical  # vertical | horizontal
    description: "Short description of what this slice covers"
    prd_references:
      - "Section X.Y: Feature Name"
summary:
  total_slices: 5
  vertical: 3
  horizontal: 2
```

### Field definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | yes | Schema version, currently `"1"` |
| `kind` | string | yes | Must be `slice-catalog` |
| `generated_at` | string | yes | ISO 8601 timestamp of generation |
| `slices[].name` | string | yes | Unique, human-readable slice name (kebab-case) |
| `slices[].type` | string | yes | `vertical` (user-facing feature) or `horizontal` (shared infrastructure) |
| `slices[].description` | string | yes | Short description of the slice's scope |
| `slices[].prd_references` | list of strings | yes | References to PRD sections that justify this slice |
| `summary.total_slices` | integer | yes | Total count of slices |
| `summary.vertical` | integer | yes | Count of vertical slices |
| `summary.horizontal` | integer | yes | Count of horizontal slices |

---

## Schema 3: File-to-Slice Mapping

Output of the `slice-map` skill and the import format for the Slice Planner UI. Self-contained: includes slice definitions, package list, and all file assignments.

```yaml
version: "1"
kind: slice-mapping
generated_at: "2026-03-13T12:00:00Z"
slices:
  - name: "slice-name"
    type: vertical  # vertical | horizontal
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
  total_files: 15
  assigned_files: 13
  unassigned_files: 2
  coverage_percent: 86.7
  low_confidence_count: 3
```

### Field definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | yes | Schema version, currently `"1"` |
| `kind` | string | yes | Must be `slice-mapping` |
| `generated_at` | string | yes | ISO 8601 timestamp of generation |
| `slices[]` | list | yes | Full slice definitions (same as Schema 2 minus `prd_references`) |
| `slices[].name` | string | yes | Unique slice name |
| `slices[].type` | string | yes | `vertical` or `horizontal` |
| `slices[].description` | string | yes | Short description |
| `packages[]` | list | yes | Full package list (same paths as Schema 1) |
| `packages[].path` | string | yes | Relative path to package directory |
| `packages[].name` | string | yes | Human-readable package name |
| `files[]` | list | yes | Files with at least one slice assignment |
| `files[].path` | string | yes | Relative path to file |
| `files[].package` | string | yes | Path of the containing package (matches `packages[].path`) |
| `files[].assignments[]` | list | yes | One or more slice assignments |
| `files[].assignments[].slice` | string | yes | Slice name (matches `slices[].name`) |
| `files[].assignments[].confidence` | float | yes | 0.0-1.0 confidence score |
| `unassigned[]` | list | yes | Files that couldn't be assigned to any slice (may be empty) |
| `unassigned[].path` | string | yes | Relative path to file |
| `unassigned[].package` | string | yes | Path of the containing package |
| `unassigned[].reason` | string | yes | Explanation of why no slice fits |
| `summary.total_files` | integer | yes | Total file count (`assigned_files + unassigned_files`) |
| `summary.assigned_files` | integer | yes | Files with at least one assignment |
| `summary.unassigned_files` | integer | yes | Files with no assignment |
| `summary.coverage_percent` | float | yes | `(assigned_files / total_files) * 100` |
| `summary.low_confidence_count` | integer | yes | Count of assignments with confidence < 0.7 |

### Confidence score guidelines

| Range | Meaning | Example |
|-------|---------|---------|
| 0.9 - 1.0 | Obvious match | File named `LoginScreen.kt` -> `auth` slice |
| 0.7 - 0.89 | Reasonable match | Utility used primarily by one feature |
| 0.5 - 0.69 | Uncertain | File serves multiple features |
| 0.3 - 0.49 | Weak | Tangential relationship |
| < 0.3 | Too weak to assign | File goes in `unassigned` instead |
