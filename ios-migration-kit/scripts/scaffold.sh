#!/usr/bin/env bash
set -euo pipefail

# scaffold.sh - Read specs/_triage.yaml and create beads for each module.
#
# For todo/partial modules: pours mol-migration-module molecule (3 beads)
# For done modules: creates a single spec-extract bead
# Skips manual/unknown modules entirely
#
# Dependency ordering:
#   - All horizontal slices' implement steps must complete before any
#     vertical slice's implement step can start (vertical depends on horizontal)
#   - Spec-extract steps have no cross-module dependencies (all parallel)
#
# Usage: scripts/scaffold.sh [--dry-run] [--triage-file PATH]

TRIAGE_FILE="specs/_triage.yaml"
DRY_RUN=0
FORMULA_DIR=".beads/formulas"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --triage-file)
      TRIAGE_FILE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: scripts/scaffold.sh [--dry-run] [--triage-file PATH]"
      echo ""
      echo "Reads specs/_triage.yaml and creates beads for each module."
      echo "  --dry-run        Print commands without executing"
      echo "  --triage-file    Path to triage YAML (default: specs/_triage.yaml)"
      echo ""
      echo "Horizontal slices are scaffolded first. Vertical slices'"
      echo "implement steps depend on all horizontal implement steps."
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$TRIAGE_FILE" ]]; then
  echo "Error: triage file not found: $TRIAGE_FILE" >&2
  echo "Run the module-triage skill first, or create it manually." >&2
  exit 1
fi

if [[ ! -f "$FORMULA_DIR/mol-migration-module.json" ]]; then
  echo "Error: formula not found: $FORMULA_DIR/mol-migration-module.json" >&2
  echo "Copy formulas/mol-migration-module.json to $FORMULA_DIR/" >&2
  exit 1
fi

echo "=== Scaffold: iOS Migration Beads ==="
echo "Triage file: $TRIAGE_FILE"
echo "Dry run: $DRY_RUN"
echo ""

# Two-pass approach:
#   Pass 1: Create all beads (horizontals first, then verticals)
#   Pass 2: Add cross-slice dependencies (vertical implement depends on horizontal implement)
#
# We capture molecule/bead IDs from bd output to wire dependencies.

COMMANDS=$(TRIAGE_FILE="$TRIAGE_FILE" python3 << 'PYEOF'
import yaml
import os

triage_file = os.environ.get("TRIAGE_FILE", "specs/_triage.yaml")

with open(triage_file) as f:
    data = yaml.safe_load(f)

modules = data.get("modules", [])
project = data.get("project", {})

# Separate by slice type and status
horizontals = []
verticals = []
done_modules = []
skipped = 0

for mod in modules:
    name = mod["name"]
    status = mod.get("status", "unknown")
    slice_type = mod.get("slice", "vertical")

    if status in ("manual", "unknown"):
        print(f"# SKIP ({status}): {name}")
        skipped += 1
        continue

    if status == "done":
        done_modules.append(mod)
        continue

    if status in ("todo", "partial"):
        if slice_type == "horizontal":
            horizontals.append(mod)
        else:
            verticals.append(mod)
        continue

    print(f"# SKIP (unrecognized status '{status}'): {name}")
    skipped += 1

# --- Phase 1: Done modules (spec-extract only, for reference) ---
if done_modules:
    print("# --- Done modules (spec-extract only) ---")
for mod in done_modules:
    name = mod["name"]
    group = mod.get("group", "default")
    slice_type = mod.get("slice", "vertical")
    legacy_files = ",".join(mod.get("legacy_files", []))
    source_files = ",".join(mod.get("source_files", []))
    test_files = ",".join(mod.get("test_files", []))

    desc = (
        f"Study all source and test files for module {name} "
        f"(group: {group}, slice: {slice_type}, status: done). "
        f"Legacy files: {legacy_files}. "
        f"Existing new files: {source_files}. "
        f"Existing tests: {test_files}. "
        f"Use the spec-extract skill. "
        f"Output: specs/{group}/{name}.md"
    )
    title = f"{name}: Spec Extract"
    print(f'bd create --title="{title}" --description="{desc}" --type=task --priority=3 --label agent_pool=general')

# --- Phase 2: Horizontal slices (migrate first) ---
if horizontals:
    print("# --- Horizontal slices (shared infrastructure, migrate first) ---")
for mod in horizontals:
    name = mod["name"]
    group = mod.get("group", "default")
    status = mod.get("status", "todo")
    legacy_files = ",".join(mod.get("legacy_files", []))
    source_files = ",".join(mod.get("source_files", []))
    test_files = ",".join(mod.get("test_files", []))

    print(
        f'bd mol pour mol-migration-module '
        f'--var module_name="{name}" '
        f'--var module_group="{group}" '
        f'--var module_status="{status}" '
        f'--var slice_type="horizontal" '
        f'--var legacy_files="{legacy_files}" '
        f'--var source_files="{source_files}" '
        f'--var test_files="{test_files}"'
    )

# --- Phase 3: Vertical slices ---
if verticals:
    print("# --- Vertical slices (user-facing features) ---")
for mod in verticals:
    name = mod["name"]
    group = mod.get("group", "default")
    status = mod.get("status", "todo")
    legacy_files = ",".join(mod.get("legacy_files", []))
    source_files = ",".join(mod.get("source_files", []))
    test_files = ",".join(mod.get("test_files", []))

    print(
        f'bd mol pour mol-migration-module '
        f'--var module_name="{name}" '
        f'--var module_group="{group}" '
        f'--var module_status="{status}" '
        f'--var slice_type="vertical" '
        f'--var legacy_files="{legacy_files}" '
        f'--var source_files="{source_files}" '
        f'--var test_files="{test_files}"'
    )

# --- Phase 4: Cross-slice dependencies ---
# After all beads are created, wire: each vertical's implement step
# depends on all horizontal implement steps.
if horizontals and verticals:
    print("# --- Cross-slice dependencies ---")
    print("# Vertical implement beads should depend on horizontal implement beads.")
    print("# Run these after all molecules are poured and you have the bead IDs:")
    h_names = [m["name"] for m in horizontals]
    v_names = [m["name"] for m in verticals]
    print(f"# Horizontal implement beads (find IDs): {', '.join(h_names)}")
    print(f"# Vertical implement beads (find IDs): {', '.join(v_names)}")
    print(f'# For each vertical implement bead, run:')
    print(f'#   bd dep add <vertical-implement-bead> <horizontal-implement-bead>')
    print(f'#')
    print(f'# Quick way to find implement bead IDs:')
    print(f'#   bd list --json | python3 -c "import sys,json; [print(b[\'id\'],b[\'title\']) for b in json.load(sys.stdin) if \'Implement\' in b.get(\'title\',\'\')]"')

total = len(done_modules) + len(horizontals) + len(verticals)
print(f"# Summary: {total} created ({len(horizontals)} horizontal, {len(verticals)} vertical, {len(done_modules)} done-spec-only), {skipped} skipped")
PYEOF
)

# Execute or print commands
while IFS= read -r cmd; do
  if [[ "$cmd" == \#* ]]; then
    echo "$cmd"
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] $cmd"
  else
    echo "Running: $cmd"
    eval "$cmd" || echo "WARNING: command failed: $cmd"
  fi
done <<< "$COMMANDS"

echo ""
echo "Done. Run 'bd ready' to see available work."
echo ""
echo "IMPORTANT: If you have both horizontal and vertical slices,"
echo "wire cross-slice dependencies so verticals wait for horizontals."
echo "See the comments above for the bd dep add commands."
