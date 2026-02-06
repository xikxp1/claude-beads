#!/bin/bash
# enforce-branch-policy.sh — PreToolUse hook for Bash tool
# Blocks git commits directly to main/master branches.
#
# Exit codes:
#   0 = allow
#   2 = block (stderr message is fed back to the agent)

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check commands that contain git commit
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Check current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  echo "Cannot commit directly to '$BRANCH'. Create a feature branch first (beads/{task-id}/{description})." >&2
  exit 2
fi

exit 0
