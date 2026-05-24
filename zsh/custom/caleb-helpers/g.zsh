#!/bin/zsh

# FUNCTIONAL REQUIREMENTS:
# • Display git branches sorted by most recent commit date
# • Show branch name and commit date in columns
# • Color code output (yellow branches, green dates)
# • Filter out branches based on configurable date patterns (default: "week|month")

# Simple git branch overview with recent activity
g_f() {
    local exclude_patterns="week|month|[0-9]{2} days"
    local search_pattern="$1"

    # Show branch overview with recent activity
    # Get output without colors for filtering, then add colors back
    local branches_output=$(git for-each-ref \
        --sort=-committerdate \
        --format='%(HEAD)%(refname:short) | %(committerdate:relative)' \
        refs/heads/ | \
        grep -vE "$exclude_patterns" | \
        # Pad first, then add colors
        awk -F'|' '{
            branch=$1;
            date=$2;
            # Find max branch length for alignment
            if (length(branch) > max_branch) max_branch = length(branch);
            lines[NR] = branch "|" date;
        }
        END {
            # Print with proper alignment
            for (i = 1; i <= NR; i++) {
                split(lines[i], parts, "|");
                branch = parts[1];
                date = parts[2];
                printf "%-" max_branch "s | %s\n", branch, date;
            }
        }' | \
        # Now add colors after alignment
        sed 's/^\*/\x1b[33m*\x1b[0m/' | \
        sed 's/| \([^|]*\)$/| \x1b[32m\1\x1b[0m/')

    # Display the normal output
    echo "$branches_output"

    echo ""
    stat_f

    # If search pattern provided, look for it in the displayed branches
    if [[ -n "$search_pattern" ]]; then
        echo ""
        # Extract branch names from the colored output and search for the pattern
        local found_branch=$(echo "$branches_output" | \
            sed 's/\x1b\[[0-9;]*m//g' | \
            awk -F'|' '{print $1}' | \
            sed 's/^\*//' | \
            sed 's/^[[:space:]]*//' | \
            sed 's/[[:space:]]*$//' | \
            grep -i "$search_pattern" | \
            head -1)

        if [[ -n "$found_branch" ]]; then
            echo "Checking out: $found_branch"
            git checkout "$found_branch"
            echo ""
            echo "Updated branch status:"
            g_f  # Show the listing again after checkout
        else
            echo "No branch found matching: $search_pattern"
        fi
    fi
}

# Create alias for backwards compatibility
alias g="g_f"
