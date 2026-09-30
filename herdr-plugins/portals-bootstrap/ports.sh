#!/usr/bin/env bash
# Publish the listening TCP ports of each worktree workspace as the $jm_ports
# spaces-sidebar token, so a forgotten `pnpm dev` is visible from the sidebar.
#
#   ports.sh --once   one pass over every worktree workspace
#   ports.sh --loop   repeat every PORTS_INTERVAL seconds (default 5); a second
#                     copy exits at once (flock).
#   ports.sh --ensure start the loop detached unless one is already running.
#                     Run from the focus/create events in herdr-plugin.toml and
#                     from layout.sh, so the poller comes back after a server
#                     restart and covers workspaces opened before it existed.
#
# A listener is credited to the deepest checkout containing its cwd. Worktrees
# nest in <repo>/.worktrees/, so the main checkout's path is a prefix of every
# other one and would otherwise claim all of them. Only processes in this
# server's own PID namespace are visible, which is the right scope: a
# devcontainer's server owns that container's workspaces.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

INTERVAL="${PORTS_INTERVAL:-5}"
# Outlives a missed pass or two, but a dead poller's badges still expire.
TTL_MS=$((INTERVAL * 3000))

ports_once() {
  local ws_json paths listeners
  ws_json=$("$HERDR" workspace list 2>/dev/null) || return 1
  listeners=$(lsof -nP -iTCP -sTCP:LISTEN -Fpn 2>/dev/null | awk '
    /^p/ { pid = substr($0, 2) }
    /^n/ { name = substr($0, 2); sub(/.*:/, "", name); print pid "\t" name }
  ' | while IFS=$'\t' read -r pid port; do
        cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || continue
        printf '%s\t%s\n' "$cwd" "$port"
      done)

  # "<workspace_id>\t<checkout_path>" for every worktree workspace.
  local rows
  rows=$(printf '%s' "$ws_json" | jq -r '.result.workspaces[]
    | select(.worktree != null) | "\(.workspace_id)\t\(.worktree.checkout_path)"')
  [ -n "$rows" ] || return 0
  paths=$(printf '%s\n' "$rows" | cut -f2)

  local ws wt ports
  while IFS=$'\t' read -r ws wt; do
    [ -n "$ws" ] || continue
    ports=$(printf '%s\n' "$listeners" | awk -F'\t' -v wt="$wt" -v paths="$paths" '
      BEGIN { n = split(paths, p, "\n") }
      NF == 2 {
        cwd = $1; best = ""
        for (i = 1; i <= n; i++)
          if (p[i] != "" && (cwd == p[i] || index(cwd, p[i] "/") == 1) && length(p[i]) > length(best))
            best = p[i]
        if (best == wt) print $2
      }' | sort -un | sed 's/^/:/' | paste -sd' ')
    if [ -n "$ports" ]; then
      "$HERDR" workspace report-metadata "$ws" --source jm-ports \
        --token "jm_ports=$ports" --ttl-ms "$TTL_MS" >/dev/null 2>&1
    else
      "$HERDR" workspace report-metadata "$ws" --source jm-ports \
        --clear-token jm_ports >/dev/null 2>&1
    fi
  done <<<"$rows"
  # The loop's status is the last report-metadata's; a workspace closed mid-pass
  # must not read as "herdr is gone" and end the poller.
  return 0
}

lock="${XDG_RUNTIME_DIR:-/tmp}/jm-herdr-ports-$(id -u).lock"

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
