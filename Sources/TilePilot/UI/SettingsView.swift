import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Settings Navigation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, layouts, advanced, about

    var id: String { rawValue }

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .layouts: return "rectangle.split.3x3"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .layouts: return .blue
        case .advanced: return .orange
        case .about: return .purple
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralTab().environmentObject(appState)
                case .layouts:
                    LayoutsTab().environmentObject(appState)
                case .advanced:
                    AdvancedTab().environmentObject(appState)
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 660, height: 480)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(tab.iconColor.gradient)
                            )

                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("v\(appVersion)")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .frame(width: 180)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var gapValue: Double = 8
    @State private var animate: Bool = false
    @AppStorage("menuBarIconStyle") private var iconStyle = "grid"
    @AppStorage("menuBarCustomIcon") private var customIcon = "square.grid.2x2"

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $appState.launchAtLogin)
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("Window gap")
                    Spacer()
                    Slider(value: $gapValue, in: 0...20, step: 1)
                        .frame(width: 160)
                    Text("\(Int(gapValue))px")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                        .monospacedDigit()
                }
                .onChange(of: gapValue) { newVal in
                    appState.config.general.gap = Int(newVal)
                }

                Toggle("Animate transitions", isOn: $animate)
                    .onChange(of: animate) { newVal in
                        appState.config.general.animate = newVal
                    }
            } header: {
                Text("Appearance")
            }

            Section {
                Picker("Style", selection: $iconStyle) {
                    Label("Grid", systemImage: "square.grid.2x2").tag("grid")
                    Label("Dot", systemImage: "circle.fill").tag("dot")
                    Label("Custom", systemImage: "star").tag("custom")
                }
                .pickerStyle(.segmented)

                if iconStyle == "custom" {
                    HStack {
                        Text("SF Symbol")
                        Spacer()
                        TextField("square.grid.2x2", text: $customIcon)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                        Image(systemName: customIcon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                }
            } header: {
                Text("Menu Bar Icon")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            gapValue = Double(appState.config.general.gap)
            animate = appState.config.general.animate
        }
    }
}

// MARK: - Layouts Tab

struct LayoutsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLayout: String?
    @State private var showEditor = false
    @State private var editingLayoutName: String?

    private let tilePalette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .brown
    ]

    var body: some View {
        HSplitView {
            layoutList
                .frame(minWidth: 200)

            if let name = selectedLayout, let layout = appState.config.layouts[name] {
                layoutDetail(name: name, layout: layout)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.split.3x3")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("Select a layout")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let name = editingLayoutName {
                LayoutEditorView(
                    layoutName: name,
                    layout: Binding(
                        get: { appState.config.layouts[name] ?? LayoutConfig(rows: 2, cols: 2, hotkey: "cmd+shift+1", tiles: []) },
                        set: { appState.config.layouts[name] = $0 }
                    )
                )
                .environmentObject(appState)
                .frame(minWidth: 620, minHeight: 520)
            }
        }
    }

    // MARK: - Layout List

    private var layoutList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedLayout) {
                ForEach(sortedLayoutNames, id: \.self) { name in
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.split.3x3")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.blue.gradient)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayName(for: name))
                                .font(.system(size: 13, weight: .medium))
                            if let layout = appState.config.layouts[name] {
                                Text("\(layout.tiles.count) tile\(layout.tiles.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let layout = appState.config.layouts[name], !layout.hotkey.isEmpty {
                            Text(HotkeyManager.displayString(for: layout.hotkey))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                    }
                    .tag(name)
                    .contextMenu {
                        Button("Edit...") {
                            editingLayoutName = name
                            showEditor = true
                        }
                        Button("Duplicate") { duplicateLayout(name) }
                        Divider()
                        Button("Delete", role: .destructive) { deleteLayout(name) }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button { addNewLayout() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add layout")

                Button {
                    if let name = selectedLayout { deleteLayout(name) }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedLayout == nil)
                .help("Remove layout")

                Spacer()

                Button("Edit") {
                    if let name = selectedLayout {
                        editingLayoutName = name
                        showEditor = true
                    }
                }
                .disabled(selectedLayout == nil)
            }
            .padding(8)
        }
    }

    // MARK: - Layout Detail

    private func layoutDetail(name: String, layout: LayoutConfig) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(displayName(for: name))
                    .font(.title2)
                    .fontWeight(.semibold)

                // Properties card
                VStack(alignment: .leading, spacing: 0) {
                    Text("DETAILS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("Hotkey")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(HotkeyManager.displayString(for: layout.hotkey))
                                .fontDesign(.monospaced)
                        }
                        GridRow {
                            Text("Grid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(layout.cols) \u{00D7} \(layout.rows)")
                        }
                        GridRow {
                            Text("Gap")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(layout.gap ?? appState.config.general.gap)px")
                        }
                        if let monitor = layout.monitor {
                            GridRow {
                                Text("Monitor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(monitor)
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )

                // Tiles card
                VStack(alignment: .leading, spacing: 0) {
                    Text("TILES (\(layout.tiles.count))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)

                    if layout.tiles.isEmpty {
                        Text("No tiles defined")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(layout.tiles.enumerated()), id: \.offset) { index, tile in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(tilePalette[index % tilePalette.count])
                                    .frame(width: 8, height: 8)
                                Text(tile.label ?? tile.app)
                                    .font(.system(size: 12))
                                Spacer()
                                Text("(\(tile.col),\(tile.row)) \(tile.colSpan)\u{00D7}\(tile.rowSpan)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        editingLayoutName = name
                        showEditor = true
                    } label: {
                        Label("Edit Layout", systemImage: "pencil")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func addNewLayout() {
        let baseName = "new-layout"
        var name = baseName
        var counter = 1
        while appState.config.layouts[name] != nil {
            name = "\(baseName)-\(counter)"
            counter += 1
        }
        appState.config.layouts[name] = LayoutConfig(
            rows: 2, cols: 2,
            hotkey: "cmd+shift+\(appState.config.layouts.count + 1)",
            tiles: []
        )
        selectedLayout = name
        editingLayoutName = name
        showEditor = true
    }

    private func duplicateLayout(_ name: String) {
        guard let original = appState.config.layouts[name] else { return }
        let newName = "\(name)-copy"
        var copy = original
        copy.hotkey = ""
        appState.config.layouts[newName] = copy
        selectedLayout = newName
    }

    private func deleteLayout(_ name: String) {
        appState.config.layouts.removeValue(forKey: name)
        if selectedLayout == name {
            selectedLayout = sortedLayoutNames.first
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

// MARK: - Advanced Tab

struct AdvancedTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var showExportPanel = false
    @State private var showImportPanel = false
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Config file")
                    Spacer()
                    Text(ConfigLoader.configFilePath.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.selectFile(
                            ConfigLoader.configFilePath.path,
                            inFileViewerRootedAtPath: ConfigLoader.configDirectory.path
                        )
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }

                    Button {
                        let path = ConfigLoader.configFilePath.path
                        if let editor = ProcessInfo.processInfo.environment["EDITOR"] {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                            process.arguments = [editor, path]
                            try? process.run()
                        } else {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }
                    } label: {
                        Label("Open in Editor", systemImage: "pencil")
                    }
                }
            } header: {
                Text("Configuration")
            }

            Section {
                HStack(spacing: 8) {
                    Button {
                        showExportPanel = true
                    } label: {
                        Label("Export...", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportPanel = true
                    } label: {
                        Label("Import...", systemImage: "square.and.arrow.down")
                    }
                }
            } header: {
                Text("Backup")
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showExportPanel,
            document: TOMLFileDocument(url: ConfigLoader.configFilePath),
            contentType: .plainText,
            defaultFilename: "tilepilot-config.toml"
        ) { _ in }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.plainText]
        ) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let contents = try? String(contentsOf: url, encoding: .utf8) {
                    try? contents.write(to: ConfigLoader.configFilePath, atomically: true, encoding: .utf8)
                    appState.reloadConfig()
                }
            }
        }
        .confirmationDialog("Reset all settings to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                try? FileManager.default.removeItem(at: ConfigLoader.configFilePath)
                appState.configLoader.ensureDefaultConfig()
                appState.reloadConfig()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace your config file with the default configuration. This cannot be undone.")
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.blue.gradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("TilePilot")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Declarative window layouts for macOS")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 6) {
                Text("Built by Rahul Mehta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("View on GitHub", destination: URL(string: "https://github.com/rahulmehta25/tilepilot")!)
                    .font(.caption)
            }

            Spacer()

            Button {
                if let url = URL(string: "https://github.com/rahulmehta25/tilepilot/releases") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, build != version {
            return "\(version) (\(build))"
        }
        return version
    }
}

// MARK: - TOML File Document

struct TOMLFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]
    var text: String

    init(url: URL) {
        self.text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
