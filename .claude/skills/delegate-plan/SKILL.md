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

Resolve two things here that execution cannot decide for itself, or they
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
