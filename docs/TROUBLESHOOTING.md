# Troubleshooting

## The login lists no cameras

The **region** is the Xiaomi cloud server, not your country. Try:
`sg` (Singapore) → `de` (Europe) → `in` → `us`.

Kenyan accounts are usually on **Singapore**.

## Chrome shows a blank page

Chrome cannot play raw HLS (`.m3u8`). Open `/stream.html?src=NAME` (HLS.js) or
`/webrtc.html?src=NAME` instead.

## Picture never appears

The camera likely outputs HEVC. Add:

~~~yaml
  name_h264:
    - ffmpeg:name#video=h264#audio=aac
~~~

and point CamBar at `name_h264`.

## The camera is offline in go2rtc

Cloud cameras sleep. Open the vendor app once to wake it, then reload the stream.

## The popover is a thin sliver

Rebuild (`./build-app.sh`) and relaunch. The app needs an explicit content size
in the popover.

## I leaked my token

Revoke the session in the vendor app and log in again through go2rtc. The token
lives only in `go2rtc.yaml`.
