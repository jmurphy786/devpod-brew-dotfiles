#!/usr/bin/env bash
# prefix,w -> b : create a worktree from a local branch, a remote branch, or an
# open pull request.
#
# Usage: workmux-add-from-branch.sh <calling_session>
#
# `workmux add` already accepts a remote ref (`workmux add origin/foo`) and
# `--pr <number>`, so all three kinds are one picker with three dispatches.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

session=$(wm_calling_session "${1-}")
wm_cd_repo_root "$session"

# Remote-tracking refs live in the shared .git dir, so fetching here refreshes
# every worktree. This is why you never need to switch to master and fetch by
# hand before making a worktree for someone's PR.
prs_json=$(mktemp)
trap 'rm -f "$prs_json"' EXIT

if command -v gh >/dev/null 2>&1; then
  gh pr list --state open --limit 100 \
     --json number,title,headRefName,author,isDraft >"$prs_json" 2>/dev/null &
  gh_pid=$!
else
  gh_pid=
fi

printf 'fetching origin…\n'
git fetch --prune --quiet origin 2>/dev/null
[ -n "$gh_pid" ] && wait "$gh_pid"

# Branches that already have a worktree: offering them again would just fail.
in_worktree=$(git worktree list --porcelain \
              | awk '/^branch /{sub("refs/heads/","",$2); print $2}')
locals=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads)

rows=$(
  printf '%s\n' "$locals" | awk -v taken="$in_worktree" '
    BEGIN { n = split(taken, t, "\n"); for (i = 1; i <= n; i++) if (t[i] != "") is_taken[t[i]] = 1 }
    $0 != "" && !($0 in is_taken) { printf "local\t%s\t\n", $0 }
  '

  # Remote branches with no local counterpart at all -- if a local copy exists
  # it is already listed above (or has a worktree), and `workmux add origin/x`
  # would collide with it.
  git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin \
    | awk -v locals="$locals" '
        BEGIN { n = split(locals, l, "\n"); for (i = 1; i <= n; i++) if (l[i] != "") is_local[l[i]] = 1 }
        # refs/remotes/origin/HEAD shortens to plain "origin".
        $0 == "origin" || $0 == "origin/HEAD" { next }
        { short = $0; sub("^origin/", "", short) }
        short != "" && !(short in is_local) { printf "remote\t%s\t\n", $0 }
      '

  if [ -s "$prs_json" ]; then
    jq -r --arg taken "$in_worktree" '
      ($taken | split("\n")) as $t
      | .[] | select(.headRefName as $h | ($t | index($h)) | not)
      | "pr\t#\(.number)\t\(if .isDraft then "[draft] " else "" end)\(.title)  (@\(.author.login), \(.headRefName))"
    ' "$prs_json" 2>/dev/null
  fi
)

[ -z "${rows//[[:space:]]/}" ] && wm_die "Nothing to create a worktree from."

selection=$(printf '%s\n' "$rows" \
            | column -t -s $'\t' \
            | fzf --prompt 'branch> ' --height 100% --border none \
                  --header "worktree from branch / remote / PR  ($(basename "$PWD"))")
[ -z "$selection" ] && exit 0

kind=$(printf '%s' "$selection" | awk '{print $1}')
key=$(printf '%s' "$selection" | awk '{print $2}')
[ -n "$kind" ] && [ -n "$key" ] || wm_die "Could not read a selection."

case "$kind" in
  local|remote) set -- workmux add "$key" ;;
  pr)           set -- workmux add --pr "${key#\#}" ;;
  *)            wm_die "Unrecognised row kind '$kind'." ;;
esac

echo "$*"
if ! "$@"; then
  wm_hold "'$*' failed."
  exit 1
fi

