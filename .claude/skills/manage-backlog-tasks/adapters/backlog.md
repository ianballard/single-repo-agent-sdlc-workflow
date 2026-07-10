# Backlog.md adapter

Realization of every `docs/agents/issue-tracker.md` contract verb via the Backlog.md CLI (`backlog`).

<!-- BACKLOG.MD GUIDELINES START -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

**For every user request in this project regarding task management, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Use the detailed guides when needed:
- `backlog instructions task-creation` for creating or splitting tasks
- `backlog instructions task-execution` for planning and implementation workflow
- `backlog instructions task-finalization` for completion and handoff

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->


**Storage model:** tasks are markdown files under `backlog/tasks/task-<id> - <title>.md`, mutated only through the CLI (never edit the files directly — see `backlog/CLAUDE.md`). `--plain` gives AI-parseable text output on every read command.

**Marker mapping quirk:** Backlog.md has no free-form comment thread — only three long-lived text fields (Plan, Notes, Final Summary) plus the description. `tracker.comment` therefore maps most markers into the Notes field (each comment becomes an appended, marker-headed block via `--append-notes`), except `[PLAN]` and `[FINAL SUMMARY]`, which have dedicated fields. If you activate this adapter, update the contract's Comment-marker schema note to record this collapse.

## tracker.session-init

No-op — Backlog.md operates on the local repo; there is no cloud handle or remote project to resolve. If `backlog/config.yml` doesn't exist yet, run `cd backlog && backlog init && cd ..` once, then set `statuses` in `backlog/config.yml` to the phase vocabulary's status list (see `tracker.set-phase`).

## tracker.find-work

```bash
backlog task list -s "To Do" --plain
```

Backlog.md's `list` has no priority sort — sort the returned rows client-side: `Highest > High > Medium > Low > Lowest`, tie-broken by lowest numeric task id. For each candidate, in that order, run `tracker.is-blocked-or-flagged` and skip any that disqualify. Select the first remaining candidate. If a specific id was requested instead, fetch it directly with `tracker.read` and run `tracker.is-blocked-or-flagged` against it.

## tracker.read

```bash
backlog task <id> --plain
```

Returns title, status, assignee, labels, priority, description (with AC list), plan, notes, and final summary.

## tracker.create

```bash
backlog task create "Title" -d "Description" --ac "First criterion" --ac "Second criterion" --priority medium
```

ACs are passed as repeated `--ac` flags at creation time (or added later — see `tracker.read-acs`/`tracker.set-acs`). Do not pass `--plan` at creation — the Implementation Plan is added only once work starts (see `tracker.comment`).

## tracker.set-phase

Phase→status is a direct name match — Backlog.md's own `statuses` list in `backlog/config.yml` **is** the phase vocabulary already (`To Do`, `Intake`, `Intake Review`, `Plan`, `Plan Review`, `Code`, `AI Code Review`, `Human Code Review`, `Done`):

```bash
backlog task edit <id> -s "<status>"
```

## tracker.assign

```bash
backlog task edit <id> -a @<user>
```

## tracker.comment

- `[PLAN]` → `backlog task edit <id> --plan "<body>"` (replaces; there is one plan per task)
- `[FINAL SUMMARY]` → `backlog task edit <id> --final-summary "<body>"` (replaces) or `--append-final-summary "<body>"` (append)
- every other marker (`[BRANCH]`, `[NOTES]`, `[MODIFIED FILES]`, `[SCOPE CHANGE]`, `[BLOCKED]`) → append a marker-headed block to Notes:
  ```bash
  backlog task edit <id> --append-notes $'## [<MARKER>]\n\n<body>'
  ```

Use `$'...'` (ANSI-C quoting) or `printf` so literal `\n` in the body becomes a real newline — the CLI does not convert escaped `\n` inside plain double quotes.

## tracker.read-comments

```bash
backlog task <id> --plain
```

Scan the returned Notes field (and Plan / Final Summary fields for those two markers) for a block starting with `## [<MARKER>]`. Because Notes is a single growing field rather than discrete comments, "read comments" here means "extract the matching marker blocks from that field's text."

## tracker.read-acs

```bash
backlog task <id> --plain
```

Parse the description's `- [ ] #N` / `- [x] #N` lines.

## tracker.set-acs

```bash
backlog task edit <id> --check-ac 1 --check-ac 3 --check-ac 5
```

Multiple `--check-ac <index>` flags in one call check all of them in a single edit.

## tracker.set-labels

```bash
backlog task edit <id> -l <label1>,<label2>
```

`-l` replaces the entire label list — read the current labels first (`tracker.read`), then add/remove the target label(s) and write the full resulting list back.

## tracker.is-blocked-or-flagged

Backlog.md has no built-in flagged field or blocking-issue-link type — model both as conventions:

- **Flagged**: the task has a `flagged` label (`-l` includes `flagged`).
- **Blocked**: the task has one or more `--dep task-N` dependencies (visible in `tracker.read`'s output) whose referenced task's `status` is not `Done`, or whose `## [BRANCH]` Notes block has a branch with no `OPEN`/`MERGED` PR (`gh pr list --head "<branch>" --state all --json state,url`) — same PR-state nuance as the JIRA adapter, needed because closeout hands off to Human Code Review rather than Done.
- If any dependency is unresolved by either check, the candidate is blocked — disqualify.
