#!/bin/bash
# Build the claude-sandbox Docker image.
# Usage: ./build.sh [--version <claude-code-version>]
# Default Claude Code version is set in the Dockerfile ARG CLAUDE_CODE_VERSION.
# Example: ./build.sh --version 2.1.111

VERSION_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION_ARG="--build-arg CLAUDE_CODE_VERSION=$2"
      shift 2 ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--version <version>]" >&2
      exit 1 ;;
  esac
done

docker build -t claude-sandbox $VERSION_ARG "$(dirname "$0")"
