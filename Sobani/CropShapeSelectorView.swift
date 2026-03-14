import Cocoa

/// クロップ形状選択用の水平ボタンバー
@MainActor
final class CropShapeSelectorView: NSView {

    // MARK: - Constants

    static let viewHeight: CGFloat = 36

    // MARK: - Properties

    var selectedShape: CropShape = .rectangle {
        didSet {
            guard selectedShape != oldValue else { return }
            updateButtonAppearances()
        }
    }

    var cornersLinked: Bool = true {
        didSet {
            guard cornersLinked != oldValue else { return }
            updateLinkButtonAppearance()
        }
    }

    var onShapeSelected: ((CropShape) -> Void)?
    var onCornersLinkedToggled: ((Bool) -> Void)?

    private var aspectOrientation: CropGeometry.AspectOrientation = .square
    private var shapeButtons: [NSButton] = []
    private var linkButton: NSButton?
    private let stackView = NSStackView()

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    // MARK: - Public API

    func setCornersLinked(_ linked: Bool) {
        cornersLinked = linked
    }

    /// アスペクト比に応じてアイコンを正方形/横長/縦長に切り替える
    func updateAspectOrientation(_ orientation: CropGeometry.AspectOrientation) {
        guard aspectOrientation != orientation else { return }
        aspectOrientation = orientation
        updateShapeIcons()
    }

    // MARK: - Setup

    private func setupSubviews() {
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.spacing = AppConstants.selectorButtonSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor)
        ])

        createShapeButtons()
        createLinkButton()
        updateButtonAppearances()
        updateLinkButtonAppearance()
    }

    private static let shapeTooltipKeys: [CropShape: String] = [
        .rectangle: "crop_editor.shape_rectangle",
        .circle: "crop_editor.shape_circle",
        .roundedRectangle: "crop_editor.shape_rounded_rect"
    ]

    private func createShapeButtons() {
        for (index, shape) in CropShape.allCases.enumerated() {
            let button = NSButton(frame: .zero)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.tag = index
            button.wantsLayer = true
            button.translatesAutoresizingMaskIntoConstraints = false
            button.imagePosition = .imageOnly
            button.image = SFSymbolUtils.icon(
                symbolName(for: shape), pointSize: AppConstants.menuIconPointSize, weight: .medium
            )
            button.toolTip = L(Self.shapeTooltipKeys[shape, default: ""])
            button.target = self
            button.action = #selector(shapeButtonTapped(_:))
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: AppConstants.shapeButtonSize),
                button.heightAnchor.constraint(equalToConstant: AppConstants.shapeButtonSize)
            ])

            stackView.addArrangedSubview(button)
            shapeButtons.append(button)
        }
    }

    private func createLinkButton() {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(linkButtonTapped)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: AppConstants.shapeButtonSize),
            button.heightAnchor.constraint(equalToConstant: AppConstants.shapeButtonSize)
        ])

        stackView.addArrangedSubview(button)
        linkButton = button
    }

    // MARK: - Actions

    @objc private func shapeButtonTapped(_ sender: NSButton) {
        let shapes = CropShape.allCases
        guard sender.tag >= 0, sender.tag < shapes.count else { return }
        let shape = shapes[sender.tag]
        selectedShape = shape
        onShapeSelected?(shape)
    }

    @objc private func linkButtonTapped() {
        cornersLinked.toggle()
        onCornersLinkedToggled?(cornersLinked)
    }

    // MARK: - Appearance

    private func updateButtonAppearances() {
        let shapes = CropShape.allCases
        for (index, button) in shapeButtons.enumerated() {
            guard index < shapes.count else { continue }
            let isSelected = shapes[index] == selectedShape

            if isSelected {
                button.contentTintColor = .labelColor
                button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(AppConstants.selectorSelectedAlpha).cgColor
                button.layer?.cornerRadius = AppConstants.selectorCornerRadius
            } else {
                button.contentTintColor = .secondaryLabelColor
                button.layer?.backgroundColor = NSColor.clear.cgColor
                button.layer?.cornerRadius = 0
            }
        }
        // Show/hide link button based on shape
        linkButton?.isHidden = selectedShape != .roundedRectangle
    }

    private func symbolName(for shape: CropShape) -> String {
        switch (shape, aspectOrientation) {
        case (.rectangle, .square):
            return "squareshape"
        case (.rectangle, .landscape):
            return "rectangle"
        case (.rectangle, .portrait):
            return "rectangle.portrait"
        case (.circle, .square):
            return "circle"
        case (.circle, .landscape):
            return "oval"
        case (.circle, .portrait):
            return "oval.portrait"
        case (.roundedRectangle, .square):
            return "square"
        case (.roundedRectangle, .landscape):
            return "rectangle.roundedtop"
        case (.roundedRectangle, .portrait):
            return "rectangle.roundedtop"
        }
    }

    private func updateShapeIcons() {
        let shapes = CropShape.allCases
        for (index, button) in shapeButtons.enumerated() {
            guard index < shapes.count else { continue }
            button.image = SFSymbolUtils.icon(
                symbolName(for: shapes[index]),
                pointSize: AppConstants.menuIconPointSize, weight: .medium
            )
        }
    }

    private func updateLinkButtonAppearance() {
        let symbolName = cornersLinked ? "link" : "link.badge.plus"
        linkButton?.image = SFSymbolUtils.icon(symbolName, pointSize: AppConstants.menuIconPointSize, weight: .medium)
        linkButton?.toolTip = cornersLinked ? L("crop_editor.corners_linked") : L("crop_editor.corners_unlinked")
        linkButton?.contentTintColor = cornersLinked ? .systemYellow : .secondaryLabelColor
    }
}
