# Shared helpers for the portals-bootstrap herdr plugin.
#
# Plugin commands run with the plugin directory as cwd and inherit the herdr
# server's PATH, which does not necessarily include linuxbrew.
case ":$PATH:" in
  *:/home/linuxbrew/.linuxbrew/bin:*) ;;
  *) PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;;
esac
export PATH

HERDR="${HERDR_BIN_PATH:-herdr}"

# jm_event <jq-filter> -- read a field out of the event payload.
#
# herdr hands event hooks HERDR_PLUGIN_EVENT_JSON. Accept both the bare
# EventData object and an {event, data} envelope so this keeps working if the
# wrapper changes.
jm_event() {
  [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ] || return 0
  printf '%s' "$HERDR_PLUGIN_EVENT_JSON" \
    | jq -r --arg f "$1" '(.data // .) | getpath($f | split(".")) // empty' 2>/dev/null
}

# jm_log <message> -- plugin command output is captured by herdr and shown by
# `herdr plugin log list --plugin jm.portals-bootstrap`; nothing reaches a pane.
jm_log() { printf '%s\n' "$*" >&2; }

# jm_stack_index <worktree-path> -- "2/3" for a worktree that owns a gh-stack
# and is sitting on layer two, empty otherwise.
#
# Ported from wm_stack_index in ~/.config/tmux/workmux-lib.sh. gh-stack keeps
# state at $(git rev-parse --git-dir)/gh-stack, which for a linked worktree is
# .git/worktrees/<name>/gh-stack -- one file per worktree that owns a stack
# (github/gh-stack#459). No `gh stack view`: that is an API round-trip.
jm_stack_index() {
  local wt="$1" gitdir branch
  [ -n "$wt" ] && [ -d "$wt" ] || return 0
  gitdir=$(git -C "$wt" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 0
  [ -f "$gitdir/gh-stack" ] || return 0
  branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null) || return 0
  jq -r --arg b "$branch" '
    .stacks[]
    | [.branches[].branch] as $bs
    | ($bs | index($b)) as $i
    | select($i != null)
    | "\($i + 1)/\($bs | length)"' "$gitdir/gh-stack" 2>/dev/null | head -1
}

# jm_report_stack <workspace-id> <worktree-path> -- publish or clear the token.
#
# No --ttl-ms: unlike a poller, this is pushed on the events that change it,
# so it must not time out in between (and the flag rejects 0 anyway --
# "metadata ttl_ms must be at least 1"). An empty index clears the token
# rather than leaving a stale one behind.
jm_report_stack() {
  local ws="$1" wt="$2" idx
  [ -n "$ws" ] || return 0
  idx=$(jm_stack_index "$wt")
  if [ -n "$idx" ]; then
    "$HERDR" workspace report-metadata "$ws" \
      --source jm-gh-stack --token "jm_stack=$idx" >/dev/null 2>&1
  else
    "$HERDR" workspace report-metadata "$ws" \
      --source jm-gh-stack --clear-token jm_stack >/dev/null 2>&1
  fi
}

# jm_report_mark <workspace-id> <worktree-path> -- the child-row glyph.
#
# herdr already indents a linked worktree under its repo's workspace; the
# marker just makes those rows read as branches of it. The main checkout gets
# no token, so its row stays plain. Same no-TTL rule as jm_report_stack.
JM_MARK="${JM_MARK:-󰘬}"
jm_report_mark() {
  local ws="$1" wt="$2" main
  [ -n "$ws" ] && [ -n "$wt" ] || return 0
  main=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  main=${main%/.git}
  if [ -n "$main" ] && [ "$main" != "$wt" ]; then
    "$HERDR" workspace report-metadata "$ws" \
      --source jm-mark --token "jm_mark=$JM_MARK" >/dev/null 2>&1
  else
    "$HERDR" workspace report-metadata "$ws" \
      --source jm-mark --clear-token jm_mark >/dev/null 2>&1
  fi
}

# jm_checkout_path <workspace-json> -- a workspace's worktree checkout, or "".
jm_checkout_path() {
  printf '%s' "$1" | jq -r '.worktree.checkout_path // empty' 2>/dev/null
}

# jm_die <message> -- print and hold, so the popup does not vanish with the
# error in it. Replaces wm_die.
jm_die() {
  printf '%s\n' "$*" >&2
  jm_hold ""
  exit 1
}

# jm_hold <message> -- wait for a keypress. herdr closes a popup the moment its
# command exits, same as a tmux popup did.
jm_hold() {
  [ -n "${1:-}" ] && printf '%s\n' "$1"
  printf '\n[any key to close] '
  read -rsn1 _ 2>/dev/null || true
  echo
}

# jm_context <jq-filter> -- read a field out of HERDR_PLUGIN_CONTEXT_JSON,
# which action and pane commands get (workspace, tab, focused pane, worktree).
jm_context() {
  [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ] || return 0
  printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" \
    | jq -r --arg f "$1" 'getpath($f | split(".")) // empty' 2>/dev/null
}

# jm_invoking_cwd -- the checkout the popup was opened over.
#
# The context herdr really sends is flat -- focused_pane_cwd, workspace_cwd --
# with no worktree block for a plain repo workspace, so those come before the
# nested keys. Without them a menu opened over a main checkout found no cwd.
#
# Plugin commands run with the *plugin directory* as cwd, not the pane's, so
# anything repo-relative has to resolve this first. A stack lives inside one
# worktree and every `gh stack` command is relative to the branch checked out
# there, which is what the tmux popup got free from -d '#{pane_current_path}'.
jm_invoking_cwd() {
  local p
  for p in \
    "$(jm_context worktree.checkout_path)" \
    "$(jm_context worktree.path)" \
    "$(jm_context workspace.worktree.checkout_path)" \
    "$(jm_context focused_pane_cwd)" \
    "$(jm_context workspace_cwd)" \
    "$(jm_context pane.cwd)"; do
    [ -n "$p" ] && [ -d "$p" ] && { printf '%s' "$p"; return 0; }
  done
  if [ -n "${HERDR_WORKSPACE_ID:-}" ]; then
    p=$("$HERDR" workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null \
      | jq -r '.result.workspace.worktree.checkout_path // empty')
    [ -n "$p" ] && [ -d "$p" ] && { printf '%s' "$p"; return 0; }
  fi
  return 1
}
