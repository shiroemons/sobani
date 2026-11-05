import SwiftUI

struct LayoutPresetsView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var presets: [LayoutPreset] = []
    @State private var selectedPreset: LayoutPreset?
    @State private var selectedPresetWindowIndex: Int?
    /// 表示中の名前入力シート。リネーム対象はここに保持する（一覧・詳細のどちらからでも同じシートを開く）
    @State private var activeNameSheet: NameSheet?
    /// プリセットごとのサムネイル（ウィンドウ順）。描画のたびにクロップ画像を作らないよう事前に計算する
    @State private var presetThumbnails: [UUID: [NSImage?]] = [:]
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
        // メニューなど管理パネル以外からの保存・削除・リネームも反映する
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.layoutPresetsDidChange)) { _ in
            refreshPresets()
        }
        .onChange(of: viewModel.registeredImageNames) {
            rebuildThumbnails()
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
                ToolbarIconButton(systemImage: "square.and.arrow.down", help: L("layout.save_current")) {
                    activeNameSheet = .save
                }

                ToolbarIconButton(systemImage: "plus.square", help: L("layout.create_new")) {
                    activeNameSheet = .create
                }

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
                    Text(LayoutPresetText.itemsCount(preset.states.count))
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
                    ForEach(Array(thumbnails(for: preset).enumerated()), id: \.offset) { _, image in
                        RoundedThumbnail(image: image, size: RoundedThumbnail.compactSize, iconFont: .caption2)
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
        .hoverRowHighlight()
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

    private func thumbnails(for preset: LayoutPreset) -> [NSImage?] {
        presetThumbnails[preset.id] ?? []
    }

    private func thumbnail(for preset: LayoutPreset, at index: Int) -> NSImage? {
        let images = thumbnails(for: preset)
        return images.indices.contains(index) ? images[index] : nil
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
                // 古いプリセットは windowId がすべて 0 のため、ID ではなく位置で選択する
                selectedIndices: selectedPresetWindowIndex.map { [$0] } ?? [],
                onWindowTapped: { index in
                    selectedPresetWindowIndex = index
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
                    RoundedThumbnail(image: thumbnail(for: preset, at: index), iconFont: .caption2)

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
        if newPresets != presets || presetThumbnails.isEmpty {
            presets = newPresets
            rebuildThumbnails()
        }
        // 詳細表示中のプリセットを最新の内容に差し替える（他の経路で削除された場合は一覧へ戻る）
        if let selected = selectedPreset {
            let latest = newPresets.first { $0.id == selected.id }
            if latest != selected {
                selectedPreset = latest
            }
        }
    }

    private func rebuildThumbnails() {
        // 古いファイルの削除に失敗したリネームなどで同じ ID のプリセットが並ぶことがあるため、重複キーは先勝ちにする
        presetThumbnails = Dictionary(
            presets.map { preset in
                (preset.id, preset.states.map { viewModel.croppedPreviewImage(for: $0) })
            },
            uniquingKeysWith: { first, _ in first }
        )
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
        showToast(.success(String(format: L("layout.updated_message"), preset.name)))
    }

    private func renamePreset(_ preset: LayoutPreset, to newName: String) {
        guard newName != preset.name else { return }
        guard viewModel.renamePreset(from: preset.name, to: newName) else { return }
        refreshPresets()
    }

    private func confirmDeletePreset(_ preset: LayoutPreset) {
        presetToDelete = preset
        isShowingDeleteConfirmation = true
    }

    private func performDeletePreset(_ preset: LayoutPreset) {
        viewModel.deletePreset(named: preset.name)
        // 詳細表示中なら refreshPresets で一覧へ戻る
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

// MARK: - LayoutPresetText

enum LayoutPresetText {
    private static let itemsCountKey = "layout.items_count"

    /// プリセットのウィンドウ数の表示（例: "1 item" / "3 items" / "3件"）。
    ///
    /// 複数形は書式化するときのロケールで選ばれるため、システムではなく表示言語のロケールを渡す
    /// （アプリ内で言語を切り替えたときに、システムの言語の規則で "1 items" にならないように）。
    static func itemsCount(_ count: Int, bundle: Bundle? = sharedLocalizationBundle) -> String {
        let format = bundle.map { NSLocalizedString(itemsCountKey, bundle: $0, comment: "") } ?? L(itemsCountKey)
        let languageCode = bundle?.bundleURL.deletingPathExtension().lastPathComponent
        let locale = languageCode.map { Locale(identifier: $0) } ?? .current
        return String(format: format, locale: locale, count)
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
