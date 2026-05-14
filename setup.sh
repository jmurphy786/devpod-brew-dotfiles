#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "?? Installing Homebrew packages..."
PACKAGES=(
    stow
    zoxide
    tmux
    neovim
    resvg
    npm
    yazi
    fzf
    lazygit
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

echo "?? Stowing dotfiles..."
cd "$SCRIPT_DIR"
stow --target="$HOME" */

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
echo "? Done!"
