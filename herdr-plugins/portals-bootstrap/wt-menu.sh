#!/usr/bin/env bash
# prefix+g: worktree menu. A two-row letter menu in one popup, then an fzf list:
#
#   o  open    the current repo's worktrees
#   a  add     local and remote branches with no worktree yet
#   n  new     a new worktree and branch, named by typing it
#
# Worktrunk (`wt`) supplies the rows and creates the checkouts; herdr's own New /
# Open worktree only run from the parent repo. Creating goes through
# `wt switch --no-cd`, then `herdr worktree open` registers the checkout with
# herdr (herdr_open below), so it does not depend on a worktrunk hook.
# Deleting is herdr's own remove_worktree (prefix+d).
#
# Arguments: (none) the menu; o | a | n a menu row; list here|add.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

self="$PWD/wt-menu.sh"

# The containers' FZF_DEFAULT_OPTS carries a file preview (bat/cat of the
# selected row), which here renders as "cat: ...: No such file". Blank it for
# this script and for the `become` step that inherits it.
export FZF_DEFAULT_OPTS=""

command -v wt  >/dev/null 2>&1 || jm_die "wt is not installed (brew install worktrunk)."
command -v fzf >/dev/null 2>&1 || jm_die "fzf is not installed (brew install fzf)."

# jm_repo_root <path> -- the main checkout of the repo <path> is in, or "".
jm_repo_root() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  printf '%s' "${common%/.git}"
}

# repos -- the repo root of the checkout this was opened over.
repos() {
  local here
  here=$(jm_invoking_cwd) || jm_die "Could not tell which checkout this was opened from."
  jm_repo_root "$here"; echo
}

# rows <mode> <repo> -- repo<TAB>kind<TAB>name<TAB>branch<TAB>path
rows() {
  local mode="$1" repo="$2" flags=() filter
  case "$mode" in
    add) flags=(--branches --remotes)
         # A local branch beats its remote twin; one row per branch.
         filter='map(select(.worktree == null)) | sort_by(.remote != null) | unique_by(.branch)' ;;
    *)   filter='map(select(.worktree != null))' ;;  # here
  esac
  wt -C "$repo" list "${flags[@]}" --format=json 2>/dev/null | jq -r \
    --arg repo "$repo" --arg name "$(basename "$repo")" ".items | $filter | .[]
      | [\$repo, (if .worktree then \"wt\" elif .remote then \"remote\" else \"local\" end),
         \$name, .branch, (.worktree.path // \"\")] | @tsv"
}

# A menu row's letter stands for the step it runs, so a bind and Enter on a row
# both just re-enter this script with that letter.
case "${1:-}" in
  o) set -- list here ;;
  a) set -- list add ;;
  n) set -- new ;;
esac

# Every herdr call below runs against the repo, not the workspace the popup was
# opened in: from a linked worktree HERDR_WORKSPACE_ID names that worktree, and
# herdr's worktree commands reject it as a target.
herdr_repo() { env -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID "$HERDR" "$@"; }

# herdr_open <repo> <branch> -- hand a branch's checkout to herdr so it shows up
# as a worktree workspace. Idempotent: opening an open workspace just focuses it.
herdr_open() {
  local repo="$1" branch="$2" path
  path=$(wt -C "$repo" list --format=json 2>/dev/null \
    | jq -r --arg b "$branch" '.items[] | select(.branch == $b and .worktree != null) | .worktree.path' | head -1)
  [ -n "$path" ] || jm_hold "No checkout found for $branch."
  [ -n "$path" ] || return 1
  (cd "$repo" && herdr_repo worktree open --cwd "$repo" --path "$path") >/dev/null \
    || jm_hold "herdr could not open $path."
}

if [ "${1:-}" = new ]; then
  repo=$(repos | head -1)
  [ -n "$repo" ] || jm_die "Not inside a git repository."
  printf 'new worktree name: '
  IFS= read -r name
  name=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$name")
  [ -n "$name" ] || exit 0
  wt -C "$repo" switch --create "$name" --no-cd --yes || { jm_hold "wt switch failed."; exit 1; }
  herdr_open "$repo" "$name"
  exit 0
fi

if [ "${1:-}" = "" ]; then
  # Step 1. --disabled makes the letters binds instead of filter text.
  printf '%s\n' \
    "o  open a worktree      this repo" \
    "a  add a worktree       from a local / remote branch" \
    "n  new worktree         type a name" \
    | fzf --disabled --no-info --layout=reverse --height=100% --prompt='' \
        --header='press a letter' \
        --bind "o:become(bash '$self' o)" \
        --bind "a:become(bash '$self' a)" \
        --bind "n:become(bash '$self' n)" \
        --bind "enter:become(bash '$self' {1})" >/dev/null
  exit 0
fi

# Step 2: the fzf lists.
[ "$1" = list ] || jm_die "unknown argument '$1'"
case "${2:-}" in
  here|add) mode="$2" ;;
  *) jm_die "unknown mode '${2:-}'" ;;
esac

list=$(repos | while IFS= read -r repo; do [ -n "$repo" ] && rows "$mode" "$repo"; done)
[ -n "$list" ] || [ "$mode" = add ] || jm_die "No worktrees found."

case "$mode" in
  here) title="worktrees"; cols=4 ;;
  add)  title="add from branch  (ctrl-n: new branch from typed text)"; cols=2,4 ;;
esac

out=$(printf '%s\n' "$list" | fzf --delimiter='\t' --with-nth="$cols" --layout=reverse \
        --height=100% --no-info --prompt='> ' --header="$title" \
        --print-query --expect=ctrl-n)
[ -n "$out" ] || exit 0
query=$(sed -n 1p <<<"$out"); key=$(sed -n 2p <<<"$out"); sel=$(sed -n 3p <<<"$out")

if [ "$key" = ctrl-n ]; then
  [ -n "$query" ] || jm_die "Type a branch name first."
  repo=$(repos | head -1)
  wt -C "$repo" switch --create "$query" --no-cd --yes || { jm_hold "wt switch failed."; exit 1; }
  herdr_open "$repo" "$query"
  exit 0
fi

[ -n "$sel" ] || exit 0
IFS=$'\t' read -r repo _kind _name branch path <<<"$sel"

if [ -n "$path" ]; then
  (cd "$repo" && herdr_repo worktree open --cwd "$repo" --path "$path") >/dev/null || jm_hold "herdr could not open $path."
else
  wt -C "$repo" switch "$branch" --no-cd --yes || { jm_hold "wt switch failed."; exit 1; }
  herdr_open "$repo" "$branch"
fi
