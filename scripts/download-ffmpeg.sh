#!/usr/bin/env bash
set -euo pipefail

# Pinned static builds. The release workflow currently produces an arm64 app;
# keeping the URL and checksum here makes the bundled dependency reproducible.
FFMPEG_VERSION="${FFMPEG_VERSION:-1792426763_N-127654-g7045cc9b80}"
DEST="${1:?usage: download-ffmpeg.sh DESTINATION}"
ARCH="$(uname -m)"

case "$ARCH" in
  arm64)
    URL="https://ffmpeg.martin-riedl.de/download/macos/arm64/${FFMPEG_VERSION}/ffmpeg.zip"
    SHA256="ff27344001daa202f2b4fc0d0c822f31222165687da4053dd9d6b0e6035fe939"
    ;;
  x86_64)
    URL="https://ffmpeg.martin-riedl.de/download/macos/amd64/1767299902_N-122320-g38e89fe502/ffmpeg.zip"
    SHA256="6f0736d424b7426f8cbb7bba5c5448d94c976c138c669593b1f40ba534ed192f"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/ffmpeg.zip"
printf '%s  %s\n' "$SHA256" "$TMP/ffmpeg.zip" | shasum -a 256 -c -
unzip -q "$TMP/ffmpeg.zip" -d "$TMP/unpacked"
install -m 0755 "$TMP/unpacked/ffmpeg" "$DEST"
echo "Bundled FFmpeg $("$DEST" -version | head -1)"
