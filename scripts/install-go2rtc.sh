#!/usr/bin/env bash
set -euo pipefail
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) ZIP="go2rtc_mac_arm64.zip" ;;
  x86_64) ZIP="go2rtc_mac_amd64.zip" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
DEST="${DEST:-$HOME/.local/bin}"
mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading go2rtc ($ARCH)…"
curl -fsSL "https://github.com/AlexxIT/go2rtc/releases/latest/download/$ZIP" -o "$TMP/go2rtc.zip"
unzip -oq "$TMP/go2rtc.zip" -d "$TMP"
install -m 0755 "$TMP/go2rtc" "$DEST/go2rtc"
echo "Installed $DEST/go2rtc"
"$DEST/go2rtc" --version 2>/dev/null | head -1 || true
case ":$PATH:" in *":$DEST:"*) ;; *) echo "Add $DEST to your PATH (e.g. export PATH=\"$DEST:\$PATH\")." ;; esac
