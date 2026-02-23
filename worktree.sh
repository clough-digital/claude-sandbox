#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <branch-name>"
  exit 1
fi

BRANCH_NAME="$1"

# Verify we're inside a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: not inside a git repository"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
REPO_PARENT="$(dirname "$REPO_ROOT")"
WORKTREE_PATH="$REPO_PARENT/$REPO_NAME-$BRANCH_NAME"

# Create worktree, creating the branch if it doesn't exist
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
  git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

# Copy .env or .envrc into the new worktree
ENV_FILE=""
if [[ -f "$REPO_ROOT/.env" ]]; then
  ENV_FILE="$REPO_ROOT/.env"
elif [[ -f "$REPO_ROOT/.envrc" ]]; then
  ENV_FILE="$REPO_ROOT/.envrc"
fi

if [[ -n "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "$WORKTREE_PATH/"
  echo "Copied $(basename "$ENV_FILE") to $WORKTREE_PATH"
fi

echo "Worktree created at $WORKTREE_PATH"

cd "$WORKTREE_PATH"