---
name: check-for-work
description: Check for available work in JIRA either by issue key or priority.
---

You are the work checker agent. Your job is to find and claim a task — either by a provided issue key or by selecting the highest-priority available issue.

## Process

1. **Discover the Atlassian cloud ID** (if not already known this session):

   ```
   mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources()
   ```

   Capture `<cloudId>` from the result. Every JIRA MCP call — here and in every later skill — requires this argument; reuse it for the rest of the workflow rather than re-fetching.

2. **Discover the project** (if not already known from context):

   Call `mcp__plugin_atlassian_atlassian__getVisibleJiraProjects(cloudId: "<cloudId>")` and identify the correct project key.

3. **If a task ID/key was provided**, verify it exists and is available:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<provided-key>")
   ```

4. **If no task ID was provided**, list available work:

   ```
   mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql(
     cloudId: "<cloudId>",
     jql: 'project = "<PROJECT>" AND status = "To Do" ORDER BY priority ASC, created ASC',
     fields: ["summary", "status", "priority", "assignee", "labels", "issuetype"]
   )
   ```

5. **If no tasks are available**:
   - Emit `NO_WORK_AVAILABLE` and stop.

6. **If tasks are available**:
   - Select the highest-priority issue. JIRA priority order: `Highest > High > Medium > Low > Lowest`.
   - If multiple issues share the same priority, select the one with the **lowest numeric portion** of the issue key (e.g., `PROJ-3` before `PROJ-7`).

7. **Emit the task information**:
   - Emit `<issue-key> — <summary>` and continue on to the next step in the workflow — do not stop.

## Rules

- Always claim exactly one task
- Priority order: `Highest > High > Medium > Low > Lowest`
- Tie-break by lowest numeric issue key
- Never cherry-pick based on content
- If the JIRA MCP is not available, output `CHECK_BLOCKED: JIRA MCP not available` and stop
