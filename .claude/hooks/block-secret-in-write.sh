#!/usr/bin/env bash
# PreToolUse | matcher: Read|Edit|Write|NotebookEdit|Grep|Glob
# Blocks writing secret material into a file (Write .content / Edit .new_string).
#
# Self-test:  bash .claude/hooks/block-secret-in-write.sh --self-test

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HOOK_DIR/lib/secret-patterns.sh"

# Fail CLOSED: a missing lib must not silently disable the check.
if [[ ! -r "$LIB" ]]; then
  echo "BLOCKED: $LIB is missing or unreadable — cannot verify this write is secret-free. Restore the file before continuing." >&2
  exit 2
fi
# shellcheck source=lib/secret-patterns.sh
source "$LIB"

if [[ "${1:-}" == "--self-test" ]]; then
  fail=0
  blk() { if r=$(has_secret_material "$1"); then echo "  ok   BLOCK  ($r) ${1:0:48}"; else echo "  FAIL allowed ${1:0:48}"; fail=1; fi; }
  alw() { if r=$(has_secret_material "$1"); then echo "  FAIL blocked ($r) ${1:0:48}"; fail=1; else echo "  ok   allow  ${1:0:48}"; fi; }
  echo "== block-secret-in-write"
  # The fixtures below are synthetic credentials — they have to have the real SHAPE or they
  # would not exercise the patterns they exist to test. `gitleaks:allow` marks the specific
  # lines so .githooks/pre-commit does not refuse the commit; without it gitleaks correctly
  # flags this file. Keep the marker line-scoped: a file- or path-level allowlist would
  # blind gitleaks to a real secret landing here later.
  blk 'aws_access_key_id = AKIAIOSFODNN7EXAMPLE'
  blk 'ASIAY34FZKBOKMUTVV7A' # gitleaks:allow
  blk '-----BEGIN RSA PRIVATE KEY-----'
  blk '-----BEGIN OPENSSH PRIVATE KEY-----'
  blk 'OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz012345'
  blk 'token: ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8' # gitleaks:allow
  blk 'SLACK_BOT=xoxb-123456789012-abcdefghijkl'
  blk 'AWS_SESSION_TOKEN=Fw0aDGV1LWNlbnRyYWwtMSJHMEUCIQD9xK3n2Lm' # gitleaks:allow
  # Deliberately NOT blocked: a low-entropy human password is indistinguishable from a
  # normal string here. gitleaks at pre-commit is the layer that catches these.
  alw 'DB_PASSWORD=hunter2hunter2hunter2'
  alw 'AWS_SECRET_ACCESS_KEY'
  alw 'grep -r AWS_SECRET_ACCESS_KEY .'
  alw 'the PRIVATE_KEY env var must be set by the operator'
  alw 'DB_PASSWORD=changeme-in-production'
  alw 'API_KEY=your-api-key-here'
  alw 'JIRA_TOKEN=$JIRA_TOKEN'
  alw 'SECRET_KEY=${SECRET_KEY}'
  alw 'API_KEY=<paste-your-key>'
  alw 'DATABASE_PASSWORD=example-value-only'
  alw 'def get_token(): return os.environ["API_TOKEN"]'
  # False-positive probes: ordinary constants whose NAME looks secret-ish but whose
  # value is not a credential. These are the realistic cost of the heuristic.
  alw 'const SECRET_KEY_HEADER = "x-secret-key"'
  alw 'API_TOKEN_HEADER = "authorization-token"'
  alw 'SECRET_NAME = "jira-connection-secret"'
  alw 'export const API_KEY_QUERY_PARAM = "apiKeyOverride"'
  alw 'ACCESS_KEY_PATTERN = re.compile(r"AKIA[0-9A-Z]{16}")'
  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi

INPUT=$(cat)
PAYLOAD="${INPUT:-${CLAUDE_TOOL_INPUT:-}}"

file_path=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)

# The hook library itself contains these patterns as regex literals, so editing
# anything under .claude/hooks/ would otherwise be unconditionally blocked.
# Those paths carry an `ask` permission rule, so a human still sees every change.
case "$file_path" in
  */.claude/hooks/*|.claude/hooks/*) exit 0 ;;
esac

content=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
[[ -z "$content" ]] && exit 0

if reason=$(has_secret_material "$content"); then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf 'BLOCKED: this write contains %s. Never commit secret material to a file. Put a placeholder in the .example file and have the human supply the real value out of band.' "$reason" | jq -Rs .)"
  exit 0
fi

exit 0
