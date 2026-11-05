import Cocoa

// MARK: - Step 3: Hotkeys

extension OnboardingWindowController {
    /// Step 3 に表示するホットキー1行分（ショートカット表示と操作名）
    struct HotkeyRow: Equatable {
        let key: String
        let description: String
    }

    /// 現在のホットキー設定から Step 3 の行を作る（設定で変更したショートカットを正しく案内するため）。
    static func step3HotkeyRows(
        actions: [AppDelegate.KeyboardAction] = AppDelegate.KeyboardAction.allCases,
        shortcut: (AppDelegate.KeyboardAction) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) = {
            (keyCode: HotkeySettings.keyCode(for: $0), modifiers: HotkeySettings.modifiers(for: $0))
        }
    ) -> [HotkeyRow] {
        actions.map { action in
            let binding = shortcut(action)
            return HotkeyRow(
                key: KeyCodeMapper.shortcutDisplayString(keyCode: binding.keyCode, modifiers: binding.modifiers),
                description: action.label
            )
        }
    }

    func buildStep3Hotkey(in container: NSView) {
        let width = container.bounds.width

        let iconView = makeSymbolView("keyboard", size: Self.iconSize, color: .systemBlue)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: Self.step3IconY)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step3.title"))
        titleLabel.frame = NSRect(
            x: Self.contentPadding, y: Self.step3TitleY,
            width: width - Self.contentPadding * 2, height: Self.titleHeight
        )
        container.addSubview(titleLabel)

        buildStep3HotkeyList(in: container, width: width)
        buildStep3HotkeyHint(in: container, width: width)
    }

    // MARK: - Private helpers

    private func buildStep3HotkeyList(in container: NSView, width: CGFloat) {
        let descX = Self.step3HotkeyX + Self.step3HotkeyKeyWidth
        for (index, row) in Self.step3HotkeyRows().enumerated() {
            let rowY = Self.step3HotkeyStartY - CGFloat(index) * Self.step3HotkeyRowHeight

            let keyLabel = NSTextField(labelWithString: row.key)
            keyLabel.frame = NSRect(
                x: Self.step3HotkeyX,
                y: rowY,
                width: Self.step3HotkeyKeyWidth,
                height: Self.step3HotkeyLabelHeight
            )
            keyLabel.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
            container.addSubview(keyLabel)

            let descLabel = NSTextField(labelWithString: row.description)
            descLabel.frame = NSRect(
                x: descX,
                y: rowY,
                width: width - descX - Self.contentPadding,
                height: Self.step3HotkeyLabelHeight
            )
            descLabel.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
            container.addSubview(descLabel)
        }
    }

    private func buildStep3HotkeyHint(in container: NSView, width: CGFloat) {
        let hintLabel = makeDescriptionLabel("💡 " + L("onboarding.step3.hotkeyCustomizeHint"))
        hintLabel.frame = NSRect(
            x: Self.step3HotkeyX, y: Self.step3HintY,
            width: width - Self.step3HotkeyInset, height: Self.step3HotkeyLabelHeight
        )
        hintLabel.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .left
        container.addSubview(hintLabel)
    }

}
