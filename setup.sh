#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="$HOME/.local/state/setup-complete"

if [[ -f "$MARKER" ]]; then
    echo "✔ Setup already ran on $(cat "$MARKER"). Skipping."
    exit 0
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "Installing Homebrew packages..."
PACKAGES=(
    stow zoxide herdr tmux raine/workmux/workmux tuicr
    lazydocker starship claude-code opencode ripgrep resvg
    yazi fzf lazygit
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

cd "$SCRIPT_DIR"
stow --target="$HOME" */

mkdir -p "$(dirname "$MARKER")"
date > "$MARKER"
echo "Done!"
