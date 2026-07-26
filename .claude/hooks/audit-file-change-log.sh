#!/usr/bin/env bash
# PostToolUse | matcher: Edit|Write|NotebookEdit
# Appends every file modification to logs/audit/file-changes.jsonl.
#
# Records the path and a size delta, never the content — the log must not become a
# second copy of anything sensitive that was legitimately edited.
#
# Flags changes to guardrail files (.claude/**, CLAUDE.md, .githooks/**) with
# "guardrail":true. This is the record that makes the accepted trade-off in CLAUDE.md
# auditable: those paths are `ask`, not `deny`, so an approved edit CAN reach the hooks
# that do the enforcing. This line in the log is how you see that after the fact.
#
# ALWAYS exits 0 — an audit failure must never block work.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
PAYLOAD="${INPUT:-${CLAUDE_TOOL_INPUT:-}}"

file_path=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)
[[ -z "$file_path" ]] && exit 0

tool=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo unknown)

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
LIB="$HOOK_DIR/lib/audit-id.sh"
# Fail OPEN: no audit is better than a broken tool call.
[[ -r "$LIB" ]] || exit 0
# shellcheck source=lib/audit-id.sh
source "$LIB" 2>/dev/null || exit 0

log_dir=$(audit_dir)
[[ -z "$log_dir" ]] && exit 0

# Same id as audit-attempt-log.sh so the two files join; an id in attempts.jsonl with no
# counterpart here was blocked before it ran.
id=$(audit_id "$(audit_canon "$PAYLOAD")")

# Guard the redirect itself: `< missing-file` fails in the shell before wc runs, and
# would print to stderr on every call for a path outside this checkout.
size=0
if [[ -f "$file_path" ]]; then
  size=$(wc -c < "$file_path" 2>/dev/null | tr -d ' ' || echo 0)
fi

guardrail=false
case "$file_path" in
  */.claude/*|.claude/*|*/CLAUDE.md|CLAUDE.md|*/.githooks/*|.githooks/*) guardrail=true ;;
esac
# Worktree source files are not guardrail files even though they sit under .claude/.
case "$file_path" in
  */.claude/worktrees/*|.claude/worktrees/*) guardrail=false ;;
esac
# ...unless they are the guidance files inside that worktree.
case "$file_path" in
  */.claude/worktrees/*/CLAUDE.md|*/.claude/worktrees/*/.claude/*) guardrail=true ;;
esac

printf '{"timestamp":%s,"id":"%s","phase":"executed","agent":%s,"session":%s,"tool":%s,"path":%s,"bytes":%s,"guardrail":%s}\n' \
  "$(date -u +"%Y-%m-%dT%H:%M:%SZ" | jq -Rs .)" \
  "$id" \
  "$(printf '%s' "${CLAUDE_AGENT:-interactive}" | jq -Rs .)" \
  "$(printf '%s' "${CLAUDE_SESSION_ID:-unknown}" | jq -Rs .)" \
  "$(printf '%s' "$tool" | jq -Rs .)" \
  "$(printf '%s' "$file_path" | jq -Rs .)" \
  "${size:-0}" \
  "$guardrail" \
  >> "$log_dir/file-changes.jsonl" 2>/dev/null || true

exit 0
