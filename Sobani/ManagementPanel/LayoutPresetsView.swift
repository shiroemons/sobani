import SwiftUI

struct LayoutPresetsView: View {
    private static let undoTimeoutSeconds: Double = 5
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var presets: [LayoutPreset] = []
    @State private var selectedPreset: LayoutPreset?
    @State private var selectedPresetWindowIndex: Int?
    @State private var isShowingRenameSheet = false
    @State private var isShowingSaveSheet = false
    @State private var newPresetName = ""
    @State private var hoveredPresetId: UUID?
    @State private var presetToDelete: LayoutPreset?
    @State private var isShowingDeleteConfirmation = false
    @State private var activeToast: ToastType?
    @State private var toastTimerTask: Task<Void, Never>?
    @State private var isShowingCreateSheet = false

    private enum ToastType: Equatable {
        case deleted(LayoutPreset)
        case success(String)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let preset = selectedPreset {
                presetDetailScreen(preset: preset)
            } else {
                presetListScreen
            }

            // Toast banner
            if let toast = activeToast {
                HStack(spacing: 12) {
                    switch toast {
                    case .deleted(let preset):
                        Text(String(format: L("layout.deleted_message"), preset.name))
                            .lineLimit(1)
                        Button(L("layout.undo")) {
                            restoreDeletedPreset()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    case .success(let message):
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(message)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeToast)
        .confirmationDialog(
            L("layout.delete_confirm_title"),
            isPresented: $isShowingDeleteConfirmation,
            presenting: presetToDelete
        ) { preset in
            Button(L("layout.delete_button"), role: .destructive) {
                performDeletePreset(preset)
            }
            Button(L("management.cancel"), role: .cancel) {}
        } message: { preset in
            Text(String(format: L("layout.delete_confirm_message"), preset.name))
        }
        .onDisappear {
            toastTimerTask?.cancel()
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
                        .frame(width: 16, height: 16)
                }
                .help(L("layout.save_current"))

                Button {
                    newPresetName = ""
                    isShowingCreateSheet = true
                } label: {
                    Image(systemName: "plus.square")
                        .frame(width: 16, height: 16)
                }
                .help(L("layout.create_new"))

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
                    ForEach(presets) { preset in
                        presetRow(for: preset)
                    }
                }
            }
        }
        .onAppear { refreshPresets() }
        .sheet(isPresented: $isShowingSaveSheet) {
            presetNameSheet(title: L("layout.save_title"), action: savePreset)
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            presetNameSheet(title: L("layout.create_title")) {
                createNewLayout()
            }
        }
    }

    // MARK: - Preset Row

    @ViewBuilder
    private func presetRow(for preset: LayoutPreset) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.body)
                    .fontWeight(.medium)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(preset.states.enumerated()), id: \.offset) { _, state in
                        thumbnailForState(state)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            PresetActionButtonsView(
                onApply: { applyPreset(preset) },
                onUpdate: { updatePreset(preset) },
                onRename: { startRename(preset) },
                onDelete: { confirmDeletePreset(preset) }
            )

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPreset = preset
            selectedPresetWindowIndex = nil
        }
        .onHover { isHovered in
            hoveredPresetId = isHovered ? preset.id : nil
        }
        .listRowBackground(
            hoveredPresetId == preset.id
                ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
                : nil
        )
        .contextMenu {
            Button { applyPreset(preset) } label: {
                Label(L("layout.apply"), systemImage: "play")
            }
            Button { updatePreset(preset) } label: {
                Label(L("layout.update"), systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                startRename(preset)
            } label: {
                Label(L("layout.rename"), systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { confirmDeletePreset(preset) } label: {
                Label(L("layout.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func thumbnailForState(_ state: WindowState) -> some View {
        let image: NSImage? = {
            guard let baseImage = viewModel.previewImage(name: state.imageName) else { return nil }
            return CroppedImageHelper.croppedImage(from: baseImage, cropRect: state.cropRect, imageName: state.imageName)
        }()
        ThumbnailView(image: image, iconFont: .caption2)
    }

    // MARK: - Name Input Sheet

    @ViewBuilder
    private func presetNameSheet(title: String, action: @escaping () -> Void) -> some View {
        PresetNameSheetView(title: title, name: $newPresetName, action: action)
    }
}

// MARK: - Detail Screen

extension LayoutPresetsView {
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

                PresetActionButtonsView(
                    onApply: { applyPreset(preset) },
                    onUpdate: { updatePreset(preset) },
                    onRename: { startRename(preset) },
                    onDelete: { confirmDeletePreset(preset) }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Minimap
            PresetMinimapView(
                states: preset.states,
                images: Dictionary(
                    uniqueKeysWithValues: preset.states.compactMap { state in
                        viewModel.previewImage(name: state.imageName).map { (state.imageName, $0) }
                    }
                ),
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
                    .splitPanelFrame()
                PresetDetailView(viewModel: viewModel, preset: preset, selectedIndex: selectedPresetWindowIndex)
                    .splitPanelFrame()
            }
        }
        .sheet(isPresented: $isShowingRenameSheet) {
            presetNameSheet(title: L("layout.rename_title")) {
                renamePreset(from: preset.name, to: newPresetName)
            }
        }
    }

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
                        Text("\(FormatUtils.formatDimensions(width: state.width, height: state.height)) ・ (\(Int(state.originX)), \(Int(state.originY)))")
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
}

// MARK: - Actions

extension LayoutPresetsView {
    private func startRename(_ preset: LayoutPreset) {
        newPresetName = preset.name
        selectedPreset = preset
        isShowingRenameSheet = true
    }

    private func refreshPresets() {
        let newPresets = viewModel.loadPresets()
        if newPresets != presets {
            presets = newPresets
        }
    }

    private func savePreset() {
        guard let states = viewModel.captureCurrentWindowStates() else { return }
        viewModel.savePreset(name: newPresetName, states: states)
        refreshPresets()
    }

    private func applyPreset(_ preset: LayoutPreset) {
        viewModel.applyLayout(preset)
        showToast(.success(String(format: L("layout.applied_message"), preset.name)))
    }

    private func updatePreset(_ preset: LayoutPreset) {
        guard let states = viewModel.captureCurrentWindowStates() else { return }
        viewModel.updatePreset(preset, states: states)
        refreshPresets()
        if selectedPreset?.id == preset.id {
            selectedPreset = presets.first { $0.id == preset.id }
        }
        showToast(.success(String(format: L("layout.updated_message"), preset.name)))
    }

    private func renamePreset(from oldName: String, to newName: String) {
        let previousId = selectedPreset?.id
        let success = viewModel.renamePreset(from: oldName, to: newName)
        if success {
            refreshPresets()
            selectedPreset = presets.first { $0.id == previousId }
        }
    }

    private func confirmDeletePreset(_ preset: LayoutPreset) {
        presetToDelete = preset
        isShowingDeleteConfirmation = true
    }

    private func performDeletePreset(_ preset: LayoutPreset) {
        viewModel.deletePreset(named: preset.name)
        if selectedPreset?.id == preset.id {
            selectedPreset = nil
        }
        if hoveredPresetId == preset.id {
            hoveredPresetId = nil
        }
        refreshPresets()
        showToast(.deleted(preset))
    }

    private func restoreDeletedPreset() {
        guard case .deleted(let preset) = activeToast else { return }
        toastTimerTask?.cancel()
        viewModel.restorePreset(preset)
        withAnimation {
            activeToast = nil
        }
        refreshPresets()
    }

    private func showToast(_ toast: ToastType) {
        toastTimerTask?.cancel()
        withAnimation {
            activeToast = toast
        }
        toastTimerTask = Task {
            do {
                try await Task.sleep(for: .seconds(Self.undoTimeoutSeconds))
                withAnimation {
                    activeToast = nil
                }
            } catch {
                // Cancelled — do nothing
            }
        }
    }

    private func createNewLayout() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        viewModel.createNewLayout(name: name)
        refreshPresets()
    }
}

// MARK: - PresetNameSheetView

struct PresetNameSheetView: View {
    let title: String
    @Binding var name: String
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            TextField(L("layout.name_placeholder"), text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: AppConstants.layoutDialogFieldWidth)
            HStack {
                Button(L("management.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(L("management.apply")) {
                    action()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }
}

// MARK: - PresetActionButtonsView

struct PresetActionButtonsView: View {
    let onApply: () -> Void
    let onUpdate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Button { onApply() } label: {
                    Image(systemName: "play")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.green)
                .help(L("layout.apply"))

                Button { onUpdate() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(L("layout.update"))
            }

            HStack(spacing: 8) {
                Button { onRename() } label: {
                    Image(systemName: "pencil")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(L("layout.rename"))

                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help(L("layout.delete"))
            }
        }
    }
}
