#!/usr/bin/env bash
set -euo pipefail

# compare-builds.sh — Run the same Maestro flow suite against two APP_IDs
# and produce a parity diff report.
#
# Usage:
#   compare-builds.sh --old-app <APP_ID> --new-app <APP_ID> --flows <dir> [--output <file>] [--dry-run]
#
# Output: a markdown table showing per-flow pass/fail for each app and the delta.

SCRIPT_NAME="$(basename "$0")"

OLD_APP=""
NEW_APP=""
FLOWS_DIR=""
OUTPUT_FILE=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --old-app <APP_ID> --new-app <APP_ID> --flows <dir> [OPTIONS]

Run the same Maestro flow suite against two different app IDs and generate
a parity comparison report.

Required:
  --old-app <APP_ID>    Bundle/package ID of the existing (reference) app
  --new-app <APP_ID>    Bundle/package ID of the new app under test
  --flows <dir>         Directory containing Maestro flow YAML files

Options:
  --output <file>       Write the diff report to this file (default: stdout)
  --dry-run             Print commands without executing
  -h, --help            Show this help message

Examples:
  $SCRIPT_NAME --old-app com.example.old --new-app com.example.new --flows e2e/flows/
  $SCRIPT_NAME --dry-run --old-app com.test.old --new-app com.test.new --flows e2e/flows/
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --old-app)
        [[ $# -ge 2 ]] || die "--old-app requires a value"
        OLD_APP="$2"
        shift 2
        ;;
      --new-app)
        [[ $# -ge 2 ]] || die "--new-app requires a value"
        NEW_APP="$2"
        shift 2
        ;;
      --flows)
        [[ $# -ge 2 ]] || die "--flows requires a value"
        FLOWS_DIR="$2"
        shift 2
        ;;
      --output)
        [[ $# -ge 2 ]] || die "--output requires a value"
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  [[ -n "$OLD_APP" ]] || die "Missing required flag: --old-app"
  [[ -n "$NEW_APP" ]] || die "Missing required flag: --new-app"
  [[ -n "$FLOWS_DIR" ]] || die "Missing required flag: --flows"
}

# Discover all .yaml flow files in the flows directory.
discover_flows() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "(flows dir '$dir' does not exist — would discover flows here)" >&2
    return
  fi
  find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort
}

# Run maestro test for a single flow against a given APP_ID.
# Returns 0 for pass, non-zero for fail.
run_single_flow() {
  local app_id="$1"
  local flow_file="$2"

  if $DRY_RUN; then
    echo "[dry-run] maestro test -e APP_ID=$app_id $flow_file"
    return 0
  fi

  if maestro test -e "APP_ID=$app_id" "$flow_file" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Run the full suite against one APP_ID. Populates an associative array
# with flow-name => PASS/FAIL.
run_suite() {
  local app_id="$1"
  local -n _suite_ref=$2
  shift 2
  local flows=("$@")

  for flow in "${flows[@]}"; do
    local name
    name="$(basename "$flow")"
    if run_single_flow "$app_id" "$flow"; then
      _suite_ref["$name"]="PASS"
    else
      _suite_ref["$name"]="FAIL"
    fi
  done
}

# Generate markdown diff report from two result sets.
generate_report() {
  local -n _old_ref=$1
  local -n _new_ref=$2
  shift 2
  local flow_names=("$@")

  local report=""
  report+="# Parity Comparison Report"$'\n'
  report+=""$'\n'
  report+="**Old App:** \`$OLD_APP\`  "$'\n'
  report+="**New App:** \`$NEW_APP\`  "$'\n'
  report+="**Flows Dir:** \`$FLOWS_DIR\`  "$'\n'
  report+="**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  "$'\n'
  report+=""$'\n'
  report+="| Flow | Old App | New App | Delta |"$'\n'
  report+="|------|---------|---------|-------|"$'\n'

  local pass_count=0
  local fail_count=0
  local regression_count=0

  for name in "${flow_names[@]}"; do
    local old_result="${_old_ref[$name]:-N/A}"
    local new_result="${_new_ref[$name]:-N/A}"
    local delta=""

    if [[ "$old_result" == "$new_result" ]]; then
      delta="--"
      ((pass_count++)) || true
    elif [[ "$old_result" == "PASS" && "$new_result" == "FAIL" ]]; then
      delta="REGRESSION"
      ((regression_count++)) || true
    elif [[ "$old_result" == "FAIL" && "$new_result" == "PASS" ]]; then
      delta="FIXED"
      ((pass_count++)) || true
    else
      delta="???"
      ((fail_count++)) || true
    fi

    report+="| $name | $old_result | $new_result | $delta |"$'\n'
  done

  report+=""$'\n'
  report+="## Summary"$'\n'
  report+=""$'\n'
  report+="- **Total flows:** ${#flow_names[@]}"$'\n'
  report+="- **Matching:** $pass_count"$'\n'
  report+="- **Regressions:** $regression_count"$'\n'
  report+="- **Other differences:** $fail_count"$'\n'

  echo "$report"
}

main() {
  parse_args "$@"

  echo "Comparing builds:" >&2
  echo "  Old app: $OLD_APP" >&2
  echo "  New app: $NEW_APP" >&2
  echo "  Flows:   $FLOWS_DIR" >&2
  echo "  Dry run: $DRY_RUN" >&2
  echo "" >&2

  # Discover flows
  local -a flow_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && flow_files+=("$f")
  done < <(discover_flows "$FLOWS_DIR")

  if [[ ${#flow_files[@]} -eq 0 ]]; then
    if $DRY_RUN; then
      echo "[dry-run] No flow files found in '$FLOWS_DIR' (directory may not exist)." >&2
      echo "[dry-run] Would run: maestro test -e APP_ID=$OLD_APP $FLOWS_DIR" >&2
      echo "[dry-run] Would run: maestro test -e APP_ID=$NEW_APP $FLOWS_DIR" >&2
      echo "" >&2
      echo "# Parity Comparison Report (Dry Run)"
      echo ""
      echo "No flows discovered. Commands that would be executed:"
      echo ""
      echo "\`\`\`bash"
      echo "maestro test -e APP_ID=$OLD_APP $FLOWS_DIR"
      echo "maestro test -e APP_ID=$NEW_APP $FLOWS_DIR"
      echo "\`\`\`"
      exit 0
    else
      die "No flow files found in '$FLOWS_DIR'"
    fi
  fi

  # Extract flow names for ordering
  local -a flow_names=()
  for f in "${flow_files[@]}"; do
    flow_names+=("$(basename "$f")")
  done

  if $DRY_RUN; then
    echo "[dry-run] Discovered ${#flow_files[@]} flow(s):" >&2
    for f in "${flow_files[@]}"; do
      echo "  $f" >&2
    done
    echo "" >&2
  fi

  # Run suites
  declare -A old_results
  declare -A new_results

  echo "Running flows against old app ($OLD_APP)..." >&2
  run_suite "$OLD_APP" old_results "${flow_files[@]}"

  echo "Running flows against new app ($NEW_APP)..." >&2
  run_suite "$NEW_APP" new_results "${flow_files[@]}"

  # Generate report
  local report
  report="$(generate_report old_results new_results "${flow_names[@]}")"

  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$report" > "$OUTPUT_FILE"
    echo "Report written to $OUTPUT_FILE" >&2
  else
    echo "$report"
  fi
}

main "$@"
