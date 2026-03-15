#!/usr/bin/env bash
set -euo pipefail

# ralph-once.sh - Inner loop: pick one ready bead, do the work, close it.
#
# Queries bd ready, filters by slice and pool, picks the first match,
# marks it in_progress, invokes claude with the bead description as prompt,
# and closes the bead on success or records failure notes on failure.
#
# Exit codes:
#   0   - Bead completed successfully
#   1   - Bead failed (claude error or non-zero exit)
#   42  - No ready beads in scope (RALPH_DONE)

RALPH_DONE=42

# Defaults
SLICES=""
POOL=""
MODEL=""
TIMEOUT=1800
PERMISSION_MODE="default"
ALLOWED_TOOLS=""
STATE_DIR=".ralph/state"
LOG_DIR=".ralph/logs"
MODELS_CONFIG=".ralph/models.yaml"
CONSECUTIVE_FAILURES_FILE="$STATE_DIR/consecutive-failures"

usage() {
  cat <<'USAGE'
ralph-once.sh - Pick one ready bead and execute it.

Usage:
  scripts/ralph-once.sh [OPTIONS]

Options:
  --slices FILTER     Filter beads by slice name pattern (passed to bd ready)
  --pool POOL         Filter beads by agent pool label
  --model MODEL       Override model selection (e.g., claude-sonnet-4-20250514)
  --timeout SECONDS   Kill claude invocation after this many seconds (default: 1800)
  --permission MODE   Claude permission mode (default: default)
  --tools TOOLS       Comma-separated allowed tools for claude
  --state-dir DIR     State directory (default: .ralph/state)
  --help              Show this help message

Exit codes:
  0   - Bead completed successfully
  1   - Bead failed
  42  - No ready beads in scope (RALPH_DONE)

Environment:
  RALPH_DRY_RUN=1    Print what would be done without executing
USAGE
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
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
      CONSECUTIVE_FAILURES_FILE="$STATE_DIR/consecutive-failures"
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

mkdir -p "$STATE_DIR" "$LOG_DIR"

# --- Resolve model from pool config ---
resolve_model() {
  local pool="$1"

  # Explicit --model flag takes precedence
  if [[ -n "$MODEL" ]]; then
    echo "$MODEL"
    return
  fi

  # Look up pool in models.yaml
  if [[ -f "$MODELS_CONFIG" && -n "$pool" ]]; then
    local model_from_config
    model_from_config=$(python3 -c "
import yaml, sys
with open('$MODELS_CONFIG') as f:
    config = yaml.safe_load(f)
pools = config.get('pools', {})
pool_config = pools.get('$pool', {})
print(pool_config.get('model', config.get('default_model', '')))
" 2>/dev/null || echo "")
    if [[ -n "$model_from_config" ]]; then
      echo "$model_from_config"
      return
    fi
  fi

  # Fallback: no model override (use claude default)
  echo ""
}

# --- Track consecutive failures ---
read_failure_count() {
  if [[ -f "$CONSECUTIVE_FAILURES_FILE" ]]; then
    cat "$CONSECUTIVE_FAILURES_FILE"
  else
    echo "0"
  fi
}

increment_failure_count() {
  local count
  count=$(read_failure_count)
  echo $((count + 1)) > "$CONSECUTIVE_FAILURES_FILE"
}

reset_failure_count() {
  echo "0" > "$CONSECUTIVE_FAILURES_FILE"
}

# --- Query bd ready ---
echo "Querying ready beads..."

READY_JSON=$(bd ready --json 2>/dev/null || echo "[]")

# Filter by pool and slices using python3
BEAD_JSON=$(python3 -c "
import json, sys

beads = json.loads('''$READY_JSON''')
if isinstance(beads, dict):
    beads = beads.get('issues', beads.get('beads', []))

pool_filter = '$POOL'
slice_filter = '$SLICES'

filtered = []
for b in beads:
    # Filter by pool if specified
    if pool_filter:
        bead_pool = b.get('agent_pool', b.get('labels', {}).get('agent_pool', ''))
        if bead_pool != pool_filter:
            continue

    # Filter by slice name pattern if specified
    if slice_filter:
        title = b.get('title', '')
        if slice_filter.lower() not in title.lower():
            continue

    filtered.append(b)

if not filtered:
    sys.exit(1)

# Pick first ready bead
print(json.dumps(filtered[0]))
" 2>/dev/null) || {
  echo "No ready beads matching filters (pool=$POOL, slices=$SLICES)"
  exit $RALPH_DONE
}

read -r BEAD_ID BEAD_POOL <<< "$(echo "$BEAD_JSON" | python3 -c "
import sys, json
b = json.load(sys.stdin)
pool = b.get('agent_pool', b.get('labels', {}).get('agent_pool', ''))
print(b['id'], pool)
")"
BEAD_TITLE=$(echo "$BEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title', 'unknown'))")
BEAD_DESC=$(echo "$BEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description', ''))")

echo "Selected bead: $BEAD_ID - $BEAD_TITLE"
echo "Pool: $BEAD_POOL"

# Mark bead as in_progress
if [[ "${RALPH_DRY_RUN:-}" != "1" ]]; then
  bd update "$BEAD_ID" --status=in_progress 2>/dev/null || true
fi

# Resolve model
RESOLVED_MODEL=$(resolve_model "$BEAD_POOL")
echo "Model: ${RESOLVED_MODEL:-default}"

# Build claude invocation
CLAUDE_ARGS=()

if [[ -n "$RESOLVED_MODEL" ]]; then
  CLAUDE_ARGS+=(--model "$RESOLVED_MODEL")
fi

if [[ "$PERMISSION_MODE" != "default" ]]; then
  CLAUDE_ARGS+=(--permission-mode "$PERMISSION_MODE")
fi

if [[ -n "$ALLOWED_TOOLS" ]]; then
  IFS=',' read -ra TOOLS <<< "$ALLOWED_TOOLS"
  for tool in "${TOOLS[@]}"; do
    CLAUDE_ARGS+=(--allowedTools "$tool")
  done
fi

# Build prompt from bead description
PROMPT="You are working on bead $BEAD_ID: $BEAD_TITLE

Instructions:
$BEAD_DESC

When you are done, commit your changes and close the bead using:
  scripts/bd-done.sh $BEAD_ID -r \"<summary of what you did>\"

If you cannot complete the task, explain why in detail."

# Log file for this invocation
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/ralph-once-$BEAD_ID-$TIMESTAMP.log"

echo "Log: $LOG_FILE"
echo "Timeout: ${TIMEOUT}s"

# Execute claude with timeout
CLAUDE_EXIT=0
if [[ "${RALPH_DRY_RUN:-}" == "1" ]]; then
  echo "[DRY-RUN] timeout $TIMEOUT claude ${CLAUDE_ARGS[*]} -p \"$PROMPT\""
else
  echo "Starting claude invocation..."
  timeout "$TIMEOUT" claude "${CLAUDE_ARGS[@]}" -p "$PROMPT" \
    2>&1 | tee "$LOG_FILE" || CLAUDE_EXIT=$?
fi

# Handle result
if [[ $CLAUDE_EXIT -eq 0 ]]; then
  echo ""
  echo "Bead $BEAD_ID completed successfully."
  reset_failure_count
  exit 0
elif [[ $CLAUDE_EXIT -eq 124 ]]; then
  echo ""
  echo "ERROR: Bead $BEAD_ID timed out after ${TIMEOUT}s."
  increment_failure_count
  if [[ "${RALPH_DRY_RUN:-}" != "1" ]]; then
    bd update "$BEAD_ID" --status=open 2>/dev/null || true
    bd comment "$BEAD_ID" --body="Ralph timeout after ${TIMEOUT}s" 2>/dev/null || true
  fi
  exit 1
else
  echo ""
  echo "ERROR: Bead $BEAD_ID failed (exit code: $CLAUDE_EXIT)."
  increment_failure_count
  if [[ "${RALPH_DRY_RUN:-}" != "1" ]]; then
    bd update "$BEAD_ID" --status=open 2>/dev/null || true
    bd comment "$BEAD_ID" --body="Ralph failure (exit $CLAUDE_EXIT). See log: $LOG_FILE" 2>/dev/null || true
  fi
  exit 1
fi
