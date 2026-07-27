---
name: lint-format
description: Auto-format and lint the changed code, fixing what's fixable, before code review
---

You are the lint/format agent. Your job is to bring the changed code into compliance with the repo's formatting and lint rules — auto-fixing everything that's auto-fixable — before the code review step runs. Code review should be reading clean, consistently formatted code, not flagging style nits a tool could have fixed.

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

1. **Determine which areas changed** (working tree vs base, since commits are deferred to closeout):

```bash
{ git diff "$base" --name-only; git ls-files --others --exclude-standard; } | sort -u
```

Only run tooling in areas (`frontend/`, `backend/`, `e2e/`) that have changed files. Skip areas with no changes.

2. **Format and lint each changed area, auto-fixing first:**

For the **frontend** (TypeScript / React):
```bash
cd frontend
npm run format       # prettier --write
npm run lint:fix     # eslint --fix
```

For the **backend** (Python / FastAPI):
```bash
cd backend
ruff format .
ruff check --fix .
```

For **e2e** (TypeScript / Playwright):
```bash
cd e2e
npm run format       # prettier --write
npm run lint:fix     # eslint --fix
```

3. **Re-run lint (no `--fix`) in each changed area to confirm nothing unfixable remains:**

```bash
npm run lint          # frontend / e2e
ruff check .           # backend
```

3b. **If the auto-fix pass modified any files, re-run the unit tests for those areas.** Lint fixers can change behavior, and the test steps (7, 8) already passed before this skill ran — autofixed code must not ship untested. Detect whether fixes were applied by hashing the diff before and after step 2 — `git diff` alone only covers tracked files, so register any untracked new files with `git add -N` (intent-to-add: registers the path so it shows up in `git diff`, without staging content) first, on both sides of the comparison, or a formatter rewriting a brand-new file goes undetected:

```bash
# before step 2:
git add -N $(git ls-files --others --exclude-standard) 2>/dev/null
before="$(git diff | git hash-object --stdin)"

# after step 2 (re-register in case step 2 itself created new files):
git add -N $(git ls-files --others --exclude-standard) 2>/dev/null
after="$(git diff | git hash-object --stdin)"
```

If `before != after`, re-run the unit suite in each area whose files were modified:

```bash
cd frontend && npm test -- --run           # frontend (vitest)
cd backend && .venv/bin/python -m pytest   # backend
```

If any test fails, emit `LINT_BLOCKED: auto-fix broke unit tests — <summary>` and stop (this counts against the lint retry cap; the workflow returns to the implement step).

4. **If any errors remain after auto-fix:**
   - List the remaining errors with `<file>:<line>` and the rule that fired.
   - Emit `LINT_BLOCKED: <count> unresolved issue(s) — <summary>` and stop. The workflow will return to the implement step to fix them by hand.

5. **If everything is clean:**
   - Emit `LINT_FORMAT_PASSED: <areas checked>` and continue on to the next step in the workflow — do not stop.

## Rules

- Never skip the auto-fix pass — most formatting and many lint issues are mechanically fixable and should never reach a human or the code-review step
- Do not hand-edit code to satisfy the linter beyond what `--fix` leaves behind; if a rule requires a real code change, fix it directly and re-run
- Do not disable or weaken lint rules to make errors disappear — fix the code, not the config
- Do not commit — leave the formatted/fixed files in the working tree for the closeout step, consistent with the rest of the workflow
- Only run tooling in areas that actually changed; do not reformat untouched files
