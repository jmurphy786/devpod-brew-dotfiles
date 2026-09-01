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

eval "$(starship init bash)"
export TERM=xterm-256color

[ -f ~/.secrets ] && source ~/.secrets
[ -f ~/.bashrc.host ] && source ~/.bashrc.host

wt-fzf() {
  local wt_json main_root current_branch existing worktree_branches new_candidates fzf_list
  local selection action branch slug wt_path result err

  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Not inside a git repository" >&2
    return 1
  }

  wt_json=$(herdr worktree list 2>/dev/null)
  main_root=$(echo "$wt_json" | jq -r '.result.source.repo_root // empty')

  if [ -z "$main_root" ]; then
    echo "Could not resolve repo root via 'herdr worktree list' — got:" >&2
    echo "$wt_json" >&2
    read -rp "Press enter to close..." _
    return 1
  fi

  current_branch=$(git -C "$main_root" rev-parse --abbrev-ref HEAD 2>/dev/null)

  existing=$(echo "$wt_json" | jq -r '
    .result.worktrees[]
    | select(.is_linked_worktree == true)
    | "open\t\(.branch)\t\(.path)"
  ')

  worktree_branches=$(echo "$wt_json" | jq -r '.result.worktrees[].branch')
  new_candidates=$(git -C "$main_root" branch --format='%(refname:short)' \
    | grep -vFx "$current_branch" \
    | grep -vFxf <(echo "$worktree_branches") \
    | while IFS= read -r b; do printf 'new\t%s\t\n' "$b"; done)

  fzf_list=$(printf '%s\n%s\n' "$existing" "$new_candidates" | grep -v '^\s*$')

  selection=$(printf '%s' "$fzf_list" \
    | awk -F'\t' '{printf "%-6s %-40s %s\n", $1, $2, $3}' \
    | fzf --prompt="Worktree > " \
          --header="enter: open/create   type a name for a brand-new branch" \
          --print-query \
    | tail -n1)

  action=$(echo "$selection" | awk '{print $1}')
  branch=$(echo "$selection" | awk '{print $2}')

  [ -z "$branch" ] && { echo "No selection" >&2; return 0; }

  if [ "$action" = "open" ]; then
    result=$(herdr worktree open --cwd "$main_root" --branch "$branch" --focus 2>&1)
  else
    slug="${branch//\//-}"
    wt_path="$main_root/.worktrees/$slug"
    result=$(herdr worktree create --cwd "$main_root" --branch "$branch" --path "$wt_path" --focus 2>&1)
  fi

  err=$(echo "$result" | jq -r '.error.message // empty' 2>/dev/null)
  if [ -n "$err" ]; then
    echo "herdr error: $err" >&2
    echo "$result" >&2
    read -rp "Press enter to close..." _
    return 1
  fi
}

wt-fzf-remove() {
  local wt_json main_root list selection branch path open_id workspace_id result err confirm

  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Not inside a git repository" >&2
    return 1
  }

  wt_json=$(herdr worktree list 2>/dev/null)
  main_root=$(echo "$wt_json" | jq -r '.result.source.repo_root // empty')

  if [ -z "$main_root" ]; then
    echo "Could not resolve repo root via 'herdr worktree list'" >&2
    read -rp "Press enter to close..." _
    return 1
  fi

  list=$(echo "$wt_json" | jq -r '
    .result.worktrees[]
    | select(.is_linked_worktree == true)
    | "\(.branch)\t\(.path)\t\(.open_workspace_id // "")"
  ')

  if [ -z "$list" ]; then
    echo "No worktrees to remove." >&2
    read -rp "Press enter to close..." _
    return 0
  fi

  selection=$(printf '%s' "$list" \
    | awk -F'\t' '{status = ($3=="") ? "closed" : "open"; printf "%-40s %-8s %s\n", $1, status, $2}' \
    | fzf --prompt="Remove worktree > " --header="enter: remove selected worktree")

  [ -z "$selection" ] && { echo "No selection" >&2; return 0; }

  branch=$(echo "$selection" | awk '{print $1}')
  path=$(echo "$list" | awk -F'\t' -v b="$branch" '$1 == b {print $2}')
  open_id=$(echo "$list" | awk -F'\t' -v b="$branch" '$1 == b {print $3}')

  read -rp "Remove worktree for '$branch' at $path? [y/N] " confirm
  case "$confirm" in
    y|Y) ;;
    *) echo "Cancelled" >&2; return 0 ;;
  esac

  # worktree remove needs an open workspace ID; if it's currently closed, open it
  # (without focus) first, just to obtain the ID.
  workspace_id="$open_id"
  if [ -z "$workspace_id" ]; then
    result=$(herdr worktree open --cwd "$main_root" --branch "$branch" --no-focus 2>&1)
    workspace_id=$(echo "$result" | jq -r '.result.workspace.workspace_id // .result.workspace_id // empty' 2>/dev/null)
    if [ -z "$workspace_id" ]; then
      echo "Could not resolve a workspace for '$branch':" >&2
      echo "$result" >&2
      read -rp "Press enter to close..." _
      return 1
    fi
  fi

  result=$(herdr worktree remove --workspace "$workspace_id" --force 2>&1)
  err=$(echo "$result" | jq -r '.error.message // empty' 2>/dev/null)
  if [ -n "$err" ]; then
    echo "herdr error: $err" >&2
    echo "$result" >&2
    read -rp "Press enter to close..." _
    return 1
  fi

  echo "Removed worktree '$branch'."
  read -rp "Press enter to close..." _
}

