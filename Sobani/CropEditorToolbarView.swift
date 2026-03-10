import Cocoa

/// クロップエディタ下部ツールバー
@MainActor
final class CropEditorToolbarView: NSView {

    // MARK: - Constants

    private static let buttonSize: CGFloat = 32
    private static let buttonSpacing: CGFloat = 24
    private static let sliderHeight: CGFloat = 50
    private static let bottomPadding: CGFloat = 12

    // MARK: - Callbacks

    var onStraightenAngleChanged: ((CGFloat) -> Void)?
    var onRotate90Tapped: (() -> Void)?
    var onAspectRatioTapped: (() -> Void)?

    // MARK: - Subviews

    private var sliderView: StraightenSliderView?

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
        let sliderY = bounds.height - Self.sliderHeight
        let slider = StraightenSliderView(
            frame: NSRect(x: 0, y: sliderY, width: bounds.width, height: Self.sliderHeight)
        )
        slider.onAngleChanged = { [weak self] angle in
            self?.onStraightenAngleChanged?(angle)
        }
        addSubview(slider)
        sliderView = slider

        // ボタン行（下部）
        let buttonY = Self.bottomPadding
        let buttons = createButtons()
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
            addSubview(button)
        }
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
            return button
        }
    }

    // MARK: - Actions

    @objc private func rotate90Tapped() {
        onRotate90Tapped?()
    }

    @objc private func aspectRatioTapped() {
        onAspectRatioTapped?()
    }

    // MARK: - Public API

    func resetStraightenAngle() {
        sliderView?.reset()
    }
}
