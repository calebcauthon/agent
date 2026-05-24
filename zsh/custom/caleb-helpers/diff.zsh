# smart diff wrapper: `diff <text>` → `git diff -- "*<text>*"` in git repos
diff() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ "$#" -eq 0 ]; then
      git diff
    elif [ "$#" -eq 2 ] && [[ "$2" == "xx" ]] && [[ "$1" != -* ]]; then
      git checkout -- "*${1}*"
    elif [ "$#" -eq 1 ] && [[ "$1" != -* ]]; then
      git diff -- "*${1}*"
    else
      command diff "$@"
    fi
  else
    command diff "$@"
  fi
}


dif() {
  diff "$@"
}


