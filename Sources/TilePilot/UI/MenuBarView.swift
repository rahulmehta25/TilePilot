import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        // Layout items
        ForEach(sortedLayoutNames, id: \.self) { name in
            layoutButton(name: name)
        }

        if !sortedLayoutNames.isEmpty {
            Divider()
        }

        Button {
            appState.restorePrevious()
        } label: {
            Label("Restore Previous", systemImage: "arrow.uturn.backward")
        }
        .disabled(!appState.hasSnapshot)

        Divider()

        Button {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            let configPath = ConfigLoader.configFilePath.path
            if let editor = ProcessInfo.processInfo.environment["EDITOR"] {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [editor, configPath]
                try? process.run()
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
            }
        } label: {
            Label("Edit Config...", systemImage: "pencil")
        }

        Button {
            appState.reloadConfig()
        } label: {
            Label("Reload Config", systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r", modifiers: .command)

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit TilePilot", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Layout Button

    private func layoutButton(name: String) -> some View {
        Button {
            let msg = "[TilePilot \(Date())] Menu button clicked: '\(name)'\n"
            try? msg.write(toFile: "/tmp/tilepilot-debug.log", atomically: false, encoding: .utf8)
            appState.applyLayout(named: name)
        } label: {
            HStack {
                Image(systemName: appState.activeLayoutName == name ? "checkmark" : "rectangle.split.3x3")
                    .font(.system(size: 11))
                    .frame(width: 16)

                Text(displayName(for: name))

                Spacer()

                if let layout = appState.config.layouts[name], !layout.hotkey.isEmpty {
                    Text(HotkeyManager.displayString(for: layout.hotkey))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
    }

    // MARK: - Helpers

    private var sortedLayoutNames: [String] {
        appState.config.layouts.keys.sorted()
    }

    private func displayName(for key: String) -> String {
        key.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
