# CamBar

A tiny macOS menu-bar app that shows a camera stream (HLS) in a popover.

It expects a go2rtc stream over HLS, e.g. a Xiaomi/IMILAB camera bridged by
go2rtc (see the `xiaomi://` source) and transcoded to H.264:

    http://127.0.0.1:1984/api/stream.m3u8?src=c200h264

## Build & run

    ./build-app.sh
    open CamBar.app

The app has no Dock icon; it lives in the menu bar with a video icon. Click it to
open the stream, click again to close.

## Configure

The default stream URL is the go2rtc HLS URL above. Override it with:

    CAM_BAR_URL="http://host:1984/api/stream.m3u8?src=other" open CamBar.app

or set the `streamURL` UserDefaults key.

## Requirements

- macOS 13+
- A reachable HLS stream (go2rtc with `#video=h264#audio=aac` for browser/AVPlayer compatibility)
