# SDLC Workflow Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 17 findings from the two-axis review of the SDLC workflow skill system — 7 consistency defects (stale/contradictory docs) and 10 design defects (tautological merge guard, undefined retry semantics, no resumability, stranded failure paths, audit theater, no proportionality, signal fragility, e2e skip escape hatch, untested lint autofixes, non-idempotent intake).

**Architecture:** All changes are edits to markdown process documents: the coordinator (`.claude/skills/workflow/SKILL.md`), component skill docs under `.claude/skills/*/SKILL.md`, and the repo `CLAUDE.md`. No application code changes. The biggest structural change moves scope declaration from Step 9 (post-hoc, from the diff) to Step 4 (plan time), which is what makes the merge guard meaningful.

**Tech Stack:** Markdown skill documents interpreted by Claude Code. Verification is via `grep` assertions (old text gone, new text present) — there is no test suite for these docs.

## Global Constraints

- Work on the current branch `JIRA-enhancements`. Never push to `main`, `develop`, `staging`, or `master`.
- Never edit `.claude/settings*` files (self-protecting permission config — human-only).
- Signal tokens (`INTAKE_COMPLETE`, `WORKTREE_READY`, `WORKFLOW_BLOCKED`, etc.) are load-bearing protocol strings. Preserve them byte-for-byte except where a task explicitly changes one.
- Every "replace" block below is quoted verbatim from the file as it exists at plan time. If an earlier task in this plan changed text a later task touches, re-read the file first.
- Blocks fenced with four backticks contain literal three-backtick fences that belong in the target file — copy the inner content exactly, including those fences.
- One commit per task, conventional format, scope `skills` (or `docs` where only CLAUDE.md changes).
- These edits change process docs only, so the workflow's own "commits at closeout only" rule does not apply to this editing session.
- Execute tasks in order — Task 6 references the "Checkpoint & resume" section that Task 7 creates, and both land before any dependent wording elsewhere is final.

---

### Task 1: Make the plan gate consistently required (Consistency #1)

The coordinator's step 4b is required (commit `5e71c31 "make human plan review required"`), but three places still call it optional — including a contradiction *inside* the coordinator itself (line 10 lists 4b among "optional human gates").

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md:10`
- Modify: `.claude/skills/workflow/SKILL.md:87-88`
- Modify: `.claude/skills/plan-gate/SKILL.md:3,6`
- Modify: `CLAUDE.md:32,50,55`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the phrase "Step 4b … required — always runs" in workflow/SKILL.md, which Tasks 8 and 9 leave untouched.

- [ ] **Step 1: Fix the coordinator's autonomy-override paragraph**

In `.claude/skills/workflow/SKILL.md`, replace:

```
The optional human gates in this workflow are steps 3b, 4b, and 10b, and they only activate when explicitly enabled.
```

with:

```
The optional human gates in this workflow are steps 3b and 10b, and they only activate when explicitly enabled. Step 4b (human plan approval) is **required** and always runs.
```

- [ ] **Step 2: Mark Step 4b required in the coordinator**

In `.claude/skills/workflow/SKILL.md`, replace:

```
## Step 4b: Human planning approval

Use the `plan-gate` skill. It presents the plan to the human interactively:
```

with:

```
## Step 4b: Human planning approval (required — always runs)

Use the `plan-gate` skill. Unlike Steps 3b and 10b this gate is not skip-by-default — it always runs. It presents the plan to the human interactively:
```

- [ ] **Step 3: Fix plan-gate's own description and invocation guard**

In `.claude/skills/plan-gate/SKILL.md`, replace the frontmatter description:

```
description: Optional human planning approval gate — present the implementation plan to the human for approval before coding begins
```

with:

```
description: Required human planning approval gate — present the implementation plan to the human for approval before coding begins
```

and replace:

```
You are the plan gate agent. This skill is only invoked when the user has explicitly requested a human planning approval gate. Do not call this skill unless that gate has been enabled.
```

with:

```
You are the plan gate agent. This gate is a required workflow step (Step 4b) — it always runs, after the hostile plan review and before implementation.
```

- [ ] **Step 4: Fix CLAUDE.md's three "optional" references**

In `CLAUDE.md`, replace:

```
- **plan-gate** - Optional human planning approval gate (Step 4b)
```

with:

```
- **plan-gate** - Required human planning approval gate (Step 4b)
```

Then in the numbered step list (line 50), replace the fragment:

```
4a. AI hostile plan review → 4b. Optional human plan review → 5. Implement changes
```

with:

```
4a. AI hostile plan review → 4b. Human plan review (required) → 5. Implement changes
```

Then in the status lifecycle line (line 55), replace:

```
(optional earlier gates: `Intake Review`, `Plan Review`)
```

with:

```
(optional earlier gate: `Intake Review`; `Plan Review` is the status used by the required plan gate)
```

- [ ] **Step 5: Verify**

Run: `grep -rn "Optional human plan\|only invoked when the user has explicitly requested a human planning" CLAUDE.md .claude/skills/plan-gate/SKILL.md .claude/skills/workflow/SKILL.md`
Expected: no matches.

Run: `grep -c "required" .claude/skills/plan-gate/SKILL.md`
Expected: ≥ 1.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/workflow/SKILL.md .claude/skills/plan-gate/SKILL.md CLAUDE.md
git commit -m "fix(skills): make plan gate consistently required across coordinator, plan-gate, and CLAUDE.md"
```

---

### Task 2: Stop the manage-backlog-tasks example from transitioning to Done (Consistency #2)

The "Full Workflow Example" models the forbidden terminal behavior — an agent transitioning to Done.

**Files:**
- Modify: `.claude/skills/manage-backlog-tasks/SKILL.md:280-284`

- [ ] **Step 1: Rewrite the example's final section**

In `.claude/skills/manage-backlog-tasks/SKILL.md`, replace:

```
# 10. Add final summary and mark done
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [FINAL SUMMARY]\n\nImplemented X using Y pattern. Updated files Z, W.")
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Done" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })
```

with:

```
# 10. Add final summary and hand off for human review
addCommentToJiraIssue(issueIdOrKey: "PROJ-42", commentBody: "## [FINAL SUMMARY]\n\nImplemented X using Y pattern. Updated files Z, W.")
getTransitionsForJiraIssue(issueIdOrKey: "PROJ-42") → find "Human Code Review" transition id
transitionJiraIssue(issueIdOrKey: "PROJ-42", transition: { id: transitionId })

# NOTE: the agent never transitions an issue to Done. A human reviews the
# pushed PR and makes the Done transition themselves.
```

- [ ] **Step 2: Verify**

Run: `grep -n '"Done" transition' .claude/skills/manage-backlog-tasks/SKILL.md`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/manage-backlog-tasks/SKILL.md
git commit -m "fix(skills): manage-backlog-tasks example hands off to Human Code Review, never Done"
```

---

### Task 3: Fix setup-worktree's stale intake-commits claim and backlog/ reference (Consistency #3, #6)

**Files:**
- Modify: `.claude/skills/setup-worktree/SKILL.md:32,68`

- [ ] **Step 1: Correct the clean-checkout rationale**

In `.claude/skills/setup-worktree/SKILL.md`, replace:

```
The intake skill commits the backlog task change before emitting `INTAKE_COMPLETE`, so this checkout is always clean (no uncommitted edits to carry over).
```

with:

```
Intake makes no local file edits (all task state lives in JIRA, and commits are deferred to closeout), so this checkout is clean — there are no uncommitted edits to carry over.
```

- [ ] **Step 2: Remove the phantom `backlog/` directory**

Replace:

```
The worktree is a complete checkout of the feature branch at the moment of creation. Every directory and file in the repo is present: `frontend/`, `backend/`, `e2e/`, `backlog/`, `.claude/`, scripts — everything.
```

with:

```
The worktree is a complete checkout of the feature branch at the moment of creation. Every directory and file in the repo is present: `frontend/`, `backend/`, `e2e/`, `.claude/`, scripts — everything.
```

- [ ] **Step 3: Verify**

Run: `grep -n "backlog" .claude/skills/setup-worktree/SKILL.md`
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/setup-worktree/SKILL.md
git commit -m "fix(skills): remove stale Backlog.md-era claims from setup-worktree"
```

---

### Task 4: Small drift fixes — CLAUDE.md closeout/precondition, `task-3` example, WORKTREE_BLOCKED branch (Consistency #4, #5, #7 + CLAUDE.md:45 drift)

**Files:**
- Modify: `CLAUDE.md:45,65`
- Modify: `.claude/skills/workflow/SKILL.md:21,59-63`

- [ ] **Step 1: Fix CLAUDE.md's closeout description (says "marks the task Done" — it never does)**

In `CLAUDE.md`, replace:

```
- **closeout** - Commits, squashes, pushes, opens the PR, and marks the task Done
```

with:

```
- **closeout** - Commits, squashes, pushes, opens the PR, and moves the task to Human Code Review
```

- [ ] **Step 2: Qualify the feature-branch precondition (it contradicts intake, which must start from trunk)**

In `CLAUDE.md`, replace:

```
When the user says "coordinate a task" or wants full SDLC automation, invoke the `workflow` skill. It will handle the entire lifecycle autonomously. The workflow operates on one task at a time and requires a feature branch (blocks if on main/master/develop/staging).
```

with:

```
When the user says "coordinate a task" or wants full SDLC automation, invoke the `workflow` skill. It will handle the entire lifecycle autonomously. The workflow operates on one task at a time. Intake starts from the base branch (`develop`) and cuts the feature branch itself; from the worktree onward every step runs on that feature branch, and the merge guard refuses to run on main/master/develop/staging.
```

- [ ] **Step 3: Fix the stale `task-3` binding example**

In `.claude/skills/workflow/SKILL.md`, replace:

```
- `<id>` — the task ID claimed in Step 1 (e.g., `task-3`)
```

with:

```
- `<id>` — the JIRA issue key claimed in Step 1 (e.g., `KAN-42`)
```

- [ ] **Step 4: Handle WORKTREE_BLOCKED explicitly in Step 2b**

In `.claude/skills/workflow/SKILL.md`, replace:

```
Capture `<worktree>` from the emitted `WORKTREE_READY: <worktree>`. All subsequent steps run from `<worktree>` as the working root.
```

with:

```
Capture `<worktree>` from the emitted `WORKTREE_READY: <worktree>`. All subsequent steps run from `<worktree>` as the working root.

If `WORKTREE_BLOCKED` is emitted (bootstrap failure), propagate as `WORKFLOW_BLOCKED: <propagated reason>` and stop.
```

- [ ] **Step 5: Verify**

Run: `grep -n "task-3\|marks the task Done\|requires a feature branch" CLAUDE.md .claude/skills/workflow/SKILL.md`
Expected: no matches.

Run: `grep -c "WORKTREE_BLOCKED" .claude/skills/workflow/SKILL.md`
Expected: 1.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md .claude/skills/workflow/SKILL.md
git commit -m "fix(skills): correct closeout/precondition drift in CLAUDE.md, stale id example, handle WORKTREE_BLOCKED"
```

---

### Task 5: Declare scope at plan time so the merge guard can actually fail (Design #1 — critical)

Today `implementation-notes` derives `## [MODIFIED FILES]` from the actual diff and `merge-guard` compares the actual diff against it — a tautology. Move scope declaration to `plan-task` (`### Files in scope` in the `## [PLAN]` comment), add a `## [SCOPE CHANGE]` protocol in `implement` for legitimate drift, and point `merge-guard` at plan scope + scope changes.

**Files:**
- Modify: `.claude/skills/plan-task/SKILL.md` (step 4 bullets + Rules)
- Modify: `.claude/skills/implement/SKILL.md` (step 4 + Rules)
- Modify: `.claude/skills/merge-guard/SKILL.md` (step 2 + Rules)
- Modify: `.claude/skills/implementation-notes/SKILL.md` (step 5)
- Modify: `CLAUDE.md:58`
- Modify: `.claude/skills/audit-followed-workflow-steps/SKILL.md` (Step 4 checklist)

**Interfaces:**
- Produces: JIRA comment sections `### Files in scope` (inside `## [PLAN]`) and `## [SCOPE CHANGE]` — consumed by merge-guard here and by the audit spot-checks in Task 9.

- [ ] **Step 1: Require a scope section in the plan spec**

In `.claude/skills/plan-task/SKILL.md`, replace:

```
   - **Scoped** — list what is explicitly *out* of scope so implementation does not drift.
```

with:

```
   - **Scoped** — list what is explicitly *out* of scope so implementation does not drift.
   - **Scope-declared** — end the spec with a `### Files in scope` section: one file per line, prefixed `- `, listing every file the implementation is expected to add or change (exact paths; a glob like `frontend/src/components/auth/*` is acceptable for a new directory). This list is the scope the merge guard (Step 12) enforces — files changed outside it require a `## [SCOPE CHANGE]` comment at implementation time.
```

And in the Rules section of the same file, replace:

```
- The spec drives implementation, AC verification, and code review later; make it specific enough to check against directly
```

with:

```
- The spec drives implementation, AC verification, and code review later; make it specific enough to check against directly
- The `### Files in scope` section is mandatory — without it the merge guard cannot enforce scope
```

- [ ] **Step 2: Add the scope-change protocol to implement**

In `.claude/skills/implement/SKILL.md`, replace:

````
4. **If implementation reveals that the plan is incorrect or incomplete**, note the deviation:

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     commentBody: "## [NOTES]\n\nPlan deviation: <what changed and why>"
   )
   ```
````

with:

````
4. **If implementation reveals that the plan is incorrect or incomplete**, note the deviation:

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     commentBody: "## [NOTES]\n\nPlan deviation: <what changed and why>"
   )
   ```

4b. **If a file outside the plan's `### Files in scope` list must change**, declare it *at the moment you touch it* — the merge guard (Step 12) blocks undeclared out-of-scope files:

   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     commentBody: "## [SCOPE CHANGE]\n\n- <file path> — <why this file must change to satisfy the ACs>"
   )
   ```

   A scope change needs a reason traceable to an AC. "While I was in there" refactors are not scope changes — leave them out entirely.
````

And in the Rules section of the same file, replace:

```
- Never add features, refactor, or clean up code beyond what the ACs require
```

with:

```
- Never add features, refactor, or clean up code beyond what the ACs require
- Never modify a file outside the plan's `### Files in scope` without posting a `## [SCOPE CHANGE]` comment first
```

- [ ] **Step 3: Point merge-guard at plan scope instead of the diff-derived list**

In `.claude/skills/merge-guard/SKILL.md`, replace:

````
2. **Read the declared scope from JIRA** — find the `## [MODIFIED FILES]` comment:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
   ```

   Scan the comments for one starting with `## [MODIFIED FILES]`. Parse the file list from it (one file per line, prefixed with `- `).
````

with:

````
2. **Read the declared scope from JIRA** — the scope is what was *planned*, never what was *changed* (comparing the diff against a list derived from the same diff proves nothing):

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
   ```

   - From the `## [PLAN]` comment, parse the `### Files in scope` section (one file or glob per line, prefixed with `- `).
   - From every `## [SCOPE CHANGE]` comment, collect the additional declared files.
   - The declared scope is the union of both. Ignore the `## [MODIFIED FILES]` comment — it is a historical record written from the diff itself.
````

Then replace the merge-guard rule:

```
- If no `## [MODIFIED FILES]` comment exists in JIRA, treat scope as unrestricted (no files are flagged as out-of-scope) and emit `MERGE_GUARD_PASSED: no scope declared`
```

with:

```
- If the `## [PLAN]` comment has no `### Files in scope` section (legacy task planned before scope declaration existed), scope cannot be enforced — emit `MERGE_GUARD_PASSED: no planned scope declared (legacy task — scope not enforced)` and continue
- Glob entries in the declared scope match with standard shell glob semantics (`frontend/src/auth/*` matches any file under that directory)
```

- [ ] **Step 4: Demote MODIFIED FILES to a historical record**

In `.claude/skills/implementation-notes/SKILL.md`, replace:

```
5. **Also record the modified files** (used by merge-guard):
```

with:

```
5. **Also record the modified files** (a historical record for reviewers; the merge guard enforces the plan's `### Files in scope`, not this list):
```

- [ ] **Step 5: Update CLAUDE.md's merge-guard description**

In `CLAUDE.md`, replace:

```
- Merge guard (Step 12) runs **before** closeout hands off for human review — compares the **working tree** (uncommitted changes since base, since commits are deferred to Step 13) against the `## [MODIFIED FILES]` JIRA comment to detect scope creep
```

with:

```
- Merge guard (Step 12) runs **before** closeout hands off for human review — compares the **working tree** (uncommitted changes since base, since commits are deferred to Step 13) against the plan's `### Files in scope` section plus any `## [SCOPE CHANGE]` comments to detect scope creep
```

- [ ] **Step 6: Make the audit check that a plan declared scope**

In `.claude/skills/audit-followed-workflow-steps/SKILL.md`, replace:

```
   **Step 4: Planning** (`plan-task` skill)
   - [ ] Task status is "Plan" or later
   - [ ] A `## [PLAN]` comment exists with the implementation plan
   - [ ] `PLAN_COMPLETE` was emitted
```

with:

```
   **Step 4: Planning** (`plan-task` skill)
   - [ ] Task status is "Plan" or later
   - [ ] A `## [PLAN]` comment exists with the implementation plan
   - [ ] The `## [PLAN]` comment contains a `### Files in scope` section
   - [ ] `PLAN_COMPLETE` was emitted
```

- [ ] **Step 7: Verify**

Run: `grep -n "MODIFIED FILES" .claude/skills/merge-guard/SKILL.md`
Expected: exactly one match — the line explaining it is ignored ("Ignore the `## [MODIFIED FILES]` comment…").

Run: `grep -rn "Files in scope" .claude/skills/plan-task/SKILL.md .claude/skills/implement/SKILL.md .claude/skills/merge-guard/SKILL.md .claude/skills/audit-followed-workflow-steps/SKILL.md CLAUDE.md | wc -l`
Expected: ≥ 6.

- [ ] **Step 8: Commit**

```bash
git add .claude/skills/plan-task/SKILL.md .claude/skills/implement/SKILL.md .claude/skills/merge-guard/SKILL.md .claude/skills/implementation-notes/SKILL.md .claude/skills/audit-followed-workflow-steps/SKILL.md CLAUDE.md
git commit -m "feat(skills): declare scope at plan time so merge guard enforces plan vs actual, not diff vs diff"
```

---

### Task 6: Define retry-counter semantics and a global iteration ceiling (Design #2)

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md:36-43` (Loop & retry caps section)
- Modify: `CLAUDE.md:60`

**Interfaces:**
- Consumes: references the "Checkpoint & resume" section that Task 7 adds (execute Tasks 6 and 7 together, in order).
- Produces: counter names `ac, unit, e2e, lint, codeReview, hostilePlan, returnsToStep5` — the checkpoint file in Task 7 persists exactly these.

- [ ] **Step 1: Rewrite the Loop & retry caps section header**

In `.claude/skills/workflow/SKILL.md`, replace:

```
## Loop & retry caps

- AC verification (Step 6): max 2 retries before emitting `WORKFLOW_BLOCKED: AC not met after 2 retries — <ids>` and stopping.
```

with:

```
## Loop & retry caps

**Counter semantics:** each counter below is per-step and **cumulative for the entire run** — it never resets, not when returning to Step 5 and not when a code-review fix iteration re-runs Steps 6–10. (Example: e2e fails once before code review and once during the code-review re-run — the e2e counter is now 2 and a third failure blocks.) Track counters as: `ac`, `unit`, `e2e`, `lint`, `codeReview`, `hostilePlan`, `returnsToStep5`, and persist them to the checkpoint file (see Checkpoint & resume) every time one increments.

**Global ceiling:** independent of the per-step caps, count every return to Step 5 regardless of cause (`returnsToStep5`). If it would exceed **6**, emit `WORKFLOW_BLOCKED: iteration ceiling reached (6 returns to implementation)` and stop — the task is thrashing and needs a human.

- AC verification (Step 6): max 2 retries before emitting `WORKFLOW_BLOCKED: AC not met after 2 retries — <ids>` and stopping.
```

- [ ] **Step 2: Update CLAUDE.md's retry summary**

In `CLAUDE.md`, replace:

```
- Retries are bounded: AC verification, unit tests, e2e tests max 2 retries each; code review max 1 fix iteration
```

with:

```
- Retries are bounded: AC verification, unit tests, e2e tests, lint/format, hostile plan review max 2 retries each; code review max 1 fix iteration. Counters are cumulative per run (never reset), and a global ceiling of 6 total returns to implementation blocks a thrashing task
```

- [ ] **Step 3: Verify**

Run: `grep -n "cumulative\|iteration ceiling" .claude/skills/workflow/SKILL.md CLAUDE.md`
Expected: ≥ 3 matches spanning both files.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/workflow/SKILL.md CLAUDE.md
git commit -m "feat(skills): define cumulative retry-counter semantics and a global iteration ceiling"
```

---

### Task 7: Add a checkpoint file for crash/compaction resume (Design #3)

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md` (new section between "## Working root" and "## Commit discipline")
- Modify: `.claude/skills/closeout/SKILL.md` (step 5 teardown)

**Interfaces:**
- Consumes: counter names from Task 6.
- Produces: checkpoint file path convention `"$REPO_ROOT/.claude/worktrees/<branch>.state.json"` — referenced by the blocked exit protocol (Task 8).

- [ ] **Step 1: Add the Checkpoint & resume section to the coordinator**

In `.claude/skills/workflow/SKILL.md`, replace:

```
## Commit discipline
```

with (the new section, followed by the original heading):

````
## Checkpoint & resume

The current step and retry counters live only in conversation context and do not survive a crash, compaction, or a fresh session. Persist them after every completed step.

**Location:** `"$REPO_ROOT/.claude/worktrees/<branch>.state.json"` — a sibling of the worktree, inside the gitignored `.claude/worktrees/` directory and *outside* the worktree's working tree, so it can never be committed or flagged by the merge guard.

**Write after every completed step from Step 2b onward** (and whenever a retry counter increments):

```bash
mkdir -p "$(dirname "$REPO_ROOT/.claude/worktrees/<branch>.state.json")"
cat > "$REPO_ROOT/.claude/worktrees/<branch>.state.json" <<EOF
{
  "cloudId": "<cloudId>",
  "id": "<id>",
  "title": "<title>",
  "branch": "<branch>",
  "worktree": "<worktree>",
  "lastCompletedStep": "<step, e.g. 8b>",
  "counters": { "ac": 0, "unit": 0, "e2e": 0, "lint": 0, "codeReview": 0, "hostilePlan": 0, "returnsToStep5": 0 }
}
EOF
```

**Resume check (before Step 1):** run `find "$REPO_ROOT/.claude/worktrees" -name '*.state.json' 2>/dev/null`. If a checkpoint exists, read it and fetch its issue. If the issue is still assigned to this agent and not in `Human Code Review` or `Done`, restore all bindings and counters from the file and resume at the step after `lastCompletedStep` instead of claiming new work. If the issue has moved on, delete the stale checkpoint and proceed to Step 1 normally.

**Cleanup:** closeout deletes the checkpoint during worktree teardown. Blocked exits keep it — it is the resume material.

## Commit discipline
````

- [ ] **Step 2: Delete the checkpoint at closeout teardown**

In `.claude/skills/closeout/SKILL.md`, replace:

```
MAIN_REPO="$(git worktree list | head -1 | awk '{print $1}')"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"
cd "$MAIN_REPO"
git worktree remove "$WORKTREE_PATH" --force
git worktree prune
```

with:

```
MAIN_REPO="$(git worktree list | head -1 | awk '{print $1}')"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"
cd "$MAIN_REPO"
git worktree remove "$WORKTREE_PATH" --force
git worktree prune
rm -f "$MAIN_REPO/.claude/worktrees/<branch>.state.json"   # workflow checkpoint — task is complete
```

- [ ] **Step 3: Verify**

Run: `grep -n "state.json" .claude/skills/workflow/SKILL.md .claude/skills/closeout/SKILL.md`
Expected: ≥ 4 matches across both files.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/workflow/SKILL.md .claude/skills/closeout/SKILL.md
git commit -m "feat(skills): persist workflow step and retry counters to a checkpoint file for resume"
```

---

### Task 8: Blocked exit protocol — push, comment, label on every early stop (Design #5)

Today exit paths commit locally and stop: JIRA is left mid-lifecycle with no explanation, the commit exists only on this machine, and nothing marks the task as needing attention.

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md` (Commit discipline exception + new section)

**Interfaces:**
- Consumes: checkpoint path convention from Task 7.
- Produces: `## [BLOCKED]` JIRA comment convention and `workflow-blocked` label.

- [ ] **Step 1: Replace the Commit discipline exception with the protocol**

In `.claude/skills/workflow/SKILL.md`, replace:

```
Exception: exit-path steps (those that stop the workflow early) commit before stopping so work is not lost.
```

with:

````
Exception: exit-path steps (those that stop the workflow early) follow the **Blocked exit protocol** below — commit, push, comment, label — so work is recoverable and the task is discoverable.

## Blocked exit protocol

Every early stop (`WORKFLOW_BLOCKED` for any reason) after intake has created the branch must run these steps before emitting:

1. **Commit** pending changes with the `commit` skill (skip if the working tree is clean).
2. **Push** so work is recoverable off this machine: `git push -u origin <branch>`.
3. **Comment** on the JIRA issue:
   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     commentBody: "## [BLOCKED]\n\nWORKFLOW_BLOCKED at Step <n>: <reason>\n\nBranch: <branch>\nWorktree: <worktree>\nCheckpoint: .claude/worktrees/<branch>.state.json\n\nResume: re-run the workflow — it resumes from the checkpoint."
   )
   ```
4. **Label** the issue so humans can find stalled work: fetch current labels from the issue, then
   ```
   mcp__plugin_atlassian_atlassian__editJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<id>",
     fields: { labels: [<existing labels>, "workflow-blocked"] }
   )
   ```
5. **Keep** the worktree and checkpoint file in place — they are the resume material. Do not tear down.
6. **Emit** `WORKFLOW_BLOCKED: <reason>` and stop.

Blocks before intake (Step 1) emit only — nothing exists yet to preserve. On a successful resume that reaches closeout, remove the `workflow-blocked` label.
````

- [ ] **Step 2: Verify**

Run: `grep -n "Blocked exit protocol\|workflow-blocked" .claude/skills/workflow/SKILL.md`
Expected: ≥ 3 matches.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/workflow/SKILL.md
git commit -m "feat(skills): blocked exit protocol — push branch, comment, and label JIRA on every early stop"
```

---

### Task 9: Make the audit check substance, not just artifact existence (Design #4)

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md` (Step 11)
- Modify: `.claude/skills/audit-followed-workflow-steps/SKILL.md` (worktree check, new spot-check section, e2e evidence)

- [ ] **Step 1: Dispatch the audit to an independent subagent**

In `.claude/skills/workflow/SKILL.md`, replace:

```
## Step 11: Audit Followed All Steps

Use the `audit-followed-workflow-steps` skill.
```

with:

```
## Step 11: Audit Followed All Steps

Use the `audit-followed-workflow-steps` skill. Like code review (Step 10), dispatch the audit to a **separate subagent** — it verifies from JIRA and the worktree only, without the bias of having executed the steps itself.
```

- [ ] **Step 2: Replace the transcript-dependent worktree check**

In `.claude/skills/audit-followed-workflow-steps/SKILL.md`, replace:

```
   **Step 2b: Worktree Setup** (`setup-worktree` skill)
   - [ ] Worktree was created at `.claude/worktrees/<branch>` (look for `WORKTREE_READY` in transcript)
   - [ ] All subsequent steps ran from the worktree root
```

with:

```
   **Step 2b: Worktree Setup** (`setup-worktree` skill)
   - [ ] Worktree exists at `.claude/worktrees/<branch>` (`git worktree list` run from the main repo shows it)
   - [ ] The worktree's checked-out branch matches the `## [BRANCH]` comment
```

- [ ] **Step 3: Require evidence for an e2e skip**

In `.claude/skills/audit-followed-workflow-steps/SKILL.md`, replace:

```
   **Step 8: E2E Tests** (`e2e-tests` skill)
   - [ ] `E2E_TESTS_PASSED` or `E2E_TESTS_SKIPPED` (with documented reason) was emitted
```

with:

```
   **Step 8: E2E Tests** (`e2e-tests` skill)
   - [ ] `E2E_TESTS_PASSED` or `E2E_TESTS_SKIPPED` was emitted
   - [ ] If skipped: a `## [NOTES]` comment contains the skip evidence — the exact command run and its captured error output. A skip claim with no evidence fails the audit
```

- [ ] **Step 4: Add substance spot-checks before the results step**

In `.claude/skills/audit-followed-workflow-steps/SKILL.md`, replace:

```
3. **For each incomplete step**:
```

with:

```
3. **Substance spot-checks** — existence of an artifact is not proof the work behind it happened. Verify evidence, not form:

   - **AC evidence:** pick up to 2 checked ACs from the description (all of them if there are 2 or fewer). For each, find the concrete change in the working-tree diff (`git diff <base>` from the worktree, plus untracked files) that satisfies it. An AC checked with no supporting change in the diff fails the audit.
   - **Scope reconciliation:** every file in the `## [MODIFIED FILES]` comment must appear in the plan's `### Files in scope` section or a `## [SCOPE CHANGE]` comment (routine artifacts — lock files, `test-results/` — exempt). An unexplained file fails the audit.
   - **Plan depth:** the `## [PLAN]` comment must name real files and contracts, not just restate the ACs. A plan with no named file fails the audit.

4. **For each incomplete step**:
```

Then renumber the following step: replace

```
4. **Emit results**:
```

with

```
5. **Emit results**:
```

- [ ] **Step 5: Verify**

Run: `grep -n "transcript" .claude/skills/audit-followed-workflow-steps/SKILL.md`
Expected: no matches.

Run: `grep -n "Substance spot-checks" .claude/skills/audit-followed-workflow-steps/SKILL.md`
Expected: 1 match.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/workflow/SKILL.md .claude/skills/audit-followed-workflow-steps/SKILL.md
git commit -m "feat(skills): audit verifies evidence (AC diffs, scope reconciliation, skip proof) via independent subagent"
```

---

### Task 10: Proportional worktree bootstrap (Design #6)

**Files:**
- Modify: `.claude/skills/setup-worktree/SKILL.md` (step 6 + Rules)

- [ ] **Step 1: Skip bootstrap for docs-only branches**

In `.claude/skills/setup-worktree/SKILL.md`, replace:

```
6. Bootstrap gitignored build artifacts so subsequent steps have working toolchains. Run all three installs from the worktree root:
```

with:

```
6. Bootstrap gitignored build artifacts so subsequent steps have working toolchains. **Skip this step entirely for `docs/`-prefixed branches** — documentation-only tasks need no toolchains, and the installs are the most expensive part of setup. For all other branches, run all three installs from the worktree root:
```

- [ ] **Step 2: Add the lazy-bootstrap escape hatch**

In the Rules section of the same file, replace:

```
- Never create the worktree for a branch that is already checked out in the main repo (git will refuse this — they must be on different branches)
```

with:

```
- Never create the worktree for a branch that is already checked out in the main repo (git will refuse this — they must be on different branches)
- If bootstrap was skipped (docs branch) and a later step turns out to need a toolchain (e.g., the task touches code after all), run the corresponding install from step 6 at that point — the installs are idempotent
```

- [ ] **Step 3: Verify**

Run: `grep -n "docs/" .claude/skills/setup-worktree/SKILL.md`
Expected: ≥ 1 match.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/setup-worktree/SKILL.md
git commit -m "feat(skills): skip worktree bootstrap for docs-only branches"
```

---

### Task 11: Signal discipline rule (Design — signal fragility)

**Files:**
- Modify: `.claude/skills/workflow/SKILL.md` (Rules section)

- [ ] **Step 1: Add the signal-discipline rule**

In `.claude/skills/workflow/SKILL.md`, replace:

```
- Propagate any `*_BLOCKED` output from sub-skills as `WORKFLOW_BLOCKED: <propagated reason>`
```

with:

```
- Propagate any `*_BLOCKED` output from sub-skills as `WORKFLOW_BLOCKED: <propagated reason>`
- **Signal discipline:** every sub-skill must emit its completion token **verbatim, on its own line** (e.g., `INTAKE_COMPLETE: <branch>`). Never infer success or failure from prose. If a sub-skill finishes without its expected token, ask it once to restate its outcome as the exact token; if it still cannot, treat the step as failed: `WORKFLOW_BLOCKED: missing completion signal from <skill>`
```

- [ ] **Step 2: Verify**

Run: `grep -n "Signal discipline" .claude/skills/workflow/SKILL.md`
Expected: 1 match.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/workflow/SKILL.md
git commit -m "feat(skills): require verbatim completion signals; treat missing signals as blocked"
```

---

### Task 12: E2E skip requires captured evidence (Design — e2e escape hatch)

**Files:**
- Modify: `.claude/skills/e2e-tests/SKILL.md` (Special Cases section)

**Interfaces:**
- Produces: the `## [NOTES]` skip-evidence comment the audit (Task 9, Step 3) checks for.

- [ ] **Step 1: Rewrite the infrastructure-unavailable case**

In `.claude/skills/e2e-tests/SKILL.md`, replace:

```
If e2e tests require infrastructure that's not available (databases, external services):
- Document the required infrastructure
- Emit `E2E_TESTS_SKIPPED: required infrastructure not available — <details>` and continue on to the next step in the workflow - do not stop.
- This is not a blocker; the workflow can continue
```

with:

````
If e2e tests require infrastructure that's not available (databases, external services):
- **Prove it — never skip on assumption.** Actually run the test command and capture the failing output. "Probably needs a database" is not evidence; a connection-refused error is.
- Post the evidence to JIRA:
  ```
  mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
    cloudId: "<cloudId>",
    issueIdOrKey: "<id>",
    commentBody: "## [NOTES]\n\nE2E SKIPPED — infrastructure unavailable:\n\nCommand: <exact command run>\nError: <captured error output>"
  )
  ```
- Emit `E2E_TESTS_SKIPPED: required infrastructure not available — <details>` and continue on to the next step in the workflow - do not stop.
- This is not a blocker; the workflow can continue. The audit (Step 11) fails a skip that has no evidence comment.
````

- [ ] **Step 2: Verify**

Run: `grep -n "Prove it" .claude/skills/e2e-tests/SKILL.md`
Expected: 1 match.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/e2e-tests/SKILL.md
git commit -m "feat(skills): e2e skip requires captured failure evidence posted to JIRA"
```

---

### Task 13: Re-run unit tests when lint autofix modified files (Design — untested autofixes)

Lint runs after unit and e2e tests pass; `eslint --fix` and `ruff check --fix` can change behavior, so autofixed code currently ships untested.

**Files:**
- Modify: `.claude/skills/lint-format/SKILL.md` (new step between current steps 3 and 4)

- [ ] **Step 1: Insert the retest step**

In `.claude/skills/lint-format/SKILL.md`, replace:

````
3. **Re-run lint (no `--fix`) in each changed area to confirm nothing unfixable remains:**

```bash
npm run lint          # frontend / e2e
ruff check .           # backend
```

4. **If any errors remain after auto-fix:**
````

with:

````
3. **Re-run lint (no `--fix`) in each changed area to confirm nothing unfixable remains:**

```bash
npm run lint          # frontend / e2e
ruff check .           # backend
```

3b. **If the auto-fix pass modified any files, re-run the unit tests for those areas.** Lint fixers can change behavior, and the test steps (7, 8) already passed before this skill ran — autofixed code must not ship untested. Detect whether fixes were applied by hashing the diff before and after step 2:

```bash
# before step 2:
before="$(git diff | git hash-object --stdin)"
# after step 2:
after="$(git diff | git hash-object --stdin)"
```

If `before != after`, re-run the unit suite in each area whose files were modified:

```bash
cd frontend && npm test -- --run           # frontend (vitest)
cd backend && .venv/bin/python -m pytest   # backend
```

If any test fails, emit `LINT_BLOCKED: auto-fix broke unit tests — <summary>` and stop (this counts against the lint retry cap; the workflow returns to the implement step).

4. **If any errors remain after auto-fix:**
````

- [ ] **Step 2: Verify**

Run: `grep -n "auto-fix broke unit tests" .claude/skills/lint-format/SKILL.md`
Expected: 1 match.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lint-format/SKILL.md
git commit -m "feat(skills): re-run unit tests when lint autofix modifies files"
```

---

### Task 14: Idempotent intake branch creation and atomic claim (Design — intake fragility)

`git checkout -b` fails if the branch exists (e.g., resuming after a blocked run), and the claim window between check-for-work selecting an issue and intake assigning it allows two-session collisions.

**Files:**
- Modify: `.claude/skills/intake/SKILL.md` (step 2)
- Modify: `.claude/skills/check-for-work/SKILL.md` (steps 4 and 7)

- [ ] **Step 1: Make branch creation idempotent**

In `.claude/skills/intake/SKILL.md`, replace:

````
2. **Create the branch**, capturing the base branch first:

   ```bash
   base="$(git branch --show-current)"
   git checkout -b <branch>
   ```

   `<base>` is the branch the feature branch is cut from. It is recorded in JIRA (step 4) and used at closeout as the squash diff base and the PR target.
````

with:

````
2. **Create the branch**, capturing the base branch first:

   ```bash
   base="$(git branch --show-current)"
   if git rev-parse --verify --quiet "<branch>" >/dev/null; then
     # Branch already exists — this is a rerun (previous run blocked or crashed after intake).
     git checkout "<branch>"
   else
     git checkout -b "<branch>"
   fi
   ```

   `<base>` is the branch the feature branch is cut from. It is recorded in JIRA (step 4) and used at closeout as the squash diff base and the PR target. **On the reuse path**, `git branch --show-current` is not the base — read `<base>` from the `Base:` line of the existing `## [BRANCH]` JIRA comment instead, and skip step 4 (don't post a duplicate comment).
````

- [ ] **Step 2: Exclude already-claimed issues from the work search**

In `.claude/skills/check-for-work/SKILL.md`, replace:

```
     jql: 'project = "<PROJECT>" AND status = "To Do" ORDER BY priority ASC, created ASC',
```

with:

```
     jql: 'project = "<PROJECT>" AND status = "To Do" AND (assignee IS EMPTY OR assignee = currentUser()) ORDER BY priority ASC, created ASC',
```

- [ ] **Step 3: Claim at selection time**

In `.claude/skills/check-for-work/SKILL.md`, replace:

```
7. **Emit the task information**:
   - Emit `<issue-key> — <summary>` and continue on to the next step in the workflow — do not stop.
```

with:

````
7. **Claim the selected issue immediately** by assigning it to the current user — this is the claim marker that closes the window where two sessions could pick the same To Do issue between selection and intake:

   ```
   mcp__plugin_atlassian_atlassian__lookupJiraAccountId(cloudId: "<cloudId>", searchString: "<current user email>")   # if account id not already known
   mcp__plugin_atlassian_atlassian__editJiraIssue(
     cloudId: "<cloudId>",
     issueIdOrKey: "<issue-key>",
     fields: { assignee: { accountId: "<current-user-account-id>" } }
   )
   ```

   If the issue turns out to be already assigned to someone else at this point (race lost), skip it and return to step 6 to select the next candidate.

8. **Emit the task information**:
   - Emit `<issue-key> — <summary>` and continue on to the next step in the workflow — do not stop.
````

- [ ] **Step 4: Verify**

Run: `grep -n "rev-parse --verify --quiet\|assignee IS EMPTY" .claude/skills/intake/SKILL.md .claude/skills/check-for-work/SKILL.md`
Expected: 2 matches (one per file).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/intake/SKILL.md .claude/skills/check-for-work/SKILL.md
git commit -m "feat(skills): idempotent intake branch creation and claim-at-selection in check-for-work"
```

---

## Finding → Task traceability

| Finding | Task |
|---|---|
| Consistency #1 — plan gate optional vs required (3-way) | Task 1 |
| Consistency #2 — example transitions to Done | Task 2 |
| Consistency #3 — setup-worktree "intake commits" claim | Task 3 |
| Consistency #4 — feature-branch precondition conflict | Task 4 |
| Consistency #5 — stale `task-3` id example | Task 4 |
| Consistency #6 — phantom `backlog/` directory | Task 3 |
| Consistency #7 — `WORKTREE_BLOCKED` unhandled | Task 4 |
| (bonus) CLAUDE.md:45 closeout "marks the task Done" | Task 4 |
| Design #1 — tautological merge guard | Task 5 |
| Design #2 — undefined compounding retry caps | Task 6 |
| Design #3 — no checkpoint / not resumable | Task 7 |
| Design #4 — audit is form-checking theater | Task 9 |
| Design #5 — failure paths strand the task | Task 8 |
| Design #6 — no proportionality (bootstrap cost) | Task 10 |
| Design (low) — signal fragility | Task 11 |
| Design (low) — e2e skip escape hatch | Task 12 |
| Design (low) — lint autofix untested | Task 13 |
| Design (low) — intake fragility / non-atomic claim | Task 14 |
