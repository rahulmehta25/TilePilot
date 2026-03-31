import Foundation
import UserNotifications

enum NotificationHelper {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                TilePilotLogger.warning("Notification permission error: \(error.localizedDescription)")
            } else if !granted {
                TilePilotLogger.info("Notification permission not granted")
            }
        }
    }

    static func configReloaded(layoutCount: Int) {
        send(
            title: "Config Reloaded",
            body: "TilePilot config reloaded. \(layoutCount) layouts active."
        )
    }

    static func configError(message: String) {
        send(
            title: "Config Error",
            body: message
        )
    }

    static func configFileMissing(path: String) {
        send(
            title: "Default Config Created",
            body: "Created default config at \(path)"
        )
    }

    static func monitorNotConnected(layoutName: String, monitorName: String) {
        send(
            title: "Monitor Not Connected",
            body: "Layout '\(layoutName)' targets '\(monitorName)' which is not connected."
        )
    }

    static func validationErrors(_ errors: [String]) {
        guard !errors.isEmpty else { return }
        let body = errors.joined(separator: "\n")
        send(
            title: "Layout Validation Errors",
            body: body
        )
    }

    private static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.tilepilot.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                TilePilotLogger.warning("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}
