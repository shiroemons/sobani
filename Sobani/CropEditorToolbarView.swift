import Cocoa

/// クロップエディタ下部ツールバー
@MainActor
final class CropEditorToolbarView: NSView {

    // MARK: - Constants

    private static let buttonSize: CGFloat = 32
    private static let buttonSpacing: CGFloat = 24
    private static let sliderHeight: CGFloat = 50
    private static let bottomPadding: CGFloat = 12
    private static let selectorHeight: CGFloat = 36

    // MARK: - Callbacks

    var onStraightenAngleChanged: ((CGFloat) -> Void)?
    var onRotate90Tapped: (() -> Void)?
    var onAspectRatioSelected: ((AspectRatioPreset) -> Void)?

    // MARK: - State

    private var isSelectorVisible = false

    // MARK: - Subviews

    private var sliderView: StraightenSliderView?
    private var selectorView: AspectRatioSelectorView?
    private var buttons: [NSButton] = []

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    // MARK: - Setup

    private func setupSubviews() {
        wantsLayer = true

        // StraightenSliderView（上部）
        let slider = StraightenSliderView(
            frame: NSRect(x: 0, y: bounds.height - Self.sliderHeight, width: bounds.width, height: Self.sliderHeight)
        )
        slider.onAngleChanged = { [weak self] angle in
            self?.onStraightenAngleChanged?(angle)
        }
        addSubview(slider)
        sliderView = slider

        // AspectRatioSelectorView
        let selector = AspectRatioSelectorView(
            frame: NSRect(x: 0, y: Self.bottomPadding + Self.buttonSize, width: bounds.width, height: Self.selectorHeight)
        )
        selector.onPresetSelected = { [weak self] preset in
            self?.onAspectRatioSelected?(preset)
        }
        selector.isHidden = true
        addSubview(selector)
        selectorView = selector

        // ボタン行（下部）
        let createdButtons = createButtons()
        for button in createdButtons {
            addSubview(button)
        }
        buttons = createdButtons
    }

    private struct ButtonSpec {
        let symbol: String
        let tooltip: String
        let action: Selector
    }

    private func createButtons() -> [NSButton] {
        let specs: [ButtonSpec] = [
            ButtonSpec(symbol: "rotate.left", tooltip: L("crop_editor.rotate_90"), action: #selector(rotate90Tapped)),
            ButtonSpec(symbol: "aspectratio", tooltip: L("crop_editor.aspect_ratio"), action: #selector(aspectRatioTapped)),
        ]

        return specs.map { spec in
            let button = NSButton(frame: .zero)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = spec.tooltip
            button.target = self
            button.action = spec.action

            if let image = NSImage(
                systemSymbolName: spec.symbol,
                accessibilityDescription: spec.tooltip
            ) {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
            }
            button.contentTintColor = .secondaryLabelColor
            return button
        }
    }

    // MARK: - Helpers

    private func updateAspectRatioButtonAppearance() {
        guard buttons.count > 1 else { return }
        let button = buttons[1]
        let symbolName = isSelectorVisible ? "aspectratio.fill" : "aspectratio"
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: L("crop_editor.aspect_ratio")) {
            button.image = image.withSymbolConfiguration(config)
        }
        button.contentTintColor = isSelectorVisible ? .labelColor : .secondaryLabelColor
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        // ボタン行（下部）
        let buttonY = Self.bottomPadding
        let totalWidth = CGFloat(buttons.count) * Self.buttonSize
            + CGFloat(buttons.count - 1) * Self.buttonSpacing
        let startX = (bounds.width - totalWidth) / 2

        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(
                x: startX + CGFloat(index) * (Self.buttonSize + Self.buttonSpacing),
                y: buttonY,
                width: Self.buttonSize,
                height: Self.buttonSize
            )
        }

        // セレクター（ボタンの上）
        let selectorY = Self.bottomPadding + Self.buttonSize
        selectorView?.frame = NSRect(x: 0, y: selectorY, width: bounds.width, height: Self.selectorHeight)

        // スライダー（最上部）
        let sliderY = bounds.height - Self.sliderHeight
        sliderView?.frame = NSRect(x: 0, y: sliderY, width: bounds.width, height: Self.sliderHeight)
    }

    // MARK: - Actions

    @objc private func rotate90Tapped() {
        onRotate90Tapped?()
    }

    @objc private func aspectRatioTapped() {
        isSelectorVisible.toggle()
        selectorView?.isHidden = !isSelectorVisible
        updateAspectRatioButtonAppearance()
    }

    // MARK: - Public API

    func resetStraightenAngle() {
        sliderView?.reset()
    }

    func updateAspectRatioSelection(_ preset: AspectRatioPreset) {
        selectorView?.updateSelection(preset)
    }

    func hideAspectRatioSelector() {
        isSelectorVisible = false
        selectorView?.isHidden = true
        updateAspectRatioButtonAppearance()
    }
}
