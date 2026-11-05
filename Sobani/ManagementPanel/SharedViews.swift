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
