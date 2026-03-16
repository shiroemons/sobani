import SwiftUI

struct PresetMinimapView: View {
    let states: [WindowState]
    var images: [String: NSImage]?
    var selectedWindowId: Int?
    var onWindowTapped: ((Int) -> Void)?

    private static let maxHeight: CGFloat = 400

    @State private var screenFrames: [CGRect] = NSScreen.screens.map(\.frame)
    @State private var totalBounds: CGRect = .zero

    var body: some View {
        minimapCanvas
            .onAppear { updateScreenInfo() }
            .onChange(of: states) { updateScreenInfo() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                updateScreenInfo()
            }
    }

    private func updateScreenInfo() {
        screenFrames = NSScreen.screens.map(\.frame)
        totalBounds = MinimapLayout.computeTotalBounds(states: states, screenFrames: screenFrames)
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
                            minimapWindow(state: state, isSelected: isSelected)
                                .frame(width: max(windowRect.width, 8), height: max(windowRect.height, 8))
                                .offset(x: windowRect.origin.x, y: windowRect.origin.y)
                                .onTapGesture {
                                    onWindowTapped?(state.windowId)
                                }
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private func minimapWindow(state: WindowState, isSelected: Bool) -> some View {
        let originalImage: NSImage? = images?[state.imageName]
        let displayImage = originalImage.map { CroppedImageHelper.croppedImage(from: $0, cropRect: state.cropRect, imageName: state.imageName) }

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
