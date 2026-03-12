import Cocoa
import os.log

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var contentContainer: NSView?
    private var currentStep = 0
    private let totalSteps = 3
    private let onboardingManager: OnboardingManager
    private var onComplete: (() -> Void)?
    var onAddImage: (() -> Void)?
    var onFinish: (() -> Void)?
    nonisolated(unsafe) private var languageObserver: NSObjectProtocol?
    private let logger = Logger(category: "OnboardingWindowController")
    private static let iconSize: CGFloat = 48
    private static let contentPadding: CGFloat = 40
    private static let dotSize: CGFloat = 8
    private static let dotSpacing: CGFloat = 12
    private static let rowHeight: CGFloat = 65
    private static let titleY: CGFloat = 320
    private static let descriptionY: CGFloat = 280
    private static let iconY: CGFloat = 360
    private static let pageIndicatorY: CGFloat = 75
    private static let navigationButtonY: CGFloat = 35
    private static let finishDelay: TimeInterval = 0.3

    init(onboardingManager: OnboardingManager = .shared) {
        self.onboardingManager = onboardingManager
        super.init()
    }

    deinit {
        assert(languageObserver == nil, "teardown() must be called before OnboardingWindowController is deallocated")
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
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildForLanguageChange()
            }
        }

        logger.info("Onboarding window shown")
    }

    func close() {
        panel?.orderOut(nil)
        teardown()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        complete()
    }

    // MARK: - Private

    private func teardown() {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
            languageObserver = nil
        }
        panel = nil
        contentContainer = nil
    }

    private func complete() {
        onboardingManager.markCompleted()
        teardown()
        onComplete?()
        logger.info("Onboarding completed")
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
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: Self.iconY)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step1.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: Self.titleY, width: width - Self.contentPadding * 2, height: 30)
        container.addSubview(titleLabel)

        let desc1 = makeDescriptionLabel(L("onboarding.step1.description1"))
        desc1.frame = NSRect(x: Self.contentPadding, y: Self.descriptionY, width: width - Self.contentPadding * 2, height: 40)
        container.addSubview(desc1)

        // Simulated menu bar icon display
        let bgWidth = Self.step1IconBackgroundWidth
        let bgHeight = Self.step1IconBackgroundHeight
        let iconBackground = NSView(frame: NSRect(x: (width - bgWidth) / 2, y: Self.step1IconBackgroundY, width: bgWidth, height: bgHeight))
        iconBackground.wantsLayer = true
        iconBackground.layer?.cornerRadius = Self.step1IconBackgroundCornerRadius
        iconBackground.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        container.addSubview(iconBackground)

        let statusSize = Self.step1StatusIconSize
        let statusIcon = makeSymbolView("person.fill", size: statusSize, color: .labelColor)
        statusIcon.frame = NSRect(x: (width - statusSize) / 2, y: Self.step1StatusIconY, width: statusSize, height: statusSize)
        container.addSubview(statusIcon)

        let hintLabel = makeDescriptionLabel(L("onboarding.step1.hint"))
        hintLabel.frame = NSRect(x: Self.contentPadding, y: Self.step1HintY, width: width - Self.contentPadding * 2, height: Self.step1HintHeight)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        container.addSubview(hintLabel)
    }

    // MARK: - Step 2: Basic Operations

    private func buildStep2(in container: NSView) {
        let width = container.bounds.width

        let titleLabel = makeTitleLabel(L("onboarding.step2.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: Self.step2TitleY, width: width - Self.contentPadding * 2, height: 30)
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
        let startY = Self.step2StartY
        let iconX = Self.step2IconX
        let labelX = Self.step2LabelX
        let contentWidth = width - Self.step2ContentInset

        for index in 0..<symbols.count {
            let rowY = startY - CGFloat(index) * rowHeight
            let content = StepRowContent(
                symbol: symbols[index],
                label: labels[index],
                description: descriptions[index],
                hint: hints[index]
            )
            let context = StepRowContext(
                rowY: rowY,
                iconX: iconX,
                labelX: labelX,
                contentWidth: contentWidth,
                containerWidth: width,
                addSeparator: index < symbols.count - 1
            )
            buildStepRow(in: container, content: content, context: context)
        }
    }

    // MARK: - Step 3: Get Started

    private func buildStep3(in container: NSView) {
        let width = container.bounds.width

        let iconView = makeSymbolView("party.popper", size: Self.iconSize, color: .systemOrange)
        iconView.frame.origin = CGPoint(x: (width - Self.iconSize) / 2, y: Self.iconY)
        container.addSubview(iconView)

        let titleLabel = makeTitleLabel(L("onboarding.step3.title"))
        titleLabel.frame = NSRect(x: Self.contentPadding, y: Self.titleY, width: width - Self.contentPadding * 2, height: 30)
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
        let frames = Self.pageIndicatorDotFrames(
            totalSteps: totalSteps, containerWidth: width, dotSize: Self.dotSize, dotSpacing: Self.dotSpacing
        )
        let y: CGFloat = Self.pageIndicatorY

        for (step, frame) in frames.enumerated() {
            let dot = NSView(frame: NSRect(x: frame.origin.x, y: y, width: frame.width, height: frame.height))
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
        let buttonY: CGFloat = Self.navigationButtonY
        let config = Self.navigationButtonConfig(currentStep: currentStep, totalSteps: totalSteps)

        if config.showBack {
            let backButton = NSButton(title: L("onboarding.button.prev"), target: self, action: #selector(prevStep))
            backButton.frame = NSRect(x: 20, y: buttonY, width: 80, height: 32)
            backButton.bezelStyle = .rounded
            container.addSubview(backButton)
        }

        if config.showSkip {
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
        }

        if config.showNext {
            let nextButton = NSButton(title: L("onboarding.button.next"), target: self, action: #selector(nextStep))
            nextButton.frame = NSRect(x: width - 100, y: buttonY, width: 80, height: 32)
            nextButton.bezelStyle = .rounded
            nextButton.keyEquivalent = "\r"
            container.addSubview(nextButton)
        }

        if config.showStart {
            let startButton = NSButton(title: L("onboarding.button.start"), target: self, action: #selector(finishOnboarding))
            startButton.frame = NSRect(x: (width - 110) / 2, y: buttonY, width: 110, height: 32)
            startButton.bezelStyle = .rounded
            startButton.keyEquivalent = "\r"
            container.addSubview(startButton)
        }

        if config.showClose {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.finishDelay) { @Sendable [weak self] in
            MainActor.assumeIsolated {
                self?.onFinish?()
            }
        }
    }

}

// MARK: - Step Layout Constants

extension OnboardingWindowController {
    // MARK: Step 共通
    fileprivate static let smallFontSize: CGFloat = 12

    // MARK: Step 1: メニューバーアイコンイラスト
    fileprivate static let step1IconBackgroundWidth: CGFloat = 36
    fileprivate static let step1IconBackgroundHeight: CGFloat = 28
    fileprivate static let step1IconBackgroundY: CGFloat = 218
    fileprivate static let step1IconBackgroundCornerRadius: CGFloat = 6
    fileprivate static let step1StatusIconSize: CGFloat = 18
    fileprivate static let step1StatusIconY: CGFloat = 223
    fileprivate static let step1HintY: CGFloat = 160
    fileprivate static let step1HintHeight: CGFloat = 50

    // MARK: Step 2: 操作一覧
    fileprivate static let step2TitleY: CGFloat = 390
    fileprivate static let step2StartY: CGFloat = 340
    fileprivate static let step2IconX: CGFloat = 70
    fileprivate static let step2LabelX: CGFloat = 110
    fileprivate static let step2LabelYOffset: CGFloat = 4
    fileprivate static let step2DescriptionYOffset: CGFloat = -14
    fileprivate static let step2HintYOffset: CGFloat = -30
    fileprivate static let step2SeparatorYOffset: CGFloat = -38
    fileprivate static let step2ContentInset: CGFloat = 150
    fileprivate static let step2SeparatorInset: CGFloat = 140
    fileprivate static let step2SymbolSize: CGFloat = 24
    fileprivate static let step2LabelFontSize: CGFloat = 13
    fileprivate static let step2HintFontSize: CGFloat = 11
}

// MARK: - View Helpers

extension OnboardingWindowController {
    fileprivate struct StepRowContent {
        let symbol: String
        let label: String
        let description: String
        let hint: String?
    }

    fileprivate struct StepRowContext {
        let rowY: CGFloat
        let iconX: CGFloat
        let labelX: CGFloat
        let contentWidth: CGFloat
        let containerWidth: CGFloat
        let addSeparator: Bool
    }

    fileprivate func buildStepRow(in container: NSView, content: StepRowContent, context: StepRowContext) {
        let icon = makeSymbolView(content.symbol, size: Self.step2SymbolSize, color: .controlAccentColor)
        icon.frame.origin = CGPoint(x: context.iconX, y: context.rowY)
        container.addSubview(icon)

        let labelField = NSTextField(labelWithString: content.label)
        labelField.frame = NSRect(x: context.labelX, y: context.rowY + Self.step2LabelYOffset, width: context.contentWidth, height: 20)
        labelField.font = NSFont.boldSystemFont(ofSize: Self.step2LabelFontSize)
        container.addSubview(labelField)

        let descField = NSTextField(labelWithString: content.description)
        descField.frame = NSRect(x: context.labelX, y: context.rowY + Self.step2DescriptionYOffset, width: context.contentWidth, height: 18)
        descField.font = NSFont.systemFont(ofSize: Self.smallFontSize)
        descField.textColor = .secondaryLabelColor
        container.addSubview(descField)

        if let hint = content.hint, !hint.isEmpty {
            let hintField = NSTextField(labelWithString: hint)
            hintField.frame = NSRect(x: context.labelX, y: context.rowY + Self.step2HintYOffset, width: context.contentWidth, height: 16)
            hintField.font = NSFont.systemFont(ofSize: Self.step2HintFontSize)
            hintField.textColor = .tertiaryLabelColor
            container.addSubview(hintField)
        }

        if context.addSeparator {
            let separatorWidth = context.containerWidth - Self.step2SeparatorInset
            let separator = NSBox(frame: NSRect(x: context.iconX, y: context.rowY + Self.step2SeparatorYOffset, width: separatorWidth, height: 1))
            separator.boxType = .separator
            container.addSubview(separator)
        }
    }

    private func makeSymbolView(_ symbolName: String, size: CGFloat, color: NSColor) -> NSImageView {
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        imageView.image = SFSymbolUtils.icon(symbolName, pointSize: size)
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

// MARK: - Testable Static Methods

extension OnboardingWindowController {
    struct NavigationButtonConfig {
        let showBack: Bool
        let showSkip: Bool
        let showNext: Bool
        let showStart: Bool
        let showClose: Bool
    }

    nonisolated static func navigationButtonConfig(
        currentStep: Int, totalSteps: Int
    ) -> NavigationButtonConfig {
        let isFirstStep = currentStep == 0
        let isLastStep = currentStep >= totalSteps - 1
        return NavigationButtonConfig(
            showBack: !isFirstStep,
            showSkip: !isLastStep,
            showNext: !isLastStep,
            showStart: isLastStep,
            showClose: isLastStep
        )
    }

    nonisolated static func pageIndicatorDotFrames(
        totalSteps: Int, containerWidth: CGFloat, dotSize: CGFloat, dotSpacing: CGFloat
    ) -> [CGRect] {
        guard totalSteps > 0 else { return [] }
        let totalWidth = CGFloat(totalSteps) * dotSize + CGFloat(totalSteps - 1) * dotSpacing
        let startX = (containerWidth - totalWidth) / 2
        return (0..<totalSteps).map { step in
            CGRect(
                x: startX + CGFloat(step) * (dotSize + dotSpacing),
                y: 0,
                width: dotSize,
                height: dotSize
            )
        }
    }
}
