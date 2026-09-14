#!/usr/bin/env bash
# Omaplague Uninstaller

INSTALL_DIR="$HOME/.local/share/omaplague"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

echo "=== Omaplague Uninstaller ==="
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/omaplague"
rm -f "$ICON_DIR/omaplague.png"
rm -f "$DESKTOP_DIR/omaplague.desktop"
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "✅ Omaplague removed."
