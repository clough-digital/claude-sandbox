FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl git zsh && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/zsh claude

# Git wrapper: block remote-mutating and structural operations
COPY container-files/git-wrapper.sh /usr/local/bin/git
RUN chmod +x /usr/local/bin/git

COPY container-files/CLAUDE-root.md /home/claude/.claude/CLAUDE.md

USER claude
WORKDIR /workspace
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:$PATH"