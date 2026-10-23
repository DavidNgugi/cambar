#!/usr/bin/env bash
set -euo pipefail
GO2RTC="${GO2RTC:-$HOME/.local/bin/go2rtc}"
CONFIG="${CONFIG:-$HOME/.config/go2rtc/go2rtc.yaml}"
PLIST="$HOME/Library/LaunchAgents/local.cambar.go2rtc.plist"
mkdir -p "$(dirname "$CONFIG")" "$(dirname "$PLIST")"
[ -x "$GO2RTC" ] || { echo "go2rtc not found at $GO2RTC" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "Missing $CONFIG — copy go2rtc.example.yaml and fill it in." >&2; exit 1; }
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.cambar.go2rtc</string>
  <key>ProgramArguments</key><array><string>$GO2RTC</string><string>-config</string><string>$CONFIG</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/go2rtc.log</string>
  <key>StandardErrorPath</key><string>/tmp/go2rtc.err</string>
</dict></plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Loaded $PLIST"
