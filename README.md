> Generated from `evolutionary-leadership/harness-forge@66d00a0`. Do not edit here. Edit in the source repo.

# harness-claude-github-railway

**Talk to an AI, ship a web app. Every feature gets its own live preview
URL, database, and file storage, provisioned and torn down for you.**

This is the **Web App** template of the
[Harness Companion](https://www.harnesscompanion.com), the
`claude-code + github + railway` cell. It wraps [Claude
Code](https://www.anthropic.com/claude-code), GitHub Actions, and
[Railway](https://railway.app) into one feature workflow: you describe the
work, and each feature branch comes up as a fully isolated preview
environment with its own PostgreSQL database and S3-compatible bucket
attached. Test against real infrastructure without ever touching
production data.

A minimal Node plus Express starter (`server.js`, `package.json`,
`.gitignore`) ships with the template so the very first preview deploy has
something to build. These starter files are write-once: replace them with
your real app whenever you are ready, in any language Railway can run.
(Not deploying to the cloud? The
[Code Only cell](https://github.com/Evolutionary-Leadership/harness-claude-github)
gives you the same feature workflow without the Railway pieces.)

## The idea in one diagram

You describe the work in plain language. A branch-naming convention and a
few short prompts drive the rest:

```
claude/<codename>-<id>      Claude Code pushes here (random codename)
       |
       |  Claude names the feature first: set-feature-name.sh writes .harness-feature
       v  GitHub Actions: claude-to-feature-branch.yml + feature-branch-railway.yml
feature/<name>              provisioned once by GitHub Actions, then
       |                    deployed on every push by Railway itself
       |                    (its own preview URL, Postgres, and bucket)
       v  /mergedev or /review
dev  ->  main               promote to production, tagged and released
```

No per-feature setup, no manual environment wrangling: the preview comes
up on the first push and is torn down when the feature merges.

## Get started

1. Click **Use this template** at the top of this repo's GitHub page.
2. Give your new repo a name and pick its visibility.
3. Follow the wizard at
   [harnesscompanion.com](https://www.harnesscompanion.com) to provision
   the Railway project, attach Postgres and the bucket, and wire up your
   secrets and local Claude Code setup.

Then open Claude Code in the new repo and just describe what you want to
build. The first session provisions your first preview environment.

## What you get

- **A `dev` and `main` branch flow** with auto-merge for features and a
  release flow that promotes `dev` to `main` and ships to the `main`
  Railway environment.
- **A Railway preview environment per feature**, torn down on merge, each
  with its own Postgres and object-storage bucket so feature testing never
  touches production data. The app, Postgres, and bucket all default to
  **EU West (Amsterdam)** in every environment so they co-locate (nothing
  lands in a US region); override via `SERVICE_REGION` (app plus Postgres)
  and `BUCKET_REGION` (bucket) in
  `.github/workflows/harness-railway.yml` and
  `.github/workflows/feature-branch-railway.yml`. Existing services do not
  migrate automatically, and feature buckets inherit their region from dev.
- **Feature branches and environments named after the work, not a random
  codename.** Claude derives a kebab-case slug from your task and runs
  `bash .claude/scripts/set-feature-name.sh <slug>` before its first push;
  that slug (stored in `.harness-feature`) becomes `feature/<name>`. If
  naming is skipped, the first push falls back to the codename. See
  `.claude/HARNESS.md` ("Feature naming") for the resolver and fallback.
- **The preview URL, committed back to your branch.** Each push writes the
  Railway URL to the feature branch as `.railway-url`; if the post-push
  hook misses it (provisioning outruns its budget, or its output is not
  visible to Claude), re-fetch on demand with
  `bash .claude/scripts/get-railway-url.sh`. The URL-publish and
  deployment-trigger steps are idempotent and self-healing, so stranded or
  half-provisioned environments recover on the next workflow trigger, and
  concurrent pushes to the same branch queue instead of cancelling.
- **A `.claude/` toolkit** of skills, hooks, and agents tuned for the
  feature lifecycle and the Railway preview flow. Drive it with short
  commands:

  | Command | What it does |
  |---|---|
  | `/feature` | Start a feature (optional; a new session auto-initializes one). |
  | `/mergedev` | Open a PR into `dev` and auto-merge it. |
  | `/review` | Open a PR for human review instead of auto-merging. |
  | `/release` | Promote `dev` to `main`, tag, and cut a GitHub Release. |
  | `/status` | Dashboard of active features, preview URLs, open PRs. |
  | `/rollback`, `/changelog`, `/deps`, `/continue` | Revert a release, generate notes, batch Dependabot PRs, resume work. |

  Run `/getting-started` any time to list them all.
- **A starter `claude-md-snippet.md`** to paste into your project's
  `CLAUDE.md`, plus an `.env.example` listing the variables the starter
  expects.

## Where deploys actually run

A common point of confusion: once a feature is provisioned, **you will not
see a GitHub Actions run on the `feature/` branch when it deploys**, and
that is by design.

- **GitHub Actions does the one-time provisioning only.**
  `feature-branch-railway.yml` runs once (triggered off the `claude/`
  push) to create the Railway environment and point Railway's deployment
  trigger at `feature/<name>`.
- **Every ongoing build and deploy is done by Railway's own GitHub
  integration** watching `feature/<name>`. Those deploys appear in the
  **Railway dashboard**, not as GitHub Actions runs.
- **An empty "Check status" on a feature branch with no open PR is
  expected.** CI (`feature-branch-checks.yml`) runs only on the PR to
  `dev` or `main`. Pushes to `feature/**` use the default `GITHUB_TOKEN`,
  which GitHub intentionally does not let trigger downstream workflows.

| Look for | Where |
|----------|-------|
| Provisioning trigger | `claude/` push, in the GitHub Actions tab |
| Deploy branch | `feature/<name>` |
| Ongoing deploys | Railway dashboard (Railway-native, not Actions) |
| Preview URL | `.railway-url` on the feature branch (or `bash .claude/scripts/get-railway-url.sh`) |
| CI checks | Only on the PR to `dev` or `main` |

See `.claude/HARNESS.md` for the full mechanics.

## Make it yours

The harness ships opinionated defaults, and they are all yours to change.
Skills are markdown files you can edit or add to, workflows are plain YAML,
and your `CLAUDE.md` is never touched by the harness. When upstream ships
improvements, run `/harness-upgrade` to review and adopt them; your custom
skills and settings are preserved. `.claude/HARNESS.md` documents exactly
which files the harness manages.

## Provenance

The contents of this repo are auto-generated from
[`evolutionary-leadership/harness-forge`](https://github.com/evolutionary-leadership/harness-forge).
Edits made directly here will be overwritten on the next sync. File issues
and send improvements upstream to harness-forge.
