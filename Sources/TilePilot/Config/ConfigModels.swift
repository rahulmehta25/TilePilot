import Foundation
import AppKit

// MARK: - Config Root

struct TilePilotConfig: Codable {
    var general: GeneralConfig
    var layout: [String: LayoutConfig]

    enum CodingKeys: String, CodingKey {
        case general
        case layout
    }

    init(general: GeneralConfig = GeneralConfig(), layouts: [String: LayoutConfig] = [:]) {
        self.general = general
        self.layout = layouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.general = try container.decodeIfPresent(GeneralConfig.self, forKey: .general) ?? GeneralConfig()
        self.layout = try container.decodeIfPresent([String: LayoutConfig].self, forKey: .layout) ?? [:]
    }

    var layouts: [String: LayoutConfig] {
        get { layout }
        set { layout = newValue }
    }
}

struct GeneralConfig: Codable {
    var gap: Int
    var animate: Bool
    var animationDurationMs: Int

    enum CodingKeys: String, CodingKey {
        case gap
        case animate
        case animationDurationMs = "animation_duration_ms"
    }

    init(gap: Int = 8, animate: Bool = false, animationDurationMs: Int = 200) {
        self.gap = gap
        self.animate = animate
        self.animationDurationMs = animationDurationMs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gap = try container.decodeIfPresent(Int.self, forKey: .gap) ?? 8
        self.animate = try container.decodeIfPresent(Bool.self, forKey: .animate) ?? false
        self.animationDurationMs = try container.decodeIfPresent(Int.self, forKey: .animationDurationMs) ?? 200
    }
}

// MARK: - Layout

struct LayoutConfig: Codable {
    var monitor: String?
    var rows: Int
    var cols: Int
    var hotkey: String
    var gap: Int?
    var tiles: [TileConfig]

    init(monitor: String? = nil, rows: Int, cols: Int, hotkey: String, gap: Int? = nil, tiles: [TileConfig] = []) {
        self.monitor = monitor
        self.rows = rows
        self.cols = cols
        self.hotkey = hotkey
        self.gap = gap
        self.tiles = tiles
    }

    enum CodingKeys: String, CodingKey {
        case monitor, rows, cols, hotkey, gap, tiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.monitor = try container.decodeIfPresent(String.self, forKey: .monitor)
        self.rows = try container.decode(Int.self, forKey: .rows)
        self.cols = try container.decode(Int.self, forKey: .cols)
        self.hotkey = try container.decode(String.self, forKey: .hotkey)
        self.gap = try container.decodeIfPresent(Int.self, forKey: .gap)
        self.tiles = try container.decodeIfPresent([TileConfig].self, forKey: .tiles) ?? []
    }
}

struct TileConfig: Codable {
    var app: String
    var label: String?
    var windowTitleContains: String?
    var row: Int
    var col: Int
    var rowSpan: Int
    var colSpan: Int

    enum CodingKeys: String, CodingKey {
        case app, label, row, col
        case windowTitleContains = "window_title_contains"
        case rowSpan = "row_span"
        case colSpan = "col_span"
    }

    init(app: String, label: String? = nil, windowTitleContains: String? = nil,
         row: Int, col: Int, rowSpan: Int = 1, colSpan: Int = 1) {
        self.app = app
        self.label = label
        self.windowTitleContains = windowTitleContains
        self.row = row
        self.col = col
        self.rowSpan = rowSpan
        self.colSpan = colSpan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decode(String.self, forKey: .app)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.windowTitleContains = try container.decodeIfPresent(String.self, forKey: .windowTitleContains)
        self.row = try container.decode(Int.self, forKey: .row)
        self.col = try container.decode(Int.self, forKey: .col)
        self.rowSpan = try container.decodeIfPresent(Int.self, forKey: .rowSpan) ?? 1
        self.colSpan = try container.decodeIfPresent(Int.self, forKey: .colSpan) ?? 1
    }
}

// MARK: - Computed at Runtime

struct ResolvedTile {
    let bundleID: String
    let label: String
    let frame: CGRect
    let windowTitleFilter: String?
}

struct ResolvedLayout {
    let name: String
    let monitorName: String?
    let tiles: [ResolvedTile]
    let hotkeyString: String
}
