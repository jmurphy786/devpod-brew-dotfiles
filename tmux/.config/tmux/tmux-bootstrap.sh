#!/usr/bin/env bash
# Bare `tmux` -> land straight in the project's master workmux session.
#
# Without this, `tmux` opens a shell in $HOME (session "0") and getting to work
# means: cd into the repo, then `workmux open <repo>` for the .workmux.yaml
# window layout. This does both, creates the master session only if it is
# missing, and attaches to it otherwise (`new-session -A` semantics).
#
# Usage: tmux-bootstrap.sh [--print-root]
#   --print-root  resolve the repo root, print it, and exit (for debugging)
#
# Called from the `tmux` shell function in ~/.bashrc for the no-argument case.
set -uo pipefail
source "${BASH_SOURCE%/*}/workmux-lib.sh"

# Placeholder session, only used to give `workmux open` a server to talk to when
# none is running. Killed again before we attach.
BOOTSTRAP_SESSION=wm-bootstrap

# Hand control to plain tmux, so a failed inference never leaves you shell-less.
wm_fallback_tmux() {
  [ -n "$*" ] && echo "tmux-bootstrap: $*" >&2
  exec tmux -u
}

# _wm_git_root <dir> -> the dir's MAIN worktree root, or nothing.
# `_wm_toplevel` resolves .worktrees/* back to the project, which is what we
# want: bare tmux from inside a worktree should still land on master.
_wm_git_root() {
  local dir="$1" root
  [ -d "$dir" ] || return 1
  root=$(_wm_toplevel "$dir" 2>/dev/null) || return 1
  [ -n "$root" ] && [ -d "$root" ] && printf '%s\n' "$root"
}

# Mount points of every bind mount, decoding the octal escapes mountinfo uses
# for spaces/tabs/newlines. Field 5 is the in-container path, which is what we
# want -- it is correct whether or not the devcontainer binds source==target.
_wm_mount_points() {
  [ -r /proc/self/mountinfo ] || return 1
  awk '{print $5}' /proc/self/mountinfo 2>/dev/null | while IFS= read -r p; do
    printf '%b\n' "${p//\\/\\0}"
  done
}

# The devcontainer's workspace folder: a bind-mounted git repo outside $HOME.
# The $HOME test drops the .ssh/.claude/.claude.json mounts. Candidates are
# ranked so the workspace wins over any incidental repo mount.
_wm_workspace_root() {
  local p root best_id= best_wm= best_dc= first=
  while IFS= read -r p; do
    case "$p" in
      "$HOME"|"$HOME"/*) continue ;;
      /) continue ;;
    esac
    root=$(_wm_git_root "$p") || continue
    [ -n "$first" ] || first="$root"
    if [ -n "${DEVPOD_WORKSPACE_ID-}" ] && [ "${root##*/}" = "$DEVPOD_WORKSPACE_ID" ]; then
      best_id="$root"
      break
    fi
    [ -z "$best_wm" ] && [ -f "$root/.workmux.yaml" ] && best_wm="$root"
    [ -z "$best_dc" ] && { [ -f "$root/.devcontainer.json" ] || [ -d "$root/.devcontainer" ]; } \
      && best_dc="$root"
  done < <(_wm_mount_points)

  for root in "$best_id" "$best_wm" "$best_dc" "$first"; do
    [ -n "$root" ] && { printf '%s\n' "$root"; return 0; }
  done
  return 1
}

# Last resort before giving up: ask workmux which projects it knows about.
_wm_known_project_root() {
  local json rows root
  command -v workmux >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  json=$(workmux list --all --json 2>/dev/null) || return 1
  [ -n "$json" ] || return 1

  if [ -n "${DEVPOD_WORKSPACE_ID-}" ]; then
    root=$(printf '%s' "$json" \
           | jq -r --arg p "$DEVPOD_WORKSPACE_ID" \
               'first(.[] | select(.project == $p) | .project_path) // empty' 2>/dev/null)
    [ -n "$root" ] && [ -d "$root" ] && { printf '%s\n' "$root"; return 0; }
  fi

  # Only trust an unqualified answer when there is exactly one project.
  rows=$(printf '%s' "$json" | jq -r '.[].project_path' 2>/dev/null | sort -u)
  [ "$(printf '%s\n' "$rows" | grep -c .)" = 1 ] || return 1
  [ -d "$rows" ] && printf '%s\n' "$rows"
}

# Nothing is hardcoded: cwd, then the devcontainer mount, then workmux's state.
wm_resolve_root() {
  _wm_git_root "$PWD" && return 0
  _wm_workspace_root && return 0
  _wm_known_project_root && return 0
  return 1
}

root=$(wm_resolve_root) || wm_fallback_tmux "could not infer a repo root from cwd, mounts or workmux."

if [ "${1-}" = "--print-root" ]; then
  printf '%s\n' "$root"
  exit 0
fi

cd "$root" || wm_fallback_tmux "could not cd to '$root'."
# workmux-lib helpers read _WM_ROOT rather than guessing.
_WM_ROOT="$root"

handle=$(wm_main_handle)
[ -n "$handle" ] || wm_fallback_tmux "could not determine the worktree handle for '$root'."

# Attach to (or switch to) a session that is already there.
wm_attach() {
  local target="$1"
  if [ -n "${TMUX-}" ]; then
    tmux switch-client -t "=$target"
  else
    # `=` forces exact matching: the session name has spaces and a nerd glyph.
    tmux -u attach-session -t "=$target"
  fi
}

session=$(wm_session_for_handle "$handle" | head -n 1)
if [ -n "$session" ]; then
  wm_attach "$session"
  exit $?
fi

# `workmux open` needs a server to create the session in.
started_placeholder=
if ! tmux has-session 2>/dev/null; then
  tmux -u new-session -d -s "$BOOTSTRAP_SESSION" -c "$root" 2>/dev/null \
    && started_placeholder=1
fi

workmux open "$handle"
status=$?

session=$(wm_session_for_handle "$handle" | head -n 1)

# Drop the placeholder once the real session exists, so no stray session is left
# behind (this is what replaces today's leftover session "0").
if [ -n "$started_placeholder" ] && [ -n "$session" ] \
   && [ "$session" != "$BOOTSTRAP_SESSION" ]; then
  tmux kill-session -t "=$BOOTSTRAP_SESSION" 2>/dev/null
fi

if [ -z "$session" ]; then
  echo "tmux-bootstrap: 'workmux open $handle' did not produce a session (exit $status)." >&2
  # Better a plain session than no shell at all.
  if [ -n "$started_placeholder" ]; then
    wm_attach "$BOOTSTRAP_SESSION"
    exit $?
  fi
  wm_fallback_tmux
fi

wm_attach "$session"

