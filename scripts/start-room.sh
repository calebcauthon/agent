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
mkdir -p "$SESSIONS_DIR" "$CLAUDE_DATA_DIR" "$(dirname "$PORT_FILE")"

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
  if ! docker exec "$CONTAINER" command -v zsh >/dev/null 2>&1; then
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
    elif docker exec "$CONTAINER" git -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      register_portless_alias
      echo "container=${CONTAINER}"
      echo "status=running-detached"
      echo "port=${PORT}"
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

# Create isolated git worktree on its own branch
mkdir -p "$(dirname "$WORKTREE")"
if [ ! -d "$WORKTREE" ]; then
  git -C "$PROJECT" worktree add "$WORKTREE" -b "room/${ROOM}"
fi

COMMON_GIT_DIR="$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)"

DOCKER_RUN_ARGS=(
  --name "$CONTAINER"
  -p "${PORT}:3000"
  -v "${WORKTREE}:${WORKTREE}"
  -v "${PROJECT_NAME}-node-${ROOM}:${WORKTREE}/node_modules"
  -v "${SESSIONS_DIR}:/sessions"
  -v "${CLAUDE_DATA_DIR}:/home/the_agent/.claude"
  -v "${COMMON_GIT_DIR}:${COMMON_GIT_DIR}:ro"
  -w "${WORKTREE}"
)
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
echo "branch=room/${ROOM}"
echo "worktree=${WORKTREE}"
if [ -f "$PROJECT_ENV_FILE" ]; then
  echo "env_file=${PROJECT_ENV_FILE}"
fi
echo "next=agent -r ${ROOM}"
echo "dev_command=npm install && npm run dev -- -H 0.0.0.0"
