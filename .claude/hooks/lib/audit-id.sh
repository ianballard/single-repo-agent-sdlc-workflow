#!/usr/bin/env bash
# Shared correlation id for the audit trail, sourced by the three audit hooks.
#
# WHY: PreToolUse records what was ATTEMPTED, PostToolUse records what EXECUTED. A tool
# call blocked by a hook or a permission rule appears only in the first. Emitting the same
# id from both makes "what was denied" a join rather than a guess:
#
#   comm -23 <(jq -r .id attempts.jsonl|sort -u) <(jq -r .id commands.jsonl|sort -u)
#
# Unlike the blocking hooks, audit code fails OPEN: a logging failure must never block
# work, so every path here returns successfully.
#
# LIMITATION: the id is a hash of (tool_name, tool_input), so the same command issued
# twice shares one id. Correlation is therefore set-based, not one-to-one for repeats.

# audit_id <canonical-payload> -> 12-char hex, or "unknown" if no hasher is available
audit_id() {
  local h=""
  h=$(printf '%s' "${1:-}" | shasum -a 256 2>/dev/null) \
    || h=$(printf '%s' "${1:-}" | sha256sum 2>/dev/null) \
    || { printf 'unknown'; return 0; }
  h="${h%% *}"
  printf '%.12s' "$h"
}

# audit_canon <raw-hook-json> -> stable canonical form both events can hash identically.
# Key order is sorted so PreToolUse and PostToolUse cannot disagree on serialisation.
audit_canon() {
  printf '%s' "${1:-}" | jq -cS '{t:(.tool_name // ""), i:(.tool_input // {})}' 2>/dev/null \
    || printf '{}'
}

# audit_classify <command-string> -> coarse type tag, shared so the two Bash-side logs
# label the same command identically.
audit_classify() {
  local c="${1:-}"
  if printf '%s' "$c" | grep -qE '\b(curl|wget|nc|ncat|netcat|socat|scp|sftp|rsync|ssh)\b'; then
    printf 'network_egress'
  elif printf '%s' "$c" | grep -qE '\b(pip3?[[:space:]]+install|uv[[:space:]]+pip[[:space:]]+install|poetry[[:space:]]+add|npm[[:space:]]+(install|i|add)|pnpm[[:space:]]+(install|add)|yarn[[:space:]]+add|npx|brew[[:space:]]+install|cargo[[:space:]]+add|go[[:space:]]+get)\b'; then
    printf 'dependency_install'
  elif printf '%s' "$c" | grep -qE '\bgit[[:space:]]+push\b'; then
    printf 'git_push'
  else
    printf 'command'
  fi
}

# audit_dir -> the log directory, created if needed. Empty output means "give up",
# which callers treat as "skip logging" rather than an error (audit fails open).
audit_dir() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="${CLAUDE_PROJECT_DIR:-.}"
  local d="$root/logs/audit"
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s' "$d"
}
