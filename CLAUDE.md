# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Docker-based sandbox environment for running Claude Code (`claude --dangerously-skip-permissions`) inside an isolated Ubuntu 24.04 container.

## Build and Run

```bash
# Build the Docker image (fetches latest Claude Code version from npm at build time)
./build.sh

# Build with a specific Claude Code version (pins instead of fetching latest)
./build.sh --version 2.1.111

# Launch a sandboxed Claude session (mounts current directory as /workspace)
./claude-sandbox.sh

# Launch with git write access (enables git add/commit inside the sandbox)
./claude-sandbox.sh --allow-git-writes

# Launch with host skills mounted read-only (~/.claude/skills/)
./claude-sandbox.sh --with-skills

# Launch in safe mode (keeps permission prompts — no --dangerously-skip-permissions)
./claude-sandbox.sh --safe

# Force a synchronous update check before starting (new version takes effect this session)
./claude-sandbox.sh --update

# Pass arbitrary flags through to claude (e.g. headless mode, named session)
./claude-sandbox.sh --bare -p "summarize the workspace"
./claude-sandbox.sh -n "my-session"
./claude-sandbox.sh --from-pr 42
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

Values with surrounding double or single quotes (e.g. `FOO="bar"`) are stripped before forwarding.

## Claude Code Version & Auto-Updates

Claude Code's native installer auto-updates the binary in place. To make these updates persist
across container restarts (rather than being discarded with each `--rm` container), the
`/home/claude/.local/` directory is mounted as the named volume `claude-sandbox-local`:

- **First run ever**: Docker populates the empty volume with the image's baseline Claude Code
  install (the version fetched from GitHub at `./build.sh` time, or the `ARG CLAUDE_CODE_VERSION`
  fallback if built directly with `docker build`).
- **Subsequent runs**: Claude's updater writes new versions to
  `/home/claude/.local/share/claude/versions/<new>/` and updates the
  `/home/claude/.local/bin/claude` symlink. Both paths live in the volume, so updates carry
  over to the next session.

### Forcing an update this session

Run `./claude-sandbox.sh --update` to check for and apply updates synchronously before Claude starts — the new version is in effect for the session you're launching (unlike the daily background updater, which only takes effect on the *next* launch). Running `--update` also resets the 24h throttle so the background updater stays quiet for the rest of the day.

### Forcing a version re-baseline

If you want to reset to the Dockerfile's pinned version (or recover from a broken update):

```bash
docker volume rm claude-sandbox-local
./build.sh                     # rebuilds with latest version from GitHub
./claude-sandbox.sh            # next launch repopulates the volume from the image
```

### Manual version override at build time

```bash
./build.sh --version 2.1.111
```

This only affects the baseline used on fresh volumes; existing `claude-sandbox-local` volumes
keep whatever version Claude last self-updated to.

## Git Security Restrictions

The container includes a custom git wrapper at `/usr/local/bin/git` that blocks operations
that could mutate the host repository, escape the sandbox, or make unauthorized network calls:

| Blocked command | Reason |
|---|---|
| `git push` | Prevents pushing from inside the container |
| `git fetch` / `git pull` / `git clone` | No network egress from git |
| `git worktree add/remove/...` | Prevents creating nested worktrees |
| `git gc` / `git prune` | Prevents garbage-collecting the shared object store |
| `git config --global` / `--system` | Prevents modifying global git config |
| `git remote add/remove/set-url/rename` | Prevents altering remote definitions |
| `git checkout <branch>` (without `--`) | Blocks ambiguous branch switch |
| `git switch` | Blocked — use `git checkout` with `--` for file restores |
| `git reset --hard` | Prevents discarding uncommitted work |
| `git clean -f` | Prevents deleting untracked files |
| `git cherry-pick` / `git am` / `git update-ref` / `git replace` | Prevents ref mutation |

All other git operations (commit, branch creation, diff, log, etc.) pass through normally.

In-container `permissions.deny` rules in `settings.json` double-enforce the most dangerous
subset of the above even if the git-wrapper is bypassed.

## Architecture

- **Dockerfile** — Ubuntu 24.04 image. Creates an unprivileged `claude` user, installs Node 22
  LTS, Playwright (Node only), GitHub CLI, a pinned Claude Code CLI version, and bakes in a
  `settings.json` with 2026 security defaults and hooks.
- **build.sh** — Builds the `claude-sandbox` Docker image. Accepts `--version <v>` to override
  the Claude Code version.
- **git-wrapper.sh** — The custom git security wrapper installed at `/usr/local/bin/git`.
- **entrypoint.sh** — Bootstraps D-Bus + gnome-keyring (for OAuth token storage), then execs
  `claude`. Supports `--safe` to omit `--dangerously-skip-permissions`.
- **settings.json** — Baked-in Claude Code settings: `showThinkingSummaries`, permission deny
  rules mirroring git-wrapper, and a `PreToolUse` hook that blocks outbound HTTP to non-Anthropic
  hosts via `curl` or `wget`.
- **hooks/block-non-anthropic-http.sh** — PreToolUse hook script enforcing the outbound HTTP
  allowlist.
- **claude-sandbox.sh** — Runs the container with:
  - Current directory mounted at `/workspace` (must be a git worktree)
  - Main `.git` mounted read-only by default; `--allow-git-writes` makes it read-write
  - `~/Documents/Code/_references` mounted read-only at `/references`
  - Named volume `claude-sandbox-config` for persisting Claude config, memory, and plugins
  - Named volume `claude-sandbox-local` for persisting `/home/claude/.local/` — including the
    Claude Code binary and any auto-updates applied in-session
  - Named volume `claude-sandbox-keyrings` for persisting gnome-keyring across sessions (mounted
    inside `claude-sandbox-local` at `/home/claude/.local/share/keyrings`)
  - `$HOME/.claude-sandbox.json` bind-mounted as `~/.claude.json` inside the container
    (persists the Claude Code account/auth state between image rebuilds)
  - Docker hardening: `--cap-drop ALL`, `--security-opt no-new-privileges`, pids/memory limits
  - `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `CLAUDE_CODE_CERT_STORE=bundled`,
    `CLAUDE_CODE_DISABLE_CRON` set in the image ENV
  - Environment variables sourced from `.env` or `.envrc` passed through via `-e` flags
  - Optional: `--with-skills` mounts `~/.claude/skills/` read-only
- **worktree.sh** — Creates a linked git worktree as a sibling directory named
  `<repo>-<branch>`, creates the branch if it does not exist, and copies `.env`/`.envrc` into
  the new worktree.
- **install.sh** — Symlinks `claude-sandbox.sh` and `worktree.sh` into `~/.local/bin`, and
  the zsh completion into `~/.local/share/zsh/completions`.

## Claude Code Authentication

Authentication persists across sessions via two mechanisms:

1. **Named volume `claude-sandbox-config`** → `/home/claude/.claude/` — stores credentials,
   settings, memory, and plugins.
2. **Named volume `claude-sandbox-keyrings`** → `/home/claude/.local/share/keyrings/` — stores
   the gnome-keyring database used by libsecret/keytar for OAuth token encryption.
3. **Bind-mount `$HOME/.claude-sandbox.json`** → `/home/claude/.claude.json` — stores the
   top-level Claude Code account state (auth tokens, `oauthAccount`, theme). The host file is
   `touch`-ed before `docker run` so Docker creates a file rather than a directory.

First-time setup requires running `claude login` interactively inside the container. Credentials
persist until token expiry (typically weeks to months).

> **Note on `CLAUDE_CONFIG_DIR`**: Claude Code v2.1.111 introduced `CLAUDE_CONFIG_DIR` which
> consolidates `~/.claude.json` into the config directory. When pinning to v2.1.111+, set
> `ENV CLAUDE_CONFIG_DIR=/home/claude/.claude` in the Dockerfile and drop the
> `~/.claude-sandbox.json` bind-mount.
