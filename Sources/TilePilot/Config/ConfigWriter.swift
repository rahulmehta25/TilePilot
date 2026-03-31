import Foundation
import TOMLKit

enum ConfigWriter {

    /// Update a single layout in the TOML config file, preserving other sections.
    static func updateLayout(name: String, layout: LayoutConfig, in configPath: String) throws {
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        let table = try TOMLTable(string: content)

        let layoutSection: TOMLTable
        if let existing = table["layout"]?.table {
            layoutSection = existing
        } else {
            layoutSection = TOMLTable()
            table["layout"] = layoutSection
        }

        let entry = TOMLTable()
        if let monitor = layout.monitor {
            entry["monitor"] = monitor
        }
        entry["rows"] = layout.rows
        entry["cols"] = layout.cols
        entry["hotkey"] = layout.hotkey
        if let gap = layout.gap {
            entry["gap"] = gap
        }

        let tilesArray = TOMLArray()
        for tile in layout.tiles {
            let tileTable = TOMLTable(inline: false)
            tileTable["app"] = tile.app
            if let label = tile.label {
                tileTable["label"] = label
            }
            if let titleFilter = tile.windowTitleContains {
                tileTable["window_title_contains"] = titleFilter
            }
            tileTable["row"] = tile.row
            tileTable["col"] = tile.col
            tileTable["row_span"] = tile.rowSpan
            tileTable["col_span"] = tile.colSpan
            tilesArray.append(tileTable)
        }
        entry["tiles"] = tilesArray

        layoutSection[name] = entry

        let output = table.convert(to: .toml)
        try output.write(toFile: configPath, atomically: true, encoding: .utf8)

        TilePilotLogger.configInfo("Saved layout '\(name)' to \(configPath)")
    }

    /// Write the full config (general + all layouts) to disk, replacing existing content.
    static func writeFullConfig(_ config: TilePilotConfig, to configPath: String) throws {
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        let table = try TOMLTable(string: content)

        // Rebuild the layout section from scratch
        let layoutSection = TOMLTable()
        for (name, layout) in config.layouts {
            let entry = TOMLTable()
            if let monitor = layout.monitor {
                entry["monitor"] = monitor
            }
            entry["rows"] = layout.rows
            entry["cols"] = layout.cols
            entry["hotkey"] = layout.hotkey
            if let gap = layout.gap {
                entry["gap"] = gap
            }

            let tilesArray = TOMLArray()
            for tile in layout.tiles {
                let tileTable = TOMLTable(inline: false)
                tileTable["app"] = tile.app
                if let label = tile.label {
                    tileTable["label"] = label
                }
                if let titleFilter = tile.windowTitleContains {
                    tileTable["window_title_contains"] = titleFilter
                }
                tileTable["row"] = tile.row
                tileTable["col"] = tile.col
                tileTable["row_span"] = tile.rowSpan
                tileTable["col_span"] = tile.colSpan
                tilesArray.append(tileTable)
            }
            entry["tiles"] = tilesArray
            layoutSection[name] = entry
        }

        table["layout"] = layoutSection

        let output = table.convert(to: .toml)
        try output.write(toFile: configPath, atomically: true, encoding: .utf8)

        TilePilotLogger.configInfo("Saved full config with \(config.layouts.count) layouts to \(configPath)")
    }
}

enum ConfigWriterError: LocalizedError {
    case missingLayoutSection

    var errorDescription: String? {
        switch self {
        case .missingLayoutSection:
            return "Config file has no [layout] section"
        }
    }
}
