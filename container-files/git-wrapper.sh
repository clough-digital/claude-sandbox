#!/bin/bash
case "$1" in
  push)
    echo "git push is disabled in this sandbox" >&2; exit 1 ;;
  fetch|pull|clone)
    echo "git $1 is disabled in this sandbox (no network egress from git)" >&2; exit 1 ;;
  worktree)
    case "$2" in
      list|repair)
        ;; # allow — read-only
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
  reset)
    for arg in "$@"; do
      if [[ "$arg" == "--hard" ]]; then
        echo "git reset --hard is disabled in this sandbox" >&2; exit 1
      fi
    done ;;
  clean)
    for arg in "$@"; do
      if [[ "$arg" == "-f"* || "$arg" == "--force" ]]; then
        echo "git clean -f is disabled in this sandbox" >&2; exit 1
      fi
    done ;;
  update-ref|am|cherry-pick|filter-branch|replace)
    echo "git $1 is disabled in this sandbox" >&2; exit 1 ;;
esac
exec /usr/bin/git "$@"
