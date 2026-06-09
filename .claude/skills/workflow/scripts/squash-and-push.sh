#!/usr/bin/env bash
#
# Workflow Step 13: Squash commits on the feature branch and force-push.
#
# If more than one commit exists ahead of the base, squashes them into one
# commit using the provided subject, then pushes with --force-with-lease.
#
# Usage:
#   .claude/skills/workflow/scripts/squash-and-push.sh <task-id> "<conventional-commit-subject>" [base-branch]
#
# [base-branch] is the branch the feature branch was cut from (recorded by the
# intake skill). Without it, a branch cut from anything other than main gets
# squashed against origin/main, folding the parent branch's own commits into
# the task commit.
#
# Exit codes:
#   0  Squashed (or nothing to squash) and pushed successfully.
#   1  Push failed.
#   3  Argument error.
#
# The script is intended to be invoked from the workspace root.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: squash-and-push.sh <task-id> \"<conventional-commit-subject>\" [base-branch]" >&2
  exit 3
fi

task_id="$1"
commit_subject="$2"
base_branch="${3:-}"
current_branch="$(git branch --show-current)"

# Derive the diff base: explicit base branch wins, then upstream, then main.
base=""
if [ -n "$base_branch" ]; then
  if git rev-parse --verify "origin/$base_branch" >/dev/null 2>&1; then
    base="origin/$base_branch"
  elif git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
    base="$base_branch"
  else
    echo "warning: base branch '$base_branch' not found, falling back" >&2
  fi
fi
if [ -z "$base" ]; then
  base="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
fi
if [ -z "$base" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    base="origin/main"
  else
    base="main"
  fi
fi

if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  echo "Skipping squash: base '$base' not found"
else
  ahead="$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)"

  if [ "$ahead" -eq 0 ]; then
    echo "Nothing to squash — no commits ahead of $base"
  elif [ "$ahead" -gt 1 ]; then
    squash_msg="$(git log --format='%s%n%n%b' "$base..HEAD" --reverse)"
    git reset --soft "$(git merge-base "$base" HEAD)"
    git commit -m "$commit_subject" -m "$squash_msg"
    echo "Squashed $ahead commits into one"
  else
    echo "1 commit ahead of $base — nothing to squash"
  fi
fi

# Push (force-with-lease if the branch already has an upstream, otherwise set it).
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push --force-with-lease
else
  git push -u origin "$current_branch"
fi

echo "SQUASH_PUSH_COMPLETE: $current_branch pushed"
exit 0
