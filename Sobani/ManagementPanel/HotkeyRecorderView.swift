import AppKit
import SwiftUI

// MARK: - KeyCaptureView

/// キー入力をキャプチャするNSView
final class KeyCaptureView: NSView {
    var onKeyCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // ESCでキャンセル
        if event.keyCode == AppConstants.escKeyCode {
            onCancel?()
            return
        }
        // 修飾キーが1つ以上必要（修飾キーのみは不可）
        guard !modifiers.isEmpty else { return }
        onKeyCapture?(event.keyCode, modifiers)
    }
}

// MARK: - HotkeyRecorderRepresentable

/// SwiftUIからキーキャプチャViewを使うためのブリッジ
struct HotkeyRecorderRepresentable: NSViewRepresentable {
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyCapture = { code, mods in
            keyCode = code
            modifiers = mods
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        if isRecording, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
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
                        keyCode: $keyCode,
                        modifiers: $modifiers,
                        isRecording: $isRecording
                    )
                    .frame(width: 0, height: 0)  // 不可視だがファーストレスポンダーとして機能
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            } else {
                Button {
                    isRecording = true
                } label: {
                    Text(KeyCodeMapper.shortcutDisplayString(keyCode: keyCode, modifiers: modifiers))
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 60)
                }
            }
        }
        .frame(height: 24)
    }
}
