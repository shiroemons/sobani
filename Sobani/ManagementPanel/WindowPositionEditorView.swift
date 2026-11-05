import SwiftUI

struct WindowPositionEditorView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    let windowInfo: ManagementPanelViewModel.WindowInfo
    @State private var fields = PositionEditorInput.Fields()
    /// 最後に読み込んだ値。未編集のまま適用して丸め誤差でずれるのを防ぐ
    @State private var loadedFields = PositionEditorInput.Fields()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("management.position"))
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                labeledField("X", text: $fields.x)
                labeledField("Y", text: $fields.y)
            }

            Text(L("management.size"))
                .font(.subheadline.bold())
                .padding(.top, 4)

            HStack(spacing: 12) {
                labeledField("W", text: $fields.width)
                labeledField("H", text: $fields.height)
            }

            Button(L("management.apply")) {
                applyChanges()
            }
            .buttonStyle(.bordered)
            .disabled(fields == loadedFields || PositionEditorInput.parseFrame(fields) == nil)
            .padding(.top, 4)
        }
        .onAppear { loadValues() }
        // 位置・サイズ以外（不透明度・ゴーストなど）の変更では入力中の値を破棄しない
        .onChange(of: currentFields) { loadValues() }
        .onChange(of: windowInfo.windowId) { loadValues() }
    }

    private var currentFields: PositionEditorInput.Fields {
        PositionEditorInput.fields(
            originX: windowInfo.originX, originY: windowInfo.originY,
            width: windowInfo.width, height: windowInfo.height
        )
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 16)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .frame(maxWidth: 80)
        }
    }

    private func loadValues() {
        fields = currentFields
        loadedFields = fields
    }

    private func applyChanges() {
        guard fields != loadedFields, let frame = PositionEditorInput.parseFrame(fields) else { return }
        viewModel.changePositionAndSize(
            windowId: windowInfo.windowId,
            origin: frame.origin,
            size: frame.size
        )
    }
}

// MARK: - Input Conversion

/// 位置エディタの入力値の変換と検証（画像基準の座標・サイズ）
enum PositionEditorInput {
    struct Fields: Equatable {
        var x = ""
        var y = ""
        var width = ""
        var height = ""
    }

    /// 入力として受け付ける座標・サイズの絶対値の上限（極端な値でウィンドウが不正な位置へ飛ぶのを防ぐ）
    static let maxMagnitude: CGFloat = 100_000

    /// 表示用の文字列に変換する。切り捨てではなく四捨五入する（切り捨てると適用のたびに最大 1pt ずれる）。
    static func fields(originX: CGFloat, originY: CGFloat, width: CGFloat, height: CGFloat) -> Fields {
        Fields(
            x: displayString(originX), y: displayString(originY),
            width: displayString(width), height: displayString(height)
        )
    }

    /// 入力値を検証して画像のフレームを返す。数値でない・有限でない・範囲外・サイズが正でない場合は nil。
    static func parseFrame(_ fields: Fields) -> CGRect? {
        guard let x = parseValue(fields.x),
              let y = parseValue(fields.y),
              let width = parseValue(fields.width),
              let height = parseValue(fields.height),
              width > 0, height > 0 else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func displayString(_ value: CGFloat) -> String {
        // NaN・無限大・Int の範囲外では Int(_:) がクラッシュするため、表現できない値は空にする
        Int(exactly: value.rounded()).map(String.init) ?? ""
    }

    private static func parseValue(_ text: String) -> CGFloat? {
        // Double は "nan" や "inf" も受け付けるため、有限かつ範囲内に限る
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)),
              value.isFinite,
              abs(value) <= maxMagnitude else { return nil }
        return CGFloat(value)
    }
}
