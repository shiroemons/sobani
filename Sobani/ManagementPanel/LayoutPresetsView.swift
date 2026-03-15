import SwiftUI

struct LayoutPresetsView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var presets: [LayoutPreset] = []
    @State private var selectedPresetName: String?
    @State private var isShowingRenameSheet = false
    @State private var isShowingSaveSheet = false
    @State private var newPresetName = ""

    var body: some View {
        HSplitView {
            presetListPane
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
            presetDetailPane
        }
        .onAppear { refreshPresets() }
    }

    // MARK: - Left Pane

    @ViewBuilder
    private var presetListPane: some View {
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
            List(presets, id: \.name, selection: $selectedPresetName) { preset in
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
                .tag(preset.name)
            }
        }
        .sheet(isPresented: $isShowingSaveSheet) {
            presetNameSheet(title: L("layout.save_title"), action: savePreset)
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private var presetDetailPane: some View {
        if let name = selectedPresetName, let preset = presets.first(where: { $0.name == name }) {
            PresetDetailView(
                preset: preset,
                onApply: { applyPreset(preset) },
                onUpdate: { updatePreset(preset) },
                onRename: {
                    newPresetName = preset.name
                    isShowingRenameSheet = true
                },
                onDelete: { deletePreset(preset) }
            )
            .sheet(isPresented: $isShowingRenameSheet) {
                presetNameSheet(title: L("layout.rename_title")) {
                    renamePreset(from: preset.name, to: newPresetName)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(L("management.select_preset"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        selectedPresetName = newPresetName
    }

    private func applyPreset(_ preset: LayoutPreset) {
        viewModel.appDelegate?.applyLayout(preset)
    }

    private func updatePreset(_ preset: LayoutPreset) {
        guard let states = viewModel.appDelegate?.captureCurrentWindowStates() else { return }
        LayoutPresetManager.shared.savePreset(name: preset.name, states: states)
        refreshPresets()
    }

    private func renamePreset(from oldName: String, to newName: String) {
        LayoutPresetManager.shared.renamePreset(from: oldName, to: newName)
        refreshPresets()
        selectedPresetName = newName
    }

    private func deletePreset(_ preset: LayoutPreset) {
        LayoutPresetManager.shared.deletePreset(named: preset.name)
        if selectedPresetName == preset.name {
            selectedPresetName = nil
        }
        refreshPresets()
    }
}
