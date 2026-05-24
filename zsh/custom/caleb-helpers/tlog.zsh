#!/bin/zsh

# tlog - Run commands while teeing stdout+stderr to per-concern log files
# Usage: tlog <concern> <command> [args...]
#        tlog latest <concern>
#        tlog copy <concern>
#        tlog read <concern>
#        tlog tail <concern>
# Logs go to ~/.devhub/logs/<concern>.log

tlog() {
    # Handle 'latest' subcommand
    if [[ "$1" == "latest" ]]; then
        local concern="$2"
        [[ -z "$concern" ]] && { echo "Usage: tlog latest <concern>" >&2; return 1; }
        
        local log_dir="$HOME/.devhub/logs"
        local log_file="$log_dir/$concern.log"
        
        [[ ! -f "$log_file" ]] && { echo "No log file found for concern: $concern" >&2; return 1; }
        
        # Find line number of last separator
        local last_sep_line=$(grep -an '^>>> TLOG_RUN_START:' "$log_file" | tail -1 | cut -d: -f1)
        
        if [[ -z "$last_sep_line" ]]; then
            echo "No separator found in log file for concern: $concern" >&2
            return 1
        fi
        
        # Print from that line onwards
        tail -n +"$last_sep_line" "$log_file"
        return 0
    fi

    # Handle 'copy' subcommand
    if [[ "$1" == "copy" ]]; then
        local concern="$2"
        [[ -z "$concern" ]] && { echo "Usage: tlog copy <concern>" >&2; return 1; }
        
        local log_dir="$HOME/.devhub/logs"
        local log_file="$log_dir/$concern.log"
        
        [[ ! -f "$log_file" ]] && { echo "No log file found for concern: $concern" >&2; return 1; }
        
        # Find line number of last separator
        local last_sep_line=$(grep -an '^>>> TLOG_RUN_START:' "$log_file" | tail -1 | cut -d: -f1)
        
        if [[ -z "$last_sep_line" ]]; then
            echo "No separator found in log file for concern: $concern" >&2
            return 1
        fi
        
        # Copy from that line onwards to clipboard
        tail -n +"$last_sep_line" "$log_file" | pbcopy
        return 0
    fi

    # Handle 'read' subcommand
    if [[ "$1" == "read" ]]; then
        local concern="$2"
        [[ -z "$concern" ]] && { echo "Usage: tlog read <concern>" >&2; return 1; }
        
        local log_dir="$HOME/.devhub/logs"
        local log_file="$log_dir/$concern.log"
        
        [[ ! -f "$log_file" ]] && { echo "No log file found for concern: $concern" >&2; return 1; }
        
        cat "$log_file"
        return 0
    fi

    # Handle 'tail' subcommand
    if [[ "$1" == "tail" ]]; then
        local concern="$2"
        [[ -z "$concern" ]] && { echo "Usage: tlog tail <concern>" >&2; return 1; }
        
        local log_dir="$HOME/.devhub/logs"
        local log_file="$log_dir/$concern.log"
        
        [[ ! -f "$log_file" ]] && { echo "No log file found for concern: $concern" >&2; return 1; }
        
        tail -f "$log_file"
        return 0
    fi

    local concern="$1"
    shift

    [[ -z "$concern" ]] && { echo "Usage: tlog <concern> <command> [args...]" >&2; return 1; }
    [[ $# -eq 0 ]] && { echo "Usage: tlog <concern> <command> [args...]" >&2; return 1; }

    local log_dir="$HOME/.devhub/logs"
    local log_file="$log_dir/$concern.log"

    mkdir -p "$log_dir"

    # Timestamp header for each invocation with unique separator
    echo -e "\n>>> TLOG_RUN_START: $(date '+%Y-%m-%d %H:%M:%S') | $* <<<" >> "$log_file"

    if command -v unbuffer &>/dev/null; then
        # unbuffer (from expect) is the cleanest PTY wrapper
        unbuffer "$@" 2>&1 | tee -a "$log_file"
        local exit_code=${pipestatus[1]}
    elif command -v stdbuf &>/dev/null; then
        # stdbuf forces line buffering without PTY overhead
        stdbuf -oL -eL "$@" 2>&1 | tee -a "$log_file"
        local exit_code=${pipestatus[1]}
    else
        # Fallback: script for PTY, sed -l for line-buffered filtering
        script -q /dev/null "$@" 2>&1 | sed -l $'s/\\^D\x08\x08//g' | tee -a "$log_file"
        local exit_code=${pipestatus[1]}
    fi

    # Automatically copy the last run to clipboard in LLM-friendly format
    local last_sep_line=$(grep -an '^>>> TLOG_RUN_START:' "$log_file" | tail -1 | cut -d: -f1)
    if [[ -n "$last_sep_line" ]]; then
        local run_content=$(tail -n +"$last_sep_line" "$log_file")
        local line_count=$(echo "$run_content" | wc -l | tr -d ' ')

        # Extract command from the header line
        local command_line=$(echo "$run_content" | head -1)
        local command=$(echo "$command_line" | sed 's/.*| \(.*\) <<<.*/\1/')

        # Format for clipboard
        local clipboard_content="---
Ran this command: $command
Got this output:
"

        if [[ $line_count -le 150 ]]; then
            # For output ≤150 lines: copy command + full output
            clipboard_content+=$(echo "$run_content" | tail -n +2)
        else
            # For output >150 lines: copy command + first 10 lines + last 100 lines
            local first_10=$(echo "$run_content" | head -10 | tail -n +2)
            local last_100=$(echo "$run_content" | tail -100)
            clipboard_content+=$(echo -e "$first_10\n\n...\n\n$last_100")
        fi

        clipboard_content+="
---
"

        # Copy to clipboard
        echo "$clipboard_content" | pbcopy
    fi

    return $exit_code
}
