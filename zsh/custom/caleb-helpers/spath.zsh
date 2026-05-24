#!/bin/zsh

# ss - Get the full path of the most recently modified file in Screenshots
# Usage: ss
# Outputs the absolute path of the last modified file in ~/Screenshots

ss() {
  local screenshots_dir="${HOME}/Screenshots"
  
  # Check if directory exists
  [[ -d "$screenshots_dir" ]] || {
    echo "❌ Screenshots directory not found: ~/Screenshots" >&2
    return 1
  }
  
  # Find most recently modified file
  local latest_file
  latest_file=$(ls -t "$screenshots_dir" 2>/dev/null | head -n1)
  
  # Check if any files exist
  [[ -n "$latest_file" ]] || {
    echo "❌ No files found in $screenshots_dir" >&2
    return 1
  }
  
  # Output full path
  local full_path="${screenshots_dir}/${latest_file}"
  echo "$full_path"
}
