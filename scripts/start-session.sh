#!/usr/bin/env bash
set -euo pipefail

ROOM="${1:?Usage: agent <room> [agent-name]}"
PROJECT="${PROJECT:-$PWD}"
PROJECT_NAME="$(basename "$PROJECT")"
PROJECT_ENV_FILE="${PROJECT}/.env"
ROOMS_DIR="${_ROOMS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

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

# Ensure the_agent user exists, uses zsh, owns /sessions, and has claude auto-authorized.
if ! docker exec "$CONTAINER" sh -lc 'command -v zsh' >/dev/null 2>&1; then
  echo "Room '${ROOM}' does not have zsh installed. Rebuild/recreate it with:"
  echo "  rooms rm ${CONTAINER}"
  echo "  agent ${AGENT} -r ${ROOM}"
  exit 1
fi

docker exec "$CONTAINER" bash -c "
  if ! id the_agent &>/dev/null; then
    useradd -m -s /bin/zsh the_agent
  else
    usermod -s /bin/zsh the_agent 2>/dev/null || true
  fi
  mkdir -p /home/the_agent/.claude /home/the_agent/.rooms-zsh /sessions/${AGENT}
  chown the_agent:the_agent /home/the_agent 2>/dev/null || true
  chown -R the_agent:the_agent /home/the_agent/.claude /home/the_agent/.rooms-zsh /sessions 2>/dev/null || true
"

# Copy in shared zsh settings. Per-agent rc files source /home/the_agent/.zshrc.
ZSH_CONFIG_DIR="${ROOMS_DIR}/zsh"
if [ -f "${ZSH_CONFIG_DIR}/zshrc" ]; then
  docker cp "${ZSH_CONFIG_DIR}/zshrc" "$CONTAINER":/home/the_agent/.zshrc
  if [ -f "${ZSH_CONFIG_DIR}/p10k.zsh" ]; then
    docker cp "${ZSH_CONFIG_DIR}/p10k.zsh" "$CONTAINER":/home/the_agent/.rooms-zsh/p10k.zsh
  fi
  if [ -d "${ZSH_CONFIG_DIR}/custom" ]; then
    docker exec "$CONTAINER" rm -rf /home/the_agent/.rooms-zsh/custom
    docker cp "${ZSH_CONFIG_DIR}/custom" "$CONTAINER":/home/the_agent/.rooms-zsh/custom
  fi
  docker exec "$CONTAINER" chown -R the_agent:the_agent /home/the_agent/.zshrc /home/the_agent/.rooms-zsh
fi

# Copy in shared tmux settings. Existing tmux servers are re-sourced below.
TMUX_CONFIG="${ROOMS_DIR}/tmux/tmux.conf"
if [ -f "$TMUX_CONFIG" ]; then
  docker cp "$TMUX_CONFIG" "$CONTAINER":/home/the_agent/.tmux.conf
  docker exec "$CONTAINER" chown the_agent:the_agent /home/the_agent/.tmux.conf
  docker exec -u the_agent "$CONTAINER" tmux -u source-file /home/the_agent/.tmux.conf >/dev/null 2>&1 || true
fi

# Copy in claude settings (base from rooms, overridden by project if present)
CLAUDE_SETTINGS="${ROOMS_DIR}/claude-settings.json"
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
  cat > /sessions/${AGENT}/.zshrc <<'EOF'
export HISTFILE=/sessions/${AGENT}/.zsh_history
export HISTSIZE=50000
export SAVEHIST=50000
setopt append_history inc_append_history share_history hist_ignore_dups 2>/dev/null || true
export ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}
[ -f /home/the_agent/.zshrc ] && source /home/the_agent/.zshrc
EOF
  chown the_agent:the_agent /sessions/${AGENT}/.zshrc
"

DOCKER_EXEC_ARGS=(-it -u the_agent -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e TERM=xterm-256color -e COLORTERM=truecolor)
if [ -f "$PROJECT_ENV_FILE" ]; then
  DOCKER_EXEC_ARGS+=(--env-file "$PROJECT_ENV_FILE")
fi
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  DOCKER_EXEC_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi

if [ -f "$PROJECT_ENV_FILE" ]; then
  echo "env_file=${PROJECT_ENV_FILE}"
fi

docker exec "${DOCKER_EXEC_ARGS[@]}" "$CONTAINER" \
  tmux -u new-session -A -s "${AGENT}" "ZDOTDIR=/sessions/${AGENT} zsh -l"
