FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    curl git zsh python3 python3-pip libsecret-1-0 gnome-keyring dbus-x11 tmux \
    ripgrep fd-find fzf jq sqlite3 make parallel entr bat tree procps \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (requires its own apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/zsh claude

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Git wrapper: block remote-mutating and structural operations
COPY container-files/git-wrapper.sh /usr/local/bin/git
RUN chmod +x /usr/local/bin/git

COPY --chown=claude:claude container-files/CLAUDE-root.md /home/claude/.claude/CLAUDE.md

# Install Playwright Python package (provides CLI) + Chromium system dependencies
RUN pip3 install playwright yq --break-system-packages && \
    playwright install-deps chromium && \
    rm -rf /var/lib/apt/lists/*

# Node.js Playwright system dependencies (ensures version-matched deps for npx playwright)
RUN npx playwright install-deps chromium

COPY --chown=claude:claude container-files/entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

USER claude
WORKDIR /workspace

# Pre-create keyrings dir as claude so the named volume mount inherits correct ownership
RUN mkdir -p /home/claude/.local/share/keyrings

RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:$PATH"

# Install Chromium browser binaries for both Python and Node.js Playwright
RUN playwright install chromium && \
    npx playwright install chromium