#!/bin/zsh

# FUNCTIONAL REQUIREMENTS:
# • Display git branches sorted by most recent commit date
# • Show branch name, commit date, and commit subject in columns
# • Color code output (yellow branches, green dates, blue subjects)
# • Filter out branches based on configurable date patterns (default: "week|month")
# • Support viewing different ref types (local branches, remotes, all refs)
# • Show git status after branch overview
# • Maintain backwards compatibility with original alias

# Git branch overview with recent activity and status
ggg_f() {
    local exclude_patterns="${1:-week|month}"
    local ref_type="${2:-refs/heads/}"

    # Show branch overview with recent activity
    # Get output without colors for filtering, then add colors back
    git for-each-ref \
        --sort=-committerdate \
        --format='%(HEAD)%(refname:short) | %(committerdate:relative) | %(subject)' \
        "$ref_type" | \
        grep -vE "$exclude_patterns" | \
        sed 's/^\*/\x1b[33m*\x1b[0m/' | \
        sed 's/| \([^|]*\) |/| \x1b[32m\1\x1b[0m |/' | \
        sed 's/| \([^|]*\)$/| \x1b[34m\1\x1b[0m/' | \
        column -t -s '|'

    echo ""  # Add spacing

    # Show git status
    git status
}

alias ggg="clear && ggg_f"
