# ~/.bashrc

# ============================================================================
# CORE CONFIGURATION (Always loaded)
# ============================================================================

# Locale -- must be UTF-8 or tmux drops to non-UTF-8 mode and mangles
# multi-byte glyphs (Nerd Font icons in nvim, box-drawing chars, etc.).
# Dev containers bypass PAM, so /etc/default/locale is never applied.
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# tmux fixes a client's UTF-8 mode at attach time from LC_ALL/LC_CTYPE/LANG.
# `-u` forces UTF-8 output regardless, so a locale-less `docker exec` attach
# can't strip Nerd Font glyphs into blank cells.
# Bare `tmux` bootstraps the project's master workmux session (see
# ~/.config/tmux/tmux-bootstrap.sh). Anything with arguments, or a call from
# inside tmux, goes straight to real tmux. A function, not an alias, because
# the two cannot coexist under one name -- the alias would always win.
tmux() {
  if [ $# -eq 0 ] && [ -z "${TMUX-}" ] && [ -x "$HOME/.config/tmux/tmux-bootstrap.sh" ]; then
    "$HOME/.config/tmux/tmux-bootstrap.sh"
  else
    command tmux -u "$@"
  fi
}

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

# Android SDK — the devcontainer feature bakes a PATH with an unresolved
# $ANDROID_HOME, and remoteEnv doesn't reach tmux-spawned shells.
[ -n "$ANDROID_HOME" ] && export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

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

eval "$(starship init bash)"
export TERM=xterm-256color

[ -f ~/.secrets ] && source ~/.secrets
[ -f ~/.bashrc.host ] && source ~/.bashrc.host






