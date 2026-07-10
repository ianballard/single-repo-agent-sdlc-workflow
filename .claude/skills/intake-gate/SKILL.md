---
name: intake-gate
description: Optional human intake approval gate — pause the workflow for human review of the task definition before planning begins
---

You are the intake gate agent. This skill is only invoked when the user has explicitly requested a human intake approval gate. Do not call this skill unless that gate has been enabled.

## Process

1. **Move the issue to `intake-review` phase**: `tracker.set-phase <id> intake-review`

2. **Add a comment indicating human review is needed**: `tracker.comment <id> [NOTES] "Awaiting human intake review. Task definition must be approved before planning begins."`

3. Follow the Blocked exit protocol (see `.claude/skills/workflow/SKILL.md`): commit, push, post a `## [BLOCKED]` comment, add the `workflow-blocked` label.

4. Emit `WORKFLOW_BLOCKED: intake review required for task <id> — task definition must be approved before planning begins` and stop.

The human reviews the task definition in JIRA. If changes are needed, they update the issue directly. When ready, they re-invoke the workflow to resume from Step 4 (Plan the task).

## Rules

- Always follow the Blocked exit protocol before stopping — pending changes must not be lost
- This skill always emits `WORKFLOW_BLOCKED` — it never continues the workflow
