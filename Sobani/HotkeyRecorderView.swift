import Cocoa
import os.log

// MARK: - HotkeyRecorderView

/// ホットキー1行分の記録UIコンポーネント。
@MainActor
final class HotkeyRecorderView: NSView {

    // MARK: - Layout Constants

    private static let viewHeight: CGFloat = 24
    private static let actionLabelWidth: CGFloat = 100
    private static let actionLabelX: CGFloat = 0
    private static let keyFieldX: CGFloat = 104
    private static let keyFieldWidth: CGFloat = 80
    private static let recordButtonX: CGFloat = 192
    private static let recordButtonWidth: CGFloat = 60
    private static let resetButtonX: CGFloat = 260
    private static let resetButtonWidth: CGFloat = 60
    private static let cornerRadius: CGFloat = 4
    private static let borderWidth: CGFloat = 1
    private static let fontSizeLabel: CGFloat = 13

    // MARK: - Properties

    private let action: HotkeyAction
    private var keyDisplayField: NSTextField?
    private var recordButton: NSButton?
    private var resetButton: NSButton?
    private var isRecording = false
    nonisolated(unsafe) private var recordMonitor: Any?

    private let logger = Logger(category: "HotkeyRecorderView")

    var onHotkeyChanged: ((HotkeyAction, HotkeyBinding) -> Void)?

    // MARK: - Init

    init(action: HotkeyAction, frame: NSRect) {
        self.action = action
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupView() {
        let height = Self.viewHeight

        // アクション名ラベル
        let nameLabel = NSTextField(labelWithString: action.displayName)
        nameLabel.frame = NSRect(x: Self.actionLabelX, y: 0, width: Self.actionLabelWidth, height: height)
        nameLabel.font = .systemFont(ofSize: Self.fontSizeLabel)
        addSubview(nameLabel)

        // キー表示フィールド
        let field = NSTextField(labelWithString: HotkeyManager.shared.binding(for: action).displayString)
        field.frame = NSRect(x: Self.keyFieldX, y: 0, width: Self.keyFieldWidth, height: height)
        field.font = .monospacedSystemFont(ofSize: Self.fontSizeLabel, weight: .regular)
        field.alignment = .center
        field.wantsLayer = true
        field.layer?.borderWidth = Self.borderWidth
        field.layer?.borderColor = NSColor.separatorColor.cgColor
        field.layer?.cornerRadius = Self.cornerRadius
        addSubview(field)
        keyDisplayField = field

        // 記録ボタン
        let recBtn = NSButton(
            frame: NSRect(x: Self.recordButtonX, y: 0, width: Self.recordButtonWidth, height: height)
        )
        recBtn.bezelStyle = .rounded
        recBtn.title = L("management.record")
        recBtn.target = self
        recBtn.action = #selector(recordButtonTapped)
        addSubview(recBtn)
        recordButton = recBtn

        // リセットボタン
        let rstBtn = NSButton(
            frame: NSRect(x: Self.resetButtonX, y: 0, width: Self.resetButtonWidth, height: height)
        )
        rstBtn.bezelStyle = .rounded
        rstBtn.title = L("management.reset")
        rstBtn.target = self
        rstBtn.action = #selector(resetButtonTapped)
        addSubview(rstBtn)
        resetButton = rstBtn
    }

    // MARK: - Public API

    func updateDisplay() {
        keyDisplayField?.stringValue = HotkeyManager.shared.binding(for: action).displayString
        setRecordingState(false)
    }

    // MARK: - Actions

    @objc private func recordButtonTapped() {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    @objc private func resetButtonTapped() {
        HotkeyManager.shared.resetBinding(for: action)
        keyDisplayField?.stringValue = action.defaultBinding.displayString
        setRecordingState(false)
        onHotkeyChanged?(action, action.defaultBinding)
    }

    // MARK: - Recording

    private func startRecording() {
        setRecordingState(true)
        keyDisplayField?.stringValue = L("hotkey.waiting")
        keyDisplayField?.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.2).cgColor

        let actionForBlock = action
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event: event, action: actionForBlock)
        }
    }

    private func handleKeyDown(event: NSEvent, action: HotkeyAction) -> NSEvent? {
        // ESC → キャンセル（nilを返してパネルのESC処理を防ぐ）
        if event.keyCode == AppConstants.escKeyCode {
            cancelRecording()
            return nil
        }

        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let hasModifier = !eventModifiers.isDisjoint(with: requiredModifiers)

        guard hasModifier else {
            logger.warning("\(L("hotkey.needs_modifier"))")
            cancelRecording()
            return nil
        }

        let binding = HotkeyBinding(keyCode: event.keyCode, modifierMask: eventModifiers.rawValue)

        if HotkeyManager.shared.hasSystemConflict(binding) {
            logger.warning("\(L("hotkey.conflict_system"))")
            cancelRecording()
            return nil
        }

        if HotkeyManager.shared.hasSobaniConflict(binding, excluding: action) {
            logger.warning("\(L("hotkey.conflict_sobani"))")
            cancelRecording()
            return nil
        }

        // 記録成功
        finishRecording(binding: binding)
        return nil
    }

    private func cancelRecording() {
        stopRecordMonitor()
        setRecordingState(false)
        keyDisplayField?.stringValue = HotkeyManager.shared.binding(for: action).displayString
        keyDisplayField?.layer?.backgroundColor = nil
    }

    private func finishRecording(binding: HotkeyBinding) {
        stopRecordMonitor()
        setRecordingState(false)
        keyDisplayField?.stringValue = binding.displayString
        keyDisplayField?.layer?.backgroundColor = nil
        onHotkeyChanged?(action, binding)
    }

    private func setRecordingState(_ recording: Bool) {
        isRecording = recording
        recordButton?.title = recording ? L("hotkey.waiting") : L("management.record")
        if !recording {
            keyDisplayField?.layer?.backgroundColor = nil
        }
    }

    private func stopRecordMonitor() {
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
    }
}
