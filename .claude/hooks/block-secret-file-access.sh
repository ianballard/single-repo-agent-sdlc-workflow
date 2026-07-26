#!/usr/bin/env bash
# PreToolUse | matchers: Read|Edit|Write|NotebookEdit|Grep|Glob  AND  Bash
#
# Blocks access to secret-bearing files, including every .env* variant EXCEPT
# templates (.env.example, .env.sample, .env.template, .env.dist).
#
# This is a hook rather than a permission rule because gitignore-style permission
# patterns have no negation operator, so "deny .env* but allow .env.example" is not
# expressible as a Read()/Edit() rule — a deny rule always beats an allow rule and
# cannot carry exceptions.
#
# Two surfaces:
#   1. File tools — matches tool_input.file_path / .path / .notebook_path
#   2. Bash       — scans path-looking tokens in tool_input.command. Read/Edit deny
#      rules already cover cat/head/tail/sed; this arm catches source, cp, tar,
#      base64, awk, xxd, python -c, docker, and friends.
#
# Self-test:  bash .claude/hooks/block-secret-file-access.sh --self-test

set -uo pipefail

# ---------------------------------------------------------------------------
# Patterns
# ---------------------------------------------------------------------------

# Explicitly SAFE even though the name looks secret-ish. Checked first.
is_exempt() {
  local base="${1##*/}"
  case "$base" in
    *.example|*.example.*|*.sample|*.sample.*|*.template|*.template.*|*.dist|*.schema) return 0 ;;
    *.pub) return 0 ;;               # public keys are not secret
    settings.local.json) return 0 ;; # permissions file; guarded by ask rules instead
  esac
  return 1
}

is_secret_path() {
  local p="$1" base="${1##*/}"

  is_exempt "$p" && return 1

  case "$base" in
    # dotenv, any depth, any suffix: .env  .env.local  .env.production
    .env|.env.*) return 0 ;;
    # trailing-form env files: production.env
    *.env) return 0 ;;
    # key / certificate material
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.asc|*.ppk) return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519) return 0 ;;
    # credential files by name
    .netrc|.npmrc|.pypirc|.credentials.json|credentials.json|kubeconfig) return 0 ;;
    *.tfvars) return 0 ;;
  esac

  case "$p" in
    */.aws/credentials|*/.aws/config) return 0 ;;
    */.ssh/*)                         return 0 ;;
    */.gnupg/*)                       return 0 ;;
    */.docker/config.json)            return 0 ;;
    */.config/gh/hosts.yml)           return 0 ;;
    */.kube/config)                   return 0 ;;
    # project-local secret sidecars, e.g. .claude/jira-connection.local.json
    */.claude/*.local.json)           return 0 ;;
    .claude/*.local.json)             return 0 ;;
  esac

  return 1
}

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | jq -Rs .)"
  exit 0
}

# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--self-test" ]]; then
  fail=0
  blk() { if is_secret_path "$1"; then echo "  ok   BLOCK  $1"; else echo "  FAIL allowed $1"; fail=1; fi; }
  alw() { if is_secret_path "$1"; then echo "  FAIL blocked $1"; fail=1; else echo "  ok   allow  $1"; fi; }
  echo "== block-secret-file-access"
  blk ".env"
  blk "backend/.env"
  blk "frontend/a/b/c/.env.production"
  blk ".env.local"
  blk "production.env"
  blk "certs/server.pem"
  blk "$HOME/.ssh/id_ed25519"
  blk "$HOME/.aws/credentials"
  blk ".claude/jira-connection.local.json"
  blk "infra/terraform.tfvars"
  alw ".env.example"
  alw "backend/.env.sample"
  alw "e2e/.env.template"
  alw "infra/terraform.tfvars.example"
  alw "$HOME/.ssh/id_ed25519.pub"
  alw ".claude/settings.local.json"
  alw "frontend/src/environment.ts"
  alw "docs/adr/0001-env-handling.md"
  alw "backend/app/main.py"

  # --- Bash-arm tokenizer, exercised through the real hook body ---
  # Regression: a jq filter like '.enabledPlugins,.env' must not read as a file.
  self="${BASH_SOURCE[0]}"
  tmp=$(mktemp -d)
  printf 'X=1\n' > "$tmp/.env"
  printf 'X=tpl\n' > "$tmp/.env.example"
  cmd_case() { # cmd_case <want: deny|allow> <command>
    local want="$1" cmd="$2" out got
    out=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | jq -Rs .)" | bash "$self" 2>&1)
    if [[ -z "$out" ]]; then got="allow"; else got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null || echo "err"); fi
    if [[ "$got" == "$want" ]]; then echo "  ok   $got  $cmd"; else echo "  FAIL want=$want got=$got  $cmd"; fail=1; fi
  }
  cmd_case deny  "cat $tmp/.env"
  cmd_case deny  "source $tmp/.env"
  cmd_case deny  "cp $tmp/.env /tmp/x"
  cmd_case allow "cat $tmp/.env.example"
  cmd_case allow "jq -S '.enabledPlugins,.env' settings.json"
  cmd_case allow "jq '.permissions.deny[]' .claude/settings.json"

  # Regressions for the "mentions it inside a longer string" false positives that
  # actually occurred while building this. A real .env EXISTS in the repo root, so these
  # only pass because a quoted span must be the WHOLE path to count.
  printf 'X=1\n' > "$tmp/realenv"; mv "$tmp/realenv" "$tmp/.env" 2>/dev/null || true
  cmd_case allow 'echo "no .env in repo root"'
  cmd_case allow 'for r in "Read(.env)" "Edit(.env)"; do echo "$r"; done'
  cmd_case allow "grep -E '^\\.env' filelist.txt"
  cmd_case allow "jq -e --arg r 'Read(.env)' '.permissions.deny|index(\$r)' s.json"
  # ...while a quoted span that IS exactly the path still blocks.
  cmd_case deny  "cat '$tmp/.env'"
  cmd_case deny  "cat \"$tmp/.env\""
  cmd_case allow "printenv | grep PATH"
  cmd_case allow "pytest backend/tests"
  # Content-free path queries: ask ABOUT the path, never read it.
  cmd_case allow "git check-ignore -v $tmp/.env"
  cmd_case allow "ls -la $tmp/.env"
  cmd_case allow "test -f $tmp/.env"
  cmd_case allow "stat $tmp/.env"
  cmd_case allow "git ls-files $tmp/.env"
  # ...but anything that can print contents still blocks, even for the same path.
  cmd_case deny  "head -5 $tmp/.env"
  cmd_case deny  "wc -c $tmp/.env"
  cmd_case deny  "grep TOKEN $tmp/.env"
  cmd_case deny  "awk '{print}' $tmp/.env"
  rm -rf "$tmp"

  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi

# ---------------------------------------------------------------------------
# Hook body
# ---------------------------------------------------------------------------
INPUT=$(cat)
PAYLOAD="${INPUT:-${CLAUDE_TOOL_INPUT:-}}"

for field in file_path path notebook_path; do
  target=$(printf '%s' "$PAYLOAD" | jq -r ".tool_input.${field} // empty" 2>/dev/null)
  if [[ -n "$target" ]] && is_secret_path "$target"; then
    deny "BLOCKED: '$target' is a secret-bearing file. Reading, editing, or globbing it is prohibited. Use the matching .example/.template file, or ask the human to supply the value out of band."
  fi
done

command=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Content-free path queries are exempt. `git check-ignore .env`, `ls -a`, `test -f .env`
# and friends ask ABOUT a path without reading a byte of it, so blocking them protects
# nothing and blocked legitimate work five times while this was being built.
# Deliberately narrow: every program here is incapable of printing file contents. Adding
# anything that can read a file (cat, head, wc, grep, awk, sed, ...) would open a hole.
if [[ -n "$command" ]]; then
  if [[ "$command" =~ ^[[:space:]]*(ls|stat|test|\[|dirname|basename|file|realpath|readlink)([[:space:]]|$) ]] \
  || [[ "$command" =~ ^[[:space:]]*git[[:space:]]+(check-ignore|check-attr|ls-files|status)([[:space:]]|$) ]]; then
    command=""
  fi
fi

if [[ -n "$command" ]]; then
  # Candidate file tokens are collected from two places, deliberately:
  #
  #   1. Each QUOTED span, but only if the ENTIRE span is a secret path. `cat '.env'`
  #      quotes exactly the path; a message like "no .env in repo root" or a rule name
  #      like "Read(.env)" merely CONTAINS it. Blanket quote-stripping conflated the two
  #      and produced four false positives in one session — including blocking commands
  #      that were verifying this very config.
  #   2. The UNQUOTED remainder, tokenised on whitespace and shell redirection, which is
  #      where real file arguments almost always live (`cat .env`, `source .env`, `<.env`).
  #
  # ',' is not a token separator: a jq filter like '.enabledPlugins,.env' would otherwise
  # yield a bare ".env". Real file arguments are never comma-separated.
  while IFS=$'\t' read -r kind payload; do
    case "$kind" in
      Q)
        # Whole quoted span must itself be the path.
        cands=("$payload")
        ;;
      U)
        # shellcheck disable=SC2206
        cands=($(printf '%s' "$payload" | tr '\n' ' ' | tr '<>|;&()' ' '))
        ;;
      *) continue ;;
    esac

    for tok in "${cands[@]}"; do
      [[ -z "$tok" || "$tok" == -* ]] && continue
      is_secret_path "$tok" || continue

      # Only block when the token plausibly denotes a real file: a non-existent path has
      # nothing to leak, and an expression that merely looks like a dotenv name refers to
      # nothing on disk. Absolute and home-relative paths always count, since they may
      # resolve outside this checkout.
      probe="$tok"
      [[ "$probe" == "~"* ]] && probe="${HOME}${probe#\~}"
      if [[ -e "$probe" || "$tok" == /* || "$tok" == "~"* ]]; then
        deny "BLOCKED: command references the secret-bearing file '$tok'. Do not read, copy, source, or pipe secret files."
      fi
    done
  done < <(printf '%s' "$command" | awk '
    {
      n = split($0, ch, "")
      inq = 0; q = ""; cur = ""; unq = ""
      for (i = 1; i <= n; i++) {
        c = ch[i]
        if (inq == 0 && (c == "\"" || c == "\047")) { inq = 1; q = c; cur = ""; continue }
        if (inq == 1 && c == q)                     { inq = 0; print "Q\t" cur; cur = ""; continue }
        if (inq == 1) { cur = cur c } else { unq = unq c }
      }
      if (inq == 1 && cur != "") print "Q\t" cur   # unterminated quote: still inspect it
      print "U\t" unq
    }')
fi

exit 0
