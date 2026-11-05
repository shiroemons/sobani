import Cocoa
import os.log

// MARK: - Display Anchor

/// ウィンドウが属するディスプレイと、保存時のそのディスプレイのフレーム。
///
/// Cocoa のグローバル座標はプライマリディスプレイ基準のため、起動直後のディスプレイ認識順や
/// 配置変更でずれる。ディスプレイ UUID とフレームを併せて保存し、復元時にディスプレイ基準の
/// 相対位置で写像することで、再起動後も同じ見た目の位置に戻す。
struct DisplayAnchor: Codable, Equatable, Sendable {
    let displayUUID: String
    let screenX: CGFloat
    let screenY: CGFloat
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    init(displayUUID: String, screenFrame: NSRect) {
        self.displayUUID = displayUUID
        self.screenX = screenFrame.origin.x
        self.screenY = screenFrame.origin.y
        self.screenWidth = screenFrame.width
        self.screenHeight = screenFrame.height
    }

    var screenFrame: NSRect {
        NSRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
    }

    /// すべての座標が有限値か（NaN / ±inf は JSON にエンコードできない）
    var hasFiniteValues: Bool {
        [screenX, screenY, screenWidth, screenHeight].allSatisfy(\.isFinite)
    }

    /// 矩形と最も大きく重なるスクリーンをアンカーとする。UUID が取れない・どこにも重ならない場合は nil。
    static func make(for rect: NSRect, screens: [ScreenInfo]) -> Self? {
        guard let index = ScreenRestorationUtils.indexOfLargestOverlap(
            for: rect, in: screens.map(\.frame)
        ), let uuid = screens[index].displayUUID else { return nil }
        return Self(displayUUID: uuid, screenFrame: screens[index].frame)
    }
}

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
    var displayAnchor: DisplayAnchor?
    /// 画像変換（反転・回転）の合成順序のバージョン。メモリ上の値は常に `currentTransformVersion`。
    ///
    /// - 1（キーなし）: 回転してから反転していたため、反転時の見た目の傾きは `-rotationAngle` だった。
    /// - 2: 反転してから回転する。`rotationAngle` がそのまま見た目の傾きになる。
    let transformVersion = Self.currentTransformVersion

    static let currentTransformVersion = 2

    enum CodingKeys: String, CodingKey {
        case imageName, originX, originY, width, height
        case isFlippedHorizontally, rotationAngle, opacityLevel, windowId
        case cropRect
        case isGhostMode
        case customGhostAlpha
        case isHidden
        case displayAnchor
        case transformVersion
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
        isHidden: Bool = false,
        displayAnchor: DisplayAnchor? = nil
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
        self.displayAnchor = displayAnchor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageName = try container.decode(String.self, forKey: .imageName)
        originX = try container.decode(CGFloat.self, forKey: .originX)
        originY = try container.decode(CGFloat.self, forKey: .originY)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        isFlippedHorizontally = try container.decode(Bool.self, forKey: .isFlippedHorizontally)
        let storedAngle = try container.decodeIfPresent(CGFloat.self, forKey: .rotationAngle) ?? 0
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .transformVersion)
        rotationAngle = Self.migratedRotationAngle(
            storedAngle, isFlipped: isFlippedHorizontally, transformVersion: storedVersion
        )
        opacityLevel = try container.decodeIfPresent(CGFloat.self, forKey: .opacityLevel) ?? 1.0
        windowId = try container.decodeIfPresent(Int.self, forKey: .windowId) ?? 0
        cropRect = try container.decodeIfPresent(CropRect.self, forKey: .cropRect)
        isGhostMode = try container.decodeIfPresent(Bool.self, forKey: .isGhostMode) ?? false
        customGhostAlpha = try container.decodeIfPresent(CGFloat.self, forKey: .customGhostAlpha)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        displayAnchor = try container.decodeIfPresent(DisplayAnchor.self, forKey: .displayAnchor)
        // transformVersion はデコード後も常に現行バージョン（移行済みの値として扱う）
    }

    /// 保存データの回転角を現行の変換順序（反転してから回転）での角度に移行する。
    ///
    /// 旧形式（バージョンキーなし）は回転してから反転していたため、反転ありの見た目の傾きは
    /// `-rotationAngle` だった。同じ見た目を保つため符号を反転する。反転なしは合成順に依存しない。
    static func migratedRotationAngle(
        _ angle: CGFloat, isFlipped: Bool, transformVersion: Int?
    ) -> CGFloat {
        guard transformVersion == nil, isFlipped, !GeometryUtils.isApproximatelyZero(angle) else {
            return angle
        }
        return GeometryUtils.normalizeAngle(-angle)
    }

    var frame: NSRect {
        NSRect(x: originX, y: originY, width: width, height: height)
    }

    /// 位置（原点とアンカー）だけを差し替えたコピーを返す。
    func withPosition(originX: CGFloat, originY: CGFloat, displayAnchor: DisplayAnchor?) -> Self {
        Self(
            imageName: imageName,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle,
            opacityLevel: opacityLevel,
            windowId: windowId,
            cropRect: cropRect,
            isGhostMode: isGhostMode,
            customGhostAlpha: customGhostAlpha,
            isHidden: isHidden,
            displayAnchor: displayAnchor
        )
    }

    /// `intended` の位置（ユーザーが意図した位置とアンカー）を採用し、それ以外の属性は自身の値を保つ。
    ///
    /// ディスプレイ切断・スリープ復帰・起動直後などで macOS やアプリがウィンドウを一時退避している間に
    /// 保存すると、退避先が正として永続化されてしまう。それを防ぐために使う。
    func preservingPosition(of intended: Self) -> Self {
        withPosition(
            originX: intended.originX,
            originY: intended.originY,
            displayAnchor: intended.displayAnchor
        )
    }

    func isPositionVisible(on screens: [ScreenInfo]) -> Bool {
        ScreenRestorationUtils.isVisible(frame, in: screens.map(\.frame))
    }

    func adjustedToVisibleArea(on screens: [ScreenInfo]) -> Self {
        if isPositionVisible(on: screens) {
            return self
        }
        let mainFrame = ScreenInfo.mainFrame(from: screens)
        return withPosition(
            originX: mainFrame.midX - width / 2,
            originY: mainFrame.midY - height / 2,
            displayAnchor: displayAnchor
        )
    }

    // MARK: - Restore Resolution

    enum AnchorResolution: Equatable, Sendable {
        /// アンカー情報なし（旧形式データ）。グローバル座標で復元した。
        case unanchored
        /// アンカーのディスプレイが見つかり、ディスプレイ基準で写像した。
        case matched
        /// アンカーのディスプレイが未接続。グローバル座標で仮配置した。
        case displayMissing
    }

    struct RestoreResolution: Equatable, Sendable {
        let state: WindowState
        /// 可視領域への退避（メイン画面中央への移動）が発生したか
        let wasAdjusted: Bool
        let anchor: AnchorResolution
    }

    /// 現在のスクリーン構成で復元すべき位置を決める。
    ///
    /// アンカーのディスプレイが接続されていれば、保存時のディスプレイフレームとの相対位置で写像する
    /// （グローバル座標の可視判定は使わない。意図的に画面外へはみ出させた配置も保つため）。
    /// 見つからなければ従来どおりグローバル座標で配置し、見えなければメイン画面中央へ退避する。
    func resolvedForRestore(on screens: [ScreenInfo]) -> RestoreResolution {
        if let anchor = displayAnchor,
           let screen = screens.first(where: { $0.displayUUID == anchor.displayUUID }) {
            let newAnchor = DisplayAnchor(displayUUID: anchor.displayUUID, screenFrame: screen.frame)
            let mappedOrigin = ScreenRestorationUtils.mapOrigin(
                of: frame, from: anchor.screenFrame, to: screen.frame
            )
            let mapped = withPosition(originX: mappedOrigin.x, originY: mappedOrigin.y, displayAnchor: newAnchor)
            // 写像先が見えない（解像度が極端に変わった等）場合だけスクリーン内にクランプする
            let origin = mapped.isPositionVisible(on: screens)
                ? mappedOrigin
                : ScreenRestorationUtils.clampOrigin(mappedOrigin, windowSize: frame.size, to: screen.frame)
            return RestoreResolution(
                state: withPosition(originX: origin.x, originY: origin.y, displayAnchor: newAnchor),
                wasAdjusted: false,
                anchor: .matched
            )
        }
        let adjusted = adjustedToVisibleArea(on: screens)
        return RestoreResolution(
            state: adjusted,
            wasAdjusted: adjusted.hasDifferentOrigin(from: self),
            anchor: displayAnchor == nil ? .unanchored : .displayMissing
        )
    }

    func hasDifferentOrigin(from other: Self) -> Bool {
        let tolerance = AppConstants.floatingPointTolerance
        return abs(originX - other.originX) > tolerance || abs(originY - other.originY) > tolerance
    }
}

// MARK: - Persistence Sanitization

extension WindowState {
    /// 永続化できる値に補正したコピーを返す（入力側のガードに対する多層防御）。
    ///
    /// `JSONEncoder` は非有限値（NaN / ±inf）を含むとエンコード自体に失敗するため、1 ウィンドウの
    /// 不正値でセッション中の保存がすべて失敗してしまう。保存直前にこの関数を通す。
    /// クロップ情報は読み込み時と同じ `CropRect.sanitized()` で補正する。
    func sanitizedForPersistence() -> Self {
        Self(
            imageName: imageName,
            originX: originX.isFinite ? originX : 0,
            originY: originY.isFinite ? originY : 0,
            width: Self.sanitizedLength(width),
            height: Self.sanitizedLength(height),
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle.isFinite ? rotationAngle : 0,
            opacityLevel: Self.sanitizedOpacity(opacityLevel),
            windowId: windowId,
            cropRect: cropRect?.sanitized(),
            isGhostMode: isGhostMode,
            customGhostAlpha: customGhostAlpha.flatMap { $0.isFinite ? $0 : nil },
            isHidden: isHidden,
            displayAnchor: displayAnchor.flatMap { $0.hasFiniteValues ? $0 : nil }
        )
    }

    /// 配列の各要素を `sanitizedForPersistence()` で補正し、補正が発生した件数をログに残す。
    static func sanitizedForPersistence(_ states: [Self], logger: Logger) -> [Self] {
        let sanitized = states.map { $0.sanitizedForPersistence() }
        // NaN を含む要素は自身とも等しくならないため、補正対象として数えられる
        let changedCount = zip(states, sanitized).filter { $0 != $1 }.count
        if changedCount > 0 {
            logger.warning("Sanitized invalid values in \(changedCount, privacy: .public) window states before saving")
        }
        return sanitized
    }

    private static func sanitizedLength(_ value: CGFloat) -> CGFloat {
        value.isFinite && value > 0 ? value : AppConstants.defaultWindowHeight
    }

    private static func sanitizedOpacity(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return AppConstants.opacityMax }
        return min(max(value, AppConstants.opacityMin), AppConstants.opacityMax)
    }
}

// MARK: - Window State Manager

/// ウィンドウ状態の永続化を管理するシングルトン。
///
/// `window_states.json` への保存・読み込みを担当し、起動時の状態復元と
/// 終了時の状態保存を `AppDelegate` から呼び出される。
/// 画像名はそのまま保存・復元する。レガシー画像名（`"デフォルト"` 等）や登録が消えた画像は、
/// 復元時に `AppDelegate.resolveImageName` がデフォルト画像へフォールバックさせる。
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
    /// 非有限値などエンコードできない値は `WindowState.sanitizedForPersistence` で補正してから書き込む。
    /// - Parameter states: 保存するウィンドウ状態の配列。Z-order は配列順で表現される。
    func saveStates(_ states: [WindowState]) {
        guard let url = statesFileURL else { return }
        JSONPersistence.save(
            WindowState.sanitizedForPersistence(states, logger: logger),
            to: url, logger: logger, errorMessage: "Failed to save window states"
        )
    }

    /// 保存済みのウィンドウ状態を JSON から読み込む。
    ///
    /// ファイルが存在しない場合は空配列を返す。デコードできない要素は読み飛ばし、
    /// 1 つでも読み飛ばした場合やファイル全体が読めない場合は、直後の保存で上書きされる前に
    /// 元ファイルを `window_states.corrupt-<日時>.json` として退避する。
    /// 一部だけ読み飛ばした場合は、退避後に読めた要素だけで書き直す（起動のたびに退避が増えないように）。
    /// - Returns: デコードされたウィンドウ状態の配列。
    func loadStates() -> [WindowState] {
        guard let url = statesFileURL else { return [] }
        guard let decoded = JSONPersistence.load(
            LossyDecodableArray<WindowState>.self,
            from: url,
            logger: logger,
            notFoundMessage: "No saved states found",
            errorMessage: "Failed to decode window states",
            backupOnDecodeFailure: true
        ) else { return [] }
        if decoded.skippedCount > 0 {
            logger.error("Skipped \(decoded.skippedCount, privacy: .public) undecodable window states")
            if JSONPersistence.backupUnreadableFile(at: url, logger: logger) != nil {
                saveStates(decoded.elements)
            }
        }
        return decoded.elements
    }

    /// 指定されたウィンドウの現在の状態をキャプチャする。
    ///
    /// - Returns: 現在のウィンドウ状態を表す `WindowState`。
    /// - Parameters:
    ///   - imageWindow: 状態を取得するイメージウィンドウ。
    ///   - screens: アンカー算出に使うスクリーン構成。
    @MainActor static func captureState(
        from imageWindow: ImageWindow,
        screens: [ScreenInfo]
    ) -> WindowState {
        // 回転中のウィンドウは外接矩形で、画像はその中に小数オフセットで置かれる（ウィンドウ中心と最大 0.5px ずれる）。
        // 復元時の setImageOrigin と同じ座標系にするため、imageView の実際のスクリーン座標を使う
        let imageFrame = imageWindow.imageFrameInScreen
        return WindowState(
            imageName: imageWindow.displayName,
            originX: imageFrame.origin.x,
            originY: imageFrame.origin.y,
            width: imageFrame.width,
            height: imageFrame.height,
            isFlippedHorizontally: imageWindow.imageView.isFlippedHorizontally,
            rotationAngle: imageWindow.imageView.rotationAngle,
            opacityLevel: imageWindow.imageView.opacityLevel,
            windowId: imageWindow.windowId,
            cropRect: imageWindow.imageView.cropRect,
            isGhostMode: imageWindow.isGhostMode,
            customGhostAlpha: imageWindow.customGhostAlpha,
            isHidden: imageWindow.isHidden,
            displayAnchor: DisplayAnchor.make(for: imageWindow.window.frame, screens: screens)
        )
    }

}

// MARK: - ImageWindow Restore Extension

extension ImageWindow {
    /// 保存状態からウィンドウを復元する。
    ///
    /// - Returns: 復元位置の解決結果。サイズが不正で復元しなかった場合は nil。
    @discardableResult
    func restore(
        from state: WindowState,
        screens: [ScreenInfo] = ScreenInfo.current()
    ) -> WindowState.RestoreResolution? {
        let resolution = state.resolvedForRestore(on: screens)
        let adjusted = resolution.state
        guard adjusted.width > 0, adjusted.height > 0 else { return nil }
        if PositionLogger.shared.isEnabled {
            PositionLogger.shared.log(
                event: "restore",
                screens: PositionLogger.shared.currentScreenSnapshots(),
                windows: [PositionLogger.WindowSnapshot(
                    windowId: adjusted.windowId,
                    originX: adjusted.originX, originY: adjusted.originY,
                    width: adjusted.width, height: adjusted.height,
                    imageWidth: adjusted.width, imageHeight: adjusted.height,
                    displayID: nil
                )],
                context: [
                    "wasAdjusted": "\(resolution.wasAdjusted)",
                    "anchor": "\(resolution.anchor)",
                    "beforeOrigin": "\(state.originX),\(state.originY)",
                    "afterOrigin": "\(adjusted.originX),\(adjusted.originY)",
                ]
            )
        }
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

        return resolution
    }

    /// 位置だけをディスプレイアンカー基準で再適用する（起動直後のディスプレイ構成変化への追従用）。
    ///
    /// - Returns: アンカーのディスプレイが見つかり位置を適用できた場合 true。
    @discardableResult
    func reapplyAnchoredPosition(of state: WindowState, screens: [ScreenInfo]) -> Bool {
        let resolution = state.resolvedForRestore(on: screens)
        guard resolution.anchor == .matched else { return false }
        setImageOrigin(resolution.state.frame.origin)
        return true
    }
}
