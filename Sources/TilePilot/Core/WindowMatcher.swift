import Foundation
import AppKit

final class WindowMatcher {

    struct MatchResult {
        let bundleID: String
        let label: String
        let app: NSRunningApplication?
        let isRunning: Bool
    }

    /// Match tile bundle IDs against currently running applications
    static func matchTiles(_ tiles: [TileConfig]) -> [MatchResult] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIDs = Set(runningApps.compactMap { $0.bundleIdentifier })

        return tiles.map { tile in
            let isRunning = runningBundleIDs.contains(tile.app)
            let app = isRunning ? runningApps.first(where: { $0.bundleIdentifier == tile.app }) : nil

            return MatchResult(
                bundleID: tile.app,
                label: tile.label ?? tile.app,
                app: app,
                isRunning: isRunning
            )
        }
    }

    /// Get the set of bundle IDs from a layout that are currently running
    static func runningBundleIDs(for layout: LayoutConfig) -> Set<String> {
        let running = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        )
        let needed = Set(layout.tiles.map { $0.app })
        return running.intersection(needed)
    }

    /// Count how many of a layout's apps are currently running
    static func availabilityCount(for layout: LayoutConfig) -> (running: Int, total: Int) {
        let running = runningBundleIDs(for: layout)
        return (running.count, layout.tiles.count)
    }
}
