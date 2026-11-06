import SwiftUI
import UniformTypeIdentifiers

struct PositionLogView: View {
    let viewModel: ManagementPanelViewModel
    @State private var isEnabled = PositionLogSettings.isEnabled
    @State private var exportErrorMessage: String?
    @State private var entries: [PositionLogger.LogEntry] = []
    @State private var filterText = ""
    @State private var selectedEntryId: UUID?
    @State private var showClearConfirmation = false
    @State private var showLogInfoFromFooter = false
    @State private var selectedEventFilter: String?
    @State private var sortOrder: [KeyPathComparator<PositionLogger.LogEntry>] = [
        KeyPathComparator(\.timestamp, order: .forward)
    ]

    /// フィルタのイベント名一覧。描画のたびではなく読み込み時に作る
    @State private var uniqueEventNames: [String] = []

    /// 絞り込み結果（最大 1000 件を文字列比較する）。body で1回だけ計算して各部に渡すこと
    private var filteredEntries: [PositionLogger.LogEntry] {
        var result = entries
        if let eventFilter = selectedEventFilter {
            result = result.filter { $0.event == eventFilter }
        }
        guard !filterText.isEmpty else { return result }
        let query = filterText.lowercased()
        return result.filter { entry in
            if entry.event.lowercased().contains(query) { return true }
            if let windows = entry.windows {
                for win in windows where String(win.windowId).contains(query) { return true }
            }
            if let values = entry.context?.values {
                for value in values where value.lowercased().contains(query) { return true }
            }
            return false
        }
    }

    private var selectedEntry: PositionLogger.LogEntry? {
        guard let id = selectedEntryId else { return nil }
        return entries.first { $0.id == id }
    }

    var body: some View {
        let visibleEntries = filteredEntries.sorted(using: sortOrder)
        VStack(spacing: 0) {
            toolbar
            Divider()
            filterBar
            Divider()
            logContent(visibleEntries)
            if !visibleEntries.isEmpty {
                Divider()
                logFooter
            }
            if let entry = selectedEntry {
                Divider()
                PositionLogDetailView(entry: entry)
            }
        }
        .onAppear { reloadEntries() }
        .alert(
            L("log.export.failed"),
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            ),
            presenting: exportErrorMessage
        ) { _ in
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            if !entries.isEmpty {
                Text(String(format: L("log.entry.count"), entries.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                reloadEntries()
            } label: {
                Label(L("log.reload"), systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(L("log.reload"))

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label(L("log.clear"), systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(entries.isEmpty)
            .help(L("log.clear"))
            .confirmationDialog(
                L("log.clear.confirm"),
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(L("log.clear"), role: .destructive) {
                    PositionLogger.shared.clearAll()
                    reloadEntries()
                }
            }

            Menu {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.menuTitle) { export(format) }
                }
            } label: {
                Label(L("log.export"), systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .disabled(entries.isEmpty)
            .help(L("log.export"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField(L("log.filter"), text: $filterText)
                .textFieldStyle(.plain)
            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Picker("", selection: $selectedEventFilter) {
                Text(L("log.filter.all")).tag(nil as String?)
                ForEach(uniqueEventNames, id: \.self) { name in
                    Text(name).tag(name as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            Toggle(L("log.toggle"), isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: isEnabled) { _, newValue in
                    PositionLogSettings.isEnabled = newValue
                }
                .help(L("log.toggle"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Log Content

    @ViewBuilder
    private func logContent(_ visibleEntries: [PositionLogger.LogEntry]) -> some View {
        if entries.isEmpty {
            PositionLogEmptyStateView(isEnabled: isEnabled) {
                // 設定への保存はトグルの onChange で行われる
                isEnabled = true
            }
        } else if visibleEntries.isEmpty {
            ContentUnavailableView {
                Label(L("log.empty"), systemImage: "doc.text")
            } description: {
                Text(L("log.footer.description"))
            }
            .frame(maxHeight: .infinity)
        } else {
            logTable(visibleEntries)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var logFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
            Text(L("log.footer.description"))
                .font(.caption)
            Spacer()
            Button {
                showLogInfoFromFooter = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showLogInfoFromFooter) {
                logInfoPopoverContent
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Log Info Popover

    @ViewBuilder
    private var logInfoPopoverContent: some View {
        PositionLogInfoView()
            .padding(16)
            .frame(width: 400)
    }

    // MARK: - Table

    @ViewBuilder
    private func logTable(_ visibleEntries: [PositionLogger.LogEntry]) -> some View {
        Table(visibleEntries, selection: $selectedEntryId, sortOrder: $sortOrder) {
            TableColumn(L("log.column.time"), value: \.timestamp) { entry in
                Text(Self.formatTime(entry.timestamp))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 100, ideal: 140, max: 180)

            TableColumn(L("log.column.event"), value: \.event) { (entry: PositionLogger.LogEntry) in
                ColorBadge(event: entry.event)
            }
            .width(min: 140, ideal: 180, max: 220)

            TableColumn(L("log.column.window")) { entry in
                let ids = entry.windows?.map { "#\($0.windowId)" }.joined(separator: ", ")
                Text(ids ?? "-")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(ids == nil ? .tertiary : .primary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn(L("log.column.details")) { entry in
                Text(entry.summary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Helpers

    private func reloadEntries() {
        entries = PositionLogger.shared.loadEntries()
        uniqueEventNames = Array(Set(entries.map(\.event))).sorted()
        if let eventFilter = selectedEventFilter, !uniqueEventNames.contains(eventFilter) {
            selectedEventFilter = nil
        }
    }

    private enum ExportFormat: String, CaseIterable {
        case jsonl
        case json

        var menuTitle: String { rawValue.uppercased() }

        /// 保存ダイアログで選べる種類。拡張子と一致させる（.json のみだと .jsonl の名前と食い違う）
        var contentType: UTType {
            UTType(filenameExtension: rawValue) ?? .data
        }
    }

    private static let exportBaseFileName = "position_log"

    private func export(_ format: ExportFormat) {
        let data: Data
        switch format {
        case .jsonl: data = PositionLogger.shared.exportAsJSONL()
        case .json: data = PositionLogger.shared.exportAsJSON()
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(Self.exportBaseFileName).\(format.rawValue)"
        panel.canCreateDirectories = true
        Task {
            // 管理パネルより前面に出すため、パネルのシートとして表示する
            guard await viewModel.runDialog(panel) == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Formatters

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter
    }()

    private static func formatTime(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? timeFormatter.string(from: date)
            : dateTimeFormatter.string(from: date)
    }
}
