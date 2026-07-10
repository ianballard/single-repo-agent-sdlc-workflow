# Agent SDLC Workflow

A harness for running an end-to-end software development lifecycle (SDLC) workflow with an autonomous agent. The agent claims tracker tasks, runs intake, plans and implements changes, runs tests and reviews, and closes out work.

## Architecture

This is a mono-repo. The project areas live as top-level subdirectories:

- **frontend/** — React + TypeScript (Vite, Vitest)
- **backend/** — FastAPI (Python 3.11+)
- **e2e/** — Playwright end-to-end tests

Task tracking is external, not a directory in this repo. The agent speaks a tracker-agnostic **capability contract** (`docs/agents/issue-tracker.md`) — capability verbs, a workflow-phase vocabulary, and a comment-marker schema — realized by a per-tracker **adapter** under `.claude/skills/manage-backlog-tasks/adapters/`. The active adapter today is `jira.md`; `github.md` and `backlog.md` are example/legacy adapters proving the contract is swappable.

## Getting Started

1. Clone this repo:
   ```bash
   git clone <repo-url> <project-folder>
   cd <project-folder>
   ```

2. Create subdirectories for any role that doesn't exist yet:
   ```bash
   mkdir -p frontend backend e2e
   ```
   If you're activating the `backlog.md` adapter instead of JIRA, also create and initialize a local task store:
   ```bash
   mkdir -p backlog
   cd backlog && backlog init && cd ..
   ```

3. Set up the active issue tracker (JIRA by default): connect the Atlassian MCP plugin and make sure the project has these workflow statuses:
   ```
   To Do, Intake, Intake Review, Plan, Plan Review, Code, AI Code Review, Human Code Review, Done
   ```
   To use a different tracker, see the "Switching trackers" section of `docs/agents/issue-tracker.md`.

## Workflow

When you want the agent to coordinate a task end-to-end, invoke the `workflow` skill. It runs the full 13-step lifecycle: claim work → intake → plan → implement → test → review → close out. See `CLAUDE.md` and `.claude/skills/workflow/SKILL.md` for details.
