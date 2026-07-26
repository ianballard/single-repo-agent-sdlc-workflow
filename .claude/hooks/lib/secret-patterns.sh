#!/usr/bin/env bash
# Shared secret-material detection, sourced by block-secret-in-write.sh and
# block-secret-in-command.sh so the two cannot drift apart.
#
# Callers MUST fail closed if this file is missing — a hook that silently exits 0
# because a `source` failed is security theatre. See either caller for the pattern.
#
# Detects secret VALUES, not secret NAMES. The reference implementation this was
# ported from blocked any command containing the literal string
# "AWS_SECRET_ACCESS_KEY" or "PRIVATE_KEY", which false-positives on
# `grep -r AWS_SECRET_ACCESS_KEY` and on writing documentation about secrets.
# Here a bare name is fine; a name bound to a literal value is not.

# has_secret_material <text>  ->  prints a human-readable reason and returns 0
#                                 when the text contains secret material.
has_secret_material() {
  local text="$1"

  # --- provider key IDs / tokens (high confidence, no false positives) ---
  if printf '%s' "$text" | grep -qE '\b(AKIA|ASIA)[0-9A-Z]{16}\b'; then
    echo "an AWS access key ID"; return 0
  fi
  if printf '%s' "$text" | grep -qE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'; then
    echo "a PEM private key block"; return 0
  fi
  if printf '%s' "$text" | grep -qE '\bsk-[A-Za-z0-9_-]{20,}'; then
    echo "an API secret key (sk-...)"; return 0
  fi
  if printf '%s' "$text" | grep -qE '\bgh[pousr]_[A-Za-z0-9]{36,}'; then
    echo "a GitHub personal access token"; return 0
  fi
  if printf '%s' "$text" | grep -qE '\bgithub_pat_[A-Za-z0-9_]{22,}'; then
    echo "a GitHub fine-grained PAT"; return 0
  fi
  if printf '%s' "$text" | grep -qE '\bxox[baprs]-[A-Za-z0-9-]{10,}'; then
    echo "a Slack token"; return 0
  fi
  if printf '%s' "$text" | grep -qE '\bAIza[0-9A-Za-z_-]{35}\b'; then
    echo "a Google API key"; return 0
  fi

  # --- secret-shaped assignment: NAME=<literal HIGH-ENTROPY value> ---
  #
  # TIGHTENED after live testing showed 5/5 false positives on ordinary code:
  #   const SECRET_KEY_HEADER = "x-secret-key"
  #   API_TOKEN_HEADER = "authorization-token"
  #   SECRET_NAME = "jira-connection-secret"
  #   export const API_KEY_QUERY_PARAM = "apiKeyOverride"
  #   ACCESS_KEY_PATTERN = re.compile(r"AKIA[0-9A-Z]{16}")
  #
  # A secret-ish NAME is far too weak a signal on its own — header names, config keys,
  # and regex constants all match it. The value now has to actually look like a
  # credential: >=20 chars and at least 3 of {lower, upper, digit, symbol}. That
  # excludes kebab-case and camelCase identifiers, which is what those five were.
  #
  # DELIBERATE GAP: a low-entropy human password (DB_PASSWORD=hunter2hunter2) is no
  # longer caught here. That is the right trade — this heuristic cannot distinguish it
  # from a normal string, and gitleaks at the pre-commit boundary does the entropy-plus-
  # context analysis properly. Real provider credentials are caught above by exact
  # pattern, which is where the actual protection lives.
  local assign
  assign=$(printf '%s' "$text" \
    | grep -oE '\b[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|APIKEY|PRIVATE_KEY|ACCESS_KEY)[A-Z0-9_]*[[:space:]]*=[[:space:]]*"?'"'"'?[^[:space:]"'"'"']{20,}' \
    | head -1 || true)
  if [[ -n "$assign" ]]; then
    local value="${assign#*=}"
    value="${value#[[:space:]]}"
    value="${value#[\"\']}"

    local skip=0
    case "$value" in
      # variable reference, substitution, or templating — not a literal
      '$'*|'`'*|'<'*|'{{'*|*'${'*) skip=1 ;;
      # code rather than a value (function call, regex, interpolation)
      *'('*|*')'*|*'{'*|*'}'*) skip=1 ;;
      # placeholder vocabulary
      *xxx*|*XXX*|*changeme*|*CHANGEME*|*your[-_]*|*YOUR[-_]*|*replace*|*REPLACE*) skip=1 ;;
      *example*|*EXAMPLE*|*placeholder*|*PLACEHOLDER*|*dummy*|*fake*|*sample*) skip=1 ;;
      *test*|*TEST*|*redacted*|*REDACTED*|*'...'*) skip=1 ;;
    esac

    if [[ $skip -eq 0 ]]; then
      # Entropy gate: need 3+ character classes to look like a generated credential.
      local classes=0
      [[ "$value" =~ [a-z] ]] && classes=$((classes + 1))
      [[ "$value" =~ [A-Z] ]] && classes=$((classes + 1))
      [[ "$value" =~ [0-9] ]] && classes=$((classes + 1))
      [[ "$value" =~ [^a-zA-Z0-9] ]] && classes=$((classes + 1))
      if [[ $classes -ge 3 ]]; then
        echo "a high-entropy secret-shaped assignment (${assign%%=*}=...)"; return 0
      fi
    fi
  fi

  return 1
}
