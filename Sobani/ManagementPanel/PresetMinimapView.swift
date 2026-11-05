import SwiftUI

struct PresetMinimapView: View {
    let states: [WindowState]
    var images: [String: NSImage]?
    /// 強調表示する `states` のインデックス。windowId は古いプリセットで重複（すべて 0）しうるため位置で指定する
    var selectedIndices: Set<Int> = []
    /// タップされたウィンドウの `states` のインデックス
    var onWindowTapped: ((Int) -> Void)?
    var isDragEnabled: Bool = false
    var onWindowDragChanged: ((Int, CGPoint) -> Void)?
    var onWindowDragEnded: ((Int, CGPoint) -> Void)?

    private static let maxHeight: CGFloat = 400
    /// ミニマップ上でウィンドウを描く最小サイズ（小さすぎるとタップ・ドラッグできない）
    private static let minWindowSize: CGFloat = 8

    @State private var screenFrames: [CGRect] = NSScreen.screens.map(\.frame)
    /// `.null` の間は描画時に `states` から計算する（初回描画で空の範囲を使わないため）
    @State private var totalBounds: CGRect = .null
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartOrigin: CGPoint = .zero

    var body: some View {
        minimapCanvas
            .onAppear { updateScreenInfo() }
            .onChange(of: states) {
                // ドラッグ中に範囲が変わると倍率が変わり、ドラッグ量の換算がずれるため完了後に更新する
                guard draggingIndex == nil else { return }
                updateScreenInfo()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didChangeScreenParametersNotification
                )
            ) { _ in
                updateScreenInfo()
            }
    }

    private func updateScreenInfo() {
        screenFrames = NSScreen.screens.map(\.frame)
        totalBounds = MinimapLayout.computeTotalBounds(states: states, screenFrames: screenFrames)
    }

    private func newOrigin(from translation: CGSize, layout: MinimapLayout) -> CGPoint {
        let macDelta = layout.macOSDelta(from: translation)
        return CGPoint(
            x: dragStartOrigin.x + macDelta.x,
            y: dragStartOrigin.y + macDelta.y
        )
    }

    @ViewBuilder
    private var minimapCanvas: some View {
        let contentAspectRatio = totalBounds.height > 0 && !screenFrames.isEmpty
            ? totalBounds.width / totalBounds.height
            : 16.0 / 9.0

        // Color.clear properly accepts size constraints from .aspectRatio
        // GeometryReader inside .overlay receives the actual rendered frame size
        Color.clear
            .aspectRatio(contentAspectRatio, contentMode: .fit)
            .frame(minHeight: MinimapLayout.minimapFallbackHeight, maxHeight: Self.maxHeight)
            .clipped()
            .background { WindowDragBlocker(isEnabled: isDragEnabled) }
            .overlay {
                GeometryReader { geometry in
                    let layout = MinimapLayout.calculate(
                        in: geometry.size,
                        states: states,
                        precomputedBounds: totalBounds.isNull ? nil : totalBounds,
                        screenFrames: screenFrames
                    )
                    if !layout.isEmpty {
                        minimapContent(layout: layout)
                    }
                }
            }
            .overlay {
                if isDragEnabled {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isDragEnabled)
    }

    @ViewBuilder
    private func minimapContent(layout: MinimapLayout) -> some View {
        ZStack(alignment: .topLeading) {
            // Screens
            ForEach(Array(layout.screens.enumerated()), id: \.offset) { _, screenRect in
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    .fill(Color.secondary.opacity(0.05))
                    .frame(width: screenRect.width, height: screenRect.height)
                    .offset(x: screenRect.origin.x, y: screenRect.origin.y)
            }

            // Windows（背面から描く）
            ForEach(Array(states.indices.reversed()), id: \.self) { index in
                minimapWindowItem(index: index, layout: layout)
            }
        }
    }

    @ViewBuilder
    private func minimapWindowItem(index: Int, layout: MinimapLayout) -> some View {
        let state = states[index]
        let isDragging = draggingIndex == index
        // ドラッグ中は開始位置 + ドラッグ量で描く（ドラッグ中に状態が更新されても二重に動かないように）
        let windowRect = isDragging
            ? layout.windowRect(
                for: dragStartOrigin.x, originY: dragStartOrigin.y,
                width: state.width, height: state.height
            )
            : layout.windowRect(for: state)
        let displayOffset = isDragging ? dragOffset : .zero
        minimapWindow(state: state, isSelected: selectedIndices.contains(index))
            .frame(
                width: max(windowRect.width, Self.minWindowSize),
                height: max(windowRect.height, Self.minWindowSize)
            )
            .offset(
                x: windowRect.origin.x + displayOffset.width,
                y: windowRect.origin.y + displayOffset.height
            )
            .gesture(
                DragGesture(
                    minimumDistance: isDragEnabled
                        ? AppConstants.minimapDragMinimumDistance : .infinity
                )
                .onChanged { value in
                    if draggingIndex == nil {
                        draggingIndex = index
                        dragStartOrigin = CGPoint(x: state.originX, y: state.originY)
                    }
                    dragOffset = value.translation
                    let origin = newOrigin(from: value.translation, layout: layout)
                    onWindowDragChanged?(state.windowId, origin)
                }
                .onEnded { value in
                    let origin = newOrigin(from: value.translation, layout: layout)
                    onWindowDragEnded?(state.windowId, origin)
                    draggingIndex = nil
                    dragOffset = .zero
                    updateScreenInfo()
                }
            )
            .onTapGesture {
                onWindowTapped?(index)
            }
    }

    @ViewBuilder
    private func minimapWindow(state: WindowState, isSelected: Bool) -> some View {
        let originalImage: NSImage? = images?[state.imageName]
        let displayImage = originalImage.map {
            CroppedImageHelper.croppedImage(
                from: $0, cropRect: state.cropRect, imageName: state.imageName)
        }

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                if let displayImage {
                    Image(nsImage: displayImage)
                        .resizable()
                        .scaledToFit()
                        .clipped()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(
                        isSelected ? Color.accentColor : Color.accentColor.opacity(0.6),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}

private struct WindowDragBlocker: NSViewRepresentable {
    let isEnabled: Bool

    func makeNSView(context: Context) -> DragBlockingView {
        DragBlockingView()
    }

    func updateNSView(_ nsView: DragBlockingView, context: Context) {
        nsView.isBlockingEnabled = isEnabled
    }
}

private final class DragBlockingView: NSView {
    var isBlockingEnabled = false
    override var mouseDownCanMoveWindow: Bool { !isBlockingEnabled }
}
