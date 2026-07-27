---
name: implementation-notes
description: Write comprehensive implementation notes documenting what was done, key decisions, and any relevant context
---

Your job is to document the implementation details for a completed task.

## Deriving the diff base

Prefer the base the branch was actually cut from over guessing — `develop` is only a fallback. Read `Base: <base>` from the task's `## [BRANCH]` JIRA comment (`tracker.read-comments <id> [BRANCH]`) — the same value `intake` recorded and `squash-and-push.sh`/`open-pr` already key off of. Only derive a git-based default when no `## [BRANCH]` comment exists (a legacy task planned before this was recorded):

```bash
# Fallback only — the [BRANCH] comment's Base: line always wins when present.
base="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -z "$base" ]; then
  if git rev-parse --verify origin/develop >/dev/null 2>&1; then
    base="origin/develop"
  else
    base="develop"
  fi
fi
```

## Process

1. **Review the changes made on the current branch** (commits are deferred to closeout, so diff the working tree, not just `HEAD`):

   ```bash
   git diff "$base" --stat
   git ls-files --others --exclude-standard
   git log "$base"..HEAD --oneline   # usually empty before closeout — informational only
   ```

2. **Review the task details** to understand the original requirements: `tracker.read <id>`

   Review the description (AC list) and existing comments (plan, any prior notes).

3. **Write implementation notes** that include:

   **What was implemented:**
   - Summary of the changes made
   - List of files modified/created/deleted
   - Key functionality added or modified

   **Key technical decisions:**
   - Architecture or design patterns used
   - Why certain approaches were chosen over alternatives
   - Any trade-offs or limitations

   **Integration points:**
   - How this integrates with existing code
   - Any new dependencies added
   - Configuration changes required

   **Testing coverage:**
   - What tests were added/updated
   - Test coverage metrics if available
   - Manual testing performed

   **Future considerations:**
   - Known limitations or technical debt
   - Potential improvements or optimizations
   - Related work that may be needed

4. **Append the implementation notes**: `tracker.comment <id> [NOTES] "<implementation notes>"`

5. **Also record the modified files** (a historical record for reviewers; the merge guard enforces the plan's `### Files in scope`, not this list): `tracker.comment <id> [MODIFIED FILES] "<list of files from git diff --stat>"`

6. **Emit completion**:
   - Emit `IMPLEMENTATION_NOTES_COMPLETE: notes added to task <id>` and continue on to the next step in the workflow — do not stop.

## Rules

- Be concise but comprehensive
- Focus on "why" decisions were made, not just "what" was done
- Use markdown formatting for readability
- Include specific file paths and line numbers where relevant
- Highlight any breaking changes or migration steps needed
- Document any deviation from the original plan and why
