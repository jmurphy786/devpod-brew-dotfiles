#!/usr/bin/env bash
# worktree.created / worktree.opened -> publish the sidebar tokens.
#
# A worktree opens as herdr's plain one-tab workspace: no tab layout, and no
# symlinks either -- worktrunk's pre-start hook (~/.config/worktrunk/config.toml)
# links node_modules. What is left is the two display-only tokens the host's
# spaces sidebar renders: $jm_mark (branch glyph) and $jm_stack (gh-stack layer).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

# worktree.opened fires for a workspace that was already on screen too; that
# is a focus, not an open.
[ "$(jm_event already_open)" = "true" ] && exit 0

ws=$(jm_event workspace.workspace_id)
wt=$(jm_event worktree.path)
[ -n "$ws" ] || { jm_log "no workspace id in event; payload: ${HERDR_PLUGIN_EVENT_JSON:-<empty>}"; exit 0; }
[ -n "$wt" ] || wt=$(jm_event workspace.worktree.checkout_path)

jm_report_mark "$ws" "$wt"
jm_report_stack "$ws" "$wt"
