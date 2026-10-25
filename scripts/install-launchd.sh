#!/usr/bin/env bash
set -euo pipefail
GO2RTC="${GO2RTC:-$HOME/.local/bin/go2rtc}"
CONFIG="${CONFIG:-$HOME/.config/go2rtc/go2rtc.yaml}"
PLIST="$HOME/Library/LaunchAgents/local.cambar.go2rtc.plist"
mkdir -p "$(dirname "$CONFIG")" "$(dirname "$PLIST")"
[ -x "$GO2RTC" ] || { echo "go2rtc not found at $GO2RTC" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "Missing $CONFIG — copy go2rtc.example.yaml and fill it in." >&2; exit 1; }

# launchd does not inherit the interactive shell's PATH. Resolve FFmpeg here
# so ffmpeg:c200#video=h264#audio=aac works for Homebrew and standard installs.
FFMPEG="${FFMPEG:-}"
if [ -z "$FFMPEG" ]; then
  for candidate in /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg /usr/bin/ffmpeg; do
    if [ -x "$candidate" ]; then
      FFMPEG="$candidate"
      break
    fi
  done
fi
[ -n "$FFMPEG" ] && [ -x "$FFMPEG" ] || {
  echo "FFmpeg is required for this camera stream but was not found. Install it with Homebrew (brew install ffmpeg), then click Install & Start again." >&2
  exit 1
}

SERVICE_PATH="$(dirname "$GO2RTC"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.cambar.go2rtc</string>
  <key>ProgramArguments</key><array><string>$GO2RTC</string><string>-config</string><string>$CONFIG</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$SERVICE_PATH</string>
    <key>FFMPEG</key><string>$FFMPEG</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>/tmp/go2rtc.log</string>
  <key>StandardErrorPath</key><string>/tmp/go2rtc.err</string>
</dict></plist>
EOF

# Use the per-user launchd domain explicitly. The older load/unload commands
# can report success while leaving a stale service registration behind on
# recent macOS releases.
DOMAIN="gui/$(id -u)"
SERVICE="${DOMAIN}/local.cambar.go2rtc"
launchctl bootout "$SERVICE" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart -k "$SERVICE"
echo "Loaded $PLIST (KeepAlive enabled)"
