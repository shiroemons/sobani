import SwiftUI

struct WindowDetailView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var bulkOpacity: CGFloat = AppConstants.opacityMax

    var body: some View {
        let selectedIds = viewModel.selectedWindowIds
        let selectedWindows = viewModel.windows.filter { selectedIds.contains($0.windowId) }

        if selectedWindows.count == 1, let windowInfo = selectedWindows.first {
            singleSelectionView(windowInfo)
        } else if selectedWindows.count > 1 {
            multiSelectionView(count: selectedWindows.count)
        } else {
            emptySelectionView
        }
    }

    // MARK: - Empty Selection

    @ViewBuilder
    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L("management.select_window"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Single Selection

    @ViewBuilder
    private func singleSelectionView(_ windowInfo: ManagementPanelViewModel.WindowInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Preview
                previewSection(windowInfo)

                Divider()

                // Info card
                infoSection(windowInfo)

                Divider()

                // Actions
                actionsSection(windowInfo)

                Divider()

                // Opacity
                opacitySection(windowInfo)

                Divider()

                // Ghost Mode
                ghostModeSection(windowInfo)

                // Position & Size
                WindowPositionEditorView(viewModel: viewModel, windowInfo: windowInfo)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    @ViewBuilder
    private func previewSection(_ window: ManagementPanelViewModel.WindowInfo) -> some View {
        GroupBox {
            if let originalImage = window.originalImage, let cropRect = window.cropRect {
                CropOverlayPreviewView(originalImage: originalImage, cropRect: cropRect)
                    .frame(maxWidth: .infinity, maxHeight: AppConstants.managementPreviewMaxHeight)
            } else if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: AppConstants.managementPreviewMaxHeight)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: AppConstants.managementPreviewMaxHeight)
            }
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(_ windowInfo: ManagementPanelViewModel.WindowInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(windowInfo.displayName)
                    .font(.headline)
            } icon: {
                Image(systemName: "photo")
            }

            Label {
                Text("#\(windowInfo.windowId)")
                    .font(.caption.monospaced())
            } icon: {
                Image(systemName: "number")
            }

            Label {
                Text(windowInfo.subtitle)
                    .font(.caption)
            } icon: {
                Image(systemName: "ruler")
            }
        }
    }

    // MARK: - Opacity Section

    @ViewBuilder
    private func opacitySection(_ windowInfo: ManagementPanelViewModel.WindowInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("management.opacity"))
                .font(.subheadline.bold())

            HStack {
                Slider(
                    value: Binding(
                        get: { windowInfo.opacityLevel },
                        set: { newValue in
                            viewModel.changeOpacity(windowId: windowInfo.windowId, opacity: newValue)
                        }
                    ),
                    in: AppConstants.opacityMin...AppConstants.opacityMax
                )

                Text(FormatUtils.formatOpacity(windowInfo.opacityLevel))
                    .font(.caption.monospaced())
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    // MARK: - Ghost Mode Section

    @ViewBuilder
    private func ghostModeSection(_ window: ManagementPanelViewModel.WindowInfo) -> some View {
        if window.isGhostMode {
            VStack(alignment: .leading, spacing: 12) {
                Label(L("management.ghost_mode_section"), systemImage: "ghost")
                    .font(.headline)

                Toggle(L("management.ghost_custom_opacity"), isOn: Binding(
                    get: { window.customGhostAlpha != nil },
                    set: { enabled in
                        if enabled {
                            viewModel.setCustomGhostAlpha(
                                windowId: window.windowId,
                                alpha: window.effectiveGhostAlpha
                            )
                        } else {
                            viewModel.clearCustomGhostAlpha(windowId: window.windowId)
                        }
                    }
                ))

                if window.customGhostAlpha != nil {
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { window.effectiveGhostAlpha },
                                set: { newValue in
                                    viewModel.setCustomGhostAlpha(
                                        windowId: window.windowId,
                                        alpha: newValue
                                    )
                                }
                            ),
                            in: AppConstants.ghostModeAlphaMin...AppConstants.ghostModeAlphaMax
                        )
                        Text(FormatUtils.formatOpacity(window.effectiveGhostAlpha))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                } else {
                    Text(L("management.ghost_using_default")
                        + " (\(FormatUtils.formatOpacity(GhostModeSettings.globalAlpha)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private func actionsSection(_ window: ManagementPanelViewModel.WindowInfo) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(L("management.actions"), systemImage: "square.grid.2x2")
                    .font(.headline)

                HStack(spacing: 8) {
                    actionButton(
                        title: L("floating_menu.crop"),
                        icon: "crop",
                        action: { viewModel.openCropEditor(windowId: window.windowId) }
                    )
                    actionButton(
                        title: L("floating_menu.flip"),
                        icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                        action: { viewModel.flipWindow(windowId: window.windowId) }
                    )
                    actionButton(
                        title: L("floating_menu.adjust"),
                        icon: "slider.horizontal.3",
                        action: { viewModel.openAdjustPanel(windowId: window.windowId) }
                    )
                    if #available(macOS 14.0, *) {
                        actionButton(
                            title: L("floating_menu.remove_background"),
                            icon: "eraser.fill",
                            action: { viewModel.removeBackground(windowId: window.windowId) }
                        )
                        .disabled(!window.isRemoveBackgroundEnabled)
                    }
                    actionButton(
                        title: L("floating_menu.reset_display"),
                        icon: "arrow.counterclockwise",
                        action: { viewModel.resetDisplay(windowId: window.windowId) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(height: 24)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Multi Selection

    @ViewBuilder
    private func multiSelectionView(count: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(String(format: L("management.selected_count"), count))
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Bulk opacity slider
            VStack(alignment: .leading, spacing: 8) {
                Text(L("management.opacity"))
                    .font(.subheadline.bold())

                HStack {
                    Slider(
                        value: $bulkOpacity,
                        in: AppConstants.opacityMin...AppConstants.opacityMax
                    )
                    .onChange(of: bulkOpacity) {
                        viewModel.changeBulkOpacity(opacity: bulkOpacity)
                    }

                    Text(FormatUtils.formatOpacity(bulkOpacity))
                        .font(.caption.monospaced())
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
