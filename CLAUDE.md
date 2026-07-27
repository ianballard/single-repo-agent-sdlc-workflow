# CLAUDE.md

## Repo Architecture

This is a mono-repo. All project areas are top-level subdirectories:

- **frontend/** — React 18+ with TypeScript, Vite, and Vitest
- **backend/** — FastAPI with Python 3.11+
- **e2e/** — Playwright end-to-end tests

All commits and branches live in this single git repo. Never reference a separate "coordination repo" or `projects/` directory — those concepts do not apply.

## Task Management

Tasks are managed through the tracker-agnostic contract in `docs/agents/issue-tracker.md` (capability verbs, workflow-phase vocabulary, comment-marker schema), implemented by the `manage-backlog-tasks` skill's per-tracker adapters. **JIRA is the active adapter** — task IDs are JIRA issue keys (e.g., `PROJ-42`) today, but the tracker is swappable: see the contract's "Switching trackers" section.

## SDLC Workflow System

The `.claude/skills/` directory contains custom Claude Code skills that implement a full SDLC automation workflow:

**Primary Skill:**
- **workflow** - The main end-to-end coordinator. Use when the user asks to coordinate a task. Claims work from JIRA, runs intake, plans, implements, tests, reviews, and closes out tasks autonomously.

**Component Skills** (called by workflow):
- **check-for-work** - Claims tasks from JIRA by issue key or priority
- **intake** - Creates the feature branch, transitions the JIRA issue to Intake, and assigns it to the current user
- **setup-worktree** - Creates a git worktree at `.claude/worktrees/<branch>` so all task work is branch-isolated
- **assess-task** - Evaluates whether a JIRA task is sufficiently well-defined to implement
- **intake-gate** - Optional human intake approval gate (Step 3b)
- **plan-task** - Writes a thorough high-level implementation plan (stored as JIRA comment)
- **hostile-plan-review** - Adversarially stress-tests the plan before coding begins
- **plan-gate** - Required human planning approval gate (Step 4b)
- **implement** - Writes production-grade code following the implementation plan
- **verify-ac** - Verifies every acceptance criterion is met and marks them complete in JIRA description
- **unit-tests** - Creates/updates and runs unit tests
- **e2e-tests** - Runs Playwright end-to-end tests
- **lint-format** - Auto-formats and lints changed code (Prettier/ESLint for frontend & e2e, Ruff for backend), fixing what's fixable, before code review
- **implementation-notes** - Documents implementation details as JIRA comments
- **code-review** - Performs comprehensive code quality review
- **code-review-gate** - Optional human code review gate (Step 10b)
- **audit-followed-workflow-steps** - Verifies all workflow steps completed (reads JIRA comments/labels)
- **self-improvement** - Reflects on execution and emits process improvement recommendations
- **merge-guard** - Verifies branch changes are within the task's declared scope
- **open-pr** - Opens a GitHub pull request for the pushed feature branch via the `gh` CLI (invoked by closeout)
- **closeout** - Commits, squashes, pushes, opens the PR, and moves the task to Human Code Review
- **commit** - Creates conventional commit messages
- **manage-backlog-tasks** - Implements the issue-tracker contract; holds per-tracker adapters

**Doctrine-mode Skills** (the un-ticketed lane — see "Ways to work in this repo" in `README.md`):
- **delegate-plan** - Invocation 1. Triage → ideation → PRD → spec with Definition of Done → plan → red-team stress test, committed to `docs/specs/YYYY-MM-DD-<slug>/`. Never implements.
- **red-team-plan** - Step 5b of delegate-plan. Adversarially stress-tests `spec.md`, its DoD, and `plan.md` before execution is authorized, across seven dimensions. Covers **solution soundness** (build vs. buy, technology fitness, version/compatibility claims verified against the actual manifests, stack coherence, ADR conflicts, simpler alternatives, failure and scale characteristics, unaddressed non-functional requirements) as well as **contract integrity** (a DoD a mock could satisfy, a spec that is not self-contained, DoD criteria with no covering task). Runs as a **fresh subagent given only the artifact paths** — never the planning conversation, since a planner reviewing its own plan shares every assumption that produced it. Read-only; it reports, the planner revises. Max 2 revision cycles.
- **delegate-execute** - Invocation 2. Delegates the plan to subagents and verifies every deliverable against the pre-committed DoD itself, never the subagent's self-report.
- **definition-of-done** - Writes a concrete, checkable DoD into a spec before any code exists; selects verification modes with honest costs.

The workflow skill enforces a strict process (see `.claude/skills/workflow/SKILL.md`):
1. Check for work → 2. Run intake (create branch) → 2b. Set up worktree → 3. Assess task definition → 3b. Optional human intake review → 4. Plan the task → 4a. AI hostile plan review → 4b. Human plan review (required) → 5. Implement changes → 6. Verify acceptance criteria → 7. Unit tests → 8. E2E tests → 8b. Lint & format → 9. Write implementation notes → 10. AI code review → 10b. Optional human code review → 11. Audit all steps → 11b. Self-improvement recommendation → 12. Merge guard (scope check) → 13. Closeout (squash, push, open GitHub PR, move to Human Code Review, tear down worktree)

**Key workflow behaviors:**
- All task reads and writes use the tracker contract verbs via the `manage-backlog-tasks` skill's active adapter
- The tracker issue key is the `<id>` throughout the workflow (e.g., `PROJ-42` under the current JIRA adapter)
- JIRA status lifecycle: `To Do → Intake → Plan → Code → AI Code Review → Human Code Review → Done` (optional earlier gate: `Intake Review`; `Plan Review` is the status used by the required plan gate). `Human Code Review` is also closeout's mandatory hand-off state — `Done` is always a human-only transition, made after reviewing the PR
- Uses gitflow branch naming: `feature/<issue-key>-description`, `fix/<issue-key>-description`, etc.
- Commits at closeout only (not between steps) — all changes accumulate in worktree
- Merge guard (Step 12) runs **before** closeout hands off for human review — compares the **working tree** (uncommitted changes since base, since commits are deferred to Step 13) against the plan's `### Files in scope` section plus any `## [SCOPE CHANGE]` comments to detect scope creep
- Closeout (Step 13) never marks the task Done. It moves the issue to Human Code Review after the PR is opened; a human reviews the PR and transitions the issue to Done themselves.
- Retries are bounded: AC verification, unit tests, e2e tests, lint/format, hostile plan review max 2 retries each; code review max 1 fix iteration. Counters are cumulative per run (never reset), and a global ceiling of 6 total returns to implementation blocks a thrashing task
- Emits `TASK_COMPLETE: <id> — <title>` on success or `WORKFLOW_BLOCKED: <reason>` on failure

## Working with the Workflow

When the user says "coordinate a task" or wants full SDLC automation, invoke the `workflow` skill. It will handle the entire lifecycle autonomously. The workflow operates on one task at a time. Intake starts from the base branch (`develop`) and cuts the feature branch itself; from the worktree onward every step runs on that feature branch, and the merge guard refuses to run on main/master/develop/staging.

The default/base branch that feature branches are cut from (and diffed, reviewed, and PR'd against, absent an explicit `Base:` override recorded at intake) is `develop`.

For manual operations, use individual skills like `unit-tests`, `e2e-tests`, `commit`, etc. or interact directly with JIRA via the MCP tools.

## Infrastructure & Cloud Guardrails

These rules are policy, and are also mechanically enforced as `deny`/`ask` permission rules in `.claude/settings.json` — they are not just documentation to follow, they block the tool call.

- **Never run `terraform apply` or `terraform destroy`.** Infrastructure changes are applied by a human (or CI) outside of an agent session, after review. If a task seems to require one, stop and hand it to a human instead of finding a workaround.
- **Never run an AWS CLI command that isn't read-only.** Only `describe-*`, `get-*`, `list-*`, `head-*`, `aws s3 ls`, and `aws sts get-caller-identity` are allowed to run automatically. Any mutating verb (`create-*`, `delete-*`, `put-*`, `update-*`, `modify-*`, `run-*`, `start-*`, `stop-*`, `terminate-*`, `attach-*`, `tag-*`, `invoke-*`, `publish-*`, `send-*`, `execute-*`, `assume-*`, `copy-*`, `import-*`, `aws s3 rm/mv/sync/cp`, `aws configure`, etc.) is denied outright. Anything not explicitly allowed or denied still requires interactive human approval before it runs — it is never silently executed.
- **Never run `cdk deploy` or `cdk destroy`.** Same reasoning as Terraform apply/destroy — these mutate live infrastructure and must go through human/CI review, not an agent session.
- **Never force-push** (`git push --force`, `git push -f`). Rewriting shared branch history is a human decision, especially on a repo where audit trail and history integrity matter.
- **Never run `rm -rf /*`** or any other wipe-the-filesystem command.
- This mirrors the "no custody, no destructive infra changes without a human" posture the platform needs for SOC 2 credibility with CDFIs, banks, and regulators — see the org-level security posture for the broader rationale.

## Agent Configuration Changes

Claude **may** change its own guidance and configuration in this repo — this is a workflow-development repo, and evolving the skills is the point. But every such change is surfaced for human approval rather than applied silently.

The following are `ask` permission rules in `.claude/settings.json`, so the tool call pauses for interactive approval instead of being blocked:

- `CLAUDE.md` (at any depth, including inside worktrees)
- `.claude/settings.json` and `.claude/settings.local.json`
- `.claude/skills/`, `.claude/hooks/`, `.claude/agents/`, `.claude/commands/`

`.claude/worktrees/**` is deliberately **excluded** — all task work happens inside a worktree, so prompting there would make the workflow unusable. The rules are written as `Edit(**/.claude/skills/**)` and friends, which reach both the main checkout and the copies inside each worktree without touching worktree source files.

Two mechanical notes for anyone editing these rules:

- Use `Edit(...)`, never `Write(...)`. Per the Claude Code permissions docs, `Write(path)` rules "are not matched by file permission checks — only `Edit(path)` rules are"; `Edit` covers Write, Edit, and NotebookEdit. A `Write(...)` rule is inert and emits a startup warning.
- `deny` beats `ask` beats `allow`, first match wins, and specificity does not matter. An `ask` rule never fires if a `deny` rule also matches the same path.

Accepted trade-off: because these are `ask` and not `deny`, an approved edit can reach the hooks that do the enforcing. The audit log (below) is what makes that visible after the fact. This is a deliberate choice for a repo under active development, not an oversight.

Second trade-off, currently accepted: an `ask` rule only prompts in a permission mode that prompts. Under `auto` a classifier resolves it and under `bypassPermissions` it is skipped, so in those modes the review above happens **after** the change via the audit log rather than before it via a prompt. `deny` rules and the hooks are unaffected and fire in every mode. See `docs/agents/claude-code-guardrails.md` §6 for the exact settings change if this ever needs to become a hard gate.

## Secrets & Privacy

- **Never read, edit, grep, or glob a secret-bearing file.** This covers `.env` and every `.env.*` variant at any depth, `*.env`, key material (`*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`, …), `*.tfvars`, `.netrc`, `.npmrc`, `.pypirc`, `~/.aws/credentials`, `~/.ssh/**`, `~/.kube/config`, `~/.docker/config.json`, and `~/.config/gh/hosts.yml`.
- **Templates and local config are explicitly allowed**: `.env.example`, `.env.sample`, `.env.template`, `.env.dist`, `*.pub`, and `.claude/*.local.json`. When a task needs a new configuration value, add it to the `.example` file and ask the human to populate the real one out of band.
- `.claude/*.local.json` — including `jira-connection.local.json` — is **local configuration, not secret material**. It records which tracker connection to use, and the agent must be able to read it. Credentials live in the MCP connection, not in the file. It stays gitignored, and `Edit(**/.claude/settings.local.json)` remains an `ask` rule since it carries permission grants.
- This is enforced by `.claude/hooks/block-secret-file-access.sh` rather than a permission rule, because gitignore-style permission patterns have **no negation operator** — `deny(.env.*)` would also swallow `.env.example`, and no `allow` rule can claw it back.
- **Never write secret material into a file or a command.** AWS access key IDs (`AKIA…`), PEM private-key blocks, and `sk-…` API keys are blocked in Edit/Write content and in Bash command strings.
- **Never print a live credential into the transcript.** `gh auth token`, `gh config get -h github.com oauth_token`, and equivalents are denied — transcripts flow into logs, memory files, and compaction summaries.
- Permission rules for `Read`/`Edit` also cover file commands Claude Code recognises in Bash (`cat`, `head`, `tail`, `sed`), but **not** arbitrary subprocesses (`python -c`, `node -e`). The hook's Bash arm covers the common remainder; OS-level enforcement would require sandboxing.

## Git & GitHub Guardrails

Beyond the branch protection below, these are blocked because this workflow defers all commits to closeout (Step 13) — uncommitted working-tree state **is** the task's work product, for the whole run.

- **Work destruction is denied**: `git reset --hard`, `git clean -f*`, `git checkout -- .`, `git restore <path>`, `git checkout HEAD -- <path>`, `git branch -D`, `git reflog expire`, `git gc --prune`, `git filter-branch`.
- **Safe variants are deliberately permitted**, because a blanket ban on these subcommands blocked ordinary development:
  - `git reset --soft` — closeout's squash needs it.
  - `git clean -n` / `--dry-run` — deletes nothing; previewing stray files is useful.
  - `git restore --staged` — unstages only, the working tree keeps its changes. Combined with `--worktree` it does discard, and stays denied.
  - `git branch -d` — git already refuses to delete an unmerged branch. Only `-D` forces it.
  - plain `git gc` — routine maintenance git runs on its own; its default two-week prune horizon leaves today's work recoverable.
  - `git stash list` / `show` — read-only.
- These exceptions live in `.claude/hooks/block-destructive-git.sh`, **not** in `settings.json`, for a structural reason: a permission rule has no negation operator and `deny` beats everything, so `Bash(git clean*)` cannot carve out `-n`. Nuanced rules belong in a hook; `settings.json` should only hold rules with no legitimate variant.
- **`git stash` (push) requires approval.** It is not destructive, so nothing flags it, but it silently empties the worktree and the next workflow step reports the implementation missing. `git stash drop` / `clear` are denied outright.
- **`git worktree remove --force` requires approval.** Closeout legitimately tears down the worktree, so this is `ask`, not `deny`.
- **Remote and config tampering is denied**: `git remote add` / `set-url` (repointing origin exfiltrates the whole repo and bypasses network egress checks), `git config` writes to `core.hooksPath` / `credential.helper` / `alias.*` (arbitrary execution and credential theft laundered through a git subcommand), any `git config --global`, and `git submodule add` / `update --remote`.
- **Remote branch deletion and mass-push are denied**: `git push --delete`, `git push origin :branch`, `git push --mirror`, `git push --all`.
- **`--no-verify` is denied** on commit and push — it would bypass the `.githooks/` layer described below.
- **`gh pr merge` is denied.** Closeout hands off at Human Code Review; a human reviews the PR and transitions the issue to Done. Nothing in an agent session merges. Also denied: `gh repo delete`, `gh release delete`, `gh secret set`, and `gh api` with `-X POST/PATCH/PUT/DELETE` (arbitrary GitHub mutation, and an egress channel invisible to the curl-based check). `gh config get` is denied only for credential keys — `gh config get git_protocol` is fine.
- **Outbound POSTs require approval rather than being blocked.** `curl -d`/`-T`/`-F` and `wget --post` to a non-localhost host prompt, because testing a staging endpoint or a third-party API is legitimate work. Unambiguous exfiltration shapes stay hard denials: archive-or-encode piped into a network tool, `printenv | curl`, raw sockets (`nc`/`socat`), and `scp`/`rsync` to a remote host. A prompt still halts an unattended run, so an autonomous attempt cannot self-approve.

## Audit Trail

Three append-only JSONL files under `logs/audit/`, gitignored — local forensic evidence, not a committed artifact:

- `attempts.jsonl` — every tool call **attempted**, written by `audit-attempt-log.sh` at `PreToolUse` *before* any hook or permission rule can block it.
- `commands.jsonl` — every Bash command that **executed** (`audit-command-log.sh`).
- `file-changes.jsonl` — every file change that **executed** (`audit-file-change-log.sh`), flagging guardrail files with `"guardrail":true`.

The split is structural, not redundant: `PostToolUse` only fires on calls that run, so a *blocked* command can only be recorded before the fact. All three emit a shared content-derived `id`, so "what was denied" is a join between the attempt log and the execution logs rather than a guess. Together they answer **"everything the agent tried"**, not just "everything it did" — the record the SOC 2 posture above implies.

Queries, and two honest caveats about the join (in-flight calls look denied; repeated identical calls share an id), are in `docs/agents/claude-code-guardrails.md` §8.

Unlike the blocking hooks, the audit hooks **fail open** — a logging failure exits 0 rather than halting work.

## Branch Protection

- **Never push directly to `main`, `develop`, `staging`, or `master`.** These are trunk/environment branches; all changes land through a pull request opened against the appropriate base (see `open-pr` skill), never a direct push.
- This is enforced at **two** layers, deliberately:
  1. `deny` rules on `git push` in `.claude/settings.json` — these match the *command string*, so they are pattern-based and incomplete by nature.
  2. `.githooks/pre-push` — this sees the **resolved refspec**, so it catches what the string match cannot.
- The second layer exists because the first is bypassable: `Bash(git push origin develop*)` does not match `git push origin HEAD:develop`, nor `git push origin feature/x:develop`, and both push to `develop`. Never rely on the permission rule alone.
- The `.githooks/` directory is only active once `core.hooksPath` points at it: `git config core.hooksPath .githooks`. This is a one-time human setup step per clone — `.git/hooks/` is not versioned and does not survive a fresh clone. `git config` writes are otherwise denied (see above), so an agent cannot unset it.

## Agent skills

### Issue tracker

Issues are tracked via the tracker contract (issue keys like `KAN-42` under the current JIRA adapter). See `docs/agents/issue-tracker.md`.

### Triage labels

Triage roles map to JIRA statuses, not labels (`Triage`, `Needs Info`, `To Do`, `Ready for Human`, `Done`/Won't Do). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
