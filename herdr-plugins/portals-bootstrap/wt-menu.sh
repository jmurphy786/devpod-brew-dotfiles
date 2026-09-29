#!/usr/bin/env bash
# prefix+g: worktree menu. Two steps in one popup, both plain fzf.
#
#   wt-menu.sh              a three-row action menu; o / l / a picks a row
#   wt-menu.sh list <mode>  the typeable list behind it
#
#   o  here  worktrees of the current repo
#   l  all   worktrees of every repo that has a workspace on this machine
#   a  add   local and remote branches with no worktree yet
#
# Worktrunk (`wt`) supplies the rows and creates the checkouts; herdr's own New /
# Open worktree only run from the parent repo. Creating goes through
# `wt switch --no-cd`, whose post-switch hook (~/.config/worktrunk/config.toml)
# hands the checkout to herdr. Opening an existing one is `herdr worktree open`.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

self="$PWD/wt-menu.sh"

command -v wt  >/dev/null 2>&1 || jm_die "wt is not installed (brew install worktrunk)."
command -v fzf >/dev/null 2>&1 || jm_die "fzf is not installed (brew install fzf)."

# jm_repo_root <path> -- the main checkout of the repo <path> is in, or "".
jm_repo_root() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  printf '%s' "${common%/.git}"
}

# repos <mode> -- one repo root per line. "all" is every herdr workspace's
# repo, from its first pane's cwd, de-duplicated.
repos() {
  local here ws pane_cwd
  if [ "$1" != all ]; then
    here=$(jm_invoking_cwd) || jm_die "Could not tell which checkout this was opened from."
    jm_repo_root "$here"; echo
    return
  fi
  for ws in $("$HERDR" workspace list 2>/dev/null | jq -r '.result.workspaces[].workspace_id'); do
    pane_cwd=$("$HERDR" pane list --workspace "$ws" 2>/dev/null | jq -r '.result.panes[0].cwd // empty')
    [ -n "$pane_cwd" ] && { jm_repo_root "$pane_cwd"; echo; }
  done | awk 'NF && !seen[$0]++'
}

# rows <mode> <repo> -- repo<TAB>kind<TAB>name<TAB>branch<TAB>path
rows() {
  local mode="$1" repo="$2" flags=() filter
  case "$mode" in
    add) flags=(--branches --remotes)
         # A local branch beats its remote twin; one row per branch.
         filter='map(select(.worktree == null)) | sort_by(.remote != null) | unique_by(.branch)' ;;
    *)   filter='map(select(.worktree != null))' ;;
  esac
  wt -C "$repo" list "${flags[@]}" --format=json 2>/dev/null | jq -r \
    --arg repo "$repo" --arg name "$(basename "$repo")" ".items | $filter | .[]
      | [\$repo, (if .worktree then \"wt\" elif .remote then \"remote\" else \"local\" end),
         \$name, .branch, (.worktree.path // \"\")] | @tsv"
}

if [ "${1:-}" != list ]; then
  # Step 1. --disabled makes the letters binds instead of filter text.
  printf '%s\n' \
    "o  open a worktree      this repo" \
    "l  open a worktree      all repos on this machine" \
    "a  add a worktree       from a local / remote branch" \
    | fzf --disabled --no-info --layout=reverse --height=100% --prompt='' \
        --header='press a letter' \
        --bind "o:become(bash '$self' list here)" \
        --bind "l:become(bash '$self' list all)" \
        --bind "a:become(bash '$self' list add)" \
        --bind "enter:become(bash '$self' list {1})" >/dev/null
  exit 0
fi

# Step 2. Enter maps the menu's letters too, so {1} works from step 1.
case "${2:-}" in
  o) mode=here ;; l) mode=all ;; a) mode=add ;;
  here|all|add) mode="$2" ;;
  *) jm_die "unknown mode '${2:-}'" ;;
esac

list=$(repos "$mode" | while IFS= read -r repo; do [ -n "$repo" ] && rows "$mode" "$repo"; done)
[ -n "$list" ] || [ "$mode" = add ] || jm_die "No worktrees found."

case "$mode" in
  here) title="worktrees"; cols=4 ;;
  all)  title="all worktrees"; cols=3,4 ;;
  add)  title="add from branch  (ctrl-n: new branch from typed text)"; cols=2,4 ;;
esac

out=$(printf '%s\n' "$list" | fzf --delimiter='\t' --with-nth="$cols" --layout=reverse \
        --height=100% --no-info --prompt='> ' --header="$title" \
        --print-query --expect=ctrl-n)
[ -n "$out" ] || exit 0
query=$(sed -n 1p <<<"$out"); key=$(sed -n 2p <<<"$out"); sel=$(sed -n 3p <<<"$out")

if [ "$key" = ctrl-n ]; then
  [ -n "$query" ] || jm_die "Type a branch name first."
  repo=$(repos here | head -1)
  wt -C "$repo" switch --create "$query" --no-cd --yes || jm_hold "wt switch failed."
  exit 0
fi

[ -n "$sel" ] || exit 0
IFS=$'\t' read -r repo _kind _name branch path <<<"$sel"
if [ -n "$path" ]; then
  (cd "$repo" && "$HERDR" worktree open --path "$path") >/dev/null || jm_hold "herdr could not open $path."
else
  wt -C "$repo" switch "$branch" --no-cd --yes || jm_hold "wt switch failed."
fi
