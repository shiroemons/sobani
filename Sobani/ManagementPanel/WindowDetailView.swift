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

                // Opacity
                opacitySection(windowInfo)

                Divider()

                // Position & Size
                WindowPositionEditorView(viewModel: viewModel, windowInfo: windowInfo)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    @ViewBuilder
    private func previewSection(_ windowInfo: ManagementPanelViewModel.WindowInfo) -> some View {
        if let image = windowInfo.thumbnail {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(maxWidth: .infinity, maxHeight: 200)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
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
