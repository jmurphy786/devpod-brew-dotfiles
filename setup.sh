#!/usr/bin/env bash

set -e

echo "?? Installing Homebrew packages..."

PACKAGES=(
    yazi
    fzf
    lazydocker
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

echo "? Done!"
