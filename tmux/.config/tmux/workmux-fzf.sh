#!/usr/bin/env bash
# prefix,w -> o / r / c : pick an existing worktree and open / remove / close it.
#
# Usage: workmux-fzf.sh <open|remove|close> <calling_session>
#
# Runs workmux directly in the popup so its confirmation prompts are visible and
# answerable. The previous `tmux run-shell -b` indirection had no TTY, so
# `workmux remove` could never get past its confirmation and silently no-opped.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

cmd="${1-}"
session=$(wm_calling_session "${2-}")
case "$cmd" in
  open|remove|close) ;;
  *) wm_die "Usage: ${0##*/} <open|remove|close> <session>" ;;
esac

wm_cd_repo_root "$session"

# `open` may target the main worktree (the master session) too, so you can always
# get back to a session for master. `remove` and `close` must never offer it.
include_main=false
[ "$cmd" = "open" ] && include_main=true

# wm_rows reads git and tmux directly (~15ms); wm_rows_slow asks workmux
# (~700ms) and is only reached if git output could not be parsed.
wm_worktrees() {
  wm_rows "$include_main" || wm_rows_slow "$include_main"
}

rows=$(wm_worktrees)
[ -z "$rows" ] && wm_die "No worktrees to $cmd."

# Column 1 is the handle -- the identifier open/remove/close document. It is the
# branch slugified (PTL-5-Foo -> ptl-5-foo), so the two differ and the branch is
# shown for readability only.
selection=$(printf '%s\n' "$rows" \
            | column -t -s $'\t' \
            | fzf --prompt "$cmd> " --height 100% --border none \
                  --header "workmux $cmd   (* = uncommitted changes, live = tmux target running)")
[ -z "$selection" ] && exit 0
handle=$(printf '%s' "$selection" | awk '{print $1}')
[ -z "$handle" ] && wm_die "Could not read a worktree handle from the selection."

# Never destroy the session/window we are standing in.
if [ "$cmd" = "remove" ] || [ "$cmd" = "close" ]; then
  wm_leave_target_session "$handle" "$session"
fi

echo "workmux $cmd $handle"
echo
workmux "$cmd" "$handle"
status=$?

if [ "$cmd" = "remove" ]; then
  # Confirm it actually went away rather than trusting the exit code. Drop the
  # cached `workmux list` first so the fallback path cannot answer from stale
  # data.
  wm_list_json_reset
  if printf '%s\n' "$(wm_worktrees)" | awk -F'\t' -v h="$handle" '$1==h{found=1} END{exit !found}'; then
    echo
    if [ $status -ne 0 ]; then
      echo "'$handle' was not removed (workmux exited $status)."
    else
      echo "'$handle' still exists after workmux remove."
    fi
    printf "Force remove '%s' (discards uncommitted changes and the branch)? [y/N] " "$handle"
    read -r reply || reply=""
    case "${reply-}" in
      y|Y)
        workmux remove -f "$handle"
        status=$?
        ;;
      *)
        wm_land_safely "$session"
        wm_hold "Left '$handle' in place."
        exit 0
        ;;
    esac
  fi
fi

wm_land_safely "$session"

if [ $status -ne 0 ]; then
  wm_hold "workmux $cmd '$handle' failed (exit $status)."
  exit $status
fi


