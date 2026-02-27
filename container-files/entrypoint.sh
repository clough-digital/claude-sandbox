#!/bin/bash

# Start a D-Bus session (required by gnome-keyring)
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null)

# Initialize/unlock gnome-keyring with empty password (headless).
# --daemonize forks and writes GNOME_KEYRING_CONTROL=... to stdout; eval exports it
# so that libsecret/keytar can find the socket.
eval "$(printf '' | /usr/bin/gnome-keyring-daemon --unlock --components=secrets --daemonize 2>/dev/null)"
export GNOME_KEYRING_CONTROL

exec claude --dangerously-skip-permissions "$@"
