#!/bin/bash

ENV_ARGS=()

# Require a linked git worktree
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_TOPLEVEL" || ! -f "$GIT_TOPLEVEL/.git" ]]; then
  echo "Error: sandbox.sh must be run from a git worktree (use worktree.sh to create one)"
  exit 1
fi

# Find .env or .envrc in current directory
ENV_FILE=""
if [[ -f .env ]]; then
  ENV_FILE=".env"
elif [[ -f .envrc ]]; then
  ENV_FILE=".envrc"
fi

# Build -e flags from env file variables
if [[ -n "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    line="${line#export }"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Extract variable name
    key="${line%%=*}"
    key="${key// /}"
    [[ -z "$key" ]] && continue
    ENV_ARGS+=(-e "$key=${!key}")
  done < "$ENV_FILE"
fi

docker run -it --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/Documents/Code/_references:/references:ro" \
  -v "claude-sandbox-config:/home/claude/.claude" \
  "${ENV_ARGS[@]}" \
  -w /workspace \
  claude-sandbox \
  claude --dangerously-skip-permissions
