import AppKit

extension NSPanel {
    /// Sobaniのフローティングパネル共通設定を適用
    func configureForFloating() {
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
