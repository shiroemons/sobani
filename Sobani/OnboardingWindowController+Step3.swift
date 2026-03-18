import Cocoa

// MARK: - Step 3: Hotkeys & Accessibility

extension OnboardingWindowController {
    func buildStep3Hotkey(in container: NSView) {
        let width = container.bounds.width
        let granted = AXIsProcessTrusted()

        let iconView = makeSymbolView("keyboard", size: Self.iconSize, color: .systemBlue)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: Self.step3IconY)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step3.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: Self.step3TitleY, width: width - Self.contentPadding * 2, height: 30)
        container.addSubview(titleLabel)

        buildStep3HotkeyList(in: container, width: width)
        buildStep3HotkeyHint(in: container, width: width)

        if granted {
            buildStep3GrantedStatus(in: container, width: width)
        } else {
            buildStep3NotGrantedViews(in: container, width: width)
        }
    }

    func startStep3AccessibilityPolling() {
        stopStep3AccessibilityPolling()
        guard !AXIsProcessTrusted() else { return }
        accessibilityTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.accessibilityPollingInterval,
            repeats: true
        ) { _ in
            MainActor.assumeIsolated { [weak self] in
                if AXIsProcessTrusted() {
                    self?.stopStep3AccessibilityPolling()
                    self?.rebuildStep3()
                }
            }
        }
    }

    func stopStep3AccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    func rebuildStep3() {
        guard let container = contentContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        buildStep3Hotkey(in: container)
        buildPageIndicator(in: container)
        buildNavigationButtons(in: container)
    }

    @objc func openAccessibilitySettings() {
        if let url = URL(string: AppConstants.accessibilitySettingsURL) {
            NSWorkspace.shared.open(url)
        }
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
        hintLabel.frame = NSRect(x: Self.step3HotkeyX, y: Self.step3HintY, width: width - Self.step3HotkeyInset, height: 20)
        hintLabel.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .left
        container.addSubview(hintLabel)
    }

    private func buildStep3GrantedStatus(in container: NSView, width: CGFloat) {
        let statusLabel = NSTextField(labelWithString: L("onboarding.step3.accessibilityGranted"))
        statusLabel.frame = NSRect(
            x: Self.contentPadding,
            y: Self.step3GrantedStatusY,
            width: width - Self.contentPadding * 2,
            height: 20
        )
        statusLabel.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        statusLabel.textColor = .systemGreen
        statusLabel.alignment = .center
        container.addSubview(statusLabel)
    }

    private func buildStep3NotGrantedViews(in container: NSView, width: CGFloat) {
        let warningLabel = makeDescriptionLabel("⚠️ " + L("onboarding.step3.accessibilityWarning"))
        warningLabel.frame = NSRect(
            x: Self.step3HotkeyX,
            y: Self.step3WarningY,
            width: width - Self.step3HotkeyInset,
            height: 20
        )
        warningLabel.font = NSFont.systemFont(ofSize: Self.step2LabelFontSize)
        warningLabel.textColor = .orange
        warningLabel.alignment = .left
        container.addSubview(warningLabel)

        let openButton = NSButton(
            title: L("onboarding.step3.openAccessibility"),
            target: self,
            action: #selector(openAccessibilitySettings)
        )
        openButton.frame = NSRect(x: (width - 220) / 2, y: Self.step3ButtonY, width: 220, height: 32)
        openButton.bezelStyle = .rounded
        container.addSubview(openButton)

        let step1Label = NSTextField(labelWithString: L("onboarding.step3.accessibilityStep1"))
        step1Label.frame = NSRect(
            x: Self.step3StepInstructionX,
            y: Self.step3Step1Y,
            width: width - Self.step3StepInstructionInset,
            height: 18
        )
        step1Label.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        step1Label.textColor = .secondaryLabelColor
        container.addSubview(step1Label)

        let step2Label = NSTextField(labelWithString: L("onboarding.step3.accessibilityStep2"))
        step2Label.frame = NSRect(
            x: Self.step3StepInstructionX,
            y: Self.step3Step2Y,
            width: width - Self.step3StepInstructionInset,
            height: 18
        )
        step2Label.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        step2Label.textColor = .secondaryLabelColor
        container.addSubview(step2Label)
    }
}
