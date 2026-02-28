FROM ubuntu:24.04

# 1. Core system packages — rarely changes
RUN apt-get update && apt-get install -y \
    curl git zsh python3 python3-pip libsecret-1-0 gnome-keyring dbus-x11 tmux \
    ripgrep fd-find fzf jq sqlite3 make parallel entr bat tree procps \
    && rm -rf /var/lib/apt/lists/*

# 2. GitHub CLI — rarely changes (own apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# 3. Create claude user — basically never changes
RUN useradd -m -s /bin/zsh claude

# 4. Node.js latest LTS — setup_lts.x always resolves to current LTS at build time
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# 5. Playwright system dependencies (Python + Node, both root-level) — infrequent
RUN pip3 install playwright yq --break-system-packages && \
    playwright install-deps chromium && \
    rm -rf /var/lib/apt/lists/*

RUN npx playwright install-deps chromium

# 6. Git wrapper — occasional changes (security rule edits)
COPY container-files/git-wrapper.sh /usr/local/bin/git
RUN chmod +x /usr/local/bin/git

# 7. Entrypoint — occasional changes (launch logic edits)
COPY --chown=claude:claude container-files/entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

# Switch to unprivileged user for all remaining steps
USER claude
WORKDIR /workspace

# Pre-create keyrings dir as claude so named volume inherits correct ownership
RUN mkdir -p /home/claude/.local/share/keyrings

# 8. Playwright browser binaries (user-level) — infrequent (before Claude install
#    so frequent Claude updates don't force browser re-downloads)
RUN playwright install chromium && \
    npx playwright install chromium

# 9. Claude Code CLI — frequent (new Claude releases)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:$PATH"

# 10. Claude instructions — most volatile, always last
COPY --chown=claude:claude container-files/CLAUDE-root.md /home/claude/.claude/CLAUDE.md
