import Cocoa
import Security
import ServiceManagement
import WebKit

private let defaultStreamName = "c200h264"
private let defaultGo2RTCPath = "~/.local/bin/go2rtc"
private let defaultConfigPath = "~/.config/go2rtc/go2rtc.yaml"

private enum CredentialStore {
    private static let service = "local.cambar.xiaomi"

    static func save(token: String, accountID: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) != errSecSuccess {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}

final class SetupWindowController: NSObject {
    var onInstall: (() -> Void)?
    var onOpenGuide: (() -> Void)?
    var onSave: ((String, String, String) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    private let window: NSWindow
    private let statusLabel = NSTextField(labelWithString: "")
    private let streamField = NSTextField(string: defaultStreamName)
    private let sourceField = NSTextField(string: "")
    private let tokenField = NSSecureTextField(string: "")
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Open CamBar at login", target: nil, action: nil)
    private let installButton = NSButton(title: "Install & Start go2rtc", target: nil, action: nil)
    private let guideButton = NSButton(title: "Open Camera Setup", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save & Open CamBar", target: nil, action: nil)

    init(initialStreamName: String, initialSource: String, initialLaunchAtLogin: Bool) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                          styleMask: [.titled, .closable],
                          backing: .buffered,
                          defer: false)
        super.init()
        window.title = "Set up CamBar"
        window.isReleasedWhenClosed = false
        window.contentView = makeContentView()
        streamField.stringValue = initialStreamName
        sourceField.stringValue = initialSource
        launchAtLoginButton.state = initialLaunchAtLogin ? .on : .off
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
        launchAtLoginButton.isEnabled = !installing
        setStatus(installing ? "Installing and starting the background service…" : "")
    }

    private func makeContentView() -> NSView {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 520))

        let title = NSTextField(labelWithString: "Your camera, one click away")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.frame = NSRect(x: 32, y: 460, width: 496, height: 32)

        let intro = NSTextField(wrappingLabelWithString: "Install the background service, configure your camera once, then CamBar will keep the stream ready in your menu bar.")
        intro.font = .systemFont(ofSize: 14)
        intro.textColor = .secondaryLabelColor
        intro.frame = NSRect(x: 32, y: 396, width: 496, height: 52)

        let stepOne = NSTextField(labelWithString: "1  Start the background service")
        stepOne.font = .systemFont(ofSize: 14, weight: .medium)
        stepOne.frame = NSRect(x: 32, y: 358, width: 240, height: 24)

        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(install)
        installButton.frame = NSRect(x: 332, y: 354, width: 196, height: 30)

        let stepTwo = NSTextField(labelWithString: "2  Add your camera in go2rtc")
        stepTwo.font = .systemFont(ofSize: 14, weight: .medium)
        stepTwo.frame = NSRect(x: 32, y: 318, width: 260, height: 24)

        guideButton.bezelStyle = .rounded
        guideButton.target = self
        guideButton.action = #selector(openGuide)
        guideButton.frame = NSRect(x: 332, y: 314, width: 196, height: 30)
        guideButton.isEnabled = false

        let sourceLabel = NSTextField(labelWithString: "Camera source URL")
        sourceLabel.font = .systemFont(ofSize: 14, weight: .medium)
        sourceLabel.frame = NSRect(x: 32, y: 270, width: 496, height: 24)

        sourceField.placeholderString = "rtsp://, onvif://, xiaomi://, ffmpeg:, or another go2rtc source"
        sourceField.frame = NSRect(x: 32, y: 238, width: 496, height: 28)

        let tokenLabel = NSTextField(labelWithString: "Xiaomi token")
        tokenLabel.font = .systemFont(ofSize: 14, weight: .medium)
        tokenLabel.stringValue = "Xiaomi token (optional)"
        tokenLabel.frame = NSRect(x: 32, y: 204, width: 496, height: 24)

        tokenField.placeholderString = "V1:… (leave blank to keep the saved token)"
        tokenField.frame = NSRect(x: 32, y: 172, width: 496, height: 28)

        let stepThree = NSTextField(labelWithString: "3  Stream name CamBar should show")
        stepThree.font = .systemFont(ofSize: 14, weight: .medium)
        stepThree.frame = NSRect(x: 32, y: 138, width: 280, height: 24)

        streamField.placeholderString = "For example c200h264"
        streamField.frame = NSRect(x: 332, y: 134, width: 196, height: 28)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: 32, y: 70, width: 496, height: 38)

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(toggleLaunchAtLogin)
        launchAtLoginButton.frame = NSRect(x: 32, y: 22, width: 220, height: 28)

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.frame = NSRect(x: 340, y: 20, width: 188, height: 30)
        saveButton.isEnabled = false

        [title, intro, stepOne, installButton, stepTwo, guideButton,
         sourceLabel, sourceField, tokenLabel, tokenField, stepThree,
         streamField, statusLabel, launchAtLoginButton, saveButton].forEach { content.addSubview($0) }
        return content
    }

    @objc private func install() { onInstall?() }
    @objc private func openGuide() { onOpenGuide?() }

    @objc private func toggleLaunchAtLogin() {
        onLaunchAtLoginChanged?(launchAtLoginButton.state == .on)
    }

    @objc private func save() {
        let name = streamField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            setStatus("Enter the stream name shown in go2rtc.", isError: true)
            return
        }
        guard !source.isEmpty else {
            setStatus("Paste the camera source URL from go2rtc.", isError: true)
            return
        }
        onSave?(name, source, token)
    }

    func markReady() {
        guideButton.isEnabled = true
        saveButton.isEnabled = true
        setStatus("go2rtc is running. Open its setup page to add your camera.")
    }

    func markSaved(streamName: String) {
        saveButton.title = "Saved ✓"
        saveButton.isEnabled = false
        guideButton.isEnabled = false
        streamField.isEnabled = false
        launchAtLoginButton.isEnabled = false
        setStatus("Saved \(streamName). Opening CamBar…")
    }

    func close() {
        window.close()
    }
}

/// Menu-bar app that shows a camera HLS stream in a popover.
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var webView: WKWebView?
    private weak var streamMessageLabel: NSTextField?
    private var setupWindow: SetupWindowController?

    private var streamName: String? {
        get { UserDefaults.standard.string(forKey: "streamName") }
        set { UserDefaults.standard.set(newValue, forKey: "streamName") }
    }

    private var webRTCURL: URL? {
        guard let streamName, !streamName.isEmpty else { return nil }
        var components = URLComponents(string: "http://127.0.0.1:1984/webrtc.html")
        components?.queryItems = [URLQueryItem(name: "src", value: streamName)]
        return components?.url
    }

    private var go2rtcPath: String {
        let path = (defaultGo2RTCPath as NSString).expandingTildeInPath
        return ProcessInfo.processInfo.environment["CAMBAR_GO2RTC"] ?? path
    }

    private var configPath: String {
        let path = (defaultConfigPath as NSString).expandingTildeInPath
        return ProcessInfo.processInfo.environment["CAMBAR_GO2RTC_CONFIG"] ?? path
    }

    private var bundledFFmpegPath: String? {
        Bundle.main.url(forResource: "ffmpeg", withExtension: nil)?.path
    }

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private var configuredSource: String {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return "" }
        for line in content.components(separatedBy: .newlines) {
            let value = line.trimmingCharacters(in: .whitespaces)
            if value.contains("://") || value.contains("ffmpeg:") {
                return value
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return ""
    }

    private func existingToken(for accountID: String) -> String? {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        let marker = "\"\(accountID)\":"
        for line in content.components(separatedBy: .newlines) where line.contains(marker) {
            guard let range = line.range(of: marker) else { continue }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func yamlValue(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func saveCameraConfig(source: String, token: String, streamName: String) throws {
        var xiaomiConfig = ""
        var xiaomiAccountID: String?
        if source.hasPrefix("xiaomi://") {
            guard let components = URLComponents(string: source),
                  let accountID = components.user,
                  !accountID.isEmpty,
                  components.password?.isEmpty == false,
                  !token.isEmpty else {
                throw NSError(domain: "CamBar", code: 1, userInfo: [NSLocalizedDescriptionKey: "A Xiaomi source needs its account ID, region, and token."])
            }
            xiaomiAccountID = accountID
            xiaomiConfig = "xiaomi:\n  \"\(yamlValue(accountID))\": \"\(yamlValue(token))\"\n\n"
        }

        let sourceValue: String
        if source.hasPrefix("xiaomi://") {
            sourceValue = "ffmpeg:cambar_source#video=h264#audio=aac"
        } else {
            sourceValue = source
        }

        let rawSource = source.hasPrefix("xiaomi://")
            ? "  cambar_source:\n    - \"\(yamlValue(source))\"\n"
            : ""
        let config = """
        \(xiaomiConfig)streams:
        \(rawSource)  "\(yamlValue(streamName))":
            - "\(yamlValue(sourceValue))"
        """
        try config.write(toFile: configPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configPath)
        if let xiaomiAccountID {
            CredentialStore.save(token: token, accountID: xiaomiAccountID)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerLaunchAtLogin()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Camera")
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        buildPopover()
        DispatchQueue.main.async {
            if self.streamName == nil || self.streamName?.isEmpty == true {
                self.showSetupWindow()
            }
        }
    }

    private func registerLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        guard !UserDefaults.standard.bool(forKey: "launchAtLoginPreferenceSet") else { return }
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "launchAtLoginPreferenceSet")
        } catch {
            NSLog("CamBar could not register as a login item: %@", error.localizedDescription)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(true, forKey: "launchAtLoginPreferenceSet")
        } catch {
            NSLog("CamBar could not update its login item: %@", error.localizedDescription)
        }
    }

    private func buildPopover() {
        webView?.stopLoading()
        webView = nil

        let width: CGFloat = 720
        let height: CGFloat = 440
        let footer: CGFloat = 48
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        if let webRTCURL {
            let configuration = WKWebViewConfiguration()
            configuration.allowsAirPlayForMediaPlayback = false
            configuration.mediaTypesRequiringUserActionForPlayback = []
            let view = WKWebView(frame: NSRect(x: 0, y: footer, width: width, height: height - footer), configuration: configuration)
            view.autoresizingMask = [.width, .height]
            view.navigationDelegate = self
            view.setValue(false, forKey: "drawsBackground")
            view.load(URLRequest(url: webRTCURL))
            webView = view
            container.addSubview(view)

            let message = NSTextField(wrappingLabelWithString: "")
            message.alignment = .center
            message.font = .systemFont(ofSize: 14)
            message.textColor = .secondaryLabelColor
            message.frame = NSRect(x: 90, y: 172, width: width - 180, height: 96)
            message.isHidden = true
            message.autoresizingMask = [.width, .minYMargin, .maxYMargin]
            container.addSubview(message)
            streamMessageLabel = message

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

    private func showStreamError(_ message: String) {
        streamMessageLabel?.stringValue = message
        streamMessageLabel?.isHidden = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        showStreamError("WebRTC stream unavailable\n\n\(error.localizedDescription)\n\nOpen Setup to check go2rtc and the camera source.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        showStreamError("WebRTC stream unavailable\n\n\(error.localizedDescription)\n\nOpen Setup to check go2rtc and the camera source.")
    }

    @objc private func showSetupWindow() {
        if setupWindow == nil {
            let controller = SetupWindowController(initialStreamName: streamName ?? defaultStreamName,
                                                    initialSource: configuredSource,
                                                    initialLaunchAtLogin: launchAtLoginEnabled)
            controller.onInstall = { [weak self, weak controller] in
                self?.installAndStart(controller: controller)
            }
            controller.onOpenGuide = { [weak self] in self?.openCameraSetup() }
            controller.onSave = { [weak self] name, source, token in
                self?.saveStream(name, source: source, token: token, controller: controller)
            }
            controller.onLaunchAtLoginChanged = { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            }
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

    private func startBackgroundService(controller: SetupWindowController?, onReady: (() -> Void)? = nil) {
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
            "CONFIG": configPath,
            "FFMPEG": bundledFFmpegPath ?? ""
        ]) { [weak controller] success, output in
            controller?.setInstalling(false)
            if success {
                controller?.markReady()
                onReady?()
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

    private func saveStream(_ name: String,
                            source: String,
                            token: String,
                            controller: SetupWindowController) {
        do {
            let resolvedToken: String
            if source.hasPrefix("xiaomi://"), let accountID = URLComponents(string: source)?.user {
                resolvedToken = token.isEmpty ? (existingToken(for: accountID) ?? "") : token
            } else {
                resolvedToken = token
            }
            try saveCameraConfig(source: source, token: resolvedToken, streamName: name)
        } catch {
            controller.setStatus(error.localizedDescription, isError: true)
            return
        }

        controller.setStatus("Configuration saved. Testing the camera stream…")
        startBackgroundService(controller: controller) { [weak self, weak controller] in
            self?.verifyStream { success, detail in
                guard let self, let controller else { return }
                if success {
                    self.streamName = name
                    controller.markSaved(streamName: name)
                    self.buildPopover()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        controller.close()
                        self.setupWindow = nil
                        self.showPopover()
                    }
                } else {
                    controller.setStatus("Configuration saved, but the stream test failed: \(detail)", isError: true)
                }
            }
        }
    }

    private func verifyStream(attempt: Int = 0, completion: @escaping (Bool, String) -> Void) {
        guard let streamName, !streamName.isEmpty else {
            completion(false, "No stream is configured.")
            return
        }
        var components = URLComponents(string: "http://127.0.0.1:1984/api/stream.m3u8")
        components?.queryItems = [URLQueryItem(name: "src", value: streamName)]
        guard let hlsURL = components?.url else {
            completion(false, "Could not create the local stream URL.")
            return
        }
        URLSession.shared.dataTask(with: hlsURL) { [weak self] data, response, error in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200
                && (data?.count ?? 0) > 20
                && String(data: data ?? Data(), encoding: .utf8).map {
                    $0.contains("#EXTM3U") && ($0.contains("#EXTINF") || $0.contains("#EXT-X-STREAM-INF"))
                } == true
            if isValid {
                DispatchQueue.main.async { completion(true, "") }
                return
            }

            if attempt < 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.verifyStream(attempt: attempt + 1, completion: completion)
                }
            } else {
                let detail = error?.localizedDescription ?? "go2rtc did not return a playable HLS playlist. Check the camera credentials and source URL."
                DispatchQueue.main.async { completion(false, detail) }
            }
        }.resume()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover() {
        guard statusItem.button != nil else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if webRTCURL == nil {
                showSetupWindow()
                return
            }
            showPopover()
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
