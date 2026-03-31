<p align="center">
  <img src="https://developer.apple.com/sf-symbols/" width="0" height="0" />
  <h1 align="center">TilePilot</h1>
  <p align="center">
    <strong>Declarative window layouts for macOS.</strong><br/>
    Define your screen. One hotkey. Every window snaps into place.
  </p>
  <p align="center">
    <a href="#install">Install</a> &bull;
    <a href="#quick-start">Quick Start</a> &bull;
    <a href="#configuration">Configuration</a> &bull;
    <a href="#architecture">Architecture</a> &bull;
    <a href="docs/CONFIGURATION.md">Full Config Reference</a>
  </p>
</p>

---

TilePilot is a native macOS menu bar app for power users who are tired of dragging windows around. You define named layouts in a simple TOML file, bind each one to a global hotkey, and press it. Every assigned app snaps to its tile instantly. No dragging. No thinking. Just your screen, exactly how you want it.

Think of it as **infrastructure-as-code for your desktop.**

```
Cmd+Shift+1  ->  "Deep Work"     Cursor 60% | Claude 25% | Terminal 15%
Cmd+Shift+2  ->  "Founder Mode"  Linear | Arc | Slack | Spotify
Cmd+Shift+3  ->  "Chill"         Spotify 50% | Arc 50%
```

## What makes TilePilot different

| Tool | How it works | You do |
|------|-------------|--------|
| Rectangle / Magnet | Reactive, per-window | Snap one window at a time |
| yabai / Amethyst | Automatic tiling | Fight the layout engine when it guesses wrong |
| **TilePilot** | **Declarative layouts** | **Define once, press one key, done** |

TilePilot sits in the gap between "I want control" and "I don't want to think about it." You declare the desired state. TilePilot enforces it.

## Features

- **TOML config** at `~/.config/tilepilot/config.toml`, version-controllable and shareable
- **Visual layout editor** with drag-to-define tile regions and live app picker
- **Global hotkeys** that work from any app, any space
- **Multi-monitor support** with per-layout monitor targeting by display name
- **Hot reload** on config file save (FSEvents watcher with debounce, no polling)
- **Zero CPU at idle**, event-driven architecture, no background polling
- **Snapshot and restore** to undo a layout and return windows to previous positions
- **5-second preview** to test a layout before committing
- **Per-layout gap overrides** for fine-tuning spacing
- **Window title filtering** to target specific windows in multi-window apps
- **Config export/import** for backup and sharing
- **Launch at login** via SMAppService
- **Onboarding flow** that walks you through Accessibility permissions and your first layout

## Install

### Homebrew (recommended)

```bash
brew install --cask tilepilot
```

### Download

Grab the latest `.dmg` from [GitHub Releases](https://github.com/rahulmehta25/TilePilot/releases).

### Build from source

```bash
git clone https://github.com/rahulmehta25/TilePilot.git
cd TilePilot
make build
make install  # copies binary to /usr/local/bin
```

**Requirements:** macOS 13 (Ventura) or later, Xcode 15+, Swift 5.9+

## Quick Start

1. **Launch TilePilot.** It appears as a grid icon in your menu bar.

2. **Grant Accessibility access** when prompted (System Settings > Privacy & Security > Accessibility). TilePilot needs this to move other apps' windows.

3. **Edit your config.** TilePilot creates a starter config at `~/.config/tilepilot/config.toml` on first launch. Open it in your editor:

```bash
$EDITOR ~/.config/tilepilot/config.toml
```

4. **Define a layout:**

```toml
[general]
gap = 8

[layout.deep-work]
rows = 2
cols = 4
hotkey = "cmd+shift+1"

[[layout.deep-work.tiles]]
app = "com.todesktop.230313mzl4w4u92"
label = "Cursor"
row = 0
col = 0
row_span = 2
col_span = 2

[[layout.deep-work.tiles]]
app = "com.anthropic.claude"
label = "Claude"
row = 0
col = 2
row_span = 1
col_span = 2

[[layout.deep-work.tiles]]
app = "com.googlecode.iterm2"
label = "Terminal"
row = 1
col = 2
row_span = 1
col_span = 2
```

5. **Save the file.** TilePilot hot-reloads automatically.

6. **Press `Cmd+Shift+1`.** Your windows snap into place.

## Configuration

Config lives at `~/.config/tilepilot/config.toml`. TilePilot watches this file and reloads on save.

See the [full configuration reference](docs/CONFIGURATION.md) for every option, example configs, and tips.

### Finding bundle IDs

```bash
# Any app
osascript -e 'id of app "Arc"'
# -> company.thebrowser.Browser

osascript -e 'id of app "Slack"'
# -> com.tinyspeck.slackmacgap
```

The default config includes a cheat sheet of common bundle IDs.

### Common bundle IDs

| App | Bundle ID |
|-----|-----------|
| Arc | `company.thebrowser.Browser` |
| Chrome | `com.google.Chrome` |
| Safari | `com.apple.Safari` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| VS Code | `com.microsoft.VSCode` |
| iTerm2 | `com.googlecode.iterm2` |
| Terminal | `com.apple.Terminal` |
| Slack | `com.tinyspeck.slackmacgap` |
| Discord | `com.hnc.Discord` |
| Spotify | `com.spotify.client` |
| Linear | `com.linear` |
| Notion | `notion.id` |
| Figma | `com.figma.Desktop` |
| Claude | `com.anthropic.claude` |
| Xcode | `com.apple.dt.Xcode` |

### Hotkey format

Hotkeys are strings like `"cmd+shift+1"`. Supported modifiers:

| Modifier | Aliases |
|----------|---------|
| Command | `cmd`, `command`, `meta` |
| Shift | `shift` |
| Control | `ctrl`, `control` |
| Option | `alt`, `opt`, `option` |

Keys: `a`-`z`, `0`-`9`, `f1`-`f12`, `space`, `tab`, `return`/`enter`, `escape`/`esc`, `delete`/`backspace`, `left`, `right`, `up`, `down`

## Screenshots

[Screenshot: Menu Bar dropdown with layout list]

[Screenshot: Visual Layout Editor with drag-to-define tiles]

[Screenshot: Settings window, General tab]

[Screenshot: Deep Work layout applied, 3 apps tiled]

## Architecture

TilePilot is built as a pure Swift Package Manager project targeting macOS 13+. It uses SwiftUI for all UI (menu bar, settings, visual editor, onboarding) and the macOS Accessibility API (`AXUIElement`) for window manipulation.

The architecture is event-driven with zero polling. At idle, TilePilot consumes no CPU. Three event sources drive all activity: global hotkey presses (via the `HotKey` package and Carbon events), config file changes (via GCD `DispatchSource` file system watching with 500ms debounce), and display connect/disconnect events (via `NSApplication.didChangeScreenParametersNotification`).

The data flow is straightforward: `ConfigLoader` parses TOML into typed Swift structs, `LayoutEngine` resolves those structs into pixel-perfect `CGRect` frames against a target screen (handling Cocoa-to-AX coordinate conversion), and `WindowManager` applies those frames via the Accessibility API. `AppState` is the central coordinator that wires these components together and drives the SwiftUI reactive UI.

For more detail, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Building from source

```bash
# Clone
git clone https://github.com/rahulmehta25/TilePilot.git
cd TilePilot

# Build (release)
swift build -c release

# Run
.build/release/TilePilot

# Run tests
swift test

# Or use the Makefile
make build    # swift build -c release
make test     # swift test
make install  # copy to /usr/local/bin
make clean    # swift package clean
```

**Requirements:**
- macOS 13 (Ventura) or later
- Xcode 15+ (or just the Xcode Command Line Tools)
- Swift 5.9+

**Dependencies** (resolved automatically by SPM):
- [TOMLKit](https://github.com/LebJe/TOMLKit) - TOML parsing
- [HotKey](https://github.com/soffes/HotKey) - Global hotkey registration

## FAQ

**Q: Why does TilePilot need Accessibility permissions?**
The macOS Accessibility API (`AXUIElement`) is the only supported way to programmatically move and resize windows belonging to other applications. Without it, TilePilot can't do its job.

**Q: Will TilePilot drain my battery?**
No. TilePilot is fully event-driven. At idle it uses 0% CPU and under 15 MB of memory. It only wakes up when you press a hotkey, change the config file, or open settings.

**Q: What happens if an app in my layout isn't running?**
TilePilot skips it silently and tiles everything else. It won't launch apps for you.

**Q: Can I use this with multiple monitors?**
Yes. Set the `monitor` field on a layout to target a specific display by name. If the monitor isn't connected, TilePilot falls back to the main display.

**Q: Does it work with Stage Manager / Spaces?**
TilePilot operates within the current macOS Space. It does not switch Spaces or interact with Stage Manager.

**Q: Can I undo a layout?**
Yes. TilePilot snapshots window positions before applying a layout. Use the "Restore Previous" option in the menu bar to put everything back.

**Q: My hotkey conflicts with another app. What do I do?**
Change the hotkey in your config file or use the visual editor. TilePilot validates for duplicate hotkeys within your config but can't detect conflicts with other apps.

**Q: How do I find an app's bundle ID?**
Run `osascript -e 'id of app "App Name"'` in Terminal. The default config also includes a reference list of common bundle IDs.

## License

[MIT](LICENSE)

## Credits

Built by [Rahul Mehta](https://github.com/rahulmehta25).

**Dependencies:**
- [TOMLKit](https://github.com/LebJe/TOMLKit) by Jeff Lebrun
- [HotKey](https://github.com/soffes/HotKey) by Sam Soffes
