#!/bin/bash
# Build the claude-sandbox Docker image.
# Usage: ./build.sh [--version <claude-code-version>] [--clean]
# Default: fetches the latest Claude Code release from GitHub.
# --clean: removes the claude-sandbox-config volume before building (auth is preserved).
# Example: ./build.sh --version 2.1.138
set -euo pipefail

VERSION=""
SOURCE=""
CLEAN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      SOURCE="pinned via --version"
      shift 2 ;;
    --clean)
      CLEAN=1
      shift ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--version <version>] [--clean]" >&2
      exit 1 ;;
  esac
done

if [[ "$CLEAN" -eq 1 ]]; then
  echo "WARNING: --clean removes the claude-sandbox-config volume."
  echo "  This wipes accumulated auto-memory and any in-container settings edits."
  echo "  Auth credentials (keyrings volume + ~/.claude-sandbox.json) are NOT affected."
  if docker volume inspect claude-sandbox-config &>/dev/null; then
    # Stop and remove any containers referencing the volume so rm doesn't fail silently
    containers=$(docker ps -aq --filter volume=claude-sandbox-config)
    if [[ -n "$containers" ]]; then
      echo "  Stopping containers using the volume: $containers"
      docker rm -f $containers
    fi
    docker volume rm claude-sandbox-config
    echo "  Volume removed."
  fi
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(curl -fsSL https://api.github.com/repos/anthropics/claude-code/releases/latest \
             | python3 -c 'import sys,json;v=json.load(sys.stdin)["tag_name"];print(v.lstrip("v"))' 2>/dev/null || true)"
  if [[ -z "$VERSION" ]]; then
    echo "Error: could not fetch latest Claude Code version from GitHub. Pass --version <X> explicitly." >&2
    exit 1
  fi
  SOURCE="latest from GitHub"
fi

echo "Building claude-sandbox with Claude Code $VERSION ($SOURCE)"
docker build -t claude-sandbox --build-arg "CLAUDE_CODE_VERSION=$VERSION" "$(dirname "$0")"
