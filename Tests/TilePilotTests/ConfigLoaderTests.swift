import XCTest
@testable import TilePilot

final class ConfigLoaderTests: XCTestCase {

    let loader = ConfigLoader()

    // MARK: - Valid Config Parsing

    func testParseValidConfig() throws {
        let toml = """
        [general]
        gap = 10
        animate = true
        animation_duration_ms = 300

        [layout.test-layout]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.test-layout.tiles]]
        app = "com.test.app"
        label = "Test"
        row = 0
        col = 0
        row_span = 1
        col_span = 1
        """

        let config = try loader.parseConfig(toml)

        XCTAssertEqual(config.general.gap, 10)
        XCTAssertTrue(config.general.animate)
        XCTAssertEqual(config.general.animationDurationMs, 300)

        XCTAssertEqual(config.layouts.count, 1)
        let layout = config.layouts["test-layout"]
        XCTAssertNotNil(layout)
        XCTAssertEqual(layout?.rows, 2)
        XCTAssertEqual(layout?.cols, 2)
        XCTAssertEqual(layout?.hotkey, "cmd+shift+1")
        XCTAssertEqual(layout?.tiles.count, 1)

        let tile = layout?.tiles[0]
        XCTAssertEqual(tile?.app, "com.test.app")
        XCTAssertEqual(tile?.label, "Test")
        XCTAssertEqual(tile?.row, 0)
        XCTAssertEqual(tile?.col, 0)
    }

    func testParseDefaultValues() throws {
        let toml = """
        [general]

        [layout.minimal]
        rows = 1
        cols = 1
        hotkey = "cmd+shift+9"

        [[layout.minimal.tiles]]
        app = "com.test"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)

        // Defaults
        XCTAssertEqual(config.general.gap, 8)
        XCTAssertFalse(config.general.animate)
        XCTAssertEqual(config.general.animationDurationMs, 200)

        let tile = config.layouts["minimal"]?.tiles[0]
        XCTAssertEqual(tile?.rowSpan, 1)
        XCTAssertEqual(tile?.colSpan, 1)
        XCTAssertNil(tile?.label)
        XCTAssertNil(tile?.windowTitleContains)
    }

    func testParseMultipleLayouts() throws {
        let toml = """
        [layout.a]
        rows = 1
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.a.tiles]]
        app = "com.a"
        row = 0
        col = 0

        [layout.b]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+2"

        [[layout.b.tiles]]
        app = "com.b"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)
        XCTAssertEqual(config.layouts.count, 2)
        XCTAssertNotNil(config.layouts["a"])
        XCTAssertNotNil(config.layouts["b"])
    }

    // MARK: - Validation

    func testTileOutOfBoundsRow() throws {
        let toml = """
        [layout.bad]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.bad.tiles]]
        app = "com.test"
        row = 1
        col = 0
        row_span = 2
        """

        let config = try loader.parseConfig(toml)
        XCTAssertTrue(config.layouts.isEmpty, "Invalid layout should be excluded")
        XCTAssertFalse(loader.lastValidationErrors.isEmpty)
        XCTAssertTrue(loader.lastValidationErrors.first?.contains("out of bounds") == true)
    }

    func testTileOutOfBoundsCol() throws {
        let toml = """
        [layout.bad]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.bad.tiles]]
        app = "com.test"
        row = 0
        col = 1
        col_span = 2
        """

        let config = try loader.parseConfig(toml)
        XCTAssertTrue(config.layouts.isEmpty, "Invalid layout should be excluded")
        XCTAssertFalse(loader.lastValidationErrors.isEmpty)
        XCTAssertTrue(loader.lastValidationErrors.first?.contains("out of bounds") == true)
    }

    func testOverlappingTiles() throws {
        let toml = """
        [layout.bad]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.bad.tiles]]
        app = "com.a"
        row = 0
        col = 0
        row_span = 2
        col_span = 2

        [[layout.bad.tiles]]
        app = "com.b"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)
        XCTAssertTrue(config.layouts.isEmpty, "Invalid layout should be excluded")
        XCTAssertFalse(loader.lastValidationErrors.isEmpty)
        XCTAssertTrue(loader.lastValidationErrors.contains { $0.contains("overlapping") })
    }

    func testDuplicateHotkeys() throws {
        let toml = """
        [layout.a]
        rows = 1
        cols = 1
        hotkey = "cmd+shift+1"

        [[layout.a.tiles]]
        app = "com.a"
        row = 0
        col = 0

        [layout.b]
        rows = 1
        cols = 1
        hotkey = "cmd+shift+1"

        [[layout.b.tiles]]
        app = "com.b"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)
        // First layout keeps its hotkey, second is rejected
        XCTAssertEqual(config.layouts.count, 1, "Only one layout should survive duplicate hotkey")
        XCTAssertFalse(loader.lastValidationErrors.isEmpty)
        XCTAssertTrue(loader.lastValidationErrors.contains { $0.contains("Duplicate hotkey") })
    }

    func testValidLayoutsSurviveAlongsideInvalid() throws {
        let toml = """
        [layout.good]
        rows = 2
        cols = 2
        hotkey = "cmd+shift+1"

        [[layout.good.tiles]]
        app = "com.good"
        row = 0
        col = 0

        [layout.bad]
        rows = 1
        cols = 1
        hotkey = "cmd+shift+2"

        [[layout.bad.tiles]]
        app = "com.bad"
        row = 0
        col = 0
        row_span = 5
        """

        let config = try loader.parseConfig(toml)
        XCTAssertEqual(config.layouts.count, 1)
        XCTAssertNotNil(config.layouts["good"])
        XCTAssertNil(config.layouts["bad"])
        XCTAssertFalse(loader.lastValidationErrors.isEmpty)
    }

    func testMalformedTOML() {
        let toml = "this is not valid toml {{{"
        XCTAssertThrowsError(try loader.parseConfig(toml))
    }

    // MARK: - Optional Fields

    func testLayoutGapOverride() throws {
        let toml = """
        [general]
        gap = 8

        [layout.custom]
        rows = 1
        cols = 2
        hotkey = "cmd+shift+1"
        gap = 16

        [[layout.custom.tiles]]
        app = "com.a"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)
        XCTAssertEqual(config.layouts["custom"]?.gap, 16)
    }

    func testMonitorField() throws {
        let toml = """
        [layout.external]
        rows = 1
        cols = 1
        hotkey = "cmd+shift+1"
        monitor = "LG HDR 4K"

        [[layout.external.tiles]]
        app = "com.a"
        row = 0
        col = 0
        """

        let config = try loader.parseConfig(toml)
        XCTAssertEqual(config.layouts["external"]?.monitor, "LG HDR 4K")
    }
}
