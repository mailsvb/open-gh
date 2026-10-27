#!/bin/bash
# Builds a release GHBar.app at .build/GHBar.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=".build/GHBar.app"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release --quiet

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GHBar "$APP/Contents/MacOS/GHBar"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.ghbar.app</string>
  <key>CFBundleName</key>
  <string>GHBar</string>
  <key>CFBundleExecutable</key>
  <string>GHBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "$APP"
