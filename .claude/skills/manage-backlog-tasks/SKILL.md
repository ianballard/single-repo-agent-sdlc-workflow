---
name: manage-backlog-tasks
description: Implements the issue-tracker contract (docs/agents/issue-tracker.md) for the active tracker. Resolves contract verbs to concrete tracker calls.
---
# Manage backlog tasks

This skill implements the tracker contract defined in `docs/agents/issue-tracker.md`.

**Active adapter: jira** — see `adapters/jira.md` for the concrete call for each `tracker.<verb>`.

To use a verb a skill named, open the active adapter and follow the matching `## tracker.<verb>` section.

Switching trackers: see the contract's Switching trackers section.
