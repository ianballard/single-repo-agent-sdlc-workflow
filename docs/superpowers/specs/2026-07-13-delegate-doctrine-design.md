# Design: doctrine mode — the two-invocation `delegate` lane

**Date:** 2026-07-13 (revised 2026-07-22)
**Status:** Approved in brainstorming; revised after intent review — this is the
big lane, not the light one
**Author:** Ian Ballard + Claude (Fable 5)

## Problem

The repo has two lanes for getting work done, and both are fixed pipelines:

1. **`workflow`** — the full 13-step ticketed SDLC (JIRA choreography, gates,
   bounded retries, audit trail). Correct for ticketed, long-term,
   compliance-relevant work — the steady-state lane once a project exists.
2. **`sdlc-workflow.js`** — a Workflow-tool mirror of the same pipeline. Same
   shape, same ceremony.

There is no lane for **large, un-ticketed builds — greenfield projects
especially** — where the goal is to maximize verified output quickly and the
orchestrating model (Fable) should *decide* the process rather than execute a
predetermined one: how to decompose the plan, which subagents (and which model
tiers) to delegate to, how to parallelize, and how to verify. The canonical
use case: scaffold all infra, backend endpoints, and frontend for a greenfield
project — with tests, e2e verification, and human-gated steps like deployment
— in as close to one shot as possible, after which the normal `workflow` skill
takes over for long-term SDLC.

Fixed pipelines pre-make judgments that a frontier orchestrator can make
better per-task — but pure discretion has known failure modes: the model
skips verification precisely when it feels confident, and untracked work
leaves no durable trail. So: doctrine over pipeline, rigid only at the edges.

## Decision

Add a third lane: **doctrine mode**, run as **two goal invocations** with a
human gate between them, implemented as three skills plus a repo convention
for the trail:

- **Invocation 1 — `delegate-plan`:** triage, then (for large work)
  brainstorm → grill → PRD → spec with Definition of Done → plan. Ends with
  all planning artifacts on disk and an explicit list of human prerequisites.
- **Human gate (the invocation boundary):** the human reviews the PRD, spec,
  DoD, and plan; completes the surfaced prerequisites (e.g. cloud account set
  up, credentials configured, so they can deploy when the time comes); and
  launches invocation 2 when satisfied. Launching `delegate-execute` *is* the
  plan approval.
- **Invocation 2 — `delegate-execute`:** executes the plan. Fable decides the
  delegation structure, verifies every deliverable against the pre-committed
  DoD, halts at human-gated checkpoints, and closes out.

The existing lanes are untouched. After the initial build lands, ongoing work
is ticketed and flows through `workflow` — doctrine mode is the on-ramp, not
a replacement.

## Skill 1: `delegate-plan` (`.claude/skills/delegate-plan/SKILL.md`)

Invoked when the user asks Fable to plan or build something that has no JIRA
ticket — from a rough idea up to a full greenfield project.

### Triage rubric (kept, scaled)

Size the task on **ambiguity**, **blast radius**, and **verifiability**,
then route:

| Signal | Route |
| --- | --- |
| Trivial + reversible (doc fix, config tweak, rename) | Do it inline. No spec, no subagents, no trail. |
| Clear but nontrivial, single deliverable, un-ticketed | Skip ideation and PRD. Spec + DoD → short plan → `delegate-execute`. |
| Large / greenfield / product-shaped, un-ticketed | Full pipeline: brainstorm → grill → PRD → spec + DoD → plan → human gate → `delegate-execute`. |
| Ticketed JIRA work (issue key exists or should) | Decline; hand off to the `workflow` skill. |

Note the reversal from the original design: product-shaped work is no longer
escalated out to per-ticket `workflow` — it is this lane's home territory.
The PRD is produced via the `to-prd` skill, with the output captured as
`prd.md` in the project trail directory (the canonical doctrine-mode
artifact).

### Pipeline (large tier)

1. **Ideation** — `superpowers:brainstorming` and/or `grill-me` until the
   open questions are resolved. The heavy thinking happens here, in
   invocation 1, so invocation 2 can run without stopping to think about
   *what* to build.
2. **PRD** — produce the PRD via the `to-prd` skill, **skipping its
   tracker-publication step**: the output is written only to `prd.md` in
   the trail directory (personas/consumers, capabilities, scope boundaries,
   non-goals). Doctrine mode makes no JIRA writes.
3. **Spec + DoD (hard gate 1)** — write `spec.md`: what is being built, files
   in scope, constraints — self-contained, because execution subagents see
   none of this conversation. Its `## Definition of Done` section is produced
   via the `definition-of-done` skill, before any code exists. Criteria that
   require a human action (deploys, account setup, external registrations)
   are flagged **human-gated**.
4. **Plan** — write `plan.md` (doctrine of `superpowers:writing-plans`):
   ordered tasks, each a deliverable one subagent can own, with dependencies
   marked so execution can parallelize. Includes a `## Human prerequisites`
   section derived from the human-gated DoD criteria — everything the human
   must have ready before execution starts (e.g. cloud account created,
   credentials configured).
5. **Hand off** — create the feature branch, commit the planning artifacts,
   present the artifact paths and prerequisites, and stop. Execution is a
   separate invocation.

## Skill 2: `delegate-execute` (`.claude/skills/delegate-execute/SKILL.md`)

Invoked by the human after reviewing the planning artifacts.

### Hard gates (the rigid parts)

1. **Plan-before-execute.** Refuses to run unless the project trail directory
   exists with a `spec.md` containing `## Definition of Done` and a
   `plan.md`. No artifacts → stop and route to `delegate-plan`. The human
   launching this skill constitutes plan approval.
2. **Orchestrator review with fresh-context evidence.** The orchestrator
   (Fable) reviews every subagent deliverable itself — it reads the diff and
   makes the accept/reject call against the pre-committed DoD. It never
   accepts a subagent's self-reported success as evidence, and never judges
   against criteria formulated after seeing the diff. Mechanical evidence
   gathering (running tests, driving the app, executing DoD checks) may be
   delegated to a fresh subagent context that did not write the code, but the
   judgment on that evidence is the orchestrator's and is not delegable.
   Bounded: 2 fix iterations per deliverable, then surface to the human with
   the failing criteria.

Rationale for pre-commitment: it converts review from "re-derive the solution
and compare" (expensive; kills the economics of cheap-model delegation) into
"check the diff against a rubric already written" (cheap), and it removes the
discretion that gets rationalized away under confidence.

### Delegation doctrine (guidance, not config)

- Subagent prompts are self-contained — subagents see no conversation
  context. The spec is the contract; hand them the spec file path plus the
  slice they own.
- One deliverable per subagent. Parallelize when file sets don't overlap;
  use worktree isolation when they do. Fable chooses the orchestration
  structure — waves, DAG, pipeline — per the plan's dependency shape.
- **Model placement heuristic:** the tighter the spec and the more mechanical
  the verification, the cheaper the model it can be handed to. Judgment-dense
  work (adversarial review, verification judgment) stays with the
  orchestrator. Decided per-delegation, not by a table.
- Existing skills are the toolbox, routed to rather than re-implemented:
  `superpowers:subagent-driven-development` and
  `superpowers:dispatching-parallel-agents` for delegation mechanics.

### Human-gated checkpoints

When execution reaches a DoD criterion flagged human-gated, halt and present
exact instructions (what to do, with what, expected result), wait for the
human, then run the criterion's post-action verification before marking it.
These are known in advance — the plan's `## Human prerequisites` section
prepped the human — so a checkpoint is a pause, not a surprise.

### Closeout (required)

Before the work is presented as complete, append a `## Closeout` section to
`spec.md`: what was delegated to which subagent (and model, if overridden),
verification outcome per DoD criterion, and any deviations from the spec with
one-line reasons. A doctrine-mode task without a closeout section is not
done.

## Skill 3: `definition-of-done` (`.claude/skills/definition-of-done/SKILL.md`)

Invoked by `delegate-plan` during spec-writing (also usable standalone).
Given the task, select verification modes from a menu — with honest costs —
and write concrete, checkable pass/fail criteria into the spec **before any
code exists**.

**Menu (mode → cost → when):**

- **Unit tests** — cheap — default for any logic change; criteria name the
  behaviors, not "add tests."
- **E2E (Playwright)** — moderate — user-visible flows; name the flow and
  the assertion.
- **Drive the running app** (`/verify`-style) — moderate — changes whose
  runtime behavior tests don't capture; name what to do and what to observe.
- **Adversarial rubric review** — cheap — always available; the rubric is
  the DoD itself, judged by the orchestrator per `delegate-execute` hard
  gate 2.
- **Human-gated checkpoint** — variable — steps the agent can't or mustn't
  perform alone (deploys, account setup, external registrations). The
  criterion names the human action, its prerequisites (surfaced in the
  plan's `## Human prerequisites`), and the post-action verification the
  agent runs afterward (e.g. post-deploy smoke).
- **Eval harness** — expensive — only for AI-behavior features or
  repeated-task batches where it amortizes. For a normal feature, "done" is
  tests + driven verification + rubric review; anything more is eval
  theater.

**Output format:** a `## Definition of Done` section listing each criterion
as a checkbox with its verification mode (human-gated ones flagged), specific
enough that a fresh context can mark it pass/fail without asking questions.

## The durable trail

- One directory per doctrine-mode project: `docs/specs/YYYY-MM-DD-<slug>/`
  containing `prd.md` (large tier only), `spec.md` (with `## Definition of
  Done` and, at the end, `## Closeout`), and `plan.md`.
- The planning artifacts are committed on the feature branch at the end of
  invocation 1; the implementation lands on the same branch, so the contract
  and the diff arrive **in the same PR** and `git log docs/specs/` is the
  audit index for un-ticketed work.
- New `docs/specs/` directory. `docs/plans/` remains for planning artifacts
  (e.g. the repo-layout manifest); `docs/superpowers/specs/` remains for
  brainstorming design docs like this one.
- Inline-tier tasks (triage row 1) intentionally leave no trail — the commit
  itself is the record.

## Untouched

- `workflow` and all its component skills: unchanged; still the lane for
  ticketed, long-term, unattended, or compliance-relevant work — and the
  hand-off target once a doctrine-mode build has landed.
- `sdlc-workflow.js`: unchanged; no model tiering retrofit (superseded by
  doctrine mode's per-delegation placement heuristic).

## Follow-ups (not part of this implementation)

1. **CLAUDE.md**: add a short "three lanes" note (interactive / doctrine
   `delegate-plan`+`delegate-execute` / ticketed `workflow`) so future
   sessions route correctly.
2. **Multi-repo harness sync** (per CLAUDE.local.md): this is a genuine
   process/behavior change — when it lands, add a gap entry to
   `multi-repo-agent-sdlc-harness/TODO.md` describing the new lane and what
   multi-repo generalization it needs (trail location per repo vs.
   coordination point; worktree/parallelism doctrine across repos). Do not
   port code unprompted.

## Resolved decisions

- Two skills, one per invocation: `delegate-plan` and `delegate-execute`
  (over one skill with modes, or a Workflow-tool script for execution — a
  script would pre-make the orchestration judgments the doctrine exists to
  leave to Fable).
- The invocation boundary is the human plan-approval gate; launching
  `delegate-execute` is the approval.
- Trail: per-project directory `docs/specs/YYYY-MM-DD-<slug>/` (over a
  single flat file — a greenfield run's PRD + spec + plan doesn't fit one
  file comfortably).
- Triage kept and scaled: trivial → inline; mid-size → spec + DoD directly;
  large → full pipeline; ticketed → `workflow`.
- Product-shaped work stays in-lane; the PRD is written via the `to-prd`
  skill with its tracker-publication step skipped — the output is captured
  only as `prd.md` in the trail directory. `idea-to-backlog` remains the
  route for work that should become a ticketed backlog instead.
- Closeout section: **mandatory**. No JIRA writes in doctrine mode.
