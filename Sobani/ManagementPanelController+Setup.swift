import Cocoa

// MARK: - Setup Extensions

extension ManagementPanelController {

    // MARK: - Content Views

    func setupContentViews() {
        guard let container = contentContainer else { return }
        let contentHeight = AppConstants.managementPanelContentHeight
        let listWidth = AppConstants.managementPanelListWidth
        let detailWidth = AppConstants.managementPanelDetailWidth

        let listView = ManagementPanelWindowListView(frame: NSRect(
            x: 0, y: 0, width: listWidth, height: contentHeight
        ))
        listView.onWindowSelected = { [weak self] charWindow in
            self?.detailView?.update(with: charWindow)
        }
        listView.onVisibilityToggled = { [weak self] charWindow in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didToggleVisibility: charWindow)
            self.reloadWindowList()
        }
        listView.onGhostToggled = { [weak self] charWindow in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didToggleGhostMode: charWindow)
            self.reloadWindowList()
        }
        listView.onReorder = { [weak self] charWindow, newIndex in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didReorderWindow: charWindow, to: newIndex)
            self.reloadWindowList()
        }
        listView.onBulkAction = { [weak self] action in
            self?.handleBulkAction(action)
        }
        container.addSubview(listView)
        windowListView = listView

        // Vertical divider
        let divider = NSBox(frame: NSRect(x: listWidth, y: 0, width: 1, height: contentHeight))
        divider.boxType = .separator
        container.addSubview(divider)

        let detail = ManagementPanelDetailView(frame: NSRect(
            x: listWidth + 1, y: 0, width: detailWidth - 1, height: contentHeight
        ))
        detail.onOpacityChanged = { [weak self] charWindow, opacity in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didChangeOpacity: opacity, for: charWindow)
        }
        detail.onGhostToggled = { [weak self] charWindow in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didToggleGhostMode: charWindow)
            self.reloadWindowList()
            self.detailView?.update(with: charWindow)
        }
        detail.onVisibilityToggled = { [weak self] charWindow in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didToggleVisibility: charWindow)
            self.reloadWindowList()
            self.detailView?.update(with: charWindow)
        }
        container.addSubview(detail)
        detailView = detail
    }

    private func handleBulkAction(_ action: ManagementPanelWindowListView.BulkAction) {
        guard let delegate else { return }
        switch action {
        case .showAll:
            delegate.managementPanelDidRequestShowAll(self)
        case .hideAll:
            delegate.managementPanelDidRequestHideAll(self)
        case .ghostAll:
            delegate.managementPanelDidRequestGhostAll(self)
        case .unghostAll:
            delegate.managementPanelDidRequestUnghostAll(self)
        }
        reloadWindowList()
    }

    func setupLayoutView() {
        guard let container = contentContainer else { return }
        let contentHeight = AppConstants.managementPanelContentHeight
        let contentWidth = AppConstants.managementPanelContentWidth

        let view = ManagementPanelLayoutView(frame: NSRect(
            x: 0, y: 0, width: contentWidth, height: contentHeight
        ))
        view.onApplyLayout = { [weak self] preset in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didRequestApplyLayout: preset)
            self.reloadWindowList()
        }
        view.onSaveLayout = { [weak self] name in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didRequestSaveLayoutWithName: name)
        }
        view.onCreateNewLayout = { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanelDidRequestCreateNewLayout(self)
            self.reloadWindowList()
            self.layoutView?.reloadPresets()
        }
        view.onUpdateLayout = { [weak self] preset in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didRequestUpdateLayout: preset)
        }
        view.onDeleteLayout = { [weak self] preset in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didRequestDeleteLayout: preset)
        }
        view.onRenameLayout = { [weak self] preset, newName in
            guard let self, let delegate = self.delegate else { return }
            delegate.managementPanel(self, didRequestRenameLayout: preset, to: newName)
        }
        container.addSubview(view)
        layoutView = view
        view.reloadPresets()
    }

    func reloadWindowList() {
        guard let delegate else { return }
        let windows = delegate.managedWindows
        windowListView?.reload(with: windows)
        updateStatusBar()
        // 現在選択中のウィンドウの詳細も更新
        if let selected = windowListView?.selectedWindow {
            detailView?.update(with: selected)
        }
    }

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
        let initialHighlightY = Self.sidebarTabYPositions[Tab.windowManagement.rawValue]
        let highlight = NSView(frame: NSRect(x: highlightInset, y: initialHighlightY, width: highlightSize, height: highlightSize))
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
            TabButtonSpec(symbolName: "square.on.square", tab: .windowManagement,
                          yPosition: Self.sidebarTabYPositions[Tab.windowManagement.rawValue]),
            TabButtonSpec(symbolName: "rectangle.3.group", tab: .layout,
                          yPosition: Self.sidebarTabYPositions[Tab.layout.rawValue]),
            TabButtonSpec(symbolName: "gearshape", tab: .settings,
                          yPosition: Self.sidebarTabYPositions[Tab.settings.rawValue])
        ]
        var buttons: [NSButton] = []
        for spec in specs {
            let button = NSButton(frame: NSRect(x: Self.sidebarButtonInset, y: spec.yPosition, width: Self.sidebarButtonSize, height: Self.sidebarButtonSize))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.image = SFSymbolUtils.icon(spec.symbolName, pointSize: Self.sidebarButtonIconPointSize, weight: .regular)
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
        label.font = .systemFont(ofSize: Self.statusBarFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        parent.addSubview(label)
        statusBar = label
    }
}
