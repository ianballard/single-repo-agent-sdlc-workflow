# Claude Code Guardrails — mechanics reference

Policy: `CLAUDE.md`. This file: how it is built and how to verify it. All of it is live.

## Inventory

Blocking hooks ship a `--self-test` and fail closed. Audit hooks always exit 0.

| File | Event / matcher | Purpose |
| ---- | --------------- | ------- |
| `.claude/settings.json` | — | permission rules + hook registration |
| `hooks/block-secret-file-access.sh` | Pre: file tools + Bash | dotenv and credential files, with template carve-out |
| `hooks/block-secret-in-write.sh` | Pre: Edit/Write | secret material in file content |
| `hooks/block-secret-in-command.sh` | Pre: Bash | secret material in a command string |
| `hooks/block-destructive-git.sh` | Pre: Bash | work destruction |
| `hooks/block-git-remote-tamper.sh` | Pre: Bash | remote/config/submodule tampering, mass push |
| `hooks/block-gh-dangerous.sh` | Pre: Bash | `gh pr merge`, credential printing, `gh api` mutations |
| `hooks/block-exfiltration.sh` | Pre: Bash | outbound data transfer |
| `hooks/audit-attempt-log.sh` | Pre: both groups, **registered first** | attempted calls → `attempts.jsonl` |
| `hooks/audit-command-log.sh` | Post: Bash | executed commands → `commands.jsonl` |
| `hooks/audit-file-change-log.sh` | Post: Edit/Write | file changes → `file-changes.jsonl` |
| `hooks/lib/secret-patterns.sh` | sourced | secret-value detection |
| `hooks/lib/git-normalize.sh` | sourced | strips git global options before matching |
| `hooks/lib/audit-id.sh` | sourced | correlation id + classification for the audit logs |
| `.githooks/pre-push` | git | resolved-refspec trunk protection |
| `.githooks/pre-commit` | git | staged secret files and content |
| `.githooks/commit-msg` | git | conventional-commit validation |

---

## 1. Permission rule semantics

- **`Write(...)` rules are inert.** Only `Edit(path)` is matched by file permission checks;
  `Edit` covers Write, Edit, NotebookEdit. A `Write(...)` rule emits a startup warning.
- **Precedence: `deny` → `ask` → `allow`, first match wins.** Specificity is irrelevant.
  A deny rule cannot carry exceptions; an `ask` rule prompts even when `allow` also matches.
- **No negation operator.** Four pattern shapes (`//abs`, `~/home`, `/settings-relative`,
  `relative`), no `!`. Reason several rules live in hooks — see §3.
- **`ask` only prompts in a prompting mode.** Under `auto` a classifier resolves it; under
  `bypassPermissions` it is skipped. `deny` and hooks fire in every mode. See §6.
- **Bare filename matches at any depth.** `Edit(CLAUDE.md)` catches worktree copies;
  `Read(.env)` ≡ `Read(**/.env)`.
- **Multi-segment patterns match only at their anchor.** Use `Edit(**/.claude/skills/**)`,
  not `Edit(.claude/skills/**)`, to reach worktree copies.
- **A hook exiting 2 stops the call before permission rules are evaluated.** So hooks fire
  on commands an `allow` rule would otherwise pass, e.g. `Bash(git checkout:*)`.

---

## 2. `settings.json` contents

`ask` — agent configuration:

```
Edit(CLAUDE.md)
Edit(**/.claude/settings.json)         Edit(**/.claude/settings.local.json)
Edit(**/.claude/skills/**)             Edit(**/.claude/hooks/**)
Edit(**/.claude/agents/**)             Edit(**/.claude/commands/**)
Bash(git worktree remove*)             Bash(git commit --amend*)
Bash(aws:*)
```

`.claude/worktrees/**` is absent by design: as an `ask` rule a single-segment pattern
matches at any depth, so a blanket `.claude/**` would prompt on every task edit.

`deny` — secrets and operations with no legitimate variant:

```
Read(.env)  Edit(.env)  Read(**/*.pem)  Read(~/.ssh/**)  Read(~/.aws/credentials)
Bash(git reset --hard*)  Bash(git checkout -- *)  Bash(git branch -D*)
Bash(git stash drop*)  Bash(git reflog expire*)  Bash(git filter-branch*)
Bash(git remote add*)  Bash(git remote set-url*)  Bash(git config core.hooksPath*)
Bash(git config credential.helper*)  Bash(git config alias.*)  Bash(git config --global*)
Bash(git push --delete*|--mirror*|--all*|origin :*)  Bash(git commit --no-verify*)
Bash(gh pr merge*)  Bash(gh auth token*)  Bash(gh repo delete*)  Bash(gh secret set*)
```

`.env.*` is not a deny rule — it would swallow `.env.example` with no way to re-allow it.
The hook owns that family.

---

## 3. Rules owned by hooks, not `settings.json`

`Bash(git clean*)` cannot carve out `git clean -n`, so these live in hooks:

| Operation | Denied | Permitted |
| --------- | ------ | --------- |
| `git clean` | `-f`, `-fd`, `-fdx` | `-n` / `--dry-run` (deletes nothing) |
| `git restore` | `<path>`, `--staged --worktree` | `--staged` alone (unstages only) |
| `git branch` | `-D`, `--delete --force` | `-d` (git refuses unmerged) |
| `git gc` | `--prune` | plain `gc`, `--aggressive` (2-week default horizon) |
| `git stash` | `drop`, `clear` | `list`, `show`. Bare `stash` asks. |
| `gh config get` | credential keys | `git_protocol`, `editor` |
| `curl`/`wget` body | archive-pipe, `printenv \|`, `nc`, `scp` | remote POST **asks** |

**`settings.json` holds only rules with no legitimate variant. Exceptions belong in a hook.**

---

## 4. Non-obvious hook behaviour

- **git global options are normalised first.** `-C`, `-c k=v`, `--git-dir=`,
  `--work-tree=`, `--no-pager` sit between `git` and the subcommand, so
  `git -C /p reset --hard` matches no pattern anchored on `git reset`. Permission rules
  miss it identically (literal prefix match). `lib/git-normalize.sh` collapses them; both
  git hooks source it and fail closed without it.
- **A quoted span counts only if it is entirely a secret path.** Otherwise any string
  merely *containing* `.env` matches. The unquoted remainder is tokenised on whitespace and
  redirection. `,` is not a separator, so `'.enabledPlugins,.env'` is not read as a file.
- **Existence gating.** A dotenv-shaped token blocks only if it resolves on disk, or is
  absolute/home-relative.
- **Content-free path queries are exempt:** `ls`, `stat`, `test`, `file`, `realpath`,
  `readlink`, `dirname`, `basename`, `git check-ignore|check-attr|ls-files|status`. The
  allowlist is narrow by design — every entry cannot print file contents. Do not add `cat`,
  `head`, `wc`, `grep`, `awk`, `sed`.
- **Secret detection is value-based.** A credential-ish *name* is too weak a signal
  (`SECRET_KEY_HEADER = "x-secret-key"` is ordinary code). The generic assignment check
  requires ≥20 chars and 3+ character classes. Exact patterns catch `AKIA`, `sk-`, `ghp_`,
  `xox`, `AIza`, PEM. Low-entropy passwords are left to gitleaks at pre-commit.
- **`block-secret-in-write.sh` skips `.claude/hooks/`.** The pattern library holds those
  regexes as literals and would block editing itself. Those paths carry an `ask` rule.
- **Library self-tests need `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`.** A sourced file inherits
  the caller's `$1`, so an unguarded self-test block runs and exits before the caller's
  assertions. Copy the guard into any new library.
- **Test fixtures carry line-scoped `gitleaks:allow`.** They need real credential shapes.
  Keep the marker line-scoped; a path allowlist would blind gitleaks to real secrets there.

---

## 5. Git-level layer

Runs inside git, so it sees resolved state rather than a command string.

- **`pre-push`** — rejects pushes whose resolved refspec targets `main`/`master`/`develop`/
  `staging`/`production`, plus remote branch deletion. Only layer that catches
  `git push origin HEAD:develop`; `Bash(git push origin develop*)` does not match that
  string. Do not rely on the permission rule alone.
- **`pre-commit`** — refuses staged secret files (reuses the hook's `is_secret_path`) and
  scans staged content via `gitleaks`, falling back to a built-in scan. Matters because
  closeout commits once with `git add -A`.
- **`commit-msg`** — conventional commits; merge/revert/fixup subjects exempt.

Active via `core.hooksPath`, a one-time human step per clone (`.git/hooks/` is not
versioned). `--no-verify` and `git config core.hooksPath*` are denied so the layer cannot
be skipped or unset.

---

## 6. Known gaps

1. **`ask` rules only prompt in a prompting mode** (§1). Affects the whole `ask` list in
   §2, including review of agent-configuration changes.

   **Current state: accepted.** `~/.claude/settings.json` has `"defaultMode": "auto"`, so
   the gate is advisory unless a session is switched manually. Guidance-file changes are
   still recorded with `"guardrail": true` (§8) — review after the fact, not before.

   To enforce it later, pick one and update this section:

   ```jsonc
   // A. this repo only — .claude/settings.json, inside "permissions"
   "disableAutoMode": "disable",
   "disableBypassPermissionsMode": "disable",

   // B. everywhere — ~/.claude/settings.json, inside "permissions"
   "defaultMode": "default",

   // C. hard-stop a subset: move it from "ask" to "deny". Survives every mode, but a deny
   //    rule cannot be approved in-session, so an agent cannot edit those files at all.
   "deny": ["Edit(**/.claude/hooks/**)"]
   ```

   A is narrowest. Verify by editing under `.claude/hooks/` and confirming a prompt.
2. **Arbitrary subprocesses bypass file guards.** Read/Edit rules cover `cat`, `head`,
   `tail`, `sed`, not `python -c` or `node -e`. Needs OS-level sandboxing.
3. **`block-exfiltration.sh` is a speed bump.** An HTTP call from inside an interpreter
   gets through; the hook makes casual egress loud and logged.
4. **String matching cannot distinguish discussing a command from running one.** A grep
   pattern containing `tar`, `|`, and `curl` reads as a pipeline. Mitigated by the
   quoted-span and existence rules, not eliminated.
5. **Worktrees outside the project are uncovered.** Relative patterns anchor to the project
   directory, so e.g. `~/.atlas-*/worktrees/` is out of scope. **Accepted** — other tools'
   checkouts. `//` absolute patterns would extend coverage.

---

## 7. Verification

```sh
for h in .claude/hooks/block-*.sh .claude/hooks/lib/git-normalize.sh; do
  printf '%-34s ' "$(basename "$h")"; bash "$h" --self-test >/dev/null 2>&1 \
    && echo PASS || { echo FAIL; bash "$h" --self-test | grep FAIL; }
done
```

212 assertions across 8 files. **Check the assertion count, not just the exit code** — a
silently-skipped suite still reports PASS (§4, `BASH_SOURCE` guard):

```sh
bash .claude/hooks/block-destructive-git.sh --self-test | grep -c '  ok '   # expect 55
```

In-session spot checks:

| Attempt | Expected |
| ------- | -------- |
| read `.env`, `backend/.env.production` | blocked |
| read `.env.example` | allowed |
| `cat .env` / `git check-ignore .env` | blocked / allowed |
| `git clean -fd` / `git clean -n` | denied / allowed |
| `git restore --staged .` / `... --staged --worktree .` | allowed / denied |
| `git -C /path reset --hard` | denied (bypass regression) |
| `git remote set-url origin <url>` | denied |
| `gh auth token` / `gh config get git_protocol` | denied / allowed |
| edit under `.claude/worktrees/…` | no prompt (regression check for §2) |

Git layer, without committing:

```sh
printf 'wip nonsense\n' > /tmp/m && git hook run commit-msg -- /tmp/m
printf 'refs/heads/f abc refs/heads/develop def\n' | bash .githooks/pre-push
```

---

## 8. Audit trail

Three append-only JSONL files under `logs/audit/` (gitignored). Records span sessions;
filter on `.session`.

| File | Written by | Contains |
| ---- | ---------- | -------- |
| `attempts.jsonl` | `audit-attempt-log.sh` (Pre) | every call attempted, before any hook or rule |
| `commands.jsonl` | `audit-command-log.sh` (Post) | Bash commands that executed |
| `file-changes.jsonl` | `audit-file-change-log.sh` (Post) | file changes that executed |

PostToolUse cannot observe a blocked call, hence the split. All three emit a shared `id`
(hash of `tool_name` + `tool_input`, from `lib/audit-id.sh`), so denials are a join.

```sh
# what was blocked
comm -23 <(jq -r .id logs/audit/attempts.jsonl | sort -u) \
         <(cat logs/audit/commands.jsonl logs/audit/file-changes.jsonl \
             | jq -r .id | sort -u) \
  | while read -r id; do
      jq -r --arg i "$id" 'select(.id==$i) | "\(.timestamp)  \(.type)\t\(.subject)"' \
        logs/audit/attempts.jsonl | head -1
    done

# guardrail-file changes, attempted or applied
jq -r 'select(.guardrail==true)|"\(.phase)\t\(.timestamp)\t\(.subject // .path)"' \
  logs/audit/attempts.jsonl logs/audit/file-changes.jsonl

# egress and dependency installs
jq -r 'select(.type=="network_egress" or .type=="dependency_install")|.command' \
  logs/audit/commands.jsonl
```

Two caveats on the denial query:

- **In-flight calls look denied** — their PostToolUse has not fired. Ignore the newest
  entries or filter by timestamp.
- **Repeated identical calls share an id**, so correlation is set-based: a command denied
  once and later allowed appears in both files.

Audit hooks fail open — a logging failure exits 0 rather than blocking work, the opposite
of the blocking hooks. A missing `lib/audit-id.sh` disables logging silently, so §7 is what
confirms the trail is live.
