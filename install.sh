#!/usr/bin/env bash
# Omaplague Install Script
# Installs the game binary and registers it as a system app

set -e

INSTALL_DIR="$HOME/.local/share/omaplague"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Omaplague Installer ==="
echo ""

# Check binary exists
if [ ! -f "$SCRIPT_DIR/omaplague.x86_64" ]; then
  echo "ERROR: omaplague.x86_64 not found next to this script."
  echo "Download a release from https://github.com/tonythesuperpony/omaplague/releases"
  exit 1
fi

echo "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DESKTOP_DIR"

# Copy binary (PCK is embedded, so just the one file)
cp "$SCRIPT_DIR/omaplague.x86_64" "$INSTALL_DIR/omaplague.x86_64"
chmod +x "$INSTALL_DIR/omaplague.x86_64"

# Copy icon
cp "$SCRIPT_DIR/icon.png" "$ICON_DIR/omaplague.png"

# Create launcher wrapper in ~/.local/bin
cat > "$BIN_DIR/omaplague" << 'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/share/omaplague/omaplague.x86_64" "$@"
EOF
chmod +x "$BIN_DIR/omaplague"

# Create .desktop entry
cat > "$DESKTOP_DIR/omaplague.desktop" << EOF
[Desktop Entry]
Name=Omaplague
GenericName=Strategy Game
Comment=Infect. Evolve. Dominate. A global pandemic strategy game by Tony the Pony.
Exec=$INSTALL_DIR/omaplague.x86_64
Icon=omaplague
Terminal=false
Type=Application
Categories=Game;StrategyGame;
Keywords=plague;pandemic;strategy;infection;
StartupWNotify=true
EOF

# Update icon cache
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "✅ Omaplague installed!"
echo "   Binary : $INSTALL_DIR/omaplague.x86_64"
echo "   Launcher: $DESKTOP_DIR/omaplague.desktop"
echo "   Command : omaplague"
echo ""
echo "It should now appear in your app launcher."
echo "You may need to log out and back in if it doesn't show immediately."
