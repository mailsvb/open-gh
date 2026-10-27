#!/bin/bash
set -euo pipefail

APP_PATH="$HOME/Applications/GHBar.app"
CONFIG_DIR="$HOME/.ghbar"
LEGACY_PLIST="$HOME/Library/LaunchAgents/com.ghbar.app.plist"
LEGACY_BINARY="/usr/local/bin/ghbar"

pkill -x GHBar 2>/dev/null || true

if [ -d "$APP_PATH" ]; then
  # Remove the login item while the app still exists to do it
  "$APP_PATH/Contents/MacOS/GHBar" --unregister-login-item || true
  rm -rf "$APP_PATH"
  echo "Removed $APP_PATH."
fi

# Leftovers from the old LaunchAgent-based install
if [ -f "$LEGACY_PLIST" ]; then
  launchctl bootout "gui/$(id -u)" "$LEGACY_PLIST" 2>/dev/null || launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
  rm -f "$LEGACY_PLIST"
  echo "Legacy Launch Agent removed."
fi
if [ -f "$LEGACY_BINARY" ]; then
  echo "Removing $LEGACY_BINARY (needs sudo)..."
  sudo rm -f "$LEGACY_BINARY"
fi

read -p "Remove config at $CONFIG_DIR? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$CONFIG_DIR"
  echo "Config removed."
else
  echo "Config kept."
fi

echo "Done."
