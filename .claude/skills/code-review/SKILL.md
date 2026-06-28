---
name: code-review
description: Perform a comprehensive code review of the implemented changes to ensure code quality, best practices, and maintainability
---

Your job is to obtain a thorough, **independent** code review of the implemented changes and act on it.

## Run the review in a separate subagent

Do **not** review the diff yourself in this context — you carry the bias of having just planned and written the code. Instead, dispatch the review to a fresh subagent (via the `Agent` tool, `subagent_type: "general-purpose"` or a dedicated `code-reviewer` agent if available) that sees only the diff, the task, and the review rubric. This gives an independent perspective that is far more likely to catch what the implementer missed.

This skill is the orchestrator: it derives the diff base, dispatches the reviewer subagent, then records the subagent's findings to JIRA and emits the verdict. The subagent performs the judgment; it does not write to JIRA or transition the issue.

## Deriving the diff base

From the workspace root:

```bash
base="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -z "$base" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    base="origin/main"
  else
    base="main"
  fi
fi
```

## Process

1. **Transition the task to "AI Code Review" status**:

   ```
   mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue(issueIdOrKey: "<id>")
   mcp__plugin_atlassian_atlassian__transitionJiraIssue(issueIdOrKey: "<id>", transitionId: "<ai-code-review-id>")
   ```

2. **Gather the review inputs.** Capture the full diff and the task context to hand to the reviewer subagent:

   ```bash
   # Note: commits are deferred to closeout, so include uncommitted work.
   git diff "$base"            # tracked changes (committed + staged + unstaged) vs base
   git status --porcelain      # surface any untracked files the reviewer should read
   ```

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
   ```

   From the issue, pull the description (AC list) and the `## [PLAN]` comment.

3. **Dispatch the review to a separate subagent.** Use the `Agent` tool with a self-contained prompt that includes: the task summary, the AC list, the `## [PLAN]` spec, and the diff (or the base ref and instructions to run the diff itself). Instruct the subagent to perform the comprehensive review described below and to **return** its findings as a structured list — each item tagged `[critical] | [major] | [minor]` with `<file>:<line>`, a description, and a suggested fix — plus an overall verdict. The subagent must not edit files, write to JIRA, or transition the issue; it only returns findings to you.

4. **The reviewer subagent performs a comprehensive code review** covering:

   **Code Quality:**
   - Code clarity and readability
   - Appropriate naming conventions
   - Code organization and structure
   - DRY principle adherence
   - Proper error handling

   **Best Practices:**
   - Language/framework-specific best practices
   - Security considerations (input validation, SQL injection, XSS, etc.)
   - Performance implications
   - Memory management
   - Proper use of design patterns

   **Maintainability:**
   - Code comments where needed (but not obvious code)
   - Documentation updates
   - Test coverage adequacy
   - Dependency management

   **Requirements Alignment:**
   - Does the implementation meet the acceptance criteria?
   - Are there any scope creep or unnecessary additions?
   - Are there any missing edge cases?

   Findings are categorized by the subagent as:
   - **Critical:** Must be fixed before merging (security, bugs, requirement gaps)
   - **Major:** Should be fixed (performance, maintainability issues)
   - **Minor:** Nice to have (style preferences, minor optimizations)

5. **Act on the subagent's findings.** Read the returned findings and verdict. Do not soften or re-litigate them; the subagent is the independent reviewer. Proceed to step 6 or 7 based on the highest severity present.

6. **If critical or major issues are found:**
   - Document each issue and add as a JIRA comment:
   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     issueIdOrKey: "<id>",
     comment: "## [NOTES]\n\nCODE REVIEW FINDINGS:\n- <file>:<line> [critical] <description> — fix: <suggested fix>\n- <file>:<line> [major] <description> — fix: <suggested fix>"
   )
   ```
   - Output `CODE_REVIEW_BLOCKED: <number> critical/major issues found` and stop.

7. **If only minor issues or no issues are found:**
   - Add review summary as a JIRA comment:
   ```
   mcp__plugin_atlassian_atlassian__addCommentToJiraIssue(
     issueIdOrKey: "<id>",
     comment: "## [NOTES]\n\nCODE REVIEW: Approved with <number> minor suggestions"
   )
   ```
   - Emit `CODE_REVIEW_APPROVED: <summary>` and continue on to the next step in the workflow — do not stop.

## Review Checklist

- [ ] Code follows project coding standards
- [ ] No hardcoded secrets or sensitive data
- [ ] Proper input validation
- [ ] Error handling is appropriate
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] No obvious performance issues
- [ ] Tests cover the main functionality
- [ ] Documentation is updated
- [ ] No unnecessary dependencies added
- [ ] Code is DRY (Don't Repeat Yourself)
- [ ] Functions/methods are single responsibility
- [ ] Variable/function names are clear and descriptive

## Rules

- Be constructive and specific in feedback
- Provide code examples for suggested fixes where helpful
- Focus on significant issues; don't nitpick style if it matches project conventions
- Critical issues must be fixed before approval
- Major issues should be strongly encouraged to fix
- Minor issues are suggestions only
- Balance perfectionism with pragmatism
