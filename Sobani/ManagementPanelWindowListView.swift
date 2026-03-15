import Cocoa
import os.log

// MARK: - ManagementPanelWindowListView

@MainActor
final class ManagementPanelWindowListView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private static let indexLabelSize: CGFloat = 16
    private static let indexLabelX: CGFloat = 8
    private static let nameLabelX: CGFloat = 28
    private static let nameLabelY: CGFloat = 22
    private static let nameLabelWidth: CGFloat = 100
    private static let nameLabelHeight: CGFloat = 16
    private static let idLabelY: CGFloat = 6
    private static let idLabelHeight: CGFloat = 12
    private static let eyeButtonX: CGFloat = 132
    private static let ghostButtonX: CGFloat = 160
    private static let actionButtonSize: CGFloat = 24

    private let logger = Logger(category: "ManagementPanelWindowListView")
    private var tableView: NSTableView?
    private var scrollView: NSScrollView?
    private(set) var windows: [CharacterWindow] = []
    private(set) var selectedWindow: CharacterWindow?

    var onWindowSelected: ((CharacterWindow?) -> Void)?
    var onVisibilityToggled: ((CharacterWindow) -> Void)?
    var onGhostToggled: ((CharacterWindow) -> Void)?
    var onReorder: ((CharacterWindow, Int) -> Void)?
    var onBulkAction: ((BulkAction) -> Void)?

    enum BulkAction {
        case showAll
        case hideAll
        case ghostAll
        case unghostAll
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTableView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }

    // MARK: - Setup

    private func setupTableView() {
        let scroll = NSScrollView(frame: bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        addSubview(scroll)
        scrollView = scroll

        let table = NSTableView(frame: scroll.bounds)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = AppConstants.managementPanelRowHeight
        table.selectionHighlightStyle = .none
        table.backgroundColor = .clear
        table.headerView = nil

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window"))
        column.width = AppConstants.managementPanelListWidth
        table.addTableColumn(column)

        scroll.documentView = table
        tableView = table
    }

    // MARK: - Public API

    func reload(with windows: [CharacterWindow]) {
        self.windows = windows
        tableView?.reloadData()
    }

    func selectWindow(_ charWindow: CharacterWindow?) {
        selectedWindow = charWindow
        guard let table = tableView else { return }
        if let charWindow, let index = windows.firstIndex(where: { $0 === charWindow }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        windows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < windows.count else { return nil }
        let charWindow = windows[row]

        let identifier = NSUserInterfaceItemIdentifier("WindowCell")
        let cellView: NSView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) {
            cellView = reused
            cellView.subviews.forEach { $0.removeFromSuperview() }
        } else {
            cellView = NSView()
            cellView.identifier = identifier
        }

        buildCellContent(in: cellView, charWindow: charWindow, index: row)
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = ManagementPanelRowView()
        guard row < windows.count else { return rowView }
        let charWindow = windows[row]
        let isSelected = charWindow === selectedWindow
        rowView.isHighlighted = isSelected
        rowView.alphaValue = charWindow.isHidden ? 0.5 : 1.0
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = tableView else { return }
        let row = table.selectedRow
        if row >= 0, row < windows.count {
            selectedWindow = windows[row]
        } else {
            selectedWindow = nil
        }
        onWindowSelected?(selectedWindow)
        table.reloadData()
    }

    // MARK: - Cell Building

    private func buildCellContent(in cellView: NSView, charWindow: CharacterWindow, index: Int) {
        let rowHeight = AppConstants.managementPanelRowHeight

        // Index label
        let indexLabel = NSTextField(labelWithString: "\(index + 1)")
        indexLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        indexLabel.textColor = .secondaryLabelColor
        indexLabel.frame = NSRect(
            x: Self.indexLabelX,
            y: (rowHeight - Self.indexLabelSize) / 2,
            width: Self.indexLabelSize,
            height: Self.indexLabelSize
        )
        cellView.addSubview(indexLabel)

        // Display name label
        let nameLabel = NSTextField(labelWithString: charWindow.localizedDisplayName)
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(
            x: Self.nameLabelX,
            y: Self.nameLabelY,
            width: Self.nameLabelWidth,
            height: Self.nameLabelHeight
        )
        cellView.addSubview(nameLabel)

        // Window ID label
        let idLabel = NSTextField(labelWithString: "#\(charWindow.windowId)")
        idLabel.font = .systemFont(ofSize: 10)
        idLabel.textColor = .tertiaryLabelColor
        idLabel.frame = NSRect(
            x: Self.nameLabelX,
            y: Self.idLabelY,
            width: Self.nameLabelWidth,
            height: Self.idLabelHeight
        )
        cellView.addSubview(idLabel)

        // Eye button (visibility toggle)
        let eyeSymbol = charWindow.isHidden ? AppConstants.hiddenWindowSymbol : AppConstants.visibleWindowSymbol
        let eyeButton = NSButton(frame: NSRect(
            x: Self.eyeButtonX,
            y: (rowHeight - Self.actionButtonSize) / 2,
            width: Self.actionButtonSize,
            height: Self.actionButtonSize
        ))
        eyeButton.bezelStyle = .regularSquare
        eyeButton.isBordered = false
        eyeButton.imagePosition = .imageOnly
        eyeButton.image = SFSymbolUtils.icon(eyeSymbol, pointSize: 14, weight: .regular)
        eyeButton.tag = index
        eyeButton.target = self
        eyeButton.action = #selector(eyeButtonTapped(_:))
        cellView.addSubview(eyeButton)

        // Ghost button
        let ghostButton = NSButton(frame: NSRect(
            x: Self.ghostButtonX,
            y: (rowHeight - Self.actionButtonSize) / 2,
            width: Self.actionButtonSize,
            height: Self.actionButtonSize
        ))
        ghostButton.bezelStyle = .regularSquare
        ghostButton.isBordered = false
        ghostButton.imagePosition = .imageOnly
        ghostButton.image = SFSymbolUtils.icon(AppConstants.ghostModeSymbol, pointSize: 14, weight: .regular)
        if charWindow.isGhostMode {
            ghostButton.contentTintColor = .controlAccentColor
        } else {
            ghostButton.contentTintColor = nil
        }
        ghostButton.tag = index
        ghostButton.target = self
        ghostButton.action = #selector(ghostButtonTapped(_:))
        cellView.addSubview(ghostButton)
    }

    // MARK: - Actions

    @objc private func eyeButtonTapped(_ sender: NSButton) {
        let index = sender.tag
        guard index < windows.count else { return }
        onVisibilityToggled?(windows[index])
    }

    @objc private func ghostButtonTapped(_ sender: NSButton) {
        let index = sender.tag
        guard index < windows.count else { return }
        onGhostToggled?(windows[index])
    }
}

// MARK: - ManagementPanelRowView

private final class ManagementPanelRowView: NSTableRowView {
    private static let highlightAlpha: CGFloat = 0.2

    var isHighlighted: Bool = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(Self.highlightAlpha).setFill()
            bounds.fill()
        }
    }
}
