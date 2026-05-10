#!/bin/bash
# Build the claude-sandbox Docker image.
# Usage: ./build.sh [--version <claude-code-version>]
# Default: fetches the latest Claude Code release from GitHub.
# Example: ./build.sh --version 2.1.138
set -euo pipefail

VERSION=""
SOURCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      SOURCE="pinned via --version"
      shift 2 ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--version <version>]" >&2
      exit 1 ;;
  esac
done

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
