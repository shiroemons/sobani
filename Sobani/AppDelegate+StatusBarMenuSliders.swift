import Cocoa

private struct SliderContainerResult {
    let container: NSView
    let iconView: NSImageView
    let label: NSTextField
    let labelMaxX: CGFloat
}

// MARK: - Status Bar Menu Sliders

extension AppDelegate {
    private func makePercentLabel(alpha: CGFloat, containerWidth: CGFloat, containerHeight: CGFloat) -> NSTextField {
        let percentWidth = AppConstants.ghostAlphaSliderPercentWidth
        let margin = AppConstants.ghostAlphaSliderTrailingMargin
        let label = NSTextField(labelWithString: FormatUtils.formatOpacity(alpha))
        label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.alignment = .right
        label.frame = NSRect(
            x: containerWidth - percentWidth - margin,
            y: (containerHeight - label.frame.height) / 2,
            width: percentWidth,
            height: label.frame.height
        )
        return label
    }

    func updatePercentLabel(in container: NSView, alpha: CGFloat) {
        if let label = container.subviews.last(where: { $0 is NSTextField }) as? NSTextField {
            label.stringValue = FormatUtils.formatOpacity(alpha)
        }
    }

    func buildPerWindowGhostAlphaSliderItem(for charWindow: CharacterWindow) -> NSMenuItem {
        let item = NSMenuItem()
        let containerWidth = AppConstants.ghostAlphaSliderContainerWidth
        let containerHeight = AppConstants.ghostAlphaSliderContainerHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        let isCustom = charWindow.customGhostAlpha != nil
        let currentAlpha = charWindow.effectiveGhostAlpha

        let checkboxX = AppConstants.ghostAlphaCheckboxX
        let checkboxSize = AppConstants.ghostAlphaCheckboxSize
        let checkboxTrailingGap = AppConstants.ghostAlphaCheckboxTrailingGap
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(togglePerWindowGhostAlphaCustom(_:)))
        checkbox.frame = NSRect(x: checkboxX, y: (containerHeight - checkboxSize) / 2, width: checkboxSize, height: checkboxSize)
        checkbox.state = isCustom ? .on : .off
        checkbox.tag = charWindow.window.windowNumber
        container.addSubview(checkbox)

        let sliderX: CGFloat = checkboxX + checkboxTrailingGap
        let sliderWidth = containerWidth - sliderX - AppConstants.ghostAlphaSliderPercentWidth - AppConstants.ghostAlphaSliderTrailingMargin
        let slider = NSSlider(
            value: Double(currentAlpha),
            minValue: Double(AppConstants.ghostModeAlphaMin),
            maxValue: Double(AppConstants.ghostModeAlphaMax),
            target: self,
            action: #selector(perWindowGhostAlphaSliderChanged(_:))
        )
        let sliderHeight = AppConstants.ghostAlphaSliderHeight
        slider.frame = NSRect(x: sliderX, y: (containerHeight - sliderHeight) / 2,
                              width: sliderWidth, height: sliderHeight)
        slider.isContinuous = true
        slider.tag = charWindow.window.windowNumber
        slider.isEnabled = isCustom
        slider.trackFillColor = .systemGray
        container.addSubview(slider)

        let percentLabel = makePercentLabel(alpha: currentAlpha, containerWidth: containerWidth, containerHeight: containerHeight)
        percentLabel.alphaValue = isCustom ? 1.0 : 0.5
        container.addSubview(percentLabel)

        item.view = container
        return item
    }

    private func makeSliderContainerBase(iconSymbol: String, labelText: String) -> SliderContainerResult {
        let containerWidth = AppConstants.ghostAlphaSliderContainerWidth
        let containerHeight = AppConstants.ghostAlphaSliderContainerHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 16
        let iconView = NSImageView(frame: NSRect(x: iconX, y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = SFSymbolUtils.icon(iconSymbol, pointSize: 12)
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        let label = NSTextField(labelWithString: labelText)
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: iconX + iconSize + 4, y: (containerHeight - label.frame.height) / 2)
        container.addSubview(label)

        return SliderContainerResult(container: container, iconView: iconView, label: label, labelMaxX: label.frame.maxX)
    }

    private func makeSlider(value: CGFloat, range: ClosedRange<CGFloat>, sliderX: CGFloat,
                            tag: Int, action: Selector) -> NSSlider {
        let containerHeight = AppConstants.ghostAlphaSliderContainerHeight
        let sliderWidth = AppConstants.ghostAlphaSliderContainerWidth - sliderX
            - AppConstants.ghostAlphaSliderPercentWidth - AppConstants.ghostAlphaSliderTrailingMargin
        let sliderHeight = AppConstants.ghostAlphaSliderHeight
        let slider = NSSlider(value: Double(value), minValue: Double(range.lowerBound),
                              maxValue: Double(range.upperBound), target: self, action: action)
        slider.frame = NSRect(x: sliderX, y: (containerHeight - sliderHeight) / 2, width: sliderWidth, height: sliderHeight)
        slider.isContinuous = true
        slider.tag = tag
        slider.trackFillColor = .systemGray
        return slider
    }

    func buildPerWindowOpacitySliderItem(for charWindow: CharacterWindow) -> NSMenuItem {
        let item = NSMenuItem()
        let containerHeight = AppConstants.opacitySliderContainerHeight
        let topRowH = AppConstants.opacitySliderTopRowHeight
        let bottomRowH = containerHeight - topRowH
        let result = makeSliderContainerBase(iconSymbol: AppConstants.opacitySymbol, labelText: L("adjust.opacity"))
        let container = result.container
        // makeSliderContainerBase が生成するコンテナは ghostAlphaSliderContainerHeight (1行) のため、
        // 2行レイアウト用の高さに拡張し、アイコン・ラベルを上段に移動する。
        container.frame.size.height = containerHeight
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 16
        let topRowIconY = containerHeight - topRowH + (topRowH - iconSize) / 2
        result.iconView.frame.origin.y = topRowIconY
        result.label.frame.origin.y = topRowIconY + (iconSize - result.label.frame.height) / 2

        let opacity = charWindow.imageView.opacityLevel
        let sliderX: CGFloat = iconX + iconSize + 4
        let slider = makeSlider(value: opacity, range: AppConstants.opacityMin...AppConstants.opacityMax,
                                sliderX: sliderX, tag: charWindow.window.windowNumber,
                                action: #selector(perWindowOpacitySliderChanged(_:)))
        slider.frame.origin.y = (bottomRowH - AppConstants.ghostAlphaSliderHeight) / 2
        container.addSubview(slider)

        container.addSubview(makePercentLabel(alpha: opacity, containerWidth: AppConstants.ghostAlphaSliderContainerWidth,
                                              containerHeight: bottomRowH))

        item.view = container
        return item
    }

    func buildGhostAlphaSliderItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.tag = MenuItemTag.ghostModeAlphaSlider.rawValue
        let result = makeSliderContainerBase(iconSymbol: AppConstants.ghostModeSymbol, labelText: L("ghost.alpha_setting"))
        let container = result.container
        let labelMaxX = result.labelMaxX
        let sliderX = labelMaxX + AppConstants.ghostAlphaSliderTrailingMargin
        container.addSubview(makeSlider(value: GhostModeSettings.globalAlpha,
                                        range: AppConstants.ghostModeAlphaMin...AppConstants.ghostModeAlphaMax,
                                        sliderX: sliderX, tag: 0,
                                        action: #selector(ghostAlphaSliderChanged(_:))))
        container.addSubview(makePercentLabel(alpha: GhostModeSettings.globalAlpha,
                                              containerWidth: AppConstants.ghostAlphaSliderContainerWidth,
                                              containerHeight: AppConstants.ghostAlphaSliderContainerHeight))
        item.view = container
        return item
    }
}
