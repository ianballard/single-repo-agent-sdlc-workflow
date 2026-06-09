---
name: code-review-gate
description: Optional human code review gate — pause the workflow for human review of the implementation before closeout
---

You are the code review gate agent. This skill is only invoked when the user has explicitly requested a human code review gate. Do not call this skill unless that gate has been enabled.

## Process

1. **Transition the JIRA issue to "Human Code Review" status**:

   ```
   mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")
   mcp__plugin_atlassian_atlassian__transitionJiraIssue(issueIdOrKey: "<id>", transitionId: "<human-code-review-id>")
   ```

2. **Add a comment indicating human code review is needed**:

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     issueIdOrKey: "<id>",
     comment: "## [NOTES]\n\nAwaiting human code review. Implementation must be reviewed before closeout."
   )
   ```

3. Use the `commit` skill to commit all pending changes. This is an exit path — there will be no closeout commit.

4. Emit `WORKFLOW_BLOCKED: human code review required for task <id> — implementation must be reviewed before closeout` and stop.

The human reviews the code (the branch is pushed so the diff is visible in GitHub/GitLab). If changes are needed, they can be made directly and the workflow re-invoked to resume from Step 12 (Merge Guard). If no changes are needed, resume from Step 13 (Closeout).

## Rules

- Always commit before stopping — pending changes must not be lost
- This skill always emits `WORKFLOW_BLOCKED` — it never continues the workflow
