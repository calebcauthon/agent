FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm
RUN apt-get update && apt-get install -y tmux && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent
WORKDIR /workspace
