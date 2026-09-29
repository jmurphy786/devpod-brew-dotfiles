#!/usr/bin/env bash
# Worktree picker: open an existing worktree, or create one from a local
# branch, a remote-only branch, an open PR, or a typed new name.
#
# All of that is `wt switch`'s own picker (worktrunk). It runs from any
# checkout of the repo, which is what herdr's built-in New/Open worktree cannot
# do -- those only work from the parent repo. --no-cd because a popup has no
# shell to move; the post-switch hook in ~/.config/worktrunk/config.toml hands
# the checkout to herdr, which emits worktree.opened and so runs layout.sh.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

command -v wt >/dev/null 2>&1 || jm_die "wt is not installed (brew install worktrunk)."
here=$(jm_invoking_cwd) || jm_die "Could not tell which checkout this was opened from."
cd "$here" || jm_die "Cannot enter $here."

wt switch --branches --remotes --prs --no-cd || jm_hold "wt switch failed."
