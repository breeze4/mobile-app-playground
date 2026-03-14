#!/usr/bin/env bash
set -euo pipefail

# bd-done: commit changes and close a bead in one step.
# Usage: bd-done <bead-id> [-r "reason"] [-- extra bd close flags]
#
# 1. Stages all changed/new files (respects .gitignore)
# 2. Commits with bead ID in the message
# 3. Closes the bead via bd close
#
# If there are no changes to commit, it still closes the bead.

if [[ $# -lt 1 ]]; then
  echo "Usage: bd-done <bead-id> [-r \"reason\"] [-- extra bd close flags]"
  exit 1
fi

BEAD_ID="$1"
shift

# Parse optional reason
REASON=""
EXTRA_FLAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--reason)
      REASON="$2"
      shift 2
      ;;
    --)
      shift
      EXTRA_FLAGS=("$@")
      break
      ;;
    *)
      EXTRA_FLAGS+=("$1")
      shift
      ;;
  esac
done

# Get bead title for commit message
BEAD_TITLE=$(bd show "$BEAD_ID" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])" 2>/dev/null || echo "$BEAD_ID")

# Check for uncommitted changes
if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
  echo "Staging changes..."
  git add -A

  COMMIT_MSG="$BEAD_TITLE"
  if [[ -n "$REASON" ]]; then
    COMMIT_MSG="$COMMIT_MSG

$REASON"
  fi
  COMMIT_MSG="$COMMIT_MSG

Closes: $BEAD_ID"

  echo "Committing: $BEAD_TITLE"
  git commit -m "$COMMIT_MSG"
else
  echo "No changes to commit."
fi

# Close the bead
echo "Closing bead: $BEAD_ID"
if [[ -n "$REASON" ]]; then
  bd close "$BEAD_ID" --reason="$REASON" --suggest-next "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
else
  bd close "$BEAD_ID" --suggest-next "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
fi
