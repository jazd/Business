---
name: contribute-pr
description: >
  Open a GitHub pull request for features or improvements made in a local clone
  of the Business schema repo on Linux (Grok Build started in the clone). Use when
  the user wants to submit a PR, contribute changes, push a branch, open a pull
  request against jazd/Business, or runs /contribute-pr. Triggers: pull request,
  PR, contribute, submit changes, fork, push branch, github pr create, open PR,
  merge request, contribute-pr.
user-invocable: true
metadata:
  short-description: "Open a GitHub PR from this clone"
---

# /contribute-pr - Submit Business schema changes as a GitHub PR

Help a contributor who **cloned this repo on Linux**, opened **Grok Build in
the clone**, and built features/improvements. Guide them to a clean PR against
upstream. Prefer **doing the git/gh work** when tools and credentials allow;
otherwise print exact commands.

## Audience and setup assumptions

- OS: **Linux**
- Workspace: git clone of **https://github.com/jazd/Business** (or a fork)
- Grok Build cwd is that clone root
- User may or may not have `gh` auth; may push to a **fork** or have write access

## Repo conventions (do not skip)

| Rule | Detail |
|------|--------|
| Base branch | Prefer **`develop`** as the PR target (not `master` unless user insists) |
| Work branch | Create/use a **feature branch** - never commit on `master` |
| Style | Match existing code; NoCRUD: procedures write, views read; no drive-by refactors |
| NoCRUD | Do not introduce silent DELETE of history or classical CRUD overwrites |
| Upgrade script | If procedures/DDL/static changed for an unreleased version, update the **living** hop (today: `PostgreSQL/0.2.9-0.2.10.sql`) in the same PR |
| DbFit pages | `DbFit/.gitignore` ignores `content.txt` / `properties.xml` - **`git add -f`** new test pages |
| Do not commit | Local host overrides (`PostgreSQLServer = postgres`, DbFit Connect host), secrets, `business.sqlite3` shop data, `tmp/`, `*~`, generated `PostgreSQL/procedures.sql` / `schema.pgsql` if gitignored |
| Vendored | Do not change `sql-translator/`, `ua-parser/` without explicit user ask |
| Wiki | Public behavior changes -> note `Business.wiki` update (may be separate repo) |

Also read root **`AGENTS.md`** if present for durable rules.

## Workflow

### 1. Inspect the clone

```bash
git rev-parse --show-toplevel
git remote -v
git status
git branch -vv
git log --oneline -5
```

Confirm:

- This is the Business repo (or a clear fork).
- What is modified / untracked.
- Whether `origin` is `jazd/Business` or the user’s fork.

### 2. Align with upstream `develop`

```bash
git fetch origin
# If origin is upstream:
git checkout develop 2>/dev/null || git checkout -b develop origin/develop
git pull --ff-only origin develop || true
```

If the user only has a fork remote:

```bash
git remote add upstream git@github.com:jazd/Business.git   # if missing
git fetch upstream
git checkout -B develop upstream/develop
```

Create a branch from current work base:

```bash
git checkout -b feature/<short-kebab-description>
```

If they already committed on a messy branch, rebase or cherry-pick onto fresh
`develop` rather than PR from `master`.

### 3. Review what goes in the PR

- Summarize changes for the user in plain language.
- Drop or unstage junk: `tmp/`, personal notes, local DB shop files, host hacks.
- Include: source under `PostgreSQL/procedures.d/`, `schema.xml`, `Bash/sqlite/`,
  skill files under `.grok/skills/`, `GETTING-STARTED.md`, tests (with `-f` if needed),
  living upgrade script when required.
- Run a quick sanity check if relevant: assemble procedures, smoke bash scripts,
  or note that FitNesse wasn’t run.

### 4. Commit (only what belongs)

```bash
git add -A   # then unstage junk, or add paths explicitly
# New DbFit pages:
git add -f DbFit/BusinessSchema/BusinessSuite/.../content.txt \
           DbFit/BusinessSchema/BusinessSuite/.../properties.xml

git status   # final review
git commit -m "$(cat <<'EOF'
Short imperative summary of the contribution.

One or two sentences on why, for maintainers.
EOF
)"
```

Prefer **small, reviewable commits** if the user has several unrelated features-
split rather than one mega-commit when easy.

### 5. Push

**Fork workflow (typical for outside contributors):**

```bash
# Ensure origin is the user's fork, or:
git remote add mine git@github.com:<USER>/Business.git
git push -u mine HEAD
```

**Write access to upstream:**

```bash
git push -u origin HEAD
```

If push fails: check SSH keys, `gh auth status`, or HTTPS credentials. Do not
force-push to `develop`/`master`.

### 6. Open the pull request

Prefer GitHub CLI:

```bash
gh pr create --base develop --head <USER>:feature/branch-or-branch-name \
  --title "Clear title" \
  --body "$(cat <<'EOF'
## Summary
- What changed and why

## Test plan
- [ ] How you verified (sqlite smoke, make pgsqldb, FitNesse, manual)

## Notes
- Upgrade script updated? Wiki?
EOF
)"
```

If `gh` is unavailable, give the compare URL:

```text
https://github.com/jazd/Business/compare/develop...<USER>:feature/branch?expand=1
```

Fill title/body from the commit messages and the user’s stated intent.

### 7. Hand back to the user

Report:

- Branch name and remote
- PR URL (if created)
- Anything left uncommitted or risky
- Suggested review focus for maintainers

## PR body quality

- Complete sentences, what/why, not only file lists.
- Call out NoCRUD-sensitive areas (procedures, `stop`, money numeric, upgrade hop).
- Link issues if any (`Fixes #…`).

## Anti-patterns

- PR into **`master`** by default when **`develop`** is the integration branch.
- Committing `business.sqlite3` shop data or secrets.
- Force-pushing shared branches.
- Bundling unrelated refactors with a feature.
- Skipping `git add -f` for new DbFit pages (they look “missing” forever).
- Claiming tests passed without saying what ran.

## Related

- Shop / bookkeeping skill: `/business-bookkeeper` and `GETTING-STARTED.md`
- Contributor design rules: `AGENTS.md` (if in tree)
- Upstream: https://github.com/jazd/Business
