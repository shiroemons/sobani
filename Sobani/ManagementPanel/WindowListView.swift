import SwiftUI

struct WindowListView: View {
    private static let imagePickerPopoverWidth: CGFloat = 400
    private static let imagePickerPopoverHeight: CGFloat = 300
    private static let imagePickerListWidth: CGFloat = 220
    private static let imagePickerPreviewWidth: CGFloat = 170
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var showingImagePicker = false
    @State private var hoveredImageName: String?

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
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(L("management.all_label"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.showAllWindows()
                } label: {
                    Image(systemName: "eye")
                        .frame(width: 16, height: 16)
                }
                .help(L("management.show_all"))

                Button {
                    viewModel.hideAllWindows()
                } label: {
                    Image(systemName: "eye.slash")
                        .frame(width: 16, height: 16)
                }
                .help(L("management.hide_all"))

                Button {
                    viewModel.ghostAllWindows()
                } label: {
                    Image(systemName: "face.dashed")
                        .frame(width: 16, height: 16)
                }
                .help(L("management.ghost_all"))

                Button {
                    viewModel.unghostAllWindows()
                } label: {
                    Image(systemName: "face.smiling")
                        .frame(width: 16, height: 16)
                }
                .help(L("management.unghost_all"))
            }

            Spacer()

            Button {
                showingImagePicker.toggle()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 16, height: 16)
            }
            .help(L("management.add_image"))
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
                                            .cornerRadius(4)
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
                            .frame(width: Self.imagePickerListWidth)

                            Divider()

                            VStack {
                                if let name = hoveredImageName,
                                   let image = viewModel.registeredImagePreview(name: name) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 150, maxHeight: 150)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: Self.imagePickerPreviewWidth)
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .frame(width: Self.imagePickerPopoverWidth, height: Self.imagePickerPopoverHeight)
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
                WindowListRow(windowInfo: windowInfo, viewModel: viewModel)
                    .opacity(windowInfo.isHidden ? 0.5 : 1.0)
                    .tag(windowInfo.windowId)
            }
            .onMove { source, destination in
                viewModel.moveWindows(from: source, to: destination)
            }
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
        ThumbnailView(image: windowInfo.thumbnail)
    }
}
