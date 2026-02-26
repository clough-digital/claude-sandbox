FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl git zsh python3 python3-pip && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/zsh claude

# Git wrapper: block remote-mutating and structural operations
COPY container-files/git-wrapper.sh /usr/local/bin/git
RUN chmod +x /usr/local/bin/git

COPY --chown=claude:claude container-files/CLAUDE-root.md /home/claude/.claude/CLAUDE.md

# Install Playwright Python package (provides CLI) + Chromium system dependencies
RUN pip3 install playwright --break-system-packages && \
    playwright install-deps chromium && \
    rm -rf /var/lib/apt/lists/*

USER claude
WORKDIR /workspace
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:$PATH"

# Install Chromium browser binary into the image for the claude user
RUN playwright install chromium