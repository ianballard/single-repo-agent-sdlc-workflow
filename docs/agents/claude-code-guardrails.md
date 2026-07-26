# Claude Code Guardrails — mechanics reference

Policy lives in `CLAUDE.md`. This file is the mechanical half: how the enforcement is
actually built, the non-obvious rules that govern it, and how to verify it still works.

Everything described here is **installed and live**. This is a reference, not a
setup guide.

Inventory. Every blocking hook ships a `--self-test`; the two audit hooks always exit 0
so a logging failure can never block work.

| File | Event / matcher | Purpose |
| ---- | --------------- | ------- |
| `.claude/settings.json` | — | permission rules + hook registration |
| `hooks/block-secret-file-access.sh` | Pre: file tools + Bash | `.env*` and credential files, with the template carve-out |
| `hooks/block-secret-in-write.sh` | Pre: Edit/Write | secret material in file content |
| `hooks/block-secret-in-command.sh` | Pre: Bash | secret material in a command string |
| `hooks/block-destructive-git.sh` | Pre: Bash | work destruction (`reset --hard`, `clean`, `restore`, …) |
| `hooks/block-git-remote-tamper.sh` | Pre: Bash | remote/config/submodule tampering, mass push |
| `hooks/block-gh-dangerous.sh` | Pre: Bash | `gh pr merge`, credential printing, `gh api` mutations |
| `hooks/block-exfiltration.sh` | Pre: Bash | outbound data transfer |
| `hooks/audit-attempt-log.sh` | **Pre: both groups, registered first** | every *attempted* call → `attempts.jsonl`, including ones later denied |
| `hooks/audit-command-log.sh` | Post: Bash | every *executed* command → `commands.jsonl` |
| `hooks/audit-file-change-log.sh` | Post: Edit/Write | every file change → `file-changes.jsonl`, flagging guardrail files |
| `hooks/lib/secret-patterns.sh` | sourced | shared secret-value detection |
| `hooks/lib/git-normalize.sh` | sourced | strips git global options before matching |
| `hooks/lib/audit-id.sh` | sourced | correlation id + shared classification for the three audit logs |
| `.githooks/pre-push` | git | resolved-refspec trunk protection |
| `.githooks/pre-commit` | git | staged secret files and content |
| `.githooks/commit-msg` | git | conventional-commit validation |

---

## 1. Four facts about permission rules

Verified against the Claude Code permissions documentation and by live testing. Getting
these wrong produces rules that look right and enforce nothing.

**`Write(...)` rules do not work.** Only `Edit(path)` rules are matched by file
permission checks; `Edit` covers Write, Edit, and NotebookEdit. A `Write(...)` rule is
inert and emits a startup warning:

```
Permission deny rule (.claude/settings.json): Write(docs/**) is not matched by file
permission checks — only Edit(path) rules are. Use Edit(docs/**) instead
(Edit rules cover all file-editing tools).
```

**Precedence is `deny` → `ask` → `allow`, first match wins.** Specificity is
irrelevant. A deny rule cannot carry allowlist exceptions, and an `ask` rule prompts
even when a more specific `allow` rule also matches.

**There is no negation operator.** Patterns are gitignore-style with four shapes
(`//abs`, `~/home`, `/settings-relative`, `relative`) and no `!` form. This is the single
most important constraint here, and the reason several rules live in hooks instead —
see §3.

**`ask` rules only prompt in a permission mode that prompts.** Under `auto` mode a
classifier resolves them instead of asking a human; under `bypassPermissions` they are
skipped entirely. `deny` rules and hooks still fire in every mode. So an `ask` rule is a
*request* for a human gate, not a guarantee of one — see §6.

Two depth rules worth knowing:

- A **bare filename** matches at any depth: `Edit(CLAUDE.md)` catches the root copy and
  the copy inside every worktree. `Read(.env)` and `Read(**/.env)` are equivalent.
- A **multi-segment** pattern matches only at its anchor, so reaching worktree copies
  needs an explicit prefix: `Edit(**/.claude/skills/**)`, not `Edit(.claude/skills/**)`.

One hook fact: a PreToolUse hook exiting with code 2 stops the call *before* permission
rules are evaluated, so a hook still fires on commands an `allow` rule would otherwise
wave through. That is what keeps the git hooks effective despite `Bash(git checkout:*)`
sitting in the allow list.

---

## 2. What is in `settings.json`

**`ask`** — guidance files, so a human sees every change to the agent's own
configuration. `.claude/worktrees/**` is deliberately absent: all task work happens
inside a worktree, and as an `ask` rule a single-segment pattern like `.claude/**`
matches at *any* depth, so a blanket rule would prompt on every implementation edit.

```
Edit(CLAUDE.md)
Edit(**/.claude/settings.json)         Edit(**/.claude/settings.local.json)
Edit(**/.claude/skills/**)             Edit(**/.claude/hooks/**)
Edit(**/.claude/agents/**)             Edit(**/.claude/commands/**)
Bash(git worktree remove*)             Bash(git commit --amend*)
Bash(aws:*)
```

**`deny`** — secrets, plus the git/gh operations with no legitimate variant. Notable:

```
Read(.env)  Edit(.env)  Read(**/*.pem)  Read(~/.ssh/**)  Read(~/.aws/credentials)
Bash(git reset --hard*)  Bash(git checkout -- *)  Bash(git branch -D*)
Bash(git stash drop*)  Bash(git reflog expire*)  Bash(git filter-branch*)
Bash(git remote add*)  Bash(git remote set-url*)  Bash(git config core.hooksPath*)
Bash(git config credential.helper*)  Bash(git config alias.*)  Bash(git config --global*)
Bash(git push --delete*|--mirror*|--all*|origin :*)  Bash(git commit --no-verify*)
Bash(gh pr merge*)  Bash(gh auth token*)  Bash(gh repo delete*)  Bash(gh secret set*)
```

`.env.*` is deliberately **not** a deny rule — it would swallow `.env.example` with no
way to re-allow it. The hook owns the whole family, with the template carve-out.

---

## 3. Why some rules live in hooks instead

A permission rule has no negation and `deny` beats everything, so
`Bash(git clean*)` cannot carve out `git clean -n`. Six rules were originally written in
`settings.json` and blocked ordinary development. Each moved to its hook, which is
regex-capable and can express the exception:

| Operation | Denied | Permitted, and why |
| --------- | ------ | ------------------ |
| `git clean` | `-f`, `-fd`, `-fdx` | `-n` / `--dry-run` — deletes nothing |
| `git restore` | `<path>`, `--staged --worktree` | `--staged` alone — unstages only, working tree keeps changes |
| `git branch` | `-D`, `--delete --force` | `-d` — git already refuses an unmerged branch |
| `git gc` | `--prune` | plain `gc`, `--aggressive` — default 2-week horizon keeps today's work |
| `git stash` | `drop`, `clear` | `list`, `show` — read-only. Bare `stash` asks. |
| `gh config get` | credential keys | `git_protocol`, `editor` |
| `curl`/`wget` body | archive-pipe, `printenv \|`, `nc`, `scp` | remote POST **asks** — staging/API testing is real work |

**The principle: `settings.json` holds only rules with no legitimate variant. Anything
needing an exception belongs in a hook.**

---

## 4. Non-obvious things the hooks handle

**`git` global options are a bypass.** `git reset --hard` was blocked while
`git -C /path reset --hard` ran and destroyed work — every pattern anchored the
subcommand directly after `git`. `-C`, `-c k=v`, `--git-dir=`, `--work-tree=`,
`--no-pager` all sit in that gap, and the `Bash(git reset --hard*)` permission rule
misses it identically because it is a literal prefix match. `lib/git-normalize.sh`
collapses those options first; both git hooks source it and fail closed without it.

**Quoted spans must be the whole path.** The Bash arm of `block-secret-file-access.sh`
originally stripped all quotes, which conflated "this quoted span *is* `.env`" with
"this string *contains* `.env`". It blocked an `echo`, a `grep` pattern, and two commands
that were verifying this config. A quoted span now only counts if it is entirely a secret
path; the unquoted remainder is tokenised normally. `,` is not a separator, so a jq
filter like `'.enabledPlugins,.env'` is not mistaken for a file.

**Existence gating.** A `.env`-shaped token only blocks if it resolves to something on
disk, or is absolute/home-relative. A jq expression refers to nothing; a non-existent
path has nothing to leak.

**Content-free path queries are exempt.** `ls`, `stat`, `test`, `file`, `realpath`,
`readlink`, `dirname`, `basename`, and `git check-ignore|check-attr|ls-files|status` ask
*about* a path without reading it. The allowlist is deliberately narrow — every entry is
incapable of printing file contents. Adding `cat`, `head`, `wc`, `grep`, `awk`, or `sed`
would open a hole; those still block on the same path.

**Secret detection is value-based, not name-based.** A secret-ish *name* is far too weak
a signal: `SECRET_KEY_HEADER = "x-secret-key"` and `ACCESS_KEY_PATTERN = re.compile(...)`
are ordinary code. The generic assignment check now requires ≥20 chars and 3+ character
classes. Deliberate gap: a low-entropy human password is no longer caught here — gitleaks
at the pre-commit boundary does that analysis properly. Real provider credentials
(`AKIA`, `sk-`, `ghp_`, `xox`, `AIza`, PEM) are caught by exact pattern.

**`block-secret-in-write.sh` skips `.claude/hooks/`.** The pattern library contains these
regexes as literals, so it would otherwise block editing itself. Those paths carry an
`ask` rule instead.

**Sourcing a library inherits `$1`.** `lib/git-normalize.sh` guards its self-test with
`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`. Without it, `bash block-destructive-git.sh
--self-test` ran the *library's* tests and exited — two suites reported PASS while
testing nothing. If you add a library with a self-test, copy that guard.

---

## 5. The git-level layer

`.githooks/` catches what Claude-side rules structurally cannot, because it runs inside
git and sees resolved state rather than a command string.

- **`pre-push`** — rejects pushes whose resolved refspec targets `main`/`master`/
  `develop`/`staging`/`production`, plus remote branch deletion. This is the only thing
  that catches `git push origin HEAD:develop`: `Bash(git push origin develop*)` is a
  string match and that command does not contain `origin develop`. **Never rely on the
  permission rule alone.**
- **`pre-commit`** — refuses staged secret files (reusing the hook's own `is_secret_path`
  so the layers cannot disagree) and scans staged content. Uses `gitleaks` when
  installed, else a self-contained fallback. Matters most because this workflow commits
  once at closeout with `git add -A` — exactly when an untracked `.env` gets swept in.
- **`commit-msg`** — conventional-commit validation; merge/revert/fixup subjects exempt.

Active via `core.hooksPath` (set, verified). `.git/hooks/` is not versioned and does not
survive a fresh clone, which is why the hooks are committed here. `--no-verify` is denied
so the layer cannot be skipped, and `git config core.hooksPath*` is denied so it cannot
be unset.

---

## 6. Known gaps

Stated plainly, because a guardrail you believe in but that does not fire is worse than
none.

1. **`ask` rules only prompt in a mode that prompts.** Under `auto` a classifier resolves
   them; under `bypassPermissions` they are skipped. `deny` rules and hooks fire in every
   mode, so this affects only the `ask` list in §2 — including the
   "human reviews changes to `.claude/`" design, which is advisory rather than gated
   whenever the session is in one of those modes.

   **Current state: accepted as-is.** `~/.claude/settings.json` carries
   `"defaultMode": "auto"`, so sessions start in auto mode by default and the `ask` gate
   is advisory unless a session is switched manually. The audit trail still records every
   guidance-file change with `"guardrail": true` (§8), so the review happens after the
   fact rather than before it.

   **To enforce the gate later, pick one:**

   ```jsonc
   // A. scope the guarantee to this repo — .claude/settings.json, inside "permissions"
   "disableAutoMode": "disable",
   "disableBypassPermissionsMode": "disable",
   ```

   ```jsonc
   // B. change the default everywhere — ~/.claude/settings.json, inside "permissions"
   "defaultMode": "default",     // was "auto"
   ```

   ```jsonc
   // C. hard-stop the subset that should never change silently:
   //    move it from "ask" to "deny". Survives every mode, but note that a deny rule
   //    cannot be approved in-session — an agent then cannot edit these at all.
   "deny": ["Edit(**/.claude/hooks/**)"]
   ```

   A is the narrowest and the one to reach for first: it keeps auto mode available
   everywhere else while making the gate real in the repo whose purpose is a reviewable
   agent workflow. Switching a single session is also enough for one-off work — verify it
   took by attempting an edit under `.claude/hooks/` and confirming a prompt appears.
   Whichever you choose, update this section so the doc and the config keep agreeing.
2. **Arbitrary subprocesses bypass the file guards.** Read/Edit rules cover `cat`, `head`,
   `tail`, `sed`, but not `python -c` or `node -e`. Only OS-level sandboxing closes this.
4. **`block-exfiltration.sh` is a speed bump, not a wall.** An HTTP call from inside an
   interpreter gets through. Its job is making casual egress loud and logged.
5. **String matching cannot distinguish discussing a command from running one.** A grep
   pattern containing `tar`, `|`, and `curl` reads as a pipeline. Inherent to the
   approach; mitigated by the quoted-span and existence rules, not eliminated.
5. **Guardrails do not reach worktrees outside the project.** Relative patterns anchor to
   the project directory, so worktrees elsewhere on disk (e.g. `~/.atlas-*/worktrees/`)
   are uncovered. **Accepted** — those are other tools' scratch checkouts, not this
   workflow's. `//` absolute patterns would extend coverage if that ever changes.

---

## 7. Verification

An unverified hook is security theatre — and this repo has already shipped one instance
of exactly that (§4, sourcing/`$1`). Re-run after any change:

```sh
for h in .claude/hooks/block-*.sh .claude/hooks/lib/git-normalize.sh; do
  printf '%-34s ' "$(basename "$h")"; bash "$h" --self-test >/dev/null 2>&1 \
    && echo PASS || { echo FAIL; bash "$h" --self-test | grep FAIL; }
done
```

203 assertions across 8 files at time of writing. **Check the assertion count, not just
the exit code** — that is how the silently-skipped suites were caught:

```sh
bash .claude/hooks/block-destructive-git.sh --self-test | grep -c '  ok '   # expect 55
```

End-to-end spot checks, in a session:

| Attempt | Expected |
| ------- | -------- |
| read `.env` / `backend/.env.production` | blocked |
| read `.env.example` | **allowed** — the carve-out that matters |
| `cat .env` | blocked; `git check-ignore .env` allowed |
| `git clean -fd` / `git clean -n` | denied / allowed |
| `git restore --staged .` / `... --staged --worktree .` | allowed / denied |
| `git -C /path reset --hard` | denied — the bypass regression |
| `git remote set-url origin <url>` | denied |
| `gh auth token` / `gh config get git_protocol` | denied / allowed |
| edit a file under `.claude/worktrees/…` | no prompt — regression check for §2 |

Git layer, without committing anything:

```sh
printf 'wip nonsense\n' > /tmp/m && git hook run commit-msg -- /tmp/m   # blocks
printf 'refs/heads/f abc refs/heads/develop def\n' | bash .githooks/pre-push  # blocks
```

Audit log is filling:

```sh
tail -3 logs/audit/commands.jsonl
jq -r 'select(.guardrail==true)|.path' logs/audit/file-changes.jsonl | sort -u
```

---

## 8. Reading the audit trail

Three append-only JSONL files under `logs/audit/` (gitignored — local forensic evidence,
not a committed artifact). Records accumulate across sessions; filter on `.session`.

| File | Written by | Contains |
| ---- | ---------- | -------- |
| `attempts.jsonl` | `audit-attempt-log.sh` (PreToolUse) | every call **attempted**, before any hook or rule could block it |
| `commands.jsonl` | `audit-command-log.sh` (PostToolUse) | every Bash command that **executed** |
| `file-changes.jsonl` | `audit-file-change-log.sh` (PostToolUse) | every file change that **executed** |

The split is structural: PostToolUse only fires on calls that run, so a blocked command can
only be recorded before the fact. All three emit a shared `id` — a hash of
`(tool_name, tool_input)` from `lib/audit-id.sh` — which makes "what was denied" a join
rather than a guess.

**What was blocked:**

```sh
comm -23 <(jq -r .id logs/audit/attempts.jsonl | sort -u) \
         <(cat logs/audit/commands.jsonl logs/audit/file-changes.jsonl \
             | jq -r .id | sort -u) \
  | while read -r id; do
      jq -r --arg i "$id" 'select(.id==$i) | "\(.timestamp)  \(.type)\t\(.subject)"' \
        logs/audit/attempts.jsonl | head -1
    done
```

Two honest caveats on that query:

- **In-flight calls look denied.** The command running the query is itself logged as an
  attempt, and its PostToolUse has not fired yet, so it appears in the output. So will any
  other call still executing. Ignore the most recent entries, or filter by timestamp.
- **Repeated identical calls share one id.** The id is content-derived, so correlation is
  set-based: if a command was denied once and later allowed, the id appears in both files
  and the denial is not distinguishable by this query alone.

**Other useful cuts:**

```sh
# every change to a guardrail file, attempted or applied — the accepted-trade-off record
jq -r 'select(.guardrail==true)|"\(.phase)\t\(.timestamp)\t\(.subject // .path)"' \
  logs/audit/attempts.jsonl logs/audit/file-changes.jsonl

# network egress and dependency installs
jq -r 'select(.type=="network_egress" or .type=="dependency_install")|.command' \
  logs/audit/commands.jsonl

# scope one session
jq -r --arg s "$CLAUDE_SESSION_ID" 'select(.session==$s)|.subject' logs/audit/attempts.jsonl
```

The audit hooks deliberately **fail open** — a logging failure exits 0 rather than blocking
work, the opposite of the blocking hooks' fail-closed sourcing. A missing
`lib/audit-id.sh` silently disables logging rather than halting the session, so the
verification in §7 is what confirms the trail is live.
