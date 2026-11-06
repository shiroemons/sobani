import Cocoa

// MARK: - Testable Static Methods

extension AppDelegate {

    /// 画像名を解決する。デフォルト画像名と一致する場合、または登録画像が存在しない場合はデフォルトにフォールバックする。
    nonisolated static func resolveImageName(
        _ imageName: String,
        defaultImageName: String,
        registeredImageExists: Bool
    ) -> (resolvedName: String, isDefault: Bool) {
        if imageName == defaultImageName {
            return (defaultImageName, true)
        } else if registeredImageExists {
            return (imageName, false)
        } else {
            return (defaultImageName, true)
        }
    }

    /// WindowState から ImageWindow を生成・設定して返す共通ファクトリメソッド。
    /// restore(from:) は呼び出さないため、呼び出し側で必要に応じて呼び出すこと。
    /// - Parameters:
    ///   - state: 復元元のウィンドウ状態
    ///   - windowId: 使用するウィンドウID。nil の場合は state.windowId を使用する。
    /// - Returns: 設定済みの ImageWindow（restore 前）
    func createImageWindow(from state: WindowState, windowId: Int? = nil) -> ImageWindow {
        let resolved = Self.resolvedImage(named: state.imageName)
        return makeImageWindow(image: resolved.image, displayName: resolved.displayName, windowId: windowId ?? state.windowId)
    }

    /// ウィンドウに表示する画像と表示名を画像名から決める。
    ///
    /// 登録画像は `ImageManager` のキャッシュから読む（NSImage は変更しないためウィンドウ間で共有してよい）。
    /// 読み込めない名前はデフォルト画像にし、表示名もデフォルトに戻す（存在しない名前を保存させないため）。
    static func resolvedImage(
        named imageName: String,
        in imageManager: ImageManager = .shared
    ) -> (image: NSImage, displayName: String) {
        let image = imageManager.image(named: imageName)
        let resolved = resolveImageName(
            imageName,
            defaultImageName: AppConstants.defaultImageName,
            registeredImageExists: image != nil
        )
        let resolvedImage = resolved.isDefault ? imageManager.defaultImage() : image
        return (resolvedImage ?? NSImage(), resolved.resolvedName)
    }

    /// ImageWindow を生成し、delegate・表示名・ウィンドウ ID を設定して返す。
    /// `zOrderedWindows` への追加は呼び出し側で行うこと。
    func makeImageWindow(image: NSImage, displayName: String, windowId: Int) -> ImageWindow {
        let imageWindow = ImageWindow(image: image)
        imageWindow.delegate = self
        imageWindow.displayName = displayName
        imageWindow.windowId = windowId
        return imageWindow
    }

    /// 新しいウィンドウ ID を払い出す
    func issueWindowId() -> Int {
        defer { nextWindowId += 1 }
        return nextWindowId
    }

    /// レガシーウィンドウID（legacyId）を持つ要素に新しいIDを割り当てる。
    /// - Parameters:
    ///   - existingIds: 現在のウィンドウID配列（インデックス順）
    ///   - legacyId: 移行対象のレガシーID値（通常は0）
    /// - Returns: assignments: レガシーIDを持つ要素の(インデックス, 新ID)タプル配列、nextId: 次に使用すべきID
    nonisolated static func migrateWindowIds(
        existingIds: [Int],
        legacyId: Int
    ) -> (assignments: [(oldIndex: Int, newId: Int)], nextId: Int) {
        let maxExistingId = existingIds.max() ?? 0
        var currentId = maxExistingId + 1
        var assignments: [(oldIndex: Int, newId: Int)] = []

        for (index, windowId) in existingIds.enumerated() where windowId == legacyId {
            assignments.append((oldIndex: index, newId: currentId))
            currentId += 1
        }

        return (assignments, currentId)
    }
}
