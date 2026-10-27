#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_PATH="$HOME/Applications/GHBar.app"
LEGACY_PLIST="$HOME/Library/LaunchAgents/com.ghbar.app.plist"
LEGACY_BINARY="/usr/local/bin/ghbar"

echo "Building GHBar.app..."
./scripts/bundle.sh >/dev/null

# Migrate from the old LaunchAgent + /usr/local/bin install
if [ -f "$LEGACY_PLIST" ]; then
  launchctl bootout "gui/$(id -u)" "$LEGACY_PLIST" 2>/dev/null || launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
  rm -f "$LEGACY_PLIST"
  echo "Removed legacy Launch Agent."
fi
if [ -f "$LEGACY_BINARY" ]; then
  echo "Removing legacy binary $LEGACY_BINARY (needs sudo)..."
  sudo rm -f "$LEGACY_BINARY"
fi

# Replace any running copy
pkill -x GHBar 2>/dev/null || true
pkill -x ghbar 2>/dev/null || true

echo "Installing to $APP_PATH..."
mkdir -p "$(dirname "$APP_PATH")"
rm -rf "$APP_PATH"
cp -R .build/GHBar.app "$APP_PATH"
open "$APP_PATH"

echo "Done. GHBar is running and will open at login (toggle it in the popover footer)."
echo "  Config:  ~/.ghbar/config.json (created on first run)"
