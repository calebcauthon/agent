#!/bin/zsh
# chrome_cdp.zsh - Chrome DevTools Protocol helpers
# Interact with Chrome browser data: console, network, HTML, etc.
#
# Usage:
#   1. Start Chrome with remote debugging:
#      macOS: /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
#      Or add to Chrome shortcut/alias permanently
#
#   2. Source this file: source ./chrome_cdp.zsh
#
#   3. Use commands:
#      chrome_pages          # List open tabs
#      chrome_html <url>     # Get HTML from a tab
#      chrome_console <url>  # Stream console logs
#      chrome_network <url>  # Capture network requests
#      chrome_eval <url> <js> # Execute JavaScript in tab
#      chrome_screenshot <url> [filename] # Save screenshot

# Default port for Chrome remote debugging (use environment variable or default to 9222)
CHROME_CDP_PORT="${CHROME_CDP_PORT:-9222}"
CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"

# Find all Chrome CDP ports currently listening
_find_chrome_cdp_ports() {
  # Look for Chrome processes listening on TCP ports
  lsof -PiTCP -sTCP:LISTEN 2>/dev/null | grep -i chrome | grep -v grep | awk '{print $9}' | sed 's/.*://' | sort -u
}

# Test if a port has Chrome CDP
test_cdp_port() {
  local port="$1"
  curl -s "http://localhost:${port}/json/version" 2>/dev/null | grep -q "Protocol-Version"
}

# Find first working CDP port
_find_working_cdp_port() {
  local ports
  ports=$(_find_chrome_cdp_ports)
  
  # Test default port first
  if test_cdp_port "$CHROME_CDP_PORT"; then
    echo "$CHROME_CDP_PORT"
    return 0
  fi
  
  # Test other discovered ports
  for port in $(echo "$ports"); do
    if test_cdp_port "$port"; then
      echo "$port"
      return 0
    fi
  done
  
  return 1
}

# Check if Chrome debugging is available
chrome_check() {
  # If user explicitly set CHROME_CDP_PORT, try that first
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    if test_cdp_port "$CHROME_CDP_PORT"; then
      CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
      local browser_info
      browser_info=$(curl -s "${CHROME_CDP_BASE}/json/version" 2>/dev/null | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
      echo "✅ Chrome remote debugging connected"
      echo "   Port: ${CHROME_CDP_PORT}"
      echo "   Browser: ${browser_info:-Unknown}"
      
      if ! command -v websocat >/dev/null 2>&1; then
        echo ""
        echo "⚠️  websocat not installed (needed for HTML/console/network)"
        echo "   Install: brew install websocat"
      fi
      return 0
    fi
  fi
  
  # Otherwise try to auto-detect
  local working_port
  working_port=$(_find_working_cdp_port)
  
  if [[ -z "$working_port" ]]; then
    echo "❌ Chrome remote debugging not detected"
    echo ""
    echo "   Chrome must be started with: --remote-debugging-port=PORT --user-data-dir=/some/path"
    echo ""
    echo "   🔧 Quick fix - Quit Chrome, then run:"
    echo "   /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &"
    echo ""
    echo "   Or use environment variable:"
    echo "   CHROME_CDP_PORT=9222 chrome_pages"
    
    # Show what Chrome processes are listening
    local chrome_ports
    chrome_ports=$(_find_chrome_cdp_ports)
    if [[ -n "$chrome_ports" ]]; then
      echo ""
      echo "   🔍 Found Chrome listening on ports:"
      for p in $(echo "$chrome_ports"); do
        if test_cdp_port "$p"; then
          echo "      ✅ Port $p - HAS CDP enabled"
        else
          echo "      ⚠️  Port $p - no CDP response"
        fi
      done
    fi
    
    return 1
  fi
  
  # Update global port to working one
  CHROME_CDP_PORT="$working_port"
  CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  
  local browser_info
  browser_info=$(curl -s "${CHROME_CDP_BASE}/json/version" 2>/dev/null | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
  
  echo "✅ Chrome remote debugging connected"
  echo "   Port: ${CHROME_CDP_PORT}"
  echo "   Browser: ${browser_info:-Unknown}"
  
  if ! command -v websocat >/dev/null 2>&1; then
    echo ""
    echo "⚠️  websocat not installed (needed for HTML/console/network)"
    echo "   Install: brew install websocat"
  fi
  
  return 0
}

# List all open pages/tabs
chrome_pages() {
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  local pages
  pages=$(curl -s "${CHROME_CDP_BASE}/json/list" 2>/dev/null)
  
  if [[ -z "$pages" ]] || [[ "$pages" == "[]" ]]; then
    echo "📭 No open pages found"
    return 1
  fi
  
  echo "📑 Open Chrome pages (port ${CHROME_CDP_PORT}):"
  echo "$pages" | grep -o '"url":"[^"]*"' | sed 's/"url":"//;s/"$//' | nl -v 0
}

# Get WebSocket debugger URL for a page (by index or URL substring)
_get_debugger_url() {
  local target="$1"
  local pages
  pages=$(curl -s "${CHROME_CDP_BASE}/json/list" 2>/dev/null)
  
  # Try by index first
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    echo "$pages" | grep -o '"webSocketDebuggerUrl":"[^"]*"' | sed 's/"webSocketDebuggerUrl":"//;s/"$//' | sed -n "$((target + 1))p"
  else
    # Try by URL substring
    echo "$pages" | grep -B5 "$target" | grep -o '"webSocketDebuggerUrl":"[^"]*"' | head -1 | sed 's/"webSocketDebuggerUrl":"//;s/"$//'
  fi
}

# Ensure websocat is available
_require_websocat() {
  if ! command -v websocat >/dev/null 2>&1; then
    echo "❌ websocat required for this command"
    echo "   Install: brew install websocat"
    return 1
  fi
  return 0
}

# Get HTML from a page
# Usage: chrome_html [index|url_substring]
#   chrome_html 0        # First tab
#   chrome_html github   # Tab with "github" in URL
chrome_html() {
  local target="${1:-0}"
  
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  _require_websocat || return 1
  
  local ws_url
  ws_url=$(_get_debugger_url "$target")
  
  if [[ -z "$ws_url" ]]; then
    echo "❌ Could not find page: $target"
    return 1
  fi
  
  # Send Runtime.evaluate to get document.documentElement.outerHTML
  echo '{"id":1,"method":"Runtime.evaluate","params":{"expression":"document.documentElement.outerHTML"}}' | \
    websocat -n1 "$ws_url" 2>/dev/null | \
    sed 's/.*"result":{.*"value":"//;s/"}}.*//' | \
    sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g'
}

# Stream console logs from a page
# Usage: chrome_console [index|url_substring] [duration_seconds]
chrome_console() {
  local target="${1:-0}"
  local duration="${2:-30}"
  
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  _require_websocat || return 1
  
  local ws_url
  ws_url=$(_get_debugger_url "$target")
  
  if [[ -z "$ws_url" ]]; then
    echo "❌ Could not find page: $target"
    return 1
  fi
  
  echo "🎧 Listening to console logs for ${duration}s (Ctrl+C to stop)..."
  echo "   Port: ${CHROME_CDP_PORT}"
  echo ""
  
  # Enable console events and listen
  (
    # Enable Runtime domain
    echo '{"id":1,"method":"Runtime.enable"}'
    sleep "$duration"
  ) | websocat "$ws_url" 2>/dev/null | while read -r line; do
    # Parse console output
    if echo "$line" | grep -q '"method":"Runtime.consoleAPICalled"'; then
      local msg_type
      local msg_content
      msg_type=$(echo "$line" | grep -o '"type":"[^"]*"' | head -1 | sed 's/"type":"//;s/"$//')
      msg_content=$(echo "$line" | grep -o '"value":"[^"]*"' | sed 's/"value":"//;s/"$//' | head -1)
      echo "[${msg_type}] ${msg_content}"
    fi
  done
}

# Capture network requests
# Usage: chrome_network [index|url_substring] [duration_seconds]
chrome_network() {
  local target="${1:-0}"
  local duration="${2:-30}"
  
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  _require_websocat || return 1
  
  local ws_url
  ws_url=$(_get_debugger_url "$target")
  
  if [[ -z "$ws_url" ]]; then
    echo "❌ Could not find page: $target"
    return 1
  fi
  
  echo "🌐 Capturing network requests for ${duration}s (Ctrl+C to stop)..."
  echo "   Port: ${CHROME_CDP_PORT}"
  echo ""
  
  # Enable Network domain and listen
  (
    echo '{"id":1,"method":"Network.enable"}'
    sleep "$duration"
  ) | websocat "$ws_url" 2>/dev/null | while read -r line; do
    # Parse network requests
    if echo "$line" | grep -q '"method":"Network.requestWillBeSent"'; then
      local url
      local method
      url=$(echo "$line" | grep -o '"url":"[^"]*"' | head -1 | sed 's/"url":"//;s/"$//')
      method=$(echo "$line" | grep -o '"method":"[^"]*"' | head -1 | sed 's/"method":"//;s/"$//')
      if [[ -n "$url" ]] && [[ -n "$method" ]]; then
        echo "📤 ${method} ${url}"
      fi
    elif echo "$line" | grep -q '"method":"Network.responseReceived"'; then
      local url
      local status
      url=$(echo "$line" | grep -o '"url":"[^"]*"' | head -1 | sed 's/"url":"//;s/"$//')
      status=$(echo "$line" | grep -o '"status":[0-9]*' | head -1 | sed 's/"status"://')
      if [[ -n "$url" ]] && [[ -n "$status" ]]; then
        local emoji="✅"
        [[ "$status" -ge 400 ]] && emoji="❌"
        echo "${emoji} ${status} ${url}"
      fi
    fi
  done
}

# Execute JavaScript in a page
# Usage: chrome_eval [index|url_substring] "javascript_code"
chrome_eval() {
  local target="${1:-0}"
  local code="$2"
  
  if [[ -z "$code" ]]; then
    echo "Usage: chrome_eval [index|url_substring] \"JS code\""
    echo "Example: chrome_eval 0 \"document.title\""
    return 1
  fi
  
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  _require_websocat || return 1
  
  local ws_url
  ws_url=$(_get_debugger_url "$target")
  
  if [[ -z "$ws_url" ]]; then
    echo "❌ Could not find page: $target"
    return 1
  fi
  
  # Escape the code for JSON
  local escaped_code
  escaped_code=$(echo "$code" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  
  echo "⚡ Executing: $code"
  echo "   Port: ${CHROME_CDP_PORT}"
  echo ""
  
  echo "{\"id\":1,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"${escaped_code}\"}}" | \
    websocat -n1 "$ws_url" 2>/dev/null | \
    grep -o '"result":{[^}]*}' | head -1
  echo ""
}

# Take a screenshot
# Usage: chrome_screenshot [index|url_substring] [filename]
chrome_screenshot() {
  local target="${1:-0}"
  local filename="${2:-screenshot.png}"
  
  # If user explicitly set CHROME_CDP_PORT, use it
  if [[ -n "${CHROME_CDP_PORT}" ]]; then
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  else
    # Otherwise try to auto-detect
    local working_port
    working_port=$(_find_working_cdp_port) || {
      echo "❌ No Chrome with remote debugging found"
      return 1
    }
    CHROME_CDP_PORT="$working_port"
    CHROME_CDP_BASE="http://localhost:${CHROME_CDP_PORT}"
  fi
  
  _require_websocat || return 1
  
  local ws_url
  ws_url=$(_get_debugger_url "$target")
  
  if [[ -z "$ws_url" ]]; then
    echo "❌ Could not find page: $target"
    return 1
  fi
  
  echo "📸 Taking screenshot via port ${CHROME_CDP_PORT}..."
  
  # Capture screenshot via CDP
  local response
  response=$(echo '{"id":1,"method":"Page.captureScreenshot"}' | websocat -n1 "$ws_url" 2>/dev/null)
  
  # Extract base64 data
  local base64_data
  base64_data=$(echo "$response" | grep -o '"data":"[^"]*"' | sed 's/"data":"//;s/"$//')
  
  if [[ -z "$base64_data" ]]; then
    echo "❌ Failed to capture screenshot"
    return 1
  fi
  
  # Decode and save
  echo "$base64_data" | base64 -d > "$filename"
  echo "✅ Screenshot saved: $(realpath "$filename" 2>/dev/null || echo "$filename")"
}

# Quick setup helper for macOS
chrome_setup_macos() {
  echo "🔧 Chrome CDP Setup for macOS"
  echo ""
  echo "REQUIRED: Use --user-data-dir for remote debugging"
  echo ""
  echo "Launch Chrome with debugging:"
  echo "   /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &"
  echo ""
  echo "Then install websocat:"
  echo "   brew install websocat"
  echo ""
  echo "💡 Tip: You can also use environment variable for custom port:"
  echo "   CHROME_CDP_PORT=9222 chrome_pages"
}

# Interactive helper
chrome_help() {
  echo "🔌 Chrome DevTools Protocol Helpers"
  echo ""
  echo "Commands:"
  echo "  chrome_check              - Verify Chrome debugging connection"
  echo "  chrome_pages              - List all open tabs"
  echo "  chrome_html [n]           - Get HTML from tab #n (default: 0)"
  echo "  chrome_console [n] [secs] - Stream console logs from tab #n"
  echo "  chrome_network [n] [secs] - Capture network requests from tab #n"
  echo "  chrome_eval [n] \"js\"      - Execute JavaScript in tab #n"
  echo "  chrome_screenshot [n] [f] - Save screenshot from tab #n"
  echo "  chrome_setup_macos        - Show macOS setup instructions"
  echo ""
  echo "Environment:"
  echo "  CHROME_CDP_PORT=XXXX      - Use custom port (auto-detected if not set)"
  echo ""
  echo "Examples:"
  echo "  chrome_html 0                    # Get HTML from first tab"
  echo "  chrome_console 0 60              # Listen to console for 60s"
  echo "  chrome_network github 30         # Capture network on github tab"
  echo '  chrome_eval 0 "document.title"   # Get page title'
  echo "  CHROME_CDP_PORT=9222 chrome_pages  # Use specific port"
}
