> Generated from `evolutionary-leadership/harness-forge@d66244b`. Do not edit here. Edit in the source repo.

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
- Per-feature Railway preview environments, torn down on merge.
- A `.claude/` directory with skills, hooks, and agents tuned for the
  feature lifecycle and the Railway preview flow.
- GitHub Actions workflows that wrap the lifecycle and the Railway
  preview lifecycle.
- A starting `claude-md-snippet.md` to paste into your project's
  `CLAUDE.md`, plus an `.env.example` listing the variables the
  starter expects.

## Provenance

The contents of this repo are auto-generated from
[`evolutionary-leadership/harness-forge`](https://github.com/evolutionary-leadership/harness-forge).
Edits made directly here will be overwritten on the next sync.
File issues and send improvements upstream to harness-forge.
