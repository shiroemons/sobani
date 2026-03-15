import SwiftUI

struct WindowListView: View {
    @Bindable var viewModel: ManagementPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if viewModel.windows.isEmpty {
                emptyState
            } else {
                windowList
            }

            statusBar
        }
        .searchable(text: $viewModel.searchText, prompt: Text(L("management.search")))
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.addImageFromFile()
            } label: {
                Image(systemName: "plus")
            }
            .help(L("management.add_image"))

            Spacer()

            Button {
                viewModel.showAllWindows()
            } label: {
                Image(systemName: "eye")
            }
            .help(L("management.show_all"))

            Button {
                viewModel.hideAllWindows()
            } label: {
                Image(systemName: "eye.slash")
            }
            .help(L("management.hide_all"))

            Button {
                viewModel.ghostAllWindows()
            } label: {
                Image(systemName: "face.dashed")
            }
            .help(L("management.ghost_all"))

            Button {
                viewModel.unghostAllWindows()
            } label: {
                Image(systemName: "face.smiling")
            }
            .help(L("management.unghost_all"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Window List

    @ViewBuilder
    private var windowList: some View {
        List(viewModel.filteredWindows, id: \.windowId, selection: $viewModel.selectedWindowIds) { windowInfo in
            WindowListRow(windowInfo: windowInfo, viewModel: viewModel)
                .opacity(windowInfo.isHidden ? 0.5 : 1.0)
        }
        .onDeleteCommand {
            if !viewModel.selectedWindowIds.isEmpty {
                viewModel.deleteWindows(windowIds: viewModel.selectedWindowIds)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L("management.no_windows"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button(L("management.add_image")) {
                viewModel.addImageFromFile()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        let visibleCount = viewModel.windows.filter { !$0.isHidden }.count
        let totalCount = viewModel.windows.count
        HStack {
            Text(String(format: L("management.status_format"), visibleCount, totalCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Window List Row

struct WindowListRow: View {
    let windowInfo: ManagementPanelViewModel.WindowInfo
    let viewModel: ManagementPanelViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            // Thumbnail
            thumbnailView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(windowInfo.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(windowInfo.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Visibility toggle
            Button {
                viewModel.toggleHidden(windowId: windowInfo.windowId)
            } label: {
                Image(systemName: windowInfo.isHidden ? "eye.slash" : "eye")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(windowInfo.isHidden ? .secondary : .primary)
            .accessibilityLabel(L("management.context.toggle_visibility"))

            // Ghost toggle
            Button {
                viewModel.toggleGhostMode(windowId: windowInfo.windowId)
            } label: {
                Image(systemName: "face.dashed")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(windowInfo.isGhostMode ? Color.accentColor : Color.secondary)
            .accessibilityLabel(L("management.context.toggle_ghost"))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                viewModel.toggleHidden(windowId: windowInfo.windowId)
            } label: {
                Label(L("management.context.toggle_visibility"),
                      systemImage: windowInfo.isHidden ? "eye" : "eye.slash")
            }

            Button {
                viewModel.toggleGhostMode(windowId: windowInfo.windowId)
            } label: {
                Label(L("management.context.toggle_ghost"),
                      systemImage: "face.dashed")
            }

            Divider()

            Button {
                viewModel.duplicateWindow(windowId: windowInfo.windowId)
            } label: {
                Label(L("management.context.duplicate"),
                      systemImage: "doc.on.doc")
            }

            Button {
                viewModel.centerWindow(windowId: windowInfo.windowId)
            } label: {
                Label(L("management.context.center"),
                      systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteWindows(windowIds: [windowInfo.windowId])
            } label: {
                Label(L("management.context.delete"),
                      systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [
                windowInfo.displayName,
                windowInfo.isHidden ? L("status.hidden") : L("status.showing"),
                windowInfo.isGhostMode ? L("ghost.toggle") : nil
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = windowInfo.thumbnail {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
