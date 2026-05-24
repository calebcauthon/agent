#!/bin/zsh

# Git push function that automatically pushes to origin with current branch
push_f() {
    # Get current branch name
    local current_branch=$(git branch --show-current)

    if [[ -z "$current_branch" ]]; then
        echo "❌ Error: Not on a git branch or not in a git repository"
        return 1
    fi

    if [[ "$1" == "HARD" ]]; then
        echo "⚠️  FORCE PUSH requested for branch '$current_branch' to origin"
        echo "Press Ctrl-C to cancel."
        for i in 5 4 3 2 1; do
            echo "⏳ Forcing in $i..."
            sleep 1
        done
        echo "🚀 Force pushing branch '$current_branch' to origin..."
        if git push origin -f "$current_branch"; then
            echo "✅ Successfully force pushed '$current_branch' to origin"
        else
            echo "❌ Failed to force push '$current_branch' to origin"
            return 1
        fi
    else
        echo "🚀 Pushing branch '$current_branch' to origin..."
        # Execute the push command
        if git push origin "$current_branch"; then
            echo "✅ Successfully pushed '$current_branch' to origin"
        else
            echo "❌ Failed to push '$current_branch' to origin"
            return 1
        fi
    fi
}

# Alias for convenience
alias push="push_f"
