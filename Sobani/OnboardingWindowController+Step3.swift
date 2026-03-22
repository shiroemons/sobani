import Cocoa

// MARK: - Step 3: Hotkeys

extension OnboardingWindowController {
    func buildStep3Hotkey(in container: NSView) {
        let width = container.bounds.width

        let iconView = makeSymbolView("keyboard", size: Self.iconSize, color: .systemBlue)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: Self.step3IconY)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step3.title"))
        titleLabel.frame = NSRect(
            x: Self.contentPadding, y: Self.step3TitleY,
            width: width - Self.contentPadding * 2, height: 30
        )
        container.addSubview(titleLabel)

        buildStep3HotkeyList(in: container, width: width)
        buildStep3HotkeyHint(in: container, width: width)
    }

    // MARK: - Private helpers

    private func buildStep3HotkeyList(in container: NSView, width: CGFloat) {
        let hotkeys: [(key: String, desc: String)] = [
            (L("onboarding.step3.hotkeyH.key"), L("onboarding.step3.hotkeyH.desc")),
            (L("onboarding.step3.hotkeyShiftH.key"), L("onboarding.step3.hotkeyShiftH.desc")),
            (L("onboarding.step3.hotkeyG.key"), L("onboarding.step3.hotkeyG.desc")),
            (L("onboarding.step3.hotkeyM.key"), L("onboarding.step3.hotkeyM.desc"))
        ]
        let hotkeyStartY: CGFloat = Self.step3HotkeyStartY
        let hotkeyRowHeight: CGFloat = Self.step3HotkeyRowHeight
        let descX: CGFloat = Self.step3HotkeyX + Self.step3HotkeyKeyWidth
        for (index, hotkey) in hotkeys.enumerated() {
            let rowY = hotkeyStartY - CGFloat(index) * hotkeyRowHeight

            let keyLabel = NSTextField(labelWithString: hotkey.key)
            keyLabel.frame = NSRect(
                x: Self.step3HotkeyX,
                y: rowY,
                width: Self.step3HotkeyKeyWidth,
                height: 20
            )
            keyLabel.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
            container.addSubview(keyLabel)

            let descLabel = NSTextField(labelWithString: hotkey.desc)
            descLabel.frame = NSRect(
                x: descX,
                y: rowY,
                width: width - descX - Self.contentPadding,
                height: 20
            )
            descLabel.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
            container.addSubview(descLabel)
        }
    }

    private func buildStep3HotkeyHint(in container: NSView, width: CGFloat) {
        let hintLabel = makeDescriptionLabel("💡 " + L("onboarding.step3.hotkeyCustomizeHint"))
        hintLabel.frame = NSRect(
            x: Self.step3HotkeyX, y: Self.step3HintY,
            width: width - Self.step3HotkeyInset, height: 20
        )
        hintLabel.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .left
        container.addSubview(hintLabel)
    }

}
