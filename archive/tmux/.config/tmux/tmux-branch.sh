#!/usr/bin/env bash
# status-left / set-titles helper: the git branch for a pane's cwd, plus the
# gh-stack layer it is on.
#
# workmux session names are "<repo> 󰘬 <handle>" where handle is a slugified
# variant of the branch, so #S shows neither the repo you care about nor the
# real branch. Ask git instead.
#
# Usage: tmux-branch.sh <path> [width]
#   " master"                          -> main checkout, not stacked
#   "󰘬 PTL-9-Patient_Profile_F…  2/3"   -> layer two of a three-layer stack
#
# <width> is a maximum, not a fixed size: a long branch is truncated to fit, a
# short one prints short, so the status block hugs its content. Omitted
# (set-titles-string) falls back to a shorter cap -- titles have less room.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

dir="${1-}"
width="${2:-0}"
[ -n "$dir" ] && [ -d "$dir" ] || exit 0

# One fork for all three. Separate `rev-parse` calls were the bulk of this
# script's cost, and at one status tick per second that cost is paid over and
# over. A linked worktree's git dir is .git/worktrees/<name>; the main one's
# equals the common dir, which is how the two are told apart below.
{ read -r branch; read -r git_dir; read -r common_dir; } < <(
  git -C "$dir" rev-parse --abbrev-ref HEAD \
                --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
[ -n "${branch:-}" ] || exit 0

# Detached HEAD is the one case needing a second call, and it is rare enough.
[ "$branch" = HEAD ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
[ -n "$branch" ] || exit 0

# The main checkout has no glyph, but it still occupies the column, so the
# branch starts in the same place in both cases.
if [ -n "$git_dir" ] && [ "$git_dir" = "$common_dir" ]; then
  icon=' '
else
  icon='󰘬'
fi

# "2/3" = layer two of a three-layer stack; nothing at all when the branch is
# not stacked -- the block is content-width now, so there is no column to hold
# open.
stack=$(wm_stack_index "$git_dir" "$branch")

# Branch names are ASCII and the nerd-font glyph is one cell, so character
# counts are display columns here.
if [ "$width" -gt 0 ]; then
  room=$(( width - 2 ))
  [ "$room" -lt 4 ] && room=4
  [ ${#branch} -gt "$room" ] && branch="${branch:0:$((room - 1))}…"
elif [ ${#branch} -gt 15 ]; then
  branch="${branch:0:15}…"
fi

if [ -n "$stack" ]; then
  printf '%s %s  %s\n' "$icon" "$branch" "$stack"
else
  printf '%s %s\n' "$icon" "$branch"
fi
