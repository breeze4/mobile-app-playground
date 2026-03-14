# Skill: slice-propose

Propose a set of named slices from a PRD and a package inventory.

## When to use

Use this skill after `slice-inventory` has produced a package inventory. This skill reads a PRD (or spec document) and proposes slices — named groupings that files will later be mapped to.

## Inputs

- **PRD path**: Path to the product requirements document or spec (markdown)
- **Inventory path**: Path to the package inventory YAML (Schema 1, output of `slice-inventory`)

Default paths if not specified:
- PRD: `docs/orchestrator/SPEC.md`
- Inventory: `docs/slices/inventory.yaml`

## Instructions

### 1. Read the PRD

- Read the entire PRD/spec document
- Identify distinct user-facing features (these become **vertical** slices)
- Identify shared infrastructure, utilities, and cross-cutting concerns (these become **horizontal** slices)

### 2. Read the inventory

- Load the package inventory YAML
- Note what packages and files exist — proposed slices should have files that can realistically map to them
- Do not propose slices that would have zero files in the current codebase

### 3. Classify slices

**Vertical slices** (type: `vertical`):
- Represent a user-facing feature or capability
- Examples: authentication, map view, video player, settings screen
- Typically map to a screen, user flow, or feature module

**Horizontal slices** (type: `horizontal`):
- Represent shared infrastructure or cross-cutting concerns
- Examples: networking layer, database, theming, navigation framework, build configuration
- Used by multiple vertical slices

### 4. Name and describe each slice

- Use kebab-case for names (e.g., `video-player`, `build-config`)
- Keep names short but descriptive (2-4 words)
- Write a one-sentence description explaining the slice's scope
- Add PRD references: cite the specific section(s) that justify this slice's existence

### 5. Produce output

Write the catalog to `docs/slices/catalog.yaml` in the following format:

```yaml
version: "1"
kind: slice-catalog
generated_at: "<ISO 8601 timestamp>"
slices:
  - name: "slice-name"
    type: vertical
    description: "Short description"
    prd_references:
      - "Section X.Y: Feature Name"
summary:
  total_slices: <count>
  vertical: <count>
  horizontal: <count>
```

See `docs/schemas/slice-schemas.md` for the full schema reference.

### 6. Validate

After generating the YAML:
- Confirm it parses as valid YAML
- Verify at least one vertical and one horizontal slice exists
- Verify every slice has a name, type, description, and at least one PRD reference
- Verify `summary` counts match the actual slice list
- Verify PRD references point to real sections in the source document
- Verify slice names are unique

## What this skill does NOT do

- No file-to-slice assignment — that is the `slice-map` skill
- No code analysis — slice proposals come from the PRD, cross-referenced with the inventory to ensure they are grounded in actual files
