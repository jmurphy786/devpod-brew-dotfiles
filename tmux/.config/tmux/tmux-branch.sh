#!/usr/bin/env bash
# status-left / set-titles helper: the git branch for a pane's cwd.
#
# workmux session names are "<repo> 󰘬 <handle>" where handle is a slugified
# variant of the branch, so #S shows neither the repo you care about nor the
# real branch. Ask git instead.
#
# Usage: tmux-branch.sh <path>
#   " master"                 -> main checkout
#   "󰘬 PTL-35-Updated_UseForm" -> linked worktree
set -uo pipefail

dir="${1-}"
[ -n "$dir" ] && [ -d "$dir" ] || exit 0

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ "$branch" = HEAD ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
[ -n "$branch" ] || exit 0

# A linked worktree's git dir is .git/worktrees/<name>; the main one's equals
# the common dir.
git_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-dir 2>/dev/null)
common_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

if [ -n "$git_dir" ] && [ "$git_dir" = "$common_dir" ]; then
  printf ' %s\n' "$branch"
else
  printf '󰘬 %s\n' "$branch"
fi

