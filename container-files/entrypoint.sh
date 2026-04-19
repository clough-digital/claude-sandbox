#!/bin/bash
# Entrypoint for the claude-sandbox container.
# Usage: entrypoint.sh [--safe] [<claude-flags>...]
#   --safe   Launch claude without --dangerously-skip-permissions.
#            All other args are forwarded to claude.

SAFE_MODE=false
CLAUDE_ARGS=()

for arg in "$@"; do
  if [[ "$arg" == "--safe" ]]; then
    SAFE_MODE=true
  else
    CLAUDE_ARGS+=("$arg")
  fi
done

# Start a D-Bus session (required by gnome-keyring)
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null)

# Initialize/unlock gnome-keyring with empty password (headless).
# --daemonize forks and writes GNOME_KEYRING_CONTROL=... to stdout; eval exports it
# so that libsecret/keytar can find the socket.
eval "$(printf '' | /usr/bin/gnome-keyring-daemon --unlock --components=secrets --daemonize 2>/dev/null)"
export GNOME_KEYRING_CONTROL

# Check for Claude Code updates at most once per day, in the background.
# The updated binary lands in the persisted claude-sandbox-local volume and is
# picked up on the NEXT launch. Non-blocking so startup is never delayed.
# Skip if CLAUDE_CODE_SKIP_UPDATE=1 is set (useful for offline use).
if [[ "${CLAUDE_CODE_SKIP_UPDATE:-0}" != "1" ]]; then
  STAMP="/home/claude/.claude/.last-update-check"
  if [[ ! -f "$STAMP" ]] || [[ -n "$(find "$STAMP" -mtime +0 2>/dev/null)" ]]; then
    touch "$STAMP"
    (claude update >/dev/null 2>&1 &)
  fi
fi

if [[ "$SAFE_MODE" == true ]]; then
  exec claude "${CLAUDE_ARGS[@]}"
else
  exec claude --dangerously-skip-permissions "${CLAUDE_ARGS[@]}"
fi
