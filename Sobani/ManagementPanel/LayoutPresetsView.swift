import SwiftUI

struct LayoutPresetsView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var presets: [LayoutPreset] = []
    @State private var selectedPreset: LayoutPreset?
    @State private var selectedPresetWindowIndex: Int?
    /// 表示中の名前入力シート。リネーム対象はここに保持する（一覧・詳細のどちらからでも同じシートを開く）
    @State private var activeNameSheet: NameSheet?
    @State private var hoveredPresetId: UUID?
    @State private var presetToDelete: LayoutPreset?
    @State private var isShowingDeleteConfirmation = false
    @State private var activeToast: ToastType?
    @State private var toastTimerTask: Task<Void, Never>?
    @State private var presetImages: [String: NSImage] = [:]

    private enum ToastType: Equatable {
        case deleted(LayoutPreset)
        case success(String)
    }

    private enum NameSheet: Identifiable {
        case save
        case create
        case rename(LayoutPreset)

        var id: String {
            switch self {
            case .save: return "save"
            case .create: return "create"
            case .rename(let preset): return "rename-\(preset.id)"
            }
        }

        var title: String {
            switch self {
            case .save: return L("layout.save_title")
            case .create: return L("layout.create_title")
            case .rename: return L("layout.rename_title")
            }
        }

        var initialName: String {
            if case .rename(let preset) = self { return preset.name }
            return ""
        }

        /// 重複判定から除外する名前（リネーム時の自分自身。大文字小文字だけの変更を重複扱いしない）
        var excludedName: String? {
            if case .rename(let preset) = self { return preset.name }
            return nil
        }
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
        .sheet(item: $activeNameSheet) { sheet in
            PresetNameSheetView(
                title: sheet.title,
                initialName: sheet.initialName,
                isNameTaken: { viewModel.presetExists(named: $0, excluding: sheet.excludedName) },
                onApply: { name in performNameSheetAction(sheet, name: name) }
            )
        }
        .onDisappear {
            toastTimerTask?.cancel()
        }
        .onChange(of: selectedPreset) { _, newPreset in
            guard let preset = newPreset else {
                presetImages = [:]
                return
            }
            presetImages = preset.states.reduce(into: [String: NSImage]()) { dict, state in
                guard dict[state.imageName] == nil,
                      let image = viewModel.previewImage(name: state.imageName) else { return }
                dict[state.imageName] = image
            }
        }
    }

    // MARK: - List Screen

    @ViewBuilder
    private var presetListScreen: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button {
                    activeNameSheet = .save
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 16, height: 16)
                }
                .help(L("layout.save_current"))

                Button {
                    activeNameSheet = .create
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
                EmptySelectionView(
                    message: L("management.select_preset"),
                    icon: "rectangle.3.group"
                )
            } else {
                List {
                    ForEach(presets) { preset in
                        presetRow(for: preset)
                    }
                }
            }
        }
        .onAppear { refreshPresets() }
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

            makePresetActionButtons(for: preset)

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
        ThumbnailView(image: viewModel.croppedPreviewImage(for: state), iconFont: .caption2)
    }

    @ViewBuilder
    private func makePresetActionButtons(for preset: LayoutPreset) -> some View {
        PresetActionButtonsView(
            onApply: { applyPreset(preset) },
            onUpdate: { updatePreset(preset) },
            onRename: { startRename(preset) },
            onDelete: { confirmDeletePreset(preset) }
        )
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

                makePresetActionButtons(for: preset)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Minimap
            PresetMinimapView(
                states: preset.states,
                images: presetImages,
                selectedWindowId: selectedPresetWindowIndex.flatMap { index in
                    index < preset.states.count ? preset.states[index].windowId : nil
                },
                onWindowTapped: { windowId in
                    selectedPresetWindowIndex = preset.states.firstIndex { $0.windowId == windowId }
                }
            )

            Divider()

            // Window list | Window detail (read-only)
            HSplitView {
                presetWindowList(preset: preset)
                    .splitPanelFrame()
                PresetDetailView(
                    viewModel: viewModel,
                    preset: preset,
                    selectedIndex: selectedPresetWindowIndex
                )
                .splitPanelFrame()
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
                        Text(
                            "\(FormatUtils.formatDimensions(width: state.width, height: state.height))"
                            + " ・ (\(Int(state.originX)), \(Int(state.originY)))"
                        )
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
        activeNameSheet = .rename(preset)
    }

    /// 名前入力シートの確定処理。`name` は正規化済みで、既存プリセットと重複しない。
    private func performNameSheetAction(_ sheet: NameSheet, name: String) {
        switch sheet {
        case .save: savePreset(name: name)
        case .create: createNewLayout(name: name)
        case .rename(let preset): renamePreset(preset, to: name)
        }
    }

    private func refreshPresets() {
        let newPresets = viewModel.loadPresets()
        if newPresets != presets {
            presets = newPresets
        }
    }

    private func savePreset(name: String) {
        guard let states = viewModel.captureCurrentWindowStates() else { return }
        viewModel.savePreset(name: name, states: states)
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

    private func renamePreset(_ preset: LayoutPreset, to newName: String) {
        guard newName != preset.name else { return }
        guard viewModel.renamePreset(from: preset.name, to: newName) else { return }
        refreshPresets()
        if selectedPreset?.id == preset.id {
            selectedPreset = presets.first { $0.id == preset.id }
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
                try await Task.sleep(for: .seconds(AppConstants.layoutUndoTimeoutSeconds))
                withAnimation {
                    activeToast = nil
                }
            } catch {
                // Cancelled — do nothing
            }
        }
    }

    private func createNewLayout(name: String) {
        viewModel.createNewLayout(name: name)
        refreshPresets()
    }
}

// MARK: - PresetNameSheetView

struct PresetNameSheetView: View {
    let title: String
    /// 正規化済みの名前が既存プリセットと重複するか
    let isNameTaken: (String) -> Bool
    /// 確定時に正規化済みの名前で呼ばれる
    let onApply: (String) -> Void
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        initialName: String = "",
        isNameTaken: @escaping (String) -> Bool,
        onApply: @escaping (String) -> Void
    ) {
        self.title = title
        self.isNameTaken = isNameTaken
        self.onApply = onApply
        _name = State(initialValue: initialName)
    }

    var body: some View {
        let validation = PresetNameValidation.validate(name, isNameTaken: isNameTaken)
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            TextField(L("layout.name_placeholder"), text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: AppConstants.layoutDialogFieldWidth)
            if validation == .duplicate {
                Label(L("layout.name_exists"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Button(L("management.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(L("management.apply")) {
                    guard case .valid(let validName) = validation else { return }
                    onApply(validName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validation.validName == nil)
            }
        }
        .padding(20)
    }
}

// MARK: - PresetNameValidation

/// プリセット名の入力検証結果。名前は `LayoutPresetManager.normalizedName` で正規化してから判定する。
enum PresetNameValidation: Equatable {
    /// 空（空白のみを含む）
    case empty
    /// 既存のプリセットと重複する（保存すると上書きしてしまう）
    case duplicate
    /// 使用可能。正規化済みの名前を持つ
    case valid(String)

    var validName: String? {
        if case .valid(let name) = self { return name }
        return nil
    }

    static func validate(_ input: String, isNameTaken: (String) -> Bool) -> Self {
        guard let name = LayoutPresetManager.normalizedName(input) else { return .empty }
        return isNameTaken(name) ? .duplicate : .valid(name)
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
