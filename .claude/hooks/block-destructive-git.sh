#!/usr/bin/env bash
# PreToolUse | matcher: Bash
# Blocks git commands that destroy uncommitted work.
#
# Why this matters more here than in most repos: the SDLC workflow defers ALL commits
# to closeout (Step 13). For the entire run, the uncommitted working tree IS the task's
# work product. A single `git clean -fd` from a subagent erases a whole task.
#
# `git reset --soft` is deliberately permitted — closeout's squash needs it.
#
# A hook rather than only permission rules because a PreToolUse hook exiting 2 stops
# the call BEFORE permission rules are evaluated, so it still fires on commands that
# the `Bash(git checkout:*)` allow rule would otherwise wave straight through.
#
# Self-test:  bash .claude/hooks/block-destructive-git.sh --self-test

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NORM="$HOOK_DIR/lib/git-normalize.sh"
# Fail CLOSED: without the normaliser, `git -C /p reset --hard` slips through.
if [[ ! -r "$NORM" ]]; then
  echo "BLOCKED: $NORM is missing or unreadable — cannot safely evaluate this git command. Restore the file before continuing." >&2
  exit 2
fi
# shellcheck source=lib/git-normalize.sh
source "$NORM"

# classify <command>  ->  prints "DENY <reason>" | "ASK <reason>" | nothing
classify() {
  local c
  # Strip git global options (-C, -c, --git-dir=, ...) so the subcommand sits next to
  # `git` and one pattern per subcommand covers every spelling.
  c="$(normalize_git "$1")"

  # --- unrecoverable history / work destruction ---
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+reset[[:space:]]+.*--hard ]]; then
    echo "DENY|git reset --hard discards every uncommitted change. This workflow holds the task's work in the working tree until closeout. Use git reset --soft if you are restructuring commits."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+clean([[:space:]]|$) ]]; then
    # A dry run deletes nothing and is genuinely useful (e.g. merge-guard checking for
    # stray files). -n wins over -f in git, so a cluster containing n is safe.
    if [[ "$c" =~ --dry-run ]] || [[ "$c" =~ [[:space:]]-[a-zA-Z]*n ]]; then
      return
    fi
    echo "DENY|git clean deletes untracked files, which includes new files the current task just created. Use git clean -n to preview instead."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+checkout[[:space:]]+--[[:space:]] ]]; then
    echo "DENY|git checkout -- <path> discards uncommitted changes to those paths."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+checkout[[:space:]]+HEAD[[:space:]]+-- ]]; then
    echo "DENY|git checkout HEAD -- <path> discards uncommitted changes to those paths."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+restore([[:space:]]|$) ]]; then
    # --staged (or -S) ALONE only unstages: the working tree keeps its changes, so no
    # work is lost. Combining it with --worktree/-W does discard, and stays denied.
    if [[ "$c" =~ (--staged|[[:space:]]-[a-zA-Z]*S) ]] \
       && [[ ! "$c" =~ (--worktree|[[:space:]]-[a-zA-Z]*W) ]]; then
      return
    fi
    echo "DENY|git restore discards uncommitted changes to those paths. git restore --staged (unstage only) is permitted."; return
  fi
  # -D force-deletes even an unmerged branch. Lowercase -d REFUSES to delete an unmerged
  # branch, so git already protects the work — no need to block it too.
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+branch[[:space:]]+.*(-D|--delete[[:space:]]+.*--force|--force[[:space:]]+.*--delete) ]]; then
    echo "DENY|git branch -D force-deletes an unmerged branch, orphaning task work. Use -d, which refuses unless the branch is merged."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+stash[[:space:]]+(drop|clear) ]]; then
    echo "DENY|git stash drop/clear permanently destroys stashed work."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+reflog[[:space:]]+expire ]]; then
    echo "DENY|expiring the reflog removes the last recovery path for destroyed commits."; return
  fi
  # Plain `git gc` is routine maintenance that git runs automatically, and its default
  # prune horizon (gc.pruneExpire, 2 weeks) leaves today's work recoverable. Only an
  # explicit --prune collapses that window.
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+gc([[:space:]]|$) ]] && [[ "$c" =~ --prune ]]; then
    echo "DENY|git gc --prune makes otherwise-recoverable commits unrecoverable. Plain git gc is permitted."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+filter-branch ]]; then
    echo "DENY|filter-branch rewrites history irreversibly."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+update-ref[[:space:]]+.*-d ]]; then
    echo "DENY|git update-ref -d deletes a ref directly, bypassing branch-deletion guards."; return
  fi

  # --- bypassing the .githooks layer ---
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+(commit|push)[[:space:]]+.*--no-verify ]]; then
    echo "DENY|--no-verify skips the .githooks/ pre-commit and pre-push checks, which are the layer that catches secrets and trunk pushes."; return
  fi

  # --- needs a human, but legitimate in some flows ---
  # Read-only stash subcommands are fine; only the ones that move work are not.
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+stash[[:space:]]+(list|show)([[:space:]]|$) ]]; then
    return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+stash([[:space:]]|$) ]]; then
    echo "ASK|git stash silently empties the working tree. Nothing flags it as destructive, but the next workflow step will report the implementation missing. Confirm this is intended."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+worktree[[:space:]]+remove ]]; then
    echo "ASK|removing a worktree discards anything uncommitted inside it. Closeout does this legitimately at teardown; confirm the work is already pushed."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])git[[:space:]]+commit[[:space:]]+.*--amend ]]; then
    echo "ASK|amending a pushed commit forces a force-push to land, and force-push is denied. Confirm this commit is unpushed."; return
  fi
}

if [[ "${1:-}" == "--self-test" ]]; then
  fail=0
  expect() { # expect <want: DENY|ASK|OK> <command>
    local want="$1" cmd="$2" got
    got=$(classify "$cmd"); got="${got%%|*}"; got="${got:-OK}"
    if [[ "$got" == "$want" ]]; then echo "  ok   $got  $cmd"; else echo "  FAIL want=$want got=$got  $cmd"; fail=1; fi
  }
  echo "== block-destructive-git"
  expect DENY 'git reset --hard HEAD'
  expect DENY 'git reset --hard origin/develop'
  expect DENY 'git clean -fd'
  expect DENY 'git clean -df'
  expect DENY 'git clean -fdx'
  expect DENY 'git checkout -- .'
  expect DENY 'git checkout -- frontend/src/App.tsx'
  expect DENY 'git checkout HEAD -- backend/'
  expect DENY 'git restore .'
  expect DENY 'git restore --staged --worktree .'
  expect DENY 'git restore -SW frontend/'
  expect DENY 'git branch -D feature/KAN-42-thing'
  expect DENY 'git branch --delete --force feature/KAN-42-thing'
  expect DENY 'git stash drop'
  expect DENY 'git stash clear'
  expect DENY 'git reflog expire --expire=now --all'
  expect DENY 'git gc --prune=now'
  expect DENY 'git commit --no-verify -m x'
  expect DENY 'git push --no-verify origin feature/x'
  expect DENY 'cd /tmp && git reset --hard'
  # Regression: git global options must not create a bypass (found by live testing).
  expect DENY 'git -C /some/path reset --hard HEAD'
  expect DENY 'git -C/some/path reset --hard'
  expect DENY 'git -c user.name=x reset --hard'
  expect DENY 'git -C /p -c a=b reset --hard'
  expect DENY 'git --git-dir=/p/.git clean -fdx'
  expect DENY 'git --work-tree=/p checkout -- .'
  expect DENY 'git --no-pager restore .'
  expect DENY 'git -P -C /p branch -D feature/x'
  expect ASK  'git -C /p stash'
  expect ASK  'git stash'
  expect ASK  'git stash push -m wip'
  expect ASK  'git worktree remove .claude/worktrees/feature-x'
  expect ASK  'git commit --amend --no-edit'
  # must NOT fire
  expect OK   'git reset --soft $(git merge-base HEAD develop)'
  expect OK   'git status'
  expect OK   'git checkout -b feature/KAN-42-thing'
  expect OK   'git checkout develop'
  expect OK   'git add -A'
  expect OK   'git commit -m "feat: thing"'
  expect OK   'git branch --show-current'
  expect OK   'git stash list'
  expect OK   'git stash show -p'
  # Relaxed after review: these have a safe variant and no longer blanket-deny.
  expect OK   'git clean -n'
  expect OK   'git clean --dry-run'
  expect OK   'git clean -nd'
  expect OK   'git clean -ndx'
  expect OK   'git restore --staged frontend/'
  expect OK   'git restore -S frontend/'
  expect OK   'git branch -d feature/KAN-42-thing'
  expect OK   'git branch --delete feature/KAN-42-thing'
  expect OK   'git gc'
  expect OK   'git gc --aggressive'
  expect OK   'git worktree add .claude/worktrees/feature-x'
  expect OK   'git log --oneline -5'
  expect OK   'npm run clean'
  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi

INPUT=$(cat)
command=$(printf '%s' "${INPUT:-${CLAUDE_TOOL_INPUT:-}}" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$command" ]] && exit 0

verdict=$(classify "$command")
[[ -z "$verdict" ]] && exit 0

decision="${verdict%%|*}"
reason="${verdict#*|}"

case "$decision" in
  DENY) pd="deny" ;;
  ASK)  pd="ask" ;;
  *)    exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' \
  "$pd" "$(printf '%s' "$reason" | jq -Rs .)"
exit 0
