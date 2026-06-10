---
name: feature
description: Name this session's feature and load previous work. Derives a meaningful name from your description so the branch and Railway environment are created under it instead of the random codename.
disable-model-invocation: true
argument-hint: "<description of what to build>"
---

# Feature

Name this session's feature from a description and make sure previous work is
loaded. Naming is the important part: it sets `.harness-feature` so the GitHub
Action creates `feature/<slug>` and provisions Railway under a meaningful name
instead of the random session codename.

Session startup no longer auto-initializes a feature branch; provisioning now
happens on your first push. This skill makes that first push a well-named one.

`$ARGUMENTS` contains the description of what to build.

## Steps

### 1. Check preconditions

```
BRANCH=$(git branch --show-current)
```

If the branch does NOT start with `claude/`, tell the user this skill only
works on `claude/` branches and stop.

### 2. Name the feature

Derive a short kebab-case slug from `$ARGUMENTS` (for example "fix the login
seed bug" becomes `fix-login-seed`) and set it:

```
bash .claude/scripts/set-feature-name.sh <slug>
```

This writes `.harness-feature`, commits it, and pushes, which triggers the
GitHub Action to create `feature/<slug>` and provision Railway under that
name. It is idempotent: if the name is already set to the same slug, it is a
no-op.

Resolve the canonical feature branch name for the rest of this skill:

```
FEATURE_NAME=$(bash .claude/scripts/resolve-feature-name.sh "$BRANCH")
FEATURE_BRANCH="feature/$FEATURE_NAME"
```

### 3. Pick up previous work (resume)

If a feature branch already exists on the remote (a resumed session), merge it
into the local branch to pick up previous work:

```
git fetch origin "$FEATURE_BRANCH" 2>/dev/null && git merge "origin/$FEATURE_BRANCH" --no-edit
```

Then show the Railway preview URL if one is already published:

```
git show "origin/$FEATURE_BRANCH:.railway-url" 2>/dev/null || echo "URL not yet available"
```

### 4. Do the work

Execute everything described in `$ARGUMENTS`. This is the main phase: write
code, create files, fix bugs, refactor, whatever the user asked for.

Commit meaningful changes as you go with descriptive commit messages.

### 5. Final push

After all work is complete, ensure everything is committed and pushed:

```
git push -u origin "$BRANCH"
```

A PostToolUse hook will try to display the Railway preview URL, but hook
output is often not visible in context. You MUST fetch it manually in the
next step.

### 6. Summary (REQUIRED, do not skip)

**You MUST run this command** to get the Railway preview URL:

```
bash .claude/scripts/get-railway-url.sh
```

The helper resolves `feature/<name>` from the current `claude/` branch (slug
from `.harness-feature`, else codename), polls until `.railway-url` is
published, and prints the URL. If provisioning is still running when it
returns empty, just re-run it; the publishing step is idempotent and
self-healing, so a later run on the same branch will commit the missing URL.

This is the primary way the user sees their preview URL. The post-push hook is
unreliable. Always run the helper and include the URL in your summary.

Summarize what was done and which files were changed. Include the Railway
preview URL. Mention the user can use `/mergedev` when ready to merge to dev.
