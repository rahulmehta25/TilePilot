import Foundation
import AppKit
import ApplicationServices

final class WindowManager {

    struct ApplyResult {
        let layoutName: String
        let successes: [(bundleID: String, label: String)]
        let skipped: [(bundleID: String, reason: String)]
        let durationMs: Double
    }

    /// Apply a resolved layout by moving/resizing windows via the Accessibility API
    @discardableResult
    static func apply(layout: ResolvedLayout) -> ApplyResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var successes: [(String, String)] = []
        var skipped: [(String, String)] = []

        // Apply in reverse order so the first tile ends up on top
        for tile in layout.tiles.reversed() {
            let result = applyTile(tile)
            switch result {
            case .success:
                successes.append((tile.bundleID, tile.label))
            case .skipped(let reason):
                skipped.append((tile.bundleID, reason))
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        let successList = successes.map { "\($0.1) ok" }.joined(separator: ", ")
        let skippedList = skipped.map { "\($0.1): \($0.0)" }.joined(separator: ", ")
        var logParts = ["Applied '\(layout.name)':"]
        if !successList.isEmpty { logParts.append(successList) }
        if !skippedList.isEmpty { logParts.append("skipped: \(skippedList)") }
        logParts.append("(\(Int(elapsed))ms)")
        TilePilotLogger.layoutInfo(logParts.joined(separator: " "))

        return ApplyResult(
            layoutName: layout.name,
            successes: successes,
            skipped: skipped,
            durationMs: elapsed
        )
    }

    private enum TileResult {
        case success
        case skipped(reason: String)
    }

    private static func applyTile(_ tile: ResolvedTile) -> TileResult {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == tile.bundleID
        }) else {
            TilePilotLogger.windowInfo("Skipping \(tile.label): not running")
            return .skipped(reason: "not running")
        }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        guard let windows = axApp.windows(), !windows.isEmpty else {
            TilePilotLogger.windowInfo("Skipping \(tile.label): no windows")
            return .skipped(reason: "no windows")
        }

        let targetWindow: AXUIElement?
        if let titleFilter = tile.windowTitleFilter {
            targetWindow = windows.first { win in
                guard !win.isMinimized, !win.isFullScreen else { return false }
                guard let title = win.title else { return false }
                return title.localizedCaseInsensitiveContains(titleFilter)
            }
        } else {
            targetWindow = windows.first { !$0.isMinimized && !$0.isFullScreen }
        }

        guard let window = targetWindow else {
            TilePilotLogger.windowInfo("Skipping \(tile.label): no visible matching window")
            return .skipped(reason: "no visible window")
        }

        window.position = tile.frame.origin
        window.size = tile.frame.size
        window.raise()

        TilePilotLogger.windowInfo("Tiled \(tile.label) to \(tile.frame)")
        return .success
    }
}
