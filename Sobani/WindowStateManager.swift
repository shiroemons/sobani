import Cocoa
import os.log

// MARK: - Window State

struct WindowState: Codable, Equatable {
    var imageName: String
    let originX: CGFloat
    let originY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isFlippedHorizontally: Bool
    let rotationAngle: CGFloat
    var opacityLevel: CGFloat
    var windowId: Int

    enum CodingKeys: String, CodingKey {
        case imageName, originX, originY, width, height, isFlippedHorizontally, rotationAngle, opacityLevel, windowId
    }

    init(
        imageName: String,
        originX: CGFloat,
        originY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        isFlippedHorizontally: Bool,
        rotationAngle: CGFloat = 0,
        opacityLevel: CGFloat = 1.0,
        windowId: Int = 0
    ) {
        self.imageName = imageName
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
        self.isFlippedHorizontally = isFlippedHorizontally
        self.rotationAngle = rotationAngle
        self.opacityLevel = opacityLevel
        self.windowId = windowId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageName = try container.decode(String.self, forKey: .imageName)
        originX = try container.decode(CGFloat.self, forKey: .originX)
        originY = try container.decode(CGFloat.self, forKey: .originY)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        isFlippedHorizontally = try container.decode(Bool.self, forKey: .isFlippedHorizontally)
        rotationAngle = try container.decodeIfPresent(CGFloat.self, forKey: .rotationAngle) ?? 0
        opacityLevel = try container.decodeIfPresent(CGFloat.self, forKey: .opacityLevel) ?? 1.0
        windowId = try container.decodeIfPresent(Int.self, forKey: .windowId) ?? 0
    }

    func isPositionVisible() -> Bool {
        let windowRect = NSRect(x: originX, y: originY, width: width, height: height)
        for screen in NSScreen.screens {
            let intersection = windowRect.intersection(screen.frame)
            let threshold = AppConstants.screenIntersectionThreshold
            if !intersection.isNull && intersection.width >= threshold && intersection.height >= threshold {
                return true
            }
        }
        return false
    }

    func adjustedToVisibleArea() -> Self {
        if isPositionVisible() {
            return self
        }
        let mainFrame = NSScreen.main?.frame ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
        let newOriginX = mainFrame.midX - width / 2
        let newOriginY = mainFrame.midY - height / 2
        return Self(
            imageName: imageName,
            originX: newOriginX,
            originY: newOriginY,
            width: width,
            height: height,
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle,
            opacityLevel: opacityLevel,
            windowId: windowId
        )
    }
}

// MARK: - Window State Manager

final class WindowStateManager {
    static let shared = WindowStateManager()
    private let logger = Logger(
        subsystem: "com.shiroemons.Sobani",
        category: "WindowStateManager"
    )
    private let baseDirectory: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
    }

    var statesFileURL: URL? {
        appSupportURL?.appendingPathComponent("window_states.json")
    }

    func saveStates(_ states: [WindowState]) {
        guard let url = statesFileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(states)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error(
                "Failed to save window states: \(error.localizedDescription)"
            )
        }
    }

    func loadStates() -> [WindowState] {
        guard let url = statesFileURL else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.debug(
                "No saved states found: \(error.localizedDescription)"
            )
            return []
        }
        var states: [WindowState]
        do {
            states = try JSONDecoder().decode(
                [WindowState].self,
                from: data
            )
        } catch {
            logger.error(
                "Failed to decode window states: \(error.localizedDescription)"
            )
            return []
        }
        // Backward compatibility: normalize legacy "デフォルト" to internal constant
        // Introduced: v202502.0 — Can be removed after sufficient migration period (e.g. v202602.0+)
        states = states.map { state in
            if state.imageName == "デフォルト" {
                var normalized = state
                normalized.imageName = AppConstants.defaultImageName
                return normalized
            }
            return state
        }
        return states
    }

    static func captureState(from charWindow: CharacterWindow) -> WindowState {
        let windowCenter = NSPoint(x: charWindow.window.frame.midX, y: charWindow.window.frame.midY)
        let baseWidth = charWindow.imageView.frame.width
        let baseHeight = charWindow.imageView.frame.height
        return WindowState(
            imageName: charWindow.displayName,
            originX: windowCenter.x - baseWidth / 2,
            originY: windowCenter.y - baseHeight / 2,
            width: baseWidth,
            height: baseHeight,
            isFlippedHorizontally: charWindow.imageView.isFlippedHorizontally,
            rotationAngle: charWindow.imageView.rotationAngle,
            opacityLevel: charWindow.imageView.opacityLevel,
            windowId: charWindow.windowId
        )
    }

}

// MARK: - CharacterWindow Restore Extension

extension CharacterWindow {
    @discardableResult
    func restore(from state: WindowState) -> Bool {
        let adjusted = state.adjustedToVisibleArea()
        guard adjusted.height > 0 else { return false }
        let tolerance = AppConstants.floatingPointTolerance
        let wasAdjusted = abs(adjusted.originX - state.originX) > tolerance
            || abs(adjusted.originY - state.originY) > tolerance
        imageView.aspectRatio = adjusted.width / adjusted.height
        imageView.frame = NSRect(x: 0, y: 0, width: adjusted.width, height: adjusted.height)

        let frame = NSRect(
            x: adjusted.originX,
            y: adjusted.originY,
            width: adjusted.width,
            height: adjusted.height
        )
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)

        imageView.isFlippedHorizontally = adjusted.isFlippedHorizontally
        imageView.rotationAngle = adjusted.rotationAngle
        imageView.opacityLevel = adjusted.opacityLevel

        // AppKit resets the backing layer's affineTransform during
        // the initial window display cycle. Defer re-application
        // to the next run loop so the transform sticks.
        if adjusted.isFlippedHorizontally || abs(adjusted.rotationAngle) > AppConstants.floatingPointTolerance {
            DispatchQueue.main.async { [weak self] in
                if abs(adjusted.rotationAngle) > AppConstants.floatingPointTolerance {
                    self?.adjustWindowForRotation()
                }
                self?.imageView.needsLayout = true
                self?.imageView.layoutSubtreeIfNeeded()
            }
        }

        return wasAdjusted
    }
}
