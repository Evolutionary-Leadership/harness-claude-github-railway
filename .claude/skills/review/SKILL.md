---
name: review
description: Submit a PR for team review (without auto-merge). Use when the user says "submit for review", "create a PR", or invokes /review.
disable-model-invocation: true
argument-hint: "[optional: PR title]"
allowed-tools: Bash(git *), Read, Write, Glob, Grep
---

# Submit for review

Create a PR from the current feature branch to dev for team review. Unlike
`/mergedev`, this does NOT auto-merge; the PR stays open for human review.

Uses the same `.pr-description.md` signal file pattern as `/mergedev`, but
with `review: true` in frontmatter so the workflow skips auto-merge.

## Steps

### 1. Determine the feature name

    BRANCH=$(git branch --show-current)
    # Strip claude/ prefix and -<sessionId> suffix
    # e.g. claude/dark-mode-abc123 → dark-mode

Derive the feature branch name: `feature/<name>`.

### 2. Gather all changes

Fetch and diff against dev to understand what's being submitted:

    git fetch origin dev
    git log origin/dev..HEAD --oneline
    git diff origin/dev..HEAD --stat

Also check if a `feature/<name>` branch exists and include its commits:

    git fetch origin feature/<name> 2>/dev/null
    git log origin/dev..origin/feature/<name> --oneline 2>/dev/null

Review ALL changes (not just the latest commit) to write an accurate PR
description.

### 3. Write `.pr-description.md`

Create `.pr-description.md` at the repo root. If `$ARGUMENTS` is provided, use
it as the PR title. Otherwise, generate a concise title from the changes.

**Important:** Include `review: true` in the frontmatter to prevent auto-merge.

Optionally read the `reviewers:` field from `.harness-version` and include it.

Also include the Railway preview URL in the PR body so reviewers can test:

    FEATURE_BRANCH="feature/<name>"
    PREVIEW_URL=$(git show "origin/$FEATURE_BRANCH:.railway-url" 2>/dev/null || echo "")

Format:

    ---
    title: Short PR title (under 70 characters)
    review: true
    reviewers: teammate1, teammate2
    ---

    ## Summary
    - 3-5 bullet points explaining what changed and why

    **Preview:** https://feature-dark-mode-production.up.railway.app

    ## What's new
    - User-facing changes described in plain language

    ## Technical changes
    - Key implementation details, files changed, architectural decisions

    ## How to test
    - Steps to verify the feature works correctly
    - Include the Railway preview URL for live testing

### 4. Commit and push

    git add .pr-description.md
    git commit -m "chore: submit for review"
    git push -u origin <current-branch>

### 5. Inform the user

Tell the user:
- A PR has been created from `feature/<name>` → `dev` for review
- The PR will NOT be auto-merged; it requires human approval
- If reviewers were configured, they have been assigned
- The Railway preview environment stays active for reviewers to test
- Share the PR URL once the workflow creates it

### 6. Generate session summary

Generate a flat, easy-to-copy-paste session summary under the heading
"Session Summary (copy-paste into your next session)" as a fenced text block.
Include ALL sections:

    SESSION SUMMARY: [Feature Name]
    Branch: claude/[branch-name] → feature/[name] → PR open for review
    Date: [today's date]

    WHAT WAS DONE (in order):
    WHAT WORKED:
    WHAT DIDN'T WORK:
    KEY DECISIONS:
    FILES CHANGED:
    CURRENT STATE:
    OPEN QUESTIONS / NEXT STEPS:
