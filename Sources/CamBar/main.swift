import Cocoa
import AVKit

/// Menu-bar app that shows a camera HLS stream in a popover.
/// Stream URL can be overridden with the CAM_BAR_URL environment variable.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var player: AVPlayer?
    private var firstRunWindow: NSWindow?

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

        showFirstRunIfNeeded()
    }

    /// Double-clicking a menu-bar-only app appears to "do nothing". The first
    /// launch explains where the app actually lives.
    private func showFirstRunIfNeeded() {
        let key = "hasLaunched"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "CamBar"
        window.isReleasedWhenClosed = false

        let text = NSTextField(wrappingLabelWithString: "CamBar is running in your menu bar — look for the camera icon at the top-right of your screen.\n\nClick it to view your camera; click it again to hide the feed.")
        text.frame = NSRect(x: 24, y: 66, width: 412, height: 96)
        text.font = NSFont.systemFont(ofSize: 14)
        text.isSelectable = false

        let gotIt = NSButton(title: "Got it", target: self, action: #selector(closeFirstRun))
        gotIt.frame = NSRect(x: 180, y: 18, width: 100, height: 30)
        gotIt.keyEquivalent = "\r"
        gotIt.bezelStyle = .rounded

        window.contentView?.addSubview(text)
        window.contentView?.addSubview(gotIt)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        firstRunWindow = window
    }

    @objc private func closeFirstRun() {
        firstRunWindow?.close()
        firstRunWindow = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
