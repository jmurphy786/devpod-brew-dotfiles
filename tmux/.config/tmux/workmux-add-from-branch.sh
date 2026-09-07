#!/usr/bin/env bash
# prefix,w -> b : create a worktree from an existing local branch.
#
# Usage: workmux-add-from-branch.sh <calling_session>
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

session=$(wm_calling_session "${1-}")
wm_cd_repo_root "$session"

# Local branches that do not already have a worktree. `workmux list` would show
# existing worktrees instead, which is the opposite of what we want here.
in_worktree=$(git worktree list --porcelain \
              | awk '/^branch /{sub("refs/heads/","",$2); print $2}')

branches=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads \
           | grep -vxF "${in_worktree:-$'\x01'}")

[ -z "$branches" ] && wm_die "No local branches without a worktree."

branch=$(printf '%s\n' "$branches" \
         | fzf --prompt 'branch> ' --height 100% --border none \
               --header "worktree from branch  ($(basename "$PWD"))")
[ -z "$branch" ] && exit 0

echo "workmux add $branch"
if ! workmux add "$branch"; then
  wm_hold "workmux add '$branch' failed."
  exit 1
fi

