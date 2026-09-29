#!/usr/bin/env bash
# Publish the gh-stack layer index ("2/3") as a spaces-sidebar token.
#
# Replaces stack-pane-title.sh, which had to smuggle the value through
# {pane_title} because workmux's sidebar has no token for it -- and had to turn
# `allow-set-title off` to stop Claude overwriting it. herdr has first-class
# workspace metadata, so the pane title goes back to Claude.
#
#   stack.sh          one workspace (the event's, or HERDR_WORKSPACE_ID)
#   stack.sh --all    every open worktree workspace
#
# --all is what the stack-refresh action uses: `gh stack add|modify` shifts
# every layer index in the stack at once, including in worktrees that did not
# change branch.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

if [ "${1:-}" = "--all" ]; then
  "$HERDR" workspace list 2>/dev/null \
    | jq -r '.result.workspaces[] | select(.worktree != null)
             | "\(.workspace_id)\t\(.worktree.checkout_path)"' \
    | while IFS=$'\t' read -r ws wt; do
        jm_report_mark "$ws" "$wt"
        jm_report_stack "$ws" "$wt"
      done
  exit 0
fi

ws=$(jm_event workspace.workspace_id)
[ -n "$ws" ] || ws="${HERDR_WORKSPACE_ID:-}"
[ -n "$ws" ] || { jm_log "no workspace id"; exit 0; }

wt=$(jm_event worktree.path)
[ -n "$wt" ] || wt=$(jm_event workspace.worktree.checkout_path)
if [ -z "$wt" ]; then
  wt=$("$HERDR" workspace get "$ws" 2>/dev/null \
    | jq -r '.result.workspace.worktree.checkout_path // empty')
fi

jm_report_stack "$ws" "$wt"
