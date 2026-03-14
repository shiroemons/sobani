import Cocoa

/// アスペクト比プリセット選択用の水平ボタンバー
@MainActor
final class AspectRatioSelectorView: NSView {

    // MARK: - Constants

    static let viewHeight: CGFloat = 36

    // MARK: - Properties

    var selectedPreset: AspectRatioPreset = .free {
        didSet {
            updateButtonAppearances()
        }
    }

    var onPresetSelected: ((AspectRatioPreset) -> Void)?

    private var buttons: [NSButton] = []
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

    /// 外部からの選択同期用（コールバックは発火しない）
    func updateSelection(_ preset: AspectRatioPreset) {
        selectedPreset = preset
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

        createButtons()
        updateButtonAppearances()
    }

    private func createButtons() {
        let allPresets = AspectRatioPreset.allCases

        for (index, preset) in allPresets.enumerated() {
            let button = NSButton(title: preset.localizedName, target: self, action: #selector(buttonTapped(_:)))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.tag = index
            button.wantsLayer = true
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            stackView.addArrangedSubview(button)
            buttons.append(button)
        }
    }

    // MARK: - Actions

    @objc private func buttonTapped(_ sender: NSButton) {
        let allPresets = AspectRatioPreset.allCases
        guard sender.tag >= 0, sender.tag < allPresets.count else { return }
        let preset = allPresets[sender.tag]
        selectedPreset = preset
        onPresetSelected?(preset)
    }

    // MARK: - Appearance

    private func updateButtonAppearances() {
        let allPresets = AspectRatioPreset.allCases
        for (index, button) in buttons.enumerated() {
            let preset = allPresets[index]
            let isSelected = preset == selectedPreset

            if isSelected {
                let font = NSFont.systemFont(ofSize: 15, weight: .bold)
                button.attributedTitle = NSAttributedString(
                    string: preset.localizedName,
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.labelColor
                    ]
                )
                button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(AppConstants.selectorSelectedAlpha).cgColor
                button.layer?.cornerRadius = AppConstants.selectorCornerRadius
            } else {
                let font = NSFont.systemFont(ofSize: 12, weight: .regular)
                button.attributedTitle = NSAttributedString(
                    string: preset.localizedName,
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                button.layer?.backgroundColor = NSColor.clear.cgColor
                button.layer?.cornerRadius = 0
            }
        }
    }
}
