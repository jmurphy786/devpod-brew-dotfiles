#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "?? Installing Homebrew packages..."
PACKAGES=(
    stow
    posting
    zoxide
    zellij
    lazydocker
    starship
    opencode
    ripgrep
    resvg
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

mkdir -p ~/.local/bin
# Create an on-demand desktop launcher
cat > ~/.local/bin/start-desktop << 'EOF'
#!/bin/bash
echo "Starting desktop on port 6080..."

# Start the VNC + noVNC stack (same as desktop-lite's own init)
/usr/local/share/desktop-init.sh &

echo ""
echo "Desktop ready → http://localhost:6080"
echo "Password: vscode"
echo ""
echo "Forward the port if needed:"
echo "  VS Code: Ports panel → Add Port 6080"
echo "  CLI:     ssh -L 6080:localhost:6080 ..."
EOF

chmod +x ~/.local/bin/start-desktop

echo "? Done!"
