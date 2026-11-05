import SwiftUI

// MARK: - PositionLogDetailView

struct PositionLogDetailView: View {
    let entry: PositionLogger.LogEntry

    private static let minimapHeight: CGFloat = 100
    /// ミニマップ上でウィンドウを描く最小サイズ（極小のウィンドウも見えるように）
    private static let minWindowMarkerSize: CGFloat = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                detailHeader
                minimapView

                if let screens = entry.screens, !screens.isEmpty {
                    GroupBox {
                        ScreensTable(screens: screens)
                    } label: {
                        Label(L("log.detail.screens"), systemImage: "display")
                            .font(.subheadline.bold())
                    }
                }

                if let windows = entry.windows, !windows.isEmpty {
                    GroupBox {
                        WindowsTable(windows: windows, windowDescription: windowDescription)
                    } label: {
                        Label(L("log.detail.windows"), systemImage: "macwindow")
                            .font(.subheadline.bold())
                    }
                }

                if let ctx = entry.context, !ctx.isEmpty {
                    GroupBox {
                        ContextGrid(context: ctx)
                    } label: {
                        Label(L("log.detail.context"), systemImage: "list.bullet.rectangle")
                            .font(.subheadline.bold())
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 200, idealHeight: 300)
    }

    // MARK: - Private

    @ViewBuilder
    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.event)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text(Self.dateFormatter.string(from: entry.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(entry.summary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @MainActor @ViewBuilder
    private var minimapView: some View {
        let screenFrames = (entry.screens ?? []).map { screen in
            CGRect(x: screen.originX, y: screen.originY, width: screen.width, height: screen.height)
        }
        let windowFrames = (entry.windows ?? []).map { win in
            CGRect(x: win.originX, y: win.originY, width: win.width, height: win.height)
        }
        // ログが調べたいのは画面外に出たウィンドウなので、スクリーンだけでなくウィンドウも範囲に含める
        let bounds = MinimapLayout.totalBounds(screenFrames: screenFrames, windowFrames: windowFrames)

        if !screenFrames.isEmpty {
            GeometryReader { geo in
                let layout = MinimapLayout.calculate(
                    in: geo.size, precomputedBounds: bounds, screenFrames: screenFrames
                )
                if !layout.isEmpty {
                    minimapContent(layout: layout, windowFrames: windowFrames)
                }
            }
            .frame(height: Self.minimapHeight)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
    }

    private func minimapContent(layout: MinimapLayout, windowFrames: [CGRect]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layout.screens.enumerated()), id: \.offset) { _, rect in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.origin.x, y: rect.origin.y)
            }
            // windowId は古いログで重複しうるため位置を ID にする
            ForEach(Array(windowFrames.enumerated()), id: \.offset) { _, frame in
                let rect = layout.windowRect(
                    for: frame.origin.x,
                    originY: frame.origin.y,
                    width: frame.width,
                    height: frame.height
                )
                RoundedRectangle(cornerRadius: 1)
                    .fill(.blue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(.blue.opacity(0.6), lineWidth: 1)
                    )
                    .frame(
                        width: max(rect.width, Self.minWindowMarkerSize),
                        height: max(rect.height, Self.minWindowMarkerSize)
                    )
                    .offset(x: rect.origin.x, y: rect.origin.y)
            }
        }
    }

    private func windowDescription(for win: PositionLogger.WindowSnapshot) -> String {
        var desc = "#\(win.windowId)"
            + " frame={\(Int(win.originX)),\(Int(win.originY))"
            + " \(Int(win.width))×\(Int(win.height))}"
            + " image=\(Int(win.imageWidth))×\(Int(win.imageHeight))"
        if let displayID = win.displayID {
            desc += " display=\(displayID)"
        }
        return desc
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - ScreensTable

struct ScreensTable: View {
    let screens: [PositionLogger.ScreenSnapshot]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 4) {
            GridRow {
                Text(L("log.detail.column.display_id"))
                    .frame(width: 90, alignment: .leading)
                Text(L("log.detail.column.origin"))
                    .frame(width: 110, alignment: .leading)
                Text(L("log.detail.column.size"))
                    .frame(width: 110, alignment: .leading)
                Text(L("log.detail.column.main"))
                    .frame(width: 40, alignment: .leading)
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            // displayID は取得できないと 0 になり重複しうるため位置を ID にする
            ForEach(Array(screens.enumerated()), id: \.offset) { _, screen in
                GridRow {
                    Text("\(screen.displayID)")
                        .frame(width: 90, alignment: .leading)
                    Text("\(Int(screen.originX)), \(Int(screen.originY))")
                        .frame(width: 110, alignment: .leading)
                    Text("\(Int(screen.width)) × \(Int(screen.height))")
                        .frame(width: 110, alignment: .leading)
                    Text(screen.isMain ? "●" : "")
                        .frame(width: 40, alignment: .leading)
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - WindowsTable

struct WindowsTable: View {
    let windows: [PositionLogger.WindowSnapshot]
    let windowDescription: (PositionLogger.WindowSnapshot) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(windows.enumerated()), id: \.offset) { _, win in
                Text(windowDescription(win))
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ContextGrid

struct ContextGrid: View {
    let context: [String: String]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
            ForEach(context.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                GridRow {
                    Text(key)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ColorBadge

struct ColorBadge: View {
    let event: String

    var body: some View {
        Text(event)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        if event.hasPrefix("states") { return .blue }
        if event.hasPrefix("restore") || event.hasPrefix("wake") { return .orange }
        if event.hasPrefix("sleep") { return .purple }
        if event.hasPrefix("screen") { return .green }
        if event.hasPrefix("pending") { return .yellow }
        if event.hasPrefix("snapshot") { return .gray }
        return .secondary
    }
}
