# Auto-commit function using sgpt for commit message generation
_commit() {
    # Check if there are staged changes
    if ! git diff --staged --quiet; then
        echo "📝 Generating commit message with AI..."
        
        # Get staged diff and generate commit message
        local commit_msg=$(git diff --staged | sgpt "write a 1 line commit

whatever you return will be sent directly into git commit
no boilerplate, just the message
 write only 1 brief line for the commit message. THIS IS VERY IMPORTANT.

Examples of good ones:
- Added search functionality to main page
- Fixed the bug where the search bar was not working
- Added column to the pricing table
")
        
        # Check if sgpt returned a message
        if [[ -n "$commit_msg" ]]; then
            echo "✨ Generated commit message: $commit_msg"
            echo "🚀 Committing changes..."
            
            # Commit with the generated message
            git commit -m "$commit_msg"
            
            echo "✅ Commit successful!"
        else
            echo "❌ Failed to generate commit message"
            return 1
        fi
    else
        echo "⚠️  No staged changes to commit"
        echo "💡 Use 'git add' to stage changes first"
        return 1
    fi
}

alias __commit="_commit"