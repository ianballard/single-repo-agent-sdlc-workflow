# Agent SDLC Workflow

A harness for running software development with an autonomous agent. It offers three lanes of operation — a full ticketed SDLC workflow, a plan-once/delegate-and-verify doctrine mode for large un-ticketed builds, and plain interactive sessions — so the ceremony matches the size of the work. See **[Ways to work in this repo](#ways-to-work-in-this-repo)** for how to choose.

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
backlog init
```

3. Set up the active issue tracker (JIRA by default): connect the Atlassian MCP plugin and make sure the project has these workflow statuses:
```
To Do, Intake, Intake Review, Plan, Plan Review, Code, AI Code Review, Human Code Review, Done
```
To use a different tracker, see the "Switching trackers" section of `docs/agents/issue-tracker.md`.

## Ways to work in this repo

There are three lanes. Pick the lightest one that fits — the point is to match the process overhead to the work, not to run every change through a lifecycle.

### 1. Interactive session — questions & small fixes

Just talk to the agent. No skill, no ticket, no PR automation: you drive turn by turn and review each change. This is the right lane for questions, exploration, one-off fixes, and anything small enough that a formal lifecycle would cost more than the change itself.

### 2. `workflow` skill — normal, tracked feature development

The main SDLC lane, for one tracked task at a time. Invoke the `workflow` skill and it runs the full 13-step lifecycle end-to-end: claim work → intake (branch) → plan (with adversarial plan review + a required human plan gate) → implement → verify acceptance criteria → unit & e2e tests → code review → audit → closeout (squash, push, open a PR, move the issue to Human Code Review). Use it for normal feature work that has — or should have — a tracker issue and needs the gates, audit trail, and PR hand-off. See `CLAUDE.md` and `.claude/skills/workflow/SKILL.md`.

### 3. Doctrine mode (`delegate-plan` → `delegate-execute`) — large / un-ticketed builds

For work with no ticket that would be smothered by per-task ticketing and the 13-step lifecycle — especially large or greenfield builds. Two invocations:

- **`delegate-plan`** (invocation 1) does all the judgment-dense thinking up front: brainstorm → PRD → `spec.md` with a **pre-committed Definition of Done** → `plan.md`, all committed to `docs/specs/YYYY-MM-DD-<slug>/`. The human reviews the artifacts.
- **`delegate-execute`** (invocation 2) delegates the plan to subagents, **verifies every deliverable against the pre-committed DoD itself** (never the subagent's self-report), halts at `[HUMAN-GATED]` checkpoints, and closes out. Plan once, delegate and verify, land as one PR.

Its own triage scales down — genuinely trivial un-ticketed changes it just does inline — so doctrine mode is really *the un-ticketed lane*, with large greenfield builds as the headline use.

### Choosing a lane

| Your situation | Lane |
| --- | --- |
| A question, or a small self-contained fix | Interactive session |
| A normal feature that has (or should have) a tracker issue | `workflow` skill |
| An un-ticketed build big enough to want a written contract before code | Doctrine mode (`delegate-plan` → `delegate-execute`) |

The precise routing signal is **ticketed vs un-ticketed**: ticketed work goes through `workflow`; un-ticketed work goes through doctrine mode (which drops to inline for trivial changes). Size is just the everyday proxy — you reach for doctrine mode when the build is large.
