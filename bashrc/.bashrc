# ~/.bashrc

# ============================================================================
# CORE CONFIGURATION (Always loaded)
# ============================================================================

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
bind -x '"\C-g": __fzf_file_widget'

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

#PROMPT_COMMAND=""

# Add Homebrew to PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export _ZO_DOCTOR=0
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

command -v zoxide &>/dev/null && eval "$(zoxide init --cmd cd bash)"

# ===========================================================================
# Scripts
# ===========================================================================

# in ~/.bashrc
function yazi() {
  FZF_DEFAULT_OPTS="" command yazi "$@"
}

# This will only work for wezterm and may need to be changed depending on the terminal emulator
export YAZI_IMAGE_PROTOCOL=sixel



# =================================================
# FZF Usage
# =================================================

# fzf
if [[ -f /usr/share/fzf/key-bindings.bash ]]; then
  source /usr/share/fzf/key-bindings.bash
  source /usr/share/fzf/completion.bash
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  source /usr/share/doc/fzf/examples/completion.bash
elif command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi


# Use fd for fzf completion (respects .fdignore)
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}
export FZF_COMPLETION_TRIGGER='**'
export FZF_DEFAULT_COMMAND='fd --type f  --hidden --follow --max-depth 4'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --max-depth 4'
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --preview "bat --style=numbers --color=always {} 2>/dev/null || cat {}"
  --bind "ctrl-/:toggle-preview"'

# fzf file/folder autocomplete with Ctrl+G
__fzf_file_widget() {
    local selected
    local current_input="${READLINE_LINE:0:$READLINE_POINT}"
    
    # Extract the path being typed (last token)
    local path_prefix=$(echo "$current_input" | grep -oE '[^ ]*$')
    
    # Determine directory to search
    local search_dir="."
    if [[ "$path_prefix" == */* ]]; then
        search_dir="${path_prefix%/*}"
        [[ -z "$search_dir" ]] && search_dir="/"
    fi
    
    # Only proceed if directory exists
    if [[ -d "$search_dir" ]]; then
        # Get files/folders, show only basenames in fzf
        selected=$(cd "$search_dir" 2>/dev/null && find . -maxdepth 1 -mindepth 1 -printf '%P\n' 2>/dev/null | \
            fzf --height=40% --reverse --prompt="Select> ")
        
        if [[ -n "$selected" ]]; then
            # Build full path
            local full_path="$search_dir/$selected"
            [[ "$search_dir" == "." ]] && full_path="$selected"
            
            # Add trailing slash for directories
            [[ -d "$full_path" ]] && full_path="$full_path/"
            
            # Replace the path prefix with the selection
            local before_path="${current_input%$path_prefix}"
            READLINE_LINE="${before_path}${full_path}"
            READLINE_POINT=${#READLINE_LINE}
        fi
    fi
}

# SSH into a devpod workspace via fzf
dpod() {
  local workspace
  workspace=$(devpod list --output plain 2>/dev/null | awk 'NR>1 {print $1}' | fzf --prompt="SSH into workspace: ")
  [ -z "$workspace" ] && return
  devpod ssh "$workspace"
}

dforward() {
  local workspace ports port_args
  devpod list --output plain &>/dev/null
  workspace=$(devpod list --output plain 2>/dev/null | awk 'NR>1 {print $1}' | fzf --prompt="Forward ports for workspace: ")
  [ -z "$workspace" ] && return

  echo "Enter ports to forward (space separated, e.g: 6080 5000 6000 7000):"
  read -r -a ports

  port_args=()
  for port in "${ports[@]}"; do
    port_args+=(--forward-ports "$port:$port")
  done

  echo "Forwarding ports: ${ports[*]}"
  echo "Ctrl+C to stop"
  devpod ssh "$workspace" "${port_args[@]}"
}

# Delete a devpod workspace via fzf
function dpod-rm() {
  local workspace
  workspace=$(devpod list --output plain 2>/dev/null | awk 'NR>1 {print $1}' | fzf --prompt="Delete workspace: ")
  if [ -n "$workspace" ]; then
    read -p "Delete '$workspace'? (y/N) " confirm
    [[ "$confirm" == [yY] ]] && devpod delete "$workspace"
  fi
}

# Shared: list zellij sessions sorted newest-first, tab-separated (sort_key <TAB> full_line)
_zj_sessions_sorted() {
  zellij list-sessions 2>/dev/null \
    | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
    | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local created secs=0
    created=$(grep -oE 'Created [0-9dhms ]+ago' <<< "$line")
    if [[ -n "$created" ]]; then
      while read -r num unit; do
        case "$unit" in
          d) ((secs+=num*86400));;
          h) ((secs+=num*3600));;
          m) ((secs+=num*60));;
          s) ((secs+=num));;
        esac
      done < <(grep -oE '[0-9]+[dhms]' <<< "$created" | sed -E 's/([0-9]+)([dhms])/\1 \2/')
    fi
    printf '%012d\t%s\n' "$secs" "$line"
  done | sort -n -k1,1 | cut -f2-
}

# zj — fzf-pick a session (newest first) and attach/resurrect it
zj() {
  local sessions selected name
  sessions=$(_zj_sessions_sorted)

  if [[ -z "$sessions" ]]; then
    echo "No zellij sessions found."
    return 1
  fi

  selected=$(fzf --height=40% --layout=reverse \
    --header='Attach to session (newest first)' <<< "$sessions")
  [[ -z "$selected" ]] && return 0

  name=$(awk '{print $1}' <<< "$selected")
  zellij attach "$name"
}

# zj-del — fzf-pick session(s) (TAB to multi-select) and delete them
zj-del() {
  local sessions selected name
  sessions=$(_zj_sessions_sorted)

  if [[ -z "$sessions" ]]; then
    echo "No zellij sessions found."
    return 1
  fi

  selected=$(fzf --multi --height=40% --layout=reverse \
    --header='Delete session(s) - TAB to multi-select' <<< "$sessions")
  [[ -z "$selected" ]] && return 0

  while IFS= read -r line; do
    name=$(awk '{print $1}' <<< "$line")
    if grep -q 'EXITED' <<< "$line"; then
      zellij delete-session "$name" && echo "Deleted exited session: $name"
    else
      zellij kill-session "$name" && zellij delete-session "$name" \
        && echo "Killed and deleted running session: $name"
    fi
  done <<< "$selected"
}

# docker-outside-of-docker resolves bind-mount sources on the HOST, and .devcontainer.json's
# remoteEnv exports HOST_PROJECT_PATH (the main checkout's host path) into every shell here. An
# exported shell var always beats a same-named value in a directory's .env file, which is what
# breaks per-worktree docker-compose mounts (see wt() below) -- so capture the original value into
# the main checkout's own .env once, then stop exporting it, letting Compose's native per-directory
# .env resolution do the rest.
if [ -n "$HOST_PROJECT_PATH" ]; then
  for _wt_root in /workspaces/*/; do
    [ -d "${_wt_root}.git" ] || continue
    if [ ! -f "${_wt_root}.env" ]; then
      echo "HOST_PROJECT_PATH=$HOST_PROJECT_PATH" > "${_wt_root}.env"
      _wt_gitdir=$(git -C "$_wt_root" rev-parse --absolute-git-dir 2>/dev/null)
      [ -n "$_wt_gitdir" ] && { grep -qxF '/.env' "$_wt_gitdir/info/exclude" 2>/dev/null \
        || echo '/.env' >> "$_wt_gitdir/info/exclude"; }
      unset _wt_gitdir
    fi
    break
  done
  unset _wt_root
  unset HOST_PROJECT_PATH
fi

# wt — create a git worktree for a branch, host-visible for docker-compose bind mounts
wt() {
  local branch main_root gitdir slug wt_path main_host_root

  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Not inside a git repository" >&2
    return 1
  }

  # Anchor on the main checkout: `git rev-parse --show-toplevel` would return the *worktree*
  # root if wt is invoked from inside one.
  main_root=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')

  branch=$(git -C "$main_root" branch --format='%(refname:short)' \
    | fzf --prompt="Select branch for worktree > " --height=40% --reverse) || return 1

  [ -z "$branch" ] && { echo "No branch selected" >&2; return 1; }

  if git -C "$main_root" worktree list --porcelain | grep -q "branch refs/heads/$branch$"; then
    echo "Branch '$branch' is already checked out in a worktree." >&2
    git -C "$main_root" worktree list | grep "\[$branch\]"
    return 1
  fi

  # Keep worktrees host-visible regardless of language/devcontainer: create them *inside* the
  # main checkout's own tree instead of herdr's default ~/.herdr/worktrees (container-only).
  # Every devcontainer bind-mounts its workspace folder from the host, so anything under
  # main_root inherits that same mount.
  slug="${branch//\//-}"
  wt_path="$main_root/.worktrees/$slug"

  herdr worktree create --cwd "$main_root" --branch "$branch" --path "$wt_path" || return 1

  gitdir=$(git -C "$main_root" rev-parse --absolute-git-dir)
  grep -qxF '/.worktrees/' "$gitdir/info/exclude" 2>/dev/null \
    || echo '/.worktrees/' >> "$gitdir/info/exclude"
  grep -qxF '/.env' "$gitdir/info/exclude" 2>/dev/null \
    || echo '/.env' >> "$gitdir/info/exclude"

  # Give this worktree its own .env pointing docker-compose (or anything else that reads
  # HOST_PROJECT_PATH) at ITS host-visible path, derived from the main checkout's own .env. This
  # works from any shell/pane whose cwd is this worktree -- no shell export to keep in sync.
  main_host_root=$(sed -n 's/^HOST_PROJECT_PATH=//p' "$main_root/.env" 2>/dev/null)
  if [ -n "$main_host_root" ]; then
    echo "HOST_PROJECT_PATH=${main_host_root}${wt_path#$main_root}" > "$wt_path/.env"
  fi

  cd "$wt_path" || return 1
}

eval "$(starship init bash)"
export TERM=xterm-256color

[ -f ~/.secrets ] && source ~/.secrets
[ -f ~/.bashrc.host ] && source ~/.bashrc.host


