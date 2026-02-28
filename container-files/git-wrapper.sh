#!/bin/bash
case "$1" in
  push)
    echo "git push is disabled in this sandbox" >&2; exit 1 ;;
  worktree)
    case "$2" in
      list|repair)
        ;; # allow — read-only
      add|remove|move|lock|unlock|prune)
        echo "git worktree $2 is disabled in this sandbox" >&2; exit 1 ;;
      *)
        echo "git worktree $2 is disabled in this sandbox" >&2; exit 1 ;;
    esac ;;
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
  checkout)
    # Only allow file-level checkout (requires -- separator to be unambiguous)
    # This permits: git checkout -- <file>
    #               git checkout <treeish> -- <file>
    # And blocks:   git checkout <branch>
    #               git checkout -b <new-branch>
    has_dashdash=false
    for arg in "$@"; do
      [[ "$arg" == "--" || "$arg" == "--theirs" || "$arg" == "--ours" ]] && { has_dashdash=true; break; }
    done
    if [[ "$has_dashdash" == false ]]; then
      echo "git checkout for branch switching is disabled in this sandbox." >&2
      echo "To restore files, use: git checkout -- <file> or git checkout <ref> -- <file>" >&2
      exit 1
    fi ;;
  switch)
    echo "git switch is disabled in this sandbox" >&2; exit 1 ;;
esac
exec /usr/bin/git "$@"
