import SwiftUI

struct WindowListView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var showingImagePicker = false
    @State private var hoveredImageName: String?
    /// 確認待ちの削除対象。すべてのウィンドウを削除する（＝アプリが終了する）場合だけ確認する
    @State private var pendingDeletion: Set<Int>?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            // 最後のウィンドウを閉じるとアプリが終了するため通常は表示されない（復元中など一時的に空になった場合の表示）
            if viewModel.windows.isEmpty {
                emptyState
            } else {
                windowList
            }

            statusBar
        }
        .confirmationDialog(
            deletionConfirmTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { windowIds in
            Button(L("management.context.close"), role: .destructive) {
                viewModel.deleteWindows(windowIds: windowIds)
            }
            Button(L("management.cancel"), role: .cancel) {}
        } message: { _ in
            Text(L("quit.confirm_message"))
        }
    }

    // MARK: - Deletion

    private func requestDelete(_ windowIds: Set<Int>) {
        guard !windowIds.isEmpty else { return }
        if viewModel.deletionRemovesAllWindows(windowIds) {
            pendingDeletion = windowIds
        } else {
            viewModel.deleteWindows(windowIds: windowIds)
        }
    }

    private var deletionConfirmTitle: String {
        guard let windowIds = pendingDeletion else { return "" }
        if windowIds.count == 1,
           let window = viewModel.windows.first(where: { windowIds.contains($0.windowId) }) {
            return String(format: L("management.delete_confirm_single"), window.displayName)
        }
        return String(format: L("management.delete_confirm_multi"), windowIds.count)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(L("management.all_label"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ToolbarIconButton(
                    systemImage: AppConstants.visibleWindowSymbol, help: L("management.show_all")
                ) {
                    viewModel.showAllWindows()
                }

                ToolbarIconButton(
                    systemImage: AppConstants.hiddenWindowSymbol, help: L("management.hide_all")
                ) {
                    viewModel.hideAllWindows()
                }

                ToolbarIconButton(
                    systemImage: AppConstants.ghostModeSymbol, help: L("management.ghost_all")
                ) {
                    viewModel.ghostAllWindows()
                }

                ToolbarIconButton(
                    systemImage: AppConstants.normalModeSymbol, help: L("management.unghost_all")
                ) {
                    viewModel.unghostAllWindows()
                }
            }

            Spacer()

            ToolbarIconButton(systemImage: "plus", help: L("management.add_image")) {
                showingImagePicker.toggle()
            }
            .popover(isPresented: $showingImagePicker, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showingImagePicker = false
                        viewModel.addImageFromFile()
                    } label: {
                        Label(L("management.add_new_image"), systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .padding(8)

                    Divider()

                    Text(L("management.registered_images"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if viewModel.registeredImageNames.isEmpty {
                        Text(L("management.no_registered_images"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else {
                        HStack(spacing: 0) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(viewModel.registeredImageNames, id: \.self) { name in
                                        Text(name)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(hoveredImageName == name
                                                ? Color.accentColor.opacity(0.15)
                                                : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .contentShape(Rectangle())
                                            .onHover { isHovered in
                                                hoveredImageName = isHovered ? name : nil
                                            }
                                            .onTapGesture {
                                                showingImagePicker = false
                                                viewModel.addFromRegisteredImage(name: name)
                                            }
                                    }
                                }
                                .padding(4)
                            }
                            .frame(width: AppConstants.managementImagePickerListWidth)

                            Divider()

                            VStack {
                                if let name = hoveredImageName,
                                   let image = viewModel.registeredImagePreview(name: name) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 150, maxHeight: 150)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: AppConstants.managementImagePickerPreviewWidth)
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .frame(
                    width: AppConstants.managementImagePickerPopoverWidth,
                    height: AppConstants.managementImagePickerPopoverHeight
                )
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Window List

    @ViewBuilder
    private var windowList: some View {
        List(selection: $viewModel.selectedWindowIds) {
            ForEach(viewModel.windows, id: \.windowId) { windowInfo in
                WindowListRow(
                    windowInfo: windowInfo,
                    viewModel: viewModel,
                    onRequestDelete: { requestDelete([windowInfo.windowId]) }
                )
                .opacity(windowInfo.isHidden ? 0.5 : 1.0)
                .tag(windowInfo.windowId)
            }
            .onMove { source, destination in
                viewModel.moveWindows(from: source, to: destination)
            }
        }
        .onDeleteCommand {
            requestDelete(viewModel.selectedWindowIds)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        EmptySelectionView(
            message: L("management.no_windows"),
            icon: "photo.on.rectangle.angled",
            actionTitle: L("management.add_image"),
            action: { viewModel.addImageFromFile() }
        )
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        let visibleCount = viewModel.visibleWindowCount
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
    let onRequestDelete: () -> Void

    var body: some View {
        // 現在の状態を示すアイコン（インラインボタン用）
        let visibilityStateIcon = windowInfo.isHidden
            ? AppConstants.hiddenWindowSymbol : AppConstants.visibleWindowSymbol
        let ghostStateIcon = windowInfo.isGhostMode
            ? AppConstants.ghostModeSymbol : AppConstants.normalModeSymbol

        // 次のアクションを示すアイコン（コンテキストメニュー用）- 状態の反転
        let visibilityActionIcon = windowInfo.isHidden
            ? AppConstants.visibleWindowSymbol : AppConstants.hiddenWindowSymbol
        let ghostActionIcon = windowInfo.isGhostMode
            ? AppConstants.normalModeSymbol : AppConstants.ghostModeSymbol

        // ラベル
        let visibilityLabel = windowInfo.isHidden
            ? L("management.context.show") : L("management.context.hide")
        let ghostLabel = windowInfo.isGhostMode
            ? L("management.context.ghost_off") : L("management.context.ghost_on")

        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            // Thumbnail
            RoundedThumbnail(image: windowInfo.thumbnail)

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
                Image(systemName: visibilityStateIcon)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(windowInfo.isHidden ? .secondary : .primary)
            .accessibilityLabel(visibilityLabel)

            // Ghost toggle
            Button {
                viewModel.toggleGhostMode(windowId: windowInfo.windowId)
            } label: {
                Image(systemName: ghostStateIcon)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(windowInfo.isGhostMode ? Color.accentColor : Color.secondary)
            .accessibilityLabel(ghostLabel)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                viewModel.toggleHidden(windowId: windowInfo.windowId)
            } label: {
                Label(visibilityLabel, systemImage: visibilityActionIcon)
            }

            Button {
                viewModel.toggleGhostMode(windowId: windowInfo.windowId)
            } label: {
                Label(ghostLabel, systemImage: ghostActionIcon)
            }

            Divider()

            Button {
                viewModel.duplicateWindow(windowId: windowInfo.windowId)
            } label: {
                Label(
                    L("management.context.duplicate"),
                    systemImage: "doc.on.doc")
            }

            Button {
                viewModel.centerWindow(windowId: windowInfo.windowId)
            } label: {
                Label(
                    L("management.context.center"),
                    systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()

            Button {
                onRequestDelete()
            } label: {
                Label(
                    L("management.context.close"),
                    systemImage: AppConstants.closeSymbol)
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

}
