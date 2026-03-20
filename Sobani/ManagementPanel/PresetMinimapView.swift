import SwiftUI

struct PresetMinimapView: View {
    let states: [WindowState]
    var images: [String: NSImage]?
    var selectedWindowId: Int?
    var onWindowTapped: ((Int) -> Void)?
    var isDragEnabled: Bool = false
    var onWindowDragChanged: ((Int, CGPoint) -> Void)?
    var onWindowDragEnded: ((Int, CGPoint) -> Void)?

    private static let maxHeight: CGFloat = 400

    @State private var screenFrames: [CGRect] = NSScreen.screens.map(\.frame)
    @State private var totalBounds: CGRect = .zero
    @State private var draggingWindowId: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartOrigin: CGPoint = .zero

    var body: some View {
        minimapCanvas
            .onAppear { updateScreenInfo() }
            .onChange(of: states) { updateScreenInfo() }
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
                    let cachedBounds = totalBounds
                    let cachedFrames = screenFrames
                    let layout = MinimapLayout.calculate(
                        in: geometry.size,
                        states: states,
                        precomputedBounds: cachedBounds,
                        screenFrames: cachedFrames
                    )
                    ZStack(alignment: .topLeading) {
                        // Screens
                        ForEach(Array(layout.screens.enumerated()), id: \.offset) { _, screenRect in
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                .fill(Color.secondary.opacity(0.05))
                                .frame(width: screenRect.width, height: screenRect.height)
                                .offset(x: screenRect.origin.x, y: screenRect.origin.y)
                        }

                        // Windows
                        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                            let windowRect = layout.windowRect(for: state)
                            let isSelected = state.windowId == selectedWindowId
                            let isDragging = draggingWindowId == state.windowId
                            let displayOffset = isDragging ? dragOffset : .zero
                            minimapWindow(state: state, isSelected: isSelected)
                                .frame(
                                    width: max(windowRect.width, 8),
                                    height: max(windowRect.height, 8)
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
                                        if draggingWindowId == nil {
                                            draggingWindowId = state.windowId
                                            dragStartOrigin = CGPoint(
                                                x: state.originX, y: state.originY
                                            )
                                        }
                                        dragOffset = value.translation
                                        let origin = newOrigin(
                                            from: value.translation, layout: layout
                                        )
                                        onWindowDragChanged?(state.windowId, origin)
                                    }
                                    .onEnded { value in
                                        let origin = newOrigin(
                                            from: value.translation, layout: layout
                                        )
                                        onWindowDragEnded?(state.windowId, origin)
                                        draggingWindowId = nil
                                        dragOffset = .zero
                                    }
                                )
                                .onTapGesture {
                                    onWindowTapped?(state.windowId)
                                }
                        }
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
                        .aspectRatio(contentMode: .fit)
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
