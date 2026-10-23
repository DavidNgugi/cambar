import Cocoa
import AVKit

private let defaultStreamName = "c200h264"
private let defaultGo2RTCPath = "~/.local/bin/go2rtc"
private let defaultConfigPath = "~/.config/go2rtc/go2rtc.yaml"

final class SetupWindowController: NSObject {
    var onInstall: (() -> Void)?
    var onOpenGuide: (() -> Void)?
    var onSave: ((String) -> Void)?

    private let window: NSWindow
    private let statusLabel = NSTextField(labelWithString: "")
    private let streamField = NSTextField(string: defaultStreamName)
    private let installButton = NSButton(title: "Install & Start go2rtc", target: nil, action: nil)
    private let guideButton = NSButton(title: "Open Camera Setup", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save & Open CamBar", target: nil, action: nil)

    init(initialStreamName: String) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                          styleMask: [.titled, .closable],
                          backing: .buffered,
                          defer: false)
        super.init()
        window.title = "Set up CamBar"
        window.isReleasedWhenClosed = false
        window.contentView = makeContentView()
        streamField.stringValue = initialStreamName
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    func setInstalling(_ installing: Bool) {
        installButton.isEnabled = !installing
        guideButton.isEnabled = !installing
        saveButton.isEnabled = !installing
        setStatus(installing ? "Installing and starting the background service…" : "")
    }

    private func makeContentView() -> NSView {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 360))

        let title = NSTextField(labelWithString: "Your camera, one click away")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.frame = NSRect(x: 32, y: 300, width: 496, height: 32)

        let intro = NSTextField(wrappingLabelWithString: "CamBar uses go2rtc to connect to cloud-only cameras. Install the background service, configure your camera once, then CamBar will keep the stream ready in your menu bar.")
        intro.font = .systemFont(ofSize: 14)
        intro.textColor = .secondaryLabelColor
        intro.frame = NSRect(x: 32, y: 236, width: 496, height: 52)

        let stepOne = NSTextField(labelWithString: "1  Start the background service")
        stepOne.font = .systemFont(ofSize: 14, weight: .medium)
        stepOne.frame = NSRect(x: 32, y: 198, width: 240, height: 24)

        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(install)
        installButton.frame = NSRect(x: 332, y: 194, width: 196, height: 30)

        let stepTwo = NSTextField(labelWithString: "2  Add your camera in go2rtc")
        stepTwo.font = .systemFont(ofSize: 14, weight: .medium)
        stepTwo.frame = NSRect(x: 32, y: 154, width: 260, height: 24)

        guideButton.bezelStyle = .rounded
        guideButton.target = self
        guideButton.action = #selector(openGuide)
        guideButton.frame = NSRect(x: 332, y: 150, width: 196, height: 30)
        guideButton.isEnabled = false

        let stepThree = NSTextField(labelWithString: "3  Choose the stream CamBar should show")
        stepThree.font = .systemFont(ofSize: 14, weight: .medium)
        stepThree.frame = NSRect(x: 32, y: 108, width: 310, height: 24)

        streamField.placeholderString = "Stream name, for example c200h264"
        streamField.frame = NSRect(x: 332, y: 104, width: 196, height: 28)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: 32, y: 66, width: 496, height: 24)

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.frame = NSRect(x: 340, y: 20, width: 188, height: 30)
        saveButton.isEnabled = false

        [title, intro, stepOne, installButton, stepTwo, guideButton,
         stepThree, streamField, statusLabel, saveButton].forEach { content.addSubview($0) }
        return content
    }

    @objc private func install() { onInstall?() }
    @objc private func openGuide() { onOpenGuide?() }

    @objc private func save() {
        let name = streamField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            setStatus("Enter the stream name shown in go2rtc.", isError: true)
            return
        }
        onSave?(name)
    }

    func markReady() {
        guideButton.isEnabled = true
        saveButton.isEnabled = true
        setStatus("go2rtc is running. Open its setup page to add your camera.")
    }
}

/// Menu-bar app that shows a camera HLS stream in a popover.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var player: AVPlayer?
    private var setupWindow: SetupWindowController?

    private var streamName: String? {
        get { UserDefaults.standard.string(forKey: "streamName") }
        set { UserDefaults.standard.set(newValue, forKey: "streamName") }
    }

    private var streamURL: URL? {
        guard let streamName, !streamName.isEmpty else { return nil }
        return URL(string: "http://127.0.0.1:1984/api/stream.m3u8?src=\(streamName)")
    }

    private var go2rtcPath: String {
        let path = (defaultGo2RTCPath as NSString).expandingTildeInPath
        return ProcessInfo.processInfo.environment["CAMBAR_GO2RTC"] ?? path
    }

    private var configPath: String {
        let path = (defaultConfigPath as NSString).expandingTildeInPath
        return ProcessInfo.processInfo.environment["CAMBAR_GO2RTC_CONFIG"] ?? path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Camera")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        buildPopover()
        DispatchQueue.main.async {
            if self.streamURL == nil {
                self.showSetupWindow()
            }
        }
    }

    private func buildPopover() {
        let width: CGFloat = 720
        let height: CGFloat = 440
        let footer: CGFloat = 48
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        if let streamURL {
            let playerView = AVPlayerView(frame: NSRect(x: 0, y: footer, width: width, height: height - footer))
            playerView.autoresizingMask = [.width, .height]
            playerView.controlsStyle = .none
            playerView.videoGravity = .resizeAspect
            let p = AVPlayer(url: streamURL)
            p.isMuted = true
            playerView.player = p
            player = p
            container.addSubview(playerView)
        } else {
            let placeholder = NSTextField(wrappingLabelWithString: "CamBar needs a camera stream before it can show video.\n\nOpen setup to install go2rtc and connect your camera.")
            placeholder.alignment = .center
            placeholder.font = .systemFont(ofSize: 16)
            placeholder.textColor = .secondaryLabelColor
            placeholder.frame = NSRect(x: 120, y: 150, width: 480, height: 100)
            container.addSubview(placeholder)
        }

        let setup = NSButton(title: "Setup", target: self, action: #selector(showSetupWindow))
        setup.bezelStyle = .inline
        setup.frame = NSRect(x: 20, y: 10, width: 80, height: 28)
        container.addSubview(setup)

        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.bezelStyle = .inline
        quit.frame = NSRect(x: (width - 80) / 2, y: 10, width: 80, height: 28)
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

    @objc private func showSetupWindow() {
        if setupWindow == nil {
            let controller = SetupWindowController(initialStreamName: streamName ?? defaultStreamName)
            controller.onInstall = { [weak self, weak controller] in
                self?.installAndStart(controller: controller)
            }
            controller.onOpenGuide = { [weak self] in self?.openCameraSetup() }
            controller.onSave = { [weak self] name in self?.saveStream(name) }
            setupWindow = controller
        }
        setupWindow?.show()
    }

    private func installAndStart(controller: SetupWindowController?) {
        controller?.setInstalling(true)
        if FileManager.default.fileExists(atPath: go2rtcPath) {
            startBackgroundService(controller: controller)
            return
        }

        runBundledScript(named: "install-go2rtc", environment: [:]) { [weak self, weak controller] success, output in
            guard let self else { return }
            guard success else {
                controller?.setInstalling(false)
                controller?.setStatus(output.isEmpty ? "Could not install go2rtc." : output, isError: true)
                return
            }
            self.startBackgroundService(controller: controller)
        }
    }

    private func startBackgroundService(controller: SetupWindowController?) {
        do {
            let directory = (configPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: configPath),
               let template = Bundle.main.url(forResource: "go2rtc.example", withExtension: "yaml") {
                try FileManager.default.copyItem(at: template, to: URL(fileURLWithPath: configPath))
            }
        } catch {
            controller?.setInstalling(false)
            controller?.setStatus("Could not create the go2rtc config: \(error.localizedDescription)", isError: true)
            return
        }

        runBundledScript(named: "install-launchd", environment: [
            "GO2RTC": go2rtcPath,
            "CONFIG": configPath
        ]) { [weak controller] success, output in
            controller?.setInstalling(false)
            if success {
                controller?.markReady()
            } else {
                controller?.setStatus(output.isEmpty ? "Could not start the go2rtc service." : output, isError: true)
            }
        }
    }

    private func runBundledScript(named name: String,
                                  environment: [String: String],
                                  completion: @escaping (Bool, String) -> Void) {
        guard let script = Bundle.main.url(forResource: name, withExtension: "sh") else {
            completion(false, "The bundled setup script is missing. Please reinstall CamBar.")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path]
        var env = ProcessInfo.processInfo.environment
        environment.forEach { env[$0.key] = $0.value }
        task.environment = env
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.terminationHandler = { process in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(process.terminationStatus == 0, output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        do {
            try task.run()
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func openCameraSetup() {
        NSWorkspace.shared.open(URL(string: "http://127.0.0.1:1984")!)
    }

    private func saveStream(_ name: String) {
        streamName = name
        setupWindow = nil
        buildPopover()
        if popover.isShown { popover.performClose(nil) }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            player?.pause()
        } else {
            if streamURL == nil {
                showSetupWindow()
                return
            }
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
