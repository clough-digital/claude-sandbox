# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Docker-based sandbox environment for running Claude Code (`claude --dangerously-skip-permissions`) inside an isolated Ubuntu 24.04 container.

## Build and Run

```bash
# Build the Docker image
./build.sh

# Launch a sandboxed Claude session (mounts current directory as /workspace)
./claude-sandbox.sh
```

## Recommended Workflow

The sandbox enforces that it must be run from a git worktree (not the main working tree). The typical workflow is:

1. **Create a worktree** for the branch you want to work on:
   ```bash
   ./worktree.sh <branch-name>
   ```
   This creates a sibling directory (`../<repo-name>-<branch-name>`), checks out the branch, and copies any `.env`/`.envrc` file into it.

2. **Change into the worktree** and launch the sandbox:
   ```bash
   cd ../<repo-name>-<branch-name>
   ./claude-sandbox.sh
   ```

## Environment Variables

The sandbox reads `.env` or `.envrc` from the current directory and passes each variable into the container via Docker `-e` flags. This is the recommended way to supply API keys and secrets without hardcoding them.

`worktree.sh` automatically copies `.env`/`.envrc` from the repo root into the new worktree so secrets are available when you launch the sandbox from there.

## Git Security Restrictions

The container includes a custom git wrapper at `/usr/local/bin/git` that blocks operations that could mutate the host repository or escape the sandbox:

| Blocked command | Reason |
|---|---|
| `git push` | Prevents pushing from inside the container |
| `git worktree` | Prevents creating nested worktrees |
| `git gc` / `git prune` | Prevents garbage-collecting the shared object store |
| `git config --global` / `--system` | Prevents modifying global git config |
| `git remote add/remove/set-url/rename` | Prevents altering remote definitions |

All other git operations (commit, branch, checkout, diff, log, etc.) pass through to `/usr/bin/git` normally.

## Architecture

- **Dockerfile** — Ubuntu 24.04 image with git, curl, zsh. Creates an unprivileged `claude` user, copies `git-wrapper.sh` to `/usr/local/bin/git`, and installs Claude Code CLI via `claude.ai/install.sh`.
- **git-wrapper.sh** — The custom git security wrapper. Blocks `push`, `worktree`, `gc`, `prune`, `config --global/--system`, and `remote add/remove/set-url/rename`; all other commands pass through to `/usr/bin/git`.
- **build.sh** — Builds the `claude-sandbox` Docker image.
- **claude-sandbox.sh** — Runs the container with:
  - Current directory mounted at `/workspace` (must be a git worktree)
  - `~/Documents/Code/_references` mounted read-only at `/references`
  - Named volume `claude-sandbox-config` for persisting Claude config across sessions
  - Environment variables sourced from `.env` or `.envrc` passed through via `-e` flags
- **worktree.sh** — Creates a linked git worktree as a sibling directory named `<repo>-<branch>`, creates the branch if it does not exist, and copies `.env`/`.envrc` into the new worktree.
