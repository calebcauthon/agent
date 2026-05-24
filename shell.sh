#!/usr/bin/env bash
# Add to ~/.zshrc:  source ~/code/rooms/shell.sh

# Directory containing this repo's scripts/config. Homebrew wrappers set _ROOMS_DIR;
# local installs can set ROOMS_DIR; otherwise keep the historical checkout path.
_ROOMS_DIR="${_ROOMS_DIR:-${ROOMS_DIR:-${HOME}/code/rooms}}"

_rooms_project_slug() {
  local slug
  slug="$(basename "$PWD" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "${slug:-project}"
}

_rooms_default_room() {
  printf 'default-%s' "$(_rooms_project_slug)"
}

room() {
  local name="${1:-$(_rooms_default_room)}"
  PROJECT="$PWD" bash "${_ROOMS_DIR}/scripts/start-room.sh" "$name"
}

agent() {
  local room_name agent_name
  room_name="$(_rooms_default_room)"
  agent_name=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--room)
        shift
        if [ "$#" -eq 0 ]; then
          echo "Usage: agent [agent-name] [-r room-name]" >&2
          return 2
        fi
        room_name="$1"
        ;;
      -h|--help)
        echo "Usage: agent [agent-name] [-r room-name]"
        echo "  agent                 # random agent in the default room"
        echo "  agent ada             # named agent in the default room"
        echo "  agent ada -r feature  # named agent in room 'feature'"
        echo "  agent -r feature      # random agent in room 'feature'"
        return 0
        ;;
      *)
        if [ -z "$agent_name" ]; then
          agent_name="$1"
        else
          echo "Usage: agent [agent-name] [-r room-name]" >&2
          echo "  For named rooms use: agent ${agent_name} -r $1" >&2
          return 2
        fi
        ;;
    esac
    shift
  done

  PROJECT="$PWD" bash "${_ROOMS_DIR}/scripts/start-room.sh" "$room_name"
  PROJECT="$PWD" bash "${_ROOMS_DIR}/scripts/start-session.sh" "$room_name" "$agent_name"
}

logs() {
  local room_name="${1:-$(_rooms_default_room)}"
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
      local room agent_name container
      if [ "$#" -eq 2 ]; then
        room="$(_rooms_default_room)"
        agent_name="$2"
      else
        room="${2:?Usage: agents rm [room] <agent-name>}"
        agent_name="${3:?Usage: agents rm [room] <agent-name>}"
      fi
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
      local room_name="${1:-$(_rooms_default_room)}"
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
