# Architecture

~~~mermaid
sequenceDiagram
    participant App as CamBar
    participant G as go2rtc
    participant Cloud as Xiaomi cloud
    participant Cam as Camera

    App->>G: GET /api/stream.m3u8?src=c200h264
    G-->>App: HLS playlist (H.264/AAC)
    G->>Cloud: login / token (once)
    G->>Cam: P2P handshake + keys
    Cam-->>G: HEVC/Opus stream
    G-->>G: ffmpeg transcode → H.264/AAC
~~~

- **CamBar** is an AppKit `NSStatusItem` + `NSPopover` + `AVPlayerView`.
- **go2rtc** owns the camera session; CamBar only consumes a standard HLS URL.
- The transcode exists because cameras often emit HEVC, which browsers and some
  players cannot decode.
