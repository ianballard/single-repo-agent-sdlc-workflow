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
- **Resume safety after an interrupt.** A subagent reporting "interrupted"
  is not proof its work stopped — a long-running child process (a build, a
  `terraform apply`, a migration) can still be live, and an interrupt
  notification can be stale. Before taking over or re-dispatching, confirm
  the work is actually dead: check for the child processes it would have
  spawned (`pgrep`), and prefer pinging the agent to re-confirm over
  assuming. Two operators on one piece of shared mutable state (a Terraform
  state file, a database mid-migration) at once is the failure to avoid;
  where the state layer has a lock, it is your backstop, not your plan.

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
cloud calls) exist precisely for these steps.

**Authorized guardrail exceptions get a durable, committed record.** If the
human explicitly authorizes an action a guardrail normally forbids — e.g.
relaxing a permission rule so the agent itself performs a one-time deploy —
do not rely on that authorization living only in the conversation or in an
uncommitted edit to a config/policy file. A fresh subagent cannot see the
conversation, and an uncommitted change to a guardrail file
(`.claude/settings*`, `CLAUDE.md`, etc.) is indistinguishable from tampering
— a well-behaved subagent will refuse it or revert it, which is correct
behavior in the wrong context and burns cycles. Record the exception
durably instead: commit an `AUTHORIZATION.md` to the trail directory
(or a dated section in `spec.md`) stating exactly what the human authorized,
its scope, and its expiry ("agent may run `terraform apply` to `<env>` for
this deploy only; revert on completion"). Hand every subagent doing the
authorized work a pointer to that committed record, and instruct it to
verify the record rather than re-litigate the guardrail. You still never
edit the guardrail files yourself — that remains the human's action; you
record the authorization, not grant it.

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
