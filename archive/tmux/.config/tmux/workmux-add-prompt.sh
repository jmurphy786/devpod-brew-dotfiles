#!/usr/bin/env bash
# prefix,w -> p : create a worktree with an LLM-named branch from a prompt.
#
# Usage: workmux-add-prompt.sh <calling_session>
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

wm_cd_repo_root "$(wm_calling_session "${1-}")"

printf 'Prompt: '
read -r prompt
[ -z "$prompt" ] && exit 0

workmux add -A -p "$prompt" || wm_die "workmux add failed."

