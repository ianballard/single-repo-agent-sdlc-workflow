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
