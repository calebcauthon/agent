#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/bump-version.sh [--patch|--minor|--major|VERSION] [--tap-dir DIR]

Defaults to a patch bump from ./VERSION (for example, 0.1.2 -> 0.1.3).

Environment:
  TAP_DIR   Path to the Homebrew tap checkout. If unset, the script tries
            `brew --repository calebcauthon/agent`.
  REMOTE    Remote to use when a repo has no upstream configured (default: origin).
USAGE
}

bump_part="patch"
explicit_version=""
tap_dir="${TAP_DIR:-}"
remote="${REMOTE:-origin}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major|--minor|--patch)
      bump_part="${1#--}"
      shift
      ;;
    major|minor|patch)
      bump_part="$1"
      shift
      ;;
    --version)
      [[ $# -ge 2 ]] || { echo "error: --version needs a value" >&2; exit 2; }
      explicit_version="$2"
      shift 2
      ;;
    --tap-dir)
      [[ $# -ge 2 ]] || { echo "error: --tap-dir needs a directory" >&2; exit 2; }
      tap_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    [0-9]*.[0-9]*.[0-9]*)
      explicit_version="$1"
      shift
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

source_dir="$PWD"
version_file="$source_dir/VERSION"

require_clean_repo() {
  local dir="$1"
  local label="$2"

  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null
  if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
    echo "error: $label has uncommitted changes; commit or stash them first" >&2
    git -C "$dir" status --short >&2
    exit 1
  fi
}

push_repo() {
  local dir="$1"
  local with_tags="$2"
  local branch

  if git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    if [[ "$with_tags" == "yes" ]]; then
      git -C "$dir" push --follow-tags
    else
      git -C "$dir" push
    fi
    return
  fi

  branch="$(git -C "$dir" branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "error: cannot push $dir because it is in a detached HEAD state" >&2
    exit 1
  fi

  if [[ "$with_tags" == "yes" ]]; then
    git -C "$dir" push -u "$remote" "$branch" --follow-tags
  else
    git -C "$dir" push -u "$remote" "$branch"
  fi
}

semver_bump() {
  local version="$1"
  local part="$2"
  local major minor patch

  IFS=. read -r major minor patch <<<"$version"
  if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
    echo "error: VERSION must be in MAJOR.MINOR.PATCH format; got '$version'" >&2
    exit 1
  fi

  case "$part" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
  esac
}

detect_tap_dir() {
  if [[ -n "$tap_dir" ]]; then
    printf '%s\n' "$tap_dir"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    if brew --repository calebcauthon/agent >/dev/null 2>&1; then
      brew --repository calebcauthon/agent
      return
    fi
  fi

  echo "error: could not find the tap checkout; pass --tap-dir DIR or set TAP_DIR" >&2
  exit 1
}

update_formula_version() {
  local formula_file="$1"
  local old_version="$2"
  local new_version="$3"

  FORMULA_FILE="$formula_file" OLD_VERSION="$old_version" NEW_VERSION="$new_version" python3 <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["FORMULA_FILE"])
old_source_version = os.environ["OLD_VERSION"]
new_version = os.environ["NEW_VERSION"]
text = path.read_text()

candidates = [old_source_version]
for pattern in (
    r'\bversion\s+["\'](\d+\.\d+\.\d+)["\']',
    r'\bv(\d+\.\d+\.\d+)\b',
):
    match = re.search(pattern, text)
    if match:
        candidates.append(match.group(1))

updated = text
for old_version in sorted(set(candidates), key=len, reverse=True):
    updated = re.sub(rf'(?<!\d){re.escape(old_version)}(?!\d)', new_version, updated)

if updated == text:
    raise SystemExit(f"error: no version string updated in {path}")

path.write_text(updated)
PY
}

update_formula_sha256() {
  local formula_file="$1"
  local url sha tmp_url

  tmp_url="$(mktemp)"
  FORMULA_FILE="$formula_file" python3 <<'PY' >"$tmp_url"
import os
import re
from pathlib import Path

text = Path(os.environ["FORMULA_FILE"]).read_text()
match = re.search(r'^\s*url\s+["\']([^"\']+)["\']', text, re.MULTILINE)
if not match:
    raise SystemExit("error: could not find a url line in the formula")
print(match.group(1))
PY
  url="$(<"$tmp_url")"
  rm -f "$tmp_url"

  case "$url" in
    http://*|https://*) ;;
    *)
      echo "error: formula URL is not downloadable: $url" >&2
      exit 1
      ;;
  esac

  echo "Downloading $url to calculate sha256..."
  sha="$(curl -fsSL "$url" | shasum -a 256)"
  sha="${sha%% *}"

  FORMULA_FILE="$formula_file" SHA256="$sha" python3 <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["FORMULA_FILE"])
sha = os.environ["SHA256"]
text = path.read_text()
updated, count = re.subn(r'sha256\s+["\'][0-9a-fA-F]{64}["\']', f'sha256 "{sha}"', text, count=1)
if count != 1:
    raise SystemExit(f"error: expected exactly one source sha256 line in {path}")
path.write_text(updated)
PY
}

[[ -f "$version_file" ]] || { echo "error: VERSION not found in current directory: $source_dir" >&2; exit 1; }
old_version="$(tr -d "[:space:]" <"$version_file")"
new_version="${explicit_version:-$(semver_bump "$old_version" "$bump_part")}"

if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: new version must be MAJOR.MINOR.PATCH; got '$new_version'" >&2
  exit 1
fi
if [[ "$new_version" == "$old_version" ]]; then
  echo "error: new version is the same as current VERSION ($old_version)" >&2
  exit 1
fi

tap_dir="$(detect_tap_dir)"
formula_file="$tap_dir/Formula/agent.rb"
[[ -f "$formula_file" ]] || { echo "error: formula not found: $formula_file" >&2; exit 1; }

require_clean_repo "$source_dir" "source repo"
require_clean_repo "$tap_dir" "tap repo"

if git -C "$source_dir" rev-parse "v$new_version" >/dev/null 2>&1; then
  echo "error: tag v$new_version already exists in source repo" >&2
  exit 1
fi

echo "Bumping agent $old_version -> $new_version"
echo "$new_version" >"$version_file"

git -C "$source_dir" add VERSION
git -C "$source_dir" commit -m "Release v$new_version"
git -C "$source_dir" tag -a "v$new_version" -m "Release v$new_version"
push_repo "$source_dir" yes

update_formula_version "$formula_file" "$old_version" "$new_version"
update_formula_sha256 "$formula_file"

git -C "$tap_dir" add Formula/agent.rb
git -C "$tap_dir" commit -m "agent $new_version"
push_repo "$tap_dir" no

echo "Released v$new_version and updated $formula_file"
