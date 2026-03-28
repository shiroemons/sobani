import SwiftUI

struct PositionLogView: View {
    @State private var isEnabled = PositionLogSettings.isEnabled
    @State private var entries: [PositionLogger.LogEntry] = []
    @State private var filterText = ""
    @State private var selectedEntryId: UUID?
    @State private var showClearConfirmation = false
    @State private var showLogInfoFromFooter = false
    @State private var selectedEventFilter: String?
    @State private var sortOrder: [KeyPathComparator<PositionLogger.LogEntry>] = [
        KeyPathComparator(\.timestamp, order: .forward)
    ]

    private var uniqueEventNames: [String] {
        Array(Set(entries.map(\.event))).sorted()
    }

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

    private var sortedEntries: [PositionLogger.LogEntry] {
        filteredEntries.sorted(using: sortOrder)
    }

    private var selectedEntry: PositionLogger.LogEntry? {
        guard let id = selectedEntryId else { return nil }
        return entries.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            filterBar
            Divider()
            logContent
            if !filteredEntries.isEmpty {
                Divider()
                logFooter
            }
            if let entry = selectedEntry {
                Divider()
                PositionLogDetailView(entry: entry)
            }
        }
        .onAppear { reloadEntries() }
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
                Button("JSONL") { exportJSONL() }
                Button("JSON") { exportJSON() }
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
    private var logContent: some View {
        if entries.isEmpty {
            PositionLogEmptyStateView(isEnabled: isEnabled) {
                isEnabled = true
                PositionLogSettings.isEnabled = true
            }
        } else if filteredEntries.isEmpty {
            ContentUnavailableView {
                Label(L("log.empty"), systemImage: "doc.text")
            } description: {
                Text(L("log.footer.description"))
            }
            .frame(maxHeight: .infinity)
        } else {
            logTable
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
    private var logTable: some View {
        Table(sortedEntries, selection: $selectedEntryId, sortOrder: $sortOrder) {
            TableColumn(L("log.column.time"), value: \.timestamp) { entry in
                Text(Self.formatTime(entry.timestamp))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 80, ideal: 120, max: 150)

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
    }

    private func exportJSONL() {
        let data = PositionLogger.shared.exportAsJSONL()
        saveToFile(data: data, extension: "jsonl")
    }

    private func exportJSON() {
        let data = PositionLogger.shared.exportAsJSON()
        saveToFile(data: data, extension: "json")
    }

    private func saveToFile(data: Data, extension ext: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "position_log.\(ext)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
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
