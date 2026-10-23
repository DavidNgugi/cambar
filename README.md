<div align="center">

<h1><img src="docs/cambar-icon.svg" alt="" width="52" height="52" valign="middle"> CamBar</h1>

<p><b>Your camera, one click away in the macOS menu bar.</b></p>

<p>
  <a href="https://github.com/DavidNgugi/cambar/actions/workflows/build.yml"><img alt="Build" src="https://github.com/DavidNgugi/cambar/actions/workflows/build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Platform: macOS 13+" src="https://img.shields.io/badge/platform-macOS%2013%2B-black">
  <img alt="Swift 5.9" src="https://img.shields.io/badge/swift-5.9-orange">
</p>

<p>
  <a href="#installation"><b>Installation</b></a> &nbsp;·&nbsp;
  <a href="#usage"><b>Usage</b></a> &nbsp;·&nbsp;
  <a href="#how-it-works"><b>How it works</b></a> &nbsp;·&nbsp;
  <a href="#safety"><b>Safety</b></a> &nbsp;·&nbsp;
  <a href="#troubleshooting"><b>Troubleshooting</b></a> &nbsp;·&nbsp;
  <a href="CONTRIBUTING.md"><b>Contributing</b></a>
</p>

<img src="docs/menubar.svg" alt="CamBar" width="760">

</div>

---

**CamBar** is a tiny native macOS menu-bar app that shows a live camera stream in a
popover. It was built for **cloud-only cameras** — Xiaomi/IMILAB and friends that
never expose RTSP/ONVIF locally — by bridging them through
[go2rtc](https://github.com/AlexxIT/go2rtc) and transcoding to H.264/AAC.

> **Why I built this.** I wanted my home camera one click away on my MacBook — not
> buried in a phone app or a browser tab. Something that sits in the menu bar,
> always running, and shows the feed the moment I click it. That's the whole idea:
> a camera that is always one gesture away.

No browser tabs, no Dock icon, no Mi Home app. Click the camera icon, watch the
feed, click again to hide it.

## How it works

Most budget cameras (Xiaomi C200/C300, IMILAB, many Tuya devices) only speak their
vendor's cloud/P2P protocol. There is no local RTSP URL, no web UI, no ONVIF — a
standard `<video>` tag or a media player has nothing to connect to.

go2rtc solves that: it logs into the vendor cloud once, speaks the P2P protocol to
the camera, and re-serves the stream as **RTSP / HLS / WebRTC / MJPEG** on your LAN.
CamBar is the missing last mile — a native player that lives in the menu bar.

~~~mermaid
flowchart LR
    Cam[Cloud-only camera] -- proprietary P2P --> G[go2rtc]
    Cloud[Vendor cloud] -- auth + token --> G
    G -- H.264/AAC HLS + WebRTC + RTSP --> App[CamBar menu bar]
    G -- Web UI --> Browser[Chrome / Safari]
~~~

### Requirements

- macOS **13+** (Ventura or newer)
- Xcode / Swift toolchain (to build)
- [go2rtc](https://github.com/AlexxIT/go2rtc) — this Mac or another always-on host
- A camera supported by go2rtc's Xiaomi source (C200, C300, C400, C500, Mi 360…)

## Installation

### Prebuilt (recommended)

Grab the latest **`CamBar-<version>.dmg`** from
[Releases](https://github.com/DavidNgugi/cambar/releases), open it, drag **CamBar**
to **Applications**, then add it to **System Settings → General → Login Items**.
You still need go2rtc running — see below.

> **First launch (Gatekeeper).** CamBar is **ad-hoc signed**, not notarized. If
> macOS blocks it, right-click **CamBar → Open**, or run:
> ~~~bash
> xattr -dr com.apple.quarantine /Applications/CamBar.app
> ~~~

### From source

~~~bash
git clone https://github.com/DavidNgugi/cambar.git
cd cambar
./scripts/install-go2rtc.sh
go2rtc
./build-app.sh
open CamBar.app
~~~

### 1. Install go2rtc

~~~bash
./scripts/install-go2rtc.sh
~~~

Downloads the right binary for Apple Silicon or Intel into `~/.local/bin`. You can
also `brew install go2rtc` or grab a release manually.

### 2. Add your camera

Start go2rtc and open **http://127.0.0.1:1984**:

1. **Add → Xiaomi**
2. Account, password, **region**, 2FA if asked
3. Pick your camera

> **Region is the cloud server, not your country:** `sg` (Singapore), `de`
> (Europe), `in`, `cn`, `us`, `ru`. A Kenyan account is usually on **Singapore**;
> if login works but lists no devices, try Europe.

go2rtc stores the token in `~/.config/go2rtc/go2rtc.yaml`. **Never commit it.**

### 3. Add the H.264/AAC transcode

Many Xiaomi cameras output **HEVC**, which browsers and AVPlayer cannot always
decode. Add a transcoded stream next to the raw one:

~~~yaml
streams:
  c200:
    - xiaomi://ACCOUNT_ID:REGION@CAMERA_IP?did=DEVICE_ID&model=MODEL
  c200h264:
    - ffmpeg:c200#video=h264#audio=aac
~~~

Restart go2rtc and verify:

~~~bash
ffprobe -rtsp_transport tcp rtsp://127.0.0.1:8554/c200h264
# → h264, 1920x1080, aac
~~~

### 4. Run go2rtc at login (recommended)

~~~bash
cp go2rtc.example.yaml ~/.config/go2rtc/go2rtc.yaml
./scripts/install-launchd.sh
~~~

The LaunchAgent keeps go2rtc alive. Add **CamBar.app** to Login Items for the icon.

## Usage

Click the **video icon** in the menu bar to show the stream; click again to hide
it. Quit from the button in the popover.

### Configuration

| Setting | Default | How |
| --- | --- | --- |
| Stream URL | `http://127.0.0.1:1984/api/stream.m3u8?src=c200h264` | `CAM_BAR_URL` env var or `streamURL` UserDefaults |

~~~bash
CAM_BAR_URL="http://127.0.0.1:1984/api/stream.m3u8?src=garage" open CamBar.app
~~~

### Endpoints

| Consumer | URL |
| --- | --- |
| CamBar / AVPlayer / Safari | `/api/stream.m3u8?src=c200h264` |
| Chrome / Firefox | `/stream.html?src=c200h264` or `/webrtc.html?src=c200h264` |
| Snapshot (JPEG) | `/api/frame.jpeg?src=c200h264` |
| RTSP | `rtsp://HOST:8554/c200h264` |

> Chrome has **no native HLS** — the `.m3u8` URL is blank there. Use
> `stream.html` (HLS.js) or `webrtc.html`.

## Safety

- **Tokens:** `go2rtc.yaml` holds your account token. It is gitignored. Keep it that way.
- **Privacy:** CamBar talks only to your local go2rtc. Nothing is uploaded.
- **LAN:** the stream is only as private as your network. Put IoT devices on a separate VLAN if you care.
- **Gatekeeper:** ad-hoc signed, not notarized (see Installation).

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Login works, no devices | Wrong region | Try `sg` → `de` |
| Blank page in Chrome | No native HLS | `stream.html` / `webrtc.html` |
| Spins / no picture | HEVC | Add the `ffmpeg:...#video=h264#audio=aac` stream |
| Camera offline in go2rtc | Camera asleep | Wake it in the vendor app |
| Popover is a thin sliver | Old build | `./build-app.sh` and relaunch |
| Token leaked | Config committed | Revoke session, re-login |

## Contributing

Issues and PRs welcome. Keep CamBar dependency-free (AppKit + AVKit only) and keep
secrets out of the repo. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © CamBar contributors. go2rtc is MIT © AlexxIT.
