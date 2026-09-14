#!/usr/bin/env bash
# prefix+S : gh stack actions for the worktree the popup was opened from.
#
# Usage: gh-stack-fzf.sh [action]
#
# With no argument an fzf menu of actions is shown. The menu is the whole point
# of this script -- gh stack already ships good interactive pickers for choosing
# a stack (`checkout`) and a layer (`switch`), so those are handed straight to
# gh rather than rebuilt here. fzf supplies the one thing gh has no equivalent
# for: fuzzy access to sixteen subcommands without remembering their names.
#
# Unlike the workmux popups this does NOT cd to the repo root. A stack lives
# inside one worktree and every gh stack command is relative to the branch
# checked out there, so the popup's -d '#{pane_current_path}' cwd is already the
# right directory.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

# ---------------------------------------------------------------- preflight --

command -v gh >/dev/null 2>&1 \
  || wm_die "gh is not installed (brew install gh)."

gh extension list 2>/dev/null | grep -q 'gh stack' \
  || wm_die "gh-stack is not installed (gh extension install github/gh-stack)."

git rev-parse --git-dir >/dev/null 2>&1 \
  || wm_die "Not inside a git repository."

# gh-stack does not resolve ~/.ssh/config Host aliases the way gh core does, so
# a remote like git@github-work:owner/repo fails every command that needs the
# API with "none of the git remotes ... point to a known GitHub host".
# See https://github.com/github/gh-stack/issues/45. Catch it here with a clear
# message rather than letting each action fail on its own.
check_remote() {
  local url
  url=$(git remote get-url origin 2>/dev/null) || return 0
  case "$url" in
    *github.com[:/]*) return 0 ;;
  esac
  wm_die "origin is '$url'.
gh-stack cannot resolve SSH host aliases (gh-stack issue #45), so anything
touching GitHub will fail. Canonicalise the remote and pin the key per repo:

  git remote set-url origin git@github.com:OWNER/REPO.git
  git config --local core.sshCommand \"ssh -i ~/.ssh/id_work -o IdentitiesOnly=yes\""
}

# ------------------------------------------------------------------- helpers --

# The ticket key from the branch you are standing on, so layers inherit it:
# everything up to the second separator. PTL-9-Additional_Filters -> PTL-9, and
# PTL-9-Filter_Form -> PTL-9 as well, so it carries through every layer without
# being retyped.
#
# The separator class covers both conventions in this repo's history
# (NGP-376-practitioner-mobile... and ngp_346_mobile_view_HTML_reports). A bare
# `cut -d- -f1,2` cannot be used: on a branch with no key, such as
# Dashboard_Filter_Form, it returns the whole name and the layer would come out
# as Dashboard_Filter_Form-Filter_Form. Matching nothing is what lets the add
# case fall back to asking for a full branch name.
ticket_key() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null \
    | grep -oE '^[A-Za-z]+[-_][0-9]+' | head -1
}

# What this worktree's branch was forked from. Git writes it to the branch
# reflog at creation, so it is right whether the worktree came off master or off
# another feature branch. Only consulted when starting a stack, at which point
# the worktree branch is still the one checked out.
fork_point() {
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return 1
  # The format is not consistent: a branch made by hand records "Created from
  # master" while one made by gh-stack records "Created from
  # refs/heads/PTL-9-Additional_Filters", so strip the prefix.
  git reflog show "$branch" 2>/dev/null \
    | tail -1 \
    | sed -n 's/.*branch: Created from \(.*\)$/\1/p' \
    | sed 's#^refs/heads/##'
}

# gh-stack keeps tracking JSON next to the git dir. In a linked worktree
# --git-dir is .git/worktrees/<name>, which is where it landed here, but check
# the common dir too rather than assume.
stack_state() {
  local d
  for d in "$(git rev-parse --git-dir)" \
           "$(git rev-parse --path-format=absolute --git-common-dir)"; do
    [ -f "$d/gh-stack" ] && { printf '%s\n' "$d/gh-stack"; return 0; }
  done
  return 1
}

# The trunk of whichever stack holds the current branch.
stack_trunk() {
  local state branch
  state=$(stack_state) || return 1
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return 1
  jq -r --arg b "$branch" \
     '.stacks[] | select(any(.branches[]; .branch == $b)) | .trunk.branch' \
     "$state" 2>/dev/null | head -1
}

# Run a gh stack command in the popup, holding it open if it fails so the error
# is readable. Interactive TUIs (view, switch, submit, modify, merge) inherit
# the popup's tty and work unchanged.
run() {
  echo "gh stack $*"
  echo
  gh stack "$@"
  local status=$?
  [ $status -ne 0 ] && wm_die "gh stack $* failed (exit $status)."
  return 0
}

# Same, but hold the popup open on success too -- for commands whose output is
# the point and which would otherwise flash past.
run_and_show() {
  run "$@" && wm_hold ""
}

# prompt <var> <label>          -- required: an empty answer cancels the action.
# prompt_optional <var> <label> -- empty is a valid answer (use the gh default).
prompt() {
  local var="$1" label="$2" reply
  printf '%s' "$label"
  read -r reply
  [ -z "$reply" ] && exit 0
  printf -v "$var" '%s' "$reply"
}

prompt_optional() {
  local var="$1" label="$2" reply
  printf '%s' "$label"
  read -r reply
  printf -v "$var" '%s' "$reply"
}

# ---------------------------------------------------------------- the menu --

# key <TAB> action <TAB> description.
#
# Deliberately short. The dropped subcommands are still reachable as arguments
# (gh-stack-fzf.sh merge) and can each earn a row back if they turn out to be
# missed. checkout and sync are here despite the trim because they are the two
# things lazygit structurally cannot do: a fetch brings down a stack's branches
# but never its tracking state, and pulling a layer in lazygit rebases it
# against its own upstream rather than against its parent.
menu() {
  local rows
  rows=$(cat <<'ROWS'
v	view	show the stack and its PR status
m	modify	reorder, fold, drop or rename layers
s	submit	push branches and create or update the PRs
y	sync	fetch, cascade-rebase, push, refresh PR state
c	checkout	open another stack (local, or pulled from GitHub)
a	add	add a layer, starting the stack if there isn't one
ROWS
)

  # The branch is the cheap, always-correct bit of context; asking gh for the
  # stack here would put a network round-trip in front of every menu open.
  local branch out key
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || branch='(detached)'

  # --expect makes each letter fire its row immediately, like the prefix+w menu.
  # fzf then prints the pressed key on line 1 (empty when Enter was used) and
  # the highlighted row on line 2, so the key wins when there is one and the row
  # is the fallback. Bare letters cost the fuzzy filter, which eight rows do not
  # need.
  out=$(printf '%s\n' "$rows" \
        | column -t -s $'\t' \
        | fzf --prompt 'stack> ' --height 100% --border none \
              --expect=v,m,s,y,c,a \
              --header "gh stack   ${branch}   $(basename "$PWD")")
  [ -z "$out" ] && return 0

  key=$(printf '%s\n' "$out" | sed -n 1p)
  if [ -n "$key" ]; then
    printf '%s\n' "$rows" | awk -F'\t' -v k="$key" '$1 == k { print $2 }'
  else
    # Displayed row is "<key>  <action>  <description>", so the action is $2.
    printf '%s\n' "$out" | sed -n 2p | awk '{print $2}'
  fi
}

# ------------------------------------------------------------------ dispatch --

action="${1-}"
[ -z "$action" ] && action=$(menu)
[ -z "$action" ] && exit 0

# Everything except the purely local moves needs the GitHub API.
case "$action" in
  up|down|continue) ;;
  *) check_remote ;;
esac

case "$action" in
  view)      run_and_show view ;;
  switch)    run switch ;;
  up)        run up ;;
  down)      run down ;;
  checkout)  run checkout ;;          # no args: gh's own picker, remote stacks included
  modify)    run modify ;;
  submit)
    # gh stack never pushes the trunk, and GitHub cannot base a pull request on
    # a branch the remote does not have. Usually a no-op, since the trunk is
    # normally master, but it is what stopped the first submit creating anything
    # when the trunk was a local-only branch.
    trunk=$(stack_trunk)
    if [ -n "$trunk" ] \
       && ! git ls-remote --exit-code --heads origin "$trunk" >/dev/null 2>&1; then
      echo "Pushing '$trunk' so the layers have a base on the remote."
      git push -u origin "$trunk" || wm_die "Could not push '$trunk'."
      echo
    fi

    run submit
    ;;
  merge)     run merge ;;

  sync|push|rebase)
             run_and_show "$action" ;;

  continue)  run rebase --continue ;;

  init)
    # --base names the stack's trunk, and the branch you are standing on is
    # almost always what you want the new layers to sit above -- not the repo
    # default. The consequence is that this branch has to merge before the
    # stack can land; pass master here for a free-standing stack.
    current=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
      || wm_die "Detached HEAD -- check out the branch you want as the base first."
    prompt branches 'Branch names, bottom to top (space separated): '
    prompt_optional base "Base branch [$current]: "
    base=${base:-$current}
    # shellcheck disable=SC2086  # deliberate word splitting: one layer per name
    run init --base "$base" $branches
    ;;

  add)
    key=$(ticket_key)
    if [ -n "$key" ]; then
      prompt_optional name "New layer name (becomes ${key}-<name>): "
    else
      prompt_optional name 'New layer branch name: '
    fi
    # A blank answer used to exit the script with no output at all, which is
    # what made the old `init` key look broken. Say why instead.
    [ -z "$name" ] && wm_die "No name given, nothing created."

    # Spaces to underscores, matching PTL-29-Recently_Viewed_Hotfix in history.
    branch="${key:+$key-}$(printf '%s' "$name" | tr ' ' '_')"

    # Whether a stack exists here is the script's problem, not yours. The first
    # layer starts one, every layer after that stacks on the one below. The
    # worktree branch is a container rather than a pull request, so the stack is
    # based on what that branch was forked from, not on the branch itself.
    # `gh stack view` exits 2 when there is no stack here yet.
    if gh stack view --short >/dev/null 2>&1; then
      run add "$branch"
    else
      base=$(fork_point)
      [ -z "$base" ] \
        && base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
      [ -z "$base" ] \
        && wm_die "Could not work out what this branch was forked from.
Run this by hand with the base you want:  gh stack init --base <branch> $branch"
      echo "Starting a stack on '$base', where this worktree was branched from."
      echo
      run init --base "$base" "$branch"
    fi
    ;;

  link)
    prompt refs 'Branches / PR numbers, bottom to top (space separated): '
    # shellcheck disable=SC2086  # deliberate word splitting
    run_and_show link $refs
    ;;

  unstack)
    printf 'Unstack the current stack on GitHub? [y/N] '
    read -r reply
    case "${reply-}" in
      y|Y) run_and_show unstack ;;
      *)   exit 0 ;;
    esac
    ;;

  *)
    wm_die "Unknown action '$action'."
    ;;
esac

