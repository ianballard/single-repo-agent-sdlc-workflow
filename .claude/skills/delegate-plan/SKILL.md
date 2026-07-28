---
name: delegate-plan
description: Invocation 1 of doctrine mode, the lane for un-ticketed builds up to full greenfield projects — use when asked to plan or build something with no JIRA ticket. Triages, then runs brainstorm → grill → PRD → spec with Definition of Done → plan → independent red-team stress test, commits the artifacts to docs/specs/, and surfaces human prerequisites. Execution happens in a separate delegate-execute invocation after human review. Not for ticketed work (use workflow) or pure questions/analysis.
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

Resolve three things here that execution cannot decide for itself, or they
become skipped specs and false-green suites later:

- **Real-dependency verification.** For every integration seam
  (browser↔API, app↔cloud, service↔database, client↔third-party) the DoD
  must carry at least one criterion verified against the real dependency,
  not a mock — and scheduled before the final deploy gate. `delegate-plan`
  is where that decision is cheap; do not let it default to unit + mocked
  e2e (see `definition-of-done` rules 5–6).
- **Test-fixture provisioning.** Any e2e criterion naming an external
  system must state how the test gets its state there (test accounts,
  confirmation flows, seed data). Fold the human-run parts into
  `## Human prerequisites` (Step 5).
- **Run surface.** State in `spec.md` where this thing runs: `local only`,
  `local + deployed`, or `no run surface` (a library, a docs or config
  change — nothing to launch). One line. It decides which runnability
  criteria the DoD carries (`definition-of-done` rule 8). "Local only" is a
  perfectly good answer; the requirement is that the question is answered
  explicitly, not that everything deploys.

## Step 5 — Plan

Write `plan.md` in the trail directory, following the doctrine of
`superpowers:writing-plans`: ordered tasks, each a deliverable one subagent
can own, dependencies marked so execution can parallelize. Include a
`## Human prerequisites` section derived from the human-gated DoD criteria:
everything the human must have ready before execution starts (e.g. cloud
account created, credentials configured so they can deploy when the time
comes).

## Step 5b — Red-team stress test (REQUIRED)

Dispatch the `red-team-plan` skill as a **fresh subagent**, passing it only the
trail directory path. Do not pass it this conversation, and do not summarize
the artifacts for it — its value comes entirely from not sharing your
assumptions. It is read-only; it reports, you revise.

It reviews two things, and both can block:

- **Is the solution sound?** Build vs. buy (is a component being hand-rolled that
  an off-the-shelf library already solves), technology fitness, version and
  compatibility claims checked against the actual manifests, stack coherence,
  conflicts with any accepted ADR, a materially simpler alternative, failure and
  scale characteristics, and the non-functional requirements the spec implies but
  never addresses.
- **Is the contract real?** `delegate-execute` verifies deliverables against the
  DoD rather than a subagent's self-report, so a criterion a mock can satisfy
  yields a confident false green. And execution subagents never see this
  conversation, so anything implicit in `spec.md` is missing rather than assumed.

Expect the deepest findings to land on `spec.md`, not `plan.md` — a wrong
technology or a build-it-yourself decision is a spec problem. Revising the spec
here is far cheaper than discovering it mid-execution.

Handle the verdict:

- `RED_TEAM_PASSED` — continue to Step 6. Warnings and minors do not block;
  fold any you accept into the artifacts, and leave `red-team.md` in the trail
  as the record of what you chose not to act on.
- `RED_TEAM_BLOCKED` — revise the artifacts and re-dispatch. **At most 2
  revision cycles.** If blocking findings survive the second, stop with
  `WORKFLOW_BLOCKED: red-team review unresolved after 2 revisions` and hand it
  to the human. Do not proceed to Step 6 with unresolved blocking findings, and
  do not argue the reviewer down — either fix the artifact or record why the
  finding is wrong in `red-team.md`.

Applies to every tier that produced artifacts. The trivial tier (done inline,
no spec) has nothing to review and skips this step.

## Step 6 — Hand off

1. Create the feature branch (`feature/<slug>`) if not already on one, and
   commit the trail directory.
2. Present to the human: the artifact paths, the DoD, and the
   `## Human prerequisites` checklist.
3. Stop. Tell the human to review the artifacts, complete the
   prerequisites, and invoke `delegate-execute` when ready — launching it
   is the plan approval. Do NOT begin implementation in this invocation.
