import SwiftUI

struct PresetDetailView: View {
    let preset: LayoutPreset
    let onApply: () -> Void
    let onUpdate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HSplitView {
            infoPane
                .frame(minWidth: 250, idealWidth: 300)
            minimapPane
        }
    }

    // MARK: - Info Pane

    @ViewBuilder
    private var infoPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(preset.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("・")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(preset.states.count)\(L("layout.items_suffix"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            // Window state list
            List {
                ForEach(Array(preset.states.enumerated()), id: \.offset) { index, state in
                    presetWindowRow(index: index, state: state)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 8) {
                Button(L("layout.apply")) {
                    onApply()
                }
                .buttonStyle(.borderedProminent)

                Button(L("layout.update")) {
                    onUpdate()
                }
                .buttonStyle(.bordered)

                Button(L("layout.rename")) {
                    onRename()
                }
                .buttonStyle(.bordered)

                Button(L("layout.delete")) {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func presetWindowRow(index: Int, state: WindowState) -> some View {
        HStack(spacing: 8) {
            // Thumbnail
            thumbnailForState(state)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("#\(index + 1)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Text(state.imageName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text("(\(Int(state.originX)), \(Int(state.originY)))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func thumbnailForState(_ state: WindowState) -> some View {
        let image: NSImage? = if state.imageName == AppConstants.defaultImageName {
            ImageManager.shared.defaultImage()
        } else {
            ImageManager.shared.loadRegisteredImageCached(named: state.imageName)
        }
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - Minimap Pane

    @ViewBuilder
    private var minimapPane: some View {
        PresetMinimapView(states: preset.states)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
    }
}
