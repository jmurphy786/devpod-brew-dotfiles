#!/usr/bin/env bash
# worktree.created -> lay the workspace out like a workmux worktree window set.
#
# The tabs and their commands come from the repo's .workmux.yaml, falling back
# to ~/.config/workmux/config.yaml, so the layout has one definition and both
# tools honour it.
#
# herdr has no "launch this pane running X" flag: a tab is created with a
# shell, and the command is submitted into that shell with `pane run`. That is
# the same thing workmux does with tmux send-keys, so an exited command leaves
# a usable shell behind either way.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

# worktree.opened fires for a workspace that was already on screen too; that
# is a focus, not a creation.
[ "$(jm_event already_open)" = "true" ] && exit 0

ws=$(jm_event workspace.workspace_id)
tab=$(jm_event workspace.active_tab_id)
wt=$(jm_event worktree.path)
[ -n "$ws" ] || { jm_log "no workspace id in event; payload: ${HERDR_PLUGIN_EVENT_JSON:-<empty>}"; exit 0; }
[ -n "$wt" ] || wt=$(jm_event workspace.worktree.checkout_path)

# Only lay out worktrees of a repo that defines a layout. Everything else --
# another project, a scratch checkout -- gets herdr's plain one-tab workspace.
# Never lay out twice. A worktree closed and re-opened arrives here with the
# tabs it already had, and appending to them is the one failure mode that
# costs real work to undo.
tab_count=$(jm_event workspace.tab_count)
if [ -n "$tab_count" ] && [ "$tab_count" -gt 1 ] 2>/dev/null; then
  jm_log "workspace $ws already has $tab_count tabs; leaving it alone"
  jm_report_mark "$ws" "$wt"
  jm_report_stack "$ws" "$wt"
  exit 0
fi

repo=$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)
common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
main=${common%/.git}

# files.symlink from .workmux.yaml -- node_modules, mostly -- linked from the
# main worktree, the same as `workmux add` does. Before any tab exists, so the
# runner's `pnpm run dev` never starts against a missing node_modules.
if [ -n "$main" ] && [ "$main" != "$wt" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src="$main/$rel" dst="$wt/$rel"
    [ -e "$src" ] || { jm_log "symlink: $src does not exist, skipping"; continue; }
    # A real file or directory there is the checkout's own; never replace it.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      jm_log "symlink: $dst already exists, leaving it"
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst" || jm_log "symlink: could not link $dst"
  done < <(python3 parse-layout.py --symlinks \
             "${repo:-/nonexistent}/.workmux.yaml" \
             "$main/.workmux.yaml" \
             "$HOME/.config/workmux/config.yaml")
fi

jm_report_mark "$ws" "$wt"

layout=$(python3 parse-layout.py \
  "${repo:-/nonexistent}/.workmux.yaml" \
  "${main:-/nonexistent}/.workmux.yaml" \
  "$HOME/.config/workmux/config.yaml") || {
  jm_log "no workmux layout for $wt; leaving the default single tab"
  exit 0
}

first=1
while IFS=$'\t' read -r name cmd _focus; do
  [ -n "$name" ] || continue
  if [ "$first" = 1 ]; then
    first=0
    # The workspace already has one tab and one pane; reuse them so the
    # layout does not leave an unnamed empty tab in front.
    pane=$("$HERDR" pane list --workspace "$ws" 2>/dev/null \
      | jq -r --arg t "$tab" '.result.panes[] | select(.tab_id == $t) | .pane_id' | head -1)
    [ -n "$tab" ] && "$HERDR" tab rename "$tab" "$name" >/dev/null 2>&1
  else
    pane=$("$HERDR" tab create --workspace "$ws" --label "$name" --no-focus 2>/dev/null \
      | jq -r '.result.root_pane.pane_id // empty')
  fi
  if [ -z "$pane" ]; then
    jm_log "could not resolve a pane for tab '$name'"
    continue
  fi
  # A window with no panes: block in the config is an empty shell on purpose
  # (workmux's `runner` is one), so an empty command is not an error.
  [ -n "$cmd" ] && "$HERDR" pane run "$pane" "$cmd" >/dev/null 2>&1
done <<<"$layout"

# gh-stack state is per worktree, so a brand new one is usually unstacked --
# publish anyway to clear any token inherited from a recycled workspace id.
jm_report_stack "$ws" "$wt"
