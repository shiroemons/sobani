import SwiftUI

/// サムネイル表示: 画像がある場合は表示、ない場合はプレースホルダー
struct ThumbnailView: View {
    let image: NSImage?
    var iconFont: Font?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .font(iconFont)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

/// 一覧の行で使う角丸サムネイル
struct RoundedThumbnail: View {
    /// 一覧の行の標準サイズ
    static let rowSize: CGFloat = 40
    /// 1行に複数並べるときのサイズ
    static let compactSize: CGFloat = 36
    private static let cornerRadius: CGFloat = 6

    let image: NSImage?
    var size: CGFloat = Self.rowSize
    var iconFont: Font?

    var body: some View {
        ThumbnailView(image: image, iconFont: iconFont)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

/// ツールバーのアイコンボタン
struct ToolbarIconButton: View {
    private static let iconSize: CGFloat = 16

    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: Self.iconSize, height: Self.iconSize)
        }
        .help(help)
    }
}

/// 不透明度のスライダーと割合表示
struct OpacitySliderRow: View {
    private static let valueLabelWidth: CGFloat = 40

    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var leadingSystemImage: String?
    var valueFont: Font = .caption.monospaced()
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            Text(FormatUtils.formatOpacity(value))
                .font(valueFont)
                .frame(width: Self.valueLabelWidth, alignment: .trailing)
        }
    }
}

/// 詳細画面の基本情報（名前・番号・寸法）
struct DetailInfoLabels: View {
    let name: String
    let number: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(name)
                    .font(.headline)
            } icon: {
                Image(systemName: "photo")
            }

            Label {
                Text(number)
                    .font(.caption.monospaced())
            } icon: {
                Image(systemName: "number")
            }

            Label {
                Text(detail)
                    .font(.caption)
            } icon: {
                Image(systemName: "ruler")
            }
        }
    }
}

/// 未選択時の空状態表示
struct EmptySelectionView: View {
    let message: String
    var icon: String = "square.on.square.dashed"
    var hint: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 画像プレビュー: 画像がある場合は表示、ない場合はプレースホルダーアイコン
struct ImagePreviewBox: View {
    let image: NSImage?

    var body: some View {
        GroupBox {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: AppConstants.managementPreviewMaxHeight)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: AppConstants.managementPreviewMaxHeight)
            }
        }
    }
}

// MARK: - Hover Row Highlight

/// リストの行にマウスが乗っている間、行の背景を強調する。
///
/// ホバー状態を行ごとに持つため、ホバーの移動で他の行が再描画されない。
private struct HoverRowHighlight: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovered = $0 }
            .listRowBackground(
                isHovered ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor) : nil
            )
    }
}

extension View {
    func hoverRowHighlight() -> some View {
        modifier(HoverRowHighlight())
    }
}

// MARK: - HSplitView Panel Modifier

extension View {
    /// HSplitViewの各パネルに適用し、コンテンツの最小幅が親に伝播するのを遮断する。
    /// GeometryReaderの最小サイズがゼロである性質を利用して、HSplitViewがidealWidthのみで分割を決定するようにする。
    func splitPanelFrame() -> some View {
        GeometryReader { _ in self }
            .frame(idealWidth: AppConstants.managementSplitIdealWidth)
    }
}
