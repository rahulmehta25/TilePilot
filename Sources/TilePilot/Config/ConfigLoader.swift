import Foundation
import TOMLKit

final class ConfigLoader {
    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/tilepilot")
    static let configFilePath = configDirectory.appendingPathComponent("config.toml")

    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private(set) var currentConfig: TilePilotConfig?
    private(set) var lastValidationErrors: [String] = []

    var onConfigReloaded: ((TilePilotConfig) -> Void)?
    var onConfigError: ((String) -> Void)?

    // MARK: - Load

    func loadConfig() -> TilePilotConfig? {
        let path = Self.configFilePath.path
        guard FileManager.default.fileExists(atPath: path) else {
            TilePilotLogger.warning("Config file not found at \(path)")
            ensureDefaultConfig()
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return loadConfig()
        }

        do {
            let tomlString = try String(contentsOfFile: path, encoding: .utf8)
            let config = try parseConfig(tomlString)
            currentConfig = config
            TilePilotLogger.info("Loaded config with \(config.layouts.count) layouts")
            return config
        } catch {
            let message = "Failed to parse config: \(error.localizedDescription)"
            TilePilotLogger.error(message)
            onConfigError?(message)
            return nil
        }
    }

    // MARK: - Parse TOML via Codable

    func parseConfig(_ tomlString: String) throws -> TilePilotConfig {
        let decoder = TOMLDecoder()
        var config = try decoder.decode(TilePilotConfig.self, from: tomlString)
        let result = validate(config)

        lastValidationErrors = result.errors
        for error in result.errors {
            TilePilotLogger.error(error)
        }

        config.layout = result.validLayouts
        return config
    }

    // MARK: - Validate

    struct ValidationResult {
        let validLayouts: [String: LayoutConfig]
        let errors: [String]
    }

    func validate(_ config: TilePilotConfig) -> ValidationResult {
        var validLayouts: [String: LayoutConfig] = [:]
        var errors: [String] = []
        var seenHotkeys: [String: String] = [:]

        for (name, layout) in config.layouts {
            var layoutValid = true

            for tile in layout.tiles {
                if tile.row + tile.rowSpan > layout.rows {
                    errors.append("Layout '\(name)': tile out of bounds - row \(tile.row) + rowSpan \(tile.rowSpan) exceeds \(layout.rows) rows")
                    layoutValid = false
                }
                if tile.col + tile.colSpan > layout.cols {
                    errors.append("Layout '\(name)': tile out of bounds - col \(tile.col) + colSpan \(tile.colSpan) exceeds \(layout.cols) cols")
                    layoutValid = false
                }
            }

            // Check overlapping tiles
            for i in 0..<layout.tiles.count {
                for j in (i+1)..<layout.tiles.count {
                    let a = layout.tiles[i]
                    let b = layout.tiles[j]
                    if tilesOverlap(a, b) {
                        errors.append("Layout '\(name)': overlapping tiles for '\(a.app)' and '\(b.app)'")
                        layoutValid = false
                    }
                }
            }

            // Check duplicate hotkeys
            if let existing = seenHotkeys[layout.hotkey] {
                errors.append("Duplicate hotkey '\(layout.hotkey)' in layouts '\(existing)' and '\(name)'")
                layoutValid = false
            }

            if layoutValid {
                seenHotkeys[layout.hotkey] = name
                validLayouts[name] = layout
            }
        }

        return ValidationResult(validLayouts: validLayouts, errors: errors)
    }

    private func tilesOverlap(_ a: TileConfig, _ b: TileConfig) -> Bool {
        let aRight = a.col + a.colSpan
        let aBottom = a.row + a.rowSpan
        let bRight = b.col + b.colSpan
        let bBottom = b.row + b.rowSpan

        return a.col < bRight && aRight > b.col && a.row < bBottom && aBottom > b.row
    }

    // MARK: - File Watching

    func startWatching() {
        let dirPath = Self.configDirectory.path
        guard FileManager.default.fileExists(atPath: dirPath) else { return }

        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else {
            TilePilotLogger.error("Failed to open config directory for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.debounceReload()
        }

        source.setCancelHandler {
            close(fd)
        }

        fileWatcherSource = source
        source.resume()
        TilePilotLogger.info("Watching config directory for changes")
    }

    func stopWatching() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
    }

    private func debounceReload() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            TilePilotLogger.info("Config file changed, reloading...")
            if let config = self.loadConfig() {
                self.onConfigReloaded?(config)
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Default Config

    func ensureDefaultConfig() {
        let dir = Self.configDirectory
        let file = Self.configFilePath

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        if !FileManager.default.fileExists(atPath: file.path) {
            if let bundledURL = Bundle.module.url(forResource: "DefaultConfig", withExtension: "toml"),
               let content = try? String(contentsOf: bundledURL, encoding: .utf8) {
                try? content.write(to: file, atomically: true, encoding: .utf8)
                TilePilotLogger.info("Created default config at \(file.path)")
                NotificationHelper.configFileMissing(path: file.path)
            }
        }
    }
}

// MARK: - Errors

enum ConfigError: LocalizedError {
    case tileOutOfBounds(layout: String, detail: String)
    case overlappingTiles(layout: String, appA: String, appB: String)
    case duplicateHotkey(hotkey: String, layoutA: String, layoutB: String)

    var errorDescription: String? {
        switch self {
        case .tileOutOfBounds(let layout, let detail):
            return "Layout '\(layout)': tile out of bounds - \(detail)"
        case .overlappingTiles(let layout, let appA, let appB):
            return "Layout '\(layout)': overlapping tiles for '\(appA)' and '\(appB)'"
        case .duplicateHotkey(let hotkey, let layoutA, let layoutB):
            return "Duplicate hotkey '\(hotkey)' in layouts '\(layoutA)' and '\(layoutB)'"
        }
    }
}
