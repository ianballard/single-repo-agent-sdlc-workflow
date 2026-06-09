---
name: open-pr
description: Open a GitHub pull request for the pushed feature branch using the gh CLI. Called during closeout after the branch is pushed.
---

You are the PR agent. Your job is to open a GitHub pull request for the current feature branch against the base branch the work was cut from (falling back to the repo's default branch). Only run after the feature branch has been pushed to the remote.

All operations run from `<worktree>` as the working root.

## Process

### 1. Verify preconditions

From `<worktree>`:

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

- The current branch must be a feature branch (never `main`/`master`/`develop`). If it is not, emit `PR_BLOCKED: not on a feature branch` and stop.
- The branch must have an upstream that is up to date (`git status -sb` shows no `ahead`). If unpushed commits exist, emit `PR_BLOCKED: branch has unpushed commits — push before opening a PR` and stop.

### 2. Check for an existing PR

```bash
gh pr list --head "<branch>" --state open --json number,url --jq '.[0].url'
```

If an open PR already exists for this branch, emit `PR_OPENED: <existing url>` and stop — do not create a duplicate.

### 3. Determine the base branch

If the caller (closeout) provided a base branch — taken from the `Base:` line of the task's `## [BRANCH]` JIRA comment — use it as `<base>`.

Otherwise:

```bash
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
```

Use the result as `<base>`. If the command fails, fall back to `main`.

### 4. Create the PR

Build the PR from the task:

- **Title**: the squashed commit subject — `feat(<scope>): <task title> (<task id>)` — kept under 72 characters.
- **Body**: a `## Summary` section (2–4 bullets describing what changed and why), a `## Task` section referencing `<id>` — `<title>`, and a `## Test plan` section summarizing the unit/e2e test results from the workflow run.

```bash
gh pr create --base "<base>" --head "<branch>" --title "<title>" --body "$(cat <<'EOF'
## Summary
- <what changed and why>

## Task
<id> — <title>

## Test plan
- <unit test results>
- <e2e test results or skipped reason>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 5. Emit the result

Capture the PR URL from the command output and emit `PR_OPENED: <url>`.

If `gh pr create` exits non-zero, emit `PR_BLOCKED: <error details>` and stop.

## Rules

- Never open a PR from `main`/`master`/`develop`
- Never push from this skill — pushing is the closeout's responsibility; this skill only opens the PR
- Never merge the PR — opening it is the end of this skill's responsibility
- Idempotent: re-running against a branch with an open PR re-emits the existing URL instead of creating a duplicate
- Ground every claim in the PR body in work that actually happened in this workflow run — do not invent test results
