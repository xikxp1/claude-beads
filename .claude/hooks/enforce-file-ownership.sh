#!/bin/bash
# enforce-file-ownership.sh — PreToolUse hook for Write|Edit tools
# Called from each subagent's frontmatter with the agent name as $1.
# Receives tool input JSON on stdin. Blocks writes outside the agent's domain.
#
# Bead-scoped paths: .claude-beads/beads/<id>/artifacts/, .claude-beads/beads/<id>/summaries/, etc.
#
# Exit codes:
#   0 = allow
#   2 = block (stderr message is fed back to the agent)

set -euo pipefail

AGENT="${1:-unknown}"
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

# If no file path in the input, allow (non-file operation)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Path checks — use substring matching for bead-scoped paths
is_artifact() { [[ "$FILE_PATH" == *"/artifacts/"* ]]; }
is_bead()     { [[ "$FILE_PATH" == *".claude-beads/beads/"* ]]; }
is_child()    { [[ "$FILE_PATH" == *"/children/"* ]]; }
is_summary()  { [[ "$FILE_PATH" == *"/summaries/"* ]]; }
is_state()    { [[ "$FILE_PATH" == *".claude-beads/state.json"* ]]; }
is_beads_dir(){ [[ "$FILE_PATH" == *".claude-beads/"* ]]; }
is_test()     { [[ "$FILE_PATH" == *"test"* ]] || [[ "$FILE_PATH" == *"spec"* ]] || [[ "$FILE_PATH" == *"__tests__"* ]]; }

block() {
  echo "$1" >&2
  exit 2
}

case "$AGENT" in
  analyst)
    # Can only write to bead artifacts
    if is_bead && is_artifact; then
      exit 0
    fi
    block "Analyst agent can only write to <BEAD_ROOT>/artifacts/"
    ;;

  architect)
    # Can write to bead artifacts and project-root ARCHITECTURE.md
    if is_bead && is_artifact; then
      exit 0
    fi
    if [[ "$(basename "$FILE_PATH")" == "ARCHITECTURE.md" ]] && ! is_beads_dir; then
      exit 0
    fi
    block "Architect agent can only write to <BEAD_ROOT>/artifacts/ and project-root ARCHITECTURE.md"
    ;;

  manager)
    # Can write to bead artifacts, children, and bead.json
    if is_bead; then
      exit 0
    fi
    block "Manager agent can only write within the bead directory (.claude-beads/beads/<id>/)"
    ;;

  test-engineer)
    # Can write to test files and bead artifacts
    if is_test; then
      exit 0
    fi
    if is_bead && is_artifact; then
      exit 0
    fi
    if is_bead && is_child; then
      exit 0
    fi
    block "Test-engineer agent can only write to test directories and bead artifacts"
    ;;

  developer)
    # Can write to source files and update child bead status, but NOT test files or artifacts
    if is_test; then
      block "Developer agent cannot modify test files. Flag contested tests in the bead's contested_tests field instead."
    fi
    if is_bead && is_artifact; then
      block "Developer agent cannot modify artifacts."
    fi
    if is_bead && is_summary; then
      block "Developer agent cannot modify summaries."
    fi
    # Allow source code and child bead status updates
    exit 0
    ;;

  validator)
    # Can only write to bead artifacts (review.md)
    if is_bead && is_artifact; then
      exit 0
    fi
    block "Validator agent can only write to <BEAD_ROOT>/artifacts/ (review.md)"
    ;;

  summarizer)
    # Can only write to bead summaries
    if is_bead && is_summary; then
      exit 0
    fi
    block "Summarizer agent can only write to <BEAD_ROOT>/summaries/"
    ;;

  *)
    # Unknown agent — allow by default
    exit 0
    ;;
esac
