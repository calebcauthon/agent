# Caleb's shell helpers, adapted for rooms containers.
# Secrets from ~/.zshrc are intentionally not copied into this repo.

local helpers_dir="${ROOMS_ZSH_DIR:-$HOME/.rooms-zsh}/custom/caleb-helpers"

if [ -d "$helpers_dir" ]; then
  for helper in \
    litellm.zsh \
    ggg.zsh \
    ai.zsh \
    init_project.zsh \
    ggup.zsh \
    stat.zsh \
    g.zsh \
    neverlost_megacommands.zsh \
    diff.zsh \
    push.zsh \
    ghostty.zsh \
    set_random_wallpapers.zsh \
    ss.zsh \
    mlclean.zsh \
    space.zsh \
    jsonshape.zsh \
    tlog.zsh \
    dotfiles.zsh \
    chrome_cdp.zsh \
    claws.zsh \
    spath.zsh \
    my192
  do
    [ -f "$helpers_dir/$helper" ] && source "$helpers_dir/$helper"
  done

  # Completion for ghoset when available. Keep quiet in minimal shells.
  [ -f "$helpers_dir/_ghoset" ] && source "$helpers_dir/_ghoset" 2>/dev/null || true
fi
