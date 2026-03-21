import Cocoa
import os.log

// MARK: - Window State

struct WindowState: Codable, Equatable, Sendable {
    var imageName: String
    let originX: CGFloat
    let originY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isFlippedHorizontally: Bool
    let rotationAngle: CGFloat
    var opacityLevel: CGFloat
    var windowId: Int
    var cropRect: CropRect?
    var isGhostMode: Bool
    var customGhostAlpha: CGFloat?
    var isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case imageName, originX, originY, width, height
        case isFlippedHorizontally, rotationAngle, opacityLevel, windowId
        case cropRect
        case isGhostMode
        case customGhostAlpha
        case isHidden
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
        windowId: Int = 0,
        cropRect: CropRect? = nil,
        isGhostMode: Bool = false,
        customGhostAlpha: CGFloat? = nil,
        isHidden: Bool = false
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
        self.cropRect = cropRect
        self.isGhostMode = isGhostMode
        self.customGhostAlpha = customGhostAlpha
        self.isHidden = isHidden
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
        cropRect = try container.decodeIfPresent(CropRect.self, forKey: .cropRect)
        isGhostMode = try container.decodeIfPresent(Bool.self, forKey: .isGhostMode) ?? false
        customGhostAlpha = try container.decodeIfPresent(CGFloat.self, forKey: .customGhostAlpha)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }

    func isPositionVisible(on screens: [ScreenInfo]) -> Bool {
        let windowRect = NSRect(x: originX, y: originY, width: width, height: height)
        for screen in screens {
            let intersection = windowRect.intersection(screen.frame)
            let threshold = AppConstants.screenIntersectionThreshold
            if !intersection.isNull && intersection.width >= threshold && intersection.height >= threshold {
                return true
            }
        }
        return false
    }

    func adjustedToVisibleArea(on screens: [ScreenInfo]) -> Self {
        if isPositionVisible(on: screens) {
            return self
        }
        let mainFrame = ScreenInfo.mainFrame(from: screens)
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
            windowId: windowId,
            cropRect: cropRect,
            isGhostMode: isGhostMode,
            customGhostAlpha: customGhostAlpha,
            isHidden: isHidden
        )
    }
}

// MARK: - Window State Manager

/// ウィンドウ状態の永続化を管理するシングルトン。
///
/// `window_states.json` への保存・読み込みを担当し、起動時の状態復元と
/// 終了時の状態保存を `AppDelegate` から呼び出される。
/// レガシー画像名（`"デフォルト"` → `"default"`）の正規化も行う。
@MainActor
final class WindowStateManager {
    static let shared = WindowStateManager()
    private let logger = Logger(category: "WindowStateManager")
    private let appSupportURL: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.appSupportURL = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
    }

    var statesFileURL: URL? {
        appSupportURL?.appendingPathComponent("window_states.json")
    }

    /// 全ウィンドウの状態を JSON にエンコードして保存する。
    ///
    /// - Parameter states: 保存するウィンドウ状態の配列。Z-order は配列順で表現される。
    func saveStates(_ states: [WindowState]) {
        guard let url = statesFileURL else { return }
        JSONPersistence.save(
            states, to: url, logger: logger, errorMessage: "Failed to save window states"
        )
    }

    /// 保存済みのウィンドウ状態を JSON から読み込む。
    ///
    /// レガシー画像名の正規化を自動的に行う。
    /// ファイルが存在しない場合は空配列を返す。
    /// - Returns: デコードされたウィンドウ状態の配列。
    func loadStates() -> [WindowState] {
        guard let url = statesFileURL else { return [] }
        guard var states = JSONPersistence.load(
            [WindowState].self,
            from: url,
            logger: logger,
            notFoundMessage: "No saved states found",
            errorMessage: "Failed to decode window states"
        ) else { return [] }
        return states
    }

    /// 指定されたウィンドウの現在の状態をキャプチャする。
    ///
    /// - Parameter imageWindow: 状態を取得するイメージウィンドウ。
    /// - Returns: 現在のウィンドウ状態を表す `WindowState`。
    @MainActor static func captureState(from imageWindow: ImageWindow) -> WindowState {
        let windowCenter = NSPoint(x: imageWindow.window.frame.midX, y: imageWindow.window.frame.midY)
        let baseWidth = imageWindow.imageView.frame.width
        let baseHeight = imageWindow.imageView.frame.height
        return WindowState(
            imageName: imageWindow.displayName,
            originX: windowCenter.x - baseWidth / 2,
            originY: windowCenter.y - baseHeight / 2,
            width: baseWidth,
            height: baseHeight,
            isFlippedHorizontally: imageWindow.imageView.isFlippedHorizontally,
            rotationAngle: imageWindow.imageView.rotationAngle,
            opacityLevel: imageWindow.imageView.opacityLevel,
            windowId: imageWindow.windowId,
            cropRect: imageWindow.imageView.cropRect,
            isGhostMode: imageWindow.isGhostMode,
            customGhostAlpha: imageWindow.customGhostAlpha,
            isHidden: imageWindow.isHidden
        )
    }

}

// MARK: - ImageWindow Restore Extension

extension ImageWindow {
    @discardableResult
    func restore(from state: WindowState) -> Bool {
        let adjusted = state.adjustedToVisibleArea(on: ScreenInfo.current())
        guard adjusted.width > 0, adjusted.height > 0 else { return false }
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
        if !adjusted.isHidden {
            window.makeKeyAndOrderFront(nil)
        }

        imageView.isFlippedHorizontally = adjusted.isFlippedHorizontally
        imageView.rotationAngle = adjusted.rotationAngle
        imageView.opacityLevel = adjusted.opacityLevel
        imageView.cropRect = adjusted.cropRect

        // AppKit resets the backing layer's affineTransform during
        // the initial window display cycle. Defer re-application
        // to the next run loop so the transform sticks.
        if adjusted.isFlippedHorizontally
            || !GeometryUtils.isApproximatelyZero(adjusted.rotationAngle) {
            DispatchQueue.main.async { @Sendable [weak self] in
                MainActor.assumeIsolated {
                    if !GeometryUtils.isApproximatelyZero(adjusted.rotationAngle) {
                        self?.adjustWindowForRotation()
                    }
                    self?.imageView.needsLayout = true
                    self?.imageView.layoutSubtreeIfNeeded()
                }
            }
        }

        setCustomGhostAlpha(adjusted.customGhostAlpha)
        if adjusted.isGhostMode {
            setGhostMode(true)
        }
        if adjusted.isHidden {
            setHidden(true)
        }

        return wasAdjusted
    }
}
