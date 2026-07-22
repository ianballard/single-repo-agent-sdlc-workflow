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
