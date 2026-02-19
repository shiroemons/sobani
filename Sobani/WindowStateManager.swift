import Cocoa

// MARK: - Window State

struct WindowState: Codable, Equatable {
    let imageName: String
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
}

// MARK: - Window State Manager

class WindowStateManager {
    static let shared = WindowStateManager()
    private let baseDirectory: URL?

    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            appDir = appSupport.appendingPathComponent("Sobani")
        }
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }

    var statesFileURL: URL? {
        appSupportURL?.appendingPathComponent("window_states.json")
    }

    func saveStates(_ states: [WindowState]) {
        guard let url = statesFileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(states) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func loadStates() -> [WindowState] {
        guard let url = statesFileURL else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WindowState].self, from: data)) ?? []
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

    static func isPositionVisible(_ state: WindowState) -> Bool {
        let windowRect = NSRect(x: state.originX, y: state.originY, width: state.width, height: state.height)
        for screen in NSScreen.screens {
            let intersection = windowRect.intersection(screen.frame)
            if !intersection.isNull && intersection.width >= 50 && intersection.height >= 50 {
                return true
            }
        }
        return false
    }

    static func adjustToVisibleArea(_ state: WindowState) -> WindowState {
        if isPositionVisible(state) {
            return state
        }
        let mainFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let newOriginX = mainFrame.midX - state.width / 2
        let newOriginY = mainFrame.midY - state.height / 2
        return WindowState(
            imageName: state.imageName,
            originX: newOriginX,
            originY: newOriginY,
            width: state.width,
            height: state.height,
            isFlippedHorizontally: state.isFlippedHorizontally,
            rotationAngle: state.rotationAngle,
            opacityLevel: state.opacityLevel,
            windowId: state.windowId
        )
    }
}

// MARK: - CharacterWindow Restore Extension

extension CharacterWindow {
    @discardableResult
    func restore(from state: WindowState) -> Bool {
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        let wasAdjusted = (adjusted.originX != state.originX || adjusted.originY != state.originY)
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
        if adjusted.isFlippedHorizontally || adjusted.rotationAngle != 0 {
            DispatchQueue.main.async { [weak self] in
                if adjusted.rotationAngle != 0 {
                    self?.adjustWindowForRotation()
                }
                self?.imageView.needsLayout = true
                self?.imageView.layoutSubtreeIfNeeded()
            }
        }

        return wasAdjusted
    }
}
