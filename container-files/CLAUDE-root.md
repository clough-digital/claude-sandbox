# Sandbox Rules

## Prohibited Actions
- Do not run `git push` or any command that pushes to a remote
- Do not switch or create git branches
- Do not run `git commit` without explicit user confirmation
- Do not install system packages with apt/brew
- Do not make outbound network requests except to the Anthropic API
- Do not use `git fetch`, `git pull`, or `git clone` (blocked by git-wrapper)
- Do not use `git reset --hard` or `git clean -f` (both blocked)

## Git File Operations

The git wrapper blocks branch switching. To restore files, use the explicit `--` separator:

- Restore from index:          `git checkout -- <file>`
- Restore from HEAD:           `git checkout HEAD -- <file>`
- Restore from another ref:    `git checkout <branch-or-commit> -- <file>`
- Restore to working tree:     `git restore <file>`
- Restore from another ref:    `git restore --source=<ref> <file>`

Do NOT use `git checkout <name>` without `--` — it will be blocked as an ambiguous branch switch.

## Git Write Operations

The environment variable `GIT_WRITES_ENABLED` controls whether the main `.git` directory is writable.

**When `GIT_WRITES_ENABLED=0` (default — read-only git):**
- Read-only operations work: `git status`, `git diff`, `git log`, `git show`
- File restores work: `git checkout -- <file>`, `git restore <file>`
- These fail (need writes to .git): `git add`, `git commit`, `git checkout --theirs`, `git checkout --ours`, `git merge`, `git rebase`

**When `GIT_WRITES_ENABLED=1` (launched with `--allow-git-writes`):**
- All of the above work
- `git push` and branch switching are still blocked by the wrapper

If you need to stage, commit, or resolve merge conflicts, ask the user to relaunch the sandbox with:
```
./claude-sandbox.sh --allow-git-writes
```

## Available Claude Code Flags

The sandbox is launched with `claude --dangerously-skip-permissions` by default. Useful flags the user can pass at launch:

- `--allow-git-writes` — enables git add/commit inside the container
- `--with-skills` — mounts the user's `~/.claude/skills/` read-only into the container
- `--safe` — removes `--dangerously-skip-permissions`; permissions prompts become active
- `-n "name"` — sets a display name for this session (v2.1.76+)
- `--bare -p "prompt"` — non-interactive headless mode; skips hooks/plugins/skill walks (v2.1.81+)
- `--from-pr <number>` — pre-loads a GitHub PR's diff into context

## Notes on Effort and Models

- Use `/model` to switch between Opus 4.7, Sonnet 4.6, and Haiku 4.5
- Use `/effort` to set effort level: `low`, `medium`, `high`, `xhigh` (xhigh = Opus 4.7 only)
- The `max` effort level was removed in v2.1.72; use `high` or `xhigh` instead
- `/vim` and `/tag` commands were removed in v2.1.92; use `/config` for editor mode

## Memory

Auto-memory is stored at `/home/claude/.claude/memory/` and persists across sessions in the
`claude-sandbox-config` named volume. Memory accumulates across sessions automatically.

## References

Refer to reference guides in `/references` as needed.
