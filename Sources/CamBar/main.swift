import Cocoa
import AVKit

/// Menu-bar app that shows a camera HLS stream in a popover.
/// Stream URL can be overridden with the CAM_BAR_URL environment variable.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var player: AVPlayer?

    private lazy var streamURL: URL = {
        let fallback = "http://127.0.0.1:1984/api/stream.m3u8?src=c200h264"
        let raw = ProcessInfo.processInfo.environment["CAM_BAR_URL"]
            ?? UserDefaults.standard.string(forKey: "streamURL")
            ?? fallback
        return URL(string: raw) ?? URL(string: fallback)!
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Camera")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        let width: CGFloat = 720
        let height: CGFloat = 440
        let footer: CGFloat = 40

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let playerView = AVPlayerView(frame: NSRect(x: 0, y: footer, width: width, height: height - footer))
        playerView.autoresizingMask = [.width, .height]
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspect
        let p = AVPlayer(url: streamURL)
        p.isMuted = true
        playerView.player = p
        player = p
        container.addSubview(playerView)

        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.bezelStyle = .inline
        quit.frame = NSRect(x: (width - 80) / 2, y: 8, width: 80, height: 24)
        quit.autoresizingMask = [.minXMargin, .maxXMargin, .maxYMargin]
        container.addSubview(quit)

        let vc = NSViewController()
        vc.view = container
        vc.preferredContentSize = NSSize(width: width, height: height)

        popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.contentSize = NSSize(width: width, height: height)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            player?.pause()
        } else {
            player?.play()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
