#!/usr/bin/env bash
# PreToolUse | matchers: Bash  AND  Read|Edit|Write|NotebookEdit|Grep|Glob
#
# Records every tool call that is ATTEMPTED, before any blocking hook or permission rule
# has had a say. This is the half the PostToolUse loggers structurally cannot capture:
# PostToolUse only fires on calls that actually execute, so a denied command exists in the
# transcript and nowhere else. Together the two files answer "everything the agent tried",
# not just "everything it did" — the record the SOC 2 posture in CLAUDE.md implies.
#
# MUST be registered FIRST in its matcher group, so it still runs when a later hook in the
# same group exits 2.
#
# Prints NOTHING to stdout — stdout from a PreToolUse hook is parsed as a permission
# decision, so a stray byte here would alter the outcome of every tool call.
# ALWAYS exits 0. Audit code fails open; a logging failure must never block work.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
PAYLOAD="${INPUT:-${CLAUDE_TOOL_INPUT:-}}"
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
LIB="$HOOK_DIR/lib/audit-id.sh"
# Fail OPEN, unlike the blocking hooks: no audit is better than a broken tool call.
[[ -r "$LIB" ]] || exit 0
# shellcheck source=lib/audit-id.sh
source "$LIB" 2>/dev/null || exit 0

log_dir=$(audit_dir)
[[ -z "$log_dir" ]] && exit 0

tool=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo unknown)
id=$(audit_id "$(audit_canon "$PAYLOAD")")

command=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
target=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.notebook_path // empty' 2>/dev/null || true)

if [[ -n "$command" ]]; then
  type=$(audit_classify "$command")
  subject="$command"
else
  type="file_access"
  subject="$target"
fi

# Flag attempts against guardrail files, mirroring audit-file-change-log.sh, so a
# configuration change is visible even when it was blocked.
guardrail=false
case "$target" in
  */.claude/*|.claude/*|*/CLAUDE.md|CLAUDE.md|*/.githooks/*|.githooks/*) guardrail=true ;;
esac
case "$target" in
  */.claude/worktrees/*|.claude/worktrees/*) guardrail=false ;;
esac
case "$target" in
  */.claude/worktrees/*/CLAUDE.md|*/.claude/worktrees/*/.claude/*) guardrail=true ;;
esac

printf '{"timestamp":%s,"id":"%s","phase":"attempt","agent":%s,"session":%s,"tool":%s,"type":"%s","cwd":%s,"subject":%s,"guardrail":%s}\n' \
  "$(date -u +"%Y-%m-%dT%H:%M:%SZ" | jq -Rs .)" \
  "$id" \
  "$(printf '%s' "${CLAUDE_AGENT:-interactive}" | jq -Rs .)" \
  "$(printf '%s' "${CLAUDE_SESSION_ID:-unknown}" | jq -Rs .)" \
  "$(printf '%s' "$tool" | jq -Rs .)" \
  "$type" \
  "$(pwd | jq -Rs .)" \
  "$(printf '%s' "$subject" | jq -Rs .)" \
  "$guardrail" \
  >> "$log_dir/attempts.jsonl" 2>/dev/null || true

exit 0
