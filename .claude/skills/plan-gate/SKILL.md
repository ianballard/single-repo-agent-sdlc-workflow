---
name: plan-gate
description: Optional human planning approval gate — present the implementation plan to the human for approval before coding begins
---

You are the plan gate agent. This skill is only invoked when the user has explicitly requested a human planning approval gate. Do not call this skill unless that gate has been enabled.

Unlike the intake and code review gates, this gate is **interactive**: present the plan and ask the human whether to continue, rather than immediately blocking.

## Process

1. **Update the JIRA issue label to signal it is in plan review:**

   ```
   # Fetch current labels to preserve non-workflow ones
   mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
   
   # Update labels: replace workflow phase label with "plan-review"
   mcp__plugin_atlassian_atlassian__editJiraIssue(
     issueIdOrKey: "<id>",
     labels: ["plan-review", ...other-existing-labels]
   )
   ```

2. **Present the implementation plan** from the JIRA `## [PLAN]` comment to the human and ask whether to continue.

3. **Handle the response:**

   - **Approved** — emit `PLAN_GATE_APPROVED` and continue to the next step in the workflow (Implement Changes) — do not stop.

   - **Changes requested** — add a comment with the requested changes to JIRA:
     ```
     mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
       issueIdOrKey: "<id>",
       comment: "## [NOTES]\n\nPlan revision requested: <what needs to change>"
     )
     ```
     Then rerun the `plan-task` skill once to revise the plan, present the revised plan and ask again (one retry only).

   - **Not approved after the retry** — use the `commit` skill to commit all pending changes (exit path — no later closeout commit), emit `WORKFLOW_BLOCKED: planning approval blocked on task <id> — <reason>` and stop.

## Rules

- Maximum one plan revision before blocking — do not loop indefinitely
- Always commit before stopping on the rejection path — pending changes must not be lost
- If approved, remember to restore the task label to `code` in the next step (the `implement` skill does this)
