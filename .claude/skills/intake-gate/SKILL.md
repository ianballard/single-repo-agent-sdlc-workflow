---
name: intake-gate
description: Optional human intake approval gate — pause the workflow for human review of the task definition before planning begins
---

You are the intake gate agent. This skill is only invoked when the user has explicitly requested a human intake approval gate. Do not call this skill unless that gate has been enabled.

## Process

1. **Update the JIRA issue to signal it is awaiting human review:**

   ```
   # Get available transitions (look for one closest to "In Review" or keep "In Progress")
   mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")
   
   # Update the label to "intake-review"
   mcp__plugin_atlassian_atlassian__editJiraIssue(
     issueIdOrKey: "<id>",
     labels: ["intake-review"]
   )
   ```

2. **Add a comment indicating human review is needed:**

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     issueIdOrKey: "<id>",
     comment: "## [NOTES]\n\nAwaiting human intake review. Task definition must be approved before planning begins."
   )
   ```

3. Use the `commit` skill to commit all pending changes. This is an exit path — there will be no closeout commit.

4. Emit `WORKFLOW_BLOCKED: intake review required for task <id> — task definition must be approved before planning begins` and stop.

The human reviews the task definition in JIRA. If changes are needed, they update the issue directly. When ready, they re-invoke the workflow to resume from Step 4 (Plan the task).

## Rules

- Always commit before stopping — pending changes must not be lost
- This skill always emits `WORKFLOW_BLOCKED` — it never continues the workflow
