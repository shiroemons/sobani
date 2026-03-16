import SwiftUI

/// サムネイル表示: 画像がある場合は表示、ない場合はプレースホルダー
struct ThumbnailView: View {
    let image: NSImage?
    var iconFont: Font?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
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

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
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
                    .aspectRatio(contentMode: .fit)
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

// MARK: - HSplitView Panel Modifier

extension View {
    /// HSplitViewの各パネルに適用し、コンテンツの最小幅が親に伝播するのを遮断する。
    /// GeometryReaderの最小サイズがゼロである性質を利用して、HSplitViewがidealWidthのみで分割を決定するようにする。
    func splitPanelFrame() -> some View {
        GeometryReader { _ in self }
            .frame(idealWidth: AppConstants.managementSplitIdealWidth)
    }
}
