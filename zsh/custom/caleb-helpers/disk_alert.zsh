#!/bin/zsh
#
# disk_alert.zsh - Monitor disk space and alert at 95% capacity
# Usage: ./disk_alert.zsh [interval_seconds]
#   interval_seconds: Optional. If provided, runs continuously every N seconds.
#                     If omitted, runs once and exits.
#
# Examples:
#   ./disk_alert.zsh              # Check once
#   ./disk_alert.zsh 60           # Check every 60 seconds
#   ./disk_alert.zsh 300 &        # Background monitor every 5 minutes

# Configuration
local THRESHOLD=95

# Function to get disk usage info (percentage, used GB, capacity GB, free GB)
get_disk_info() {
  # Use diskutil for accurate macOS APFS space calculation
  # This includes snapshots and all volume usage, unlike df
  local mount_point="/System/Volumes/Data"
  [[ -d "$mount_point" ]] || mount_point="/"
  
  # Get diskutil info output
  local diskutil_output
  diskutil_output=$(diskutil info "$mount_point" 2>/dev/null)
  
  # Extract just the byte number from between parentheses
  local used_str total_str container_str free_str
  used_str=$(echo "$diskutil_output" | grep "Volume Used Space:" | sed -n 's/.*(\([0-9]*\) Bytes).*/\1/p')
  total_str=$(echo "$diskutil_output" | grep "Disk Size:" | sed -n 's/.*(\([0-9]*\) Bytes).*/\1/p')
  
  # Get container info
  local container_ref container_info
  container_ref=$(echo "$diskutil_output" | grep "APFS Container:" | awk '{print $3}')
  
  if [[ -n "$container_ref" ]]; then
    container_info=$(diskutil apfs list 2>/dev/null | grep -A 6 "APFS Container Reference:.*${container_ref}")
    container_str=$(echo "$container_info" | grep "Capacity In Use By Volumes:" | sed -n 's/.* \([0-9]*\) B (.*/\1/p')
    free_str=$(echo "$container_info" | grep "Capacity Not Allocated:" | sed -n 's/.* \([0-9]*\) B (.*/\1/p')
  fi
  
  # Fallbacks
  [[ -z "$container_str" ]] && container_str="$used_str"
  [[ -z "$free_str" ]] && free_str="0"
  
  # Convert to GB
  local used_gb=$((used_str / 1000000000))
  local total_gb=$((total_str / 1000000000))
  local container_used_gb=$((container_str / 1000000000))
  local free_gb=$((free_str / 1000000000))
  
  # Calculate percentage based on container usage (the real metric)
  local pct=$((container_str * 100 / total_str))
  
  echo "$pct $container_used_gb $total_gb $free_gb $used_gb"
}

# Function to play loud alert sound (continuous until Ctrl+C or disk frees up)
play_alert() {
  local current_usage="$1"
  local container_used="$2"
  local total_gb="$3"
  local free_gb="$4"
  
  echo "\033[31m⚠️  WARNING: Disk at ${current_usage}% capacity!\033[0m"
  echo "\033[31m   ${container_used}GB used, only ${free_gb}GB free of ${total_gb}GB total\033[0m"
  echo "\033[31m   Threshold: ${THRESHOLD}%\033[0m"
  echo "\033[31m   🔊 BEEPING CONTINUOUSLY - Press Ctrl+C to stop\033[0m"
  echo ""
  
  # Continuous alert loop - won't stop until manually interrupted
  while true; do
    # Check if disk is still critical - if not, stop beeping
    local pct_check container_check total_check free_check user_check
    read pct_check container_check total_check free_check user_check < <(get_disk_info)
    if (( pct_check < THRESHOLD )); then
      echo "\033[32m✅ Disk usage dropped to ${pct_check}% (${container_check}GB used, ${free_check}GB free). Stopping alert.\033[0m"
      return 0
    fi
    
    # Print beep indicator
    echo -n "\033[31m🔊 BEEP! ${container_check}GB used, ${free_check}GB free\033[0m "
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS - continuous beeping
      afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
      local pid1=$!
      sleep 0.1
      afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
      sleep 0.1
      afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &
      sleep 0.3
      # Kill lingering sounds
      kill $pid1 2>/dev/null
      kill $(pgrep -f "afplay.*Ping" 2>/dev/null) 2>/dev/null
      kill $(pgrep -f "afplay.*Glass" 2>/dev/null) 2>/dev/null
      kill $(pgrep -f "afplay.*Funk" 2>/dev/null) 2>/dev/null
      # Verbal warning every few seconds
      if (( SECONDS % 5 == 0 )); then
        say "Disk critical! ${current_usage} percent! Only ${free_check} gigabytes free!" 2>/dev/null
      fi
    else
      # Linux - continuous beeping
      speaker-test -t sine -f 1000 -l 1 &>/dev/null &
      local pid=$!
      sleep 0.5
      kill $pid 2>/dev/null
      # Terminal bell
      printf '\a\a\a'
      sleep 0.2
    fi
  done
}

# Main check function
# Args: $1 = "background" if running in continuous mode (don't block on alert)
check_disk() {
  local run_mode="${1:-}"
  local pct container_used total_gb free_gb user_gb
  read pct container_used total_gb free_gb user_gb < <(get_disk_info)
  
  if [[ -z "$pct" ]]; then
    echo "\033[31m❌ Error: Could not determine disk usage\033[0m" >&2
    return 1
  fi
  
  # Display current status - focused on container usage (the real metric)
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if (( pct >= THRESHOLD )); then
    echo "[${timestamp}] \033[31m🔴 CRITICAL: ${pct}% full - ${container_used}GB used, ${free_gb}GB free of ${total_gb}GB\033[0m"
    if [[ "$run_mode" == "background" ]]; then
      play_alert "$pct" "$container_used" "$total_gb" "$free_gb" &
      local alert_pid=$!
      echo "\033[31m   🔔 Alert running in background (PID: $alert_pid)\033[0m"
    else
      play_alert "$pct" "$container_used" "$total_gb" "$free_gb"
    fi
    return 2  # Critical
  elif (( pct >= THRESHOLD - 5 )); then
    echo "[${timestamp}] \033[33m🟡 WARNING: ${pct}% full - ${container_used}GB used, ${free_gb}GB free of ${total_gb}GB\033[0m"
  else
    echo "[${timestamp}] \033[32m🟢 OK: ${pct}% full - ${container_used}GB used, ${free_gb}GB free of ${total_gb}GB\033[0m"
  fi
  
  return 0
}

# Main execution
main() {
  local interval="$1"
  
  # Validate interval if provided
  if [[ -n "$interval" ]]; then
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
      echo "\033[31m❌ Error: Interval must be a number (seconds)\033[0m" >&2
      exit 1
    fi
  fi
  
  echo "\033[36m📊 Disk Space Monitor\033[0m"
  echo "   Threshold: ${THRESHOLD}%"
  local pct container_used total_gb free_gb user_gb
  read pct container_used total_gb free_gb user_gb < <(get_disk_info)
  echo "   Current: ${pct}% - ${container_used}GB used, ${free_gb}GB free of ${total_gb}GB"
  echo ""
  
  if [[ -n "$interval" ]]; then
    echo "\033[36m⏱️  Running every ${interval} seconds (Ctrl+C to stop)\033[0m"
    echo "   Note: Alert will beep continuously until disk usage drops below ${THRESHOLD}%"
    echo ""
    while true; do
      check_disk "background"
      sleep "$interval"
    done
  else
    check_disk
  fi
}

# Run main function
main "$@"
