# Small composable helpers for rooms agent shells.

mkcd() {
  if [ "$#" -ne 1 ]; then
    echo "usage: mkcd <dir>" >&2
    return 2
  fi
  mkdir -p "$1" && cd "$1"
}

path() {
  print -l ${(s/:/)PATH}
}

ports() {
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tulpn
  else
    echo "ports: neither ss nor netstat is installed" >&2
    return 1
  fi
}

json-pretty() {
  node -e '
const fs = require("fs");
const input = process.argv[1] ? fs.readFileSync(process.argv[1], "utf8") : fs.readFileSync(0, "utf8");
console.log(JSON.stringify(JSON.parse(input), null, 2));
' "$@"
}
