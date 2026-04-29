#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: runs after `git push` on claude/ branches.
# Shows Railway preview URL and waits for deployment to complete.
# Stdout from PostToolUse hooks is added to Claude's context.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on pushes to claude/ branches
if ! echo "$COMMAND" | grep -q 'git push'; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ ! "$BRANCH" == claude/* ]]; then
  exit 0
fi

# Derive feature branch name: claude/dark-mode-abc123 → feature/dark-mode
WITHOUT_PREFIX="${BRANCH#claude/}"
FEATURE_NAME="${WITHOUT_PREFIX%-*}"
FEATURE_BRANCH="feature/$FEATURE_NAME"

# Try to get the URL (may already exist from a previous push)
git fetch origin "$FEATURE_BRANCH" 2>/dev/null || true
URL=$(git show "origin/$FEATURE_BRANCH:.railway-url" 2>/dev/null || echo "")

if [[ -z "$URL" ]]; then
  # First push: poll for .railway-url (GitHub Action needs time to create env)
  echo ""
  echo "Waiting for Railway preview environment..."
  WAITS=(5 5 10 10 15 15 20)
  for WAIT in "${WAITS[@]}"; do
    sleep "$WAIT"
    git fetch origin "$FEATURE_BRANCH" 2>/dev/null || continue
    URL=$(git show "origin/$FEATURE_BRANCH:.railway-url" 2>/dev/null || echo "")
    if [[ -n "$URL" ]]; then
      break
    fi
  done
fi

if [[ -z "$URL" ]]; then
  echo ""
  echo "Railway preview URL not yet available. The GitHub Action may still be provisioning."
  echo "Check: git fetch origin $FEATURE_BRANCH && git show origin/$FEATURE_BRANCH:.railway-url"
  exit 0
fi

echo ""
echo "=========================================="
echo "  Railway preview: $URL"
echo "  Deploying... (typically 30-120s)"
echo "=========================================="
exit 0
