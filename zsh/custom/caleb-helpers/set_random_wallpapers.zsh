#!/bin/zsh

# Define a function so this file can be sourced into interactive shells.
set_random_wallpapers() {
  # default images directory (can override by passing first arg)
  local images_dir=${1:-"$HOME/code/ghostty_background_images"}

  # expand ~ if provided
  if [[ $images_dir == ~* ]]; then
    images_dir=${images_dir/#\~/$HOME}
  fi

  # resolve script directory (the file this function was sourced from)
  local script_path script_dir
  if [[ -n ${ZSH_VERSION-} ]]; then
    script_path=${(%):-%x}
  else
    script_path=$0
  fi
  script_dir=${script_path:A:h}
  local applescript="$script_dir/set_random_wallpapers.applescript"

  if [[ ! -f "$applescript" ]]; then
    print -u2 -- "AppleScript not found: $applescript"
    return 1
  fi

  osascript "$applescript" "$images_dir"
}

# Alias for convenience in interactive shells
alias rotate_desktop_bgs='set_random_wallpapers'
