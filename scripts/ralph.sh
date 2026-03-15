#!/usr/bin/env bash
set -euo pipefail

# ralph.sh - Outer loop: run ralph-once.sh N times with filters and safety.
#
# Runs the inner loop repeatedly, stopping on RALPH_DONE (no more beads),
# max iterations reached, or max consecutive failures exceeded.

RALPH_DONE=42

# Defaults
ITERATIONS=10
SLICES=""
POOL=""
MODEL=""
TIMEOUT=1800
MAX_FAILURES=3
PERMISSION_MODE="default"
ALLOWED_TOOLS=""
STATE_DIR=".ralph/state"
LOG_DIR=".ralph/logs"
CONSECUTIVE_FAILURES_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INNER_LOOP="$SCRIPT_DIR/ralph-once.sh"

usage() {
  cat <<'USAGE'
ralph.sh - Outer loop for autonomous bead processing.

Usage:
  scripts/ralph.sh [OPTIONS]

Options:
  --iterations N      Max iterations to run (default: 10)
  --slices FILTER     Filter beads by slice name pattern
  --pool POOL         Filter beads by agent pool label
  --model MODEL       Override model selection
  --timeout SECONDS   Per-bead timeout in seconds (default: 1800)
  --max-failures N    Stop after N consecutive failures (default: 3)
  --permission MODE   Claude permission mode (default: default)
  --tools TOOLS       Comma-separated allowed tools for claude
  --state-dir DIR     State directory (default: .ralph/state)
  --help              Show this help message

Safety features:
  - Checks bd ready count before starting; warns and exits if 0
  - Stops after --max-failures consecutive failures
  - Per-bead timeout via --timeout
  - Summary report at end of run

Environment:
  RALPH_DRY_RUN=1    Print what would be done without executing
USAGE
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --slices)
      SLICES="$2"
      shift 2
      ;;
    --pool)
      POOL="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --max-failures)
      MAX_FAILURES="$2"
      shift 2
      ;;
    --permission)
      PERMISSION_MODE="$2"
      shift 2
      ;;
    --tools)
      ALLOWED_TOOLS="$2"
      shift 2
      ;;
    --state-dir)
      STATE_DIR="$2"
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

CONSECUTIVE_FAILURES_FILE="$STATE_DIR/consecutive-failures"
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Reset consecutive failures at start
echo "0" > "$CONSECUTIVE_FAILURES_FILE"

# --- Pre-flight: check bd ready count ---
echo "=== Ralph Outer Loop ==="
echo "Iterations: $ITERATIONS"
echo "Pool: ${POOL:-any}"
echo "Slices: ${SLICES:-any}"
echo "Timeout: ${TIMEOUT}s per bead"
echo "Max failures: $MAX_FAILURES"
echo ""

echo "Checking for ready beads..."
READY_COUNT=$(bd ready --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict):
    data = data.get('issues', data.get('beads', []))
print(len(data))
" 2>/dev/null || echo "0")

if [[ "$READY_COUNT" -eq 0 ]]; then
  echo "WARNING: No ready beads found. Nothing to do."
  echo "Run 'bd ready' to check bead status."
  exit 0
fi

echo "Found $READY_COUNT ready beads."
echo ""

# --- Track stats ---
START_TIME=$(date +%s)
BEADS_COMPLETED=0
BEADS_FAILED=0
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTER_LOG="$LOG_DIR/ralph-$TIMESTAMP.log"

echo "Log: $OUTER_LOG"
echo "Started: $(date -Iseconds)"
echo ""

# Log header
{
  echo "=== Ralph Run ==="
  echo "Started: $(date -Iseconds)"
  echo "Iterations: $ITERATIONS"
  echo "Pool: ${POOL:-any}"
  echo "Slices: ${SLICES:-any}"
  echo ""
} >> "$OUTER_LOG"

# --- Main loop ---
for i in $(seq 1 "$ITERATIONS"); do
  echo "--- Iteration $i/$ITERATIONS ---"

  # Check consecutive failures
  FAIL_COUNT=0
  if [[ -f "$CONSECUTIVE_FAILURES_FILE" ]]; then
    FAIL_COUNT=$(cat "$CONSECUTIVE_FAILURES_FILE")
  fi

  if [[ "$FAIL_COUNT" -ge "$MAX_FAILURES" ]]; then
    echo "WARNING: $FAIL_COUNT consecutive failures (max: $MAX_FAILURES). Stopping."
    echo "Check logs in $LOG_DIR for failure details."
    echo "[$i] STOPPED: max consecutive failures ($FAIL_COUNT)" >> "$OUTER_LOG"
    break
  fi

  # Build inner loop args
  INNER_ARGS=()
  [[ -n "$SLICES" ]] && INNER_ARGS+=(--slices "$SLICES")
  [[ -n "$POOL" ]] && INNER_ARGS+=(--pool "$POOL")
  [[ -n "$MODEL" ]] && INNER_ARGS+=(--model "$MODEL")
  [[ -n "$TIMEOUT" ]] && INNER_ARGS+=(--timeout "$TIMEOUT")
  [[ "$PERMISSION_MODE" != "default" ]] && INNER_ARGS+=(--permission "$PERMISSION_MODE")
  [[ -n "$ALLOWED_TOOLS" ]] && INNER_ARGS+=(--tools "$ALLOWED_TOOLS")
  INNER_ARGS+=(--state-dir "$STATE_DIR")

  # Run inner loop
  INNER_EXIT=0
  bash "$INNER_LOOP" "${INNER_ARGS[@]}" 2>&1 | tee -a "$OUTER_LOG" || INNER_EXIT=$?

  if [[ $INNER_EXIT -eq 0 ]]; then
    BEADS_COMPLETED=$((BEADS_COMPLETED + 1))
    echo "[$i] SUCCESS" >> "$OUTER_LOG"
  elif [[ $INNER_EXIT -eq $RALPH_DONE ]]; then
    echo ""
    echo "No more ready beads in scope. Stopping."
    echo "[$i] RALPH_DONE" >> "$OUTER_LOG"
    break
  else
    BEADS_FAILED=$((BEADS_FAILED + 1))
    echo "[$i] FAILED (exit $INNER_EXIT)" >> "$OUTER_LOG"
  fi

  echo ""
done

# --- Summary ---
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))

# Count remaining beads
REMAINING=$(bd ready --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict):
    data = data.get('issues', data.get('beads', []))
print(len(data))
" 2>/dev/null || echo "?")

echo "=== Summary ==="
echo "Beads completed: $BEADS_COMPLETED"
echo "Beads failed:    $BEADS_FAILED"
echo "Beads remaining: $REMAINING"
echo "Total time:      ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
echo "Log file:        $OUTER_LOG"

# Append summary to log
{
  echo ""
  echo "=== Summary ==="
  echo "Ended: $(date -Iseconds)"
  echo "Beads completed: $BEADS_COMPLETED"
  echo "Beads failed:    $BEADS_FAILED"
  echo "Beads remaining: $REMAINING"
  echo "Total time:      ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
} >> "$OUTER_LOG"
