#!/usr/bin/env bash
# Create a worktree from a local branch, a remote-only branch, an open pull
# request, or a typed new branch name.
#
# Ported from ~/.config/tmux/workmux-add-from-branch.sh and -add-branch.sh.
# herdr's own `New worktree` dialog covers neither remote branches nor PRs, and
# always puts the checkout under worktrees.directory -- outside the bind-mounted
# repo, so it would not survive a devcontainer rebuild. This one passes --path
# so checkouts land in <repo>/.worktrees/<slug>, exactly where workmux puts
# them, and the two tools keep addressing the same directories.
#
# Everything after the checkout -- symlinks, tabs, sidebar tokens -- is
# layout.sh, fired by the worktree.created event this emits.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

here=$(jm_invoking_cwd) || jm_die "Could not tell which checkout this was opened from."
common=$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
  || jm_die "'$here' is not inside a git repo."
root=${common%/.git}
cd "$root" || jm_die "Could not cd to '$root'."

# base_branch from .workmux.yaml, so a new branch starts where `workmux add`
# would start it.
base=$(sed -n 's/^base_branch:[[:space:]]*//p' .workmux.yaml 2>/dev/null | head -n 1 | tr -d "'\"")
base=${base:-master}

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
  # it is already listed above (or has a worktree).
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

# --print-query: with no row matching, Enter hands back the typed text as a new
# branch name -- the old `prefix,w -> a` picker folded into this one.
out=$(printf '%s\n' "$rows" \
      | sed '/^[[:space:]]*$/d' \
      | column -t -s $'\t' \
      | fzf --print-query --prompt 'branch> ' --height 100% --border none --no-preview \
            --header "local / remote / PR, or type a new name  ($(basename "$root"), base $base)")
query=$(printf '%s\n' "$out" | sed -n 1p)
selection=$(printf '%s\n' "$out" | sed -n 2p)

if [ -n "$selection" ]; then
  kind=$(printf '%s' "$selection" | awk '{print $1}')
  key=$(printf '%s' "$selection" | awk '{print $2}')
elif [ -n "$query" ]; then
  kind=new
  key=$query
else
  exit 0
fi
[ -n "$kind" ] && [ -n "$key" ] || jm_die "Could not read a selection."

# Resolve the row to <branch> and the ref a missing branch is created from.
upstream=
case "$kind" in
  local)
    branch=$key from= ;;
  remote)
    branch=${key#origin/} from=$key upstream=$key ;;
  pr)
    n=${key#\#}
    branch=$(gh pr view "$n" --json headRefName -q .headRefName 2>/dev/null) \
      || jm_die "gh pr view $n failed."
    [ -n "$branch" ] || jm_die "PR #$n has no head branch."
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      from=
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      from="origin/$branch" upstream="origin/$branch"
    else
      # A PR from a fork: its branch is not on origin, but GitHub publishes
      # every PR head as pull/<n>/head.
      git fetch --quiet origin "pull/$n/head:$branch" \
        || jm_die "Could not fetch pull/$n/head."
      from=
    fi
    ;;
  new)
    branch=$key
    git check-ref-format --branch "$branch" >/dev/null 2>&1 \
      || jm_die "'$branch' is not a valid branch name."
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      from=
    else
      from=$base
    fi
    ;;
  *)
    jm_die "Unrecognised row kind '$kind'." ;;
esac

# workmux's directory slug: lowercase, every non-alphanumeric run as '-'.
# PTL-699_DatePickerFix -> ptl-699-datepickerfix.
slug=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-')
path="$root/.worktrees/$slug"
[ -e "$path" ] && jm_die "'$path' already exists. Open it with the open-worktree picker instead."

# herdr checks out an existing local branch, and creates a missing one from
# --base. --cwd rather than --workspace so the new workspace groups under the
# repo's own row even when this was opened from another worktree.
set -- "$HERDR" worktree create --cwd "$root" --branch "$branch" --path "$path" --focus
[ -n "$from" ] && set -- "$@" --base "$from"
printf 'creating %s (%s%s)\n' "$path" "$branch" "${from:+ from $from}"
"$@" >/dev/null || jm_die "herdr worktree create failed for '$branch'."

# A branch herdr created from origin/<x> has no upstream, so `git pull` and
# gh-stack would not know where it came from.
if [ -n "$upstream" ]; then
  git -C "$path" branch --quiet --set-upstream-to="$upstream" \
    || jm_hold "Created, but could not set the upstream to $upstream."
fi
