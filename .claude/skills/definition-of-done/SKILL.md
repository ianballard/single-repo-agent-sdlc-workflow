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
   ceremony. One well-chosen mode per criterion — but "cheapest" means
   cheapest mode that *actually exercises the behavior*, not the cheapest
   mode that produces a green checkmark (see rules 5–6).
4. **Human-gated criteria carry their prerequisites.** A criterion the
   agent cannot or must not complete alone names the human action, what
   the human needs ready beforehand (these feed the plan's
   `## Human prerequisites` section), and the post-action verification the
   agent runs afterward.
5. **Every integration boundary gets one real-dependency criterion.** For
   each seam where two systems meet — browser↔API, app↔cloud service,
   service↔database, client↔third-party — at least one criterion must be
   verified against the REAL dependency, not a mock or an in-process
   double. Unit tests and mocked/DOM-emulated e2e (e.g. jsdom) do NOT
   exercise cross-origin/CORS, real-browser runtime, real auth exchanges
   (e.g. SRP), or cloud request-signing — a suite can be fully green while
   the app is broken the moment it meets the real thing. Put a "drive the
   running app" criterion on these seams, and schedule it EARLIER than the
   final human-gated deploy — the first real-dependency contact should not
   be the last checkpoint.
6. **A static/dry-run check is not proof the thing works.** Linters, type
   checks, schema validators, `--dry-run`, and `terraform validate` verify
   syntax and the dependency graph, not that the resource/behavior actually
   works when created or run. A criterion whose only verification is a
   static check is weak; name the mode that exercises the real thing (for
   infra, that is a real `plan`/`apply` at a human-gated checkpoint — say so
   explicitly rather than resting on `validate`).
7. **E2E against an external system names its fixture story.** Any criterion
   verified by e2e/integration against a system with its own state
   (auth providers, SaaS APIs, seeded databases) must state HOW the test
   obtains its fixtures there — test accounts, confirmation/verification
   steps, seed data, teardown. An unresolved "how does the test get a
   confirmed user?" becomes a skipped spec at execution time. This
   provisioning story also feeds the plan's `## Human prerequisites`.
8. **Runnability follows the spec's declared run surface.** `spec.md` states
   where the thing runs — `local only`, `local + deployed`, or `no run
   surface`. Carry criteria to match, and no more:
   - **Any runnable surface** → one criterion that a fresh context with no
     conversation history can start it and exercise it using only committed
     repo instructions. Phrase it as the capability, never as the tooling: on
     a greenfield build no project run skill exists yet, and the `run`
     skill's fallback patterns are a legitimate way to satisfy it.
   - **`local + deployed`** → one criterion exercising the deployed target,
     usually the post-deploy smoke at the human-gated deploy checkpoint. One
     is enough. Do not require that the whole suite run against both.
   - **`no run surface`** → no runnability criterion. Record that in one line
     rather than inventing one.

   The first of these is load-bearing, not ceremonial: `delegate-execute`
   delegates evidence gathering to a fresh subagent that did not write the
   code, which is only possible if a stranger can actually start the thing.

## Verification mode menu

| Mode | Cost | Use when |
| --- | --- | --- |
| Unit tests | Cheap | Default for any logic change. Criteria name the behaviors under test, never just "add tests". |
| E2E (Playwright) | Moderate | User-visible flows. Name the flow and the assertion. |
| Drive the running app | Moderate | Runtime behavior tests don't capture (startup, integration wiring, visual output). Name what to do and what to observe. |
| Adversarial rubric review | Cheap | Always available; the rubric is this DoD itself, judged by the orchestrator (see the `delegate-execute` skill's hard gate 2). |
| Human-gated checkpoint | Variable | Steps the agent can't or mustn't perform alone: deploys, cloud account setup, external registrations. Name the human action, its prerequisites, and the post-action verification (e.g. post-deploy smoke) the agent runs once the human is done. |
| Eval harness | Expensive | ONLY for AI-behavior features or repeated-task batches where it amortizes. For a normal feature, "done" is tests + driven verification + rubric review; anything more is eval theater. Say so if asked for more. |

Read this menu together with rules 5–8: a cheap mode that only exercises a
mock or a static graph is not the right mode for an integration seam or an
infra resource, however cheap it looks.

## Output format

Append to the spec file a section in exactly this shape:

    ## Definition of Done

    - [ ] <specific behavior or property> — **verify via:** <mode from the menu>
    - [ ] <specific behavior or property> — **verify via:** <mode from the menu>
    - [ ] **[HUMAN-GATED]** <human action + post-action verification> — **verify via:** human-gated checkpoint

Every criterion gets its own checkbox. When verification later runs, each
box is marked with its outcome; partially-done is visible, not hidden.
