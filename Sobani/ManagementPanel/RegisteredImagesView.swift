import SwiftUI

struct RegisteredImagesView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if viewModel.registeredImageNames.isEmpty {
                noImagesEmptyState
            } else {
                HSplitView {
                    imageListPanel
                        .splitPanelFrame()

                    detailPanel
                        .splitPanelFrame()
                }
            }
        }
        .confirmationDialog(
            L("registered_images.delete_confirm_title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("registered_images.delete"), role: .destructive) {
                if let name = viewModel.selectedRegisteredImageName {
                    viewModel.removeRegisteredImage(named: name)
                }
            }
            Button(L("management.cancel"), role: .cancel) {}
        } message: {
            if let name = viewModel.selectedRegisteredImageName {
                let count = viewModel.windowCountUsingImage(named: name)
                if count > 0 {
                    Text(String(format: L("registered_images.delete_in_use_warning"), count))
                } else {
                    Text(L("registered_images.delete_confirm"))
                }
            }
        }
    }

    // MARK: - Image List Panel

    @ViewBuilder
    private var imageListPanel: some View {
        VStack(spacing: 0) {
            listToolbar

            imageList
        }
    }

    @ViewBuilder
    private var listToolbar: some View {
        HStack {
            Spacer()

            Button {
                viewModel.addImageFromFile(createWindow: false)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 16, height: 16)
            }
            .help(L("registered_images.add"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var imageList: some View {
        List(selection: $viewModel.selectedRegisteredImageName) {
            ForEach(viewModel.registeredImageNames, id: \.self) { name in
                ImageListRow(
                    name: name,
                    thumbnail: viewModel.registeredImagePreview(name: name),
                    windowCount: viewModel.windowCountUsingImage(named: name)
                )
                .tag(name)
            }
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let name = viewModel.selectedRegisteredImageName {
            imageDetailView(name: name)
        } else {
            noSelectionEmptyState
        }
    }

    @ViewBuilder
    private func imageDetailView(name: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Preview
                previewSection(name: name)

                Divider()

                // Info
                infoSection(name: name)

                Divider()

                // Actions
                actionsSection(name: name)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview Section

    @ViewBuilder
    private func previewSection(name: String) -> some View {
        ImagePreviewBox(image: viewModel.registeredImagePreview(name: name))
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(name: String) -> some View {
        let windowCount = viewModel.windowCountUsingImage(named: name)

        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(L("registered_images.file_name"))
                    .font(.subheadline.bold())
            } icon: {
                Image(systemName: "doc")
            }

            Text(name)
                .font(.body)
                .lineLimit(2)
                .truncationMode(.middle)

            Divider()

            Label {
                Text(L("registered_images.usage_count"))
                    .font(.subheadline.bold())
            } icon: {
                Image(systemName: "photo.on.rectangle")
            }

            HStack(spacing: 6) {
                Text("\(windowCount)")
                    .font(.body.monospaced())

                if windowCount > 0 {
                    Text(L("registered_images.in_use"))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                } else {
                    Text(L("registered_images.not_in_use"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private func actionsSection(name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.addFromRegisteredImage(name: name)
            } label: {
                Label(L("registered_images.add_as_window"), systemImage: "plus.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(L("registered_images.delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Empty States

    @ViewBuilder
    private var noImagesEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L("registered_images.empty"))
                .font(.body)
                .foregroundStyle(.secondary)
            Text(L("registered_images.empty_hint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(L("registered_images.add")) {
                viewModel.addImageFromFile(createWindow: false)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var noSelectionEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L("registered_images.select_image"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Image List Row

private struct ImageListRow: View {
    let name: String
    let thumbnail: NSImage?
    let windowCount: Int

    var body: some View {
        HStack(spacing: 8) {
            thumbnailView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if windowCount > 0 {
                Text("\(windowCount)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ThumbnailView(image: thumbnail)
    }
}
