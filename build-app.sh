#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="CamBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CamBar "$APP/Contents/MacOS/CamBar"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CamBar</string>
  <key>CFBundleIdentifier</key><string>local.cambar</string>
  <key>CFBundleName</key><string>CamBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
echo "Built $APP — run: open $APP"
