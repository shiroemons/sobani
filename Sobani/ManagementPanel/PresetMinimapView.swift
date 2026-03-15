import SwiftUI

struct PresetMinimapView: View {
    let states: [WindowState]
    var images: [String: NSImage]?
    var selectedWindowId: Int?
    var onWindowTapped: ((Int) -> Void)?

    private static let minHeight: CGFloat = 150
    private static let maxHeight: CGFloat = 450

    var body: some View {
        minimapCanvas
            .clipped()
    }

    @ViewBuilder
    private var minimapCanvas: some View {
        GeometryReader { geometry in
            let layout = MinimapLayout.calculate(in: geometry.size, states: states)
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
        .aspectRatio(minimapAspectRatio, contentMode: .fit)
        .frame(minHeight: Self.minHeight, maxHeight: Self.maxHeight)
    }

    @MainActor
    private var minimapAspectRatio: CGFloat {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else { return 16 / 9 }

        var totalBounds = screenFrames.reduce(CGRect.null) { $0.union($1) }
        for state in states {
            let windowFrame = CGRect(
                x: state.originX, y: state.originY,
                width: state.width, height: state.height
            )
            totalBounds = totalBounds.union(windowFrame)
        }

        guard totalBounds.height > 0 else { return 16 / 9 }
        return totalBounds.width / totalBounds.height
    }

    @ViewBuilder
    private func minimapWindow(state: WindowState, isSelected: Bool) -> some View {
        let originalImage: NSImage? = if let images, let img = images[state.imageName] {
            img
        } else {
            ImageManager.shared.image(named: state.imageName)
        }
        let displayImage = originalImage.map { CroppedImageHelper.croppedImage(from: $0, cropRect: state.cropRect) }

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
