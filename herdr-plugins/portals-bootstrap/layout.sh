#!/usr/bin/env bash
# worktree.created / worktree.opened -> publish the sidebar tokens.
#
# A worktree opens as herdr's plain one-tab workspace with no tab layout. This
# links node_modules from the main checkout, then publishes the two
# display-only tokens the host's spaces sidebar renders: $jm_mark (branch
# glyph) and $jm_stack (gh-stack layer).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

# Keep the sidebar ports poller alive. Idempotent, so every event may call it.
bash ports.sh --ensure

# worktree.opened fires for a workspace that was already on screen too; that
# is a focus, not an open.
[ "$(jm_event already_open)" = "true" ] && exit 0

ws=$(jm_event workspace.workspace_id)
wt=$(jm_event worktree.path)
[ -n "$ws" ] || { jm_log "no workspace id in event; payload: ${HERDR_PLUGIN_EVENT_JSON:-<empty>}"; exit 0; }
[ -n "$wt" ] || wt=$(jm_event workspace.worktree.checkout_path)

# node_modules is shared with the main checkout. Skipped for the main checkout
# itself, when it has none, or when the worktree already has its own.
if [ -n "$wt" ]; then
  common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  main=${common%/.git}
  if [ -n "$main" ] && [ "$main" != "$wt" ] && [ -e "$main/node_modules" ] \
     && [ ! -e "$wt/node_modules" ] && [ ! -L "$wt/node_modules" ]; then
    ln -s "$main/node_modules" "$wt/node_modules"
  fi
fi

jm_report_mark "$ws" "$wt"
jm_report_stack "$ws" "$wt"
