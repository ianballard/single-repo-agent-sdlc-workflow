---
name: manage-backlog-tasks
description: Manage backlog tasks using the JIRA MCP. Create, edit, assign, prioritize, and track tasks with full metadata via the Atlassian plugin MCP tools.
---
# JIRA Task Management via MCP

All task operations use the JIRA Atlassian MCP plugin. Never read or write task data any other way.

## Project Discovery

If the JIRA project key is not already known from context, discover it:

1. Call `mcp__plugin_atlassian_atlassian__getVisibleJiraProjects` to list accessible projects
2. Pick the one that matches the current repo/context, or ask the user if multiple exist
3. Capture the project key (e.g., `PROJ`) — use it in all subsequent JQL and issue creation

---

## Data Model

JIRA fields used by this workflow:

| Concept | JIRA Field | Notes |
|---|---|---|
| Task ID | Issue Key | e.g., `PROJ-42` — this is the `<id>` throughout the workflow |
| Title | `summary` | One-liner |
| Description | `description` | Markdown — includes task description + AC list |
| Acceptance Criteria | In `description` | Format: `- [ ] #N criterion` / `- [x] #N criterion` |
| Status | `status` | Changed via transitions — see Status Reference below |
| Assignee | `assignee` | Set to current user or service account |
| Priority | `priority` | `Highest`, `High`, `Medium`, `Low`, `Lowest` |
| Labels | `labels` | User-defined labels only (no workflow phase labels needed) |
| Implementation Plan | Comment | Header: `## [PLAN]` |
| Implementation Notes | Comments | Header: `## [NOTES]` (append; multiple allowed) |
| Final Summary | Comment | Header: `## [FINAL SUMMARY]` |
| Modified Files | Comment | Header: `## [MODIFIED FILES]` |
| Branch Ref | Comment | Header: `## [BRANCH]` |

---

## Core Operations

### Read a Task

```
mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
```

Returns all fields: summary, description, status, assignee, labels, priority, and comments.

### List / Search Tasks

```
mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql(
  jql: 'project = "<PROJECT>" AND status = "To Do" ORDER BY priority ASC, created ASC',
  fields: ["summary", "status", "priority", "assignee", "labels"]
)
```

Priority ordering in JQL: `ORDER BY priority ASC` puts Highest first. Use `created ASC` as tiebreaker for same-priority issues.

Common JQL patterns:
```
# All open issues
project = "PROJ" AND status != Done ORDER BY priority ASC, created ASC

# By status (use exact status names from the board)
project = "PROJ" AND status = "To Do"
project = "PROJ" AND status = "Code"
project = "PROJ" AND status = "AI Code Review"

# Issues currently being worked on (any in-flight status)
project = "PROJ" AND status in ("Intake", "Plan", "Code", "AI Code Review")
```

### Create a Task

```
mcp__plugin_atlassian_atlassian__createJiraIssue(
  projectKey: "<PROJECT>",
  summary: "Task title",
  description: "## Description\n\n<why>\n\n## Acceptance Criteria\n\n- [ ] #1 First criterion\n- [ ] #2 Second criterion",
  issueTypeName: "Story",   // or "Task", "Bug"
  priority: "Medium"
)
```

Include ACs directly in the description using the `- [ ] #N text` format.

### Update Fields

```
mcp__plugin_atlassian_atlassian__editJiraIssue(
  issueIdOrKey: "<id>",
  summary: "New title",           // optional
  description: "<markdown>",      // optional — replaces entire description
  assignee: "<account-id>",       // optional
  labels: ["label1", "label2"],   // optional — replaces entire label list
  priority: "High"                // optional
)
```

### Change Status (Transitions)

Always discover transitions before transitioning — the available transition IDs depend on the current status:

```
1. mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")
   → Returns list of {id, name} transitions available from current status

2. mcp__plugin_atlassian_atlassian__transitionJiraIssue(
     issueIdOrKey: "<id>",
     transitionId: "<id-from-step-1>"
   )
```

Pick the transition whose `name` matches the target status exactly (case-insensitive).

### Add a Comment

```
mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
  issueIdOrKey: "<id>",
  comment: "## [NOTES]\n\n<content>"
)
```

Comment type headers used by this workflow:
- `## [BRANCH]` — set during intake; value is the git branch name
- `## [PLAN]` — set during plan-task; implementation plan prose
- `## [NOTES]` — appended during implementation; progress log entries
- `## [MODIFIED FILES]` — set during implementation; list of files changed
- `## [FINAL SUMMARY]` — set during closeout; PR-description-style summary

### Lookup User Account ID

```
mcp__plugin_atlassian_atlassian__lookupJiraAccountId(query: "<email or name>")
```

Use to get the account ID needed for assignee updates.

---

## Acceptance Criteria Management

ACs are stored directly in the issue description using this format:

```markdown
## Acceptance Criteria

- [ ] #1 First criterion
- [x] #2 Second criterion (completed)
- [ ] #3 Third criterion
```

### Reading ACs

Fetch the issue and parse the description for `- [ ] #N` and `- [x] #N` lines.

### Checking Off an AC

1. Fetch the full description via `getJiraIssue`
2. Find the line matching `- [ ] #<index>` and replace with `- [x] #<index>`
3. Update with `editJiraIssue(issueIdOrKey, description: <updated>)`

### Checking Multiple ACs

Do all replacements in one pass on the description string, then call `editJiraIssue` once.

---

## Status Reference

The JIRA board uses these exact statuses — transition to them by name:

| Workflow Step | JIRA Status |
|---|---|
| Available for work | `To Do` |
| Branch created, work claimed | `Intake` |
| Awaiting human intake review (optional gate) | `Intake Review` |
| Implementation planning | `Plan` |
| Awaiting human plan review (optional gate) | `Plan Review` |
| Writing code | `Code` |
| AI code review in progress | `AI Code Review` |
| Awaiting human code review (optional gate) | `Human Code Review` |
| Complete | `Done` |

---

## Full Workflow Example

```
# 1. Find work
searchJiraIssuesUsingJql('project = "PROJ" AND status = "To Do" ORDER BY priority ASC, created ASC')

# 2. Read task
getJiraIssue("PROJ-42")

# 3. Start work: transition to Intake
getTransitionsForJiraIssue("PROJ-42") → find "Intake" transition id
transitionJiraIssue("PROJ-42", transitionId)

# 4. Record branch
addCommentToJiraIssue("PROJ-42", "## [BRANCH]\n\nfeature/proj-42-add-auth")

# 5. Transition to Plan, add implementation plan
getTransitionsForJiraIssue("PROJ-42") → find "Plan" transition id
transitionJiraIssue("PROJ-42", transitionId)
addCommentToJiraIssue("PROJ-42", "## [PLAN]\n\n1. Analyze\n2. Implement\n3. Test")

# 6. Transition to Code, implement
getTransitionsForJiraIssue("PROJ-42") → find "Code" transition id
transitionJiraIssue("PROJ-42", transitionId)

# 7. Append implementation notes
addCommentToJiraIssue("PROJ-42", "## [NOTES]\n\n- Investigated root cause\n- Added edge case tests")

# 8. Check off ACs
getJiraIssue("PROJ-42")  → get current description
# Replace "- [ ] #1" with "- [x] #1" etc.
editJiraIssue("PROJ-42", description: <updated description with ACs checked>)

# 9. Transition to AI Code Review
getTransitionsForJiraIssue("PROJ-42") → find "AI Code Review" transition id
transitionJiraIssue("PROJ-42", transitionId)

# 10. Add final summary and mark done
addCommentToJiraIssue("PROJ-42", "## [FINAL SUMMARY]\n\nImplemented X using Y pattern. Updated files Z, W.")
getTransitionsForJiraIssue("PROJ-42") → find "Done" transition id
transitionJiraIssue("PROJ-42", transitionId)
```

---

## Task Creation Guidelines

A well-written JIRA issue clearly defines the problem, expected outcome, how to validate the outcome, and context so implementing a solution has minimal ambiguity.

### Description Format

```markdown
## Description

Brief explanation of the task purpose and why it's needed.

## Acceptance Criteria

- [ ] #1 First verifiable criterion
- [ ] #2 Second verifiable criterion
- [ ] #3 Third verifiable criterion
```

### Good Acceptance Criteria

- **Outcome-Oriented**: Focus on the result, not the method
- **Testable/Verifiable**: Each criterion should be objectively verifiable
- **Clear and Concise**: Unambiguous language
- **User-Focused**: Frame from end-user or system behavior perspective

Good examples:
- "User can successfully log in with valid credentials"
- "API returns 400 with descriptive error when required field is missing"

Bad examples (implementation steps, not outcomes):
- "Add a new function handleLogin() in auth.ts"
- "Define expected behavior"

---

## Priority Ordering

JQL returns priorities as: `Highest > High > Medium > Low > Lowest`. Workflow picks the highest-priority, lowest-issue-number task.

---

## Finding Comments by Type

To find a specific comment type (e.g., the plan), fetch the issue with `getJiraIssue` and scan the returned comments for one starting with `## [PLAN]`.

```
issue = getJiraIssue("<id>")
planComment = issue.comments.find(c => c.body.startsWith("## [PLAN]"))
```

---

## Rules

- Never read or write JIRA data outside of the MCP tools
- Always use `getTransitionsForJiraIssue` before `transitionJiraIssue` — never guess transition IDs
- ACs must be managed by editing the issue description, not by adding comments
- JIRA status is the single source of truth for workflow phase — use real transitions, not labels
