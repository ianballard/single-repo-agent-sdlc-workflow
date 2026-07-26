#!/usr/bin/env bash
# Shared git command normalisation, sourced by block-destructive-git.sh and
# block-git-remote-tamper.sh. Callers MUST fail closed if this file is missing.
#
# WHY THIS EXISTS — a bypass found by live testing on 2026-07-26:
#
#     git reset --hard          -> blocked
#     git -C /path reset --hard -> NOT blocked, and it ran
#
# Every pattern anchored `reset` directly after `git`, but git accepts global options
# BEFORE the subcommand. `-C <path>`, `-c <k=v>`, `--git-dir=`, `--work-tree=`,
# `--no-pager` and friends all sit in that gap. The `Bash(git reset --hard*)`
# permission rule misses it identically, since that is a literal prefix match — which
# is precisely why the hook has to be the real defence.
#
# normalize_git collapses those global options so the subcommand lands adjacent to
# `git`, letting a single pattern per subcommand cover every spelling.

# normalize_git <command> -> prints the command with git global options removed
normalize_git() {
  local c="$1" prev=""
  # Loop: several global options can be chained (git -C p -c k=v --no-pager reset).
  # Bounded by the fact that each pass strictly shortens the string or stops.
  local guard=0
  while [[ "$c" != "$prev" && $guard -lt 12 ]]; do
    prev="$c"
    guard=$((guard + 1))
    c=$(printf '%s' "$c" | sed -E '
      s/(^|[[:space:];&|(])git[[:space:]]+(-C[[:space:]]*[^[:space:]]+|-c[[:space:]]*[^[:space:]]+|--git-dir[=[:space:]][^[:space:]]+|--work-tree[=[:space:]][^[:space:]]+|--namespace[=[:space:]][^[:space:]]+|--exec-path[=][^[:space:]]*|--config-env[=[:space:]][^[:space:]]+|-P|--no-pager|--paginate|--bare|--no-replace-objects|--literal-pathspecs|--icase-pathspecs|--noglob-pathspecs|--glob-pathspecs)[[:space:]]+/\1git /g
    ')
  done
  printf '%s' "$c"
}

# Self-test:  bash lib/git-normalize.sh --self-test
#
# The BASH_SOURCE guard is load-bearing, not boilerplate. A sourced script inherits the
# caller's positional parameters, so without it `bash block-destructive-git.sh --self-test`
# ran THIS block and exited before the caller's own tests executed — two suites silently
# tested nothing while reporting PASS.
if [[ "${BASH_SOURCE[0]}" == "${0}" && "${1:-}" == "--self-test" ]]; then
  fail=0
  eq() {
    local got want="$2"
    got=$(normalize_git "$1")
    if [[ "$got" == "$want" ]]; then echo "  ok   $1"; else echo "  FAIL  $1"; echo "         got: $got"; echo "        want: $want"; fail=1; fi
  }
  echo "== git-normalize"
  eq 'git reset --hard'                          'git reset --hard'
  eq 'git -C /p reset --hard'                     'git reset --hard'
  eq 'git -C/p reset --hard'                     'git reset --hard'
  eq 'git -c user.name=x reset --hard'           'git reset --hard'
  eq 'git -C /p -c a=b reset --hard'             'git reset --hard'
  eq 'git --git-dir=/p/.git clean -fd'           'git clean -fd'
  eq 'git --git-dir /p/.git clean -fd'           'git clean -fd'
  eq 'git --work-tree=/p checkout -- .'          'git checkout -- .'
  eq 'git --no-pager restore .'                  'git restore .'
  eq 'git -P -C /p branch -D x'                  'git branch -D x'
  eq 'git -C /p remote set-url origin u'         'git remote set-url origin u'
  eq 'cd /t && git -C /p reset --hard'           'cd /t && git reset --hard'
  eq 'git status'                                'git status'
  eq 'git log --oneline'                         'git log --oneline'
  eq 'npm run build'                             'npm run build'
  if [[ $fail -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi
  exit $fail
fi
