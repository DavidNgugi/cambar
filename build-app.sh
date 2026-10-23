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
mkdir -p "$APP/Contents/Resources"
cp scripts/install-go2rtc.sh scripts/install-launchd.sh go2rtc.example.yaml "$APP/Contents/Resources/"
chmod +x "$APP/Contents/Resources/install-go2rtc.sh" "$APP/Contents/Resources/install-launchd.sh"
./scripts/download-ffmpeg.sh "$APP/Contents/Resources/ffmpeg"
cp docs/THIRD-PARTY-NOTICES.md "$APP/Contents/Resources/"

# Build the app icon from the source artwork for Finder, Launchpad, and the Dock.
ICONSET="$APP/Contents/Resources/CamBar.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" docs/cambar-icon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" docs/cambar-icon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/CamBar.icns"
rm -rf "$ICONSET"
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
  <key>CFBundleIconFile</key><string>CamBar</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP/Contents/MacOS/CamBar"
  codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
  codesign --display --verbose=4 "$APP/Contents/MacOS/CamBar" 2>&1 | grep -E '^(Executable|Identifier|Format|CodeDirectory|TeamIdentifier|Authority|Timestamp)='
  codesign --verify --deep --strict "$APP"
  echo "Signed $APP with ${CODESIGN_IDENTITY}"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && echo "Ad-hoc signed $APP" || true
fi
echo "Built $APP (version ${VERSION}) — run: open $APP"
