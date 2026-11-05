import AppKit
import Observation

@MainActor @Observable
final class ManagementPanelViewModel {
    private(set) weak var appDelegate: AppDelegate?
    /// 選択・保存ダイアログをシートとして表示する親ウィンドウ（管理パネル）
    @ObservationIgnored weak var presentingWindow: NSWindow?
    var selectedTab: ManagementTab? = .images
    var selectedWindowIds: Set<Int> = []
    var selectedRegisteredImageName: String?
    private(set) var windows: [WindowInfo] = []
    private(set) var registeredImageNames: [String] = []
    private(set) var windowCountByImageName: [String: Int] = [:]
    var windowStates: [WindowState] { windows.map { $0.toWindowState() } }
    private(set) var windowImages: [String: NSImage] = [:]
    var visibleWindowCount: Int { windows.lazy.filter { !$0.isHidden }.count }
    private(set) var languageRefreshId = UUID()
    @ObservationIgnored private var stateObserver: NSObjectProtocol?
    @ObservationIgnored private var listObserver: NSObjectProtocol?
    @ObservationIgnored private var imageListObserver: NSObjectProtocol?
    @ObservationIgnored private var languageObserver: NSObjectProtocol?
    @ObservationIgnored private var geometryObservers: [NSObjectProtocol] = []
    /// 管理パネルが表示中か。非表示中は通知による再構築を省き、表示時にまとめて反映する。
    @ObservationIgnored private var isPanelVisible = false
    @ObservationIgnored private var isRefreshScheduled = false
    /// 状態変更・移動・リサイズ通知による再構築の間引き間隔。
    /// ドラッグ・スクロールでのリサイズ・スライダーなど、イベントごとに全ウィンドウを再構築するのを防ぐ
    private static let refreshCoalescingInterval: Duration = .milliseconds(100)

    enum ManagementTab: String, CaseIterable, Identifiable {
        case images
        case layouts
        case registeredImages
        case logs
        case settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .images: return L("management.images")
            case .layouts: return L("management.layout")
            case .registeredImages: return L("management.registered_images")
            case .logs: return L("management.logs")
            case .settings: return L("management.settings")
            }
        }

        var iconName: String {
            switch self {
            case .images: return "photo.on.rectangle"
            case .layouts: return "rectangle.3.group"
            case .registeredImages: return "photo.stack"
            case .logs: return "doc.text.magnifyingglass"
            case .settings: return "gearshape"
            }
        }

        /// 設定以外のタブ（サイドバー上部に表示）
        static let topTabs: [Self] = [.images, .layouts, .registeredImages]
    }

    /// 一覧は表示に切り替わったとき（`setPanelVisible(true)`）に構築する。
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupNotificationObservers()
    }

    isolated deinit {
        let center = NotificationCenter.default
        let observers = [stateObserver, listObserver, imageListObserver, languageObserver].compactMap { $0 }
        for observer in observers + geometryObservers {
            center.removeObserver(observer)
        }
    }

    // MARK: - Panel Visibility

    /// 管理パネルの表示状態を伝える。表示に切り替わったら、非表示中に省いた更新をまとめて反映する。
    func setPanelVisible(_ visible: Bool) {
        isPanelVisible = visible
        guard visible else { return }
        refreshRegisteredImageNames()
        rebuildWindows()
    }

    // MARK: - Window List

    private func rebuildWindows() {
        guard let appDelegate else {
            windows = []
            windowImages = [:]
            windowCountByImageName = [:]
            return
        }
        let newWindows = appDelegate.zOrderedWindows.map { imageWindow in
            // 位置・サイズは画像（imageView）基準。WindowState・プリセット・位置エディタと同じ座標系にそろえる
            let imageFrame = imageWindow.imageFrameInScreen
            let screenName = imageWindow.window.screen?.localizedName ?? L("image.unknown")
            let dims = FormatUtils.formatDimensions(
                width: imageFrame.width, height: imageFrame.height)
            let subtitle = "\(dims) ・ \(screenName)"
            return WindowInfo(
                windowId: imageWindow.windowId,
                displayName: imageWindow.localizedDisplayName,
                subtitle: subtitle,
                isHidden: imageWindow.isHidden,
                isGhostMode: imageWindow.isGhostMode,
                opacityLevel: imageWindow.imageView.opacityLevel,
                thumbnail: imageWindow.imageView.image,
                originalImage: imageWindow.imageView.originalImage,
                cropRect: imageWindow.imageView.cropRect,
                customGhostAlpha: imageWindow.customGhostAlpha,
                effectiveGhostAlpha: imageWindow.effectiveGhostAlpha,
                isRemoveBackgroundEnabled: imageWindow.isRemoveBackgroundAvailable,
                originX: imageFrame.minX,
                originY: imageFrame.minY,
                width: imageFrame.width,
                height: imageFrame.height,
                imageName: imageWindow.displayName,
                isFlippedHorizontally: imageWindow.imageView.isFlippedHorizontally,
                rotationAngle: imageWindow.imageView.rotationAngle
            )
        }
        if newWindows != windows {
            windows = newWindows
            // WindowInfo の == は画像の同一性も比較するため、画像の差し替え（背景除去など）もここで検出できる
            rebuildImageCaches()
        }
    }

    private func rebuildImageCaches() {
        let counts = Dictionary(grouping: windows, by: \.imageName).mapValues(\.count)
        if counts != windowCountByImageName {
            windowCountByImageName = counts
        }
        var imageDict: [String: NSImage] = [:]
        for window in windows where imageDict[window.imageName] == nil {
            imageDict[window.imageName] = window.originalImage ?? window.thumbnail
        }
        if imageDict != windowImages {
            windowImages = imageDict
        }
    }

    private func refreshRegisteredImageNames() {
        let newNames = ImageManager.shared.registeredImageNames()
        if newNames != registeredImageNames {
            registeredImageNames = newNames
        }
        if let selected = selectedRegisteredImageName, !newNames.contains(selected) {
            selectedRegisteredImageName = nil
        }
    }

    // MARK: - Window Operations
    // パネルからの操作は、状態変更通知の間引きを待たずにすぐ再構築する（triggerRefresh）。
    // 一括操作で届く通知は間引かれるため、ウィンドウごとに再構築されることはない。

    func toggleHidden(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        // 表示切り替えは AppDelegate に集約する（表示時に Z-order を再適用するため）
        appDelegate?.setWindowsHidden(!imageWindow.isHidden, windows: [imageWindow])
        triggerRefresh()
    }

    func toggleGhostMode(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setGhostMode(!imageWindow.isGhostMode)
        triggerRefresh()
    }

    // MARK: - Bulk Operations

    func showAllWindows() {
        appDelegate?.setWindowsHidden(false)
        triggerRefresh()
    }

    func hideAllWindows() {
        appDelegate?.setWindowsHidden(true)
        triggerRefresh()
    }

    func ghostAllWindows() {
        appDelegate?.zOrderedWindows.forEach { $0.setGhostMode(true) }
        triggerRefresh()
    }

    func unghostAllWindows() {
        appDelegate?.zOrderedWindows.forEach { $0.setGhostMode(false) }
        triggerRefresh()
    }

    // MARK: - Detail View Operations

    func changeOpacity(windowId: Int, opacity: CGFloat) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.applyOpacity(opacity)
        triggerRefresh()
    }

    func changeBulkOpacity(opacity: CGFloat) {
        targetWindows.forEach { $0.applyOpacity(opacity) }
        triggerRefresh()
    }

    /// ゴーストモードの共通の不透明度を変更して各ウィンドウの見た目に反映し、パネルの表示も更新する。
    ///
    /// 見た目の再適用は状態変更通知を伴わないため、ここで再構築する。
    func applyGlobalGhostAlpha(_ alpha: CGFloat) {
        appDelegate?.applyGlobalGhostAlpha(alpha)
        triggerRefresh()
    }

    /// 位置とサイズを画像（imageView）基準の値で変更する。
    func changePositionAndSize(windowId: Int, origin: CGPoint, size: CGSize) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setPositionAndSize(origin: origin, size: size)
        triggerRefresh()
    }

    /// ミニマップでのドラッグ中: 画像の原点だけ動かす（ミニマップの座標は windowStates と同じ画像基準）。
    ///
    /// 状態変更の通知はドラッグ完了時に1回だけ送る。ドラッグ中のパネルの再構築は移動通知の間引きに任せる
    /// （ミニマップはドラッグ中のウィンドウを「開始位置 + ドラッグ量」で描くため、再構築されても二重に動かない）。
    func moveWindowDuringDrag(windowId: Int, origin: CGPoint) {
        findImageWindow(by: windowId)?.setImageOrigin(origin)
    }

    /// ミニマップでのドラッグ完了: 最終位置へ動かして `.position` を通知し、パネルの状態を同期する。
    ///
    /// 通知しないと、起動時・スリープ復帰時の画面復元がドラッグ前の位置へ戻してしまう。
    func finishWindowDrag(windowId: Int, origin: CGPoint) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setPositionAndSize(origin: origin, size: imageWindow.imageView.frame.size)
        triggerRefresh()
    }

    // MARK: - Dialogs

    /// 選択・保存ダイアログを管理パネルの上に表示する。
    ///
    /// 管理パネルは `.floating` より高いレベルにあるため、通常のモーダル表示では
    /// ダイアログがパネルの裏に隠れる。パネルが表示中ならシートとして表示する。
    func runDialog(_ dialog: NSSavePanel) async -> NSApplication.ModalResponse {
        if let window = presentingWindow, window.isVisible {
            return await dialog.beginSheetModal(for: window)
        }
        return dialog.runModal()
    }

    // MARK: - Private Helpers

    private func setupNotificationObservers() {
        let center = NotificationCenter.default
        stateObserver = center.addObserver(
            forName: AppConstants.imageWindowStateDidChange,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] note in
            let rawTrigger = note.userInfo?[AppConstants.notificationTriggerKey] as? String
            MainActor.assumeIsolated {
                self?.handleWindowStateChange(rawTrigger: rawTrigger)
            }
        }
        listObserver = center.addObserver(
            forName: AppConstants.imageWindowListDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.requestRefresh()
            }
        }
        imageListObserver = center.addObserver(
            forName: AppConstants.registeredImagesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                CroppedImageHelper.invalidateCache()
                guard let self, self.isPanelVisible else { return }
                self.refreshRegisteredImageNames()
            }
        }
        languageObserver = center.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.languageRefreshId = UUID()
            }
        }
        // 画面復元などのプログラムによる移動・リサイズは状態変更通知を伴わないため、NSWindow の通知も監視する
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            let observer = center.addObserver(
                forName: name, object: nil, queue: .main
            ) { @Sendable [weak self] note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let window else { return }
                    self?.scheduleGeometryRefresh(for: window)
                }
            }
            geometryObservers.append(observer)
        }
    }

    private func handleWindowStateChange(rawTrigger: String?) {
        let trigger = rawTrigger.flatMap(AppConstants.SnapshotTrigger.init(rawValue:))
        if trigger == .image {
            // クロップ済みプレビューのキャッシュは画像名がキーのため、同じ名前で画像が変わったら破棄する
            CroppedImageHelper.invalidateCache()
        }
        // スクロールでのリサイズ・回転ダイヤル・不透明度スライダーなどはイベントごとに届くため間引く
        scheduleRefresh()
    }

    /// 通知を契機とした再構築。パネル非表示中は省く（表示時に再構築する）。
    private func requestRefresh() {
        guard isPanelVisible else { return }
        triggerRefresh()
    }

    private func scheduleGeometryRefresh(for window: NSWindow) {
        // 移動・リサイズ通知はすべてのウィンドウから届くため、安価な判定を先に済ませる
        guard isPanelVisible, !isRefreshScheduled,
              appDelegate?.zOrderedWindows.contains(where: { $0.window === window }) == true else { return }
        scheduleRefresh()
    }

    /// 通知を間引いて再構築する。
    ///
    /// 予約中に届いた通知は無視するが、予約した再構築は実行時点の状態を読むため最終状態は必ず反映される。
    private func scheduleRefresh() {
        guard isPanelVisible, !isRefreshScheduled else { return }
        isRefreshScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: Self.refreshCoalescingInterval)
            self?.isRefreshScheduled = false
            self?.requestRefresh()
        }
    }

    /// 現在の `zOrderedWindows` からウィンドウ一覧を再構築する。
    /// 画像キャッシュは一覧に変化があったときだけ再構築される（`rebuildWindows` 参照）。
    func triggerRefresh() {
        rebuildWindows()
    }

    func findImageWindow(by windowId: Int) -> ImageWindow? {
        appDelegate?.zOrderedWindows.first { $0.windowId == windowId }
    }

    /// Returns the target windows for bulk operations.
    /// If windows are selected, returns only the selected ones.
    /// If no windows are selected, returns all windows.
    private var targetWindows: [ImageWindow] {
        guard let appDelegate else { return [] }
        if selectedWindowIds.isEmpty {
            return appDelegate.zOrderedWindows
        }
        return appDelegate.zOrderedWindows.filter { selectedWindowIds.contains($0.windowId) }
    }

}
