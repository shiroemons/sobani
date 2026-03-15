import Cocoa

// MARK: - Setup Extensions

extension ManagementPanelController {

    func setupSidebar(in parent: NSView) {
        let sidebarFrame = NSRect(
            x: 0,
            y: AppConstants.managementPanelStatusBarHeight,
            width: AppConstants.managementPanelSidebarWidth,
            height: AppConstants.managementPanelContentHeight
        )
        let sidebar = NSVisualEffectView(frame: sidebarFrame)
        sidebar.material = .sidebar
        sidebar.state = .active
        sidebar.blendingMode = .behindWindow
        parent.addSubview(sidebar)
        sidebarView = sidebar

        // Selection highlight view (behind buttons)
        let highlightSize = Self.sidebarButtonSize
        let highlightInset = Self.sidebarButtonInset
        let highlight = NSView(frame: NSRect(x: highlightInset, y: 400, width: highlightSize, height: highlightSize))
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(Self.sidebarHighlightAlpha).cgColor
        highlight.layer?.cornerRadius = Self.sidebarHighlightCornerRadius
        sidebar.addSubview(highlight, positioned: .below, relativeTo: nil)
        sidebarHighlight = highlight

        sidebarButtons = makeSidebarButtons(in: sidebar)
    }

    func setupContentContainer(in parent: NSView) {
        let containerFrame = NSRect(
            x: AppConstants.managementPanelSidebarWidth,
            y: AppConstants.managementPanelStatusBarHeight,
            width: AppConstants.managementPanelContentWidth,
            height: AppConstants.managementPanelContentHeight
        )
        let container = NSView(frame: containerFrame)
        parent.addSubview(container)
        contentContainer = container
    }

    private func makeSidebarButtons(in parent: NSView) -> [NSButton] {
        struct TabButtonSpec {
            let symbolName: String
            let tab: Tab
            let yPosition: CGFloat
        }
        let specs = [
            TabButtonSpec(symbolName: "square.on.square", tab: .windowManagement, yPosition: 400),
            TabButtonSpec(symbolName: "rectangle.3.group", tab: .layout, yPosition: 356),
            TabButtonSpec(symbolName: "gearshape", tab: .settings, yPosition: 4)
        ]
        var buttons: [NSButton] = []
        for spec in specs {
            let button = NSButton(frame: NSRect(x: Self.sidebarButtonInset, y: spec.yPosition, width: Self.sidebarButtonSize, height: Self.sidebarButtonSize))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.image = SFSymbolUtils.icon(spec.symbolName, pointSize: 16, weight: .regular)
            button.tag = spec.tab.rawValue
            button.target = self
            button.action = #selector(sidebarTabClicked(_:))
            parent.addSubview(button)
            buttons.append(button)
        }
        return buttons
    }

    func setupStatusBar(in parent: NSView) {
        let statusFrame = NSRect(
            x: AppConstants.managementPanelSidebarWidth,
            y: 0,
            width: AppConstants.managementPanelContentWidth,
            height: AppConstants.managementPanelStatusBarHeight
        )
        let label = NSTextField(labelWithString: "")
        label.frame = statusFrame
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        parent.addSubview(label)
        statusBar = label
    }
}
