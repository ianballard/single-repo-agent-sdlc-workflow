# CLAUDE.md

## Repo Architecture

This is a mono-repo. All project areas are top-level subdirectories:

- **frontend/** — React 18+ with TypeScript, Vite, and Vitest
- **backend/** — FastAPI with Python 3.11+
- **e2e/** — Playwright end-to-end tests

All commits and branches live in this single git repo. Never reference a separate "coordination repo" or `projects/` directory — those concepts do not apply.

## Task Management

Tasks are managed through the tracker-agnostic contract in `docs/agents/issue-tracker.md` (capability verbs, workflow-phase vocabulary, comment-marker schema), implemented by the `manage-backlog-tasks` skill's per-tracker adapters. **JIRA is the active adapter** — task IDs are JIRA issue keys (e.g., `PROJ-42`) today, but the tracker is swappable: see the contract's "Switching trackers" section.

## SDLC Workflow System

The `.claude/skills/` directory contains custom Claude Code skills that implement a full SDLC automation workflow:

**Primary Skill:**
- **workflow** - The main end-to-end coordinator. Use when the user asks to coordinate a task. Claims work from JIRA, runs intake, plans, implements, tests, reviews, and closes out tasks autonomously.

**Component Skills** (called by workflow):
- **check-for-work** - Claims tasks from JIRA by issue key or priority
- **intake** - Creates the feature branch, transitions the JIRA issue to Intake, and assigns it to the current user
- **setup-worktree** - Creates a git worktree at `.claude/worktrees/<branch>` so all task work is branch-isolated
- **assess-task** - Evaluates whether a JIRA task is sufficiently well-defined to implement
- **intake-gate** - Optional human intake approval gate (Step 3b)
- **plan-task** - Writes a thorough high-level implementation plan (stored as JIRA comment)
- **hostile-plan-review** - Adversarially stress-tests the plan before coding begins
- **plan-gate** - Required human planning approval gate (Step 4b)
- **implement** - Writes production-grade code following the implementation plan
- **verify-ac** - Verifies every acceptance criterion is met and marks them complete in JIRA description
- **unit-tests** - Creates/updates and runs unit tests
- **e2e-tests** - Runs Playwright end-to-end tests
- **lint-format** - Auto-formats and lints changed code (Prettier/ESLint for frontend & e2e, Ruff for backend), fixing what's fixable, before code review
- **implementation-notes** - Documents implementation details as JIRA comments
- **code-review** - Performs comprehensive code quality review
- **code-review-gate** - Optional human code review gate (Step 10b)
- **audit-followed-workflow-steps** - Verifies all workflow steps completed (reads JIRA comments/labels)
- **self-improvement** - Reflects on execution and emits process improvement recommendations
- **merge-guard** - Verifies branch changes are within the task's declared scope
- **open-pr** - Opens a GitHub pull request for the pushed feature branch via the `gh` CLI (invoked by closeout)
- **closeout** - Commits, squashes, pushes, opens the PR, and moves the task to Human Code Review
- **commit** - Creates conventional commit messages
- **manage-backlog-tasks** - Implements the issue-tracker contract; holds per-tracker adapters

The workflow skill enforces a strict process (see `.claude/skills/workflow/SKILL.md`):
1. Check for work → 2. Run intake (create branch) → 2b. Set up worktree → 3. Assess task definition → 3b. Optional human intake review → 4. Plan the task → 4a. AI hostile plan review → 4b. Human plan review (required) → 5. Implement changes → 6. Verify acceptance criteria → 7. Unit tests → 8. E2E tests → 8b. Lint & format → 9. Write implementation notes → 10. AI code review → 10b. Optional human code review → 11. Audit all steps → 11b. Self-improvement recommendation → 12. Merge guard (scope check) → 13. Closeout (squash, push, open GitHub PR, move to Human Code Review, tear down worktree)

**Key workflow behaviors:**
- All task reads and writes use the tracker contract verbs via the `manage-backlog-tasks` skill's active adapter
- The tracker issue key is the `<id>` throughout the workflow (e.g., `PROJ-42` under the current JIRA adapter)
- JIRA status lifecycle: `To Do → Intake → Plan → Code → AI Code Review → Human Code Review → Done` (optional earlier gate: `Intake Review`; `Plan Review` is the status used by the required plan gate). `Human Code Review` is also closeout's mandatory hand-off state — `Done` is always a human-only transition, made after reviewing the PR
- Uses gitflow branch naming: `feature/<issue-key>-description`, `fix/<issue-key>-description`, etc.
- Commits at closeout only (not between steps) — all changes accumulate in worktree
- Merge guard (Step 12) runs **before** closeout hands off for human review — compares the **working tree** (uncommitted changes since base, since commits are deferred to Step 13) against the plan's `### Files in scope` section plus any `## [SCOPE CHANGE]` comments to detect scope creep
- Closeout (Step 13) never marks the task Done. It moves the issue to Human Code Review after the PR is opened; a human reviews the PR and transitions the issue to Done themselves.
- Retries are bounded: AC verification, unit tests, e2e tests, lint/format, hostile plan review max 2 retries each; code review max 1 fix iteration. Counters are cumulative per run (never reset), and a global ceiling of 6 total returns to implementation blocks a thrashing task
- Emits `TASK_COMPLETE: <id> — <title>` on success or `WORKFLOW_BLOCKED: <reason>` on failure

## Working with the Workflow

When the user says "coordinate a task" or wants full SDLC automation, invoke the `workflow` skill. It will handle the entire lifecycle autonomously. The workflow operates on one task at a time. Intake starts from the base branch (`develop`) and cuts the feature branch itself; from the worktree onward every step runs on that feature branch, and the merge guard refuses to run on main/master/develop/staging.

The default/base branch that feature branches are cut from (and diffed, reviewed, and PR'd against, absent an explicit `Base:` override recorded at intake) is `develop`.

For manual operations, use individual skills like `unit-tests`, `e2e-tests`, `commit`, etc. or interact directly with JIRA via the MCP tools.

## Infrastructure & Cloud Guardrails

These rules are policy, and are also mechanically enforced as `deny`/`ask` permission rules in `.claude/settings.json` — they are not just documentation to follow, they block the tool call.

- **Never run `terraform apply` or `terraform destroy`.** Infrastructure changes are applied by a human (or CI) outside of an agent session, after review. If a task seems to require one, stop and hand it to a human instead of finding a workaround.
- **Never run an AWS CLI command that isn't read-only.** Only `describe-*`, `get-*`, `list-*`, `head-*`, `aws s3 ls`, and `aws sts get-caller-identity` are allowed to run automatically. Any mutating verb (`create-*`, `delete-*`, `put-*`, `update-*`, `modify-*`, `run-*`, `start-*`, `stop-*`, `terminate-*`, `attach-*`, `tag-*`, `invoke-*`, `publish-*`, `send-*`, `execute-*`, `assume-*`, `copy-*`, `import-*`, `aws s3 rm/mv/sync/cp`, `aws configure`, etc.) is denied outright. Anything not explicitly allowed or denied still requires interactive human approval before it runs — it is never silently executed.
- **Never run `cdk deploy` or `cdk destroy`.** Same reasoning as Terraform apply/destroy — these mutate live infrastructure and must go through human/CI review, not an agent session.
- **Never force-push** (`git push --force`, `git push -f`). Rewriting shared branch history is a human decision, especially on a repo where audit trail and history integrity matter.
- **Never run `rm -rf /*`** or any other wipe-the-filesystem command.
- **Never edit or write `.claude/settings*` files.** Permission configuration is self-protecting — an agent session must not be able to loosen its own guardrails. Changes to `.claude/settings.json` are a human-only action.
- This mirrors the "no custody, no destructive infra changes without a human" posture the platform needs for SOC 2 credibility with CDFIs, banks, and regulators — see the org-level security posture for the broader rationale.

## Branch Protection

- **Never push directly to `main`, `develop`, `staging`, or `master`.** These are trunk/environment branches; all changes land through a pull request opened against the appropriate base (see `open-pr` skill), never a direct push. This is intended to be mechanically enforced as `deny` rules on `git push` to these branches in `.claude/settings.json`, same posture as the other guardrails above.

## Agent skills

### Issue tracker

Issues are tracked via the tracker contract (issue keys like `KAN-42` under the current JIRA adapter). See `docs/agents/issue-tracker.md`.

### Triage labels

Triage roles map to JIRA statuses, not labels (`Triage`, `Needs Info`, `To Do`, `Ready for Human`, `Done`/Won't Do). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
