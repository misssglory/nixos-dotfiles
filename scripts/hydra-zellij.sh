#!/usr/bin/env bash
set -euo pipefail

# Requirements: Zellij 0.44+, jq, bash, nix; run inside your Zellij session.
PROJECT="${HYDRA_PROJECT_DIR:-/home/mg/gh/hydra-eth-bundle}"
WAIT_SECONDS=120

: "${ZELLIJ_SESSION_NAME:?Run this command from inside the target Zellij session}"
for cmd in zellij jq nix sha256sum flock; do
    command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done
[[ -f "$PROJECT/flake.nix" ]] || { echo "No flake.nix in $PROJECT" >&2; exit 1; }

# Separate state per Zellij session; do not let two hreset calls interleave.
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hydra-zellij"
mkdir -p "$STATE_DIR"
SESSION_KEY=$(printf '%s' "$ZELLIJ_SESSION_NAME" | sha256sum | cut -c1-16)
STATE="$STATE_DIR/$SESSION_KEY.state"
exec 9>"$STATE_DIR/$SESSION_KEY.lock"
flock -x 9

error() { echo "ERROR: $*" >&2; exit 1; }

# Records: tab ID, then IDs for hruns, hrunv, runs, runv (one per line).
load_state() {
    [[ -f "$STATE" ]] || error "No Hydra tab recorded. Run hstart first."
    mapfile -t saved < "$STATE"
    ((${#saved[@]} == 5)) || error "Invalid state file: $STATE"
    TAB_ID=${saved[0]}
    PANE_IDS=("${saved[@]:1}")
    [[ $TAB_ID =~ ^[0-9]+$ ]] || error "Invalid saved tab ID"
    for pane in "${PANE_IDS[@]}"; do
        [[ $pane =~ ^terminal_[0-9]+$ ]] || error "Invalid saved pane ID: $pane"
    done
}

tab_exists() {
    zellij action list-tabs --json |
        jq -e --argjson tab "$1" 'any(.[]; .tab_id == $tab)' >/dev/null
}

# Prints running, exited, or missing, using Zellij's authoritative pane state.
pane_state() {
    local snapshot=$1 pane=$2
    local id=${pane#terminal_}
    jq -r --argjson id "$id" '
      [.[] | select(.is_plugin == false and .id == $id) | .exited] |
      if length == 0 then "missing" elif .[0] then "exited" else "running" end
    ' <<< "$snapshot"
}

start() {
    if [[ -f $STATE ]]; then
        load_state
        if tab_exists "$TAB_ID"; then
            echo "Hydra tab already exists (tab $TAB_ID). Use hreset to restart it."
            return 0
        fi
        rm -f "$STATE"
    fi

    echo "Creating Hydra tab from $PROJECT"
    TAB_ID=$(zellij action new-tab --name Hydra --cwd "$PROJECT" \
        -- bash -lc 'exec nix develop -c bash -ic hruns')
    [[ $TAB_ID =~ ^[0-9]+$ ]] || error "Could not get tab ID: $TAB_ID"

    local first=""
    local snapshot
    for _ in {1..30}; do
        snapshot=$(zellij action list-panes --json)
        first=$(jq -r --argjson tab "$TAB_ID" \
            '[.[] | select(.tab_id == $tab and .is_plugin == false) | .id] |
             if length == 0 then empty else "terminal_\(.[0])" end' \
             <<< "$snapshot")
        [[ -n $first ]] && break
        sleep 0.1
    done
    [[ -n $first ]] || error "Created tab, but its initial pane was not found."

    # First two are stacked. Next two are distinct tiled panes.
    local second third fourth
    second=$(zellij action new-pane --tab-id "$TAB_ID" --stacked \
        --cwd "$PROJECT" --name hrunv -- bash -lc 'exec nix develop -c bash -ic hrunv')
    third=$(zellij action new-pane --tab-id "$TAB_ID" --direction right \
        --cwd "$PROJECT" --name runs -- bash -lc 'exec nix develop -c bash -ic runs')
    fourth=$(zellij action new-pane --tab-id "$TAB_ID" --direction down \
        --cwd "$PROJECT" --name runv -- bash -lc 'exec nix develop -c bash -ic runv')

    local pane
    for pane in "$second" "$third" "$fourth"; do
        [[ $pane =~ ^terminal_[0-9]+$ ]] || error "Unexpected pane ID: $pane"
    done
    zellij action rename-pane --pane-id "$first" hruns

    # Atomically save IDs once all 4 panes exist.
    local tmp
    tmp=$(mktemp "$STATE.XXXXXX")
    printf '%s\n' "$TAB_ID" "$first" "$second" "$third" "$fourth" > "$tmp"
    mv -f -- "$tmp" "$STATE"
    printf 'Ready: tab %s | hruns=%s hrunv=%s runs=%s runv=%s\n' \
        "$TAB_ID" "$first" "$second" "$third" "$fourth"
}

status() {
    load_state
    tab_exists "$TAB_ID" || error "Hydra tab $TAB_ID is gone; run hstart to create a new tab."
    local snapshot
    snapshot=$(zellij action list-panes --json)
    local names=(hruns hrunv runs runv)
    for i in "${!PANE_IDS[@]}"; do
        printf '%-6s %-14s %s\n' "${names[$i]}" "${PANE_IDS[$i]}" \
            "$(pane_state "$snapshot" "${PANE_IDS[$i]}")"
    done
}

stop_or_reset() {
    local restart=$1
    load_state
    tab_exists "$TAB_ID" || error "Hydra tab no longer exists."
    local snapshot pane s
    snapshot=$(zellij action list-panes --json)

    # Verify all four IDs exist *before* sending interrupts.
    for pane in "${PANE_IDS[@]}"; do
        s=$(pane_state "$snapshot" "$pane")
        [[ $s != missing ]] || error "Pane $pane is missing; not touching other panes."
    done

    echo "Sending Ctrl+C to running Hydra panes..."
    for pane in "${PANE_IDS[@]}"; do
        snapshot=$(zellij action list-panes --json)
        s=$(pane_state "$snapshot" "$pane")
        if [[ $s == running ]]; then
            zellij action send-keys --pane-id "$pane" 'Ctrl c'
        fi
    done

    # Wait for Zellij to report all four commands exited.
    local deadline=$((SECONDS + WAIT_SECONDS))
    local all_exited
    while :; do
        snapshot=$(zellij action list-panes --json)
        all_exited=true
        for pane in "${PANE_IDS[@]}"; do
            s=$(pane_state "$snapshot" "$pane")
            [[ $s != missing ]] || error "Pane $pane disappeared while stopping."
            [[ $s == exited ]] || all_exited=false
        done
        [[ $all_exited == true ]] && break
        (( SECONDS < deadline )) || error "Processes did not all exit within ${WAIT_SECONDS}s. Not restarting anything."
        sleep 0.3
    done

    if [[ $restart == true ]]; then
        echo "All commands exited; restarting all four..."
        for pane in "${PANE_IDS[@]}"; do
            zellij action send-keys --pane-id "$pane" Enter
        done
        echo "Restart commands sent."
    else
        echo "All four commands stopped. Use hreset to start them again."
    fi
}

case "${1:-start}" in
    start) start ;;
    reset) stop_or_reset true ;;
    stop) stop_or_reset false ;;
    status) status ;;
    *) echo 'Usage: hydra-zellij {start|reset|stop|status}' >&2; exit 2 ;;
esac
