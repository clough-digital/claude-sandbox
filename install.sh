#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SANDBOX_DIR="$HOME/.sandbox"

# Create ~/.local/bin if needed
mkdir -p "$BIN_DIR"

# Symlink scripts (force-overwrite if stale)
ln -sf "$REPO_DIR/claude-sandbox.sh" "$BIN_DIR/claude-sandbox"
ln -sf "$REPO_DIR/worktree.sh"       "$BIN_DIR/worktree"

# Create ~/.sandbox directory
mkdir -p "$SANDBOX_DIR"

# Install zsh completion
COMPLETION_DIR="$HOME/.local/share/zsh/completions"
mkdir -p "$COMPLETION_DIR"
ln -sf "$REPO_DIR/completions/_worktree" "$COMPLETION_DIR/_worktree"

echo "Installed:"
echo "  $BIN_DIR/claude-sandbox -> $REPO_DIR/claude-sandbox.sh"
echo "  $BIN_DIR/worktree       -> $REPO_DIR/worktree.sh"
echo "  $COMPLETION_DIR/_worktree -> $REPO_DIR/completions/_worktree"
echo "  $SANDBOX_DIR created (or already exists)"
echo
echo "Ensure $BIN_DIR is in your PATH."
echo
echo "To enable tab completion, ensure this is in your ~/.zshrc:"
echo "  fpath=(~/.local/share/zsh/completions \$fpath)"
echo "  autoload -Uz compinit && compinit"
