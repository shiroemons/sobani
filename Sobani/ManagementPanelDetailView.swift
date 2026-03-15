import Cocoa
import os.log

// MARK: - ManagementPanelDetailView

@MainActor
final class ManagementPanelDetailView: NSView {
    // Layout constants
    private static let contentHeight: CGFloat = AppConstants.managementPanelContentHeight
    private static let previewMaxWidth: CGFloat = AppConstants.managementPanelPreviewMaxWidth
    private static let previewMaxHeight: CGFloat = AppConstants.managementPanelPreviewMaxHeight
    private static let marginX: CGFloat = 18
    private static let previewTop: CGFloat = 16
    private static let separatorTop: CGFloat = 204
    private static let nameLabelTop: CGFloat = 216
    private static let idLabelTop: CGFloat = 240
    private static let screenLabelTop: CGFloat = 258
    private static let opacityRowTop: CGFloat = 290
    private static let ghostRowTop: CGFloat = 320
    private static let visibilityRowTop: CGFloat = 350
    private static let opacitySliderX: CGFloat = 82
    private static let opacitySliderWidth: CGFloat = 200
    private static let opacityPercentX: CGFloat = 290
    private static let opacityPercentWidth: CGFloat = 45
    private static let switchX: CGFloat = 102
    // フォントサイズ
    private static let nameFontSize: CGFloat = 14
    private static let rowLabelFontSize: CGFloat = 12
    private static let smallLabelFontSize: CGFloat = 11
    // 行・ラベルのサイズ
    private static let rowHeight: CGFloat = 20
    private static let nameLabelHeight: CGFloat = 17
    private static let idLabelHeight: CGFloat = 14
    private static let screenLabelHeight: CGFloat = 13
    private static let rowLabelWidth: CGFloat = 80
    private static let opacityLabelWidth: CGFloat = 60

    private let logger = Logger(category: "ManagementPanelDetailView")
    private var imagePreview: NSImageView?
    private var nameLabel: NSTextField?
    private var sizeLabel: NSTextField?
    private var screenLabel: NSTextField?
    private var opacitySlider: NSSlider?
    private var opacityLabel: NSTextField?
    private var ghostSwitch: NSSwitch?
    private var visibilitySwitch: NSSwitch?
    private var emptyLabel: NSTextField?
    private weak var currentWindow: CharacterWindow?

    var onOpacityChanged: ((CharacterWindow, CGFloat) -> Void)?
    var onGhostToggled: ((CharacterWindow) -> Void)?
    var onVisibilityToggled: ((CharacterWindow) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    // MARK: - Setup

    private func buildUI() {
        buildEmptyState()
        buildPreview()
        buildSeparator()
        buildLabels()
        buildOpacityRow()
        buildGhostRow()
        buildVisibilityRow()

        showEmpty()
    }

    private func buildEmptyState() {
        let label = NSTextField(labelWithString: L("management.select_window"))
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.sizeToFit()
        label.frame = NSRect(
            x: (bounds.width - label.frame.width) / 2,
            y: (bounds.height - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )
        label.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        addSubview(label)
        emptyLabel = label
    }

    private func buildPreview() {
        let previewY = Self.contentHeight - Self.previewTop - Self.previewMaxHeight
        let preview = NSImageView(frame: NSRect(
            x: Self.marginX,
            y: previewY,
            width: Self.previewMaxWidth,
            height: Self.previewMaxHeight
        ))
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.imageAlignment = .alignCenter
        addSubview(preview)
        imagePreview = preview
    }

    private func buildSeparator() {
        let sepY = Self.contentHeight - Self.separatorTop - 1
        let sep = NSBox(frame: NSRect(x: Self.marginX, y: sepY, width: Self.previewMaxWidth, height: 1))
        sep.boxType = .separator
        addSubview(sep)
    }

    private func buildLabels() {
        // Display name
        let nameLabelY = Self.contentHeight - Self.nameLabelTop - Self.nameLabelHeight
        let name = NSTextField(labelWithString: "")
        name.font = .systemFont(ofSize: Self.nameFontSize, weight: .semibold)
        name.frame = NSRect(x: Self.marginX, y: nameLabelY, width: Self.previewMaxWidth, height: Self.nameLabelHeight)
        name.lineBreakMode = .byTruncatingTail
        addSubview(name)
        nameLabel = name

        // Size / ID label
        let sizeLabelY = Self.contentHeight - Self.idLabelTop - Self.idLabelHeight
        let size = NSTextField(labelWithString: "")
        size.font = .monospacedDigitSystemFont(ofSize: Self.smallLabelFontSize, weight: .regular)
        size.textColor = .secondaryLabelColor
        size.frame = NSRect(x: Self.marginX, y: sizeLabelY, width: Self.previewMaxWidth, height: Self.idLabelHeight)
        addSubview(size)
        sizeLabel = size

        // Screen name label
        let screenLabelY = Self.contentHeight - Self.screenLabelTop - Self.screenLabelHeight
        let screen = NSTextField(labelWithString: "")
        screen.font = .systemFont(ofSize: Self.smallLabelFontSize)
        screen.textColor = .secondaryLabelColor
        screen.frame = NSRect(x: Self.marginX, y: screenLabelY, width: Self.previewMaxWidth, height: Self.screenLabelHeight)
        addSubview(screen)
        screenLabel = screen
    }

    private func buildOpacityRow() {
        let rowY = Self.contentHeight - Self.opacityRowTop - Self.rowHeight

        // "不透明度" label
        let label = NSTextField(labelWithString: L("management.opacity"))
        label.font = .systemFont(ofSize: Self.rowLabelFontSize)
        label.frame = NSRect(x: Self.marginX, y: rowY, width: Self.opacityLabelWidth, height: Self.rowHeight)
        addSubview(label)

        // Slider
        let slider = NSSlider(value: 1.0, minValue: Double(AppConstants.opacityMin),
                              maxValue: Double(AppConstants.opacityMax), target: self,
                              action: #selector(opacitySliderChanged(_:)))
        slider.frame = NSRect(x: Self.opacitySliderX, y: rowY,
                              width: Self.opacitySliderWidth, height: Self.rowHeight)
        slider.isContinuous = true
        addSubview(slider)
        opacitySlider = slider

        // Percent label
        let pctLabel = NSTextField(labelWithString: "100%")
        pctLabel.font = .monospacedDigitSystemFont(ofSize: Self.smallLabelFontSize, weight: .regular)
        pctLabel.alignment = .right
        pctLabel.frame = NSRect(x: Self.opacityPercentX, y: rowY,
                                width: Self.opacityPercentWidth, height: Self.rowHeight)
        addSubview(pctLabel)
        opacityLabel = pctLabel
    }

    private func buildGhostRow() {
        let rowY = Self.contentHeight - Self.ghostRowTop - Self.rowHeight

        let label = NSTextField(labelWithString: L("management.ghost_mode"))
        label.font = .systemFont(ofSize: Self.rowLabelFontSize)
        label.frame = NSRect(x: Self.marginX, y: rowY, width: Self.rowLabelWidth, height: Self.rowHeight)
        addSubview(label)

        let ghostSw = NSSwitch()
        ghostSw.controlSize = .small
        ghostSw.sizeToFit()
        ghostSw.frame.origin = NSPoint(x: Self.switchX, y: rowY)
        ghostSw.target = self
        ghostSw.action = #selector(ghostSwitchChanged(_:))
        addSubview(ghostSw)
        ghostSwitch = ghostSw
    }

    private func buildVisibilityRow() {
        let rowY = Self.contentHeight - Self.visibilityRowTop - Self.rowHeight

        let label = NSTextField(labelWithString: L("management.visibility"))
        label.font = .systemFont(ofSize: Self.rowLabelFontSize)
        label.frame = NSRect(x: Self.marginX, y: rowY, width: Self.rowLabelWidth, height: Self.rowHeight)
        addSubview(label)

        let visibilitySw = NSSwitch()
        visibilitySw.controlSize = .small
        visibilitySw.sizeToFit()
        visibilitySw.frame.origin = NSPoint(x: Self.switchX, y: rowY)
        visibilitySw.target = self
        visibilitySw.action = #selector(visibilitySwitchChanged(_:))
        addSubview(visibilitySw)
        visibilitySwitch = visibilitySw
    }

    // MARK: - Public API

    func update(with charWindow: CharacterWindow?) {
        guard let charWindow else {
            showEmpty()
            return
        }
        currentWindow = charWindow
        setContentVisible(true)

        // Image preview
        let image = ImageManager.shared.loadRegisteredImageCached(named: charWindow.displayName)
            ?? charWindow.imageView.image
        imagePreview?.image = image

        // Name
        nameLabel?.stringValue = charWindow.localizedDisplayName

        // Window size
        let winFrame = charWindow.window.frame
        let winW = Int(winFrame.width)
        let winH = Int(winFrame.height)
        sizeLabel?.stringValue = "#\(charWindow.windowId)  \(winW)×\(winH)"

        // Screen
        screenLabel?.stringValue = charWindow.window.screen?.localizedName ?? ""

        // Opacity
        let opacity = charWindow.imageView.opacityLevel
        opacitySlider?.doubleValue = Double(opacity)
        opacityLabel?.stringValue = FormatUtils.formatOpacity(opacity)

        // Ghost switch
        ghostSwitch?.state = charWindow.isGhostMode ? .on : .off

        // Visibility switch
        visibilitySwitch?.state = charWindow.isHidden ? .off : .on
    }

    func showEmpty() {
        currentWindow = nil
        setContentVisible(false)
    }

    // MARK: - Helpers

    private func setContentVisible(_ visible: Bool) {
        emptyLabel?.isHidden = visible
        imagePreview?.isHidden = !visible
        nameLabel?.isHidden = !visible
        sizeLabel?.isHidden = !visible
        screenLabel?.isHidden = !visible
        opacitySlider?.isHidden = !visible
        opacityLabel?.isHidden = !visible
        ghostSwitch?.isHidden = !visible
        visibilitySwitch?.isHidden = !visible
        // separators and row labels always visible is fine when empty
    }

    // MARK: - Actions

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        opacityLabel?.stringValue = FormatUtils.formatOpacity(value)
        guard let charWindow = currentWindow else { return }
        onOpacityChanged?(charWindow, value)
    }

    @objc private func ghostSwitchChanged(_ sender: NSSwitch) {
        guard let charWindow = currentWindow else { return }
        onGhostToggled?(charWindow)
    }

    @objc private func visibilitySwitchChanged(_ sender: NSSwitch) {
        guard let charWindow = currentWindow else { return }
        onVisibilityToggled?(charWindow)
    }
}
