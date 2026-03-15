import SwiftUI

struct LayoutPresetsView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var presets: [LayoutPreset] = []
    @State private var selectedPreset: LayoutPreset?
    @State private var selectedPresetWindowIndex: Int?
    @State private var isShowingRenameSheet = false
    @State private var isShowingSaveSheet = false
    @State private var newPresetName = ""

    var body: some View {
        if let preset = selectedPreset {
            presetDetailScreen(preset: preset)
        } else {
            presetListScreen
        }
    }

    // MARK: - List Screen

    @ViewBuilder
    private var presetListScreen: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button {
                    isShowingSaveSheet = true
                    newPresetName = ""
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help(L("layout.save_current"))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // List
            if presets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(L("management.select_preset"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            selectedPreset = preset
                            selectedPresetWindowIndex = nil
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.body)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text("\(preset.states.count)\(L("layout.items_suffix"))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("・")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(preset.createdAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                applyPreset(preset)
                            } label: {
                                Label(L("layout.apply"), systemImage: "play")
                            }
                            Button {
                                updatePreset(preset)
                            } label: {
                                Label(L("layout.update"), systemImage: "arrow.triangle.2.circlepath")
                            }
                            Button {
                                newPresetName = preset.name
                                selectedPreset = preset
                                isShowingRenameSheet = true
                            } label: {
                                Label(L("layout.rename"), systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                deletePreset(preset)
                            } label: {
                                Label(L("layout.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { refreshPresets() }
        .sheet(isPresented: $isShowingSaveSheet) {
            presetNameSheet(title: L("layout.save_title"), action: savePreset)
        }
    }

    // MARK: - Detail Screen

    @ViewBuilder
    private func presetDetailScreen(preset: LayoutPreset) -> some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button {
                    selectedPreset = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(preset.name)
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Button(L("layout.apply")) {
                        applyPreset(preset)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(L("layout.update")) {
                        updatePreset(preset)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Minimap
            PresetMinimapView(
                states: preset.states,
                selectedWindowId: selectedPresetWindowIndex.flatMap { index in
                    index < preset.states.count ? preset.states[index].windowId : nil
                },
                onWindowTapped: { windowId in
                    selectedPresetWindowIndex = preset.states.firstIndex { $0.windowId == windowId }
                }
            )
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Window list | Window detail (read-only)
            HSplitView {
                presetWindowList(preset: preset)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                PresetDetailView(preset: preset, selectedIndex: selectedPresetWindowIndex)
            }
        }
        .sheet(isPresented: $isShowingRenameSheet) {
            presetNameSheet(title: L("layout.rename_title")) {
                renamePreset(from: preset.name, to: newPresetName)
            }
        }
    }

    // MARK: - Preset Window List

    @ViewBuilder
    private func presetWindowList(preset: LayoutPreset) -> some View {
        List(selection: $selectedPresetWindowIndex) {
            ForEach(Array(preset.states.enumerated()), id: \.offset) { index, state in
                HStack(spacing: 8) {
                    thumbnailForState(state)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.imageName)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(Int(state.width))×\(Int(state.height)) px ・ (\(Int(state.originX)), \(Int(state.originY)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .tag(index)
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func thumbnailForState(_ state: WindowState) -> some View {
        if let image = ImageManager.shared.image(named: state.imageName) {
            let cropped = CroppedImageHelper.croppedImage(from: image, cropRect: state.cropRect)
            Image(nsImage: cropped)
                .resizable()
                .aspectRatio(contentMode: .fit)
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

    // MARK: - Name Input Sheet

    @ViewBuilder
    private func presetNameSheet(title: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            TextField(L("layout.name_placeholder"), text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Button(L("management.cancel")) {
                    isShowingSaveSheet = false
                    isShowingRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Button(L("management.apply")) {
                    action()
                    isShowingSaveSheet = false
                    isShowingRenameSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: - Actions

    private func refreshPresets() {
        presets = LayoutPresetManager.shared.loadPresets()
    }

    private func savePreset() {
        guard let states = viewModel.appDelegate?.captureCurrentWindowStates() else { return }
        LayoutPresetManager.shared.savePreset(name: newPresetName, states: states)
        refreshPresets()
    }

    private func applyPreset(_ preset: LayoutPreset) {
        viewModel.appDelegate?.applyLayout(preset)
    }

    private func updatePreset(_ preset: LayoutPreset) {
        guard let states = viewModel.appDelegate?.captureCurrentWindowStates() else { return }
        LayoutPresetManager.shared.savePreset(name: preset.name, states: states)
        refreshPresets()
        // Update the detail view if currently viewing this preset
        if selectedPreset?.name == preset.name {
            selectedPreset = presets.first { $0.name == preset.name }
        }
    }

    private func renamePreset(from oldName: String, to newName: String) {
        LayoutPresetManager.shared.renamePreset(from: oldName, to: newName)
        refreshPresets()
        selectedPreset = presets.first { $0.name == newName }
    }

    private func deletePreset(_ preset: LayoutPreset) {
        LayoutPresetManager.shared.deletePreset(named: preset.name)
        if selectedPreset?.name == preset.name {
            selectedPreset = nil
        }
        refreshPresets()
    }
}
