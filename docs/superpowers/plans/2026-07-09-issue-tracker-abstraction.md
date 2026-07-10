# Issue-Tracker Abstraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple every SDLC skill from JIRA so the issue tracker can be swapped by editing one pointer. All vendor-specific commands move behind a tracker-agnostic **capability contract**; concrete calls live only in per-tracker **adapters**.

**Architecture:** Hybrid contract + adapters. `docs/agents/issue-tracker.md` holds the agnostic **contract** (capability verbs, workflow-phase vocabulary, comment-marker schema, AC model) and a single "Active adapter" pointer. The `manage-backlog-tasks` skill holds the **adapters** — one file per tracker under `adapters/`, each mapping every contract verb to concrete calls. The JIRA adapter (`adapters/jira.md`) is the current MCP content, relocated. An example GitHub adapter (`adapters/github.md`) proves the contract is genuinely tracker-neutral. The ~19 component skills stop naming `mcp__plugin_atlassian_atlassian__*` entirely and speak only contract verbs.

**Tech Stack:** Markdown skill/doc files interpreted by Claude Code. The tracker is reached through the Atlassian MCP tools (agent-invoked), so the abstraction is a **prose indirection**, not a code layer — the contract names an operation, the active adapter says which tool call realizes it. Verification is grep-based; the real correctness test is Task 3 (a second adapter that satisfies every verb).

## Global Constraints

- **This plan assumes the review-fixes plan (`2026-07-09-sdlc-workflow-review-fixes.md`) has already landed.** Both plans edit the same ~19 skill files. The review-fixes work adds new tracker calls (`## [BLOCKED]` comment + `workflow-blocked` label in the blocked-exit protocol, claim-at-selection `assign`, `## [SCOPE CHANGE]` comments); this plan migrates those to verbs too. Do not run the two concurrently — land review-fixes first, then execute this. If review-fixes is abandoned, drop the `[SCOPE CHANGE]`/`[BLOCKED]` markers and the claim-at-selection verb from Tasks 1–8.
- Work on a feature branch cut from the review-fixes tip. Never push to `main`, `develop`, `staging`, `master`.
- Never edit `.claude/settings*` files (self-protecting permission config — human-only).
- **After migration, the string `mcp__plugin_atlassian_atlassian__` must not appear anywhere except `.claude/skills/manage-backlog-tasks/adapters/jira.md`.** This is the headline invariant and the final task asserts it.
- Comment-marker names are the workflow's own data schema and do not change: `[BRANCH]`, `[PLAN]`, `[NOTES]`, `[MODIFIED FILES]`, `[FINAL SUMMARY]`, `[SCOPE CHANGE]`, `[BLOCKED]`.
- Workflow completion-signal tokens (`INTAKE_COMPLETE`, `PLAN_COMPLETE`, `WORKFLOW_BLOCKED`, etc.) are unrelated to the tracker and must be left byte-for-byte unchanged.
- Every contract verb must be implemented by **both** adapters (jira and github). A verb no adapter implements, or an adapter method with no contract verb, is a defect.
- One commit per task, conventional format, scope `skills` (or `docs`).

## Target File Structure

```
docs/agents/issue-tracker.md                      # CONTRACT (agnostic) + "Active adapter: jira" pointer
.claude/skills/manage-backlog-tasks/
    SKILL.md                                       # dispatcher: names the contract, points at the active adapter
    adapters/
        jira.md                                    # JIRA/Atlassian-MCP mapping (all current SKILL.md content moves here)
        github.md                                  # example gh-CLI mapping (proves swappability; not wired live)
```

## The Capability Contract (authored in Task 1, referenced by every later task)

**Verbs** — the complete set of tracker operations the skills perform. Signatures use contract vocabulary, not vendor fields:

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

**Phase vocabulary** — contract phase → JIRA status (the mapping lives in the adapter, listed here so the contract fixes the names):

`available`→To Do, `claimed`→Intake, `intake-review`→Intake Review, `planning`→Plan, `plan-review`→Plan Review, `coding`→Code, `ai-review`→AI Code Review, `human-review`→Human Code Review, `done`→Done.

**Comment-marker schema** — the markers above. Storage is the adapter's choice (JIRA comments; GitHub could use comments or body sections); the marker names are fixed by the contract.

---

### Task 1: Author the agnostic contract in docs/agents/issue-tracker.md

**Files:**
- Modify: `docs/agents/issue-tracker.md` (full rewrite)

**Interfaces:**
- Produces: the verb names, phase vocabulary, and comment-marker schema exactly as tabulated in "The Capability Contract" above. Every later task references these names; they must match verbatim.

- [ ] **Step 1: Replace the file with the contract**

Rewrite `docs/agents/issue-tracker.md` so it contains, in this order:
1. A one-paragraph intro: "This file is the tracker-agnostic contract. Skills speak these verbs; they never name a vendor tool. The **active adapter** below resolves each verb to concrete calls. Switch trackers by changing the active-adapter pointer and ensuring that adapter implements every verb."
2. **Active adapter:** a single line — `Active adapter: jira (.claude/skills/manage-backlog-tasks/adapters/jira.md)`.
3. The **Verbs** table (copy the 12-row table from "The Capability Contract" section of this plan verbatim).
4. The **Phase vocabulary** mapping (copy verbatim).
5. The **Comment-marker schema** list (copy verbatim).
6. A short **AC model** note: ACs live in the issue description as `- [ ] #N criterion` / `- [x] #N criterion`; read via `tracker.read-acs`, checked via `tracker.set-acs`.
7. A **Switching trackers** section: "1. Add `adapters/<tracker>.md` implementing every verb. 2. Change the Active adapter line here and in `manage-backlog-tasks/SKILL.md`. 3. Update the phase→status mapping if the new tracker's states differ. No component skill changes."

- [ ] **Step 2: Verify**

Run: `grep -c "tracker\." docs/agents/issue-tracker.md`
Expected: ≥ 12 (all verbs named).

Run: `grep -n "Active adapter: jira" docs/agents/issue-tracker.md`
Expected: 1 match.

Run: `grep -c "mcp__plugin_atlassian" docs/agents/issue-tracker.md`
Expected: 0 (the contract names no vendor tool).

- [ ] **Step 3: Commit**

```bash
git add docs/agents/issue-tracker.md
git commit -m "docs(tracker): define agnostic issue-tracker capability contract"
```

---

### Task 2: Extract the JIRA adapter and slim manage-backlog-tasks to a dispatcher

**Files:**
- Create: `.claude/skills/manage-backlog-tasks/adapters/jira.md`
- Modify: `.claude/skills/manage-backlog-tasks/SKILL.md` (reduce to dispatcher)

**Interfaces:**
- Consumes: the verb names and phase vocabulary from Task 1.
- Produces: `adapters/jira.md` — the only file permitted to contain `mcp__plugin_atlassian_atlassian__`.

- [ ] **Step 1: Create the JIRA adapter, organized by verb**

Create `.claude/skills/manage-backlog-tasks/adapters/jira.md`. Move **all** concrete content currently in `manage-backlog-tasks/SKILL.md` (Cloud ID discovery, Project discovery, Data Model table, Core Operations, transitions, flagged/blocked, AC management, Status Reference, the Full Workflow Example) into it, but restructure under one `## tracker.<verb>` heading per contract verb. Each heading gives the exact MCP call(s) that realize the verb. Specifically:

- `## tracker.session-init` — Cloud ID discovery (`getAccessibleAtlassianResources`) + project discovery (`getVisibleJiraProjects`). Capture `<cloudId>` and project key; reuse for the run.
- `## tracker.find-work` — the JQL search (`searchJiraIssuesUsingJql`) with the priority ordering and the `assignee IS EMPTY OR assignee = currentUser()` filter, plus per-candidate `tracker.is-blocked-or-flagged`.
- `## tracker.read` — `getJiraIssue`.
- `## tracker.create` — `createJiraIssue` with `additional_fields` note.
- `## tracker.set-phase` — the phase→status table + the discover-then-`transitionJiraIssue({id})` two-step.
- `## tracker.assign` — `editJiraIssue(fields:{assignee:{accountId}})` + `lookupJiraAccountId`.
- `## tracker.comment` — `addCommentToJiraIssue(commentBody)` with the marker-header convention.
- `## tracker.read-comments` — `getJiraIssue` with `responseContentFormat: "markdown"` (the ADF quirk) and marker filtering.
- `## tracker.read-acs` / `## tracker.set-acs` — the description-parse and single-`editJiraIssue`-per-pass rules.
- `## tracker.set-labels` — `editJiraIssue(fields:{labels})`, read-modify-write.
- `## tracker.is-blocked-or-flagged` — the `getIssueLinkTypes` / `getJiraIssueTypeMetaWithFields` discovery and the flagged/blocked resolution logic (including PR-state check for blockers).

Fix the stale bits while relocating: the Full Workflow Example must end at `human-review`, never `done` (this is also review-fixes Task 2 — if that already landed, carry the corrected version).

- [ ] **Step 2: Reduce SKILL.md to a dispatcher**

Rewrite `.claude/skills/manage-backlog-tasks/SKILL.md` to a short file:
- Keep the frontmatter `name: manage-backlog-tasks`; update the description to "Implements the issue-tracker contract (`docs/agents/issue-tracker.md`) for the active tracker. Resolves contract verbs to concrete tracker calls."
- Body: "This skill implements the tracker contract defined in `docs/agents/issue-tracker.md`. **Active adapter: jira** — see `adapters/jira.md` for the concrete call for each `tracker.<verb>`. To use a verb a skill named, open the active adapter and follow the matching `## tracker.<verb>` section. Switching trackers: see the contract's Switching trackers section."
- Nothing vendor-specific stays in SKILL.md.

- [ ] **Step 3: Verify**

Run: `grep -rl "mcp__plugin_atlassian_atlassian__" .claude/skills/manage-backlog-tasks/`
Expected: only `adapters/jira.md`.

Run: `grep -c "## tracker\." .claude/skills/manage-backlog-tasks/adapters/jira.md`
Expected: 12 (one section per verb).

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/manage-backlog-tasks/SKILL.md`
Expected: 0.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/manage-backlog-tasks/
git commit -m "refactor(skills): extract JIRA adapter, reduce manage-backlog-tasks to a dispatcher"
```

---

### Task 3: Author an example GitHub adapter to validate the contract

This is the real test of the abstraction: if every verb maps cleanly to `gh`, the contract is genuinely tracker-neutral. If a verb can't be expressed, the contract is leaky and Task 1 needs revision.

**Files:**
- Create: `.claude/skills/manage-backlog-tasks/adapters/github.md`

**Interfaces:**
- Consumes: the verb list and phase vocabulary from Task 1.

- [ ] **Step 1: Implement every verb via `gh`**

Create `adapters/github.md` with one `## tracker.<verb>` section per contract verb, each giving the `gh` realization. Map deliberately:
- `session-init` — `gh repo view` (resolve owner/repo); no cloudId concept.
- `find-work` — `gh issue list --state open --label ready --json ...` ordered by a priority label; exclude issues with a `blocked` label or open `blocked-by` task-list references.
- `read` — `gh issue view <id> --json title,body,labels,comments,assignees,state`.
- `create` — `gh issue create --title --body`.
- `set-phase` — phase→**label** mapping (GitHub has no status workflow): remove the old phase label, add the new one (`gh issue edit --add-label --remove-label`); `done` → `gh issue close`.
- `assign` — `gh issue edit --add-assignee`.
- `comment` — `gh issue comment --body` with the same marker header.
- `read-comments` — from the `read` JSON `comments[]`, filter by marker.
- `read-acs` / `set-acs` — parse/rewrite the `- [ ] #N` lines in the body; `gh issue edit --body`.
- `set-labels` — `gh issue edit --add-label/--remove-label`.
- `is-blocked-or-flagged` — presence of a `blocked`/`flagged` label, or an unchecked `blocked by #N` line whose referenced issue is open.

- [ ] **Step 2: Note the phase-model difference**

At the top of `github.md`, state plainly: "GitHub has no status state machine — workflow phases are modeled as mutually-exclusive `phase:*` labels, and `done` closes the issue. If you activate this adapter, update the phase→status mapping note in the contract accordingly." This surfaces the one place the contract's phase vocabulary meets tracker reality.

- [ ] **Step 3: Verify (contract parity)**

Run: `comm -3 <(grep -o "tracker\.[a-z-]*" docs/agents/issue-tracker.md | sort -u) <(grep -o "tracker\.[a-z-]*" .claude/skills/manage-backlog-tasks/adapters/github.md | sort -u)`
Expected: no output (every contract verb is implemented; no extra verbs invented).

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/manage-backlog-tasks/adapters/github.md
git commit -m "docs(tracker): add example GitHub adapter to validate contract coverage"
```

---

### Task 4: Migrate check-for-work to contract verbs

The hardest component skill — session init, work search, flagged/blocked, claim.

**Files:**
- Modify: `.claude/skills/check-for-work/SKILL.md`

**Interfaces:**
- Consumes: `tracker.session-init`, `tracker.find-work`, `tracker.is-blocked-or-flagged`, `tracker.assign` from Task 1.

- [ ] **Step 1: Replace all MCP calls with verbs**

Rewrite the process so it reads: "1. `tracker.session-init` (see the active adapter). 2. `tracker.find-work [key]` — returns the next claimable issue honoring flagged/blocked, or verifies a named key. 3. If none, emit `NO_WORK_AVAILABLE`. 4. `tracker.assign <id> <current user>` to claim. 5. Emit `<id> — <summary>`." Move the flagged/blocked resolution detail and the PR-state check out — they now live in the adapter behind `tracker.is-blocked-or-flagged` and `tracker.find-work`. Keep every completion-signal token unchanged. Delete the `getAccessibleAtlassianResources`/`getVisibleJiraProjects`/`getIssueLinkTypes`/`getJiraIssueTypeMetaWithFields`/`searchJiraIssuesUsingJql`/`getJiraIssue` blocks.

- [ ] **Step 2: Verify**

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/check-for-work/SKILL.md`
Expected: 0.

Run: `grep -c "tracker\." .claude/skills/check-for-work/SKILL.md`
Expected: ≥ 3.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/check-for-work/SKILL.md
git commit -m "refactor(skills): migrate check-for-work to tracker contract verbs"
```

---

### Task 5: Migrate intake and closeout to contract verbs

**Files:**
- Modify: `.claude/skills/intake/SKILL.md`
- Modify: `.claude/skills/closeout/SKILL.md`

**Interfaces:**
- Consumes: `tracker.set-phase`, `tracker.assign`, `tracker.comment`, `tracker.read-comments`.

- [ ] **Step 1: Migrate intake**

Replace the transition + assign + branch-comment MCP blocks with: `tracker.set-phase <id> claimed`; `tracker.assign <id> <current user>`; `tracker.comment <id> [BRANCH] "<branch>\n\nBase: <base>"`. Preserve the branch-derivation and idempotent-checkout logic (from review-fixes Task 14 if landed) and `INTAKE_COMPLETE`.

- [ ] **Step 2: Migrate closeout**

Replace: reading the `Base:` line → `tracker.read-comments <id> [BRANCH]`; the Final Summary MCP call → `tracker.comment <id> [FINAL SUMMARY] "<body>"`; the Human Code Review transition → `tracker.set-phase <id> human-review`. Leave the git/`gh` PR mechanics, squash script, worktree teardown, and checkpoint deletion untouched (those are not tracker ops).

- [ ] **Step 3: Verify**

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/intake/SKILL.md .claude/skills/closeout/SKILL.md`
Expected: 0 for both.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/intake/SKILL.md .claude/skills/closeout/SKILL.md
git commit -m "refactor(skills): migrate intake and closeout to tracker contract verbs"
```

---

### Task 6: Migrate planning and gate skills to contract verbs

**Files:**
- Modify: `.claude/skills/plan-task/SKILL.md`
- Modify: `.claude/skills/hostile-plan-review/SKILL.md`
- Modify: `.claude/skills/plan-gate/SKILL.md`
- Modify: `.claude/skills/intake-gate/SKILL.md`
- Modify: `.claude/skills/code-review-gate/SKILL.md`

**Interfaces:**
- Consumes: `tracker.set-phase`, `tracker.read`, `tracker.comment`.

- [ ] **Step 1: Migrate each**

- plan-task: transition → `tracker.set-phase <id> planning`; read → `tracker.read <id>`; plan comment → `tracker.comment <id> [PLAN] "<spec + ### Files in scope>"` (keep the scope section from review-fixes Task 5).
- hostile-plan-review: read → `tracker.read`; findings comment → `tracker.comment <id> [NOTES] "..."` (preserve its existing marker).
- plan-gate: transition to Plan Review → `tracker.set-phase <id> plan-review`; revision comment → `tracker.comment`; keep the interactive approve/retry logic and `PLAN_GATE_APPROVED`.
- intake-gate: transition to Intake Review → `tracker.set-phase <id> intake-review`; comment → `tracker.comment`.
- code-review-gate: transition to Human Code Review → `tracker.set-phase <id> human-review`; comment → `tracker.comment`.

- [ ] **Step 2: Verify**

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/plan-task/SKILL.md .claude/skills/hostile-plan-review/SKILL.md .claude/skills/plan-gate/SKILL.md .claude/skills/intake-gate/SKILL.md .claude/skills/code-review-gate/SKILL.md`
Expected: 0 for all.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/plan-task/SKILL.md .claude/skills/hostile-plan-review/SKILL.md .claude/skills/plan-gate/SKILL.md .claude/skills/intake-gate/SKILL.md .claude/skills/code-review-gate/SKILL.md
git commit -m "refactor(skills): migrate planning and gate skills to tracker contract verbs"
```

---

### Task 7: Migrate implementation-phase skills to contract verbs

**Files:**
- Modify: `.claude/skills/implement/SKILL.md`
- Modify: `.claude/skills/verify-ac/SKILL.md`
- Modify: `.claude/skills/implementation-notes/SKILL.md`
- Modify: `.claude/skills/assess-task/SKILL.md`

**Interfaces:**
- Consumes: `tracker.set-phase`, `tracker.read`, `tracker.read-acs`, `tracker.set-acs`, `tracker.comment`.

- [ ] **Step 1: Migrate each**

- implement: transition → `tracker.set-phase <id> coding`; read plan → `tracker.read`; deviation + `[SCOPE CHANGE]` comments (review-fixes Task 5) → `tracker.comment`.
- verify-ac: read/parse ACs → `tracker.read-acs <id>`; check off → `tracker.set-acs <id> <indexes>`.
- implementation-notes: read diff base is git (leave it); `[NOTES]` and `[MODIFIED FILES]` comments → `tracker.comment`.
- assess-task: read → `tracker.read`; refinement comment → `tracker.comment <id> [NOTES] "..."`.

- [ ] **Step 2: Verify**

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/implement/SKILL.md .claude/skills/verify-ac/SKILL.md .claude/skills/implementation-notes/SKILL.md .claude/skills/assess-task/SKILL.md`
Expected: 0 for all.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/implement/SKILL.md .claude/skills/verify-ac/SKILL.md .claude/skills/implementation-notes/SKILL.md .claude/skills/assess-task/SKILL.md
git commit -m "refactor(skills): migrate implementation-phase skills to tracker contract verbs"
```

---

### Task 8: Migrate review, guard, audit, and self-improvement skills to contract verbs

**Files:**
- Modify: `.claude/skills/code-review/SKILL.md`
- Modify: `.claude/skills/merge-guard/SKILL.md`
- Modify: `.claude/skills/audit-followed-workflow-steps/SKILL.md`
- Modify: `.claude/skills/self-improvement/SKILL.md`

**Interfaces:**
- Consumes: `tracker.set-phase`, `tracker.read`, `tracker.read-comments`, `tracker.comment`.

- [ ] **Step 1: Migrate each**

- code-review: transition → `tracker.set-phase <id> ai-review`; read description/plan → `tracker.read`; findings/summary comments → `tracker.comment`. Leave the subagent-dispatch and git-diff mechanics.
- merge-guard: read scope → `tracker.read-comments <id> [PLAN]` (the `### Files in scope` section) and `tracker.read-comments <id> [SCOPE CHANGE]` (review-fixes Task 5); blocked comment → `tracker.comment`. Leave git working-tree inspection.
- audit-followed-workflow-steps: read markers/status → `tracker.read` + `tracker.read-comments`. Leave the `git worktree list` and diff spot-checks.
- self-improvement: read → `tracker.read`; comment → `tracker.comment`.

- [ ] **Step 2: Verify**

Run: `grep -c "mcp__plugin_atlassian" .claude/skills/code-review/SKILL.md .claude/skills/merge-guard/SKILL.md .claude/skills/audit-followed-workflow-steps/SKILL.md .claude/skills/self-improvement/SKILL.md`
Expected: 0 for all.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/code-review/SKILL.md .claude/skills/merge-guard/SKILL.md .claude/skills/audit-followed-workflow-steps/SKILL.md .claude/skills/self-improvement/SKILL.md
git commit -m "refactor(skills): migrate review, guard, audit, self-improvement to tracker contract verbs"
```

---

### Task 9: Migrate the coordinator, commit skill, and CLAUDE.md

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md`
- Modify: `.claude/skills/commit/SKILL.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: all contract verbs; `tracker.session-init` (for the `<cloudId>` binding note).

- [ ] **Step 1: Migrate the coordinator's variable bindings and its one MCP call**

In `workflow/SKILL.md`: the Task Rule's inline `createJiraIssue` → `tracker.create {...}`. In Variable bindings, reframe `<cloudId>` as an adapter-managed handle: "`<cloudId>` — tracker session handle established by `tracker.session-init` in Step 1 (JIRA-specific; other adapters may not need it). Reuse for the run." Keep every step's verb usage pointing at "the `manage-backlog-tasks` skill / active adapter." Leave completion signals and the blocked-exit protocol logic; only its calls (`tracker.comment [BLOCKED]`, `tracker.set-labels add workflow-blocked`) change to verbs.

- [ ] **Step 2: Migrate the commit skill's one read**

In `commit/SKILL.md`: `getJiraIssue` → `tracker.read <id>`.

- [ ] **Step 3: Update CLAUDE.md**

Replace the "Task Management" and "Issue tracker" prose so it describes the contract/adapter split: tasks are managed through the tracker **contract** in `docs/agents/issue-tracker.md`, implemented by the `manage-backlog-tasks` adapters; JIRA is the active adapter. Update the `manage-backlog-tasks` bullet ("Documents all JIRA MCP operations…") to "Implements the issue-tracker contract; holds per-tracker adapters." Keep the JIRA issue-key `<id>` examples but note the tracker is swappable.

- [ ] **Step 4: Verify**

Run: `grep -rc "mcp__plugin_atlassian" .claude/skills/workflow/SKILL.md .claude/skills/commit/SKILL.md CLAUDE.md`
Expected: 0 for all.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/workflow/SKILL.md .claude/skills/commit/SKILL.md CLAUDE.md
git commit -m "refactor(skills): migrate coordinator, commit, and CLAUDE.md to tracker contract"
```

---

### Task 10: Final invariant sweep

**Files:**
- (verification only; fixes go back to the owning task if anything fails)

- [ ] **Step 1: Assert the headline invariant — no vendor tool outside the JIRA adapter**

Run: `grep -rl "mcp__plugin_atlassian_atlassian__" .claude/ CLAUDE.md docs/`
Expected: exactly one path — `.claude/skills/manage-backlog-tasks/adapters/jira.md`. Any other hit is a missed migration; fix it in its owning task and re-run.

- [ ] **Step 2: Assert verb parity across contract and both adapters**

Run:
```bash
c=$(grep -o "tracker\.[a-z-]*" docs/agents/issue-tracker.md | sort -u)
j=$(grep -o "## tracker\.[a-z-]*" .claude/skills/manage-backlog-tasks/adapters/jira.md | sed 's/## //' | sort -u)
g=$(grep -o "## tracker\.[a-z-]*" .claude/skills/manage-backlog-tasks/adapters/github.md | sed 's/## //' | sort -u)
echo "contract-vs-jira:"; comm -3 <(echo "$c") <(echo "$j")
echo "contract-vs-github:"; comm -3 <(echo "$c") <(echo "$g")
```
Expected: no differences under either heading — every verb the contract names is implemented by both adapters, and neither adapter invents a verb.

- [ ] **Step 3: Assert no orphan verbs in component skills**

Run: `grep -rho "tracker\.[a-z-]*" .claude/skills --include=SKILL.md | grep -v manage-backlog-tasks | sort -u`
Then confirm every verb printed appears in the contract table. (Manual check — the list should be a subset of the 12 contract verbs.)

- [ ] **Step 4: Commit (if Step 3 required a doc note) or record clean**

```bash
git commit --allow-empty -m "chore(tracker): final invariant sweep — vendor calls isolated to jira adapter"
```

---

## Finding → Task traceability

| Concern | Task |
|---|---|
| Define agnostic contract (verbs, phases, comment schema) | Task 1 |
| Isolate all JIRA/MCP syntax to one adapter | Task 2, Task 10 |
| Prove the contract is tracker-neutral (2nd adapter) | Task 3 |
| Remove `mcp__` from component skills | Tasks 4–9 |
| Make switching = one pointer change | Tasks 1, 2 (pointer), 3 (spare adapter) |
| Keep CLAUDE.md consistent with the new split | Task 9 |
| Enforce the "vendor calls only in jira.md" invariant | Task 10 |

## Open risks (call out at execution time)

- **Indirection reliability.** Prose verbs are less concrete than inline tool calls; an agent must dereference verb → adapter section. Mitigation: keep verbs ~1:1 with operations, and have each component skill say "via the `manage-backlog-tasks` skill's active adapter" so the agent always knows where to resolve. If reliability regresses in practice, the fallback is to inline the adapter's call snippet next to the verb in high-traffic skills — losing some DRY but not the single-source-of-truth.
- **MCP can't be script-wrapped.** This plan is a prose abstraction, not a code layer, because the Atlassian MCP is agent-invoked. A future move to a genuinely testable adapter would require replacing the MCP path with a CLI/REST one (the `github.md` adapter is already CLI-shaped and would port directly).
- **Overlap with review-fixes.** Both plans touch the same files; this plan assumes review-fixes landed first (see Global Constraints).
