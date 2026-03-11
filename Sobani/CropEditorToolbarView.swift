import Cocoa

// MARK: - Enums

enum ToolbarMode {
    case correction   // デフォルト: モードボタン + ルーラーダイヤル
    case aspectRatio  // アスペクト比セレクターのみ

    var toggleSymbolName: String {
        switch self {
        case .correction: return "aspectratio"
        case .aspectRatio: return "angle"
        }
    }
}

enum StraightenMode: CaseIterable {
    case straighten              // 水平傾き補正
    case verticalPerspective     // 垂直パース補正
    case horizontalPerspective   // 水平パース補正

    var symbolName: String {
        switch self {
        case .straighten: return "circle.and.line.horizontal"
        case .verticalPerspective: return "trapezoid.and.line.vertical"
        case .horizontalPerspective: return "trapezoid.and.line.horizontal"
        }
    }

    var localizationKey: String {
        switch self {
        case .straighten: return "crop_editor.straighten"
        case .verticalPerspective: return "crop_editor.vertical_perspective"
        case .horizontalPerspective: return "crop_editor.horizontal_perspective"
        }
    }
}

// MARK: - CropEditorToolbarView

/// クロップエディタ下部ツールバー（iPhone風 2モード切替）
@MainActor
final class CropEditorToolbarView: NSView {

    // MARK: - Constants

    private static let modeButtonSize: CGFloat = 40
    private static let modeButtonSpacing: CGFloat = 16

    // MARK: - Callbacks

    var onStraightenAngleChanged: ((CGFloat) -> Void)?
    var onAspectRatioSelected: ((AspectRatioPreset) -> Void)?
    var onModeChanged: ((StraightenMode) -> Void)?
    var onSliderDragEnded: (() -> Void)?

    // MARK: - State

    private var toolbarMode: ToolbarMode = .correction
    private var straightenMode: StraightenMode = .straighten

    private var modeAngles: [StraightenMode: CGFloat] = [
        .straighten: 0,
        .verticalPerspective: 0,
        .horizontalPerspective: 0
    ]

    // MARK: - Subviews

    private var sliderView: StraightenSliderView?
    private var selectorView: AspectRatioSelectorView?
    private var modeButtonViews: [ModeButtonView] = []

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

        // ルーラーダイヤル（上部）
        let slider = StraightenSliderView(frame: .zero)
        slider.onAngleChanged = { [weak self] angle in
            self?.handleSliderAngleChanged(angle)
        }
        slider.onDragEnded = { [weak self] in
            self?.onSliderDragEnded?()
        }
        addSubview(slider)
        sliderView = slider

        // アスペクト比セレクター（非表示で開始）
        let selector = AspectRatioSelectorView(frame: .zero)
        selector.onPresetSelected = { [weak self] preset in
            self?.onAspectRatioSelected?(preset)
        }
        selector.isHidden = true
        addSubview(selector)
        selectorView = selector

        // モードボタン行（下部）
        let created = createModeButtonViews()
        for view in created {
            addSubview(view)
        }
        modeButtonViews = created

        updateModeButtonViews()
    }

    private struct ModeButtonSpec {
        let symbol: String
        let tooltip: String
        let mode: StraightenMode
    }

    private func createModeButtonViews() -> [ModeButtonView] {
        let specs: [ModeButtonSpec] = StraightenMode.allCases.map { mode in
            ModeButtonSpec(symbol: mode.symbolName, tooltip: L(mode.localizationKey), mode: mode)
        }

        return specs.map { spec in
            let view = ModeButtonView(symbolName: spec.symbol)
            view.toolTip = spec.tooltip
            view.onClick = { [weak self] in
                self?.switchStraightenMode(to: spec.mode)
            }
            return view
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        switch toolbarMode {
        case .correction:
            layoutCorrectionMode()
        case .aspectRatio:
            layoutAspectRatioMode()
        }
    }

    private func switchStraightenMode(to mode: StraightenMode) {
        if mode == straightenMode {
            // 同じモードを再タップ → その補正をリセット
            resetAngleForMode(mode)
            sliderView?.angle = 0
            updateModeButtonViews()
            onStraightenAngleChanged?(0)
            onSliderDragEnded?()
            return
        }
        straightenMode = mode
        // 切り替えたモードの角度をルーラーに反映
        sliderView?.angle = angleForMode(mode)
        onModeChanged?(mode)
        updateModeButtonViews()
        // 選択中ボタンが中央に来るようにレイアウトを更新
        layout()
    }

    private func resetAngleForMode(_ mode: StraightenMode) {
        modeAngles[mode] = 0
    }

    // MARK: - Slider Callback

    private func handleSliderAngleChanged(_ angle: CGFloat) {
        modeAngles[straightenMode] = angle
        onStraightenAngleChanged?(angle)
        updateModeButtonViews()
    }

    // MARK: - Helpers

    private func angleForMode(_ mode: StraightenMode) -> CGFloat {
        modeAngles[mode, default: 0]
    }

    // MARK: - Public API

    var currentToolbarMode: ToolbarMode {
        toolbarMode
    }

    var currentStraightenMode: StraightenMode {
        straightenMode
    }

    func setMode(_ mode: ToolbarMode) {
        toolbarMode = mode
        layout()
    }

    func resetStraightenAngle() {
        for mode in StraightenMode.allCases {
            modeAngles[mode] = 0
        }
        sliderView?.reset()
        updateModeButtonViews()
    }

    func updateAspectRatioSelection(_ preset: AspectRatioPreset) {
        selectorView?.updateSelection(preset)
    }

    func hideAspectRatioSelector() {
        setMode(.correction)
    }

    func setAngleForCurrentMode(_ angle: CGFloat) {
        modeAngles[straightenMode] = angle
        sliderView?.angle = angle
    }

    func getCurrentModeAngle() -> CGFloat {
        angleForMode(straightenMode)
    }

    /// Undo/Redo時に全モードの角度を一括同期する
    func syncAngles(straighten: CGFloat, verticalPerspective: CGFloat, horizontalPerspective: CGFloat) {
        modeAngles[.straighten] = straighten
        modeAngles[.verticalPerspective] = verticalPerspective
        modeAngles[.horizontalPerspective] = horizontalPerspective
        sliderView?.angle = angleForMode(straightenMode)
        updateModeButtonViews()
    }
}

// MARK: - Layout

private extension CropEditorToolbarView {

    func layoutCorrectionMode() {
        // Layout (bottom to top) within toolbar:
        // y=14:  ruler (44pt)
        // y=82:  modeButtons (40pt) — TOP
        let rulerY: CGFloat = 14
        let buttonY: CGFloat = 82

        // ボタン行: 選択中ボタンが中央に来るようにオフセット
        let modes: [StraightenMode] = [.straighten, .verticalPerspective, .horizontalPerspective]
        let selectedIndex = CGFloat(modes.firstIndex(of: straightenMode) ?? 0)
        let startX = bounds.midX - Self.modeButtonSize / 2
            - selectedIndex * (Self.modeButtonSize + Self.modeButtonSpacing)

        for (index, buttonView) in modeButtonViews.enumerated() {
            let buttonX = startX + CGFloat(index) * (Self.modeButtonSize + Self.modeButtonSpacing)
            buttonView.frame = NSRect(x: buttonX, y: buttonY, width: Self.modeButtonSize, height: Self.modeButtonSize)
            buttonView.isHidden = false
        }

        // ルーラーダイヤル（下部）
        sliderView?.frame = NSRect(
            x: 0,
            y: rulerY,
            width: bounds.width,
            height: AppConstants.cropEditorRulerHeight
        )
        sliderView?.isHidden = false

        // セレクターを隠す
        selectorView?.isHidden = true
    }

    func layoutAspectRatioMode() {
        // モードボタン・ルーラーを隠す
        for buttonView in modeButtonViews {
            buttonView.isHidden = true
        }
        sliderView?.isHidden = true

        // セレクターを垂直中央配置
        let selectorHeight = AspectRatioSelectorView.viewHeight
        let selectorY = (bounds.height - selectorHeight) / 2
        selectorView?.frame = NSRect(x: 0, y: selectorY, width: bounds.width, height: selectorHeight)
        selectorView?.isHidden = false
    }
}

// MARK: - Button Management

private extension CropEditorToolbarView {

    func updateModeButtonViews() {
        let modes: [StraightenMode] = [.straighten, .verticalPerspective, .horizontalPerspective]
        for (index, buttonView) in modeButtonViews.enumerated() {
            guard index < modes.count else { continue }
            let newSelected = modes[index] == straightenMode
            let newAngle = angleForMode(modes[index])
            if buttonView.isSelected != newSelected {
                buttonView.isSelected = newSelected
            }
            if abs(buttonView.angle - newAngle) > AppConstants.floatingPointTolerance {
                buttonView.angle = newAngle
            }
        }
    }
}

// MARK: - ModeButtonView

/// iPhone風プログレスアーク付きモードボタン
private class ModeButtonView: NSView {
    private static let inset: CGFloat = 2
    private static let iconPointSize: CGFloat = 16
    private static let arcLineWidth: CGFloat = 2.0
    private static let baseCircleLineWidth: CGFloat = 1.5
    private static let angleFontSize: CGFloat = 13
    private static let zeroAngleThreshold: CGFloat = 0.05

    var symbolName: String
    private var cachedIcon: NSImage?

    var angle: CGFloat = 0 {
        didSet {
            if abs(angle - oldValue) > AppConstants.floatingPointTolerance {
                needsDisplay = true
            }
        }
    }

    var isSelected: Bool = false {
        didSet {
            if isSelected != oldValue {
                cachedIcon = nil
                needsDisplay = true
            }
        }
    }

    var onClick: (() -> Void)?

    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(rect.width, rect.height) / 2
        let ellipseRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        if abs(angle) < Self.zeroAngleThreshold {
            // 値=0: サークル全体を描画
            let baseColor: NSColor = isSelected ? .labelColor : .secondaryLabelColor.withAlphaComponent(0.5)
            let baseWidth: CGFloat = isSelected ? Self.arcLineWidth : Self.baseCircleLineWidth
            context.setStrokeColor(baseColor.cgColor)
            context.setLineWidth(baseWidth)
            context.addEllipse(in: ellipseRect)
            context.strokePath()

            // 選択中の背景
            if isSelected {
                context.setFillColor(NSColor.white.withAlphaComponent(0.15).cgColor)
                context.fillEllipse(in: ellipseRect)
            }

            // アイコン表示
            drawIcon(at: center)
        } else {
            // 値≠0: 薄いベースライン + プログレスアーク
            context.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(Self.arcLineWidth)
            context.addEllipse(in: ellipseRect)
            context.strokePath()

            // プログレスアーク
            let proportion = min(abs(angle) / AppConstants.straightenMaxAngle, 1.0)
            let arcAngle = proportion * CGFloat.pi * 2
            let arcColor: NSColor = angle > 0 ? .systemOrange : .labelColor

            context.setStrokeColor(arcColor.cgColor)
            context.setLineWidth(Self.arcLineWidth)
            context.setLineCap(.round)
            let startAngle = CGFloat.pi / 2
            let endAngle = startAngle - arcAngle
            context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            context.strokePath()

            // 数値テキスト表示
            let textColor: NSColor = angle > 0 ? .systemOrange : .labelColor
            let text = String(format: "%.0f", angle)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: Self.angleFontSize, weight: .semibold),
                .foregroundColor: textColor
            ]
            let attrString = NSAttributedString(string: text, attributes: attrs)
            let size = attrString.size()
            let drawPoint = NSPoint(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2
            )
            attrString.draw(at: drawPoint)
        }
    }

    private func drawIcon(at center: CGPoint) {
        let iconColor: NSColor = isSelected ? .labelColor : .secondaryLabelColor
        let icon: NSImage
        if let cached = cachedIcon {
            icon = cached
        } else {
            guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return }
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [iconColor])
            let sizeConfig = NSImage.SymbolConfiguration(pointSize: Self.iconPointSize, weight: .medium)
            let config = sizeConfig.applying(colorConfig)
            icon = baseImage.withSymbolConfiguration(config) ?? baseImage
            cachedIcon = icon
        }
        let imageSize = icon.size
        let imageRect = NSRect(
            x: center.x - imageSize.width / 2,
            y: center.y - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        icon.draw(in: imageRect)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
