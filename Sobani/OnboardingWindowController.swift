import Cocoa
import os.log

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var contentContainer: NSView?
    private var currentStep = 0
    private let totalSteps = 3
    private let onboardingManager: OnboardingManager
    private var onComplete: (() -> Void)?
    var onAddImage: (() -> Void)?
    var onFinish: (() -> Void)?
    private var languageObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "OnboardingWindowController")
    private static let iconSize: CGFloat = 48
    private static let contentPadding: CGFloat = 40
    private static let dotSize: CGFloat = 8
    private static let dotSpacing: CGFloat = 12
    private static let rowHeight: CGFloat = 65

    init(onboardingManager: OnboardingManager = .shared) {
        self.onboardingManager = onboardingManager
        super.init()
    }

    deinit {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show(onComplete: (() -> Void)? = nil) {
        if panel != nil { return }
        self.onComplete = onComplete

        let width = AppConstants.Onboarding.width
        let height = AppConstants.Onboarding.height
        let panelRect = NSRect(x: 0, y: 0, width: width, height: height)

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = L("onboarding.title")
        newPanel.level = .modalPanel
        newPanel.hidesOnDeactivate = false
        newPanel.delegate = self
        newPanel.isReleasedWhenClosed = false
        newPanel.center()

        let container = NSView(frame: panelRect)
        newPanel.contentView = container
        contentContainer = container

        currentStep = 0
        buildCurrentStep()

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = newPanel

        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildForLanguageChange()
        }

        logger.info("Onboarding window shown")
    }

    func close() {
        panel?.orderOut(nil)
        cleanup()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        complete()
    }

    // MARK: - Private

    private func complete() {
        onboardingManager.markCompleted()
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
            languageObserver = nil
        }
        onComplete?()
        panel = nil
        contentContainer = nil
        logger.info("Onboarding completed")
    }

    private func cleanup() {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
            languageObserver = nil
        }
        panel = nil
        contentContainer = nil
    }

    private func rebuildForLanguageChange() {
        panel?.title = L("onboarding.title")
        buildCurrentStep()
    }

    private func buildCurrentStep() {
        guard let container = contentContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        switch currentStep {
        case 0: buildStep1(in: container)
        case 1: buildStep2(in: container)
        case 2: buildStep3(in: container)
        default: break
        }

        buildPageIndicator(in: container)
        buildNavigationButtons(in: container)
    }

    private func goToStep(_ step: Int) {
        guard step >= 0, step < totalSteps else { return }
        currentStep = step
        buildCurrentStep()
    }

    // MARK: - Step 1: Welcome

    private func buildStep1(in container: NSView) {
        let width = container.bounds.width

        let iconView = makeSymbolView("star.fill", size: Self.iconSize, color: .systemYellow)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: 360)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step1.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: 320, width: width - Self.contentPadding * 2, height: 30)
        container.addSubview(titleLabel)

        let desc1 = makeDescriptionLabel(L("onboarding.step1.description1"))
        desc1.frame = NSRect(x: Self.contentPadding, y: 280, width: width - Self.contentPadding * 2, height: 40)
        container.addSubview(desc1)

        // Simulated menu bar icon display
        let iconBackground = NSView(frame: NSRect(x: (width - 36) / 2, y: 218, width: 36, height: 28))
        iconBackground.wantsLayer = true
        iconBackground.layer?.cornerRadius = 6
        iconBackground.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        container.addSubview(iconBackground)

        let statusIcon = makeSymbolView("person.fill", size: 18, color: .labelColor)
        statusIcon.frame = NSRect(x: (width - 18) / 2, y: 223, width: 18, height: 18)
        container.addSubview(statusIcon)

        let hintLabel = makeDescriptionLabel(L("onboarding.step1.hint"))
        hintLabel.frame = NSRect(x: Self.contentPadding, y: 160, width: width - Self.contentPadding * 2, height: 50)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(hintLabel)
    }

    // MARK: - Step 2: Basic Operations

    private func buildStep2(in container: NSView) {
        let width = container.bounds.width

        let titleLabel = makeTitleLabel(L("onboarding.step2.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: 390, width: width - Self.contentPadding * 2, height: 30)
        container.addSubview(titleLabel)

        let symbols = ["hand.draw", "scroll", "contextualmenu.and.cursorarrow", "option"]
        let labels = [
            L("onboarding.step2.dragLabel"), L("onboarding.step2.scrollLabel"),
            L("onboarding.step2.rightClickLabel"), L("onboarding.step2.hotkeyLabel")
        ]
        let descriptions = [
            L("onboarding.step2.drag"), L("onboarding.step2.scroll"),
            L("onboarding.step2.rightClick"), L("onboarding.step2.hotkey")
        ]
        let hints: [String?] = [
            L("onboarding.step2.dragHint"), L("onboarding.step2.scrollHint"),
            nil, L("onboarding.step2.hotkeyHint")
        ]

        let rowHeight = Self.rowHeight
        let startY: CGFloat = 340

        for index in 0..<symbols.count {
            let rowY = startY - CGFloat(index) * rowHeight

            let icon = makeSymbolView(symbols[index], size: 24, color: .controlAccentColor)
            icon.frame.origin = CGPoint(x: 70, y: rowY)
            container.addSubview(icon)

            let labelField = NSTextField(labelWithString: labels[index])
            labelField.frame = NSRect(x: 110, y: rowY + 4, width: width - 150, height: 20)
            labelField.font = NSFont.boldSystemFont(ofSize: 13)
            container.addSubview(labelField)

            let descField = NSTextField(labelWithString: descriptions[index])
            descField.frame = NSRect(x: 110, y: rowY - 14, width: width - 150, height: 18)
            descField.font = NSFont.systemFont(ofSize: 12)
            descField.textColor = .secondaryLabelColor
            container.addSubview(descField)

            if let hint = hints[index], !hint.isEmpty {
                let hintField = NSTextField(labelWithString: hint)
                hintField.frame = NSRect(x: 110, y: rowY - 30, width: width - 150, height: 16)
                hintField.font = NSFont.systemFont(ofSize: 11)
                hintField.textColor = .tertiaryLabelColor
                container.addSubview(hintField)
            }

            if index < symbols.count - 1 {
                let separator = NSBox(frame: NSRect(x: 70, y: rowY - 38, width: width - 140, height: 1))
                separator.boxType = .separator
                container.addSubview(separator)
            }
        }
    }

    // MARK: - Step 3: Get Started

    private func buildStep3(in container: NSView) {
        let width = container.bounds.width

        let iconView = makeSymbolView("party.popper", size: Self.iconSize, color: .systemOrange)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: 360)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step3.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: 320, width: width - Self.contentPadding * 2, height: 30)
        container.addSubview(titleLabel)

        let descLabel = makeDescriptionLabel(L("onboarding.step3.description"))
        descLabel.frame = NSRect(x: Self.contentPadding, y: 250, width: width - Self.contentPadding * 2, height: 60)
        container.addSubview(descLabel)

        let ctaButton = NSButton(title: L("onboarding.step3.cta"), target: self, action: #selector(addImageFromOnboarding))
        ctaButton.frame = NSRect(x: (width - 200) / 2, y: 200, width: 200, height: 36)
        ctaButton.bezelStyle = .rounded
        ctaButton.font = NSFont.systemFont(ofSize: 14)
        container.addSubview(ctaButton)
    }

    // MARK: - Page Indicator

    private func buildPageIndicator(in container: NSView) {
        let width = container.bounds.width
        let totalWidth = CGFloat(totalSteps) * Self.dotSize + CGFloat(totalSteps - 1) * Self.dotSpacing
        let startX = (width - totalWidth) / 2
        let y: CGFloat = 75

        for step in 0..<totalSteps {
            let dot = NSView(frame: NSRect(
                x: startX + CGFloat(step) * (Self.dotSize + Self.dotSpacing),
                y: y,
                width: Self.dotSize,
                height: Self.dotSize
            ))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = Self.dotSize / 2
            dot.layer?.backgroundColor = step == currentStep
                ? NSColor.controlAccentColor.cgColor
                : NSColor.separatorColor.cgColor
            container.addSubview(dot)
        }
    }

    // MARK: - Navigation Buttons

    private func buildNavigationButtons(in container: NSView) {
        let width = container.bounds.width
        let buttonY: CGFloat = 35

        if currentStep > 0 {
            let backButton = NSButton(title: L("onboarding.button.prev"), target: self, action: #selector(prevStep))
            backButton.frame = NSRect(x: 20, y: buttonY, width: 80, height: 32)
            backButton.bezelStyle = .rounded
            container.addSubview(backButton)
        }

        if currentStep < totalSteps - 1 {
            let skipButton = NSButton(title: L("onboarding.button.skip"), target: self, action: #selector(skipOnboarding))
            skipButton.frame = NSRect(x: (width - 80) / 2, y: buttonY, width: 80, height: 32)
            skipButton.bezelStyle = .rounded
            skipButton.isBordered = false
            skipButton.font = NSFont.systemFont(ofSize: 12)
            container.addSubview(skipButton)

            let skipHint = NSTextField(wrappingLabelWithString: L("onboarding.skipHint"))
            skipHint.frame = NSRect(x: 20, y: buttonY - 20, width: width - 40, height: 16)
            skipHint.font = NSFont.systemFont(ofSize: 10)
            skipHint.textColor = .tertiaryLabelColor
            skipHint.alignment = .center
            skipHint.isEditable = false
            skipHint.isSelectable = false
            skipHint.isBordered = false
            skipHint.drawsBackground = false
            container.addSubview(skipHint)

            let nextButton = NSButton(title: L("onboarding.button.next"), target: self, action: #selector(nextStep))
            nextButton.frame = NSRect(x: width - 100, y: buttonY, width: 80, height: 32)
            nextButton.bezelStyle = .rounded
            nextButton.keyEquivalent = "\r"
            container.addSubview(nextButton)
        } else {
            let startButton = NSButton(title: L("onboarding.button.start"), target: self, action: #selector(finishOnboarding))
            startButton.frame = NSRect(x: (width - 110) / 2, y: buttonY, width: 110, height: 32)
            startButton.bezelStyle = .rounded
            startButton.keyEquivalent = "\r"
            container.addSubview(startButton)

            let closeButton = NSButton(title: L("onboarding.button.close"), target: self, action: #selector(skipOnboarding))
            closeButton.frame = NSRect(x: width - 100, y: buttonY, width: 80, height: 32)
            closeButton.bezelStyle = .rounded
            container.addSubview(closeButton)
        }
    }

    // MARK: - Actions

    @objc private func nextStep() {
        goToStep(currentStep + 1)
    }

    @objc private func prevStep() {
        goToStep(currentStep - 1)
    }

    @objc private func addImageFromOnboarding() {
        panel?.close()
        onAddImage?()
    }

    @objc private func skipOnboarding() {
        panel?.close()
    }

    @objc private func finishOnboarding() {
        panel?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onFinish?()
        }
    }

    // MARK: - View Helpers

    private func makeSymbolView(_ symbolName: String, size: CGFloat, color: NSColor) -> NSImageView {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        imageView.image = image
        imageView.contentTintColor = color
        return imageView
    }

    private func makeTitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 20)
        label.alignment = .center
        return label
    }

    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14)
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        return label
    }
}
