#!/bin/bash
# push.sh — Review and push all local changes to GitHub
# Usage: ./push.sh
# Usage with message: ./push.sh "your commit message"

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "================================================"
echo "📂 Repo: $(git remote get-url origin)"
echo "🌿 Branch: $(git branch --show-current)"
echo "================================================"

# Check if there are any changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "✅ Nothing to commit — working tree clean."
  exit 0
fi

echo ""
echo "📋 Changes to be committed:"
echo "------------------------------------------------"
git status --short
echo "------------------------------------------------"
echo ""
echo "📊 Diff summary:"
git diff --stat
git diff --cached --stat
echo ""

# Prompt for commit message if not provided
if [ -n "$1" ]; then
  COMMIT_MSG="$1"
else
  read -p "✏️  Enter commit message: " COMMIT_MSG
  if [ -z "$COMMIT_MSG" ]; then
    echo "❌ Commit message cannot be empty. Aborting."
    exit 1
  fi
fi

echo ""
echo "🚀 Preparing to push with message: \"$COMMIT_MSG\""
read -p "   Confirm? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "❌ Aborted."
  exit 1
fi

echo ""
echo "➕ git add -A ..."
git add -A

echo "💾 git commit ..."
git commit -m "$COMMIT_MSG"

echo "📤 git push ..."
git push

echo ""
echo "✅ Successfully pushed to $(git remote get-url origin)"
echo "🔗 Branch: $(git branch --show-current)"
