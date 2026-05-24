#!/bin/zsh

# Smart git add function - adds files with uncommitted changes matching patterns
ggup() {
  # Resolve file types to patterns; supports env default via GGUP_DEFAULT_TYPES
  local default_types
  default_types=${GGUP_DEFAULT_TYPES:-"ts py"}

  local raw_specs=()
  local no_args=0
  if [ $# -eq 0 ]; then
    no_args=1
    echo "🎯 No args provided — will patch-add all changes"
  else
    raw_specs=("$@")
  fi

  # Expand types to glob patterns. Accepts literal globs too.
  local patterns=()
  for spec in "${raw_specs[@]}"; do
    if [[ "$spec" == *"*"* || "$spec" == *"?"* || "$spec" == *"["* || "$spec" == *"]"* ]]; then
      patterns+=("$spec")
    elif [[ "$spec" == .* ]]; then
      patterns+=("*${spec#.}*")
    else
      patterns+=("*${spec}*")
    fi
  done
  if [ ${#patterns[@]} -gt 0 ]; then
    echo "📦 Patterns: ${patterns[@]}"
  fi

  # Get uncommitted changes (staged, unstaged, and untracked files)
  staged_files=$(git diff --cached --name-only | sort -u)
  unstaged_files=$(git diff --name-only | sort -u)
  untracked_files=$(git ls-files --others --exclude-standard | sort -u)
  
  # Combine all files into one list, filtering out empty lines more robustly
  all_files=$(printf "%s\n%s\n%s\n" "$staged_files" "$unstaged_files" "$untracked_files" | sort -u | sed '/^[[:space:]]*$/d')
  
  if [ -z "$all_files" ]; then
    echo "No uncommitted changes found"
    return 0
  fi

  # Resolve repo root so file existence checks work from any subdirectory
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

  echo "🔍 Uncommitted changes (staged, unstaged, and untracked files):"
  echo "$all_files" | sed 's/^/  /'
  echo ""

  # Collect all matching files first
  matching_files=()
  # Build add args from ORIGINAL user specs, each wrapped in *...*
  original_wrapped_specs=()
  for spec in "${raw_specs[@]}"; do
    original_wrapped_specs+=("*${spec}*")
  done
  
  # For each expanded pattern (only if any were provided)
  if [ ${#patterns[@]} -gt 0 ]; then
    for pattern in "${patterns[@]}"; do
      echo "📁 Looking for files matching: $pattern"
      
      # Match using shell globs against each file path
      found=0
      while IFS= read -r file; do
        if [[ "$file" == ${~pattern} ]]; then
          if [ -f "$repo_root/$file" ]; then
            echo "  ✅ Found: $file"
            matching_files+=("$file")
            found=1
          fi
        fi
      done <<< "$all_files"
      [ $found -eq 0 ] && echo "  ❌ No files matching '$pattern'"
    done
  fi

  # Run interactive git add
  echo ""
  if [ $no_args -eq 1 ]; then
    echo "🎯 Running interactive git add for ALL changes"
    echo "Actual command: git -C $repo_root add -up"
    git -C "$repo_root" add -up
  else
    echo "🎯 Running interactive git add using original patterns: ${original_wrapped_specs[*]}"
    echo "Actual command: git -C $repo_root add -up -- ${original_wrapped_specs[*]}"
    git -C "$repo_root" add -up -- "${original_wrapped_specs[@]}"
  fi

  echo "🎉 Interactive git add completed!"
}
