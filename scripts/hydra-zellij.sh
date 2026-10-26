#!/usr/bin/env bash
# Control five panes in one stacked Zellij tab, without replacing session UI.
set -euo pipefail

PROJECT="${HYDRA_PROJECT_DIR:-$HOME/gh/hydra-eth-bundle}"
TAB_NAME="${HYDRA_ZELLIJ_TAB_NAME:-Hydra}"
WAIT_SECONDS="${HYDRA_ZELLIJ_WAIT_SECONDS:-120}"
NAMES=(hruns hrunv runs runv nix-shell)

usage() {
    cat <<'HELP'
Usage: hydra-zellij <command>

  start     Create/focus one Hydra tab with five stacked panes
  reset     Ctrl+C services, leave nix-shell, wait for exits, rerun all five
  restart   Alias for reset
  stop      Stop all five without closing the tab
  status    Show the state of all five panes
  focus     Switch to the existing Hydra tab
  close     Stop all five and close only the managed Hydra tab
  help      Show this help

Panes (all under $HOME/gh/hydra-eth-bundle by default):
  hruns      nix develop -c bash -ic hruns
  hrunv      nix develop -c bash -ic hrunv
  runs       nix develop -c bash -ic runs
  runv       nix develop -c bash -ic runv
  nix-shell  nix develop  (interactive)

Configuration:
  HYDRA_PROJECT_DIR          override project directory
  HYDRA_ZELLIJ_WAIT_SECONDS  stop timeout (default: 120)
  HYDRA_ZELLIJ_TAB_NAME      tab name (default: Hydra)

Run start/reset/stop/close from an UNMANAGED Zellij pane or tab; do not
restart the pane in which this controller itself is running.
HELP
}

error() { printf 'hydra-zellij: %s\n' "$*" >&2; exit 1; }
info()  { printf 'hydra-zellij: %s\n' "$*"; }

case "${1:-help}" in
    help|-h|--help) usage; exit 0 ;;
    start|reset|restart|stop|status|focus|close) ACTION=$1 ;;
    *) usage >&2; exit 2 ;;
esac
[[ $# == 1 ]] || { usage >&2; exit 2; }

: "${ZELLIJ_SESSION_NAME:?Run this command inside the Zellij session you want to control}"
for cmd in zellij jq sha256sum flock; do
    command -v "$cmd" >/dev/null || error "missing command: $cmd"
done
[[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] && ((WAIT_SECONDS > 0)) || error 'HYDRA_ZELLIJ_WAIT_SECONDS must be a positive integer'

# Persist pane IDs per session, and serialize changes to avoid overlapping resets.
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/hydra-zellij-$(id -u)"
mkdir -p -m 700 -- "$RUNTIME"
SESSION_KEY=$(printf '%s' "$ZELLIJ_SESSION_NAME" | sha256sum | cut -c1-16)
STATE="$RUNTIME/$SESSION_KEY.state"
exec 9>"$RUNTIME/$SESSION_KEY.lock"
flock -x 9

TAB_ID=''
PANE_IDS=()

load_state() {
    [[ -f "$STATE" ]] || return 1
    local -a saved
    mapfile -t saved < "$STATE"
    ((${#saved[@]} == 6)) || error "invalid state file: $STATE (expected tab ID + 5 pane IDs)"
    TAB_ID=${saved[0]}
    PANE_IDS=("${saved[@]:1}")
    [[ $TAB_ID =~ ^[0-9]+$ ]] || error "invalid tab ID in $STATE"
    local pane
    for pane in "${PANE_IDS[@]}"; do
        [[ $pane =~ ^terminal_[0-9]+$ ]] || error "invalid pane ID: $pane"
    done
}

tab_exists() {
    zellij action list-tabs --json |
        jq -e --argjson t "$1" 'any(.[]; .tab_id == $t)' >/dev/null
}

pane_state() {
    local json=$1 pane=$2 id=${2#terminal_}
    jq -r --argjson id "$id" --argjson tab "$TAB_ID" '
      [.[] | select(.tab_id == $tab and .is_plugin == false and .id == $id) | .exited] |
      if length == 0 then "missing" elif .[0] == true then "exited" else "running" end
    ' <<< "$json"
}

# Refuse to kill the calling pane; that would interrupt this script mid-reset.
ensure_external_caller() {
    local current=${ZELLIJ_PANE_ID:-}
    local pane
    for pane in "${PANE_IDS[@]}"; do
        if [[ "$current" == "${pane#terminal_}" || "$current" == "$pane" ]]; then
            error 'run this operation from another (unmanaged) Zellij pane/tab'
        fi
    done
}

validate_panes() {
    local snapshot pane state
    tab_exists "$TAB_ID" || error "managed tab $TAB_ID no longer exists; run 'hydra-zellij start'"
    snapshot=$(zellij action list-panes --json)
    for pane in "${PANE_IDS[@]}"; do
        state=$(pane_state "$snapshot" "$pane")
        [[ $state != missing ]] || error "managed pane $pane is missing; not touching other panes"
    done
}

start() {
    [[ -f "$PROJECT/flake.nix" ]] || error "no flake.nix found in $PROJECT"
    if load_state; then
        if tab_exists "$TAB_ID"; then
            validate_panes
            info "Hydra tab $TAB_ID already exists; focusing it"
            zellij action go-to-tab-by-id "$TAB_ID"
            return 0
        fi
        # State was left by a tab that has since been closed.
        rm -f -- "$STATE"
        PANE_IDS=()
    fi

    info "creating five-pane Hydra tab in $PROJECT"
    # Do NOT supply --layout: preserve the user's existing tab/status bars.
    TAB_ID=$(zellij action new-tab --name "$TAB_NAME" --cwd "$PROJECT" \
        -- bash -lc 'exec nix develop -c bash -ic hruns')
    [[ "$TAB_ID" =~ ^[0-9]+$ ]] || error "new-tab did not return a numeric tab ID: $TAB_ID"

    # Newly-created first pane is discovered via the tab ID.
    local snapshot first=''
    local attempt
    for ((attempt=0; attempt<40; attempt++)); do
        snapshot=$(zellij action list-panes --json)
        first=$(jq -r --argjson tab "$TAB_ID" '
            [.[] | select(.tab_id == $tab and .is_plugin == false) | .id] |
            if length > 0 then "terminal_\(.[0])" else "" end
        ' <<< "$snapshot")
        [[ -n "$first" ]] && break
        sleep 0.1
    done
    [[ -n "$first" ]] || error 'new tab created, but its initial pane was not found'
    PANE_IDS=("$first")

    # The first pane exists already. Append the other four to the same tab.
    local name pane
    for name in hrunv runs runv; do
        pane=$(zellij action new-pane --tab-id "$TAB_ID" --stacked \
            --name "$name" --cwd "$PROJECT" \
            -- bash -lc "exec nix develop -c bash -ic $name")
        [[ "$pane" =~ ^terminal_[0-9]+$ ]] || error "unexpected $name pane ID: $pane"
        PANE_IDS+=("$pane")
    done
    pane=$(zellij action new-pane --tab-id "$TAB_ID" --stacked \
        --name nix-shell --cwd "$PROJECT" -- nix develop)
    [[ "$pane" =~ ^terminal_[0-9]+$ ]] || error "unexpected nix-shell pane ID: $pane"
    PANE_IDS+=("$pane")
    zellij action rename-pane --pane-id "$first" hruns

    # Explicitly guarantee one stack containing all five pane IDs.
    zellij action stack-panes -- "${PANE_IDS[@]}"

    # Write state only when all panes are created and grouped successfully.
    local tmp
    tmp=$(mktemp "$STATE.XXXXXXXX")
    printf '%s\n' "$TAB_ID" "${PANE_IDS[@]}" > "$tmp"
    mv -f -- "$tmp" "$STATE"
    info "ready (tab $TAB_ID): ${NAMES[*]}"
}

status() {
    if ! load_state; then
        info 'no managed Hydra tab; run hydra-zellij start'
        return 0
    fi
    if ! tab_exists "$TAB_ID"; then
        info "saved tab $TAB_ID no longer exists; run hydra-zellij start"
        return 0
    fi
    local snapshot i
    snapshot=$(zellij action list-panes --json)
    printf 'Tab: %s | project: %s\n' "$TAB_ID" "$PROJECT"
    for i in "${!PANE_IDS[@]}"; do
        printf '%-10s %-14s %s\n' "${NAMES[$i]}" "${PANE_IDS[$i]}" \
            "$(pane_state "$snapshot" "${PANE_IDS[$i]}")"
    done
}

focus_tab() {
    load_state || error 'no managed tab; run hydra-zellij start'
    validate_panes
    zellij action go-to-tab-by-id "$TAB_ID"
}

# Query the shell's state after interrupts, then explicitly exit the interactive
# `nix develop` shell. Ctrl+C alone does NOT exit an interactive shell.
leave_devshell() {
    local shell_pane=${PANE_IDS[4]} snapshot s
    snapshot=$(zellij action list-panes --json)
    s=$(pane_state "$snapshot" "$shell_pane")
    [[ $s != running ]] && return 0
    zellij action send-keys --pane-id "$shell_pane" 'Ctrl c'
    sleep 0.4
    snapshot=$(zellij action list-panes --json)
    s=$(pane_state "$snapshot" "$shell_pane")
    [[ $s != running ]] && return 0
    zellij action send-keys --pane-id "$shell_pane" 'Ctrl d'

    local until=$((SECONDS + 2))
    while ((SECONDS < until)); do
        snapshot=$(zellij action list-panes --json)
        s=$(pane_state "$snapshot" "$shell_pane")
        [[ $s != running ]] && return 0
        sleep 0.2
    done

    # Fallback for interactive shells that ignore Ctrl+D.
    snapshot=$(zellij action list-panes --json)
    s=$(pane_state "$snapshot" "$shell_pane")
    if [[ $s == running ]]; then
        zellij action write-chars --pane-id "$shell_pane" 'exit'
        zellij action send-keys --pane-id "$shell_pane" Enter
    fi
}

wait_for_all_exited() {
    local deadline=$((SECONDS + WAIT_SECONDS))
    local json pane s all
    while :; do
        json=$(zellij action list-panes --json)
        all=true
        for pane in "${PANE_IDS[@]}"; do
            s=$(pane_state "$json" "$pane")
            [[ $s != missing ]] || error "pane $pane disappeared during shutdown"
            [[ $s == exited ]] || all=false
        done
        [[ "$all" == true ]] && return 0
        ((SECONDS < deadline)) || error "shutdown timed out (${WAIT_SECONDS}s); not restarting"
        sleep 0.25
    done
}

stop_reset() {
    local restart=$1
    load_state || error 'no managed tab; run hydra-zellij start'
    validate_panes
    ensure_external_caller

    local snapshot pane s i
    info 'sending Ctrl+C to running service panes...'
    snapshot=$(zellij action list-panes --json)
    # Stop viewers first, then backends; no reliance on focused pane.
    for i in 3 1 2 0; do
        pane=${PANE_IDS[$i]}
        s=$(pane_state "$snapshot" "$pane")
        if [[ $s == running ]]; then
            zellij action send-keys --pane-id "$pane" 'Ctrl c'
        fi
    done
    info 'leaving the interactive nix develop shell...'
    leave_devshell
    info "waiting up to ${WAIT_SECONDS}s for all five to exit..."
    wait_for_all_exited

    if [[ $restart == true ]]; then
        info 'all five exited; rerunning each pane command...'
        for pane in "${PANE_IDS[@]}"; do
            zellij action send-keys --pane-id "$pane" Enter
        done
        info 'restart requested for all five panes'
    else
        info 'all five stopped; use hydra-zellij reset to run them again'
    fi
}

close_tab() {
    load_state || error 'no managed tab; run hydra-zellij start'
    validate_panes
    stop_reset false
    zellij action close-tab-by-id "$TAB_ID"
    rm -f -- "$STATE"
    info 'managed Hydra tab closed'
}

case "$ACTION" in
    start)   start ;;
    reset|restart) stop_reset true ;;
    stop)    stop_reset false ;;
    status)  status ;;
    focus)   focus_tab ;;
    close)   close_tab ;;
esac
