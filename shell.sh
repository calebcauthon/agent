#!/usr/bin/env bash
# Add to ~/.zshrc:  source /path/to/rooms/shell.sh

_rooms_shell_dir() {
  local source_path=""

  if [ -n "${ZSH_VERSION:-}" ]; then
    eval 'source_path="${(%):-%N}"'
  elif [ -n "${BASH_SOURCE[0]:-}" ]; then
    source_path="${BASH_SOURCE[0]}"
  fi

  if [ -n "$source_path" ] && [ "$source_path" != "-" ]; then
    cd "$(dirname "$source_path")" && pwd -P
  else
    pwd -P
  fi
}

# Directory containing this repo's scripts/config. Homebrew wrappers can set
# _ROOMS_DIR; local installs can set ROOMS_DIR. Otherwise infer it from this
# sourced file instead of assuming a checkout path.
_ROOMS_DIR="${_ROOMS_DIR:-${ROOMS_DIR:-$(_rooms_shell_dir)}}"

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
          echo "Usage: agent [agent-name] [@room|-r room-name]" >&2
          return 2
        fi
        room_name="$1"
        ;;
      @*)
        room_name="${1#@}"
        if [ -z "$room_name" ]; then
          echo "Usage: agent [agent-name] [@room|-r room-name]" >&2
          return 2
        fi
        ;;
      -h|--help)
        echo "Usage: agent [agent-name] [@room|-r room-name]"
        echo "  agent                  # next numbered agent in the default room"
        echo "  agent ada              # named agent in the default room"
        echo "  agent @feature         # next numbered agent in room 'feature'"
        echo "  agent -r feature       # same as agent @feature (-r still works)"
        echo "  agent ada @feature     # named agent in room 'feature'"
        echo "  agent ada -r feature   # named agent in room 'feature' (-r still works)"
        return 0
        ;;
      *)
        if [ -z "$agent_name" ]; then
          agent_name="$1"
        else
          echo "Usage: agent [agent-name] [@room|-r room-name]" >&2
          echo "  For named rooms use: agent ${agent_name} @$1" >&2
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
