import SwiftUI

struct PresetMinimapView: View {
    let states: [WindowState]

    var body: some View {
        GeometryReader { geometry in
            let layout = calculateLayout(in: geometry.size)
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
                    minimapWindow(state: state)
                        .frame(width: max(windowRect.width, 8), height: max(windowRect.height, 8))
                        .offset(x: windowRect.origin.x, y: windowRect.origin.y)
                }
            }
        }
    }

    @ViewBuilder
    private func minimapWindow(state: WindowState) -> some View {
        let image: NSImage? = if state.imageName == AppConstants.defaultImageName {
            ImageManager.shared.defaultImage()
        } else {
            ImageManager.shared.loadRegisteredImageCached(named: state.imageName)
        }
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
            )
    }

    // MARK: - Layout Calculation

    private struct MinimapLayout {
        let screens: [CGRect]
        let scale: CGFloat
        let offset: CGPoint

        func windowRect(for state: WindowState) -> CGRect {
            // Flip Y: macOS has origin at bottom-left, SwiftUI at top-left
            let totalBounds = screens.reduce(CGRect.null) { $0.union($1) }
            let scaledX = (state.originX * scale) + offset.x - totalBounds.origin.x * scale
            let scaledY = totalBounds.height - (state.originY + state.height) * scale + offset.y - totalBounds.origin.y * scale
            let scaledW = state.width * scale
            let scaledH = state.height * scale
            return CGRect(x: scaledX, y: scaledY, width: scaledW, height: scaledH)
        }
    }

    @MainActor
    private func calculateLayout(in availableSize: CGSize) -> MinimapLayout {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else {
            return MinimapLayout(screens: [], scale: 1, offset: .zero)
        }

        // Calculate total bounds of all screens
        let totalBounds = screenFrames.reduce(CGRect.null) { $0.union($1) }

        // Calculate scale to fit
        let padding: CGFloat = 16
        let usableWidth = availableSize.width - padding * 2
        let usableHeight = availableSize.height - padding * 2
        let scaleX = usableWidth / totalBounds.width
        let scaleY = usableHeight / totalBounds.height
        let scale = min(scaleX, scaleY)

        // Center the minimap
        let scaledWidth = totalBounds.width * scale
        let scaledHeight = totalBounds.height * scale
        let offsetX = (availableSize.width - scaledWidth) / 2
        let offsetY = (availableSize.height - scaledHeight) / 2

        // Convert screen frames
        let scaledScreens = screenFrames.map { frame -> CGRect in
            let scaledX = (frame.origin.x - totalBounds.origin.x) * scale + offsetX
            // Flip Y
            let scaledY = (totalBounds.height - (frame.origin.y - totalBounds.origin.y + frame.height)) * scale + offsetY
            return CGRect(
                x: scaledX,
                y: scaledY,
                width: frame.width * scale,
                height: frame.height * scale
            )
        }

        return MinimapLayout(screens: scaledScreens, scale: scale, offset: CGPoint(x: offsetX, y: offsetY))
    }
}
