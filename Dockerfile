FROM node:22.19.0-bookworm

ENV SHELL=/bin/zsh \
  ZSH=/opt/oh-my-zsh \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  TERM=xterm-256color \
  COLORTERM=truecolor \
  NONINTERACTIVE=1 \
  HOMEBREW_NO_ANALYTICS=1 \
  HOMEBREW_NO_ENV_HINTS=1 \
  ROOMS_IMAGE_VERSION=node-22.19.0_pi-0.75.5_ohmyzsh_utf8_homebrew

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    iproute2 \
    less \
    procps \
    shellcheck \
    sudo \
    tmux \
    zoxide \
    zsh \
  && rm -rf /var/lib/apt/lists/*

RUN usermod -aG sudo node \
  && echo 'node ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/node \
  && chmod 0440 /etc/sudoers.d/node

USER node
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
USER root

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh \
  && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/oh-my-zsh/custom/themes/powerlevel10k \
  && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions \
  && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
  && chmod -R a+rX /opt/oh-my-zsh

RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.5

WORKDIR /workspace
CMD ["zsh"]
