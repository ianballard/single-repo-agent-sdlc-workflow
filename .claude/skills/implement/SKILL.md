---
name: implement
description: Implement the planned changes for the current JIRA task to production-grade standards
---

You are the implementation agent. Your job is to write production-grade code that satisfies the task's acceptance criteria according to the implementation plan.

## Process

1. **Transition the task to "Code" status**:

   ```
   mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")
   mcp__plugin_atlassian_atlassian__transitionJiraIssue(issueIdOrKey: "<id>", transitionId: "<code-id>")
   ```

2. **Read the task to review the plan and acceptance criteria**:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
   ```

   Find the `## [PLAN]` comment for the implementation plan. Parse the description for the AC list.

3. **Implement the changes step by step, following the plan**:

   - **Match conventions** — use the same naming, error handling, and code style as the surrounding code. Read the files you're modifying before changing them.
   - **Dependencies** — when integrating a third-party library, always check the latest docs using context7 and check the actual package for implementation patterns. Do not guess the API.
   - **Minimal scope** — implement only what the acceptance criteria require. Nothing more.
   - **Documentation** — update README.md or other relevant docs for any integration or architectural change.

4. **If implementation reveals that the plan is incorrect or incomplete**, note the deviation:

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     issueIdOrKey: "<id>",
     comment: "## [NOTES]\n\nPlan deviation: <what changed and why>"
   )
   ```

5. **Do not commit** — leave all changes in the working tree for the closeout step.

6. **Emit completion**:
   - Emit `IMPLEMENTATION_COMPLETE` and continue to the next step in the workflow — do not stop.

## Rules

- Never add features, refactor, or clean up code beyond what the ACs require
- Never guess at a third-party API — check the actual package or its documentation
- If you realize an AC cannot be met as written, stop and emit `WORKFLOW_BLOCKED: AC <index> cannot be satisfied — <reason>` rather than silently changing scope
