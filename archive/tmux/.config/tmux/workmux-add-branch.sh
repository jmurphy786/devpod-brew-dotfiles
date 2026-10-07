#!/usr/bin/env bash
# prefix,w -> a : create a worktree from a typed branch name.
#
# Usage: workmux-add-branch.sh <calling_session>
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

wm_cd_repo_root "$(wm_calling_session "${1-}")"

printf 'Branch: '
read -r branch
[ -z "$branch" ] && exit 0

workmux add "$branch" || wm_die "workmux add '$branch' failed."

