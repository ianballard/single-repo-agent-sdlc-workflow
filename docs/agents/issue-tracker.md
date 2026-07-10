# Issue tracker: capability contract

This file is the tracker-agnostic contract. Skills speak these verbs; they never name a vendor tool. The **active adapter** below resolves each verb to concrete calls. Switch trackers by changing the active-adapter pointer and ensuring that adapter implements every verb.

Active adapter: jira (.claude/skills/manage-backlog-tasks/adapters/jira.md)

## Verbs

| Verb | Purpose | Used by |
|---|---|---|
| `tracker.session-init` | One-time per run: resolve any tracker handle (JIRA cloudId, GitHub repo) + project. No-op for trackers that need none. | check-for-work (workflow start) |
| `tracker.find-work [key]` | Return the next claimable issue by priority, or verify a named one — honoring flagged/blocked exclusion. | check-for-work |
| `tracker.read <id>` | Fetch summary, description, ACs, status/phase, comments. | most skills |
| `tracker.create {summary, description, type, priority}` | Create an issue; ACs embedded in description as `- [ ] #N`. | workflow task rule |
| `tracker.set-phase <id> <phase>` | Move the issue to a workflow phase (see phase vocabulary). Hides discover-then-transition mechanics. | intake, plan-task, implement, code-review, closeout, gates |
| `tracker.assign <id> <user>` | Assign the issue (used as the claim marker). | check-for-work, intake |
| `tracker.comment <id> <marker> <body>` | Append a workflow comment under a marker header. | plan, notes, modified-files, final-summary, branch, scope-change, blocked |
| `tracker.read-comments <id> [marker]` | Return comments, optionally filtered to one marker. | merge-guard, audit, check-for-work (blocker BRANCH) |
| `tracker.read-acs <id>` | Parse the AC checklist from the description. | verify-ac, assess-task |
| `tracker.set-acs <id> <indexes>` | Mark the given AC indexes complete in the description. | verify-ac |
| `tracker.set-labels <id> add\|remove <labels>` | Add/remove user labels (e.g. `workflow-blocked`). | blocked-exit protocol |
| `tracker.is-blocked-or-flagged <id>` | True if flagged or blocked by an unresolved dependency. | check-for-work |

## Phase vocabulary

Contract phase → JIRA status (the mapping lives in the adapter, listed here so the contract fixes the names):

`available`→To Do, `claimed`→Intake, `intake-review`→Intake Review, `planning`→Plan, `plan-review`→Plan Review, `coding`→Code, `ai-review`→AI Code Review, `human-review`→Human Code Review, `done`→Done.

## Comment-marker schema

Storage is the adapter's choice (JIRA comments; GitHub could use comments or body sections); the marker names are fixed by the contract:

- `[BRANCH]` — set during intake; value is the git branch name
- `[PLAN]` — set during plan-task; implementation plan prose, including a `### Files in scope` sub-section
- `[NOTES]` — appended during implementation; progress log entries
- `[MODIFIED FILES]` — set during implementation; historical record for reviewers only
- `[SCOPE CHANGE]` — set during implementation when a file outside the plan's declared scope must change, with reason
- `[BLOCKED]` — set on an early workflow stop; records the block reason, step, branch, worktree, checkpoint
- `[FINAL SUMMARY]` — set during closeout; PR-description-style summary

## AC model

ACs live in the issue description as `- [ ] #N criterion` / `- [x] #N criterion`; read via `tracker.read-acs`, checked via `tracker.set-acs`.

## Switching trackers

1. Add `adapters/<tracker>.md` implementing every verb.
2. Change the Active adapter line here and in `manage-backlog-tasks/SKILL.md`.
3. Update the phase→status mapping if the new tracker's states differ.
4. No component skill changes.
