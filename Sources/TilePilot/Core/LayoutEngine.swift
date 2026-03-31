import Foundation
import AppKit

final class LayoutEngine {

    /// Compute pixel-level CGRects for each tile in a layout.
    /// The screenFrame must be in AX coordinates (top-left origin, y increases downward).
    static func resolve(
        layout: LayoutConfig,
        layoutName: String,
        screenFrame: CGRect,
        globalGap: Int
    ) -> ResolvedLayout {
        let gap = CGFloat(layout.gap ?? globalGap)
        let rows = layout.rows
        let cols = layout.cols

        let cellWidth = (screenFrame.width - gap * CGFloat(cols + 1)) / CGFloat(cols)
        let cellHeight = (screenFrame.height - gap * CGFloat(rows + 1)) / CGFloat(rows)

        let resolvedTiles = layout.tiles.map { tile -> ResolvedTile in
            let x = screenFrame.origin.x + gap + CGFloat(tile.col) * (cellWidth + gap)
            let y = screenFrame.origin.y + gap + CGFloat(tile.row) * (cellHeight + gap)
            let w = CGFloat(tile.colSpan) * cellWidth + CGFloat(tile.colSpan - 1) * gap
            let h = CGFloat(tile.rowSpan) * cellHeight + CGFloat(tile.rowSpan - 1) * gap

            let frame = CGRect(x: x, y: y, width: w, height: h).pixelAligned

            return ResolvedTile(
                bundleID: tile.app,
                label: tile.label ?? tile.app,
                frame: frame,
                windowTitleFilter: tile.windowTitleContains
            )
        }

        return ResolvedLayout(
            name: layoutName,
            monitorName: layout.monitor,
            tiles: resolvedTiles,
            hotkeyString: layout.hotkey
        )
    }

    /// Convenience: resolve with an NSScreen (handles Cocoa-to-AX coordinate conversion).
    static func resolve(
        layout: LayoutConfig,
        layoutName: String,
        screen: NSScreen,
        generalGap: Int
    ) -> ResolvedLayout {
        let axFrame = Self.visibleFrameInAXCoordinates(for: screen)
        return resolve(layout: layout, layoutName: layoutName, screenFrame: axFrame, globalGap: generalGap)
    }

    /// Convert NSScreen.visibleFrame (Cocoa bottom-left origin) to AX coordinates (top-left origin).
    static func visibleFrameInAXCoordinates(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens[0].frame.height
        let vf = screen.visibleFrame
        return CGRect(
            x: vf.origin.x,
            y: primaryHeight - vf.origin.y - vf.height,
            width: vf.width,
            height: vf.height
        )
    }
}
