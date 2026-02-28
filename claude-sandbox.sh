#!/bin/bash

ENV_ARGS=()

# Require a linked git worktree
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_TOPLEVEL" || ! -f "$GIT_TOPLEVEL/.git" ]]; then
  echo "Error: sandbox.sh must be run from a git worktree (use worktree.sh to create one)"
  exit 1
fi

# Extract the main repo's .git directory so git inside the container can
# resolve the worktree reference (the .git file points to an absolute host path)
GITDIR=$(sed 's/^gitdir: //' "$GIT_TOPLEVEL/.git")
MAIN_GIT_DIR=$(echo "$GITDIR" | sed 's|/\.git/worktrees/.*|/.git|')

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
    # Extract variable name and value from the file itself
    key="${line%%=*}"
    key="${key// /}"
    [[ -z "$key" ]] && continue
    value="${line#*=}"
    ENV_ARGS+=(-e "$key=$value")
  done < "$ENV_FILE"
fi

# Pass ANTHROPIC_API_KEY from host environment if not already included
if [[ -n "$ANTHROPIC_API_KEY" ]] && ! printf '%s\n' "${ENV_ARGS[@]}" | grep -q "ANTHROPIC_API_KEY="; then
  ENV_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
fi

# Ensure ~/.claude.json persistence file exists on host
# (Docker bind-mount requires a file; if absent it creates a directory instead)
touch "$HOME/.claude-sandbox.json"

docker run -it --rm \
  -v "$(pwd):/workspace" \
  -v "$MAIN_GIT_DIR:$MAIN_GIT_DIR:ro" \
  -v "$HOME/Documents/Code/_references:/references:ro" \
  -v "claude-sandbox-config:/home/claude/.claude" \
  -v "claude-sandbox-keyrings:/home/claude/.local/share/keyrings" \
  -v "$HOME/.claude-sandbox.json:/home/claude/.claude.json" \
  "${ENV_ARGS[@]}" \
  -w /workspace \
  claude-sandbox \
  /home/claude/entrypoint.sh
