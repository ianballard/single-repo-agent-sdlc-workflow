# GitHub adapter

Realization of every `docs/agents/issue-tracker.md` contract verb via the `gh` CLI.

**Phase-model note:** GitHub has no status state machine — workflow phases are modeled as mutually-exclusive `phase:*` labels, and `done` closes the issue. If you activate this adapter, update the phase→status mapping note in the contract accordingly.

## tracker.session-init

```bash
gh repo view --json owner,name
```

Resolves the owner/repo pair used by every subsequent call. No cloudId concept — nothing else to discover per-session.

## tracker.find-work

```bash
gh issue list --state open --label ready --json number,title,labels,assignees --search "sort:created-asc"
```

Order candidates by a priority label (e.g. `priority:highest` > `priority:high` > ... > `priority:lowest`), tie-broken by lowest issue number. For each candidate, in priority order, run `tracker.is-blocked-or-flagged` and skip any that disqualify (a `blocked` label, or an open `blocked-by #N` reference). Select the first remaining candidate. If a specific number was requested instead, fetch it directly with `tracker.read` and run `tracker.is-blocked-or-flagged` against it.

## tracker.read

```bash
gh issue view <id> --json title,body,labels,comments,assignees,state
```

## tracker.create

```bash
gh issue create --title "<summary>" --body "<description with - [ ] #N ACs>"
```

## tracker.set-phase

Phase→label mapping (no status workflow):

| Contract phase | GitHub realization |
|---|---|
| `available` | no `phase:*` label present |
| `claimed` | `phase:intake` |
| `intake-review` | `phase:intake-review` |
| `planning` | `phase:plan` |
| `plan-review` | `phase:plan-review` |
| `coding` | `phase:code` |
| `ai-review` | `phase:ai-review` |
| `human-review` | `phase:human-review` |
| `done` | close the issue |

```bash
gh issue edit <id> --remove-label "phase:<old>" --add-label "phase:<new>"
# done:
gh issue close <id>
```

## tracker.assign

```bash
gh issue edit <id> --add-assignee "<username>"
```

## tracker.comment

```bash
gh issue comment <id> --body "## [NOTES]

<content>"
```

Same marker-header convention as the contract's Comment-marker schema.

## tracker.read-comments

From the `tracker.read` JSON `comments[]` array, filter for a body starting with the requested `## [MARKER]` header:

```bash
gh issue view <id> --json comments --jq '.comments[] | select(.body | startswith("## [PLAN]"))'
```

## tracker.read-acs

Parse the `- [ ] #N` / `- [x] #N` lines out of the `body` field returned by `tracker.read`.

## tracker.set-acs

1. Fetch the current body via `tracker.read`.
2. Replace the target `- [ ] #<index>` lines with `- [x] #<index>` in one pass.
3. Write the full body back:

```bash
gh issue edit <id> --body "<updated body>"
```

## tracker.set-labels

```bash
gh issue edit <id> --add-label "<label>"
gh issue edit <id> --remove-label "<label>"
```

## tracker.is-blocked-or-flagged

- **Flagged**: the issue has a `flagged` label.
- **Blocked**: the issue body contains an unchecked `blocked by #N` reference whose referenced issue (`gh issue view N --json state`) is still `open`. If none are open, the issue is not blocked.
