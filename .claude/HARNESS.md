# Harness Context

This project was scaffolded from the
[`evolutionary-leadership/harness-claude-github-railway`](https://github.com/evolutionary-leadership/harness-claude-github-railway)
template repo (variant: **harness-claude-github-railway**) using GitHub's
"Use this template" button. The template added automated CI/CD
infrastructure with Railway preview environments, PostgreSQL, and
S3-compatible object storage, not application code. Understanding what it
set up helps you work with it instead of against it.

The template content itself is authored in
[`evolutionary-leadership/harness-forge`](https://github.com/evolutionary-leadership/harness-forge)
and synced from there into this template repo on every harness release.

## Architecture

### Branch naming drives everything

```
claude/<feature>-<sessionId>   ← you work here
       ↓ (GitHub Action)
feature/<feature>              ← created automatically from dev
       ↓                         + Railway env + Postgres + Bucket provisioned
       ↓ (/mergedev)
dev                            ← PR auto-merged
                                 Railway env + Postgres + Bucket cleaned up
```

- Pushing to a `claude/` branch triggers the Action that creates/updates
  the corresponding `feature/` branch.
- The feature name is derived by stripping the `claude/` prefix and
  `-<sessionId>` suffix: `claude/dark-mode-abc123` → `feature/dark-mode`.
- Each feature branch gets its own isolated Railway environment with a
  dedicated PostgreSQL instance and S3-compatible bucket, duplicated from
  dev.

### Signal files

- **`.pr-description.md`**: Committing this file to the repo root triggers
  the GitHub Action to create a PR from `feature/<name>` → `dev` and
  auto-merge it. The `/mergedev` skill writes this file for you. If the
  frontmatter contains `review: true`, the PR is created but NOT
  auto-merged (used by the `/review` skill). If `hotfix: true`, the hotfix
  workflow handles it instead.
- **`.release-description.md`**: Committing this file triggers the release
  workflow to create a PR from `dev` → `main`, tag a version, and create
  a GitHub Release. The `/release` skill writes this file.
- **`.railway-url`**: Written by the GitHub Action to the feature branch.
  Contains the Railway preview URL for this feature's environment.

### `.harness-version` configuration

The `.harness-version` file supports these fields:

```yaml
harness: harness-claude-github-railway
version: 0.3.38
repo: evolutionary-leadership/harness-forge
traits: nodejs, typescript, express
check: npm test && npm run lint
reviewers: teammate1, teammate2
```

- **`harness`**: variant identifier; matches the per-cell template repo
  this project was scaffolded from.
- **`version`**: harness version installed; used by `/harness-upgrade` to
  diff against the latest release.
- **`repo`**: the upstream forge repo (`evolutionary-leadership/harness-forge`),
  which hosts `VERSION`, `migrations/`, and `stacks/traits/`.
- **`check`**: CI command to run on PRs to dev. When configured, the
  `feature-branch-checks.yml` workflow runs this command, and mergedev
  uses `gh pr merge --auto` to wait for checks.
- **`reviewers`**: Default reviewers assigned when using `/review`.
- **`traits`**: stack-specific best-practice files installed under
  `.claude/traits/` and managed by `/harness-upgrade`.

**Prerequisites for CI checks:**
- Enable "Allow auto-merge" in GitHub repo settings (Settings → General)
- Add a branch protection rule for `dev` requiring the "check" status check
- Optionally add the same for `main` to gate releases and hotfixes

### Hooks

- **SessionStart**: Runs `.claude/scripts/session-start.sh` on every new
  session. On a `claude/` branch, it automatically initializes the
  feature: if the feature branch exists, it merges previous work; if not,
  it pushes an init commit to trigger the GitHub Action (creates feature
  branch + Railway environment). This means `/feature` is no longer
  required to start a new chat, just describe what you want to build.
- **PreToolUse (Write/Edit/Bash)**: Runs
  `.claude/hooks/prevent-em-dash.sh`, which blocks any write that contains
  a U+2014 em dash.
- **PostToolUse (git push)**: Runs
  `.claude/hooks/post-push-railway-url.sh` after every `git push`, which
  fetches and displays the Railway preview URL.

### Railway environments

Each feature gets a fully isolated Railway environment:
- Duplicated from the `dev` environment (same services and config)
- Includes its own PostgreSQL instance and S3-compatible bucket
- `DATABASE_URL` is auto-wired via Railway reference variable
  (`${{Postgres.DATABASE_URL}}`), so your app just reads `DATABASE_URL`
- Bucket credentials are auto-wired as environment variables (see below)
- Deployed automatically when the feature branch is pushed
- Cleaned up automatically (including Postgres and bucket) when the
  feature is merged
- Preview URL stored in `.railway-url` on the feature branch

**Database migrations:** Each feature environment starts with an empty
database. Your migration tooling must handle creating tables from scratch.

**Seed data:** Production has `SEED_DATA=false` set automatically by the
harness setup workflow. Dev does NOT have this variable, and feature
environments inherit from dev, so they seed normally. Projects should
check `process.env.SEED_DATA === "false"` at the top of their seed script
to bail out early on production.

**Bucket environment variables:**

| Variable | Purpose |
|----------|---------|
| `AWS_S3_BUCKET_NAME` | Globally unique S3 bucket name |
| `AWS_ENDPOINT_URL` | S3 endpoint |
| `AWS_ACCESS_KEY_ID` | S3 access key |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key |
| `AWS_DEFAULT_REGION` | S3 region (e.g., `auto`) |

Use any S3-compatible client library. Each environment's bucket is
completely isolated, with no cross-contamination between feature, dev,
and production.

## Managed trait files

Stack-specific best practices live in `.claude/traits/` as separate
managed files (e.g. `.claude/traits/nodejs.md`,
`.claude/traits/typescript.md`). These are fetched from the forge repo's
`stacks/traits/` directory and can be auto-updated via `/harness-upgrade`.

To install traits, add the trait names to `.harness-version`:

```
traits: nodejs, typescript, express, vitest, eslint, pnpm
```

Then run `/harness-upgrade`. It will fetch the matching trait files from
the forge and install them in `.claude/traits/`. On future upgrades, it
will show diffs and let you update to the latest best practices.

Add this line to your project's `CLAUDE.md` so the AI reads them:

```
Read `.claude/traits/` for stack-specific best practices before writing code.
```

Available traits and presets are listed in the forge repo's `stacks/`
directory.

## Migration system

Each harness version has a structured migration file
(`migrations/X.Y.Z.yaml` in the forge repo) describing what changed. The
`/harness-upgrade` skill uses these to:

- **Filter by relevance**: only show changes that affect your variant and
  traits
- **Categorize by priority**: REQUIRED (infrastructure), RECOMMENDED
  (traits), INFORMATIONAL (other)
- **Show context**: what changed and why, not just raw diffs

Migration files are auto-generated by the `harness-version-bump.yml`
workflow in the forge whenever a feature merges to `dev`. They are never
manually authored.

## Harness-managed files

These files are maintained by the harness and replaced on
`/harness-upgrade`. Do not edit them; your changes will be overwritten.

| File | Purpose |
|------|---------|
| `.github/workflows/claude-to-feature-branch.yml` | Merges `claude/` branches into `feature/` branches |
| `.github/workflows/claude-mergedev.yml` | Deletes Railway environment, creates PR from `feature/` to `dev`, and auto-merges (or opens for review) |
| `.github/workflows/feature-branch-checks.yml` | Runs CI checks on PRs to dev (reads `check:` from `.harness-version`) |
| `.github/workflows/release.yml` | Creates release PR dev → main, tags version, creates GitHub Release |
| `.github/workflows/hotfix.yml` | Handles hotfix PRs to main, tags patch release, back-merges to dev |
| `.github/workflows/feature-branch-railway.yml` | Creates Railway environment with Postgres and bucket when a new feature branch is created |
| `.github/workflows/feature-merge-cleanup.yml` | Deletes Railway environment (including Postgres and bucket) and feature branch after merge to dev |
| `.github/workflows/feature-branch-cleanup.yml` | Fallback cleanup if a feature branch is deleted manually |
| `.claude/scripts/session-start.sh` | Session startup hook |
| `.claude/scripts/list-skills.sh` | Skill discovery script |
| `.claude/hooks/post-push-railway-url.sh` | Fetches Railway preview URL after push |
| `.claude/hooks/prevent-em-dash.sh` | Blocks writes containing U+2014 em dashes |
| `.claude/skills/getting-started/SKILL.md` | Orientation skill |
| `.claude/skills/feature/SKILL.md` | `/feature` skill |
| `.claude/skills/mergedev/SKILL.md` | `/mergedev` skill |
| `.claude/skills/review/SKILL.md` | `/review` skill: submit PR for team review |
| `.claude/skills/release/SKILL.md` | `/release` skill: ship dev to production |
| `.claude/skills/hotfix/SKILL.md` | `/hotfix` skill: emergency production fix |
| `.claude/skills/status/SKILL.md` | `/status` skill: team dashboard |
| `.claude/skills/changelog/SKILL.md` | `/changelog` skill: generate changelog |
| `.claude/skills/deps/SKILL.md` | `/deps` skill: handle Dependabot PRs |
| `.claude/skills/continue/SKILL.md` | `/continue` skill: resume in-progress feature |
| `.claude/skills/chat/SKILL.md` | `/chat` skill: conversation mode (no file changes) |
| `.claude/skills/endchat/SKILL.md` | `/endchat` skill: clean up the orphan feature branch left behind by `/chat` |
| `.claude/skills/rollback/SKILL.md` | `/rollback` skill: revert bad deploy |
| `.claude/skills/harness-upgrade/SKILL.md` | `/harness-upgrade` skill |
| `.claude/agents/docs-updater.md` | Documentation auditor agent (runs during mergedev) |
| `.claude/HARNESS.md` | This file |
| `.harness-version` | Version tracking |
| `.claude/traits/*.md` | Stack best practices (managed per `traits:` in `.harness-version`) |

**Note:** `harness-railway.yml` is a one-time setup workflow that
self-destructs after its first run. It is not part of ongoing upgrades.
It can be triggered two ways: manually via the Actions tab ("Run
workflow"), or by writing a one-line `.harness-bootstrap` file to the
`dev` branch (used by the harnesscompanion.com wizard via the GitHub
MCP server, which can write files but not dispatch workflows). The
final cleanup step removes both `.github/workflows/harness-railway.yml`
and `.harness-bootstrap`, so the trigger can never re-fire.

## Harness-provided starting points

The harness created these files as a starting point. You own them, so
edit freely to match your project. On `/harness-upgrade`, these are
diffed and you choose whether to accept upstream changes.

| File | What to customize |
|------|-------------------|
| `.claude/settings.json` | Add your own hooks and tool permissions alongside the harness-provided ones |
| `.github/dependabot.yml` | Add entries for your package ecosystems (npm, pip, Docker, etc.) |
| `railway.json` | Customize build commands, start commands, restart policy for your app |

## Starter scaffold (write-once)

The harness ships a minimal Node + Express "it works" app so the Railway
pipeline has something to deploy on the very first push. These files are
**created once on init and never touched again** by `/harness-upgrade`:

| File | What to do |
|------|------------|
| `server.js` | Replace with your real app, or delete entirely if not using Node |
| `package.json` | Replace with your real manifest, or delete entirely if not using Node |
| `.gitignore` | Extend for your stack |

Concretely:
- If you edit any of these files, `/harness-upgrade` will **never overwrite
  your changes**.
- If you delete any of these files, `/harness-upgrade` will **never
  recreate them**. You can safely move to Python, Go, Rust, or any other
  stack: delete `server.js`, `package.json`, `.gitignore`, and update
  `railway.json`'s `startCommand` and `watchPatterns` to match your
  runtime.
- If a starter file is missing on a fresh scaffold (partial install), the
  next `/harness-upgrade` run will offer to create it from upstream.

## Project-owned files

Everything else belongs to the project. The harness does not touch:

- **`CLAUDE.md`**: Your project instructions. The harness provides
  `claude-md-snippet.md` as a starting point; copy what you need.
- **All application code**: Source files, configs, tests, etc.
- **Custom skills**: Any skill you add to `.claude/skills/` that isn't
  listed above.

## How to extend

### Adding a skill

Create `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`,
`description`). Custom skills are not touched by `/harness-upgrade`.

### Adding an agent

Create `.claude/agents/<name>.md` with YAML frontmatter (`name`,
`description`, `allowed-tools`). Agents are autonomous specialists that
run in their own context via the Agent tool. Custom agents are not
touched by `/harness-upgrade`.

### Adding workflows

Prefer adding new workflow files in `.github/workflows/` over modifying
harness-managed ones. New files won't be touched by upgrades.

### Switching to Docker builds

Railway defaults to Railpack, which auto-detects your framework and
handles builds with zero config. If you need custom build steps (system
dependencies, multi-stage builds, binary compilation), create a
`Dockerfile` and update `railway.json`:

```json
{
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  }
}
```

## Variants

Two per-cell template repos currently ship from the forge:

| Variant | Repo | What you get |
|---------|------|--------------|
| `harness-claude-github` | [evolutionary-leadership/harness-claude-github](https://github.com/evolutionary-leadership/harness-claude-github) | Feature branches + auto-merge, no deploy target |
| **`harness-claude-github-railway`** *(this project)* | [evolutionary-leadership/harness-claude-github-railway](https://github.com/evolutionary-leadership/harness-claude-github-railway) | + Railway preview environments per feature with isolated PostgreSQL and S3-compatible bucket |

Switching from `harness-claude-github` to
`harness-claude-github-railway` is not an automated migration; it
requires re-scaffolding from the new template and porting your
application code over.

## Upgrading (same variant)

Run `/harness-upgrade` to check for version updates within your current
variant. The skill uses structured migration files from the forge
(`evolutionary-leadership/harness-forge`) to show you exactly what
changed, filtered by your variant and installed traits. See
`.harness-version` for current version info.

### Version numbering

Harness versions use semver (`MAJOR.MINOR.PATCH`):
- **PATCH** bumps automatically on each feature merge to the forge's
  `dev` branch
- **MINOR** bumps are a developer decision for significant releases
- **MAJOR** is reserved for breaking architecture changes

## License

The Harness Companion is licensed under the **Apache License 2.0**.
See the `LICENSE` and `NOTICE` files in the root of this repository.

The NOTICE file must be preserved in any derivative works or forks.
It attributes this project to its origin:
[The Harness Companion](https://www.harnesscompanion.com)
by Evolutionary Leadership Coöperatie U.A.
