##### Atomic open commands (exposed via aliases below)

# Color palette for Ghostty windows and countdown
NL_BG_EXPO="#3f36a6"
NL_BG_API="#2c437e"
NL_BG_REACT="#d2deaf"
NL_BG_PYTESTS="#d2deaf"
NL_BG_SQLEE="#20a673"
NL_INFO_BG="#3A3A3A"
NL_COUNTDOWN_COLOR_PRIMARY=90
NL_COUNTDOWN_COLOR_ALT=30
NL_COUNTDOWN_DONE_COLOR=90
NL_FG="#FFFFFF"
NL_BLACK="#000000"
NL_WHITE="#FFFFFF"

nl__gen_id() {
    echo "NEVERLOST"
}

nl_open_browser() {
    if nl__is_chrome_neverlost_open; then
        echo "✅ Chrome Neverlost window already open, skipping"
        return 0
    fi
    open -na "Google Chrome" --args --new-window \
        "https://github.com/calebcauthon/neverlost_app/pulls" \
        "https://expo.dev/accounts/calebcomputer/projects/neverlost" \
        "https://appstoreconnect.apple.com/apps/6739098633/distribution/ios/version/deliverable" \
        "https://fly.io/apps/neverlostapi" \
        "https://ui.honeycomb.io/calebcauthon-neverlost/environments/prod/datasets/neverlost-app/home?tab=explore" \
        "https://cursor.com/dashboard?tab=usage" \
        "https://www.notion.so/273a23fd172980fa880ef8a43237a39e?v=273a23fd172980a2af0b000c89661057"
}

nl_open_code_workspace() {
    cursor -n "/Users/caleb/Code/neverlost.code-workspace"
}

nl_open_expo() {
    if nl__is_window_open "Expo-$(nl__gen_id)"; then
        echo "✅ Expo window already open, skipping"
        return 0
    fi
    local id title
    id=$(nl__gen_id)
    title="Expo-$id"
    open -na "Ghostty" --args --title="$title" --background="$NL_BG_EXPO" --foreground="$NL_FG" --shell-integration="zsh" --command='zsh -i -c "npx expo start"' --working-directory="/Users/caleb/Code/neverlost_monorepo/neverlost_app"
}

nl_open_api() {
    if nl__is_window_open "API-$(nl__gen_id)"; then
        echo "✅ API window already open, skipping"
        return 0
    fi
    local id title
    id=$(nl__gen_id)
    title="API-$id"
    open -na "Ghostty" --args --title="$title" --background="$NL_BG_API" --foreground="$NL_FG" --shell-integration="zsh" --command='zsh -i -c "source .env.local && uv run opentelemetry-instrument python app.py"' --working-directory="/Users/caleb/Code/neverlost_monorepo/neverlost_api"
}

nl_open_react_tests() {
    if nl__is_window_open "React Tests-$(nl__gen_id)"; then
        echo "✅ React Tests window already open, skipping"
        return 0
    fi
    local id title
    id=$(nl__gen_id)
    title="React Tests-$id"
    open -na "Ghostty" --args --title="$title" --background="$NL_BG_REACT" --foreground="$NL_BLACK" --shell-integration="zsh" --command='zsh -i -c "npm run test"' --working-directory="/Users/caleb/Code/neverlost_monorepo/neverlost_app"
}

nl_open_python_tests() {
    if nl__is_window_open "Python Tests-$(nl__gen_id)"; then
        echo "✅ Python Tests window already open, skipping"
        return 0
    fi
    local id title
    id=$(nl__gen_id)
    title="Python Tests-$id"
    open -na "Ghostty" --args --title="$title" --background="$NL_BG_PYTESTS" --foreground="$NL_BLACK" --shell-integration="zsh" --command='zsh -i -c "uv run python -m pytest -f ."' --wait-after-command="true" --working-directory="/Users/caleb/Code/neverlost_monorepo/neverlost_api"
}

nl_open_sqlee() {
    if nl__is_window_open "Sqlee-$(nl__gen_id)"; then
        echo "✅ Sqlee window already open, skipping"
        return 0
    fi
    local id title
    id=$(nl__gen_id)
    title="Sqlee-$id"
    open -na "Ghostty" --args --title="$title" --background="$NL_BG_SQLEE" --foreground="$NL_FG" --shell-integration="zsh" --command='zsh -i -c "go run . ~/Code/neverlost_monorepo/neverlost_api/instance/neverlost.db"' --working-directory="/Users/caleb/Code/sqlee"
    echo "Tip: to kill all Ghostty windows started by neverlost in one shot, run: pkill -f 'NEVERLOST'"
}

##### Window placement helpers

nl__yabai_id_for_title() {
    # $1: base title (matches both "Name" and "Name-XXX")
    local pattern
    pattern="^${1}(-[A-Z0-9]{3})?$"
    yabai -m query --windows | jq -r --arg pattern "$pattern" '.[] | select(.app=="Ghostty" and ((.title // "") | test($pattern))) | .id' | head -n1
}

nl__is_window_open() {
    # $1: title
    [ -n "$(nl__yabai_id_for_title "$1")" ]
}

nl__is_cursor_open() {
    local id
    id=$(yabai -m query --windows | jq -r '.[] | select(.app=="Cursor") | .id' | head -n1)
    [ -n "$id" ]
}

nl__is_chrome_neverlost_open() {
    local id
    id=$(yabai -m query --windows | jq -r '.[] | select(.app=="Google Chrome" and ((.title // "") | test("neverlost|Expo|Render|Fly|App Store Connect"; "i"))) | .id' | head -n1)
    [ -n "$id" ]
}

nl__debug() {
    echo "[NEVERLOST] $*"
}

nl__ensure_floating() {
    # $1: window id
    # Ensure window is floating; don't toggle if already floating
    local id floating floating_raw i
    id="$1"
    [ -z "$id" ] && return 0

    # Read floating state robustly (handles is-floating or floating, booleans, null)
    floating_raw=$(yabai -m query --windows --window "$id" 2>/dev/null | jq -r '."is-floating" // .floating // 0' 2>/dev/null || echo 0)
    floating="$floating_raw"

    case "$floating" in
        1|"1"|true|"true"|on|"on") floating=1 ;;
        *) floating=0 ;;
    esac

    nl__debug "ensure_floating id=$id before=$floating_raw=>${floating}"

    if [ "$floating" -eq 0 ]; then
        yabai -m window "$id" --toggle float
        # Wait briefly until yabai reports floating to avoid grid failure
        for i in 1 2 3 4 5; do
            floating_raw=$(yabai -m query --windows --window "$id" 2>/dev/null | jq -r '."is-floating" // .floating // 0' 2>/dev/null || echo 0)
            floating="$floating_raw"
            case "$floating" in
                1|"1"|true|"true"|on|"on") floating=1 ;;
                *) floating=0 ;;
            esac
            [ "$floating" -eq 1 ] && break
            sleep 0.05
        done
        nl__debug "ensure_floating id=$id after=$floating_raw=>${floating}"
    fi
}

nl_place_expo() {
    local id
    id=$(nl__yabai_id_for_title "Expo-$(nl__gen_id)")
    if [ -n "$id" ]; then
        nl__debug "place Expo id=$id"
        nl__ensure_floating "$id"
        nl__debug "grid Expo 12:12:0:0:6:6"
        yabai -m window "$id" --grid 12:12:0:0:6:6
    fi
}

nl_place_api() {
    local id
    id=$(nl__yabai_id_for_title "API-$(nl__gen_id)")
    if [ -n "$id" ]; then
        nl__debug "place API id=$id"
        nl__ensure_floating "$id"
        nl__debug "grid API 12:12:6:0:6:6"
        yabai -m window "$id" --grid 12:12:6:0:6:6
    fi
}

nl_place_react_tests() {
    local id
    id=$(nl__yabai_id_for_title "React Tests-$(nl__gen_id)")
    if [ -n "$id" ]; then
        nl__debug "place React Tests id=$id"
        nl__ensure_floating "$id"
        nl__debug "grid ReactTests 12:12:6:6:6:3"
        yabai -m window "$id" --grid 12:12:6:6:6:3
    fi
}

nl_place_python_tests() {
    local id
    id=$(nl__yabai_id_for_title "Python Tests-$(nl__gen_id)")
    if [ -n "$id" ]; then
        nl__debug "place Python Tests id=$id"
        nl__ensure_floating "$id"
        nl__debug "grid PythonTests 12:12:6:9:6:4"
        yabai -m window "$id" --grid 12:12:6:9:6:4
    fi
}

nl_place_sqlee() {
    local id
    id=$(nl__yabai_id_for_title "Sqlee-$(nl__gen_id)")
    if [ -n "$id" ]; then
        nl__debug "place Sqlee id=$id"
        nl__ensure_floating "$id"
        nl__debug "grid Sqlee 12:12:0:6:6:6"
        yabai -m window "$id" --grid 12:12:0:6:6:6
    fi
}

nl_place_all() {
    # Give windows a moment to spawn before arranging
    sleep 2
    nl_place_expo
    nl_place_api
    nl_place_react_tests
    nl_place_python_tests
    nl_place_sqlee
}

##### Info summary helper
nl_info() {
    local now tmp
    now=$(date '+%Y-%m-%d %H:%M:%S')
    tmp=$(mktemp /tmp/nl_info.XXXXXX)

    local has_expo has_api has_react has_pytests has_sqlee has_cursor has_chrome

    [ -n "$(nl__yabai_id_for_title "Expo-$(nl__gen_id)")" ] && has_expo=1 || has_expo=0
    [ -n "$(nl__yabai_id_for_title "API-$(nl__gen_id)")" ] && has_api=1 || has_api=0
    [ -n "$(nl__yabai_id_for_title "React Tests-$(nl__gen_id)")" ] && has_react=1 || has_react=0
    [ -n "$(nl__yabai_id_for_title "Python Tests-$(nl__gen_id)")" ] && has_pytests=1 || has_pytests=0
    [ -n "$(nl__yabai_id_for_title "Sqlee-$(nl__gen_id)")" ] && has_sqlee=1 || has_sqlee=0

    local cursor_id chrome_id
    cursor_id=$(yabai -m query --windows | jq -r '.[] | select(.app=="Cursor") | .id' | head -n1)
    chrome_id=$(yabai -m query --windows | jq -r '.[] | select(.app=="Google Chrome" and ((.title // "") | test("neverlost|Expo|Render|Fly|App Store Connect"; "i"))) | .id' | head -n1)
    [ -n "$cursor_id" ] && has_cursor=1 || has_cursor=0
    [ -n "$chrome_id" ] && has_chrome=1 || has_chrome=0

    local run_expo run_api run_react run_pytests run_sqlee
    pgrep -fl "npx expo start" >/dev/null 2>&1 && run_expo=1 || run_expo=0
    pgrep -fl "uv run opentelemetry-instrument python app.py" >/dev/null 2>&1 && run_api=1 || run_api=0
    pgrep -fl "npm run test" >/dev/null 2>&1 && run_react=1 || run_react=0
    pgrep -fl "uv run python -m pytest -f" >/dev/null 2>&1 && run_pytests=1 || run_pytests=0
    pgrep -fl "go run .*neverlost.db" >/dev/null 2>&1 && run_sqlee=1 || run_sqlee=0

    {
        echo ""
        echo "============================"
        echo "     NEVERLOST STATUS"
        echo "============================"
        echo "Checked: $now"
        echo ""
        echo "Expo:        $([ $has_expo -eq 1 ] && echo "✅ WINDOW" || echo "❌ WINDOW" ) | proc: $([ $run_expo -eq 1 ] && echo "✅ running" || echo "❌ stopped")"
        echo "API:         $([ $has_api -eq 1 ] && echo "✅ WINDOW" || echo "❌ WINDOW" ) | proc: $([ $run_api -eq 1 ] && echo "✅ running" || echo "❌ stopped")"
        echo "React Tests: $([ $has_react -eq 1 ] && echo "✅ WINDOW" || echo "❌ WINDOW" ) | proc: $([ $run_react -eq 1 ] && echo "✅ running" || echo "❌ stopped")"
        echo "PythonTests: $([ $has_pytests -eq 1 ] && echo "✅ WINDOW" || echo "❌ WINDOW" ) | proc: $([ $run_pytests -eq 1 ] && echo "✅ running" || echo "❌ stopped")"
        echo "Sqlee:       $([ $has_sqlee -eq 1 ] && echo "✅ WINDOW" || echo "❌ WINDOW" ) | proc: $([ $run_sqlee -eq 1 ] && echo "✅ running" || echo "❌ stopped")"
        echo "Cursor:      $([ $has_cursor -eq 1 ] && echo "✅ OPEN" || echo "❌ CLOSED")"
        echo "Chrome:      $([ $has_chrome -eq 1 ] && echo "✅ OPEN" || echo "❌ CLOSED")"
        echo ""
        echo "Note: Window state via yabai; process state via pgrep (best-effort)."
        echo ""
    } > "$tmp"

    open -na "Ghostty" --args --background="$NL_INFO_BG" --foreground="$NL_FG" --title="Neverlost Info" --shell-integration="zsh" --command="sh -lc 'cat $tmp; rm -f $tmp; tail -f /dev/null'" --wait-after-command="true"
}

##### Aliases for atomic actions
alias nl-browser="nl_open_browser"
alias nl-code="nl_open_code_workspace"
alias nl-expo="nl_open_expo"
alias nl-api="nl_open_api"
alias nl-react-tests="nl_open_react_tests"
alias nl-python-tests="nl_open_python_tests"
alias nl-sqlee="nl_open_sqlee"
alias nl-place-expo="nl_place_expo"
alias nl-place-api="nl_place_api"
alias nl-place-react-tests="nl_place_react_tests"
alias nl-place-python-tests="nl_place_python_tests"
alias nl-place-sqlee="nl_place_sqlee"
alias nl-place-all="nl_place_all"
alias nl-info="nl_info"

# Show a short, colorful countdown (5..1) before exiting a Ghostty window
nl_cool_countdown() {
    local n color
    tput civis 2>/dev/null || true
    for n in 5 4 3 2 1; do
        case "$n" in
            5) color=90 ;;
            4) color=30 ;;
            3) color=90 ;;
            2) color=30 ;;
            1) color=90 ;;
            *) color=0  ;;
        esac
        printf "\n\e[1;%sm  ▶  %s\e[0m\n\n" "$color" "$n"
        sleep 1
    done
    printf "\n\e[90m  Done — closing window...\e[0m\n"
    sleep 0.5
    tput cnorm 2>/dev/null || true
}
alias nl-countdown="nl_cool_countdown"

##### Megacommand orchestrating the atomic pieces
neverlost_megastartup() {
    nl-browser \
        && sleep 0.5 \
        && nl-code \
        && sleep 0.5 \
        && nl-expo \
        && sleep 0.5 \
        && nl-api \
        && sleep 0.5 \
        && nl-react-tests \
        && sleep 0.5 \
        && nl-python-tests \
        && sleep 0.5 \
        && nl-sqlee \
        && sleep 0.5 \
        && nl-place-all \
        && sleep 0.5 \
        && nl-countdown
}

alias neverlost-megastart="neverlost_megastartup"

# Minimal "expo only" helper (maps to your cmd+alt-9)
neverlost_expo_only() {
    nl-expo
}
alias neverlost-expo-only="neverlost_expo_only"

# Hotkey reference (documentation only)
# cmd+alt+0 -> neverlost-megastart
# cmd+alt+9 -> neverlost-expo-only


