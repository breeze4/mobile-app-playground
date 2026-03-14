#!/usr/bin/env bash
set -euo pipefail

# Bead Scaffolder: Pour slice pipeline molecules from slice catalog YAML
# Usage: scaffold.sh [--dry-run] [--teardown <slice-name>] [--id-map <path>] <catalog.yaml> [mapping.yaml]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_NAME="mol-slice-pipeline"

# Defaults
DRY_RUN=false
TEARDOWN_SLICE=""
ID_MAP_FILE=""
CATALOG_FILE=""
MAPPING_FILE=""
EPIC_TITLE="Slice Pipeline"
deps_tmpfile=""
trap 'rm -f "${deps_tmpfile:-}"' EXIT

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
    cat <<'USAGE'
Usage: scaffold.sh [OPTIONS] <catalog.yaml> [mapping.yaml]

Pour bead molecules for each slice defined in a slice catalog YAML file.

Arguments:
  catalog.yaml    Slice catalog file (kind: slice-catalog, Schema 2)
  mapping.yaml    Optional file-to-slice mapping (kind: slice-mapping, Schema 3)

Options:
  --dry-run                Print commands without executing
  --teardown <slice>       Tear down molecule for a single slice, then exit
  --id-map <path>          Path for the ID mapping output (default: tools/bead-scaffolder/id-map.yaml)
  -h, --help               Show this help

Environment:
  BD_ACTOR                 Actor name passed to bd commands
USAGE
    exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ":: $*"; }
warn() { echo "WARN: $*" >&2; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# Run a bd command, or print it in dry-run mode. Captures stdout into $REPLY.
bd_run() {
    if $DRY_RUN; then
        echo "[dry-run] bd $*"
        REPLY=""
    else
        REPLY="$(bd "$@")"
    fi
}

# ── YAML parsing (minimal, no external deps beyond python3) ──────────────────

# Extract slice names from catalog YAML. Outputs one name per line.
parse_slice_names() {
    python3 -c "
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert doc.get('kind') in ('slice-catalog', 'slice-mapping'), \
    f\"Expected kind slice-catalog or slice-mapping, got {doc.get('kind')}\"
for s in doc.get('slices', []):
    print(s['name'])
" "$1"
}

# Extract slice metadata as tab-separated: name\ttype\tdescription
parse_slices() {
    python3 -c "
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for s in doc.get('slices', []):
    print(s['name'] + '\t' + s.get('type','') + '\t' + s.get('description',''))
" "$1"
}

# Extract dependencies from catalog. Output: dependent_name\tblocking_name
# The catalog schema does not have a dependencies field by default,
# but we support it as an optional extension: slices[].dependencies[]
parse_dependencies() {
    python3 -c "
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for s in doc.get('slices', []):
    for dep in s.get('dependencies', []):
        print(s['name'] + '\t' + dep)
" "$1"
}

# Extract files assigned to a slice from the mapping YAML.
# Output: comma-separated file paths
parse_slice_files() {
    local mapping_file="$1" slice_name="$2"
    python3 -c "
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
target = sys.argv[2]
paths = []
for f in doc.get('files', []):
    for a in f.get('assignments', []):
        if a['slice'] == target:
            paths.append(f['path'])
            break
print(','.join(paths))
" "$mapping_file" "$slice_name"
}

# ── Topological sort with cycle detection ────────────────────────────────────

# Input: lines of "dependent\tblocking" pairs on stdin
# Plus all node names as arguments (to include nodes with no edges)
# Output: sorted node names, one per line
# Exits 1 if a cycle is detected
topo_sort() {
    python3 -c "
import sys

nodes = set(sys.argv[1:])
edges = []  # (dependent, blocking) meaning blocking must come before dependent
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('\t')
    if len(parts) != 2:
        continue
    dependent, blocking = parts
    edges.append((dependent, blocking))
    nodes.add(dependent)
    nodes.add(blocking)

# Build adjacency: for topo sort, blocking -> dependent
adj = {n: [] for n in nodes}
in_degree = {n: 0 for n in nodes}
for dependent, blocking in edges:
    adj[blocking].append(dependent)
    in_degree[dependent] += 1

# Kahn's algorithm
queue = sorted([n for n in nodes if in_degree[n] == 0])
result = []
while queue:
    n = queue.pop(0)
    result.append(n)
    for m in sorted(adj[n]):
        in_degree[m] -= 1
        if in_degree[m] == 0:
            queue.append(m)

if len(result) != len(nodes):
    remaining = nodes - set(result)
    print(f'CYCLE DETECTED among: {remaining}', file=sys.stderr)
    sys.exit(1)

for n in result:
    print(n)
" "$@"
}

# ── Idempotency: check if a molecule already exists ──────────────────────────

# Check if a molecule with label "slice:<name>" exists.
# Returns 0 if it exists, 1 if not.
molecule_exists() {
    local slice_name="$1"
    if $DRY_RUN; then
        return 1  # In dry-run, always treat as not existing
    fi
    local result
    result="$(bd query "label:slice:${slice_name} label:molecule" --json 2>/dev/null || true)"
    if [ -n "$result" ] && [ "$result" != "[]" ] && [ "$result" != "null" ]; then
        return 0
    fi
    return 1
}

# ── Teardown ─────────────────────────────────────────────────────────────────

teardown_slice() {
    local slice_name="$1"
    info "Tearing down molecule for slice: $slice_name"

    if $DRY_RUN; then
        echo "[dry-run] bd query \"label:slice:${slice_name} label:molecule\" --json"
        echo "[dry-run] Would delete all beads in the molecule"
        return
    fi

    local mol_beads
    mol_beads="$(bd query "label:slice:${slice_name} label:molecule" --json 2>/dev/null || true)"
    if [ -z "$mol_beads" ] || [ "$mol_beads" = "[]" ] || [ "$mol_beads" = "null" ]; then
        warn "No molecule found for slice: $slice_name"
        return
    fi

    local ids
    ids="$(echo "$mol_beads" | python3 -c "import sys,json; [print(b['id']) for b in json.load(sys.stdin)]" 2>/dev/null || true)"
    if [ -z "$ids" ]; then
        warn "Could not extract bead IDs for slice: $slice_name"
        return
    fi

    # shellcheck disable=SC2086
    bd delete $ids
    info "Deleted molecule beads for slice: $slice_name"
}

# ── Critical path calculation ────────────────────────────────────────────────

# Given the dependency edges and the 8-step pipeline per slice, compute
# the critical path through the DAG (longest path in terms of step count).
compute_critical_path() {
    local -n _slice_names_ref=$1
    local deps_file="$2"

    # Each slice is 8 steps sequentially. Cross-slice deps add the full
    # predecessor chain. The critical path is the longest chain.
    python3 -c "
import sys

slices = sys.argv[1].split(',')
steps_per_slice = 8
deps_file = sys.argv[2]

# Read cross-slice deps: dependent -> [blockers]
deps = {}
try:
    with open(deps_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split('\t')
            if len(parts) != 2: continue
            dependent, blocker = parts
            deps.setdefault(dependent, []).append(blocker)
except FileNotFoundError:
    pass

# Compute longest path to each slice (in total steps)
# A slice can only start after all its blockers finish
dist = {}
def longest(s, visited=None):
    if visited is None:
        visited = set()
    if s in dist:
        return dist[s]
    if s in visited:
        return steps_per_slice  # cycle guard
    visited.add(s)
    blockers = deps.get(s, [])
    if not blockers:
        dist[s] = steps_per_slice
        return steps_per_slice
    max_blocker = max(longest(b, visited) for b in blockers)
    dist[s] = max_blocker + steps_per_slice
    return dist[s]

for s in slices:
    longest(s)

if not dist:
    print('(no slices)')
    sys.exit(0)

# Find the critical path by tracing back from the longest
critical_len = max(dist.values())
# Find a slice with that length and trace back
path = []
current_candidates = [s for s in slices if dist.get(s, 0) == critical_len]
current = sorted(current_candidates)[0]
path.append(current)
while True:
    blockers = deps.get(current, [])
    if not blockers:
        break
    # Pick the blocker with the longest path
    blockers_sorted = sorted(blockers, key=lambda b: dist.get(b, 0), reverse=True)
    current = blockers_sorted[0]
    path.append(current)
path.reverse()
print('Critical path (%d steps): %s' % (critical_len, ' -> '.join(path)))
" "$(IFS=,; echo "${_slice_names_ref[*]}")" "$deps_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage ;;
            --dry-run) DRY_RUN=true; shift ;;
            --teardown)
                [[ $# -ge 2 ]] || die "--teardown requires a slice name"
                TEARDOWN_SLICE="$2"; shift 2 ;;
            --id-map)
                [[ $# -ge 2 ]] || die "--id-map requires a path"
                ID_MAP_FILE="$2"; shift 2 ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$CATALOG_FILE" ]]; then
                    CATALOG_FILE="$1"
                elif [[ -z "$MAPPING_FILE" ]]; then
                    MAPPING_FILE="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    if [[ -n "$TEARDOWN_SLICE" ]]; then
        # Teardown doesn't require a catalog file
        return
    fi

    [[ -n "$CATALOG_FILE" ]] || die "Missing required argument: catalog.yaml (try --help)"
    [[ -f "$CATALOG_FILE" ]] || die "File not found: $CATALOG_FILE"

    if [[ -n "$MAPPING_FILE" ]] && [[ ! -f "$MAPPING_FILE" ]]; then
        die "Mapping file not found: $MAPPING_FILE"
    fi

    if [[ -z "$ID_MAP_FILE" ]]; then
        ID_MAP_FILE="$SCRIPT_DIR/id-map.yaml"
    fi
}

main() {
    parse_args "$@"
    require_cmd python3
    require_cmd bd

    # Handle teardown mode
    if [[ -n "$TEARDOWN_SLICE" ]]; then
        teardown_slice "$TEARDOWN_SLICE"
        exit 0
    fi

    # ── Parse catalog ────────────────────────────────────────────────────
    info "Parsing catalog: $CATALOG_FILE"
    local slice_names=()
    while IFS= read -r name; do
        slice_names+=("$name")
    done < <(parse_slice_names "$CATALOG_FILE")

    if [[ ${#slice_names[@]} -eq 0 ]]; then
        die "No slices found in $CATALOG_FILE"
    fi
    info "Found ${#slice_names[@]} slices: ${slice_names[*]}"

    # ── Parse slice metadata ─────────────────────────────────────────────
    declare -A slice_types slice_descs
    while IFS=$'\t' read -r name stype sdesc; do
        slice_types["$name"]="$stype"
        slice_descs["$name"]="$sdesc"
    done < <(parse_slices "$CATALOG_FILE")

    # ── Parse dependencies and topo-sort ─────────────────────────────────
    local deps_tmpfile
    deps_tmpfile="$(mktemp)"
    parse_dependencies "$CATALOG_FILE" > "$deps_tmpfile"

    local dep_count
    dep_count="$(wc -l < "$deps_tmpfile" | tr -d ' ')"
    if [[ "$dep_count" -gt 0 ]]; then
        info "Found $dep_count cross-slice dependencies"
    fi

    local sorted_slices=()
    while IFS= read -r name; do
        sorted_slices+=("$name")
    done < <(topo_sort "${slice_names[@]}" < "$deps_tmpfile")
    info "Topological order: ${sorted_slices[*]}"

    # ── Phase 1: Create top-level epic ───────────────────────────────────
    info "Creating top-level epic: $EPIC_TITLE"
    bd_run create "$EPIC_TITLE" -t epic -d "Parent epic for all slice pipeline molecules"
    local epic_id=""
    if ! $DRY_RUN && [[ -n "$REPLY" ]]; then
        epic_id="$(echo "$REPLY" | grep -oP 'bd-[a-f0-9]+' | head -1 || true)"
    fi
    if [[ -n "$epic_id" ]]; then
        info "Epic created: $epic_id"
    fi

    # ── Phase 2: Pour molecules ──────────────────────────────────────────
    declare -A mol_ids  # slice_name -> root bead ID of the poured molecule
    declare -A step_ids # "slice_name/step_id" -> bead ID
    local poured_count=0
    local skipped_count=0

    for slice_name in "${sorted_slices[@]}"; do
        # Idempotency check
        if molecule_exists "$slice_name"; then
            info "SKIP: Molecule already exists for slice: $slice_name"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        local stype="${slice_types[$slice_name]:-unknown}"
        local sdesc="${slice_descs[$slice_name]:-}"

        # Get file list if mapping is available
        local sfiles=""
        if [[ -n "$MAPPING_FILE" ]]; then
            sfiles="$(parse_slice_files "$MAPPING_FILE" "$slice_name")"
        fi

        info "Pouring molecule for slice: $slice_name ($stype)"
        local pour_args=(
            mol pour "$FORMULA_NAME"
            --var "slice_name=$slice_name"
            --var "slice_type=$stype"
            --var "slice_description=$sdesc"
            --var "slice_files=$sfiles"
            --json
        )

        bd_run "${pour_args[@]}"

        if ! $DRY_RUN && [[ -n "$REPLY" ]]; then
            # Parse the pour output to extract bead IDs
            # bd mol pour --json returns the molecule structure with bead IDs
            local mol_root_id
            mol_root_id="$(echo "$REPLY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# The root ID is typically the molecule/epic bead
if isinstance(data, dict):
    print(data.get('id', data.get('root_id', '')))
elif isinstance(data, list) and len(data) > 0:
    print(data[0].get('id', ''))
" 2>/dev/null || true)"
            mol_ids["$slice_name"]="$mol_root_id"

            # Extract step bead IDs (use process substitution to avoid subshell scoping)
            while IFS=$'\t' read -r bid btitle; do
                for step in research plan test-design test-implement test-verify implement verify report; do
                    if [[ "${btitle,,}" == "${step}:"* ]] || [[ "${btitle,,}" == "${step} "* ]]; then
                        step_ids["${slice_name}/${step}"]="$bid"
                        break
                    fi
                done
            done < <(echo "$REPLY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
beads = data if isinstance(data, list) else data.get('beads', data.get('children', []))
if isinstance(data, dict) and 'id' in data:
    beads = data.get('children', [])
for b in beads:
    title = b.get('title', '')
    bead_id = b.get('id', '')
    if bead_id:
        print(bead_id + '\t' + title)
" 2>/dev/null)

            # Label the molecule beads for idempotency tracking
            if [[ -n "$mol_root_id" ]]; then
                bd label add "$mol_root_id" "slice:$slice_name" "molecule" 2>/dev/null || true
                # Parent under epic
                if [[ -n "$epic_id" ]]; then
                    bd update "$mol_root_id" --parent "$epic_id" 2>/dev/null || true
                fi
            fi
        fi

        poured_count=$((poured_count + 1))
    done

    # ── Phase 3: Add cross-slice dependencies ────────────────────────────
    local dep_added_count=0
    if [[ "$dep_count" -gt 0 ]]; then
        info "Adding cross-slice dependencies..."
        while IFS=$'\t' read -r dependent blocker; do
            [[ -z "$dependent" ]] && continue
            # Link dependent/research -> blocker/report
            local dep_research="${step_ids["${dependent}/research"]:-}"
            local blk_report="${step_ids["${blocker}/report"]:-}"

            if $DRY_RUN; then
                echo "[dry-run] bd dep add ${dependent}/research ${blocker}/report"
                dep_added_count=$((dep_added_count + 1))
            elif [[ -n "$dep_research" ]] && [[ -n "$blk_report" ]]; then
                bd dep add "$dep_research" "$blk_report" 2>/dev/null || true
                dep_added_count=$((dep_added_count + 1))
            else
                warn "Cannot link ${dependent}/research -> ${blocker}/report: bead IDs not found"
            fi
        done < "$deps_tmpfile"
    fi

    # ── Phase 4: Create swarm ────────────────────────────────────────────
    if [[ -n "$epic_id" ]]; then
        info "Creating swarm from epic: $epic_id"
        bd_run label add "$epic_id" "swarm"
    elif $DRY_RUN; then
        echo "[dry-run] bd label add <epic-id> swarm"
    fi

    # ── Phase 5: Write ID mapping file ───────────────────────────────────
    info "Writing ID mapping to: $ID_MAP_FILE"
    if $DRY_RUN; then
        echo "[dry-run] Would write ID mapping to $ID_MAP_FILE"
    else
        {
            echo "# Bead Scaffolder ID Mapping"
            echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "# Catalog: $CATALOG_FILE"
            echo ""
            echo "epic_id: \"${epic_id:-}\""
            echo ""
            echo "slices:"
            for slice_name in "${sorted_slices[@]}"; do
                echo "  - name: \"$slice_name\""
                echo "    mol_root_id: \"${mol_ids[$slice_name]:-}\""
                echo "    steps:"
                for step in research plan test-design test-implement test-verify implement verify report; do
                    echo "      ${step}: \"${step_ids["${slice_name}/${step}"]:-}\""
                done
            done
        } > "$ID_MAP_FILE"
    fi

    # ── Phase 5b: Validate cross-slice deps ──────────────────────────────
    if ! $DRY_RUN && [[ "$dep_count" -gt 0 ]] && [[ -n "$epic_id" ]]; then
        info "Validating dependency tree..."
        bd dep tree "$epic_id" 2>/dev/null || warn "Could not validate dep tree"
    fi

    # ── Phase 5c: Critical path ──────────────────────────────────────────
    compute_critical_path sorted_slices "$deps_tmpfile"

    # ── Summary ──────────────────────────────────────────────────────────
    local total_beads=$((poured_count * 9))  # 1 root + 8 steps per molecule
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Scaffold Summary"
    echo "═══════════════════════════════════════════"
    echo "  Slices poured:   $poured_count"
    echo "  Slices skipped:  $skipped_count"
    echo "  Beads created:   ~$total_beads"
    echo "  Cross-slice deps: $dep_added_count"
    echo "  Epic ID:         ${epic_id:-N/A}"
    echo "  ID map:          $ID_MAP_FILE"
    echo "═══════════════════════════════════════════"
}

main "$@"
