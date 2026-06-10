---
name: mergedev
description: Merge the current feature branch into dev. Use when the user says "merge to dev", "merge into dev", or invokes /mergedev.
disable-model-invocation: true
argument-hint: "[optional: PR title]"
allowed-tools: Bash(git *), Read, Write, Glob, Grep
---

# Merge to dev

Merge the current feature into dev by creating the `.pr-description.md` signal
file, committing, and pushing. The GitHub Action (`claude-to-feature-branch.yml`)
handles PR creation and auto-merge.

## Steps

### 1. Determine the feature name

    BRANCH=$(git branch --show-current)
    FEATURE_NAME=$(bash .claude/scripts/resolve-feature-name.sh "$BRANCH")
    FEATURE_BRANCH="feature/$FEATURE_NAME"

This prefers the slug in `.harness-feature` (set via `set-feature-name.sh`)
and falls back to the random session codename, matching the workflows.

### 2. Gather all changes and sync with dev

Fetch and diff against dev to understand what's being merged:

    git fetch origin dev
    git log origin/dev..HEAD --oneline
    git diff origin/dev..HEAD --stat

Also check if a `feature/<name>` branch exists and include its commits:

    git fetch origin feature/<name> 2>/dev/null
    git log origin/dev..origin/feature/<name> --oneline 2>/dev/null

Review ALL changes (not just the latest commit) to write an accurate PR
description.

**Pre-empt merge conflicts with dev.** The workflow merges this branch into
`dev` through the PR; if `dev` has advanced in a conflicting way, the PR cannot
merge and the workflow leaves it open. Merge `dev` into the current branch now
so any conflict surfaces here, where you can resolve it, instead of stalling the
PR:

    git merge origin/dev --no-edit

If the merge succeeds cleanly, continue. If it reports conflicts, **resolve
them yourself on a best-effort basis** rather than aborting:

- List the conflicted files: `git diff --name-only --diff-filter=U`.
- For each one, reconcile the two sides so both this feature's intent and the
  incoming `dev` changes are preserved. Do not blindly discard either side.
- For generated, lock, or signal files, prefer the `dev` version.
- Stage the resolved files and finish the merge:

      git add -A
      git commit --no-edit

After resolving, **remember what you changed**: in your final message to the
user (step 6) note which files conflicted and how you resolved each one. A clean
merge needs no mention; only report conflicts you actually had to resolve. If a
conflict is genuinely ambiguous and you cannot resolve it safely (e.g. two
incompatible intents in the same hunk), stop and ask the user instead of
guessing.

### 3. Run docs-updater agent

Before writing the PR description, launch the docs-updater agent to ensure all
documentation reflects the changes being merged. Use the Agent tool:

    Launch the docs-updater agent with prompt:
    "Audit and update all project documentation for changes being merged to dev.
     This is a delta audit; focus on files changed since origin/dev.
     Update CLAUDE.md, README, architecture docs, .env.example, API docs,
     and any other documentation that needs to reflect the current codebase."

Wait for the agent to complete. If it committed documentation changes, those
changes will be included in the merge automatically.

### 4. Write `.pr-description.md`

Create `.pr-description.md` at the repo root. If `$ARGUMENTS` is provided, use
it as the PR title. Otherwise, generate a concise title from the changes.

Format:

    ---
    title: Short PR title (under 70 characters)
    ---

    ## Summary
    - 3-5 bullet points explaining what changed and why

    ## What's new
    - User-facing changes described in plain language

    ## Technical changes
    - Key implementation details, files changed, architectural decisions

    ## How to test
    - Steps to verify the feature works correctly

### 5. Commit and push

Push any pending feature work **first**, so the whole branch (including the
conflict resolution from step 2) is on the remote before the signal file
triggers the workflow:

    git push -u origin <current-branch>

Then add the signal file as its own commit and push it. `.pr-description.md`
is in `.gitignore` (it is a signal file, never committed to dev/main), so the
`-f` flag is required to stage it on the `claude/` branch:

    git add -f .pr-description.md
    git commit -m "chore: trigger auto-merge to dev"
    git push -u origin <current-branch>

### 6. Inform the user

Tell the user:
- The auto-merge has been triggered
- The GitHub Action will create a PR from `feature/<name>` → `dev` and merge it
- Any conflicts with `dev` were already resolved locally in step 2; report
  which files conflicted and how you resolved them. The PR should now merge
  cleanly. (If the workflow still cannot merge, it leaves a comment on the PR
  with manual resolution steps.)
- The feature branch will be cleaned up automatically
- They can stay in this chat and chain `/release` once the merge lands. The
  release skill works on `dev` and never re-pushes the `claude/` branch, so
  it will not re-trigger feature branch creation.

### 7. If the workflow fails

If the GitHub Actions run for this push fails, the recovery path depends on
where it broke. Open the Actions tab in GitHub and find the run titled
"Merge feature branch to dev (mergedev)" triggered by the `claude/<branch>`
push.

Common failure modes:

- **Workflow run failed mid-step** (e.g. a transient git push race): re-push
  the local `claude/` branch with `git push -u origin <branch>`. If the remote
  `claude/` branch was already deleted by `claude-to-feature-branch.yml`, the
  push creates a fresh branch and retriggers the chain. The workflow is
  idempotent, so re-runs do not duplicate commits or work.
- **PR opened but could not auto-merge** (conflicts with dev): the workflow
  leaves a comment on the PR with manual resolution steps. Check out
  `feature/<name>` locally, merge `dev` into it, resolve the conflicts, push,
  and merge the PR by hand.
- **PR did not open at all**: the workflow errored before PR creation. Read
  the failed step's logs in the Actions tab. Most common cause: a missing or
  empty `PAT_TOKEN` secret. The workflow now fails fast with an explicit
  `::error::PAT_TOKEN is missing or empty...` annotation pointing at
  Settings → Secrets and variables → Actions; the PAT needs `repo` and
  `workflow` scopes (or fine-grained equivalent: Contents r/w, Pull
  requests r/w, Workflows r/w). Other causes: branch protection on `dev`
  that requires explicit reviewers. **Recovery when `PAT_TOKEN` was
  missing**: add the secret, then re-push the `claude/` branch
  (`git push -u origin <branch>`) to retrigger. Because cleanup now runs
  *after* PR creation, the signal file is still on `feature/<name>` and
  the rerun picks up cleanly.

Do not confuse the recovery push above with the gotcha already documented in
`CLAUDE.md`: after a successful merge, both the `claude/` and `feature/`
branches are deleted remotely, and pushing again re-creates everything from
scratch. That warning applies to post-success pushes, not to recovery from a
failed workflow run.

### 8. Generate session summary

Generate a flat, easy-to-copy-paste session summary under the heading
"Session Summary (copy-paste into your next session)" as a fenced text block.
Include ALL sections:

    SESSION SUMMARY: [Feature Name]
    Branch: claude/[branch-name] → feature/[name] → merged to dev
    Date: [today's date]

    WHAT WAS DONE (in order):
    WHAT WORKED:
    WHAT DIDN'T WORK:
    KEY DECISIONS:
    FILES CHANGED:
    CURRENT STATE:
    OPEN QUESTIONS / NEXT STEPS:

### 9. Update memory files if warranted

If the session revealed broadly useful lessons (new conventions, gotchas, etc.),
update CLAUDE.md. Do NOT add feature-specific WIP notes.
