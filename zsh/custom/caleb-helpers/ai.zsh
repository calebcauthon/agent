#!/bin/zsh

# Model configuration helpers
_ai_get_model() {
    local config_file="$HOME/.ai_model_config"
    if [[ -f "$config_file" ]]; then
        grep "^current=" "$config_file" | cut -d'=' -f2-
    else
        echo "liquid/lfm2-1.2b"  # default
    fi
}

_ai_set_model() {
    local new_model="$1"
    local config_file="$HOME/.ai_model_config"
    local old_model=$(_ai_get_model)
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    
    # Create temp file for atomic write
    local temp_file="${config_file}.tmp"
    
    # Write current model
    echo "current=$new_model" > "$temp_file"
    
    # Process existing history
    if [[ -f "$config_file" ]]; then
        # Copy all history entries except the new model (we'll add it with updated timestamp)
        grep "^history:" "$config_file" | grep -v "history:$new_model=" >> "$temp_file" 2>/dev/null || true
    fi
    
    # Add/update new model in history (since it's now being used)
    # Remove any existing entry first, then add with current timestamp
    if grep -q "^history:$new_model=" "$temp_file" 2>/dev/null; then
        sed -i '' "s|^history:$new_model=.*|history:$new_model=$timestamp|" "$temp_file"
    else
        echo "history:$new_model=$timestamp" >> "$temp_file"
    fi
    
    # Add old model to history if it's different and not empty
    if [[ -n "$old_model" && "$old_model" != "$new_model" ]]; then
        # Update timestamp if model already in history, otherwise add new entry
        if grep -q "^history:$old_model=" "$temp_file" 2>/dev/null; then
            sed -i '' "s|^history:$old_model=.*|history:$old_model=$timestamp|" "$temp_file"
        else
            echo "history:$old_model=$timestamp" >> "$temp_file"
        fi
    fi
    
    # Atomic move
    mv "$temp_file" "$config_file"
}

# AI assistant alias using sgpt with shell mode
# Usage: ai "your question or command"
# Usage: ai -h (runs last command and asks AI what to run next to fix issues)
ai() {
    # Check for redo command
    if [ "$1" = "redo" ]; then
        local cmd_output
        local last_cmd
        local exit_code

        # Get the last command from history (excluding this ai command)
        # Use fc -ln -1 to get the most recent command, then exclude if it's an ai command
        last_cmd=$(fc -ln -1 | sed 's/^[ \t]*//')

        # If the last command was an ai command, get the one before it
        if [[ "$last_cmd" == ai* ]]; then
            last_cmd=$(fc -ln -2 -2 | head -1 | sed 's/^[ \t]*//')
        fi

        if [ -z "$last_cmd" ]; then
            echo "No previous command found in history"
            return 1
        fi

        echo ""
        echo "� \033[1;36mAI REDO MODE ACTIVATED\033[0m 🤖"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎯 \033[1;33mTarget Command:\033[0m $last_cmd"
        echo "⚡ \033[1;32mLet's analyze and fix this!\033[0m"
        echo ""

        # Check for -paste flag to determine how to get output
        if [ "$2" = "-paste" ]; then
            echo "📋 \033[1;35mPulled output from clipboard...\033[0m"
            echo "\033[2;37m────────────────────────────────────────\033[0m"

            # Get content from clipboard
            cmd_output=$(pbpaste)

            if [ -z "$cmd_output" ]; then
                echo "\033[1;31m❌ Clipboard is empty\033[0m"
                return 1
            fi

            # Display the clipboard content
            echo "\033[0;36m$cmd_output\033[0m"
            echo "\033[2;37m────────────────────────────────────────\033[0m"
            echo ""
        else
            # Original redo functionality (re-run last command)
            echo "🔄 \033[1;34mRe-running:\033[0m \033[1;37m$last_cmd\033[0m"
            echo "\033[2;37m────────────────────────────────────────\033[0m"

            # Run the last command and save its output
            cmd_output=$(eval "$last_cmd" 2>&1)
            exit_code=$?

            # Display the output with color based on exit code
            if [ $exit_code -eq 0 ]; then
                echo "\033[0;32m$cmd_output\033[0m"
                echo "\033[2;37m────────────────────────────────────────\033[0m"
                echo "✅ \033[1;32mExit code: $exit_code (Success)\033[0m"
            else
                echo "\033[0;31m$cmd_output\033[0m"
                echo "\033[2;37m────────────────────────────────────────\033[0m"
                echo "❌ \033[1;31mExit code: $exit_code (Error)\033[0m"
            fi
            echo ""
        fi

        # Shared analysis and solution flow
        echo "🔍 Analyzing the problem..."
        local problem_explanation=$(sgpt --model=$(_ai_get_model) "$cmd_output explain what the problem is")

        # Display the analysis
        echo "$problem_explanation"
        echo "----------------------------------------"
        echo ""

        # Get solution using sgpt -s
        echo "🤖 Getting solution..."
        local ai_response=$(sgpt --model=$(_ai_get_model) -s "$problem_explanation" | tee /dev/tty)

        # Copy the first line of AI response to clipboard
        echo "$ai_response" | head -n 1 | pbcopy
        echo "📋 copied"
        return 0
    fi

    if [ $# -eq 0 ]; then
        echo "Usage: ai \"your question or command\""
        echo "       ai redo (re-run last command, analyze problem, get solution)"
        echo "       ai redo -paste (analyze clipboard content, get solution)"
        echo "Example: ai \"How do I list files in Linux?\""
        return 1
    fi

    # Run sgpt -s and capture output while still displaying it
    local output=$(sgpt --model=$(_ai_get_model) -s "$*" | tee /dev/tty)

    # Copy only the first line to clipboard
    echo "$output" | head -n 1 | pbcopy
    echo "📋 copied"
}

# AI assistant without shell mode with hardcoded context
# Usage: ask "your question"
ask() {
    if [ $# -eq 0 ]; then
        echo "Usage: ask \"your question\""
        echo "Example: ask \"Explain what is Docker\""
        return 1
    fi

    # Hardcoded context prompt - customize this as needed
    local context_prompt="You are a helpful programming assistant. Please provide clear, concise answers with practical examples when relevant."

    # Combine context with user input
    sgpt --model=$(_ai_get_model) "$context_prompt

User question: $*"
}

commit() {
    # Generate a one-line commit message from staged diff using qwen3-coder-30b
    local staged_diff
    staged_diff=$(git diff --staged)

    if [ -z "$staged_diff" ]; then
        echo "No staged changes found."
        return 1
    fi

    local prompt
    prompt="You are given a git staged diff below. Produce a single, concise one-line commit message that summarizes the changes. Do NOT include any surrounding explanation or quotes. Exclude any <think> or <thinking> tags. Output only the one-line commit message. Dont say 'The changes are...' Just say what they are. Be breif!!! Grandmas gets to live in a nice house if you are concise!!"

    # Send staged diff and prompt to sgpt model
    local ai_output
    ai_output=$(sgpt --model=$(_ai_get_model) "$staged_diff

$prompt")

    # Remove any <think> or <thinking> tags, trim whitespace
    local cleaned
    cleaned=$(echo "$ai_output" | sed -E 's/<\/?(think|thinking)>//gi' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    local one_line

    # Check if cleaned output is >100 chars and has multiple lines
    local char_count=$(echo -n "$cleaned" | wc -c)
    local line_count=$(echo "$cleaned" | wc -l)

    if [ "$char_count" -gt 100 ] && [ "$line_count" -gt 1 ]; then
        # Use last line if too long and multi-line
        one_line=$(echo "$cleaned" | tail -n 1)
    else
        # Use first line (default behavior)
        one_line=$(echo "$cleaned" | sed -n '1p')
    fi

    if [ -z "$one_line" ]; then
        echo "AI did not return a commit message."
        echo "AI output: $ai_output"
        return 1
    fi

    # Pass the one-line message to gcommit or git commit
    if command -v gcommit >/dev/null 2>&1; then
        gcommit -m "$one_line"
    else
        git commit -m "$one_line"
    fi
}

# Model configuration command
# Usage: aimodel              - show current model
#        aimodel list         - list all models with usage history
#        aimodel set <model>  - set new model and test it
aimodel() {
    local config_file="$HOME/.ai_model_config"
    
    if [[ "$1" == "set" ]]; then
        if [[ -z "$2" ]]; then
            echo "Usage: aimodel set <model>"
            echo "Example: aimodel set gpt-4o"
            return 1
        fi
        
        local new_model="$2"
        local old_model=$(_ai_get_model)
        
        echo "🔄 Changing model from \033[1;33m$old_model\033[0m to \033[1;32m$new_model\033[0m"
        
        # Save old model to history and set new one
        _ai_set_model "$new_model"
        
        # Test the new model
        echo "🧪 Testing model..."
        local test_output
        test_output=$(sgpt --model="$new_model" "say ok" 2>&1)
        local test_exit=$?
        
        if [[ $test_exit -eq 0 ]]; then
            echo "✅ \033[1;32mModel test successful!\033[0m"
            echo "📋 Response: $test_output"
            echo ""
            echo "Current model: \033[1;32m$new_model\033[0m"
        else
            echo "❌ \033[1;31mModel test failed!\033[0m"
            echo "Error output: $test_output"
            echo ""
            echo "⚠️  Reverting to previous model: \033[1;33m$old_model\033[0m"
            _ai_set_model "$old_model"
            return 1
        fi
        
    elif [[ "$1" == "list" ]]; then
        local current_model=$(_ai_get_model)
        echo "Current model: \033[1;32m$current_model\033[0m"
        echo ""
        
        if [[ -f "$config_file" ]]; then
            local history_lines=$(grep "^history:" "$config_file" 2>/dev/null)
            if [[ -n "$history_lines" ]]; then
                echo "Usage history:"
                echo "$history_lines" | sed 's/^history://' | while IFS='=' read -r model timestamp; do
                    if [[ "$model" == "$current_model" ]]; then
                        echo "  \033[1;32m$model\033[0m (current) - last used: $timestamp"
                    else
                        echo "  \033[0;37m$model\033[0m - last used: $timestamp"
                    fi
                done
            else
                echo "No usage history yet."
            fi
        else
            echo "No usage history yet."
        fi
        
    else
        # Show current model (default behavior)
        local current_model=$(_ai_get_model)
        echo "Current model: \033[1;32m$current_model\033[0m"
        echo ""
        echo "Usage:"
        echo "  aimodel              - show current model"
        echo "  aimodel list         - list all models with usage history"
        echo "  aimodel set <model>  - set new model and test it"
    fi
}
