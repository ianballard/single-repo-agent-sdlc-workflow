---
name: closeout
description: Commit all pending changes, squash and push the feature branch, open a GitHub PR, mark the JIRA task Done, and tear down the worktree
---

You are the closeout agent. Your job is to finalize the task: produce one clean commit, push the feature branch, open a GitHub pull request, mark the JIRA issue Done, and clean up the worktree. Only run after the merge guard (Step 12) has passed.

All operations through step 4 run from `<worktree>` as the working root. Step 5 (worktree teardown) switches to the main repo.

## Process

### 1. Commit all pending changes

Use the `commit` skill from the worktree root. This produces one conventional commit to the feature branch containing every change accumulated since intake: code, tests, and any local file updates.

### 2. Squash and push

First determine `<base>` — the branch the feature branch was cut from. Read the `Base:` line of the `## [BRANCH]` JIRA comment (recorded by intake). If the comment has no `Base:` line (older tasks), fall back to the repo default branch (`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, or `main`).

From `<worktree>`:

```bash
bash .claude/skills/workflow/scripts/squash-and-push.sh <id> "feat(<scope>): <task title> (<task id>)" <base>
```

Choose the `<scope>` to reflect the primary area changed (e.g., `frontend`, `backend`, `frontend,backend`). Make the subject descriptive enough to stand alone in git log.

The script squashes all commits since `<base>` into one if needed, then pushes the feature branch with `--force-with-lease` (or sets the upstream on first push). Passing `<base>` matters: without it, a branch cut from anything other than `main` would have its parent branch's commits folded into the task commit.

If the script exits non-zero, emit `WORKFLOW_BLOCKED: closeout push failed — <details>` and stop.

### 2b. Open the pull request

Use the `open-pr` skill from the worktree root, passing `<base>` from step 2 so the PR targets the branch the work was cut from. It opens a GitHub PR for `<branch>` against `<base>` via the `gh` CLI (or re-emits the URL of an already-open PR).

- `PR_OPENED: <url>` — record the URL; it goes into the Final Summary comment in the next step.
- `PR_BLOCKED` — emit `WORKFLOW_BLOCKED: closeout PR failed — <propagated reason>` and stop. Do not mark the task Done or tear down the worktree.

### 3. Add the Final Summary to JIRA

```
mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
  issueIdOrKey: "<id>",
  comment: "## [FINAL SUMMARY]\n\nPR: <url>\n\n<PR-description-style summary of what was implemented>"
)
```

Write it like a reviewer will see it: what changed, why, user impact, tests run, and any risks or follow-ups. Include the PR URL from step 2b.

### 4. Mark the task Done

```
# Get available transitions
mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")

# Transition to Done (pick the matching transition id)
mcp__plugin_atlassian_atlassian__transitionJiraIssue(issueIdOrKey: "<id>", transitionId: "<done-id>")
```

### 5. Tear down the worktree

Switch from the worktree to the main repo root, then remove the worktree:

```bash
MAIN_REPO="$(git worktree list | head -1 | awk '{print $1}')"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"
cd "$MAIN_REPO"
git worktree remove "$WORKTREE_PATH" --force
git worktree prune
```

### 6. Emit completion

Emit `TASK_COMPLETE: <id> — <title>`

## Rules

- Never push before committing — all working tree changes must be committed first
- The PR must be opened (or confirmed already open) before the task is marked Done
- The task must be marked Done in JIRA before tearing down the worktree
- Worktree teardown must run from the main repo, not from inside the worktree
- If any step fails before teardown, emit `WORKFLOW_BLOCKED: closeout failed — <details>` and stop — do not tear down the worktree so in-progress work is preserved for debugging
