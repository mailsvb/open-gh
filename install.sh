#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="ghbar"
PLIST_NAME="com.ghbar.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo "Building GHBar..."
swift build -c release --quiet

echo "Installing to $INSTALL_DIR/$BINARY_NAME..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -f .build/release/GHBar "$INSTALL_DIR/$BINARY_NAME"

# Install Launch Agent (start on login)
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALL_DIR/$BINARY_NAME</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
EOF

# Load the agent (starts it now + on future logins)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Done. GHBar is running and will start automatically on login."
echo "  Config:  ~/.ghbar/config.json (created on first run)"
echo "  Stop:    launchctl unload $PLIST_PATH"
echo "  Restart: launchctl unload $PLIST_PATH && launchctl load $PLIST_PATH"
