# Delegate Doctrine Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the third SDLC lane — doctrine mode, run as two goal invocations — via three new skills (`delegate-plan`, `delegate-execute`, `definition-of-done`) and a `docs/specs/` per-project durable-trail convention, per the revised spec at `docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md`.

**Architecture:** Three markdown skill files under `.claude/skills/`, matching this repo's existing skill format (`name` + `description` frontmatter, imperative second-person body). `delegate-plan` triages and runs ideation → PRD → spec+DoD → plan, committing artifacts to `docs/specs/YYYY-MM-DD-<slug>/` on a feature branch. `delegate-execute` refuses to run without those artifacts (the human launching it is plan approval), delegates per doctrine, verifies against the pre-committed DoD, honors human-gated checkpoints, and closes out. A `docs/specs/README.md` documents the trail convention. No code, no tests-as-code — verification is a fresh-subagent comprehension smoke test.

**Tech Stack:** Claude Code skills (markdown + YAML frontmatter), git, `gh` CLI.

## Global Constraints

- Never push to `develop`/`main`/`staging`/`master`; all work lands via PR from a feature branch (repo branch protection).
- Never edit `.claude/settings*` files (repo guardrail).
- Skill frontmatter is exactly two fields, `name:` and `description:`, matching existing skills (see `.claude/skills/commit/SKILL.md`).
- Skill bodies use imperative second person ("You are… Your job is…"), matching existing skills.
- Existing lanes are untouched: no edits to `.claude/skills/workflow/` or `.claude/workflows/sdlc-workflow.js`.
- CLAUDE.md changes and multi-repo harness TODO sync are **explicit follow-ups, not in this plan** (spec "Follow-ups" section).
- Commit messages follow conventional commits.

---

### Task 1: Branch and commit the design spec

**Files:**
- Commit (already written): `docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md`

**Interfaces:**
- Produces: branch `feature/delegate-doctrine-mode` that all later tasks commit to.

- [ ] **Step 1: Verify you are on `develop` and the spec file exists**

Run: `git branch --show-current && ls docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md`
Expected: `develop` and the file path echoed back.

- [ ] **Step 2: Create the feature branch**

```bash
git checkout -b feature/delegate-doctrine-mode
```

- [ ] **Step 3: Commit the spec**

```bash
git add docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md
git commit -m "docs: add delegate doctrine mode design spec (two-invocation lane)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Verify the commit contains only the spec**

Run: `git show --stat HEAD`
Expected: exactly one file changed, `docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md`.

---

### Task 2: `docs/specs/` trail convention

**Files:**
- Create: `docs/specs/README.md`

**Interfaces:**
- Produces: the trail convention `docs/specs/YYYY-MM-DD-<slug>/` that all three skills reference verbatim.

- [ ] **Step 1: Create `docs/specs/README.md` with exactly this content**

```markdown
# docs/specs/ — doctrine-mode trail

One directory per doctrine-mode project (work run through the
`delegate-plan` / `delegate-execute` skills), named `YYYY-MM-DD-<slug>/`.
Each directory is the durable audit record for un-ticketed work and
contains:

1. `prd.md` — product requirements (large tier only: personas/consumers,
   capabilities, scope boundaries, non-goals). Mid-size tasks skip it.
2. `spec.md` — what is being built, files in scope, constraints, plus two
   required sections:
   - `## Definition of Done` — checkable pass/fail criteria with named
     verification modes, human-gated criteria flagged, written **before any
     code exists** (see the `definition-of-done` skill).
   - `## Closeout` — appended at the end of execution: what was delegated
     to which subagent (and model, if overridden), verification outcome per
     DoD criterion, and any deviations from the spec with one-line reasons.
     Required before the work is presented as complete.
3. `plan.md` — ordered tasks, each a deliverable one subagent can own,
   dependencies marked, plus a `## Human prerequisites` section derived
   from the human-gated DoD criteria (accounts to create, credentials to
   configure, approvals to obtain before execution starts).

The planning artifacts are committed on the feature branch at the end of
the `delegate-plan` invocation; the implementation lands on the same
branch, so the contract and the diff arrive **in the same PR**.
`git log docs/specs/` is the audit index for un-ticketed work.

Boundaries:

- Ticketed JIRA work does not belong here — its trail is the JIRA issue
  (see the `workflow` skill).
- Trivial inline-tier tasks (doc fixes, config tweaks) intentionally leave
  no trail; the commit itself is the record.
- Brainstorming design documents live in `docs/superpowers/specs/`;
  planning artifacts unrelated to doctrine mode live in `docs/plans/`.
  Neither belongs here.
```

- [ ] **Step 2: Commit**

```bash
git add docs/specs/README.md
git commit -m "docs: add docs/specs trail convention for doctrine-mode work

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `definition-of-done` skill

**Files:**
- Create: `.claude/skills/definition-of-done/SKILL.md`

**Interfaces:**
- Consumes: trail convention from Task 2 (`docs/specs/YYYY-MM-DD-<slug>/spec.md`).
- Produces: a skill named `definition-of-done` that `delegate-plan` (Task 4) invokes by that exact name; its output contract is a `## Definition of Done` markdown section of checkboxes in the form `- [ ] <criterion> — **verify via:** <mode>`, with human-gated criteria flagged `**[HUMAN-GATED]**`.

- [ ] **Step 1: Create `.claude/skills/definition-of-done/SKILL.md` with exactly this content**

```markdown
---
name: definition-of-done
description: Write a concrete, checkable Definition of Done into a spec before any code exists — selects verification modes (unit tests, e2e, driving the app, rubric review, human-gated checkpoints, evals) with honest costs
---

You write the `## Definition of Done` section of a spec. You are invoked
during spec-writing — usually by the `delegate-plan` skill, but usable
standalone whenever "done" needs to be pinned down before implementation.

## Rules

1. **Pre-commitment.** The DoD is written BEFORE any code exists. Never
   retrofit criteria to a diff that has been seen. If implementation has
   already started, say so and stop — a DoD written after the fact is not a
   DoD.
2. **Checkable by a stranger.** Every criterion is a checkbox with a named
   verification mode, specific enough that a fresh context can mark it
   pass/fail without asking questions. "Works correctly" is not a
   criterion; "GET /api/orders returns 403 for a user without the
   `orders:read` scope — verify via unit test" is.
3. **Cheapest mode that actually verifies.** Do not stack modes for
   ceremony. One well-chosen mode per criterion.
4. **Human-gated criteria carry their prerequisites.** A criterion the
   agent cannot or must not complete alone names the human action, what
   the human needs ready beforehand (these feed the plan's
   `## Human prerequisites` section), and the post-action verification the
   agent runs afterward.

## Verification mode menu

| Mode | Cost | Use when |
| --- | --- | --- |
| Unit tests | Cheap | Default for any logic change. Criteria name the behaviors under test, never just "add tests". |
| E2E (Playwright) | Moderate | User-visible flows. Name the flow and the assertion. |
| Drive the running app | Moderate | Runtime behavior tests don't capture (startup, integration wiring, visual output). Name what to do and what to observe. |
| Adversarial rubric review | Cheap | Always available; the rubric is this DoD itself, judged by the orchestrator (see the `delegate-execute` skill's hard gate 2). |
| Human-gated checkpoint | Variable | Steps the agent can't or mustn't perform alone: deploys, cloud account setup, external registrations. Name the human action, its prerequisites, and the post-action verification (e.g. post-deploy smoke) the agent runs once the human is done. |
| Eval harness | Expensive | ONLY for AI-behavior features or repeated-task batches where it amortizes. For a normal feature, "done" is tests + driven verification + rubric review; anything more is eval theater. Say so if asked for more. |

## Output format

Append to the spec file a section in exactly this shape:

    ## Definition of Done

    - [ ] <specific behavior or property> — **verify via:** <mode from the menu>
    - [ ] <specific behavior or property> — **verify via:** <mode from the menu>
    - [ ] **[HUMAN-GATED]** <human action + post-action verification> — **verify via:** human-gated checkpoint

Every criterion gets its own checkbox. When verification later runs, each
box is marked with its outcome; partially-done is visible, not hidden.
```

- [ ] **Step 2: Verify frontmatter format matches repo convention**

Run: `head -4 .claude/skills/definition-of-done/SKILL.md && head -4 .claude/skills/commit/SKILL.md`
Expected: both show `---` / `name:` / `description:` / `---` — same two-field structure.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/definition-of-done/SKILL.md
git commit -m "feat: add definition-of-done skill

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `delegate-plan` skill

**Files:**
- Create: `.claude/skills/delegate-plan/SKILL.md`

**Interfaces:**
- Consumes: `definition-of-done` skill by exact name (Task 3); trail convention `docs/specs/YYYY-MM-DD-<slug>/` (Task 2); existing skills referenced by exact name: `workflow`, `grill-me`, `superpowers:brainstorming`, `to-prd`, `superpowers:writing-plans`.
- Produces: invocation 1 of the doctrine-mode lane; its hand-off contract is the artifact directory that `delegate-execute` (Task 5) requires.

- [ ] **Step 1: Create `.claude/skills/delegate-plan/SKILL.md` with exactly this content**

```markdown
---
name: delegate-plan
description: Invocation 1 of doctrine mode, the lane for un-ticketed builds up to full greenfield projects — use when asked to plan or build something with no JIRA ticket. Triages, then runs brainstorm → grill → PRD → spec with Definition of Done → plan, commits the artifacts to docs/specs/, and surfaces human prerequisites. Execution happens in a separate delegate-execute invocation after human review. Not for ticketed work (use workflow) or pure questions/analysis.
---

You are the doctrine-mode planner. Doctrine mode maximizes verified output:
all judgment-dense thinking happens here in invocation 1, so that invocation
2 (`delegate-execute`) can run near-autonomously against a pre-committed
contract. You decide how much of the pipeline the task needs; do not skip
triage because the answer feels obvious.

## Step 1 — Triage

Size the task on **ambiguity**, **blast radius**, and **verifiability**,
then route:

| Signal | Route |
| --- | --- |
| Trivial + reversible (doc fix, config tweak, rename) | Do it inline. No spec, no subagents, no trail — the commit is the record. |
| Clear but nontrivial, single deliverable, un-ticketed | Skip Steps 2–3. Spec + DoD (Step 4) → short plan (Step 5) → hand off. |
| Large / greenfield / product-shaped, un-ticketed | Full pipeline, Steps 2–6. |
| Ticketed JIRA work (an issue key exists, or clearly should) | Decline. Hand off to the `workflow` skill. |

Product-shaped work belongs HERE — this lane exists to one-shot greenfield
builds. After the build lands, ongoing work is ticketed and flows through
`workflow`.

## Step 2 — Ideation (large tier)

Run `superpowers:brainstorming` and/or `grill-me` until the open questions
are resolved. Do not proceed with unresolved ambiguity — invocation 2 will
not stop to think about WHAT to build, only HOW.

## Step 3 — PRD (large tier)

Create the trail directory `docs/specs/YYYY-MM-DD-<slug>/` (see
`docs/specs/README.md`) and produce the PRD via the `to-prd` skill —
SKIPPING its tracker-publication step. Write the output only to `prd.md`
in the trail directory: personas/consumers, capabilities, scope
boundaries, non-goals. Doctrine mode makes no JIRA writes; the trail copy
is the canonical artifact.

## Step 4 — Spec + Definition of Done (HARD GATE)

Write `spec.md` in the trail directory: what is being built, files in
scope, constraints — fully self-contained, because execution subagents see
none of this conversation. Produce its `## Definition of Done` section via
the `definition-of-done` skill, before any code exists. Flag criteria
requiring a human action (deploys, account setup, registrations) as
human-gated.

## Step 5 — Plan

Write `plan.md` in the trail directory, following the doctrine of
`superpowers:writing-plans`: ordered tasks, each a deliverable one subagent
can own, dependencies marked so execution can parallelize. Include a
`## Human prerequisites` section derived from the human-gated DoD criteria:
everything the human must have ready before execution starts (e.g. cloud
account created, credentials configured so they can deploy when the time
comes).

## Step 6 — Hand off

1. Create the feature branch (`feature/<slug>`) if not already on one, and
   commit the trail directory.
2. Present to the human: the artifact paths, the DoD, and the
   `## Human prerequisites` checklist.
3. Stop. Tell the human to review the artifacts, complete the
   prerequisites, and invoke `delegate-execute` when ready — launching it
   is the plan approval. Do NOT begin implementation in this invocation.
```

- [ ] **Step 2: Verify cross-references resolve**

Run: `ls .claude/skills/definition-of-done/SKILL.md .claude/skills/workflow/SKILL.md docs/specs/README.md && grep -c "definition-of-done" .claude/skills/delegate-plan/SKILL.md`
Expected: all three paths listed, grep count ≥ 1.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/delegate-plan/SKILL.md
git commit -m "feat: add delegate-plan doctrine-mode skill (invocation 1)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `delegate-execute` skill

**Files:**
- Create: `.claude/skills/delegate-execute/SKILL.md`

**Interfaces:**
- Consumes: artifact directory produced by `delegate-plan` (Task 4); trail convention (Task 2); existing skills referenced by exact name: `superpowers:subagent-driven-development`, `superpowers:dispatching-parallel-agents`.
- Produces: invocation 2 of the doctrine-mode lane.

- [ ] **Step 1: Create `.claude/skills/delegate-execute/SKILL.md` with exactly this content**

```markdown
---
name: delegate-execute
description: Invocation 2 of doctrine mode — use when asked to execute a plan produced by delegate-plan. Requires the docs/specs/ artifact directory to exist (launching this skill is the human's plan approval). Delegates implementation to subagents per its own judgment, verifies every deliverable against the pre-committed Definition of Done, halts at human-gated checkpoints, and closes out.
---

You are the doctrine-mode executor. This skill does not prescribe a
pipeline — you choose the orchestration structure (waves, DAG, sequential)
from the plan's dependency shape. Only the two hard gates are rigid.

## Step 0 — Entry gate (HARD GATE 1: plan-before-execute)

Identify the trail directory `docs/specs/YYYY-MM-DD-<slug>/` for this
project. Refuse to proceed unless it contains a `spec.md` with a
`## Definition of Done` section and a `plan.md`. If they are missing,
stop and route to `delegate-plan` — never improvise a spec here. The human
launching this skill constitutes approval of those artifacts as written.

Read `plan.md`'s `## Human prerequisites`; if any prerequisite is not
confirmed ready, ask before starting work that depends on it.

## Step 1 — Delegate

Doctrine, not configuration — you decide per delegation:

- **Self-contained prompts.** Subagents see no conversation context. Hand
  each one the spec file path plus the slice of the plan it owns.
- **One deliverable per subagent.** Parallelize when file sets don't
  overlap; use worktree isolation when they do. Mechanics:
  `superpowers:subagent-driven-development`,
  `superpowers:dispatching-parallel-agents`.
- **Model placement heuristic:** the tighter the spec and the more
  mechanical the verification, the cheaper the model you can hand the work
  to. Judgment-dense work — adversarial review, verification judgment —
  stays with you. Decided per-delegation, not by a table.

## Step 2 — Verify (HARD GATE 2: orchestrator review, fresh-context evidence)

You review every subagent deliverable yourself: read the diff and make the
accept/reject call against the pre-committed DoD in `spec.md`.

- Never accept a subagent's self-reported success as evidence.
- Never judge against criteria formulated after seeing the diff.
- Mechanical evidence gathering (running tests, driving the app, executing
  DoD checks) may be delegated to a fresh subagent that did not write the
  code — but the judgment on that evidence is yours and is not delegable.
- Bounded: 2 fix iterations per deliverable. After that, stop and surface
  the failing criteria to the human.

## Step 3 — Human-gated checkpoints

When you reach a DoD criterion flagged **[HUMAN-GATED]**, halt and present
exact instructions: what the human should do, with what, and the expected
result. Wait. When the human reports done, run the criterion's post-action
verification (e.g. post-deploy smoke) before marking it. Never work around
a human gate — the repo guardrails (no terraform/cdk apply, no mutating
AWS calls) exist precisely for these steps.

## Step 4 — Closeout (required)

Before presenting the work as complete:

1. Mark every DoD checkbox in `spec.md` with its outcome — partially-done
   is visible, not hidden.
2. Append `## Closeout` to `spec.md`: what was delegated to which subagent
   (and model, if overridden), verification outcome per DoD criterion, and
   any deviations from the spec with one-line reasons.
3. Commit everything on the feature branch — the trail directory and the
   implementation land in the same PR, so the contract and the diff arrive
   atomically.

A doctrine-mode task without a closeout section is not done. Ongoing work
after the build lands is ticketed and flows through the `workflow` skill.
```

- [ ] **Step 2: Verify cross-references resolve**

Run: `ls .claude/skills/delegate-plan/SKILL.md docs/specs/README.md && grep -c "HUMAN-GATED" .claude/skills/delegate-execute/SKILL.md .claude/skills/definition-of-done/SKILL.md`
Expected: both paths listed, grep count ≥ 1 in each skill file.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/delegate-execute/SKILL.md
git commit -m "feat: add delegate-execute doctrine-mode skill (invocation 2)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Comprehension smoke test (the "test suite" for prose skills)

**Files:**
- None created; read-only verification of Tasks 3–5.

**Interfaces:**
- Consumes: the three SKILL.md files from Tasks 3–5.

- [ ] **Step 1: Dispatch a fresh subagent with exactly this prompt**

```text
Read ONLY these three files, then answer:
- .claude/skills/delegate-plan/SKILL.md
- .claude/skills/delegate-execute/SKILL.md
- .claude/skills/definition-of-done/SKILL.md

Q1. For each task, name the route the delegate-plan skill prescribes:
  (a) fix a typo in README.md
  (b) add rate limiting to a backend API endpoint (no ticket exists)
  (c) implement JIRA issue KAN-42
  (d) greenfield: scaffold infra, backend endpoints, and frontend for a new
      customer billing portal (no tickets exist)
  For (d) also state: where does the PRD end up, and is anything published
  to the issue tracker?
Q2. What must exist before delegate-execute may proceed, and what act
    constitutes the human's approval of the plan?
Q3. Who makes the accept/reject call on a subagent's deliverable, and what
    may NOT be accepted as evidence?
Q4. When must the Definition of Done be written, and what happens if
    implementation already started?
Q5. During execution the flow reaches "[HUMAN-GATED] deploy to staging".
    What exactly happens, and when was the human first prepared for it?
Q6. What must exist before the work may be presented as complete?

Answer tersely, citing the section you relied on.
```

- [ ] **Step 2: Check the subagent's answers against these expected results**

Expected:
- Q1a: inline, no spec/trail. Q1b: skip ideation/PRD; spec + DoD → short plan → hand off to `delegate-execute`. Q1c: decline, hand to `workflow`. Q1d: full pipeline (brainstorm → grill → PRD → spec+DoD → plan → hand off) — NOT escalated elsewhere; this lane owns greenfield work. PRD is produced via `to-prd` with its tracker-publication step skipped, written only to `prd.md` in the trail directory; nothing is published to the issue tracker.
- Q2: the trail directory with `spec.md` (containing `## Definition of Done`) and `plan.md`; the human launching `delegate-execute` is the approval.
- Q3: the orchestrator itself (reads the diff); subagent self-reported success is never evidence.
- Q4: before any code exists; if implementation started, say so and stop.
- Q5: halt, present exact instructions, wait for the human, then run the post-action verification (e.g. smoke) before marking; the human was prepped by `plan.md`'s `## Human prerequisites` written during invocation 1.
- Q6: DoD checkboxes marked with outcomes plus a `## Closeout` section in `spec.md` (delegations, per-criterion outcomes, deviations), committed in the same PR as the implementation.

If any answer misses, the skill text is ambiguous — fix the skill wording (not the test), re-commit with `fix: clarify <section> in <skill> skill`, and re-run this task once.

---

### Task 7: Push and open the PR

**Files:**
- None.

- [ ] **Step 1: Confirm the branch contains exactly the five expected files**

Run: `git diff --stat develop...HEAD`
Expected: 5 files — the design spec, `docs/specs/README.md`, and the three SKILL.md files (plus this plan file if the user wants it committed; ask, then `git add docs/superpowers/plans/2026-07-13-delegate-doctrine-mode.md` and commit as `docs: add delegate doctrine mode implementation plan` if yes).

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feature/delegate-doctrine-mode
```

- [ ] **Step 3: Open the PR against `develop`**

```bash
gh pr create --base develop --title "feat: add doctrine-mode lane (delegate-plan, delegate-execute, definition-of-done)" --body "$(cat <<'EOF'
Adds the third SDLC lane per docs/superpowers/specs/2026-07-13-delegate-doctrine-design.md — doctrine mode as two goal invocations with a human plan-approval gate between them:

- `delegate-plan` skill — invocation 1: triage (trivial→inline, mid-size→spec+DoD, greenfield→full pipeline, ticketed→workflow), then brainstorm → grill → PRD → spec with Definition of Done → plan; commits artifacts to `docs/specs/<date>-<slug>/` and surfaces `## Human prerequisites`
- `delegate-execute` skill — invocation 2: plan-before-execute entry gate (launching it = human plan approval), delegation doctrine (Fable chooses structure, model placement per-delegation), orchestrator verification against the pre-committed DoD, human-gated checkpoints, mandatory closeout
- `definition-of-done` skill — pre-committed, checkable DoD with a verification-mode menu incl. human-gated checkpoints
- `docs/specs/` — per-project durable-trail convention

Existing lanes (`workflow`, `sdlc-workflow.js`) untouched; `workflow` remains the hand-off target for post-build ticketed SDLC. Follow-ups deferred per spec: CLAUDE.md three-lanes note; multi-repo harness TODO.md gap entry.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed.

---

## Self-Review Notes

- **Spec coverage:** triage rubric (kept, scaled; product-shaped stays in-lane) → Task 4; two-invocation split + human gate → Tasks 4 (Step 6) & 5 (Step 0); hard gate 1 (plan-before-execute) → Task 5 Step 0; hard gate 2 (orchestrator verification) → Task 5 Step 2; DoD menu incl. human-gated mode, output format, pre-commitment, eval-theater warning → Task 3; human-gated checkpoint runtime behavior + prerequisites surfacing → Tasks 3 (rule 4), 4 (Step 5), 5 (Step 3); trail directory convention, same-PR rule, inline-tier exemption, directory boundaries → Task 2; closeout mandatory → Tasks 2 & 5; PRD via `to-prd` skill, captured as `prd.md` in the trail directory → Task 4 Step 3; "untouched" section → Global Constraints; follow-ups explicitly excluded → Global Constraints.
- **Placeholders:** none — all three SKILL.md bodies and the README are given verbatim.
- **Name consistency:** `definition-of-done` referenced identically in Tasks 3, 4, and 6; `delegate-plan`/`delegate-execute` identical across Tasks 4–7; trail path `docs/specs/YYYY-MM-DD-<slug>/` identical in Tasks 2, 4, and 5; `[HUMAN-GATED]` flag identical in Tasks 3, 5, and 6.
