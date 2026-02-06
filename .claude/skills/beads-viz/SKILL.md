---
name: beads-viz
description: "Generate a static HTML dashboard visualizing the current beads workflow state."
allowed-tools: Bash
---

# Beads Visualization

Generate a static HTML dashboard from the current workflow state.

Run the generator script:

```bash
$CLAUDE_PROJECT_DIR/.claude/scripts/generate-viz.sh
```

After generation, tell the user the file is at `.claude-beads/viz.html` and they can open it in a browser.

If the script fails because no `state.json` exists, tell the user to start a workflow first with `/beads`.
