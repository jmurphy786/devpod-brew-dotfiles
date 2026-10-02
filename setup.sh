#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "Installing Homebrew packages..."
PACKAGES=(
    stow zoxide tmux raine/workmux/workmux tuicr
    lazydocker starship claude-code ripgrep resvg file
    yazi fzf lazygit wl-clipboard
    herdr worktrunk
)
for package in "${PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "V $package already installed, skipping"
    else
        echo "Installing $package..."
        brew install "$package"
    fi
done

rm -f ~/.bashrc
echo "Stowing dotfiles..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

gh extension install github/gh-stack

cd "$SCRIPT_DIR"
# herdr-plugins/ holds plugin sources linked by `herdr plugin link` below, not
# a stow package -- stowing it would drop a stray ~/portals-bootstrap symlink.
packages=()
for d in */; do
    [ "$d" = "herdr-plugins/" ] || packages+=("${d%/}")
done
stow --target="$HOME" "${packages[@]}"

# herdr plugins. These are global to the user and registered outside the
# stowed config, so a rebuilt container needs them re-registered even though
# ~/.config/herdr came back with the dotfiles.
#   portals-bootstrap  -- local: worktree picker, symlinks and
#                         the gh-stack sidebar index
#   herdr-navigator    -- from GitHub: ctrl+h/j/k/l across nvim splits and
#                         herdr panes (pairs with lua/plugins/herdr-navigator.lua)
echo "Registering herdr plugins..."
herdr plugin link "$SCRIPT_DIR/herdr-plugins/portals-bootstrap" || true
herdr plugin install kaar/nvim-herdr-navigator || true

# Lets herdr resume claude sessions (claude --resume) after a server restart.
herdr integration install claude || true

echo "Done!"
