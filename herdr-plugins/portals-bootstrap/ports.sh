#!/usr/bin/env bash
# Publish the listening TCP ports of each workspace as the $jm_ports
# spaces-sidebar token, so a forgotten `pnpm dev`, `expo start` or Aspire
# AppHost is visible from the sidebar.
#
#   ports.sh --once   one pass over every workspace
#   ports.sh --loop   repeat every PORTS_INTERVAL seconds (default 5); a second
#                     copy exits at once (flock).
#   ports.sh --ensure start the loop detached unless one is already running.
#                     Run from the focus/create events in herdr-plugin.toml and
#                     from layout.sh, so the poller comes back after a server
#                     restart and covers workspaces opened before it existed.
#
# A listener belongs to the workspace whose root is the deepest one containing
# the process's cwd. A workspace's root is its worktree checkout, or else the
# git toplevel of each of its panes' cwds (a plain workspace such as a
# microservices repo opened from a subdirectory has no worktree info). Worktrees
# nest in <repo>/.worktrees/, so the main checkout is a prefix of every other
# one and must not claim theirs.
#
# What is shown: ports below the kernel's ephemeral range, at most
# PORTS_MAX_SHOWN of them, then "+N". Kestrel/Aspire bind dozens of random
# high ports per run; those would bury the ones you can actually open, so they
# are dropped -- unless they are all there is, which shows as ":auto".
#
# Only processes this server can read /proc/<pid>/cwd for are seen: a
# devcontainer's server owns that container's workspaces. The containers share a
# PID namespace (and XDG_RUNTIME_DIR), so the lock lives in the per-container
# plugin state dir, not the runtime dir.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

INTERVAL="${PORTS_INTERVAL:-5}"
MAX_SHOWN="${PORTS_MAX_SHOWN:-4}"
# Outlives a missed pass or two, but a dead poller's badges still expire.
TTL_MS=$((INTERVAL * 3000))

eph_low=$(awk '{print $1}' /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null)
eph_low=${eph_low:-32768}

# cwd -> git toplevel ("" for none), kept across passes of the loop.
declare -A root_cache=()

# pane_root <cwd> -- the git toplevel of <cwd>, or "" outside a repo.
pane_root() {
  local cwd="$1"
  if [ -z "${root_cache[$cwd]+x}" ]; then
    root_cache[$cwd]=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  fi
  printf '%s' "${root_cache[$cwd]}"
}

# roots <workspaces-json> -- "<workspace_id>\t<root>" for every workspace.
roots() {
  printf '%s' "$1" | jq -r '.result.workspaces[]
    | select(.worktree != null) | "\(.workspace_id)\t\(.worktree.checkout_path)"'

  local plain ws cwd root
  plain=$(printf '%s' "$1" | jq -c '[.result.workspaces[] | select(.worktree == null) | .workspace_id]')
  [ "$plain" != "[]" ] || return 0
  "$HERDR" pane list 2>/dev/null | jq -r --argjson ids "$plain" '
      .result.panes[] | select(.workspace_id as $w | $ids | index($w))
      | "\(.workspace_id)\t\(.cwd // empty)"' | sort -u \
    | while IFS=$'\t' read -r ws cwd; do
        [ -n "$cwd" ] && [ -d "$cwd" ] || continue
        root=$(pane_root "$cwd")
        [ -n "$root" ] && [ "$root" != "$HOME" ] && printf '%s\t%s\n' "$ws" "$root"
      done | sort -u
}

ports_once() {
  local ws_json
  ws_json=$("$HERDR" workspace list 2>/dev/null) || return 1

  local listeners
  listeners=$(lsof -nP -iTCP -sTCP:LISTEN -Fpn 2>/dev/null | awk '
    /^p/ { pid = substr($0, 2) }
    /^n/ { name = substr($0, 2); sub(/.*:/, "", name); print pid "\t" name }
  ' | while IFS=$'\t' read -r pid port; do
        cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || continue
        printf '%s\t%s\n' "$cwd" "$port"
      done)

  # "<workspace_id>\t<port>", each listener credited to its deepest root.
  local owned
  owned=$(awk -F'\t' '
      FNR == NR { n++; w[n] = $1; r[n] = $2; next }
      NF == 2 {
        best = 0; len = 0
        for (i = 1; i <= n; i++)
          if (r[i] != "" && ($1 == r[i] || index($1, r[i] "/") == 1) && length(r[i]) > len) {
            best = i; len = length(r[i])
          }
        if (best) print w[best] "\t" $2
      }' <(roots "$ws_json") <(printf '%s\n' "$listeners") | sort -u)

  local ws ports low high n
  while IFS= read -r ws; do
    [ -n "$ws" ] || continue
    ports=$(awk -F'\t' -v w="$ws" '$1 == w { print $2 }' <<<"$owned" | sort -un)
    low=$(awk -v e="$eph_low" '$1 < e' <<<"$ports")
    high=$(awk -v e="$eph_low" '$1 >= e' <<<"$ports")
    if [ -n "$low" ]; then
      n=$(wc -l <<<"$low")
      token=$(head -n "$MAX_SHOWN" <<<"$low" | sed 's/^/:/' | paste -sd' ')
      [ "$n" -gt "$MAX_SHOWN" ] && token="$token +$((n - MAX_SHOWN))"
    elif [ -n "$high" ]; then
      token=":auto"
    else
      token=
    fi
    if [ -n "$token" ]; then
      "$HERDR" workspace report-metadata "$ws" --source jm-ports \
        --token "jm_ports=$token" --ttl-ms "$TTL_MS" >/dev/null 2>&1
    else
      "$HERDR" workspace report-metadata "$ws" --source jm-ports \
        --clear-token jm_ports >/dev/null 2>&1
    fi
  done < <(printf '%s' "$ws_json" | jq -r '.result.workspaces[].workspace_id')
  # The loop's status is the last report-metadata's; a workspace closed mid-pass
  # must not read as "herdr is gone" and end the poller.
  return 0
}

state_dir="${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/jm.portals-bootstrap}"
mkdir -p "$state_dir" 2>/dev/null
lock="$state_dir/ports.lock"

case "${1:---once}" in
  --once) ports_once ;;
  --ensure)
    # Free lock means no poller. The probe subshell releases it on exit.
    ( exec 8>"$lock" && flock -n 8 ) || exit 0
    setsid nohup bash ports.sh --loop >/dev/null 2>&1 </dev/null &
    ;;
  --loop)
    exec 9>"$lock" || exit 1
    flock -n 9 || exit 0
    while ports_once; do sleep "$INTERVAL"; done
    ;;
  *) echo "usage: ports.sh [--once|--loop|--ensure]" >&2; exit 2 ;;
esac
