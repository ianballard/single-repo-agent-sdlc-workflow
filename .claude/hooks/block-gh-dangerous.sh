#!/usr/bin/env bash
# PreToolUse | matcher: Bash
# Guards the gh CLI. The open-pr skill depends on gh, so gh is available in every
# session — which means the dangerous verbs need explicit blocking.
#
# Two things here are not obvious:
#   - `gh pr merge` contradicts the documented hand-off model. Closeout stops at
#     Human Code Review and a human transitions the issue to Done after reviewing
#     the PR. Nothing in an agent session merges.
#   - `gh auth token` prints a live credential to stdout, which lands in the
#     transcript, the audit log, memory files, and every compaction summary after.
#
# `gh api` with a mutating method is both arbitrary GitHub mutation and an egress
# channel that a curl/wget-based exfiltration hook cannot see. Flag forms vary
# (-X POST, --method POST, -XPOST), which is exactly why this is a hook and not a
# permission-rule string match.
#
# Self-test:  bash .claude/hooks/block-gh-dangerous.sh --self-test

set -uo pipefail

classify() {
  local c="$1"

  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+pr[[:space:]]+merge ]]; then
    echo "DENY|gh pr merge is prohibited. Closeout hands off at Human Code Review; a human reviews the PR and transitions the issue to Done. Nothing in an agent session merges."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+auth[[:space:]]+token ]]; then
    echo "DENY|gh auth token prints a live credential to stdout, which is recorded in the transcript, the audit log, and every later compaction summary. Never surface a credential."; return
  fi
  # Only the credential keys matter. Blanket-denying `gh config get` also blocked
  # harmless reads like `gh config get git_protocol`.
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+config[[:space:]]+get ]] \
     && [[ "$c" =~ (oauth|token|password|credential) ]]; then
    echo "DENY|this reads a stored credential, which would land in the transcript, the audit log, and every later compaction summary. Never surface a credential."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+api([[:space:]]|$) ]]; then
    if [[ "$c" =~ (-X|--method)[[:space:]]*(POST|PATCH|PUT|DELETE) ]]; then
      echo "DENY|gh api with a mutating method is arbitrary GitHub mutation, and an egress channel that curl/wget-based checks cannot see. Use the purpose-built gh subcommand a skill declares, or hand the change to a human."; return
    fi
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+repo[[:space:]]+(delete|archive|rename) ]]; then
    echo "DENY|destructive repository administration is a human action."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+release[[:space:]]+delete ]]; then
    echo "DENY|deleting a release is a human action."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+secret[[:space:]]+(set|delete) ]]; then
    echo "DENY|managing repository secrets is a human action, and setting one would place secret material in a command string."; return
  fi
  if [[ "$c" =~ (^|[[:space:];&|])gh[[:space:]]+workflow[[:space:]]+run ]]; then
    echo "ASK|triggering a GitHub Actions workflow runs CI against real credentials and may deploy. Confirm this is intended."; return
  fi
}

if [[ "${1:-}" == "--self-test" ]]; then
  fail=0
  expect() {
    local want="$1" cmd="$2" got
    got=$(classify "$cmd"); got="${got%%|*}"; got="${got:-OK}"
    if [[ "$got" == "$want" ]]; then echo "  ok   $got  $cmd"; else echo "  FAIL want=$want got=$got  $cmd"; fail=1; fi
  }
  echo "== block-gh-dangerous"
  expect DENY 'gh pr merge 42 --squash'
  expect DENY 'gh auth token'
  expect DENY 'gh config get -h github.com oauth_token'
  expect DENY 'gh api -X POST /repos/o/r/issues'
  expect DENY 'gh api --method DELETE /repos/o/r/git/refs/heads/x'
  expect DENY 'gh api -XPOST /repos/o/r/merges'
  expect DENY 'gh repo delete o/r'
  expect DENY 'gh release delete v1.0.0'
  expect DENY 'gh secret set MY_TOKEN'
  expect ASK  'gh workflow run deploy.yml'
  # must NOT fire — the open-pr skill needs these
  expect OK   'gh pr create --base develop --title x --body y'
  expect OK   'gh pr view 42'
  expect OK   'gh pr list --state open'
  expect OK   'gh api /repos/o/r/pulls/42'
  expect OK   'gh auth status'
  expect OK   'gh repo view --json defaultBranchRef'
  expect OK   'gh config get git_protocol'
  expect OK   'gh config get editor'
  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi

INPUT=$(cat)
command=$(printf '%s' "${INPUT:-${CLAUDE_TOOL_INPUT:-}}" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$command" ]] && exit 0

verdict=$(classify "$command")
[[ -z "$verdict" ]] && exit 0

case "${verdict%%|*}" in
  DENY) pd="deny" ;;
  ASK)  pd="ask" ;;
  *)    exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' \
  "$pd" "$(printf '%s' "${verdict#*|}" | jq -Rs .)"
exit 0
