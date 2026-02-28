#!/bin/bash

# Verify we're inside a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: not inside a git repository"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
REPO_PARENT="$(dirname "$REPO_ROOT")"

usage() {
  echo "Usage: $(basename "$0") <branch-name>"
  echo "       $(basename "$0") --remove <branch-name>"
  exit 1
}

# --remove mode
if [[ "$1" == "--remove" ]]; then
  [[ $# -ne 2 ]] && usage
  BRANCH_NAME="$2"
  WORKTREE_PATH="$REPO_PARENT/$REPO_NAME-$BRANCH_NAME"
  if ! git worktree list --porcelain | grep -q "^worktree $WORKTREE_PATH"; then
    echo "Error: no worktree found at $WORKTREE_PATH"
    exit 1
  fi
  git worktree remove "$WORKTREE_PATH"
  echo "Worktree removed: $WORKTREE_PATH"
  exit 0
fi

[[ $# -ne 1 ]] && usage

BRANCH_NAME="$1"
WORKTREE_PATH="$REPO_PARENT/$REPO_NAME-$BRANCH_NAME"

# Check if worktree already exists
if git worktree list --porcelain | grep -q "^worktree $WORKTREE_PATH"; then
  echo "Worktree already exists at $WORKTREE_PATH"
  exit 0
fi

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
