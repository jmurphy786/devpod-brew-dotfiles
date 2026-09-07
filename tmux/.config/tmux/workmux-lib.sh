#!/usr/bin/env bash
# Shared helpers for the ~/.config/tmux/workmux-*.sh popup scripts.
#
# Popups inherit the cwd of whatever pane you happened to be in, and inside a
# popup $TMUX_PANE is empty, so workmux cannot infer the repo or the calling
# client on its own. Everything here exists to pin those two things down
# explicitly instead of letting workmux guess.

# Popups get the tmux server's PATH, which may not include linuxbrew.
case ":$PATH:" in
  *":/home/linuxbrew/.linuxbrew/bin:"*) ;;
  *) PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;;
esac
export PATH

# Print a message and hold the popup open so the user can read it.
wm_hold() {
  echo
  echo "$*"
  echo "Press any key to close."
  read -r -n 1 -s
}

wm_die() {
  wm_hold "$*"
  exit 1
}

# wm_calling_session [hint] -> the session the popup was launched from.
#
# `display-popup -E` does NOT expand tmux formats, so a "#{session_name}"
# argument arrives literally (verified). Inside a popup $TMUX_PANE is also
# empty. But tmux still resolves the active client with no target, so ask it
# directly and treat the argument as a hint only.
wm_calling_session() {
  local hint="${1-}"
  if [ -n "$hint" ] && [ "${hint#\#\{}" = "$hint" ] \
     && tmux has-session -t "=$hint" 2>/dev/null; then
    printf '%s\n' "$hint"
    return 0
  fi
  tmux display-message -p '#{client_session}' 2>/dev/null
}

# Echo the main worktree root for a git dir, resolving worktrees to the project.
_wm_toplevel() {
  local dir="$1" common
  git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || return 1
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  dirname "$common"
}

# wm_repo_root <calling_session> -> absolute path of the main worktree.
wm_repo_root() {
  local session="$1" root pane project

  # 1. The popup's inherited cwd, when it happens to be inside the repo.
  root=$(_wm_toplevel "$PWD") && { _WM_ROOT="$root"; echo "$root"; return 0; }

  # 2. Any pane in the calling session that is inside a repo.
  if [ -n "$session" ]; then
    while IFS= read -r pane; do
      [ -n "$pane" ] || continue
      root=$(_wm_toplevel "$pane") && { _WM_ROOT="$root"; echo "$root"; return 0; }
    done < <(tmux list-panes -s -t "$session" -F '#{pane_current_path}' 2>/dev/null)
  fi

  # 3. Match the session name against known workmux projects.
  if [ -n "$session" ]; then
    while IFS=$'\t' read -r project root; do
      [ -n "$project" ] || continue
      case "$session" in
        *"$project"*) [ -d "$root" ] && { _WM_ROOT="$root"; echo "$root"; return 0; } ;;
      esac
    done < <(workmux list --all --json 2>/dev/null \
             | jq -r '.[] | [.project, .project_path] | @tsv' | sort -u)
  fi

  return 1
}

# wm_cd_repo_root <calling_session> -- cd there or die loudly.
wm_cd_repo_root() {
  local root
  root=$(wm_repo_root "$1") \
    || wm_die "Could not find a git repo from cwd '$PWD' or session '$1'."
  cd "$root" || wm_die "Could not cd to '$root'."
  _WM_ROOT="$root"
}

# `workmux list` only works from inside a repo. Pin it to the resolved root so
# helpers keep working even if the cwd is gone (e.g. just-removed worktree).
_WM_ROOT=

# `workmux list` costs ~700ms (it forks ~23 git and ~8 tmux processes), so cache
# the result: one popup must never pay for it twice. Call wm_list_json_reset
# after a command that changes the worktree set.
_WM_LIST_JSON=
_WM_LIST_JSON_SET=
wm_list_json() {
  [ -n "$_WM_LIST_JSON_SET" ] && { printf '%s\n' "$_WM_LIST_JSON"; return 0; }
  local root="${_WM_ROOT:-}"
  if [ -z "$root" ]; then
    root=$(wm_repo_root "${1:-$(wm_calling_session)}") || return 1
  fi
  _WM_LIST_JSON=$(cd "$root" 2>/dev/null && workmux list --json 2>/dev/null)
  _WM_LIST_JSON_SET=1
  printf '%s\n' "$_WM_LIST_JSON"
}

wm_list_json_reset() {
  _WM_LIST_JSON=
  _WM_LIST_JSON_SET=
}

# wm_main_handle -> the main worktree's handle, which is its directory name
# (`workmux open --help`: "worktree name (directory name)"). Cheaper and more
# reliable than digging it out of `workmux list --json`.
wm_main_handle() {
  local root="${_WM_ROOT:-$PWD}"
  printf '%s\n' "${root##*/}"
}

# The tmux client to act on. Inside a popup $TMUX_PANE is empty, so we cannot
# rely on tmux's notion of "current client".
wm_client() {
  tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1
}

# Read the `window_prefix` scalar out of the workmux config, repo first.
_wm_config_window_prefix() {
  local f v
  for f in "${_WM_ROOT:-$PWD}/.workmux.yaml" "$HOME/.config/workmux/config.yaml"; do
    [ -f "$f" ] || continue
    v=$(sed -n 's/^window_prefix:[[:space:]]*//p' "$f" | head -n 1)
    [ -n "$v" ] || continue
    case "$v" in
      \"*\") v=${v#\"}; v=${v%\"} ;;
      \'*\') v=${v#\'}; v=${v%\'} ;;
    esac
    printf '%s' "$v"
    return 0
  done
  return 1
}

# workmux names its tmux targets "<window_prefix><handle>", where window_prefix
# is the config value (here "{project} <glyph> ") with {project} substituted.
# Read it from the config rather than from `workmux list`, which costs ~700ms
# and only works while the main session happens to be alive. Exact
# "<prefix><handle>" matching then avoids false hits (handle "apps" must not
# match session "... portalsv2-frontend-web-apps").
_WM_PREFIX=
_WM_PREFIX_SET=
_wm_prefix() {
  [ -n "$_WM_PREFIX_SET" ] && { printf '%s' "$_WM_PREFIX"; return 0; }
  _WM_PREFIX_SET=1
  local main_handle p s
  main_handle=$(wm_main_handle)
  if p=$(_wm_config_window_prefix); then
    p=${p//\{project\}/$main_handle}
    # A placeholder we do not understand means we cannot trust the result.
    case "$p" in *'{'*) p= ;; esac
  else
    p=
  fi
  if [ -z "$p" ]; then
    # Fall back to whatever precedes the main handle in its own session name.
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      if [ "${s%"$main_handle"}" != "$s" ]; then
        p="${s%"$main_handle"}"
        break
      fi
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
  fi
  _WM_PREFIX="$p"
  printf '%s' "$_WM_PREFIX"
}

# _wm_name_matches_handle <tmux name> <handle>
_wm_name_matches_handle() {
  local name="$1" handle="$2" prefix
  [ -n "$handle" ] || return 1
  [ "$name" = "$handle" ] && return 0
  prefix=$(_wm_prefix)
  [ -n "$prefix" ] && [ "$name" = "${prefix}${handle}" ] && return 0
  return 1
}

# wm_session_for_handle <handle> -> session name, if one exists.
wm_session_for_handle() {
  local handle="$1" s
  [ -n "$handle" ] || return 1
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    if _wm_name_matches_handle "$s" "$handle"; then
      printf '%s\n' "$s"
      return 0
    fi
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
  return 1
}

# The session belonging to the main worktree, used as a safe landing spot.
wm_main_session() {
  local main_handle
  main_handle=$(wm_main_handle)
  [ -n "$main_handle" ] || return 1
  wm_session_for_handle "$main_handle" | head -n 1
}

# wm_leave_target_session <handle> <calling_session>
# If we are standing in the session (or window) about to be destroyed, move the
# client to the main project session first so tmux is never left without a
# target to switch to.
wm_leave_target_session() {
  local handle="$1" calling="$2" target main client
  target=$(wm_session_for_handle "$handle" | head -n 1)
  client=$(wm_client)
  [ -n "$client" ] || return 0

  if [ -n "$target" ] && [ "$target" = "$calling" ]; then
    main=$(wm_main_session)
    if [ -n "$main" ] && [ "$main" != "$target" ]; then
      tmux switch-client -c "$client" -t "$main" 2>/dev/null
      return 0
    fi
  fi

  # Window mode: the worktree is a window inside the calling session. Move off
  # it so the window being killed is not the active one.
  local cur w
  if [ -n "$calling" ]; then
    cur=$(tmux display-message -p -t "$calling" '#{window_name}' 2>/dev/null)
    if [ -n "$cur" ] && _wm_name_matches_handle "$cur" "$handle"; then
      while IFS= read -r w; do
        [ -n "$w" ] || continue
        if [ "$w" != "$cur" ]; then
          tmux select-window -t "$calling:$w" 2>/dev/null
          break
        fi
      done < <(tmux list-windows -t "$calling" -F '#{window_name}' 2>/dev/null)
    fi
  fi
  return 0
}

# wm_land_safely <calling_session> -- after a destructive command, make sure the
# client is attached to something that still exists.
wm_land_safely() {
  local calling="$1" main client
  client=$(wm_client)
  [ -n "$client" ] || return 0
  [ -n "$calling" ] && tmux has-session -t "$calling" 2>/dev/null && return 0
  main=$(wm_main_session)
  [ -n "$main" ] && tmux switch-client -c "$client" -t "$main" 2>/dev/null
  return 0
}

# wm_rows <include_main> -- TSV rows for the fzf pickers:
#   handle \t dirty(* or blank) \t live|closed \t branch \t mode \t path
#
# Everything here comes straight from git and tmux (~15ms) instead of from
# `workmux list --json` (~700ms), which computes far more than the picker needs.
# Sources: paths/branches from `git worktree list --porcelain`, the handle from
# the worktree's directory name, the mode from the `workmux.worktree.*.mode`
# git config keys workmux writes, dirtiness from `git status --porcelain`
# (untracked included -- that is what workmux's has_uncommitted_changes counts),
# and liveness from the tmux session/window names.
wm_rows() {
  local include_main="${1:-false}" main_handle prefix
  main_handle=$(wm_main_handle)
  prefix=$(_wm_prefix)

  local -A modes=() live=()
  local key val name
  while read -r key val; do
    key=${key#workmux.worktree.}
    modes["${key%.mode}"]="$val"
  done < <(git config --get-regexp '^workmux\.worktree\..*\.mode$' 2>/dev/null)
  while IFS= read -r name; do
    [ -n "$name" ] && live["$name"]=1
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null
           tmux list-windows -a -F '#{window_name}' 2>/dev/null)

  local path= branch= handle mode dirty state main_row= n=0
  local -a rest=()

  _wm_emit_row() {
    [ -n "$path" ] || return 0
    handle=${path##*/}
    [ -n "$branch" ] || branch='(detached)'
    mode=${modes[$handle]:-${modes[$branch]:-session}}
    dirty=' '
    [ -n "$(git -C "$path" status --porcelain 2>/dev/null | head -c 1)" ] && dirty='*'
    state=closed
    if [ -n "${live[$handle]:-}" ] || [ -n "${live[${prefix}${handle}]:-}" ]; then
      state=live
    fi
    # n counts parsed records, not printed ones: a repo whose only worktree is
    # the main one is a successful empty listing, not a parse failure.
    n=$((n + 1))
    if [ "$handle" = "$main_handle" ]; then
      [ "$include_main" = true ] || { path=; branch=; return 0; }
      main_row=$(printf '%s\t%s\t%s\t%s\t%s\t%s' \
                        "$handle" "$dirty" "$state" "$branch" "$mode" "$path")
    else
      rest+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' \
                       "$handle" "$dirty" "$state" "$branch" "$mode" "$path")")
    fi
    path=; branch=
  }

  while IFS= read -r name; do
    case "$name" in
      'worktree '*) _wm_emit_row; path=${name#worktree } ;;
      'branch refs/heads/'*) branch=${name#branch refs/heads/} ;;
      'branch '*) branch=${name#branch } ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  _wm_emit_row
  unset -f _wm_emit_row

  [ "$n" -gt 0 ] || return 1
  [ -n "$main_row" ] && printf '%s\n' "$main_row"
  [ "${#rest[@]}" -gt 0 ] && printf '%s\n' "${rest[@]}" | sort
  return 0
}

# The slow but authoritative version, kept as a fallback for when git output
# cannot be parsed. Same columns, minus liveness detail (workmux's is_open).
wm_rows_slow() {
  local include_main="${1:-false}"
  wm_list_json | jq -r --argjson main "$include_main" '
    .[] | select($main or (.is_main | not))
    | [ .handle,
        (if .has_uncommitted_changes then "*" else " " end),
        (if .is_open then "live" else "closed" end),
        .branch,
        .mode,
        .path ] | @tsv'
}

