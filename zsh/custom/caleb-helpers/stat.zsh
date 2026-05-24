#!/bin/zsh

# Git status wrapper that collapses paths to just the filename (keeps colors)
# Examples:
#   a/b/c/d/e/file.txt -> file.txt
#   renamed: a/b/c.txt -> d/e/f.txt  =>  renamed: c.txt -> f.txt

stat_f() {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		# Keep git colors; replace any path containing slashes with just its basename
		git -c color.status=always status "$@" | perl -CS -pe 's{((?:\e\[[0-9;]*m)*)(?:[^/\s]+/)+([^/\s]+)}{$1$2}g'
	else
		git status "$@"
	fi
}

alias stat="stat_f"

