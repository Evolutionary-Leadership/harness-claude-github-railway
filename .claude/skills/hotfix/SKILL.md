---
name: hotfix
description: Emergency production fix. Branch from main, fix, PR to main, auto-tag patch release, back-merge to dev. Production Railway redeploys automatically.
disable-model-invocation: true
argument-hint: "<description of the fix needed>"
allowed-tools: Bash(git *), Bash(gh *), Read, Write, Edit, Glob, Grep
---

# Hotfix: emergency production fix

Create a hotfix branch from `main`, apply the fix, and trigger a fast-track
release directly to production. Bypasses the normal feature → dev → release flow.
Production Railway environment redeploys automatically when main is updated.

## Steps

### 1. Create hotfix branch

    git fetch origin main
    git checkout -b hotfix/<name> origin/main

Derive `<name>` from `$ARGUMENTS`. Slugify it (lowercase, hyphens, no spaces).

### 2. Apply the fix

Do the work the user described. Keep changes minimal; a hotfix should fix the
specific issue and nothing else.

### 3. Determine next patch version

    LAST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "v0.0.0")
    # Bump patch: v1.2.3 → v1.2.4

### 4. Write `.pr-description.md`

Create the signal file with `hotfix: true` in frontmatter:

    ---
    title: "Hotfix: <description>"
    hotfix: true
    version: v1.2.4
    ---

    ## Hotfix: <description>

    ### Problem
    - What broke in production

    ### Fix
    - What this hotfix changes

    ### Risk assessment
    - Impact and scope of the change

### 5. Commit and push

    git add -A
    git commit -m "hotfix: <description>"
    git push -u origin hotfix/<name>

### 6. Inform the user

Tell the user:
- The hotfix workflow will create a PR from `hotfix/<name>` → `main`
- After merge, version `$NEW_VERSION` will be tagged automatically
- A GitHub Release will be created marked as a hotfix
- The production Railway environment will redeploy automatically
- `main` will be back-merged into `dev` to prevent drift
