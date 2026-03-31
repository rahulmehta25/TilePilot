import SwiftUI
import AppKit

struct TileAssignmentView: View {
    @Binding var bundleID: String
    @Binding var label: String

    @State private var searchText = ""
    @State private var showManualEntry = false
    @State private var manualBundleID = ""
    @State private var runningApps: [AppInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            appList
            manualEntryToggle
            if showManualEntry {
                manualEntryField
            }
        }
        .onAppear { refreshRunningApps() }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            TextField("Search running apps...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - App List

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredApps) { app in
                    appRow(app)
                }
                if filteredApps.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "app.dashed")
                            .font(.title3)
                            .foregroundStyle(.quaternary)
                        Text("No matching apps")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func appRow(_ app: AppInfo) -> some View {
        Button {
            bundleID = app.bundleID
            label = app.name
        } label: {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13))
                    Text(app.bundleID)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                if app.bundleID == bundleID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if app.bundleID == bundleID {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
    }

    // MARK: - Manual Entry

    private var manualEntryToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showManualEntry.toggle()
            }
            if showManualEntry { manualBundleID = bundleID }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showManualEntry ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Enter bundle ID manually")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var manualEntryField: some View {
        HStack(spacing: 8) {
            TextField("com.example.app", text: $manualBundleID)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            Button("Set") {
                guard !manualBundleID.isEmpty else { return }
                bundleID = manualBundleID
                if label.isEmpty {
                    label = manualBundleID.split(separator: ".").last.map(String.init) ?? manualBundleID
                }
            }
            .disabled(manualBundleID.isEmpty)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Data

    private var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return runningApps }
        let query = searchText.lowercased()
        return runningApps.filter {
            $0.name.lowercased().contains(query) ||
            $0.bundleID.lowercased().contains(query)
        }
    }

    private func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppInfo? in
                guard let bid = app.bundleIdentifier else { return nil }
                return AppInfo(
                    bundleID: bid,
                    name: app.localizedName ?? bid,
                    icon: app.icon
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - App Info

struct AppInfo: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage?
    var id: String { bundleID }
}
