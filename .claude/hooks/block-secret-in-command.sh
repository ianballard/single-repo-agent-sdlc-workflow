#!/usr/bin/env bash
# PreToolUse | matcher: Bash
# Blocks embedding secret material in a shell command. Command strings land in the
# transcript, which flows into logs, memory files, and compaction summaries.
#
# Self-test:  bash .claude/hooks/block-secret-in-command.sh --self-test

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HOOK_DIR/lib/secret-patterns.sh"

# Fail CLOSED: a missing lib must not silently disable the check.
if [[ ! -r "$LIB" ]]; then
  echo "BLOCKED: $LIB is missing or unreadable — cannot verify this command is secret-free. Restore the file before continuing." >&2
  exit 2
fi
# shellcheck source=lib/secret-patterns.sh
source "$LIB"

if [[ "${1:-}" == "--self-test" ]]; then
  fail=0
  blk() { if r=$(has_secret_material "$1"); then echo "  ok   BLOCK  ($r) ${1:0:48}"; else echo "  FAIL allowed ${1:0:48}"; fail=1; fi; }
  alw() { if r=$(has_secret_material "$1"); then echo "  FAIL blocked ($r) ${1:0:48}"; fail=1; else echo "  ok   allow  ${1:0:48}"; fi; }
  echo "== block-secret-in-command"
  # Synthetic credentials; they need the real shape to exercise the patterns. The
  # line-scoped `gitleaks:allow` markers keep .githooks/pre-commit from refusing the commit.
  blk 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE aws s3 ls'
  blk 'curl -H "Authorization: Bearer sk-abcdefghijklmnopqrstuvwxyz01"'
  blk 'export GH_TOKEN=ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8' # gitleaks:allow
  alw 'echo $AWS_SECRET_ACCESS_KEY | wc -c'
  alw 'grep -rn PRIVATE_KEY backend/'
  alw 'export AWS_PROFILE=jg-sandbox'
  alw 'pytest backend/tests/test_auth.py'
  alw 'git commit -m "docs: explain API_KEY handling"'
  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi

INPUT=$(cat)
command=$(printf '%s' "${INPUT:-${CLAUDE_TOOL_INPUT:-}}" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$command" ]] && exit 0

if reason=$(has_secret_material "$command"); then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf 'BLOCKED: this command contains %s. Command strings are recorded in the transcript and the audit log. Reference an environment variable instead of inlining the value.' "$reason" | jq -Rs .)"
  exit 0
fi

exit 0
