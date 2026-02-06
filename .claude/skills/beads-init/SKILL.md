---
name: beads-init
description: |
  Initialize the claude-beads workflow for this project. Creates the
  .claude-beads/ directory structure and prompts for project configuration.
argument-hint: "[tech stack, e.g. 'svelte tailwind']"
allowed-tools: Read, Write, Bash, AskUserQuestion, Glob
---

# Beads Initialization

Initialize the claude-beads workflow directory for this project.

## Steps

### 1. Check Existing Setup

Check if `.claude-beads/config.yml` already exists.
- If it exists, ask the user if they want to reinitialize (this will reset the config but preserve any existing beads).
- If it doesn't exist, proceed with setup.

### 2. Create Directory Structure

Ensure the base directory exists (create if missing):
- `.claude-beads/beads/`

Individual bead directories (with their own `artifacts/`, `summaries/`, `children/`) are created automatically by the orchestrator when a workflow starts via `/beads`.

### 3. Detect Tech Stack

Explore the project to auto-detect the tech stack:
- Check `package.json` for JS/TS frameworks and libraries
- Check `go.mod`, `Cargo.toml`, `pyproject.toml`, `Gemfile`, etc.
- Check existing config files (`.svelte`, `next.config`, `vite.config`, etc.)

Present the detected stack to the user and ask if it's correct. Allow them to add or remove items.

If `$ARGUMENTS` was provided (e.g., `svelte tailwind`), use that as the starting point instead of auto-detection.

### 4. Write Configuration

Write `.claude-beads/config.yml` with the confirmed stack. For each technology, look up the official documentation URL:

```yaml
stack:
  - name: <tech>
    docs: <official docs URL>
```

Include the default workflow settings:

```yaml
workflow:
  loop_limits:
    analyst_architect: 2
    analyst_manager: 2
    developer_validator: 3
    developer_test_engineer: 1
  user_checkpoints:
    - post-requirements
    - post-architecture
    - post-planning
    - final-review

branch:
  strategy: feature-branch
  naming: "beads/{task-id}/{short-description}"
```

### 5. Verify .gitignore

Check if `.gitignore` includes entries for volatile beads files. If not, suggest adding:
```
.claude-beads/state.json
.claude-beads/audit.jsonl
```

### 6. Print Summary

Confirm the setup is complete:
- List the detected/configured tech stack
- Show the directory structure created
- Explain how to start a workflow: use `/beads <task description>`
- Note that `.claude-beads/state.json` and `audit.jsonl` are gitignored (volatile state)
- Note that bead directories (with artifacts, summaries, children) ARE tracked in git (team visibility)
- Explain that each `/beads` invocation creates an isolated bead directory under `.claude-beads/beads/<task-id>/`
