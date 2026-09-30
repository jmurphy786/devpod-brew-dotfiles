#!/usr/bin/env bash
# ctrl+h/j/k/l: move between herdr panes, but hand the key to nvim/vim when one
# is in the foreground so it can move between its own splits first. nvim does
# the reverse at its edge (nvim-tmux-navigator.lua calls `herdr pane focus`).
#
# Herdr has no vim passthrough: a built-in focus_pane_* key is swallowed before
# the app sees it, so ctrl+hjkl is a keys.command (plugin_action) that decides.
#
# Arguments: left | down | up | right
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

dir="${1:-}"
case "$dir" in
  left)  key=ctrl+h ;;
  down)  key=ctrl+j ;;
  up)    key=ctrl+k ;;
  right) key=ctrl+l ;;
  *) jm_log "nav.sh: unknown direction '$dir'"; exit 1 ;;
esac

pane=""
for f in focused_pane_id pane.id pane_id; do
  pane=$(jm_context "$f")
  [ -n "$pane" ] && break
done
pane="${pane:-${HERDR_PANE_ID:-}}"
[ -n "$pane" ] || { jm_log "nav.sh: no focused pane in context"; exit 1; }

procs=$("$HERDR" pane process-info --pane "$pane" 2>/dev/null \
  | jq -r '.result.process_info.foreground_processes[]?.name' 2>/dev/null)

if grep -qiE '^g?(n?vim?|vimdiff)$' <<<"$procs"; then
  exec "$HERDR" pane send-keys "$pane" "$key"
fi
exec "$HERDR" pane focus --pane "$pane" --direction "$dir"
