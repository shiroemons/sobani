import AppKit

// MARK: - Alert Factory

@MainActor
enum AlertFactory {
    /// 情報/警告アラートを生成
    static func make(
        style: NSAlert.Style = .informational,
        messageText: String,
        informativeText: String = "",
        buttonTitles: [String] = [L("common.ok")]
    ) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = messageText
        alert.informativeText = informativeText
        for title in buttonTitles {
            alert.addButton(withTitle: title)
        }
        return alert
    }

    /// 確認ダイアログ（OK/キャンセル）を生成
    static func confirmation(
        messageText: String,
        informativeText: String = "",
        okTitle: String = L("common.ok"),
        cancelTitle: String = L("common.cancel")
    ) -> NSAlert {
        make(
            style: .warning,
            messageText: messageText,
            informativeText: informativeText,
            buttonTitles: [okTitle, cancelTitle]
        )
    }
}
