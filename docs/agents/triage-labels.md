# Triage Labels

The skills speak in terms of five canonical triage roles. In this repo those roles
map to **JIRA statuses**, not labels — transition the issue rather than labeling it.

| Role in mattpocock/skills | JIRA status        | Meaning                                  |
| ------------------------- | ------------------ | ---------------------------------------- |
| `needs-triage`            | `Triage`           | Maintainer needs to evaluate this issue  |
| `needs-info`              | `Needs Info`       | Waiting on reporter for more information |
| `ready-for-agent`         | `To Do`            | Fully specified, ready for an AFK agent  |
| `ready-for-human`         | `Ready for Human`  | Requires human implementation            |
| `wontfix`                 | `Done` (Won't Do)  | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), discover
transitions with `getTransitionsForJiraIssue` and transition to the corresponding
status. For `wontfix`, prefer a transition that sets resolution **Won't Do**; if
the workflow only offers plain `Done`, use it and note "wontfix" in a comment.

`To Do` is the claim pool for the autonomous SDLC workflow — new issues should
start in `Triage` so untriaged work is never claimed.

> **Setup required**: `Triage`, `Needs Info`, and `Ready for Human` must exist in
> the KAN project's workflow scheme. If a transition to one of them is missing,
> stop and report it (the statuses need to be added in JIRA board settings) —
> do not fall back to labels.
