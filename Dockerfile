FROM node:22.19.0-bookworm

ENV SHELL=/bin/zsh \
  ZSH=/opt/oh-my-zsh \
  ROOMS_IMAGE_VERSION=node-22.19.0_pi-0.75.5_ohmyzsh

RUN apt-get update \
  && apt-get install -y --no-install-recommends tmux git zsh less iproute2 ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh \
  && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions \
  && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
  && chmod -R a+rX /opt/oh-my-zsh

RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.5

WORKDIR /workspace
CMD ["zsh"]
