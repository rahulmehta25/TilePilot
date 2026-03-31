import SwiftUI
import ServiceManagement

@main
struct TilePilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }

        Window("Onboarding", id: "onboarding") {
            OnboardingView()
                .environmentObject(appDelegate.appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
        .windowResizability(.contentSize)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var config: TilePilotConfig
    @Published var activeLayoutName: String?
    @Published var hasSnapshot: Bool = false
    @Published var hasCompletedOnboarding: Bool
    @Published var launchAtLogin: Bool {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    let configLoader = ConfigLoader()
    let hotkeyManager = HotkeyManager()
    let displayManager = DisplayManager()
    private var windowSnapshot: [String: CGRect] = [:]

    init() {
        self.config = TilePilotConfig(general: GeneralConfig(), layouts: [:])
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        configLoader.ensureDefaultConfig()
        if let loaded = configLoader.loadConfig() {
            self.config = loaded
        }

        setupHotkeys()
        setupConfigReloading()
        displayManager.startObserving()
    }

    func applyLayout(named name: String) {
        let msg2 = "[TilePilot \(Date())] applyLayout: '\(name)', layouts: \(Array(config.layouts.keys)), AX: \(AXIsProcessTrusted())\n"
        if let data = msg2.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: "/tmp/tilepilot-debug.log") {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            } else {
                FileManager.default.createFile(atPath: "/tmp/tilepilot-debug.log", contents: data)
            }
        }
        print("[TilePilot] applyLayout called: '\(name)'")
        print("[TilePilot] Available layouts: \(Array(config.layouts.keys))")

        guard let layout = config.layouts[name] else {
            print("[TilePilot] Layout '\(name)' NOT FOUND in config")
            TilePilotLogger.warning("Layout '\(name)' not found")
            return
        }

        print("[TilePilot] AXIsProcessTrusted: \(AXIsProcessTrusted())")
        guard AXIsProcessTrusted() else {
            print("[TilePilot] AX NOT TRUSTED - showing alert")
            TilePilotLogger.warning("Accessibility permission not granted")
            showAccessibilityAlert()
            return
        }
        
        print("[TilePilot] Layout '\(name)' has \(layout.tiles.count) tiles")

        let screen: NSScreen
        if layout.monitor != nil {
            guard let found = displayManager.screen(for: layout) else {
                let monitorName = layout.monitor ?? ""
                TilePilotLogger.warning("Layout '\(name)': monitor '\(monitorName)' not connected, skipping")
                NotificationHelper.monitorNotConnected(layoutName: name, monitorName: monitorName)
                return
            }
            screen = found
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }

        let resolved = LayoutEngine.resolve(
            layout: layout,
            layoutName: name,
            screen: screen,
            generalGap: config.general.gap
        )

        snapshotPositions(for: resolved)
        let result = WindowManager.apply(layout: resolved)
        activeLayoutName = name
        hasSnapshot = true
        TilePilotLogger.layoutInfo(
            "Layout '\(name)': \(result.successes.count) tiled, \(result.skipped.count) skipped (\(Int(result.durationMs))ms)"
        )
    }

    func restorePrevious() {
        guard hasSnapshot else { return }
        for (bundleID, frame) in windowSnapshot {
            restoreFrame(frame, toBundleID: bundleID)
        }
        windowSnapshot.removeAll()
        hasSnapshot = false
        activeLayoutName = nil
        TilePilotLogger.info("Restored previous window positions")
    }

    func previewLayout(_ layout: LayoutConfig, name: String) {
        guard AXIsProcessTrusted() else { return }

        let screen: NSScreen
        if layout.monitor != nil {
            guard let found = displayManager.screen(for: layout) else {
                NotificationHelper.monitorNotConnected(layoutName: name, monitorName: layout.monitor ?? "")
                return
            }
            screen = found
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }
        let resolved = LayoutEngine.resolve(
            layout: layout,
            layoutName: name,
            screen: screen,
            generalGap: config.general.gap
        )
        snapshotPositions(for: resolved)
        let _ = WindowManager.apply(layout: resolved)
        hasSnapshot = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.restorePrevious()
        }
    }

    func reloadConfig() {
        if let loaded = configLoader.loadConfig() {
            config = loaded
            setupHotkeys()
            TilePilotLogger.configInfo("Config reloaded: \(config.layouts.count) layouts")
        }
    }

    func saveConfigToDisk() {
        do {
            try ConfigWriter.writeFullConfig(config, to: ConfigLoader.configFilePath.path)
        } catch {
            TilePilotLogger.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Alerts

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "TilePilot needs accessibility permissions to move and resize windows. Please grant access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Snapshot Helpers

    private func snapshotPositions(for layout: ResolvedLayout) {
        windowSnapshot.removeAll()
        for tile in layout.tiles {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == tile.bundleID
            }) else { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = axApp.windows(), let window = windows.first else { continue }

            if let pos = window.position, let size = window.size {
                windowSnapshot[tile.bundleID] = CGRect(origin: pos, size: size)
            }
        }
    }

    private func restoreFrame(_ frame: CGRect, toBundleID bundleID: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID
        }) else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = axApp.windows(), let window = windows.first else { return }

        window.position = frame.origin
        window.size = frame.size
    }

    // MARK: - Private Setup

    private func setupHotkeys() {
        hotkeyManager.onHotkeyTriggered = { [weak self] layoutName in
            DispatchQueue.main.async {
                self?.applyLayout(named: layoutName)
            }
        }
        hotkeyManager.registerAll(from: config)
    }

    private func setupConfigReloading() {
        configLoader.onConfigReloaded = { [weak self] newConfig in
            DispatchQueue.main.async {
                guard let self else { return }
                self.config = newConfig
                self.setupHotkeys()
                TilePilotLogger.configInfo("Config hot-reloaded: \(newConfig.layouts.count) layouts")
            }
        }
        configLoader.onConfigError = { message in
            TilePilotLogger.error("Config error: \(message)")
        }
        configLoader.startWatching()
    }
}
