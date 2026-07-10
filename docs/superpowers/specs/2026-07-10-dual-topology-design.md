# Dual-Topology Support: Monorepo + Multi-Repo in One Harness

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Supersedes:** `multi-repo-agent-sdlc-harness/TODO.md` (stale — predates this repo's tracker-contract refactor)

## Goal

Make this repo's SDLC workflow system support both repo topologies:

- **Monorepo** (today): `frontend/`, `backend/`, `e2e/` as top-level dirs of one git repo.
- **Multi-repo**: each role is (or shares) a separate git repository, cloned under `projects/`, coordinated from this repo.

The move mirrors the tracker-contract refactor exactly: skills stop speaking vendor facts (`frontend/`, `develop`, "the repo") and start speaking **topology contract verbs** resolved through a config + resolver. Monorepo becomes the degenerate config, not a separate code path. The multi-repo fork (`multi-repo-agent-sdlc-harness`) is then deleted; its topology assets are grafted here.

## Resolved decisions

1. **Coordination-repo semantics.** Task commits land only in *project roots*. In monorepo config, the project root happens to be this repo — behavior unchanged. In multi-repo config, this repo is the coordination repo (skills, `repos.yaml`, docs) and **never receives task commits**; merge-guard, closeout, and PRs operate only on `projects/` roots. The existing `frontend/`/`backend/`/`e2e/` dirs remain as the built-in demo monorepo that the default config points at.
2. **Partial-failure policy (multi-root closeout).** Halt & report, no rollback. Roots are processed in deterministic config order; on the first push/PR failure: stop, leave already-opened PRs up, preserve all worktrees, post per-root status to the tracker, emit `WORKFLOW_BLOCKED`. Matches the workflow's bounded-retry, no-destructive-recovery posture.

## Architecture

### The topology contract (`docs/agents/repo-topology.md`, new)

Sibling to `docs/agents/issue-tracker.md`. Defines the verbs skills are allowed to use; skills never name a role directory, git root, or base branch directly.

| Verb | Returns |
|---|---|
| `topo.roles` | Declared roles (e.g. `frontend`, `backend`, `e2e`) |
| `topo.path <role>` | Role's working path — **inside the active worktree set** when one exists |
| `topo.unique-roots [roles…]` | Deduplicated git roots for the given (or all) roles; each root carries its member roles, remote, and repo name |
| `topo.base <root>` | Base branch for a root: intake `Base:` override for that root → `default_branch` from config → remote HEAD |
| `topo.commands <role> <verb>` | Toolchain command for `bootstrap` / `lint` / `lint-fix` / `test` / `typecheck` from the role's config |

### `repos.yaml` (new, committed, always present)

There is always an active topology config — same posture as "there is always an active tracker adapter." No config-vs-no-config bifurcation; the monorepo case dogfoods the resolver daily.

```yaml
# Default (committed) config — the built-in demo monorepo. Current behavior, zero change.
repos:
  frontend:
    path: frontend
    default_branch: develop
    commands:
      bootstrap: "npm ci"
      lint: "npm run lint"
      lint-fix: "npm run lint -- --fix && npx prettier --write ."
      test: "npm test"
  backend:
    path: backend
    default_branch: develop
    commands:
      bootstrap: "python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'"
      lint: "ruff check ."
      lint-fix: "ruff check --fix . && ruff format ."
      test: "pytest"
  e2e:
    path: e2e
    default_branch: develop
    commands:
      bootstrap: "npm ci"
      lint: "npm run lint"
      test: "npx playwright test"
```

Multi-repo config adds `remote:` per role and points `path:` at `projects/<clone>`; roles sharing a remote share a root (the fork's proven auto-dedup rule). `projects/` is gitignored.

The `commands:` block is the key addition beyond the fork's design: it converts the **per-role toolchain coupling** (the inventory's hardest ROLE_DIR finding — npm vs venv/pip vs ruff/vitest/pytest hardcoded in `setup-worktree`, `lint-format`, `unit-tests`) into data.

### Resolver (`.claude/skills/_shared/scripts/resolve-repos.py`)

Ported from the fork and extended: emits role→path, unique-roots (deduped by remote, else by git-root path), per-root base, and per-role commands as JSON for skills/scripts to consume. Learns one new trick the fork lacked: resolving role paths **inside a worktree set** (below).

### Base-branch resolution (kills the copy-pasted idiom)

The identical 8-line `@{u} → origin/develop → develop` snippet duplicated across `lint-format`, `unit-tests`, `code-review`, `implementation-notes`, `merge-guard` is replaced by one shared helper (`_shared/scripts/resolve-base.sh <root>`) implementing the `topo.base` ladder — which, unlike today's idiom, honors the intake `Base:` override. `squash-and-push.sh` already accepts an explicit base arg and needs only its terminal `develop` fallback swapped for the helper.

### Multi-root worktree isolation (the one real design item)

Uniform layout, both topologies:

```
.claude/worktrees/<branch>/<repo-name>/   # one worktree per unique git root
.claude/worktrees/<branch>.state.json     # checkpoint: roots, paths, bases, bootstrap status
```

- **Mono:** one entry (`<branch>/<repo-name>/` where repo-name is this repo). The worktree is a full checkout including `.claude/`, as today; the only change is one directory level, and all consumers of the old path are rewritten in the same phase.
- **Multi:** one worktree per project root; the coordination repo gets **no worktree** (it receives no task commits — decision 1). Skills execute from the coordination checkout; work happens in the project worktrees via `topo.path`.
- **Bootstrap:** per role, `topo.commands <role> bootstrap`, run in `topo.path <role>` — replaces `setup-worktree`'s three hardcoded installs. The `docs/`-branch skip and idempotent re-run behavior carry over.
- **Detach step:** `git checkout develop` (needed when the feature branch is checked out in the main clone) becomes `git checkout <topo.base root>` per root.
- **Teardown (closeout step 5):** remove all worktrees in the set; on any failure anywhere in closeout, preserve the entire set for debugging.

### Git-op fan-out

| Skill/script | Change |
|---|---|
| `intake` | Cut `feature/<id>-…` in **each** involved unique root (involved roles come from the task's scope; when unknown at intake, all roots). Record in the `[BRANCH]` tracker comment one `Base: <repo-name>=<branch>` line **per root**. Idempotent re-run preserved per root. |
| `squash-and-push.sh` | Already role-agnostic and override-aware. Invoked once per root by closeout with that root's base; internals unchanged apart from the fallback swap. |
| `open-pr` | One PR per pushed root against that root's base. `gh` runs with the root as CWD. Collect all PR URLs. |
| `closeout` | Orchestrates per root in config order under the halt-&-report policy. Final `[FINAL SUMMARY]` lists per-root: pushed?, PR URL, status. `git worktree list | head -1` main-checkout discovery is replaced by the state file. |
| `merge-guard` | Graft the fork's working-tree guard (ahead of this repo's prose-only version). Scope globs become **role-qualified** (`frontend:src/auth/*`); the guard diffs each root's working tree against its own base and unions results. Trunk-refusal check runs per root. |
| Blocked-exit push (`workflow` SKILL.md) | `git push -u origin <branch>` per root that has commits. |

### Tracker-comment schema deltas

Topology never leaks into the tracker *contract* (the inventory confirmed it's topology-clean), only into comment payloads:

- `[BRANCH]`: multi-line `Base:` block, one per root (single line in mono — backward compatible).
- `[PLAN]` `### Files in scope` and `[MODIFIED FILES]`: paths become role-qualified (`backend:app/api/users.py`). In mono this is cosmetic; the guard maps role → path prefix.
- `[BLOCKED]`: records the worktree *set* path and per-root branch state.

### E2E cross-role composition

The exactly-3 REL_PATH sites (both `playwright.config.ts` copies + their mirror in `e2e-tests/SKILL.md`): replace `cwd: '../backend'` and `npm --prefix ../frontend` with env vars (`E2E_BACKEND_DIR`, `E2E_FRONTEND_DIR`) defaulting to the current relative paths, set by the `e2e-tests` skill from `topo.path`. Configs keep working standalone in mono; multi-repo gets correct absolute paths for free. The ~40 remaining `e2e/` string anchors in the SKILL are a mechanical swap to `topo.path e2e`.

### Orchestrator (`sdlc-workflow.js`)

- `contextCapsule()` gains the resolved topology (roots, worktree paths, bases) so subagents never re-resolve.
- `WORKING ROOT: ${state.worktree}` becomes the worktree-set map; "never operate on the main checkout" becomes "never operate outside the worktree set."
- `implContext.filesChanged` paths become role-qualified.
- Delete the stale `Run backlog CLI commands from ${state.worktree}/backlog` lines (l.180/202) — pre-tracker-refactor leftover, wrong in both topologies.

### Docs

- `CLAUDE.md`: rewrite the Repo Architecture section — "single git repo / never reference a coordination repo or `projects/`" inverts to describing both configs and pointing at `repos.yaml` + the topology contract.
- `docs/agents/domain.md`: single-context claim becomes per-topology (mono: one `CONTEXT.md`; multi: coordination repo holds it, or per-project — decide during that phase; default: coordination repo holds it).

## What gets grafted from the fork, then the fork dies

| Asset | Disposition |
|---|---|
| `repos.yaml` layout + same-remote-dedup rule | Adopt (extended with `commands:`) |
| `_shared/scripts/resolve-repos.py` | Port + extend (worktree-set resolution) |
| `workflow/scripts/merge-guard.sh` (working-tree, multi-root) | Graft into `merge-guard` skill |
| Everything else (monolithic skills, Backlog.md coupling, TODO.md) | Superseded; archive/delete the fork repo |

## Implementation phases

Each phase lands independently with mono behavior verified unchanged (same commit-series discipline as the tracker refactor, `294a1f6`→`e79f63f`).

| # | Phase | Contents | Effort |
|---|---|---|---|
| 0 | Contract + plumbing | `repo-topology.md`, committed default `repos.yaml`, resolver port, `resolve-base.sh`. No skill behavior change. | S |
| 1 | BASE_BRANCH sweep | Replace the 5-skill idiom with the helper; fix `setup-worktree` detach, `open-pr`/`closeout` `develop` fallbacks. | S |
| 2 | ROLE_DIR / toolchain sweep | `setup-worktree` bootstrap → `commands:`; `lint-format`, `unit-tests` → resolver-driven; `commit` scopes from roles; `e2e-tests` anchor swap + env-var REL_PATH fix. | M (mechanical) |
| 3 | GIT_ROOT fan-out | `intake` per-root branch + per-root `Base:`; `closeout`/`open-pr` per-root orchestration + halt policy; merge-guard graft + role-qualified scope; blocked-exit per root. | M |
| 4 | Multi-root worktrees | Uniform `<branch>/<repo>/` layout, state file, per-role bootstrap, teardown-all. | L (design item) |
| 5 | Coordinator + docs + orchestrator | `workflow/SKILL.md`, `CLAUDE.md`, `domain.md`, `sdlc-workflow.js` capsule + stale-line fix. | M |
| 6 | Validation | Mono regression: run a real task end-to-end on the default config, diff observable behavior against today. Multi fixture: two throwaway local git repos under `projects/` (gitignored) + a multi-root `repos.yaml`; drive intake→closeout; verify per-root branches, PRs (against local remotes or `gh` dry-run), halt-&-report by injecting a push failure on root 2. | M |

Phases 1–2 correspond to the tracker refactor's mechanical middle (7 commits there; smaller here). Phase 4 is the only genuinely new design work and is unavoidable in any approach, including reseeding.

## Out of scope

- Cross-repo *contract* awareness in hostile-plan-review (frontend↔backend API compatibility checks) — worth a follow-up, not needed for topology support.
- Per-project `CONTEXT.md`/ADR federation in multi-repo mode (default: coordination repo holds the single context).
- Tracker changes — the contract is already topology-clean.
- Real multi-repo engagement config (placeholder remotes) — Phase 6 uses a synthetic fixture.

## Risks

- **Worktree layout change in mono** (`<branch>/` → `<branch>/<repo>/`): all consumers (`workflow` checkpoint, `closeout` teardown, `[BLOCKED]` comments) are rewritten in Phase 4 together; in-flight tasks straddling the upgrade must be closed out first.
- **Role-qualified scope globs** change the `[PLAN]`/`[MODIFIED FILES]` format that merge-guard parses; old-format comments on in-flight tasks need a fallback parse (treat unqualified paths as mono-root-relative).
- **`gh` multi-remote auth**: multi-repo PRs assume `gh` is authenticated for every project host; pre-flight this in `open-pr` and fail with a clear `WORKFLOW_BLOCKED` reason.

---

## Appendix: topology-assumption inventory (2026-07-10 scan)

Classes: **ROLE_DIR** hardcoded role path · **GIT_ROOT** single-root git op · **BASE_BRANCH** hardcoded `develop` · **REL_PATH** cross-role relative path.

**The duplicated base idiom (BASE_BRANCH, 5 sites):** identical `@{u} → origin/develop → develop` snippet in `lint-format` (13–21), `unit-tests` (13–20), `code-review` (18–26), `implementation-notes` (15–18), `merge-guard` (31–34). None honors the intake `Base:` override.

**`setup-worktree/SKILL.md`** — worktree at `$REPO_ROOT/.claude/worktrees/<branch>` (GIT_ROOT); `git checkout develop` detach (BASE_BRANCH, l.23/28); hardcoded bootstrap `cd frontend && npm ci`, `cd e2e && npm ci`, backend venv+pip (ROLE_DIR + toolchain, l.49–58); enumerates worktree contents (ROLE_DIR, l.68).

**`workflow/SKILL.md`** — worktree-contents enumeration (ROLE_DIR, l.28); `$REPO_ROOT`/`git worktree list | head -1`/checkpoint path (GIT_ROOT, l.32–55); blocked-exit single push (GIT_ROOT, l.70).

**`e2e-tests/SKILL.md`** — ~40 mechanical `e2e/` anchors (cd/test-results/config paths); the load-bearing pair `cwd: '../backend'` + `npm --prefix ../frontend` (REL_PATH, l.117–118); backend-only skip heuristic (semantic, l.40/70/169).

**`playwright.config.ts` (skill asset + `e2e/` copy, identical)** — `cwd: '../backend'` (l.33), `npm --prefix ../frontend` (l.40) (REL_PATH); venv uvicorn entrypoint + localhost FE↔BE composition (l.15/32/44).

**`lint-format/SKILL.md`** — per-role `cd` + tool commands (ROLE_DIR + toolchain, l.31–60); base idiom.

**`unit-tests/SKILL.md`** — `git diff "$base"...HEAD -- frontend/ backend/` (ROLE_DIR, l.28); `cd backend` pytest / `cd frontend` vitest (l.43–51); base idiom.

**`commit/SKILL.md`** — "single git commit… no `backlog/`" (GIT_ROOT, l.8); role commit-scopes (cosmetic, l.33/80/90).

**`intake/SKILL.md`** — `git branch --show-current` single-root base capture (GIT_ROOT, l.21); `Base:` write in `[BRANCH]` comment (the good override pattern, l.30/39); trunk-set guardrail (l.47).

**`closeout/SKILL.md`** — `Base:` consume with `develop` terminal fallback (l.18); single-root squash/push/teardown, `git worktree list | head -1` (GIT_ROOT, l.56–61); base flows to `open-pr` (l.34).

**`open-pr/SKILL.md`** — trunk-set refusal (l.21/76); `defaultBranchRef` → `develop` fallback (l.38–42).

**`merge-guard/SKILL.md`** — trunk set (l.18); base idiom (l.31–34); `frontend/src/auth/*` glob example (l.70).

**`squash-and-push.sh`** — arg → `@{u}` → `origin/develop` → `develop` ladder (l.35–55, override-aware); single-root reset/push (l.33/66/79/81). Role-agnostic otherwise.

**`sdlc-workflow.js`** — stale `${state.worktree}/backlog` CLI lines (l.180/202); single `WORKING ROOT` (l.180–181/201–203); repo-root-relative `filesChanged` (l.140); single-push closeout prompt (l.435). No role-dir or `develop` literals.

**`CLAUDE.md`** — mono declaration + "never reference a coordination repo or `projects/`" (l.5–11); `develop` base + trunk protections (l.65/67/85).

**`docs/agents/domain.md`** — single-context over the three roles (l.14, 22–24).

**Topology-clean:** `docs/agents/issue-tracker.md`, tracker adapters (except one `[BLOCKED]` doc mention of "the worktree"), `install-browsers.js`, `plan-task` (illustrative glob only), `audit-followed-workflow-steps`.
