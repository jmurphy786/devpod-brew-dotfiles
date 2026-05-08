# ~/.bashrc

# ============================================================================
# CORE CONFIGURATION (Always loaded)
# ============================================================================

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# BettecopeFuzzyCommandSearch) completion
# if [ -f /etc/bash_completion ]; then
#   . /etc/bash_completion
# fi

# dedupe_path() {
#   local new_path=""
#   local -A seen
#   IFS=: read -ra parts <<< "$PATH"
#   for part in "${parts[@]}"; do
#     if [[ -z "${seen[$part]}" ]]; then
#       seen[$part]=1
#       new_path="${new_path:+$new_path:}$part"
#     fi
#   done
#   export PATH="$new_path"
# }

tmux-kill() {
  echo "Killing tmux server and cleaning nvim undo cache..."
  tmux kill-server

  # Clean up nvim undo files
  local undo_dir="$HOME/.local/state/nvim/undo"
  if [ -d "$undo_dir" ]; then
    rm -rf "$undo_dir"/*
    echo "✓ Cleared nvim undo cache: $undo_dir"
  fi

  # Alternative location (some systems use this)
  local cache_undo="$HOME/.cache/nvim/undo"
  if [ -d "$cache_undo" ]; then
    rm -rf "$cache_undo"/*
    echo "✓ Cleared nvim undo cache: $cache_undo"
  fi
}


# ============================================================================
# PATH CONFIGURATION
# ============================================================================

PROMPT_COMMAND=""

export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.tmuxifier/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
export PATH="/mnt/c/Program Files/WezTerm:$PATH"  # ✅

[ -f "$HOME/.bash_module_loader" ] && source "$HOME/.bash_module_loader"
command -v tmuxifier &>/dev/null && eval "$(tmuxifier init -)"
command -v zoxide &>/dev/null && eval "$(zoxide init --cmd cd bash)"

# Add Homebrew to PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
alias tdev='tmuxifier load-session dev'
alias tkill='tmux kill-server'

# ===========================================================================
# Scripts
# ===========================================================================

daily() {
  NOTES_DIR="$HOME/Documents/personal/routines"
  DAILY_DIR="$NOTES_DIR/daily"
  TODAY=$(date +%Y-%m-%d)
  DAILY_FILE="$DAILY_DIR/$TODAY.md"

  mkdir -p "$DAILY_DIR"

  if [ ! -f "$DAILY_FILE" ]; then
    cat > "$DAILY_FILE" << EOF
# Daily Note - $(date '+%B %d, %Y')

## Work Tasks
- [ ] 

## Gym Notes
- []

##
Personal Notes
- []

## Links
- [[$(date -d 'yesterday' +%Y-%m-%d)]] (Yesterday)
EOF
  fi

  cd "$DAILY_DIR" && nvim "$DAILY_FILE"
}

alias pdfopen='pdf=$(find ~/Documents/books -type f -name "*.pdf" | fzf) && cmd.exe /c start "" "$(wslpath -w "$pdf")"'

export CLAUDE_CONVOS_DIR="$HOME/claude-convos"
# ============================================================================
# STARTUP
# ============================================================================

#fastfetch

alias bat='batcat'

# in ~/.bashrc
function yazi() {
  FZF_DEFAULT_OPTS="" command yazi "$@"
}

# ==========================================
# Android & Java - Using Windows installations
# ==========================================

# Java - use WSL JDK (better for Gradle)
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$HOME/.local/kitty.app/bin:$PATH"
export PATH="$JAVA_HOME/bin:$PATH"
alias scrcpy='scrcpy.exe --force-adb-forward'
export DISPLAY=:0
# This will only work for wezterm and may need to be changed depending on the terminal emulator
export YAZI_IMAGE_PROTOCOL=sixel

export NVM_DIR="$HOME/.nvm"

