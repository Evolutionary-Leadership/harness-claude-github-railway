---
name: feature
description: Start working on a feature. Session startup already initializes the branch and Railway environment automatically; this skill is only needed if you want to explicitly name the task.
disable-model-invocation: true
argument-hint: "<description of what to build>"
---

# Feature

Work on a feature. The session-start hook automatically initializes new
feature branches (pushes an init commit, triggers Railway environment
provisioning). This skill is a convenience wrapper; use it when you want
to explicitly describe what to build, or as a fallback if auto-init was
skipped.

`$ARGUMENTS` contains the description of what to build.

## Steps

### 1. Check preconditions

```
BRANCH=$(git branch --show-current)
```

If the branch does NOT start with `claude/`, tell the user this skill only
works on `claude/` branches and stop.

Derive the feature name:

```
# claude/dark-mode-abc123 → dark-mode → feature/dark-mode
WITHOUT_PREFIX="${BRANCH#claude/}"
FEATURE_NAME="${WITHOUT_PREFIX%-*}"
FEATURE_BRANCH="feature/$FEATURE_NAME"
```

### 2. Ensure feature is initialized

Check if the feature branch already exists on the remote:

```
git fetch origin "$FEATURE_BRANCH" 2>/dev/null
```

**If it already exists**, merge it into the local branch to pick up previous
work:

```
git merge "origin/$FEATURE_BRANCH" --no-edit
```

Fetch and display the Railway preview URL:

```
git show "origin/$FEATURE_BRANCH:.railway-url" 2>/dev/null || echo "URL not yet available"
```

**If it does NOT exist**, check whether session-start already pushed an init
commit by looking for `.harness-init`:

```
git log --oneline -1 --grep="initialize feature branch"
```

If no init commit exists, do the initialization now (fallback):

```
if [ -f ".pr-description.md" ]; then
  git rm .pr-description.md
  git commit -m "chore: clean up stale signal file from previous merge"
fi

git config user.name "claude-code[bot]" 2>/dev/null || true
git config user.email "claude-code[bot]@users.noreply.github.com" 2>/dev/null || true
date -u > .harness-init
git add .harness-init
git commit -m "chore: initialize feature branch ($FEATURE_NAME)"
git push -u origin "$BRANCH"
```

If push fails, retry in the background (2s, 4s, 8s delays) so Claude can
start working immediately.

### 3. Do the work

Execute everything described in `$ARGUMENTS`. This is the main phase: write
code, create files, fix bugs, refactor, whatever the user asked for.

Commit meaningful changes as you go with descriptive commit messages.

### 4. Final push

After all work is complete, ensure everything is committed and pushed:

```
git push -u origin "$BRANCH"
```

A PostToolUse hook will try to display the Railway preview URL, but hook
output is often not visible in context. You MUST fetch it manually in
the next step.

### 5. Summary (REQUIRED, do not skip)

**You MUST run this command** to get the Railway preview URL:

```
git fetch origin $FEATURE_BRANCH && git show origin/$FEATURE_BRANCH:.railway-url
```

This is the primary way the user sees their preview URL. The post-push
hook is unreliable. Always run this command and include the URL in your
summary.

Summarize what was done and which files were changed. Include the Railway
preview URL. Mention the user can use `/mergedev` when ready to merge to dev.
