#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "Installing Homebrew packages..."
PACKAGES=(
    stow zoxide  tuicr
    lazydocker starship claude-code ripgrep resvg file
    yazi fzf lazygit wl-clipboard
    herdr
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
# archive/ holds retired configs, not a stow package -- stowing it would drop
# its children (tmux, workmux, zellij) into $HOME.
packages=()
for d in */; do
    case "$d" in
        archive/) ;;
        *) packages+=("${d%/}") ;;
    esac
done
stow --target="$HOME" "${packages[@]}"

echo "Registering herdr plugins..."
# portals-bootstrap ships in the herdr package (stowed above) and is linked, not
# installed, so edits in the repo apply live.
herdr plugin link "$HOME/.config/herdr/local-plugins/portals-bootstrap" || true
herdr plugin install kaar/nvim-herdr-navigator || true

# Lets herdr resume claude sessions (claude --resume) after a server restart.
herdr integration install claude || true

echo "Done!"
