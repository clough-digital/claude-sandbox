#!/bin/bash
# PreToolUse hook — enforces the sandbox rule that outbound HTTP must go to Anthropic or
# explicitly allowlisted hosts. Receives a JSON tool call on stdin; extracts the URL from
# the bash command, checks it against the allowlist, and returns a deny decision for anything
# outside the list.
#
# Add entries to the allowlist below as needed (e.g. internal package registries).
set -euo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Extract the first URL from the command string
URL=$(printf '%s' "$COMMAND" | grep -oE 'https?://[^[:space:]"'"'"'\\]+' | head -n1 || true)

# No URL found — not an HTTP call, allow it
[[ -z "$URL" ]] && exit 0

case "$URL" in
  https://api.anthropic.com/* | \
  https://statsig.anthropic.com/* | \
  https://sentry.io/* | \
  https://claude.ai/* | \
  https://code.claude.com/* | \
  https://downloads.claude.ai/* | \
  https://storage.googleapis.com/claude-code-dist-* | \
  https://registry.npmjs.org/* | \
  https://github.com/* | \
  https://raw.githubusercontent.com/* | \
  https://api.github.com/* | \
  https://objects.githubusercontent.com/*)
    exit 0 ;;
  http://*)
    printf '{"decision":"deny","reason":"Plain HTTP is blocked in sandbox. Use HTTPS."}\n'
    exit 0 ;;
  *)
    printf '{"decision":"deny","reason":"Blocked outbound HTTPS to %s — not in sandbox allowlist (/home/claude/hooks/block-non-anthropic-http.sh)."}\n' "$URL"
    exit 0 ;;
esac
