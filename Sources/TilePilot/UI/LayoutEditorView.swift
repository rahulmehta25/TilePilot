import SwiftUI
import AppKit

struct LayoutEditorView: View {
    let layoutName: String
    @Binding var layout: LayoutConfig
    @EnvironmentObject private var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTileIndex: Int?
    @State private var showTileAssignment = false
    @State private var dragStart: GridCell?
    @State private var dragEnd: GridCell?
    @State private var isPreviewing = false
    @State private var saveError: String?
    @State private var showDeleteConfirmation = false

    private let tilePalette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .brown
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    gridControls
                    canvasView
                    tileList
                }
                .padding()
            }
            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Edit Layout")
                    .font(.headline)
                Text(displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red.opacity(0.7))
            .help("Delete layout")
            .confirmationDialog(
                "Delete '\(displayName)'?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete Layout", role: .destructive) {
                    appState.config.layouts.removeValue(forKey: layoutName)
                    appState.saveConfigToDisk()
                    appState.hotkeyManager.registerAll(from: appState.config)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove this layout. This cannot be undone.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Grid Controls (Toolbar)

    private var gridControls: some View {
        HStack(spacing: 16) {
            // Monitor picker
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("Monitor", selection: monitorBinding) {
                    Text("Main Display").tag(Optional<String>.none)
                    ForEach(appState.displayManager.screenNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                .controlSize(.small)
            }

            Divider().frame(height: 18)

            // Grid dimensions
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Cols")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(layout.cols)", value: $layout.cols, in: 1...8)
                        .frame(width: 80)
                        .controlSize(.small)
                }

                HStack(spacing: 4) {
                    Text("Rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(layout.rows)", value: $layout.rows, in: 1...8)
                        .frame(width: 80)
                        .controlSize(.small)
                }
            }

            Divider().frame(height: 18)

            // Gap slider
            HStack(spacing: 4) {
                Text("Gap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: gapBinding, in: 0...20, step: 1)
                    .frame(width: 80)
                    .controlSize(.small)
                Text("\(effectiveGap)px")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Canvas

    private var canvasView: some View {
        GeometryReader { geo in
            let canvasSize = canvasSize(in: geo.size)
            let cellWidth = (canvasSize.width - CGFloat(layout.cols + 1) * scaledGap) / CGFloat(layout.cols)
            let cellHeight = (canvasSize.height - CGFloat(layout.rows + 1) * scaledGap) / CGFloat(layout.rows)

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    }

                // Grid cells
                ForEach(0..<layout.rows, id: \.self) { row in
                    ForEach(0..<layout.cols, id: \.self) { col in
                        let rect = cellRect(row: row, col: col, cellWidth: cellWidth, cellHeight: cellHeight)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.quaternary.opacity(0.3))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                // Dashed grid dividers
                Path { path in
                    for col in 1..<layout.cols {
                        let x = scaledGap + CGFloat(col) * (cellWidth + scaledGap) - scaledGap / 2
                        path.move(to: CGPoint(x: x, y: scaledGap * 2))
                        path.addLine(to: CGPoint(x: x, y: canvasSize.height - scaledGap * 2))
                    }
                    for row in 1..<layout.rows {
                        let y = scaledGap + CGFloat(row) * (cellHeight + scaledGap) - scaledGap / 2
                        path.move(to: CGPoint(x: scaledGap * 2, y: y))
                        path.addLine(to: CGPoint(x: canvasSize.width - scaledGap * 2, y: y))
                    }
                }
                .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Existing tiles
                ForEach(Array(layout.tiles.enumerated()), id: \.offset) { index, tile in
                    let rect = tileRect(for: tile, cellWidth: cellWidth, cellHeight: cellHeight)
                    tileOverlay(tile: tile, index: index, rect: rect)
                        .position(x: rect.midX, y: rect.midY)
                }

                // Drag preview
                if let start = dragStart, let end = dragEnd {
                    let rect = dragPreviewRect(start: start, end: end, cellWidth: cellWidth, cellHeight: cellHeight)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.blue.opacity(0.15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.blue, lineWidth: 2)
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let cell = cellAt(point: value.startLocation, cellWidth: cellWidth, cellHeight: cellHeight)
                        if dragStart == nil { dragStart = cell }
                        dragEnd = cellAt(point: value.location, cellWidth: cellWidth, cellHeight: cellHeight)
                    }
                    .onEnded { _ in commitDrag() }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: 260)
    }

    private func tileOverlay(tile: TileConfig, index: Int, rect: CGRect) -> some View {
        let color = tilePalette[index % tilePalette.count]
        let isSelected = selectedTileIndex == index
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(isSelected ? 0.3 : 0.15))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color.opacity(isSelected ? 0.9 : 0.5), lineWidth: isSelected ? 2 : 1)
            }
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(color.opacity(0.7))
                    Text(tile.label ?? (tile.app.isEmpty ? "Empty" : tile.app))
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    Text("\(tile.colSpan)\u{00D7}\(tile.rowSpan)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .frame(width: rect.width, height: rect.height)
            .onTapGesture {
                selectedTileIndex = (selectedTileIndex == index) ? nil : index
            }
    }

    // MARK: - Tile List

    private var tileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tiles")
                    .font(.headline)

                if !layout.tiles.isEmpty {
                    Text("\(layout.tiles.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.12))
                        )
                }

                Spacer()

                Button {
                    showTileAssignment = true
                } label: {
                    Label("Add Tile", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if layout.tiles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "rectangle.dashed")
                            .font(.title2)
                            .foregroundStyle(.quaternary)
                        Text("Drag on the canvas to define tiles, or click Add Tile")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(Array(layout.tiles.enumerated()), id: \.offset) { index, tile in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tilePalette[index % tilePalette.count])
                            .frame(width: 10, height: 10)

                        Text(tile.label ?? (tile.app.isEmpty ? "Unassigned" : tile.app))
                            .font(.system(size: 13, weight: .medium))

                        if !tile.app.isEmpty && tile.label != nil {
                            Text(tile.app)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("(\(tile.col),\(tile.row)) \(tile.colSpan)\u{00D7}\(tile.rowSpan)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Button {
                            layout.tiles.remove(at: index)
                            if selectedTileIndex == index { selectedTileIndex = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove tile")
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background {
                        if selectedTileIndex == index {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(tilePalette[index % tilePalette.count].opacity(0.08))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTileIndex = (selectedTileIndex == index) ? nil : index
                    }
                }
            }
        }
        .sheet(isPresented: $showTileAssignment) {
            tileAssignmentSheet
        }
    }

    private var tileAssignmentSheet: some View {
        VStack(spacing: 16) {
            Text("Assign App to Tile")
                .font(.headline)

            TileAssignmentView(
                bundleID: Binding(
                    get: {
                        if let idx = selectedTileIndex, idx < layout.tiles.count {
                            return layout.tiles[idx].app
                        }
                        return ""
                    },
                    set: { newVal in
                        if let idx = selectedTileIndex, idx < layout.tiles.count {
                            layout.tiles[idx].app = newVal
                        }
                    }
                ),
                label: Binding(
                    get: {
                        if let idx = selectedTileIndex, idx < layout.tiles.count {
                            return layout.tiles[idx].label ?? ""
                        }
                        return ""
                    },
                    set: { newVal in
                        if let idx = selectedTileIndex, idx < layout.tiles.count {
                            layout.tiles[idx].label = newVal.isEmpty ? nil : newVal
                        }
                    }
                )
            )

            HStack {
                Spacer()
                Button("Done") { showTileAssignment = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380, height: 400)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HotkeyRecorderView(
                hotkeyString: $layout.hotkey,
                existingLayoutName: layoutName
            )

            Spacer()

            Button {
                isPreviewing = true
                appState.previewLayout(layout, name: layoutName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    isPreviewing = false
                }
            } label: {
                Label("Preview", systemImage: "play.fill")
            }
            .disabled(layout.tiles.isEmpty || isPreviewing)
            .help("Preview layout for 5 seconds")

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                appState.config.layouts[layoutName] = layout
                appState.hotkeyManager.registerAll(from: appState.config)

                do {
                    try ConfigWriter.updateLayout(
                        name: layoutName,
                        layout: layout,
                        in: ConfigLoader.configFilePath.path
                    )
                } catch {
                    saveError = error.localizedDescription
                    TilePilotLogger.error("Failed to save layout: \(error.localizedDescription)")
                    return
                }

                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .alert("Save Failed", isPresented: showSaveError) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "Unknown error")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Grid Math

    private var effectiveGap: Int {
        layout.gap ?? appState.config.general.gap
    }

    private var scaledGap: CGFloat {
        CGFloat(effectiveGap) * 0.5
    }

    private var displayName: String {
        layoutName.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private var showSaveError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    private var monitorBinding: Binding<String?> {
        Binding(
            get: { layout.monitor },
            set: { layout.monitor = $0 }
        )
    }

    private var gapBinding: Binding<Double> {
        Binding(
            get: { Double(layout.gap ?? appState.config.general.gap) },
            set: { layout.gap = Int($0) }
        )
    }

    private func canvasSize(in available: CGSize) -> CGSize {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let aspect = screen.visibleFrame.width / screen.visibleFrame.height
        let width = min(available.width - 32, 540)
        let height = width / aspect
        return CGSize(width: width, height: min(height, 260))
    }

    private func cellRect(row: Int, col: Int, cellWidth: CGFloat, cellHeight: CGFloat) -> CGRect {
        let x = scaledGap + CGFloat(col) * (cellWidth + scaledGap)
        let y = scaledGap + CGFloat(row) * (cellHeight + scaledGap)
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }

    private func tileRect(for tile: TileConfig, cellWidth: CGFloat, cellHeight: CGFloat) -> CGRect {
        let x = scaledGap + CGFloat(tile.col) * (cellWidth + scaledGap)
        let y = scaledGap + CGFloat(tile.row) * (cellHeight + scaledGap)
        let w = CGFloat(tile.colSpan) * cellWidth + CGFloat(tile.colSpan - 1) * scaledGap
        let h = CGFloat(tile.rowSpan) * cellHeight + CGFloat(tile.rowSpan - 1) * scaledGap
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func cellAt(point: CGPoint, cellWidth: CGFloat, cellHeight: CGFloat) -> GridCell? {
        let col = Int((point.x - scaledGap) / (cellWidth + scaledGap))
        let row = Int((point.y - scaledGap) / (cellHeight + scaledGap))
        guard col >= 0, col < layout.cols, row >= 0, row < layout.rows else { return nil }
        return GridCell(row: row, col: col)
    }

    private func dragPreviewRect(start: GridCell, end: GridCell, cellWidth: CGFloat, cellHeight: CGFloat) -> CGRect {
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)

        let x = scaledGap + CGFloat(minCol) * (cellWidth + scaledGap)
        let y = scaledGap + CGFloat(minRow) * (cellHeight + scaledGap)
        let colSpan = maxCol - minCol + 1
        let rowSpan = maxRow - minRow + 1
        let w = CGFloat(colSpan) * cellWidth + CGFloat(colSpan - 1) * scaledGap
        let h = CGFloat(rowSpan) * cellHeight + CGFloat(rowSpan - 1) * scaledGap
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func commitDrag() {
        guard let start = dragStart, let end = dragEnd else {
            dragStart = nil
            dragEnd = nil
            return
        }

        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)

        let newTile = TileConfig(
            app: "",
            label: nil,
            row: minRow,
            col: minCol,
            rowSpan: maxRow - minRow + 1,
            colSpan: maxCol - minCol + 1
        )

        layout.tiles.append(newTile)
        selectedTileIndex = layout.tiles.count - 1
        showTileAssignment = true

        dragStart = nil
        dragEnd = nil
    }
}

// MARK: - Grid Cell

struct GridCell: Equatable {
    let row: Int
    let col: Int
}
