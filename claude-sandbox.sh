#!/bin/bash
# Launch a sandboxed Claude Code session inside the Docker container.
# Must be run from a git worktree (not the main working tree).
#
# Flags:
#   --allow-git-writes   Mount the main .git directory read-write (needed for git add/commit).
#   --with-skills        Mount ~/.claude/skills read-only into the container.
#   --safe               Launch without --dangerously-skip-permissions (uses permission prompts).
#   --update             Run `claude update` synchronously before starting; new version takes
#                        effect this session. Resets the daily background-update timer.
#   All other flags      Passed through to `claude` inside the container.
#                        E.g.: claude-sandbox --bare -p "do X"
#                              claude-sandbox -n "my-session"
#                              claude-sandbox --from-pr 123

ALLOW_GIT_WRITES=false
WITH_SKILLS=false
SAFE_MODE=false
FORCE_UPDATE=false
REMAINING_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --allow-git-writes) ALLOW_GIT_WRITES=true ;;
    --with-skills)      WITH_SKILLS=true ;;
    --safe)             SAFE_MODE=true ;;
    --update)           FORCE_UPDATE=true ;;
    *)                  REMAINING_ARGS+=("$arg") ;;
  esac
done

ENV_ARGS=()
EXTRA_MOUNTS=()

# Require a linked git worktree
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$GIT_TOPLEVEL" || ! -f "$GIT_TOPLEVEL/.git" ]]; then
  echo "Error: claude-sandbox must be run from a git worktree (use worktree.sh to create one)" >&2
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
    line="${line#export }"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key="${line%%=*}"
    key="${key// /}"
    [[ -z "$key" ]] && continue
    value="${line#*=}"
    # Strip surrounding double or single quotes from values
    [[ "$value" =~ ^\"(.*)\"$ ]] && value="${BASH_REMATCH[1]}"
    [[ "$value" =~ ^\'(.*)\'$ ]] && value="${BASH_REMATCH[1]}"
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

if [[ "$ALLOW_GIT_WRITES" == true ]]; then
  GIT_MOUNT="$MAIN_GIT_DIR:$MAIN_GIT_DIR"
  GIT_WRITES_ENV="-e GIT_WRITES_ENABLED=1"
else
  GIT_MOUNT="$MAIN_GIT_DIR:$MAIN_GIT_DIR:ro"
  GIT_WRITES_ENV="-e GIT_WRITES_ENABLED=0"
fi

if [[ "$WITH_SKILLS" == true ]]; then
  EXTRA_MOUNTS+=(-v "$HOME/.claude/skills:/home/claude/.claude/skills:ro")
fi

if [[ "$SAFE_MODE" == true ]]; then
  ENTRYPOINT_ARGS=(--safe)
else
  ENTRYPOINT_ARGS=()
fi

if [[ "$FORCE_UPDATE" == true ]]; then
  ENTRYPOINT_ARGS+=(--update)
fi

docker run -it --rm \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 512 \
  --memory 8g --memory-swap 8g \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  -v "$(pwd):/workspace" \
  -v "$GIT_MOUNT" \
  -v "$HOME/Documents/Code/_references:/references:ro" \
  -v "claude-sandbox-config:/home/claude/.claude" \
  -v "claude-sandbox-local:/home/claude/.local" \
  -v "claude-sandbox-keyrings:/home/claude/.local/share/keyrings" \
  -v "$HOME/.claude-sandbox.json:/home/claude/.claude.json" \
  "${EXTRA_MOUNTS[@]}" \
  $GIT_WRITES_ENV \
  "${ENV_ARGS[@]}" \
  -w /workspace \
  claude-sandbox \
  /home/claude/entrypoint.sh "${ENTRYPOINT_ARGS[@]}" "${REMAINING_ARGS[@]}"
