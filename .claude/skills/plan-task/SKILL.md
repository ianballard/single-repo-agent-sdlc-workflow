---
name: plan-task
description: Write a concrete, intent-driven implementation spec for the current JIRA task before any code is written
---

You are the planning agent. Your job is to write a concrete implementation **spec** — not a vague sketch — for a task before any code is written. The spec must be specific enough that a different engineer (or agent) could implement it without re-deriving your decisions, and specific enough that AC verification and code review can be checked directly against it.
## Process

1. **Move the task to `planning` phase**: `tracker.set-phase <id> planning`

2. **Read the task in full** to understand the problem, AC, and any references: `tracker.read <id>`

   Review: `summary`, `description` (description text + AC list), and all comments.

3. **Explore the relevant codebase areas.** Read the files that will be touched, understand existing patterns and conventions, and identify what already exists that can be reused. Do not write the plan from memory alone. When integrating with a third party dependency, always check latest docs (use context7 if available) and check the actual package for implementation patterns. Do not guess.


4. **Write the implementation spec.** It must be:
   - **Intent-first** — open with a short statement of *what* the change accomplishes and *why*, so every decision below traces back to a goal.
   - **Concrete and file-level** — name the specific files to add or change and, for each, what changes (the functions/components/endpoints/types touched and the behavior they gain). Name the modules, routes, data shapes, and key identifiers by their real names — not "the relevant handler."
   - **Interface-explicit** — specify the contracts that matter: function/endpoint signatures, request/response or props shapes, data-model or schema changes, and any new config or env. State the inputs, outputs, and error/edge behavior. Describe these precisely; do not paste full implementations.
   - **Complete** — every AC maps to one or more named changes, and the spec says how that AC is satisfied.
   - **Ordered** — steps that depend on earlier ones come later; call out dependencies.
   - **Verifiable** — for each AC, state the concrete check (test, command, or observable behavior) that will confirm it.
   - **Scoped** — list what is explicitly *out* of scope so implementation does not drift.
   - **Scope-declared** — end the spec with a `### Files in scope` section: one file per line, prefixed `- `, listing every file the implementation is expected to add or change (exact paths; a glob like `frontend/src/components/auth/*` is acceptable for a new directory and covers files at any depth beneath it). This list is the scope the merge guard (Step 12) enforces — files changed outside it require a `## [SCOPE CHANGE]` comment at implementation time.

   Be specific about intent and contracts, but stop short of writing the full implementation — describe behavior and signatures, not line-by-line code or pseudocode bodies.

5. **Write the spec as a comment**: `tracker.comment <id> [PLAN] "<spec text, including the ### Files in scope section>"`

6. **Emit completion**:
   - Emit `PLAN_COMPLETE: plan written to task <id>` and continue to the next step in the workflow — do not stop.

## Rules

- Always read the relevant source files before writing the spec — the spec must name real files, symbols, and contracts, not placeholders
- Every AC must be traceable to at least one named change in the spec, with a stated verification check
- If planning reveals the task scope is larger than the ACs suggest, note this explicitly in the spec — do not silently expand scope
- Be concrete about intent and interfaces, but do not write the full implementation; describe behavior and signatures, not finished code
- The spec drives implementation, AC verification, and code review later; make it specific enough to check against directly
- The `### Files in scope` section is mandatory — without it the merge guard cannot enforce scope
