#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use API to avoid cloning homebrew-core
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_NO_INSTALL_FROM_API=0

# Install Homebrew if not already installed
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Try both possible brew locations
if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew not found, exiting"
    exit 1
fi

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
