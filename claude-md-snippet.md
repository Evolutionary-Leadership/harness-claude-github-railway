# CLAUDE.md Snippet: Feature Development Workflow

Add the following to your project's `CLAUDE.md`. Adapt project-specific details.

---

## Harness infrastructure

This project's CI/CD was set up by the
[harness-forge](https://github.com/Evolutionary-Leadership/harness-forge)
harness. Read `.claude/HARNESS.md` for details on which files are
harness-managed (don't edit; they get overwritten on upgrade) and how to
extend the setup.

## Starter app

The harness scaffolds a minimal Node + Express "it works" app
(`server.js`, `package.json`, `.gitignore`) so the Railway pipeline has
something to deploy on the very first push. Visit the Railway preview URL
after pushing a feature branch and you'll see a page confirming the
pipeline is live, with branch name, environment, and git SHA.

These three files are **write-once**: `/harness-upgrade` will never
overwrite them and never recreate them if you delete them. To build your
real app, just edit `server.js` (and `package.json`). To use a non-Node
stack, delete all three files and update `railway.json`'s `startCommand`
and `watchPatterns` for your runtime; nothing in the harness will pull
the starter back.

## Writing rules

- Never use em dashes (U+2014). Use commas, colons, semicolons, or parentheses instead. A PreToolUse hook will block any write containing an em dash

## Avoiding stream timeouts

The "API Error: Stream idle timeout, partial response received" error
fires when the API stream stays silent for too long mid-response. The
harness sets `API_TIMEOUT_MS=900000` and `CLAUDE_CODE_MAX_RETRIES=15` in
`.claude/settings.json` so long responses have headroom and transient
network blips get retried. Claude cannot detect a pending timeout from
inside a turn (the stall happens in the API layer), so the rest is
habits that keep any single turn from going quiet for too long:

- Avoid single tool calls that produce huge output. Cap noisy commands
  with `| head` or narrow paths, and prefer `Read` with `offset`/`limit`
  over reading whole large files.
- Break large file writes into multiple `Edit` calls instead of one
  mega `Write`.
- Run `/compact` proactively at natural seams (after finishing a
  sub-task, before starting a long multi-tool sequence) rather than
  waiting for context pressure.
- Prefer parallel small tool calls over a single huge sequential one.

If a timeout still fires, the next prompt usually completes the work;
check status.claude.com if it persists across sessions.

## Feature development workflow

The full lifecycle from idea to merged feature is automated. Railway
environments are created automatically by GitHub Actions so the feature
is deployable from the first push.

### Database

Every Railway environment (production, dev, and each feature branch) gets
its own isolated PostgreSQL instance. The `DATABASE_URL` environment variable
is automatically wired to the app service via a Railway reference variable
(`${{Postgres.DATABASE_URL}}`). Your app just reads `DATABASE_URL`, so no
manual connection string configuration needed.

**Migrations:** Database migrations run automatically on deploy via the
`railway.json` startCommand. It detects your ORM (Drizzle or Prisma) and
runs the appropriate migration command before starting the app. Each feature
environment starts with an empty database, so all migrations run from
scratch. Dev and production only run new (pending) migrations.

**How migrations flow through branches:**

| Environment | DB state | What happens on deploy |
|---|---|---|
| Feature branch | Empty (fresh) | All migrations run from first to latest |
| Dev | Persistent | Only new migrations from merged feature run |
| Main/Production | Persistent | Only new migrations from release run |

**Safe schema changes:** For breaking changes (renaming columns, changing
types), use the expand-and-contract pattern: add the new column alongside
the old one, migrate data, update code, then drop the old column in a
separate migration. See your database trait (`.claude/traits/`) for details.

**Migration conflicts:** When two feature branches both modify the schema,
merging them will produce a git conflict in the migration journal file.
This is intentional; resolve it manually and verify with your ORM's
generate command.

### Object Storage (Bucket)

Every Railway environment gets its own isolated S3-compatible bucket. Bucket
credentials are available as environment variables in your app service:

| Variable | Purpose |
|---|---|
| `AWS_S3_BUCKET_NAME` | Globally unique S3 bucket name |
| `AWS_ENDPOINT_URL` | S3 endpoint |
| `AWS_ACCESS_KEY_ID` | S3 access key |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key |
| `AWS_DEFAULT_REGION` | S3 region (e.g., `auto`) |

Use any S3-compatible client library (AWS SDK, Bun S3, boto3, etc.) to
interact with the bucket. Railway uses virtual-hosted-style URLs, and most
libraries handle this automatically when given the base endpoint.

**Environment isolation:** Each environment's bucket is completely separate.
Feature branch environments get their own bucket with isolated credentials,
so you won't accidentally touch production data.

### Seed data

Seed data runs by default on all environments. Production has
`SEED_DATA=false` set automatically by the harness setup workflow, so it
never gets seeded with demo data. Dev and feature environments do not have
this variable, so they seed normally.

Projects should check for this at the top of their seed script:

```js
if (process.env.SEED_DATA === "false") {
  console.log("SEED_DATA=false, skipping seed");
  process.exit(0);
}
```

### Railway preview URL

A PostToolUse hook (`.claude/hooks/post-push-railway-url.sh`) tries to
fetch the Railway preview URL after every `git push`. However, hook output
is not always visible in your context. **After your final push, always
manually fetch and include the Railway URL in your summary:**

```
git fetch origin feature/<name> && git show origin/feature/<name>:.railway-url
```

### 1. Starting a new feature

Every new chat on a `claude/` branch is automatically treated as a new
feature, no `/feature` prefix needed. Just describe what you want to build.

On session start, the harness automatically:
1. Pushes an init commit to trigger the GitHub Action
2. The Action derives the feature name (strip `claude/` prefix and
   `-<sessionId>` suffix), creates `feature/<name>` from dev, and creates a
   Railway environment duplicated from dev (including its own Postgres
   instance and bucket)
3. The Railway preview URL appears automatically after each push

You can still use `/feature <description>` explicitly if you prefer, but
it's no longer required.

### 2. Pushing code

Push to the `claude/` branch. The GitHub Action merges it into the feature
branch and deletes the source claude/ branch.

### 3. Merging to dev

Use `/mergedev` or say "merge to dev". This writes `.pr-description.md`,
commits, and pushes. The GitHub Action creates a PR and auto-merges it.

### 3b. Submitting for review (instead of auto-merge)

Use `/review` to create a PR without auto-merge. The PR stays open for
team review, with the Railway preview URL included for live testing.
Reviewers are assigned from `.harness-version` if configured.

### 4. Automatic cleanup

When auto-merge succeeds, `claude-to-feature-branch.yml` deletes the source
`claude/` branch. The PR merge then triggers `feature-merge-cleanup.yml`,
which deletes the Railway environment (including its Postgres instance and
bucket) and feature branch. The separate `feature-branch-cleanup.yml` workflow
serves as a fallback if a feature branch is deleted manually (e.g., without
going through a PR).

**Gotcha:** Don't push to a merged branch. After `/mergedev`, both branches
are deleted remotely. Pushing again re-creates everything from scratch.

**`/release` after `/mergedev` in the same chat is fine.** The release skill
works on `dev` (stash, switch, commit, push, return) and never pushes the
`claude/` branch, so it does not re-trigger feature branch creation. No
need to start a new chat for a release.

## Releasing to production

Use `/release` (with optional `major`, `minor`, or `patch` argument) to ship
dev to production. This creates a release PR from `dev` → `main`, tags the
version, and generates a GitHub Release with notes. The production Railway
environment deploys automatically from main. For emergencies, use `/hotfix`
to go directly from main with a fast-track patch release.

## CI checks

Configure CI checks by adding a `check:` field to `.harness-version`:

```
check: npm test && npm run lint
```

When set, PRs to dev (and main) run the check command, and merges wait for
checks to pass. See `.claude/HARNESS.md` for prerequisites.

## Team configuration

Optional `.harness-version` fields:

```
reviewers: teammate1, teammate2
check: npm test && npm run lint
```

## Available skills

Run `/getting-started` to see all skills, or use these directly:
- `/feature`: start a new feature (optional; auto-initializes on session start)
- `/mergedev`: merge to dev (auto-merge)
- `/review`: submit PR for team review
- `/release`: ship dev to production
- `/hotfix`: emergency production fix
- `/status`: team dashboard (with Railway preview URLs)
- `/changelog`: generate changelog
- `/deps`: handle Dependabot PRs
- `/continue`: resume in-progress feature
- `/rollback`: revert bad deploy
- `/chat`: think and brainstorm without modifying the repo (the session-start
  hook still creates an empty `feature/<name>` branch on GitHub; pair with
  `/endchat` to clean up)
- `/endchat`: clean up after `/chat` (deletes the orphaned `feature/<name>`
  branch and switches local back to `dev`)

## Dependency management

Dependabot is configured in `.github/dependabot.yml` to automatically check
for outdated dependencies and open PRs to update them. When you add a new
package ecosystem to the project (e.g., npm, pip, Docker, Bundler), add a
corresponding entry to `.github/dependabot.yml` so Dependabot monitors it.


## Stack best practices

If you have installed managed traits via the harness, add this line:

```
Read `.claude/traits/` for stack-specific best practices before writing code.
```

Trait files in `.claude/traits/` are managed by the harness and updated via
`/harness-upgrade`. Configure which traits to track in `.harness-version`:

```
traits: nodejs, typescript, express, vitest, eslint, pnpm
```
