import SwiftUI

struct PresetDetailView: View {
    let preset: LayoutPreset
    let selectedIndex: Int?

    var body: some View {
        if let index = selectedIndex, index < preset.states.count {
            let state = preset.states[index]
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    previewSection(state: state)

                    Divider()

                    infoSection(state: state, index: index)

                    Divider()

                    positionSection(state: state)

                    Divider()

                    displaySection(state: state)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
    }

    // MARK: - Preview

    @ViewBuilder
    private func previewSection(state: WindowState) -> some View {
        let image = ImageManager.shared.image(named: state.imageName)
        GroupBox {
            if let image {
                let cropped = CroppedImageHelper.croppedImage(from: image, cropRect: state.cropRect)
                Image(nsImage: cropped)
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

    // MARK: - Info

    @ViewBuilder
    private func infoSection(state: WindowState, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(state.imageName)
                    .font(.headline)
            } icon: {
                Image(systemName: "photo")
            }

            Label {
                Text("#\(index + 1)")
                    .font(.caption.monospaced())
            } icon: {
                Image(systemName: "number")
            }

            Label {
                Text("\(Int(state.width))×\(Int(state.height)) px")
                    .font(.caption)
            } icon: {
                Image(systemName: "ruler")
            }
        }
    }

    // MARK: - Position & Size

    @ViewBuilder
    private func positionSection(state: WindowState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("management.position_size"))
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                coordinateLabel("X", value: state.originX)
                coordinateLabel("Y", value: state.originY)
                coordinateLabel("W", value: state.width)
                coordinateLabel("H", value: state.height)
            }
        }
    }

    private func coordinateLabel(_ label: String, value: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(value))")
                .font(.body.monospaced())
        }
    }

    // MARK: - Display Settings

    @ViewBuilder
    private func displaySection(state: WindowState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("management.display_settings"))
                .font(.subheadline.bold())

            HStack {
                Text(L("management.opacity"))
                    .font(.body)
                Spacer()
                Text(FormatUtils.formatOpacity(state.opacityLevel))
                    .font(.body.monospaced())
            }

            if state.isGhostMode {
                HStack {
                    Label(L("management.ghost_mode_section"), systemImage: "ghost")
                        .font(.body)
                    Spacer()
                    Text(L("management.enabled"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if state.isHidden {
                HStack {
                    Label(L("status.hidden"), systemImage: "eye.slash")
                        .font(.body)
                    Spacer()
                }
            }
        }
    }

}
