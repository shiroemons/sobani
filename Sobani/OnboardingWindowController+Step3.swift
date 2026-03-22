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
        let hotkeyKeys = [
            L("onboarding.step3.hotkeyH"),
            L("onboarding.step3.hotkeyG"),
            L("onboarding.step3.hotkeyM")
        ]
        let hotkeyStartY: CGFloat = Self.step3HotkeyStartY
        let hotkeyRowHeight: CGFloat = Self.step3HotkeyRowHeight
        for (index, text) in hotkeyKeys.enumerated() {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(
                x: Self.step3HotkeyX,
                y: hotkeyStartY - CGFloat(index) * hotkeyRowHeight,
                width: width - Self.step3HotkeyInset,
                height: 20
            )
            label.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
            container.addSubview(label)
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
