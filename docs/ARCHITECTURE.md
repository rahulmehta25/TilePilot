# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            TilePilot                                    │
│                                                                         │
│  ┌─────────────────┐     ┌──────────────┐     ┌─────────────────────┐  │
│  │   Event Sources  │     │   AppState   │     │        UI           │  │
│  │                  │     │  (Coordinator)│     │                     │  │
│  │  Hotkey Press ───┼────>│              │<────┼── MenuBarView       │  │
│  │  Config Change ──┼────>│   config     │<────┼── SettingsView      │  │
│  │  Display Change ─┼────>│   hotkeys    │<────┼── LayoutEditorView  │  │
│  │                  │     │   displays   │     │   OnboardingView    │  │
│  └─────────────────┘     └──────┬───────┘     └─────────────────────┘  │
│                                 │                                       │
│                    ┌────────────┼────────────┐                          │
│                    v            v            v                          │
│            ┌──────────┐  ┌──────────┐  ┌──────────┐                    │
│            │  Config   │  │  Layout  │  │  Window  │                    │
│            │  Loader   │  │  Engine  │  │  Manager │                    │
│            └─────┬─────┘  └────┬─────┘  └────┬─────┘                   │
│                  │             │              │                          │
│                  v             v              v                          │
│            ┌──────────┐  ┌──────────┐  ┌──────────┐                    │
│            │  TOML    │  │  Screen  │  │   AX     │                    │
│            │  File    │  │  Geometry│  │   API    │                    │
│            └──────────┘  └──────────┘  └──────────┘                    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### AppState (Coordinator)

`Sources/TilePilot/App/TilePilotApp.swift`

The central coordinator. AppState is a `@MainActor ObservableObject` that owns every subsystem and drives the SwiftUI UI via `@Published` properties. It initializes the config loader, hotkey manager, and display manager at launch, and wires their callbacks together.

Key responsibilities:
- Loads config on init, sets up hotkey bindings
- Receives hotkey callbacks and dispatches to LayoutEngine + WindowManager
- Receives config-reload callbacks and re-registers hotkeys
- Manages window position snapshots for undo/restore
- Provides layout preview (apply for 5 seconds, then restore)

### ConfigLoader

`Sources/TilePilot/Config/ConfigLoader.swift`

Reads, parses, validates, and watches the TOML config file at `~/.config/tilepilot/config.toml`.

- **Parsing:** Uses `TOMLKit`'s `TOMLDecoder` to decode TOML directly into `TilePilotConfig` (Codable structs)
- **Validation:** Checks tile bounds (row+rowSpan <= rows, col+colSpan <= cols), detects overlapping tiles via rectangle intersection, and flags duplicate hotkeys across layouts
- **File watching:** Opens the config directory with `O_EVTONLY` and creates a GCD `DispatchSource.makeFileSystemObjectSource` for `.write` events. A 500ms debounce prevents rapid-fire reloads during editor saves.
- **Default config:** On first launch, copies `DefaultConfig.toml` from the app bundle to `~/.config/tilepilot/config.toml`

### LayoutEngine

`Sources/TilePilot/Core/LayoutEngine.swift`

Pure computation, no side effects. Takes a `LayoutConfig` and screen geometry, produces a `ResolvedLayout` with pixel-perfect `CGRect` frames for each tile.

**Grid math:**
```
cellWidth  = (screenWidth  - gap * (cols + 1)) / cols
cellHeight = (screenHeight - gap * (rows + 1)) / rows

tile.x = screenOrigin.x + gap + col * (cellWidth + gap)
tile.y = screenOrigin.y + gap + row * (cellHeight + gap)
tile.w = colSpan * cellWidth  + (colSpan - 1) * gap
tile.h = rowSpan * cellHeight + (rowSpan - 1) * gap
```

Frames are pixel-aligned to avoid subpixel rendering artifacts on Retina displays.

**Coordinate conversion:** macOS has two coordinate systems. Cocoa uses bottom-left origin (y increases upward). The Accessibility API uses top-left origin (y increases downward). LayoutEngine converts between them using the primary screen height as the reference point.

### WindowManager

`Sources/TilePilot/Core/WindowManager.swift`

Applies resolved layouts by moving and resizing windows via the macOS Accessibility API.

For each tile in the resolved layout:
1. Find the running application by bundle ID (`NSWorkspace.shared.runningApplications`)
2. Get the AX application element (`AXUIElementCreateApplication`)
3. Find the target window (first non-minimized, non-fullscreen window, optionally filtered by title)
4. Set position and size via AX attributes
5. Raise the window to front

Windows are applied in reverse order so the first tile in the config ends up visually on top (z-order).

**Skip conditions:** App not running, no windows, all windows minimized/fullscreen, no window matching title filter. All skips are logged but never error.

### HotkeyManager

`Sources/TilePilot/Core/HotkeyManager.swift`

Registers and manages global hotkeys using the [HotKey](https://github.com/soffes/HotKey) package (which wraps Carbon `RegisterEventHotKey`).

- Parses hotkey strings like `"cmd+shift+1"` into `Key` + `NSEvent.ModifierFlags`
- Supports multiple modifier aliases (`cmd`/`command`/`meta`, `ctrl`/`control`, `alt`/`opt`/`option`)
- Re-registers all hotkeys when config reloads (unregister all, then register fresh)
- Provides `displayString(for:)` to render hotkeys with symbols (e.g. "cmd+shift+1" -> "Cmd+Shift+1")

### DisplayManager

`Sources/TilePilot/Core/DisplayManager.swift`

Tracks connected displays and handles monitor changes.

- Observes `NSApplication.didChangeScreenParametersNotification` for display connect/disconnect
- Resolves layout `monitor` fields to `NSScreen` instances by `localizedName`
- Falls back to main display when a named monitor isn't connected
- Posts `TilePilotDisplaysDidChange` notification for other components to observe

## Data Flow

### Hotkey Press (Primary Path)

```
User presses Cmd+Shift+1
        │
        v
HotkeyManager (Carbon event tap)
        │
        │  onHotkeyTriggered("deep-work")
        v
AppState.applyLayout(named: "deep-work")
        │
        ├── 1. Look up LayoutConfig from config.layouts["deep-work"]
        ├── 2. Resolve target screen (DisplayManager)
        ├── 3. LayoutEngine.resolve() -> ResolvedLayout (pixel CGRects)
        ├── 4. Snapshot current window positions (for undo)
        ├── 5. WindowManager.apply() -> move/resize via AX API
        └── 6. Update @Published activeLayoutName (UI reflects)
```

### Config File Change

```
User saves ~/.config/tilepilot/config.toml
        │
        v
DispatchSource (FSEvents, .write on directory)
        │
        │  500ms debounce
        v
ConfigLoader.loadConfig()
        │
        ├── Read file contents
        ├── TOMLDecoder.decode() -> TilePilotConfig
        ├── validate() -> check bounds, overlaps, duplicate hotkeys
        │
        │  onConfigReloaded(newConfig)
        v
AppState
        ├── Update config (triggers SwiftUI re-render)
        └── Re-register all hotkeys via HotkeyManager
```

### Display Change

```
Monitor connected/disconnected
        │
        v
NSApplication.didChangeScreenParametersNotification
        │
        v
DisplayManager.handleScreenChange()
        │
        ├── Refresh NSScreen.screens list
        ├── Log old count -> new count
        └── Post TilePilotDisplaysDidChange
```

## State Management

`AppState` is the single source of truth. It is a `@MainActor` class conforming to `ObservableObject`, injected into the SwiftUI environment via `.environmentObject()`.

**Published properties:**

| Property | Type | Purpose |
|----------|------|---------|
| `config` | `TilePilotConfig` | Current parsed config (layouts, general settings) |
| `activeLayoutName` | `String?` | Currently applied layout, shown in menu bar |
| `hasSnapshot` | `Bool` | Whether there are saved positions to restore |
| `hasCompletedOnboarding` | `Bool` | Persisted to UserDefaults |
| `launchAtLogin` | `Bool` | Backed by SMAppService |

**Owned subsystems:**

| Property | Type | Purpose |
|----------|------|---------|
| `configLoader` | `ConfigLoader` | TOML parsing, validation, file watching |
| `hotkeyManager` | `HotkeyManager` | Global hotkey registration |
| `displayManager` | `DisplayManager` | Multi-monitor tracking |

## Performance Design

TilePilot is designed to be invisible until invoked:

- **Zero polling.** No timers, no `setInterval`, no periodic checks. All activity is triggered by events: hotkey presses, file system changes, display changes, or user interaction.
- **Event-driven file watching.** Uses GCD `DispatchSource` (kernel-level FSEvents), not polling. The 500ms debounce coalesces rapid editor saves.
- **Fast layout application.** LayoutEngine is pure math (microseconds). WindowManager iterates running apps via `NSWorkspace` (no shell commands) and uses AX API calls directly. Target: < 300ms for 6 windows.
- **Pixel alignment.** All computed CGRects are pixel-aligned to avoid triggering subpixel rendering, which can cause visual artifacts and unnecessary compositing.
- **Reverse z-order application.** Tiles are applied in reverse order so the first tile ends up on top. This avoids redundant raise operations.

## Multi-Monitor Handling

Each layout can optionally specify a `monitor` field with a display name (e.g., `"Built-in Retina Display"`, `"LG UltraFine"`).

- `DisplayManager` maintains a live list of connected screens
- On layout application, `DisplayManager.screen(for:)` resolves the monitor name to an `NSScreen`
- If the named monitor isn't connected, falls back to `NSScreen.main`
- `LayoutEngine` computes frames against the resolved screen's `visibleFrame` (which accounts for menu bar, Dock, and notch)
- Coordinate conversion handles the Cocoa/AX coordinate system mismatch per-screen

## Config Format

TOML was chosen over JSON/YAML for developer ergonomics:
- Human-readable without closing braces
- Comments are first-class (great for documenting bundle IDs)
- Dotfiles-friendly (version control, share between machines)
- Well-supported via TOMLKit

See [docs/CONFIGURATION.md](CONFIGURATION.md) for the full schema reference.

## Project Structure

```
TilePilot/
  Package.swift                            # SPM: macOS 13+, TOMLKit, HotKey
  Sources/TilePilot/
    App/
      TilePilotApp.swift                   # @main, MenuBarExtra, AppState
      AppDelegate.swift                    # AX permission check, app lifecycle
    Core/
      LayoutEngine.swift                   # Grid math, coordinate conversion
      WindowManager.swift                  # AX API window manipulation
      WindowMatcher.swift                  # App matching logic
      HotkeyManager.swift                 # Global hotkey registration
      DisplayManager.swift                 # Multi-monitor tracking
    Config/
      ConfigLoader.swift                   # TOML parse, validate, watch
      ConfigModels.swift                   # TilePilotConfig, LayoutConfig, TileConfig
      BundleIDResolver.swift               # App name -> bundle ID resolution
    UI/
      MenuBarView.swift                    # Menu bar dropdown
      SettingsView.swift                   # Settings tabs (General, Layouts, Advanced, About)
      LayoutEditorView.swift               # Visual grid editor with drag-to-define
      TileAssignmentView.swift             # App picker for tile assignment
      HotkeyRecorderView.swift            # Hotkey capture field
      OnboardingView.swift                 # First-run AX permission flow
    Utilities/
      AXExtensions.swift                   # AXUIElement convenience extensions
      CGRectExtensions.swift               # Pixel alignment, frame math
      Logger.swift                         # Structured logging
    Resources/
      DefaultConfig.toml                   # Starter config, bundled with app
  Tests/TilePilotTests/                    # Unit tests
  Makefile
  README.md
  LICENSE
```
