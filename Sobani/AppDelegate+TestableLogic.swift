import Foundation

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
