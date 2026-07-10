# JIRA adapter

Concrete realization of every `docs/agents/issue-tracker.md` contract verb via the Atlassian MCP plugin. Never read or write JIRA data outside of these MCP tools.

## tracker.session-init

Every call below requires a `cloudId` argument — there is no default. Discover it once per session/workflow run and reuse it for every subsequent call; do not re-fetch per call.

```
mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources()
```

Returns the accessible Atlassian sites, each with a `cloudId`. If there is exactly one, use it. If multiple, pick the one matching the current repo/context or ask the user. Capture it as `<cloudId>`.

If the JIRA project key is not already known from context, discover it:

```
mcp__plugin_atlassian_atlassian__getVisibleJiraProjects(cloudId: "<cloudId>")
```

Pick the project matching the current repo/context, or ask the user if multiple exist. Capture the project key (e.g., `PROJ`) — use it in all subsequent JQL and issue creation.

## tracker.find-work

```
mcp__plugin_atlassian_atlassian__searchJiraIssuesUsingJql(
  cloudId: "<cloudId>",
  jql: 'project = "<PROJECT>" AND status = "To Do" AND (assignee IS EMPTY OR assignee = currentUser()) ORDER BY priority ASC, created ASC',
  fields: ["summary", "status", "priority", "assignee", "labels", "issuetype", "issuelinks", "<flaggedFieldKey>"]
)
```

Priority ordering in JQL: `ORDER BY priority ASC` puts Highest first. Use `created ASC` as tiebreaker for same-priority issues.

For each candidate, in priority order, run `tracker.is-blocked-or-flagged` and skip any that disqualify. Select the first remaining candidate. If a specific key was requested instead, fetch it directly with `getJiraIssue` and run `tracker.is-blocked-or-flagged` against it — an explicitly requested task is never silently swapped for another one.

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

## tracker.read

```
mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
```

Returns all fields: summary, description, status, assignee, labels, priority, and comments. Pass `fields: [...]` to narrow the response, and `responseContentFormat: "markdown"` when comment bodies must be read as plain text (see `tracker.read-comments`).

## tracker.create

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

`priority` (and any other field without its own parameter, e.g. `labels`, `components`) is set via `additional_fields`, not as a top-level argument. Include ACs directly in the description using the `- [ ] #N text` format.

## tracker.set-phase

The JIRA board uses these exact statuses — transition to them by name:

| Contract phase | JIRA Status |
|---|---|
| `available` | `To Do` |
| `claimed` | `Intake` |
| `intake-review` | `Intake Review` |
| `planning` | `Plan` |
| `plan-review` | `Plan Review` |
| `coding` | `Code` |
| `ai-review` | `AI Code Review` |
| `human-review` | `Human Code Review` |
| `done` | `Done` |

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

Pick the transition whose `name` matches the target status exactly (case-insensitive). Note the parameter is `transition: { id: "..." }`, not a flat `transitionId`. Never guess transition IDs.

## tracker.assign

```
mcp__plugin_atlassian_atlassian__lookupJiraAccountId(cloudId: "<cloudId>", searchString: "<email or name>")

mcp__plugin_atlassian_atlassian__editJiraIssue(
  cloudId: "<cloudId>",
  issueIdOrKey: "<id>",
  fields: { assignee: { accountId: "<account-id>" } }
)
```

The search argument to `lookupJiraAccountId` is `searchString`, not `query`.

## tracker.comment

```
mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
  cloudId: "<cloudId>",
  issueIdOrKey: "<id>",
  commentBody: "## [NOTES]\n\n<content>"
)
```

The comment text argument is `commentBody`, not `comment`. Comment marker headers used by this workflow (see the contract's Comment-marker schema for the full list): `## [BRANCH]`, `## [PLAN]`, `## [NOTES]`, `## [MODIFIED FILES]`, `## [SCOPE CHANGE]`, `## [BLOCKED]`, `## [FINAL SUMMARY]`.

Also relevant: the `workflow-blocked` JIRA label, added to an issue on an early workflow stop (via `tracker.set-labels`) so humans can find stalled work; removed on a successful resume that reaches closeout.

## tracker.read-comments

```
mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>", fields: ["comment"], responseContentFormat: "markdown")
```

`responseContentFormat: "markdown"` matters — without it, comment bodies come back as ADF (nested JSON), not plain text. Filter the returned comments client-side for one starting with the requested `## [MARKER]` header:

```
issue = getJiraIssue("<id>", responseContentFormat: "markdown")
planComment = issue.comments.find(c => c.body.startsWith("## [PLAN]"))
```

## tracker.read-acs

Fetch the issue (`tracker.read`) and parse the description for `- [ ] #N` and `- [x] #N` lines.

## tracker.set-acs

1. Fetch the full description via `getJiraIssue`.
2. For each target index, find the line matching `- [ ] #<index>` and replace with `- [x] #<index>`.
3. Do all replacements in one pass on the description string, then call `editJiraIssue` once:

```
mcp__plugin_atlassian_atlassian__editJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>", fields: { description: "<updated description>" })
```

ACs must be managed by editing the issue description, not by adding comments.

## tracker.set-labels

```
mcp__plugin_atlassian_atlassian__editJiraIssue(
  cloudId: "<cloudId>",
  issueIdOrKey: "<id>",
  fields: { labels: ["label1", "label2"] }
)
```

`labels` replaces the entire label list — read the current labels first (`tracker.read`), then add/remove the target label(s) and write the full resulting list back.

## tracker.is-blocked-or-flagged

Requires a one-time discovery per session:

```
mcp__plugin_atlassian_atlassian__getIssueLinkTypes(cloudId: "<cloudId>")
```

Find the type whose `inward` phrase is `"is blocked by"` (default Jira Cloud names it `Blocks`). Capture its `id` as `<blocksLinkTypeId>`. If no such link type exists on this site, skip the blocked check entirely (treat nothing as blocked).

```
mcp__plugin_atlassian_atlassian__getJiraIssueTypeMetaWithFields(cloudId: "<cloudId>", projectIdOrKey: "<PROJECT>", issueTypeId: "<issue-type-id>", requiredFieldsOnly: false)
```

Find the field named `Flagged` (a checkboxes custom field, e.g. `customfield_10021`). Capture its `key` as `<flaggedFieldKey>`. If no such field exists in this project, skip the flagged check entirely. Neither ID is guaranteed to be the same across different JIRA sites — always discover, never hardcode.

Then, when reading a candidate issue, request both:

```
mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>", fields: ["status", "priority", "issuelinks", "<flaggedFieldKey>"])
```

- **Flagged**: the `<flaggedFieldKey>` value is a non-empty array (e.g. `[{"value": "Impediment"}]`) rather than `null` — disqualify.
- **Blocked**: an `issuelinks` entry has `type.id` matching `<blocksLinkTypeId>` and an `inwardIssue` present — that `inwardIssue.key` is a blocker. Fetch the blocker with `responseContentFormat: "markdown"`. A blocker counts as resolved if its `status.statusCategory.key` is `done` (the category, not `status.name` — a site can rename its terminal status to anything), or if its `## [BRANCH]` comment's branch name has an `OPEN` or `MERGED` PR (`gh pr list --head "<branch>" --state all --json state,url`). Checking the PR state, not just JIRA status, matters because closeout hands a finished task off for human review instead of transitioning it straight to `Done`.
- If any blocker is not resolved, the candidate is blocked — disqualify.

---

## Data Model

JIRA fields used by this workflow:

| Concept | JIRA Field | Notes |
|---|---|---|
| Task ID | Issue Key | e.g., `PROJ-42` — this is the `<id>` throughout the workflow |
| Title | `summary` | One-liner |
| Description | `description` | Markdown — includes task description + AC list |
| Acceptance Criteria | In `description` | Format: `- [ ] #N criterion` / `- [x] #N criterion` |
| Status | `status` | Changed via transitions — see `tracker.set-phase` |
| Assignee | `assignee` | Set to current user or service account |
| Priority | `priority` | `Highest`, `High`, `Medium`, `Low`, `Lowest` |
| Labels | `labels` | User-defined labels plus the `workflow-blocked` marker label |
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

## Rules

- Never read or write JIRA data outside of the MCP tools
- Always use `getTransitionsForJiraIssue` before `transitionJiraIssue` — never guess transition IDs
- ACs must be managed by editing the issue description, not by adding comments
- JIRA status is the single source of truth for workflow phase — use real transitions, not labels
