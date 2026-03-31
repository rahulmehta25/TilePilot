# Configuration Reference

TilePilot is configured via a single TOML file at:

```
~/.config/tilepilot/config.toml
```

TilePilot creates this file with a starter config on first launch. It watches the file for changes and hot-reloads automatically when you save.

## Table of Contents

- [Schema Reference](#schema-reference)
- [General Settings](#general-settings)
- [Layout Definition](#layout-definition)
- [Tile Definition](#tile-definition)
- [Hotkey Format](#hotkey-format)
- [Finding Bundle IDs](#finding-bundle-ids)
- [Example Configs](#example-configs)
- [Multi-Monitor Setup](#multi-monitor-setup)
- [Validation Rules](#validation-rules)
- [Tips](#tips)

---

## Schema Reference

```toml
[general]
gap = 8                    # Pixels between tiles (default: 8)
animate = false            # Animate layout transitions (default: false)
animation_duration_ms = 200 # Animation duration in ms (default: 200)

[layout.<name>]
rows = <int>               # Grid rows (required, 1-8)
cols = <int>               # Grid columns (required, 1-8)
hotkey = "<string>"        # Global hotkey (required, e.g. "cmd+shift+1")
monitor = "<string>"       # Target display name (optional, defaults to main)
gap = <int>                # Per-layout gap override (optional, overrides general.gap)

[[layout.<name>.tiles]]
app = "<bundle-id>"        # macOS bundle identifier (required)
label = "<string>"         # Display name (optional, defaults to bundle ID)
row = <int>                # Grid row, 0-indexed (required)
col = <int>                # Grid column, 0-indexed (required)
row_span = <int>           # How many rows to span (optional, default: 1)
col_span = <int>           # How many columns to span (optional, default: 1)
window_title_contains = "<string>"  # Match specific window by title substring (optional)
```

## General Settings

The `[general]` section controls app-wide defaults.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `gap` | int | `8` | Pixel gap between tiles and screen edges. Set to `0` for no gaps. |
| `animate` | bool | `false` | Whether to animate window transitions. |
| `animation_duration_ms` | int | `200` | Duration of animation in milliseconds. Only applies when `animate = true`. |

```toml
[general]
gap = 12
animate = false
```

## Layout Definition

Each layout is a named section under `[layout.*]`. The name becomes the identifier used in hotkey callbacks and the menu bar dropdown.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `rows` | int | yes | Number of rows in the grid (1-8) |
| `cols` | int | yes | Number of columns in the grid (1-8) |
| `hotkey` | string | yes | Global hotkey to trigger this layout |
| `monitor` | string | no | Target display by name. Falls back to main display if not connected. |
| `gap` | int | no | Override the general gap for this layout only |

Layout names should be lowercase with hyphens: `deep-work`, `founder-mode`, `two-up`.

```toml
[layout.deep-work]
rows = 2
cols = 4
hotkey = "cmd+shift+1"
gap = 10
```

## Tile Definition

Tiles are defined as arrays under each layout using TOML's `[[array]]` syntax.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `app` | string | yes | | macOS bundle identifier |
| `label` | string | no | bundle ID | Human-friendly name shown in the UI |
| `row` | int | yes | | Grid row (0-indexed from top) |
| `col` | int | yes | | Grid column (0-indexed from left) |
| `row_span` | int | no | `1` | Number of rows this tile spans |
| `col_span` | int | no | `1` | Number of columns this tile spans |
| `window_title_contains` | string | no | | Match a specific window whose title contains this substring (case-insensitive) |

### Grid coordinates

The grid is 0-indexed from the top-left corner:

```
         col 0    col 1    col 2    col 3
       ┌────────┬────────┬────────┬────────┐
row 0  │ (0,0)  │ (0,1)  │ (0,2)  │ (0,3)  │
       ├────────┼────────┼────────┼────────┤
row 1  │ (1,0)  │ (1,1)  │ (1,2)  │ (1,3)  │
       └────────┴────────┴────────┴────────┘
```

A tile at `row=0, col=0, row_span=2, col_span=2` occupies the entire left half of a 2x4 grid.

### Window title filtering

Use `window_title_contains` when an app has multiple windows and you want to target a specific one:

```toml
[[layout.research.tiles]]
app = "com.google.Chrome"
label = "Chrome - Docs"
window_title_contains = "Google Docs"
row = 0
col = 0
```

This matches the first Chrome window whose title contains "Google Docs" (case-insensitive).

## Hotkey Format

Hotkeys are strings with modifiers and a key separated by `+`:

```
"cmd+shift+1"
"ctrl+alt+f"
"cmd+shift+left"
```

### Supported modifiers

| Modifier | Aliases |
|----------|---------|
| Command | `cmd`, `command`, `meta` |
| Shift | `shift` |
| Control | `ctrl`, `control` |
| Option | `alt`, `opt`, `option` |

At least one modifier is required.

### Supported keys

| Category | Keys |
|----------|------|
| Letters | `a` through `z` |
| Numbers | `0` through `9` |
| Function keys | `f1` through `f12` |
| Special | `space`, `tab`, `return`/`enter`, `escape`/`esc`, `delete`/`backspace` |
| Arrows | `left`, `right`, `up`, `down` |

### Examples

```
"cmd+shift+1"        # Cmd+Shift+1
"ctrl+alt+a"         # Ctrl+Option+A
"cmd+shift+f5"       # Cmd+Shift+F5
"cmd+ctrl+left"      # Cmd+Ctrl+Left Arrow
"opt+shift+space"    # Option+Shift+Space
```

## Finding Bundle IDs

Every macOS app has a unique bundle identifier. TilePilot uses these to find running applications.

### Using osascript (easiest)

```bash
osascript -e 'id of app "Arc"'
# company.thebrowser.Browser

osascript -e 'id of app "Visual Studio Code"'
# com.microsoft.VSCode

osascript -e 'id of app "Slack"'
# com.tinyspeck.slackmacgap
```

### Using mdls

```bash
mdls -name kMDItemCFBundleIdentifier /Applications/Arc.app
# kMDItemCFBundleIdentifier = "company.thebrowser.Browser"
```

### Common bundle IDs

| App | Bundle ID |
|-----|-----------|
| Arc Browser | `company.thebrowser.Browser` |
| Chrome | `com.google.Chrome` |
| Safari | `com.apple.Safari` |
| Firefox | `org.mozilla.firefox` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| VS Code | `com.microsoft.VSCode` |
| Windsurf | `com.codeium.windsurf` |
| iTerm2 | `com.googlecode.iterm2` |
| Terminal | `com.apple.Terminal` |
| Slack | `com.tinyspeck.slackmacgap` |
| Discord | `com.hnc.Discord` |
| Spotify | `com.spotify.client` |
| Linear | `com.linear` |
| Notion | `notion.id` |
| Figma | `com.figma.Desktop` |
| Obsidian | `md.obsidian` |
| Claude | `com.anthropic.claude` |
| ChatGPT | `com.openai.chat` |
| Messages | `com.apple.MobileSMS` |
| Mail | `com.apple.mail` |
| Calendar | `com.apple.iCal` |
| Notes | `com.apple.Notes` |
| Finder | `com.apple.finder` |
| Preview | `com.apple.Preview` |
| Xcode | `com.apple.dt.Xcode` |

## Example Configs

### Productivity: Deep Work

Editor takes up 60% of the screen, AI assistant and terminal split the remaining 40%.

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

### Productivity: Founder Mode

Four apps in a 2x2 grid for sprint planning and coordination.

```toml
[layout.founder-mode]
rows = 2
cols = 2
hotkey = "cmd+shift+2"

[[layout.founder-mode.tiles]]
app = "com.linear"
label = "Linear"
row = 0
col = 0

[[layout.founder-mode.tiles]]
app = "company.thebrowser.Browser"
label = "Arc"
row = 0
col = 1

[[layout.founder-mode.tiles]]
app = "com.tinyspeck.slackmacgap"
label = "Slack"
row = 1
col = 0

[[layout.founder-mode.tiles]]
app = "com.spotify.client"
label = "Spotify"
row = 1
col = 1
```

### Simple: Half and Half

Two apps side by side.

```toml
[layout.chill]
rows = 1
cols = 2
hotkey = "cmd+shift+3"

[[layout.chill.tiles]]
app = "com.spotify.client"
label = "Spotify"
row = 0
col = 0

[[layout.chill.tiles]]
app = "company.thebrowser.Browser"
label = "Arc"
row = 0
col = 1
```

### Creative: Design Review

Figma large, browser preview medium, Slack narrow on the right.

```toml
[layout.design-review]
rows = 2
cols = 6
hotkey = "cmd+shift+4"
gap = 6

[[layout.design-review.tiles]]
app = "com.figma.Desktop"
label = "Figma"
row = 0
col = 0
row_span = 2
col_span = 3

[[layout.design-review.tiles]]
app = "com.google.Chrome"
label = "Preview"
row = 0
col = 3
row_span = 2
col_span = 2

[[layout.design-review.tiles]]
app = "com.tinyspeck.slackmacgap"
label = "Slack"
row = 0
col = 5
row_span = 2
col_span = 1
```

### Advanced: Multi-Monitor

Target specific displays by name. Use `System Settings > Displays` or run the following to see your display names:

```bash
system_profiler SPDisplaysDataType | grep "Display Type\|Resolution"
```

```toml
[layout.dual-monitor-code]
rows = 1
cols = 2
hotkey = "cmd+shift+5"
monitor = "Built-in Retina Display"

[[layout.dual-monitor-code.tiles]]
app = "com.todesktop.230313mzl4w4u92"
label = "Cursor"
row = 0
col = 0
col_span = 2

[layout.dual-monitor-reference]
rows = 1
cols = 2
hotkey = "cmd+shift+6"
monitor = "LG UltraFine"

[[layout.dual-monitor-reference.tiles]]
app = "com.anthropic.claude"
label = "Claude"
row = 0
col = 0

[[layout.dual-monitor-reference.tiles]]
app = "company.thebrowser.Browser"
label = "Arc"
row = 0
col = 1
```

### Minimal: Zero Gaps

For maximum screen real estate, set gap to 0.

```toml
[general]
gap = 0

[layout.max-screen]
rows = 1
cols = 3
hotkey = "cmd+shift+7"

[[layout.max-screen.tiles]]
app = "com.microsoft.VSCode"
label = "VS Code"
row = 0
col = 0
col_span = 2

[[layout.max-screen.tiles]]
app = "com.apple.Terminal"
label = "Terminal"
row = 0
col = 2
```

## Multi-Monitor Setup

Set the `monitor` field on a layout to target a specific display:

```toml
[layout.external-only]
monitor = "LG UltraFine"
rows = 2
cols = 2
hotkey = "cmd+shift+8"
```

**How monitor matching works:**
1. TilePilot compares the `monitor` value against `NSScreen.localizedName` for each connected display
2. If a match is found, the layout tiles onto that screen
3. If the named monitor isn't connected, falls back to the main display
4. If `monitor` is omitted, the layout always targets the main display

**Finding your display names:**

Your display names appear in System Settings > Displays, or you can check in TilePilot's visual editor (the Monitor dropdown lists all connected displays).

## Validation Rules

TilePilot validates your config on every load and reload. Invalid configs are rejected, and the last valid config stays active.

| Rule | What happens |
|------|-------------|
| Tile `row + row_span > rows` | Layout rejected, error logged |
| Tile `col + col_span > cols` | Layout rejected, error logged |
| Two tiles overlap in the same layout | Layout rejected, error logged |
| Two layouts share the same hotkey | Second layout rejected, error logged |
| Malformed TOML syntax | Entire file rejected, last valid config kept |
| Unknown bundle ID | Allowed (app might be installed later). Tile is skipped at runtime if app isn't running. |

## Tips

**Keep your config in version control.** Symlink or copy `~/.config/tilepilot/config.toml` into your dotfiles repo. Share layouts with your team.

**Use labels.** They make the menu bar dropdown and visual editor much more readable than raw bundle IDs.

**Start simple.** A 1x2 or 2x2 grid covers most use cases. You can always add complexity later.

**Use per-layout gaps.** Tighter gaps for productivity layouts (maximize code), larger gaps for presentation layouts (visual breathing room).

**Backup via Settings.** The Advanced tab in Settings has Export/Import buttons that save your config as a `.toml` file you can share or restore from.
