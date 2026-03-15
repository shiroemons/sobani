import Cocoa
import os.log

// MARK: - ManagementPanelDelegate

@MainActor
protocol ManagementPanelDelegate: AnyObject {
    var managedWindows: [CharacterWindow] { get }
    func managementPanel(_ panel: ManagementPanelController, didToggleVisibility charWindow: CharacterWindow)
    func managementPanel(_ panel: ManagementPanelController, didToggleGhostMode charWindow: CharacterWindow)
    func managementPanel(_ panel: ManagementPanelController, didChangeOpacity opacity: CGFloat, for charWindow: CharacterWindow)
    func managementPanel(_ panel: ManagementPanelController, didReorderWindow charWindow: CharacterWindow, to index: Int)
    func managementPanelDidRequestShowAll(_ panel: ManagementPanelController)
    func managementPanelDidRequestHideAll(_ panel: ManagementPanelController)
    func managementPanelDidRequestGhostAll(_ panel: ManagementPanelController)
    func managementPanelDidRequestUnghostAll(_ panel: ManagementPanelController)
    func managementPanel(_ panel: ManagementPanelController, didRequestApplyLayout preset: LayoutPreset)
    func managementPanel(_ panel: ManagementPanelController, didRequestSaveLayoutWithName name: String)
    func managementPanelDidRequestCreateNewLayout(_ panel: ManagementPanelController)
    func managementPanel(_ panel: ManagementPanelController, didRequestUpdateLayout preset: LayoutPreset)
    func managementPanel(_ panel: ManagementPanelController, didRequestDeleteLayout preset: LayoutPreset)
    func managementPanel(_ panel: ManagementPanelController, didRequestRenameLayout preset: LayoutPreset, to newName: String)
    func managementPanelDidChangeHotkey(_ panel: ManagementPanelController)
}

// MARK: - ManagementPanelController

@MainActor
final class ManagementPanelController: NSObject {
    enum Tab: Int {
        case windowManagement = 0
        case layout = 1
        case settings = 2
    }

    private static let closeButtonSize: CGFloat = 20
    private static let titleFontSize: CGFloat = 13
    private static let closeButtonX: CGFloat = 4
    private static let titleLabelPadding: CGFloat = 8
    private static let closeIconPointSize: CGFloat = 14
    // サイドバーボタン・ハイライトのサイズ・外観定数
    static let sidebarButtonSize: CGFloat = 36
    static let sidebarButtonInset: CGFloat = 4
    static let sidebarHighlightCornerRadius: CGFloat = 8
    static let sidebarHighlightAlpha: CGFloat = 0.15
    static let sidebarTabAnimationDuration: TimeInterval = 0.15
    // サイドバータブボタンの y 座標（Tab.rawValue の順と一致）
    static let sidebarTabYPositions: [CGFloat] = [400, 356, 4]
    static let sidebarButtonIconPointSize: CGFloat = 16
    static let statusBarFontSize: CGFloat = 10

    private let logger = Logger(category: "ManagementPanelController")
    private var panel: NSPanel?
    private var backgroundView: NSVisualEffectView?
    // 以下のプロパティは +Setup.swift extension から書き込まれるため internal
    var contentContainer: NSView?
    private var titleBar: NSView?
    var sidebarView: NSVisualEffectView?
    var sidebarButtons: [NSButton] = []
    var sidebarHighlight: NSView?
    var statusBar: NSTextField?
    private var activeTab: Tab = .windowManagement
    nonisolated(unsafe) private var keyMonitor: Any?
    nonisolated(unsafe) private var appearanceObservation: NSKeyValueObservation?
    weak var delegate: ManagementPanelDelegate?
    var windowListView: ManagementPanelWindowListView?
    var detailView: ManagementPanelDetailView?
    var layoutView: ManagementPanelLayoutView?
    var settingsView: ManagementPanelSettingsView?

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Public API

    func toggle() {
        if isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            setupPanel()
        }

        guard let panel else {
            logger.error("Management panel is nil after setup")
            return
        }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            logger.error("No screen available to show management panel")
            return
        }

        let screenFrame = screen.visibleFrame
        let panelSize = NSSize(
            width: AppConstants.managementPanelWidth,
            height: AppConstants.managementPanelHeight
        )
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2
        )

        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)

        reloadWindowList()
        clearEventMonitors()
        installEventMonitors()
    }

    func dismiss() {
        clearEventMonitors()
        panel?.orderOut(nil)
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        let panelRect = NSRect(
            x: 0,
            y: 0,
            width: AppConstants.managementPanelWidth,
            height: AppConstants.managementPanelHeight
        )

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.configureForFloating()
        newPanel.level = .floating + 2
        newPanel.hasShadow = true
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear

        let effectView = NSVisualEffectView(frame: panelRect)
        effectView.material = .menu
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = AppConstants.managementPanelCornerRadius
        effectView.layer?.masksToBounds = true

        setupTitleBar(in: effectView)
        setupSidebar(in: effectView)
        setupContentContainer(in: effectView)
        setupStatusBar(in: effectView)

        newPanel.contentView = effectView
        backgroundView = effectView
        panel = newPanel

        installAppearanceObserver()
        switchTab(.windowManagement)
    }

    private func setupTitleBar(in parent: NSView) {
        let panelWidth = AppConstants.managementPanelWidth
        let panelHeight = AppConstants.managementPanelHeight
        let titleBarHeight = AppConstants.managementPanelTitleBarHeight

        let titleBarFrame = NSRect(
            x: AppConstants.managementPanelSidebarWidth,
            y: panelHeight - titleBarHeight,
            width: panelWidth - AppConstants.managementPanelSidebarWidth,
            height: titleBarHeight
        )
        let bar = NSView(frame: titleBarFrame)
        parent.addSubview(bar)
        titleBar = bar

        // Close button (✕)
        let closeButtonFrame = NSRect(
            x: Self.closeButtonX,
            y: (titleBarHeight - Self.closeButtonSize) / 2,
            width: Self.closeButtonSize,
            height: Self.closeButtonSize
        )
        let closeButton = NSButton(frame: closeButtonFrame)
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.image = SFSymbolUtils.icon("xmark.circle.fill", pointSize: Self.closeIconPointSize, weight: .regular)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        bar.addSubview(closeButton)

        // Title label (centered)
        let titleLabel = NSTextField(labelWithString: L("management.title"))
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .medium)
        titleLabel.sizeToFit()
        let labelWidth = titleBarFrame.width - Self.closeButtonSize * 2 - Self.titleLabelPadding
        titleLabel.frame = NSRect(
            x: (titleBarFrame.width - labelWidth) / 2,
            y: (titleBarHeight - titleLabel.frame.height) / 2,
            width: labelWidth,
            height: titleLabel.frame.height
        )
        bar.addSubview(titleLabel)
    }

    @objc private func closeTapped() {
        dismiss()
    }

    // MARK: - Tab Switching

    @objc func sidebarTabClicked(_ sender: NSButton) {
        guard let tab = Tab(rawValue: sender.tag) else { return }
        switchTab(tab)
    }

    func switchTab(_ tab: Tab) {
        activeTab = tab
        contentContainer?.subviews.forEach { $0.removeFromSuperview() }
        updateSidebarHighlight(tab)
        switch tab {
        case .windowManagement:
            setupContentViews()
        case .layout:
            setupLayoutView()
        case .settings:
            setupSettingsView()
        }
        updateStatusBar()
    }

    private func updateSidebarHighlight(_ tab: Tab) {
        // Tab.rawValue (0,1,2) と1:1対応
        guard tab.rawValue < Self.sidebarTabYPositions.count else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.sidebarTabAnimationDuration
            sidebarHighlight?.animator().frame.origin.y = Self.sidebarTabYPositions[tab.rawValue]
        }
    }

    func updateStatusBar() {
        guard let delegate else {
            statusBar?.stringValue = ""
            return
        }
        if activeTab == .windowManagement {
            let all = delegate.managedWindows
            let visible = all.filter { !$0.isHidden }.count
            statusBar?.stringValue = "\(visible)/\(all.count) 表示中"
        } else {
            statusBar?.stringValue = ""
        }
    }

    // MARK: - Appearance

    private func installAppearanceObserver() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateAppearanceDependentColors()
            }
        }
    }

    private func updateAppearanceDependentColors() {
        sidebarHighlight?.layer?.backgroundColor =
            NSColor.controlAccentColor.withAlphaComponent(Self.sidebarHighlightAlpha).cgColor
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // ESC key → dismiss
            if event.keyCode == AppConstants.escKeyCode {
                self.dismiss()
                return nil
            }

            // Management panel hotkey re-press → dismiss
            let binding = HotkeyManager.shared.binding(for: .managementPanel)
            if HotkeyManager.shared.matches(event, binding: binding) {
                self.dismiss()
                return nil
            }

            return event
        }
    }

    private func clearEventMonitors() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    deinit {
        // deinit 時は参照が消滅するため nil 書き戻し不要
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        appearanceObservation?.invalidate()
    }
}
