#!/bin/zsh

# Initialize an AI-first project structure with goal files and iteration folders
# Creates: goal.md in root, iteration_01/ folder with agents.md, goal.md, conclusion.md
init_project() {
  # Check if we're in a git repo or warn about running in project root
  if [[ ! -d ".git" && ! -f "README.md" && ! -f "package.json" ]]; then
    echo "⚠️  Warning: No .git/, README.md, or package.json found"
    echo "   Run this from your project root directory"
    read "response?Continue anyway? [y/N] "
    [[ "$response" =~ ^[Yy]$ ]] || return 1
  fi

  local iter_dir="iteration_01"
  local created_count=0

  echo "🚀 Initializing AI-first project structure..."
  echo ""

  # Create root goal.md if it doesn't exist
  if [[ -f "goal.md" ]]; then
    echo "⏭️  goal.md already exists, skipping"
  else
    echo "📄 Creating goal.md"
    touch "goal.md"
    ((created_count++))
  fi

  # Create iteration_01 directory
  if [[ -d "$iter_dir" ]]; then
    echo "⏭️  $iter_dir/ already exists, checking contents..."
  else
    echo "📁 Creating $iter_dir/"
    mkdir -p "$iter_dir"
  fi

  # Create blank files in iteration_01
  local iter_files=("agents.md" "goal.md" "conclusion.md")
  for file in "${iter_files[@]}"; do
    local full_path="$iter_dir/$file"
    if [[ -f "$full_path" ]]; then
      echo "  ⏭️  $file already exists"
    else
      echo "  📄 Creating $file"
      touch "$full_path"
      ((created_count++))
    fi
  done

  echo ""
  echo "✅ Project structure initialized!"
  echo ""
  echo "📋 Structure:"
  echo "  goal.md"
  echo "  $iter_dir/"
  echo "    ├── agents.md"
  echo "    ├── goal.md"
  echo "    └── conclusion.md"
  echo ""
  echo "🎯 Next steps:"
  echo "  1. Fill out goal.md with your high-level objective"
  echo "  2. Add project context to $iter_dir/agents.md"
  echo "  3. Define specific iteration goal in $iter_dir/goal.md"
  echo "  4. Run AI session, then document results in $iter_dir/conclusion.md"

  return 0
}

# Short alias
alias iproj='init_project'
