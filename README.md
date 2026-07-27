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

4. Activate the git-level guardrails. **This is required once per clone** — `.git/hooks/` is not versioned, so the hooks are committed to `.githooks/` and only run once `core.hooksPath` points at them:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

This turns on three hooks that run inside git, and so catch what a command-string permission rule structurally cannot:

- **`pre-push`** — refuses pushes whose *resolved refspec* targets `main`/`master`/`develop`/`staging`/`production`. This is the only layer that catches `git push origin HEAD:develop`, which no `git push origin develop*` pattern matches.
- **`pre-commit`** — refuses staged secret files and scans staged content. Matters most because the workflow commits once at closeout with `git add -A`, exactly when an untracked `.env` gets swept in.
- **`commit-msg`** — validates conventional-commit format.

Note the ordering: an agent session cannot run the command above for you, because `git config core.hooksPath*` is a denied operation — a guardrail an agent could install is one it could also remove.

5. Install `gitleaks` (recommended):

```bash
brew install gitleaks
```

`pre-commit` uses it for entropy-and-context secret scanning when present, and falls back to a weaker self-contained pattern scan when it isn't — so the hook has no hard dependency, but it is meaningfully better with it. It is also the layer that catches low-entropy secrets (a human-chosen password), which the pattern-based hooks deliberately do not attempt.

Guardrail mechanics, the full rule inventory, and known gaps are documented in `docs/agents/claude-code-guardrails.md`; the policy they enforce is in `CLAUDE.md`.

## Ways to work in this repo

There are three lanes. Pick the best one that fits — the point is to match the process to the work.

### 1. Interactive session — questions & small fixes

Just talk to the agent. No skill, no ticket, no PR automation: you drive turn by turn and review each change. This is the right lane for questions, exploration, one-off fixes, and anything small enough that a formal lifecycle would cost more than the change itself.

### 2. `workflow` skill — normal, tracked feature development

The main SDLC lane, for one tracked task at a time. Invoke the `workflow` skill and it runs the full 13-step lifecycle end-to-end: claim work → intake (branch) → plan (with adversarial plan review + a required human plan gate) → implement → verify acceptance criteria → unit & e2e tests → code review → audit → closeout (squash, push, open a PR, move the issue to Human Code Review). Use it for normal feature work that has — or should have — a tracker issue and needs the gates, audit trail, and PR hand-off. See `CLAUDE.md` and `.claude/skills/workflow/SKILL.md`.

### 3. Doctrine mode (`delegate-plan` → `delegate-execute`) — large / un-ticketed builds

For work with no ticket that would be smothered by per-task ticketing and the 13-step lifecycle — especially large or greenfield builds. Two invocations:

- **`delegate-plan`** (invocation 1) does all the judgment-dense thinking up front: brainstorm → PRD → `spec.md` with a **pre-committed Definition of Done** → `plan.md` → an **independent red-team stress test** of all three, all committed to `docs/specs/YYYY-MM-DD-<slug>/`. The human reviews the artifacts.
  - The stress test (`red-team-plan`) runs as a fresh subagent given only the artifact paths, never the planning conversation — a planner reviewing its own plan shares every assumption that produced it. It asks two questions, and either can block. **Is the solution sound?** — build vs. buy (is something being hand-rolled that a library already solves), technology fitness, versions checked against the real manifests, conflicts with an accepted ADR, a simpler alternative, scale and failure characteristics. **Is the contract real?** — a Definition of Done a mock could satisfy would let execution report green without building the thing.
- **`delegate-execute`** (invocation 2) delegates the plan to subagents, **verifies every deliverable against the pre-committed DoD itself** (never the subagent's self-report), halts at `[HUMAN-GATED]` checkpoints, and closes out. Plan once, delegate and verify, land as one PR.