---
name: release
description: Ship dev to production. Create a release PR, tag a version, and generate a GitHub Release. Production Railway deploys automatically.
disable-model-invocation: true
argument-hint: "[optional: major|minor|patch (default: patch)]"
allowed-tools: Bash(git *), Read, Write, Glob, Grep
---

# Release to production

Push a release commit directly to dev. The `release.yml` workflow then creates
a PR from dev → main, merges it, tags the version, and creates a GitHub Release.

**Important:** This skill pushes directly to dev. It does NOT go through
the mergedev workflow chain.

## Steps

### 1. Preflight checks

    CURRENT_BRANCH=$(git branch --show-current)

Abort with a clear message if the current branch is `main`; you cannot
release from main.

### 2. Determine version

    git fetch origin dev main --tags

Get the last release tag:

    LAST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "v0.0.0")

Parse the version type from `$ARGUMENTS` (default: `patch`):
- `major` → bump major (e.g., v1.2.3 → v2.0.0)
- `minor` → bump minor (e.g., v1.2.3 → v1.3.0)
- `patch` → bump patch (e.g., v1.2.3 → v1.2.4)

Calculate the new version accordingly.

### 3. Check for changes

    git log "$LAST_TAG"..origin/dev --oneline

If there are no commits between the last tag and origin/dev, abort with:
"Nothing to release: dev and main are at the same point."

### 4. Generate release notes

Gather commit messages and categorize them into:
- **Features**: new functionality (commits containing "feat", "add", "new")
- **Fixes**: bug fixes (commits containing "fix", "bug", "patch")
- **Improvements**: everything else (refactors, chores, docs, etc.)

Keep notes concise. Use commit subject lines only.

### 5. Update CHANGELOG.md

Checkout the current CHANGELOG.md from dev:

    git show origin/dev:CHANGELOG.md > CHANGELOG.md 2>/dev/null || echo ""

If CHANGELOG.md exists, prepend the new release section after the `# Changelog`
heading. If not, create it.

Format:

    # Changelog

    ## [v1.3.0] - YYYY-MM-DD

    ### Features
    - Dark mode toggle (#45)

    ### Fixes
    - Fix login redirect (#43)

    ### Improvements
    - Refactor auth module

### 6. Write `.release-description.md`

Create a single signal file at the repo root (NOT `.pr-description.md`):

    ---
    version: v1.3.0
    type: minor
    ---

    ## Release v1.3.0

    ### Features
    - Dark mode toggle (#45)

    ### Fixes
    - Fix login redirect bug (#43)

### 7. Commit and push directly to dev

This is the critical step. Push directly to dev; do NOT push to the
current claude/ branch.

**Concrete procedure** (follow exactly):

1. Write CHANGELOG.md and .release-description.md to the repo root first
2. Stage them: `git add CHANGELOG.md .release-description.md`
3. Stash everything (including staged files): `git stash --include-untracked`
4. Switch to dev: `git checkout dev`
5. Pull latest: `git pull origin dev`
6. Restore the two files from stash: `git checkout stash -- CHANGELOG.md .release-description.md`
7. Commit: `git commit -m "chore: release $NEW_VERSION"`
8. Push: `git push origin dev`
9. Clean up orphaned branches (session-start auto-creates `feature/<name>`,
   and the source `claude/<name>` may still exist if `claude-to-feature-branch.yml`
   failed or was skipped):
   `if [[ "$CURRENT_BRANCH" == claude/* ]]; then WITHOUT_PREFIX="${CURRENT_BRANCH#claude/}"; FEATURE_NAME="${WITHOUT_PREFIX%-*}"; git push origin --delete "feature/$FEATURE_NAME" 2>/dev/null || true; git push origin --delete "$CURRENT_BRANCH" 2>/dev/null || true; fi`
10. Return: `git checkout "$CURRENT_BRANCH"`
11. Restore working state: `git stash pop || true`

**Note:** The session-start hook auto-creates a `feature/` branch and Railway
environment for every `claude/` session, and the source `claude/` branch is
normally deleted by `claude-to-feature-branch.yml`. Since the release skill
bypasses the feature branch chain entirely, step 9 cleans up both, in case
either survived (e.g. the cleanup workflow failed mid-run, or the release
file landed on `claude/` and triggered the `is_release` skip). Deleting
the remote `feature/` branch triggers `feature-branch-cleanup.yml`, which
removes any associated Railway environment automatically.

### 8. Inform the user

Tell the user:
- Release commit has been pushed directly to dev
- The `release.yml` workflow will now:
  1. Create a PR from dev → main
  2. Merge the PR
  3. Tag version `$NEW_VERSION` and create a GitHub Release
- Share the version number and key changes
- If main has branch protection with required checks, the merge will wait
  for checks to pass (auto-merge)
