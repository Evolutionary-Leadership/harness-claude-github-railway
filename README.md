> Generated from `evolutionary-leadership/harness-forge@eb1f0c5`. Do not edit here. Edit in the source repo.

# harness-claude-github-railway

This is the Web App template of the
[Harness Companion](https://www.harnesscompanion.com), the
`claude-code + github + railway` cell.

It is aimed at web applications that deploy to Railway. Each feature
branch gets its own preview environment with a PostgreSQL database
and an S3-compatible bucket attached. Use what you need; ignore what
you don't. Production deploys promote from `dev` to `main` and ship
to the same Railway project on the `main` environment.

A minimal Node plus Express starter (`server.js`, `package.json`,
`.gitignore`) is included so the very first preview deploy has
something to build. These starter files are write-once: replace them
with your real app whenever you're ready.

## How to use

1. Click **Use this template** at the top of the GitHub repo page.
2. Give your new repo a name and pick its visibility.
3. Once the repo is created, follow the wizard at
   [www.harnesscompanion.com](https://www.harnesscompanion.com) to
   provision the Railway project, attach Postgres and the bucket, and
   finish wiring up secrets and your local Claude Code setup.

## What you get

- A `dev` and `main` branch convention with auto-merge for features
  and a release flow that promotes `dev` to `main`.
- Per-feature Railway preview environments, torn down on merge. App,
  Postgres, and the object-storage bucket are pinned to **EU West
  (Amsterdam)** by default so they co-locate; override via
  `SERVICE_REGION` in `.github/workflows/harness-railway.yml` and
  `.github/workflows/feature-branch-railway.yml`.
- A `.claude/` directory with skills, hooks, and agents tuned for the
  feature lifecycle and the Railway preview flow. Each push commits
  the resulting Railway URL back to the feature branch as
  `.railway-url`; if the post-push hook misses it (provisioning
  outruns its budget, or the hook output is not visible to Claude),
  re-fetch it on demand with
  `bash .claude/scripts/get-railway-url.sh`.
- GitHub Actions workflows that wrap the lifecycle and the Railway
  preview lifecycle. Concurrent pushes to the same `claude/...` branch
  queue instead of cancelling, and both the URL-publish step and the
  deployment-trigger wiring are idempotent and self-healing, so
  stranded or half-provisioned environments are recoverable on the
  next workflow trigger.
- A starting `claude-md-snippet.md` to paste into your project's
  `CLAUDE.md`, plus an `.env.example` listing the variables the
  starter expects.

## Branch flow (and where deploys actually run)

```
claude/<codename>-<id>  ← Claude Code pushes here (random codename)
       ↓  Claude names the feature first: set-feature-name.sh writes .harness-feature
       ↓  GitHub Actions: claude-to-feature-branch.yml
       ↓  (merges into feature/<name>, deletes the claude/ branch)
feature/<name>          ← provisioned once by GitHub Actions, then
       ↓                  deployed on every push by Railway itself
       ↓  /mergedev or /review
dev → main
```

Feature branches and Railway environments are named after the work, not the
random session codename. Claude derives a kebab-case slug from your task and
runs `bash .claude/scripts/set-feature-name.sh <slug>` before its first push;
that slug (stored in `.harness-feature`) becomes `feature/<name>`. If naming
is skipped, the first push falls back to the codename. See `.claude/HARNESS.md`
("Feature naming") for the resolver and fallback rules.

A common point of confusion: once a feature is provisioned, **you will
not see a GitHub Actions run on the `feature/` branch when it deploys**,
and that is by design.

- **GitHub Actions does the one-time provisioning only.**
  `feature-branch-railway.yml` runs once (triggered off the `claude/`
  push) to create the Railway environment and point Railway's deployment
  trigger at `feature/<name>`.
- **Every ongoing build and deploy is done by Railway's own GitHub
  integration** watching `feature/<name>`. Those deploys appear in the
  **Railway dashboard**, not as GitHub Actions runs.
- **An empty "Check status" on a feature branch with no open PR is
  expected.** CI (`feature-branch-checks.yml`) runs only on the PR to
  `dev`/`main`. Pushes to `feature/**` are made with the default
  `GITHUB_TOKEN`, which GitHub intentionally does not let trigger
  downstream workflows.

| Look for | Where |
|----------|-------|
| Provisioning trigger | `claude/` push → GitHub Actions tab |
| Deploy branch | `feature/<name>` |
| Ongoing deploys | Railway dashboard (Railway-native, not Actions) |
| Preview URL | `.railway-url` on the feature branch (or `bash .claude/scripts/get-railway-url.sh`) |
| CI checks | Only on the PR to `dev`/`main` |

See `.claude/HARNESS.md` for the full mechanics.

## Provenance

The contents of this repo are auto-generated from
[`evolutionary-leadership/harness-forge`](https://github.com/evolutionary-leadership/harness-forge).
Edits made directly here will be overwritten on the next sync.
File issues and send improvements upstream to harness-forge.
