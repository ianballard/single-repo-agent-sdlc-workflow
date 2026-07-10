---
name: manage-backlog-tasks
description: Manage backlog tasks using the JIRA MCP. Create, edit, assign, prioritize, and track tasks with full metadata via the Atlassian plugin MCP tools.
---
# JIRA Task Management via MCP

All task operations use the JIRA Atlassian MCP plugin. Never read or write task data any other way.

## Cloud ID Discovery

Every call below requires a `cloudId` argument — there is no default. Discover it once per session/workflow run and reuse it for every subsequent call documented here; do not re-fetch per call.

```
mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources()
```

Returns the accessible Atlassian sites, each with a `cloudId`. If there is exactly one, use it. If multiple, pick the one matching the current repo/context or ask the user. Capture it as `<cloudId>` — every example below assumes it is already known.

## Project Discovery

If the JIRA project key is not already known from context, discover it:

1. Call `mcp__plugin_atlassian_atlassian__getVisibleJiraProjects(cloudId: "<cloudId>")` to list accessible projects
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
| Modified Files | Comment | Header: `## [MODIFIED FILES]` — historical record for reviewers; the merge guard enforces the plan's `### Files in scope`, not this list |
| Branch Ref | Comment | Header: `## [BRANCH]` |
| Scope Change | Comment | Header: `## [SCOPE CHANGE]` — set during implementation when a file outside the plan's declared scope must change; includes the reason |
| Blocked | Comment | Header: `## [BLOCKED]` — set on an early workflow stop; records the block reason, step, branch, worktree, and checkpoint |
| Flagged | Custom checkboxes field (e.g. `customfield_10021`, named `Flagged`) | Non-empty (e.g. `[{"value": "Impediment"}]`) = flagged. Field key varies by site — discover via `getJiraIssueTypeMetaWithFields`, don't hardcode. |
| Blocking relationship | `issuelinks` | A link with `type.inward == "is blocked by"` and `inwardIssue` set means this issue is blocked by `inwardIssue`. Link type IDs vary by site — discover via `getIssueLinkTypes`. |

---

## Core Operations

### Read a Task

```
mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
```

Returns all fields: summary, description, status, assignee, labels, priority, and comments.

### List / Search Tasks

```
mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql(
  cloudId: "<cloudId>",
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
  cloudId: "<cloudId>",
  projectKey: "<PROJECT>",
  summary: "Task title",
  description: "## Description\n\n<why>\n\n## Acceptance Criteria\n\n- [ ] #1 First criterion\n- [ ] #2 Second criterion",
  issueTypeName: "Story",   // or "Task", "Bug"
  additional_fields: { priority: { name: "Medium" } }
)
```

`priority` (and any other field without its own parameter, e.g. `labels`, `components`) is set via `additional_fields`, not as a top-level argument.

Include ACs directly in the description using the `- [ ] #N text` format.

### Update Fields

```
mcp__plugin_atlassian_atlassian__editJiraIssue(
  cloudId: "<cloudId>",
  issueIdOrKey: "<id>",
  fields: {
    summary: "New title",                      // optional
    description: "<markdown>",                 // optional — replaces entire description
    assignee: { accountId: "<account-id>" },    // optional
    labels: ["label1", "label2"],               // optional — replaces entire label list
    priority: { name: "High" }                  // optional
  }
)
```

All field updates go inside a single `fields` object — there is no flat/top-level field syntax.

### Change Status (Transitions)

Always discover transitions before transitioning — the available transition IDs depend on the current status:

```
1. mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
   → Returns list of {id, name} transitions available from current status

2. mcp__plugin_atlassian_atlassian__transitionJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     transition: { id: "<id-from-step-1>" }
   )
```

Pick the transition whose `name` matches the target status exactly (case-insensitive). Note the parameter is `transition: { id: "..." }`, not a flat `transitionId`.

### Add a Comment

```
mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
  cloudId: "<cloudId>",
  issueIdOrKey: "<id>",
  commentBody: "## [NOTES]\n\n<content>"
)
```

The comment text argument is `commentBody`, not `comment`.

Comment type headers used by this workflow:
- `## [BRANCH]` — set during intake; value is the git branch name
- `## [PLAN]` — set during plan-task; implementation plan prose. Contains a `### Files in scope` sub-section (one file or glob per line, prefixed `- `) — this is the authoritative scope the merge guard enforces
- `## [NOTES]` — appended during implementation; progress log entries
- `## [MODIFIED FILES]` — set during implementation; list of files changed. Historical record for reviewers — the merge guard enforces the plan's `### Files in scope`, not this list
- `## [SCOPE CHANGE]` — set during implementation; a file outside the plan's declared scope that must change, with reason
- `## [BLOCKED]` — set on an early workflow stop; records the block reason, step, branch, worktree, checkpoint
- `## [FINAL SUMMARY]` — set during closeout; PR-description-style summary

Also relevant: the `workflow-blocked` JIRA label, added to an issue on an early workflow stop (via the Blocked exit protocol) so humans can find stalled work; it is removed on a successful resume that reaches closeout.

### Check Whether an Issue Is Flagged or Blocked

Used by `check-for-work` before claiming a task. Both checks require a one-time discovery per session:

```
mcp__plugin_atlassian_atlassian__getIssueLinkTypes(cloudId: "<cloudId>")
```

Find the type whose `inward` phrase is `"is blocked by"` (default Jira Cloud names it `Blocks`). Capture its `id`.

```
mcp__plugin_atlassian_atlassian__getJiraIssueTypeMetaWithFields(cloudId: "<cloudId>", projectIdOrKey: "<PROJECT>", issueTypeId: "<issue-type-id>", requiredFieldsOnly: false)
```

Find the field named `Flagged` (a checkboxes custom field). Capture its `key`. Neither the link type ID nor the flagged field key is guaranteed to be the same across different JIRA sites — always discover them, never hardcode.

Then, when reading a candidate issue, request both:

```
mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>", fields: ["status", "priority", "issuelinks", "<flaggedFieldKey>"])
```

- Flagged: the `<flaggedFieldKey>` value is a non-empty array (e.g. `[{"value": "Impediment"}]`) rather than `null`.
- Blocked: an `issuelinks` entry has `type.id` matching the discovered Blocks link type and an `inwardIssue` present — that `inwardIssue.key` is a blocker. Fetch the blocker with `responseContentFormat: "markdown"` (comment bodies are ADF JSON otherwise, not the plain `## [BRANCH]` text you need to extract a branch name from). A blocker counts as resolved if its `status.statusCategory.key` is `done` (the category, not `status.name` — a site can rename its terminal status to anything), or if its `## [BRANCH]` comment's branch name has an `OPEN` or `MERGED` PR (`gh pr list --head "<branch>" --state all --json state,url`). Checking the PR state, not just JIRA status, matters if a variant of `closeout` in use hands a finished task off for human review instead of transitioning it straight to `Done`.

### Lookup User Account ID

```
mcp__plugin_atlassian_atlassian__lookupJiraAccountId(cloudId: "<cloudId>", searchString: "<email or name>")
```

Use to get the account ID needed for assignee updates. The search argument is `searchString`, not `query`.

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
3. Update with `editJiraIssue(cloudId, issueIdOrKey, fields: { description: <updated> })`

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

`cloudId` is required on every call below and omitted here for brevity — thread it through each one.

```
# 1. Find work
searchJiraIssuesUsingJql(jql: 'project = "PROJ" AND status = "To Do" ORDER BY priority ASC, created ASC')

# 2. Read task
getJiraIssue(issueIdOrKey: "PROJ-42")

# 3. Start work: transition to Intake
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Intake" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })

# 4. Record branch
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [BRANCH]\n\nfeature/proj-42-add-auth")

# 5. Transition to Plan, add implementation plan
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Plan" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [PLAN]\n\n1. Analyze\n2. Implement\n3. Test")

# 6. Transition to Code, implement
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Code" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })

# 7. Append implementation notes
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [NOTES]\n\n- Investigated root cause\n- Added edge case tests")

# 8. Check off ACs
getJiraIssue(issueIdOrKey: "PROJ-42")  → get current description
# Replace "- [ ] #1" with "- [x] #1" etc.
editJiraIssue(issueIdOrKey: "PROJ-42", fields: { description: <updated description with ACs checked> })

# 9. Transition to AI Code Review
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "AI Code Review" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })

# 10. Add final summary and hand off for human review
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [FINAL SUMMARY]\n\nImplemented X using Y pattern. Updated files Z, W.")
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Human Code Review" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })

# NOTE: the agent never transitions an issue to Done. A human reviews the
# pushed PR and makes the Done transition themselves.
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
