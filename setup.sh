#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "?? Installing Homebrew packages..."

PACKAGES=(
    nvim
    stow
    zoxide
    yazi
    imagemagick
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

echo "?? Stowing dotfiles..."

cd "$SCRIPT_DIR"

rm -f ~/.bashrc

stow */

echo "? Done!"
