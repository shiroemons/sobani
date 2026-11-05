import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - HotkeyInputValidator

/// ホットキー入力の検証（UI から切り離してテストできるようにする）
enum HotkeyInputValidator {
    enum Result: Equatable {
        /// ホットキーとして登録できる組み合わせ（修飾キーは `supportedModifiers` に限定済み）
        case accept(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
        /// 録音を取り消す（Esc）
        case cancel
        /// 登録できない組み合わせ（修飾キーなし・Shift のみなど）。録音を続ける
        case ignore
    }

    /// グローバルホットキー（Carbon）が扱える修飾キー。
    ///
    /// `.deviceIndependentFlagsMask` には Caps Lock・fn・テンキーなども含まれるが、Carbon の登録では
    /// 落とされるため、それらだけで「修飾キーあり」と判定すると単独キーがシステム全体で奪われてしまう。
    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static func normalizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection(supportedModifiers)
    }

    static func evaluate(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Result {
        if keyCode == UInt16(kVK_Escape) {
            return .cancel
        }
        let modifiers = normalizedModifiers(modifierFlags)
        // Shift だけでは通常の文字入力（大文字など）を奪ってしまうため、Shift 以外の修飾キーを必須にする
        guard !modifiers.subtracting(.shift).isEmpty else { return .ignore }
        return .accept(keyCode: keyCode, modifiers: modifiers)
    }

    /// 同じキーと修飾キーの組み合わせが複数の操作に割り当てられているか。
    ///
    /// 修飾キーは Carbon が扱うものに限定して比較する（Caps Lock などの違いだけでは別のホットキーにならない）。
    static func containsDuplicates(_ shortcuts: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)]) -> Bool {
        var seen = Set<UInt64>()
        for shortcut in shortcuts {
            let modifiers = normalizedModifiers(shortcut.modifiers)
            let key = UInt64(shortcut.keyCode) << 32 | UInt64(modifiers.rawValue)
            if !seen.insert(key).inserted {
                return true
            }
        }
        return false
    }
}

// MARK: - KeyCaptureView

/// キー入力をキャプチャするNSView
final class KeyCaptureView: NSView {
    var onKeyCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        let center = NotificationCenter.default
        if let window {
            center.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        }
        if let newWindow {
            // 録音中にパネルを閉じたり他のウィンドウへ移ったりしたら録音をやめ、ホットキーを登録し直させる
            center.addObserver(
                self, selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification, object: newWindow
            )
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        onCancel?()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // ⌘ を含む組み合わせはメニューなどに先に取られるため、録音中はここで受け取る
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch HotkeyInputValidator.evaluate(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
        case .accept(let keyCode, let modifiers):
            onKeyCapture?(keyCode, modifiers)
        case .cancel:
            onCancel?()
        case .ignore:
            break
        }
    }
}

// MARK: - HotkeyRecorderRepresentable

/// SwiftUIからキーキャプチャViewを使うためのブリッジ
struct HotkeyRecorderRepresentable: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyCapture = onCapture
        nsView.onCancel = onCancel
        guard isRecording else { return }
        guard nsView.window?.firstResponder !== nsView else { return }
        nsView.window?.makeFirstResponder(nsView)
    }
}

// MARK: - HotkeyRecorderButton

/// ホットキーレコーディングボタン
/// 通常時はショートカット表示、クリックで録音モードに切り替え
struct HotkeyRecorderButton: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    @State private var isRecording = false

    var body: some View {
        ZStack {
            if isRecording {
                HStack {
                    Text(L("management.hotkey_press_key"))
                        .foregroundStyle(.secondary)
                    HotkeyRecorderRepresentable(
                        isRecording: isRecording,
                        onCapture: { code, mods in
                            keyCode = code
                            modifiers = mods
                            stopRecording()
                        },
                        onCancel: { stopRecording() }
                    )
                    // 不可視だがファーストレスポンダーとして機能
                    .frame(width: 0, height: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            } else {
                Button {
                    startRecording()
                } label: {
                    Text(KeyCodeMapper.shortcutDisplayString(
                        keyCode: keyCode,
                        modifiers: modifiers
                    ))
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 60)
                }
            }
        }
        .frame(height: 24)
        .onDisappear {
            stopRecording()
        }
    }

    /// 録音中は登録済みのグローバルホットキーを外す（押したキーが既存のホットキーとして実行されないように）
    private func startRecording() {
        CarbonHotkeyManager.shared.unregisterAll()
        isRecording = true
    }

    /// 録音を終え、AppDelegate にホットキーを登録し直させる
    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        NotificationCenter.default.post(name: AppConstants.hotkeySettingsDidChange, object: nil)
    }
}
