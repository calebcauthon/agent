#!/usr/bin/env bash
set -euo pipefail

ROOM="${1:?Usage: agent <room> [agent-name]}"
PROJECT="${PROJECT:-$PWD}"
PROJECT_NAME="$(basename "$PROJECT")"
PROJECT_ENV_FILE="${PROJECT}/.env"

# Accept either the full container name or just the room name
if docker inspect "$ROOM" &>/dev/null 2>&1; then
  CONTAINER="$ROOM"
else
  CONTAINER="${PROJECT_NAME}-room-${ROOM}"
fi

if [ -n "${2:-}" ]; then
  AGENT="$2"
else
  ADJECTIVES=(amber azure coral dusty ember frost golden jade misty rusty silver teal)
  ANIMALS=(bear crane deer eagle finch hawk ibis jay kite lynx mole newt)
  NUM=$(( RANDOM % 100 ))
  ADJ=${ADJECTIVES[$((RANDOM % ${#ADJECTIVES[@]}))]}
  ANI=${ANIMALS[$((RANDOM % ${#ANIMALS[@]}))]}
  AGENT="${ADJ}-${ANI}-${NUM}"
fi

STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "missing")
if [ "$STATUS" != "running" ]; then
  echo "Room '${ROOM}' is not running (status: ${STATUS})"
  echo "  → room ${ROOM}"
  exit 1
fi

echo "agent '${AGENT}' in room '${ROOM}' (${PROJECT_NAME})"
WORKDIR="$(docker inspect "$CONTAINER" --format '{{.Config.WorkingDir}}')"

# Ensure the_agent user exists, owns /sessions, and has claude auto-authorized
docker exec "$CONTAINER" bash -c "
  if ! id the_agent &>/dev/null; then
    useradd -m -s /bin/bash the_agent
  fi
  mkdir -p /home/the_agent/.claude /sessions/${AGENT}
  chown the_agent:the_agent /home/the_agent 2>/dev/null || true
  chown -R the_agent:the_agent /home/the_agent/.claude /sessions 2>/dev/null || true
"

# Copy in claude settings (base from rooms, overridden by project if present)
CLAUDE_SETTINGS="${_ROOMS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}/claude-settings.json"
docker cp "$CLAUDE_SETTINGS" "$CONTAINER":/home/the_agent/.claude/settings.json
docker exec "$CONTAINER" chown the_agent:the_agent /home/the_agent/.claude/settings.json

# Apply project-level override if one exists
PROJECT_SETTINGS="${PROJECT}/.claude/agent-settings.json"
if [ -f "$PROJECT_SETTINGS" ]; then
  docker cp "$PROJECT_SETTINGS" "$CONTAINER":/home/the_agent/.claude/settings.json
  docker exec "$CONTAINER" chown the_agent:the_agent /home/the_agent/.claude/settings.json
fi

# Make git usable for the non-root agent and fail clearly if the room was
# created with a stale/broken git metadata mount.
docker exec -u the_agent "$CONTAINER" git config --global --add safe.directory "$WORKDIR" >/dev/null
if ! docker exec -u the_agent "$CONTAINER" git -C "$WORKDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Room '${ROOM}' has a broken git mount. Repair it with:"
  echo "  room ${ROOM}"
  exit 1
fi

docker exec "$CONTAINER" bash -c "
  {
    echo 'export HISTFILE=/sessions/${AGENT}/.bash_history'
    echo 'export HISTSIZE=50000'
    echo 'export HISTFILESIZE=50000'
    echo \"export PROMPT_COMMAND='history -a'\"
    echo \"trap 'history -a' EXIT\"
    echo 'export ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}'
    echo 'history -r 2>/dev/null || true'
    echo '[ -f /home/the_agent/.bashrc ] && source /home/the_agent/.bashrc'
  } > /sessions/${AGENT}/init.sh
  chown the_agent:the_agent /sessions/${AGENT}/init.sh
"

EXEC_ENV_ARGS=()
if [ -f "$PROJECT_ENV_FILE" ]; then
  EXEC_ENV_ARGS+=(--env-file "$PROJECT_ENV_FILE")
fi
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  EXEC_ENV_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi

if [ -f "$PROJECT_ENV_FILE" ]; then
  echo "env_file=${PROJECT_ENV_FILE}"
fi

docker exec -it -u the_agent "${EXEC_ENV_ARGS[@]}" "$CONTAINER" \
  tmux new-session -A -s "${AGENT}" "bash --init-file /sessions/${AGENT}/init.sh"
