import Foundation
import os.log

enum TilePilotLogger {
    private static let subsystem = "com.rahulmehta.TilePilot"

    private static let general = Logger(subsystem: subsystem, category: "general")
    private static let layout = Logger(subsystem: subsystem, category: "layout")
    private static let config = Logger(subsystem: subsystem, category: "config")
    private static let windowMgmt = Logger(subsystem: subsystem, category: "window")

    static func info(_ message: String) {
        general.info("\(message, privacy: .public)")
    }

    static func warning(_ message: String) {
        general.warning("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        general.error("\(message, privacy: .public)")
    }

    static func layoutInfo(_ message: String) {
        layout.info("\(message, privacy: .public)")
    }

    static func configInfo(_ message: String) {
        config.info("\(message, privacy: .public)")
    }

    static func windowInfo(_ message: String) {
        windowMgmt.info("\(message, privacy: .public)")
    }

    static func windowWarning(_ message: String) {
        windowMgmt.warning("\(message, privacy: .public)")
    }
}
