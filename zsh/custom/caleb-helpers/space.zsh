unalias space 2>/dev/null
_space_analyze() {
  local show_all=$1
  local prefix=$2
  
  local total_kb=$(du -sk . 2>/dev/null | cut -f1)
  if [[ -z "$total_kb" || "$total_kb" -eq 0 ]]; then
    return
  fi
  
  du -k -d 1 . 2>/dev/null | awk -v total="$total_kb" '$1 >= 1024 && $2 != "." {
    sub(/^\.\//, "", $2)
    print $1, $2
  }' | sort -n | awk -v total="$total_kb" -v show_all="$show_all" -v prefix="$prefix" '
    {sizes[NR]=$1; names[NR]=$2}
    END {
      if (total == 0) exit
      for (i=1; i<=NR; i++) {
        pct = int(sizes[i] / total * 20)
        if (pct >= 1 || show_all == 1) {
          bar = sprintf("[%-20s]", substr("####################", 1, pct))
          if (sizes[i] >= 1048576) printf "%s%6.1fG %s %s\n", prefix, sizes[i]/1048576, bar, names[i]
          else printf "%s%6.1fM %s %s\n", prefix, sizes[i]/1024, bar, names[i]
        }
      }
    }'
}

space() {
  local show_all=0
  local follow=0
  
  # Parse flags
  for arg in "$@"; do
    case "$arg" in
      -a|--all) show_all=1 ;;
      -f|--follow) follow=1 ;;
    esac
  done
  
  local total_kb=$(du -sk . 2>/dev/null | cut -f1)
  if [[ -z "$total_kb" || "$total_kb" -eq 0 ]]; then
    echo "Total: $(du -sh . 2>/dev/null | cut -f1)"
    return
  fi
  
  # Get top-level items
  local items=$(du -k -d 1 . 2>/dev/null | awk -v total="$total_kb" '$1 >= 1024 && $2 != "." {
    sub(/^\.\//, "", $2)
    print $1, $2
  }' | sort -n)
  
  # Process and display items, collecting directories that appeared
  local dirs_to_follow=""
  local output=$(echo "$items" | awk -v total="$total_kb" -v show_all="$show_all" '
    {sizes[NR]=$1; names[NR]=$2}
    END {
      if (total == 0) exit
      for (i=1; i<=NR; i++) {
        pct = int(sizes[i] / total * 20)
        if (pct >= 1 || show_all == 1) {
          bar = sprintf("[%-20s]", substr("####################", 1, pct))
          if (sizes[i] >= 1048576) printf "%6.1fG %s %s\n", sizes[i]/1048576, bar, names[i]
          else printf "%6.1fM %s %s\n", sizes[i]/1024, bar, names[i]
        }
      }
    }')
  
  echo "$output"
  
  # Collect directories to follow
  if [[ $follow -eq 1 ]]; then
    echo "$items" | awk -v total="$total_kb" -v show_all="$show_all" '
      {sizes[NR]=$1; names[NR]=$2}
      END {
        if (total == 0) exit
        for (i=1; i<=NR; i++) {
          pct = int(sizes[i] / total * 20)
          if (pct >= 1 || show_all == 1) {
            print names[i]
          }
        }
      }' | while IFS= read -r item; do
      if [[ -d "$item" ]]; then
        echo ""
        echo "  └─ $item/"
        (cd "$item" && _space_analyze "$show_all" "    ")
      fi
    done
  fi
  
  echo "---"
  echo "Total: $(du -sh . 2>/dev/null | cut -f1)"
}

