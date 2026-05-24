# Bare git repo dotfiles management
unalias dotfiles 2>/dev/null
dotfiles() {
  if [[ "$1" == "setup" ]]; then
    if [[ -d "$HOME/.dotfiles" ]]; then
      echo "~/.dotfiles already exists — skipping init"
    else
      git init --bare "$HOME/.dotfiles"
      echo "Bare repo initialized at ~/.dotfiles"
    fi
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
    echo "Done. Use 'dotfiles add <file>' to start tracking files."
    return
  fi

  if [[ "$1" == "help" ]]; then
    echo ""
    echo "dotfiles — bare git repo for tracking config files"
    echo ""
    echo "  dotfiles setup               initialize the bare repo (first time only)"
    echo "  dotfiles status              show tracked changes"
    echo "  dotfiles add <file>          start tracking a file"
    echo "  dotfiles commit -m 'msg'     commit changes"
    echo "  dotfiles push                push to remote"
    echo "  dotfiles remote add origin <url>  add a remote"
    echo ""
    return
  fi

  git --git-dir=$HOME/.dotfiles --work-tree=$HOME "$@"
}
