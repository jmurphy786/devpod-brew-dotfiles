#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "Installing Homebrew packages..."
PACKAGES=(
    stow zoxide tmux raine/workmux/workmux tuicr
    lazydocker starship claude-code ripgrep resvg file
    yazi fzf lazygit wl-clipboard
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
stow --target="$HOME" */

echo "Done!"
