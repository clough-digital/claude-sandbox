# Sandbox Rules

## Prohibited Actions
- Do not run `git push` or any command that pushes to a remote
- Do not switch or create git branches
- Do not run `git commit` without explicit user confirmation
- Do not install system packages with apt/brew
- Do not make outbound network requests except to the Anthropic API

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

## References

Refer to reference guides in `/references` as needed
