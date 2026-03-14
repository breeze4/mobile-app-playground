#!/usr/bin/env bash
set -euo pipefail

# ralph-once: Run one iteration of the Ralph loop.
# Picks the highest-priority ready bead, sends it to an AI agent, and
# closes it on success or re-opens it on failure.
#
# Usage: ralph-once.sh [--slices "s1,s2"] [--pool POOL] [--model MODEL]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_DIR="$REPO_ROOT/.ralph"
MODELS_YAML="$RALPH_DIR/models.yaml"

# --- Defaults ---
SLICES=""
POOL=""
MODEL=""

# --- Help ---
usage() {
  cat <<'USAGE'
ralph-once — pick and execute the next ready bead

Usage:
  ralph-once.sh [--slices "s1,s2"] [--pool POOL] [--model MODEL]

Options:
  --slices CSV   Comma-separated slice names to filter on (matched against
                 parent molecule name)
  --pool POOL    Agent pool label to filter on (e.g. test-author, code-author,
                 general). Matched against the bead's agent_pool label.
  --model MODEL  Override the AI model (claude or codex). When omitted, the
                 model is looked up from .ralph/models.yaml by pool, defaulting
                 to claude.
  --help         Show this help message

Exit behaviour:
  Prints "RALPH_DONE" and exits 0 when no ready beads remain in scope.
USAGE
  exit 0
}

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slices)  SLICES="$2";  shift 2 ;;
    --pool)    POOL="$2";    shift 2 ;;
    --model)   MODEL="$2";   shift 2 ;;
    --help|-h) usage ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# --- Helper: look up model from models.yaml ---
resolve_model() {
  local pool="$1"
  # Explicit --model wins
  if [[ -n "$MODEL" ]]; then
    echo "$MODEL"
    return
  fi
  # Try to look up by pool in models.yaml
  if [[ -n "$pool" && -f "$MODELS_YAML" ]]; then
    local mapped
    # Simple YAML parse: find "pool: value" lines, strip comments
    mapped=$(grep -E "^${pool}:" "$MODELS_YAML" 2>/dev/null \
      | head -1 \
      | sed 's/^[^:]*:[[:space:]]*//' \
      | sed 's/[[:space:]]*#.*//' \
      | tr -d '[:space:]')
    if [[ -n "$mapped" ]]; then
      echo "$mapped"
      return
    fi
  fi
  # Default
  echo "claude"
}

# --- 1. Query ready beads, apply filters, pick first match ---
BD_ARGS=(ready --json --limit 50)
if [[ -n "$POOL" ]]; then
  BD_ARGS+=(--label "agent_pool:$POOL")
fi

READY_JSON=$(bd "${BD_ARGS[@]}" 2>/dev/null) || {
  echo "Error: bd ready failed" >&2
  exit 1
}

# Filter by --slices (if set) and pick the first matching bead.
# Outputs "id\ntitle" on success, exits non-zero if nothing matches.
PICKED=$(echo "$READY_JSON" | SLICES="$SLICES" python3 -c "
import sys, json, os

data = json.load(sys.stdin)
if not isinstance(data, list) or not data:
    sys.exit(1)

slices_csv = os.environ.get('SLICES', '')
slices = [s.strip().lower() for s in slices_csv.split(',') if s.strip()]

for bead in data:
    if slices:
        bead_text = (bead.get('title', '') + ' ' + bead.get('parent_title', '')).lower()
        if not any(s in bead_text for s in slices):
            continue
    print(bead['id'])
    print(bead['title'])
    sys.exit(0)

sys.exit(1)
" 2>/dev/null) || {
  echo "RALPH_DONE"
  exit 0
}

BEAD_ID=$(echo "$PICKED" | head -1)
BEAD_TITLE=$(echo "$PICKED" | tail -1)

echo ">>> Ralph picking bead: $BEAD_ID — $BEAD_TITLE"

# --- 2. Claim the bead ---
bd update "$BEAD_ID" --status=in_progress 2>/dev/null || true

# --- 3. Read full bead details ---
BEAD_DETAIL=$(bd show "$BEAD_ID" --json 2>/dev/null) || {
  echo "Error: could not read bead $BEAD_ID" >&2
  bd update "$BEAD_ID" --status=open 2>/dev/null || true
  exit 1
}

# Extract description, labels, and agent_pool in one pass
eval "$(echo "$BEAD_DETAIL" | python3 -c "
import sys, json, shlex

d = json.load(sys.stdin)
desc = d.get('description', '(no description)')
labels = d.get('labels', [])
pool = ''
for l in labels:
    if l.startswith('agent_pool:'):
        pool = l.split(':',1)[1]
        break
labels_str = ', '.join(labels) if labels else '(none)'

print('BEAD_DESC=' + shlex.quote(desc))
print('BEAD_LABELS=' + shlex.quote(labels_str))
print('BEAD_POOL=' + shlex.quote(pool))
")"

# --- 4. Resolve model ---
RESOLVED_MODEL=$(resolve_model "$BEAD_POOL")
echo ">>> Using model: $RESOLVED_MODEL"

# --- 5. Construct prompt ---
PROMPT="You are working on a mobile app migration project.

## Your Task

$BEAD_TITLE

## Instructions

$BEAD_DESC

## Context

- Bead ID: $BEAD_ID
- Labels: $BEAD_LABELS

## Rules

- Read the instructions carefully — they contain everything you need
- Commit your work with a descriptive message
- When done, output RALPH_STEP_DONE
- If you are blocked or stuck, output RALPH_BLOCKED with a reason"

# --- 6. Invoke the agent ---
AGENT_EXIT=0
if [[ "$RESOLVED_MODEL" == "codex" ]]; then
  echo ">>> Invoking codex agent..."
  codex --print -p "$PROMPT" || AGENT_EXIT=$?
else
  echo ">>> Invoking claude agent..."
  claude --print -p "$PROMPT" \
    --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
    || AGENT_EXIT=$?
fi

# --- 7. Handle result ---
if [[ "$AGENT_EXIT" -eq 0 ]]; then
  echo ">>> Bead $BEAD_ID succeeded. Closing."
  bd close "$BEAD_ID" --reason="completed by ralph" --suggest-next 2>/dev/null || true
else
  echo ">>> Bead $BEAD_ID failed (exit $AGENT_EXIT). Reopening."
  bd update "$BEAD_ID" \
    --status=open \
    --append-notes "ralph failed: agent exited with code $AGENT_EXIT" \
    2>/dev/null || true
fi

# --- 8. Commit any uncommitted changes ---
if [[ -n $(git -C "$REPO_ROOT" status --porcelain 2>/dev/null) ]]; then
  echo ">>> Committing leftover changes..."
  git -C "$REPO_ROOT" add -A
  git -C "$REPO_ROOT" commit -m "$BEAD_TITLE

Bead: $BEAD_ID" || true
fi
