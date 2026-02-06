# claude-beads

A structured, multi-agent development workflow for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop the `.claude/` directory into any project to get a full requirements-to-review pipeline powered by specialized subagents.

## How it works

When you run `/beads <task description>`, the orchestrator guides your task through six phases, each handled by a dedicated subagent:

```
User request
 → Analyst        (captures requirements via Q&A)
 → [User approves requirements]
 → Architect      (produces technical specification)
 → [User approves architecture]
 → Manager        (breaks spec into subtasks, creates feature branch)
 → [User approves plan]
 → Test-engineer  (writes tests before implementation)
 → Developer      (implements subtasks, must pass tests)
 → Validator      (code review + functional QA)
 → [User final review]
```

Each phase produces a named artifact (`requirements.md`, `architecture.md`, etc.) stored in the task's own bead directory. Agents communicate through these artifacts, not conversation history. Each task is fully isolated — starting a new `/beads` workflow creates a fresh bead directory so previous artifacts are never overwritten.

## Setup

### 1. Copy into your project

```bash
cp -r /path/to/claude-beads/.claude /path/to/your-project/
```

### 2. Initialize

Open Claude Code in your project and run:

```
/beads-init
```

This detects your tech stack, creates the `.claude-beads/` working directory, and writes a `config.yml`. You can also pass your stack explicitly:

```
/beads-init svelte tailwind
```

### 3. Start a workflow

```
/beads implement user authentication with OAuth
```

The orchestrator takes it from there.

## What's included

```
.claude/
├── agents/
│   ├── analyst.md          # Requirements capture
│   ├── architect.md        # Technical specification
│   ├── manager.md          # Subtask breakdown + branch creation
│   ├── test-engineer.md    # Test-first development
│   ├── developer.md        # Implementation
│   ├── validator.md        # Code review + QA
│   └── summarizer.md       # Context compression between phases
├── skills/
│   ├── beads/SKILL.md      # Orchestrator (/beads command)
│   ├── beads-init/SKILL.md # Project setup (/beads-init command)
│   ├── beads-viz/SKILL.md  # HTML dashboard (/beads-viz command)
│   └── doc-search/SKILL.md # Tech doc search (preloaded into agents)
├── hooks/
│   ├── enforce-file-ownership.sh
│   └── enforce-branch-policy.sh
├── scripts/
│   └── generate-viz.sh     # Static HTML dashboard generator
└── settings.json           # Global hook wiring
```

Each `/beads` invocation creates an isolated bead directory:

```
.claude-beads/
├── config.yml                          # Tech stack + workflow settings
├── state.json                          # Current workflow state (gitignored)
├── audit.jsonl                         # Event log (gitignored)
└── beads/
    └── beads-20250206-001/             # One directory per task
        ├── bead.json                   # Root bead metadata
        ├── artifacts/
        │   ├── requirements.md
        │   ├── architecture.md
        │   ├── plan.md
        │   ├── test-plan.md
        │   └── review.md
        ├── summaries/
        │   ├── post-requirements.md
        │   ├── post-architecture.md
        │   └── post-planning.md
        └── children/
            ├── beads-20250206-001-sub-01/
            │   └── bead.json
            └── beads-20250206-001-sub-02/
                └── bead.json
```

## Guardrails

**File ownership** — Each agent can only write to its designated paths. The Developer cannot modify test files; the Test-engineer cannot modify source files. Enforced by hooks.

**Branch policy** — Commits are blocked on `main`/`master`. All work happens on feature branches (`beads/{task-id}/{description}`).

**Bounded loops** — Back-and-forth between agents is capped (Analyst ↔ Architect: 2 rounds, Developer ↔ Validator: 3 rounds). When limits are reached, the user is asked to resolve.

**User checkpoints** — You approve at four gates: post-requirements, post-architecture, post-planning, and final review. Nothing advances without your sign-off.

**Bead isolation** — Each task gets its own directory under `.claude-beads/beads/`. Artifacts, summaries, and subtask beads are scoped to that directory. Starting a new workflow never overwrites previous work.

## Configuration

After running `/beads-init`, edit `.claude-beads/config.yml`:

```yaml
stack:
  - name: svelte
    docs: https://svelte.dev/docs
  - name: tailwind
    docs: https://tailwindcss.com/docs

workflow:
  loop_limits:
    analyst_architect: 2      # Max rounds before escalating to user
    developer_validator: 3
  user_checkpoints:
    - post-requirements
    - post-architecture
    - post-planning
    - final-review

branch:
  strategy: feature-branch
  naming: "beads/{task-id}/{short-description}"
```

## Git policy

| Path | Tracked | Reason |
|------|---------|--------|
| `.claude-beads/beads/*/` | Yes | Bead directories with artifacts, summaries, subtasks |
| `.claude-beads/config.yml` | Yes | Project configuration |
| `.claude-beads/state.json` | No | Volatile session state |
| `.claude-beads/audit.jsonl` | No | Volatile event log |

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `jq` (used by hook scripts)
- `gh` CLI (used by the Developer agent to open PRs and Validator to publish reviews)
