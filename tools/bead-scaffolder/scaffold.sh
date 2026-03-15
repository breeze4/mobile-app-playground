#!/usr/bin/env bash
set -euo pipefail

# scaffold.sh - Pour molecules from slice YAML using the mol-slice-pipeline formula.
#
# Parses slice catalog and mapping YAML, pours one molecule per slice,
# adds cross-slice dependencies, creates a top-level epic and swarm.
#
# Requires: bd (beads CLI), python3, yq or python3 yaml parser
#
# Usage:
#   tools/bead-scaffolder/scaffold.sh [OPTIONS]
#
# Options:
#   --catalog FILE      Path to slice catalog YAML (required)
#   --mapping FILE      Path to file-to-slice mapping YAML (required)
#   --formula NAME      Formula name (default: mol-slice-pipeline)
#   --dry-run           Print commands without executing
#   --id-map FILE       Output file for bead ID mapping (default: .ralph/state/id-mapping.json)
#   --help              Show this help message

CATALOG=""
MAPPING=""
FORMULA="mol-slice-pipeline"
DRY_RUN=false
ID_MAP=".ralph/state/id-mapping.json"

usage() {
  cat <<'USAGE'
scaffold.sh - Pour molecules from slice YAML using the mol-slice-pipeline formula.

Usage:
  tools/bead-scaffolder/scaffold.sh [OPTIONS]

Options:
  --catalog FILE      Path to slice catalog YAML (required)
  --mapping FILE      Path to file-to-slice mapping YAML (required)
  --formula NAME      Formula name (default: mol-slice-pipeline)
  --dry-run           Print commands without executing
  --id-map FILE       Output file for bead ID mapping (default: .ralph/state/id-mapping.json)
  --help              Show this help message

The catalog YAML should have a list of slices with fields:
  name, type, description, depends_on (list of slice names)

The mapping YAML should map slice names to lists of file paths.

Example:
  tools/bead-scaffolder/scaffold.sh \
    --catalog docs/slices/catalog.yaml \
    --mapping docs/slices/mapping.yaml \
    --dry-run
USAGE
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog)
      CATALOG="$2"
      shift 2
      ;;
    --mapping)
      MAPPING="$2"
      shift 2
      ;;
    --formula)
      FORMULA="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --id-map)
      ID_MAP="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CATALOG" || -z "$MAPPING" ]]; then
  echo "Error: --catalog and --mapping are required." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$CATALOG" ]]; then
  echo "Error: catalog file not found: $CATALOG" >&2
  exit 1
fi

if [[ ! -f "$MAPPING" ]]; then
  echo "Error: mapping file not found: $MAPPING" >&2
  exit 1
fi

# --- Parse YAML with python3 ---
# Outputs JSON arrays for slices and mapping that we can process with python3.
parse_slices_json() {
  python3 -c "
import yaml, json, sys

with open('$CATALOG') as f:
    catalog = yaml.safe_load(f)

with open('$MAPPING') as f:
    mapping = yaml.safe_load(f)

slices = catalog.get('slices', catalog if isinstance(catalog, list) else [])
file_map = mapping.get('mapping', mapping if isinstance(mapping, dict) else {})

result = []
for s in slices:
    name = s['name']
    files = file_map.get(name, [])
    result.append({
        'name': name,
        'type': s.get('type', 'vertical'),
        'description': s.get('description', ''),
        'depends_on': s.get('depends_on', []),
        'files': files if isinstance(files, list) else [files]
    })

json.dump(result, sys.stdout)
"
}

# --- Topological sort with cycle detection ---
topo_sort() {
  local slices_json="$1"
  python3 -c "
import json, sys

slices = json.loads('''$slices_json''')
name_to_idx = {s['name']: i for i, s in enumerate(slices)}

# Build adjacency: depends_on means edge from dep -> slice
in_degree = {s['name']: 0 for s in slices}
adj = {s['name']: [] for s in slices}

for s in slices:
    for dep in s.get('depends_on', []):
        if dep in name_to_idx:
            adj[dep].append(s['name'])
            in_degree[s['name']] += 1

# Kahn's algorithm
queue = [n for n in in_degree if in_degree[n] == 0]
order = []
while queue:
    queue.sort()
    node = queue.pop(0)
    order.append(node)
    for neighbor in adj[node]:
        in_degree[neighbor] -= 1
        if in_degree[neighbor] == 0:
            queue.append(neighbor)

if len(order) != len(slices):
    visited = set(order)
    cycle_nodes = [s['name'] for s in slices if s['name'] not in visited]
    print('CYCLE_ERROR:' + ','.join(cycle_nodes), file=sys.stderr)
    sys.exit(1)

print(json.dumps(order))
"
}

# --- Helpers ---
run_cmd() {
  if $DRY_RUN; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

bd_create_json() {
  if $DRY_RUN; then
    local title=""
    for arg in "$@"; do
      case "$arg" in
        --title=*) title="${arg#--title=}" ;;
      esac
    done
    echo "[DRY-RUN] bd create $*"
    echo "dry-run-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | head -c 40)"
    return
  fi

  local output
  output=$(bd create "$@" --json 2>/dev/null)
  echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || {
    echo "$output" | grep -oP '"id":\s*"\K[^"]+' || echo "unknown"
  }
}

check_existing_molecule() {
  local name="$1"
  if $DRY_RUN; then
    echo ""
    return
  fi
  # Check if a molecule with this title already exists
  local existing
  existing=$(bd list --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
issues = data if isinstance(data, list) else data.get('issues', [])
for i in issues:
    if i.get('title', '') == '$name' and i.get('type', '') == 'molecule':
        print(i['id'])
        break
" 2>/dev/null || echo "")
  echo "$existing"
}

# --- Main logic ---
echo "=== Bead Scaffolder ==="
echo "Catalog: $CATALOG"
echo "Mapping: $MAPPING"
echo "Formula: $FORMULA"
$DRY_RUN && echo "Mode: DRY RUN"
echo ""

# Parse slices
SLICES_JSON=$(parse_slices_json)
SLICE_COUNT=$(echo "$SLICES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "Found $SLICE_COUNT slices"

# Topological sort
echo "Running topological sort..."
SORTED_ORDER=$(topo_sort "$SLICES_JSON")
echo "Sort order: $SORTED_ORDER"
echo ""

# Create top-level epic
echo "--- Creating top-level epic ---"
TOP_EPIC=$(bd_create_json \
  --title="Slice Migration Pipeline" \
  --description="Top-level epic for all slice migration molecules." \
  --type="epic" \
  --priority=1)
echo "Top epic: $TOP_EPIC"

# Counters
BEADS_TOTAL=0
DEPS_ADDED=0
SLICES_POURED=0
SKIPPED=0

# ID mapping: slice_name -> { mol_id, step_ids: { step_name: id } }
declare -A MOL_IDS

# Pour molecules in topological order
echo ""
echo "--- Pouring molecules ---"

SORTED_NAMES=$(echo "$SORTED_ORDER" | python3 -c "import sys,json; [print(n) for n in json.load(sys.stdin)]")

while IFS= read -r slice_name; do
  [[ -z "$slice_name" ]] && continue

  echo ""
  echo "Processing slice: $slice_name"

  # Check idempotency
  existing=$(check_existing_molecule "mol-$slice_name")
  if [[ -n "$existing" ]]; then
    echo "  SKIP: molecule already exists ($existing)"
    MOL_IDS["$slice_name"]="$existing"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Get slice data
  SLICE_DATA=$(echo "$SLICES_JSON" | python3 -c "
import sys, json
slices = json.load(sys.stdin)
for s in slices:
    if s['name'] == '$slice_name':
        json.dump(s, sys.stdout)
        break
")

  SLICE_TYPE=$(echo "$SLICE_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['type'])")
  SLICE_DESC=$(echo "$SLICE_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['description'])")
  SLICE_FILES=$(echo "$SLICE_DATA" | python3 -c "import sys,json; print(', '.join(json.load(sys.stdin)['files']))")

  # Pour molecule with variable substitution
  if $DRY_RUN; then
    echo "  [DRY-RUN] bd mol pour $FORMULA \\"
    echo "    --var slice_name=$slice_name \\"
    echo "    --var slice_type=$SLICE_TYPE \\"
    echo "    --var slice_files=$SLICE_FILES \\"
    echo "    --var slice_description=$SLICE_DESC"
    MOL_IDS["$slice_name"]="dry-run-mol-$slice_name"
    BEADS_TOTAL=$((BEADS_TOTAL + 8))
  else
    MOL_OUTPUT=$(bd mol pour "$FORMULA" \
      --var "slice_name=$slice_name" \
      --var "slice_type=$SLICE_TYPE" \
      --var "slice_files=$SLICE_FILES" \
      --var "slice_description=$SLICE_DESC" \
      --json 2>/dev/null || echo "{}")

    MOL_ID=$(echo "$MOL_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id', 'unknown'))" 2>/dev/null || echo "unknown")
    MOL_IDS["$slice_name"]="$MOL_ID"
    echo "  Molecule: $MOL_ID"

    # Count child beads
    CHILD_COUNT=$(echo "$MOL_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('children', [])))" 2>/dev/null || echo "8")
    BEADS_TOTAL=$((BEADS_TOTAL + CHILD_COUNT))
  fi

  # Add dependency on top epic
  run_cmd bd dep add "${MOL_IDS[$slice_name]}" "$TOP_EPIC" 2>/dev/null || true
  DEPS_ADDED=$((DEPS_ADDED + 1))

  SLICES_POURED=$((SLICES_POURED + 1))

done <<< "$SORTED_NAMES"

# Add cross-slice dependencies
echo ""
echo "--- Adding cross-slice dependencies ---"

while IFS= read -r slice_name; do
  [[ -z "$slice_name" ]] && continue

  SLICE_DEPS=$(echo "$SLICES_JSON" | python3 -c "
import sys, json
slices = json.load(sys.stdin)
for s in slices:
    if s['name'] == '$slice_name':
        for d in s.get('depends_on', []):
            print(d)
        break
")

  while IFS= read -r dep_name; do
    [[ -z "$dep_name" ]] && continue

    if [[ -n "${MOL_IDS[$dep_name]:-}" && -n "${MOL_IDS[$slice_name]:-}" ]]; then
      echo "  $slice_name depends on $dep_name"
      run_cmd bd dep add "${MOL_IDS[$slice_name]}" "${MOL_IDS[$dep_name]}" 2>/dev/null || true
      DEPS_ADDED=$((DEPS_ADDED + 1))
    else
      echo "  WARNING: cannot add dep $slice_name -> $dep_name (missing molecule ID)"
    fi
  done <<< "$SLICE_DEPS"

done <<< "$SORTED_NAMES"

# Create swarm
echo ""
echo "--- Creating swarm ---"
if $DRY_RUN; then
  echo "[DRY-RUN] bd swarm create --epic=$TOP_EPIC"
  SWARM_ID="dry-run-swarm"
else
  SWARM_ID=$(bd swarm create --epic="$TOP_EPIC" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('id', 'unknown'))" 2>/dev/null || echo "unknown")
fi
echo "Swarm: $SWARM_ID"

# Export ID mapping
echo ""
echo "--- Exporting ID mapping ---"
mkdir -p "$(dirname "$ID_MAP")"
python3 -c "
import json, sys

mapping = {}
mol_ids_raw = '''$(for k in "${!MOL_IDS[@]}"; do echo "$k=${MOL_IDS[$k]}"; done)'''

for line in mol_ids_raw.strip().split('\n'):
    if '=' in line:
        name, mid = line.split('=', 1)
        mapping[name.strip()] = {'molecule_id': mid.strip()}

result = {
    'top_epic': '$TOP_EPIC',
    'swarm': '$SWARM_ID',
    'molecules': mapping
}

with open('$ID_MAP', 'w') as f:
    json.dump(result, f, indent=2)

print(json.dumps(result, indent=2))
"
echo "ID mapping written to: $ID_MAP"

# Compute critical path (longest path through the DAG)
echo ""
echo "--- Critical path ---"
python3 -c "
import json

slices = json.loads('''$SLICES_JSON''')
order = json.loads('''$SORTED_ORDER''')
name_to_slice = {s['name']: s for s in slices}

# Each molecule has 8 steps, so weight = 8
STEPS_PER_SLICE = 8

# Longest path via dynamic programming
dist = {n: STEPS_PER_SLICE for n in order}
pred = {n: None for n in order}

for n in order:
    for dep in name_to_slice[n].get('depends_on', []):
        if dep in dist and dist[dep] + STEPS_PER_SLICE > dist[n]:
            dist[n] = dist[dep] + STEPS_PER_SLICE
            pred[n] = dep

# Find the end of the longest path
end = max(dist, key=dist.get)
path = []
node = end
while node is not None:
    path.append(node)
    node = pred[node]
path.reverse()

print('Critical path (%d steps): %s' % (dist[end], ' -> '.join(path)))
"

# Summary
echo ""
echo "=== Summary ==="
echo "Slices poured:  $SLICES_POURED"
echo "Slices skipped: $SKIPPED"
echo "Beads total:    $BEADS_TOTAL"
echo "Deps added:     $DEPS_ADDED"
echo "Top epic:       $TOP_EPIC"
echo "Swarm:          $SWARM_ID"
echo "ID mapping:     $ID_MAP"
