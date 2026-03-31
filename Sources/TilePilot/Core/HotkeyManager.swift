import Foundation
import AppKit
import Carbon
import HotKey

final class HotkeyManager {

    private var registeredHotkeys: [String: HotKey] = [:]
    var onHotkeyTriggered: ((String) -> Void)?

    /// Register hotkeys for all layouts in a config
    func registerAll(from config: TilePilotConfig) {
        unregisterAll()

        for (name, layout) in config.layouts {
            register(layoutName: name, hotkeyString: layout.hotkey)
        }

        registerLayoutPickerHotkey()
        TilePilotLogger.info("Registered \(registeredHotkeys.count) hotkeys")
    }

    /// Register Cmd+Shift+L to activate the menu bar layout picker
    private func registerLayoutPickerHotkey() {
        let hotkey = HotKey(key: .l, modifiers: [.command, .shift])
        hotkey.keyDownHandler = { [weak self] in
            TilePilotLogger.info("Layout picker hotkey triggered")
            self?.onHotkeyTriggered?("__layout-picker")
        }
        registeredHotkeys["__layout-picker"] = hotkey
    }

    /// Register a single hotkey for a layout
    func register(layoutName: String, hotkeyString: String) {
        guard let (key, modifiers) = parseHotkey(hotkeyString) else {
            TilePilotLogger.warning("Failed to parse hotkey '\(hotkeyString)' for layout '\(layoutName)'")
            return
        }

        let hotkey = HotKey(key: key, modifiers: modifiers)
        hotkey.keyDownHandler = { [weak self] in
            TilePilotLogger.info("Hotkey triggered: \(hotkeyString) -> \(layoutName)")
            self?.onHotkeyTriggered?(layoutName)
        }

        registeredHotkeys[layoutName] = hotkey
        TilePilotLogger.info("Registered hotkey \(hotkeyString) for '\(layoutName)'")
    }

    /// Unregister all hotkeys
    func unregisterAll() {
        registeredHotkeys.removeAll()
    }

    /// Parse a hotkey string like "cmd+shift+1" into Key + NSEvent.ModifierFlags
    func parseHotkey(_ str: String) -> (Key, NSEvent.ModifierFlags)? {
        let parts = str.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var keyPart: String?

        for part in parts {
            switch part {
            case "cmd", "command", "meta":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "alt", "opt", "option":
                modifiers.insert(.option)
            default:
                keyPart = part
            }
        }

        guard let keyString = keyPart, let key = keyFromString(keyString) else {
            return nil
        }

        return (key, modifiers)
    }

    private func keyFromString(_ str: String) -> Key? {
        switch str {
        case "0": return .zero
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        case "f1": return .f1
        case "f2": return .f2
        case "f3": return .f3
        case "f4": return .f4
        case "f5": return .f5
        case "f6": return .f6
        case "f7": return .f7
        case "f8": return .f8
        case "f9": return .f9
        case "f10": return .f10
        case "f11": return .f11
        case "f12": return .f12
        case "space": return .space
        case "tab": return .tab
        case "return", "enter": return .return
        case "escape", "esc": return .escape
        case "delete", "backspace": return .delete
        case "left": return .leftArrow
        case "right": return .rightArrow
        case "up": return .upArrow
        case "down": return .downArrow
        default: return nil
        }
    }

    /// Format a hotkey string for display with symbols
    static func displayString(for hotkeyString: String) -> String {
        let parts = hotkeyString.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        var result = ""

        for part in parts {
            switch part {
            case "cmd", "command", "meta": result += "\u{2318}"
            case "shift": result += "\u{21E7}"
            case "ctrl", "control": result += "\u{2303}"
            case "alt", "opt", "option": result += "\u{2325}"
            default: result += part.uppercased()
            }
        }

        return result
    }
}
