# TilePilot Activity Log

## 2026-03-24 04:15 EST

### User Prompt
"Create comprehensive documentation: README.md, docs/ARCHITECTURE.md, docs/CONFIGURATION.md, LICENSE, Makefile"

### Actions Taken
- Created README.md: polished open-source README with hero section, features list, install/quick start, config guide, bundle ID reference, architecture overview, build instructions, FAQ, MIT license
- Created docs/ARCHITECTURE.md: system overview ASCII diagram, component breakdown (AppState, ConfigLoader, LayoutEngine, WindowManager, HotkeyManager, DisplayManager), data flow diagrams (hotkey press, config change, display change), state management, performance design, multi-monitor handling, project structure
- Created docs/CONFIGURATION.md: full TOML schema reference, general settings, layout/tile definitions, hotkey format, bundle ID discovery methods, 7 example configs (deep work, founder mode, chill, design review, multi-monitor, zero gap, minimal), validation rules, tips
- Created LICENSE: MIT license, Rahul Mehta, 2026
- Created Makefile: build, install, uninstall, clean, test, run, lint, format, dmg, resolve, update targets

## 2026-03-24 03:30 EST

### User Prompt
"Build TilePilot using the PRD file I have provided you with."

### Actions Taken
- Fixed Package.swift: corrected resource path, added test target with ApplicationServices framework
- Switched ConfigLoader from manual TOMLTable parsing to TOMLDecoder Codable decoding
- Added Codable conformance to all config models with CodingKeys for snake_case mapping and decodeIfPresent for optional fields with defaults
- Fixed critical coordinate system bug: LayoutEngine now converts NSScreen.visibleFrame (Cocoa bottom-left origin) to AX coordinates (top-left origin) via visibleFrameInAXCoordinates()
- Removed row-flip hack from LayoutEngine, grid math now works directly in AX coordinates
- Added NSApp.setActivationPolicy(.accessory) to AppDelegate to hide app from Dock
- Added isFullScreen check to WindowManager tile application (both title-filtered and default paths)
- Created SettingsView.swift: 4-tab settings window (General/Layouts/Advanced/About) with login item toggle, gap slider, config export/import, layout editor integration
- Created OnboardingView.swift: 3-step onboarding (welcome, AX permission with polling, success with sample layout)
- Created LayoutEngineTests.swift: 6 tests covering basic grids, spanning tiles, zero gap, single tile, AX coordinate conversion, gap override
- Created ConfigLoaderTests.swift: 10 tests covering valid parsing, defaults, multiple layouts, validation errors (bounds, overlap, duplicate hotkeys), malformed TOML, optional fields
- All 16 tests passing, build clean
- Project: 19 source files, 2 test files, 1 TOML config, ~2,100 lines

## 2026-03-24 03:25 EST

### User Prompt
"Build the ENTIRE Phase 1 core engine + Phase 2 multi-monitor support from scratch using Swift Package Manager."

### Actions Taken
- Created Package.swift with TOMLKit and HotKey dependencies, targeting macOS 13+
- Created Sources/TilePilot/Config/ConfigModels.swift: TilePilotConfig, GeneralConfig, LayoutConfig, TileConfig, ResolvedTile, ResolvedLayout structs
- Created Sources/TilePilot/Config/ConfigLoader.swift: TOML parsing, validation (bounds, overlap, duplicate hotkeys), file watching with 500ms debounce, default config provisioning
- Created Sources/TilePilot/Config/BundleIDResolver.swift: Resolve app names to bundle IDs via NSWorkspace
- Created Sources/TilePilot/Core/LayoutEngine.swift: Grid math computing pixel CGRects from layout config + NSScreen.visibleFrame
- Created Sources/TilePilot/Core/WindowManager.swift: AXUIElement window discovery by bundle ID, position/size application, skip minimized, title filter support
- Created Sources/TilePilot/Core/WindowMatcher.swift: Match running apps to layout tile bundle IDs
- Created Sources/TilePilot/Core/DisplayManager.swift: NSScreen enumeration, name-based matching, screen change observer
- Created Sources/TilePilot/Core/HotkeyManager.swift: Parse hotkey strings, register via HotKey package, full key mapping, display string formatting
- Created Sources/TilePilot/App/TilePilotApp.swift: @main SwiftUI app with MenuBarExtra, AppState with hotkey registration, config reloading, display management
- Created Sources/TilePilot/App/AppDelegate.swift: NSApplicationDelegate with AXIsProcessTrusted() check
- Created Sources/TilePilot/UI/MenuBarView.swift: Layout list with hotkey display, Edit Config, Reload Config, Quit
- Created Sources/TilePilot/UI/LayoutEditorView.swift: Visual grid editor with drag-to-select tiles
- Created Sources/TilePilot/UI/TileAssignmentView.swift: Running app picker for tile assignment
- Created Sources/TilePilot/UI/HotkeyRecorderView.swift: Key combo recorder with NSEvent capture
- Created Sources/TilePilot/Utilities/AXExtensions.swift, CGRectExtensions.swift, Logger.swift
- Created Resources/DefaultConfig.toml: 3 starter layouts with bundle ID reference

## 2026-04-18 13:02 EDT

### User Prompt
"Read CLAUDE.md, then DELTA.md in ~/Desktop/Projects/portfolio-upgrade/tilepilot/. ... Start at the first incomplete item in DELTA.md's 'Delta items (ordered)' section."

### Actions Taken
- Confirmed no App Store listing and no GitHub release for TilePilot; current README messaging (GitHub Releases + Homebrew cask) already matches the DELTA fallback, no change needed for item 1
- Logged out-of-scope or user-input-required items (2, 4, 5, 6, 7, 8) to ~/Desktop/Projects/portfolio-upgrade/_logs/tilepilot.scope-requests.md
- Refreshed README.md per DELTA item 3: trimmed from 271 to 144 lines, kept real declarative-TOML framing and actual keybinds, shortened hero and FAQ, fixed repo URL references
