import AppKit

extension NSMenu {
    /// 登録画像のメニューアイテムを追加
    ///
    /// - Parameters:
    ///   - names: 登録画像名の配列。空の場合は何も追加しない。
    ///   - target: メニューアイテムのターゲット
    ///   - action: メニューアイテムのアクション
    ///   - configure: 各メニューアイテムに追加設定を行うクロージャ（省略可）
    func addRegisteredImageItems(
        names: [String],
        target: AnyObject?,
        action: Selector,
        configure: ((NSMenuItem, String) -> Void)? = nil
    ) {
        guard !names.isEmpty else { return }
        addItem(.separator())
        let label = NSMenuItem(title: L("image.registered"), action: nil, keyEquivalent: "")
        label.isEnabled = false
        addItem(label)
        for name in names {
            let item = NSMenuItem(title: name, action: action, keyEquivalent: "")
            item.target = target
            item.representedObject = name
            configure?(item, name)
            addItem(item)
        }
    }
}
