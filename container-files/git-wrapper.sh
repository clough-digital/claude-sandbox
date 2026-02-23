#!/bin/bash
case "$1" in
  push)
    echo "git push is disabled in this sandbox" >&2; exit 1 ;;
  worktree)
    echo "git worktree is disabled in this sandbox" >&2; exit 1 ;;
  gc|prune)
    echo "git $1 is disabled in this sandbox" >&2; exit 1 ;;
  config)
    for arg in "$@"; do
      if [[ "$arg" == "--global" || "$arg" == "--system" ]]; then
        echo "git config $arg is disabled in this sandbox" >&2; exit 1
      fi
    done ;;
  remote)
    case "$2" in
      add|remove|set-url|rename)
        echo "git remote $2 is disabled in this sandbox" >&2; exit 1 ;;
    esac ;;
esac
exec /usr/bin/git "$@"
