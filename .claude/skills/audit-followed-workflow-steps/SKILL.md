---
name: audit-followed-workflow-steps
description: Audit the workflow to ensure all required steps were completed properly
---

You are the audit agent. Your job is to verify that all required workflow steps were completed before finalizing the task.

## Process

1. **Review the task history** to verify each step was completed:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(cloudId: "<cloudId>", issueIdOrKey: "<id>")
   ```

   Examine: current status, labels, assignee, description (AC checkboxes), and all comments (look for `## [BRANCH]`, `## [PLAN]`, `## [NOTES]`, `## [MODIFIED FILES]`, `## [FINAL SUMMARY]` headers).

2. **Verify the following checklist.** Expected status progression: `To Do → Intake → Plan → Code → AI Code Review → Human Code Review → Done`. Closeout moves the issue to Human Code Review, not Done — Done is a human-only transition made after reviewing the PR.

   **Step 1: Work Claimed**
   - [ ] Task ID and title appear in the workflow context

   **Step 2: Intake** (`intake` skill)
   - [ ] Task status is "Intake" or later
   - [ ] A `## [BRANCH]` comment exists with the git branch name
   - [ ] Git branch was created following gitflow conventions (e.g., `feature/<key>-<slug>`)
   - [ ] `INTAKE_COMPLETE` was emitted

   **Step 2b: Worktree Setup** (`setup-worktree` skill)
   - [ ] Worktree exists at `.claude/worktrees/<branch>` (`git worktree list` run from the main repo shows it)
   - [ ] The worktree's checked-out branch matches the `## [BRANCH]` comment

   **Step 3: Task Assessment** (`assess-task` skill)
   - [ ] Task has clear problem definition, expected outcome, and testable AC
   - [ ] `TASK_ASSESSMENT_PASSED` was emitted (or workflow was blocked for refinement)

   **Step 4: Planning** (`plan-task` skill)
   - [ ] Task status is "Plan" or later
   - [ ] A `## [PLAN]` comment exists with the implementation plan
   - [ ] The `## [PLAN]` comment contains a `### Files in scope` section
   - [ ] `PLAN_COMPLETE` was emitted

   **Step 4a: AI Hostile Plan Review** (`hostile-plan-review` skill)
   - [ ] A `HOSTILE PLAN REVIEW` comment exists in the JIRA issue
   - [ ] `HOSTILE_REVIEW_PASSED` was emitted (or blocking issues were resolved and plan revised)

   **Step 5: Implementation** (`implement` skill)
   - [ ] Task status is "Code" or later
   - [ ] Changes were implemented according to the plan
   - [ ] `IMPLEMENTATION_COMPLETE` was emitted

   **Step 6: AC Verification** (`verify-ac` skill)
   - [ ] All ACs in the description are checked (`- [x] #N`) with no unchecked `- [ ]` items remaining
   - [ ] `AC_VERIFIED` was emitted

   **Step 7: Unit Tests** (`unit-tests` skill)
   - [ ] Unit tests were created/updated as needed
   - [ ] `UNIT_TESTS_PASSED` was emitted

   **Step 8: E2E Tests** (`e2e-tests` skill)
   - [ ] `E2E_TESTS_PASSED` or `E2E_TESTS_SKIPPED` was emitted
   - [ ] If skipped: a `## [NOTES]` comment contains the skip evidence — the exact command run and its captured error output. A skip claim with no evidence fails the audit

   **Step 8b: Lint & Format** (`lint-format` skill)
   - [ ] `LINT_FORMAT_PASSED` was emitted (or blocking issues were resolved and re-run)

   **Step 9: Implementation Notes** (`implementation-notes` skill)
   - [ ] A `## [NOTES]` comment exists with implementation details
   - [ ] A `## [MODIFIED FILES]` comment exists
   - [ ] `IMPLEMENTATION_NOTES_COMPLETE` was emitted

   **Step 10: Code Review** (`code-review` skill)
   - [ ] Task status is "AI Code Review" or later
   - [ ] `CODE_REVIEW_APPROVED` was emitted (or all blocking issues resolved and re-reviewed)

3. **Substance spot-checks** — existence of an artifact is not proof the work behind it happened. Verify evidence, not form:

   - **AC evidence:** pick up to 2 checked ACs from the description (all of them if there are 2 or fewer). For each, find the concrete change in the working-tree diff (`git diff <base>` from the worktree, plus untracked files) that satisfies it. An AC checked with no supporting change in the diff fails the audit.
   - **Scope reconciliation:** every file in the `## [MODIFIED FILES]` comment must appear in the plan's `### Files in scope` section or a `## [SCOPE CHANGE]` comment (routine artifacts — lock files, `test-results/` — exempt). An unexplained file fails the audit.
   - **Plan depth:** the `## [PLAN]` comment must name real files and contracts, not just restate the ACs. A plan with no named file fails the audit.

4. **For each incomplete step**:
   - Document which step was missed
   - Document what needs to be done

5. **Emit results**:
   - If all steps completed: Emit `AUDIT_PASSED: all workflow steps completed` and continue on to the next step in the workflow — do not stop.
   - If steps are missing: Emit `AUDIT_FAILED: missing steps — <list of missing steps>` and return the list

## Rules

- All steps must be verified as complete
- Check the JIRA issue comments and fields for evidence of each step
- If a step was intentionally skipped, there should be a documented reason in the comments
- Do not pass the audit if any critical steps are missing
- If the audit fails, provide clear guidance on what needs to be completed
