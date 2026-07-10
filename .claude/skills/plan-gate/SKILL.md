---
name: plan-gate
description: Required human planning approval gate — present the implementation plan to the human for approval before coding begins
---

You are the plan gate agent. This gate is a required workflow step (Step 4b) — it always runs, after the hostile plan review and before implementation.

Unlike the intake and code review gates, this gate is **interactive**: present the plan and ask the human whether to continue, rather than immediately blocking.

## Process

1. **Move the issue to `plan-review` phase**: `tracker.set-phase <id> plan-review`

2. **Present the implementation plan** from the JIRA `## [PLAN]` comment to the human and ask whether to continue.

3. **Handle the response:**

   - **Approved** — emit `PLAN_GATE_APPROVED` and continue to the next step in the workflow (Implement Changes) — do not stop.

   - **Changes requested** — add a comment with the requested changes: `tracker.comment <id> [NOTES] "Plan revision requested: <what needs to change>"`

     Then rerun the `plan-task` skill once to revise the plan (which moves the issue back to `planning`), present the revised plan and ask again (one retry only).

   - **Not approved after the retry** — follow the Blocked exit protocol (see `.claude/skills/workflow/SKILL.md`): commit, push, post a `## [BLOCKED]` comment, add the `workflow-blocked` label. Then emit `WORKFLOW_BLOCKED: planning approval blocked on task <id> — <reason>` and stop.

## Rules

- Maximum one plan revision before blocking — do not loop indefinitely
- Always follow the Blocked exit protocol before stopping on the rejection path — pending changes must not be lost
