#!/usr/bin/env bash
# Add to ~/.zshrc:  source ~/code/rooms/shell.sh

_ROOMS_DIR="${HOME}/code/rooms"

room() {
  local name="${1:?Usage: room <name>}"
  PROJECT="$PWD" bash "${_ROOMS_DIR}/scripts/start-room.sh" "$name"
}

agent() {
  local room_name="${1:?Usage: agent <room> [agent-name]}"
  PROJECT="$PWD" bash "${_ROOMS_DIR}/scripts/start-session.sh" "$room_name" "${2:-}"
}

logs() {
  local room_name="${1:?Usage: logs <room>}"
  if docker inspect "$room_name" &>/dev/null 2>&1; then
    docker logs -f "$room_name"
  else
    docker logs -f "$(basename "$PWD")-room-${room_name}"
  fi
}

rooms() {
  case "${1:-}" in
    rm)
      local container="${2:?Usage: rooms rm <container-name>}"
      docker rm -f "$container"
      ;;
    *)
      docker ps -a \
        --filter "name=-room-" \
        --format "table {{.Names}}\t{{.Status}}"
      ;;
  esac
}

agents() {
  case "${1:-}" in
    rm)
      local room="${2:?Usage: agents rm <room> <agent-name>}"
      local agent_name="${3:?Usage: agents rm <room> <agent-name>}"
      local container
      if docker inspect "$room" &>/dev/null 2>&1; then
        container="$room"
      else
        container="$(basename "$PWD")-room-${room}"
      fi
      docker exec "$container" tmux kill-session -t "$agent_name" 2>/dev/null \
        && echo "agent '${agent_name}' removed" \
        || echo "agent '${agent_name}' not found"
      ;;
    *)
      local room_name="${1:?Usage: agents <room>}"
      local container
      if docker inspect "$room_name" &>/dev/null 2>&1; then
        container="$room_name"
      else
        container="$(basename "$PWD")-room-${room_name}"
      fi
      docker exec "$container" tmux list-sessions -F "#{session_name}" 2>/dev/null \
        || echo "no agents running in room '${room_name}'"
      ;;
  esac
}
