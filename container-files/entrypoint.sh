#!/bin/bash
# Entrypoint for the claude-sandbox container.
# Usage: entrypoint.sh [--safe] [--update] [<claude-flags>...]
#   --safe     Launch claude without --dangerously-skip-permissions.
#   --update   Run `claude update` synchronously before starting; new version takes
#              effect this session. Resets the daily background-update timer.
#   All other args are forwarded to claude.

SAFE_MODE=false
FORCE_UPDATE=false
CLAUDE_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --safe)   SAFE_MODE=true ;;
    --update) FORCE_UPDATE=true ;;
    *)        CLAUDE_ARGS+=("$arg") ;;
  esac
done

# Start a D-Bus session (required by gnome-keyring)
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null)

# Initialize/unlock gnome-keyring with empty password (headless).
# --daemonize forks and writes GNOME_KEYRING_CONTROL=... to stdout; eval exports it
# so that libsecret/keytar can find the socket.
eval "$(printf '' | /usr/bin/gnome-keyring-daemon --unlock --components=secrets --daemonize 2>/dev/null)"
export GNOME_KEYRING_CONTROL

STAMP="/home/claude/.claude/.last-update-check"

if [[ "$FORCE_UPDATE" == true ]]; then
  # Synchronous update: runs before exec so the new binary is in effect this session.
  echo "Checking for Claude Code updates..."
  claude update
  touch "$STAMP"
elif [[ "${CLAUDE_CODE_SKIP_UPDATE:-0}" != "1" ]]; then
  # Check for updates at most once per day, in the background.
  # The updated binary lands in the persisted claude-sandbox-local volume and is
  # picked up on the NEXT launch. Non-blocking so startup is never delayed.
  if [[ ! -f "$STAMP" ]] || [[ -n "$(find "$STAMP" -mtime +0 2>/dev/null)" ]]; then
    touch "$STAMP"
    (claude update >/dev/null 2>&1 &)
  fi
fi

claude --version

if [[ "$SAFE_MODE" == true ]]; then
  exec claude "${CLAUDE_ARGS[@]}"
else
  exec claude --dangerously-skip-permissions "${CLAUDE_ARGS[@]}"
fi
