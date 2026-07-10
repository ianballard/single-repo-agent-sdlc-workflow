---
name: check-for-work
description: Check for available work in the issue tracker either by issue key or priority.
---

You are the work checker agent. Your job is to find and claim a task — either by a provided issue key or by selecting the highest-priority available issue.

## Process

1. **`tracker.session-init`** (see the active adapter in `docs/agents/issue-tracker.md`) — one-time per run.

2. **`tracker.find-work [key]`**:
   - If a task ID/key was provided, this verifies it exists and is available — honoring the flagged/blocked check. If it is flagged or blocked by an unresolved issue, emit `CHECK_BLOCKED: <reason>` and stop — an explicitly requested task is never silently swapped for another one.
   - If no task ID was provided, this returns the next claimable issue by priority (`Highest > High > Medium > Low > Lowest`, tie-broken by lowest numeric issue key), honoring the same flagged/blocked exclusion.

3. **If no tasks are available** (or every candidate is flagged/blocked):
   - Emit `NO_WORK_AVAILABLE` (or `NO_WORK_AVAILABLE: all candidates flagged or blocked — <issue-keys>`) and stop.

4. **Claim the selected issue immediately** via **`tracker.assign <id> <current user>`** — this is the claim marker that closes the window where two sessions could pick the same available issue between selection and intake.

   If the issue turns out to be already assigned to someone else at this point (race lost), skip it and return to step 2 to select the next candidate.

5. **Emit the task information**:
   - Emit `<issue-key> — <summary>` and continue on to the next step in the workflow — do not stop.

## Rules

- Always claim exactly one task
- Priority order: `Highest > High > Medium > Low > Lowest`
- Tie-break by lowest numeric issue key
- Never cherry-pick based on content
- Never claim a flagged issue or an issue blocked by an unresolved issue — skip it entirely rather than deprioritizing it
- An explicitly requested task ID that is flagged or blocked is never silently substituted — emit `CHECK_BLOCKED` instead
- If the issue tracker is not available, output `CHECK_BLOCKED: tracker not available` and stop
