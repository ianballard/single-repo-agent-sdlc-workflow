# Issue tracker: JIRA (Atlassian MCP)

Issues and PRDs for this repo live in JIRA. All operations go through the
`mcp__plugin_atlassian_atlassian__*` MCP tools — never raw REST or any other path.
The `manage-backlog-tasks` skill (`.claude/skills/manage-backlog-tasks/SKILL.md`)
is the authoritative reference for exact tool-call shapes; this file summarizes
the conventions.

## Conventions

- **Issue ID**: the JIRA issue key (e.g. `KAN-42`). Discover the project key via
  `getVisibleJiraProjects` if not known from context.
- **Create an issue**: `createJiraIssue(projectKey, summary, description, issueTypeName, priority)`.
  Acceptance criteria go in the description as `- [ ] #N criterion` lines.
- **Read an issue**: `getJiraIssue(issueIdOrKey)` — returns fields and comments.
- **List/search**: `searchJiraIssuesUsingJql(jql)`, e.g.
  `project = "KAN" AND status = "To Do" ORDER BY priority ASC, created ASC`.
- **Comment**: `addCommentToJiraIssue(issueIdOrKey, comment)`.
- **Change state**: always `getTransitionsForJiraIssue` first, then
  `transitionJiraIssue` with the matching transition id. Never guess ids.
- **Labels**: user-defined only; workflow phase and triage state live in statuses.

## When a skill says "publish to the issue tracker"

Create a JIRA issue with `createJiraIssue`.

## When a skill says "fetch the relevant ticket"

Call `getJiraIssue(issueIdOrKey)`.

## When a skill says "apply a label"

For the five triage roles, transition the issue to the mapped JIRA status instead
(see `docs/agents/triage-labels.md`). For anything else, use real JIRA labels via
`editJiraIssue`.
