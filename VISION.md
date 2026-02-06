# Claude-beads

Claude-beads is an agentic task management workflow for Claude Code. It provides a structured, multi-agent coding workflow that uses subagents for every phase of development — from requirements capture through validation — with explicit user checkpoints and bounded iteration loops.

## Design Principles

- **Orchestrator as router, not worker.** The main agent reads task metadata (status, current phase, open questions) to make routing decisions, but never performs implementation work itself.
- **Bounded loops.** Any back-and-forth between agents is capped (default: 3 rounds) before escalating to the user.
- **Explicit user gates.** The user approves at defined checkpoints rather than only at the start.
- **Structured handoffs.** Each agent produces a named artifact attached to the bead. Downstream agents read defined inputs, not the full conversation history.
- **Enforced via hooks.** Workflow transitions and file ownership are enforced through Claude Code hooks.

## Inspirations and Dependencies

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) — core execution model
- [Beads](https://github.com/steveyegge/beads) — task management and state tracking
- [better-context](https://github.com/davis7dotsh/better-context) — inspiration for agentic doc search (not used directly)

## Workflow Overview

```
User
 → Analyst (requirements capture with user Q&A)
 → [User approves requirements]
 → Architect (technical spec)
 → [Resolve with Analyst or escalate to user, max 2 rounds]
 → [User approves architecture]
 → Manager (subtask breakdown, dependency graph, branch creation)
 → [User approves plan]
 → Test-engineer (writes tests per spec)
 → Developer (implements, must pass tests)
 → Validator (code review + functional QA)
 → [Issues? → Developer, max 3 rounds, then escalate to user]
 → [User final review]
```

## Subagents

### Orchestrator

The main Claude Code agent. It controls workflow state and routes between subagents.

**Responsibilities:**

- Read bead task metadata: current phase, status, open questions, iteration count
- Advance tasks to the next subagent when phase criteria are met
- Route tasks backward when a subagent raises questions (within loop limits)
- Escalate to user when loop limits are reached or on error
- Invoke the Summarizer between phases to compress context for downstream agents

**Does not:** perform any task-specific analysis, write code, or make architectural decisions.

### Documentation

An internal utility subagent available to all other subagents. Provides agentic search over technology documentation relevant to the project stack.

**Approach:**

- Maintain a project-level config file (e.g., `.claude-beads/docs.yml`) that maps stack technologies to curated doc sources, example repos, and known reference paths
- Perform targeted fetches and searches against these sources on demand rather than bulk-cloning entire doc repositories
- Pre-populated templates for common stacks (Svelte, React, Next.js, etc.) with known doc structures
- Cache fetched docs locally for the duration of the task

**Invoked by:** any subagent that needs technology-specific reference material.

### Analyst

Captures and refines product requirements through direct user interaction.

**Input:** user's initial request
**Tools:** `AskUserQuestion` for interactive requirements gathering
**Behavior:**

- Challenge vague requirements — ask about edge cases, scope boundaries, success criteria
- Produce structured requirements, not freeform prose
- If revisited due to Architect or Manager questions, refine the relevant sections and note what changed

**Output artifact:** `requirements.md` attached to bead

### Architect

Translates product requirements into a technical specification.

**Input:** `requirements.md` from Analyst
**Behavior:**

- Analyze requirements and produce architecture decisions: component structure, data flow, API boundaries, technology choices
- Use Documentation agent to verify assumptions about the stack
- If requirements are ambiguous, post clarification questions as bead comments and hand back to Analyst (max 2 rounds, then escalate to user)

**Output artifact:** `architecture.md` attached to bead

### Manager

Breaks the technical specification into implementable subtasks with dependencies.

**Input:** `requirements.md` + `architecture.md`
**Behavior:**

- Produce a dependency graph and rough scope estimate for user approval before creating subtasks
- Create subtask beads with explicit dependencies between them
- Post clarification questions to Architect/Analyst via bead comments if needed (max 2 rounds)
- Create a feature branch from main once the user approves the plan
- Subtasks are sequential commits on the feature branch (not sub-branches), unless explicitly parallelizable

**Output artifact:** subtask beads with dependencies + `plan.md` summarizing the breakdown

### Test-engineer

Writes tests according to the approved specifications before implementation begins.

**Input:** `requirements.md` + `architecture.md` + subtask beads
**Behavior:**

- Write tests that cover the acceptance criteria from requirements and the contracts from architecture
- Commit test files to the feature branch
- Tests should be structured so the Developer can run them incrementally per subtask

**Output artifact:** test files + `test-plan.md` attached to bead

### Developer

Implements subtasks in order on the feature branch.

**Input:** `requirements.md` + `architecture.md` + subtask beads + test files
**Behavior:**

- Implement each subtask, committing after each is complete
- Must make all existing tests pass
- **Cannot modify test files** — but can flag a specific test as "contested" with a written rationale, which routes back to Test-engineer for resolution
- Use Documentation agent as needed for implementation reference
- Open a pull request after all subtasks are complete

**Output artifact:** code commits + PR reference attached to bead

### Validator

Combined code review and functional QA (replaces separate Code-reviewer and QA-engineer to avoid redundant overlap).

**Input:** `requirements.md` + `architecture.md` + `test-plan.md` + PR diff
**Behavior — two passes:**

1. **Code quality pass:** review for patterns, security, performance, maintainability, adherence to architecture spec
2. **Functional correctness pass:** verify implementation against product requirements, check edge cases, confirm test coverage is adequate

- Creates issues on the bead for any problems found
- If issues exist, task routes back to Developer (max 3 rounds, then escalate to user)
- If clean, task advances to user final review

**Output artifact:** `review.md` with pass/fail status and issue list

### Summarizer

A lightweight subagent invoked by the Orchestrator between phases.

**Purpose:** compress the outgoing agent's output into a concise brief for the next agent. Prevents context bloat — downstream agents receive the final agreed artifact plus a summary, not the full negotiation history.

## Context Handoff Protocol

Each agent reads only its defined inputs and produces a named artifact. The chain of artifacts forms the source of truth:

| Phase | Agent | Reads | Produces |
|-------|-------|-------|----------|
| Requirements | Analyst | User input | `requirements.md` |
| Architecture | Architect | `requirements.md` | `architecture.md` |
| Planning | Manager | `requirements.md` + `architecture.md` | subtask beads + `plan.md` |
| Testing | Test-engineer | all specs + subtask beads | test files + `test-plan.md` |
| Implementation | Developer | all specs + tests + subtask beads | code commits + PR |
| Validation | Validator | all specs + `test-plan.md` + PR diff | `review.md` |

Agents communicate questions via bead comments, not by modifying each other's artifacts.

## User Checkpoints

The user is prompted for explicit approval at these gates:

1. **Post-requirements** — approve `requirements.md` before architecture begins
2. **Post-architecture** — approve `architecture.md` before planning begins
3. **Post-planning** — approve `plan.md` and subtask breakdown before implementation begins
4. **Final review** — review PR and `review.md` before merge

The user can reject at any gate, adding comments that feed back into the relevant agent.

## Loop Limits and Escalation

| Loop | Max rounds | On limit reached |
|------|-----------|-----------------|
| Analyst ↔ Architect | 2 | Escalate to user with both perspectives |
| Analyst/Architect ↔ Manager | 2 | Escalate to user with open questions |
| Developer ↔ Validator | 3 | Escalate to user with issue list |
| Developer → Test-engineer (contested test) | 1 | Test-engineer rules or escalates to user |

## Hook Enforcement

Claude Code hooks enforce workflow integrity:

- **File ownership:** Developer cannot modify test files; Test-engineer cannot modify source files
- **Phase gating:** agents cannot produce output for a phase until the previous phase's artifact exists and is approved
- **Commit validation:** commits must be associated with the current active subtask bead
- **Branch policy:** all work happens on the feature branch; no direct commits to main

## Error Recovery

- **Agent failure (token limits, malformed output, crash):** Orchestrator retries once, then escalates to user with the failure context
- **Stuck loops:** tracked by iteration counter on the bead; automatic escalation at limit
- **Partial progress:** all artifacts and commits are persisted to the bead, so work is never lost even if a phase fails midway

## Project Configuration

```yaml
# .claude-beads/config.yml
stack:
  - name: svelte
    docs: https://svelte.dev/docs
    examples: https://github.com/sveltejs/examples
  - name: tailwind
    docs: https://tailwindcss.com/docs

workflow:
  loop_limits:
    analyst_architect: 2
    analyst_manager: 2
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
