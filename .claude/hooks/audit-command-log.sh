#!/usr/bin/env bash
# PostToolUse | matcher: Bash
# Appends every Bash command to logs/audit/commands.jsonl, tagging network egress and
# dependency installs. This is the "we can show you every command the agent ran" record
# the SOC 2 posture in CLAUDE.md implies.
#
# ALWAYS exits 0 — an audit failure must never block work. logs/ is gitignored: this is
# local forensic evidence, not a committed artifact.
#
# Note this records what was ATTEMPTED and reached execution. A command a PreToolUse hook
# denied never reaches PostToolUse, so it is not logged here; the denial surfaces in the
# transcript instead.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
PAYLOAD="${INPUT:-${CLAUDE_TOOL_INPUT:-}}"
command=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)
[[ -z "$command" ]] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
LIB="$HOOK_DIR/lib/audit-id.sh"
# Fail OPEN: no audit is better than a broken tool call.
[[ -r "$LIB" ]] || exit 0
# shellcheck source=lib/audit-id.sh
source "$LIB" 2>/dev/null || exit 0

log_dir=$(audit_dir)
[[ -z "$log_dir" ]] && exit 0

# Same id and type tags as audit-attempt-log.sh, so the two files join. An id present in
# attempts.jsonl but absent here was blocked before it ran.
id=$(audit_id "$(audit_canon "$PAYLOAD")")
type=$(audit_classify "$command")

printf '{"timestamp":%s,"id":"%s","phase":"executed","agent":%s,"session":%s,"tool":"Bash","type":"%s","cwd":%s,"command":%s}\n' \
  "$(date -u +"%Y-%m-%dT%H:%M:%SZ" | jq -Rs .)" \
  "$id" \
  "$(printf '%s' "${CLAUDE_AGENT:-interactive}" | jq -Rs .)" \
  "$(printf '%s' "${CLAUDE_SESSION_ID:-unknown}" | jq -Rs .)" \
  "$type" \
  "$(pwd | jq -Rs .)" \
  "$(printf '%s' "$command" | jq -Rs .)" \
  >> "$log_dir/commands.jsonl" 2>/dev/null || true

exit 0
