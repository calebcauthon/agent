#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: scripts/bump-version.sh [--patch|--minor|--major|VERSION] [--tap-dir DIR]' \
    '' \
    'Defaults to a patch bump from ./VERSION (for example, 0.1.2 -> 0.1.3).' \
    '' \
    'Environment:' \
    '  TAP_DIR   Path to the Homebrew tap checkout. If unset, the script tries' \
    "            \`brew --repository calebcauthon/agent\`." \
    '  REMOTE    Remote to use when a repo has no upstream configured (default: origin).'
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

release_archive_url() {
  local version="$1"
  printf 'https://github.com/calebcauthon/agent/archive/refs/tags/v%s.tar.gz\n' "$version"
}

update_formula_version() {
  local formula_file="$1"
  local old_version="$2"
  local new_version="$3"
  local archive_url

  archive_url="$(release_archive_url "$new_version")"

  if ! grep -Fq "$old_version" "$formula_file"; then
    echo "error: old version $old_version not found in $formula_file" >&2
    exit 1
  fi

  perl -0pi -e "s/\Q$old_version\E/$new_version/g" "$formula_file"
  perl -0pi -e "s{^([[:blank:]]*)url[[:blank:]]+\"[^\"]+\"[^\n]*}{\${1}url \"$archive_url\"}m" "$formula_file"
}

update_formula_sha256() {
  local formula_file="$1"
  local url=""
  local sha sha_count line

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*url[[:space:]]+\"([^\"]+)\" ]]; then
      url="${BASH_REMATCH[1]}"
      break
    fi
  done <"$formula_file"

  if [[ -z "$url" ]]; then
    echo "error: could not find a double-quoted url line in $formula_file" >&2
    exit 1
  fi

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

  sha_count="$(grep -Eoc "sha256[[:space:]]+\"[0-9a-fA-F]{64}\"" "$formula_file" || true)"
  case "$sha_count" in
    0)
      perl -0pi -e "s{(^[[:blank:]]*url[^\n]*\n)}{\${1}  sha256 \"$sha\"\n}m" "$formula_file"
      ;;
    1)
      perl -0pi -e "s/sha256\\s+\\\"[0-9a-fA-F]{64}\\\"/sha256 \\\"$sha\\\"/" "$formula_file"
      ;;
    *)
      echo "error: expected at most one source sha256 line in $formula_file; found $sha_count" >&2
      exit 1
      ;;
  esac
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
