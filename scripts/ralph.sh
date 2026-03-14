#!/usr/bin/env bash
set -euo pipefail

# ralph: Outer loop that repeatedly invokes ralph-once until all beads are
# done or the iteration limit is reached.
#
# Usage: ralph.sh [--slices "s1,s2"] [--pool POOL] [--iterations N] [--model MODEL]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_DIR="$REPO_ROOT/.ralph"
LOG_DIR="$RALPH_DIR/logs"

# --- Defaults ---
SLICES=""
POOL=""
ITERATIONS=100
MODEL=""

# --- Help ---
usage() {
  cat <<'USAGE'
ralph — autonomous loop that processes beads until done

Usage:
  ralph.sh [--slices "s1,s2"] [--pool POOL] [--iterations N] [--model MODEL]

Options:
  --slices CSV      Comma-separated slice names to filter on
  --pool POOL       Agent pool label to filter on (e.g. test-author,
                    code-author, general)
  --iterations N    Maximum iterations before stopping (default: 100)
  --model MODEL     Override the AI model (claude or codex)
  --help            Show this help message

The loop runs ralph-once.sh repeatedly. It stops when ralph-once prints
RALPH_DONE (no more ready beads) or when the iteration limit is reached.

Logs are written to .ralph/logs/ralph-<timestamp>.log
USAGE
  exit 0
}

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slices)     SLICES="$2";     shift 2 ;;
    --pool)       POOL="$2";       shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --model)      MODEL="$2";      shift 2 ;;
    --help|-h)    usage ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# Validate iterations is a number
if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: --iterations must be a positive integer, got '$ITERATIONS'" >&2
  exit 1
fi

# --- Setup logging ---
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/ralph-$(date +%Y%m%d-%H%M%S).log"
echo "Ralph starting at $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee "$LOGFILE"
echo "  slices:     ${SLICES:-(all)}" | tee -a "$LOGFILE"
echo "  pool:       ${POOL:-(all)}" | tee -a "$LOGFILE"
echo "  iterations: $ITERATIONS" | tee -a "$LOGFILE"
echo "  model:      ${MODEL:-(auto)}" | tee -a "$LOGFILE"
echo "  log:        $LOGFILE" | tee -a "$LOGFILE"
echo "---" | tee -a "$LOGFILE"

# --- Build ralph-once args ---
ONCE_ARGS=()
if [[ -n "$SLICES" ]]; then
  ONCE_ARGS+=(--slices "$SLICES")
fi
if [[ -n "$POOL" ]]; then
  ONCE_ARGS+=(--pool "$POOL")
fi
if [[ -n "$MODEL" ]]; then
  ONCE_ARGS+=(--model "$MODEL")
fi

# --- Main loop ---
COMPLETED=0
for (( i=1; i<=ITERATIONS; i++ )); do
  echo "" | tee -a "$LOGFILE"
  echo "=== Iteration $i / $ITERATIONS ===" | tee -a "$LOGFILE"
  echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOGFILE"

  OUTPUT=$("$SCRIPT_DIR/ralph-once.sh" "${ONCE_ARGS[@]}" 2>&1 | tee -a "$LOGFILE") || true

  if echo "$OUTPUT" | grep -q "RALPH_DONE"; then
    echo "All beads processed. Stopping." | tee -a "$LOGFILE"
    break
  fi

  COMPLETED=$i
  echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOGFILE"
done

# --- Summary ---
echo "" | tee -a "$LOGFILE"
echo "---" | tee -a "$LOGFILE"
echo "Ralph finished at $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOGFILE"
echo "  Iterations completed: $COMPLETED" | tee -a "$LOGFILE"
echo "  Log: $LOGFILE" | tee -a "$LOGFILE"
