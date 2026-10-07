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

# `open` gets its own leaner row/header: no dirty/live/path noise (there is
# nothing to lose by jumping somewhere), but a ports column so a lingering
# docker-compose stack or dev server is visible before you go looking for it.
# `remove`/`close` keep the full wm_worktrees rows, since dirty/live status is
# exactly what matters before destroying something.
if [ "$cmd" = "open" ]; then
  rows=$(wm_rows_open "$session")
  header="workmux open   (▶ = current, i/n = stack layer, ports = live servers)"
else
  rows=$(wm_worktrees)
  header="workmux $cmd   (* = uncommitted, live = tmux running, 2/3 = layer in stack)"
fi
[ -z "$rows" ] && wm_die "No worktrees to $cmd."

# `open` rows have no handle column (nobody picking a worktree to jump to
# needs to see it) -- column 1 is the current-worktree marker instead, and the
# handle is resolved from column 2 (branch) after selection. `remove`/`close`
# still lead with the handle itself, since branch is shown there for
# readability only.
selection=$(printf '%s\n' "$rows" \
            | column -t -s $'\t' \
            | fzf --prompt "$cmd> " --height 100% --border none --no-preview \
                  --header "$header")
[ -z "$selection" ] && exit 0
if [ "$cmd" = "open" ]; then
  branch=$(printf '%s' "$selection" | awk '{print $2}')
  handle=$(wm_handle_for_branch "$branch")
else
  handle=$(printf '%s' "$selection" | awk '{print $1}')
fi
[ -z "$handle" ] && wm_die "Could not read a worktree handle from the selection."

# Never destroy the session/window we are standing in.
if [ "$cmd" = "remove" ] || [ "$cmd" = "close" ]; then
  wm_leave_target_session "$handle" "$session"
fi

# `remove` gets -k: tear down the worktree and tmux target but leave the local
# branch alone (local branches get pruned by hand in lazygit). The remote branch
# is never touched by `workmux remove` either way.
if [ "$cmd" = "remove" ]; then
  echo "workmux remove -k $handle"
  echo
  workmux remove -k "$handle"
else
  echo "workmux $cmd $handle"
  echo
  workmux "$cmd" "$handle"
fi
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
    printf "Force remove '%s' (discards uncommitted changes; keeps the branch)? [y/N] " "$handle"
    read -r reply || reply=""
    case "${reply-}" in
      y|Y)
        workmux remove -f -k "$handle"
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










