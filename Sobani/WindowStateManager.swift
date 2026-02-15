import Cocoa

// MARK: - Window State

struct WindowState: Codable, Equatable {
    let imageName: String
    let originX: CGFloat
    let originY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isFlippedHorizontally: Bool
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
        let frame = charWindow.window.frame
        return WindowState(
            imageName: charWindow.displayName,
            originX: frame.origin.x,
            originY: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height,
            isFlippedHorizontally: charWindow.imageView.isFlippedHorizontally
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
            isFlippedHorizontally: state.isFlippedHorizontally
        )
    }
}

// MARK: - CharacterWindow Restore Extension

extension CharacterWindow {
    func restore(from state: WindowState) {
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        imageView.aspectRatio = adjusted.width / adjusted.height
        let frame = NSRect(
            x: adjusted.originX,
            y: adjusted.originY,
            width: adjusted.width,
            height: adjusted.height
        )
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        imageView.isFlippedHorizontally = adjusted.isFlippedHorizontally
        // AppKit resets the backing layer's affineTransform during
        // the initial window display cycle. Defer re-application
        // to the next run loop so the transform sticks.
        if adjusted.isFlippedHorizontally {
            DispatchQueue.main.async { [weak self] in
                self?.imageView.needsLayout = true
                self?.imageView.layoutSubtreeIfNeeded()
            }
        }
    }
}
