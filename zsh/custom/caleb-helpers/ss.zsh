#!/bin/zsh

# Visual git status tree alias
# - Uses the repo's `ss` script if available
# - Falls back to a sibling `ss` next to this file or `/workspace/ss`

ss_f() {
    local script_path=""

    # Prefer git repo root `ss` if we're in a repo
    if command -v git >/dev/null 2>&1; then
        local repo_root
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$repo_root" && -x "$repo_root/ss" ]]; then
            script_path="$repo_root/ss"
        fi
    fi

    # Next, try to resolve path relative to this zsh file
    if [[ -z "$script_path" ]]; then
        local this_dir
        this_dir=$(cd -- "${0:A:h}" 2>/dev/null && pwd)
        if [[ -n "$this_dir" && -x "$this_dir/ss" ]]; then
            script_path="$this_dir/ss"
        fi
    fi

    # Fallback to absolute path as used in this environment
    if [[ -z "$script_path" && -x "/workspace/ss" ]]; then
        script_path="/workspace/ss"
    fi

    if [[ -z "$script_path" ]]; then
        echo "ss script not found. Ensure 'ss' exists in repo root or alongside ss.zsh." >&2
        return 127
    fi

    # Forward args and honor FORCE_COLOR/NO_COLOR env from caller
    "$script_path" "$@"
}

# Alias for convenience
alias ssg="ss_f"

