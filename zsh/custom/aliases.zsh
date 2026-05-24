# Friendly defaults for interactive agent shells.

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'

alias gs='git status --short --branch'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --decorate --graph -20'
alias gp='git push'
alias gpl='git pull --ff-only'

alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dc='docker compose'

alias ni='npm install'
alias nr='npm run'
alias nt='npm test'
alias nb='npm run build'
