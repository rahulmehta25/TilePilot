import SwiftUI
import AppKit
import Carbon

struct HotkeyRecorderView: View {
    @Binding var hotkeyString: String
    var existingLayoutName: String?
    var onConflict: ((String) -> Void)?

    @EnvironmentObject private var appState: AppState
    @State private var isRecording = false
    @State private var pulseAnimation = false
    @State private var conflictWarning: String?

    private static let systemHotkeys: Set<String> = [
        "cmd+c", "cmd+v", "cmd+x", "cmd+z", "cmd+q", "cmd+w",
        "cmd+tab", "cmd+space", "cmd+h", "cmd+m",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                recordButton
            }

            if let warning = conflictWarning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(warning)
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: conflictWarning)
            }
        }
    }

    private var recordButton: some View {
        Button {
            isRecording.toggle()
            pulseAnimation = isRecording
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text("Press keys...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else if hotkeyString.isEmpty {
                    Text("Click to record")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(HotkeyManager.displayString(for: hotkeyString))
                        .font(.system(size: 12, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
            .frame(minWidth: 120)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isRecording ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isRecording ? 2 : 1
                            )
                            .opacity(isRecording && pulseAnimation ? 0.4 : 1.0)
                            .animation(
                                isRecording
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .default,
                                value: pulseAnimation
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .overlay {
            if isRecording {
                HotkeyEventCatcher { event in
                    handleNSEvent(event)
                }
                .frame(width: 0, height: 0)
            }
        }
    }

    // MARK: - Event Handling

    private func handleNSEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        if isModifierOnlyKeyCode(keyCode) { return }
        guard !modifiers.isEmpty else { return }

        let combo = buildHotkeyString(modifiers: modifiers, keyCode: keyCode)
        guard !combo.isEmpty else { return }

        if let existingLayoutName,
           let conflict = checkConflict(combo, excludingLayout: existingLayoutName) {
            conflictWarning = "Conflicts with \(conflict)"
            onConflict?(conflict)
        } else {
            conflictWarning = nil
        }

        hotkeyString = combo
        isRecording = false
        pulseAnimation = false
    }

    private func checkConflict(_ hotkey: String, excludingLayout: String) -> String? {
        let normalized = hotkey.lowercased()

        if Self.systemHotkeys.contains(normalized) {
            return "system shortcut (\(hotkey))"
        }

        for (name, layout) in appState.config.layouts where name != excludingLayout {
            if layout.hotkey.lowercased() == normalized {
                return name
            }
        }

        return nil
    }

    private func isModifierOnlyKeyCode(_ keyCode: UInt16) -> Bool {
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 60, 58, 61, 59, 62, 57, 63]
        return modifierKeyCodes.contains(keyCode)
    }

    private func buildHotkeyString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("alt") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("cmd") }

        if let keyName = keyName(for: keyCode) {
            parts.append(keyName)
        } else {
            return ""
        }
        return parts.joined(separator: "+")
    }

    private func keyName(for keyCode: UInt16) -> String? {
        let keyMap: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
            37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
            48: "tab", 49: "space", 50: "`", 51: "delete",
            53: "escape", 36: "return",
            96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8",
            101: "f9", 103: "f11", 109: "f10", 111: "f12",
            118: "f4", 120: "f2", 122: "f1",
            123: "left", 124: "right", 125: "down", 126: "up",
        ]
        return keyMap[keyCode]
    }
}

// MARK: - NSEvent Catcher

struct HotkeyEventCatcher: NSViewRepresentable {
    let onEvent: (NSEvent) -> Void

    func makeNSView(context: Context) -> HotkeyEventCatcherView {
        let view = HotkeyEventCatcherView()
        view.onEvent = onEvent
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyEventCatcherView, context: Context) {
        nsView.onEvent = onEvent
    }
}

final class HotkeyEventCatcherView: NSView {
    var onEvent: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onEvent?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore modifier-only events
    }
}
