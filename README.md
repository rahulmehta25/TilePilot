# TilePilot

A native macOS window tiler. Declarative layouts, keyboard-first, zero telemetry. Built in Swift, uses AppKit and the Accessibility API (`AXUIElement`) directly.

## Why this exists

macOS has gestured at window tiling since Sequoia, but the system tiler still misses the basics: no memorized layouts, no keyboard primitives, no quick restore. Rectangle and Magnet are great for reactive snapping. Amethyst and yabai are great if you want an opinionated layout engine. TilePilot sits in the gap: you declare the desired state in a config file, bind one hotkey per layout, and press it.

```
cmd+shift+1  ->  Deep Work     Cursor 60% | Claude 25% | Terminal 15%
cmd+shift+2  ->  Founder Mode  Linear | Arc | Slack | Spotify
cmd+shift+3  ->  Chill         Spotify 50% | Arc 50%
```

Think of it as infrastructure-as-code for your desktop.

## Tech

- Swift 5.9, AppKit, SwiftUI for the menu bar and settings surfaces
- Accessibility API (`AXUIElement`) for window manipulation
- TOML config with FSEvents hot reload, no polling
- Event-driven: 0% CPU at idle, under 15 MB memory
- HotKey package for global hotkeys, SMAppService for launch-at-login
- No account, no telemetry, no cloud sync

## Install

Homebrew:

```bash
brew install --cask tilepilot
```

Or download the signed, notarized DMG from [GitHub Releases](https://github.com/rahulmehta25/TilePilot/releases).

Build from source:

```bash
git clone https://github.com/rahulmehta25/TilePilot.git
cd TilePilot
make build
make install
```

Requirements: macOS 13 (Ventura) or later, Swift 5.9+, Xcode Command Line Tools.

## Quick start

1. Launch TilePilot. It appears as a grid icon in your menu bar.
2. Grant Accessibility access when prompted (System Settings > Privacy and Security > Accessibility). TilePilot needs it to move other apps' windows.
3. Open the starter config at `~/.config/tilepilot/config.toml`:

```toml
[general]
gap = 8

[layout.deep-work]
rows = 2
cols = 4
hotkey = "cmd+shift+1"

[[layout.deep-work.tiles]]
app = "com.todesktop.230313mzl4w4u92"  # Cursor
row = 0
col = 0
row_span = 2
col_span = 2

[[layout.deep-work.tiles]]
app = "com.anthropic.claude"
row = 0
col = 2
row_span = 1
col_span = 2

[[layout.deep-work.tiles]]
app = "com.googlecode.iterm2"
row = 1
col = 2
row_span = 1
col_span = 2
```

4. Save. TilePilot hot-reloads automatically.
5. Press `cmd+shift+1`. Windows snap into place.

Finding bundle IDs:

```bash
osascript -e 'id of app "Arc"'
```

The [full configuration reference](docs/CONFIGURATION.md) covers every option, monitor targeting, window title filtering, per-layout gap overrides, and a bundle ID cheat sheet.

## Permissions

TilePilot needs Accessibility access to move windows. The onboarding walks you through enabling it in one place. No other permissions are requested, ever.

## Screenshots

![2x2 grid layout in action](docs/screenshots/grid.png)
![Onboarding accessibility permission flow](docs/screenshots/onboarding.png)
![Menu bar with active tile mode indicator](docs/screenshots/menubar.png)

## Architecture

Pure Swift Package Manager project targeting macOS 13+. Event-driven with three sources: global hotkey presses, config file changes (GCD `DispatchSource` with 500 ms debounce), and display connect/disconnect notifications. `ConfigLoader` parses TOML, `LayoutEngine` resolves tiles into pixel-perfect `CGRect` frames (handling Cocoa-to-AX coordinate conversion), `WindowManager` applies them via the Accessibility API.

Full detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development

```bash
swift build          # debug build
swift run            # run the app
swift test           # run tests
make build           # release build
make clean
```

Dependencies (resolved by SPM):

- [TOMLKit](https://github.com/LebJe/TOMLKit)
- [HotKey](https://github.com/soffes/HotKey)

## FAQ

**Does it drain battery?** No. Fully event-driven. 0% CPU at idle, under 15 MB memory.

**What if an app in a layout isn't running?** TilePilot skips it silently and tiles everything else. It will not launch apps for you.

**Multi-monitor?** Yes. Set `monitor` on a layout to target a display by name. Falls back to the main display if the target is disconnected.

**Stage Manager / Spaces?** Operates within the current Space. Does not switch Spaces or touch Stage Manager.

**Can I undo a layout?** Yes. TilePilot snapshots window positions before applying. Use "Restore Previous" in the menu bar.

**Hotkey conflict with another app?** Change the hotkey in your config. TilePilot detects duplicates within your config but cannot see other apps' bindings.

## License

[MIT](LICENSE).

Built by [Rahul Mehta](https://github.com/rahulmehta25).
