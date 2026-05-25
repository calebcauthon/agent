#!/usr/bin/env bash
set -euo pipefail

ROOM="${1:?Usage: room <name>}"
PROJECT="${PROJECT:?PROJECT env var required (set automatically by shell functions)}"
PROJECT_NAME="$(basename "$PROJECT")"
CONTAINER="${PROJECT_NAME}-room-${ROOM}"
ROOMS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE="${HOME}/.rooms/worktrees/${PROJECT_NAME}/${ROOM}"
SESSIONS_DIR="${HOME}/.rooms/sessions/${PROJECT_NAME}/${ROOM}"
PORT_FILE="${HOME}/.rooms/ports/${PROJECT_NAME}/${ROOM}"
PROJECT_ENV_FILE="${PROJECT}/.env"

CLAUDE_DATA_DIR="${HOME}/.rooms/claude/${PROJECT_NAME}/${ROOM}"

CODEX_AUTH_SCOPE="${CODEX_AUTH_SCOPE:-global}"
case "$CODEX_AUTH_SCOPE" in
  global) CODEX_DATA_DIR="${HOME}/.rooms/codex/global" ;;
  project) CODEX_DATA_DIR="${HOME}/.rooms/codex/${PROJECT_NAME}" ;;
  room) CODEX_DATA_DIR="${HOME}/.rooms/codex/${PROJECT_NAME}/${ROOM}" ;;
  none) CODEX_DATA_DIR="" ;;
  *)
    echo "Invalid CODEX_AUTH_SCOPE='${CODEX_AUTH_SCOPE}' (use global, project, room, or none)" >&2
    exit 2
    ;;
esac

PI_AUTH_SCOPE="${PI_AUTH_SCOPE:-global}"
case "$PI_AUTH_SCOPE" in
  global) PI_DATA_DIR="${HOME}/.rooms/pi/global" ;;
  project) PI_DATA_DIR="${HOME}/.rooms/pi/${PROJECT_NAME}" ;;
  room) PI_DATA_DIR="${HOME}/.rooms/pi/${PROJECT_NAME}/${ROOM}" ;;
  none) PI_DATA_DIR="" ;;
  *)
    echo "Invalid PI_AUTH_SCOPE='${PI_AUTH_SCOPE}' (use global, project, room, or none)" >&2
    exit 2
    ;;
esac

mkdir -p "$SESSIONS_DIR" "$CLAUDE_DATA_DIR" "$(dirname "$PORT_FILE")"

seed_auth_file() {
  local source_file="$1"
  local target_file="$2"
  local label="$3"
  local target_contents=""

  if [ ! -f "$source_file" ]; then
    return 0
  fi

  if [ -f "$target_file" ]; then
    target_contents="$(tr -d '[:space:]' < "$target_file" 2>/dev/null || true)"
    if [ -n "$target_contents" ] && [ "$target_contents" != "{}" ]; then
      return 0
    fi
  fi

  cp -p "$source_file" "$target_file"
  SEEDED_FILES="${SEEDED_FILES:+${SEEDED_FILES},}${label}"
}

CODEX_SEEDED_FILES=""
SEEDED_FILES=""
if [ -n "$CODEX_DATA_DIR" ]; then
  mkdir -p "$CODEX_DATA_DIR"

  # Keep Codex CLI login usable in newly created rooms without mounting the whole
  # host ~/.codex directory (which also contains logs, sessions, and caches).
  HOST_CODEX_DIR="${HOME}/.codex"
  for CODEX_SEED_FILE in auth.json config.toml; do
    seed_auth_file "${HOST_CODEX_DIR}/${CODEX_SEED_FILE}" "${CODEX_DATA_DIR}/${CODEX_SEED_FILE}" "${CODEX_SEED_FILE}"
  done
  CODEX_SEEDED_FILES="$SEEDED_FILES"
fi

PI_SEEDED_FILES=""
SEEDED_FILES=""
if [ -n "$PI_DATA_DIR" ]; then
  mkdir -p "$PI_DATA_DIR"

  # Pi does not read ~/.codex/auth.json. Its ChatGPT/Codex OAuth and provider
  # API keys live in ~/.pi/agent/auth.json, with defaults in settings/models.
  # Seed only portable config/auth files, not host ~/.pi/agent/bin (macOS
  # binaries would not run in Linux containers).
  HOST_PI_DIR="${HOME}/.pi/agent"
  for PI_SEED_FILE in auth.json settings.json models.json; do
    seed_auth_file "${HOST_PI_DIR}/${PI_SEED_FILE}" "${PI_DATA_DIR}/${PI_SEED_FILE}" "${PI_SEED_FILE}"
  done
  PI_SEEDED_FILES="$SEEDED_FILES"
fi
unset SEEDED_FILES

mount_source_matches() {
  local actual="$1"
  local expected="$2"

  [ "$actual" = "$expected" ] || [ "$actual" = "/host_mnt${expected}" ]
}

print_auth_status() {
  if [ -n "$CODEX_DATA_DIR" ]; then
    echo "codex_auth=${CODEX_AUTH_SCOPE}:${CODEX_DATA_DIR}"
    if [ -n "$CODEX_SEEDED_FILES" ]; then
      printf 'codex_seeded_from_host=%s\n' "$CODEX_SEEDED_FILES"
    fi
  fi

  if [ -n "$PI_DATA_DIR" ]; then
    echo "pi_auth=${PI_AUTH_SCOPE}:${PI_DATA_DIR}"
    if [ -n "$PI_SEEDED_FILES" ]; then
      printf 'pi_seeded_from_host=%s\n' "$PI_SEEDED_FILES"
    fi
  fi
}

find_free_port() {
  python3 - <<'PY'
import socket
with socket.socket() as s:
    s.bind(("127.0.0.1", 0))
    print(s.getsockname()[1])
PY
}

register_portless_alias() {
  if command -v portless >/dev/null 2>&1; then
    portless alias "$ROOM" "$PORT" --force >/dev/null
    echo "url=https://${ROOM}.localhost"
  else
    echo "url=http://localhost:${PORT}"
    echo "warning=portless-not-found; install/use portless for https://${ROOM}.localhost"
  fi
}

saved_port() {
  cat "$PORT_FILE" 2>/dev/null || true
}

container_port() {
  docker inspect "$CONTAINER" \
    --format '{{with (index (index .NetworkSettings.Ports "3000/tcp") 0)}}{{.HostPort}}{{end}}' \
    2>/dev/null || true
}

choose_port() {
  local existing saved
  existing="$(container_port)"
  saved="$(saved_port)"

  if [ -n "$existing" ]; then
    echo "$existing"
  elif [ -n "$saved" ]; then
    echo "$saved"
  elif [ -n "${PORT:-}" ]; then
    echo "$PORT"
  else
    find_free_port
  fi
}

PORT="$(choose_port)"
export PORT
echo "$PORT" > "$PORT_FILE"

room_recreate_reason() {
  if ! docker exec "$CONTAINER" sh -lc 'command -v zsh' >/dev/null 2>&1; then
    echo "missing-zsh"
    return 0
  fi

  if ! docker exec "$CONTAINER" node -e '
const [major, minor, patch] = process.versions.node.split(".").map(Number);
process.exit(major > 22 || (major === 22 && (minor > 19 || (minor === 19 && patch >= 0))) ? 0 : 1);
' >/dev/null 2>&1; then
    echo "node-too-old"
    return 0
  fi

  if ! docker exec "$CONTAINER" node -e '
const cp = require("child_process");
const root = cp.execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
const pkg = require(root + "/@earendil-works/pi-coding-agent/package.json");
process.exit(pkg.version === "0.75.5" ? 0 : 1);
' >/dev/null 2>&1; then
    echo "pi-not-0.75.5"
    return 0
  fi

  if ! docker exec "$CONTAINER" test -f /opt/oh-my-zsh/oh-my-zsh.sh >/dev/null 2>&1; then
    echo "missing-oh-my-zsh"
    return 0
  fi

  if ! docker exec "$CONTAINER" test -d /opt/oh-my-zsh/custom/themes/powerlevel10k >/dev/null 2>&1; then
    echo "missing-powerlevel10k"
    return 0
  fi

  if ! docker exec "$CONTAINER" test -d /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions >/dev/null 2>&1; then
    echo "missing-zsh-autosuggestions"
    return 0
  fi

  if ! docker exec "$CONTAINER" test -d /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting >/dev/null 2>&1; then
    echo "missing-zsh-syntax-highlighting"
    return 0
  fi

  if ! docker exec "$CONTAINER" sh -lc 'command -v zoxide' >/dev/null 2>&1; then
    echo "missing-zoxide"
    return 0
  fi

  if [ -n "$CODEX_DATA_DIR" ]; then
    CODEX_MOUNT_SOURCE="$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/home/the_agent/.codex"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)"
    if ! mount_source_matches "$CODEX_MOUNT_SOURCE" "$CODEX_DATA_DIR"; then
      echo "codex-auth-mount-changed"
      return 0
    fi
  fi

  if [ -n "$PI_DATA_DIR" ]; then
    PI_MOUNT_SOURCE="$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/home/the_agent/.pi/agent"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)"
    if ! mount_source_matches "$PI_MOUNT_SOURCE" "$PI_DATA_DIR"; then
      echo "pi-auth-mount-changed"
      return 0
    fi
  fi
}

# Restart existing bash-detached containers. Recreate old rooms that were created
# with a foreground dev command, a broken git mount, or an outdated runtime so
# `agent ...` always leaves a healthy shell alive for agents.
if docker inspect "$CONTAINER" &>/dev/null; then
  CONTAINER_CMD="$(docker inspect "$CONTAINER" --format '{{json .Config.Cmd}}')"
  if [ "$CONTAINER_CMD" = '["bash"]' ]; then
    CONTAINER_STATUS="$(docker inspect "$CONTAINER" --format '{{.State.Status}}')"
    if [ "$CONTAINER_STATUS" != "running" ]; then
      docker start "$CONTAINER" >/dev/null
    fi

    RECREATE_REASON="$(room_recreate_reason)"
    if [ -n "$RECREATE_REASON" ]; then
      echo "container=${CONTAINER}"
      echo "status=recreating-${RECREATE_REASON}"
      docker rm -f "$CONTAINER" >/dev/null
    elif docker exec "$CONTAINER" git -c "safe.directory=${WORKTREE}" -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      register_portless_alias
      echo "container=${CONTAINER}"
      echo "status=running-detached"
      echo "port=${PORT}"
      print_auth_status
      echo "next=agent -r ${ROOM}"
      exit 0
    else
      echo "container=${CONTAINER}"
      echo "status=recreating-broken-git-mount"
      docker rm -f "$CONTAINER" >/dev/null
    fi
  else
    echo "container=${CONTAINER}"
    echo "status=recreating-non-detached-room"
    echo "old_cmd=${CONTAINER_CMD}"
    docker rm -f "$CONTAINER" >/dev/null
  fi
fi

# Create isolated git worktree on its own branch. Use a per-room ref directory
# (`refs/heads/room/<room>/head`) so the container can write lockfiles for its
# own branch without seeing sibling room branches.
ROOM_BRANCH="room/${ROOM}/head"
mkdir -p "$(dirname "$WORKTREE")"
if [ ! -d "$WORKTREE" ]; then
  if git -C "$PROJECT" show-ref --verify --quiet "refs/heads/room/${ROOM}"; then
    git -C "$PROJECT" worktree add "$WORKTREE" "room/${ROOM}"
  else
    git -C "$PROJECT" worktree add "$WORKTREE" -b "$ROOM_BRANCH"
  fi
fi

COMMON_GIT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)"
WORKTREE_GIT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-dir)"
CURRENT_BRANCH="$(git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

# Migrate old room branches (`room/<room>`) to the isolated layout for existing
# worktrees. This low-level move avoids the ref namespace conflict where the old
# ref file blocks creating `room/<room>/head` as a child ref.
if [ "$CURRENT_BRANCH" = "room/${ROOM}" ]; then
  CURRENT_SHA="$(git -C "$WORKTREE" rev-parse HEAD)"
  rm -f "${COMMON_GIT_DIR}/refs/heads/room/${ROOM}" "${COMMON_GIT_DIR}/logs/refs/heads/room/${ROOM}"
  mkdir -p "${COMMON_GIT_DIR}/refs/heads/room/${ROOM}" "${COMMON_GIT_DIR}/logs/refs/heads/room/${ROOM}"
  printf 'ref: refs/heads/%s\n' "$ROOM_BRANCH" > "${WORKTREE_GIT_DIR}/HEAD"
  printf '%s\n' "$CURRENT_SHA" > "${COMMON_GIT_DIR}/refs/heads/${ROOM_BRANCH}"
  : > "${COMMON_GIT_DIR}/logs/refs/heads/${ROOM_BRANCH}"
  CURRENT_BRANCH="$ROOM_BRANCH"
fi

if [ "$CURRENT_BRANCH" != "$ROOM_BRANCH" ]; then
  echo "Worktree ${WORKTREE} is on '${CURRENT_BRANCH:-detached}', expected '${ROOM_BRANCH}'." >&2
  echo "Remove or move that worktree before starting this room." >&2
  exit 1
fi

ROOM_BRANCH_REFS_DIR="${COMMON_GIT_DIR}/refs/heads/room/${ROOM}"
ROOM_BRANCH_LOGS_DIR="${COMMON_GIT_DIR}/logs/refs/heads/room/${ROOM}"
mkdir -p "${COMMON_GIT_DIR}/objects" "$ROOM_BRANCH_REFS_DIR" "$ROOM_BRANCH_LOGS_DIR"

DOCKER_RUN_ARGS=(
  --name "$CONTAINER"
  -p "${PORT}:3000"
  -v "${WORKTREE}:${WORKTREE}"
  -v "${PROJECT_NAME}-node-${ROOM}:${WORKTREE}/node_modules"
  -v "${SESSIONS_DIR}:/sessions"
  -v "${CLAUDE_DATA_DIR}:/home/the_agent/.claude"
  -v "${WORKTREE_GIT_DIR}:${WORKTREE_GIT_DIR}"
  -v "${COMMON_GIT_DIR}/objects:${COMMON_GIT_DIR}/objects"
  -v "${ROOM_BRANCH_REFS_DIR}:${ROOM_BRANCH_REFS_DIR}"
  -v "${ROOM_BRANCH_LOGS_DIR}:${ROOM_BRANCH_LOGS_DIR}"
  -w "${WORKTREE}"
)
if [ -n "$CODEX_DATA_DIR" ]; then
  DOCKER_RUN_ARGS+=(-v "${CODEX_DATA_DIR}:/home/the_agent/.codex")
fi
if [ -n "$PI_DATA_DIR" ]; then
  DOCKER_RUN_ARGS+=(-v "${PI_DATA_DIR}:/home/the_agent/.pi/agent")
fi
if [ -f "$PROJECT_ENV_FILE" ]; then
  DOCKER_RUN_ARGS+=(--env-file "$PROJECT_ENV_FILE")
fi
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  DOCKER_RUN_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi
DOCKER_RUN_ARGS+=("${PROJECT_NAME}-room" bash)

# Use project's Dockerfile if it has one, otherwise fall back to rooms default
if [ -f "${PROJECT}/Dockerfile" ]; then
  docker build -t "${PROJECT_NAME}-room" "$PROJECT"
else
  docker build -t "${PROJECT_NAME}-room" "$ROOMS_DIR"
fi

# Keep the room alive with a detached bash process. Agents attach later via tmux.
docker run -dit "${DOCKER_RUN_ARGS[@]}" >/dev/null

register_portless_alias
echo "container=${CONTAINER}"
echo "status=created-detached"
echo "port=${PORT}"
echo "branch=${ROOM_BRANCH}"
echo "worktree=${WORKTREE}"
if [ -f "$PROJECT_ENV_FILE" ]; then
  echo "env_file=${PROJECT_ENV_FILE}"
fi
print_auth_status
echo "next=agent -r ${ROOM}"
echo "dev_command=npm install && npm run dev -- -H 0.0.0.0"
