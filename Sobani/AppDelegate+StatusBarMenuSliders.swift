import Cocoa

// MARK: - Slider Menu Item Factory

/// メニューに埋め込むスライダー項目（アイコン・ラベル・スライダー・% 表示）のビューを組み立てる。
///
/// 画像ウィンドウのコンテキストメニューとステータスメニューで共通に使う。
@MainActor
enum SliderMenuItemFactory {
    /// スライダーの値と操作先
    struct SliderSpec {
        let value: CGFloat
        let range: ClosedRange<CGFloat>
        let target: AnyObject
        let action: Selector
        /// ステータスメニューではウィンドウ番号を入れて操作対象を識別する
        var tag: Int = 0
    }

    /// % 表示ラベルの識別用タグ。スライダーやチェックボックスの tag はウィンドウ番号に使うため、ラベルにだけ付ける。
    private static let percentLabelTag = 1
    private static let leadingInset: CGFloat = 16
    private static let iconSize: CGFloat = 16
    private static let iconPointSize: CGFloat = 12
    private static let iconLabelGap: CGFloat = 4
    /// スライダーが無効なときの % 表示の透明度
    private static let disabledPercentLabelAlpha: CGFloat = 0.5

    /// 2 行レイアウトでスライダーの左端を揃える位置（アイコン + 間隔の右）
    private static var contentLeadingX: CGFloat { leadingInset + iconSize + iconLabelGap }

    /// 上段にアイコンとラベル、下段にスライダーと % 表示を置く 2 行のスライダー項目
    static func makeTwoRowItem(iconSymbol: String, text: String, slider spec: SliderSpec) -> NSMenuItem {
        let containerHeight = AppConstants.opacitySliderContainerHeight
        let topRowHeight = AppConstants.opacitySliderTopRowHeight
        let bottomRowHeight = containerHeight - topRowHeight
        let container = makeContainer(height: containerHeight)
        addIconAndLabel(
            to: container, iconSymbol: iconSymbol, text: text,
            row: (minY: bottomRowHeight, height: topRowHeight)
        )
        addSlider(spec, to: container, x: contentLeadingX, row: (minY: 0, height: bottomRowHeight))
        addPercentLabel(value: spec.value, to: container, row: (minY: 0, height: bottomRowHeight))
        return menuItem(with: container)
    }

    /// アイコン・ラベル・スライダー・% 表示を 1 行に並べるスライダー項目
    static func makeSingleRowItem(iconSymbol: String, text: String, slider spec: SliderSpec) -> NSMenuItem {
        let row = (minY: CGFloat(0), height: AppConstants.ghostAlphaSliderContainerHeight)
        let container = makeContainer(height: row.height)
        let label = addIconAndLabel(to: container, iconSymbol: iconSymbol, text: text, row: row)
        addSlider(spec, to: container, x: label.frame.maxX + AppConstants.ghostAlphaSliderTrailingMargin, row: row)
        addPercentLabel(value: spec.value, to: container, row: row)
        return menuItem(with: container)
    }

    static func makeContainer(height: CGFloat) -> NSView {
        NSView(frame: NSRect(x: 0, y: 0, width: AppConstants.ghostAlphaSliderContainerWidth, height: height))
    }

    static func menuItem(with container: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = container
        return item
    }

    /// アイコンとラベルを行の縦中央に置き、ラベルを返す
    @discardableResult
    static func addIconAndLabel(
        to container: NSView, iconSymbol: String, text: String, row: (minY: CGFloat, height: CGFloat)
    ) -> NSTextField {
        let iconY = row.minY + (row.height - iconSize) / 2
        let iconView = NSImageView(frame: NSRect(x: leadingInset, y: iconY, width: iconSize, height: iconSize))
        iconView.image = SFSymbolUtils.icon(iconSymbol, pointSize: iconPointSize)
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: contentLeadingX, y: iconY + (iconSize - label.frame.height) / 2)
        container.addSubview(label)
        return label
    }

    /// スライダーを `x` から % 表示の手前まで、行の縦中央に置く
    @discardableResult
    static func addSlider(
        _ spec: SliderSpec, to container: NSView, x: CGFloat, row: (minY: CGFloat, height: CGFloat)
    ) -> NSSlider {
        let width = AppConstants.ghostAlphaSliderContainerWidth - x
            - AppConstants.ghostAlphaSliderPercentWidth
            - AppConstants.ghostAlphaSliderTrailingMargin
        let height = AppConstants.ghostAlphaSliderHeight
        let slider = NSSlider(
            value: Double(spec.value),
            minValue: Double(spec.range.lowerBound),
            maxValue: Double(spec.range.upperBound),
            target: spec.target,
            action: spec.action
        )
        slider.frame = NSRect(x: x, y: row.minY + (row.height - height) / 2, width: width, height: height)
        slider.isContinuous = true
        slider.tag = spec.tag
        slider.trackFillColor = .systemGray
        container.addSubview(slider)
        return slider
    }

    /// 右端に % 表示ラベルを行の縦中央に置く
    @discardableResult
    static func addPercentLabel(
        value: CGFloat, to container: NSView, row: (minY: CGFloat, height: CGFloat)
    ) -> NSTextField {
        let percentWidth = AppConstants.ghostAlphaSliderPercentWidth
        let label = NSTextField(labelWithString: FormatUtils.formatOpacity(value))
        label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.alignment = .right
        label.tag = percentLabelTag
        label.frame = NSRect(
            x: AppConstants.ghostAlphaSliderContainerWidth - percentWidth - AppConstants.ghostAlphaSliderTrailingMargin,
            y: row.minY + (row.height - label.frame.height) / 2,
            width: percentWidth,
            height: label.frame.height
        )
        container.addSubview(label)
        return label
    }

    static func slider(in container: NSView) -> NSSlider? {
        container.subviews.lazy.compactMap { $0 as? NSSlider }.first
    }

    static func percentLabel(in container: NSView) -> NSTextField? {
        container.subviews.lazy.compactMap { $0 as? NSTextField }.first { $0.tag == percentLabelTag }
    }

    /// スライダーと % 表示を現在値に合わせる
    static func update(_ container: NSView, value: CGFloat) {
        slider(in: container)?.doubleValue = Double(value)
        updatePercentLabel(in: container, value: value)
    }

    static func updatePercentLabel(in container: NSView, value: CGFloat) {
        percentLabel(in: container)?.stringValue = FormatUtils.formatOpacity(value)
    }

    /// スライダーの有効・無効を切り替え、無効時は % 表示を薄くする
    static func setSliderEnabled(_ enabled: Bool, in container: NSView) {
        slider(in: container)?.isEnabled = enabled
        percentLabel(in: container)?.alphaValue = enabled ? 1.0 : disabledPercentLabelAlpha
    }
}

// MARK: - Status Bar Menu Sliders

extension AppDelegate {
    func buildPerWindowGhostAlphaSliderItem(for imageWindow: ImageWindow) -> NSMenuItem {
        let row = (minY: CGFloat(0), height: AppConstants.ghostAlphaSliderContainerHeight)
        let container = SliderMenuItemFactory.makeContainer(height: row.height)
        let isCustom = imageWindow.customGhostAlpha != nil
        let currentAlpha = imageWindow.effectiveGhostAlpha

        let checkboxX = AppConstants.ghostAlphaCheckboxX
        let checkboxSize = AppConstants.ghostAlphaCheckboxSize
        let checkbox = NSButton(
            checkboxWithTitle: "",
            target: self,
            action: #selector(togglePerWindowGhostAlphaCustom(_:))
        )
        checkbox.frame = NSRect(
            x: checkboxX,
            y: (row.height - checkboxSize) / 2,
            width: checkboxSize,
            height: checkboxSize
        )
        checkbox.state = isCustom ? .on : .off
        checkbox.tag = imageWindow.window.windowNumber
        container.addSubview(checkbox)

        SliderMenuItemFactory.addSlider(
            SliderMenuItemFactory.SliderSpec(
                value: currentAlpha,
                range: AppConstants.ghostModeAlphaMin...AppConstants.ghostModeAlphaMax,
                target: self,
                action: #selector(perWindowGhostAlphaSliderChanged(_:)),
                tag: imageWindow.window.windowNumber
            ),
            to: container,
            x: checkboxX + AppConstants.ghostAlphaCheckboxTrailingGap,
            row: row
        )
        SliderMenuItemFactory.addPercentLabel(value: currentAlpha, to: container, row: row)
        SliderMenuItemFactory.setSliderEnabled(isCustom, in: container)
        return SliderMenuItemFactory.menuItem(with: container)
    }

    func buildPerWindowOpacitySliderItem(for imageWindow: ImageWindow) -> NSMenuItem {
        SliderMenuItemFactory.makeTwoRowItem(
            iconSymbol: AppConstants.opacitySymbol,
            text: L("adjust.opacity"),
            slider: SliderMenuItemFactory.SliderSpec(
                value: imageWindow.imageView.opacityLevel,
                range: AppConstants.opacityMin...AppConstants.opacityMax,
                target: self,
                action: #selector(perWindowOpacitySliderChanged(_:)),
                tag: imageWindow.window.windowNumber
            )
        )
    }

    func buildGhostAlphaSliderItem() -> NSMenuItem {
        let item = SliderMenuItemFactory.makeSingleRowItem(
            iconSymbol: AppConstants.ghostModeSymbol,
            text: L("ghost.alpha_setting"),
            slider: SliderMenuItemFactory.SliderSpec(
                value: GhostModeSettings.globalAlpha,
                range: AppConstants.ghostModeAlphaMin...AppConstants.ghostModeAlphaMax,
                target: self,
                action: #selector(ghostAlphaSliderChanged(_:))
            )
        )
        item.tag = MenuItemTag.ghostModeAlphaSlider.rawValue
        return item
    }
}
