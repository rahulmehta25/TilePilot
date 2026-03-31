import XCTest
@testable import TilePilot

final class LayoutEngineTests: XCTestCase {

    // MARK: - Basic Grid Math

    func testBasic2x2Grid() {
        let layout = LayoutConfig(rows: 2, cols: 2, hotkey: "cmd+shift+1", tiles: [
            TileConfig(app: "com.app.a", row: 0, col: 0),
            TileConfig(app: "com.app.b", row: 0, col: 1),
            TileConfig(app: "com.app.c", row: 1, col: 0),
            TileConfig(app: "com.app.d", row: 1, col: 1),
        ])

        // Screen: 1440x900, visible starting at y=25 (menu bar), AX coordinates
        let screenFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "test", screenFrame: screenFrame, globalGap: 8
        )

        XCTAssertEqual(resolved.tiles.count, 4)

        // Cell size: (1440 - 8*3) / 2 = 708, (875 - 8*3) / 2 = 425.5
        let cellW: CGFloat = (1440 - 24) / 2  // 708
        let cellH: CGFloat = (875 - 24) / 2   // 425.5

        // Tile (0,0): x=8, y=33
        let t0 = resolved.tiles[0]
        XCTAssertEqual(t0.frame.origin.x, 8, accuracy: 1)
        XCTAssertEqual(t0.frame.origin.y, 33, accuracy: 1)
        XCTAssertEqual(t0.frame.width, cellW, accuracy: 1)

        // Tile (0,1): x=8+708+8=724, y=33
        let t1 = resolved.tiles[1]
        XCTAssertEqual(t1.frame.origin.x, 724, accuracy: 1)
        XCTAssertEqual(t1.frame.origin.y, 33, accuracy: 1)

        // Tile (1,0): x=8, y=33+425.5+8=466.5
        let t2 = resolved.tiles[2]
        XCTAssertEqual(t2.frame.origin.x, 8, accuracy: 1)
        XCTAssertEqual(t2.frame.origin.y, 466, accuracy: 2)

        // Tile (1,1): bottom-right
        let t3 = resolved.tiles[3]
        XCTAssertEqual(t3.frame.origin.x, 724, accuracy: 1)
        XCTAssertEqual(t3.frame.origin.y, 466, accuracy: 2)
    }

    func testSpanningTile() {
        let layout = LayoutConfig(rows: 2, cols: 4, hotkey: "cmd+shift+1", tiles: [
            TileConfig(app: "com.cursor", label: "Cursor", row: 0, col: 0, rowSpan: 2, colSpan: 2),
            TileConfig(app: "com.claude", label: "Claude", row: 0, col: 2, rowSpan: 1, colSpan: 2),
            TileConfig(app: "com.term", label: "Terminal", row: 1, col: 2, rowSpan: 1, colSpan: 2),
        ])

        let screenFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "deep-work", screenFrame: screenFrame, globalGap: 8
        )

        XCTAssertEqual(resolved.tiles.count, 3)

        let cursor = resolved.tiles[0]
        let claude = resolved.tiles[1]
        let terminal = resolved.tiles[2]

        // Cursor spans 2 cols and 2 rows: should take left half, full height
        XCTAssertEqual(cursor.frame.origin.x, 8, accuracy: 1)
        XCTAssertEqual(cursor.frame.origin.y, 33, accuracy: 1)

        // Cursor width should be ~2 cells + 1 gap
        let cellW = (1440.0 - 8.0 * 5) / 4.0  // (1440-40)/4 = 350
        let expectedCursorW = 2 * cellW + 8  // 708
        XCTAssertEqual(cursor.frame.width, expectedCursorW, accuracy: 1)

        // Claude and Terminal should be in right half
        XCTAssertGreaterThan(claude.frame.origin.x, cursor.frame.maxX)
        XCTAssertGreaterThan(terminal.frame.origin.x, cursor.frame.maxX)

        // Claude above Terminal
        XCTAssertLessThan(claude.frame.origin.y, terminal.frame.origin.y)
    }

    func testZeroGap() {
        let layout = LayoutConfig(rows: 1, cols: 2, hotkey: "cmd+shift+1", gap: 0, tiles: [
            TileConfig(app: "com.a", row: 0, col: 0),
            TileConfig(app: "com.b", row: 0, col: 1),
        ])

        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "test", screenFrame: screenFrame, globalGap: 0
        )

        // With 0 gap, each tile is exactly half the screen
        XCTAssertEqual(resolved.tiles[0].frame.origin.x, 0, accuracy: 1)
        XCTAssertEqual(resolved.tiles[0].frame.width, 500, accuracy: 1)
        XCTAssertEqual(resolved.tiles[1].frame.origin.x, 500, accuracy: 1)
        XCTAssertEqual(resolved.tiles[1].frame.width, 500, accuracy: 1)
    }

    func testSingleTileFullScreen() {
        let layout = LayoutConfig(rows: 1, cols: 1, hotkey: "cmd+shift+1", tiles: [
            TileConfig(app: "com.app", row: 0, col: 0),
        ])

        let screenFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "test", screenFrame: screenFrame, globalGap: 8
        )

        let tile = resolved.tiles[0]
        // Should fill screen minus gaps on all sides
        XCTAssertEqual(tile.frame.origin.x, 8, accuracy: 1)
        XCTAssertEqual(tile.frame.origin.y, 33, accuracy: 1)
        XCTAssertEqual(tile.frame.width, 1440 - 16, accuracy: 1)
        XCTAssertEqual(tile.frame.height, 875 - 16, accuracy: 1)
    }

    // MARK: - Coordinate System

    func testAXCoordinateConversion() {
        // Verify that row 0 maps to the top of the screen in AX coordinates
        let layout = LayoutConfig(rows: 2, cols: 1, hotkey: "cmd+shift+1", tiles: [
            TileConfig(app: "com.top", label: "Top", row: 0, col: 0),
            TileConfig(app: "com.bottom", label: "Bottom", row: 1, col: 0),
        ])

        let screenFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "test", screenFrame: screenFrame, globalGap: 8
        )

        let top = resolved.tiles[0]
        let bottom = resolved.tiles[1]

        // In AX coordinates (y increases downward), row 0 should have smaller y
        XCTAssertLessThan(top.frame.origin.y, bottom.frame.origin.y)
    }

    func testLayoutGapOverridesGlobal() {
        let layout = LayoutConfig(rows: 1, cols: 2, hotkey: "cmd+shift+1", gap: 20, tiles: [
            TileConfig(app: "com.a", row: 0, col: 0),
            TileConfig(app: "com.b", row: 0, col: 1),
        ])

        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let resolved = LayoutEngine.resolve(
            layout: layout, layoutName: "test", screenFrame: screenFrame, globalGap: 8
        )

        // The layout gap (20) should be used, not global (8)
        XCTAssertEqual(resolved.tiles[0].frame.origin.x, 20, accuracy: 1)
    }
}
