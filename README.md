# CamBar

> **Your camera, one click away in the macOS menu bar.**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

![CamBar](docs/menubar.svg)

CamBar is a tiny native macOS menu-bar app that shows a live camera stream in a
popover. It was built for **cloud-only cameras** — Xiaomi/IMILAB and friends that
never expose RTSP/ONVIF locally — by bridging them through
[go2rtc](https://github.com/AlexxIT/go2rtc) and transcoding to H.264/AAC.

No browser tabs, no Dock icon, no Mi Home app. Click the camera icon, watch the
feed, click again to hide it.

## Download

Grab the latest **`CamBar-<version>.dmg`** from
[Releases](../../releases), open it, drag **CamBar** to Applications, then add it
to **System Settings → General → Login Items**. (You still need go2rtc running —
see [Full setup](#full-setup).)

Releases are built and packaged by GitHub Actions on every `v*` tag.

> **First launch (Gatekeeper).** CamBar is **ad-hoc signed**, not notarized. If
> macOS blocks it, right-click **CamBar** → **Open**, or run:
> ```bash
> xattr -dr com.apple.quarantine /Applications/CamBar.app
> ```

---

## Why I built this

I wanted my home camera **one click away** on my MacBook — not buried in a phone
app or a browser tab. Something that sits in the menu bar, always running, and
shows the feed the moment I click it. That's the whole idea: a camera that is
always one gesture away, without a browser or a phone in the way.

The camera happened to be a cloud-only Xiaomi unit with no local RTSP, so the
project also ships the go2rtc bridge that makes it playable at all.

## Why a bridge is needed

Most budget cameras (Xiaomi C200/C300, IMILAB, many Tuya devices) only speak their
vendor's cloud/P2P protocol. There is no local RTSP URL, no web UI, no ONVIF —
a standard `<video>` tag or a media player has nothing to connect to.

go2rtc solves that: it logs into the vendor cloud once, speaks the P2P protocol to
the camera, and re-serves the stream as **RTSP / HLS / WebRTC / MJPEG** on your LAN.
CamBar is the missing last mile — a native player that lives in the menu bar.

## Architecture

~~~mermaid
flowchart LR
    Cam[Cloud-only camera] -- proprietary P2P --> G[go2rtc]
    Cloud[Vendor cloud] -- auth + token --> G
    G -- H.264/AAC HLS + WebRTC + RTSP --> App[CamBar menu bar]
    G -- Web UI --> Browser[Chrome / Safari]
~~~

- **go2rtc** does the hard part (cloud login, P2P, codec conversion).
- **CamBar** is a thin AVPlayer wrapper with a status item and a popover.
- Everything runs on your Mac; the camera feed never leaves your LAN once bridged.

## Requirements

- macOS **13+** (Ventura or newer)
- Xcode / Swift toolchain (for building)
- [go2rtc](https://github.com/AlexxIT/go2rtc) — same machine or another always-on host
- A camera supported by go2rtc's Xiaomi source (C200, C300, C400, C500, Mi 360…)

## Quick start

~~~bash
git clone https://github.com/YOURNAME/cam-bar.git
cd cam-bar
./scripts/install-go2rtc.sh      # downloads go2rtc into ~/.local/bin
go2rtc                           # then open http://127.0.0.1:1984 and add your camera
./build-app.sh
open CamBar.app
~~~

## Full setup

### 1. Install go2rtc

~~~bash
./scripts/install-go2rtc.sh
~~~

This downloads the right binary for Apple Silicon or Intel into `~/.local/bin`.
You can also `brew install go2rtc` or grab a release manually.

### 2. Add your camera to go2rtc

Start go2rtc and open **http://127.0.0.1:1984**:

1. Click **Add** → **Xiaomi**.
2. Enter your Xiaomi account, password and **region**.
3. Complete 2FA if asked.
4. Pick your camera from the device list.

> **Region matters.** It is *not* your country — it is the Xiaomi cloud server
> your account lives on: `sg` (Singapore), `de` (Europe), `in`, `cn`, `us`, `ru`.
> A Kenyan account is usually on **Singapore**; if the login succeeds but lists no
> devices, try Europe.

go2rtc stores a token in its config (`~/.config/go2rtc/go2rtc.yaml`). **Never
commit that file** — it grants access to your account.

### 3. Add an H.264/AAC transcode

Many Xiaomi cameras output **HEVC (H.265)**. Chrome and most web players cannot
decode it, so add a transcoded stream next to the raw one:

~~~yaml
streams:
  c200:
    - xiaomi://ACCOUNT_ID:REGION@CAMERA_IP?did=DEVICE_ID&model=MODEL
  c200h264:
    - ffmpeg:c200#video=h264#audio=aac
~~~

Restart go2rtc. Verify:

~~~bash
ffprobe -rtsp_transport tcp rtsp://127.0.0.1:8554/c200h264
# → h264, 1920x1080, aac
~~~

### 4. Build and run CamBar

~~~bash
./build-app.sh
open CamBar.app
~~~

A **video icon** appears in the menu bar. Click it to watch the feed, click again
to hide it. Quit from the button in the popover.

### 5. Run go2rtc at login (optional, recommended)

~~~bash
cp go2rtc.example.yaml ~/.config/go2rtc/go2rtc.yaml   # fill in your values
./scripts/install-launchd.sh
~~~

This installs a LaunchAgent so go2rtc starts automatically and restarts if it
exits. CamBar can be added to **System Settings → General → Login Items**.

## Configuration

| Setting | Default | How |
| --- | --- | --- |
| Stream URL | `http://127.0.0.1:1984/api/stream.m3u8?src=c200h264` | `CAM_BAR_URL` env var or `streamURL` UserDefaults key |

~~~bash
CAM_BAR_URL="http://127.0.0.1:1984/api/stream.m3u8?src=garage" open CamBar.app
~~~

### Endpoints cheat sheet

| Consumer | URL |
| --- | --- |
| CamBar / AVPlayer / Safari | `/api/stream.m3u8?src=c200h264` |
| Chrome / Firefox | `/stream.html?src=c200h264` or `/webrtc.html?src=c200h264` |
| Snapshot (JPEG) | `/api/frame.jpeg?src=c200h264` |
| RTSP | `rtsp://HOST:8554/c200h264` |

> Chrome has **no native HLS**. The `.m3u8` URL will show a blank page there;
> use `stream.html` (HLS.js) or `webrtc.html` instead.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Login works, no devices | Wrong region | Try `sg` → `de` (or your region) |
| Blank page in Chrome | Chrome can't play raw HLS | Use `stream.html` / `webrtc.html` |
| Video spins / no picture | HEVC not decoded | Add the `ffmpeg:c200#video=h264#audio=aac` stream |
| Camera offline in go2rtc | Camera asleep / P2P-only | Wake it in the vendor app once |
| Popover is a thin sliver | App build too old | `./build-app.sh` and relaunch |
| Token leaked | Config committed | Revoke the session in the app and re-login |

## Security

- `go2rtc.yaml` contains your account token. It is gitignored here — keep it that way.
- CamBar only talks to your local go2rtc; nothing is uploaded.
- The camera stream is only as private as your LAN. Put IoT devices on a separate
  VLAN if you care about isolation.

## Repo layout

~~~
├── Sources/CamBar/main.swift   # the app
├── build-app.sh                # builds CamBar.app
├── go2rtc.example.yaml         # config template (no secrets)
├── scripts/
│   ├── install-go2rtc.sh       # fetch the right binary
│   └── install-launchd.sh      # run go2rtc at login
├── docs/
│   ├── ARCHITECTURE.md
│   └── TROUBLESHOOTING.md
└── README.md
~~~

## Contributing

Issues and PRs welcome. Keep the app dependency-free (AppKit + AVKit only) and
keep secrets out of the repo. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © CamBar contributors. go2rtc is MIT © AlexxIT.
