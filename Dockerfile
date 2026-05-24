FROM node:22.19.0-bookworm

ENV SHELL=/bin/zsh \
  ROOMS_IMAGE_VERSION=node-22.19.0_pi-0.75.5_zsh

RUN apt-get update \
  && apt-get install -y --no-install-recommends tmux git zsh ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.5

WORKDIR /workspace
CMD ["zsh"]
