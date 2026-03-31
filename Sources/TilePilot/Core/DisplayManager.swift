import Foundation
import AppKit

final class DisplayManager {

    /// Notification posted when displays change
    static let displaysDidChange = Notification.Name("TilePilotDisplaysDidChange")

    private var screenChangeObserver: NSObjectProtocol?

    /// Currently connected screens
    private(set) var screens: [NSScreen] = NSScreen.screens

    init() {
        screens = NSScreen.screens
    }

    /// Start observing display connect/disconnect events
    func startObserving() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
        TilePilotLogger.info("Display manager: observing \(screens.count) screen(s)")
    }

    /// Stop observing display changes
    func stopObserving() {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }

    /// Find a screen matching a display name.
    /// If no name specified, returns main screen. If name specified but not found, returns nil.
    func screen(forName name: String?) -> NSScreen? {
        guard let name else { return NSScreen.main }
        return screens.first { $0.localizedName == name }
    }

    /// List all connected screen names
    var screenNames: [String] {
        screens.map { $0.localizedName }
    }

    /// Find the appropriate screen for a layout config
    func screen(for layout: LayoutConfig) -> NSScreen? {
        screen(forName: layout.monitor)
    }

    // MARK: - Private

    private func handleScreenChange() {
        let oldCount = screens.count
        screens = NSScreen.screens
        let newCount = screens.count

        let names = screenNames.joined(separator: ", ")
        TilePilotLogger.info("Display change: \(oldCount) -> \(newCount) screens [\(names)]")

        NotificationCenter.default.post(name: Self.displaysDidChange, object: self)
    }
}
