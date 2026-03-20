import Cocoa

// MARK: - Top Bar Builder

extension CropEditorPanelController {

    func createTopBar(width: CGFloat) -> NSView {
        let bar = NSView(frame: NSRect(
            x: 0, y: 0, width: width, height: AppConstants.cropEditorTopBarHeight
        ))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = Self.toolbarBackgroundCGColor()
        topBarView = bar

        let pillSize = AppConstants.cropEditorPillButtonSize
        let rowSpacing = Self.topBarRowSpacing

        // Centre the two rows within the bar height
        let twoRowsHeight = pillSize * 2 + rowSpacing
        let verticalOffset = (AppConstants.cropEditorTopBarHeight - twoRowsHeight) / 2

        let row2Y = verticalOffset                         // bottom row (row 2)
        let row1Y = verticalOffset + pillSize + rowSpacing // top row (row 1)

        addRow1(to: bar, rowY: row1Y)
        addRow2(to: bar, rowY: row2Y)

        return bar
    }

    func addRow1(to bar: NSView, rowY: CGFloat) {
        let pillSize = AppConstants.cropEditorPillButtonSize
        let sidePad = Self.topBarSidePadding
        let width = AppConstants.cropEditorPanelWidth
        // ── Row 1: [× Cancel]  [↩ Undo | Redo ↪]  [✓ Done] ──
        let (cancelPill, _) = makePillButton(symbolName: "xmark", action: #selector(cancelTapped))
        cancelPill.frame = NSRect(x: sidePad, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(cancelPill)
        pillContainers.append(cancelPill)

        let (donePill, doneBtn) = makePillButton(
            symbolName: "checkmark", action: #selector(doneTapped)
        )
        doneBtn.keyEquivalent = "\r"
        donePill.frame = NSRect(
            x: width - sidePad - pillSize, y: rowY, width: pillSize, height: pillSize
        )
        bar.addSubview(donePill)
        doneButton = doneBtn
        donePillContainer = donePill
        // donePillContainer は updateDoneButtonAppearance で色管理するため pillContainers に追加しない

        // Center: grouped Undo/Redo pill
        let groupWidth = pillSize * 2 + Self.separatorWidth
        let undoRedoResult = makeGroupedPill(
            symbols: [
                ("arrow.uturn.backward", #selector(undoTapped)),
                ("arrow.uturn.forward", #selector(redoTapped))
            ],
            width: groupWidth
        )
        let groupX = (width - groupWidth) / 2
        undoRedoResult.container.frame = NSRect(
            x: groupX, y: rowY, width: groupWidth, height: pillSize
        )
        bar.addSubview(undoRedoResult.container)
        pillContainers.append(undoRedoResult.container)
        separatorViews.append(contentsOf: undoRedoResult.separators)

        if undoRedoResult.buttons.count >= 2 {
            undoButton = undoRedoResult.buttons[0]
            redoButton = undoRedoResult.buttons[1]
        }
    }

    func addRow2(to bar: NSView, rowY: CGFloat) {
        let pillSize = AppConstants.cropEditorPillButtonSize
        let sidePad = Self.topBarSidePadding
        let width = AppConstants.cropEditorPanelWidth
        // ── Row 2: [Flip | Rotate]  [戻す] ──

        // Left: grouped pill [Flip | Rotate90]
        let groupWidth = pillSize * 2 + Self.separatorWidth
        let flipRotateResult = makeGroupedPill(
            symbols: [
                (
                    "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    #selector(flipTapped)
                ),
                ("rotate.left", #selector(rotate90Tapped))
            ],
            width: groupWidth
        )
        flipRotateResult.container.frame = NSRect(
            x: sidePad, y: rowY, width: groupWidth, height: pillSize
        )
        bar.addSubview(flipRotateResult.container)
        pillContainers.append(flipRotateResult.container)
        separatorViews.append(contentsOf: flipRotateResult.separators)

        // Center: "戻す" revert button
        let revertX = (width - Self.revertPillWidth) / 2
        let revertContainer = makePillContainer(
            frame: NSRect(x: revertX, y: rowY, width: Self.revertPillWidth, height: pillSize)
        )

        let revertBtn = NSButton(frame: revertContainer.bounds)
        revertBtn.bezelStyle = .regularSquare
        revertBtn.isBordered = false
        revertBtn.imagePosition = .noImage
        revertBtn.title = L("crop_editor.reset")
        revertBtn.font = NSFont.systemFont(ofSize: Self.revertFontSize, weight: .medium)
        revertBtn.contentTintColor = .systemYellow
        revertBtn.target = self
        revertBtn.action = #selector(resetTapped)
        revertContainer.addSubview(revertBtn)
        bar.addSubview(revertContainer)
        revertButton = revertBtn
        pillContainers.append(revertContainer)

        // Right: mode toggle pill [angle | aspectratio]
        let modeGroupWidth = pillSize * 2 + Self.separatorWidth
        let modeResult = makeGroupedPill(
            symbols: [
                ("angle", #selector(correctionModeTapped)),
                ("aspectratio", #selector(aspectRatioModeTapped))
            ],
            width: modeGroupWidth
        )
        modeResult.container.frame = NSRect(
            x: width - sidePad - modeGroupWidth, y: rowY, width: modeGroupWidth, height: pillSize
        )
        bar.addSubview(modeResult.container)
        modeButtons = modeResult.buttons
        pillContainers.append(modeResult.container)
        separatorViews.append(contentsOf: modeResult.separators)
    }

    func makePillContainer(frame: NSRect) -> NSView {
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.pillBackgroundCGColor()
        container.layer?.cornerRadius = AppConstants.cropEditorPillCornerRadius
        return container
    }

    func configureIconButton(_ button: NSButton, symbolName: String, action: Selector) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.image = SFSymbolUtils.icon(
            symbolName, pointSize: Self.pillIconPointSize, weight: .medium
        )
        button.contentTintColor = .labelColor
    }

    /// Creates a pill-shaped container with a single icon button inside.
    func makePillButton(
        symbolName: String, action: Selector
    ) -> (container: NSView, button: NSButton) {
        let size = AppConstants.cropEditorPillButtonSize
        let container = makePillContainer(frame: NSRect(x: 0, y: 0, width: size, height: size))

        let button = NSButton(frame: container.bounds)
        configureIconButton(button, symbolName: symbolName, action: action)
        container.addSubview(button)
        return (container, button)
    }

    struct GroupedPillResult {
        let container: NSView
        let buttons: [NSButton]
        let separators: [NSView]
    }

    /// Creates a grouped pill with multiple icon buttons separated by a 1px vertical line.
    func makeGroupedPill(
        symbols: [(String, Selector)], width: CGFloat
    ) -> GroupedPillResult {
        let height = AppConstants.cropEditorPillButtonSize
        let container = makePillContainer(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let buttonWidth =
            (width - CGFloat(symbols.count - 1) * Self.separatorWidth) / CGFloat(symbols.count)
        var buttons: [NSButton] = []
        var separators: [NSView] = []

        for (index, (symbolName, action)) in symbols.enumerated() {
            let buttonX = CGFloat(index) * (buttonWidth + Self.separatorWidth)
            let button = NSButton(frame: NSRect(
                x: buttonX, y: 0, width: buttonWidth, height: height
            ))
            configureIconButton(button, symbolName: symbolName, action: action)
            container.addSubview(button)
            buttons.append(button)

            // Add 1px separator between buttons
            if index < symbols.count - 1 {
                let sepX = buttonX + buttonWidth
                let separator = NSView(frame: NSRect(
                    x: sepX, y: Self.separatorInset,
                    width: Self.separatorWidth, height: height - Self.separatorInset * 2
                ))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = Self.separatorCGColor()
                container.addSubview(separator)
                separators.append(separator)
            }
        }

        return GroupedPillResult(container: container, buttons: buttons, separators: separators)
    }
}

// MARK: - Shape Handlers

extension CropEditorPanelController {

    func handleShapeSelected(_ shape: CropShape) {
        var updated = currentCropRect.with(shape: shape)

        if shape == .roundedRectangle && updated.cornerRadii == .zero {
            // 角丸初回選択: デフォルト角丸を設定
            updated = updated.with(cornerRadii: CornerRadii.defaultLinked)
        }

        currentCropRect = updated
        canvasView?.initializeFromCropRect(updated)
        syncToolbarState(to: updated)
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    func handleCornersLinkedToggled(_ linked: Bool) {
        currentCropRect = currentCropRect.with(cornersLinked: linked)
        canvasView?.cropRect = currentCropRect
        recordCurrentState()
    }
}
