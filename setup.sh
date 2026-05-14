#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Homebrew if not already installed
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Setup Homebrew env
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Use API to avoid cloning homebrew-core
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_INSTALL_FROM_API=0

echo "Installing Homebrew packages..."
PACKAGES=(
    stow
    zoxide
    tmux
    neovim
    npm
    yazi
    luarocks
    imagemagick
    fzf
    lazygit
)

for package in "${PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "$package already installed, skipping"
    else
        echo "Installing $package..."
        brew install "$package"
    fi
done

echo "Stowing dotfiles..."
rm -f ~/.bashrc
cd "$SCRIPT_DIR"
stow --target="$HOME" */

echo "Setting up tmux plugins..."
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

source ~/.bashrc
tmux source-file ~/.tmux.conf

echo "Done!"
