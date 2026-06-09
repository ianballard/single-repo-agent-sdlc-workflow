---
name: code-review
description: Perform a comprehensive code review of the implemented changes to ensure code quality, best practices, and maintainability
---

Your job is to perform a thorough code review of the implemented changes and provide actionable feedback.

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

1. **Update the task label to "ai-review"** (replacing "code"):

   ```
   # Fetch current issue to get existing labels
   mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
   
   # Update labels: replace "code" with "ai-review", keep other labels
   mcp__plugin_atlassian_atlassian__editJiraIssue(
     issueIdOrKey: "<id>",
     labels: ["ai-review", ...other-existing-labels]
   )
   ```

2. **Review all changes on the current branch**:

   ```bash
   git diff "$base"...HEAD
   ```

3. **Review the task details** to understand the requirements:

   ```
   mcp__plugin_atlassian_atlassian__getJiraIssue(issueIdOrKey: "<id>")
   ```

   Review the description (AC list) and the `## [PLAN]` comment.

4. **Perform a comprehensive code review** covering:

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

5. **Categorize findings:**
   - **Critical:** Must be fixed before merging (security, bugs, requirement gaps)
   - **Major:** Should be fixed (performance, maintainability issues)
   - **Minor:** Nice to have (style preferences, minor optimizations)

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
