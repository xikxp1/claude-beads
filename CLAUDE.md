# Claude-Beads

Multi-agent task management workflow for Claude Code. Uses subagents for every phase of development with explicit user checkpoints and bounded iteration loops.

## Quick Start

1. Copy the `.claude/` directory into your project
2. Run `/beads-init` to set up the `.claude-beads/` working directory
3. Start a workflow with `/beads <task description>`

## Workflow Phases

`/beads` routes through: Analyst → Architect → Manager → Test-engineer → Developer → Validator

User approval is required after requirements, architecture, planning, and final review.

## Key Commands

- `/beads <description>` — start or resume a workflow
- `/beads-init [stack]` — initialize beads for this project
- `/beads-viz` — generate HTML dashboard of current workflow state

## File Layout

- `.claude/agents/` — subagent definitions (analyst, architect, manager, test-engineer, developer, validator, summarizer)
- `.claude/skills/beads/` — orchestrator skill
- `.claude/skills/doc-search/` — tech doc search (preloaded into agents)
- `.claude/hooks/` — file ownership and branch policy enforcement
- `.claude/scripts/` — viz generator script
- `.claude-beads/config.yml` — project configuration (tech stack, loop limits)
- `.claude-beads/state.json` — volatile workflow state (gitignored)
- `.claude-beads/audit.jsonl` — volatile event log (gitignored)
- `.claude-beads/beads/<task-id>/` — isolated bead directory per task:
  - `bead.json` — root bead metadata
  - `artifacts/` — phase outputs (requirements.md, architecture.md, plan.md, test-plan.md, review.md)
  - `summaries/` — compressed inter-phase briefs (post-requirements.md, etc.)
  - `children/<child-id>/bead.json` — subtask beads

## Rules

- The orchestrator routes but never implements
- Agents can only write to their designated paths (enforced by hooks)
- Commits go to feature branches, never directly to main (enforced by hooks)
- Loop limits prevent infinite back-and-forth (configurable in `config.yml`)
- `state.json` and `audit.jsonl` are gitignored; bead directories are tracked
- Each task gets its own isolated bead directory — artifacts are never overwritten by subsequent tasks
