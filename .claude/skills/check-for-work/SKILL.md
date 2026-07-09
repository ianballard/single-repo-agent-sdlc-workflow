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

2b. **Discover the "Flagged" field and the "Blocks" link type** (once per session/run — reuse for the rest of this step and later steps that need them):

   ```
   mcp__plugin_atlassian_atlassian__getIssueLinkTypes(cloudId: "<cloudId>")
   ```

   Find the entry whose `inward` phrase is `"is blocked by"` (typically named `Blocks`). Capture its `id` as `<blocksLinkTypeId>`. If no such link type exists on this site, skip the blocked-issue check entirely (treat nothing as blocked).

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssueTypeMetaWithFields(cloudId: "<cloudId>", projectIdOrKey: "<PROJECT>", issueTypeId: "<any-issue-type-id-in-this-project>", requiredFieldsOnly: false)
   ```

   Find the field whose `name` is `Flagged` (a checkboxes custom field, e.g. `customfield_10021`). Capture its `key` as `<flaggedFieldKey>`. If no such field exists in this project, skip the flagged check entirely (treat nothing as flagged).

3. **If a task ID/key was provided**, verify it exists and is available:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<provided-key>", fields: ["summary", "status", "priority", "issuelinks", "<flaggedFieldKey>"])
   ```

   Run the **Flagged / Blocked check** (below) against it. If it is flagged or blocked by an unresolved issue, emit `CHECK_BLOCKED: <reason>` and stop — an explicitly requested task is never silently swapped for another one.

4. **If no task ID was provided**, list available work:

   ```
   mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql(
     cloudId: "<cloudId>",
     jql: 'project = "<PROJECT>" AND status = "To Do" ORDER BY priority ASC, created ASC',
     fields: ["summary", "status", "priority", "assignee", "labels", "issuetype", "issuelinks", "<flaggedFieldKey>"]
   )
   ```

5. **If no tasks are available**:
   - Emit `NO_WORK_AVAILABLE` and stop.

6. **If tasks are available**:
   - Run the **Flagged / Blocked check** (below) against each candidate, in priority order (`Highest > High > Medium > Low > Lowest`, tie-broken by lowest numeric issue key). Skip any candidate that is flagged or blocked by an unresolved issue.
   - Select the first remaining candidate.
   - If every candidate is flagged and/or blocked, emit `NO_WORK_AVAILABLE: all candidates flagged or blocked — <issue-keys>` and stop.

7. **Emit the task information**:
   - Emit `<issue-key> — <summary>` and continue on to the next step in the workflow — do not stop.

## Flagged / Blocked check

Run against a single candidate issue (already fetched with `issuelinks` and `<flaggedFieldKey>`):

1. **Flagged**: if `<flaggedFieldKey>` was discovered in step 2b and the candidate's value for it is non-empty (e.g. contains `{"value": "Impediment", ...}`), the candidate is **flagged** — disqualify it.

2. **Blocked**: from the candidate's `issuelinks`, collect every entry where `type.id == <blocksLinkTypeId>` and `inwardIssue` is present — each `inwardIssue.key` is a blocker (the candidate "is blocked by" it). If there are none, the candidate is not blocked.

   For each blocker key:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<blocker-key>", fields: ["status", "comment"], responseContentFormat: "markdown")
   ```

   `responseContentFormat: "markdown"` matters here — without it, comment bodies come back as ADF (nested JSON), not the plain `## [BRANCH]\n\n<branch>` text the extraction below expects.

   The blocker is **resolved** if either:
   - Its `status.statusCategory.key` is `done` (check the category, not `status.name` — a site can rename its terminal status to anything, e.g. `Closed` or `Shipped`, but the category is always `done`), or
   - Its comments contain a `## [BRANCH]` header — extract the branch name from the comment body, then run `gh pr list --head "<branch>" --state all --json state,url` and check whether any returned PR has `state` `OPEN` or `MERGED`.

   If any blocker is not resolved, the candidate is **blocked** — disqualify it.

## Rules

- Always claim exactly one task
- Priority order: `Highest > High > Medium > Low > Lowest`
- Tie-break by lowest numeric issue key
- Never cherry-pick based on content
- Never claim a flagged issue or an issue blocked by an unresolved issue — skip it entirely rather than deprioritizing it
- An explicitly requested task ID that is flagged or blocked is never silently substituted — emit `CHECK_BLOCKED` instead
- If the JIRA MCP is not available, output `CHECK_BLOCKED: JIRA MCP not available` and stop
