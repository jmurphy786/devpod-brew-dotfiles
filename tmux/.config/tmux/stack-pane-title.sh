#!/usr/bin/env bash
# Put the gh-stack layer index into the workmux sidebar.
#
# Usage: stack-pane-title.sh
#
# The sidebar is rendered by the workmux binary against a fixed set of template
# placeholders -- there is no token for a stack and no shell escape, so the only
# field we can write from outside is {pane_title}, the third tile line.
#
# Claude sets that title itself via OSC, so writing it once would be undone on
# the agent's next redraw. `allow-set-title off` on the agent window closes that
# off, which is the trade: a worktree holding a stack shows "2/3" in the sidebar
# instead of Claude's own title. Worktrees with no stack are put back to `on`
# and behave exactly as before.
#
# Called after every gh stack action (gh-stack-fzf.sh) and on
# client-session-changed (~/.tmux.conf), so a worktree opened fresh is labelled
# without running anything by hand.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

wm_cd_repo_root "$(wm_calling_session)" >/dev/null 2>&1 || exit 0

changed=
declare -A stacked=()
while IFS=$'\t' read -r sb sp; do
  [ -n "$sb" ] && stacked["$sb"]="$sp"
done < <(wm_stack_map)

# wm_rows gives handle/branch for every worktree, main included (~15ms, git and
# tmux only). Columns: handle, dirty, state, stack, branch, mode, path.
while IFS=$'\t' read -r handle _ state _ branch _ _; do
  [ "$state" = live ] || continue
  session=$(wm_session_for_handle "$handle" | head -n 1)
  [ -n "$session" ] || continue

  index="${stacked[$branch]:-}"

  # The agent pane is the one in the "agent" window that is not workmux's own
  # sidebar pane; workmux tags that one with the @workmux_role pane option.
  while IFS=$'\t' read -r win pane role; do
    [ "$win" = agent ] && [ "$role" != sidebar ] || continue
    if [ -n "$index" ]; then
      was=$(tmux display-message -p -t "$pane" '#{pane_title}' 2>/dev/null)
      tmux set-option -w -t "$pane" allow-set-title off 2>/dev/null
      tmux select-pane -t "$pane" -T "$index" 2>/dev/null
      [ "$was" != "$index" ] && changed=1
    else
      tmux set-option -w -t "$pane" allow-set-title on 2>/dev/null
    fi
  done < <(tmux list-panes -s -t "$session" \
                -F '#{window_name}'$'\t''#{pane_id}'$'\t''#{@workmux_role}' 2>/dev/null)
done < <(wm_rows true)

# The daemon does not watch pane titles, so without this the new index waits for
# its next tick. SIGUSR1 is workmux's own repaint trigger -- the same line it
# installs into the after-select-window and after-kill-pane tmux hooks -- rather
# than anything read out of its internals. Only when something actually moved,
# so a session that is already right does not cost a repaint.
if [ -n "$changed" ]; then
  pid=$(tmux show-option -gqv @workmux_sidebar_daemon_pid 2>/dev/null)
  [ -n "$pid" ] && kill -USR1 "$pid" 2>/dev/null
fi

exit 0

