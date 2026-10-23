#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="CamBar.app"
VERSION="${VERSION:-${1:-1.0.0}}"
VERSION="${VERSION#v}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CamBar "$APP/Contents/MacOS/CamBar"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CamBar</string>
  <key>CFBundleIdentifier</key><string>local.cambar</string>
  <key>CFBundleName</key><string>CamBar</string>
  <key>CFBundleDisplayName</key><string>CamBar</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && echo "Ad-hoc signed $APP" || true
echo "Built $APP (version ${VERSION}) — run: open $APP"
